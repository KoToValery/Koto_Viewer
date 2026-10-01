import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_camera.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_gpu_bindings.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';
import '../rendering/structural_3d_mesh_builder.dart';

/// Fullscreen interactive 3D viewport for structural frames, slabs, and cantilevers.
class Structural3dViewport extends StatefulWidget {
  final StructuralProject project;
  final List<CantileverZone> cantileverZones;
  final VerticalCapacityReport? verticalReport;
  final VoidCallback onExit;
  final double cadUnitsPerMeter;

  const Structural3dViewport({
    super.key,
    required this.project,
    this.cantileverZones = const [],
    this.verticalReport,
    required this.onExit,
    this.cadUnitsPerMeter = 1.0,
  });

  @override
  State<Structural3dViewport> createState() => _Structural3dViewportState();
}

class _Structural3dViewportState extends State<Structural3dViewport> {
  late final Cad3DCamera _camera;
  Cad3DShadingMode _shadingMode = Cad3DShadingMode.cadShadedEdges;
  int? _highlightStoreyIndex;
  late Mesh3D _mesh;
  bool _isInteracting = false;

  // Hardware acceleration (native SIMD depth buffer GPU renderer)
  final Cad3DGpuRenderer _gpuRenderer = Cad3DGpuRenderer();
  bool _useGpuAcceleration = true;
  ui.Image? _gpuImage;
  bool _isGpuRendering = false;
  bool _pendingGpuRender = false;
  Size _lastViewportSize = Size.zero;

