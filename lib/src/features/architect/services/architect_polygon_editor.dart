import 'dart:ui';
import '../rendering/architect_snap_helper.dart';
import 'architect_polygon_geometry.dart';

/// One gesture controller for rectangles and slabs. Model commands own Undo.
class ArchitectPolygonEditor {
  String? elementId;
  List<Offset>? original, preview;
  int? index;
  bool edge = false, invalid = false;
  ArchitectSnapResult? activeSnap;
  Offset grabOffset = Offset.zero;
  bool get active => elementId != null;

  bool start(String id, List<Offset> polygon, Offset raw, double scale) {
    if (!ArchitectPolygonGeometry.valid(polygon)) return false;
    final radius = 16 / scale;
    int? hit;
    var best = radius;
    for (var i = 0; i < polygon.length; i++) {
      final d = (raw - polygon[i]).distance;
      if (d < best) {
        hit = i;
        best = d;
      }
    }
    edge = false;
    // Closest handle wins even on short segments with overlapping touch areas.
    for (var i = 0; i < polygon.length; i++) {
      final p = (polygon[i] + polygon[(i + 1) % polygon.length]) / 2;
      final d = (raw - p).distance;
      if (d < best - 1e-9) {
        hit = i;
        best = d;
        edge = true;
      }
    }
    if (hit == null) return false;
    elementId = id;
    original = List.of(polygon);
    preview = List.of(polygon);
    index = hit;
    final handle = edge
        ? (polygon[hit] + polygon[(hit + 1) % polygon.length]) / 2
        : polygon[hit];
    grabOffset = handle - raw;
    invalid = false;
    return true;
  }

  void update(
    Offset raw,
    ArchitectSnapResult Function(Offset) snap,
    double mergeRadius,
  ) {
    if (!active) return;
    final polygon = original!, i = index!, target = raw + grabOffset;
    List<Offset>? next;
    if (edge) {
      final n = ArchitectPolygonGeometry.normal(polygon, i);
      final midpoint = (polygon[i] + polygon[(i + 1) % polygon.length]) / 2;
      final distance = ArchitectPolygonGeometry.dot(target - midpoint, n);
      var correctionDistance = 0.0;
      activeSnap = null;
      // Align either moving endpoint or midpoint, while preserving the edge direction.
      var best = double.infinity;
      for (final p in [
        polygon[i],
        polygon[(i + 1) % polygon.length],
        midpoint,
      ]) {
        final moving = p + n * distance;
        final result = snap(moving);
        if (!result.isSnapped) continue;
        final correction = result.point - moving;
        final along = ArchitectPolygonGeometry.dot(correction, n);
        if ((correction - n * along).distance > 1e-7 || along.abs() >= best) {
          continue;
        }
        best = along.abs();
        correctionDistance = along;
        activeSnap = result;
      }
      next = ArchitectPolygonGeometry.pullEdge(
        polygon,
        i,
        distance + correctionDistance,
      );
    } else {
      activeSnap = snap(target);
      var point = activeSnap!.point;
      for (final neighbor in [
        (i - 1 + polygon.length) % polygon.length,
        (i + 1) % polygon.length,
      ]) {
        if ((target - polygon[neighbor]).distance <= mergeRadius) {
          point = polygon[neighbor];
        }
      }
      next = ArchitectPolygonGeometry.moveVertex(polygon, i, point);
    }
    invalid = next == null;
    if (invalid) activeSnap = null;
    if (next != null) preview = next;
  }

  void cancel() {
    elementId = null;
    original = null;
    preview = null;
    index = null;
    invalid = false;
    activeSnap = null;
  }
}
