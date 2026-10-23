import 'package:clipper2/clipper2.dart' as clip;
import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elevation.dart';
import '../models/architect_project.dart';
import '../rendering/architect_3d_builder.dart';
import 'architect_elevation_symbols.dart';

/// Vector hidden-surface removal, independent of screen resolution. Coplanar
/// triangles (including separate wall segments/storeys) are united before any
/// outlines are drawn, eliminating tessellation and boolean-cut seams.
class ArchitectBuildingElevation {
  final List<Path> faces;
  final Rect bounds;
  final Map<String, Path> elementPaths;
  final List<({Path lines, Path clip})> operations;
  final List<ArchitectElevationSlope> slopes;
  const ArchitectBuildingElevation(
    this.faces,
    this.bounds, {
    this.elementPaths = const {},
    this.operations = const [],
    this.slopes = const [],
  });

  static ArchitectBuildingElevation build(
    ArchitectProject project,
    ArchitectElevation view, {
    List<List<Offset>> occlusionMasks = const [],
  }) {
    final sources = <Triangle3D, String>{};
    final mesh = Architect3dBuilder.buildProjectMesh(
      project,
      previewGeometry: false,
      sources: sources,
    );
    return _fromTriangles(
      mesh.triangles,
      view,
      sources: sources,
      project: project,
      occlusionMasks: occlusionMasks,
    );
  }

  static ArchitectBuildingElevation fromTriangles(
    List<Triangle3D> triangles,
    ArchitectElevation view, {
    Map<Triangle3D, String> sources = const {},
  }) => _fromTriangles(triangles, view, sources: sources);

