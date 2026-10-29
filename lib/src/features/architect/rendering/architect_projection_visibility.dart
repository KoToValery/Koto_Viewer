import 'dart:ui' show Offset, Rect;
import 'package:clipper2/clipper2.dart' as clip;
import '../../cad_3d/models/mesh_3d.dart' show Vector3;

typedef ProjectionTriangle = ({
  Vector3 a,
  Vector3 b,
  Vector3 c,
  int? color,
  String? source,
  String? silhouette,
});
typedef ProjectionAperture = ({String id, List<Vector3> points});

/// Only value objects cross the isolate boundary. No Path, Canvas, image,
/// project controller, or widget is captured by the visibility calculation.
class ArchitectProjectionRequest {
  final List<ProjectionTriangle> triangles;
  final Offset centre, right, forward;
  final double length;
  final double? depth;
  final List<List<Offset>> masks;
  final List<ProjectionAperture> apertures;
  const ArchitectProjectionRequest({
    required this.triangles,
    required this.centre,
    required this.right,
    required this.forward,
    required this.length,
    required this.depth,
    required this.masks,
    required this.apertures,
  });
}

class ArchitectProjectionContours {
  final List<List<List<Offset>>> faces;
  final Map<String, List<List<Offset>>> elements;
  final List<List<List<Offset>>> apertures;
  final Rect? bounds;
  const ArchitectProjectionContours(
    this.faces,
    this.elements,
    this.apertures,
    this.bounds,
  );
}

/// Shared by synchronous export/tests and the interactive background worker.
ArchitectProjectionContours solveArchitectProjection(
  ArchitectProjectionRequest input,
) {
  final groups = <String, _Plane>{};
  Vector3 project(Vector3 p) {
    final delta = Offset(p.x, p.y) - input.centre;
    return Vector3(
      delta.dx * input.right.dx + delta.dy * input.right.dy,
      p.z,
      delta.dx * input.forward.dx + delta.dy * input.forward.dy,
    );
  }

  List<Vector3> crop(List<Vector3> polygon) {
    var result = _clip3(polygon, (p) => p.z);
    if (input.depth != null) result = _clip3(result, (p) => input.depth! - p.z);
    result = _clip3(result, (p) => p.x + input.length / 2);
    return _clip3(result, (p) => input.length / 2 - p.x);
  }

  for (final triangle in input.triangles) {
    final a = project(triangle.a),
        b = project(triangle.b),
        c = project(triangle.c);
    final normal = (b - a).cross(c - a);
    if (normal.z.abs() < 1e-10) continue;
    final u = -normal.x / normal.z, v = -normal.y / normal.z;
    final w = a.z - u * a.x - v * a.y;
    final polygon = crop([a, b, c]);
    if (polygon.length < 3) continue;
    final points = [for (final p in polygon) Offset(p.x, p.y)];
    if (!_hasArea(points)) continue;
    final key =
        '${(u * 1e6).round()}:${(v * 1e6).round()}:${(w * 1e6).round()}:${triangle.color}:${triangle.silhouette ?? ''}';
    final plane = groups.putIfAbsent(
      key,
      () => _Plane(u, v, w, triangle.silhouette),
    );
    plane.add(points, triangle.source);
  }
  final index = _OcclusionIndex(groups.values.toList());
  final masks = [
    for (final mask in input.masks)
      if (_hasArea(mask)) (mask, _bounds(mask)),
  ];
  List<clip.PointD> clipPoints(List<Offset> p) => [
    for (final v in _area(p) < 0 ? p.reversed : p) clip.PointD(v.dx, v.dy),
  ];
  List<List<clip.PointD>> visible(
    _Plane face, {
    String? onlySource,
    String? ignoreSource,
  }) {
    final subjects = [
      for (final p in face.pieces)
        if (onlySource == null || p.source == onlySource) p.points,
    ];
    if (subjects.isEmpty) return [];
    final cutters = <List<Offset>>[];
    for (final other in index.overlapping(face.bounds)) {
      if (identical(face, other) ||
          face.silhouette != null && face.silhouette == other.silhouette) {
        continue;
      }
      for (final p in other.pieces) {
        if (ignoreSource != null && p.source == ignoreSource) continue;
        final mask = _clip2(
          p.points,
          (p) => face.depth(p) - other.depth(p) - 1e-7,
        );
        if (_hasArea(mask) && face.bounds.overlaps(_bounds(mask))) {
          cutters.add(mask);
        }
      }
    }
    for (final (mask, bounds) in masks) {
      if (face.bounds.overlaps(bounds)) cutters.add(mask);
    }
    final engine = clip.ClipperD(roundingDecimalPrecision: 8)
      ..preserveCollinear = false
      ..addSubjects([
        for (final p in subjects)
          if (_hasArea(p)) clipPoints(p),
      ])
      ..addClips([for (final p in cutters) clipPoints(p)]);
    final result = engine.executeClosed(
      clip.ClipType.difference,
      clip.FillRule.nonZero,
    );
    if (result == null) {
      throw StateError('Architectural visibility clipping failed');
    }
    return result;
  }

  List<List<Offset>> offsets(List<List<clip.PointD>> contours) => [
    for (final loop in contours) [for (final p in loop) Offset(p.x, p.y)],
  ];
  List<List<clip.PointD>> union(List<List<clip.PointD>> contours) {
    final engine = clip.ClipperD(roundingDecimalPrecision: 8)
      ..preserveCollinear = false
      ..addSubjects(contours);
    final result = engine.executeClosed(
      clip.ClipType.union,
      clip.FillRule.nonZero,
    );
    if (result == null) throw StateError('Element silhouette union failed');
    return result;
  }

  final faces = <List<List<Offset>>>[];
  final silhouettes = <String, List<List<clip.PointD>>>{};
  final sourceContours = <String, List<List<clip.PointD>>>{};
  Rect? bounds;
  for (final face in groups.values) {
    final contours = visible(face);
    if (contours.isEmpty) continue;
    final polygons = offsets(contours);
    for (final polygon in polygons) {
      final box = _bounds(polygon);
      bounds = bounds?.expandToInclude(box) ?? box;
    }
    if (face.silhouette == null) {
      faces.add(polygons);
    } else {
      (silhouettes[face.silhouette!] ??= []).addAll(contours);
    }
    for (final source in face.sources) {
      final pieces = face.sources.length == 1
          ? contours
          : visible(face, onlySource: source);
      (sourceContours[source] ??= []).addAll(pieces);
    }
  }
  for (final entry in silhouettes.entries) {
    if (entry.value.isEmpty) continue;
    var contours = union(entry.value);
    if (entry.key.startsWith('construction:')) {
      contours = clip.Clipper.inflatePathsD(
        paths: contours,
        delta: .00001,
        joinType: clip.JoinType.miter,
        endType: clip.EndType.polygon,
        precision: 7,
      );
      contours = clip.Clipper.inflatePathsD(
        paths: contours,
        delta: -.00001,
        joinType: clip.JoinType.miter,
        endType: clip.EndType.polygon,
        precision: 7,
      );
    }
    if (contours.isNotEmpty) faces.add(offsets(contours));
  }
  final elements = <String, List<List<Offset>>>{
    for (final entry in sourceContours.entries)
      entry.key: offsets(union(entry.value)),
  };
  final apertures = <List<List<Offset>>>[];
  for (final aperture in input.apertures) {
    final a = aperture.points.first, b = aperture.points[1];
    if ((b.x - a.x).abs() < 1e-6) {
      apertures.add([]);
      continue;
    }
    final polygon = crop(aperture.points);
    if (polygon.length < 3) {
      apertures.add([]);
      continue;
    }
    final u = (b.z - a.z) / (b.x - a.x);
    final plane = _Plane(u, 0, a.z - u * a.x, null)
      ..add([for (final p in polygon) Offset(p.x, p.y)], aperture.id);
    apertures.add(offsets(visible(plane, ignoreSource: aperture.id)));
  }
  return ArchitectProjectionContours(faces, elements, apertures, bounds);
}

