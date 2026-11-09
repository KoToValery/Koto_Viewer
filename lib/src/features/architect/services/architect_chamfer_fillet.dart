// === SECTION: ARCHITECT CHAMFER & FILLET GEOMETRY ===
// Table of Contents:
// 1. Math Helpers & Intersections
// 2. Polygon Chamfer & Fillet (Slabs, Hatches, Roofs, Polylines)
// 3. Wall Pair Chamfer & Fillet
// 4. CAD Line Pair Chamfer & Fillet

import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_elements.dart';
import '../models/architect_wall.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';

class ArchitectChamferFillet {
  // === SECTION: 1. MATH HELPERS ===

  static Offset? lineIntersection(Offset a1, Offset b1, Offset a2, Offset b2) {
    return BimLineGeometry.intersection(a1, b1, a2, b2, firstFinite: false, secondFinite: false);
  }

  // === SECTION: 2. POLYGON CHAMFER & FILLET ===

  /// Applies chamfer (bevel) to vertices of a polygon.
  /// If [vertexIndex] is provided, only that vertex is chamfered.
  /// Otherwise, all valid corners are chamfered.
  static List<Offset> polygonChamfer(
    List<Offset> polygon, {
    int? vertexIndex,
    required double distance,
    bool isClosed = true,
  }) {
    if (polygon.length < 3 || distance <= 1e-6) return polygon;
    final n = polygon.length;
    final result = <Offset>[];

    for (var i = 0; i < n; i++) {
      if (vertexIndex != null && vertexIndex != i) {
        result.add(polygon[i]);
        continue;
      }
      if (!isClosed && (i == 0 || i == n - 1)) {
        result.add(polygon[i]);
        continue;
      }

      final prev = polygon[(i - 1 + n) % n];
      final curr = polygon[i];
      final next = polygon[(i + 1) % n];

      final d1 = prev - curr;
      final d2 = next - curr;
      final l1 = d1.distance;
      final l2 = d2.distance;

      if (l1 < 1e-5 || l2 < 1e-5) {
        result.add(curr);
        continue;
      }

      final u1 = d1 / l1;
      final u2 = d2 / l2;
      final cosTheta = (u1.dx * u2.dx + u1.dy * u2.dy).clamp(-1.0, 1.0);

      // Collinear or foldback
      if (cosTheta.abs() > 0.9999) {
        result.add(curr);
        continue;
      }

      final c1 = math.min(distance, l1 * 0.49);
      final c2 = math.min(distance, l2 * 0.49);

      final p1 = curr + u1 * c1;
      final p2 = curr + u2 * c2;

      result.add(p1);
      result.add(p2);
    }
    return result;
  }

