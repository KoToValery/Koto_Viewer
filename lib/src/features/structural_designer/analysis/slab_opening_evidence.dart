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
    return visited > 40000 ? [] : result;
  }

  static bool supports(
    List<(Offset, Offset, String)> strokes,
    Offset start,
    Offset end,
    double thickness,
    double scale,
  ) {
    final length = (end - start).distance,
        u = (end - start) / (end - start).distance;
    double dot(Offset p) => p.dx * u.dx + p.dy * u.dy;
    double cross(Offset p) => p.dx * u.dy - p.dy * u.dx;
    final candidates = <(double, double, double, String)>[];
    for (final (a, b, layer) in strokes) {
      final v = b - a;
      if (v.distance < length * .55 || cross(v).abs() > scale * 5) continue;
      final lo = math.min(dot(a - start), dot(b - start));
      final hi = math.max(dot(a - start), dot(b - start));
      final offset = cross((a + b) / 2 - start);
      if (lo < -50 * scale ||
          hi > length + 50 * scale ||
          offset.abs() > thickness / 2 + 20 * scale) {
        continue;
      }
      candidates.add((lo, hi, offset, layer));
      if (candidates.length > 200) return false;
    }
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        final a = candidates[i], b = candidates[j];
        final separation = (a.$3 - b.$3).abs();
        if (a.$4 == b.$4 &&
            separation >= 5 * scale &&
            separation <= 100 * scale &&
            math.min(a.$2, b.$2) - math.max(a.$1, b.$1) >= .55 * length) {
          return true;
        }
      }
    }
    return false;
  }
}
