import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as gpu;
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_filament_camera.dart';

void main() {
  for (final size in [const Size(1200, 800), const Size(360, 740)]) {
    for (final dimension in [8.0, 25000.0]) {
      for (final preset in Cad3DViewPreset.values) {
        test('GPU projection matches CAD $preset $size, extent $dimension', () {
          final camera = Cad3DCamera()..setPreset(preset);
          camera.zoom = 1.7;
          camera.panOffset = const Offset(37, -21);
          _compare(camera, size, dimension);
          camera.mode = Cad3DInteractionMode.fly;
          camera.eyePosition = Vector3(
            dimension * .1,
            -dimension * .05,
            dimension * .02,
          );
          _compare(camera, size, dimension);
        });
      }
    }
  }
}

void _compare(Cad3DCamera camera, Size size, double dimension) {
  final matrices = Cad3DFilamentCamera(camera, size, dimension);
  final view = gpu.Matrix4.inverted(matrices.model);
  final mvp = matrices.projection * view;
  final modelScale = size.shortestSide * .55 / dimension;
  for (final point in [
    Vector3.zero,
    Vector3(dimension * .2, dimension * .1, -dimension * .15),
  ]) {
    final expected = camera.projectToScreen(
      camera.transformVertex(point),
      size,
      modelScale,
    );
    final clip = mvp.transform(
      gpu.Vector4(
        point.x * 20 / dimension,
        point.y * 20 / dimension,
        point.z * 20 / dimension,
        1,
      ),
    );
    final actual = Offset(
      (clip.x / clip.w + 1) * size.width / 2,
      (1 - clip.y / clip.w) * size.height / 2,
    );
    expect(actual.dx, closeTo(expected.dx, 1e-8));
    expect(actual.dy, closeTo(expected.dy, 1e-8));
    expect(clip.w, greaterThan(0));
  }
}