  /// Applies fillet (arc rounding) to vertices of a polygon.
  /// If [vertexIndex] is provided, only that vertex is filleted.
  /// Otherwise, all valid corners are filleted.
  static List<Offset> polygonFillet(
    List<Offset> polygon, {
    int? vertexIndex,
    required double radius,
    int segments = 8,
    bool isClosed = true,
  }) {
    if (polygon.length < 3 || radius <= 1e-6) return polygon;
    final n = polygon.length;
    final result = <Offset>[];

    for (var i = 0; i < n; i++) {
      if (vertexIndex != null && vertexIndex != i) {
        result.add(polygon[i]);
        continue;
      }
      if (!isClosed && (i == 0 || i == n - 1)) {
        result.add(polygon[i]);
        continue;
      }

      final prev = polygon[(i - 1 + n) % n];
      final curr = polygon[i];
      final next = polygon[(i + 1) % n];

      final d1 = prev - curr;
      final d2 = next - curr;
      final l1 = d1.distance;
      final l2 = d2.distance;

      if (l1 < 1e-5 || l2 < 1e-5) {
        result.add(curr);
        continue;
      }

      final u1 = d1 / l1;
      final u2 = d2 / l2;
      final cosTheta = (u1.dx * u2.dx + u1.dy * u2.dy).clamp(-1.0, 1.0);

      // Collinear or foldback
      if (cosTheta.abs() > 0.9999) {
        result.add(curr);
        continue;
      }

      final theta = math.acos(cosTheta);
      final alpha = theta / 2;
      final tanAlpha = math.tan(alpha);
      if (tanAlpha.abs() < 1e-6) {
        result.add(curr);
        continue;
      }

      final idealTangent = radius / tanAlpha;
      final maxTangent = math.min(l1, l2) * 0.49;
      final tEff = math.min(idealTangent, maxTangent);
      final rEff = tEff * tanAlpha;

      final t1 = curr + u1 * tEff;
      final t2 = curr + u2 * tEff;

      // Bisector direction pointing inside the corner
      final bisector = u1 + u2;
      final bLen = bisector.distance;
      if (bLen < 1e-6) {
        result.add(curr);
        continue;
      }
      final uB = bisector / bLen;
      final dCenter = rEff / math.sin(alpha);
      final center = curr + uB * dCenter;

      // Generate arc points from t1 to t2 around center
      final phi1 = math.atan2(t1.dy - center.dy, t1.dx - center.dx);
      final phi2 = math.atan2(t2.dy - center.dy, t2.dx - center.dx);
      var deltaPhi = phi2 - phi1;
      while (deltaPhi > math.pi) {
        deltaPhi -= 2 * math.pi;
      }
      while (deltaPhi < -math.pi) {
        deltaPhi += 2 * math.pi;
      }

      final arcSteps = math.max(4, segments);
      for (var s = 0; s <= arcSteps; s++) {
        final frac = s / arcSteps;
        final phi = phi1 + deltaPhi * frac;
        result.add(center + Offset(math.cos(phi), math.sin(phi)) * rEff);
      }
    }
    return result;
  }

  // === SECTION: 3. WALL PAIR CHAMFER & FILLET ===

  /// Applies chamfer to two intersecting walls, returning the modified walls and a straight connecting wall.
  static ({ArchitectWall wallA, ArchitectWall wallB, ArchitectWall connector})?
      wallPairChamfer(
    ArchitectWall wallA,
    ArchitectWall wallB, {
    required double distance,
  }) {
    final v = lineIntersection(
      wallA.startPoint,
      wallA.endPoint,
      wallB.startPoint,
      wallB.endPoint,
    );
    if (v == null || distance <= 1e-6) return null;

    final (aNearStart, aFar) = (wallA.startPoint - v).distance < (wallA.endPoint - v).distance
        ? (true, wallA.endPoint)
        : (false, wallA.startPoint);
    final (bNearStart, bFar) = (wallB.startPoint - v).distance < (wallB.endPoint - v).distance
        ? (true, wallB.endPoint)
        : (false, wallB.startPoint);

    final uA = (aFar - v) / (aFar - v).distance;
    final uB = (bFar - v) / (bFar - v).distance;

    final cA = math.min(distance, (aFar - v).distance * 0.49);
    final cB = math.min(distance, (bFar - v).distance * 0.49);

    final pA = v + uA * cA;
    final pB = v + uB * cB;

    final newWallA = aNearStart
        ? wallA.copyWith(startPoint: pA)
        : wallA.copyWith(endPoint: pA);
    final newWallB = bNearStart
        ? wallB.copyWith(startPoint: pB)
        : wallB.copyWith(endPoint: pB);

    final connector = ArchitectWall(
      id: 'chamfer_wall_${DateTime.now().microsecondsSinceEpoch}',
      startPoint: pA,
      endPoint: pB,
      thickness: wallA.thickness,
      layers: wallA.layers,
      wallTypeId: wallA.wallTypeId,
    );

    return (wallA: newWallA, wallB: newWallB, connector: connector);
  }

