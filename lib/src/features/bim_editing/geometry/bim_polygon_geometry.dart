import 'dart:ui';

enum BimPolygonEdgeMode { pull, move }

/// Shared contour editing for planar CAD shapes and volumetric slabs.
class BimPolygonGeometry {
  static const epsilon = 1e-8;
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  static double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

  static List<Offset>? insertMidpoint(List<Offset> polygon, int edge) {
    if (edge < 0 || edge >= polygon.length) return null;
    return List<Offset>.of(polygon)..insert(
      edge + 1,
      (polygon[edge] + polygon[(edge + 1) % polygon.length]) / 2,
    );
  }

  static List<Offset>? removeVertex(List<Offset> polygon, int index) {
    if (polygon.length <= 3 || index < 0 || index >= polygon.length) {
      return null;
    }
    final next = List<Offset>.of(polygon)..removeAt(index);
    return valid(next) ? next : null;
  }

  static bool contains(List<Offset> polygon, Offset point) {
    var inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i], b = polygon[j];
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static double signedArea(List<Offset> polygon) {
    if (polygon.isEmpty) return 0;
    final origin = polygon.first;
    var result = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      result += cross(
        polygon[i] - origin,
        polygon[(i + 1) % polygon.length] - origin,
      );
    }
    return result / 2;
  }

  static Offset normal(List<Offset> polygon, int edge) {
    final u = polygon[(edge + 1) % polygon.length] - polygon[edge];
    if (u.distance < epsilon) return Offset.zero;
    return Offset(u.dy, -u.dx) /
        u.distance *
        (signedArea(polygon) >= 0 ? 1 : -1);
  }

  /// Remove duplicates and backtracking spikes; keep useful collinear vertices
  /// after outward pulls so the original corners remain editable.
  static List<Offset> clean(
    List<Offset> polygon, {
    bool removeCollinear = false,
  }) {
    final points = List<Offset>.from(polygon);
    var changed = true;
    while (changed && points.length >= 3) {
      changed = false;
      for (var i = 0; i < points.length; i++) {
        final previous = points[(i - 1 + points.length) % points.length];
        final current = points[i], next = points[(i + 1) % points.length];
        final incoming = current - previous, outgoing = next - current;
        final collinear =
            cross(incoming, outgoing).abs() <=
            epsilon * (incoming.distance + outgoing.distance);
        if (incoming.distance < epsilon ||
            outgoing.distance < epsilon ||
            (collinear && (dot(incoming, outgoing) < 0 || removeCollinear))) {
          points.removeAt(i);
          changed = true;
          break;
        }
      }
    }
    return points;
  }

  static bool valid(List<Offset> polygon) {
    if (polygon.length < 3 ||
        polygon.length > 2048 ||
        polygon.any((p) => !p.dx.isFinite || !p.dy.isFinite) ||
        signedArea(polygon).abs() < 1e-6) {
      return false;
    }
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      if ((b - a).distance < epsilon) return false;
      for (var j = i + 1; j < polygon.length; j++) {
        if (j == i + 1 || (i == 0 && j == polygon.length - 1)) continue;
        if (_intersects(a, b, polygon[j], polygon[(j + 1) % polygon.length])) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _intersects(Offset a, Offset b, Offset c, Offset d) {
    final u = b - a, v = d - c;
    final den = cross(u, v);
    if (den.abs() > epsilon * u.distance * v.distance) {
      final t = cross(c - a, v) / den, s = cross(c - a, u) / den;
      return t >= -epsilon &&
          t <= 1 + epsilon &&
          s >= -epsilon &&
          s <= 1 + epsilon;
    }
    if (cross(c - a, u).abs() > epsilon * u.distance) return false;
    final first = dot(c - a, u) / u.distanceSquared;
    final second = dot(d - a, u) / u.distanceSquared;
    final low = first < second ? first : second,
        high = first > second ? first : second;
    return high >= -epsilon && low <= 1 + epsilon;
  }

  static List<Offset>? moveVertex(
    List<Offset> polygon,
    int index,
    Offset point,
  ) {
    if (index < 0 || index >= polygon.length) return null;
    final next = clean([...polygon]..[index] = point);
    return valid(next) ? next : null;
  }

  static List<Offset>? pullEdge(
    List<Offset> polygon,
    int edge,
    double distance,
  ) {
    if (edge < 0 || edge >= polygon.length || !distance.isFinite) return null;
    if (distance.abs() < epsilon) return List.of(polygon);
    final a = polygon[edge], b = polygon[(edge + 1) % polygon.length];
    final n = normal(polygon, edge) * distance;
    final next = List<Offset>.from(polygon)
      ..insertAll(edge + 1, [a + n, b + n]);
    // Backtracking removes vertices overtaken by the retracting edge.
    // Collinear old corners still inside the contour remain useful edit points.
    final cleaned = clean(next);
    if (!valid(cleaned) || signedArea(cleaned) * signedArea(polygon) <= 0) {
      return null;
    }
    // An inward pull must remove area; crossing the opposite side cannot flip it.
    if (distance < 0 &&
        signedArea(cleaned).abs() >= signedArea(polygon).abs()) {
      return null;
    }
    return cleaned;
  }

  static List<Offset>? offsetEdge(
    List<Offset> polygon,
    int edge,
    double distance, {
    BimPolygonEdgeMode mode = BimPolygonEdgeMode.pull,
  }) => mode == BimPolygonEdgeMode.move
      ? moveEdge(polygon, edge, distance)
      : pullEdge(polygon, edge, distance);

  /// Translate both endpoints by the same normal displacement. Neighboring
  /// edges follow those endpoints without retaining the old endpoint positions.
  static List<Offset>? moveEdge(
    List<Offset> polygon,
    int edge,
    double distance,
  ) {
    if (polygon.length < 3 ||
        edge < 0 ||
        edge >= polygon.length ||
        !distance.isFinite) {
      return null;
    }
    final next = (edge + 1) % polygon.length;
    final displacement = normal(polygon, edge) * distance;
    final moved = List<Offset>.of(polygon)
      ..[edge] = polygon[edge] + displacement
      ..[next] = polygon[next] + displacement;
    final cleaned = clean(moved);
    if (!valid(cleaned) || signedArea(cleaned) * signedArea(polygon) <= 0) {
      return null;
    }
    return cleaned;
  }
}
