import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import '../models/wall_axis_models.dart';
import 'geometric_window_detector.dart';
import 'slab_contact_geometry.dart';

/// Architectural permission for the entire section, independent of grid axes.
/// Only explicitly detected, jamb-bounded openings can extend the solid domain.
class WallPlacementDomain {
  final double scale;
  final List<StructuralSlab> solid;
  final List<GeometricWindowOpening> openings;
  late final _solidBounds = solid.map((s) => _bounds(s.polygon)).toList();
  late final _openingBounds = openings
      .map((o) => _bounds(o.barrierPolygon))
      .toList();
  WallPlacementDomain._(this.scale, this.solid, this.openings);
  static Rect _bounds(List<Offset> p) => Rect.fromLTRB(
    p.map((v) => v.dx).reduce(math.min),
    p.map((v) => v.dy).reduce(math.min),
    p.map((v) => v.dx).reduce(math.max),
    p.map((v) => v.dy).reduce(math.max),
  );

  static List<Offset> strip(Offset a, Offset b, double width) {
    final u = (b - a) / (b - a).distance;
    final n = Offset(-u.dy, u.dx) * width / 2;
    return [a + n, b + n, b - n, a - n];
  }

  factory WallPlacementDomain.build(
    List<WallPairCandidate> pairs,
    List<GeometricWindowOpening> detectedOpenings,
    double scale,
  ) {
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    final polygons = <StructuralSlab>[];
    final validPairs = <WallPairCandidate>[];
    for (final pair in pairs) {
      final a = pair.centerlineStart, b = pair.centerlineEnd;
      if (![
            a.dx,
            a.dy,
            b.dx,
            b.dy,
            pair.perpendicularDistance,
          ].every((x) => x.isFinite) ||
          (b - a).distance < .1 * scale ||
          pair.perpendicularDistance <= 0) {
        continue;
      }
      validPairs.add(pair);
      polygons.add(
        StructuralSlab(
          id: 'wall-domain:${polygons.length}',
          polygon: strip(a, b, pair.perpendicularDistance),
        ),
      );
    }
    final openings = <GeometricWindowOpening>[];
    for (final opening in detectedOpenings) {
      final a = opening.start, b = opening.end;
      if (![
            a.dx,
            a.dy,
            b.dx,
            b.dy,
            opening.thickness,
          ].every((x) => x.isFinite) ||
          (b - a).distance < .1 * scale ||
          opening.thickness <= 0) {
        continue;
      }
      final u = (b - a) / (b - a).distance, n = Offset(-u.dy, u.dx);
      double? jambWidth(Offset p, bool before) {
        double? width;
        for (final pair in validPairs) {
          final x = pair.centerlineStart, y = pair.centerlineEnd;
          final v = (y - x) / (y - x).distance;
          if (dot(u, v).abs() < .999 ||
              dot(x - p, n).abs() > .02 * scale ||
              math.min((x - p).distance, (y - p).distance) > .03 * scale) {
            continue;
          }
          final middle = (x + y) / 2;
          if (before ? dot(middle - p, u) >= 0 : dot(middle - p, u) <= 0) {
            continue;
          }
          width = width == null
              ? pair.perpendicularDistance
              : math.min(width, pair.perpendicularDistance);
        }
        return width;
      }

      final left = jambWidth(a, true), right = jambWidth(b, false);
      if (left == null || right == null) continue;
      final width = math.min(opening.thickness, math.min(left, right));
      openings.add(
        GeometricWindowOpening(
          start: a,
          end: b,
          thickness: width,
          length: (b - a).distance,
          barrierPolygon: strip(a, b, width),
          evidence: opening.evidence,
        ),
      );
    }
    openings.sort((a, b) {
      final x = a.start.dx.compareTo(b.start.dx);
      return x != 0 ? x : a.start.dy.compareTo(b.start.dy);
    });
    return WallPlacementDomain._(
      scale,
      polygons
          .map(
            (p) => p.copyWith(
              openings: openings
                  .where(
                    (o) =>
                        _bounds(p.polygon).overlaps(_bounds(o.barrierPolygon)),
                  )
                  .map((o) => o.barrierPolygon)
                  .toList(),
            ),
          )
          .toList(),
      openings,
    );
  }

  bool contains(List<Offset> footprint, {bool includeOpenings = false}) {
    final area = StructuralSlab.calculateArea(footprint) / (scale * scale);
    if (!area.isFinite || area <= 1e-10) return false;
    final bounds = _bounds(footprint);
    final contact = SlabContactGeometry.measure(footprint, [
      for (var i = 0; i < solid.length; i++)
        if (bounds.overlaps(_solidBounds[i])) solid[i],
      if (includeOpenings)
        for (var i = 0; i < openings.length; i++)
          if (bounds.overlaps(_openingBounds[i]))
            StructuralSlab(
              id: 'opening-domain:$i',
              polygon: openings[i].barrierPolygon,
            ),
    ], scale);
    return contact != null &&
        (contact.areaM2 - area).abs() <= math.max(1e-10, area * 1e-7);
  }
}
