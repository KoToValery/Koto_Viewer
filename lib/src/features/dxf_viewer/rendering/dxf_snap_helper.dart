import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dxf_models.dart';
import 'dxf_math.dart';

/// Snap point type for CAD snapping.
enum DxfSnapType {
  endpoint(label: 'Endpoint'),
  midpoint(label: 'Midpoint'),
  center(label: 'Center'),
  nearest(label: 'Nearest'),
  perpendicular(label: 'Perpendicular'),
  point(label: 'Point');

  final String label;
  const DxfSnapType({required this.label});
}

/// Result of a CAD snap query.
class DxfSnapResult {
  final Offset point;
  final DxfSnapType type;
  final double distance;

  const DxfSnapResult({
    required this.point,
    required this.type,
    required this.distance,
  });
}

/// High-performance spatial helper to snap CAD cursor to geometric vertices,
/// landmarks, right-angle perpendicular points, and arbitrary points on line segments and curves (Nearest snap).
class DxfSnapHelper {
  const DxfSnapHelper._();

  /// Calculates the closest point on segment AB from query point P.
  static Offset closestPointOnSegment(Offset p, Offset a, Offset b) {
    final double abX = b.dx - a.dx;
    final double abY = b.dy - a.dy;
    final double lenSq = abX * abX + abY * abY;
    if (lenSq < 1e-12) return a;

    final double apX = p.dx - a.dx;
    final double apY = p.dy - a.dy;
    final double t = (apX * abX + apY * abY) / lenSq;
    final double clampedT = t.clamp(0.0, 1.0);
    return Offset(a.dx + clampedT * abX, a.dy + clampedT * abY);
  }

