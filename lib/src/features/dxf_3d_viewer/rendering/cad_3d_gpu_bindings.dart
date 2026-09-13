// ignore_for_file: always_specify_types, camel_case_types
// ignore_for_file: directives_ordering, non_constant_identifier_names

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

import '../models/mesh_3d.dart';
import 'cad_3d_camera.dart';

// ---------------------------------------------------------------------------
// Native Function Typedefs
// ---------------------------------------------------------------------------

typedef _Cad3DGpuIsAvailableNative = Int32 Function();
typedef _Cad3DGpuIsAvailableDart = int Function();

typedef _Cad3DGpuInitNative = Int32 Function(Int32 width, Int32 height);
typedef _Cad3DGpuInitDart = int Function(int width, int height);

typedef _Cad3DGpuDestroyNative = Void Function();
typedef _Cad3DGpuDestroyDart = void Function();

typedef _Cad3DGpuUploadMeshNative = Int32 Function(
  Pointer<Float> positions,
  Pointer<Float> normals,
  Pointer<Float> colors,
  Pointer<Float> flags,
  Int32 vertexCount,
);
typedef _Cad3DGpuUploadMeshDart = int Function(
  Pointer<Float> positions,
  Pointer<Float> normals,
  Pointer<Float> colors,
  Pointer<Float> flags,
  int vertexCount,
);

typedef _Cad3DGpuRenderNative = Int32 Function(
  Pointer<Float> mvpMatrix,
  Pointer<Float> lightParams,
  Pointer<Uint8> outRgbaPixels,
  Int32 width,
  Int32 height,
);
typedef _Cad3DGpuRenderDart = int Function(
  Pointer<Float> mvpMatrix,
  Pointer<Float> lightParams,
  Pointer<Uint8> outRgbaPixels,
  int width,
  int height,
);

// ---------------------------------------------------------------------------
// Cad3DGpuBindings: Low-level Dynamic Library Wrapper
// ---------------------------------------------------------------------------

class Cad3DGpuBindings {
  static final Cad3DGpuBindings instance = Cad3DGpuBindings._();

  DynamicLibrary? _lib;
  bool _initialized = false;
  bool _available = false;

  _Cad3DGpuIsAvailableDart? _isAvailableFunc;
  _Cad3DGpuInitDart? _initFunc;
  _Cad3DGpuDestroyDart? _destroyFunc;
  _Cad3DGpuUploadMeshDart? _uploadMeshFunc;
  _Cad3DGpuRenderDart? _renderFunc;

  Cad3DGpuBindings._();

  void _loadLibrary() {
    if (_initialized) return;
    _initialized = true;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libkotoview_3d_gpu.so');
      } else if (Platform.isWindows) {
        try {
          _lib = DynamicLibrary.open('kotoview_3d_gpu.dll');
        } on ArgumentError catch (_) {
          final candidates = [
            'build\\windows\\x64\\runner\\Debug\\kotoview_3d_gpu.dll',
            'build\\windows\\x64\\runner\\Release\\kotoview_3d_gpu.dll',
            'build\\windows\\x64\\Debug\\kotoview_3d_gpu.dll',
            'build\\windows\\x64\\Release\\kotoview_3d_gpu.dll',
          ];
          for (final path in candidates) {
            if (File(path).existsSync()) {
              try {
                _lib = DynamicLibrary.open(path);
                break;
              } catch (_) {}
            }
          }
        }
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libkotoview_3d_gpu.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libkotoview_3d_gpu.dylib');
      }

