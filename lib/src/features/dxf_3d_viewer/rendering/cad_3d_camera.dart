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

/// Primary interaction mode for 3D gestures and mouse dragging.
enum Cad3DInteractionMode {
  orbit('Rotate / Orbit', Icons.threed_rotation_rounded),
  pan('Drag / Pan', Icons.pan_tool_rounded),
  fly('Walk / Fly', Icons.flight_takeoff_rounded);

  final String label;
  final IconData icon;

  const Cad3DInteractionMode(this.label, this.icon);
}

/// 3D Orbit & Fly (Walkthrough) Camera Controller for CAD models.
class Cad3DCamera {
  double yaw; // Azimuth angle (radians)
  double pitch; // Elevation angle (radians)
  double zoom; // Zoom multiplier
  Offset panOffset; // Screen pan translation
  bool invertY; // Invert vertical orbit/look direction (default: true)

  Cad3DInteractionMode mode;
  Vector3 eyePosition; // Camera 3D position in model coordinates (relative to center)

  Cad3DCamera({
    this.yaw = math.pi / 4, // 45°
    this.pitch = 0.6154797, // ~35.264° standard isometric
    this.zoom = 1.0,
    this.panOffset = Offset.zero,
    this.invertY = true,
    this.mode = Cad3DInteractionMode.orbit,
    Vector3? eyePosition,
  }) : eyePosition = eyePosition ?? Vector3.zero;

  bool get isFlyMode => mode == Cad3DInteractionMode.fly;

  /// 3D Forward gaze vector in model coordinates (Z is up, pitch tilts up/down).
  /// When pitch < 0 (looking up), -sin(pitch) > 0, so forward points up in Z.
  /// When pitch > 0 (looking down), -sin(pitch) < 0, so forward points down in Z.
  Vector3 get forwardVector {
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    return Vector3(sinY * cosP, cosY * cosP, -sinP);
  }

  /// 3D Right strafe vector in model coordinates (horizontal, perpendicular to view).
  Vector3 get rightVector {
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    return Vector3(cosY, -sinY, 0.0);
  }

  /// 3D Up vector in model coordinates.
  Vector3 get upVector {
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    return Vector3(sinY * sinP, cosY * sinP, cosP);
  }

  /// Switches to Walkthrough / Fly Mode, initializing eye position seamlessly from current view.
  void switchToFlyMode(double modelScale) {
    if (mode == Cad3DInteractionMode.fly) return;
    mode = Cad3DInteractionMode.fly;

    const cameraDist = 1200.0;
    final effectiveDist = cameraDist / (math.max(modelScale * zoom, 1e-6));
    final fwd = forwardVector;
    final rgt = rightVector;
    final up = upVector;

    final panX = panOffset.dx / (math.max(modelScale * zoom, 1e-6));
    final panY = panOffset.dy / (math.max(modelScale * zoom, 1e-6));

    eyePosition = (fwd * -effectiveDist) - (rgt * panX) + (up * panY);
    panOffset = Offset.zero;
    zoom = 1.0;
  }

  /// Switches back to Orbit mode.
  void switchToOrbitMode() {
    if (mode != Cad3DInteractionMode.fly) return;
    mode = Cad3DInteractionMode.orbit;
    eyePosition = Vector3.zero;
  }

  /// Moves camera in fly mode: forward/backward strictly along gaze vector (ArchiCAD style),
  /// and left/right strafe along horizontal right vector.
  void fly({
    required double forward,
    required double strafe,
    required double speed,
    required double dt,
  }) {
    if (forward == 0.0 && strafe == 0.0) return;
    final fwd = forwardVector;
    final rgt = rightVector;
    final deltaMove = (fwd * forward + rgt * strafe) * (speed * dt);
    eyePosition += deltaMove;
  }

  /// First-person look rotation for right thumb drag.
  void look(double deltaX, double deltaY) {
    yaw += deltaX * 0.005;
    pitch += (invertY ? 1 : -1) * deltaY * 0.005;
    const limit = math.pi * 0.48; // ~86.4 degrees
    pitch = pitch.clamp(-limit, limit);
  }

  void orbit(double deltaX, double deltaY) {
    yaw += deltaX * 0.01;
    pitch += (invertY ? 1 : -1) * deltaY * 0.01;
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
    mode = Cad3DInteractionMode.orbit;
    eyePosition = Vector3.zero;
    setPreset(Cad3DViewPreset.isometric);
    zoom = 1.0;
    panOffset = Offset.zero;
  }

  void setPreset(Cad3DViewPreset preset) {
    mode = Cad3DInteractionMode.orbit;
    eyePosition = Vector3.zero;
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

  /// Transforms a 3D vector centered at origin into view coordinates (pure rotation).
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

  /// Transforms a model-space point (relative to model centroid) into view coordinates,
  /// taking into account the eyePosition if in Fly mode.
  Vector3 transformVertex(Vector3 pLocal) {
    if (isFlyMode) {
      return transformPoint(pLocal - eyePosition);
    }
    return transformPoint(pLocal);
  }

  /// Projects a 3D view-space point to 2D screen coordinates.
  Offset projectToScreen(Vector3 p, Size viewport, double modelScale) {
    final centerX = viewport.width / 2.0 + panOffset.dx;
    final centerY = viewport.height / 2.0 + panOffset.dy;

    // Scale point to screen units so perspective behaves consistently across all CAD model sizes
    final sx = p.x * modelScale;
    final sy = p.y * modelScale;
    final sz = p.z * modelScale;

    const cameraDist = 1200.0;
    final double depth;
    if (isFlyMode) {
      // In fly mode, p is relative to camera eye, so sy is the distance along forward line of sight.
      // Near plane distance minimum in screen units prevents division by zero or negative flip.
      depth = math.max(sy, 10.0);
    } else {
      depth = math.max(cameraDist + sy, 40.0);
    }

    final perspective = cameraDist / depth;
    final scaleFactor = isFlyMode ? perspective : (zoom * perspective);

    final screenX = centerX + sx * scaleFactor;
    final screenY = centerY - sz * scaleFactor;

    return Offset(screenX, screenY);
  }
}

