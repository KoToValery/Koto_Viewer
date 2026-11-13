import 'dart:math' as math;
import 'dart:ui';

import '../models/architect_elements.dart';

/// Three picks: centre, first semi-axis, perpendicular second semi-axis.
/// A review candidate never mutates the document.
class ArchitectEllipseDraft {
  Offset? center, axisEnd, cursor;
  double? _radiusY;
  bool ready = false;

  double get radiusX => center == null
      ? 0
      : ((axisEnd ?? cursor ?? center ?? Offset.zero) - (center ?? Offset.zero))
            .distance;
  Offset get direction => radiusX > 1e-9
      ? ((axisEnd ?? cursor)! - center!) / radiusX
      : const Offset(1, 0);
  double get radiusY {
    if (_radiusY != null) return _radiusY!;
    if (center == null || axisEnd == null || cursor == null) return 0;
    final d = cursor! - center!, u = direction;
    return (d.dx * -u.dy + d.dy * u.dx).abs();
  }

  void aim(Offset point) {
    if (!ready && point.dx.isFinite && point.dy.isFinite) cursor = point;
  }

  /// Returns true once all three valid picks are available for exact review.
  bool pick(Offset point) {
    if (!point.dx.isFinite || !point.dy.isFinite || ready) return ready;
    if (center == null) {
      center = cursor = point;
    } else if (axisEnd == null) {
      if ((point - center!).distance >= .001) axisEnd = cursor = point;
    } else {
      cursor = point;
      if (radiusY >= .001) {
        _radiusY = radiusY;
        ready = true;
      }
    }
    return ready;
  }

  void setRadius(int index, double meters) {
    if (!ready || !meters.isFinite || meters < .001) return;
    if (index == 0) {
      axisEnd = center! + direction * meters;
    } else {
      _radiusY = meters;
    }
  }

  ArchitectCadPrimitive? get preview {
    if (center == null || axisEnd == null || radiusY < .001) return null;
    return ArchitectCadPrimitive(
      id: 'ellipse-preview',
      type: CadPrimitiveType.ellipse,
      startPoint: center!,
      endPoint: axisEnd!,
      radiusX: radiusX,
      radiusY: radiusY,
      rotationDeg: math.atan2(direction.dy, direction.dx) * 180 / math.pi,
    );
  }

  void cancel() {
    center = axisEnd = cursor = null;
    _radiusY = null;
    ready = false;
  }
}
