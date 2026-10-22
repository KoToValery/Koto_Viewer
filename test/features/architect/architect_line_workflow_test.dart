import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_line_editing.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectCadPrimitive line(String id, Offset a, Offset b) =>
    ArchitectCadPrimitive(
      id: id,
      type: CadPrimitiveType.line,
      startPoint: a,
      endPoint: b,
      colorValue: 0xFF234567,
      strokeWidth: 2.5,
    );

void main() {
  testWidgets('Phone line controls and keypad fit 360 by 800; cancel preserves mode', (tester) async {
    final model = workspace.commands();
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    await tools.choose(tester, Icons.timeline_rounded);
    await tester.pumpAndSettle();
    workspace.camera(tester).fit(const Rect.fromLTRB(-3, -3, 3, 3), padding: 40);
    await tester.pumpAndSettle();
    await workspace.wallTap(tester, Offset.zero);
    await workspace.wallTap(tester, const Offset(1, 0));
    await tester.tap(find.byKey(const ValueKey('wall-length-input')));
    await tester.pump();
    for (final key in ['wall-dimension-mode', 'wall-chain-toggle', 'wall-length-input', 'wall-key-0', 'wall-end', 'wall-continue', 'wall-cancel']) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(800));
    }
    await tester.tap(find.byKey(const ValueKey('wall-cancel')));
    await tester.pump();
    expect(model.project.activeStorey.cadPrimitives, isEmpty);
    await workspace.wallTap(tester, Offset.zero);
    await workspace.wallTap(tester, const Offset(1, 0));
    expect(find.byKey(const ValueKey('wall-length-input')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wall-end')));
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.cadPrimitives, hasLength(1));
    expect(find.byType(EditableText), findsNothing);
    expect(tester.takeException(), isNull);
  });
  final a = line('a', Offset.zero, const Offset(6, 0));
  final b = line('b', const Offset(2, -2), const Offset(2, 2));
  final c = line('c', const Offset(4, -2), const Offset(4, 2));
  ArchitectCommandController seeded(List<ArchitectCadPrimitive> lines) {
    final model = editing.seeded(
      ArchitectStorey(
        id: 's',
        name: 's',
        cadPrimitives: lines,
        walls: const [
          ArchitectWall(
            id: 'wall',
            startPoint: Offset(10, 0),
            endPoint: Offset(10, 3),
          ),
        ],
      ),
    );
    addTearDown(model.dispose);
    return model;
  }

  void execute(
    ArchitectCommandController model,
    ArchitectModelCommand command,
  ) => model.execute(ArchitectLineEditing.adapt(model.project, command));

  test(
    'Trim removes the picked interval, keeps style, real walls and Undo/Redo',
    () {
      final model = seeded([a, b, c]);
      final before = model.project.toJson();
      execute(
        model,
        const TrimArchitectWall(storeyId: 's', wallId: 'a', pick: Offset(3, 0)),
      );
      final lines = model.project.activeStorey.cadPrimitives;
      expect(lines, hasLength(4));
      expect(lines[0].startPoint, Offset.zero);
      expect(lines[0].endPoint, const Offset(2, 0));
      expect(lines[1].startPoint, const Offset(4, 0));
      expect(lines[1].endPoint, const Offset(6, 0));
      expect(
        lines
            .take(2)
            .every(
              (p) =>
                  p.colorValue == a.colorValue &&
                  p.strokeWidth == a.strokeWidth,
            ),
        isTrue,
      );
      expect(model.project.activeStorey.walls.single.id, 'wall');
      final after = model.project.toJson();
      model.undo();
      expect(model.project.toJson(), before);
      model.redo();
      expect(model.project.toJson(), after);
    },
  );
  test(
    'Split many lines is atomic and preserves styles and unrelated figures',
    () {
      final rect = a.copyWith(
        id: 'rect',
        type: CadPrimitiveType.rect,
        endPoint: const Offset(2, 2),
      );
      final model = seeded([
        a,
        a.copyWith(
          id: 'other',
          startPoint: const Offset(0, 1),
          endPoint: const Offset(6, 1),
        ),
        rect,
      ]);
      execute(
        model,
        const CutArchitectWalls(
          storeyId: 's',
          wallIds: {'a', 'other'},
          start: Offset(3, -1),
          end: Offset(3, 2),
        ),
      );
      expect(model.project.activeStorey.cadPrimitives, hasLength(5));
      expect(
        model.project.activeStorey.cadPrimitives.last.toJson(),
        rect.toJson(),
      );
      expect(
        model.project.activeStorey.cadPrimitives
            .take(4)
            .every(
              (p) =>
                  p.colorValue == a.colorValue &&
                  p.strokeWidth == a.strokeWidth,
            ),
        isTrue,
      );
      model.undo();
      expect(model.project.activeStorey.cadPrimitives, hasLength(3));
    },
  );
  test('Endpoint edit does not drag neighbours or real walls', () {
    final model = seeded([a, b]);
    execute(
      model,
      UpdateArchitectWall(
        storeyId: 's',
        wall: ArchitectLineEditing.segment(
          a,
        ).copyWith(endPoint: const Offset(5, 1)),
        carryConnections: false,
      ),
    );
    expect(
      model.project.activeStorey.cadPrimitives[0].endPoint,
      const Offset(5, 1),
    );
    expect(model.project.activeStorey.cadPrimitives[1].toJson(), b.toJson());
    expect(
      model.project.activeStorey.walls.single.endPoint,
      const Offset(10, 3),
    );
  });
  test(
    'Extend and join use exact intersections and preserve line appearance',
    () {
      final model = seeded([
        a.copyWith(endPoint: const Offset(1, 0)),
        b.copyWith(startPoint: const Offset(2, 1)),
      ]);
      execute(
        model,
        const JoinArchitectWalls(storeyId: 's', wallIds: {'a', 'b'}),
      );
      expect(
        model.project.activeStorey.cadPrimitives[0].endPoint,
        const Offset(2, 0),
      );
      expect(
        model.project.activeStorey.cadPrimitives[1].startPoint,
        const Offset(2, 0),
      );
      execute(
        model,
        const ExtendArchitectWall(
          storeyId: 's',
          wallId: 'a',
          target: Offset(5, .3),
        ),
      );
      expect(
        model.project.activeStorey.cadPrimitives[0].endPoint,
        const Offset(5, 0),
      );
      expect(
        model.project.activeStorey.cadPrimitives[0].strokeWidth,
        a.strokeWidth,
      );
    },
  );
  test('Invalid and mixed edits leave the project untouched', () {
    final model = seeded([a]);
    final before = model.project.toJson();
    expect(
      () => execute(
        model,
        const JoinArchitectWalls(storeyId: 's', wallIds: {'a', 'wall'}),
      ),
      throwsArgumentError,
    );
    expect(
      () => execute(
        model,
        UpdateArchitectWall(
          storeyId: 's',
          wall: ArchitectLineEditing.segment(a).copyWith(endPoint: Offset.zero),
          carryConnections: false,
        ),
      ),
      throwsArgumentError,
    );
    expect(model.project.toJson(), before);
  });

  testWidgets(
    'Line exact length, Continue and End share the wall keypad workflow',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.timeline_rounded);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, Offset.zero);
      await workspace.wallTap(tester, const Offset(3, .04));
      expect(model.project.activeStorey.cadPrimitives, isEmpty);
      await tester.tap(find.byKey(const ValueKey('wall-length-input')));
      await tester.pump();
      for (final key in ['4', '.', '2', '5']) {
        await tester.tap(find.byKey(ValueKey('wall-key-$key')));
        await tester.pump();
      }
      expect(find.byType(EditableText), findsNothing);
      await tester.tap(find.byKey(const ValueKey('wall-continue')));
      await tester.pump();
      final first = model.project.activeStorey.cadPrimitives.single;
      expect((first.endPoint - first.startPoint).distance, closeTo(4.25, 1e-9));
      expect(workspace.overlay(tester).activeDraftStart, first.endPoint);
      await workspace.wallTap(tester, first.endPoint + const Offset(0, 2));
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.last.startPoint,
        first.endPoint,
      );
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      expect(model.project.activeStorey.walls, isEmpty);
      model.undo();
      expect(model.project.activeStorey.cadPrimitives, hasLength(1));
      model.redo();
      expect(model.project.activeStorey.cadPrimitives, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Held line placement aims above finger and a second finger cancels it',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.timeline_rounded);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-dimension-mode')));
      await tester.pump();
      final camera = workspace.camera(tester).translation;
      final first = await tester.startGesture(
        workspace.screen(tester, Offset.zero) + const Offset(0, 64),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await first.up();
      await tester.pump();
      expect(workspace.overlay(tester).activeDraftStart, Offset.zero);
      final second = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 0)) + const Offset(0, 64),
        pointer: 2,
      );
      await tester.pump(const Duration(milliseconds: 281));
      await second.moveTo(
        workspace.screen(tester, const Offset(4, .04)) + const Offset(0, 64),
      );
      await tester.pump();
      expect(workspace.camera(tester).translation, camera);
      final third = await tester.startGesture(
        workspace.screen(tester, const Offset(-1, -1)),
        pointer: 3,
      );
      await tester.pump();
      await third.up();
      await second.up();
      await tester.pump();
      expect(model.project.activeStorey.cadPrimitives, isEmpty);
      expect(workspace.overlay(tester).activeDraftStart, Offset.zero);
      await workspace.wallTap(tester, const Offset(4, 0));
      expect(
        (model.project.activeStorey.cadPrimitives.single.endPoint -
                const Offset(4, 0))
            .distance,
        lessThan(1e-9),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Line context menu exposes cut and split; endpoint drag has Undo',
    (tester) async {
      final model = seeded([a, b, c]);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.timeline_rounded);
      await tester.pumpAndSettle();
      await editing.hold(tester, const Offset(1, 0));
      expect(workspace.overlay(tester).selectedElementId, 'a');
      await tester.tap(find.byKey(const ValueKey('architect-wall-actions')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wall-cut')), findsOneWidget);
      expect(find.byKey(const ValueKey('wall-split-stroke')), findsOneWidget);
      expect(find.byKey(const ValueKey('wall-extend')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wall-cut')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(3, 0));
      expect(model.project.activeStorey.cadPrimitives, hasLength(4));
      model.undo();
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(
        workspace.screen(tester, const Offset(6, 0)),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveTo(workspace.screen(tester, const Offset(6, 1)));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.first.endPoint,
        const Offset(6, 1),
      );
      model.undo();
      expect(
        model.project.activeStorey.cadPrimitives.first.endPoint,
        const Offset(6, 0),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
