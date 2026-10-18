// === SECTION: TABLE OF CONTENTS ===
// 1. COLUMN SNAP RESULT & HELPERS
// 2. ARCHITECT COLUMN SNAP ENGINE

import 'dart:math' as math;
import 'dart:ui';

import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/architect_column.dart';
import '../models/architect_project.dart';
import 'architect_snap_helper.dart';

// === SECTION: ARCHITECT COLUMN SNAP ENGINE ===

/// Specialized snapping engine for architectural and structural columns.
/// Provides precise flush attachment to door and window jambs (along and across walls),
/// automatic element rotation alignment to host walls, and falls back to general snaps.
class ArchitectColumnSnap {
  ArchitectColumnSnap._();

  /// Resolves the snapped target position, wall-aligned rotation, and magnetic guides
  /// for placing or translating a column.
  static ArchitectSnapResult resolve({
    required Offset raw,
    required ArchitectProject project,
    required double columnWidth,
    required double columnDepth,
    required ColumnShape columnShape,
    double currentRotationDeg = 0.0,
    double tolerance = 0.25,
    bool magnetic = true,
    Set<String> excludedIds = const {},
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    if (!magnetic || tolerance <= 0) {
      return ArchitectSnapResult(
        point: ArchitectSnapHelper.precision(project).inputPoint(raw),
      );
    }

    ArchitectSnapResult? bestOpeningSnap;
    double bestDist = tolerance;

    final floor = project.activeStorey;
    final activeIdx = project.storeys.indexWhere((s) => s.id == floor.id);
    final referenceWalls = floor.walls.isNotEmpty
        ? floor.walls
        : (activeIdx > 0 ? project.storeys[activeIdx - 1].walls : floor.walls);

    for (final wall in referenceWalls) {
      if (excludedIds.contains(wall.id)) continue;
      final wallLen = wall.length;
      if (wallLen < 1e-4) continue;

      for (final opening in [
        for (final d in wall.doors) (d.id, d.offsetRatio, d.width, true),
        for (final w in wall.windows) (w.id, w.offsetRatio, w.width, false),
      ]) {
        if (excludedIds.contains(opening.$1)) continue;

        final ratio = opening.$2;
        final openWidth = opening.$3;
        final isDoor = opening.$4;
        final snapLabel = isDoor ? 'Door jamb' : 'Window jamb';

        final center = wall.centerPointAt(ratio);
        final tangent = wall.tangentAt(ratio);
        final normal = wall.normalAt(ratio);

        final halfOpen = openWidth / 2.0;
        final leftJamb = wall.isCurved
            ? wall.centerPointAt(((ratio * wallLen - halfOpen) / wallLen).clamp(0.0, 1.0))
            : center - tangent * halfOpen;
        final rightJamb = wall.isCurved
            ? wall.centerPointAt(((ratio * wallLen + halfOpen) / wallLen).clamp(0.0, 1.0))
            : center + tangent * halfOpen;

        final wallAngleDeg =
            (math.atan2(tangent.dy, tangent.dx) * 180.0 / math.pi) % 360.0;

        // Try parallel and (for rectangular with different width/depth) perpendicular orientation
        final orientations = <({double rot, double halfAlong, double halfAcross})>[
          (
            rot: wallAngleDeg,
            halfAlong: columnWidth / 2.0,
            halfAcross: columnDepth / 2.0,
          ),
          if (columnShape == ColumnShape.rectangular &&
              (columnWidth - columnDepth).abs() > 1e-4)
            (
              rot: (wallAngleDeg + 90.0) % 360.0,
              halfAlong: columnDepth / 2.0,
              halfAcross: columnWidth / 2.0,
            ),
        ];

        for (final orient in orientations) {
          final acrossOffsets = <double>[
            0.0, // Centered on wall core / centerline
            if (wall.thickness > orient.halfAcross * 2.0 + 0.01) ...[
              wall.thickness / 2.0 - orient.halfAcross, // Flush exterior face
              -(wall.thickness / 2.0 - orient.halfAcross), // Flush interior face
            ],
          ];

          for (final acrossOff in acrossOffsets) {
            final acrossVec = normal * acrossOff;

            // 1. Column flush against left jamb (outside opening)
            final pLeft = leftJamb - tangent * orient.halfAlong + acrossVec;
            final dLeft = (pLeft - raw).distance;
            if (dLeft <= bestDist) {
              bestDist = dLeft;
              final jambGuideStart = leftJamb - normal * (wall.thickness * 1.5);
              final jambGuideEnd = leftJamb + normal * (wall.thickness * 1.5);
              final wallGuideStart = center - tangent * (openWidth + 1.2);
              final wallGuideEnd = center + tangent * (openWidth + 1.2);
              bestOpeningSnap = ArchitectSnapResult(
                point: pLeft,
                isSnapped: true,
                snapLabel: snapLabel,
                angleDeg: orient.rot,
                magneticGuides: [
                  (jambGuideStart, jambGuideEnd),
                  (wallGuideStart, wallGuideEnd),
                ],
              );
            }

            // 2. Column flush against right jamb (outside opening)
            final pRight = rightJamb + tangent * orient.halfAlong + acrossVec;
            final dRight = (pRight - raw).distance;
            if (dRight <= bestDist) {
              bestDist = dRight;
              final jambGuideStart = rightJamb - normal * (wall.thickness * 1.5);
              final jambGuideEnd = rightJamb + normal * (wall.thickness * 1.5);
              final wallGuideStart = center - tangent * (openWidth + 1.2);
              final wallGuideEnd = center + tangent * (openWidth + 1.2);
              bestOpeningSnap = ArchitectSnapResult(
                point: pRight,
                isSnapped: true,
                snapLabel: snapLabel,
                angleDeg: orient.rot,
                magneticGuides: [
                  (jambGuideStart, jambGuideEnd),
                  (wallGuideStart, wallGuideEnd),
                ],
              );
            }
          }
        }
      }
    }

    if (bestOpeningSnap != null) {
      return bestOpeningSnap;
    }

    // Fallback to standard drawing snaps (axes, endpoints, edges, intersections)
    return ArchitectSnapHelper.snapFree(
      rawPoint: raw,
      project: project,
      tolerance: tolerance,
      magnetic: magnetic,
      alignment: true,
      excludedIds: excludedIds,
      underlay: underlay,
      frame: frame,
      visibility: visibility,
    );
  }
}
