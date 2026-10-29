import 'dart:ui';
import 'package:flutter/foundation.dart' show compute;
import 'package:clipper2/clipper2.dart' as clip;
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_path_solid.dart';

/// Closed mesh sections retain nested contours (notably hollow steel profiles).
/// Contours are cleaned in double precision before entering Flutter's paths.
class ArchitectMeshSection {
  static final _vertical = Expando<Map<(Offset, Offset, double), Path>>();

  /// Slice closed components in one worker request; keep native Paths local.
  static Future<void> prepareVertical(
    Iterable<List<Triangle3D>> meshes,
    Offset origin,
    Offset axis,
    double length,
  ) async {
    final key = (origin, axis, length);
    final pending = meshes
        .where((mesh) => _vertical[mesh]?[key] == null)
        .toList();
    if (pending.isEmpty) return;
    final contours = await compute(_sliceVerticalComponents, (
      pending,
      origin,
      axis,
      length,
    ), debugLabel: 'architectural-wall-sections');
    for (var i = 0; i < pending.length; i++) {
      (_vertical[pending[i]] ??= {})[key] = _offsetPath(contours[i]);
    }
  }

  static Path verticalClipped(
    List<Triangle3D> mesh,
    Offset origin,
    Offset axis,
    double length,
  ) => (_vertical[mesh] ??= {})[(origin, axis, length)] ??= _offsetPath(
    _sliceVerticalComponents(([mesh], origin, axis, length)).single,
  );

