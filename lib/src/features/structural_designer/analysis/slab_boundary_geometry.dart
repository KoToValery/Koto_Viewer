import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import 'slab_contact_geometry.dart';
import 'structural_polygon_distance.dart';

enum PunchingSupportPosition { interior, edge, corner, undetermined }

class SlabBoundaryEdge {
  final Offset a, b;
  final bool opening;
  const SlabBoundaryEdge(this.a, this.b, {this.opening = false});
}

class PunchingPositionCheck {
  final PunchingSupportPosition position;
  final bool nearOpening;
  const PunchingPositionCheck(this.position, {this.nearOpening = false});
  double get beta => switch (position) {
    PunchingSupportPosition.interior => 1.15,
    PunchingSupportPosition.edge => 1.4,
    PunchingSupportPosition.corner => 1.5,
    PunchingSupportPosition.undetermined => 1.5,
  };
}

/// Exposed boundaries of the slab union. Shared and partly shared seams are
/// split and excluded; holes remain free boundaries. No midpoint-distance rule.
class SlabBoundaryGeometry {
  static bool contains(Offset p, List<StructuralSlab> slabs) => slabs.any(
    (s) =>
        StructuralPolygonDistance.inside(p, s.polygon) &&
        !s.openings.any((h) => StructuralPolygonDistance.inside(p, h)),
  );

  static bool segmentOnSlabs(
    Offset a,
    Offset b,
    List<StructuralSlab> slabs,
    double scale,
  ) {
    final u = b - a, cuts = <double>[0, 1];
    for (final slab in slabs) {
      for (final ring in [slab.polygon, ...slab.openings]) {
        for (var i = 0; i < ring.length; i++) {
          final c = ring[i], v = ring[(i + 1) % ring.length] - c;
          final den = u.dx * v.dy - u.dy * v.dx;
          if (den.abs() < 1e-12 * u.distance * v.distance) continue;
          final d = c - a,
              t = (d.dx * v.dy - d.dy * v.dx) / den,
              q = (d.dx * u.dy - d.dy * u.dx) / den;
          if (t > 0 && t < 1 && q >= 0 && q <= 1) cuts.add(t);
        }
      }
    }
    cuts.sort();
    for (var i = 1; i < cuts.length; i++) {
      if (cuts[i] - cuts[i - 1] < 1e-10) continue;
      final p = a + u * ((cuts[i] + cuts[i - 1]) / 2);
      final inMaterial = slabs.any(
        (s) =>
            (StructuralPolygonDistance.inside(p, s.polygon) ||
                List.generate(
                  s.polygon.length,
                  (j) =>
                      StructuralPolygonDistance.pointToSegment(
                        p,
                        s.polygon[j],
                        s.polygon[(j + 1) % s.polygon.length],
                      ) <=
                      1e-7 * scale,
                ).any((v) => v)) &&
            !s.openings.any((h) => StructuralPolygonDistance.inside(p, h)),
      );
      if (!inMaterial) return false;
    }
    return true;
  }

