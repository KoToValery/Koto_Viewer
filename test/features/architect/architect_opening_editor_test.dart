import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_editor.dart';
import 'architect_contour_opening_test.dart' as fixture;
import 'architect_editing_test.dart' as editing;
import 'architect_polygon_editor_test.dart' as polygon_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

const secondHole = [Offset(6, 2), Offset(7, 2), Offset(7, 4), Offset(6, 4)];

ArchitectProject project(String id) {
  final initial = fixture.project();
  final floor = initial.activeStorey;
  var p = initial.copyWith(
    storeys: [
      floor.copyWith(
        slabs: id == 'slab' ? [floor.slabs.first] : [],
        roofs: id == 'roof' ? floor.roofs : [],
        cadPrimitives: id == 'hatch' ? [fixture.hatch] : [],
      ),
    ],
    units: ArchitectUnit.meters,
  );
  for (final hole in [fixture.hole, secondHole]) {
    p = CutArchitectContourOpening(
      storeyId: 's',
      elementId: id,
      polygon: hole,
    ).apply(p);
  }
  return p;
}

Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(workspace.screen(tester, from));
  await tester.pump(const Duration(milliseconds: 281));
  await g.moveTo(workspace.screen(tester, to));
  await tester.pump();
  await g.up();
  await tester.pumpAndSettle();
}