  static Path _offsetPath(List<List<Offset>> contours) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final contour in contours) {
      path.addPolygon(contour, true);
    }
    return path;
  }

  static Path slice(
    List<Triangle3D> mesh,
    Vector3 origin,
    Vector3 normal,
    Offset Function(Vector3) project,
  ) => _offsetPath(sliceContours(mesh, origin, normal, project));

  /// Numerical mesh intersection and contour welding, independent of Path.
  static List<List<Offset>> sliceContours(
    List<Triangle3D> mesh,
    Vector3 origin,
    Vector3 normal,
    Offset Function(Vector3) project,
  ) {
    const tolerance = 1e-6;
    final bins = <(int, int), List<(String, Offset)>>{};
    // Once welded, an endpoint must keep its node. A later nearby anchor in a
    // neighbouring bin must not change its identity while assembling links.
    final pointKeys = <Offset, String>{};
    var serial = 0;
    String key(Offset p) => pointKeys.putIfAbsent(p, () {
      final x = (p.dx / tolerance).floor(), y = (p.dy / tolerance).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final entry in bins[(x + dx, y + dy)] ?? <(String, Offset)>[]) {
            if ((p - entry.$2).distance <= tolerance) return entry.$1;
          }
        }
      }
      final id = '${serial++}';
      (bins[(x, y)] ??= []).add((id, p));
      return id;
    });

    final segments = <(Offset, Offset)>[], seen = <String>{};
    for (final face in mesh) {
      final vs = [face.v0, face.v1, face.v2],
          ds = [
            for (final v in [face.v0, face.v1, face.v2])
              (v - origin).dot(normal),
          ];
      if (ds.every((d) => d.abs() < 1e-9)) continue;
      final points = <Vector3>[];
      void add(Vector3 p) {
        if (points.every((q) => (p - q).length > 1e-8)) points.add(p);
      }

      for (var i = 0; i < 3; i++) {
        final j = (i + 1) % 3;
        if (ds[i].abs() < 1e-9) add(vs[i]);
        if (ds[i] * ds[j] < -1e-18) {
          add(vs[i] + (vs[j] - vs[i]) * (ds[i] / (ds[i] - ds[j])));
        }
      }
      if (points.length != 2) continue;
      final a = project(points[0]), b = project(points[1]);
      if ((a - b).distance < 1e-8) continue;
      final names = [key(a), key(b)]..sort();
      if (names.first == names.last) continue;
      if (seen.add(names.join(':'))) segments.add((a, b));
    }
    final links = <String, List<int>>{};
    for (var i = 0; i < segments.length; i++) {
      for (final p in [segments[i].$1, segments[i].$2]) {
        (links[key(p)] ??= []).add(i);
      }
    }
    final used = <int>{}, loops = <List<clip.PointD>>[];
    for (var seed = 0; seed < segments.length; seed++) {
      if (used.contains(seed)) continue;
      used.add(seed);
      final loop = [segments[seed].$1, segments[seed].$2];
      while (key(loop.first) != key(loop.last)) {
        final next = (links[key(loop.last)] ?? [])
            .where((i) => !used.contains(i))
            .firstOrNull;
        if (next == null) break;
        used.add(next);
        final edge = segments[next];
        loop.add(key(edge.$1) == key(loop.last) ? edge.$2 : edge.$1);
      }
      if (key(loop.first) == key(loop.last) && loop.length >= 4) {
        loops.add([
          for (final p in loop.take(loop.length - 1)) clip.PointD(p.dx, p.dy),
        ]);
      }
    }
    final engine = clip.ClipperD(roundingDecimalPrecision: 7)
      ..preserveCollinear = false
      ..addSubjects(loops);
    final contours = engine.executeClosed(
      clip.ClipType.union,
      clip.FillRule.evenOdd,
    );
    if (contours == null) throw StateError('Construction section failed');
    return [
      for (final loop in contours) [for (final p in loop) Offset(p.x, p.y)],
    ];
  }

  static Path vertical(List<Triangle3D> mesh, Offset origin, Offset axis) =>
      slice(
        mesh,
        Vector3(origin.dx, origin.dy, 0),
        Vector3(-axis.dy, axis.dx, 0),
        (v) => Offset(
          (v.x - origin.dx) * axis.dx + (v.y - origin.dy) * axis.dy,
          v.z,
        ),
      );
  static Path horizontal(List<Triangle3D> mesh, double z) => slice(
    mesh,
    Vector3(0, 0, z),
    const Vector3(0, 0, 1),
    (v) => Offset(v.x, v.y),
  );

  static Path _path(List<List<clip.PointD>> contours) {
    final result = Path();
    for (final loop in contours) {
      result.addPolygon([for (final p in loop) Offset(p.x, p.y)], true);
    }
    return result;
  }

  /// Union operands as independently filled regions. A reflected polygon may
  /// have the opposite winding to its neighbour; normalize each operand before
  /// batching so it cannot cancel material or fill another operand's holes.
  static Path unionPaths(Iterable<Path> paths) {
    final contours = <List<clip.PointD>>[];
    for (final path in paths) {
      if (path.getBounds().isEmpty) continue;
      final engine = clip.ClipperD(roundingDecimalPrecision: 7)
        ..preserveCollinear = false
        ..addSubjects([
          for (final loop in ArchitectPathSolid.contours(path))
            [for (final p in loop) clip.PointD(p.dx, p.dy)],
        ]);
      final normalized = engine.executeClosed(
        clip.ClipType.union,
        path.fillType == PathFillType.evenOdd
            ? clip.FillRule.evenOdd
            : clip.FillRule.nonZero,
      );
      if (normalized == null) {
        throw StateError('Construction contour normalization failed');
      }
      contours.addAll(normalized);
    }
    final engine = clip.ClipperD(roundingDecimalPrecision: 7)
      ..preserveCollinear = false
      ..addSubjects(contours);
    final united = engine.executeClosed(
      clip.ClipType.union,
      clip.FillRule.nonZero,
    );
    if (united == null) throw StateError('Construction contour union failed');
    return _path(united);
  }

  static Path combine(PathOperation operation, Path a, Path b) {
    List<List<clip.PointD>> paths(Path p) => [
      for (final loop in ArchitectPathSolid.contours(p))
        [for (final v in loop) clip.PointD(v.dx, v.dy)],
    ];
    // Normalize each operand independently so its own holes keep their meaning.
    List<List<clip.PointD>> normalize(Path p) {
      final engine = clip.ClipperD(roundingDecimalPrecision: 7)
        ..addSubjects(paths(p));
      final result = engine.executeClosed(
        clip.ClipType.union,
        p.fillType == PathFillType.evenOdd
            ? clip.FillRule.evenOdd
            : clip.FillRule.nonZero,
      );
      if (result == null) {
        throw StateError('Construction contour normalization failed');
      }
      return result;
    }

    final engine = clip.ClipperD(roundingDecimalPrecision: 7)
      ..preserveCollinear = false
      ..addSubjects(
        normalize(operation == PathOperation.reverseDifference ? b : a),
      )
      ..addClips(
        normalize(operation == PathOperation.reverseDifference ? a : b),
      );
    final result = engine.executeClosed(switch (operation) {
      PathOperation.union => clip.ClipType.union,
      PathOperation.intersect => clip.ClipType.intersection,
      PathOperation.xor => clip.ClipType.xor,
      _ => clip.ClipType.difference,
    }, clip.FillRule.nonZero);
    if (result == null) throw StateError('Construction path operation failed');
    return _path(result);
  }
}

List<List<List<Offset>>> _sliceVerticalComponents(
  (List<List<Triangle3D>>, Offset, Offset, double) request,
) {
  final (meshes, start, axis, length) = request;
  return [
    for (final mesh in meshes)
      (() {
        final contours = ArchitectMeshSection.sliceContours(
          mesh,
          Vector3(start.dx, start.dy, 0),
          Vector3(-axis.dy, axis.dx, 0),
          (v) => Offset(
            (v.x - start.dx) * axis.dx + (v.y - start.dy) * axis.dy,
            v.z,
          ),
        );
        final engine = clip.ClipperD(roundingDecimalPrecision: 7)
          ..preserveCollinear = false
          ..addSubjects([
            for (final loop in contours)
              [for (final p in loop) clip.PointD(p.dx, p.dy)],
          ])
          ..addClips([
            [
              clip.PointD(0, -1e6),
              clip.PointD(length, -1e6),
              clip.PointD(length, 1e6),
              clip.PointD(0, 1e6),
            ],
          ]);
        final clipped = engine.executeClosed(
          clip.ClipType.intersection,
          clip.FillRule.evenOdd,
        );
        if (clipped == null) {
          throw StateError('Construction section clipping failed');
        }
        return [
          for (final loop in clipped) [for (final p in loop) Offset(p.x, p.y)],
        ];
      })(),
  ];
}
