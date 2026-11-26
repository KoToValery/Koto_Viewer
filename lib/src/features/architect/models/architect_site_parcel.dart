import 'dart:math' as math;
import 'dart:ui';

import 'package:clipper2/clipper2.dart' as clip;

import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';

typedef ArchitectSiteSegment = (Offset, Offset);

/// A single project parcel. Vertex order is retained so a setback stays
/// attached to its boundary side when vertices move or the site rotates.
class ArchitectSiteParcel {
  final List<Offset> vertices;
  final Map<int, double> setbacks;
  late final List<ArchitectSiteSegment> trimmedSetbacks = List.unmodifiable(
    _trimSetbacks(),
  );

  ArchitectSiteParcel(
    List<Offset> vertices, {
    Map<int, double> setbacks = const {},
  }) : vertices = List.unmodifiable(vertices),
       setbacks = Map.unmodifiable(setbacks);

  double get area => BimPolygonGeometry.signedArea(vertices).abs();

  ArchitectSiteSegment side(int index) =>
      (vertices[index], vertices[(index + 1) % vertices.length]);

  ArchitectSiteParcel withSetback(int index, double? distance) =>
      ArchitectSiteParcel(
        vertices,
        setbacks: Map.of(setbacks)
          ..remove(index)
          ..addAll({index: ?distance}),
      );

  ArchitectSiteParcel transformed(Offset Function(Offset) turn) =>
      ArchitectSiteParcel(vertices.map(turn).toList(), setbacks: setbacks);

  Map<String, dynamic> toJson() => {
    'vertices': [
      for (final p in vertices) [p.dx, p.dy],
    ],
    if (setbacks.isNotEmpty)
      'setbacks': {for (final e in setbacks.entries) '${e.key}': e.value},
  };

  static ArchitectSiteParcel? fromJson(Object? raw) {
    if (raw is! Map || raw['vertices'] is! List) return null;
    final vertices = <Offset>[];
    for (final point in raw['vertices'] as List) {
      if (point is! List ||
          point.length != 2 ||
          point[0] is! num ||
          point[1] is! num) {
        return null;
      }
      vertices.add(
        Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
      );
    }
    if (!BimPolygonGeometry.valid(vertices)) return null;
    final setbacks = <int, double>{};
    final stored = raw['setbacks'];
    if (stored is Map) {
      for (final entry in stored.entries) {
        final index = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (index != null &&
            index >= 0 &&
            index < vertices.length &&
            value is num &&
            value.isFinite &&
            value > 0) {
          setbacks[index] = value.toDouble();
        }
      }
    }
    return ArchitectSiteParcel(vertices, setbacks: setbacks);
  }

  bool contains(Offset point) =>
      BimPolygonGeometry.contains(vertices, point) ||
      BimLineGeometry.insertion(vertices, point, closed: true)!.distance < 1e-8;

  /// The intervals inside the parcel that overlap the selected side's span.
  /// Clipping works with either winding and with non-convex boundaries.
  List<ArchitectSiteSegment> setbackSegments(int index, double distance) {
    if (!distance.isFinite || distance <= 0) return [];
    final (a, b) = side(index);
    final length = (b - a).distance;
    final direction = (b - a) / length;
    final normal = -BimPolygonGeometry.normal(vertices, index);
    final start = a + normal * distance;
    final cuts = <double>[];
    for (var i = 0; i < vertices.length; i++) {
      final (p, q) = side(i);
      final hp = BimLineGeometry.dot(p - start, normal);
      final hq = BimLineGeometry.dot(q - start, normal);
      if (hp.abs() < 1e-8) cuts.add(BimLineGeometry.dot(p - start, direction));
      if (hp * hq < 0) {
        final hit = p + (q - p) * (hp / (hp - hq));
        cuts.add(BimLineGeometry.dot(hit - start, direction));
      }
    }
    cuts.sort();
    final result = <ArchitectSiteSegment>[];
    for (var i = 1; i < cuts.length; i++) {
      final low = cuts[i - 1], high = cuts[i];
      if (math.min(length, high) - math.max(0.0, low) <= 1e-8) continue;
      final mid = start + direction * ((low + high) / 2);
      if (!BimPolygonGeometry.contains(vertices, mid) ||
          BimLineGeometry.insertion(vertices, mid, closed: true)!.distance <
              1e-8) {
        continue;
      }
      // A deep offset may enter another lobe after leaving the selected
      // side's interior. Require an uninterrupted normal from the side.
      final along = (math.max(0.0, low) + math.min(length, high)) / 2;
      final back = a + direction * along;
      final front = back + normal * distance;
      if (List.generate(vertices.length, side).asMap().entries.any((e) {
        if (e.key == index) return false;
        final hit = BimLineGeometry.intersection(
          back,
          front,
          e.value.$1,
          e.value.$2,
          firstFinite: true,
          secondFinite: true,
        );
        return hit != null && (hit - back).distance > 1e-8;
      })) {
        continue;
      }
      result.add((start + direction * low, start + direction * high));
    }
    return result;
  }

