import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_interaction_mode.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

const scene = ArchitectStorey(
  id: 's',
  name: '',
  walls: [
    ArchitectWall(
      id: 'first',
      startPoint: Offset(-3, 0),
      endPoint: Offset(0, 0),
      thickness: .18,
      height: 3.2,
      followStoreyHeight: false,
      baseOffset: .15,
    ),
    ArchitectWall(
      id: 'second',
      startPoint: Offset(1, 0),
      endPoint: Offset(4, 0),
    ),
  ],
  columns: [ArchitectColumn(id: 'column', position: Offset(2, 2))],
);

ArchitectToolPalette palette(WidgetTester tester) =>
    tester.widget(find.byType(ArchitectToolPalette));
Future<void> tap(WidgetTester tester, Offset point) async {
  await tester.tapAt(workspace.screen(tester, point));
  await tester.pumpAndSettle();
}

Future<void> command(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<ArchitectCommandController> open(WidgetTester tester) async {
  final model = editing.seeded(scene);
  addTearDown(model.dispose);
  await workspace.open(tester, model);
  workspace
      .camera(tester)
      .fit(const Rect.fromLTWH(-5, -3, 11, 9), padding: 180);
  await tester.pumpAndSettle();
  return model;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Navigation picks context, preserves category, and empty space returns to navigation',
    (tester) async {
      final model = await open(tester);
      expect(
        palette(tester).interactionMode,
        ArchitectInteractionMode.navigation,
      );
      expect(palette(tester).activeTool, ArchitectTool.pan);
      expect(
        find.byKey(const ValueKey('architect-selection-controls')),
        findsNothing,
      );
      await tap(tester, const Offset(-1.5, 0));
      expect(
        palette(tester).interactionMode,
        ArchitectInteractionMode.contextEdit,
      );
      expect(palette(tester).activeTool, ArchitectTool.wall);
      expect(
        find.byKey(const ValueKey('architect-tools-selection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-draw-selection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-select-similar')),
        findsNothing,
      );
      await tap(tester, const Offset(2, 2));
      expect(palette(tester).activeTool, ArchitectTool.column);
      expect(workspace.overlay(tester).selectedElementIds, {'column'});
      await tap(tester, const Offset(4, 4));
      expect(palette(tester).activeTool, ArchitectTool.pan);
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      expect(model.canUndo, isFalse);
    },
  );

  testWidgets(
    'Single selection stays manual and dragging never creates an area selection',
    (tester) async {
      final model = await open(tester);
      await command(tester, 'architect-tool-select');
      await tap(tester, const Offset(-1.5, 0));
      expect(palette(tester).activeTool, ArchitectTool.select);
      expect(
        palette(tester).interactionMode,
        ArchitectInteractionMode.singleSelect,
      );
      await tap(tester, const Offset(2, 2));
      expect(workspace.overlay(tester).selectedElementIds, {'column'});
      final before = workspace.camera(tester).translation;
      await tester.dragFrom(
        workspace.screen(tester, const Offset(-4, -2)),
        const Offset(60, 40),
      );
      await tester.pumpAndSettle();
      expect(
        workspace.camera(tester).translation,
        before + const Offset(60, 40),
      );
      expect(workspace.overlay(tester).marqueePoints, isEmpty);
      expect(palette(tester).activeTool, ArchitectTool.select);
      await command(tester, 'architect-tool-select');
      expect(palette(tester).activeTool, ArchitectTool.pan);
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      expect(model.canUndo, isFalse);
    },
  );

  testWidgets(
    'Multi alone accumulates picks; toggling it off clears selection',
    (tester) async {
      await open(tester);
      await tap(tester, const Offset(-1.5, 0));
      await command(tester, 'architect-multi-select');
      expect(workspace.overlay(tester).selectedElementIds, {'first'});
      await tap(tester, const Offset(2, 2));
      expect(
        palette(tester).interactionMode,
        ArchitectInteractionMode.multiSelect,
      );
      expect(palette(tester).activeTool, ArchitectTool.select);
      expect(workspace.overlay(tester).selectedElementIds, {'first', 'column'});
      expect(
        find.byKey(const ValueKey('architect-draw-selection')),
        findsNothing,
      );
      await command(tester, 'architect-tool-select');
      expect(
        palette(tester).interactionMode,
        ArchitectInteractionMode.singleSelect,
      );
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      await command(tester, 'architect-multi-select');
      expect(
        palette(tester).interactionMode,
        ArchitectInteractionMode.multiSelect,
      );
      await command(tester, 'architect-multi-select');
      expect(palette(tester).activeTool, ArchitectTool.pan);
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
    },
  );

  testWidgets(
    'Rapid repeated taps never select similar or connected elements',
    (tester) async {
      final model = await open(tester);
      for (final manual in [false, true]) {
        if (manual) await command(tester, 'architect-tool-select');
        for (var i = 0; i < 3; i++) {
          await tester.tapAt(workspace.screen(tester, const Offset(-1.5, 0)));
          await tester.pump(const Duration(milliseconds: 40));
          expect(workspace.overlay(tester).selectedElementIds, {'first'});
          expect(palette(tester).multiSelect, isFalse);
        }
      }
      await command(tester, 'architect-multi-select');
      await tap(tester, const Offset(2, 2));
      for (var i = 0; i < 2; i++) {
        await tester.tapAt(workspace.screen(tester, const Offset(-1.5, 0)));
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(workspace.overlay(tester).selectedElementIds, {'first', 'column'});
      expect(
        palette(tester).interactionMode,
        ArchitectInteractionMode.multiSelect,
      );
      expect(model.canUndo, isFalse);
    },
  );

  testWidgets(
    'Edit shortcut starts drawing with picked wall defaults in one undo transaction',
    (tester) async {
      final model = await open(tester);
      final original = model.project.activeStorey.walls.first;
      await tap(tester, const Offset(-1.5, 0));
      await command(tester, 'architect-draw-selection');
      expect(palette(tester).interactionMode, ArchitectInteractionMode.drawing);
      expect(palette(tester).wallThickness, .18);
      expect(
        find.byKey(const ValueKey('architect-tools-selection')),
        findsOneWidget,
      );
      expect(model.canUndo, isFalse);
      await tap(tester, const Offset(-2, 4));
      await tap(tester, const Offset(1, 4));
      await command(tester, 'wall-end');
      expect(model.project.activeStorey.walls, hasLength(3));
      final placed = model.project.activeStorey.walls.last;
      expect(placed.thickness, .18);
      expect(placed.height, 3.2);
      expect(placed.baseOffset, .15);
      expect(placed.followStoreyHeight, isFalse);
      expect(placed.id, isNot(original.id));
      expect(
        model.project.activeStorey.walls.first.toJson(),
        original.toJson(),
      );
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls, hasLength(2));
      expect(model.canUndo, isFalse);
      await command(tester, 'architect-draw-selection');
      expect(palette(tester).activeTool, ArchitectTool.pan);
    },
  );

  testWidgets(
    'Edit controls are absent from other categories and returning keeps the picked type',
    (tester) async {
      await open(tester);
      await tools.prepare(tester, Icons.line_weight_rounded);
      expect(find.byKey(const ValueKey('architect-tool-pan')), findsNothing);
      expect(
        find.byKey(const ValueKey('architect-multi-select')),
        findsNothing,
      );
      await tap(tester, const Offset(-1.5, 0));
      expect(
        find.byKey(const ValueKey('architect-tools-build')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-draw-selection')),
        findsNothing,
      );
      await tools.prepare(tester, Icons.near_me_outlined);
      expect(
        find.byKey(const ValueKey('architect-draw-selection')),
        findsOneWidget,
      );
    },
  );

  for (final locale in ['en', 'bg']) {
    for (final brightness in Brightness.values) {
      testWidgets('Phone Edit layout $locale ${brightness.name}', (
        tester,
      ) async {
        final model = editing.seeded(scene);
        addTearDown(model.dispose);
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await (FontLoader('Roboto')
                ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('navigation-capture'),
            child: MaterialApp(
              locale: Locale(locale),
              theme: ThemeData(brightness: brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        workspace
            .camera(tester)
            .fit(const Rect.fromLTWH(-4, -2, 9, 8), padding: 40);
        await tester.pumpAndSettle();
        await tap(tester, const Offset(-1.5, 0));
        await tester.ensureVisible(
          find.byKey(const ValueKey('architect-draw-selection')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final toolBounds = tester.getRect(
          find.byKey(const ValueKey('architect-tools-selection')),
        );
        for (final key in [
          'architect-tool-pan',
          'architect-tool-select',
          'architect-multi-select',
          'architect-draw-selection',
        ]) {
          final bounds = tester.getRect(find.byKey(ValueKey(key)));
          expect(bounds.left, greaterThanOrEqualTo(toolBounds.left));
          expect(bounds.right, lessThanOrEqualTo(toolBounds.right));
        }
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('navigation-capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '.dart_tool/navigation-edit-$locale-${brightness.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