  /// Applies fillet to two intersecting walls, returning the modified walls and a curved connecting wall.
  static ({ArchitectWall wallA, ArchitectWall wallB, ArchitectWall connector})?
      wallPairFillet(
    ArchitectWall wallA,
    ArchitectWall wallB, {
    required double radius,
  }) {
    final v = lineIntersection(
      wallA.startPoint,
      wallA.endPoint,
      wallB.startPoint,
      wallB.endPoint,
    );
    if (v == null || radius <= 1e-6) return null;

    final (aNearStart, aFar) = (wallA.startPoint - v).distance < (wallA.endPoint - v).distance
        ? (true, wallA.endPoint)
        : (false, wallA.startPoint);
    final (bNearStart, bFar) = (wallB.startPoint - v).distance < (wallB.endPoint - v).distance
        ? (true, wallB.endPoint)
        : (false, wallB.startPoint);

    final lenA = (aFar - v).distance;
    final lenB = (bFar - v).distance;
    if (lenA < 1e-5 || lenB < 1e-5) return null;

    final uA = (aFar - v) / lenA;
    final uB = (bFar - v) / lenB;

    final cosTheta = (uA.dx * uB.dx + uA.dy * uB.dy).clamp(-1.0, 1.0);
    if (cosTheta.abs() > 0.9999) return null;

    final theta = math.acos(cosTheta);
    final alpha = theta / 2;
    final tanAlpha = math.tan(alpha);
    if (tanAlpha.abs() < 1e-6) return null;

    final idealT = radius / tanAlpha;
    final maxT = math.min(lenA, lenB) * 0.49;
    final tEff = math.min(idealT, maxT);
    final rEff = tEff * tanAlpha;

    final tA = v + uA * tEff;
    final tB = v + uB * tEff;

    final newWallA = aNearStart
        ? wallA.copyWith(startPoint: tA)
        : wallA.copyWith(endPoint: tA);
    final newWallB = bNearStart
        ? wallB.copyWith(startPoint: tB)
        : wallB.copyWith(endPoint: tB);

    final bisector = uA + uB;
    final bLen = bisector.distance;
    if (bLen < 1e-6) return null;
    final uBis = bisector / bLen;
    final center = v + uBis * (rEff / math.sin(alpha));

    // Calculate arc bulge from tA to tB
    final phiA = math.atan2(tA.dy - center.dy, tA.dx - center.dx);
    final phiB = math.atan2(tB.dy - center.dy, tB.dx - center.dx);
    var sweep = phiB - phiA;
    while (sweep > math.pi) {
      sweep -= 2 * math.pi;
    }
    while (sweep < -math.pi) {
      sweep += 2 * math.pi;
    }

    final bulge = math.tan(sweep / 4);

    final connector = ArchitectWall(
      id: 'fillet_wall_${DateTime.now().microsecondsSinceEpoch}',
      startPoint: tA,
      endPoint: tB,
      arcBulge: bulge,
      thickness: wallA.thickness,
      layers: wallA.layers,
      wallTypeId: wallA.wallTypeId,
    );

    return (wallA: newWallA, wallB: newWallB, connector: connector);
  }

  // === SECTION: 4. CAD LINE PAIR CHAMFER & FILLET ===

  /// Applies chamfer to two intersecting CAD lines.
  static ({
    ArchitectCadPrimitive lineA,
    ArchitectCadPrimitive lineB,
    ArchitectCadPrimitive connector,
  })? linePairChamfer(
    ArchitectCadPrimitive lineA,
    ArchitectCadPrimitive lineB, {
    required double distance,
  }) {
    final v = lineIntersection(
      lineA.startPoint,
      lineA.endPoint,
      lineB.startPoint,
      lineB.endPoint,
    );
    if (v == null || distance <= 1e-6) return null;

    final (aNearStart, aFar) = (lineA.startPoint - v).distance < (lineA.endPoint - v).distance
        ? (true, lineA.endPoint)
        : (false, lineA.startPoint);
    final (bNearStart, bFar) = (lineB.startPoint - v).distance < (lineB.endPoint - v).distance
        ? (true, lineB.endPoint)
        : (false, lineB.startPoint);

    final uA = (aFar - v) / (aFar - v).distance;
    final uB = (bFar - v) / (bFar - v).distance;

    final cA = math.min(distance, (aFar - v).distance * 0.49);
    final cB = math.min(distance, (bFar - v).distance * 0.49);

    final pA = v + uA * cA;
    final pB = v + uB * cB;

    final newLineA = aNearStart
        ? lineA.copyWith(startPoint: pA)
        : lineA.copyWith(endPoint: pA);
    final newLineB = bNearStart
        ? lineB.copyWith(startPoint: pB)
        : lineB.copyWith(endPoint: pB);

    final connector = lineA.copyWith(
      id: 'chamfer_line_${DateTime.now().microsecondsSinceEpoch}',
      type: CadPrimitiveType.line,
      startPoint: pA,
      endPoint: pB,
    );

    return (lineA: newLineA, lineB: newLineB, connector: connector);
  }

