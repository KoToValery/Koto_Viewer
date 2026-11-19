import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_framing.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_junctions.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_ridge_beams.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';

import 'architect_package_roof_junction_regression_test.dart' show sectionArea;
import 'architect_section_drainage_performance_test.dart'
    show attachedDrainageProject;

ArchitectRoofFraming framing(ArchitectStorey floor) =>
    ArchitectRoofFraming.build(
      floor,
      ArchitectRoofJunctions.of(floor),
      ArchitectRoofRidgeBeam.build(floor),
    );

ArchitectProject automaticHipProject(double width) {
  final floor = ArchitectStorey(
    id: 'roof',
    name: 'Roof',
    elevation: 3,
    slabs: [
      ArchitectSlab(
        id: 'slab',
        thickness: .2,
        polygon: [
          Offset.zero,
          Offset(width, 0),
          Offset(width, 6),
          const Offset(0, 6),
        ],
      ),
    ],
  );
  final project = ArchitectProject(
    id: 'auto-roof',
    name: 'Automatic roof',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    activeStoreyId: floor.id,
    storeys: [floor],
  );
  final roofs = ArchitectRoofGeometry.generateAutoRoof(
    project: project,
    type: AutoRoofType.hip,
  );
  return project.copyWith(storeys: [floor.copyWith(roofs: roofs)]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in ArchitectRoofDiagonalKind.values) {
    test(
      'One ${kind.name} timber with paired rafters and clean 3D and section cuts',
      () {
        final valley = kind == ArchitectRoofDiagonalKind.valley;
        final assembly = ArchitectRoofAssembly.fromPreset(
          ArchitectRoofPreset.pitchedTiles,
        );
        final simple = assembly.copyWith(
          timber: assembly.timber.copyWith(
            hasWallPlate: false,
            hasRingBeam: false,
            hasBattens: false,
            hasCounterBattens: false,
            hasFasciaBoard: false,
            hasMetalFlashing: false,
          ),
        );
        final a = ArchitectRoofPlane(
          id: 'a',
          storeyId: 'roof',
          points: [
            const Offset(0, 0),
            const Offset(4, 0),
            const Offset(4, 4),
            if (valley) const Offset(0, 4),
          ],
          roofGroupId: 'joined',
          reverseSlope: valley,
          assembly: simple,
        );
        final b = a.copyWith(
          id: 'b',
          points: [
            const Offset(0, 4),
            const Offset(0, 0),
            if (valley) const Offset(4, 0),
            const Offset(4, 4),
          ],
        );
        final floor = ArchitectStorey(
          id: 'roof',
          name: 'Roof',
          elevation: 3,
          roofs: [b, a],
        );
        final layout = framing(floor);
        if (valley) {
          expect(ArchitectRoofJunctions.of(floor).trimmed, {a.id, b.id});
        }
        final beam = layout.diagonals.single;
        expect(beam.kind, kind);
        expect(beam.roofIds, [a.id, b.id]);
        expect((beam.start - beam.end).distance, closeTo(math.sqrt(32), 1e-5));
        expect(
          beam.topAt(beam.start),
          isNot(closeTo(beam.topAt(beam.end), .001)),
        );

        List<double> stations(
          ArchitectRoofPlane roof,
          double Function(Vector3) coordinate,
        ) => [
          for (final mesh in layout.rafters(roof, seats: []))
            if (mesh.isNotEmpty)
              (() {
                final values = mesh
                    .expand((t) => [t.v0, t.v1, t.v2])
                    .map(coordinate);
                return (values.reduce(math.min) + values.reduce(math.max)) / 2;
              })(),
        ]..sort();
        final aStations = stations(a, (p) => p.x);
        final bStations = stations(b, (p) => p.y);
        expect(aStations, hasLength(7));
        expect(
          bStations,
          orderedEquals(aStations.map((x) => closeTo(x, 1e-6))),
        );
        for (var i = 1; i < aStations.length; i++) {
          expect(aStations[i] - aStations[i - 1], closeTo(4 / 7, 1e-6));
        }

        final project = ArchitectProject(
          id: 'joined-roof',
          name: 'Joined roof',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: floor.id,
          storeys: [floor],
        );
        const cut = ArchitectSection(
          id: 'cut',
          start: Offset(1, 3),
          end: Offset(3, 1),
        );
        final groups = <Triangle3D, String>{};
        final model = Architect3dBuilder.buildProjectMesh(
          project,
          silhouetteGroups: groups,
        );
        final diagonalMesh = model.triangles
            .where(
              (t) =>
                  groups[t]?.startsWith('construction:roof-diagonal:') == true,
            )
            .toList();
        expect(diagonalMesh, isNotEmpty);
        final beamSection = ArchitectMeshSection.verticalClipped(
          diagonalMesh,
          cut.start,
          cut.axis,
          cut.length,
        );
        expect(sectionArea(beamSection), greaterThan(.01));
        final members = ArchitectRoofGeometry.buildSectionSlices(
          storey: floor,
          sectionLine: cut,
          project: project,
        ).expand((slice) => slice.members).toList();
        final diagonal = members.singleWhere(
          (m) => m.kind == ArchitectRoofMemberKind.diagonalRafter,
        );
        expect(
          sectionArea(
            Path.combine(PathOperation.xor, beamSection, diagonal.path),
          ),
          lessThan(1e-6),
        );
        final rafters = members.where(
          (m) => m.kind == ArchitectRoofMemberKind.rafter,
        );
        expect(rafters.map((m) => m.roofId).toSet(), {a.id, b.id});
        for (final rafter in rafters) {
          expect(
            sectionArea(
              Path.combine(PathOperation.intersect, diagonal.path, rafter.path),
            ),
            lessThan(1e-7),
          );
        }
      },
    );
  }

  test('An automatically generated hipped roof has four diagonal timbers', () {
    final floor = automaticHipProject(12).activeStorey;
    final layout = framing(floor);
    expect(layout.diagonals, hasLength(4));
    expect(
      layout.diagonals.map((beam) => beam.kind),
      everyElement(ArchitectRoofDiagonalKind.hip),
    );
    for (final (i, beam) in layout.diagonals.indexed) {
      for (final other in layout.diagonals.skip(i + 1)) {
        expect(
          sectionArea(
            Path.combine(
              PathOperation.intersect,
              beam.footprint,
              other.footprint,
            ),
          ),
          lessThan(1e-6),
          reason: '${beam.start}–${beam.end} and ${other.start}–${other.end}',
        );
      }
    }
    expect(
      framing(
        floor.copyWith(roofs: floor.roofs.reversed.toList()),
      ).diagonals.map((b) => (b.kind, b.start, b.end)),
      layout.diagonals.map((b) => (b.kind, b.start, b.end)),
    );
  });

  test('Short hip ridge section keeps projection out of thin cut layers', () {
    final project = automaticHipProject(7);
    final floor = project.activeStorey;
    final ridge = ArchitectRoofRidgeBeam.build(floor).single;
    expect((ridge.end - ridge.start).distance, closeTo(1, 1e-7));

    for (final cut in const [
      ArchitectSection(
        id: 'centre',
        start: Offset(3.5, -1),
        end: Offset(3.5, 7),
      ),
      ArchitectSection(
        id: 'ridge-end',
        start: Offset(3, -1),
        end: Offset(3, 7),
      ),
      ArchitectSection(id: 'oblique', start: Offset(-1, -1), end: Offset(7, 7)),
    ]) {
      final data = ArchitectBuildingSection.build(project, cut);
      final cutRoof = data.regions
          .where((region) => region.roof && region.occludesProjection)
          .fold(
            Path(),
            (path, region) =>
                Path.combine(PathOperation.union, path, region.path),
          );
      final background = data.background!.faces;
      expect(background, isNotEmpty);
      for (final face in background) {
        expect(
          sectionArea(Path.combine(PathOperation.intersect, cutRoof, face)),
          lessThan(1e-5),
          reason: 'Projection crosses cut material in ${cut.id}',
        );
      }
    }
  });

  test('Cut at a short ridge end gives the purlin its full seat', () {
    final project = automaticHipProject(7);
    final members = ArchitectRoofGeometry.buildSectionSlices(
      storey: project.activeStorey,
      sectionLine: const ArchitectSection(
        id: 'ridge-end',
        start: Offset(3, -1),
        end: Offset(3, 7),
      ),
      project: project,
    ).expand((slice) => slice.members).toList();
    final ridge = members.singleWhere(
      (member) => member.kind == ArchitectRoofMemberKind.ridgePurlin,
    );
    final hips = members.where(
      (member) => member.kind == ArchitectRoofMemberKind.diagonalRafter,
    );
    expect(hips, hasLength(2));
    for (final hip in hips) {
      expect(
        sectionArea(
          Path.combine(PathOperation.intersect, hip.path, ridge.path),
        ),
        lessThan(1e-7),
      );
    }
  });

  test('Reference roof sections cut the hips without double material', () {
    final project = attachedDrainageProject();
    final floor = project.roofStorey!;
    for (final cut in project.sections) {
      final members = ArchitectRoofGeometry.buildSectionSlices(
        storey: floor,
        sectionLine: cut,
        project: project,
        lowerStorey: ArchitectRoofGeometry.supportingWallStorey(project, floor),
      ).expand((slice) => slice.members).toList();
      final diagonals = members.where(
        (member) => member.kind == ArchitectRoofMemberKind.diagonalRafter,
      );
      if (cut == project.sections[1]) expect(diagonals, hasLength(2));
      for (final diagonal in diagonals) {
        for (final member in members) {
          if (identical(diagonal, member) ||
              !diagonal.path.getBounds().overlaps(member.path.getBounds())) {
            continue;
          }
          expect(
            sectionArea(
              Path.combine(PathOperation.intersect, diagonal.path, member.path),
            ),
            lessThan(1e-6),
            reason: '${cut.name}: diagonal / ${member.kind} (${member.role})',
          );
        }
      }
    }
  });
}
