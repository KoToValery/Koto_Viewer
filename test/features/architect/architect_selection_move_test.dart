import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_selection_move_button.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

Future<void> chooseMove(WidgetTester tester, String action) async {
  await tester.tap(find.byKey(const ValueKey('architect-selection-move')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('architect-move-$action')));
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['bg', 'en']) {
    for (final distance in [-.5, .5]) {
      testWidgets(
        'Phone Move offset retains junctions, openings and one Undo ($language, $distance)',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final model = editing.seeded(
            ArchitectStorey(
              id: 's',
              name: '',
              walls: [
                editing
                    .wall('a', const Offset(-2, 0), const Offset(2, 0))
                    .addDoor(
                      const ArchitectDoor(
                        id: 'd',
                        wallId: 'a',
                        uuid: 'd',
                        offsetRatio: .5,
                      ),
                    ),
                editing.wall('b', const Offset(-2, 0), const Offset(-2, 3)),
                editing.wall('c', const Offset(2, 0), const Offset(2, 3)),
              ],
            ),
          );
          addTearDown(model.dispose);
          model.restore(
            model.project.copyWith(units: ArchitectUnit.centimeters),
          );
          final original = model.project;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ArchitectWorkspaceScreen(commandController: model),
            ),
          );
          await tester.pumpAndSettle();
          await editing.selectTool(tester, 'wall');
          await workspace.wallTap(tester, const Offset(-1.25, 0));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('architect-wall-parallel')),
            findsNothing,
          );
          expect(workspace.overlay(tester).selectedElementId, 'a');
          final move = find.byKey(const ValueKey('architect-selection-move'));
          final l = AppLocalizations.of(tester.element(move))!;
          expect(l.localeName, language);
          await tester.tap(move);
          await tester.pumpAndSettle();
          for (final label in [
            l.architectMoveFree,
            l.architectMoveTransverse,
            l.architectMoveOffset,
          ]) {
            final item = find.text(label);
            expect(item, findsOneWidget);
            final rect = tester.getRect(item);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(360));
            expect(rect.bottom, lessThanOrEqualTo(800));
          }
          await tester.tap(find.byKey(const ValueKey('architect-move-offset')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('architect-axis-value')),
            '${distance * 100}',
          );
          await tester.tap(
            find.byKey(const ValueKey('architect-axis-value-save')),
          );
          await tester.pumpAndSettle();
          await editing.acceptGeometryCommand(tester);
          final walls = model.project.activeStorey.walls;
          expect(walls.first.startPoint, Offset(-2, distance));
          expect(walls.first.endPoint, Offset(2, distance));
          expect(walls[1].startPoint, walls.first.startPoint);
          expect(walls[2].startPoint, walls.first.endPoint);
          expect(walls[1].endPoint, const Offset(-2, 3));
          expect(walls[2].endPoint, const Offset(2, 3));
          expect(walls.first.doors.single.id, 'd');
          expect(walls.first.doors.single.wallId, 'a');
          expect(walls.first.doors.single.offsetRatio, .5);
          expect(model.undoCount, 1);
          model.undo();
          expect(model.project.activeStorey, same(original.activeStorey));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Move switches back to free movement, stops and cancels offset', (
    tester,
  ) async {
    final wall = editing.wall('a', Offset.zero, const Offset(4, 3));
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: '', walls: [wall]),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await tool_ui.setMagnetic(tester, false);
    await editing.hold(tester, const Offset(1, .75));
    await chooseMove(tester, 'transverse');
    await chooseMove(tester, 'free');
    await tester.tapAt(workspace.screen(tester, const Offset(2, 1.5)));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      workspace.screen(tester, const Offset(2, 1.5)),
    );
    await gesture.moveTo(workspace.screen(tester, const Offset(3, 2.5)));
    await gesture.up();
    await tester.pumpAndSettle();
    await editing.acceptGeometryCommand(tester);
    final moved = model.project.activeStorey.walls.single;
    final delta = moved.startPoint - wall.startPoint;
    expect(
      delta.dx * wall.unitVector.dx + delta.dy * wall.unitVector.dy,
      greaterThan(.5),
    );
    expect(model.undoCount, 1);
    final button = tester.widget<ArchitectSelectionMoveButton>(
      find.byType(ArchitectSelectionMoveButton),
    );
    expect(button.active, isFalse);
    expect(button.transverse, isFalse);
    final before = model.project;
    await chooseMove(tester, 'offset');
    final l = AppLocalizations.of(
      tester.element(find.byKey(const ValueKey('architect-axis-value'))),
    )!;
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(model.project, same(before));
    expect(model.undoCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Move applies a signed offset to a CAD line and preserves its style',
    (tester) async {
      const line = ArchitectCadPrimitive(
        id: 'line',
        type: CadPrimitiveType.line,
        startPoint: Offset(-2, 0),
        endPoint: Offset(2, 0),
        colorValue: 0xFF234567,
        strokeWidth: 2.5,
      );
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', cadPrimitives: [line]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.ensureSelectionTool(tester);
      await workspace.wallTap(tester, const Offset(-1, 0));
      await tester.pumpAndSettle();
      await chooseMove(tester, 'offset');
      await tester.enterText(
        find.byKey(const ValueKey('architect-axis-value')),
        '-0.5',
      );
      await tester.tap(find.byKey(const ValueKey('architect-axis-value-save')));
      await tester.pumpAndSettle();
      await editing.acceptGeometryCommand(tester);
      final next = model.project.activeStorey.cadPrimitives.single;
      expect(next.startPoint, const Offset(-2, -.5));
      expect(next.endPoint, const Offset(2, -.5));
      expect(next.id, line.id);
      expect(next.colorValue, line.colorValue);
      expect(next.strokeWidth, line.strokeWidth);
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project.activeStorey.cadPrimitives.single, same(line));
      expect(tester.takeException(), isNull);
    },
  );
}
