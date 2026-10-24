import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_contour.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_polygon_geometry.dart';
import 'architect_room_detector.dart';

class ArchitectClosedContour {
  final List<Offset> polygon;
  final List<List<Offset>> holes;
  const ArchitectClosedContour(this.polygon, [this.holes = const []]);

  /// Smallest bounded face around the pick. CAD lines are split at crossings
  /// before walking directed faces, so dividers and T junctions work too.
  static ArchitectClosedContour? detect(ArchitectStorey storey, Offset seed) {
    final segments = <(Offset, Offset)>[];
    void ring(List<Offset> p) {
      if (!ArchitectPolygonGeometry.valid(p)) return;
      for (var i = 0; i < p.length; i++) {
        segments.add((p[i], p[(i + 1) % p.length]));
      }
    }

    for (final p in storey.cadPrimitives) {
      if (p.type == CadPrimitiveType.line) {
        if ((p.endPoint - p.startPoint).distance > 1e-8) {
          segments.add((p.startPoint, p.endPoint));
        }
      } else if (p.isPolygon) {
        ring(p.polygonCorners);
        for (final h in p.holes) {
          ring(h);
        }
      } else if (p.type == CadPrimitiveType.circle) {
        final radius = (p.endPoint - p.startPoint).distance;
        ring([
          for (var i = 0; i < 128; i++)
            p.startPoint +
                Offset(math.cos(i * math.pi / 64), math.sin(i * math.pi / 64)) *
                    radius,
        ]);
      }
    }
    for (final s in storey.slabs) {
      ring(s.polygon);
      for (final h in s.holes) {
        ring(h);
      }
    }
    for (final r in storey.roofs) {
      ring(r.points);
      for (final h in r.holes) {
        ring(h);
      }
    }
    for (final z in storey.zones) {
      ring(z.polygon);
    }
    for (final o in storey.openings) {
      ring(o.boundary);
    }
    final room = ArchitectRoomDetector.detectRoomPolygon(
      seedPoint: seed,
      walls: storey.walls,
    );
    if (room != null && ArchitectPolygonGeometry.valid(room)) {
      ring(room);
    }
    final faces = _faces(segments);
    final candidates =
        faces.where((p) => ArchitectPolygonGeometry.contains(p, seed)).toList()
          ..sort(
            (a, b) => ArchitectPolygonGeometry.signedArea(
              a,
            ).abs().compareTo(ArchitectPolygonGeometry.signedArea(b).abs()),
          );
    if (candidates.isEmpty) return null;
    final outer = candidates.first;
    final holes = <List<Offset>>[];
    // Keep the outermost islands only; overlapping loops cannot toggle fill.
    faces.sort(
      (a, b) => ArchitectPolygonGeometry.signedArea(
        b,
      ).abs().compareTo(ArchitectPolygonGeometry.signedArea(a).abs()),
    );
    for (final p in faces) {
      if (!ArchitectPolygonGeometry.contains(p, seed) &&
          ArchitectContour.canAdd(outer, holes, p)) {
        holes.add(p);
      }
    }
    return ArchitectClosedContour(outer, holes);
  }

  static List<List<Offset>> _faces(List<(Offset, Offset)> segments) {
    final cuts = [
      for (final _ in segments) <double>[0, 1],
    ];
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      final u = b - a;
      for (var j = i + 1; j < segments.length; j++) {
        final (c, d) = segments[j];
        if (!Rect.fromPoints(
          a,
          b,
        ).inflate(1e-7).overlaps(Rect.fromPoints(c, d).inflate(1e-7))) {
          continue;
        }
        final v = d - c, den = cross(u, v);
        if (den.abs() > 1e-10) {
          final t = cross(c - a, v) / den, s = cross(c - a, u) / den;
          if (t >= -1e-8 && t <= 1 + 1e-8 && s >= -1e-8 && s <= 1 + 1e-8) {
            cuts[i].add(t.clamp(0, 1));
            cuts[j].add(s.clamp(0, 1));
          }
        } else if (cross(c - a, u).abs() < 1e-8 * u.distance) {
          double parameter(Offset p, Offset start, Offset dir) =>
              ((p - start).dx * dir.dx + (p - start).dy * dir.dy) /
              dir.distanceSquared;
          for (final p in [c, d]) {
            final t = parameter(p, a, u);
            if (t > 0 && t < 1) cuts[i].add(t);
          }
          for (final p in [a, b]) {
            final t = parameter(p, c, v);
            if (t > 0 && t < 1) cuts[j].add(t);
          }
        }
      }
    }
    final vertices = <Offset>[];
    final indices = <(int, int), int>{};
    int vertex(Offset p) {
      final key = ((p.dx * 1e7).round(), (p.dy * 1e7).round());
      return indices.putIfAbsent(key, () {
        vertices.add(p);
        return vertices.length - 1;
      });
    }

    final adjacency = <int, Set<int>>{};
    for (var i = 0; i < segments.length; i++) {
      cuts[i].sort();
      final (a, b) = segments[i];
      for (var j = 1; j < cuts[i].length; j++) {
        final x = vertex(a + (b - a) * cuts[i][j - 1]);
        final y = vertex(a + (b - a) * cuts[i][j]);
        if (x == y) continue;
        (adjacency[x] ??= {}).add(y);
        (adjacency[y] ??= {}).add(x);
      }
    }
    final sorted = {
      for (final e in adjacency.entries)
        e.key: e.value.toList()
          ..sort((a, b) {
            final u = vertices[a] - vertices[e.key],
                v = vertices[b] - vertices[e.key];
            return math.atan2(u.dy, u.dx).compareTo(math.atan2(v.dy, v.dx));
          }),
    };
    final visited = <(int, int)>{};
    final faces = <List<Offset>>[];
    for (final e in sorted.entries) {
      for (final next in e.value) {
        var edge = (e.key, next);
        if (visited.contains(edge)) continue;
        final start = edge, points = <Offset>[];
        while (visited.add(edge)) {
          points.add(vertices[edge.$1]);
          final neighbors = sorted[edge.$2]!;
          final index = neighbors.indexOf(edge.$1);
          edge = (
            edge.$2,
            neighbors[(index - 1 + neighbors.length) % neighbors.length],
          );
        }
        final clean = ArchitectPolygonGeometry.clean(
          points,
          removeCollinear: true,
        );
        if (edge == start &&
            ArchitectPolygonGeometry.signedArea(clean) > 1e-6 &&
            ArchitectPolygonGeometry.valid(clean)) {
          faces.add(clean);
        }
      }
    }
    return faces;
  }
}
