import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../models/structural_element.dart';
import 'staircase_geometry_detector.dart';
import 'staircase_inventory.dart';
import 'slab_contact_geometry.dart';

/// Observed closed CAD faces near flights, without inventing a closing edge.
/// A proposal may be a room or another outline: confirmation remains mandatory.
class StaircaseOpeningContours {
  /// Search around every part of a staircase. A larger family search window
  /// can join a neighbouring room into the CAD graph; retain the observed
  /// bounded faces found around its individual flights as well.
  static List<List<Offset>> findAssembly(
    StairGeometryResult evidence,
    List<StairFlightCandidate> flights,
    double scale,
  ) {
    if (flights.isEmpty) return [];
    final whole = StairFlightCandidate(
      polygon: compute2DConvexHull(flights.expand((f) => f.polygon).toList()),
      treads: flights.expand((f) => f.treads).toList(),
      boundarySides: 0,
      spacingM: 0,
    );
    final result = <List<Offset>>[], seen = <String>{};
    for (final flight in [whole, ...flights]) {
      for (final contour in find(evidence, flight, scale)) {
        final points = [
          for (final p in contour)
            '${(p.dx / scale * 1000).round()},${(p.dy / scale * 1000).round()}',
        ];
        var start = 0;
        for (var i = 1; i < points.length; i++) {
          if (points[i].compareTo(points[start]) < 0) start = i;
        }
        final key = [...points.skip(start), ...points.take(start)].join('/');
        if (seen.add(key)) result.add(contour);
      }
    }
    result.sort(
      (a, b) => StructuralSlab.calculateArea(
        a,
      ).compareTo(StructuralSlab.calculateArea(b)),
    );
    return result.take(8).toList();
  }

  static List<List<Offset>> find(
    StairGeometryResult evidence,
    StairFlightCandidate flight,
    double scale,
  ) {
    if (!scale.isFinite ||
        scale <= 0 ||
        evidence.limited ||
        flight.polygon.length < 3) {
      return [];
    }
    final polygon = flight.polygon;
    final bounds = Rect.fromLTRB(
      polygon.map((p) => p.dx).reduce(math.min),
      polygon.map((p) => p.dy).reduce(math.min),
      polygon.map((p) => p.dx).reduce(math.max),
      polygon.map((p) => p.dy).reduce(math.max),
    ).inflate(1.5 * scale);
    // Use the target level's boundaries. Lower-level risers are evidence only.
    final treadKeys = <String>{};
    String point(Offset p) =>
        '${(p.dx / scale * 1000).round()},${(p.dy / scale * 1000).round()}';
    String key((Offset, Offset) s) {
      final a = point(s.$1), b = point(s.$2);
      return a.compareTo(b) < 0 ? '$a/$b' : '$b/$a';
    }

    for (final f in evidence.flights) {
      for (final s in f.treads) {
        treadKeys.add(key(s));
      }
    }
    final lines = (evidence.boundaryStrokes ?? evidence.strokes)
        .where(
          (s) =>
              !treadKeys.contains(key(s)) &&
              bounds.contains(s.$1) &&
              bounds.contains(s.$2),
        )
        .toList();
    if (lines.length > 600) return [];
    final splits = [
      for (final s in lines) <Offset>[s.$1, s.$2],
    ];
    for (var i = 0; i < lines.length; i++) {
      for (var j = i + 1; j < lines.length; j++) {
        final p = DxfSegmentSnap.intersection(lines[i], lines[j]);
        if (p != null) {
          splits[i].add(p);
          splits[j].add(p);
        }
      }
    }
    final points = <Offset>[], adjacency = <int, Set<int>>{};
    final cells = <String, List<int>>{};
    final tolerance = .001 * scale;
    int node(Offset p) {
      final x = (p.dx / tolerance).floor(), y = (p.dy / tolerance).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final i in cells['${x + dx},${y + dy}'] ?? const <int>[]) {
            if ((points[i] - p).distance <= tolerance) return i;
          }
        }
      }
      final i = points.length;
      points.add(p);
      cells.putIfAbsent('$x,$y', () => []).add(i);
      return i;
    }

    for (var i = 0; i < lines.length; i++) {
      final d = lines[i].$2 - lines[i].$1;
      double parameter(Offset p) =>
          (p - lines[i].$1).dx * d.dx + (p - lines[i].$1).dy * d.dy;
      splits[i].sort((a, b) => parameter(a).compareTo(parameter(b)));
      int? previous;
      for (final p in splits[i]) {
        final current = node(p);
        if (previous != null && previous != current) {
          adjacency.putIfAbsent(previous, () => {}).add(current);
          adjacency.putIfAbsent(current, () => {}).add(previous);
        }
        previous = current;
      }
    }
    if (points.length > 1600) return [];
    // Remove dangling CAD strokes; they are not closing edges of a face.
    final leaves = [
      for (final e in adjacency.entries)
        if (e.value.length < 2) e.key,
    ];
    for (var cursor = 0; cursor < leaves.length; cursor++) {
      final leaf = leaves[cursor];
      final edges = adjacency.remove(leaf);
      for (final neighbour in edges ?? const <int>{}) {
        adjacency[neighbour]?.remove(leaf);
        if (adjacency[neighbour]?.length == 1) leaves.add(neighbour);
      }
    }
    final neighbours = <int, List<int>>{};
    for (final entry in adjacency.entries) {
      final p = points[entry.key];
      neighbours[entry.key] = entry.value.toList()
        ..sort(
          (a, b) => math
              .atan2(points[a].dy - p.dy, points[a].dx - p.dx)
              .compareTo(math.atan2(points[b].dy - p.dy, points[b].dx - p.dx)),
        );
    }
    final visited = <String>{}, contours = <List<Offset>>[];
    final flightArea = StructuralSlab.calculateArea(polygon) / (scale * scale);
    final reference = StructuralSlab(id: 'flight', polygon: polygon);
    for (final entry in neighbours.entries) {
      for (final end in entry.value) {
        final first = entry.key;
        if (visited.contains('$first/$end')) continue;
        var a = first, b = end;
        final loop = <Offset>[];
        bool closed = false;
        for (var step = 0; step < 3200; step++) {
          if (!visited.add('$a/$b')) break;
          loop.add(points[a]);
          final choices = neighbours[b]!;
          final next =
              choices[(choices.indexOf(a) - 1 + choices.length) %
                  choices.length];
          a = b;
          b = next;
          if (a == first && b == end) {
            closed = true;
            break;
          }
        }
        if (!closed || loop.length < 3 || loop.length > 160) continue;
        var signed = 0.0;
        for (var i = 0; i < loop.length; i++) {
          final a = loop[i] - loop.first,
              b = loop[(i + 1) % loop.length] - loop.first;
          signed += a.dx * b.dy - b.dx * a.dy;
        }
        if (signed <= 0) {
          continue; // Exterior face; retain bounded interior faces.
        }
        final area = signed / (2 * scale * scale);
        if (area < flightArea * .5 || area > flightArea * 5) continue;
        final contact = SlabContactGeometry.measure(loop, [reference], scale);
        if (contact == null || contact.areaM2 < flightArea * .35) continue;
        final cleaned = StructuralSlab.cleanPolygon(
          loop,
          minDistance: .001 * scale,
        );
        if (!StaircaseInventory.validZone(cleaned, scale)) continue;
        contours.add(cleaned);
        if (contours.length >= 8) break;
      }
      if (contours.length >= 8) break;
    }
    contours.sort(
      (a, b) => StructuralSlab.calculateArea(
        a,
      ).compareTo(StructuralSlab.calculateArea(b)),
    );
    return contours;
  }
}
