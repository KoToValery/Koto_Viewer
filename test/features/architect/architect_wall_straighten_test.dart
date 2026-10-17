import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  testWidgets('Straighten crooked wall aligns to nearest axis and updates connected walls', (tester) async {
    // Wall 'a' is crooked: (0, 0) -> (4, 0.2)
    // Wall 'b' is connected at (4, 0.2) -> (4, 4)
    final wallA = editing.wall('a', Offset.zero, const Offset(4, 0.2));
    final wallB = editing.wall('b', const Offset(4, 0.2), const Offset(4, 4));
    final model = editing.seeded(
      ArchitectStorey(
        id: 's',
        name: 'Floor',
        walls: [wallA, wallB],
      ),
    );
    addTearDown(model.dispose);

    await workspace.open(tester, model);
    await tester.pumpAndSettle();
    await editing.selectTool(tester, 'wall');
    await tester.pumpAndSettle();

    // Select wall 'a' by holding near middle
    await editing.hold(tester, const Offset(2, 0.1));
    await tester.pumpAndSettle();

    // Straighten button should be present in the wall selection actions
    final straightenFinder = find.byKey(const ValueKey('architect-wall-straighten'));
    expect(straightenFinder, findsOneWidget);

    // Tap straighten button
    await tester.tap(straightenFinder);
    await tester.pumpAndSettle();

    // Check wall 'a' is straightened onto the horizontal axis (dy == 0) while preserving length
    final updatedA = model.project.activeStorey.walls.firstWhere((w) => w.id == 'a');
    expect(updatedA.startPoint, Offset.zero);
    expect(updatedA.endPoint.dy, closeTo(0.0, 1e-4));
    expect(updatedA.endPoint.dx, closeTo(wallA.length, 1e-4));

    // Check connected wall 'b' moved its start point to match wall 'a' exactly
    final updatedB = model.project.activeStorey.walls.firstWhere((w) => w.id == 'b');
    expect(updatedB.startPoint.dy, closeTo(0.0, 1e-4));
    expect(updatedB.startPoint.dx, closeTo(wallA.length, 1e-4));
  });

  testWidgets('Dragging wall endpoint updates only that endpoint without moving whole wall', (tester) async {
    final wallA = editing.wall('w', Offset.zero, const Offset(4, 0));
    final model = editing.seeded(
      ArchitectStorey(
        id: 's',
        name: 'Floor',
        walls: [wallA],
      ),
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
    final updated = model.project.activeStorey.walls.firstWhere((w) => w.id == 'w');
    expect(updated.startPoint, Offset.zero);
    expect(updated.endPoint.dx, closeTo(4.0, 0.1));
    expect(updated.endPoint.dy, closeTo(2.0, 0.1));
  });
}
