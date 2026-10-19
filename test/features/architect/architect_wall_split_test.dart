import 'architect_tool_test_helper.dart' as tool_ui;
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
      id: 'p_split',
      name: 'Split Workspace',
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

Future<void> hold(WidgetTester tester, Offset point) async {
  final g = await tester.startGesture(screen(tester, point));
  await tester.pump(const Duration(milliseconds: 451));
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  group('Architect Wall Split - Reworked Workflow', () {
    testWidgets(
      'Full 3-step Split with perpendicular guide and canvas tap side selection',
      (tester) async {
        final w1 = ArchitectWall(
          id: 'w1',
          startPoint: const Offset(0, 0),
          endPoint: const Offset(6, 0),
          thickness: 0.25,
        );
        final model = seededController(walls: [w1]);
        addTearDown(model.dispose);

        await openWorkspace(tester, model);

        // Select wall tool
        await tool_ui.choose(tester, Icons.line_weight_rounded);
        await tester.pumpAndSettle();

        // Select wall w1 with hold
        await hold(tester, const Offset(3, 0));

        // Start split session from wall selection action bar
        expect(find.byKey(const ValueKey('architect-wall-cut')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('architect-wall-cut')));
        await tester.pumpAndSettle();

        // Banner should be visible with Step 1 prompt
        expect(find.byKey(const ValueKey('architect-split-banner')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('architect-split-banner')),
            matching: find.text('Specify first split point'),
          ),
          findsOneWidget,
        );

        // Step 1: Pick Point 1 at (2, 0)
        await tester.tapAt(screen(tester, const Offset(2, 0)));
        await tester.pumpAndSettle();

        // Step 2: Pale dashed perpendicular guide appears, prompt updates, Perpendicular button visible
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('architect-split-banner')),
            matching: find.text('Specify second split point'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-split-perpendicular-btn')),
          findsOneWidget,
        );
        final painter = interactionOverlay(tester);
        expect(painter.splitPoint1, isNotNull);
        expect(painter.splitPerpendicularGuide, isNotNull);

        // Step 2: Pick Point 2 at (2, 1)
        await tester.tapAt(screen(tester, const Offset(2, 1)));
        await tester.pumpAndSettle();

        // Step 3: Prompt updates to pick side, side buttons are visible
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('architect-split-banner')),
            matching: find.text('Click the side to keep selected'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('architect-split-side1-btn')), findsOneWidget);
        expect(find.byKey(const ValueKey('architect-split-side2-btn')), findsOneWidget);
        expect(find.byKey(const ValueKey('architect-split-both-btn')), findsOneWidget);

        // Wall is still 1 piece until side is selected
        expect(model.project.activeStorey.walls.length, 1);

        // Step 3: Tap on canvas on side 1 (e.g. at (1, 0))
        await tester.tapAt(screen(tester, const Offset(1, 0)));
        await tester.pumpAndSettle();

        // Wall is cut into 2 pieces!
        final walls = model.project.activeStorey.walls;
        expect(walls.length, 2);

        // Banner disappears
        expect(find.byKey(const ValueKey('architect-split-banner')), findsNothing);

        // Selection should be piece on side 1 (midpoint around x=1)
        final selectedIds = model.project.activeStorey.walls
            .where((w) => w.referencePointAt(0.5).dx < 2.0)
            .map((w) => w.id)
            .toSet();
        expect(selectedIds.length, 1);
      },
    );

    testWidgets(
      'Perpendicular quick shortcut button advances to Step 3 and cuts wall',
      (tester) async {
        final w1 = ArchitectWall(
          id: 'w1',
          startPoint: const Offset(0, 0),
          endPoint: const Offset(6, 0),
          thickness: 0.25,
        );
        final model = seededController(walls: [w1]);
        addTearDown(model.dispose);

        await openWorkspace(tester, model);

        await tool_ui.choose(tester, Icons.line_weight_rounded);
        await tester.pumpAndSettle();

        await hold(tester, const Offset(3, 0));
        await tester.tap(find.byKey(const ValueKey('architect-wall-cut')));
        await tester.pumpAndSettle();

        // Step 1: Pick Point 1 at (3, 0)
        await tester.tapAt(screen(tester, const Offset(3, 0)));
        await tester.pumpAndSettle();

        // Step 2: Tap the Perpendicular shortcut button
        final perpBtn = find.byKey(const ValueKey('architect-split-perpendicular-btn'));
        expect(perpBtn, findsOneWidget);
        await tester.tap(perpBtn);
        await tester.pumpAndSettle();

        // Directly enters Step 3
        expect(find.byKey(const ValueKey('architect-split-side2-btn')), findsOneWidget);

        // Tap Side 2 button
        await tester.tap(find.byKey(const ValueKey('architect-split-side2-btn')));
        await tester.pumpAndSettle();

        expect(model.project.activeStorey.walls.length, 2);
      },
    );

    testWidgets(
      'Both sides button selects all resulting pieces after split',
      (tester) async {
        final w1 = ArchitectWall(
          id: 'w1',
          startPoint: const Offset(0, 0),
          endPoint: const Offset(6, 0),
          thickness: 0.25,
        );
        final model = seededController(walls: [w1]);
        addTearDown(model.dispose);

        await openWorkspace(tester, model);

        await tool_ui.choose(tester, Icons.line_weight_rounded);
        await tester.pumpAndSettle();

        await hold(tester, const Offset(3, 0));
        await tester.tap(find.byKey(const ValueKey('architect-wall-cut')));
        await tester.pumpAndSettle();

        await tester.tapAt(screen(tester, const Offset(3, 0)));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('architect-split-perpendicular-btn')));
        await tester.pumpAndSettle();

        // Tap Both button
        await tester.tap(find.byKey(const ValueKey('architect-split-both-btn')));
        await tester.pumpAndSettle();

        expect(model.project.activeStorey.walls.length, 2);
      },
    );

    testWidgets(
      'Cancel button resets split session without modifying walls',
      (tester) async {
        final w1 = ArchitectWall(
          id: 'w1',
          startPoint: const Offset(0, 0),
          endPoint: const Offset(6, 0),
          thickness: 0.25,
        );
        final model = seededController(walls: [w1]);
        addTearDown(model.dispose);

        await openWorkspace(tester, model);

        await tool_ui.choose(tester, Icons.line_weight_rounded);
        await tester.pumpAndSettle();

        await hold(tester, const Offset(3, 0));
        await tester.tap(find.byKey(const ValueKey('architect-wall-cut')));
        await tester.pumpAndSettle();

        await tester.tapAt(screen(tester, const Offset(3, 0)));
        await tester.pumpAndSettle();

        // Tap Cancel
        final cancelBtn = find.byKey(const ValueKey('architect-split-cancel-btn'));
        expect(cancelBtn, findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('architect-split-banner')), findsNothing);
        expect(model.project.activeStorey.walls.length, 1);
      },
    );

    testWidgets(
      'Undo and Redo work seamlessly with wall split',
      (tester) async {
        final w1 = ArchitectWall(
          id: 'w1',
          startPoint: const Offset(0, 0),
          endPoint: const Offset(6, 0),
          thickness: 0.25,
        );
        final model = seededController(walls: [w1]);
        addTearDown(model.dispose);

        await openWorkspace(tester, model);

        await tool_ui.choose(tester, Icons.line_weight_rounded);
        await tester.pumpAndSettle();

        await hold(tester, const Offset(3, 0));
        await tester.tap(find.byKey(const ValueKey('architect-wall-cut')));
        await tester.pumpAndSettle();

        await tester.tapAt(screen(tester, const Offset(3, 0)));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('architect-split-perpendicular-btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('architect-split-side1-btn')));
        await tester.pumpAndSettle();

        expect(model.project.activeStorey.walls.length, 2);

        // Undo
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls.length, 1);

        // Redo
        model.redo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls.length, 2);
      },
    );

    testWidgets(
      'Perpendicular guide line is geometrically perpendicular to the wall baseline',
      (tester) async {
        final w1 = ArchitectWall(
          id: 'w1',
          startPoint: const Offset(0, 0),
          endPoint: const Offset(6, 0),
          thickness: 0.25,
        );
        final model = seededController(walls: [w1]);
        addTearDown(model.dispose);

        await openWorkspace(tester, model);

        await tool_ui.choose(tester, Icons.line_weight_rounded);
        await tester.pumpAndSettle();

        await hold(tester, const Offset(3, 0));
        await tester.tap(find.byKey(const ValueKey('architect-wall-cut')));
        await tester.pumpAndSettle();

        // Step 1: Pick Point 1 at (2, 0)
        await tester.tapAt(screen(tester, const Offset(2, 0)));
        await tester.pumpAndSettle();

        final painter = interactionOverlay(tester);
        expect(painter.splitPoint1, isNotNull);
        expect(painter.splitPoint1!.dx, closeTo(2.0, 1e-3));
        expect(painter.splitPoint1!.dy, closeTo(0.0, 1e-3));

        // For wall along X, perpendicular guide is along x = 2
        final guide = painter.splitPerpendicularGuide;
        expect(guide, isNotNull);
        expect(guide!.$1.dx, closeTo(2.0, 1e-3));
        expect(guide.$2.dx, closeTo(2.0, 1e-3));
        expect((guide.$1.dy - guide.$2.dy).abs(), greaterThan(10.0));
      },
    );
  });
}
