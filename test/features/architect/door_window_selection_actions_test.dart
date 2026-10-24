import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';

void main() {
  group('ArchitectWindow model tests', () {
    test('isFlipped defaults to false and survives serialization', () {
      const win = ArchitectWindow(
        id: 'win-1',
        wallId: 'wall-1',
        offsetRatio: 0.5,
        uuid: 'UUID-WIN-1',
      );
      expect(win.isFlipped, isFalse);

      final flipped = win.copyWith(isFlipped: true);
      expect(flipped.isFlipped, isTrue);

      final json = flipped.toJson();
      expect(json['isFlipped'], isTrue);

      final deserialized = ArchitectWindow.fromJson(json);
      expect(deserialized.isFlipped, isTrue);
    });
  });

  group('ArchitectSelection and SetArchitectElementProperties', () {
    test('SetArchitectElementProperties can flip window isFlipped', () {
      final now = DateTime.now();
      const win = ArchitectWindow(
        id: 'win-1',
        wallId: 'wall-1',
        offsetRatio: 0.5,
        uuid: 'UUID-WIN-1',
        isFlipped: false,
      );
      final wall = ArchitectWall(
        id: 'wall-1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        windows: const [win],
      );
      final project = ArchitectProject(
        id: 'proj-1',
        name: 'Test Project',
        createdAt: now,
        updatedAt: now,
        storeys: [
          ArchitectStorey(
            id: 'storey-1',
            name: 'Storey 1',
            walls: [wall],
          ),
        ],
        activeStoreyId: 'storey-1',
      );

      final cmd = SetArchitectElementProperties(
        storeyId: 'storey-1',
        elementIds: {'win-1'},
        textValues: {'isFlipped': 'true'},
      );

      final updated = cmd.apply(project);
      final updatedWin = updated.activeStorey.walls.first.windows.first;
      expect(updatedWin.isFlipped, isTrue);
    });

    test('SetArchitectElementProperties can flip door openInward and isHingeLeft', () {
      final now = DateTime.now();
      const door = ArchitectDoor(
        id: 'door-1',
        wallId: 'wall-1',
        offsetRatio: 0.5,
        openInward: true,
        isHingeLeft: true,
        specId: "1'",
        uuid: 'UUID-DOOR-1',
      );
      final wall = ArchitectWall(
        id: 'wall-1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        doors: const [door],
      );
      final project = ArchitectProject(
        id: 'proj-1',
        name: 'Test Project',
        createdAt: now,
        updatedAt: now,
        storeys: [
          ArchitectStorey(
            id: 'storey-1',
            name: 'Storey 1',
            walls: [wall],
          ),
        ],
        activeStoreyId: 'storey-1',
      );

      // Flip swing outward
      final cmdSwing = SetArchitectElementProperties(
        storeyId: 'storey-1',
        elementIds: {'door-1'},
        textValues: {'openInward': 'false'},
      );
      final updated1 = cmdSwing.apply(project);
      final updatedDoor1 = updated1.activeStorey.walls.first.doors.first;
      expect(updatedDoor1.openInward, isFalse);

      // Flip hinge right
      final cmdHinge = SetArchitectElementProperties(
        storeyId: 'storey-1',
        elementIds: {'door-1'},
        textValues: {'isHingeLeft': 'false'},
      );
      final updated2 = cmdHinge.apply(project);
      final updatedDoor2 = updated2.activeStorey.walls.first.doors.first;
      expect(updatedDoor2.isHingeLeft, isFalse);
      expect(updatedDoor2.specId, equals('1'));
    });
  });

  group('ArchitectElementTool.flipElementById', () {
    test('flips window isFlipped', () {
      final tool = ArchitectElementTool();
      const win = ArchitectWindow(
        id: 'win-1',
        wallId: 'wall-1',
        offsetRatio: 0.5,
        uuid: 'UUID-WIN-1',
        isFlipped: false,
      );
      final wall = ArchitectWall(
        id: 'wall-1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        windows: const [win],
      );
      final storey = ArchitectStorey(
        id: 'storey-1',
        name: 'Storey 1',
        walls: [wall],
      );

      final flippedStorey = tool.flipElementById(storey, 'win-1');
      expect(flippedStorey.walls.first.windows.first.isFlipped, isTrue);

      final flippedBack = tool.flipElementById(flippedStorey, 'win-1');
      expect(flippedBack.walls.first.windows.first.isFlipped, isFalse);
    });

    test('flips door isHingeLeft', () {
      final tool = ArchitectElementTool();
      const door = ArchitectDoor(
        id: 'door-1',
        wallId: 'wall-1',
        offsetRatio: 0.5,
        uuid: 'UUID-DOOR-1',
        isHingeLeft: true,
      );
      final wall = ArchitectWall(
        id: 'wall-1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        doors: const [door],
      );
      final storey = ArchitectStorey(
        id: 'storey-1',
        name: 'Storey 1',
        walls: [wall],
      );

      final flippedStorey = tool.flipElementById(storey, 'door-1');
      expect(flippedStorey.walls.first.doors.first.isHingeLeft, isFalse);
    });
  });

  group('ArchitectElementPropertiesDialog for Window', () {
    testWidgets('renders window flip switch and toggling updates property', (tester) async {
      const win = ArchitectWindow(
        id: 'win-1',
        wallId: 'wall-1',
        offsetRatio: 0.5,
        uuid: 'UUID-WIN-1',
        isFlipped: false,
      );
      final wall = ArchitectWall(
        id: 'wall-1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        windows: const [win],
      );
      final now = DateTime.now();
      final project = ArchitectProject(
        id: 'proj-1',
        name: 'Test Project',
        createdAt: now,
        updatedAt: now,
        storeys: [
          ArchitectStorey(
            id: 'storey-1',
            name: 'Storey 1',
            walls: [wall],
          ),
        ],
        activeStoreyId: 'storey-1',
      );

      Map<String, String>? savedTexts;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArchitectElementPropertiesDialog(
              project: project,
              elementIds: const {'win-1'},
              onApply: (values, texts) {
                savedTexts = texts;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const ValueKey('architect-property-window-flip'));
      expect(switchFinder, findsOneWidget);

      final switchWidget = find.descendant(of: switchFinder, matching: find.byType(Switch));
      expect(switchWidget, findsOneWidget);

      await tester.tap(switchWidget);
      await tester.pumpAndSettle();

      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedTexts, isNotNull);
      expect(savedTexts!['isFlipped'], equals('true'));
    });
  });

  group('ArchitectWorkspaceScreen Door and Window Selection Bar', () {
    Architect2dPainter overlay(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((e) => e.painter)
        .whereType<Architect2dPainter>()
        .firstWhere((e) => e.layer == ArchitectPaintLayer.interaction);

    BimViewportController camera(WidgetTester tester) => overlay(tester).viewport!;

    Offset screen(WidgetTester tester, Offset point) =>
        tester.getTopLeft(find.byKey(const ValueKey('architect-viewport-input'))) +
        camera(tester).toScreen(point);

    testWidgets('Selecting a door shows door quick action buttons and toggles swing/hinge', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const door = ArchitectDoor(
        id: 'door-1',
        wallId: 'wall-1',
        offsetRatio: 0.5,
        width: 1.0,
        height: 2.0,
        isHingeLeft: true,
        openInward: true,
        uuid: 'UUID-DOOR-1',
      );
      final wall = ArchitectWall(
        id: 'wall-1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.25,
        doors: const [door],
      );
      final project = ArchitectProject(
        id: 'proj-1',
        name: 'Workspace Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 'storey-1',
        storeys: [
          ArchitectStorey(
            id: 'storey-1',
            name: 'Floor',
            walls: [wall],
          ),
        ],
      );

      final commands = ArchitectCommandController(project);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(
            commandController: commands,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select tool
      await tester.tap(find.byIcon(Icons.pan_tool_rounded));
      await tester.pump();

      // Tap on door at (3.0, 0.0)
      await tester.tapAt(screen(tester, const Offset(3.0, 0.0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify specialized door selection bar appears
      expect(find.byKey(const ValueKey('architect-selection-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-door-flip-swing')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-door-flip-hinge')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-selection-move')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-selection-properties')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-selection-delete')), findsOneWidget);

      // Tap flip swing
      await tester.tap(find.byKey(const ValueKey('architect-door-flip-swing')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final doorAfterSwing = commands.project.activeStorey.walls.first.doors.first;
      expect(doorAfterSwing.openInward, isFalse);

      // Tap flip hinge
      await tester.tap(find.byKey(const ValueKey('architect-door-flip-hinge')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final doorAfterHinge = commands.project.activeStorey.walls.first.doors.first;
      expect(doorAfterHinge.isHingeLeft, isFalse);
    });

    testWidgets('Selecting a window shows window flip button and toggles isFlipped', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const win = ArchitectWindow(
        id: 'win-1',
        wallId: 'wall-1',
        offsetRatio: 0.5,
        width: 1.2,
        height: 1.4,
        isFlipped: false,
        uuid: 'UUID-WIN-1',
      );
      final wall = ArchitectWall(
        id: 'wall-1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.25,
        windows: const [win],
      );
      final project = ArchitectProject(
        id: 'proj-1',
        name: 'Workspace Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 'storey-1',
        storeys: [
          ArchitectStorey(
            id: 'storey-1',
            name: 'Floor',
            walls: [wall],
          ),
        ],
      );

      final commands = ArchitectCommandController(project);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(
            commandController: commands,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select tool
      await tester.tap(find.byIcon(Icons.pan_tool_rounded));
      await tester.pump();

      // Tap on window at (3.0, 0.0)
      await tester.tapAt(screen(tester, const Offset(3.0, 0.0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify specialized window selection bar appears
      expect(find.byKey(const ValueKey('architect-selection-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-window-flip-side')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-selection-move')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-selection-properties')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-selection-delete')), findsOneWidget);

      // Tap flip side
      await tester.tap(find.byKey(const ValueKey('architect-window-flip-side')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final winAfterFlip = commands.project.activeStorey.walls.first.windows.first;
      expect(winAfterFlip.isFlipped, isTrue);
    });
  });
}
