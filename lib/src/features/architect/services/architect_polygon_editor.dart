import 'dart:ui';
import '../../bim_editing/interaction/bim_polygon_editor.dart';
import '../rendering/architect_snap_helper.dart';
export '../../bim_editing/interaction/bim_polygon_editor.dart';

class ArchitectPolygonEditor extends BimPolygonEditor<ArchitectSnapResult> {
  ArchitectPolygonEditor()
    : super(pointOf: (snap) => snap.point, isSnapped: (snap) => snap.isSnapped);

  /// Zero is the outer boundary, subsequent indices identify inner rings.
  /// Actual contours take priority over displaced handles on nearby rings.
  static int? hitContour(
    List<Offset> outer,
    List<List<Offset>> holes,
    Offset point,
    double scale, {
    double offsetLengthPx = 50,
  }) {
    final rings = [outer, ...holes];
    int? hit;
    var best = 18 / scale;
    for (var r = 0; r < rings.length; r++) {
      final ring = rings[r];
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i], d = ring[(i + 1) % ring.length] - a;
        if (d.distanceSquared < 1e-12) continue;
        final t =
            (((point - a).dx * d.dx + (point - a).dy * d.dy) /
                    d.distanceSquared)
                .clamp(0.0, 1.0);
        final distance = (point - a - d * t).distance;
        if (distance <= best) {
          best = distance;
          hit = r;
        }
      }
    }
    if (hit != null || offsetLengthPx <= 0) return hit;
    best = 48 / scale;
    for (var r = 0; r < rings.length; r++) {
      for (var i = 0; i < rings[r].length; i++) {
        for (final handle in [
          offsetVertexHandle(rings[r], i, scale, offsetLengthPx),
          offsetEdgeHandle(rings[r], i, scale, offsetLengthPx),
        ]) {
          final distance = (point - handle).distance;
          if (distance < best) {
            best = distance;
            hit = r;
          }
        }
      }
    }
    return hit;
  }

  static Offset vertexNormal(List<Offset> polygon, int i) =>
      BimPolygonEditor.vertexNormal(polygon, i);
  static Offset offsetVertexHandle(
    List<Offset> polygon,
    int i,
    double scale, [
    double offsetLengthPx = 50.0,
  ]) => BimPolygonEditor.offsetVertexHandle(polygon, i, scale, offsetLengthPx);
  static Offset offsetEdgeHandle(
    List<Offset> polygon,
    int i,
    double scale, [
    double offsetLengthPx = 50.0,
  ]) => BimPolygonEditor.offsetEdgeHandle(polygon, i, scale, offsetLengthPx);
}
