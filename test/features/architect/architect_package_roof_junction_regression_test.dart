import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_path_solid.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_ridge_beams.dart';
import 'architect_section_drainage_performance_test.dart' as fixture;

double sectionArea(Path path) {
  var area = 0.0;
  for (final loop in ArchitectPathSolid.contours(path, tolerance: .00001)) {
    for (var i = 0; i < loop.length; i++) {
      final a = loop[i], b = loop[(i + 1) % loop.length];
      area += (a.dx * b.dy - a.dy * b.dx) / 2;
    }
  }
  return area.abs();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    '3D rafter seats meet the physical ridge without overlapping timber',
    () {
      final original = fixture.attachedDrainageProject();
      final roof = ArchitectRoofPlane(
        id: 'single',
        storeyId: 'roof',
        points: const [Offset(0, 0), Offset(6, 0), Offset(6, 4), Offset(0, 4)],
        slopeDegrees: 22,
        baseElevationOffset: 0,
      );
      final floor = ArchitectStorey(
        id: 'roof',
        name: '',
        elevation: 3,
        roofs: [roof],
      );
      final project = original.copyWith(
        storeys: [floor],
        activeStoreyId: floor.id,
      );
      final mesh = Architect3dBuilder.buildProjectMesh(project);
      final rafters = mesh.triangles
          .where(
            (t) =>
                t.color?.toARGB32() == 0xffd7a86e ||
                t.color?.toARGB32() == 0xffc49256,
          )
          .toList();
      final beam = ArchitectRoofRidgeBeam.build(floor, project: project).single;
      final timber = ArchitectMeshSection.vertical(
        rafters,
        const Offset(.04, -1),
        const Offset(0, 1),
      );
      final purlin = ArchitectMeshSection.vertical(
        beam.mesh(),
        const Offset(.04, -1),
        const Offset(0, 1),
      );
      expect(sectionArea(timber), greaterThan(.1));
      expect(sectionArea(purlin), greaterThan(.001));
      expect(
        sectionArea(Path.combine(PathOperation.intersect, timber, purlin)),
        lessThan(1e-7),
      );
    },
  );
  test(
    'actual A-A B-B C-C have one physical ridge and no overlapping roof materials',
    () {
      final project = fixture.attachedDrainageProject();
      final floor = project.roofStorey!;
      final ridge = ArchitectRoofRidgeBeam.build(floor).single;
      expect((ridge.end - ridge.start).distance, closeTo(.6, 1e-5));
      expect(ridge.width, closeTo(.16, 1e-6));
      expect(ridge.height, closeTo(.20, 1e-6));
      for (var i = 0; i < project.sections.length; i++) {
        final cut = project.sections[i];
        final slices = ArchitectRoofGeometry.buildSectionSlices(
          storey: floor,
          sectionLine: cut,
          project: project,
          lowerStorey: ArchitectRoofGeometry.supportingWallStorey(
            project,
            floor,
          ),
        );
        final members = slices
            .expand((s) => s.members)
            .where((m) => !m.path.getBounds().isEmpty)
            .toList();
        final purlins = members
            .where((m) => m.kind == ArchitectRoofMemberKind.ridgePurlin)
            .toList();
        expect(
          purlins,
          hasLength(i == 1 ? 0 : 1),
          reason: 'B-B crosses hips, not a ridge',
        );
        if (i == 2) {
          expect(purlins.single.path.getBounds().width, closeTo(.6, 1e-5));
          expect(
            purlins.single.drawTimberDiagonals,
            isFalse,
            reason: 'A longitudinal beam is not a transverse timber section',
          );
        }
        for (var a = 0; a < members.length; a++) {
          for (var b = a + 1; b < members.length; b++) {
            if (!members[a].path.getBounds().overlaps(
              members[b].path.getBounds(),
            )) {
              continue;
            }
            final area = sectionArea(
              Path.combine(
                PathOperation.intersect,
                members[a].path,
                members[b].path,
              ),
            );
            expect(
              area,
              lessThan(1e-6),
              reason:
                  '${cut.name}: ${members[a].kind} (${members[a].roofId}) / ${members[b].kind} (${members[b].roofId})',
            );
          }
        }
      }
    },
  );

  test(
    'shared-ridge boundary ownership does not depend on roof creation order',
    () {
      final project = fixture.attachedDrainageProject();
      List<double> layers(ArchitectStorey floor) =>
          ArchitectRoofGeometry.buildSectionSlices(
                storey: floor,
                sectionLine: project.sections.last,
                lowerStorey: project.storeys.first,
              )
              .expand((s) => s.members)
              .where((m) => m.kind == ArchitectRoofMemberKind.layer)
              .map((m) => sectionArea(m.path))
              .toList()
            ..sort();
      final floor = project.roofStorey!;
      final forward = layers(floor),
          reverse = layers(
            floor.copyWith(roofs: floor.roofs.reversed.toList()),
          );
      expect(reverse.length, forward.length);
      for (var i = 0; i < forward.length; i++) {
        expect(reverse[i], closeTo(forward[i], 1e-6));
      }
    },
  );
}
