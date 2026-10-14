import 'dart:math' as math;
import 'dart:ui';
import 'bim_contour_repair.dart';
import 'bim_polygon_geometry.dart';
import 'bim_transform_2d.dart';
import 'bim_line_geometry.dart';

enum BimContourOrthoType { none, horizontal, vertical, diagonal45 }

/// Result of orthogonal straightening snap relative to an anchor vertex.
class BimContourOrthoSnapResult {
  final Offset point;
  final bool isSnapped;
  final BimContourOrthoType type;
  final (Offset, Offset)? guideLine;
  final double angleDeg;

  const BimContourOrthoSnapResult({
    required this.point,
    required this.isSnapped,
    required this.type,
    this.guideLine,
    this.angleDeg = 0.0,
  });
}

/// Shared contour drafting extensions: orthogonal guides, whole-boundary
/// offset and squarify. Legacy facades retain their public API.
class BimContourDraftingGeometry {
  /// Robust segment-segment intersection test with tolerance.
  static bool linesIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    return BimContourRepair.doSegmentsIntersect(p1, p2, p3, p4, epsilon: 0);
  }

  /// Checks if polygon has any self-intersecting boundary edges.
  static bool hasSelfIntersections(List<Offset> polygon) {
    return BimContourRepair.hasSelfIntersections(polygon, epsilon: 0);
  }

  /// Tests if candidate segment [from, to] intersects any edge of an open chain [chain].
  static bool segmentIntersectsChain(
    Offset from,
    Offset to,
    List<Offset> chain, {
    bool isClosing = false,
  }) {
    if (chain.length < 2) return false;
    final segLen = (to - from).distance;
    if (segLen < 1e-4) return false;

    final limit = isClosing ? chain.length : chain.length - 1;
    for (int i = 0; i < limit; i++) {
      final p1 = chain[i];
      final p2 = chain[(i + 1) % chain.length];

      // Exclude shared endpoints
      if ((p1 - from).distance < 1e-3 ||
          (p2 - from).distance < 1e-3 ||
          (p1 - to).distance < 1e-3 ||
          (p2 - to).distance < 1e-3) {
        continue;
      }

      if (linesIntersect(from, to, p1, p2)) {
        return true;
      }
    }
    return false;
  }

  /// Cleans polygon by removing:
  /// 1. Duplicate vertices closer than [minDistance] (default 5 cm).
  /// 2. Collinear / orphan vertices sitting along straight lines.
  /// 3. Acute needle fold-backs / spikes.
  /// 4. Non-adjacent pinch loops.
  static List<Offset> cleanPolygon(
    List<Offset> polygon, {
    double minDistance = 0.05,
    double minCollinearDistance = 0.02,
  }) => BimContourRepair.cleanDraftPolygon(
    polygon,
    minDistance: minDistance,
    minCollinearDistance: minCollinearDistance,
  );

  /// Calculates net area using Shoelace formula.
  static double calculateArea(List<Offset> polygon) {
    return BimPolygonGeometry.signedArea(polygon).abs();
  }

  /// Calculates outward normal unit vector for edge [edgeIndex] of [polygon].
  static Offset calculateOutwardNormal(List<Offset> polygon, int edgeIndex) {
    if (polygon.length < 3 ||
        edgeIndex < 0 ||
        edgeIndex >= polygon.length ||
        (polygon[(edgeIndex + 1) % polygon.length] - polygon[edgeIndex])
                .distance <
            1e-6) {
      return const Offset(0, 1);
    }
    return BimPolygonGeometry.normal(polygon, edgeIndex);
  }

  /// Extrudes the segment from [edgeIndex] to [edgeIndex + 1] outward/inward by [distance].
  /// Preserves the original vertices v1 and v2, and inserts two new vertices [vNew1, vNew2]
  /// forming an architectural step / niche.
  /// Strictly prevents self-intersections and micro-distance degenerate vertices.
  static List<Offset>? extrudeEdge({
    required List<Offset> polygon,
    required int edgeIndex,
    required double distance,
    double minDistance = 0.05,
  }) {
    final n = polygon.length;
    if (n < 3 || edgeIndex < 0 || edgeIndex >= n) return null;
    if (distance.abs() < 1e-3) return polygon;

    final v1 = polygon[edgeIndex];
    final v2 = polygon[(edgeIndex + 1) % n];
    final normal = calculateOutwardNormal(polygon, edgeIndex);

    final vNew1 = v1 + normal * distance;
    final vNew2 = v2 + normal * distance;

    if ((vNew1 - v1).distance < minDistance ||
        (vNew2 - v2).distance < minDistance) {
      return polygon;
    }

    final newPts = List<Offset>.from(polygon);
    newPts.insertAll(edgeIndex + 1, [vNew1, vNew2]);

    if (hasSelfIntersections(newPts)) {
      return null;
    }

    if (calculateArea(newPts) < 1e-4) {
      return null;
    }

    return newPts;
  }

  /// Calculates vector-style orthogonal straightening guide line relative to [anchor].
  /// Snaps to exact horizontal (0°/180°) or vertical (90°/270°) if within [snapAngleToleranceDeg].
  static BimContourOrthoSnapResult calculateOrthoSnap({
    required Offset anchor,
    required Offset raw,
    double snapAngleToleranceDeg = 6.0,
    double guideLineLength = 25.0,
  }) {
    final delta = raw - anchor;
    final dist = delta.distance;
    if (dist < 1e-3) {
      return BimContourOrthoSnapResult(
        point: raw,
        isSnapped: false,
        type: BimContourOrthoType.none,
      );
    }

    final angleRad = math.atan2(delta.dy, delta.dx);
    final angleDeg = angleRad * 180.0 / math.pi;
    final absAngleDeg = angleDeg.abs();

    // Horizontal check: near 0° or 180°
    final isNear0 = absAngleDeg <= snapAngleToleranceDeg;
    final isNear180 = (absAngleDeg - 180.0).abs() <= snapAngleToleranceDeg;
    if (isNear0 || isNear180) {
      final snapped = Offset(raw.dx, anchor.dy);
      final guide = (
        Offset(anchor.dx - guideLineLength, anchor.dy),
        Offset(anchor.dx + guideLineLength, anchor.dy),
      );
      return BimContourOrthoSnapResult(
        point: snapped,
        isSnapped: true,
        type: BimContourOrthoType.horizontal,
        guideLine: guide,
        angleDeg: isNear0 ? 0.0 : 180.0,
      );
    }

    // Vertical check: near 90° or -90° (270°)
    final isNear90 = (angleDeg - 90.0).abs() <= snapAngleToleranceDeg;
    final isNearMinus90 = (angleDeg + 90.0).abs() <= snapAngleToleranceDeg;
    if (isNear90 || isNearMinus90) {
      final snapped = Offset(anchor.dx, raw.dy);
      final guide = (
        Offset(anchor.dx, anchor.dy - guideLineLength),
        Offset(anchor.dx, anchor.dy + guideLineLength),
      );
      return BimContourOrthoSnapResult(
        point: snapped,
        isSnapped: true,
        type: BimContourOrthoType.vertical,
        guideLine: guide,
        angleDeg: isNear90 ? 90.0 : -90.0,
      );
    }

    return BimContourOrthoSnapResult(
      point: raw,
      isSnapped: false,
      type: BimContourOrthoType.none,
      angleDeg: angleDeg,
    );
  }

  /// Computes the arithmetic centroid (center of mass) of polygon vertices.
  static Offset calculateCentroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    double sumX = 0.0;
    double sumY = 0.0;
    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  /// Rotates a list of [points] by [angleDeg] around [center] (defaults to centroid).
  static List<Offset> rotatePolygon(
    List<Offset> points,
    double angleDeg, [
    Offset? center,
  ]) {
    if (points.isEmpty || angleDeg.abs() < 1e-4) return points;
    final pivot = center ?? calculateCentroid(points);
    final radians = angleDeg * math.pi / 180;
    return points.map((p) => BimTransform2D.rotate(p, pivot, radians)).toList();
  }

  /// Translates all polygon vertices by [delta].
  static List<Offset> translatePolygon(List<Offset> points, Offset delta) {
    if (delta == Offset.zero || points.isEmpty) return points;
    return points.map((p) => p + delta).toList();
  }

  /// Calculates intersection of two infinite rays in 2D Cartesian plane.
  static Offset? rayIntersection(
    Offset p1,
    double angleDeg1,
    Offset p2,
    double angleDeg2,
  ) {
    final a = angleDeg1 * math.pi / 180;
    final b = angleDeg2 * math.pi / 180;
    return BimLineGeometry.intersection(
      p1,
      p1 + Offset(math.cos(a), math.sin(a)),
      p2,
      p2 + Offset(math.cos(b), math.sin(b)),
      parallelTolerance: 1e-4,
    );
  }

  /// Straightens polygon corners and wall alignments to exact 90° (and 45°/5°),
  /// ported from the battle-tested GPS_Mapping alignment engine into 2D Cartesian space.
  /// Rectangles become perfectly orthogonal; complex rooms snap corners to 90°.
  /// Centroid is preserved to prevent spatial drift.
  static List<Offset> alignPolygonToNearest2D(
    List<Offset> points, {
    bool isClosed = true,
  }) {
    if (points.length < 3) return List.from(points);

    // 1. Specialized 4-point rectangle / square orthogonalizer
    if (isClosed && points.length == 4) {
      final p0 = points[0];
      final p1 = points[1];
      final p2 = points[2];
      final p3 = points[3];

      final v01 = p1 - p0;
      double baseBearing = math.atan2(v01.dy, v01.dx) * 180.0 / math.pi;
      if (baseBearing < 0) baseBearing += 360.0;

      // Snap base orientation to nearest 90° or 5°
      double nearest90 = (baseBearing / 90.0).round() * 90.0;
      if (nearest90 >= 360.0) nearest90 -= 360.0;
      double diff90 = (baseBearing - nearest90).abs();
      if (diff90 > 180.0) diff90 = 360.0 - diff90;

      if (diff90 <= 12.0) {
        baseBearing = nearest90;
      } else {
        double nearest5 = (baseBearing / 5.0).round() * 5.0;
        if (nearest5 >= 360.0) nearest5 -= 360.0;
        double diff5 = (baseBearing - nearest5).abs();
        if (diff5 > 180.0) diff5 = 360.0 - diff5;
        if (diff5 <= 4.0) baseBearing = nearest5;
      }

      // Detect turning direction (CW vs CCW)
      final cross =
          (p1.dx - p0.dx) * (p2.dy - p1.dy) - (p1.dy - p0.dy) * (p2.dx - p1.dx);
      final turnAngle = cross < 0 ? -90.0 : 90.0;

      final d01 = (p1 - p0).distance;
      final d12 = (p2 - p1).distance;
      final d23 = (p3 - p2).distance;
      final d30 = (p0 - p3).distance;

      // Average opposite lengths and round to clean 5 cm increments
      double length = ((d01 + d23) / 2.0);
      length = (length * 20.0).round() / 20.0;
      if (length < 0.20) length = 0.20;

      double width = ((d12 + d30) / 2.0);
      width = (width * 20.0).round() / 20.0;
      if (width < 0.20) width = 0.20;

      final b1 = baseBearing;
      final b2 = (b1 + turnAngle) % 360.0;
      final b3 = (b2 + turnAngle) % 360.0;

      Offset step(Offset from, double deg, double dist) {
        final r = deg * math.pi / 180.0;
        return from + Offset(math.cos(r) * dist, math.sin(r) * dist);
      }

      final ap0 = p0;
      final ap1 = step(ap0, b1, length);
      final ap2 = step(ap1, b2, width);
      final ap3 = step(ap2, b3, length);

      final origCenter = calculateCentroid(points);
      final alignedCenter = calculateCentroid([ap0, ap1, ap2, ap3]);
      final shift = origCenter - alignedCenter;

      return [ap0 + shift, ap1 + shift, ap2 + shift, ap3 + shift];
    }

    // 2. Multi-point polygon alignment (L-shaped, T-shaped, arbitrary polyline)
    final aligned = <Offset>[points.first];
    double? firstAlignedBearing;
    double? prevAlignedBearing;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final delta = p2 - p1;
      double dist = delta.distance;
      dist = (dist * 20.0).round() / 20.0;
      if (dist < 0.05) dist = 0.05;

      double bearing = math.atan2(delta.dy, delta.dx) * 180.0 / math.pi;
      if (bearing < 0) bearing += 360.0;

      double targetAngle;
      if (prevAlignedBearing == null) {
        targetAngle = bearing;
        double n90 = (targetAngle / 90.0).round() * 90.0;
        if (n90 >= 360.0) n90 -= 360.0;
        double d90 = (targetAngle - n90).abs();
        if (d90 > 180.0) d90 = 360.0 - d90;

        if (d90 <= 12.0) {
          targetAngle = n90;
        } else {
          double n45 = (targetAngle / 45.0).round() * 45.0;
          if (n45 >= 360.0) n45 -= 360.0;
          double d45 = (targetAngle - n45).abs();
          if (d45 > 180.0) d45 = 360.0 - d45;
          if (d45 <= 6.0) targetAngle = n45;
        }
        firstAlignedBearing = targetAngle;
      } else {
        double relAngle = (bearing - prevAlignedBearing) % 360.0;
        if (relAngle < 0) relAngle += 360.0;

        double snappedRel = relAngle;
        double n90 = (relAngle / 90.0).round() * 90.0;
        double d90 = (relAngle - n90).abs();
        if (d90 > 180.0) d90 = 360.0 - d90;

        if (d90 <= 12.0) {
          snappedRel = n90;
        } else {
          double n45 = (relAngle / 45.0).round() * 45.0;
          double d45 = (relAngle - n45).abs();
          if (d45 > 180.0) d45 = 360.0 - d45;
          if (d45 <= 6.0) snappedRel = n45;
        }
        targetAngle = (prevAlignedBearing + snappedRel) % 360.0;
      }

      // Closing segment ray intersection for closed polygons
      if (isClosed &&
          points.length > 3 &&
          i == points.length - 2 &&
          firstAlignedBearing != null) {
        final closingDelta = points.last - points.first;
        double closingBearing =
            math.atan2(closingDelta.dy, closingDelta.dx) * 180.0 / math.pi;
        if (closingBearing < 0) closingBearing += 360.0;

        double relClosing = (closingBearing - firstAlignedBearing) % 360.0;
        if (relClosing < 0) relClosing += 360.0;
        double n90 = (relClosing / 90.0).round() * 90.0;
        double d90 = (relClosing - n90).abs();
        if (d90 > 180.0) d90 = 360.0 - d90;

        double snappedRelClosing = d90 <= 12.0 ? n90 : relClosing;
        double targetClosing =
            (firstAlignedBearing + snappedRelClosing) % 360.0;

        final isect = rayIntersection(
          aligned.last,
          targetAngle,
          points.first,
          targetClosing,
        );
        if (isect != null && (isect - aligned.last).distance < dist * 2.5) {
          aligned.add(isect);
          prevAlignedBearing = targetAngle;
          continue;
        }
      }

      prevAlignedBearing = targetAngle;
      final rad = targetAngle * math.pi / 180.0;
      final nextPt =
          aligned.last + Offset(math.cos(rad) * dist, math.sin(rad) * dist);
      aligned.add(nextPt);
    }

    if (isClosed && aligned.length >= 3) {
      final origCenter = calculateCentroid(points);
      final alignedCenter = calculateCentroid(aligned);
      final shift = origCenter - alignedCenter;
      return aligned.map((p) => p + shift).toList();
    }
    return aligned;
  }

  /// Offsets polygon boundary outward (positive distance) or inward (negative distance).
  static List<Offset> offsetPolygon(List<Offset> polygon, double distance) {
    final n = polygon.length;
    if (n < 3 || distance.abs() < 1e-4) return polygon;

    final normals = <Offset>[];
    for (int i = 0; i < n; i++) {
      normals.add(calculateOutwardNormal(polygon, i));
    }

    final newPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final prevEdge = (i - 1 + n) % n;
      final currEdge = i;
      final n1 = normals[prevEdge];
      final n2 = normals[currEdge];

      final pPrev = polygon[prevEdge] + n1 * distance;
      final v1 = polygon[i] - polygon[prevEdge];
      final pCurr = polygon[currEdge] + n2 * distance;
      final v2 = polygon[(currEdge + 1) % n] - polygon[currEdge];

      final det = v1.dx * v2.dy - v1.dy * v2.dx;
      if (det.abs() > 1e-4) {
        final dp = pCurr - pPrev;
        final t = (dp.dx * v2.dy - dp.dy * v2.dx) / det;
        newPts.add(pPrev + v1 * t);
      } else {
        newPts.add(polygon[i] + (n1 + n2) / 2.0 * distance);
      }
    }

    if (hasSelfIntersections(newPts) || calculateArea(newPts) < 0.1) {
      return polygon;
    }
    return newPts;
  }
}
