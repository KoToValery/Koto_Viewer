import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as gpu;
// Thermion exposes texture allocation but does not re-export its descriptor.
// ignore: implementation_imports
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
// Pinned Thermion 0.5 does not expose SH-only ambient lighting in its interface.
// Keep these native integration details confined to this surface adapter.
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import '../cad_3d_controller.dart';
import '../models/mesh_3d.dart';
import '../rendering/cad_3d_feature_edges.dart';
import '../rendering/cad_3d_gltf_encoder.dart';
import '../rendering/cad_3d_filament_camera.dart';
import '../rendering/cad_3d_mesh_painter.dart';

/// A persistent Filament scene presented as a Flutter platform texture. Camera
/// gestures only update two matrices; no triangle sorting or pixel readback.
class Cad3DGpuSurface extends StatefulWidget {
  final Mesh3D mesh;
  final Cad3DController controller;
  final Cad3DTheme theme;
  final Cad3DShadingMode shadingMode;
  final Color? modelColor;
  final bool showGrid;
  final bool active;
  final ValueChanged<bool> onReady;
  final VoidCallback onFailure;
  final ValueChanged<gpu.ThermionViewer>? onViewerCreated;

  const Cad3DGpuSurface({
    super.key,
    required this.mesh,
    required this.controller,
    required this.theme,
    required this.shadingMode,
    required this.showGrid,
    required this.active,
    required this.onReady,
    required this.onFailure,
    this.modelColor,
    this.onViewerCreated,
  });

  @override
  State<Cad3DGpuSurface> createState() => _Cad3DGpuSurfaceState();
}

