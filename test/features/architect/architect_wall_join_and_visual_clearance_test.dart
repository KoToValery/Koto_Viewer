import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_manual_selection_test.dart' as selection;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Wall Join UI and Interactive Mode', () {
    testWidgets(
      'Single wall selected -> Join button enters interactive mode -> tap second wall joins them',
      (tester) async {
        final walls = [
          editing.wall('w1', const Offset(0, 0), const Offset(5, 0)),
          editing.wall('w2', const Offset(5, 1), const Offset(5, 6)),
        ];
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: 'Floor', walls: walls),
        );
        addTearDown(model.dispose);

        await workspace.open(tester, model);
        await selection.selectTool(tester);

        // Select w1
        await workspace.wallTap(tester, const Offset(2.5, 0));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementIds, {'w1'});

        // Tap Join button in floating bar
        final joinButton = find.byKey(const ValueKey('architect-wall-join'));
        expect(joinButton, findsOneWidget);
        await tester.tap(joinButton);
        await tester.pumpAndSettle();

        // Interactive banner should be displayed
        expect(find.byKey(const ValueKey('architect-wall-join-banner')), findsOneWidget);

        // Tap second wall w2
        await workspace.wallTap(tester, const Offset(5, 3));
        await tester.pumpAndSettle();

        // Walls should now be joined at (5, 0)
        final storey = model.project.activeStorey;
        final joinedW1 = storey.walls.firstWhere((w) => w.id == 'w1');
        final joinedW2 = storey.walls.firstWhere((w) => w.id == 'w2');
        expect(joinedW1.endPoint, const Offset(5, 0));
        expect(joinedW2.startPoint, const Offset(5, 0));

        // Interactive banner should be gone
        expect(find.byKey(const ValueKey('architect-wall-join-banner')), findsNothing);
      },
    );

    testWidgets(
      'Interactive Join banner cancel button dismisses join mode',
      (tester) async {
        final walls = [
          editing.wall('w1', const Offset(0, 0), const Offset(5, 0)),
          editing.wall('w2', const Offset(5, 1), const Offset(5, 6)),
        ];
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: 'Floor', walls: walls),
        );
        addTearDown(model.dispose);

        await workspace.open(tester, model);
        await selection.selectTool(tester);

        // Select w1
        await workspace.wallTap(tester, const Offset(2.5, 0));
        await tester.pumpAndSettle();

        // Tap Join
        final joinButton = find.byKey(const ValueKey('architect-wall-join'));
        await tester.tap(joinButton);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('architect-wall-join-banner')), findsOneWidget);

        // Tap close (X) icon in banner
        await tester.tap(find.byKey(const ValueKey('architect-wall-join-cancel')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('architect-wall-join-banner')), findsNothing);
      },
    );

    testWidgets(
      'Two walls selected -> Join button directly joins both walls',
      (tester) async {
        final walls = [
          editing.wall('w1', const Offset(0, 0), const Offset(4, 0)),
          editing.wall('w2', const Offset(5, 1), const Offset(5, 5)),
        ];
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: 'Floor', walls: walls),
        );
        addTearDown(model.dispose);

        await workspace.open(tester, model);
        await selection.selectTool(tester);

        // Select both walls
        await workspace.wallTap(tester, const Offset(2, 0));
        await workspace.wallTap(tester, const Offset(5, 3));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementIds, {'w1', 'w2'});

        // Tap Join
        final joinButton = find.byKey(const ValueKey('architect-wall-join'));
        await tester.tap(joinButton);
        await tester.pumpAndSettle();

        // Joined immediately at intersection (5, 0)
        final storey = model.project.activeStorey;
        final joinedW1 = storey.walls.firstWhere((w) => w.id == 'w1');
        final joinedW2 = storey.walls.firstWhere((w) => w.id == 'w2');
        expect(joinedW1.endPoint, const Offset(5, 0));
        expect(joinedW2.startPoint, const Offset(5, 0));
      },
    );
  });

  group('Visual Corner Edge Clearance', () {
    test('Calculates clearance at inner/outer visual edges rather than centerline', () {
      // Support wall 'b' along y = 0 from x = 0 to 10 with thickness 0.5 (faces at y = -0.25 and y = +0.25)
      // Slanted wall 'a' from (2, 0) to (4, 4) with thickness 0.5 extending upwards (y >= 0)
      // Neighbor wall 'd' along x = 10 from y = -1 to 5 with thickness 0.5 (inner face at x = 9.75)
      final wallA = ArchitectWall(id: 'a', startPoint: const Offset(2, 0), endPoint: const Offset(4, 4), thickness: 0.5);
      final wallB = ArchitectWall(id: 'b', startPoint: const Offset(0, 0), endPoint: const Offset(10, 0), thickness: 0.5);
      final wallD = ArchitectWall(id: 'd', startPoint: const Offset(10, -1), endPoint: const Offset(10, 5), thickness: 0.5);
      final storeyWalls = <ArchitectWall>[wallA, wallB, wallD];

      final gaps = ArchitectWallClearance.endpoints(wallA, storeyWalls);
      expect(gaps, isNotEmpty);
      final gapStart = gaps.firstWhere((g) => g.atStart == true);

      // Support inner face is at y = 0.25.
      // Slanted wall 'a' direction is (2, 4) normalized = (1, 2) / sqrt(5).
      // Centerline meets y = 0 at (2, 0), and at y = 0.25 at x = 2 + 0.25 * (2/4) = 2.125.
      // The visual corner of wall 'a' on face y = 0.25 facing wall 'd' (to the right):
      // The right finished face of wall 'a' intersects the support face y = 0.25.
      // Since normal of wall 'a' pointing right/down has normal.dy < 0,
      // the face towards 'd' (x > 2) is offset along support x-axis.
      // Therefore gap.start.dx must NOT be the centerline startPoint.dx (2.0)!
      expect(gapStart.start.dx, isNot(closeTo(2.0, 1e-4)));
      // gap.end.dx should match wall 'd' visual inner face (x = 9.75), not centerline (10.0)!
      expect(gapStart.end.dx, closeTo(9.75, 1e-4));
      // gap.distance is the true visual clearance along the support face
      expect(gapStart.distance, closeTo(gapStart.end.dx - gapStart.start.dx, 1e-4));
    });
  });

  group('Drafting Scale & Auxiliary Indicators', () {
    test('Drafting scale prevents dynamic enlargement of auxiliary indicators when zooming out', () {
      final project = editing.seeded(ArchitectStorey(id: 's', name: 'Floor')).project;
      final painterAt100 = Architect2dPainter(
        project: project,
        activeTool: ArchitectTool.select,
        zoomScale: 100.0,
      );
      final painterAt40 = Architect2dPainter(
        project: project,
        activeTool: ArchitectTool.select,
        zoomScale: 40.0,
      );
      final painterAt10 = Architect2dPainter(
        project: project,
        activeTool: ArchitectTool.select,
        zoomScale: 10.0,
      );

      // At zoom >= minDraftingScale (80.0), scale follows zoomScale
      expect(painterAt100.draftingScale, 100.0);

      // When zooming out below minDraftingScale, draftingScale is clamped to minDraftingScale
      // so model-space dimensions of dots and indicators NEVER blow up
      expect(painterAt40.draftingScale, Architect2dPainter.minDraftingScale);
      expect(painterAt10.draftingScale, Architect2dPainter.minDraftingScale);

      // Orange dot radius at zoomScale = 10 must NOT blow up to 7 / 10 = 0.70m!
      // It must be capped at 7 / 80 = 0.0875m
      const baseDotRadius = 7.0;
      final worldRadiusAt10 = baseDotRadius / painterAt10.draftingScale;
      expect(worldRadiusAt10, closeTo(0.0875, 1e-4));
      expect(worldRadiusAt10, isNot(closeTo(0.70, 1e-2)));
    });
  });

  group('Wall Extend Tool Behavior', () {
    test('ExtendArchitectWall modifies only the selected wall and keeps perpendicularly connected walls fixed', () {
      // Main wall w1 from (0,0) to (10,0)
      // Perpendicular T-junction wall w2 from (5,0) to (5,5)
      // Perpendicular end-connected wall w3 from (10,0) to (10,5)
      final w1 = editing.wall('w1', const Offset(0, 0), const Offset(10, 0));
      final w2 = editing.wall('w2', const Offset(5, 0), const Offset(5, 5));
      final w3 = editing.wall('w3', const Offset(10, 0), const Offset(10, 5));

      final storey = ArchitectStorey(id: 's', name: 'Floor', walls: [w1, w2, w3]);
      final model = editing.seeded(storey);
      addTearDown(model.dispose);

      // Extend w1 from (10,0) to (15,0)
      model.execute(
        const ExtendArchitectWall(
          storeyId: 's',
          wallId: 'w1',
          target: Offset(15, 0),
        ),
      );

      final updatedStorey = model.project.activeStorey;
      final updatedW1 = updatedStorey.walls.firstWhere((w) => w.id == 'w1');
      final updatedW2 = updatedStorey.walls.firstWhere((w) => w.id == 'w2');
      final updatedW3 = updatedStorey.walls.firstWhere((w) => w.id == 'w3');

      // w1 endPoint extended to (15, 0)
      expect(updatedW1.startPoint, const Offset(0, 0));
      expect(updatedW1.endPoint, const Offset(15, 0));

      // w2 (perpendicular wall hitting w1 at (5,0)) MUST NOT be moved or dragged
      expect(updatedW2.startPoint, const Offset(5, 0));
      expect(updatedW2.endPoint, const Offset(5, 5));

      // w3 (perpendicular wall meeting w1 at original end (10,0)) MUST NOT be dragged
      expect(updatedW3.startPoint, const Offset(10, 0));
      expect(updatedW3.endPoint, const Offset(10, 5));
    });

    test('ExtendArchitectWall at start point does not drag perpendicularly connected walls', () {
      final w1 = editing.wall('w1', const Offset(0, 0), const Offset(10, 0));
      final w2 = editing.wall('w2', const Offset(5, 0), const Offset(5, 5));

      final storey = ArchitectStorey(id: 's', name: 'Floor', walls: [w1, w2]);
      final model = editing.seeded(storey);
      addTearDown(model.dispose);

      // Extend w1 at start to (-5, 0)
      model.execute(
        const ExtendArchitectWall(
          storeyId: 's',
          wallId: 'w1',
          target: Offset(-5, 0),
        ),
      );

      final updatedStorey = model.project.activeStorey;
      final updatedW1 = updatedStorey.walls.firstWhere((w) => w.id == 'w1');
      final updatedW2 = updatedStorey.walls.firstWhere((w) => w.id == 'w2');

      expect(updatedW1.startPoint, const Offset(-5, 0));
      expect(updatedW1.endPoint, const Offset(10, 0));

      // w2 remains anchored at (5, 0)
      expect(updatedW2.startPoint, const Offset(5, 0));
      expect(updatedW2.endPoint, const Offset(5, 5));
    });

    testWidgets(
      'Interactive Extend tool extends selected wall to target without dragging perpendicular wall',
      (tester) async {
        final w1 = editing.wall('w1', const Offset(0, 0), const Offset(2, 0));
        final w2 = editing.wall('w2', const Offset(1, 0), const Offset(1, 2));
        final targetWall = editing.wall('wTarget', const Offset(3, -2), const Offset(3, 2));

        final storey = ArchitectStorey(id: 's', name: 'Floor', walls: [w1, w2, targetWall]);
        final model = editing.seeded(storey);
        addTearDown(model.dispose);

        await workspace.open(tester, model);
        await selection.selectTool(tester);

        // Select w1
        await workspace.wallTap(tester, const Offset(0.5, 0));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementIds, {'w1'});

        // Tap more actions -> extend
        await tester.tap(find.byKey(const ValueKey('architect-wall-actions')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-extend')));
        await tester.pumpAndSettle();

        // Tap on targetWall at (3, 1) to extend w1 to it
        await tester.tapAt(workspace.screen(tester, const Offset(3, 1)));
        await tester.pumpAndSettle();

        final updatedStorey = model.project.activeStorey;
        final updatedW1 = updatedStorey.walls.firstWhere((w) => w.id == 'w1');
        final updatedW2 = updatedStorey.walls.firstWhere((w) => w.id == 'w2');

        // w1 extended to intersection with targetWall at (3, 0)
        expect(updatedW1.endPoint, const Offset(3, 0));
        // Perpendicular wall w2 at (1, 0) must remain fixed and NOT be pulled
        expect(updatedW2.startPoint, const Offset(1, 0));
        expect(updatedW2.endPoint, const Offset(1, 2));
      },
    );
  });

  group('Floating Quick Menu - Wall Reference Line Choice', () {
    testWidgets(
      'Wall selection displays reference line selector in floating actions and changes wall reference line',
      (tester) async {
        final w1 = editing.wall('w1', const Offset(0, 0), const Offset(4, 0))
            .copyWith(referenceLine: WallReferenceLine.center);

        final storey = ArchitectStorey(id: 's', name: 'Floor', walls: [w1]);
        final model = editing.seeded(storey);
        addTearDown(model.dispose);

        await workspace.open(tester, model);
        await selection.selectTool(tester);

        // Select w1
        await workspace.wallTap(tester, const Offset(2, 0));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementIds, {'w1'});

        // Floating quick menu must contain the reference line selector
        final refSelector = find.byKey(const ValueKey('architect-wall-reference-line'));
        expect(refSelector, findsOneWidget);

        // Initially shows "Axis" (English)
        expect(find.descendant(of: refSelector, matching: find.text('Axis')), findsOneWidget);

        // Tap the selector to open popup menu
        await tester.tap(refSelector);
        await tester.pumpAndSettle();

        // Check options are displayed
        expect(find.byKey(const ValueKey('architect-wall-ref-center')), findsOneWidget);
        expect(find.byKey(const ValueKey('architect-wall-ref-inner')), findsOneWidget);
        expect(find.byKey(const ValueKey('architect-wall-ref-outer')), findsOneWidget);

        // Select "Outside" (WallReferenceLine.outer)
        await tester.tap(find.byKey(const ValueKey('architect-wall-ref-outer')));
        await tester.pumpAndSettle();

        // Wall reference line should now be outer
        var wall = model.project.activeStorey.walls.firstWhere((w) => w.id == 'w1');
        expect(wall.referenceLine, WallReferenceLine.outer);
        expect(find.descendant(of: refSelector, matching: find.text('Outside')), findsOneWidget);

        // Tap again and select "Inside" (WallReferenceLine.inner)
        await tester.tap(refSelector);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('architect-wall-ref-inner')));
        await tester.pumpAndSettle();

        wall = model.project.activeStorey.walls.firstWhere((w) => w.id == 'w1');
        expect(wall.referenceLine, WallReferenceLine.inner);
        expect(find.descendant(of: refSelector, matching: find.text('Inside')), findsOneWidget);
      },
    );
  });
}