  /// Applies fillet to two intersecting CAD lines, returning the modified lines and an arc connector.
  static ({
    ArchitectCadPrimitive lineA,
    ArchitectCadPrimitive lineB,
    ArchitectCadPrimitive connector,
  })? linePairFillet(
    ArchitectCadPrimitive lineA,
    ArchitectCadPrimitive lineB, {
    required double radius,
  }) {
    final v = lineIntersection(
      lineA.startPoint,
      lineA.endPoint,
      lineB.startPoint,
      lineB.endPoint,
    );
    if (v == null || radius <= 1e-6) return null;

    final (aNearStart, aFar) = (lineA.startPoint - v).distance < (lineA.endPoint - v).distance
        ? (true, lineA.endPoint)
        : (false, lineA.startPoint);
    final (bNearStart, bFar) = (lineB.startPoint - v).distance < (lineB.endPoint - v).distance
        ? (true, lineB.endPoint)
        : (false, lineB.startPoint);

    final lenA = (aFar - v).distance;
    final lenB = (bFar - v).distance;
    if (lenA < 1e-5 || lenB < 1e-5) return null;

    final uA = (aFar - v) / lenA;
    final uB = (bFar - v) / lenB;

    final cosTheta = (uA.dx * uB.dx + uA.dy * uB.dy).clamp(-1.0, 1.0);
    if (cosTheta.abs() > 0.9999) return null;

    final theta = math.acos(cosTheta);
    final alpha = theta / 2;
    final tanAlpha = math.tan(alpha);
    if (tanAlpha.abs() < 1e-6) return null;

    final idealT = radius / tanAlpha;
    final maxT = math.min(lenA, lenB) * 0.49;
    final tEff = math.min(idealT, maxT);
    final rEff = tEff * tanAlpha;

    final tA = v + uA * tEff;
    final tB = v + uB * tEff;

    final newLineA = aNearStart
        ? lineA.copyWith(startPoint: tA)
        : lineA.copyWith(endPoint: tA);
    final newLineB = bNearStart
        ? lineB.copyWith(startPoint: tB)
        : lineB.copyWith(endPoint: tB);

    final bisector = uA + uB;
    final bLen = bisector.distance;
    if (bLen < 1e-6) return null;
    final uBis = bisector / bLen;
    final center = v + uBis * (rEff / math.sin(alpha));

    final phiA = math.atan2(tA.dy - center.dy, tA.dx - center.dx);
    final phiB = math.atan2(tB.dy - center.dy, tB.dx - center.dx);
    var sweep = phiB - phiA;
    while (sweep > math.pi) {
      sweep -= 2 * math.pi;
    }
    while (sweep < -math.pi) {
      sweep += 2 * math.pi;
    }

    final bulge = math.tan(sweep / 4);

    final connector = lineA.copyWith(
      id: 'fillet_arc_${DateTime.now().microsecondsSinceEpoch}',
      type: CadPrimitiveType.arc,
      startPoint: tA,
      endPoint: tB,
      arcBulge: bulge,
    );

    return (lineA: newLineA, lineB: newLineB, connector: connector);
  }
}
