import 'dart:ui';
import '../models/structural_element.dart';

/// Local metre coordinates for numerical assessment only. Model objects and
/// physical elevations/loads stay unchanged. Nanometre rounding removes CAD
/// arithmetic noise, not architectural geometry or a placement tolerance.
class StructuralGeometryUnits {
  final double scale;
  final Offset origin;
  const StructuralGeometryUnits(this.scale, this.origin);
  double _round(double x) => x.isFinite ? (x * 1e9).round() / 1e9 : x;
  Offset toMetres(Offset p) => Offset(
    _round((p.dx - origin.dx) / scale),
    _round((p.dy - origin.dy) / scale),
  );
  Offset toCad(Offset p) => origin + p * scale;
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
  );
  StructuralProject project(StructuralProject p) => p.copyWith(
    storeys: p.storeys.map(floor).toList(),
    gridAxes: p.gridAxes.map(axis).toList(),
  );
}
