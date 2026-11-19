import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/widgets/architect_polygon_distance_overlay.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_polygon_editor_test.dart' as keypad;
import 'architect_polygon_exact_offset_test.dart' as grips;
import 'architect_roof_drainage_test.dart' as fixture;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  testWidgets(
    'the exact wall-to-eaves dimension applies with one confirmation',
    (tester) async {
      final project = fixture.drainageProject().copyWith(
        units: ArchitectUnit.centimeters,
      );
      final model = ArchitectCommandController(project);
      addTearDown(model.dispose);
      final roof = model.project.activeStorey.roofs.single;
      await workspace.open(tester, model);
      await workspace.wallTap(tester, roof.centroid);
      await tester.pumpAndSettle();

      final overlay = tester.widget<ArchitectPolygonDistanceOverlay>(
        find.byType(ArchitectPolygonDistanceOverlay),
      );
      final dimension = overlay.dimensions.singleWhere(
        (d) => d.referenceId == 'facade' && d.side == -1,
      );
      final before = model.project;
      await tester.tap(
        find.byKey(ValueKey('polygon-distance-${dimension.key}')),
      );
      await tester.pumpAndSettle();
      await keypad.enter(tester, '160');
      expect(model.project, same(before));
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();

      final edited = model.project.activeStorey.roofs.single;
      expect(edited.eavesOverhang, closeTo(1.6, 1e-9));
      expect(
        edited.eavesEdge.$1.dy,
        closeTo(roof.eavesEdge.$1.dy - (1.6 - dimension.distance), 1e-9),
      );
      expect(find.byKey(const ValueKey('shape-save')), findsNothing);
      expect(
        find.byKey(const ValueKey('architect-command-apply')),
        findsNothing,
      );
      expect(model.canUndo, isTrue);
      model.undo();
      expect(model.project.activeStorey.roofs.single.points, roof.points);
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('automatic hipped eaves open the exact keypad after a drag', (
    tester,
  ) async {
    const perimeter = [
      Offset(0, 0),
      Offset(10, 0),
      Offset(10, 6),
      Offset(0, 6),
    ];
    final base = fixture.drainageProject();
    final ground = base.activeStorey.copyWith(
      roofs: [],
      walls: [
        for (var i = 0; i < perimeter.length; i++)
          ArchitectWall(
            id: 'wall-$i',
            startPoint: perimeter[i],
            endPoint: perimeter[(i + 1) % perimeter.length],
          ),
      ],
    );
    final withRoofStorey = base
        .copyWith(storeys: [ground], units: ArchitectUnit.centimeters)
        .ensureRoofStorey();
    final roofPlan = withRoofStorey.copyWith(
      activeStoreyId: withRoofStorey.roofStorey!.id,
    );
    final generated = ArchitectRoofGeometry.generateAutoRoof(
      project: roofPlan,
      type: AutoRoofType.hip,
    );
    expect(generated.length, greaterThan(2));
    final model = ArchitectCommandController(
      roofPlan.updateActiveStorey(
        roofPlan.activeStorey.copyWith(roofs: generated),
      ),
    );
    addTearDown(model.dispose);
    final roof = model.project.activeStorey.roofs.first;
    await workspace.open(tester, model);
    await editing.ensureSelectionTool(tester);
    await workspace.wallTap(tester, roof.centroid);
    await tester.pumpAndSettle();
    expect(workspace.overlay(tester).selectedElementId, roof.id);
    final before = model.project;
    final edge = roof.safeEavesEdgeIndex;
    final grip = (roof.eavesEdge.$1 + roof.eavesEdge.$2) / 2;
    final outward = ArchitectPolygonGeometry.normal(roof.points, edge);
    final numeric = find.byKey(const ValueKey('polygon-displacement-keypad'));
    final screenGrip = workspace.screen(tester, grip);
    final viewport = tester.getRect(
      find.byKey(const ValueKey('architect-viewport-input')),
    );
    expect(
      viewport.contains(screenGrip),
      isTrue,
      reason: '$screenGrip in $viewport',
    );

    await grips.drag(tester, grip, grip + outward * .4);
    expect(numeric, findsOneWidget);
    await keypad.enter(tester, '1000');
    await tester.tap(find.byKey(const ValueKey('shape-sign')));
    await tester.pumpAndSettle();
    expect(
      find.text('This size would make the roof outline invalid.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('shape-save')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('shape-cancel')));
    await tester.pumpAndSettle();
    expect(model.project, same(before));
    expect(model.canUndo, isFalse);

    await grips.drag(tester, grip, grip + outward * .4);
    expect(numeric, findsOneWidget);
    await keypad.enter(tester, '25.5');
    expect(model.project, same(before));
    await tester.tap(find.byKey(const ValueKey('shape-save')));
    await tester.pumpAndSettle();

    final edited = model.project.activeStorey.roofs.first;
    expect(edited.roofGroupId, roof.roofGroupId);
    expect(
      ArchitectPolygonGeometry.dot(
        edited.eavesEdge.$1 - roof.eavesEdge.$1,
        outward,
      ),
      closeTo(.255, 1e-8),
    );
    expect(numeric, findsNothing);
    expect(find.byKey(const ValueKey('architect-command-apply')), findsNothing);
    expect(model.canUndo, isTrue);
    model.undo();
    expect(model.project.activeStorey.roofs.first.points, roof.points);
    expect(model.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });
}
