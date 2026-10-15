import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_axis_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_grid_axis_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'package:kotoview/src/features/architect/widgets/architect_grid_axis_properties_card.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_manual_selection_test.dart' as selection;
import 'architect_workspace_interaction_test.dart' as workspace;

const selected = StructuralGridAxis(
  id: 'axis',
  name: 'A',
  start: Offset(-4, 1),
  end: Offset(4, 1),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Neighbors are nearest per side, ignoring reversed, coincident and crossing lines',
    () {
      const u = Offset(.6, .8), n = Offset(-.8, .6);
      final axis = selected.copyWith(start: -u * 4, end: u * 4);
      StructuralGridAxis parallel(String id, double d) =>
          axis.copyWith(id: id, start: u * 7 + n * d, end: -u * 7 + n * d);
      final axes = [
        axis,
        parallel('far', -8),
        parallel('left', -2),
        parallel('right', 3),
        parallel('far2', 4),
        parallel('same', 0),
        axis.copyWith(id: 'crossing', start: -n * 3, end: n * 3),
      ];
      final neighbors = ArchitectAxisGeometry.neighbors(axis, axes);
      expect(neighbors.map((e) => e.axis.id), ['left', 'right']);
      expect(neighbors[0].distance, closeTo(-2, 1e-8));
      expect(neighbors[1].distance, closeTo(3, 1e-8));
      expect(
        ArchitectAxisGeometry.neighbors(axis, [axis, parallel('only', 4)]),
        hasLength(1),
      );
      expect(ArchitectAxisGeometry.neighbors(axis, [axis]), isEmpty);
    },
  );

  for (final reference in WallReferenceLine.values) {
    test('Move snaps oblique axis to core for $reference wall reference', () {
      final wall = editing
          .wall(
            'wall',
            const Offset(-3, -4),
            const Offset(3, 4),
            exterior: true,
          )
          .copyWith(referenceLine: reference);
      final n = wall.normalVector, u = wall.unitVector;
      final axis = selected.copyWith(
        start: wall.coreCenterStart + n,
        end: wall.coreCenterEnd + n,
      );
      final result = ArchitectAxisGeometry.snapToWall(
        axis: axis,
        delta: -n * .94 + u * .3,
        walls: [wall],
        tolerance: .12,
      )!;
      final start = axis.start + result.delta;
      expect((start - wall.coreCenterStart - u * .3).distance, lessThan(1e-8));
      expect(result.guide, (wall.coreCenterStart, wall.coreCenterEnd));
      expect(
        ArchitectAxisGeometry.snapToWall(
          axis: axis,
          delta: -n * .8,
          walls: [wall],
          tolerance: .12,
        ),
        isNull,
      );
      expect(
        ArchitectAxisGeometry.snapToWall(
          axis: axis,
          delta: u * 30 - n * .94,
          walls: [wall],
          tolerance: .12,
        ),
        isNull,
      );
    });
  }

  test(
    'Axis tool previews and commits the wall snap; magnetic off preserves pointer delta',
    () {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [
            ArchitectWall(
              id: 'w',
              startPoint: Offset(-4, 0),
              endPoint: Offset(4, 0),
            ),
          ],
        ),
        axes: [selected],
      );
      addTearDown(model.dispose);
      final tool = ArchitectGridAxisTool();
      addTearDown(tool.dispose);
      tool.startMoving(selected, const Offset(0, 1));
      tool.updateMoving(
        const Offset(.3, .05),
        model.project.gridAxes,
        100,
        walls: model.project.activeStorey.walls,
      );
      expect(tool.previewAxes(model.project.gridAxes).single.start.dy, 0);
      expect(tool.moveWallGuide, isNotNull);
      model.commit(tool.commitMoving(model.project, false)!);
      expect(model.project.gridAxes.single.start.dy, 0);
      model.undo();
      expect(model.project.gridAxes.single.start, selected.start);
      tool.startMoving(selected, const Offset(0, 1));
      tool.updateMoving(
        const Offset(.3, .05),
        model.project.gridAxes,
        100,
        walls: model.project.activeStorey.walls,
        magnetic: false,
      );
      expect(
        tool.previewAxes(model.project.gridAxes).single.start.dy,
        closeTo(.05, 1e-8),
      );
      expect(tool.moveWallGuide, isNull);
    },
  );

  testWidgets(
    'Axis fan renames and rotates with Undo and no bottom menu or count',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: 'Floor'),
        axes: [selected],
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await selection.selectTool(tester);
      await workspace.wallTap(tester, const Offset(0, 1));
      expect(
        find.byKey(const ValueKey('architect-selection-context')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('architect-context-menu-btn')),
        findsNothing,
      );
      final card = find.byType(ArchitectGridAxisPropertiesCard);
      expect(
        find.descendant(of: card, matching: find.text('Rename')),
        findsNothing,
      );
      var menu = await selection.holdMenu(tester, const Offset(0, 1));
      expect(
        menu.items.map((i) => i.action),
        containsAll([
          ArchitectRadialAction.rename,
          ArchitectRadialAction.offset,
          ArchitectRadialAction.rotate,
        ]),
      );
      menu.onActionSelected(ArchitectRadialAction.rename);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('architect-axis-value')),
        'A-2',
      );
      await tester.tap(find.byKey(const ValueKey('architect-axis-value-save')));
      await tester.pumpAndSettle();
      expect(model.project.gridAxes.single.name, 'A-2');
      expect(model.undoCount, 1);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.gridAxes.single.name, 'A');
      menu = await selection.holdMenu(tester, const Offset(0, 1));
      menu.onActionSelected(ArchitectRadialAction.rotate);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('architect-axis-value'));
      await tester.enterText(field, 'NaN');
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('architect-axis-value-save')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(field, '37,5');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('architect-axis-value-save')));
      await tester.pumpAndSettle();
      final rotated = model.project.gridAxes.single;
      expect(rotated.angleRad * 180 / math.pi, closeTo(37.5, 1e-8));
      expect(rotated.length, closeTo(selected.length, 1e-8));
      expect((rotated.start + rotated.end) / 2, const Offset(0, 1));
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.gridAxes.single.start, selected.start);
      menu = await selection.holdMenu(tester, const Offset(0, 1));
      menu.onActionSelected(ArchitectRadialAction.offset);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final axisMode in [false, true]) {
    testWidgets(
      'Moving through ${axisMode ? 'Axes' : 'Select'} shows and commits the core snap',
      (tester) async {
        final model = editing.seeded(
          const ArchitectStorey(
            id: 's',
            name: 'Floor',
            walls: [
              ArchitectWall(
                id: 'w',
                startPoint: Offset(-4, 0),
                endPoint: Offset(4, 0),
              ),
            ],
          ),
          axes: [selected],
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        if (axisMode) {
          await editing.selectTool(tester, 'axis');
        } else {
          await selection.selectTool(tester);
        }
        await workspace.wallTap(tester, const Offset(0, 1));
        if (!axisMode) {
          final menu = await selection.holdMenu(tester, const Offset(0, 1));
          menu.onActionSelected(ArchitectRadialAction.move);
          await tester.pumpAndSettle();
        }
        final gesture = await tester.startGesture(
          workspace.screen(tester, const Offset(0, 1)),
        );
        if (axisMode) await tester.pump(const Duration(milliseconds: 300));
        await gesture.moveTo(workspace.screen(tester, const Offset(.2, .06)));
        await tester.pump();
        final preview = workspace.overlay(tester);
        expect(preview.project.gridAxes.single.start.dy, closeTo(0, 1e-8));
        expect(preview.magneticGuides, isNotEmpty);
        expect(preview.activeSnapLabel, 'Center');
        await gesture.up();
        await tester.pumpAndSettle();
        expect(model.project.gridAxes.single.start.dy, closeTo(0, 1e-8));
        expect(model.undoCount, 1);
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project.gridAxes.single.start, selected.start);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final language in ['bg', 'en']) {
    testWidgets('Phone $language axis readouts and six menu actions fit', (
      tester,
    ) async {
      final axes = [
        for (final entry in [('a', -3.0), ('b', 0.0), ('c', 2.0)])
          StructuralGridAxis(
            id: entry.$1,
            name: entry.$1.toUpperCase(),
            start: Offset(entry.$2, -4),
            end: Offset(entry.$2, 4),
          ),
      ];
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: 'Floor'),
        axes: axes,
      );
      addTearDown(model.dispose);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      final capture =
          Platform.environment['UPDATE_ARCHITECT_AXIS_PREVIEW'] == 'true';
      if (capture) {
        await tester.runAsync(() async {
          await (FontLoader('Roboto')..addFont(
                File(
                  'C:/Windows/Fonts/arial.ttf',
                ).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepaintBoundary(
            key: boundaryKey,
            child: ArchitectWorkspaceScreen(commandController: model),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await selection.selectTool(tester);
      await workspace.wallTap(tester, Offset.zero);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedAxisId, 'b');
      final neighbors = ArchitectAxisGeometry.neighbors(
        workspace.overlay(tester).project.gridAxes[1],
        workspace.overlay(tester).project.gridAxes,
      );
      expect(neighbors.map((e) => e.distance.abs()).toSet(), {2, 3});
      Future<void> captureImage(String name) async {
        if (!capture || language != 'bg') return;
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'docs/images/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await captureImage('architect_axis_distances_phone');
      final menu = await selection.holdMenu(tester, Offset.zero);
      expect(menu.items, hasLength(6));
      final badge = tester.getRect(
        find.byKey(const ValueKey('architect-radial-title')),
      );
      final rects = <Rect>[];
      for (final item in menu.items) {
        final button = tester.getRect(
          find.byKey(ValueKey('architect-radial-${item.action.name}')),
        );
        expect(button.left, greaterThanOrEqualTo(0));
        expect(button.right, lessThanOrEqualTo(360));
        expect(badge.overlaps(button), isFalse);
        expect(
          rects.any((r) => (r.center - button.center).distance < 52),
          isFalse,
        );
        rects.add(button);
      }
      await captureImage('architect_axis_menu_phone');
      expect(tester.takeException(), isNull);
    });
  }
}
