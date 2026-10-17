import 'dart:math' as math;
import 'dart:ui';
import 'package:thermion_flutter/thermion_flutter.dart' as v;
import 'cad_3d_camera.dart';

/// Filament camera matrices for the existing Z-up CAD projection. Geometry is
/// centered before upload and normalized to 20 units on its longest side.
class Cad3DFilamentCamera {
  final v.Matrix4 model;
  final v.Matrix4 projection;
  final double near;
  final double far;

  Cad3DFilamentCamera(Cad3DCamera camera, Size viewport, double dimension)
    : model = v.Matrix4.identity(),
      projection = v.Matrix4.zero(),
      near = .05,
      far = 10000 {
    final extent = math.max(dimension, 1e-4);
    final normalization = 20 / extent;
    final scale = math.min(viewport.width, viewport.height) * .55 / extent;
    final distance = camera.cameraDist / scale * normalization;
    final right = camera.rightVector;
    final up = camera.upVector;
    final forward = camera.forwardVector;
    final eye = camera.isFlyMode ? camera.eyePosition * normalization : null;
    model.setColumn(0, v.Vector4(right.x, right.y, right.z, 0));
    model.setColumn(1, v.Vector4(up.x, up.y, up.z, 0));
    model.setColumn(2, v.Vector4(-forward.x, -forward.y, -forward.z, 0));
    model.setColumn(
      3,
      v.Vector4(
        (eye?.x ?? 0) - forward.x * distance,
        (eye?.y ?? 0) - forward.y * distance,
        (eye?.z ?? 0) - forward.z * distance,
        1,
      ),
    );
    final focal = camera.cameraDist * camera.zoom;
    projection.setEntry(0, 0, 2 * focal / viewport.width);
    projection.setEntry(1, 1, 2 * focal / viewport.height);
    projection.setEntry(0, 2, -2 * camera.panOffset.dx / viewport.width);
    projection.setEntry(1, 2, 2 * camera.panOffset.dy / viewport.height);
    projection.setEntry(2, 2, -(far + near) / (far - near));
    projection.setEntry(2, 3, -2 * far * near / (far - near));
    projection.setEntry(3, 2, -1);
  }
}