  /// Calculates the closest point on a circle circumference from query point P.
  static Offset closestPointOnCircle(Offset p, Offset center, double radius) {
    final double dx = p.dx - center.dx;
    final double dy = p.dy - center.dy;
    final double dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1e-12) {
      return Offset(center.dx + radius, center.dy);
    }
    return Offset(center.dx + radius * (dx / dist), center.dy + radius * (dy / dist));
  }

  /// Calculates the closest point on a circular arc curve from query point P.
  static Offset closestPointOnArc(
    Offset p,
    Offset center,
    double radius,
    double startAngleDeg,
    double endAngleDeg,
  ) {
    final double dx = p.dx - center.dx;
    final double dy = p.dy - center.dy;
    final double dist = math.sqrt(dx * dx + dy * dy);

    final double radStart = startAngleDeg * math.pi / 180.0;
    final double radEnd = endAngleDeg * math.pi / 180.0;
    final Offset pStart = Offset(
      center.dx + radius * math.cos(radStart),
      center.dy + radius * math.sin(radStart),
    );
    final Offset pEnd = Offset(
      center.dx + radius * math.cos(radEnd),
      center.dy + radius * math.sin(radEnd),
    );

    if (dist < 1e-12) {
      return pStart;
    }

    double angleDeg = math.atan2(dy, dx) * 180.0 / math.pi;
    if (angleDeg < 0) angleDeg += 360.0;

    double normStart = startAngleDeg % 360.0;
    if (normStart < 0) normStart += 360.0;
    double normEnd = endAngleDeg % 360.0;
    if (normEnd < 0) normEnd += 360.0;

    double sweep = normEnd - normStart;
    if (sweep <= 0) sweep += 360.0;

    double diff = angleDeg - normStart;
    if (diff < 0) diff += 360.0;

    if (diff <= sweep) {
      // Point falls on the arc curve
      return Offset(
        center.dx + radius * (dx / dist),
        center.dy + radius * (dy / dist),
      );
    }

    // Closest endpoint
    final double dStartSq = (p.dx - pStart.dx) * (p.dx - pStart.dx) +
        (p.dy - pStart.dy) * (p.dy - pStart.dy);
    final double dEndSq = (p.dx - pEnd.dx) * (p.dx - pEnd.dx) +
        (p.dy - pEnd.dy) * (p.dy - pEnd.dy);

    return dStartSq <= dEndSq ? pStart : pEnd;
  }

  /// Searches for the closest CAD vertex/landmark, perpendicular right-angle point, or arbitrary point on an edge/segment
  /// within [toleranceCad] distance of [cadPoint].
  ///
  /// When [basePoint] is provided (e.g. 1st measurement point P1), it searches for right-angle perpendicular
  /// projection points (90° / прав ъгъл) onto all visible segments and curves.
  static DxfSnapResult? findSnapPoint({
    required DxfDocument document,
    required Offset cadPoint,
    required double toleranceCad,
    Offset? basePoint,
  }) {
    if (toleranceCad <= 0) return null;

    final double maxDistSq = toleranceCad * toleranceCad;

    DxfSnapResult? bestLandmarkSnap;
    double minLandmarkDistSq = maxDistSq;

    DxfSnapResult? bestPerpendicularSnap;
    double minPerpDistSq = maxDistSq;

    DxfSnapResult? bestNearestSnap;
    double minNearestDistSq = maxDistSq;

    void testLandmark(Offset p, DxfSnapType type) {
      final dx = p.dx - cadPoint.dx;
      final dy = p.dy - cadPoint.dy;
      final distSq = dx * dx + dy * dy;

      if (distSq <= minLandmarkDistSq) {
        minLandmarkDistSq = distSq;
        bestLandmarkSnap = DxfSnapResult(
          point: p,
          type: type,
          distance: math.sqrt(distSq),
        );
      }
    }

    void testPerpendicularPoint(Offset p) {
      final dx = p.dx - cadPoint.dx;
      final dy = p.dy - cadPoint.dy;
      final distSq = dx * dx + dy * dy;

      if (distSq <= minPerpDistSq) {
        minPerpDistSq = distSq;
        bestPerpendicularSnap = DxfSnapResult(
          point: p,
          type: DxfSnapType.perpendicular,
          distance: math.sqrt(distSq),
        );
      }
    }

    void testSegment(Offset a, Offset b) {
      final pClosest = closestPointOnSegment(cadPoint, a, b);
      final dx = pClosest.dx - cadPoint.dx;
      final dy = pClosest.dy - cadPoint.dy;
      final distSq = dx * dx + dy * dy;

      if (distSq <= minNearestDistSq) {
        minNearestDistSq = distSq;
        bestNearestSnap = DxfSnapResult(
          point: pClosest,
          type: DxfSnapType.nearest,
          distance: math.sqrt(distSq),
        );
      }

      // Check perpendicular foot from basePoint if available
      if (basePoint != null) {
        final double abX = b.dx - a.dx;
        final double abY = b.dy - a.dy;
        final double lenSq = abX * abX + abY * abY;
        if (lenSq > 1e-12) {
          final double uX = basePoint.dx - a.dx;
          final double uY = basePoint.dy - a.dy;
          final double t = (uX * abX + uY * abY) / lenSq;
          if (t >= 0.0 && t <= 1.0) {
            final perpPt = Offset(a.dx + t * abX, a.dy + t * abY);
            if ((perpPt - basePoint).distanceSquared > 1e-6) {
              testPerpendicularPoint(perpPt);
            }
          }
        }
      }
    }

    void testCircleCurve(Offset center, double radius) {
      final pClosest = closestPointOnCircle(cadPoint, center, radius);
      final dx = pClosest.dx - cadPoint.dx;
      final dy = pClosest.dy - cadPoint.dy;
      final distSq = dx * dx + dy * dy;

      if (distSq <= minNearestDistSq) {
        minNearestDistSq = distSq;
        bestNearestSnap = DxfSnapResult(
          point: pClosest,
          type: DxfSnapType.nearest,
          distance: math.sqrt(distSq),
        );
      }

      if (basePoint != null) {
        final double bdx = basePoint.dx - center.dx;
        final double bdy = basePoint.dy - center.dy;
        final double bdist = math.sqrt(bdx * bdx + bdy * bdy);
        if (bdist > 1e-6) {
          final p1 = Offset(center.dx + radius * (bdx / bdist), center.dy + radius * (bdy / bdist));
          final p2 = Offset(center.dx - radius * (bdx / bdist), center.dy - radius * (bdy / bdist));
          testPerpendicularPoint(p1);
          testPerpendicularPoint(p2);
        }
      }
    }

    void testArcCurve(Offset center, double radius, double startAngleDeg, double endAngleDeg) {
      final pClosest = closestPointOnArc(cadPoint, center, radius, startAngleDeg, endAngleDeg);
      final dx = pClosest.dx - cadPoint.dx;
      final dy = pClosest.dy - cadPoint.dy;
      final distSq = dx * dx + dy * dy;

      if (distSq <= minNearestDistSq) {
        minNearestDistSq = distSq;
        bestNearestSnap = DxfSnapResult(
          point: pClosest,
          type: DxfSnapType.nearest,
          distance: math.sqrt(distSq),
        );
      }

      if (basePoint != null) {
        final double bdx = basePoint.dx - center.dx;
        final double bdy = basePoint.dy - center.dy;
        final double bdist = math.sqrt(bdx * bdx + bdy * bdy);
        if (bdist > 1e-6) {
          void checkAngleAndTest(Offset p) {
            double angleDeg = math.atan2(p.dy - center.dy, p.dx - center.dx) * 180.0 / math.pi;
            if (angleDeg < 0) angleDeg += 360.0;
            double normStart = startAngleDeg % 360.0;
            if (normStart < 0) normStart += 360.0;
            double normEnd = endAngleDeg % 360.0;
            if (normEnd < 0) normEnd += 360.0;
            double sweep = normEnd - normStart;
            if (sweep <= 0) sweep += 360.0;
            double diff = angleDeg - normStart;
            if (diff < 0) diff += 360.0;
            if (diff <= sweep) {
              testPerpendicularPoint(p);
            }
          }

          checkAngleAndTest(Offset(center.dx + radius * (bdx / bdist), center.dy + radius * (bdy / bdist)));
          checkAngleAndTest(Offset(center.dx - radius * (bdx / bdist), center.dy - radius * (bdy / bdist)));
        }
      }
    }

    // Iterate through all visible entities
    for (final entity in document.entities) {
      final layer = document.layers[entity.layer];
      if (layer != null && !layer.isVisible) continue;

      if (entity is DxfLine) {
        testLandmark(entity.p1, DxfSnapType.endpoint);
        testLandmark(entity.p2, DxfSnapType.endpoint);
        testLandmark(
          Offset((entity.p1.dx + entity.p2.dx) / 2, (entity.p1.dy + entity.p2.dy) / 2),
          DxfSnapType.midpoint,
        );
        testSegment(entity.p1, entity.p2);
      } else if (entity is DxfPoint) {
        testLandmark(entity.point, DxfSnapType.point);
      } else if (entity is DxfCircle) {
        testLandmark(entity.center, DxfSnapType.center);
        testCircleCurve(entity.center, entity.radius);
      } else if (entity is DxfArc) {
        testLandmark(entity.center, DxfSnapType.center);
        final rad1 = entity.startAngleDeg * math.pi / 180.0;
        final rad2 = entity.endAngleDeg * math.pi / 180.0;
        final pStart = Offset(
          entity.center.dx + entity.radius * math.cos(rad1),
          entity.center.dy + entity.radius * math.sin(rad1),
        );
        final pEnd = Offset(
          entity.center.dx + entity.radius * math.cos(rad2),
          entity.center.dy + entity.radius * math.sin(rad2),
        );
        testLandmark(pStart, DxfSnapType.endpoint);
        testLandmark(pEnd, DxfSnapType.endpoint);

        double sweep = entity.endAngleDeg - entity.startAngleDeg;
        if (sweep <= 0) sweep += 360.0;
        final midAngleRad = (entity.startAngleDeg + sweep / 2.0) * math.pi / 180.0;
        final pMid = Offset(
          entity.center.dx + entity.radius * math.cos(midAngleRad),
          entity.center.dy + entity.radius * math.sin(midAngleRad),
        );
        testLandmark(pMid, DxfSnapType.midpoint);

        testArcCurve(entity.center, entity.radius, entity.startAngleDeg, entity.endAngleDeg);
      } else if (entity is DxfEllipse) {
        testLandmark(entity.center, DxfSnapType.center);
        final points = DxfMath.generateEllipsePoints(
          entity.center,
          entity.majorAxisEndOffset,
          entity.minorRatio,
          startParam: entity.startParam,
          endParam: entity.endParam,
        );
        for (int i = 0; i < points.length - 1; i++) {
          testSegment(points[i], points[i + 1]);
        }
      } else if (entity is DxfLwPolyline) {
        final vertices = entity.vertices;
        final count = vertices.length;
        for (int i = 0; i < count; i++) {
          final v1 = vertices[i];
          testLandmark(v1.offset, DxfSnapType.endpoint);

          if (i + 1 < count || entity.isClosed) {
            final v2 = vertices[(i + 1) % count];
            if (v1.bulge.abs() > 1e-6) {
              final arcPts = DxfMath.generateBulgeArcPoints(v1.offset, v2.offset, v1.bulge);
              if (arcPts.length > 2) {
                final midIdx = arcPts.length ~/ 2;
                testLandmark(arcPts[midIdx], DxfSnapType.midpoint);
              }
              for (int k = 0; k < arcPts.length - 1; k++) {
                testSegment(arcPts[k], arcPts[k + 1]);
              }
            } else {
              testLandmark(
                Offset((v1.x + v2.x) / 2, (v1.y + v2.y) / 2),
                DxfSnapType.midpoint,
              );
              testSegment(v1.offset, v2.offset);
            }
          }
        }
      } else if (entity is DxfPolyline) {
        final vertices = entity.vertices;
        final count = vertices.length;
        for (int i = 0; i < count; i++) {
          final v1 = vertices[i];
          testLandmark(v1.offset, DxfSnapType.endpoint);

          if (i + 1 < count || entity.isClosed) {
            final v2 = vertices[(i + 1) % count];
            if (v1.bulge.abs() > 1e-6) {
              final arcPts = DxfMath.generateBulgeArcPoints(v1.offset, v2.offset, v1.bulge);
              if (arcPts.length > 2) {
                final midIdx = arcPts.length ~/ 2;
                testLandmark(arcPts[midIdx], DxfSnapType.midpoint);
              }
              for (int k = 0; k < arcPts.length - 1; k++) {
                testSegment(arcPts[k], arcPts[k + 1]);
              }
            } else {
              testLandmark(
                Offset((v1.x + v2.x) / 2, (v1.y + v2.y) / 2),
                DxfSnapType.midpoint,
              );
              testSegment(v1.offset, v2.offset);
            }
          }
        }
      } else if (entity is DxfSpline) {
        for (final p in entity.controlPoints) {
          testLandmark(p, DxfSnapType.endpoint);
        }
        for (final p in entity.fitPoints) {
          testLandmark(p, DxfSnapType.endpoint);
        }
        final splinePoints = DxfMath.evaluateSpline(
          entity.degree,
          entity.controlPoints.isNotEmpty ? entity.controlPoints : entity.fitPoints,
          knots: entity.knots.isNotEmpty ? entity.knots : null,
          weights: entity.weights.isNotEmpty ? entity.weights : null,
        );
        for (int i = 0; i < splinePoints.length - 1; i++) {
          testSegment(splinePoints[i], splinePoints[i + 1]);
        }
      } else if (entity is DxfSolid) {
        testLandmark(entity.p0, DxfSnapType.endpoint);
        testLandmark(entity.p1, DxfSnapType.endpoint);
        testLandmark(entity.p2, DxfSnapType.endpoint);
        testLandmark(entity.p3, DxfSnapType.endpoint);
        testSegment(entity.p0, entity.p1);
        testSegment(entity.p1, entity.p2);
        testSegment(entity.p2, entity.p3);
        testSegment(entity.p3, entity.p0);
      } else if (entity is DxfLeader) {
        for (final p in entity.vertices) {
          testLandmark(p, DxfSnapType.endpoint);
        }
        for (int i = 0; i < entity.vertices.length - 1; i++) {
          testSegment(entity.vertices[i], entity.vertices[i + 1]);
        }
      } else if (entity is DxfInsert) {
        testLandmark(entity.insertPoint, DxfSnapType.point);
      }
    }

    // If both landmark and nearest point coincide (e.g. at the segment endpoint),
    // always return the landmark snap.
    if (bestLandmarkSnap != null && bestNearestSnap != null) {
      final double diffSq = (bestNearestSnap!.point.dx - bestLandmarkSnap!.point.dx) *
              (bestNearestSnap!.point.dx - bestLandmarkSnap!.point.dx) +
          (bestNearestSnap!.point.dy - bestLandmarkSnap!.point.dy) *
              (bestNearestSnap!.point.dy - bestLandmarkSnap!.point.dy);
      if (diffSq < 1e-6) {
        return bestLandmarkSnap;
      }
    }

    // Prioritize perpendicular right-angle snap when cursor is close to the perpendicular point (within 70% of tolerance)
    if (bestPerpendicularSnap != null) {
      if (bestPerpendicularSnap!.distance <= toleranceCad * 0.70 ||
          (bestNearestSnap != null && (bestPerpendicularSnap!.point - bestNearestSnap!.point).distanceSquared < 1e-4)) {
        return bestPerpendicularSnap;
      }
    }

    // Prioritize landmark (endpoint/midpoint/center) when cursor is within 65% of snap tolerance,
    // or when no nearest segment was found.
    if (bestLandmarkSnap != null) {
      if (bestNearestSnap == null || bestLandmarkSnap!.distance <= toleranceCad * 0.65) {
        return bestLandmarkSnap;
      }
    }

    // If perpendicular snap was found and is closer than nearest
    if (bestPerpendicularSnap != null &&
        (bestNearestSnap == null || bestPerpendicularSnap!.distance < bestNearestSnap!.distance)) {
      return bestPerpendicularSnap;
    }

    if (bestNearestSnap != null) {
      return bestNearestSnap;
    }

    return bestLandmarkSnap ?? bestPerpendicularSnap;
  }
}