      if (_lib != null) {
        _isAvailableFunc = _lib!.lookupFunction<_Cad3DGpuIsAvailableNative, _Cad3DGpuIsAvailableDart>(
          'cad_3d_gpu_is_available',
        );
        _initFunc = _lib!.lookupFunction<_Cad3DGpuInitNative, _Cad3DGpuInitDart>(
          'cad_3d_gpu_init',
        );
        _destroyFunc = _lib!.lookupFunction<_Cad3DGpuDestroyNative, _Cad3DGpuDestroyDart>(
          'cad_3d_gpu_destroy',
        );
        _uploadMeshFunc = _lib!.lookupFunction<_Cad3DGpuUploadMeshNative, _Cad3DGpuUploadMeshDart>(
          'cad_3d_gpu_upload_mesh',
        );
        _renderFunc = _lib!.lookupFunction<_Cad3DGpuRenderNative, _Cad3DGpuRenderDart>(
          'cad_3d_gpu_render',
        );

        _available = (_isAvailableFunc != null && _isAvailableFunc!() == 1);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cad3DGpuBindings: native library load note: $e');
      }
      _available = false;
    }
  }

  /// True if native GPU acceleration library is loaded and operational.
  bool get isAvailable {
    _loadLibrary();
    return _available;
  }

  /// Initializes GPU viewport / depth buffer dimensions.
  bool init(int width, int height) {
    if (!isAvailable || _initFunc == null) return false;
    return _initFunc!(width, height) == 1;
  }

  /// Releases GPU resources.
  void destroy() {
    if (!isAvailable || _destroyFunc == null) return;
    _destroyFunc!();
  }

  /// Uploads triangle mesh data to the native GPU buffer.
  bool uploadMesh({
    required Float32List positions,
    Float32List? normals,
    Float32List? colors,
    Float32List? flags,
    required int vertexCount,
  }) {
    if (!isAvailable || _uploadMeshFunc == null || vertexCount <= 0) return false;

    final posPtr = calloc<Float>(positions.length);
    posPtr.asTypedList(positions.length).setAll(0, positions);

    Pointer<Float>? normPtr;
    if (normals != null) {
      normPtr = calloc<Float>(normals.length);
      normPtr.asTypedList(normals.length).setAll(0, normals);
    }

    Pointer<Float>? colPtr;
    if (colors != null) {
      colPtr = calloc<Float>(colors.length);
      colPtr.asTypedList(colors.length).setAll(0, colors);
    }

    Pointer<Float>? flagPtr;
    if (flags != null) {
      flagPtr = calloc<Float>(flags.length);
      flagPtr.asTypedList(flags.length).setAll(0, flags);
    }

    try {
      final res = _uploadMeshFunc!(
        posPtr,
        normPtr ?? nullptr,
        colPtr ?? nullptr,
        flagPtr ?? nullptr,
        vertexCount,
      );
      return res == 1;
    } finally {
      calloc.free(posPtr);
      if (normPtr != null) calloc.free(normPtr);
      if (colPtr != null) calloc.free(colPtr);
      if (flagPtr != null) calloc.free(flagPtr);
    }
  }

  /// Renders current GPU mesh into [outPixels] with hardware Z-buffering.
  bool render({
    required Float32List mvpMatrix,
    required Float32List lightParams,
    required Pointer<Uint8> outPixels,
    required int width,
    required int height,
  }) {
    if (!isAvailable || _renderFunc == null) return false;

    final mvpPtr = calloc<Float>(16);
    mvpPtr.asTypedList(16).setAll(0, mvpMatrix);

    final lightPtr = calloc<Float>(16);
    lightPtr.asTypedList(16).setAll(0, lightParams);

    try {
      final res = _renderFunc!(mvpPtr, lightPtr, outPixels, width, height);
      return res == 1;
    } finally {
      calloc.free(mvpPtr);
      calloc.free(lightPtr);
    }
  }
}

// ---------------------------------------------------------------------------
// Cad3DGpuMeshBuffer: Prepares and packs contiguous vertex data for GPU
// ---------------------------------------------------------------------------

class Cad3DGpuMeshBuffer {
  final Float32List positions;
  final Float32List normals;
  final Float32List colors;
  final Float32List flags;
  final int vertexCount;

  Cad3DGpuMeshBuffer({
    required this.positions,
    required this.normals,
    required this.colors,
    required this.flags,
    required this.vertexCount,
  });

