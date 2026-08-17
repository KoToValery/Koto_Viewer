import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/mesh_3d.dart';

/// 3D Camera Preset Viewpoints.
enum Cad3DViewPreset {
  isometric('Isometric', Icons.view_in_ar_rounded),
  top('Top View', Icons.keyboard_arrow_up_rounded),
  front('Front View', Icons.crop_square_rounded),
  right('Right View', Icons.keyboard_arrow_right_rounded),
  bottom('Bottom View', Icons.keyboard_arrow_down_rounded),
  back('Back View', Icons.flip_to_back_rounded);

  final String label;
  final IconData icon;

  const Cad3DViewPreset(this.label, this.icon);
}

/// 3D Orbit Camera Controller for CAD models.
class Cad3DCamera {
  double yaw; // Azimuth angle (radians)
  double pitch; // Elevation angle (radians)
  double zoom; // Zoom multiplier
  Offset panOffset; // Screen pan translation

  Cad3DCamera({
    this.yaw = math.pi / 4, // 45°
    this.pitch = 0.6154797, // ~35.264° standard isometric
    this.zoom = 1.0,
    this.panOffset = Offset.zero,
  });

  void orbit(double deltaX, double deltaY) {
    yaw += deltaX * 0.01;
    pitch -= deltaY * 0.01;
    // Clamp pitch to avoid gimbal flip
    const limit = math.pi / 2 - 0.01;
    pitch = pitch.clamp(-limit, limit);
  }

  void pan(Offset delta) {
    panOffset += delta;
  }

  void zoomBy(double factor) {
    zoom = (zoom * factor).clamp(0.05, 100.0);
  }

  void reset() {
    setPreset(Cad3DViewPreset.isometric);
    zoom = 1.0;
    panOffset = Offset.zero;
  }

  void setPreset(Cad3DViewPreset preset) {
    switch (preset) {
      case Cad3DViewPreset.isometric:
        yaw = math.pi / 4;
        pitch = 0.6154797;
        break;
      case Cad3DViewPreset.top:
        yaw = 0.0;
        pitch = math.pi / 2 - 0.001;
        break;
      case Cad3DViewPreset.front:
        yaw = 0.0;
        pitch = 0.0;
        break;
      case Cad3DViewPreset.right:
        yaw = math.pi / 2;
        pitch = 0.0;
        break;
      case Cad3DViewPreset.bottom:
        yaw = 0.0;
        pitch = -math.pi / 2 + 0.001;
        break;
      case Cad3DViewPreset.back:
        yaw = math.pi;
        pitch = 0.0;
        break;
    }
  }

  /// Transforms a 3D point centered at model origin into view coordinates
  Vector3 transformPoint(Vector3 p) {
    // 1. Rotation by Yaw around Z/Y axis
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final x1 = p.x * cosY - p.y * sinY;
    final y1 = p.x * sinY + p.y * cosY;
    final z1 = p.z;

    // 2. Rotation by Pitch around X axis
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    final x2 = x1;
    final y2 = y1 * cosP - z1 * sinP;
    final z2 = y1 * sinP + z1 * cosP;

    return Vector3(x2, y2, z2);
  }

  /// Projects a 3D view-space point to 2D screen coordinates
  Offset projectToScreen(Vector3 p, Size viewport, double modelScale) {
    final centerX = viewport.width / 2.0 + panOffset.dx;
    final centerY = viewport.height / 2.0 + panOffset.dy;

    // Perspective projection depth factor
    const cameraDist = 800.0;
    final scaleFactor = (modelScale * zoom) * (cameraDist / (cameraDist + p.y));

    final screenX = centerX + p.x * scaleFactor;
    final screenY = centerY - p.z * scaleFactor;

    return Offset(screenX, screenY);
  }
}
