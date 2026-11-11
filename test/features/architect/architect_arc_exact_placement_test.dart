import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_arc_dimension_dialog.dart';
import 'architect_arc_dimension_ui_test.dart' as arc_ui;
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final tool in ['wall', 'line', 'arc', 'polyline']) {
    for (final rise in ['0', '0.75']) {
      testWidgets(
        '$tool: exact chord then exact rise $rise, one undo on phone',
        (tester) async {
          final model = editing.seeded(
            const ArchitectStorey(id: 's', name: ''),
          );
          addTearDown(model.dispose);
          await arc_ui.open(tester, model, 'bg', const Size(360, 800));
          await editing.selectTool(tester, tool == 'wall' ? 'wall' : 'CAD');
          if (tool == 'arc') {
            final arcTool = find.byKey(const ValueKey('architect-tool-cadArc'));
            await tester.ensureVisible(arcTool);
            await tester.tap(arcTool);
            await tester.pumpAndSettle();
          } else if (tool == 'polyline') {
            await arc_ui.button(tester, 'architect-line-mode-polyline');
            await arc_ui.button(tester, 'architect-polyline-arc-mode');
          } else {
            await arc_ui.button(tester, 'wall-arc-toggle');
          }
          await workspace.wallTap(tester, const Offset(-2, 0));
          await workspace.wallTap(tester, const Offset(1, 0));
          await tester.pumpAndSettle();
          expect(workspace.overlay(tester).activeWallArcEnd, isNull);
          expect(find.byType(EditableText), findsNothing);
          expect(find.byKey(const ValueKey('wall-key-0')), findsOneWidget);
          for (final key in [
            'wall-length-input',
            'wall-key-0',
            'wall-end',
            'wall-cancel',
          ]) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(360));
            expect(rect.bottom, lessThanOrEqualTo(800));
            expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
          }
          await arc_ui.button(tester, 'wall-key-4');
          expect(model.undoCount, 0);
          await arc_ui.button(tester, 'wall-end');
          expect(
            workspace.overlay(tester).activeWallArcEnd,
            const Offset(2, 0),
          );
          await workspace.wallTap(tester, const Offset(0, 1));
          await tester.pumpAndSettle();
          expect(find.byType(ArchitectWallArcDimensionDialog), findsOneWidget);
          expect(model.undoCount, 0);
          await arc_ui.enter(tester, rise);
          expect(tester.takeException(), isNull);
          await arc_ui.button(tester, 'wall-arc-dimension-save');
          final storey = model.project.activeStorey;
          final ArchitectWallArc shape;
          if (tool == 'wall') {
            final wall = storey.walls.single;
            shape = ArchitectWallArc(
              wall.startPoint,
              wall.endPoint,
              wall.arcBulge,
            );
            expect(wall.isCurved, rise != '0');
          } else {
            final line = storey.cadPrimitives.single;
            if (tool == 'polyline') {
              shape = ArchitectWallArc(
                line.linePoints[0],
                line.linePoints[1],
                line.bulges!.single,
              );
            } else {
              shape = ArchitectWallArc(
                line.startPoint,
                line.endPoint,
                line.arcBulge ?? 0,
              );
              if (rise == '0') expect(line.type, CadPrimitiveType.line);
            }
          }
          expect(shape.chordLength, closeTo(4, 1e-8));
          expect(shape.sagitta, closeTo(double.parse(rise), 1e-8));
          expect(model.undoCount, 1);
          final saved = model.project.toJson();
          model.undo();
          expect(model.project.activeStorey.walls, isEmpty);
          expect(model.project.activeStorey.cadPrimitives, isEmpty);
          model.redo();
          expect(model.project.toJson(), saved);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Existing curved wall straightens with 0 and restores with undo',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: '',
          walls: [arc_ui.arc, arc_ui.neighbor],
        ),
      );
      addTearDown(model.dispose);
      await arc_ui.open(tester, model, 'bg', const Size(360, 800));
      await tester.tapAt(
        workspace.screen(tester, arc_ui.arc.centerPointAt(.5)),
      );
      await tester.pumpAndSettle();
      await arc_ui.button(tester, 'wall-arc-dimension-badge');
      await arc_ui.enter(tester, '0');
      await arc_ui.button(tester, 'wall-arc-dimension-save');
      await editing.acceptGeometryCommand(tester);
      expect(model.project.activeStorey.walls.first.isCurved, isFalse);
      expect(
        model.project.activeStorey.walls.first.startPoint,
        arc_ui.arc.startPoint,
      );
      expect(
        model.project.activeStorey.walls.first.endPoint,
        arc_ui.arc.endPoint,
      );
      expect(model.undoCount, 1);
      model.undo();
      expect(
        model.project.activeStorey.walls.first.arcBulge,
        arc_ui.arc.arcBulge,
      );
      model.redo();
      expect(model.project.activeStorey.walls.first.arcBulge, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Exact rise cancel preserves the draft; shaping drag locks pan and hold menus',
    (tester) async {
      final model = editing.seeded(const ArchitectStorey(id: 's', name: ''));
      addTearDown(model.dispose);
      await arc_ui.open(tester, model, 'en', const Size(390, 844));
      await editing.selectTool(tester, 'wall');
      await arc_ui.button(tester, 'wall-arc-toggle');
      await workspace.wallTap(tester, const Offset(-2, 0));
      await workspace.wallTap(tester, const Offset(2, 0));
      await arc_ui.button(tester, 'wall-end');
      final camera = workspace.camera(tester);
      final translation = camera.translation;
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(0, .6)),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 800));
      await gesture.moveTo(workspace.screen(tester, const Offset(.4, 1.2)));
      await tester.pump();
      expect(camera.translation, translation);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectWallArcDimensionDialog), findsOneWidget);
      await arc_ui.enter(tester, '0');
      await arc_ui.button(tester, 'wall-arc-dimension-cancel');
      expect(model.undoCount, 0);
      expect(workspace.overlay(tester).activeWallArcEnd, isNotNull);
      await arc_ui.button(tester, 'wall-stop-drawing');
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