Future<void> radial(WidgetTester tester, String action) async {
  final button = find.byKey(ValueKey('architect-radial-$action'));
  for (var page = 0; page < 6 && button.evaluate().isEmpty; page++) {
    await tester.tap(find.byKey(const ValueKey('architect-radial-more')));
    await tester.pumpAndSettle();
  }
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Contour picking prioritizes real edges, supports either winding and displaced handles',
    () {
      for (final reverse in [false, true]) {
        final hole = reverse ? fixture.hole.reversed.toList() : fixture.hole;
        expect(
          ArchitectPolygonEditor.hitContour(
            fixture.outer,
            [hole, secondHole],
            const Offset(4, 3),
            100,
          ),
          1,
        );
        expect(
          ArchitectPolygonEditor.hitContour(
            fixture.outer,
            [hole, secondHole],
            const Offset(6, 3),
            100,
          ),
          2,
        );
        expect(
          ArchitectPolygonEditor.hitContour(
            fixture.outer,
            [hole],
            Offset.zero,
            100,
          ),
          0,
        );
        expect(
          ArchitectPolygonEditor.hitContour(
            fixture.outer,
            [hole],
            const Offset(20, 20),
            100,
          ),
          isNull,
        );
        final handle = ArchitectPolygonEditor.offsetVertexHandle(hole, 0, 100);
        expect(
          ArchitectPolygonEditor.hitContour(fixture.outer, [hole], handle, 100),
          1,
        );
      }
    },
  );

  testWidgets('Direct selection switches between openings and outer contour; new point edits only its opening', (tester) async {
    final model = ArchitectCommandController(project('hatch'));
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await editing.hold(tester, const Offset(1, 1));
    await drag(tester, const Offset(7, 4), const Offset(7.5, 4.5));
    var host = CutArchitectContourOpening.target(model.project.activeStorey, 'hatch')!;
    expect(workspace.overlay(tester).polygonEditHoleIndex, 1);
    expect(host.$1, fixture.outer);
    expect(host.$2.first, fixture.hole);
    expect(host.$2.last, contains(const Offset(7.5, 4.5)));
    model.undo();
    await tester.pumpAndSettle();
    await drag(tester, const Offset(8, 6), const Offset(9, 7));
    host = CutArchitectContourOpening.target(model.project.activeStorey, 'hatch')!;
    expect(workspace.overlay(tester).polygonEditHoleIndex, isNull);
    expect(host.$1, contains(const Offset(9, 7)));
    expect(host.$2, [fixture.hole, secondHole]);
    model.undo();
    await tester.pumpAndSettle();
    await editing.contextHold(tester, const Offset(6.5, 2));
    await radial(tester, 'newPoint');
    await tester.tapAt(workspace.screen(tester, const Offset(6.5, 2)));
    await tester.pumpAndSettle();
    host = CutArchitectContourOpening.target(model.project.activeStorey, 'hatch')!;
    expect(host.$1, fixture.outer);
    expect(host.$2.first, fixture.hole);
    expect(host.$2.last, [secondHole[0], const Offset(6.5, 2), ...secondHole.skip(1)]);
    model.undo();
    await tester.pumpAndSettle();
    expect(CutArchitectContourOpening.target(model.project.activeStorey, 'hatch')!.$2.last, secondHole);
    expect(tester.takeException(), isNull);
  });

  for (final id in ['slab', 'roof', 'hatch']) {
    test(
      'Opening edits and point insertion preserve host and other holes and undo atomically: $id',
      () {
        final model = ArchitectCommandController(project(id));
        addTearDown(model.dispose);
        final before = jsonEncode(model.project.toJson());
        final changed = [const Offset(1.5, 1.5), ...fixture.hole.skip(1)];
        model.execute(
          UpdateArchitectPolygon(
            storeyId: 's',
            elementId: id,
            polygon: changed,
            holeIndex: 0,
          ),
        );
        var host = CutArchitectContourOpening.target(
          model.project.activeStorey,
          id,
        )!;
        expect(host.$1, fixture.outer);
        expect(host.$2, [changed, secondHole]);
        expect(
          CutArchitectContourOpening.target(
            ArchitectProject.fromJson(model.project.toJson()).activeStorey,
            id,
          )!.$2,
          host.$2,
        );
        model.undo();
        expect(jsonEncode(model.project.toJson()), before);
        model.redo();
        model.execute(
          InsertArchitectElementPoint(
            storeyId: 's',
            elementId: id,
            point: const Offset(6.8, 2),
            newElementId: 'unused',
            holeIndex: 1,
            atMidpoint: true,
          ),
        );
        host = CutArchitectContourOpening.target(
          model.project.activeStorey,
          id,
        )!;
        expect(host.$2.first, changed);
        expect(host.$2.last, [
          secondHole[0],
          const Offset(6.5, 2),
          ...secondHole.skip(1),
        ]);
        expect(host.$1, fixture.outer);
        model.undo();
        expect(
          CutArchitectContourOpening.target(
            model.project.activeStorey,
            id,
          )!.$2.last,
          secondHole,
        );
        final unchanged = jsonEncode(model.project.toJson());
        for (final invalid in [
          fixture.outer,
          secondHole,
          const [Offset(0, 2), Offset(4, 2), Offset(4, 4), Offset(0, 4)],
          const [Offset(2, 2), Offset(9, 2), Offset(9, 4), Offset(2, 4)],
        ]) {
          expect(
            () => model.execute(
              UpdateArchitectPolygon(
                storeyId: 's',
                elementId: id,
                polygon: invalid,
                holeIndex: 0,
              ),
            ),
            throwsArgumentError,
          );
          expect(jsonEncode(model.project.toJson()), unchanged);
        }
        expect(
          () => model.execute(
            UpdateArchitectPolygon(
              storeyId: 's',
              elementId: id,
              polygon: fixture.hole,
              holeIndex: 2,
            ),
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'Hole edges are selectable from the void, while an empty hole interior remains empty: $id',
      () {
        final floor = project(id).activeStorey;
        final tool = ArchitectElementTool();
        expect(tool.hitTestElement(floor, const Offset(3.99, 3), 100), id);
        expect(tool.hitTestElement(floor, const Offset(3, 3), 100), isNull);
      },
    );

    testWidgets(
      'Select opening, drag vertex, edit edge numerically and reject crossings: $id',
      (tester) async {
        final model = ArchitectCommandController(project(id));
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await editing.contextHold(tester, const Offset(4, 3));
        expect(workspace.overlay(tester).selectedElementId, id);
        expect(workspace.overlay(tester).polygonEditHoleIndex, 0);
        await radial(tester, 'edit');
        final original = model.project;
        await drag(tester, const Offset(2, 2), const Offset(1.5, 1.5));
        var host = CutArchitectContourOpening.target(
          model.project.activeStorey,
          id,
        )!;
        expect(host.$1, fixture.outer);
        expect(host.$2.first.first, const Offset(1.5, 1.5));
        expect(host.$2.last, secondHole);
        model.undo();
        await tester.pumpAndSettle();
        expect(identical(model.project, original), isTrue);

        await tester.tap(find.byKey(const ValueKey('polygon-edge-move')));
        await tester.pumpAndSettle();
        await drag(tester, const Offset(4, 3), const Offset(5, 3));
        host = CutArchitectContourOpening.target(
          model.project.activeStorey,
          id,
        )!;
        expect(host.$2.first, const [
          Offset(2, 2),
          Offset(5, 2),
          Offset(5, 4),
          Offset(2, 4),
        ]);
        expect(host.$1, fixture.outer);
        final moved = model.project;
        await drag(tester, const Offset(5, 3), const Offset(7, 3));
        expect(identical(model.project, moved), isTrue);
        expect(tester.takeException(), isNull);

        await tester.tapAt(workspace.screen(tester, const Offset(5, 3)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
        await tester.pumpAndSettle();
        await polygon_ui.enter(tester, '.25');
        await tester.tap(find.byKey(const ValueKey('shape-cancel')));
        await tester.pumpAndSettle();
        expect(identical(model.project, moved), isTrue);
        await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
        await tester.pumpAndSettle();
        await polygon_ui.enter(tester, '.25');
        await tester.tap(find.byKey(const ValueKey('shape-save')));
        await tester.pumpAndSettle();
        host = CutArchitectContourOpening.target(
          model.project.activeStorey,
          id,
        )!;
        expect(host.$2.first, id == 'hatch' ? const [
          Offset(1.75, 1.75), Offset(5.25, 1.75),
          Offset(5.25, 4.25), Offset(1.75, 4.25),
        ] : const [
          Offset(2, 2),
          Offset(5.25, 2),
          Offset(5.25, 4),
          Offset(2, 4),
        ]);
        expect(host.$1, fixture.outer);
        expect(host.$2.last, secondHole);
        model.undo();
        await tester.pumpAndSettle();
        expect(identical(model.project, moved), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