  static List<SlabBoundaryEdge> exposedEdges(
    List<StructuralSlab> slabs,
    double scale,
  ) {
    final edges = <SlabBoundaryEdge>[
      for (final s in slabs)
        for (final ring in [s.polygon, ...s.openings])
          for (var i = 0; i < ring.length; i++)
            SlabBoundaryEdge(
              ring[i],
              ring[(i + 1) % ring.length],
              opening: !identical(ring, s.polygon),
            ),
    ];
    final result = <SlabBoundaryEdge>[];
    for (final edge in edges) {
      final v = edge.b - edge.a;
      if (v.distance < 1e-8 * scale) continue;
      final cuts = <double>[0, 1];
      for (final other in edges) {
        for (final p in [other.a, other.b]) {
          if (StructuralPolygonDistance.pointToSegment(p, edge.a, edge.b) <
              1e-7 * scale) {
            cuts.add(
              ((p - edge.a).dx * v.dx + (p - edge.a).dy * v.dy) /
                  v.distanceSquared,
            );
          }
        }
        final w = other.b - other.a;
        final den = v.dx * w.dy - v.dy * w.dx;
        if (den.abs() < 1e-12 * v.distance * w.distance) continue;
        final d = other.a - edge.a;
        final t = (d.dx * w.dy - d.dy * w.dx) / den;
        final q = (d.dx * v.dy - d.dy * v.dx) / den;
        if (t > 0 && t < 1 && q >= 0 && q <= 1) cuts.add(t);
      }
      cuts.sort();
      final n = Offset(-v.dy, v.dx) / v.distance * (1e-6 * scale);
      for (var i = 1; i < cuts.length; i++) {
        if (cuts[i] - cuts[i - 1] < 1e-9) continue;
        final midpoint = edge.a + v * ((cuts[i] + cuts[i - 1]) / 2);
        if (contains(midpoint + n, slabs) == contains(midpoint - n, slabs)) {
          continue;
        }
        result.add(
          SlabBoundaryEdge(
            edge.a + v * cuts[i - 1],
            edge.a + v * cuts[i],
            opening: edge.opening,
          ),
        );
      }
    }
    return result;
  }

  static double distanceToFootprint(SlabBoundaryEdge edge, List<Offset> poly) {
    if (StructuralPolygonDistance.inside(edge.a, poly) ||
        StructuralPolygonDistance.inside(edge.b, poly)) {
      return 0;
    }
    var distance = double.infinity;
    final u = edge.b - edge.a;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length], v = b - a;
      final den = u.dx * v.dy - u.dy * v.dx;
      if (den != 0) {
        final d = a - edge.a;
        final t = (d.dx * v.dy - d.dy * v.dx) / den;
        final q = (d.dx * u.dy - d.dy * u.dx) / den;
        if (t >= 0 && t <= 1 && q >= 0 && q <= 1) return 0;
      }
      distance = math.min(
        distance,
        math.min(
          math.min(
            StructuralPolygonDistance.pointToSegment(a, edge.a, edge.b),
            StructuralPolygonDistance.pointToSegment(b, edge.a, edge.b),
          ),
          math.min(
            StructuralPolygonDistance.pointToSegment(edge.a, a, b),
            StructuralPolygonDistance.pointToSegment(edge.b, a, b),
          ),
        ),
      );
    }
    return distance;
  }

  static PunchingPositionCheck classify(
    StructuralColumn column,
    List<StructuralSlab> slabs,
    double scale,
    double effectiveDepthM, {
    List<SlabBoundaryEdge>? boundaries,
  }) {
    final contact = SlabContactGeometry.columnContact(column, slabs, scale);
    if (contact == null || contact.areaM2 <= 1e-10 || effectiveDepthM <= 0) {
      return const PunchingPositionCheck(PunchingSupportPosition.undetermined);
    }
    final allBoundaries = boundaries ?? exposedEdges(slabs, scale);
    final near = allBoundaries
        .where(
          (edge) =>
              distanceToFootprint(edge, column.polygonVertices) <=
              2 * effectiveDepthM * scale + 1e-8 * scale,
        )
        .toList();
    final outer = near.where((e) => !e.opening).toList();
    var corner = false;
    for (var i = 0; i < outer.length; i++) {
      for (var j = 0; j < i; j++) {
        final u = outer[i].b - outer[i].a, v = outer[j].b - outer[j].a;
        if ((u.dx * v.dy - u.dy * v.dx).abs() > .3 * u.distance * v.distance) {
          corner = true;
        }
      }
    }
    return PunchingPositionCheck(
      corner
          ? PunchingSupportPosition.corner
          : outer.isNotEmpty
          ? PunchingSupportPosition.edge
          : PunchingSupportPosition.interior,
      nearOpening: allBoundaries.any(
        (e) =>
            e.opening &&
            distanceToFootprint(e, column.polygonVertices) <=
                6 * effectiveDepthM * scale + 1e-8 * scale,
      ),
    );
  }
}
