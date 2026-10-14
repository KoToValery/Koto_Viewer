import 'dart:math' as math;
import 'dart:ui';
import 'bim_polygon_geometry.dart';

/// Compatibility repair policy for imported/legacy contours. Domain adapters
/// choose it explicitly; normal edits use BimPolygonGeometry's strict policy.
class BimContourRepair {
  /// Legacy drafting cleanup; preserves valid origin vertices and accepts the
  /// caller's collinear threshold. Imported stray-origin repair is separate.
  static List<Offset> cleanDraftPolygon(
    List<Offset> polygon, {
    double minDistance = 0.05,
    double minCollinearDistance = 0.02,
  }) {
    final nonNanPts = polygon
        .where((p) => p.dx.isFinite && p.dy.isFinite)
        .toList();

    if (nonNanPts.length < 3) return nonNanPts;

    final validPts = List<Offset>.from(nonNanPts);
    bool changed = true;
    int maxPasses = 15;

    while (changed && validPts.length > 3 && maxPasses-- > 0) {
      changed = false;

      // 1. Collapse adjacent duplicate points (< minDistance)
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        final next = (i + 1) % validPts.length;
        if ((validPts[i] - validPts[next]).distance < minDistance) {
          validPts.removeAt(next);
          changed = true;
          break;
        }
      }
      if (changed) continue;

      // 2. Remove collinear points (orphan points sitting on straight edges)
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        final prev = (i - 1 + validPts.length) % validPts.length;
        final next = (i + 1) % validPts.length;
        final v1 = validPts[i] - validPts[prev];
        final v2 = validPts[next] - validPts[i];
        final l1 = v1.distance;
        final l2 = v2.distance;

        if (l1 > 1e-4 && l2 > 1e-4) {
          final cross = (v1.dx * v2.dy - v1.dy * v2.dx) / (l1 * l2);
          final dot = (v1.dx * v2.dx + v1.dy * v2.dy) / (l1 * l2);

          final chord = validPts[next] - validPts[prev];
          final chordLen = chord.distance;
          final double distToChord;
          if (chordLen > 1e-4) {
            final t =
                (((validPts[i].dx - validPts[prev].dx) * chord.dx +
                            (validPts[i].dy - validPts[prev].dy) * chord.dy) /
                        (chordLen * chordLen))
                    .clamp(0.0, 1.0);
            final proj = validPts[prev] + chord * t;
            distToChord = (validPts[i] - proj).distance;
          } else {
            distToChord = (validPts[i] - validPts[prev]).distance;
          }

          // Collinear redundant vertex
          if ((cross.abs() < 0.04 &&
                  dot > 0.96 &&
                  distToChord < minCollinearDistance) ||
              (distToChord < minCollinearDistance && dot > 0.5)) {
            validPts.removeAt(i);
            changed = true;
            break;
          }

          // Acute needle fold-back / spike
          if (cross.abs() < 0.08 && dot < -0.85) {
            validPts.removeAt(i);
            changed = true;
            break;
          }

          // Slit where chord is almost closed
          if (chordLen < minDistance * 1.5 && dot < -0.5) {
            validPts.removeAt(i);
            changed = true;
            break;
          }
        }
      }
      if (changed) continue;

