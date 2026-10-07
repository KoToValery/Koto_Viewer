import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';

/// Straight glazing/frame strokes are supporting evidence for a wide facade
/// opening, never proof that an arbitrary gap between buildings should close.
class SlabOpeningEvidence {
  static List<(Offset, Offset, String)> collect(DxfDocument doc) {
    final result = <(Offset, Offset, String)>[];
    var visited = 0;
    void visit(
      DxfEntity e,
      Offset Function(Offset) tr,
      String inherited,
      String inheritedType,
      int depth,
    ) {
      if (++visited > 40000 || depth > 8 || e.isPaperSpace) return;
      final layer = e.layer == '0' ? inherited : e.layer;
      var type = (e.lineType ?? 'BYLAYER').toUpperCase();
      if (type == 'BYBLOCK') type = inheritedType;
      if (type == 'BYLAYER') {
        type = (doc.layers[layer]?.lineType ?? 'CONTINUOUS').toUpperCase();
      }
      if (type != 'CONTINUOUS' && type.isNotEmpty) return;
      if (e is DxfInsert) {
        final block = doc.blocks[e.blockName];
        if (block == null) return;
        final angle = e.rotationDeg * math.pi / 180;
        Offset child(Offset p) {
          final v = p - block.basePoint;
          final x = v.dx * e.scaleX, y = v.dy * e.scaleY;
          return tr(
            e.insertPoint +
                Offset(
                  x * math.cos(angle) - y * math.sin(angle),
                  x * math.sin(angle) + y * math.cos(angle),
                ),
          );
        }

        for (final entity in block.entities) {
          visit(entity, child, layer, type, depth + 1);
        }
      } else if (e is DxfLine) {
        result.add((tr(e.p1), tr(e.p2), layer));
      } else if (e is DxfLwPolyline) {
        final count = e.isClosed ? e.vertices.length : e.vertices.length - 1;
        for (var i = 0; i < count; i++) {
          final a = e.vertices[i], b = e.vertices[(i + 1) % e.vertices.length];
          if (a.bulge.abs() < 1e-8) {
            result.add((tr(Offset(a.x, a.y)), tr(Offset(b.x, b.y)), layer));
          }
        }
      }
    }

    for (final e in doc.layoutEntities['Model'] ?? doc.entities) {
      visit(e, (p) => p, '0', 'CONTINUOUS', 0);
    }
    return result;
  }

  static bool supports(
    List<(Offset, Offset, String)> strokes,
    Offset start,
    Offset end,
    double thickness,
    double scale,
  ) {
    final length = (end - start).distance;
    if (length <= 0) return false;
    final u = (end - start) / length;
    double dot(Offset p) => p.dx * u.dx + p.dy * u.dy;
    double cross(Offset p) => p.dx * u.dy - p.dy * u.dx;
    final candidates = <(double, double, double, String)>[];
    int transverseCount = 0;
    final minStrokeLen = math.min(length * 0.12, 60.0 * scale);
    final maxOffset = thickness / 2 + 120.0 * scale;

    for (final (a, b, layer) in strokes) {
      final v = b - a;
      final vDist = v.distance;
      if (vDist < 10.0 * scale) continue;

      final sinAngle = (cross(v) / vDist).abs();
      final cosAngle = ((v.dx * u.dx + v.dy * u.dy) / vDist).abs();

      final lo = math.min(dot(a - start), dot(b - start));
      final hi = math.max(dot(a - start), dot(b - start));
      final offset = cross((a + b) / 2 - start);

      if (lo < -60.0 * scale ||
          hi > length + 60.0 * scale ||
          offset.abs() > maxOffset) {
        continue;
      }

      // Longitudinal frame / glazing stroke (aligned with opening axis within ~10 deg)
      if (sinAngle <= 0.174 && vDist >= minStrokeLen) {
        candidates.add((lo, hi, offset, layer));
      }
      // Transverse stroke (mullion / profile / делител)
      else if (cosAngle <= 0.25 && vDist >= 20.0 * scale && vDist <= thickness * 1.5) {
        transverseCount++;
      }

      if (candidates.length > 500) break;
    }

    if (candidates.length < 2) return false;

    // Check 1: Pair of parallel frame / glazing strokes (Archicad 2D or standard CAD window)
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        final a = candidates[i], b = candidates[j];
        final separation = (a.$3 - b.$3).abs();
        final overlap = math.min(a.$2, b.$2) - math.max(a.$1, b.$1);
        if (separation >= 5.0 * scale &&
            separation <= 150.0 * scale &&
            overlap >= 0.25 * length) {
          return true;
        }
      }
    }

    // Check 2: Multi-sash window / vitrina coverage (handles 3-4m openings divided into sashes)
    final strokesByLayer = <String, List<(double, double)>>{};
    for (final c in candidates) {
      strokesByLayer.putIfAbsent(c.$4, () => []).add((c.$1, c.$2));
    }
    for (final spans in strokesByLayer.values) {
      if (spans.length < 2) continue;
      spans.sort((a, b) => a.$1.compareTo(b.$1));
      double totalCovered = 0.0;
      double curStart = spans.first.$1;
      double curEnd = spans.first.$2;
      for (int k = 1; k < spans.length; k++) {
        final next = spans[k];
        if (next.$1 <= curEnd + 30.0 * scale) {
          curEnd = math.max(curEnd, next.$2);
        } else {
          totalCovered += math.max(0.0, curEnd - curStart);
          curStart = next.$1;
          curEnd = next.$2;
        }
      }
      totalCovered += math.max(0.0, curEnd - curStart);

      // 35% longitudinal coverage is conclusive for multi-sash vitrines
      if (totalCovered >= 0.35 * length) {
        return true;
      }
      // 20% coverage with at least 1 transverse mullion / frame profile tick
      if (totalCovered >= 0.20 * length && transverseCount >= 1) {
        return true;
      }
    }

    return false;
  }
}
