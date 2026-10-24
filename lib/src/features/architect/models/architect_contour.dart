import 'dart:ui';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';

/// Persistent inner rings use model coordinates, just like the outer contour.
class ArchitectContour {
  static Path path(List<Offset> outer, List<List<Offset>> holes) {
    var result = Path()..addPolygon(outer, true);
    for (final hole in holes) {
      result = Path.combine(
        PathOperation.difference,
        result,
        Path()..addPolygon(hole, true),
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
