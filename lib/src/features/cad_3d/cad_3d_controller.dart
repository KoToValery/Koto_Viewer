import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'models/mesh_3d.dart';
import 'rendering/cad_3d_camera.dart';

/// Navigation shared by BIM editing and imported models. Never edits geometry.
class Cad3DController extends ChangeNotifier {
  final Cad3DCamera camera;
  Size viewport = Size.zero;
  double maxDimension = 1;
  double? unitsPerMeter;
  int revision = 0;

  Cad3DController({Cad3DCamera? camera}) : camera = camera ?? Cad3DCamera();

  Cad3DInteractionMode get mode => camera.mode;
  double get modelScale =>
      math.min(viewport.width, viewport.height) *
      .55 /
      math.max(maxDimension, 1e-4);

  void changed() {
    revision++;
    notifyListeners();
  }

  void setMode(Cad3DInteractionMode mode) {
    if (this.mode == mode) return;
    if (mode == Cad3DInteractionMode.fly) {
      camera.switchToFlyMode(modelScale);
    } else {
      camera.switchToOrbitMode();
      camera.mode = mode;
    }
    changed();
  }

  void reset() {
    camera.reset();
    changed();
  }

  void setPreset(Cad3DViewPreset preset) {
    camera.reset();
    camera.setPreset(preset);
    changed();
  }

  void drag(Offset delta, {bool pan = false}) {
    if (delta == Offset.zero) return;
    if (camera.isFlyMode) {
      camera.look(delta.dx, delta.dy, modelScale);
    } else if (pan || mode == Cad3DInteractionMode.pan) {
      camera.pan(delta);
    } else {
      camera.orbit(delta.dx, delta.dy);
    }
    changed();
  }

  void scale(double zoom, Offset pan) {
    camera.zoom = zoom.clamp(.05, 100);
    camera.pan(pan);
    changed();
  }

  double get _meter {
    if (unitsPerMeter case final units? when units.isFinite && units > 0) {
      return units;
    }
    // Compatibility for imported formats without explicit unit metadata.
    if (maxDimension >= 500) return 1000;
    if (maxDimension >= 3) return 1;
    return math.max(maxDimension / 10, 1e-4);
  }

  void scroll(double delta) {
    if (delta == 0) return;
    if (camera.isFlyMode) {
      camera.fly(
        forward: delta < 0 ? 1 : -1,
        strafe: 0,
        speed: _meter * .4 / math.max(camera.zoom, .5),
        dt: 1,
      );
    } else {
      camera.zoomBy(delta < 0 ? 1.15 : 1 / 1.15);
    }
    changed();
  }

  /// Same analog walk/fly response as the IFC viewer, with explicit BIM units.
  void walk(Offset deflection, double seconds) {
    if (!camera.isFlyMode || deflection == Offset.zero || seconds <= 0) return;
    final magnitude = deflection.distance.clamp(0.0, 1.0);
    if (magnitude < 1e-4) return;
    final meter = _meter;
    final walkSpeed = 1.3 * meter;
    final modelMeters = maxDimension / meter;
    final cruise =
        (7 + math.max(0, modelMeters - 30) * .1).clamp(7, 30) * meter;
    final speed = magnitude <= .5
        ? walkSpeed * math.pow(magnitude / .5, 2)
        : walkSpeed + (cruise - walkSpeed) * math.pow((magnitude - .5) / .5, 2);
    final direction = deflection / deflection.distance;
    camera.fly(
      forward: -direction.dy,
      strafe: direction.dx,
      speed: speed / math.max(camera.zoom, .5),
      dt: seconds.clamp(0.0, .1),
    );
    changed();
  }

  /// Snapshot for asynchronous rendering; later gestures cannot mutate a request.
  Cad3DCamera snapshot() => Cad3DCamera(
    yaw: camera.yaw,
    pitch: camera.pitch,
    zoom: camera.zoom,
    panOffset: camera.panOffset,
    invertY: camera.invertY,
    mode: camera.mode,
    eyePosition: Vector3(
      camera.eyePosition.x,
      camera.eyePosition.y,
      camera.eyePosition.z,
    ),
  );
}