  /// Factory to extract and pack contiguous vertex arrays from [Mesh3D].
  static Cad3DGpuMeshBuffer fromMesh(Mesh3D mesh, {Color? customColor}) {
    final triangles = mesh.triangles;
    final int triCount = triangles.length;
    final int vCount = triCount * 3;

    final positions = Float32List(vCount * 3);
    final normals = Float32List(vCount * 3);
    final colors = Float32List(vCount * 4);
    final flags = Float32List(vCount * 4);

    final center = mesh.bounds.center;

    for (int t = 0; t < triCount; t++) {
      final tri = triangles[t];
      final int vBase = t * 3;

      // Vertices offset by model center
      final v0 = tri.v0 - center;
      final v1 = tri.v1 - center;
      final v2 = tri.v2 - center;

      final int pIdx = vBase * 3;
      positions[pIdx + 0] = v0.x;
      positions[pIdx + 1] = v0.y;
      positions[pIdx + 2] = v0.z;

      positions[pIdx + 3] = v1.x;
      positions[pIdx + 4] = v1.y;
      positions[pIdx + 5] = v1.z;

      positions[pIdx + 6] = v2.x;
      positions[pIdx + 7] = v2.y;
      positions[pIdx + 8] = v2.z;

      // Normal
      final norm = tri.normal;
      for (int i = 0; i < 3; i++) {
        final int nIdx = (vBase + i) * 3;
        normals[nIdx + 0] = norm.x;
        normals[nIdx + 1] = norm.y;
        normals[nIdx + 2] = norm.z;
      }

      // Color
      final c = customColor ?? tri.color ?? const Color(0xFFD9D9D9);
      final r = c.r;
      final g = c.g;
      final b = c.b;
      final a = c.a;

      for (int i = 0; i < 3; i++) {
        final int cIdx = (vBase + i) * 4;
        colors[cIdx + 0] = r;
        colors[cIdx + 1] = g;
        colors[cIdx + 2] = b;
        colors[cIdx + 3] = a;
      }

      // Flags: [depthBias, isTransparent, isDoubleSided, reserved]
      final double depthBias = tri.depthBias;
      final double isTrans = (a < 0.99) ? 1.0 : 0.0;
      final double isDouble = tri.isDoubleSided ? 1.0 : 0.0;

      for (int i = 0; i < 3; i++) {
        final int fIdx = (vBase + i) * 4;
        flags[fIdx + 0] = depthBias;
        flags[fIdx + 1] = isTrans;
        flags[fIdx + 2] = isDouble;
        flags[fIdx + 3] = 0.0;
      }
    }

    return Cad3DGpuMeshBuffer(
      positions: positions,
      normals: normals,
      colors: colors,
      flags: flags,
      vertexCount: vCount,
    );
  }

  /// Uploads this buffer to native GPU memory.
  bool upload() {
    return Cad3DGpuBindings.instance.uploadMesh(
      positions: positions,
      normals: normals,
      colors: colors,
      flags: flags,
      vertexCount: vertexCount,
    );
  }
}

// ---------------------------------------------------------------------------
// Cad3DGpuRenderer: Controller for Matrix Projection and Frame Generation
// ---------------------------------------------------------------------------

class Cad3DGpuRenderer {
  final Cad3DGpuBindings bindings = Cad3DGpuBindings.instance;

  Cad3DGpuMeshBuffer? _currentMesh;
  int _lastWidth = 0;
  int _lastHeight = 0;

  bool get isReady => bindings.isAvailable && _currentMesh != null;

  /// Loads and uploads [mesh] to GPU.
  bool setMesh(Mesh3D mesh, {Color? customColor}) {
    if (!bindings.isAvailable) return false;
    _currentMesh = Cad3DGpuMeshBuffer.fromMesh(mesh, customColor: customColor);
    return _currentMesh!.upload();
  }

