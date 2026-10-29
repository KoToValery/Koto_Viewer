import 'dart:math' as math;
import 'dart:ui';

import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_mesh_section.dart';
import '../rendering/architect_path_solid.dart';
import 'architect_roof_junctions.dart';

/// A physical horizontal purlin on a high, level roof edge. Its extent and
/// orientation are independent of the direction of a particular section.
class ArchitectRoofRidgeBeam {
  final Offset start, end;
  final double width, height, top;
  final String roofId;
  final Set<String> roofIds;
  Path? _planClip;
  ArchitectRoofRidgeBeam(
    this.start,
    this.end,
    this.width,
    this.height,
    this.top,
    this.roofId,
  ) : roofIds = {roofId};

  double get bottom => top - height;
  Offset get axis => (end - start) / (end - start).distance;
  Path get footprint {
    final n = Offset(-axis.dy, axis.dx) * (width / 2);
    final outline = Path()
      ..addPolygon([start + n, end + n, end - n, start - n], true);
    return _planClip == null
        ? outline
        : ArchitectMeshSection.combine(
            PathOperation.intersect,
            outline,
            _planClip!,
          );
  }

  List<Triangle3D> mesh({Path? planClip}) {
    final path = planClip == null
        ? footprint
        : ArchitectMeshSection.combine(
            PathOperation.intersect,
            footprint,
            planClip,
          );
    return ArchitectPathSolid.extrude(
      path,
      bottom,
      top,
      const Color(0xffb8864b),
    );
  }

  /// Concrete bearing under this purlin, shared by all views. Ordinary eaves
  /// plates are not stacked through a ridge purlin on the same wall.
  List<ArchitectRoofRidgeBearing> bearings(
    ArchitectStorey roofStorey,
    ArchitectStorey? wallStorey,
  ) {
    if (wallStorey == null) return [];
    final roof = roofStorey.roofs.firstWhere((r) => r.id == roofId);
    final timber = roof.assembly.timber;
    if (!timber.hasRingBeam || timber.ringBeamHeight <= .01) return [];
    final result = <ArchitectRoofRidgeBearing>[];
    for (final wall in wallStorey.walls) {
      if (wall.isParapet ||
          (!wall.followStoreyHeight &&
              wallStorey.elevation +
                      wall.baseOffset +
                      wall.effectiveHeight(wallStorey.height) <
                  bottom - timber.ringBeamHeight - .12)) {
        continue;
      }
      final n =
          Offset(-axis.dy, axis.dx) * (math.max(width, wall.coreThickness) / 2);
      final extent = Path()
        ..addPolygon([start + n, end + n, end - n, start - n], true);
      var path = ArchitectMeshSection.combine(
        PathOperation.intersect,
        extent,
        Path()..addPolygon(wall.coreCorners, true),
      );
      if (_planClip != null) {
        path = ArchitectMeshSection.combine(
          PathOperation.intersect,
          path,
          _planClip!,
        );
      }
      final bounds = path.getBounds();
      if (bounds.width < 1e-5 || bounds.height < 1e-5) continue;
      result.add(
        ArchitectRoofRidgeBearing(this, wall, path, timber.ringBeamHeight),
      );
    }
    return result;
  }

  static List<ArchitectRoofRidgeBeam> build(
    ArchitectStorey storey, {
    ArchitectProject? project,
  }) {
    final result = <ArchitectRoofRidgeBeam>[];
    final roofs = [...storey.roofs]..sort((a, b) => a.id.compareTo(b.id));
    for (final roof in roofs) {
      final timber = roof.assembly.timber;
      if (roof.assembly.panels != null ||
          !timber.hasRidgePurlin ||
          roof.slopeDegrees < 5 ||
          roof.points.length < 3) {
        continue;
      }
      for (var i = 0; i < roof.points.length; i++) {
        final a = roof.points[i], b = roof.points[(i + 1) % roof.points.length];
        final mid = (a + b) / 2;
        if ((b - a).distance < .01 ||
            (roof.topElevationAt(a) - roof.topElevationAt(b)).abs() > 1e-5 ||
            (roof.signedDistanceFromEaves(mid) - roof.maxSlopeRun).abs() >
                1e-4) {
          continue;
        }
        final top = storey.elevation + roof.undersideElevationAt(mid);
        final existing = result
            .where(
              (beam) =>
                  ((beam.start - a).distance < 1e-4 &&
                          (beam.end - b).distance < 1e-4 ||
                      (beam.start - b).distance < 1e-4 &&
                          (beam.end - a).distance < 1e-4) &&
                  (beam.top - top).abs() < 1e-4,
            )
            .firstOrNull;
        if (existing != null) {
          existing.roofIds.add(roof.id);
          continue;
        }
        result.add(
          ArchitectRoofRidgeBeam(
            a,
            b,
            math.max(.001, timber.ridgePurlinWidth),
            math.max(.001, timber.ridgePurlinHeight),
            top,
            roof.id,
          ),
        );
      }
    }
    final junctions = ArchitectRoofJunctions.of(storey, project: project);
    for (final beam in result) {
      beam._planClip = ArchitectMeshSection.unionPaths([
        for (final roof in storey.roofs.where(
          (r) => beam.roofIds.contains(r.id),
        ))
          junctions.footprint(roof),
      ]);
    }
    return result.where((beam) => !beam.footprint.getBounds().isEmpty).toList();
  }
}

class ArchitectRoofRidgeBearing {
  final ArchitectRoofRidgeBeam beam;
  final ArchitectWall wall;
  final Path footprint;
  final double height;
  const ArchitectRoofRidgeBearing(
    this.beam,
    this.wall,
    this.footprint,
    this.height,
  );
  double get top => beam.bottom;
  double get bottom => top - height;
  List<Triangle3D> mesh() => ArchitectPathSolid.extrude(
    footprint,
    bottom,
    top,
    const Color(0xffb0bec5),
  );
}
