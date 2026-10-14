import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  test('Overlapping objects select only through their own tool', () {
    final tool = ArchitectElementTool();
    addTearDown(tool.dispose);
    final wall = editing
        .wall('w', const Offset(-2, 0), const Offset(2, 0))
        .copyWith(
          doors: const [
            ArchitectDoor(id: 'd', wallId: 'w', uuid: 'u', offsetRatio: .5),
          ],
        );
    final storey = ArchitectStorey(
      id: 's',
      name: 's',
      walls: [wall],
      columns: const [ArchitectColumn(id: 'c', position: Offset.zero)],
      cadPrimitives: const [
        ArchitectCadPrimitive(
          id: 'line',
          type: CadPrimitiveType.line,
          startPoint: Offset(-2, 0),
          endPoint: Offset(2, 0),
        ),
        ArchitectCadPrimitive(
          id: 'rect',
          type: CadPrimitiveType.rect,
          startPoint: Offset(-1, -1),
          endPoint: Offset(1, 1),
        ),
      ],
    );
    for (final expected in {
      ArchitectTool.wall: 'w',
      ArchitectTool.door: 'd',
      ArchitectTool.column: 'c',
      ArchitectTool.cadLine: 'line',
      ArchitectTool.cadRect: 'rect',
      ArchitectTool.window: null,
      ArchitectTool.select: null,
      ArchitectTool.beam: null,
    }.entries) {
      expect(
        tool.hitTestForTool(storey, Offset.zero, 100, expected.key),
        expected.value,
      );
    }
  });

  for (final reverse in [false, true]) {
    test(
      '50m clearance extends supports, preserves their doors and Undoes ($reverse)',
      () {
        final moving = editing.wall(
          'moving',
          const Offset(0, 16.25),
          const Offset(4, 16.25),
        );
        final neighbor = editing.wall('base', Offset.zero, const Offset(4, 0));
        final supports = [
          for (final x in [0.0, 4.0])
            editing
                .wall(
                  'side$x',
                  Offset(x, reverse ? 16.25 : 0),
                  Offset(x, reverse ? 0 : 16.25),
                )
                .copyWith(
                  doors: [
                    ArchitectDoor(
                      id: 'door$x',
                      wallId: 'side$x',
                      uuid: 'u$x',
                      offsetRatio: .5,
                      width: 1,
                    ),
                  ],
                ),
        ];
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: 's',
            walls: [moving, neighbor, ...supports],
          ),
        );
        addTearDown(model.dispose);
        final old = model.project;
        model.execute(
          const SetArchitectWallClearance(
            storeyId: 's',
            wallId: 'moving',
            neighborId: 'base',
            distance: 50,
          ),
        );
        final next = model.project.activeStorey.walls;
        expect(
          ArchitectWallClearance.nearest(next.first, next).single.distance,
          closeTo(50, 1e-8),
        );
        expect(next[1].toJson(), neighbor.toJson());
        for (var i = 0; i < supports.length; i++) {
          final before = supports[i];
          final after = next[i + 2];
          expect(after.length, closeTo(50.25, 1e-8));
          final oldDoor =
              before.startPoint + before.unitVector * (before.length * .5);
          final newDoor =
              after.startPoint +
              after.unitVector *
                  (after.length * after.doors.single.offsetRatio);
          expect((oldDoor - newDoor).distance, lessThan(1e-8));
        }
        model.undo();
        expect(identical(model.project, old), isTrue);
        model.redo();
        expect(
          model.project.activeStorey.walls[2].length,
          closeTo(50.25, 1e-8),
        );
      },
    );
  }

  test(
    'Split creates independent movable parts and preserves the other half',
    () {
      final original = editing.wall('w', Offset.zero, const Offset(6, 0));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [original]),
      );
      addTearDown(model.dispose);
      model.execute(
        const CutArchitectWalls(
          storeyId: 's',
          wallIds: {'w'},
          start: Offset(3, -1),
          end: Offset(3, 1),
        ),
      );
      final parts = model.project.activeStorey.walls;
      model.execute(
        MoveArchitectElements(
          storeyId: 's',
          elementIds: {parts.last.id},
          delta: const Offset(0, 2),
        ),
      );
      expect(
        model.project.activeStorey.walls.first.toJson(),
        parts.first.toJson(),
      );
      expect(
        model.project.activeStorey.walls.last.startPoint,
        const Offset(3, 2),
      );
    },
  );

  testWidgets(
    'Selection tool chooses overlaps; drafting tools prioritize their own type',
    (tester) async {
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [editing.wall('w', const Offset(-2, 0), const Offset(2, 0))],
          columns: const [ArchitectColumn(id: 'c', position: Offset.zero)],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      final old = model.project;
      await tester.tap(find.byIcon(Icons.pan_tool_rounded));
      await tester.pumpAndSettle();
      await editing.hold(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementId, 'c');
      await editing.selectTool(tester, 'wall');
      await editing.hold(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementId, 'w');
      expect(
        tester
            .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
            .activeTool,
        ArchitectTool.wall,
      );
      await editing.selectTool(tester, 'column');
      await editing.hold(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementId, 'c');
      expect(identical(model.project, old), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in {
    'wall': Icons.line_weight_rounded,
    'axis': Icons.grid_on_rounded,
    'zone': Icons.space_dashboard_rounded,
    'column': Icons.view_column_rounded,
    'door': Icons.meeting_room_rounded,
    'window': Icons.window_rounded,
    'beam': Icons.horizontal_rule_rounded,
    'slab': Icons.layers_rounded,
    'opening': Icons.crop_free_rounded,
    'stair': Icons.stairs_rounded,
    'dimension': Icons.straighten_rounded,
    'level': Icons.change_history_rounded,
    'text': Icons.title_rounded,
    'line': Icons.timeline_rounded,
    'rect': Icons.crop_square_rounded,
    'circle': Icons.radio_button_unchecked_rounded,
    'measure': Icons.square_foot_rounded,
  }.entries) {
    testWidgets('${entry.key} uses an offset marker and cancels on pinch', (
      tester,
    ) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.ensureVisible(find.byIcon(entry.value));
      await tester.tap(find.byIcon(entry.value));
      await tester.pumpAndSettle();
      final old = model.project;
      final finger = workspace.screen(tester, const Offset(1, 1));
      final first = await tester.startGesture(finger, pointer: 81);
      await tester.pump(const Duration(milliseconds: 281));
      final paint = tester.widget<CustomPaint>(
        find.byKey(
          ValueKey(
            entry.key == 'wall'
                ? 'wall-offset-pointer'
                : 'architect-offset-pointer',
          ),
        ),
      );
      final marker = paint.painter! as StructuralPointerPainter;
      expect((marker.touchPos - marker.targetPos).dy, 64);
      expect(marker.targetPos.dx, marker.touchPos.dx);
      final second = await tester.startGesture(
        finger + const Offset(80, 0),
        pointer: 82,
      );
      await second.up();
      await first.up();
      await tester.pumpAndSettle();
      expect(identical(model.project, old), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Held column releases at its visible marker, not the finger', (
    tester,
  ) async {
    final model = workspace.commands();
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await editing.selectTool(tester, 'column');
    final g = await tester.startGesture(
      workspace.screen(tester, const Offset(1, 1)),
    );
    await tester.pump(const Duration(milliseconds: 281));
    final marker =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('architect-offset-pointer')),
                )
                .painter!
            as StructuralPointerPainter;
    final target = workspace
        .camera(tester)
        .toModel(marker.effectivePlacementPosition);
    await g.up();
    await tester.pumpAndSettle();
    expect(
      (model.project.activeStorey.columns.single.position - target).distance,
      lessThan(1e-8),
    );
  });

  testWidgets('Hold on empty space resumes placement after a selection', (
    tester,
  ) async {
    final model = editing.seeded(
      const ArchitectStorey(
        id: 's',
        name: 's',
        columns: [ArchitectColumn(id: 'c', position: Offset.zero)],
      ),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await editing.selectTool(tester, 'column');
    await editing.hold(tester, Offset.zero);
    expect(workspace.overlay(tester).selectedElementId, 'c');
    final g = await tester.startGesture(
      workspace.screen(tester, Offset.zero) + const Offset(120, 80),
    );
    await tester.pump(const Duration(milliseconds: 281));
    expect(
      find.byKey(const ValueKey('architect-offset-pointer')),
      findsOneWidget,
    );
    await g.up();
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.columns, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
