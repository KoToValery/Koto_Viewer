import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';

class ArchitectSnapResult {
  final Offset point;
  final bool isSnapped;
  final String? snapLabel;
  final double? angleDeg;

  const ArchitectSnapResult({
    required this.point,
    this.isSnapped = false,
    this.snapLabel,
    this.angleDeg,
  });
}

/// CAD snapping engine for architectural drafting: angle locks (0°, 90°, 45°),
/// wall endpoints, and grid axis intersections.
class ArchitectSnapHelper {
  /// Snaps a candidate point [rawPoint] relative to an anchor [anchor] (e.g. wall start point).
  static ArchitectSnapResult snapWithAnchor({
    required Offset anchor,
    required Offset rawPoint,
    required ArchitectProject project,
    double tolerance = 0.20, // in meters
  }) {
    // 1. Point Snap: Check if near existing wall endpoints (highest priority)
    final activeStorey = project.activeStorey;
    for (final wall in activeStorey.walls) {
      if ((rawPoint - wall.startPoint).distance <= tolerance &&
          (wall.startPoint - anchor).distance > 1e-3) {
        return ArchitectSnapResult(
          point: wall.startPoint,
          isSnapped: true,
          snapLabel: 'End',
        );
      }
      if ((rawPoint - wall.endPoint).distance <= tolerance &&
          (wall.endPoint - anchor).distance > 1e-3) {
        return ArchitectSnapResult(
          point: wall.endPoint,
          isSnapped: true,
          snapLabel: 'End',
        );
      }
    }

    // 2. Angle Snap: Snap to 0°, 90°, 180°, 270° (or 45°) relative to anchor
    final delta = rawPoint - anchor;
    final dist = delta.distance;
    if (dist < 1e-3) {
      return ArchitectSnapResult(point: rawPoint);
    }

    double angleRad = math.atan2(delta.dy, delta.dx);
    if (angleRad < 0) angleRad += 2 * math.pi;
    final angleDeg = angleRad * 180.0 / math.pi;

    // Standard orthogonal and diagonal lock targets
    final targets = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0, 360.0];
    const snapBandDeg = 6.0; // Comfort zone for snapping

    for (final target in targets) {
      final diff = (angleDeg - target).abs();
      if (diff <= snapBandDeg) {
        final snappedRad = (target % 360.0) * math.pi / 180.0;
        final snappedPoint = anchor +
            Offset(
              dist * math.cos(snappedRad),
              dist * math.sin(snappedRad),
            );
        final label = (target % 90.0 == 0) ? '${target.round()}°' : '45°';
        return ArchitectSnapResult(
          point: snappedPoint,
          isSnapped: true,
          snapLabel: label,
          angleDeg: target % 360.0,
        );
      }
    }

    return ArchitectSnapResult(point: rawPoint, angleDeg: angleDeg);
  }

  /// Free point snapping to existing vertices when picking a starting point.
  static ArchitectSnapResult snapFree({
    required Offset rawPoint,
    required ArchitectProject project,
    double tolerance = 0.25,
  }) {
    final activeStorey = project.activeStorey;
    for (final wall in activeStorey.walls) {
      if ((rawPoint - wall.startPoint).distance <= tolerance) {
        return ArchitectSnapResult(
          point: wall.startPoint,
          isSnapped: true,
          snapLabel: 'Endpoint',
        );
      }
      if ((rawPoint - wall.endPoint).distance <= tolerance) {
        return ArchitectSnapResult(
          point: wall.endPoint,
          isSnapped: true,
          snapLabel: 'Endpoint',
        );
      }
    }
    return ArchitectSnapResult(point: rawPoint);
  }
}
