import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';

ArchitectCommandController seededController({List<ArchitectWall> walls = const []}) {
  return ArchitectCommandController(
    ArchitectProject(
      id: 'p',
      name: 'Workspace',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      storeys: [
        ArchitectStorey(
          id: 's',
          name: 'Floor',
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

Architect2dPainter overlay(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((e) => e.painter)
    .whereType<Architect2dPainter>()
    .firstWhere((e) => e.layer == ArchitectPaintLayer.interaction);

BimViewportController camera(WidgetTester tester) => overlay(tester).viewport!;

Offset screen(WidgetTester tester, Offset point) =>
    tester.getTopLeft(find.byKey(const ValueKey('architect-viewport-input'))) +
    camera(tester).toScreen(point);

Future<void> hold(WidgetTester tester, Offset point) async {
  final g = await tester.startGesture(screen(tester, point));
  await tester.pump(const Duration(milliseconds: 451));
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  group('Selection, Undo/Redo, and Cutting mechanics', () {
    testWidgets('Undo and Redo show visible arrows without counters', (
      tester,
    ) async {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final model = seededController(walls: [w1]);
      addTearDown(model.dispose);
      await openWorkspace(tester, model);

      final undo = find.byKey(const ValueKey('architect-undo'));
      final redo = find.byKey(const ValueKey('architect-redo'));
      for (final button in [undo, redo]) {
        expect(
          find.descendant(of: button, matching: find.byType(Badge)),
          findsNothing,
        );
        final widget = tester.widget<IconButton>(button);
        expect(widget.onPressed, isNull);
        expect(widget.color, Colors.white);
        expect(widget.disabledColor, Colors.white38);
      }
      expect(
        find.descendant(of: undo, matching: find.byIcon(Icons.undo)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: redo, matching: find.byIcon(Icons.redo)),
        findsOneWidget,
      );

      model.execute(
        const SplitArchitectWall(
          storeyId: 's',
          wallId: 'w1',
          newWallId: 'w1_b',
          ratio: 0.5,
        ),
      );
      await tester.pump();
      expect(tester.widget<IconButton>(undo).onPressed, isNotNull);
      expect(
        find.descendant(of: undo, matching: find.byType(Text)),
        findsNothing,
      );
      await tester.tap(undo);
      await tester.pump();
      expect(model.project.activeStorey.walls, hasLength(1));
      expect(tester.widget<IconButton>(redo).onPressed, isNotNull);
      await tester.tap(redo);
      await tester.pump();
      expect(model.project.activeStorey.walls, hasLength(2));
      expect(
        find.descendant(of: redo, matching: find.byType(Text)),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('architect-deselect')), findsOneWidget);
    });

    testWidgets('Deselect button and empty space tap clear selection', (
      tester,
    ) async {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final model = seededController(walls: [w1]);
      addTearDown(model.dispose);

      await openWorkspace(tester, model);

      // Select wall tool
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();

      // Hold on wall to select it
      await hold(tester, const Offset(2, 0));

      // Selection bar is visible
      expect(find.byKey(const ValueKey('architect-clear-selection')), findsOneWidget);

      // Tap the always-visible deselect button
      final deselectFinder = find.byKey(const ValueKey('architect-deselect'));
      await tester.tap(deselectFinder);
      await tester.pumpAndSettle();

      // Selection bar is now gone
      expect(find.byKey(const ValueKey('architect-clear-selection')), findsNothing);

      // Select wall again with hold
      await hold(tester, const Offset(2, 0));
      expect(find.byKey(const ValueKey('architect-clear-selection')), findsOneWidget);

      // Tap in empty space (e.g. at (2, -0.5))
      final tapPos = screen(tester, const Offset(2, -0.5));
      await tester.tapAt(tapPos);
      await tester.pumpAndSettle();

      // Selection is cleared!
      expect(find.byKey(const ValueKey('architect-clear-selection')), findsNothing);
    });

    testWidgets('Tapping on wall in cut mode splits the wall directly at that point', (tester) async {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final model = seededController(walls: [w1]);
      addTearDown(model.dispose);

      await openWorkspace(tester, model);

      // Select wall tool
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();

      // Select wall w1 with hold
      await hold(tester, const Offset(2, 0));

      // Open wall actions popup menu and select Split tool
      await tester.tap(find.byKey(const ValueKey('architect-wall-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-split-stroke')));
      await tester.pumpAndSettle();

      // Click 1 confirms the surface on wall w1 at (1, 0)
      await tester.tapAt(screen(tester, const Offset(1, 0)));
      await tester.pumpAndSettle();

      // Wall is not yet split after click 1 (waiting for cut direction)
      expect(model.project.activeStorey.walls.length, 1);

      // Click 2 sets cut direction (perpendicular cut across the wall towards (1, 1))
      await tester.tapAt(screen(tester, const Offset(1, 1)));
      await tester.pumpAndSettle();

      // Wall is split into 2 walls!
      expect(model.project.activeStorey.walls.length, 2);
    });
  });
}
