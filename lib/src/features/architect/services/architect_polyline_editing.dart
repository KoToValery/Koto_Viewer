import 'dart:ui';

/// Shared geometry for painting and picking the grips of an open CAD path.
class ArchitectPolylineEditing {
  static List<Offset> moveVertex(
    List<Offset> points,
    int index,
    Offset target,
  ) {
    final result = List<Offset>.of(points)..[index] = target;
    // A path explicitly returned to its first point has one shared end vertex.
    if (points.first == points.last &&
        (index == 0 || index == points.length - 1)) {
      result[0] = result[result.length - 1] = target;
    }
    return result;
  }

  /// Translate a segment's shared vertices atomically. Adjacent segments reuse
  /// those vertices and can never detach as a side effect of a drag.
  static List<Offset> moveEdge(List<Offset> points, int index, Offset delta) {
    if (index < 0 || index + 1 >= points.length)
      throw ArgumentError('Missing segment');
    var result = moveVertex(points, index, points[index] + delta);
    result = moveVertex(result, index + 1, points[index + 1] + delta);
    return result;
  }

  static Offset edgeHandle(
    List<Offset> points,
    int index,
    double scale,
    double offsetLengthPx,
  ) {
    final a = points[index], b = points[index + 1], v = b - a;
    return (a + b) / 2 +
        (v.distance < 1e-10 ? Offset.zero : Offset(-v.dy, v.dx) / v.distance) *
            (offsetLengthPx / scale);
  }

  static (int, bool)? hitEdge(
    List<Offset> points,
    Offset point,
    double scale,
    double offsetLengthPx,
  ) {
    if (points.any((p) => (p - point).distance < 18 / scale)) return null;
    var best = 12 / scale;
    (int, bool)? result;
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], v = points[i + 1] - a;
      if (v.distanceSquared < 1e-10) continue;
      final t =
          (((point - a).dx * v.dx + (point - a).dy * v.dy) / v.distanceSquared)
              .clamp(0.0, 1.0);
      final distance = (point - a - v * t).distance;
      if (distance < best) {
        best = distance;
        result = (i, false);
      }
    }
    if (result != null || offsetLengthPx <= 0) return result;
    best = 18 / scale;
    for (var i = 0; i + 1 < points.length; i++) {
      final distance =
          (point - edgeHandle(points, i, scale, offsetLengthPx)).distance;
      if (distance < best) {
        best = distance;
        result = (i, true);
      }
    }
    return result;
  }

  static Offset handle(
    List<Offset> points,
    int index,
    double scale,
    double offsetLengthPx,
  ) {
    final point = points[index];
    Offset unit(Offset v) => v.distance < 1e-9 ? Offset.zero : v / v.distance;
    final Offset direction;
    if (index == 0) {
      direction = unit(point - points[1]);
    } else if (index == points.length - 1) {
      direction = unit(point - points[index - 1]);
    } else {
      final incoming = unit(point - points[index - 1]);
      final outgoing = unit(points[index + 1] - point);
      final outward = incoming - outgoing;
      direction = outward.distance < 1e-6
          ? Offset(incoming.dy, -incoming.dx)
          : unit(outward);
    }
    return point + direction * (offsetLengthPx / scale);
  }

  /// Direct vertices take priority; the returned flag identifies a leader grip.
  static (int, bool)? hit(
    List<Offset> points,
    Offset point,
    double scale,
    double offsetLengthPx,
  ) {
    (int, bool)? result;
    var best = 18 / scale;
    for (var i = 0; i < points.length; i++) {
      final distance = (point - points[i]).distance;
      if (distance <= best) {
        best = distance;
        result = (i, false);
      }
    }
    if (result != null || offsetLengthPx <= 0) return result;
    best = 28 / scale;
    for (var i = 0; i < points.length; i++) {
      final distance =
          (point - handle(points, i, scale, offsetLengthPx)).distance;
      if (distance <= best) {
        best = distance;
        result = (i, true);
      }
    }
    return result;
  }
}
