import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_polygon_geometry.dart';
import 'architect_slab_geometry.dart';
import 'architect_stair_geometry.dart';
import 'architect_stair_layout_resolver.dart';
import '../rendering/architect_stair_mesh.dart';

/// Minimum vertical clearance over complete tread/landing areas. For planar
/// undersides extrema occur at overlay vertices, including opening rims.
class ArchitectStairHeadroom {
  static double? minimum(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectStair stair,
  ) {
    final d = stair.design;
    if (d == null) return null;
    final geometry = ArchitectStairGeometry.of(stair);
    double? minimum;
    var hasSlabs = false;
    void obstacle(
      List<Offset> walk,
      double level,
      List<Offset> outer,
      List<List<Offset>> holes,
      double Function(Offset) bottom,
      double Function(Offset) top,
    ) {
      if (walk.length < 3 || outer.length < 3) return;
      var area = Path.combine(
        PathOperation.intersect,
        Path()..addPolygon(walk, true),
        Path()..addPolygon(outer, true),
      );
      for (final h in holes) {
        area = Path.combine(
          PathOperation.difference,
          area,
          Path()..addPolygon(h, true),
        );
      }
      if (!ArchitectStairLayoutResolver.hasArea(area)) return;
      final rings = [walk, outer, ...holes];
      final candidates = <Offset>[...walk, ...outer, ...holes.expand((h) => h)];
      for (var r = 0; r < rings.length; r++) {
        for (var s = r + 1; s < rings.length; s++) {
          for (var i = 0; i < rings[r].length; i++) {
            final a = rings[r][i], u = rings[r][(i + 1) % rings[r].length] - a;
            for (var j = 0; j < rings[s].length; j++) {
              final b = rings[s][j],
                  v = rings[s][(j + 1) % rings[s].length] - b;
              final den = ArchitectPolygonGeometry.cross(u, v);
              if (den.abs() < 1e-12) continue;
              final t = ArchitectPolygonGeometry.cross(b - a, v) / den;
              final q = ArchitectPolygonGeometry.cross(b - a, u) / den;
              if (t >= -1e-9 && t <= 1 + 1e-9 && q >= -1e-9 && q <= 1 + 1e-9) {
                candidates.add(a + u * t);
              }
            }
          }
        }
      }
      bool onArea(Offset p) {
        if (area.contains(p)) return true;
        for (final o in const [
          Offset(1e-7, 0),
          Offset(-1e-7, 0),
          Offset(0, 1e-7),
          Offset(0, -1e-7),
        ]) {
          if (area.contains(p + o)) return true;
        }
        return false;
      }

      for (final p in candidates.where(onArea)) {
        if (top(p) <= level + 1e-7) continue;
        final gap = math.max(0.0, bottom(p) - level);
        minimum = minimum == null ? gap : math.min(minimum!, gap);
      }
    }

    for (final surface in stair.plan.surfaces) {
      final z = storey.elevation + d.startOffset + surface.elevation;
      for (final floor in project.storeys) {
        for (final slab in floor.slabs) {
          hasSlabs = true;
          final layers = ArchitectSlabGeometry.surfaces(project, floor, slab);
          if (layers.isEmpty) continue;
          obstacle(
            surface.polygon,
            z,
            slab.polygon,
            ArchitectSlabGeometry.holes(floor, slab, project: project),
            layers.last.bottomAt,
            layers.first.topAt,
          );
        }
      }
      // An upper flight is an obstacle even when no slab is present above it.
      for (final f in geometry.flights) {
        if (f.base <= surface.elevation + 1e-7) continue;
        if (d.construction != StairConstruction.concrete) {
          // Open risers have no full-width waist. Actual treads and the two
          // side stringers supply separate overhead surfaces.
          for (var i = 0; i < f.count - 1; i++) {
            final a = i * f.going - d.nosingProjection, b = (i + 1) * f.going;
            final top =
                storey.elevation + d.startOffset + f.base + (i + 1) * f.riser;
            obstacle(
              surface.polygon,
              z,
              [
                f.point(a, -f.width / 2),
                f.point(b, -f.width / 2),
                f.point(b, f.width / 2),
                f.point(a, f.width / 2),
              ],
              [],
              (_) => top - d.treadThickness,
              (_) => top,
            );
          }
          for (final side in [-1.0, 1.0]) {
            final center = side * (f.width - d.stringerWidth) / 2;
            final low = center - d.stringerWidth / 2,
                high = center + d.stringerWidth / 2;
            double bottom(Offset p) {
              final t =
                  ArchitectStairGeometry.dot(p - f.origin, f.axis) / f.run;
              final climb = d.construction == StairConstruction.timber
                  ? f.riser + t * (f.count - 2) * f.riser
                  : t * (f.count - 1) * f.riser;
              return storey.elevation +
                  d.startOffset +
                  f.base +
                  climb -
                  d.treadThickness -
                  d.stringerDepth;
            }

            obstacle(
              surface.polygon,
              z,
              [
                f.point(0, low),
                f.point(f.run, low),
                f.point(f.run, high),
                f.point(0, high),
              ],
              [],
              bottom,
              (p) => bottom(p) + d.stringerDepth,
            );
          }
          continue;
        }
        final polygon = [
          f.point(0, -f.width / 2),
          f.point(f.run, -f.width / 2),
          f.point(f.run, f.width / 2),
          f.point(0, f.width / 2),
        ];
        double bottom(Offset p) =>
            storey.elevation +
            d.startOffset +
            f.base +
            ArchitectStairGeometry.dot(p - f.origin, f.axis) /
                f.going *
                f.riser -
            (d.construction == StairConstruction.concrete
                ? d.finishThickness + d.concreteThickness
                : d.treadThickness + d.stringerDepth);
        obstacle(
          surface.polygon,
          z,
          polygon,
          [],
          bottom,
          (p) => bottom(p) + d.concreteThickness + d.riser + d.finishThickness,
        );
      }
      for (final l in geometry.landings) {
        if (l.elevation <= surface.elevation + 1e-7) continue;
        final top = storey.elevation + d.startOffset + l.elevation;
        obstacle(
          surface.polygon,
          z,
          l.polygon,
          [],
          (_) =>
              top -
              (d.construction == StairConstruction.concrete
                  ? d.finishThickness + d.concreteThickness
                  : d.treadThickness),
          (_) => top,
        );
        if (d.construction != StairConstruction.concrete) {
          for (final p in ArchitectStairMesh.landingSupportPolygons(
            l.polygon,
            d.stringerWidth,
          )) {
            obstacle(
              surface.polygon,
              z,
              p,
              [],
              (_) => top - d.treadThickness - d.stringerDepth,
              (_) => top - d.treadThickness,
            );
          }
        }
      }
    }
    // Absence of modelled obstructions is not a measured clearance.
    return minimum ?? (hasSlabs ? double.infinity : null);
  }
}
