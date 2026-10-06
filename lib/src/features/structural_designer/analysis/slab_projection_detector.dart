import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import 'slab_envelope_detector.dart';

/// External areas bounded by existing straight CAD chains and the envelope.
/// They are proposals, not a determination of material, level or balcony type.
class SlabProjectionCandidate {
  final List<Offset> contour;
  final String sourceLayer;
  final double area;
  final String kind;
  const SlabProjectionCandidate(
    this.contour,
    this.sourceLayer,
    this.area, {
    this.kind = 'externalArea',
  });
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'coordinateSpace': 'sourceCad',
    'status': 'needsReview',
    'sourceLayer': sourceLayer,
    'areaCadSquared': area,
    'contour': contour.map((p) => [p.dx, p.dy]).toList(),
    'levelVerified': false,
    'materialVerified': false,
  };
}

class SlabProjectionDetector {
  static double _area(List<Offset> ring) {
    var sum = 0.0;
    final origin = ring.first;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i] - origin, b = ring[(i + 1) % ring.length] - origin;
      sum += a.dx * b.dy - a.dy * b.dx;
    }
    return sum.abs() / 2;
  }

  static bool _inside(Offset p, List<Offset> ring) {
    var inside = false;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static ({Offset point, int edge, double distance}) _nearest(
    Offset p,
    List<Offset> ring, {
    Offset? transverseTo,
  }) {
    var best = double.infinity, index = 0, point = Offset.zero;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], d = ring[(i + 1) % ring.length] - a;
      if (transverseTo != null &&
          (d.distance == 0 ||
              (d.dx * transverseTo.dx + d.dy * transverseTo.dy).abs() /
                      (d.distance * transverseTo.distance) >
                  0.2)) {
        continue;
      }
      final t = d.distanceSquared == 0
          ? 0.0
          : (((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared).clamp(
              0.0,
              1.0,
            );
      final q = a + d * t, distance = (p - q).distance;
      if (distance < best) {
        best = distance;
        index = i;
        point = q;
      }
    }
    return (point: point, edge: index, distance: best);
  }

  static bool _simple(List<Offset> ring, double tolerance) {
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length], u = b - a;
      for (var j = i + 2; j < ring.length; j++) {
        if (i == 0 && j == ring.length - 1) continue;
        final c = ring[j], d = ring[(j + 1) % ring.length], v = d - c;
        final denominator = cross(u, v);
        if (denominator.abs() < tolerance * tolerance) continue;
        final t = cross(c - a, v) / denominator,
            s = cross(c - a, u) / denominator;
        if (t > 1e-7 && t < 1 - 1e-7 && s > 1e-7 && s < 1 - 1e-7) return false;
      }
    }
    return true;
  }

  static List<SlabProjectionCandidate> detect(
    DxfDocument doc,
    SlabEnvelopeResult envelope,
    double scale, {
    Set<String> wallLayers = const {},
  }) {
    if (envelope.contours.isEmpty || scale <= 0 || !scale.isFinite) return [];
    final byLayer = <String, List<(Offset, Offset)>>{};
    bool outside(Offset p) => !envelope.contours.any((r) => _inside(p, r));
    double distance(Offset p) =>
        envelope.contours.map((r) => _nearest(p, r).distance).reduce(math.min);
    var count = 0;
    void add(Offset a, Offset b, String layer) {
      if ((a - b).distance < 50 * scale || count >= 4000) return;
      final mid = (a + b) / 2;
      if (!outside(mid) || distance(mid) > 6000 * scale) return;
      if ([a, b].any((p) => distance(p) > 6000 * scale)) return;
      byLayer.putIfAbsent(layer, () => []).add((a, b));
      count++;
    }

    for (final e in doc.entities) {
      if (e.isPaperSpace || wallLayers.contains(e.layer)) continue;
      var lt = e.lineType?.toUpperCase() ?? 'BYLAYER';
      if (lt == 'BYLAYER') {
        lt = doc.layers[e.layer]?.lineType?.toUpperCase() ?? 'CONTINUOUS';
      }
      if (!{'CONTINUOUS', 'BYBLOCK', 'BYLAYER'}.contains(lt)) continue;
      if (e is DxfLine) add(e.p1, e.p2, e.layer);
      if (e is DxfLwPolyline) {
        for (var i = 0; i < e.vertices.length - (e.isClosed ? 0 : 1); i++) {
          final a = e.vertices[i], b = e.vertices[(i + 1) % e.vertices.length];
          if (a.bulge.abs() < 1e-10) {
            add(Offset(a.x, a.y), Offset(b.x, b.y), e.layer);
          }
        }
      }
    }
    final candidates = <SlabProjectionCandidate>[];
    final attachment = 200 * scale;
    for (final entry in byLayer.entries) {
      final points = <Offset>[],
          edges = <(int, int)>[],
          adjacency = <int, List<int>>{};
      int node(Offset p) {
        for (var i = 0; i < points.length; i++) {
          if ((points[i] - p).distance <= 5 * scale) return i;
        }
        points.add(p);
        return points.length - 1;
      }

      for (final segment in entry.value) {
        final a = node(segment.$1), b = node(segment.$2);
        if (a == b ||
            edges.any(
              (e) => (e.$1 == a && e.$2 == b) || (e.$1 == b && e.$2 == a),
            )) {
          continue;
        }
        final i = edges.length;
        edges.add((a, b));
        adjacency.putIfAbsent(a, () => []).add(i);
        adjacency.putIfAbsent(b, () => []).add(i);
      }
      final visited = <int>{};
      for (final start in adjacency.keys.where(
        (n) => adjacency[n]!.length == 1,
      )) {
        if (visited.contains(adjacency[start]!.single)) continue;
        final chain = <Offset>[points[start]];
        var current = start, ambiguous = false;
        while (true) {
          final next = adjacency[current]!
              .where((e) => !visited.contains(e))
              .toList();
          if (next.isEmpty) break;
          if (next.length != 1 || adjacency[current]!.length > 2) {
            ambiguous = true;
            break;
          }
          final edge = next.single;
          visited.add(edge);
          current = edges[edge].$1 == current ? edges[edge].$2 : edges[edge].$1;
          chain.add(points[current]);
        }
        if (ambiguous || chain.length < 2) continue;
        for (final ring in envelope.contours) {
          final mouthDirection = chain.length == 2
              ? chain.last - chain.first
              : null;
          final first = _nearest(
                chain.first,
                ring,
                transverseTo: mouthDirection,
              ),
              last = _nearest(chain.last, ring, transverseTo: mouthDirection);
          if (first.distance > attachment || last.distance > attachment) {
            continue;
          }
          final isLoggia = chain.length == 2;
          if (isLoggia) {
            // A single railing across a recess needs two opposing side walls.
            final mouth = chain.last - chain.first;
            final sideA =
                ring[(first.edge + 1) % ring.length] - ring[first.edge];
            final sideB = ring[(last.edge + 1) % ring.length] - ring[last.edge];
            double cosine(Offset a, Offset b) =>
                (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
            if (first.edge == last.edge ||
                mouth.distance > 6000 * scale ||
                cosine(mouth, sideA).abs() > 0.2 ||
                cosine(mouth, sideB).abs() > 0.2) {
              continue;
            }
          }
          final routes = <List<Offset>>[];
          if (first.edge == last.edge) {
            routes.add([first.point, ...chain, last.point]);
          }
          for (final forward in [true, false]) {
            final polygon = [first.point, ...chain, last.point];
            var i = forward ? (last.edge + 1) % ring.length : last.edge;
            final stop = forward ? (first.edge + 1) % ring.length : first.edge;
            for (var k = 0; i != stop && k <= ring.length; k++) {
              polygon.add(ring[i]);
              i = (i + (forward ? 1 : ring.length - 1)) % ring.length;
            }
            routes.add(polygon);
          }
          routes.sort((a, b) => _area(a).compareTo(_area(b)));
          for (final polygon in routes) {
            // A long detour into an unclosed building is not a balcony.
            final chainLength = List.generate(
              chain.length - 1,
              (i) => (chain[i + 1] - chain[i]).distance,
            ).fold<double>(0, (a, b) => a + b);
            final perimeter = List.generate(
              polygon.length,
              (i) => (polygon[(i + 1) % polygon.length] - polygon[i]).distance,
            ).fold<double>(0, (a, b) => a + b);
            if (perimeter > chainLength * 4 + 2 * attachment) continue;
            final area = _area(polygon);
            if (area < 500000 * scale * scale ||
                area > 100000000 * scale * scale) {
              continue;
            }
            if (polygon.length > 2000 || !_simple(polygon, scale * 0.1)) {
              continue;
            }
            final left = polygon.map((p) => p.dx).reduce(math.min),
                right = polygon.map((p) => p.dx).reduce(math.max);
            final top = polygon.map((p) => p.dy).reduce(math.min),
                bottom = polygon.map((p) => p.dy).reduce(math.max);
            var samples = 0, external = 0;
            for (var y = 0; y < 11; y++) {
              for (var x = 0; x < 11; x++) {
                final p = Offset(
                  left + (x + 0.5) * (right - left) / 11,
                  top + (y + 0.5) * (bottom - top) / 11,
                );
                if (_inside(p, polygon)) {
                  samples++;
                  if (outside(p)) external++;
                }
              }
            }
            if (samples < 5 || external / samples < 0.95) continue;
            candidates.add(
              SlabProjectionCandidate(
                polygon,
                entry.key,
                area,
                kind: isLoggia ? 'loggiaCandidate' : 'externalArea',
              ),
            );
            break;
          }
        }
      }
    }
    // Double railing outlines describe one external area. Keep the enclosing
    // outline only when the smaller one is almost entirely contained in it.
    candidates.sort((a, b) => b.area.compareTo(a.area));
    final result = <SlabProjectionCandidate>[];
    for (final candidate in candidates) {
      if (result.any(
        (r) =>
            candidate.area / r.area > 0.6 &&
            candidate.contour.every(
              (p) =>
                  _inside(p, r.contour) ||
                  _nearest(p, r.contour).distance <= attachment,
            ),
      )) {
        continue;
      }
      result.add(candidate);
    }
    return result;
  }
}