  Offset? _lastPanPos;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _camera = Cad3DCamera(
      yaw: math.pi / 4,
      pitch: 0.615,
      zoom: 1.0,
      mode: Cad3DInteractionMode.orbit,
    );
    _rebuildMesh();
  }

  @override
  void dispose() {
    _gpuRenderer.dispose();
    _gpuImage?.dispose();
    super.dispose();
  }

  void _rebuildMesh() {
    _mesh = Structural3dMeshBuilder.buildProjectMesh(
      widget.project,
      cantileverZones: widget.cantileverZones,
      verticalReport: widget.verticalReport,
      highlightStoreyIndex: _highlightStoreyIndex,
      cadUnitsPerMeter: widget.cadUnitsPerMeter,
    );
    if (_useGpuAcceleration) {
      _gpuRenderer.setMesh(_mesh);
      if (_lastViewportSize != Size.zero) {
        _requestGpuRender(_lastViewportSize);
      }
    }
  }

  void _requestGpuRender(Size size) {
    if (!_useGpuAcceleration ||
        !_gpuRenderer.isReady ||
        size.isEmpty) {
      return;
    }
    if (_isGpuRendering) {
      _pendingGpuRender = true;
      return;
    }
    _isGpuRendering = true;
    _pendingGpuRender = false;

    final maxDim = math.max(_mesh.bounds.maxDimension, 1e-4);
    final modelScale = (math.min(size.width, size.height) * 0.55) / maxDim;

    _gpuRenderer
        .renderFrame(
          camera: _camera,
          viewport: size,
          modelScale: modelScale,
        )
        .then((img) {
          if (!mounted) {
            img?.dispose();
            return;
          }
          if (img != null) {
            final old = _gpuImage;
            setState(() {
              _gpuImage = img;
            });
            old?.dispose();
          }
          _isGpuRendering = false;
          if (_pendingGpuRender && _lastViewportSize != Size.zero) {
            _requestGpuRender(_lastViewportSize);
          }
        })
        .catchError((_) {
          _isGpuRendering = false;
        });
  }

  @override
  void didUpdateWidget(covariant Structural3dViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project ||
        oldWidget.cantileverZones != widget.cantileverZones ||
        oldWidget.verticalReport != widget.verticalReport) {
      _rebuildMesh();
    }
  }

  String _getShadingModeLabel(Cad3DShadingMode mode, AppLocalizations l10n) {
    switch (mode) {
      case Cad3DShadingMode.cadShadedEdges:
        return l10n.shadingShadedEdges;
      case Cad3DShadingMode.smoothShaded:
        return 'Smooth';
      case Cad3DShadingMode.flatShaded:
        return l10n.shadingSolid;
      case Cad3DShadingMode.wireframe:
        return l10n.shadingWireframe;
      case Cad3DShadingMode.xray:
        return 'X-Ray';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onExit,
        ),
        title: Text(
          '${l10n.structural3dTitle} (${_mesh.triangleCount})',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          // GPU Hardware Acceleration Toggle
          IconButton(
            icon: Icon(
              _useGpuAcceleration ? Icons.speed_rounded : Icons.speed_outlined,
              color: _useGpuAcceleration ? const Color(0xFF00E5FF) : Colors.white38,
            ),
            tooltip: _useGpuAcceleration
                ? l10n.gpuAccelerationActive
                : l10n.gpuAccelerationInactive,
            onPressed: () {
              setState(() {
                _useGpuAcceleration = !_useGpuAcceleration;
                if (!_useGpuAcceleration) {
                  _gpuImage?.dispose();
                  _gpuImage = null;
                } else {
                  _gpuRenderer.setMesh(_mesh);
                  if (_lastViewportSize != Size.zero) {
                    _requestGpuRender(_lastViewportSize);
                  }
                }
              });
            },
          ),
          // Shading mode menu
          PopupMenuButton<Cad3DShadingMode>(
            icon: Icon(_shadingMode.icon, color: Colors.white70),
            tooltip: l10n.shadingModeTitle,
            onSelected: (mode) => setState(() {
              _shadingMode = mode;
              if (_useGpuAcceleration && _lastViewportSize != Size.zero) {
                _requestGpuRender(_lastViewportSize);
              }
            }),
            itemBuilder: (ctx) => [
              for (final m in Cad3DShadingMode.values)
                PopupMenuItem(
                  value: m,
                  child: Row(
                    children: [
                      Icon(m.icon, size: 18, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(_getShadingModeLabel(m, l10n)),
                    ],
                  ),
                ),
            ],
          ),
          // Reset Camera
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Colors.white70),
            tooltip: l10n.centerView,
            onPressed: () {
              setState(() {
                _camera.yaw = math.pi / 4;
                _camera.pitch = 0.615;
                _camera.zoom = 1.0;
                _camera.panOffset = Offset.zero;
              });
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _lastViewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (_useGpuAcceleration && _gpuImage == null && !_isGpuRendering) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _requestGpuRender(_lastViewportSize);
            });
          }

          return Stack(
            children: [
              // 3D Canvas with Gestures
              GestureDetector(
                onScaleStart: (details) {
                  _isInteracting = true;
                  _lastPanPos = details.localFocalPoint;
                  _baseZoom = _camera.zoom;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    if (details.pointerCount == 1 && _lastPanPos != null) {
                      // Single finger: orbit rotation
                      final delta = details.localFocalPoint - _lastPanPos!;
                      _camera.yaw += delta.dx * 0.01;
                      _camera.pitch = (_camera.pitch + delta.dy * 0.01)
                          .clamp(-math.pi / 2.1, math.pi / 2.1);
                      _lastPanPos = details.localFocalPoint;
                    } else if (details.pointerCount > 1) {
                      // Multi-touch: zoom & pan
                      _camera.zoom = (_baseZoom * details.scale).clamp(0.2, 10.0);
                      if (_lastPanPos != null) {
                        final delta = details.localFocalPoint - _lastPanPos!;
                        _camera.panOffset += delta;
                        _lastPanPos = details.localFocalPoint;
                      }
                    }
                  });
                  if (_useGpuAcceleration) {
                    _requestGpuRender(_lastViewportSize);
                  }
                },
                onScaleEnd: (_) {
                  setState(() {
                    _isInteracting = false;
                    _lastPanPos = null;
                  });
                  if (_useGpuAcceleration) {
                    _requestGpuRender(_lastViewportSize);
                  }
                },
                child: Listener(
                  onPointerSignal: (signal) {
                    if (signal is PointerScrollEvent) {
                      setState(() {
                        final factor = signal.scrollDelta.dy > 0 ? 0.9 : 1.1;
                        _camera.zoom = (_camera.zoom * factor).clamp(0.2, 10.0);
                      });
                      if (_useGpuAcceleration) {
                        _requestGpuRender(_lastViewportSize);
                      }
                    }
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: Cad3DMeshPainter(
                      mesh: _mesh,
                      camera: _camera,
                      shadingMode: _shadingMode,
                      theme: Cad3DTheme.darkCad,
                      showGrid: true,
                      isInteracting: _isInteracting,
                      gpuImage: _useGpuAcceleration ? _gpuImage : null,
                    ),
                  ),
                ),
              ),

          // Storey Filter Chips (Top Overlay)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(l10n.allStoreys),
                    selected: _highlightStoreyIndex == null,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _highlightStoreyIndex = null;
                          _rebuildMesh();
                        });
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  for (int i = 0; i < widget.project.storeys.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(widget.project.storeys[i].name),
                        selected: _highlightStoreyIndex == i,
                        onSelected: (sel) {
                          setState(() {
                            _highlightStoreyIndex = sel ? i : null;
                            _rebuildMesh();
                          });
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  ),
);
}
}
