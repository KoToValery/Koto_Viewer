import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  testWidgets(
    'Straighten crooked wall aligns to nearest axis and updates connected walls',
    (tester) async {
      // Wall 'a' is crooked: (0, 0) -> (4, 0.2)
      // Wall 'b' is connected at (4, 0.2) -> (4, 4)
      final wallA = editing.wall('a', Offset.zero, const Offset(4, 0.2));
      final wallB = editing.wall('b', const Offset(4, 0.2), const Offset(4, 4));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', walls: [wallA, wallB]),
      );
      addTearDown(model.dispose);

      await workspace.open(tester, model);
      await tester.pumpAndSettle();
      await editing.selectTool(tester, 'wall');
      await tester.pumpAndSettle();

      // Select wall 'a' by holding near middle
      await editing.contextHold(tester, const Offset(2, 0.1));
      await tester.pumpAndSettle();

      // Straighten belongs to properties, not the floating or radial menus.
      expect(
        find.byKey(const ValueKey('architect-wall-straighten')),
        findsNothing,
      );
      await tester.tap(find.text('Properties'));
      await tester.pumpAndSettle();
      final straightenFinder = find.byKey(
        const ValueKey('architect-property-straighten'),
      );
      await tester.ensureVisible(straightenFinder);
      await tester.tap(straightenFinder);
      await tester.pumpAndSettle();

      // Check wall 'a' is straightened onto the horizontal axis (dy == 0) while preserving length
      final updatedA = model.project.activeStorey.walls.firstWhere(
        (w) => w.id == 'a',
      );
      expect(updatedA.startPoint, Offset.zero);
      expect(updatedA.endPoint.dy, closeTo(0.0, 1e-4));
      expect(updatedA.endPoint.dx, closeTo(wallA.length, 1e-4));

      // Check connected wall 'b' moved its start point to match wall 'a' exactly
      final updatedB = model.project.activeStorey.walls.firstWhere(
        (w) => w.id == 'b',
      );
      expect(updatedB.startPoint.dy, closeTo(0.0, 1e-4));
      expect(updatedB.startPoint.dx, closeTo(wallA.length, 1e-4));
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project.activeStorey.walls.first.endPoint, wallA.endPoint);
    },
  );

  testWidgets(
    'Dragging wall endpoint updates only that endpoint without moving whole wall',
    (tester) async {
      final wallA = editing.wall('w', Offset.zero, const Offset(4, 0));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', walls: [wallA]),
      );
      addTearDown(model.dispose);

      await workspace.open(tester, model);
      await tester.pumpAndSettle();
      await editing.selectTool(tester, 'wall');
      await tester.pumpAndSettle();

      // Select the wall
      await editing.hold(tester, const Offset(2, 0));
      await tester.pumpAndSettle();

      // Drag the endpoint at (4, 0) up to (4, 2)
      final endScreen = workspace.screen(tester, const Offset(4, 0));
      final gesture = await tester.startGesture(endScreen);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(workspace.screen(tester, const Offset(4, 2)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // The start point must remain at (0, 0), and only the endpoint moved!
      final updated = model.project.activeStorey.walls.firstWhere(
        (w) => w.id == 'w',
      );
      expect(updated.startPoint, Offset.zero);
      expect(updated.endPoint.dx, closeTo(4.0, 0.1));
      expect(updated.endPoint.dy, closeTo(2.0, 0.1));
    },
  );
}
