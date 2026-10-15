import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
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
}
