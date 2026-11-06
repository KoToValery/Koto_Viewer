import 'dart:math' as math;
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_section_junctions.dart';
import 'architect_slab_geometry.dart';

/// The first riser's finish meets the approach floor, while the concrete waist
/// retains its structural seat. Values are relative to the owning storey.
class ArchitectStairFloorContact {
  static double firstRiserBottom(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectStair stair,
  ) {
    final start = stair.design?.startOffset ?? 0;
    if (stair.design == null || stair.plan.nosings.isEmpty) return start;
    final (a, b) = stair.plan.nosings.first;
    final approach =
        (a + b) / 2 -
        stair.unitVector * math.max(.005, stair.design!.nosingProjection);
    var bottom = start;
    for (final slab in storey.slabs) {
      if (!ArchitectSlabGeometry.contains(storey, slab, approach, project: project)) {
        continue;
      }
      final surfaces = ArchitectSlabGeometry.surfaces(
        project,
        storey,
        slab,
        assemblyOverride:
            ArchitectSectionJunctions.resolveEffectiveSlabAssembly(
              project,
              storey,
              slab,
            ),
      );
      if (surfaces.isNotEmpty) {
        bottom = math.max(
          bottom,
          surfaces.first.topAt(approach) - storey.elevation,
        );
      }
    }
    return bottom;
  }
}
