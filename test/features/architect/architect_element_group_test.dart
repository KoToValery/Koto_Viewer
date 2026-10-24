import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_line_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectCadPrimitive line(String id, double y) => ArchitectCadPrimitive(
  id: id,
  type: CadPrimitiveType.line,
  startPoint: Offset(0, y),
  endPoint: Offset(4, y),
);
ArchitectStorey fixture() => ArchitectStorey(
  id: 's',
  name: '',
  cadPrimitives: [line('a', 0), line('b', 2), line('c', 4)],
);
const group = GroupArchitectElements(
  storeyId: 's',
  groupId: 'g',
  elementIds: {'a', 'b'},
);
Future<void> action(WidgetTester tester, BimEditAction a) async {
  for (var i = 0; i < 4; i++) {
    final f = find.byKey(ValueKey('architect-radial-${a.name}'));
    if (f.evaluate().isNotEmpty) {
      expect(tester.widget<InkWell>(f).onTap, isNotNull);
      await tester.tap(f);
      await tester.pumpAndSettle();
      return;
    }
    await tester.tap(find.byKey(const ValueKey('architect-radial-more')));
    await tester.pumpAndSettle();
  }
  fail('Missing action ${a.name}');
}

void main() {
  test(
    'Flat groups persist, preserve geometry, reject nesting and undo in one step',
    () {
      final model = editing.seeded(fixture());
      addTearDown(model.dispose);
      final before = model.project.toJson();
      model.execute(group);
      final s = model.project.activeStorey;
      expect(s.expandGroups({'a'}), {'a', 'b'});
      expect(
        s.cadPrimitives.map((p) => p.toJson()).toList(),
        before['storeys'][0]['cadPrimitives'],
      );
      expect(
        ArchitectSelection.records(
          model.project.toJson(),
          's',
        ).any((r) => r['id'] == 'g'),
        isFalse,
      );
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(model.project.toJson())),
      );
      expect(restored.activeStorey.groups.single.elementIds, {'a', 'b'});
      for (final ids in [
        {'g', 'c'},
        {'a', 'c'},
        {'a'},
        {'a', 'missing'},
      ]) {
        expect(
          () => model.execute(
            GroupArchitectElements(
              storeyId: 's',
              groupId: 'bad',
              elementIds: ids,
            ),
          ),
          throwsArgumentError,
        );
      }
      model.undo();
      expect(model.project.toJson(), before);
      model.redo();
      expect(model.project.activeStorey.groups, hasLength(1));
      model.execute(
        const UngroupArchitectElements(storeyId: 's', groupId: 'g'),
      );
      expect(model.project.activeStorey.groups, isEmpty);
      model.undo();
      expect(model.project.activeStorey.groups, hasLength(1));
    },
  );
  test(
    'Group members must belong to one storey; old projects have no groups',
    () {
      final model = editing.seeded(fixture());
      addTearDown(model.dispose);
      final p = model.project.copyWith(
        storeys: [
          fixture(),
          ArchitectStorey(id: 'other', name: '', cadPrimitives: [line('d', 0)]),
        ],
      );
      expect(
        () => const GroupArchitectElements(
          storeyId: 's',
          groupId: 'g',
          elementIds: {'a', 'd'},
        ).apply(p),
        throwsArgumentError,
      );
      expect(
        ArchitectProject.fromJson(model.project.toJson()).activeStorey.groups,
        isEmpty,
      );
    },
  );
  test(
    'Copies form separate groups; member deletion and splits keep valid membership',
    () {
      final source = editing.seeded(fixture());
      addTearDown(source.dispose);
      var p = group.apply(source.project);
      final tool = ArchitectElementTool();
      addTearDown(tool.dispose);
      final (copied, copyIds) = tool.duplicateElementsByIds(p.activeStorey, {
        'a',
        'b',
      });
      expect(copied.groups, hasLength(2));
      expect(copied.groups.last.elementIds, copyIds.toSet());
      final (mirrored, mirroredIds) = tool.mirrorElementsByIds(
        p.activeStorey,
        {'a', 'b'},
        origin: Offset.zero,
        direction: const Offset(0, 1),
        isDuplicate: true,
      );
      expect(mirrored.groups.last.elementIds, mirroredIds.toSet());
      p = const InsertArchitectElementPoint(
        storeyId: 's',
        elementId: 'a',
        point: Offset(2, 0),
        newElementId: 'split',
      ).apply(p);
      expect(p.activeStorey.groups.single.elementIds, {'a', 'b', 'split'});
      final deleted = tool.deleteElementsByIds(p.activeStorey, {'a', 'split'});
      expect(deleted.groups, isEmpty);
      final serialized = deleted.toJson();
      expect(serialized.containsKey('groups'), isFalse);
    },
  );
  test(
    'Cutting grouped CAD lines preserves generated members and wall groups',
    () {
      final model = editing.seeded(fixture());
      addTearDown(model.dispose);
      model.execute(group);
      model.execute(
        ArchitectLineEditing.adapt(
          model.project,
          const CutArchitectWalls(
            storeyId: 's',
            wallIds: {'a'},
            start: Offset(2, -1),
            end: Offset(2, 1),
          ),
        ),
      );
      expect(model.project.activeStorey.groups.single.elementIds, hasLength(3));
      expect(
        model.project.activeStorey.groups.single.elementIds,
        containsAll(['a', 'b']),
      );
      model.undo();
      expect(model.project.activeStorey.groups.single.elementIds, {'a', 'b'});
    },
  );
  test(
    'Trimming and copying a subset retain flat membership; rotation is rigid',
    () {
      final model = editing.seeded(fixture());
      addTearDown(model.dispose);
      model.execute(group);
      final tool = ArchitectElementTool();
      addTearDown(tool.dispose);
      final (copy, ids) = tool.duplicateElementsByIds(
        model.project.activeStorey,
        {'a', 'b'},
        copyGroups: false,
      );
      expect(copy.groups, hasLength(1));
      final expanded = AddArchitectGroupMembers(
        storeyId: 's',
        groupId: 'g',
        elementIds: ids.toSet(),
      ).apply(model.project.updateActiveStorey(copy));
      expect(expanded.activeStorey.groups.single.elementIds, hasLength(4));
      final rotated = tool.rotateElementsByIds(model.project.activeStorey, {
        'a',
        'b',
      }, origin: Offset.zero);
      expect(rotated.cadPrimitives[0].startPoint, Offset.zero);
      expect(
        (rotated.cadPrimitives[1].startPoint - const Offset(-2, 0)).distance,
        lessThan(1e-7),
      );
      expect(rotated.groups.single.elementIds, {'a', 'b'});
      final withCutters = model.project.updateActiveStorey(
        model.project.activeStorey.copyWith(
          cadPrimitives: [
            ...fixture().cadPrimitives,
            const ArchitectCadPrimitive(
              id: 'left',
              type: CadPrimitiveType.line,
              startPoint: Offset(1, -1),
              endPoint: Offset(1, 1),
            ),
            const ArchitectCadPrimitive(
              id: 'right',
              type: CadPrimitiveType.line,
              startPoint: Offset(3, -1),
              endPoint: Offset(3, 1),
            ),
          ],
        ),
      );
      final trimmed = ArchitectLineEditing.adapt(
        withCutters,
        const TrimArchitectWall(storeyId: 's', wallId: 'a', pick: Offset(2, 0)),
      ).apply(withCutters);
      expect(trimmed.activeStorey.groups.single.elementIds, hasLength(3));
    },
  );
  testWidgets(
    'Group, select all, edit one member, exit and ungroup through More',
    (tester) async {
      final model = editing.seeded(fixture());
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(2, 0)));
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(2, 2)));
      await tester.pumpAndSettle();
      await editing.contextHold(tester, const Offset(2, 0));
      await action(tester, BimEditAction.group);
      expect(model.project.activeStorey.groups.single.elementIds, {'a', 'b'});
      await tester.tap(find.byKey(const ValueKey('architect-deselect')));
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(2, 2)));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'a', 'b'});
      await editing.contextHold(tester, const Offset(2, 2));
      await action(tester, BimEditAction.editGroup);
      expect(
        find.byKey(const ValueKey('architect-group-done')),
        findsOneWidget,
      );
      await tester.tapAt(workspace.screen(tester, const Offset(2, 0)));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'a'});
      await tester.tapAt(workspace.screen(tester, const Offset(2, 4)));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      model.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'a',
          delta: Offset(1, 0),
          carryConnections: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.groups.single.elementIds, {'a', 'b'});
      expect(
        model.project.activeStorey.cadPrimitives[1].startPoint,
        const Offset(0, 2),
      );
      await tester.tap(find.byKey(const ValueKey('architect-group-done')));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'a', 'b'});
      await editing.contextHold(tester, const Offset(2, 2));
      await action(tester, BimEditAction.ungroup);
      expect(model.project.activeStorey.groups, isEmpty);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.groups, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Dragging a group moves every member and Undo restores the complete group',
    (tester) async {
      final model = editing.seeded(fixture());
      addTearDown(model.dispose);
      model.execute(group);
      await workspace.open(tester, model);
      await tools.setMagnetic(tester, false);
      await tester.tapAt(workspace.screen(tester, const Offset(2, 2)));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'a', 'b'});
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 2)),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(workspace.screen(tester, const Offset(3, 3)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives[0].startPoint,
        const Offset(1, 1),
      );
      expect(
        model.project.activeStorey.cadPrimitives[1].startPoint,
        const Offset(1, 3),
      );
      expect(
        model.project.activeStorey.cadPrimitives[2].startPoint,
        const Offset(0, 4),
      );
      model.undo();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives[0].startPoint,
        Offset.zero,
      );
      expect(model.project.activeStorey.groups.single.elementIds, {'a', 'b'});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('A copied member stays in the edited group with one Undo', (
    tester,
  ) async {
    final model = editing.seeded(fixture());
    addTearDown(model.dispose);
    model.execute(group);
    await workspace.open(tester, model);
    await tools.setMagnetic(tester, false);
    await editing.contextHold(tester, const Offset(2, 0));
    await action(tester, BimEditAction.editGroup);
    await editing.contextHold(tester, const Offset(2, 0));
    await action(tester, BimEditAction.duplicate);
    expect(model.project.activeStorey.cadPrimitives, hasLength(3));
    final gesture = await tester.startGesture(
      workspace.screen(tester, const Offset(2, 0)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(workspace.screen(tester, const Offset(3, 1)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.cadPrimitives, hasLength(4));
    expect(model.project.activeStorey.groups.single.elementIds, hasLength(3));
    expect(find.byKey(const ValueKey('architect-group-done')), findsOneWidget);
    model.undo();
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.cadPrimitives, hasLength(3));
    expect(model.project.activeStorey.groups.single.elementIds, {'a', 'b'});
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Finish groups only committed chain segments and Undo leaves the lines',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.timeline_rounded);
      await tester.pumpAndSettle();
      workspace.camera(tester).fit(const Rect.fromLTRB(-2, -2, 8, 6));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, Offset.zero);
      await workspace.wallTap(tester, const Offset(3, 0));
      await tester.tap(find.byKey(const ValueKey('wall-continue')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(3, 3));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-continue')));
      await tester.pumpAndSettle();
      model.undo();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('architect-draft-group')), findsNothing);
      model.redo();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-draft-group')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('architect-draft-group-finish')),
      );
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.groups.single.elementIds, hasLength(2));
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.groups, isEmpty);
      expect(model.project.activeStorey.cadPrimitives, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  for (final wall in [false, true]) {
    for (final grouped in [false, true]) {
      testWidgets('Draft ${wall ? 'walls' : 'lines'} with grouping $grouped', (
        tester,
      ) async {
        final model = workspace.commands();
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        if (grouped) {
          tester.view.physicalSize = const Size(320, 740);
          await tester.pumpAndSettle();
        }
        await tools.choose(
          tester,
          wall ? Icons.line_weight_rounded : Icons.timeline_rounded,
        );
        await tester.pumpAndSettle();
        workspace.camera(tester).fit(const Rect.fromLTRB(-2, -2, 8, 6));
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, Offset.zero);
        await workspace.wallTap(tester, const Offset(3, 0));
        expect(
          find.byKey(const ValueKey('architect-draft-group')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('wall-continue')));
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(3, 3));
        await tester.pumpAndSettle();
        final checkbox = find.byKey(const ValueKey('architect-draft-group'));
        expect(tester.widget<Checkbox>(checkbox).value, isFalse);
        if (grouped) {
          await tester.tap(checkbox);
          await tester.pump();
        }
        await tester.tap(find.byKey(const ValueKey('wall-end')));
        await tester.pumpAndSettle();
        final s = model.project.activeStorey;
        expect(wall ? s.walls : s.cadPrimitives, hasLength(2));
        expect(s.groups, hasLength(grouped ? 1 : 0));
        if (grouped) {
          expect(s.groups.single.elementIds, s.groupableIds);
          model.undo();
          await tester.pumpAndSettle();
          expect(model.project.activeStorey.groups, isEmpty);
          expect(
            wall
                ? model.project.activeStorey.walls
                : model.project.activeStorey.cadPrimitives,
            hasLength(1),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
