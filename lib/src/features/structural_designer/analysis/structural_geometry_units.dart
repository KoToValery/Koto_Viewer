import 'dart:ui';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../models/structural_element.dart';

/// Local metre coordinates for numerical assessment only. Model objects and
/// physical elevations/loads stay unchanged. Nanometre rounding removes CAD
/// arithmetic noise, not architectural geometry or a placement tolerance.
class StructuralGeometryUnits {
  final double scale;
  final Offset origin;
  const StructuralGeometryUnits(this.scale, this.origin);
  double _round(double x) => BimPrecisionPolicy.removeNumericalNoise(x);
  BimCoordinateFrame get frame =>
      BimCoordinateFrame(origin: origin, unitsPerMeter: scale);
  Offset toMetres(Offset p) {
    final metres = frame.toModel(p);
    return Offset(_round(metres.dx), _round(metres.dy));
  }

  Offset toCad(Offset p) => frame.toCad(p);
  StructuralGridAxis axis(StructuralGridAxis a) =>
      a.copyWith(start: toMetres(a.start), end: toMetres(a.end));
  StoreyLevel floor(StoreyLevel s) => s.copyWith(
    columns: [
      for (final c in s.columns)
        c.copyWith(
          center: toMetres(c.center),
          width: _round(c.width / scale),
          height: _round(c.height / scale),
          thickness: _round(c.thickness / scale),
        ),
    ],
    shearWalls: [
      for (final w in s.shearWalls)
        w.copyWith(
          start: toMetres(w.start),
          end: toMetres(w.end),
          thickness: _round(w.thickness / scale),
        ),
    ],
    beams: [
      for (final b in s.beams)
        b.copyWith(
          start: toMetres(b.start),
          end: toMetres(b.end),
          width: _round(b.width / scale),
          depth: _round(b.depth / scale),
        ),
    ],
    slabs: [
      for (final slab in s.slabs)
        slab.copyWith(
          polygon: slab.polygon.map(toMetres).toList(),
          openings: [for (final h in slab.openings) h.map(toMetres).toList()],
        ),
    ],
    gridAxes: s.gridAxes.map(axis).toList(),
    staircaseZones: {
      for (final e in s.staircaseZones.entries)
        e.key: e.value.map(toMetres).toList(),
    },
  );
  StructuralProject project(StructuralProject p) => p.copyWith(
    storeys: p.storeys.map(floor).toList(),
    gridAxes: p.gridAxes.map(axis).toList(),
  );
}
