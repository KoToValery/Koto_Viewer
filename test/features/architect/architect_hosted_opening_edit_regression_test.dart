import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart'
    show ArchitectTool, WallDraftingMode;
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

Future<void> _enterOpeningDimension(
  WidgetTester tester,
  String chipKey,
  String expectedCurrentLabel,
  String digits,
) async {
  final chip = find.descendant(
    of: find.byType(ArchitectToolPalette),
    matching: find.byKey(ValueKey(chipKey)),
  );
  expect(chip, findsOneWidget);
  expect(
    find.descendant(of: chip, matching: find.text(expectedCurrentLabel)),
    findsOneWidget,
  );
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
  for (final ch in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('bim-number-key-$ch')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
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

      expect(_paletteChip('70 cm'), findsNothing);
      expect(_paletteChip('210 cm'), findsNothing);
      expect(_paletteChip(l.architectDoorSillNone), findsNothing);
      expect(_paletteChip(l.architectDoorSillStep), findsNothing);
      expect(
        find.byKey(const ValueKey('door-height-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('door-sill-input')),
        findsOneWidget,
      );
      await _enterOpeningDimension(tester, 'door-width-input', '90 cm', '80');
      expect(_door(commands.project).width, .8);
      expect(_door(commands.project).isHingeLeft, isFalse);
      expect(commands.undoCount, 2);
      await _enterOpeningDimension(tester, 'door-sill-input', '0 cm', '12');
      expect(_door(commands.project).sillHeight, closeTo(.12, 1e-9));
      expect(commands.undoCount, 3);
      final persisted = _persisted(commands);
      expect(_door(persisted).width, .8);
      expect(_door(persisted).sillHeight, closeTo(.12, 1e-9));
      expect(_door(persisted).isHingeLeft, isFalse);
      expect(_door(persisted).offsetRatio, .15);
      expect(persisted.activeStorey.walls.last.toJson(), legacyWall.toJson());
      expect(find.text(l.architectOperationRejected), findsNothing);

      commands.undo();
      await tester.pumpAndSettle();
      expect(commands.undoCount, 2);
      expect(_door(commands.project).sillHeight, 0);
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
      commands.redo();
      await tester.pumpAndSettle();
      expect(commands.undoCount, 3);
      expect(_door(commands.project).width, .8);
      expect(_door(commands.project).sillHeight, closeTo(.12, 1e-9));
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

      expect(_paletteChip('80 cm'), findsNothing);
      expect(_paletteChip('150 cm'), findsNothing);
      expect(
        find.byKey(const ValueKey('window-height-input')),
        findsOneWidget,
      );
      await _enterOpeningDimension(tester, 'window-width-input', '90 cm', '80');
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

  testWidgets(
    'initial door placement uses single direct width, height, and sill inputs without presets',
    (tester) async {
      const host = ArchitectWall(
        id: _hostId,
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        thickness: .25,
      );
      final commands = workspace.seededController(walls: [host]);
      addTearDown(commands.dispose);

      await workspace.openWorkspace(tester, commands);
      workspace
          .camera(tester)
          .fit(const Rect.fromLTRB(-.5, -1, 4.5, 2), padding: 64);
      await tester.pumpAndSettle();

      await tool_ui.choose(tester, Icons.meeting_room_rounded);
      await tester.pumpAndSettle();

      final palette = tester.widget<ArchitectToolPalette>(
        find.byType(ArchitectToolPalette),
      );
      expect(palette.activeTool, ArchitectTool.door);
      expect(palette.selectedDoor, isNull);

      final l = AppLocalizations.of(
        tester.element(find.byType(ArchitectToolPalette)),
      )!;
      expect(_paletteChip('60 cm'), findsNothing);
      expect(_paletteChip('70 cm'), findsNothing);
      expect(_paletteChip('210 cm'), findsNothing);
      expect(_paletteChip(l.architectDoorSillNone), findsNothing);
      expect(_paletteChip(l.architectDoorSillStep), findsNothing);
      expect(find.byKey(const ValueKey('door-width-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('door-height-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('door-sill-input')), findsOneWidget);

      await _enterOpeningDimension(tester, 'door-width-input', '90 cm', '85');
      await _enterOpeningDimension(
        tester,
        'door-height-input',
        '200 cm',
        '215',
      );
      await _enterOpeningDimension(tester, 'door-sill-input', '0 cm', '12');

      await tester.tapAt(workspace.screen(tester, const Offset(2.0, 0)));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      expect(_host(commands.project).doors, hasLength(1));
      final placed = _door(commands.project);
      expect(placed.width, closeTo(.85, 1e-9));
      expect(placed.height, closeTo(2.15, 1e-9));
      expect(placed.sillHeight, closeTo(.12, 1e-9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial window placement uses single direct width, height, and sill inputs without presets',
    (tester) async {
      const host = ArchitectWall(
        id: _hostId,
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        thickness: .25,
      );
      final commands = workspace.seededController(walls: [host]);
      addTearDown(commands.dispose);

      await workspace.openWorkspace(tester, commands);
      workspace
          .camera(tester)
          .fit(const Rect.fromLTRB(-.5, -1, 4.5, 2), padding: 64);
      await tester.pumpAndSettle();

      await tool_ui.choose(tester, Icons.window_rounded);
      await tester.pumpAndSettle();

      final palette = tester.widget<ArchitectToolPalette>(
        find.byType(ArchitectToolPalette),
      );
      expect(palette.activeTool, ArchitectTool.window);
      expect(palette.selectedWindow, isNull);

      expect(_paletteChip('80 cm'), findsNothing);
      expect(_paletteChip('150 cm'), findsNothing);
      expect(_paletteChip('180 cm'), findsNothing);
      expect(find.byKey(const ValueKey('window-width-input')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('window-height-input')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('window-sill-input')), findsOneWidget);

      await _enterOpeningDimension(
        tester,
        'window-width-input',
        '120 cm',
        '135',
      );
      await _enterOpeningDimension(
        tester,
        'window-height-input',
        '140 cm',
        '145',
      );
      await _enterOpeningDimension(tester, 'window-sill-input', '90 cm', '85');

      await tester.tapAt(workspace.screen(tester, const Offset(2.0, 0)));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      expect(_host(commands.project).windows, hasLength(1));
      final placed = _window(commands.project);
      expect(placed.width, closeTo(1.35, 1e-9));
      expect(placed.height, closeTo(1.45, 1e-9));
      expect(placed.sillHeight, closeTo(.85, 1e-9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'door and window placement sub-bars fit cleanly on narrow phone in bg locale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final tool in [ArchitectTool.door, ArchitectTool.window]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('bg'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              bottomNavigationBar: ArchitectToolPalette(
                activeTool: tool,
                onToolChanged: (_) {},
                onZoneCategoryChanged: (_) {},
                wallThickness: 0.25,
                onWallThicknessChanged: (_) {},
                wallMode: WallDraftingMode.singleLine,
                onWallModeChanged: (_) {},
                doorWidth: 0.90,
                onDoorWidthChanged: (_) {},
                doorHeight: 2.00,
                onDoorHeightChanged: (_) {},
                doorSill: 0.0,
                onDoorSillChanged: (_) {},
                isHingeLeft: true,
                onHingeSideChanged: (_) {},
                windowWidth: 1.20,
                onWindowWidthChanged: (_) {},
                windowHeight: 1.40,
                onWindowHeightChanged: (_) {},
                windowSill: 0.90,
                onWindowSillChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectToolPalette)),
        )!;
        if (tool == ArchitectTool.door) {
          expect(find.byKey(const ValueKey('door-width-input')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('door-height-input')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('door-sill-input')), findsOneWidget);
          expect(find.text(l.architectDoorSill), findsOneWidget);
          expect(find.text(l.architectDoorSillNone), findsNothing);
          expect(find.text(l.architectDoorSillStep), findsNothing);
        } else {
          expect(
            find.byKey(const ValueKey('window-width-input')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('window-height-input')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('window-sill-input')),
            findsOneWidget,
          );
          expect(find.text(l.architectWindowSill), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
