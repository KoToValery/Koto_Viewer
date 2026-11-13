import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_arc_dimension_dialog.dart';
import 'architect_arc_dimension_ui_test.dart' as arc_ui;
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final language in ['bg', 'en']) {
    for (final curveControl in ['panel', 'toolbar', 'palette']) {
      testWidgets(
        'Straight-arc-straight chain preserves endpoints, hints and history ($language, $curveControl)',
        (tester) async {
          final model = editing.seeded(
            const ArchitectStorey(id: 's', name: ''),
          );
          addTearDown(model.dispose);
          await arc_ui.open(tester, model, language, const Size(390, 844));
          await editing.selectTool(tester, 'wall');
          await workspace.wallTap(tester, const Offset(-3, 0));
          await workspace.wallTap(tester, const Offset(-1, 0));
          await arc_ui.button(tester, 'wall-continue');
          final first = model.project.activeStorey.walls.single;
          await workspace.wallTap(tester, const Offset(2, 0));
          final chordEnd = workspace.overlay(tester).activeDraftEnd;
          if (curveControl == 'palette') {
            await arc_ui.button(tester, 'wall-drawing-mode');
            await arc_ui.button(tester, 'architect-wall-arc-mode');
          } else {
            await arc_ui.button(
              tester,
              curveControl == 'panel' ? 'wall-panel-curve' : 'wall-arc-toggle',
            );
          }
          expect(workspace.overlay(tester).activeDraftStart, first.endPoint);
          expect(workspace.overlay(tester).activeDraftEnd, chordEnd);
          expect(model.undoCount, 1);
          final l = AppLocalizations.of(
            tester.element(find.byType(ArchitectWorkspaceScreen)),
          )!;
          expect(find.text(l.wallArcPickEnd), findsNothing);
          expect(find.text(l.wallArcConfirmChord), findsOneWidget);
          await arc_ui.button(tester, 'wall-end');
          expect(find.text(l.wallArcPickThrough), findsOneWidget);
          await workspace.wallTap(tester, const Offset(.5, 1));
          await tester.pumpAndSettle();
          expect(find.byType(ArchitectWallArcDimensionDialog), findsOneWidget);
          await arc_ui.enter(tester, '.75');
          await arc_ui.button(tester, 'wall-arc-dimension-save');
          final arc = model.project.activeStorey.walls.last;
          expect(model.project.activeStorey.walls, hasLength(2));
          expect(arc.isCurved, isTrue);
          expect(arc.arc!.sagitta, closeTo(.75, 1e-8));
          expect(arc.startPoint, first.endPoint);
          expect(arc.endPoint, chordEnd);
          expect(workspace.overlay(tester).activeDraftStart, arc.endPoint);
          expect(workspace.overlay(tester).activeWallArcEnd, isNull);
          expect(model.undoCount, 2);
          await arc_ui.button(tester, 'wall-arc-toggle');
          expect(workspace.overlay(tester).activeDraftStart, arc.endPoint);
          await workspace.wallTap(tester, const Offset(2, 2));
          await arc_ui.button(tester, 'wall-end');
          final walls = model.project.activeStorey.walls;
          expect(walls, hasLength(3));
          expect(walls.last.isCurved, isFalse);
          expect(walls.last.startPoint, arc.endPoint);
          expect(workspace.overlay(tester).activeDraftStart, isNull);
          expect(model.undoCount, 3);
          final saved = model.project.toJson();
          final restored = ArchitectProject.fromJson(saved).activeStorey.walls;
          expect(restored[1].arcBulge, arc.arcBulge);
          expect(restored.last.startPoint, arc.endPoint);
          model.undo();
          expect(model.project.activeStorey.walls, hasLength(2));
          model.undo();
          expect(model.project.activeStorey.walls, hasLength(1));
          model.redo();
          model.redo();
          expect(model.project.toJson(), saved);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
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
          } else if (tool != 'wall') {
            await arc_ui.button(tester, 'wall-arc-toggle');
          }
          await workspace.wallTap(tester, const Offset(-2, 0));
          await workspace.wallTap(tester, const Offset(1, 0));
          await tester.pumpAndSettle();
          if (tool == 'wall') {
            await arc_ui.button(tester, 'wall-panel-curve');
          }
          expect(workspace.overlay(tester).activeWallArcEnd, isNull);
          expect(find.byType(EditableText), findsNothing);
          expect(find.byKey(const ValueKey('wall-key-0')), findsNothing);
          await arc_ui.button(tester, 'wall-length-input');
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
      final chordEnd = workspace.overlay(tester).activeWallArcEnd;
      await arc_ui.button(tester, 'wall-arc-toggle');
      expect(workspace.overlay(tester).activeWallArcEnd, isNull);
      expect(workspace.overlay(tester).activeDraftStart, const Offset(-2, 0));
      expect(workspace.overlay(tester).activeDraftEnd, chordEnd);
      expect(find.byKey(const ValueKey('wall-length-input')), findsOneWidget);
      await arc_ui.button(tester, 'wall-stop-drawing');
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