  /// Computes the 16-element column-major MVP Matrix matching Cad3DCamera.
  static Float32List computeMvpMatrix({
    required Cad3DCamera camera,
    required ui.Size viewport,
    required double modelScale,
  }) {
    final cosY = math.cos(camera.yaw);
    final sinY = math.sin(camera.yaw);
    final cosP = math.cos(camera.pitch);
    final sinP = math.sin(camera.pitch);

    // 3x3 Rotation matrix (Yaw then Pitch)
    final rxx = cosY;
    final rxy = -sinY;
    const rxz = 0.0;

    final ryx = sinY * cosP;
    final ryy = cosY * cosP;
    final ryz = -sinP;

    final rzx = sinY * sinP;
    final rzy = cosY * sinP;
    final rzz = cosP;

    final w = viewport.width;
    final h = viewport.height;
    final z = camera.zoom;
    final panX = camera.panOffset.dx;
    final panY = camera.panOffset.dy;

    // Viewport and perspective projection parameters
    final p00 = (2400.0 * z * modelScale) / w;
    final p01 = (2.0 * panX * modelScale) / w;
    final p03 = (2400.0 * panX) / w;

    final p11 = (-2.0 * panY * modelScale) / h;
    final p12 = (2400.0 * z * modelScale) / h;
    final p13 = (-2400.0 * panY) / h;

    const nearZ = 10.0;
    const farZ = 10000.0;
    const a = (farZ + nearZ) / (farZ - nearZ);
    const b = (-2.0 * farZ * nearZ) / (farZ - nearZ);

    const p21 = a * 1.0; // scale factor applied per element
    final p23 = 1200.0 * a + b;

    final p31 = modelScale;
    const p33 = 1200.0;

    // Combine M_proj * M_rot into column-major 4x4 matrix
    final m = Float32List(16);

    // Column 0
    m[0] = p00 * rxx + p01 * ryx;
    m[1] = p11 * ryx + p12 * rzx;
    m[2] = p21 * modelScale * ryx;
    m[3] = p31 * ryx;

    // Column 1
    m[4] = p00 * rxy + p01 * ryy;
    m[5] = p11 * ryy + p12 * rzy;
    m[6] = p21 * modelScale * ryy;
    m[7] = p31 * ryy;

    // Column 2
    m[8] = p00 * rxz + p01 * ryz;
    m[9] = p11 * ryz + p12 * rzz;
    m[10] = p21 * modelScale * ryz;
    m[11] = p31 * ryz;

    // Column 3
    m[12] = p03;
    m[13] = p13;
    m[14] = p23;
    m[15] = p33;

    return m;
  }

  /// Prepares 16 lighting parameters including 3x3 view rotation submatrix.
  static Float32List computeLightParams({
    required Cad3DCamera camera,
    Color? customColor,
  }) {
    final cosY = math.cos(camera.yaw);
    final sinY = math.sin(camera.yaw);
    final cosP = math.cos(camera.pitch);
    final sinP = math.sin(camera.pitch);

    final params = Float32List(16);
    // 0..8: 3x3 rotation matrix for normal rotation
    params[0] = cosY;
    params[1] = -sinY;
    params[2] = 0.0;

    params[3] = sinY * cosP;
    params[4] = cosY * cosP;
    params[5] = -sinP;

    params[6] = sinY * sinP;
    params[7] = cosY * sinP;
    params[8] = cosP;

    // 9..11: Lighting intensities
    params[9] = 0.25;  // Ambient
    params[10] = 0.55; // Key light
    params[11] = 0.25; // Fill light

    // 12..15: Custom color override (or -1.0 if using per-vertex colors)
    if (customColor != null) {
      params[12] = customColor.r;
      params[13] = customColor.g;
      params[14] = customColor.b;
      params[15] = customColor.a;
    } else {
      params[12] = -1.0;
      params[13] = -1.0;
      params[14] = -1.0;
      params[15] = -1.0;
    }

    return params;
  }

  /// Renders a single frame into a [ui.Image] using the native GPU depth-buffer.
  Future<ui.Image?> renderFrame({
    required Cad3DCamera camera,
    required ui.Size viewport,
    required double modelScale,
    Color? customColor,
  }) async {
    if (!isReady || viewport.width <= 0 || viewport.height <= 0) return null;

    final width = viewport.width.round();
    final height = viewport.height.round();

    if (_lastWidth != width || _lastHeight != height) {
      if (!bindings.init(width, height)) return null;
      _lastWidth = width;
      _lastHeight = height;
    }

    final mvpMatrix = computeMvpMatrix(
      camera: camera,
      viewport: viewport,
      modelScale: modelScale,
    );

    final lightParams = computeLightParams(
      camera: camera,
      customColor: customColor,
    );

    final int byteLength = width * height * 4;
    final outPixelsPtr = calloc<Uint8>(byteLength);

    try {
      final success = bindings.render(
        mvpMatrix: mvpMatrix,
        lightParams: lightParams,
        outPixels: outPixelsPtr,
        width: width,
        height: height,
      );

      if (!success) return null;

      final pixelBytes = Uint8List.fromList(outPixelsPtr.asTypedList(byteLength));

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixelBytes,
        width,
        height,
        ui.PixelFormat.rgba8888,
        (img) => completer.complete(img),
      );

      return await completer.future;
    } catch (e) {
      if (kDebugMode) {
        print('Cad3DGpuRenderer: renderFrame error: $e');
      }
      return null;
    } finally {
      calloc.free(outPixelsPtr);
    }
  }

  void dispose() {
    bindings.destroy();
    _currentMesh = null;
  }
}
