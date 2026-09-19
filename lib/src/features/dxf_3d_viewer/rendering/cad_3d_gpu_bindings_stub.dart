import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart' show Color;

import '../models/mesh_3d.dart';
import 'cad_3d_camera.dart';

/// Web stub for Cad3DGpuBindings (native GPU FFI is not supported on web).
class Cad3DGpuBindings {
  static final Cad3DGpuBindings instance = Cad3DGpuBindings._();
  Cad3DGpuBindings._();

  bool get isAvailable => false;

  bool init(int width, int height) => false;

  void destroy() {}

  bool uploadMesh({
    required Float32List positions,
    Float32List? normals,
    Float32List? colors,
    Float32List? flags,
    required int vertexCount,
  }) => false;
}

class Cad3DGpuMeshBuffer {
  final Float32List positions;
  final Float32List? normals;
  final Float32List? colors;
  final Float32List? flags;
  final int vertexCount;

  const Cad3DGpuMeshBuffer({
    required this.positions,
    this.normals,
    this.colors,
    this.flags,
    required this.vertexCount,
  });

  static Cad3DGpuMeshBuffer? fromMesh(Mesh3D mesh, {Color? customColor}) => null;

  bool upload() => false;
}

class Cad3DGpuRenderer {
  final Cad3DGpuBindings bindings = Cad3DGpuBindings.instance;

  bool get isReady => false;

  bool setMesh(Mesh3D mesh, {Color? customColor}) => false;

  static Float32List computeMvpMatrix({
    required Cad3DCamera camera,
    required ui.Size viewport,
    required double modelScale,
  }) => Float32List(16);

  static Float32List computeLightParams({
    required Cad3DCamera camera,
    Color? customColor,
  }) => Float32List(12);

  Future<ui.Image?> renderFrame({
    required Cad3DCamera camera,
    required ui.Size viewport,
    required double modelScale,
    Color? customColor,
  }) async => null;

  void dispose() {}
}