  static ArchitectBuildingElevation _fromTriangles(
    List<Triangle3D> triangles,
    ArchitectElevation view, {
    Map<Triangle3D, String> sources = const {},
    ArchitectProject? project,
    List<List<Offset>> occlusionMasks = const [],
  }) {
    if (view.steps.isNotEmpty) {
      final parts = <ArchitectBuildingElevation>[];
      for (final s in view.segments) {
        final depth = view.viewDepth == null
            ? null
            : view.viewDepth! - s.offset;
        if (depth != null && depth <= 0) continue;
        final local = _fromTriangles(
          triangles,
          view.copyWith(
            start: s.start,
            end: s.end,
            steps: const [],
            viewDepth: depth,
          ),
          sources: sources,
          project: project,
        );
        final delta = (s.start + s.end) / 2 - view.centre;
        final shift = Offset(
          delta.dx * view.right.dx + delta.dy * view.right.dy,
          0,
        );
        parts.add(
          ArchitectBuildingElevation(
            [for (final p in local.faces) p.shift(shift)],
            local.bounds.shift(shift),
            elementPaths: {
              for (final e in local.elementPaths.entries)
                e.key: e.value.shift(shift),
            },
            operations: [
              for (final op in local.operations)
                (lines: op.lines.shift(shift), clip: op.clip.shift(shift)),
            ],
            slopes: [
              for (final s in local.slopes)
                ArchitectElevationSlope(
                  s.id,
                  s.start + shift,
                  s.end + shift,
                  s.percent,
                ),
            ],
          ),
        );
      }
      final paths = <String, Path>{};
      for (final part in parts) {
        for (final e in part.elementPaths.entries) {
          paths[e.key] = paths.containsKey(e.key)
              ? Path.combine(PathOperation.union, paths[e.key]!, e.value)
              : e.value;
        }
      }
      return ArchitectBuildingElevation(
        [for (final p in parts) ...p.faces],
        parts.isEmpty
            ? Rect.fromLTWH(-view.length / 2, 0, view.length, 3)
            : parts.map((p) => p.bounds).reduce((a, b) => a.expandToInclude(b)),
        elementPaths: paths,
        operations: [for (final p in parts) ...p.operations],
        slopes: [for (final p in parts) ...p.slopes],
      );
    }
    if (view.length < .01) {
      return const ArchitectBuildingElevation([], Rect.fromLTWH(-1, 0, 2, 3));
    }
    final groups = <String, _ElevationPlane>{};
    final cutMasks = [
      for (final mask in occlusionMasks)
        if (_hasArea(mask)) (mask, _bounds2(mask)),
    ];
    final right = view.right, forward = view.viewDirection;
    Vector3 projectVector(Vector3 v) {
      final p = Offset(v.x, v.y) - view.centre;
      return Vector3(
        p.dx * right.dx + p.dy * right.dy,
        v.z,
        p.dx * forward.dx + p.dy * forward.dy,
      );
    }

    for (final triangle in triangles) {
      final a = projectVector(triangle.v0),
          b = projectVector(triangle.v1),
          c = projectVector(triangle.v2);
      final normal = (b - a).cross(c - a);
      // Edge-on faces have no projected area.
      if (normal.z.abs() < 1e-10) continue;
      final u = -normal.x / normal.z, v = -normal.y / normal.z;
      final w = a.z - u * a.x - v * a.y;
      var polygon = _clip3([a, b, c], (p) => p.z);
      if (view.viewDepth != null) {
        polygon = _clip3(polygon, (p) => view.viewDepth! - p.z);
      }
      polygon = _clip3(polygon, (p) => p.x + view.length / 2);
      polygon = _clip3(polygon, (p) => view.length / 2 - p.x);
      if (polygon.length < 3) continue;
      final path = Path()
        ..addPolygon([for (final p in polygon) Offset(p.x, p.y)], true);
      if (path.getBounds().isEmpty) continue;
      // Keep material boundaries (e.g. a flush window frame) while removing
      // triangle edges and construction seams within one finish.
      final key =
          '${(u * 1e6).round()}:${(v * 1e6).round()}:${(w * 1e6).round()}:${triangle.color?.toARGB32()}';
      final plane = groups[key];
      if (plane == null) {
        groups[key] = _ElevationPlane(u, v, w, path);
      } else {
        plane.path = Path()
          ..addPath(plane.path, Offset.zero)
          ..addPath(path, Offset.zero);
      }
      final id = sources[triangle];
      groups[key]!.pieces.add((
        points: [for (final p in polygon) Offset(p.x, p.y)],
        source: id,
      ));
      if (id != null) {
        final group = groups[key]!;
        group.sources[id] = group.sources.containsKey(id)
            ? (Path()
                ..addPath(group.sources[id]!, Offset.zero)
                ..addPath(path, Offset.zero))
            : path;
      }
    }
    final faces = <Path>[];
    Rect? bounds;
    final elementPaths = <String, Path>{};
    Path visiblePart(
      _ElevationPlane face, {
      String? ignoreSource,
      String? onlySource,
    }) {
      final subjects = [
        for (final p in face.pieces)
          if (onlySource == null || p.source == onlySource) p.points,
      ];
      if (subjects.isEmpty) return Path();
      final box = face.path.getBounds();
      final masks = <List<Offset>>[];
      for (final other in groups.values) {
        if (identical(face, other) || !box.overlaps(other.path.getBounds())) {
          continue;
        }
        for (final piece in other.pieces) {
          if (ignoreSource != null && piece.source == ignoreSource) continue;
          final mask = _clip2(
            piece.points,
            (p) => face.depth(p.dx, p.dy) - other.depth(p.dx, p.dy) - 1e-7,
          );
          if (_hasArea(mask) && box.overlaps(_bounds2(mask))) masks.add(mask);
        }
      }
      for (final (mask, bounds) in cutMasks) {
        if (box.overlaps(bounds)) masks.add(mask);
      }
      // Perform the complete union/difference before encoding any Flutter Path.
      // Clipper uses integer coordinates internally (10 nm in model metres),
      // so nearly coincident roof edges cannot corrupt intermediate contours.
      List<clip.PointD> points(List<Offset> p) => [
        for (final v in _area2(p) < 0 ? p.reversed : p) clip.PointD(v.dx, v.dy),
      ];
      final engine = clip.ClipperD(roundingDecimalPrecision: 8)
        ..preserveCollinear = false
        ..addSubjects([
          for (final p in subjects)
            if (_hasArea(p)) points(p),
        ])
        ..addClips([for (final p in masks) points(p)]);
      final contours = engine.executeClosed(
        clip.ClipType.difference,
        clip.FillRule.nonZero,
      );
      if (contours == null) {
        throw StateError('Architectural visibility clipping failed');
      }
      final path = Path();
      for (final contour in contours) {
        path.addPolygon([for (final p in contour) Offset(p.x, p.y)], true);
      }
      return path;
    }

    for (final face in groups.values) {
      final visible = visiblePart(face);
      if (visible.getBounds().isEmpty) continue;
      faces.add(visible);
      for (final entry in face.sources.entries) {
        final hit = face.sources.length == 1
            ? visible
            : visiblePart(face, onlySource: entry.key);
        if (hit.getBounds().isEmpty) continue;
        elementPaths[entry.key] = elementPaths.containsKey(entry.key)
            ? (Path()
                ..addPath(elementPaths[entry.key]!, Offset.zero)
                ..addPath(hit, Offset.zero))
            : hit;
      }
      bounds =
          bounds?.expandToInclude(visible.getBounds()) ?? visible.getBounds();
    }
    final operations = <({Path lines, Path clip})>[];
    if (project != null) {
      for (final operation in ArchitectElevationOperation.build(
        project,
        view,
      )) {
        final a = operation.aperture[0], b = operation.aperture[1];
        if ((b.x - a.x).abs() < 1e-6) continue;
        final u = (b.z - a.z) / (b.x - a.x);
        var polygon = _clip3(operation.aperture, (p) => p.z);
        if (view.viewDepth != null) {
          polygon = _clip3(polygon, (p) => view.viewDepth! - p.z);
        }
        polygon = _clip3(polygon, (p) => p.x + view.length / 2);
        polygon = _clip3(polygon, (p) => view.length / 2 - p.x);
        if (polygon.length < 3) continue;
        final plane = _ElevationPlane(
          u,
          0,
          a.z - u * a.x,
          Path()..addPolygon([for (final p in polygon) Offset(p.x, p.y)], true),
        );
        plane.pieces.add((
          points: [for (final p in polygon) Offset(p.x, p.y)],
          source: operation.id,
        ));
        final visible = visiblePart(plane, ignoreSource: operation.id);
        if (!visible.getBounds().isEmpty) {
          operations.add((lines: operation.lines, clip: visible));
          // Empty apertures of open doors remain selectable, but a foreground
          // solid still masks them just like the operation indication.
          elementPaths[operation.id] = elementPaths.containsKey(operation.id)
              ? (Path()
                  ..addPath(elementPaths[operation.id]!, Offset.zero)
                  ..addPath(visible, Offset.zero))
              : visible;
        }
      }
    }
    final slopes = project == null
        ? <ArchitectElevationSlope>[]
        : ArchitectElevationSlope.build(project, view, elementPaths);
    for (final slope in slopes) {
      final arrowBounds = Rect.fromPoints(slope.start, slope.end).inflate(.25);
      bounds = bounds?.expandToInclude(arrowBounds) ?? arrowBounds;
    }
    return ArchitectBuildingElevation(
      faces,
      bounds ??
          Rect.fromLTWH(-view.length / 2, 0, math.max(.01, view.length), 3),
      elementPaths: elementPaths,
      operations: operations,
      slopes: slopes,
    );
  }

