import 'dart:math' as math;
import 'dart:ui';

import '../models/architect_project.dart';
import '../rendering/architect_mesh_section.dart';
import '../rendering/architect_path_solid.dart';
import 'architect_roof_geometry.dart';
import 'architect_roof_junctions.dart';
import 'architect_roof_ridge_beams.dart';

/// Horizontal timber bearings shared by log-wall trimming, sections and 3D.
/// The actual wall core locates the plate; overhang is only a fallback when
/// there are no walls, or the user has supplied a manual bearing line.
class ArchitectRoofWallPlate extends ArchitectRoofRidgeBeam {
  final Path outline;
  ArchitectRoofWallPlate(
    super.start,
    super.end,
    super.width,
    super.height,
    super.top,
    super.roofId,
    this.outline,
  );

  @override
  Path get footprint => outline;

  static double rafterBottomDepth(ArchitectRoofPlane roof) {
    var depth = 0.0;
    double? bottom;
    for (final layer in roof.assembly.layers) {
      depth += roof.assembly.layerDepth(layer);
      if (layer.role == ArchitectRoofLayerRole.rafters ||
          layer.isBetweenRafters) {
        bottom = depth;
      }
    }
    return bottom ?? roof.assembly.totalThickness;
  }

  static List<ArchitectRoofWallPlate> build(
    ArchitectStorey storey, {
    ArchitectProject? project,
    ArchitectStorey? lowerStorey,
  }) {
    final support = storey.walls.isNotEmpty
        ? storey
        : lowerStorey ??
              (project == null
                  ? null
                  : ArchitectRoofGeometry.supportingWallStorey(
                      project,
                      storey,
                    ));
    final result = <ArchitectRoofWallPlate>[];
    final junctions = ArchitectRoofJunctions.of(storey, project: project);
    for (final roof in storey.roofs) {
      final timber = roof.assembly.timber;
      if (roof.assembly.preset != ArchitectRoofPreset.logTimber ||
          !timber.hasWallPlate) {
        continue;
      }
      final lines = <(Offset, Offset, double)>[];
      if (roof.manualSupportDistance != null ||
          support == null ||
          support.walls.isEmpty) {
        final line = ArchitectRoofGeometry.wallBearingLine(roof);
        if (line != null) lines.add((line.$1, line.$2, timber.wallPlateWidth));
      } else {
        for (final wall in support.walls) {
          if (wall.isParapet ||
              wall.isCurved ||
              (wall.unitVector.dx * roof.slopeDirection.dx +
                          wall.unitVector.dy * roof.slopeDirection.dy)
                      .abs() >
                  .25) {
            continue;
          }
          final mid = (wall.coreCenterStart + wall.coreCenterEnd) / 2;
          // A ridge purlin owns the high bearing; do not stack an eaves plate.
          if ((roof.signedDistanceFromEaves(mid) - roof.maxSlopeRun).abs() <
              .02) {
            continue;
          }
          lines.add((
            wall.coreCenterStart,
            wall.coreCenterEnd,
            math.min(wall.coreThickness, timber.wallPlateWidth),
          ));
        }
      }
      for (final (a, b, width) in lines) {
        if ((b - a).distance < 1e-6 || width <= 0) continue;
        final axis = (b - a) / (b - a).distance;
        final n = Offset(-axis.dy, axis.dx) * (width / 2);
        final outline = ArchitectMeshSection.combine(
          PathOperation.intersect,
          Path()..addPolygon([a + n, b + n, b - n, a - n], true),
          junctions.footprint(roof),
        );
        final points = ArchitectPathSolid.contours(
          outline,
        ).expand((c) => c).toList();
        if (points.isEmpty) continue;
        final depth = rafterBottomDepth(roof);
        final top = points
            .map((p) {
              final slope =
                  roof.isMansard &&
                      roof.signedDistanceFromEaves(p) >
                          roof.effectiveBreakDistance
                  ? roof.upperSlopeRadians
                  : roof.slopeRadians;
              return storey.elevation +
                  roof.topElevationAt(p) -
                  depth / math.cos(slope).clamp(.15, 1.0);
            })
            .reduce(math.max);
        result.add(
          ArchitectRoofWallPlate(
            a,
            b,
            width,
            timber.wallPlateHeight,
            top,
            roof.id,
            outline,
          ),
        );
      }
    }
    return result;
  }
}
