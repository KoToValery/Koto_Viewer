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
      id: 'p_cut_trim',
      name: 'Cut Trim Workspace',
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
  group('Architect Wall Cut / Trim Span Mechanics', () {
    testWidgets('Both Cut and Split buttons are present on selected wall', (
      tester,
    ) async {
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

      expect(find.byKey(const ValueKey('architect-wall-cut')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-wall-split')), findsOneWidget);
    });

    testWidgets('Cut trims protruding stub outside intersecting wall', (
      tester,
    ) async {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.25,
      );
      final w2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4, -3),
        endPoint: const Offset(4, 3),
        thickness: 0.25,
      );
      final model = seededController(walls: [w1, w2]);
      addTearDown(model.dispose);

      await openWorkspace(tester, model);
      await tool_ui.choose(tester, Icons.line_weight_rounded);
      await tester.pumpAndSettle();

      // Select w1
      await hold(tester, const Offset(2, 0));

      // Tap Cut button
      await tester.tap(find.byKey(const ValueKey('architect-wall-cut')));
      await tester.pumpAndSettle();

      // Banner should be visible
      expect(find.byKey(const ValueKey('architect-cut-banner')), findsOneWidget);

      // Tap on the protruding stub at (5, 0)
      await tester.tapAt(screen(tester, const Offset(5, 0)));
      await tester.pumpAndSettle();

      // Stub should be trimmed away, wall w1 should now end at (4, 0)
      final walls = model.project.activeStorey.walls;
      final trimmedW1 = walls.firstWhere((w) => w.id == 'w1');
      expect((trimmedW1.endPoint.dx - 4.0).abs(), lessThan(1e-3));
      expect(trimmedW1.length, closeTo(4.0, 1e-3));
      expect(find.byKey(const ValueKey('architect-cut-banner')), findsNothing);
    });

    testWidgets('Cut removes span between two crossing walls', (tester) async {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.25,
      );
      final w2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(3, -3),
        endPoint: const Offset(3, 3),
        thickness: 0.25,
      );
      final w3 = ArchitectWall(
        id: 'w3',
        startPoint: const Offset(7, -3),
        endPoint: const Offset(7, 3),
        thickness: 0.25,
      );
      final model = seededController(walls: [w1, w2, w3]);
      addTearDown(model.dispose);

      await openWorkspace(tester, model);
      await tool_ui.choose(tester, Icons.line_weight_rounded);
      await tester.pumpAndSettle();

      // Select w1
      await hold(tester, const Offset(1, 0));

      // Tap Cut button
      await tester.tap(find.byKey(const ValueKey('architect-wall-cut')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('architect-cut-banner')), findsOneWidget);

      // Tap on the middle segment at (5, 0) between x=3 and x=7
      await tester.tapAt(screen(tester, const Offset(5, 0)));
      await tester.pumpAndSettle();

      // The middle span should be cut out, leaving two walls from original w1: (0..3) and (7..10)
      final walls = model.project.activeStorey.walls;
      expect(walls.length, 4); // w1_a, w1_b, w2, w3
      final segA = walls.firstWhere((w) => w.id == 'w1');
      expect(segA.startPoint, const Offset(0, 0));
      expect(segA.endPoint.dx, closeTo(3.0, 1e-3));

      final otherSeg = walls.firstWhere((w) => w.id != 'w1' && w.id != 'w2' && w.id != 'w3');
      expect(otherSeg.startPoint.dx, closeTo(7.0, 1e-3));
      expect(otherSeg.endPoint, const Offset(10, 0));
    });

    testWidgets('Cut cancel button cancels cut mode without modifying walls', (
      tester,
    ) async {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.25,
      );
      final w2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4, -3),
        endPoint: const Offset(4, 3),
        thickness: 0.25,
      );
      final model = seededController(walls: [w1, w2]);
      addTearDown(model.dispose);

      await openWorkspace(tester, model);
      await tool_ui.choose(tester, Icons.line_weight_rounded);
      await tester.pumpAndSettle();

      await hold(tester, const Offset(2, 0));

      await tester.tap(find.byKey(const ValueKey('architect-wall-cut')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('architect-cut-banner')), findsOneWidget);

      // Tap cancel button on the banner
      await tester.tap(find.byKey(const ValueKey('architect-cut-cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('architect-cut-banner')), findsNothing);
      expect(model.project.activeStorey.walls.firstWhere((w) => w.id == 'w1').length, 6.0);
    });
  });
}
