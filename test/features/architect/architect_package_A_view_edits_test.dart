import 'architect_projection_test_helper.dart' as projection;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectProject _project() => ArchitectProject.fromJson(
  jsonDecode(
    File('test/fixtures/bim_package_A_view_edits.json').readAsStringSync(),
  ),
);

void _finiteMesh(ArchitectProject project) {
  // Check source geometry directly, before any painter validation or culling.
  final mesh = Architect3dBuilder.buildProjectMesh(project);
  expect(mesh.triangles, isNotEmpty);
  expect(mesh.bounds.maxDimension.isFinite, isTrue);
  for (final t in mesh.triangles) {
    for (final v in [t.v0, t.v1, t.v2]) {
      expect(
        v.x.isFinite && v.y.isFinite && v.z.isFinite,
        isTrue,
        reason: '$v',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'A package: main workspace paints the section after roof and depth edits',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final source = ArchitectCommandController(_project());
      addTearDown(source.dispose);
      await workspace.open(tester, source);
      await tester.tap(find.byKey(const ValueKey('architect-view-section')));
      await projection.settleProjection(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is CheckedPopupMenuItem<String> &&
              w.value == source.project.sections.single.id,
        ),
      );
      await projection.settleProjection(tester);
      expect(tester.takeException(), isNull);
      final roof = source.project.storeys.expand((s) => s.roofs).first;
      source.commit(
        ArchitectProjectionEditing.move(
          source.project,
          roof.id,
          const Offset(0, -.25),
          source.project.sections.single.axis,
          elevation: false,
        ),
      );
      await projection.settleProjection(tester);
      expect(tester.takeException(), isNull);
      final project = source.project;
      source.commit(
        project.copyWith(
          sections: [project.sections.single.copyWith(viewDepth: 2)],
        ),
      );
      await projection.settleProjection(tester);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'A package: original model and every roof edit have finite source geometry',
    () {
      final project = _project();
      _finiteMesh(project);
      final cut = project.sections.single;
      for (final roof in project.storeys.expand((s) => s.roofs)) {
        final sectionEdit = ArchitectProjectionEditing.move(
          project,
          roof.id,
          const Offset(0, -.25),
          cut.axis,
          elevation: false,
        );
        _finiteMesh(sectionEdit);
        final facadeEdit = ArchitectProjectionEditing.move(
          project,
          roof.id,
          const Offset(.2, .25),
          const Offset(1, 0),
          elevation: true,
        );
        _finiteMesh(facadeEdit);
      }
    },
  );

  test(
    'A package: existing, relocated and new stepped sections build at finite depths',
    () {
      final project = _project();
      final original = project.sections.single;
      for (final cut in [
        original,
        original.copyWith(
          start: original.start + const Offset(.2, 0),
          end: original.end + const Offset(.2, 0),
        ),
        ArchitectSection(
          id: 'new-cut',
          start: original.start,
          end: original.end,
          steps: [
            Offset(original.length * .4, .3),
            Offset(original.length * .7, 0),
          ],
        ),
      ]) {
        for (final depth in [null, .01, 2.0, 10.0]) {
          stdout.writeln(
            'Checking section ${cut.id}, steps=${cut.steps.length}, depth=$depth',
          );
          final view = cut.copyWith(
            viewDepth: depth,
            clearViewDepth: depth == null,
          );
          final section = ArchitectBuildingSection.build(project, view);
          expect(section.bounds.isFinite, isTrue);
          for (final path in section.elementPaths.values) {
            expect(path.getBounds().isFinite, isTrue);
          }
          for (final region in section.drawingRegions) {
            expect(region.path.getBounds().isFinite, isTrue);
          }
          for (final r in section.regions) {
            expect(r.path.getBounds().isFinite, isTrue);
          }
          for (final p in section.background?.faces ?? <Path>[]) {
            expect(p.getBounds().isFinite, isTrue);
          }
        }
      }
    },
  );

  test(
    'A package: new elevation and roof edit retain valid depth-clipped projections',
    () {
      final project = _project();
      final mesh = Architect3dBuilder.buildProjectMesh(project);
      final b = mesh.bounds;
      final view = ArchitectElevation(
        id: 'new-elevation',
        start: Offset(b.min.x - 1, b.min.y - 1),
        end: Offset(b.max.x + 1, b.min.y - 1),
      );
      final roof = project.storeys.expand((s) => s.roofs).first;
      final edited = ArchitectProjectionEditing.move(
        project,
        roof.id,
        const Offset(.2, -.25),
        view.right,
        elevation: true,
      );
      // Reuse one source mesh for depth changes: the depth belongs to the view,
      // and must never alter or corrupt the model's solids.
      final triangles = Architect3dBuilder.buildProjectMesh(
        edited,
        previewGeometry: false,
      ).triangles;
      for (final depth in [null, .01, 2.0, 10.0]) {
        for (final steps in [
          const <Offset>[],
          [Offset(view.length * .5, .3)],
        ]) {
          final geometry = ArchitectBuildingElevation.fromTriangles(
            triangles,
            view.copyWith(
              viewDepth: depth,
              clearViewDepth: depth == null,
              steps: steps,
            ),
          );
          expect(geometry.bounds.isFinite, isTrue);
          for (final p in geometry.faces) {
            expect(p.getBounds().isFinite, isTrue);
          }
        }
      }
      _finiteMesh(edited);
    },
  );
}
