import 'dart:ui';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import 'architect_wall_arc.dart';

/// Persistent inner rings use model coordinates, just like the outer contour.
class ArchitectContour {
  static Path ringPath(List<Offset> pts, {List<double>? bulges}) {
    final path = Path();
    if (pts.isEmpty) return path;
    if (bulges == null || !bulges.any((b) => b.abs() > 1e-6)) {
      path.addPolygon(pts, true);
      return path;
    }
    path.moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length; i++) {
      final p1 = pts[i];
      final p2 = pts[(i + 1) % pts.length];
      final b = i < bulges.length ? bulges[i] : 0.0;
      if (b.abs() > 1e-6) {
        final arc = ArchitectWallArc(p1, p2, b);
        final arcPts = arc.arcPoints();
        for (var j = 1; j < arcPts.length; j++) {
          path.lineTo(arcPts[j].dx, arcPts[j].dy);
        }
      } else {
        path.lineTo(p2.dx, p2.dy);
      }
    }
    path.close();
    return path;
  }

  static List<Offset> tessellate(List<Offset> polygon, [List<double>? bulges]) {
    if (polygon.isEmpty) return const [];
    if (bulges == null || !bulges.any((b) => b.abs() > 1e-6)) {
      return polygon;
    }
    final result = <Offset>[];
    for (var i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      final b = i < bulges.length ? bulges[i] : 0.0;
      if (b.abs() > 1e-6) {
        final arc = ArchitectWallArc(p1, p2, b);
        final pts = arc.arcPoints();
        for (var j = 0; j < pts.length - 1; j++) {
          result.add(pts[j]);
        }
      } else {
        result.add(p1);
      }
    }
    return result;
  }

  static Path path(
    List<Offset> outer,
    List<List<Offset>> holes, {
    List<double>? bulges,
    List<List<double>>? holeBulges,
  }) {
    var result = ringPath(outer, bulges: bulges);
    for (var i = 0; i < holes.length; i++) {
      final hole = holes[i];
      final hb = (holeBulges != null && i < holeBulges.length) ? holeBulges[i] : null;
      result = Path.combine(
        PathOperation.difference,
        result,
        ringPath(hole, bulges: hb),
      );
    }
    return result;
  }

  static List<List<Offset>> read(dynamic json) => [
    for (final ring in json as List? ?? const [])
      [
        for (final p in ring as List)
          Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
      ],
  ];
  static List<dynamic> write(List<List<Offset>> holes) => [
    for (final ring in holes)
      [
        for (final p in ring) {'x': p.dx, 'y': p.dy},
      ],
  ];
  static List<List<Offset>> transform(
    List<List<Offset>> holes,
    Offset Function(Offset) transform,
  ) => [for (final ring in holes) ring.map(transform).toList()];

  /// Reject touching/crossing rings, including edges escaping a concave host.
  static bool canAdd(
    List<Offset> outer,
    List<List<Offset>> holes,
    List<Offset> hole,
  ) {
    if (!BimPolygonGeometry.valid(outer) || !BimPolygonGeometry.valid(hole)) {
      return false;
    }
    bool touches(List<Offset> a, List<Offset> b) {
      for (var i = 0; i < a.length; i++) {
        for (var j = 0; j < b.length; j++) {
          if (BimPolygonGeometry.segmentsIntersect(
            a[i],
            a[(i + 1) % a.length],
            b[j],
            b[(j + 1) % b.length],
          )) {
            return true;
          }
        }
      }
      return false;
    }

    return hole.every((p) => BimPolygonGeometry.contains(outer, p)) &&
        !touches(outer, hole) &&
        !holes.any(
          (h) =>
              touches(h, hole) ||
              BimPolygonGeometry.contains(h, hole.first) ||
              BimPolygonGeometry.contains(hole, h.first),
        );
  }

  static bool valid(List<Offset> outer, List<List<Offset>> holes) {
    final accepted = <List<Offset>>[];
    for (final hole in holes) {
      if (!canAdd(outer, accepted, hole)) return false;
      accepted.add(hole);
    }
    return BimPolygonGeometry.valid(outer);
  }

  static double area(List<List<Offset>> holes) =>
      holes.fold(0.0, (sum, h) => sum + BimPolygonGeometry.signedArea(h).abs());
}