  /// Remove the strip between each configured side and its setback. Taking
  /// the boundary of the remaining region joins the dashed lines where they
  /// intersect and supports disconnected regions in a concave parcel.
  List<ArchitectSiteSegment> _trimSetbacks() {
    final active = {
      for (final entry in setbacks.entries)
        if (setbackSegments(entry.key, entry.value).isNotEmpty)
          entry.key: entry.value,
    };
    if (active.isEmpty) return [];
    if (active.length == 1) {
      final entry = active.entries.single;
      return setbackSegments(entry.key, entry.value);
    }

    final origin = vertices.first;
    List<clip.PointD> polygon(List<Offset> points) => [
      for (final p
          in BimPolygonGeometry.signedArea(points) < 0
              ? points.reversed
              : points)
        clip.PointD(p.dx - origin.dx, p.dy - origin.dy),
    ];
    Offset shift(int index) =>
        -BimPolygonGeometry.normal(vertices, index) * (active[index] ?? 0);

    final cutters = <List<clip.PointD>>[];
    final fronts = <(Offset, Offset)>[];
    for (final index in active.keys) {
      final (a, b) = side(index);
      final shiftVector = shift(index);
      final start = a + shiftVector, end = b + shiftVector;
      final length = (b - a).distance;
      final along = (b - a) / length;
      var minimum = 0.0, maximum = length;
      for (final vertex in vertices) {
        final t = BimLineGeometry.dot(vertex - start, along);
        minimum = math.min(minimum, t);
        maximum = math.max(maximum, t);
      }

      double corner(int neighbour, double limit, {required bool atStart}) {
        final (p, q) = side(neighbour);
        var result = limit;
        // Cover the full inward band at the parcel edge and extend it to
        // the offset miter at a re-entrant corner. Keep crossed bands wide
        // enough to remove their overlap when the envelope collapses.
        for (final delta in [Offset.zero, shift(neighbour)]) {
          final hit = BimLineGeometry.intersection(
            start,
            end,
            p + delta,
            q + delta,
          );
          if (hit == null) continue;
          final t = BimLineGeometry.dot(
            hit - start,
            along,
          ).clamp(minimum, maximum);
          result = atStart ? math.min(result, t) : math.max(result, t);
        }
        return result;
      }

      final previous = (index - 1 + vertices.length) % vertices.length;
      final next = (index + 1) % vertices.length;
      final first = start + along * corner(previous, 0, atStart: true);
      final last = start + along * corner(next, length, atStart: false);
      cutters.add(polygon([a, b, last, first]));
      fronts.add((first, last));
    }

    final engine = clip.ClipperD(roundingDecimalPrecision: 7)
      ..addSubjects([polygon(vertices)])
      ..addClips(cutters);
    final loops = engine.executeClosed(
      clip.ClipType.difference,
      clip.FillRule.nonZero,
    );
    final boundaries = List.generate(vertices.length, side);
    final result = <ArchitectSiteSegment>[];
    for (final loop in loops ?? const <List<clip.PointD>>[]) {
      for (var i = 0; i < loop.length; i++) {
        final first = loop[i], last = loop[(i + 1) % loop.length];
        final a = origin + Offset(first.x, first.y);
        final b = origin + Offset(last.x, last.y);
        if ((b - a).distance < 1e-7) continue;
        List<(double, double)> overlap(List<ArchitectSiteSegment> segments) {
          final parts = <(double, double)>[];
          final direction = (b - a) / (b - a).distance;
          for (final (p, q) in segments) {
            if (BimLineGeometry.cross(direction, p - a).abs() > 1e-6 ||
                BimLineGeometry.cross(direction, q - a).abs() > 1e-6) {
              continue;
            }
            final u = BimLineGeometry.parameter(p, a, b);
            final v = BimLineGeometry.parameter(q, a, b);
            if ((u - v).abs() > 1e-8) {
              parts.add((math.min(u, v), math.max(u, v)));
            }
          }
          return parts;
        }

        final offsets = overlap(fronts);
        if (offsets.isEmpty) continue;
        final parcelEdges = overlap(boundaries);
        final cuts = <double>{
          for (final (lo, hi) in [...offsets, ...parcelEdges]) ...[lo, hi],
        }.toList()..sort();
        bool covers(List<(double, double)> segments, double t) =>
            segments.any((part) => t >= part.$1 && t <= part.$2);
        double? start;
        for (var j = 1; j < cuts.length; j++) {
          final lo = cuts[j - 1], hi = cuts[j], mid = (lo + hi) / 2;
          if (covers(offsets, mid) && !covers(parcelEdges, mid)) {
            start ??= lo;
          } else if (start != null) {
            result.add((a + (b - a) * start, a + (b - a) * lo));
            start = null;
          }
        }
        if (start != null) {
          result.add((a + (b - a) * start, a + (b - a) * cuts.last));
        }
      }
    }
    return result;
  }