  /// Sutherland–Hodgman clipping against an affine half-space.
  static Rect _bounds2(List<Offset> p) {
    var b = Rect.fromPoints(p.first, p.first);
    for (final v in p.skip(1)) {
      b = b.expandToInclude(Rect.fromPoints(v, v));
    }
    return b;
  }

  static double _area2(List<Offset> polygon) {
    var area = 0.0;
    final origin = polygon.first;
    for (var i = 1; i + 1 < polygon.length; i++) {
      final a = polygon[i] - origin, b = polygon[i + 1] - origin;
      area += a.dx * b.dy - a.dy * b.dx;
    }
    return area;
  }

  static bool _hasArea(List<Offset> p) =>
      p.length >= 3 && _area2(p).abs() > 1e-14;

  static List<Offset> _clip2(
    List<Offset> input,
    double Function(Offset) distance,
  ) {
    if (input.isEmpty) return [];
    final result = <Offset>[];
    var previous = input.last, dp = distance(input.last);
    for (final current in input) {
      final dc = distance(current);
      if ((dp >= 0) != (dc >= 0)) {
        result.add(previous + (current - previous) * (dp / (dp - dc)));
      }
      if (dc >= 0) result.add(current);
      previous = current;
      dp = dc;
    }
    return result;
  }

  static List<Vector3> _clip3(
    List<Vector3> input,
    double Function(Vector3) distance,
  ) {
    final output = <Vector3>[];
    if (input.isEmpty) return output;
    var previous = input.last;
    var dp = distance(previous);
    for (final current in input) {
      final dc = distance(current);
      if ((dc >= 0) != (dp >= 0)) {
        output.add(previous + (current - previous) * (dp / (dp - dc)));
      }
      if (dc >= 0) output.add(current);
      previous = current;
      dp = dc;
    }
    return output;
  }
}

class _ElevationPlane {
  final double u, v, w;
  Path path;
  final sources = <String, Path>{};
  final pieces = <({List<Offset> points, String? source})>[];
  _ElevationPlane(this.u, this.v, this.w, this.path);
  double depth(double x, double z) => u * x + v * z + w;
}
