import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/widgets/architect_curving_edge_overlay.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_arc_dimension_dialog.dart';
import 'architect_arc_dimension_ui_test.dart' as arc_ui;
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final kind in ['wall', 'line', 'polyline', 'slab']) {
    testWidgets('$kind: exact h first, choose side, final Apply commits once', (
      tester,
    ) async {
      final wall = editing.wall(
        'edit',
        const Offset(-2, 0),
        const Offset(2, 0),
      );
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: '',
          walls: kind == 'wall' ? [wall] : [],
          cadPrimitives: kind == 'line' || kind == 'polyline'
              ? [
                  ArchitectCadPrimitive(
                    id: 'edit',
                    type: kind == 'line'
                        ? CadPrimitiveType.line
                        : CadPrimitiveType.polyline,
                    startPoint: wall.startPoint,
                    endPoint: wall.endPoint,
                    polygon: kind == 'polyline'
                        ? [wall.startPoint, wall.endPoint]
                        : null,
                  ),
                ]
              : [],
          slabs: kind == 'slab'
              ? [
                  ArchitectSlab(
                    id: 'edit',
                    polygon: const [
                      Offset(-2, 0),
                      Offset(2, 0),
                      Offset(2, -2),
                      Offset(-2, -2),
                    ],
                  ),
                ]
              : [],
        ),
      );
      addTearDown(model.dispose);
      await arc_ui.open(tester, model, 'bg', const Size(390, 844));
      await tester.tapAt(workspace.screen(tester, Offset.zero));
      await tester.pumpAndSettle();
      await tools.selectionAction(tester, switch (kind) {
        'wall' => 'wall-curve',
        'line' => 'architect-line-curve',
        'polyline' => 'architect-poly-curve',
        _ => 'architect-contour-curve',
      });
      expect(find.byType(ArchitectWallArcDimensionDialog), findsOneWidget);
      final before = model.project.toJson();
      expect(model.undoCount, 0);
      await arc_ui.enter(tester, '0.75');
      expect(model.project.toJson(), before);
      await arc_ui.button(tester, 'wall-arc-dimension-save');
      expect(find.byType(ArchitectWallArcDimensionDialog), findsNothing);
      expect(
        find.byKey(const ValueKey('architect-command-apply')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-command-cancel')),
        findsOneWidget,
      );
      expect(model.project.toJson(), before);
      final overlay = tester.widget<ArchitectCurvingEdgeOverlay>(
        find.byType(ArchitectCurvingEdgeOverlay),
      );
      expect(overlay.distanceText, model.project.formatLength(.75));
      final origin = tester.getTopLeft(
        find.byKey(const ValueKey('architect-viewport-input')),
      );
      final offset = overlay.gripPos - overlay.handlePos;
      final target =
          overlay.chordMid - (overlay.handlePos - overlay.chordMid) * 3;
      final camera = workspace.camera(tester);
      final translation = camera.translation;
      final drag = await tester.startGesture(origin + overlay.gripPos);
      await tester.pump();
      expect(
        tester
            .widget<ArchitectCurvingEdgeOverlay>(
              find.byType(ArchitectCurvingEdgeOverlay),
            )
            .pendingConfirmation,
        isFalse,
        reason:
            'Grip must own the gesture at ${origin + overlay.gripPos}; target=${origin + target + offset}',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await drag.moveTo(origin + target + offset);
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      final placed = tester.widget<ArchitectCurvingEdgeOverlay>(
        find.byType(ArchitectCurvingEdgeOverlay),
      );
      expect(placed.distanceText, model.project.formatLength(.75));
      expect(
        (placed.handlePos - placed.chordMid).dy *
            (overlay.handlePos - overlay.chordMid).dy,
        lessThan(0),
      );
      expect(camera.translation, translation);
      expect(find.byType(ArchitectWallArcDimensionDialog), findsNothing);
      expect(model.project.toJson(), before);
      await arc_ui.button(tester, 'architect-command-apply');
      expect(model.undoCount, 1);
      expect(find.byType(ArchitectCurvingEdgeOverlay), findsNothing);
      final after = model.project.toJson();
      expect(after, isNot(before));
      if (kind == 'wall') {
        expect(
          model.project.activeStorey.walls.single.arc!.sagitta,
          closeTo(.75, 1e-8),
        );
      } else if (kind == 'line') {
        expect(
          model.project.activeStorey.cadPrimitives.single.arc!.sagitta,
          closeTo(.75, 1e-8),
        );
      } else if (kind == 'polyline') {
        expect(
          model.project.activeStorey.cadPrimitives.single.bulges!.first.abs(),
          closeTo(.375, 1e-8),
        );
      } else {
        expect(
          model.project.activeStorey.slabs.single.bulges!.first.abs(),
          closeTo(.375, 1e-8),
        );
      }
      model.undo();
      expect(model.project.toJson(), before);
      model.redo();
      expect(model.project.toJson(), after);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Zero rise straightens an existing wall only after final Apply', (
    tester,
  ) async {
    final model = editing.seeded(
      const ArchitectStorey(id: 's', name: '', walls: [arc_ui.arc]),
    );
    addTearDown(model.dispose);
    await arc_ui.open(tester, model, 'bg', const Size(360, 800));
    await tester.tapAt(workspace.screen(tester, arc_ui.arc.centerPointAt(.5)));
    await tester.pumpAndSettle();
    await tools.selectionAction(tester, 'wall-curve');
    await arc_ui.enter(tester, '0');
    await arc_ui.button(tester, 'wall-arc-dimension-save');
    expect(model.project.activeStorey.walls.single.isCurved, isTrue);
    expect(model.undoCount, 0);
    await arc_ui.button(tester, 'architect-command-apply');
    expect(model.project.activeStorey.walls.single.isCurved, isFalse);
    expect(model.undoCount, 1);
    model.undo();
    expect(
      model.project.activeStorey.walls.single.arcBulge,
      arc_ui.arc.arcBulge,
    );
    expect(tester.takeException(), isNull);
  });

  for (final cancelStage in ['input', 'review']) {
    testWidgets(
      'Cancel at $cancelStage restores the existing curve without undo',
      (tester) async {
        final model = editing.seeded(
          const ArchitectStorey(id: 's', name: '', walls: [arc_ui.arc]),
        );
        addTearDown(model.dispose);
        await arc_ui.open(tester, model, 'en', const Size(360, 800));
        await tester.tapAt(
          workspace.screen(tester, arc_ui.arc.centerPointAt(.5)),
        );
        await tester.pumpAndSettle();
        await tools.selectionAction(tester, 'wall-curve');
        final before = model.project.toJson();
        await arc_ui.enter(tester, '0');
        expect(model.project.toJson(), before);
        if (cancelStage == 'review') {
          await arc_ui.button(tester, 'wall-arc-dimension-save');
          final preview = tester.widget<ArchitectCurvingEdgeOverlay>(
            find.byType(ArchitectCurvingEdgeOverlay),
          );
          expect(preview.isCurved, isFalse);
          await arc_ui.button(tester, 'architect-command-cancel');
        } else {
          await arc_ui.button(tester, 'wall-arc-dimension-cancel');
        }
        expect(find.byType(ArchitectCurvingEdgeOverlay), findsNothing);
        expect(model.project.toJson(), before);
        expect(model.undoCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