  /// Returns the actual nearest-point pair for each finite parcel side.
  List<ArchitectSiteSegment> clearances(List<List<Offset>> loops) {
    final result = <ArchitectSiteSegment>[];
    for (var i = 0; i < vertices.length; i++) {
      final (a, b) = side(i);
      ArchitectSiteSegment? closest;
      var best = double.infinity;
      void consider(Offset p, Offset q) {
        final distance = (p - q).distanceSquared;
        if (distance < best) {
          closest = (p, q);
          best = distance;
        }
      }

      for (final loop in loops) {
        for (var j = 0; j < loop.length; j++) {
          final p = loop[j], q = loop[(j + 1) % loop.length];
          final hit = BimLineGeometry.intersection(
            a,
            b,
            p,
            q,
            firstFinite: true,
            secondFinite: true,
          );
          if (hit != null) consider(hit, hit);
          consider(BimLineGeometry.closest(p, a, b), p);
          consider(BimLineGeometry.closest(q, a, b), q);
          consider(a, BimLineGeometry.closest(a, p, q));
          consider(b, BimLineGeometry.closest(b, p, q));
        }
      }
      if (closest != null) result.add(closest!);
    }
    return result;
  }

  bool buildingOutside(List<List<Offset>> loops) {
    for (final loop in loops) {
      for (var i = 0; i < loop.length; i++) {
        final a = loop[i], b = loop[(i + 1) % loop.length];
        if (!contains(a)) return true;
        final cuts = <double>[0, 1];
        for (var j = 0; j < vertices.length; j++) {
          final (p, q) = side(j);
          final hit = BimLineGeometry.intersection(
            a,
            b,
            p,
            q,
            firstFinite: true,
            secondFinite: true,
          );
          if (hit != null) cuts.add(BimLineGeometry.parameter(hit, a, b));
        }
        cuts.sort();
        for (var j = 1; j < cuts.length; j++) {
          if (!contains(a + (b - a) * ((cuts[j - 1] + cuts[j]) / 2))) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
