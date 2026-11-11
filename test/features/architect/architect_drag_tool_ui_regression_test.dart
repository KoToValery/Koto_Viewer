import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_floating_command_overlay.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

const _columnId = 'drag-column';
const _columnPosition = Offset(3, 5);
const _captureKey = ValueKey('drag-visual-capture');
const _dragSurface = ValueKey('architect-drag-command-overlay');
const _genericSurface = ValueKey('architect-generic-command-overlay');

ArchitectCommandController _dragModel({bool wall = false}) {
  final source = workspace.commands();
  final model = ArchitectCommandController(
    source.project.copyWith(
      storeys: [
        ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: wall
              ? const [
                  ArchitectWall(
                    id: 'wall',
                    startPoint: Offset(-2, 0),
                    endPoint: Offset(2, 0),
                  ),
                  ArchitectWall(
                    id: 'left',
                    startPoint: Offset(-2, 0),
                    endPoint: Offset(-2, 3),
                  ),
                  ArchitectWall(
                    id: 'right',
                    startPoint: Offset(2, 0),
                    endPoint: Offset(2, 3),
                  ),
                ]
              : const [],
          columns: wall
              ? const []
              : const [
                  ArchitectColumn(id: _columnId, position: _columnPosition),
                  ArchitectColumn(
                    id: 'reference-column',
                    position: Offset(-1, -1),
                  ),
                ],
        ),
      ],
    ),
  );
  source.dispose();
  return model;
}