Rect _bounds(List<Offset> points) {
  var box = Rect.fromPoints(points.first, points.first);
  for (final p in points.skip(1)) {
    box = box.expandToInclude(Rect.fromPoints(p, p));
  }
  return box;
}

double _area(List<Offset> p) {
  var area = 0.0;
  final origin = p.first;
  for (var i = 1; i + 1 < p.length; i++) {
    final a = p[i] - origin, b = p[i + 1] - origin;
    area += a.dx * b.dy - a.dy * b.dx;
  }
  return area;
}

bool _hasArea(List<Offset> p) => p.length >= 3 && _area(p).abs() > 1e-14;
List<Offset> _clip2(List<Offset> input, double Function(Offset) distance) {
  if (input.isEmpty) return [];
  final output = <Offset>[];
  var previous = input.last, dp = distance(previous);
  for (final current in input) {
    final dc = distance(current);
    if ((dp >= 0) != (dc >= 0)) {
      output.add(previous + (current - previous) * (dp / (dp - dc)));
    }
    if (dc >= 0) output.add(current);
    previous = current;
    dp = dc;
  }
  return output;
}

List<Vector3> _clip3(List<Vector3> input, double Function(Vector3) distance) {
  if (input.isEmpty) return [];
  final output = <Vector3>[];
  var previous = input.last, dp = distance(previous);
  for (final current in input) {
    final dc = distance(current);
    if ((dp >= 0) != (dc >= 0)) {
      output.add(previous + (current - previous) * (dp / (dp - dc)));
    }
    if (dc >= 0) output.add(current);
    previous = current;
    dp = dc;
  }
  return output;
}

class _Plane {
  final double u, v, w;
  final String? silhouette;
  Rect bounds = Rect.zero;
  final sources = <String>{};
  final pieces = <({List<Offset> points, String? source})>[];
  _Plane(this.u, this.v, this.w, this.silhouette);
  double depth(Offset p) => u * p.dx + v * p.dy + w;
  void add(List<Offset> points, String? source) {
    final box = _bounds(points);
    bounds = pieces.isEmpty ? box : bounds.expandToInclude(box);
    pieces.add((points: points, source: source));
    if (source != null) sources.add(source);
  }
}

class _OcclusionIndex {
  late final Rect bounds;
  late final List<_Plane> leaves;
  _OcclusionIndex? left, right;
  _OcclusionIndex(List<_Plane> faces) {
    bounds =
        faces.fold<Rect?>(
          null,
          (b, p) => b?.expandToInclude(p.bounds) ?? p.bounds,
        ) ??
        Rect.zero;
    if (faces.length <= 8) {
      leaves = faces;
      return;
    }
    leaves = const [];
    final horizontal = bounds.width >= bounds.height;
    faces.sort(
      (a, b) => (horizontal ? a.bounds.center.dx : a.bounds.center.dy)
          .compareTo(horizontal ? b.bounds.center.dx : b.bounds.center.dy),
    );
    final mid = faces.length ~/ 2;
    left = _OcclusionIndex(faces.sublist(0, mid));
    right = _OcclusionIndex(faces.sublist(mid));
  }
  Iterable<_Plane> overlapping(Rect box) sync* {
    if (!bounds.overlaps(box)) return;
    for (final face in leaves) {
      if (face.bounds.overlaps(box)) yield face;
    }
    if (left != null) yield* left!.overlapping(box);
    if (right != null) yield* right!.overlapping(box);
  }
}
