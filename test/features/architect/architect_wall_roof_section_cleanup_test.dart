import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_material_layer.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';

import 'architect_package_roof_junction_regression_test.dart' show sectionArea;
import 'architect_section_drainage_performance_test.dart'
    show attachedDrainageProject;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'wall/roof junction keeps full insulation width flush to ring beam without 5mm gap or pocket clutter',
    () {
      const cut = ArchitectSection(
        id: 'sec_aa',
        name: 'Section A-A',
        start: Offset(10.797, 16.135),
        end: Offset(10.797, 3.65),
      );
      final project = attachedDrainageProject();
      final section = ArchitectBuildingSection.build(project, cut);

      // Exterior EPS insulation on the south wall (y=6.6, 12 cm EPS outside 25 cm brick)
      // must keep full 12 cm width flush with the ring beam with no 5 mm vertical notch.
      final wallId = 'wall_element_298564cc_1793200317961540_1';
      final epsRegion = section.regions.firstWhere(
        (r) =>
            r.sourceId == wallId && r.material == SlabMaterial.floorInsulation,
      );
      final brickRegion = section.regions.firstWhere(
        (r) => r.sourceId == wallId && r.material == SlabMaterial.plaster,
      );
      final ringBeamRegion = section.regions.firstWhere(
        (r) =>
            r.roof &&
            r.material == SlabMaterial.concrete &&
            r.path.getBounds().overlaps(
              brickRegion.path.getBounds().inflate(0.2),
            ),
      );
      final wallPlateRegion = section.regions.firstWhere(
        (r) =>
            r.roof &&
            r.timberCrossSectionPolygon != null &&
            r.path.getBounds().width > 0.10 &&
            r.path.getBounds().overlaps(
              ringBeamRegion.path.getBounds().inflate(0.2),
            ),
      );

      final epsBounds = epsRegion.path.getBounds();
      final rbBounds = ringBeamRegion.path.getBounds();
      final wpBounds = wallPlateRegion.path.getBounds();

      // In Section A-A (start y=16.135 -> end y=3.65), south wall core is [9.41, 9.66]
      // and exterior EPS is on the +s side [9.66, 9.78].
      expect(epsBounds.width, closeTo(0.12, 1e-4));
      expect(
        (epsBounds.left - rbBounds.right).abs(),
        lessThan(1e-4),
        reason: 'EPS must meet ring beam flush with no 5 mm gap',
      );
      // Sample mid-height of ring beam and mid-height of wall plate: EPS must remain solid across all 12 cm.
      expect(
        epsRegion.path.contains(Offset(rbBounds.right + 0.002, rbBounds.center.dy)),
        isTrue,
      );
      expect(
        epsRegion.path.contains(Offset(rbBounds.right + 0.002, rbBounds.bottom + 0.01)),
        isTrue,
      );
      // Inspect exact EPS vertical profile at the outer face (epsBounds.right - 0.002)
      final outerS = epsBounds.right - 0.002;
      expect(
        epsRegion.path.contains(Offset(outerS, rbBounds.bottom + 0.005)),
        isTrue,
        reason:
            'epsBounds=$epsBounds rbBounds=$rbBounds wpBounds=$wpBounds',
      );

      // No background projection faces may bleed into the two pockets above the ring beam beside the wall plate.
      // In Y-up world coordinates, rbBounds.bottom is zRbTop and wpBounds.bottom is zWpTop.
      final leftPocket = Rect.fromLTRB(
        rbBounds.left + 0.002,
        rbBounds.bottom + 0.002,
        wpBounds.left - 0.002,
        rbBounds.bottom + 0.05,
      );
      final rightPocket = Rect.fromLTRB(
        wpBounds.right + 0.002,
        rbBounds.bottom + 0.002,
        rbBounds.right - 0.002,
        rbBounds.bottom + 0.05,
      );
      for (final pocket in [leftPocket, rightPocket]) {
        final pocketPath = Path()..addRect(pocket);
        for (final face in section.background!.faces) {
          expect(
            sectionArea(Path.combine(PathOperation.intersect, face, pocketPath)),
            lessThan(1e-6),
            reason: 'Background face bleeds into wall/roof pocket $pocket',
          );
        }
      }
    },
  );

  test(
    'longitudinal section between rafters on a joined hip roof keeps continuous rafter layer without background bleed',
    () {
      // Shift Section A-A slightly off-center (x = 10.60) so it misses discrete 60cm-spaced rafters.
      const betweenRaftersCut = ArchitectSection(
        id: 'sec_between',
        name: 'Section Between',
        start: Offset(10.60, 16.135),
        end: Offset(10.60, 3.65),
      );
      final project = attachedDrainageProject();
      final section = ArchitectBuildingSection.build(project, betweenRaftersCut);

      final roofStorey = project.roofStorey!;
      final slices = ArchitectRoofGeometry.buildSectionSlices(
        storey: roofStorey,
        sectionLine: betweenRaftersCut,
        lowerStorey: ArchitectRoofGeometry.supportingWallStorey(
          project,
          roofStorey,
        ),
        project: project,
      );
      final members = slices.expand((s) => s.members).toList();
      final rafterLayers = members.where(
        (m) =>
            m.kind == ArchitectRoofMemberKind.layer &&
            m.role == ArchitectRoofLayerRole.rafters,
      );
      expect(
        rafterLayers,
        isNotEmpty,
        reason: 'Longitudinal section between rafters must still render the rafter zone',
      );
      for (final rl in rafterLayers) {
        expect(rl.path.getBounds().isEmpty, isFalse);
      }

      // Confirm zero overlap among roof members in the longitudinal slice.
      for (var i = 0; i < members.length; i++) {
        for (var j = i + 1; j < members.length; j++) {
          if (!members[i].path.getBounds().overlaps(members[j].path.getBounds())) {
            continue;
          }
          expect(
            sectionArea(
              Path.combine(
                PathOperation.intersect,
                members[i].path,
                members[j].path,
              ),
            ),
            lessThan(1e-6),
          );
        }
      }

      // Background faces must not bleed into any cut roof region.
      final cutRoof = section.regions
          .where((r) => r.roof && r.occludesProjection)
          .fold(Path(), (p, r) => Path.combine(PathOperation.union, p, r.path));
      for (final face in section.background!.faces) {
        expect(
          sectionArea(Path.combine(PathOperation.intersect, cutRoof, face)),
          lessThan(1e-5),
        );
      }
    },
  );

  test(
    '3D wall solids under roof footprint avoid unnecessary horizontal seam at nominalTop',
    () {
      final base = attachedDrainageProject();
      final ground = base.storeys.first;
      // Use only walls and roof so slab finish layers don't split the wall base;
      // verify no horizontal split occurs at nominalTop (3.00 m).
      final cleanProject = base.copyWith(
        storeys: [
          ground.copyWith(slabs: const []),
          ...base.storeys.skip(1),
        ],
      );
      final solids = ArchitectWallSolids.build(
        cleanProject.storeys.first,
        cleanProject.wallTypes,
        project: cleanProject,
      );
      for (final wall in ground.walls) {
        final wallSolids = solids.where((s) => s.wall.id == wall.id).toList();
        final epsSolids = wallSolids
            .where((s) => s.layer.role == ArchitectLayerRole.insulation)
            .toList();
        final coreSolids = wallSolids
            .where((s) => s.layer.role == ArchitectLayerRole.core)
            .toList();
        for (final s in [...epsSolids, ...coreSolids]) {
          expect(s.bottom, closeTo(0.0, 1e-6));
          expect(s.top, isNot(closeTo(3.0, 1e-4)));
        }
      }
    },
  );
}
