import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';

import 'architect_tool_test_helper.dart' as tool_ui;

ArchitectCommandController seededController({List<ArchitectWall> walls = const []}) {
  return ArchitectCommandController(
    ArchitectProject(
      id: 'p_openings',
      name: 'Openings Workspace',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      storeys: [
        ArchitectStorey(
          id: 's',
          name: 'Floor 1',
          walls: walls,
        ),
      ],
    ),
  );
}

Future<void> openWorkspace(
  WidgetTester tester,
  ArchitectCommandController commands,
) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
  await tester.pumpAndSettle();
}

Architect2dPainter interactionOverlay(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((e) => e.painter)
    .whereType<Architect2dPainter>()
    .firstWhere((e) => e.layer == ArchitectPaintLayer.interaction);

BimViewportController camera(WidgetTester tester) =>
    interactionOverlay(tester).viewport!;

Offset screen(WidgetTester tester, Offset point) =>
    tester.getTopLeft(find.byKey(const ValueKey('architect-viewport-input'))) +
    camera(tester).toScreen(point);

int doorCount(ArchitectCommandController model) =>
    model.project.activeStorey.walls.expand((w) => w.doors).length;

int windowCount(ArchitectCommandController model) =>
    model.project.activeStorey.walls.expand((w) => w.windows).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArchitectOpeningPlacement duplicate and overlap algorithms', () {
    test('detects when point or candidate overlaps existing doors and windows', () {
      final wall = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.25,
        doors: [
          ArchitectDoor(
            id: 'd1',
            wallId: 'w1',
            offsetRatio: 0.30, // center at 3.0m, width 1.0m -> [2.5, 3.5]
            width: 1.0,
            uuid: 'd1',
          ),
        ],
        windows: [
          ArchitectWindow(
            id: 'w_win1',
            wallId: 'w1',
            offsetRatio: 0.70, // center at 7.0m, width 1.2m -> [6.4, 7.6]
            width: 1.2,
            uuid: 'w_win1',
          ),
        ],
      );

      // Points inside door [2.5, 3.5]
      expect(
        ArchitectOpeningPlacement.isPointInsideExistingOpening(wall: wall, along: 3.0),
        isTrue,
      );
      expect(
        ArchitectOpeningPlacement.isPointInsideExistingOpening(wall: wall, along: 2.52),
        isTrue,
      );

      // Points inside window [6.4, 7.6]
      expect(
        ArchitectOpeningPlacement.isPointInsideExistingOpening(wall: wall, along: 7.0),
        isTrue,
      );
      expect(
        ArchitectOpeningPlacement.isPointInsideExistingOpening(wall: wall, along: 6.5),
        isTrue,
      );

      // Free points
      expect(
        ArchitectOpeningPlacement.isPointInsideExistingOpening(wall: wall, along: 1.0),
        isFalse,
      );
      expect(
        ArchitectOpeningPlacement.isPointInsideExistingOpening(wall: wall, along: 5.0),
        isFalse,
      );

      // Overlapping candidate placement
      expect(
        ArchitectOpeningPlacement.doesOpeningOverlapExisting(
          wall: wall,
          candidateAlong: 3.0,
          openingWidth: 0.90,
        ),
        isTrue,
      );
      expect(
        ArchitectOpeningPlacement.doesOpeningOverlapExisting(
          wall: wall,
          candidateAlong: 3.8, // [3.35, 4.25] overlaps [2.5, 3.5]
          openingWidth: 0.90,
        ),
        isTrue,
      );
      expect(
        ArchitectOpeningPlacement.doesOpeningOverlapExisting(
          wall: wall,
          candidateAlong: 5.0, // [4.55, 5.45] cleanly between [3.5] and [6.4]
          openingWidth: 0.90,
        ),
        isFalse,
      );

      // Overall blocked check:
      // Tapping at 3.0 directly on door
      expect(
        ArchitectOpeningPlacement.isPlacementBlockedOrOverlapping(
          wall: wall,
          candidateAlong: 5.0,
          rawAlong: 3.0,
          openingWidth: 0.90,
        ),
        isTrue,
      );

      // Clamped too far away (> 0.75 * width = 0.675m)
      expect(
        ArchitectOpeningPlacement.isPlacementBlockedOrOverlapping(
          wall: wall,
          candidateAlong: 5.0,
          rawAlong: 4.0, // diff 1.0m > 0.675m
          openingWidth: 0.90,
        ),
        isTrue,
      );

      // Clean placement at 5.0m
      expect(
        ArchitectOpeningPlacement.isPlacementBlockedOrOverlapping(
          wall: wall,
          candidateAlong: 5.0,
          rawAlong: 5.05,
          openingWidth: 0.90,
        ),
        isFalse,
      );
    });
  });

  group('Continuous Door & Window Placement with Cooldown in Workspace', () {
    testWidgets('Door tool remains active after placement, enforces 1.5s cooldown, and prevents duplicates', (tester) async {
      final wall = ArchitectWall(
        id: 'w_main',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.25,
      );
      final model = seededController(walls: [wall]);
      addTearDown(model.dispose);

      await openWorkspace(tester, model);

      // Select Door tool
      await tool_ui.choose(tester, Icons.meeting_room_rounded);
      await tester.pumpAndSettle();

      // Tap at (2.0, 0.0) to place first door
      await tester.tapAt(screen(tester, const Offset(2.0, 0.0)));
      await tester.pump();

      // Verify first door placed
      expect(doorCount(model), 1);

      // Attempt immediate second tap during cooldown at (5.0, 0.0) -> must be ignored!
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(screen(tester, const Offset(5.0, 0.0)));
      await tester.pump();
      expect(doorCount(model), 1);

      // Fast forward past cooldown (1500 ms)
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      // Tool should STILL be active without having to re-select it!
      // Tap at (5.0, 0.0) to place second door
      await tester.tapAt(screen(tester, const Offset(5.0, 0.0)));
      await tester.pump();
      expect(doorCount(model), 2);

      // Fast forward past cooldown
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Duplicate prevention: tapping directly at (2.0, 0.0) on top of the first door
      await tester.tapAt(screen(tester, const Offset(2.0, 0.0)));
      await tester.pump();
      // Should NOT place a duplicate door
      expect(doorCount(model), 2);
    });

    testWidgets('Window tool remains active after placement and enforces cooldown', (tester) async {
      final wall = ArchitectWall(
        id: 'w_main',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.25,
      );
      final model = seededController(walls: [wall]);
      addTearDown(model.dispose);

      await openWorkspace(tester, model);

      // Select Window tool
      await tool_ui.choose(tester, Icons.window_rounded);
      await tester.pumpAndSettle();

      // Tap at (3.0, 0.0) to place first window
      await tester.tapAt(screen(tester, const Offset(3.0, 0.0)));
      await tester.pump();

      // Verify first window placed
      expect(windowCount(model), 1);

      // Immediate tap during cooldown at (7.0, 0.0) -> must be ignored!
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(screen(tester, const Offset(7.0, 0.0)));
      await tester.pump();
      expect(windowCount(model), 1);

      // Fast forward past cooldown
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      // Place second window without having to re-select window tool
      await tester.tapAt(screen(tester, const Offset(7.0, 0.0)));
      await tester.pump();
      expect(windowCount(model), 2);

      // Fast forward past cooldown
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Duplicate prevention: tapping on existing window at (3.0, 0.0)
      await tester.tapAt(screen(tester, const Offset(3.0, 0.0)));
      await tester.pump();
      expect(windowCount(model), 2);
    });
  });
}
