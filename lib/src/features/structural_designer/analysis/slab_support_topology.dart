import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';
import 'slab_contact_geometry.dart';
import 'slab_topology_analyzer.dart';
import '../models/slab_topology.dart';
import 'structural_polygon_distance.dart';
import 'vertical_capacity_calculator.dart';

class SlabSupportField {
  final List<Offset> polygon;
  final double lxM, lyM, thicknessM;
  final bool requiresReview;
  const SlabSupportField({
    required this.polygon,
    required this.lxM,
    required this.lyM,
    required this.thicknessM,
    this.requiresReview = false,
  });
  double get allowableSpanM =>
      thicknessM > .03 ? (thicknessM - .03) * 22 : double.nan;
  double get utilization => allowableSpanM.isFinite
      ? math.max(lxM, lyM) / allowableSpanM
      : double.infinity;
}

class SlabSupportTopology {
  final List<SlabSupportField> fields;
  final double unresolvedAreaM2;
  final bool limited, invalidGeometry;
  const SlabSupportTopology({
    this.fields = const [],
    this.unresolvedAreaM2 = 0,
    this.limited = false,
    this.invalidGeometry = false,
  });

  /// Closed faces of a planar graph of adjacent support intervals and actual
  /// wall/beam lines. These are geometric plate fields, not FEM elements.
  /// Crossings without a physical support and faces crossing holes are never
  /// certified. Unclosed material remains explicitly unresolved.
  static SlabSupportTopology analyze(
    StoreyLevel floor,
    double scale, {
    List<SupportSpanCheck>? intervals,
  }) {
    final topology = SlabTopologyAnalyzer.analyze(floor.slabs, scale);
    if (!scale.isFinite || scale <= 0 || floor.slabs.isEmpty) {
      return const SlabSupportTopology(invalidGeometry: true);
    }
    if (topology.issue != SlabTopologyIssue.none &&
        topology.issue != SlabTopologyIssue.separateRegions) {
      return const SlabSupportTopology(invalidGeometry: true);
    }
    final netArea = floor.slabs.fold<double>(
      0,
      (a, s) => a + s.netArea / (scale * scale),
    );
    final raw = <(Offset, Offset)>[
      for (final s
          in intervals ??
              VerticalCapacityCalculator.evaluateSupportSpans(floor, scale))
        s.segment,
      for (final w in floor.shearWalls) (w.start, w.end),
      for (final b in floor.beams) (b.start, b.end),
    ];
    if (raw.length > 600 ||
        floor.columns.length + floor.shearWalls.length > 120) {
      return SlabSupportTopology(unresolvedAreaM2: netArea, limited: true);
    }
    final origin = floor.slabs.first.polygon.first;
    String key(Offset p) =>
        '${((p.dx - origin.dx) / scale * 1e6).round()},${((p.dy - origin.dy) / scale * 1e6).round()}';
    final unique = <String, (Offset, Offset)>{};
    for (final e in raw) {
      if ((e.$2 - e.$1).distance <= 1e-7 * scale) continue;
      final ends = [key(e.$1), key(e.$2)]..sort();
      unique.putIfAbsent(ends.join(':'), () => e);
    }
    final segments = unique.values.toList();
    final cuts = [
      for (final _ in segments) <double>[0, 1],
    ];
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    for (var i = 0; i < segments.length; i++) {
      final a = segments[i].$1, u = segments[i].$2 - a;
      for (var j = 0; j < i; j++) {
        final b = segments[j].$1, v = segments[j].$2 - b;
        final den = cross(u, v);
        if (den.abs() > 1e-10 * u.distance * v.distance) {
          final t = cross(b - a, v) / den, q = cross(b - a, u) / den;
          if (t >= -1e-8 && t <= 1 + 1e-8 && q >= -1e-8 && q <= 1 + 1e-8) {
            cuts[i].add(t.clamp(0.0, 1.0));
            cuts[j].add(q.clamp(0.0, 1.0));
          }
        } else {
          for (final p in [b, b + v]) {
            if (StructuralPolygonDistance.pointToSegment(p, a, a + u) <
                1e-7 * scale) {
              cuts[i].add(
                ((p - a).dx * u.dx + (p - a).dy * u.dy) / u.distanceSquared,
              );
            }
          }
          for (final p in [a, a + u]) {
            if (StructuralPolygonDistance.pointToSegment(p, b, b + v) <
                1e-7 * scale) {
              cuts[j].add(
                ((p - b).dx * v.dx + (p - b).dy * v.dy) / v.distanceSquared,
              );
            }
          }
        }
      }
    }
    final nodes = <Offset>[],
        nodeIds = <String, int>{},
        links = <int, Set<int>>{};
    int node(Offset p) => nodeIds.putIfAbsent(key(p), () {
      nodes.add(p);
      return nodes.length - 1;
    });
    for (var i = 0; i < segments.length; i++) {
      cuts[i].sort();
      final a = segments[i].$1, u = segments[i].$2 - a;
      for (var j = 1; j < cuts[i].length; j++) {
        if (cuts[i][j] - cuts[i][j - 1] < 1e-8) continue;
        final x = node(a + u * cuts[i][j - 1]), y = node(a + u * cuts[i][j]);
        if (x == y) continue;
        links.putIfAbsent(x, () => {}).add(y);
        links.putIfAbsent(y, () => {}).add(x);
      }
    }
    // A dead-end support line does not bound a plate field. Remove graph
    // bridges before walking faces; otherwise a legitimate boundary walk
    // visits both sides of that spur and gets rejected as a repeated polygon.
    final entered = <int, int>{}, low = <int, int>{}, bridges = <(int, int)>[];
    var clock = 0;
    void visit(int at, int parent) {
      entered[at] = low[at] = clock++;
      for (final next in links[at] ?? <int>{}) {
        if (next == parent) continue;
        if (!entered.containsKey(next)) {
          visit(next, at);
          low[at] = math.min(low[at]!, low[next]!);
          if (low[next]! > entered[at]!) bridges.add((at, next));
        } else {
          low[at] = math.min(low[at]!, entered[next]!);
        }
      }
    }

    for (final at in links.keys) {
      if (!entered.containsKey(at)) visit(at, -1);
    }
    for (final bridge in bridges) {
      links[bridge.$1]!.remove(bridge.$2);
      links[bridge.$2]!.remove(bridge.$1);
    }
    final adjacency = <int, List<int>>{};
    for (final e in links.entries) {
      adjacency[e.key] = e.value.toList()
        ..sort((a, b) {
          final u = nodes[a] - nodes[e.key], v = nodes[b] - nodes[e.key];
          return math.atan2(u.dy, u.dx).compareTo(math.atan2(v.dy, v.dx));
        });
    }
    final footprints = <List<Offset>>[
      ...floor.columns.map((c) => c.polygonVertices),
      ...floor.shearWalls.map((w) => w.polygonVertices),
    ];
    bool physical(Offset p) => footprints.any(
      (poly) =>
          StructuralPolygonDistance.inside(p, poly) ||
          List.generate(
            poly.length,
            (i) =>
                StructuralPolygonDistance.pointToSegment(
                  p,
                  poly[i],
                  poly[(i + 1) % poly.length],
                ) <
                1e-6 * scale,
          ).any((v) => v),
    );
    // Freeze the assessment frame to the architecture/axes. Resizing a wall
    // must not rotate every measured field or change its score by itself.
    var direction = const Offset(1, 0);
    final axes = [...floor.gridAxes]..sort((a, b) => a.id.compareTo(b.id));
    if (axes.isNotEmpty && (axes.first.end - axes.first.start).distance > 0) {
      final v = axes.first.end - axes.first.start;
      direction = v / v.distance;
    } else {
      final boundary = [
        for (final s in floor.slabs)
          for (var i = 0; i < s.polygon.length; i++)
            (s.polygon[i], s.polygon[(i + 1) % s.polygon.length]),
      ];
      boundary.sort(
        (a, b) => (b.$2 - b.$1).distance.compareTo((a.$2 - a.$1).distance),
      );
      if (boundary.isNotEmpty &&
          (boundary.first.$2 - boundary.first.$1).distance > 0) {
        final v = boundary.first.$2 - boundary.first.$1;
        direction = v / v.distance;
      }
    }
    final normal = Offset(-direction.dy, direction.dx);
    final visited = <String>{}, fields = <SlabSupportField>[];
    var covered = 0.0;
    for (final e in adjacency.entries) {
      for (final neighbor in e.value) {
        if (visited.contains('${e.key}:$neighbor')) continue;
        var a = e.key, b = neighbor;
        final face = <int>[];
        var closed = false;
        for (var step = 0; step < links.length * 2 + 2; step++) {
          final edge = '$a:$b';
          if (visited.contains(edge)) {
            closed = a == e.key && b == neighbor;
            break;
          }
          visited.add(edge);
          face.add(a);
          final at = adjacency[b]!;
          final next = at[(at.indexOf(a) - 1 + at.length) % at.length];
          a = b;
          b = next;
        }
        if (!closed || face.length < 3 || face.toSet().length != face.length) {
          continue;
        }
        final poly = face.map((i) => nodes[i]).toList();
        var signed = 0.0;
        for (var i = 0; i < poly.length; i++) {
          signed += cross(
            poly[i] - origin,
            poly[(i + 1) % poly.length] - origin,
          );
        }
        if (signed <= 1e-6 * scale * scale) {
          continue; // excludes the unbounded exterior face
        }
        final area = signed / 2 / (scale * scale);
        final contact = SlabContactGeometry.measure(poly, floor.slabs, scale);
        if (contact == null ||
            (contact.areaM2 - area).abs() > math.max(1e-8, area * 1e-7)) {
          continue;
        }
        final touched = floor.slabs
            .where(
              (s) =>
                  (SlabContactGeometry.measure(poly, [s], scale)?.areaM2 ?? 0) >
                  1e-8,
            )
            .toList();
        final h = touched.isEmpty
            ? double.nan
            : touched.map((s) => s.thickness).reduce(math.min);
        double projection(Offset p, Offset u) =>
            (p - origin).dx * u.dx + (p - origin).dy * u.dy;
        final xs = poly.map((p) => projection(p, direction)),
            ys = poly.map((p) => projection(p, normal));
        final review = face.any((i) => !physical(nodes[i]));
        fields.add(
          SlabSupportField(
            polygon: List.unmodifiable(poly),
            lxM: (xs.reduce(math.max) - xs.reduce(math.min)) / scale,
            lyM: (ys.reduce(math.max) - ys.reduce(math.min)) / scale,
            thicknessM: h,
            requiresReview: review,
          ),
        );
        if (!review) covered += area;
      }
    }
    return SlabSupportTopology(
      fields: List.unmodifiable(fields),
      unresolvedAreaM2: math.max(0, netArea - covered),
    );
  }
}