Future<void> _openPhone(
  WidgetTester tester,
  ArchitectCommandController model,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (Platform.environment['UPDATE_ARCHITECT_DRAG_PREVIEW'] == 'true') {
    await tester.runAsync(() async {
      for (final family in ['Roboto', 'ArchitectNoto']) {
        await (FontLoader(family)
              ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
            .load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
  }
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectCompactInBounds(WidgetTester tester) {
  expect(find.byType(ArchitectFloatingCommandOverlay), findsOneWidget);
  expect(find.byKey(_genericSurface), findsNothing);
  final overlay = find.byKey(_dragSurface);
  expect(overlay, findsOneWidget);
  final rect = tester.getRect(overlay);
  final canvas = tester.getRect(
    find.byKey(const ValueKey('architect-viewport-input')),
  );
  expect(rect.width, lessThanOrEqualTo(132));
  expect(canvas.contains(rect.topLeft), isTrue);
  expect(canvas.contains(rect.bottomRight), isTrue);
  expect(find.byType(ArchitectToolPalette), findsNothing);
  expect(find.byKey(const ValueKey('architect-selection-bar')), findsNothing);
  expect(find.byKey(const ValueKey('architect-wall-split')), findsNothing);
  expect(find.byKey(const ValueKey('architect-wall-cut')), findsNothing);
  expect(find.text('Hold → edit · longer → menu'), findsNothing);
  expect(find.byType(SnackBar), findsNothing);
}

IconButton _apply(WidgetTester tester) => tester.widget<IconButton>(
  find.byKey(const ValueKey('architect-command-apply')),
);

Future<void> _radialMove(WidgetTester tester, Offset point) async {
  final hold = await tester.startGesture(workspace.screen(tester, point));
  await tester.pump(const Duration(milliseconds: 750));
  await hold.up();
  await tester.pumpAndSettle();
  final menu = tester.widget<ArchitectRadialMenu>(
    find.byType(ArchitectRadialMenu),
  );
  menu.onActionSelected(ArchitectRadialAction.move);
  await tester.pumpAndSettle();
}

Future<void> _snapshot(WidgetTester tester, String name) async {
  if (Platform.environment['UPDATE_ARCHITECT_DRAG_PREVIEW'] != 'true') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  final previousShadows = debugDisableShadows;
  try {
    debugDisableShadows = false;
    repaint(boundary);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('scratch/$name.png').writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = previousShadows;
    repaint(boundary);
    await tester.pump();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final route in ['selection', 'radial', 'palette']) {
    testWidgets(
      'phone $route Move previews, cancels, and commits only with Apply',
      (tester) async {
        final model = _dragModel();
        addTearDown(model.dispose);
        await _openPhone(tester, model);
        await tool_ui.choose(tester, Icons.near_me_outlined);
        await tester.pumpAndSettle();

        Future<void> start() async {
          if (route == 'radial') {
            await _radialMove(tester, _columnPosition);
          } else {
            if (workspace.overlay(tester).selectedElementId != _columnId) {
              await tester.longPressAt(
                workspace.screen(tester, _columnPosition),
              );
              await tester.pumpAndSettle();
            }
            if (route == 'selection') {
              await tool_ui.selectionAction(tester, 'architect-selection-move');
            } else {
              final palette = tester.widget<ArchitectToolPalette>(
                find.byType(ArchitectToolPalette),
              );
              palette.onToolChanged(ArchitectTool.drag);
              await tester.pumpAndSettle();
            }
          }
          _expectCompactInBounds(tester);
        }

        await start();
        expect(
          find.byKey(const ValueKey('architect-command-apply')),
          findsNothing,
        );
        await tester.tapAt(workspace.screen(tester, _columnPosition));
        await tester.pump();
        expect(
          _apply(tester).onPressed,
          isNull,
          reason: 'A zero displacement must not commit.',
        );
        await tester.tapAt(workspace.screen(tester, const Offset(2, 4)));
        await tester.pump();
        _expectCompactInBounds(tester);
        expect(_apply(tester).onPressed, isNotNull);
        expect(model.undoCount, 0);
        await tester.tap(
          find.byKey(const ValueKey('architect-command-cancel')),
        );
        await tester.pumpAndSettle();
        expect(
          model.project.activeStorey.columns.first.position,
          _columnPosition,
        );
        expect(model.undoCount, 0);
        expect(find.byKey(_dragSurface), findsNothing);
        expect(find.byType(ArchitectToolPalette), findsOneWidget);

        await start();
        final camera = workspace.camera(tester);
        final fixedPoint = camera.toScreen(Offset.zero);
        final gesture = await tester.startGesture(
          workspace.screen(tester, _columnPosition),
        );
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.byType(ArchitectRadialMenu), findsNothing);
        await gesture.moveTo(workspace.screen(tester, const Offset(2, 4)));
        await gesture.up();
        await tester.pumpAndSettle();
        _expectCompactInBounds(tester);
        expect(
          camera.toScreen(Offset.zero),
          fixedPoint,
          reason: 'Dragging must not pan or resize the canvas.',
        );
        expect(
          model.project.activeStorey.columns.first.position,
          _columnPosition,
        );
        expect(
          model.undoCount,
          0,
          reason: 'Release leaves a reviewable preview.',
        );

        final preview = workspace
            .overlay(tester)
            .project
            .activeStorey
            .columns
            .first
            .position;
        expect(preview, isNot(_columnPosition));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(10, 150));
        await mouse.moveTo(const Offset(30, 190));
        await tester.pump();
        expect(
          workspace.overlay(tester).project.activeStorey.columns.first.position,
          preview,
        );
        await mouse.removePointer();

        var commits = 0;
        model.addListener(() => commits++);
        await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.columns.first.position, preview);
        expect(commits, 1);
        expect(model.undoCount, 1);
        expect(find.byKey(_dragSurface), findsNothing);
        expect(find.byKey(_genericSurface), findsNothing);
        expect(find.byType(ArchitectToolPalette), findsOneWidget);
        model.undo();
        await tester.pumpAndSettle();
        expect(
          model.project.activeStorey.columns.first.position,
          _columnPosition,
        );
        model.redo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.columns.first.position, preview);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'radial wall Move keeps connected joints and one clear phone overlay',
    (tester) async {
      final model = _dragModel(wall: true);
      addTearDown(model.dispose);
      await _openPhone(tester, model);
      await tool_ui.choose(tester, Icons.line_weight_rounded);
      await tester.pumpAndSettle();
      await _radialMove(tester, const Offset(-1, 0));
      _expectCompactInBounds(tester);
      await _snapshot(tester, 'drag_wall_pick_phone');
      await tester.tapAt(workspace.screen(tester, const Offset(-1, 0)));
      await tester.tapAt(workspace.screen(tester, const Offset(-1, 1)));
      await tester.pumpAndSettle();
      _expectCompactInBounds(tester);
      final preview = workspace.overlay(tester).project.activeStorey.walls;
      expect(model.undoCount, 0);
      expect(preview.first.startPoint.dy, closeTo(1, .05));
      expect(preview[1].startPoint, preview.first.startPoint);
      expect(preview[2].startPoint, preview.first.endPoint);
      await _snapshot(tester, 'drag_wall_review_phone');
      await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
      await tester.pumpAndSettle();
      expect(model.undoCount, 1);
      expect(
        model.project.activeStorey.walls.first.startPoint,
        preview.first.startPoint,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'raster Move preserves its mask, previews until Apply, and undoes once',
    (tester) async {
      const raster = ArchitectRasterUnderlay(
        id: 'raster',
        storeyId: 's',
        fileName: 'plan.png',
        internalImagePath: '',
        imageWidthPx: 400,
        imageHeightPx: 200,
        position: Offset(-2, -1),
        maskPolygon: [
          Offset(-2, -1),
          Offset(2, -1),
          Offset(2, 1),
          Offset(-2, 1),
        ],
      );
      final model = _dragModel();
      addTearDown(model.dispose);
      model.restore(model.project.copyWith(rasterUnderlays: [raster]));
      await _openPhone(tester, model);
      workspace
          .camera(tester)
          .fit(const Rect.fromLTRB(-4, -3, 4, 4), padding: 32);
      await tester.pumpAndSettle();
      await _radialMove(tester, Offset.zero);
      _expectCompactInBounds(tester);
      await tester.tapAt(workspace.screen(tester, const Offset(-1, 0)));
      await tester.tapAt(workspace.screen(tester, const Offset(0, 1.5)));
      await tester.pumpAndSettle();
      _expectCompactInBounds(tester);
      final delta = workspace.overlay(tester).dragController!.deltaModel!;
      expect(delta.distance, greaterThan(.5));
      expect(model.project.rasterUnderlays.single.position, raster.position);
      expect(model.undoCount, 0);
      await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
      await tester.pumpAndSettle();
      final moved = model.project.rasterUnderlays.single;
      expect(moved.position, raster.position + delta);
      expect(moved.maskPolygon, [
        for (final point in raster.maskPolygon!) point + delta,
      ]);
      expect(model.undoCount, 1);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.rasterUnderlays.single.position, raster.position);
      expect(
        model.project.rasterUnderlays.single.maskPolygon,
        raster.maskPolygon,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'edge target keeps controls in the canvas and Escape discards the preview',
    (tester) async {
      final model = _dragModel();
      addTearDown(model.dispose);
      await _openPhone(tester, model);
      await _radialMove(tester, _columnPosition);
      await tester.tapAt(workspace.screen(tester, _columnPosition));
      final viewport = tester.getRect(
        find.byKey(const ValueKey('architect-viewport-input')),
      );
      final gesture = await tester.startGesture(
        viewport.bottomRight - const Offset(12, 12),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      _expectCompactInBounds(tester);
      final overlay = tester.getRect(find.byKey(_dragSurface));
      expect(
        overlay.contains(viewport.bottomRight - const Offset(12, 12)),
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_dragSurface), findsNothing);
      expect(find.byType(ArchitectToolPalette), findsOneWidget);
      expect(model.undoCount, 0);
      expect(
        model.project.activeStorey.columns.first.position,
        _columnPosition,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
