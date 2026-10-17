import 'dart:ui' as ui;
import '../models/mesh_3d.dart';
import 'cad_3d_camera.dart';
import 'cad_3d_gpu_bindings.dart';
import 'cad_3d_mesh_painter.dart';
import 'cad_3d_gpu_platform.dart';

/// Offscreen fallback boundary. Filament uses a persistent texture surface;
/// these image backends remain available when that surface cannot be created.
abstract class Cad3DRenderBackend {
  static bool get acceleratedAvailable =>
      cad3dTextureSupported || Cad3DNativeDepthBackend.available;
  bool get isAvailable;
  bool supports(Cad3DShadingMode mode);
  bool setMesh(Mesh3D mesh, {ui.Color? color});
  Future<ui.Image?> render({
    required Cad3DCamera camera,
    required ui.Size viewport,
    required double modelScale,
    double pixelRatio = 1,
  });
  void dispose();
}

class Cad3DNativeDepthBackend implements Cad3DRenderBackend {
  final Cad3DGpuRenderer _renderer = Cad3DGpuRenderer();

  static bool get available => Cad3DGpuBindings.instance.isAvailable;
  @override
  bool get isAvailable => available;
  @override
  bool supports(Cad3DShadingMode mode) =>
      mode == Cad3DShadingMode.smoothShaded ||
      mode == Cad3DShadingMode.flatShaded;
  @override
  bool setMesh(Mesh3D mesh, {ui.Color? color}) =>
      _renderer.setMesh(mesh, customColor: color);
  @override
  Future<ui.Image?> render({
    required Cad3DCamera camera,
    required ui.Size viewport,
    required double modelScale,
    double pixelRatio = 1,
  }) => _renderer.renderFrame(
    camera: camera,
    viewport: viewport,
    modelScale: modelScale,
    pixelRatio: pixelRatio,
  );
  @override
  void dispose() => _renderer.dispose();
}
