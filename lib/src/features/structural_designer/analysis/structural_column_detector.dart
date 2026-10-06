import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/wall_axis_models.dart';

/// Represents a detected structural column or shear wall (колона или шайба).
class DetectedStructuralColumn {
  /// Vertices of the column's closed boundary in CAD coordinates.
  final List<Offset> polygon;

  /// Axis-aligned bounding box.
  final Rect bounds;

  /// Dimension along primary/width axis (in CAD units).
  final double width;

  /// Dimension along secondary/length axis (in CAD units).
  final double height;

  /// Source layer in the CAD document.
  final String sourceLayer;

  /// Whether this element has elongated dimensions typical for a shear wall (шайба).
  final bool isShearWall;

  const DetectedStructuralColumn({
    required this.polygon,
    required this.bounds,
    required this.width,
    required this.height,
    required this.sourceLayer,
    this.isShearWall = false,
  });

  /// Boundary segments of the column perimeter.
  List<(Offset, Offset)> get boundarySegments {
    final segments = <(Offset, Offset)>[];
    if (polygon.length < 3) return segments;
    for (int i = 0; i < polygon.length; i++) {
      segments.add((polygon[i], polygon[(i + 1) % polygon.length]));
    }
    return segments;
  }
}

/// Geometric detector for structural columns and shear walls (колони и шайби).
///
/// Features:
/// 1. Primary: Pure geometric discovery without requiring hardcoded layer names.
///    Identifies closed rectangular/convex loops with cross-section dimensions:
///    - Thickness 140 mm to 650 mm (standard columns & shear walls).
///    - Length up to 2600 mm (aspect ratio 1:1 up to 1:10).
/// 2. Spatial wall correlation:
///    Confirms candidate as structural if a wall terminates at it, passes through it,
///    or forms an L-corner/T-junction at it.
/// 3. Rejects interior furniture geometrically (walls do not terminate at furniture).
/// 4. Secondary fallback: Recognizes column & shear wall keywords across Cyrillic and Latin.
class StructuralColumnDetector {
  const StructuralColumnDetector._();

  /// Expanded keywords for fallback detection when layer names are conventional.
  static const List<String> fallbackKeywords = [
    // Bulgarian (Cyrillic)
    'колона', 'колони', 'шайба', 'шайби',
    'стб', 'сб', 'к-', 'ш-', 'к_', 'ш_',
    // Bulgarian (Latinized / Transliterated)
    'kolona', 'koloni', 'shaiba', 'shayba', 'stb',
    // English
    'column', 'columns', 'col', 'cols',
    'pillar', 'pillars', 'shear', 'shearwall', 'shear_wall',
    'rc_col', 'rc_wall',
  ];

