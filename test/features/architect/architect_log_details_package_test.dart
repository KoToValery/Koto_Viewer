import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_snap.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_wall_plates.dart';
import 'package:kotoview/src/features/architect/services/architect_slab_geometry.dart';

ArchitectProject logDetailsProject() => ArchitectProject.fromJson(
  jsonDecode(
    File(
      'test/fixtures/bim_package_log_details_2026_10_29.json',
    ).readAsStringSync(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ArchitectProject project;
  late ArchitectBuildingSection section;
  setUpAll(() {
    final controller = ArchitectCommandController(logDetailsProject());
    project = controller.project;
    controller.dispose();
    section = ArchitectBuildingSection.build(
      project,
      project.sections.single,
      includeProjection: false,
    );
  });

  test(
    'each seated log retains one closed continuous unhatched course outline',
    () {
      final logIds = project.storeys.first.walls.map((w) => w.id).toSet();
      final logs = section.regions
          .where(
            (r) =>
                logIds.contains(r.sourceId) &&
                !r.slab &&
                r.material == SlabMaterial.parquet,
          )
          .toList();
      expect(logs.length, greaterThanOrEqualTo(26));
      for (final log in logs) {
        expect(log.drawHatch, isFalse);
        expect(section.drawingRegions, contains(same(log)));
        final contours = log.path.computeMetrics().toList();
        expect(contours, hasLength(1));
        expect(contours.single.isClosed, isTrue);
      }
      final view = section.forView(project.sections.single);
      expect(
        view.drawingRegions.where((r) => !r.drawHatch).length,
        logs.length,
      );
    },
  );

  test(
    'slab and sub-base cover the whole interior despite reversed wall exterior flags',
    () {
      final floor = project.storeys.first, slab = floor.slabs.single;
      final span = ArchitectSlabGeometry.intervals(
        floor,
        slab,
        project.sections.single,
      ).single;
      for (final (material, z) in [
        (SlabMaterial.concrete, -.08),
        (SlabMaterial.ballast, -.28),
        (SlabMaterial.compactedFill, -.48),
      ]) {
        final paths = section.regions
            .where((r) => r.sourceId == slab.id && r.material == material)
            .map((r) => r.path);
        for (var x = span.$1 + .3; x < span.$2 - .3; x += .05) {
          expect(
            paths.any((p) => p.contains(Offset(x, z))),
            isTrue,
            reason: '$material missing at $x, $z',
          );
        }
      }
    },
  );

  test(
    'log wall plate is the same horizontal seated solid in mesh and section',
    () {
      final floor = project.storeys.last, cut = project.sections.single;
      final plates = ArchitectRoofWallPlate.build(floor, project: project);
      expect(plates, hasLength(2));
      final slices = ArchitectRoofGeometry.buildSectionSlices(
        storey: floor,
        sectionLine: cut,
        project: project,
        lowerStorey: project.storeys.first,
      );
      final logs = ArchitectWallSolids.build(
        project.storeys.first,
        project.wallTypes,
        project: project,
      );
      for (final plate in plates) {
        final profile = ArchitectMeshSection.vertical(
          plate.mesh(),
          cut.start,
          cut.axis,
        );
        final member = slices
            .expand((s) => s.members)
            .singleWhere(
              (m) =>
                  m.roofId == plate.roofId &&
                  m.kind == ArchitectRoofMemberKind.wallPlate,
            );
        expect(
          member.path.getBounds().left,
          closeTo(profile.getBounds().left, 1e-5),
        );
        expect(
          member.path.getBounds().right,
          closeTo(profile.getBounds().right, 1e-5),
        );
        expect(member.path.getBounds().top, closeTo(plate.bottom, 1e-5));
        expect(member.path.getBounds().bottom, closeTo(plate.top, 1e-5));
        final b = profile.getBounds();
        for (final log in logs) {
          final logProfile = ArchitectMeshSection.vertical(
            log.triangles,
            cut.start,
            cut.axis,
          );
          if (!logProfile.getBounds().overlaps(b)) continue;
          final overlap = ArchitectMeshSection.combine(
            PathOperation.intersect,
            profile,
            logProfile,
          ).getBounds();
          expect(
            overlap.isEmpty || overlap.width * overlap.height < 1e-8,
            isTrue,
          );
        }
      }
    },
  );

  test(
    'fine manual roof height survives unrelated edits, undo, redo and reopening',
    () {
      final controller = ArchitectCommandController(logDetailsProject());
      addTearDown(controller.dispose);
      final roof = controller.project.storeys.last.roofs.first;
      expect(roof.attachToWalls, isFalse);
      controller.commit(
        ArchitectProjectionEditing.move(
          controller.project,
          roof.id,
          const Offset(0, .002),
          project.sections.single.axis,
          elevation: false,
        ),
      );
      final height = roof.baseElevationOffset + .002;
      controller.commit(controller.project.copyWith(name: 'edited'));
      controller.undo();
      controller.undo();
      controller.redo();
      controller.redo();
      final reopened = ArchitectCommandController(
        ArchitectProject.fromJson(controller.project.toJson()),
      );
      addTearDown(reopened.dispose);
      expect(
        reopened.project.storeys.last.roofs.first.baseElevationOffset,
        closeTo(height, 1e-9),
      );
      expect(reopened.project.storeys.last.roofs.first.attachToWalls, isFalse);
      reopened.execute(
        UpdateArchitectRoofPlane(
          storeyId: reopened.project.storeys.last.id,
          roof: reopened.project.storeys.last.roofs.first.copyWith(
            attachToWalls: true,
          ),
        ),
      );
      expect(reopened.project.storeys.last.roofs.first.attachToWalls, isFalse);
      expect(
        reopened.project.storeys.last.roofs.first.placementResolved,
        isTrue,
      );
      final plate = ArchitectRoofWallPlate.build(
        reopened.project.storeys.last,
        project: reopened.project,
      ).firstWhere((p) => p.roofId == roof.id);
      expect(plate.bottom, closeTo(3, 1e-5));
    },
  );

  test(
    'roof seat partitions leave no internal faces that project across batten gaps',
    () {
      final sources = <Triangle3D, String>{};
      final mesh = Architect3dBuilder.buildProjectMesh(
        project,
        previewGeometry: false,
        sources: sources,
      );
      for (final roof in project.storeys.last.roofs) {
        final footprint = Path()..addPolygon(roof.points, true);
        for (final t in mesh.triangles.where((t) => sources[t] == roof.id)) {
          final c = (t.v0 + t.v1 + t.v2) / 3;
          final p = Offset(c.x, c.y);
          final strictlyInside = [
            const Offset(.0001, 0),
            const Offset(-.0001, 0),
            const Offset(0, .0001),
            const Offset(0, -.0001),
          ].every((d) => footprint.contains(p + d));
          if (!strictlyInside) continue;
          final bottom =
              project.storeys.last.elevation + roof.undersideElevationAt(p);
          final top = project.storeys.last.elevation + roof.topElevationAt(p);
          expect(
            c.z > bottom + .0001 && c.z < top - .0001,
            isFalse,
            reason: 'Internal roof face at $c',
          );
        }
      }
    },
  );

  test(
    'longitudinal plate section retains its actual length without cross-grain diagonals',
    () {
      const cut = ArchitectSection(
        id: 'longitudinal',
        start: Offset(6.5, 6.6),
        end: Offset(15, 6.6),
      );
      final members =
          ArchitectRoofGeometry.buildSectionSlices(
                storey: project.storeys.last,
                sectionLine: cut,
                project: project,
                lowerStorey: project.storeys.first,
              )
              .expand((s) => s.members)
              .where((m) => m.kind == ArchitectRoofMemberKind.wallPlate)
              .toList();
      expect(members, hasLength(1));
      expect(members.single.path.getBounds().width, closeTo(7.2, 1e-5));
      expect(members.single.drawTimberDiagonals, isFalse);
    },
  );

  test(
    'roof-following wall silhouette and decorative roof members cannot claim a false snap',
    () {
      final roof = project.storeys.last.roofs.first,
          wall = project.storeys.first.walls.first;
      final paths = {
        roof.id: Path()..addRect(const Rect.fromLTRB(0, 3, 4, 4)),
        wall.id: Path()..addRect(const Rect.fromLTRB(1, 0, 3, 3.998)),
      };
      final snap = ArchitectProjectionSnap(
        project,
        paths,
        roof.id,
        roofProfiles: {
          roof.id: Path()
            ..addPolygon(const [
              Offset(0, 3),
              Offset(4, 4),
              Offset(4, 4.2),
              Offset(0, 3.2),
            ], true),
        },
      );
      final result = snap.resolve(
        const Offset(0, -.002),
        .005,
        horizontal: false,
      );
      expect(result.contact, isNull);
      expect(result.delta.dy, -.002);
    },
  );
}
