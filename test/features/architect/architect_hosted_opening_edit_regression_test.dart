import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart'
    show ArchitectTool;
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_opening_continuous_placement_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tool_ui;

const _hostId = 'w_main';
const _doorId = 'door_at_jamb';
const _windowId = 'window_at_jamb';

ArchitectWall _host(ArchitectProject project) =>
    project.activeStorey.walls.firstWhere((wall) => wall.id == _hostId);

ArchitectDoor _door(ArchitectProject project) => _host(project).doors.single;
ArchitectWindow _window(ArchitectProject project) =>
    _host(project).windows.single;

ArchitectProject _persisted(ArchitectCommandController commands) =>
    ArchitectProject.fromJson(
      jsonDecode(jsonEncode(commands.project.toJson())) as Map<String, dynamic>,
    );

Finder _paletteChip(String label) => find.descendant(
  of: find.byType(ArchitectToolPalette),
  matching: find.widgetWithText(ChoiceChip, label),
);

Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = _paletteChip(label);
  expect(chip, findsOneWidget);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<AppLocalizations> _selectOpening(
  WidgetTester tester,
  ArchitectCommandController commands,
) async {
  await workspace.openWorkspace(tester, commands);
  workspace.camera(tester).fit(const Rect.fromLTRB(-.5, -1, 4, 5), padding: 64);
  await tester.pumpAndSettle();
  final palette = tester.widget<ArchitectToolPalette>(
    find.byType(ArchitectToolPalette),
  );
  if (palette.activeTool != ArchitectTool.select) {
    await tool_ui.choose(tester, Icons.near_me_outlined);
    await tester.pumpAndSettle();
  }
  await tester.tapAt(workspace.screen(tester, const Offset(.45, 0)));
  await tester.pumpAndSettle();
  expect(commands.undoCount, 0);
  return AppLocalizations.of(
    tester.element(find.byType(ArchitectToolPalette)),
  )!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'placed door at host jamb accepts hinge and width edits with one undo each',
    (tester) async {
      const door = ArchitectDoor(
        id: _doorId,
        wallId: _hostId,
        offsetRatio: .15,
        width: .9,
        uuid: 'door-at-jamb-uuid',
      );
      // Accepted placement touches the start jamb. Multiplying the stored ratio
      // by the host length gives .44999999999999996 rather than exactly .45.
      const host = ArchitectWall(
        id: _hostId,
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        thickness: .25,
        doors: [door],
      );
      // A legacy opening elsewhere must not block edits to this selected door.
      const legacyWall = ArchitectWall(
        id: 'w_legacy',
        startPoint: Offset(0, 4),
        endPoint: Offset(1, 4),
        doors: [
          ArchitectDoor(
            id: 'legacy_door',
            wallId: 'w_legacy',
            offsetRatio: .1,
            width: 1,
            uuid: 'legacy-door-uuid',
          ),
        ],
      );
      final commands = workspace.seededController(walls: [host, legacyWall]);
      addTearDown(commands.dispose);
      final l = await _selectOpening(tester, commands);
      expect(
        tester
            .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
            .selectedDoor
            ?.id,
        _doorId,
      );

      await _tapChip(tester, l.architectDoorHingeLeft);
      expect(_door(commands.project).isHingeLeft, isFalse);
      expect(_door(commands.project).width, .9);
      expect(commands.undoCount, 1);
      expect(find.text(l.architectOperationRejected), findsNothing);

      await _tapChip(tester, '80 cm');
      expect(_door(commands.project).width, .8);
      expect(_door(commands.project).isHingeLeft, isFalse);
      expect(commands.undoCount, 2);
      final persisted = _persisted(commands);
      expect(_door(persisted).width, .8);
      expect(_door(persisted).isHingeLeft, isFalse);
      expect(_door(persisted).offsetRatio, .15);
      expect(persisted.activeStorey.walls.last.toJson(), legacyWall.toJson());
      expect(find.text(l.architectOperationRejected), findsNothing);

      commands.undo();
      await tester.pumpAndSettle();
      expect(commands.undoCount, 1);
      expect(_door(commands.project).width, .9);
      expect(_door(commands.project).isHingeLeft, isFalse);
      commands.undo();
      await tester.pumpAndSettle();
      expect(commands.undoCount, 0);
      expect(_door(commands.project).width, .9);
      expect(_door(commands.project).isHingeLeft, isTrue);

      commands.redo();
      commands.redo();
      await tester.pumpAndSettle();
      expect(commands.undoCount, 2);
      expect(_door(commands.project).width, .8);
      expect(_door(commands.project).isHingeLeft, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'placed window at host jamb accepts flip and width edits with one undo each',
    (tester) async {
      const window = ArchitectWindow(
        id: _windowId,
        wallId: _hostId,
        offsetRatio: .15,
        width: .9,
        uuid: 'window-at-jamb-uuid',
      );
      const host = ArchitectWall(
        id: _hostId,
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        thickness: .25,
        windows: [window],
      );
      final commands = workspace.seededController(walls: [host]);
      addTearDown(commands.dispose);
      final l = await _selectOpening(tester, commands);
      expect(
        tester
            .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
            .selectedWindow
            ?.id,
        _windowId,
      );

      await _tapChip(tester, l.architectWindowFlipSide);
      expect(_window(commands.project).isFlipped, isTrue);
      expect(_window(commands.project).width, .9);
      expect(commands.undoCount, 1);
      expect(find.text(l.architectOperationRejected), findsNothing);

      await _tapChip(tester, '80 cm');
      expect(_window(commands.project).width, .8);
      expect(_window(commands.project).isFlipped, isTrue);
      expect(commands.undoCount, 2);
      final persisted = _window(_persisted(commands));
      expect(persisted.width, .8);
      expect(persisted.isFlipped, isTrue);
      expect(persisted.offsetRatio, .15);
      expect(find.text(l.architectOperationRejected), findsNothing);

      commands.undo();
      await tester.pumpAndSettle();
      expect(commands.undoCount, 1);
      expect(_window(commands.project).width, .9);
      expect(_window(commands.project).isFlipped, isTrue);
      commands.undo();
      await tester.pumpAndSettle();
      expect(commands.undoCount, 0);
      expect(_window(commands.project).width, .9);
      expect(_window(commands.project).isFlipped, isFalse);

      commands.redo();
      commands.redo();
      await tester.pumpAndSettle();
      expect(commands.undoCount, 2);
      expect(_window(commands.project).width, .8);
      expect(_window(commands.project).isFlipped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