class _Cad3DGpuSurfaceState extends State<Cad3DGpuSurface>
    with WidgetsBindingObserver {
  // Desktop viewers share one engine. Keep surface binding and orphan cleanup
  // atomic across sibling viewports, including a quick close/reopen.
  static Future<void> _surfaceWork = Future.value();
  static Future<T> _serializeSurface<T>(Future<T> Function() operation) {
    final result = _surfaceWork.then((_) => operation());
    _surfaceWork = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  gpu.ThermionViewer? _viewer;
  gpu.ToneMapper? _toneMapper;
  final _assets = <gpu.ThermionAsset>[];
  final _materials = <gpu.MaterialInstance>[];
  Future<void> _work = Future.value();
  bool _closed = false, _failed = false, _queued = false;
  bool _foreground = true, _textureReady = false;
  PlatformTextureDescriptor? _texture;
  Size _textureSize = Size.zero, _pendingTextureSize = Size.zero;
  Timer? _resizeTimer;
  int _revision = 0;
  bool _sceneDirty = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_schedule);
    WidgetsBinding.instance.addObserver(this);
    _work = _serializeSurface(_initialize).catchError(_fail);
  }

  Future<void> _initialize() async {
    final viewer = await gpu.ThermionFlutterPlugin.createViewer();
    _viewer = viewer;
    await viewer.setRendering(false);
    if (_closed) return;
    await viewer.setPostProcessing(true);
    // The shared Vulkan/D3D Windows target does not support MSAA. FXAA works
    // with the same target on Windows and Android and preserves sharp outlines.
    await viewer.view.setAntiAliasing(false, true, false);
    final app = viewer.app as FFIFilamentApp;
    _toneMapper = await gpu.ToneMapper.aces(app);
    await viewer.setToneMapper(_toneMapper!);
    await viewer.view.setBloom(false, 0);
    await viewer.setShadowsEnabled(true);
    await viewer.view.setAmbientOcclusionOptions(
      const gpu.AmbientOcclusionOptions(
        enabled: true,
        radius: .5,
        intensity: 1.1,
      ),
    );
    await viewer.addDirectLight(
      gpu.DirectLight.sun(
        intensity: 90000,
        direction: gpu.Vector3(-.5, .4, -1),
      ),
    );
    // Filament supports one directional light. A constant diffuse environment
    // lights shadowed faces and lets SSAO darken junctions without black walls.
    final harmonics = gpu.makeFloat32List(27)..fillRange(0, 27, 0);
    harmonics.setAll(0, [.9, .94, 1]);
    final ambient = await FFIIndirectLight.fromIrradianceHarmonics(
      app,
      harmonics,
      intensity: 18000,
    );
    final scene = await viewer.view.getScene();
    await scene.setIndirectLight(ambient);
    // The viewer owns the scene's indirect light and releases it on dispose.
    if (_closed) return;
    widget.onViewerCreated?.call(viewer);
    setState(() {});
    _schedule();
  }

  void _fail(Object error, StackTrace stack) {
    debugPrint('CAD Filament texture unavailable: $error\n$stack');
    if (_closed || _failed) return;
    _failed = true;
    widget.onFailure();
  }

  void _schedule() {
    _revision++;
    if (_queued || _closed || _failed) return;
    _queued = true;
    _work = _work
        .then<void>((_) async {
          try {
            var processed = -1;
            while (!_closed && !_failed && processed != _revision) {
              processed = _revision;
              final viewer = _viewer;
              if (viewer == null) break;
              if (_sceneDirty) {
                _sceneDirty = false;
                await _upload(viewer);
              }
              if (!_closed) await _serializeSurface(() => _resize(viewer));
              if (!_closed) await _camera(viewer);
            }
          } finally {
            _queued = false;
          }
        })
        .catchError(_fail);
  }

  Future<void> _resize(gpu.ThermionViewer viewer) async {
    final size = _pendingTextureSize;
    if (size.isEmpty || size == _textureSize) return;
    await viewer.setRendering(false);
    final plugin = gpu.ThermionFlutterPlugin.instance;
    final texture = _texture == null
        ? await plugin.createTextureAndBindToView(
            viewer.view,
            size.width.toInt(),
            size.height.toInt(),
          )
        : await plugin.resizeTexture(
            _texture!,
            viewer.view,
            size.width.toInt(),
            size.height.toInt(),
          );
    if (texture == null) throw StateError('No GPU platform texture');
    // Even an allocation completed after unmount belongs to queued cleanup.
    _texture = texture;
    _textureSize = size;
    // Thermion creates a headless swapchain for every new desktop viewer, then
    // binds the platform render target to the engine's first swapchain. Remove
    // the redundant association instead of rendering the same view twice.
    final attached = viewer.app.renderManager
        .getAttachedSwapChains(viewer.view)
        .toList();
    if (Platform.isWindows && attached.length > 1) {
      final primary = (await viewer.app.getSwapChains()).first;
      for (final chain in attached) {
        if (chain.getNativeHandle() == primary.getNativeHandle()) continue;
        await viewer.app.renderManager.detach(viewer.view, swapChain: chain);
        if (viewer.app.renderManager.getAttachedViews(chain).isEmpty) {
          await viewer.app.destroySwapChain(chain);
        }
      }
    }
    if (_closed) return;
    await viewer.view.setViewport(texture.width, texture.height);
    _textureReady = true;
    await _camera(viewer);
    if (_closed) return;
    setState(() {});
    widget.onReady(true);
  }

  Future<void> _clear(gpu.ThermionViewer viewer) async {
    for (final asset in _assets) {
      await viewer.destroyAsset(asset);
    }
    _assets.clear();
    for (final material in _materials) {
      await material.destroy();
    }
    _materials.clear();
  }

  static double _linear(double c) =>
      c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();

  Future<void> _upload(gpu.ThermionViewer viewer) async {
    await viewer.setRendering(false);
    await _clear(viewer);
    final mesh = widget.mesh;
    final center = mesh.bounds.center;
    final scale = 20 / math.max(mesh.bounds.maxDimension, 1e-4);
    final wire = widget.shadingMode == Cad3DShadingMode.wireframe;
    final xray = widget.shadingMode == Cad3DShadingMode.xray;
    final useMaterials =
        !wire &&
        !xray &&
        widget.modelColor == null &&
        mesh.triangles.any((t) => t.material != null);
    final batches = <(bool, bool), List<Triangle3D>>{};
    if (!useMaterials) {
      for (final t in mesh.triangles) {
        if (t.area < 1e-8) continue;
        final color =
            widget.modelColor ?? t.color ?? widget.theme.defaultMeshColor;
        (batches[(t.isDoubleSided || xray, color.a < .999 || xray)] ??= []).add(
          t,
        );
      }
    }
    if (useMaterials) {
      // gltfio owns the PBR textures, samplers and material instances together.
      // It also generates tangent frames for normal maps and handles alpha masks
      // and UV transforms. Camera motion does not repeat this upload.
      final data = Cad3DGltfEncoder.encode(
        mesh,
        flatShaded: widget.shadingMode == Cad3DShadingMode.flatShaded,
        defaultColor: widget.theme.defaultMeshColor,
      );
      if (_closed) return;
      final asset = await viewer.loadGltfFromBuffer(
        data,
        releaseSourceData: true,
      );
      _assets.add(asset);
    } else if (!wire) {
      for (final entry in batches.entries) {
        if (_closed) return;
        final material = await viewer.app.createUbershaderMaterial(
          hasVertexColors: true,
          doubleSided: entry.key.$1,
          alphaMode: entry.key.$2 ? gpu.AlphaMode.BLEND : gpu.AlphaMode.OPAQUE,
        );
        _materials.add(material.materialInstance);
        await material.setBaseColorFactor(1, 1, 1, 1);
        await material.setMetallicFactor(0);
        await material.setRoughnessFactor(.72);
        final triangles = entry.value;
        // Bound transient upload memory. Keep architectural face normals sharp.
        for (var start = 0; start < triangles.length; start += 20000) {
          if (_closed) return;
          final end = math.min(start + 20000, triangles.length);
          final count = (end - start) * 3;
          final positions = gpu.makeFloat32List(count * 3);
          final normals = gpu.makeFloat32List(count * 3);
          final colors = gpu.makeFloat32List(count * 4);
          var vertex = 0;
          for (var i = start; i < end; i++) {
            final t = triangles[i];
            final cross = (t.v1 - t.v0).cross(t.v2 - t.v0);
            final n = cross.lengthSquared > 1e-10
                ? cross.normalized()
                : (t.normal.lengthSquared > 1e-10
                    ? t.normal.normalized()
                    : const Vector3(0, 0, 1));
            final c =
                widget.modelColor ?? t.color ?? widget.theme.defaultMeshColor;
            final points = [t.v0, t.v1, t.v2];
            for (var corner = 0; corner < 3; corner++) {
              final p = points[corner];
              final authoredNormal = t.vertexNormals?[corner];
              final vertexNormal =
                  widget.shadingMode != Cad3DShadingMode.flatShaded &&
                      authoredNormal != null &&
                      authoredNormal.lengthSquared > 1e-10
                  ? authoredNormal.normalized()
                  : n;
              final vertexColor = widget.modelColor == null
                  ? (t.vertexColors?[corner] ?? c)
                  : c;
              final local = (p - center) * scale;
              final safeLocal = Vector3(
                local.x.isFinite ? local.x : 0,
                local.y.isFinite ? local.y : 0,
                local.z.isFinite ? local.z : 0,
              );
              final safeNormal = Vector3(
                vertexNormal.x.isFinite ? vertexNormal.x : 0,
                vertexNormal.y.isFinite ? vertexNormal.y : 0,
                vertexNormal.z.isFinite ? vertexNormal.z : 1,
              );
              positions.setAll(vertex * 3, [safeLocal.x, safeLocal.y, safeLocal.z]);
              normals.setAll(vertex * 3, [
                safeNormal.x,
                safeNormal.y,
                safeNormal.z,
              ]);
              colors.setAll(vertex * 4, [
                _linear(vertexColor.r),
                _linear(vertexColor.g),
                _linear(vertexColor.b),
                xray ? vertexColor.a * .22 : vertexColor.a,
              ]);
              vertex++;
            }
          }
          // createGeometry consumes/frees its native geometry buffers.
          final geometry = gpu.Geometry(
            positions,
            List.generate(count, (i) => i),
            normals: normals,
            colors: colors,
          );
          final asset = await viewer.createGeometry(
            geometry,
            materialInstances: [material.materialInstance],
          );
          _assets.add(asset);
          // Procedural Thermion geometry defaults both shadow flags to false.
          // Transparent panes must not cast an opaque wall-shaped shadow.
          await asset.setCastShadows(!entry.key.$2);
          await asset.setReceiveShadows(!xray);
        }
      }
    }
    if (!_closed &&
        (wire || widget.shadingMode == Cad3DShadingMode.cadShadedEdges)) {
      final masks = wire
          ? null
          : Cad3DFeatureEdges.masks(mesh.triangles, mesh.bounds.maxDimension);
      final points = <Vector3>[];
      final edges = <(String, String), (Vector3, Vector3, Vector3)>{};
      final epsilon = math.max(mesh.bounds.maxDimension, 1e-4) * 1e-8;
      String key(Vector3 p) =>
          '${((p.x - center.x) / epsilon).round()},${((p.y - center.y) / epsilon).round()},${((p.z - center.z) / epsilon).round()}';
      for (final t in mesh.triangles) {
        final vertices = [t.v0, t.v1, t.v2];
        for (var edge = 0; edge < 3; edge++) {
          if (masks != null && ((masks[t] ?? 0) & (1 << edge)) == 0) continue;
          final a = vertices[edge], b = vertices[(edge + 1) % 3];
          final ka = key(a), kb = key(b);
          final edgeKey = ka.compareTo(kb) < 0 ? (ka, kb) : (kb, ka);
          final previous = edges[edgeKey];
          edges[edgeKey] = (a, b, (previous?.$3 ?? Vector3.zero) + t.normal);
        }
      }
      // Draw each crease once, offset along the bisector of its adjacent face
      // normals. Per-face copies intersected each other and produced dotted
      // z-fighting along corners even when their individual bias was increased.
      for (final (a, b, normal) in edges.values) {
        if (normal.lengthSquared < 1e-10) continue;
        final bias = normal.normalized() * (mesh.bounds.maxDimension * .001);
        points.addAll([a + bias, b + bias]);
      }
      await _lines(
        viewer,
        points,
        center,
        scale,
        widget.theme.isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
      );
    }
    if (!_closed && widget.showGrid) {
      final step = mesh.bounds.maxDimension / 10;
      final points = <Vector3>[];
      final z = mesh.bounds.min.z - step * .002;
      for (var i = -12; i <= 12; i++) {
        points.addAll([
          Vector3(center.x + i * step, center.y - 12 * step, z),
          Vector3(center.x + i * step, center.y + 12 * step, z),
          Vector3(center.x - 12 * step, center.y + i * step, z),
          Vector3(center.x + 12 * step, center.y + i * step, z),
        ]);
      }
      await _lines(viewer, points, center, scale, widget.theme.gridColor);
    }
    final background = widget.theme.background;
    await viewer.setBackgroundColor(
      background.r,
      background.g,
      background.b,
      1,
    );
  }

  Future<void> _lines(
    gpu.ThermionViewer viewer,
    List<Vector3> points,
    Vector3 center,
    double scale,
    Color color,
  ) async {
    if (points.isEmpty) return;
    final material = await viewer.app.createUbershaderMaterial(unlit: true);
    _materials.add(material.materialInstance);
    await material.setBaseColorFactor(
      _linear(color.r),
      _linear(color.g),
      _linear(color.b),
      1,
    );
    final positions = gpu.makeFloat32List(points.length * 3);
    for (var i = 0; i < points.length; i++) {
      final p = (points[i] - center) * scale;
      positions.setAll(i * 3, [p.x, p.y, p.z]);
    }
    _assets.add(
      await viewer.createGeometry(
        gpu.Geometry(
          positions,
          List.generate(points.length, (i) => i),
          primitiveType: gpu.PrimitiveType.LINES,
        ),
        materialInstances: [material.materialInstance],
      ),
    );
  }

  Future<void> _camera(gpu.ThermionViewer viewer) async {
    final size = widget.controller.viewport;
    if (size.isEmpty) return;
    final matrices = Cad3DFilamentCamera(
      widget.controller.snapshot(),
      size,
      widget.mesh.bounds.maxDimension,
    );
    final camera = await viewer.getActiveCamera();
    await camera.setModelMatrix(matrices.model);
    await camera.setProjectionMatrixWithCulling(
      matrices.projection,
      matrices.near,
      matrices.far,
    );
    await viewer.setRendering(widget.active && _foreground && _textureReady);
  }

  @override
  void didUpdateWidget(Cad3DGpuSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_schedule);
      widget.controller.addListener(_schedule);
    }
    if (oldWidget.mesh != widget.mesh ||
        oldWidget.modelColor != widget.modelColor ||
        oldWidget.theme != widget.theme ||
        oldWidget.shadingMode != widget.shadingMode ||
        oldWidget.showGrid != widget.showGrid) {
      _sceneDirty = true;
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void dispose() {
    _closed = true;
    _resizeTimer?.cancel();
    widget.controller.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    // Texture allocation, resize, uploads and teardown share one queue, so an
    // in-flight allocation cannot attach to a view that has already been freed.
    unawaited(
      _work
          .then<void>(
            (_) => _serializeSurface(() async {
              final viewer = _viewer;
              if (viewer == null) return;
              final chains = viewer.app.renderManager
                  .getAttachedSwapChains(viewer.view)
                  .toList();
              try {
                await viewer.setRendering(false);
                await gpu.ThermionFlutterPlugin.instance.destroyTextureForView(
                  viewer.view,
                );
              } finally {
                try {
                  await _clear(viewer);
                } finally {
                  await viewer.dispose();
                  await _toneMapper?.dispose();
                  _toneMapper = null;
                  final remaining = await viewer.app.getSwapChains();
                  for (final chain in chains) {
                    if (remaining.any(
                          (current) =>
                              current.getNativeHandle() ==
                              chain.getNativeHandle(),
                        ) &&
                        viewer.app.renderManager
                            .getAttachedViews(chain)
                            .isEmpty) {
                      await viewer.app.destroySwapChain(chain);
                    }
                  }
                }
              }
            }),
          )
          .catchError((Object error) {
            debugPrint('CAD texture cleanup: $error');
          }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = _viewer;
    if (viewer == null || _failed) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, constraints) {
        final logical = constraints.biggest;
        if (logical.isEmpty || !logical.isFinite) {
          return const SizedBox.expand();
        }
        final ratio = math.min(
          MediaQuery.devicePixelRatioOf(context),
          2560 / logical.longestSide,
        );
        final physical = Size(
          (logical.width * ratio).ceilToDouble(),
          (logical.height * ratio).ceilToDouble(),
        );
        if (physical != _pendingTextureSize) {
          _pendingTextureSize = physical;
          _resizeTimer?.cancel();
          // Debounce native allocation during desktop window resizing.
          _resizeTimer = Timer(
            _texture == null
                ? Duration.zero
                : const Duration(milliseconds: 100),
            _schedule,
          );
        }
        return _texture == null
            ? const SizedBox.expand()
            : Texture(
                textureId: _texture!.flutterTextureId,
                filterQuality: FilterQuality.none,
              );
      },
    );
  }
}