      // 3. Non-adjacent pinch duplicate collapse
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        for (int j = i + 2; j < validPts.length; j++) {
          if (i == 0 && j == validPts.length - 1) continue;
          if ((validPts[i] - validPts[j]).distance < minDistance) {
            final loop1Len = j - i;
            final loop2Len = validPts.length - loop1Len;
            if (loop1Len <= loop2Len) {
              validPts.removeRange(i + 1, j + 1);
            } else {
              validPts.removeRange(j + 1, validPts.length);
              validPts.removeRange(0, i);
            }
            changed = true;
            break;
          }
        }
        if (changed) break;
      }
    }

    return validPts;
  }

  static bool doSegmentsIntersect(
    Offset p1,
    Offset p2,
    Offset p3,
    Offset p4, {
    double epsilon = 1e-6,
  }) {
    double ccw(Offset a, Offset b, Offset c) {
      return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    }

    final d1 = ccw(p3, p4, p1);
    final d2 = ccw(p3, p4, p2);
    final d3 = ccw(p1, p2, p3);
    final d4 = ccw(p1, p2, p4);

    if (((d1 > epsilon && d2 < -epsilon) || (d1 < -epsilon && d2 > epsilon)) &&
        ((d3 > epsilon && d4 < -epsilon) || (d3 < -epsilon && d4 > epsilon))) {
      return true;
    }
    return false;
  }

  static bool hasSelfIntersections(List<Offset> pts, {double epsilon = 1e-6}) {
    final n = pts.length;
    if (n < 4) return false;
    for (int i = 0; i < n; i++) {
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      for (int j = i + 2; j < n; j++) {
        if (i == 0 && j == n - 1) continue;
        final p3 = pts[j];
        final p4 = pts[(j + 1) % n];
        if (doSegmentsIntersect(p1, p2, p3, p4, epsilon: epsilon)) {
          return true;
        }
      }
    }
    return false;
  }

  static List<Offset> cleanPolygon(
    List<Offset> rawPts, {
    double minDistance = 0.05,
  }) {
    if (rawPts.length < 3) return List.from(rawPts);

    // 1. Filter out NaN and Infinite points
    final nonNanPts = <Offset>[];
    for (final p in rawPts) {
      if (!p.dx.isNaN && !p.dy.isNaN && !p.dx.isInfinite && !p.dy.isInfinite) {
        nonNanPts.add(p);
      }
    }
    if (nonNanPts.length < 3) return nonNanPts;

    // Check for orphan (0, 0): only drop (0, 0) if the non-zero points form a coherent
    // contour (>= 3 points) and (0, 0) is well outside their bounding box (isolated stray point).
    final nonZeroPts = nonNanPts
        .where((p) => p.dx.abs() > 1e-4 || p.dy.abs() > 1e-4)
        .toList();
    bool dropZero = false;
    if (nonZeroPts.length >= 3) {
      double minX = nonZeroPts[0].dx, maxX = nonZeroPts[0].dx;
      double minY = nonZeroPts[0].dy, maxY = nonZeroPts[0].dy;
      for (final p in nonZeroPts) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      final bbox = Rect.fromLTRB(minX, minY, maxX, maxY);
      final margin = math.max(0.5, math.min(bbox.width, bbox.height) * 0.1);
      if (!bbox.inflate(margin).contains(Offset.zero)) {
        dropZero = true;
      }
    }

    final validPts = <Offset>[];
    for (final p in nonNanPts) {
      if (dropZero && p.dx.abs() < 1e-4 && p.dy.abs() < 1e-4) {
        continue;
      }
      validPts.add(p);
    }

    if (validPts.length < 3) return validPts;

    // Iterative multi-pass reduction until polygon is completely clean
    bool outerChanged = true;
    int maxPasses = 15;
    while (outerChanged && validPts.length > 3 && maxPasses-- > 0) {
      outerChanged = false;

      // 2. Collapse adjacent duplicate points
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        final next = (i + 1) % validPts.length;
        if ((validPts[i] - validPts[next]).distance < minDistance) {
          validPts.removeAt(next);
          outerChanged = true;
          break;
        }
      }
      if (outerChanged) continue;

      // 3. Remove collinear points, acute needle fold-backs, and slits
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        final prev = (i - 1 + validPts.length) % validPts.length;
        final next = (i + 1) % validPts.length;
        final v1 = validPts[i] - validPts[prev];
        final v2 = validPts[next] - validPts[i];
        final l1 = v1.distance;
        final l2 = v2.distance;
        if (l1 > 1e-4 && l2 > 1e-4) {
          final cross = (v1.dx * v2.dy - v1.dy * v2.dx) / (l1 * l2);
          final dot = (v1.dx * v2.dx + v1.dy * v2.dy) / (l1 * l2);

          // Distance from vertex i to chord between prev and next
          final chord = validPts[next] - validPts[prev];
          final chordLen = chord.distance;
          final double distToChord;
          if (chordLen > 1e-4) {
            final t =
                (((validPts[i].dx - validPts[prev].dx) * chord.dx +
                            (validPts[i].dy - validPts[prev].dy) * chord.dy) /
                        (chordLen * chordLen))
                    .clamp(0.0, 1.0);
            final proj = validPts[prev] + chord * t;
            distToChord = (validPts[i] - proj).distance;
          } else {
            distToChord = (validPts[i] - validPts[prev]).distance;
          }

          // A. Collinear redundant vertex (orphan point sitting on straight line)
          if ((cross.abs() < 0.04 && dot > 0.96) ||
              (distToChord < math.max(minDistance * 0.4, 0.015) && dot > 0.5)) {
            validPts.removeAt(i);
            outerChanged = true;
            break;
          }

          // B. Acute needle fold-back / spike (израстък/остър вглъбнат участък)
          if (cross.abs() < 0.08 && dot < -0.85) {
            validPts.removeAt(i);
            if (chordLen < minDistance * 1.5 && validPts.length > 3) {
              final newNext = next > i ? next - 1 : next;
              validPts.removeAt(newNext);
            }
            outerChanged = true;
            break;
          }

          // C. Degenerate narrow slit where chord between prev and next is almost closed
          if (chordLen < minDistance * 1.5 && dot < -0.5) {
            validPts.removeAt(i);
            outerChanged = true;
            break;
          }
        }
      }
      if (outerChanged) continue;

      // 4. Non-adjacent pinch duplicate collapse (merging or touching points)
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        for (int j = i + 2; j < validPts.length; j++) {
          if (i == 0 && j == validPts.length - 1) continue;
          if ((validPts[i] - validPts[j]).distance < minDistance) {
            // Find smaller sub-loop between i and j
            final loop1Len = j - i;
            final loop2Len = validPts.length - loop1Len;
            if (loop1Len <= loop2Len) {
              // Subloop is from i+1 to j
              validPts.removeRange(i + 1, j + 1);
            } else {
              // Subloop wraps around 0: from j+1 to end and 0 to i-1
              validPts.removeRange(j + 1, validPts.length);
              validPts.removeRange(0, i);
            }
            outerChanged = true;
            break;
          }
        }
        if (outerChanged) break;
      }
    }

    return validPts;
  }

  static List<Offset> extendEdge(
    List<Offset> polygon, {
    required int edgeIndex,
    required double distance,
    double minDistanceCad = 0.05,
  }) {
    if (polygon.length < 3 || edgeIndex < 0 || edgeIndex >= polygon.length) {
      return polygon;
    }
    if (distance.abs() < 1e-4) {
      return polygon;
    }

    final n = polygon.length;
    final v1 = polygon[edgeIndex];
    final v2 = polygon[(edgeIndex + 1) % n];
    final edge = v2 - v1;
    final len = edge.distance;
    if (len < 1e-6) return polygon;

    final u = edge / len;

    // Outward normal via Shoelace signed area
    final isCCW = BimPolygonGeometry.signedArea(polygon) > 0;
    final normal = isCCW ? Offset(u.dy, -u.dx) : Offset(-u.dy, u.dx);

    final vPrev = polygon[(edgeIndex - 1 + n) % n];
    final vNext = polygon[(edgeIndex + 2) % n];

    final d1 = v1 - vPrev;
    final d2 = vNext - v2;
    final len1 = d1.distance;
    final len2 = d2.distance;

    // Projections of adjacent edge unit directions along the outward normal
    final double normProj1 = len1 > 1e-6
        ? (d1.dx * normal.dx + d1.dy * normal.dy) / len1
        : 0.0;
    final double normProj2 = len2 > 1e-6
        ? (d2.dx * (-normal.dx) + d2.dy * (-normal.dy)) / len2
        : 0.0;

    // Collinear checks: an adjacent edge is collinear with the moved edge if its direction is
    // perpendicular to the outward normal (|normProj| <= 0.08)
    final bool isD1Collinear = normProj1.abs() <= 0.08;
    final bool isD2Collinear = normProj2.abs() <= 0.08;

    Offset vNew1;
    if (isD1Collinear) {
      // Wall continues along the same straight line: keep v1 as step anchor, insert new corner
      vNew1 = v1 + normal * distance;
    } else {
      // Adjacent edge is at an angle or perpendicular: intersect the extended adjacent ray
      // with the offset edge line.
      if (normProj1.abs() >= 0.20) {
        final t1 = distance / (normProj1 * len1);
        vNew1 = v1 + d1 * t1;
      } else {
        // Very shallow angle: fallback to perpendicular offset to avoid extreme runaway spike
        vNew1 = v1 + normal * distance;
      }
    }

    Offset vNew2;
    if (isD2Collinear) {
      // Wall continues along the same straight line: keep v2 as step anchor, insert new corner
      vNew2 = v2 + normal * distance;
    } else {
      // Adjacent edge is at an angle or perpendicular: intersect with offset edge line
      final proj2 =
          (d2.dx * normal.dx + d2.dy * normal.dy) / (len2 > 1e-6 ? len2 : 1.0);
      if (proj2.abs() >= 0.20) {
        final t2 = distance / (proj2 * len2);
        vNew2 = v2 + d2 * t2;
      } else {
        vNew2 = v2 + normal * distance;
      }
    }

    final newPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      if (i == edgeIndex) {
        if (isD1Collinear) {
          newPts.add(v1);
        }
        newPts.add(vNew1);
        newPts.add(vNew2);
        if (isD2Collinear) {
          newPts.add(v2);
        }
      } else if (i == (edgeIndex + 1) % n) {
        continue;
      } else {
        newPts.add(polygon[i]);
      }
    }

    final cleanedPts = cleanPolygon(newPts, minDistance: minDistanceCad);
    if (cleanedPts.length >= 3 && !hasSelfIntersections(cleanedPts)) {
      final newArea = BimPolygonGeometry.signedArea(cleanedPts).abs();
      if (newArea > 1e-4) {
        return cleanedPts;
      }
    }

    // Fallback: parallel offset without runaway miters
    final fallbackPts = <Offset>[];
    final fbNew1 = v1 + normal * distance;
    final fbNew2 = v2 + normal * distance;
    for (int i = 0; i < n; i++) {
      if (i == edgeIndex) {
        if (isD1Collinear) fallbackPts.add(v1);
        fallbackPts.add(fbNew1);
        fallbackPts.add(fbNew2);
        if (isD2Collinear) fallbackPts.add(v2);
      } else if (i == (edgeIndex + 1) % n) {
        continue;
      } else {
        fallbackPts.add(polygon[i]);
      }
    }
    final cleanedFallback = cleanPolygon(
      fallbackPts,
      minDistance: minDistanceCad,
    );
    if (cleanedFallback.length >= 3 && !hasSelfIntersections(cleanedFallback)) {
      return cleanedFallback;
    }

    return polygon;
  }

  static List<Offset>? mergeVertices(
    List<Offset> polygon, {
    required int fromIndex,
    required int toIndex,
    double minDistanceCad = 0.05,
  }) {
    if (polygon.length <= 3) return null;
    if (fromIndex < 0 || fromIndex >= polygon.length) return null;
    if (toIndex < 0 || toIndex >= polygon.length || fromIndex == toIndex) {
      return null;
    }

    final n = polygon.length;
    final bool isAdjacent =
        (fromIndex + 1) % n == toIndex || (toIndex + 1) % n == fromIndex;

    List<Offset> candidate;
    if (isAdjacent) {
      candidate = List<Offset>.from(polygon)..removeAt(fromIndex);
    } else {
      candidate = List<Offset>.from(polygon);
      candidate[fromIndex] = candidate[toIndex];
    }

    final cleaned = cleanPolygon(candidate, minDistance: minDistanceCad);
    if (cleaned.length >= 3 && !hasSelfIntersections(cleaned)) {
      return cleaned;
    }

    // Fallback: direct removal
    final fallback = List<Offset>.from(polygon)..removeAt(fromIndex);
    final cleanedFb = cleanPolygon(fallback, minDistance: minDistanceCad);
    if (cleanedFb.length >= 3 && !hasSelfIntersections(cleanedFb)) {
      return cleanedFb;
    }

    return null;
  }
}