  /// Checks if a layer name matches any known column or shear wall keywords.
  static bool matchesColumnKeyword(String layerName) {
    final lower = layerName.trim().toLowerCase();
    for (final kw in fallbackKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  /// Detects all structural columns and shear walls in [document].
  static List<DetectedStructuralColumn> detect(
    DxfDocument document, {
    required List<WallPairCandidate> wallPairs,
    required double scale,
  }) {
    if (!scale.isFinite || scale <= 0) return const [];

    final candidates = <(List<Offset> poly, Rect bounds, String layer)>[];

    // Tolerance thresholds scaled to drawing units
    final minThickCad = 190.0 * scale; // 19 cm (standard structural columns >= 20 cm)
    final maxThickCad = 650.0 * scale; // 65 cm
    final maxLenCad = 2600.0 * scale;  // 2.6 m
    final maxAspectRatio = 10.0;

    void evaluateLoop(List<Offset> rawPoly, String layer) {
      if (rawPoly.length < 3) return;

      // Clean duplicate consecutive points
      final poly = <Offset>[];
      for (final pt in rawPoly) {
        if (poly.isEmpty || (poly.last - pt).distance > 1e-4) {
          poly.add(pt);
        }
      }
      if (poly.length >= 3 && (poly.first - poly.last).distance < 1e-4) {
        poly.removeLast();
      }
      if (poly.length < 3 || poly.length > 12) return;

      var minX = double.infinity, maxX = -double.infinity;
      var minY = double.infinity, maxY = -double.infinity;
      for (final p in poly) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      final w = maxX - minX;
      final h = maxY - minY;

      double dimMin, dimMax;
      if (poly.length == 4) {
        // Oriented side lengths for rectangles
        final s1 = (poly[1] - poly[0]).distance;
        final s2 = (poly[2] - poly[1]).distance;
        dimMin = math.min(s1, s2);
        dimMax = math.max(s1, s2);
      } else {
        dimMin = math.min(w, h);
        dimMax = math.max(w, h);
      }

      if (dimMin < minThickCad || dimMin > maxThickCad || dimMax > maxLenCad) {
        return;
      }

      if (dimMin > 0 && (dimMax / dimMin) > maxAspectRatio) {
        return;
      }

      candidates.add((poly, Rect.fromLTRB(minX, minY, maxX, maxY), layer));
    }

    final entities = document.layoutEntities['Model'] ?? document.entities;

    // 1. Scan closed LWPOLYLINE and POLYLINE entities
    for (final e in entities) {
      if (e.isPaperSpace) continue;
      if (e is DxfLwPolyline && e.isClosed) {
        evaluateLoop(e.vertices.map((v) => Offset(v.x, v.y)).toList(), e.layer);
      } else if (e is DxfPolyline && e.isClosed) {
        evaluateLoop(e.vertices.map((v) => Offset(v.x, v.y)).toList(), e.layer);
      }
    }

    // 2. Scan block inserts for column definitions
    for (final e in entities) {
      if (e.isPaperSpace || e is! DxfInsert) continue;
      final block = document.blocks[e.blockName];
      if (block == null) continue;

      final angle = e.rotationDeg * math.pi / 180.0;
      Offset transform(Offset p) {
        final v = p - block.basePoint;
        final x = v.dx * e.scaleX;
        final y = v.dy * e.scaleY;
        return e.insertPoint + Offset(
          x * math.cos(angle) - y * math.sin(angle),
          x * math.sin(angle) + y * math.cos(angle),
        );
      }

      for (final child in block.entities) {
        if (child is DxfLwPolyline && child.isClosed) {
          evaluateLoop(child.vertices.map((v) => transform(Offset(v.x, v.y))).toList(), e.layer);
        } else if (child is DxfPolyline && child.isClosed) {
          evaluateLoop(child.vertices.map((v) => transform(Offset(v.x, v.y))).toList(), e.layer);
        }
      }
    }

    // 3. Assemble 4-line closed loops on column layers or where walls terminate
    _assembleLineLoops(entities, evaluateLoop, scale);

    final confirmed = <DetectedStructuralColumn>[];
    final tol = 25.0 * scale; // 2.5 cm tolerance for wall contact

    for (final (poly, bounds, layer) in candidates) {
      final inflated = bounds.inflate(tol);

      int terminatingWalls = 0;
      bool wallOverlapsOrCrosses = false;

      final minWallLength = 350.0 * scale; // 35 cm: real structural walls, rejects furniture chair backrests
      for (final wp in wallPairs) {
        final wallLen = (wp.centerlineEnd - wp.centerlineStart).distance;
        if (wallLen < minWallLength) continue;

        final startIn = inflated.contains(wp.centerlineStart);
        final endIn = inflated.contains(wp.centerlineEnd);

        // Wall terminates at/inside this column
        if (startIn ^ endIn) {
          terminatingWalls++;
        }

        // Wall passes through or overlaps this column
        if (!startIn && !endIn) {
          final a = wp.centerlineStart, b = wp.centerlineEnd;
          if (inflated.overlaps(Rect.fromPoints(a, b))) {
            final mid = (a + b) / 2.0;
            if (bounds.contains(mid) ||
                (a.dx <= bounds.right && b.dx >= bounds.left && (a.dy - bounds.center.dy).abs() <= wp.perpendicularDistance / 2) ||
                (a.dy <= bounds.bottom && b.dy >= bounds.top && (a.dx - bounds.center.dx).abs() <= wp.perpendicularDistance / 2)) {
              final w = bounds.width, h = bounds.height;
              if ((wp.perpendicularDistance - w).abs() <= 60.0 * scale ||
                  (wp.perpendicularDistance - h).abs() <= 60.0 * scale) {
                wallOverlapsOrCrosses = true;
              }
            }
          }
        }
      }

      final isKeywordMatch = matchesColumnKeyword(layer);

      // Geometric confirmation: terminates wall or overlaps wall, OR keyword match fallback
      if (terminatingWalls > 0 || wallOverlapsOrCrosses || isKeywordMatch) {
        // Deduplicate overlapping candidate boxes
        final alreadyPresent = confirmed.any((c) =>
            (c.bounds.center - bounds.center).distance <= 20.0 * scale &&
            (c.width - bounds.width).abs() <= 20.0 * scale &&
            (c.height - bounds.height).abs() <= 20.0 * scale);

        if (!alreadyPresent) {
          final w = bounds.width;
          final h = bounds.height;
          final dimMin = math.min(w, h);
          final dimMax = math.max(w, h);
          final isShear = (dimMin > 0 && dimMax / dimMin >= 2.0) || dimMax >= 600.0 * scale;

          confirmed.add(
            DetectedStructuralColumn(
              polygon: poly,
              bounds: bounds,
              width: w,
              height: h,
              sourceLayer: layer,
              isShearWall: isShear,
            ),
          );
        }
      }
    }

    return confirmed;
  }

  /// Assembles connected 4-line loops that form a closed rectangle.
  static void _assembleLineLoops(
    Iterable<DxfEntity> entities,
    void Function(List<Offset> poly, String layer) onLoop,
    double scale,
  ) {
    // Group lines by layer
    final linesByLayer = <String, List<DxfLine>>{};
    for (final e in entities) {
      if (e is DxfLine && !e.isPaperSpace) {
        linesByLayer.putIfAbsent(e.layer, () => []).add(e);
      }
    }

    final snapDist = 5.0 * scale;

    for (final entry in linesByLayer.entries) {
      final lines = entry.value;
      if (lines.length < 4 || lines.length > 500) continue;

      // Only attempt line assembly on layers matching keywords or with small line counts
      if (!matchesColumnKeyword(entry.key) && lines.length > 100) continue;

      for (int i = 0; i < lines.length; i++) {
        final l1 = lines[i];
        for (int j = i + 1; j < lines.length; j++) {
          final l2 = lines[j];
          if ((l1.p2 - l2.p1).distance > snapDist &&
              (l1.p2 - l2.p2).distance > snapDist &&
              (l1.p1 - l2.p1).distance > snapDist &&
              (l1.p1 - l2.p2).distance > snapDist) {
            continue;
          }
          for (int k = j + 1; k < lines.length; k++) {
            final l3 = lines[k];
            for (int m = k + 1; m < lines.length; m++) {
              final l4 = lines[m];
              final pts = _tryOrderBox(l1, l2, l3, l4, snapDist);
              if (pts != null) {
                onLoop(pts, entry.key);
              }
            }
          }
        }
      }
    }
  }

  static List<Offset>? _tryOrderBox(
    DxfLine l1,
    DxfLine l2,
    DxfLine l3,
    DxfLine l4,
    double snapDist,
  ) {
    final list = [l1, l2, l3, l4];
    final ordered = <Offset>[l1.p1, l1.p2];
    final remaining = [l2, l3, l4];

    for (int step = 0; step < 3; step++) {
      final tail = ordered.last;
      int matchIdx = -1;
      bool reverse = false;
      for (int i = 0; i < remaining.length; i++) {
        if ((remaining[i].p1 - tail).distance <= snapDist) {
          matchIdx = i;
          reverse = false;
          break;
        } else if ((remaining[i].p2 - tail).distance <= snapDist) {
          matchIdx = i;
          reverse = true;
          break;
        }
      }
      if (matchIdx == -1) return null;
      final match = remaining.removeAt(matchIdx);
      ordered.add(reverse ? match.p1 : match.p2);
    }

    if ((ordered.last - ordered.first).distance <= snapDist) {
      return ordered.sublist(0, 4);
    }
    return null;
  }
}
