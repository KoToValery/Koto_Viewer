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
import 'package:kotoview/src/features/bim_editing/interaction/bim_pointer_interaction.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
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
  ArchitectCommandController model, {
  String language = 'en',
  Map<String, DxfDocument>? underlays,
}) async {
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
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(
          commandController: model,
          underlaysByStorey: underlays,
        ),
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
  expect(rect.width, lessThanOrEqualTo(100));
  expect(tester.widget<Material>(overlay).type, MaterialType.transparency);
  for (final key in ['architect-command-cancel', 'architect-command-apply']) {
    final action = find.byKey(ValueKey(key));
    if (action.evaluate().isNotEmpty) {
      expect(tester.getSize(action), const Size(48, 48));
    }
  }
  expect(
    tester.getSize(find.byKey(const ValueKey('architect-command-cancel-disc'))),
    const Size(32, 32),
  );
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
        // The first complete gesture chooses a base without moving anything.
        final baseGesture = await tester.startGesture(
          workspace.screen(tester, const Offset(2, 4)),
        );
        const baseCorner = Offset(2.875, 4.875);
        await baseGesture.moveTo(workspace.screen(tester, baseCorner));
        await baseGesture.up();
        await tester.pumpAndSettle();
        expect(
          workspace.overlay(tester).dragController!.basePointModel,
          baseCorner,
        );
        expect(workspace.overlay(tester).dragController!.distanceMeters, 0);
        expect(
          workspace.overlay(tester).project.activeStorey.columns.first.position,
          _columnPosition,
        );
        expect(_apply(tester).onPressed, isNull);
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

  for (final language in ['en', 'bg']) {
    testWidgets('precise base and target are separate picks ($language)', (
      tester,
    ) async {
      final model = _dragModel();
      addTearDown(model.dispose);
      await _openPhone(tester, model, language: language);
      await _radialMove(tester, _columnPosition);
      final l = AppLocalizations.of(tester.element(find.byKey(_dragSurface)))!;
      expect(find.text(l.architectDragPickBasePoint), findsOneWidget);

      // First aim from empty space at a point outside the selected column.
      // The standard lifted pointer must mark the reference column exactly.
      const base = Offset(-1.125, -1.125);
      final finger =
          workspace.screen(tester, base) +
          const Offset(0, BimPointerInteraction.touchClearancePx);
      final first = await tester.startGesture(finger + const Offset(25, 0));
      await tester.pump(BimPointerInteraction.placementHoldDuration);
      await first.moveTo(finger);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('architect-offset-pointer')),
        findsOneWidget,
      );
      final drag = workspace.overlay(tester).dragController!;
      expect(drag.isPickingBasePoint, isTrue);
      expect(drag.currentPointModel, base);
      expect(drag.deltaModel, isNull);
      await _snapshot(tester, 'drag_base_precision_$language');
      expect(model.undoCount, 0);
      expect(
        workspace.overlay(tester).project.activeStorey.columns.first.position,
        _columnPosition,
      );
      await first.up();
      await tester.pumpAndSettle();
      expect(drag.basePointModel, base);
      expect(drag.distanceMeters, 0);
      expect(find.text(l.architectDragPickTargetPoint), findsOneWidget);
      expect(_apply(tester).onPressed, isNull);

      // A separate gesture places that reference at the destination.
      const target = Offset(0, 1);
      await tester.tapAt(workspace.screen(tester, target));
      await tester.pumpAndSettle();
      expect((drag.deltaModel! - (target - base)).distance, lessThan(1e-6));
      expect(model.undoCount, 0);
      await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.columns.first.position,
        _columnPosition + target - base,
      );
      expect(model.undoCount, 1);
      model.undo();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.columns.first.position,
        _columnPosition,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('default leader relocates the base before moving the element', (
    tester,
  ) async {
    final model = _dragModel();
    addTearDown(model.dispose);
    await _openPhone(tester, model);
    await _radialMove(tester, _columnPosition);
    final drag = workspace.overlay(tester).dragController!;
    final grip = workspace.screen(tester, drag.defaultHandleGrip!);
    final base = drag.defaultHandleAnchor!;
    final destination = workspace.screen(tester, base + const Offset(-1, -1));
    final first = await tester.startGesture(
      grip,
      kind: PointerDeviceKind.mouse,
    );
    await first.moveTo(destination + grip - workspace.screen(tester, base));
    await first.up();
    await tester.pumpAndSettle();
    expect(
      (drag.basePointModel! - (base + const Offset(-1, -1))).distance,
      lessThan(1e-6),
    );
    expect(drag.distanceMeters, 0);
    expect(model.project.activeStorey.columns.first.position, _columnPosition);
    expect(model.undoCount, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(_dragSurface), findsNothing);
  });

  testWidgets(
    'radial wall Move keeps connected joints and one clear phone overlay',
    (tester) async {
      final model = _dragModel(wall: true);
      addTearDown(model.dispose);
      await _openPhone(tester, model);
      await tool_ui.choose(tester, Icons.line_weight_rounded);
      await tester.pumpAndSettle();
      await _snapshot(tester, 'drag_idle_hint_phone');
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
    'CAD underlay reference pick stays fixed, then snaps and saves one move',
    (tester) async {
      const config = ArchitectCadUnderlayConfig(
        storeyId: 's',
        fileName: 'plan.dxf',
        internalCopyPath: '',
        lockedCadOriginX: 5000,
        lockedCadOriginY: 10000,
        unitsPerMeter: 1000,
        lockOrigin: true,
        maskPolygon: [Offset(0, 0), Offset(4, 0), Offset(4, 2), Offset(0, 2)],
      );
      final document = DxfDocument(
        layers: {},
        blocks: {},
        headerVars: {},
        entityStats: {},
        bounds: const Rect.fromLTRB(5000, 10000, 9000, 12000),
        entities: [
          const DxfLine(p1: Offset(5000, 10000), p2: Offset(9000, 12000)),
        ],
      );
      final model = _dragModel();
      addTearDown(model.dispose);
      model.restore(model.project.copyWith(cadUnderlays: {'s': config}));
      await _openPhone(tester, model, underlays: {'s': document});
      await _radialMove(tester, const Offset(2, 1));
      final drag = workspace.overlay(tester).dragController!;
      expect(drag.isCadUnderlay, isTrue);

      final finger =
          workspace.screen(tester, Offset.zero) +
          const Offset(0, BimPointerInteraction.touchClearancePx);
      final first = await tester.startGesture(finger + const Offset(30, 0));
      await tester.pump(BimPointerInteraction.placementHoldDuration);
      await first.moveTo(finger);
      await tester.pump();
      expect(drag.currentPointModel, Offset.zero);
      expect(drag.currentSnapLabel, 'Endpoint');
      expect(drag.isPickingBasePoint, isTrue);
      expect(drag.ghostCadFrame, isNull);
      expect(model.project.cadUnderlays['s'], same(config));
      await _snapshot(tester, 'drag_cad_base_precision_phone');
      await first.up();
      await tester.pumpAndSettle();
      expect(drag.basePointCad, const Offset(5000, 10000));
      expect(drag.distanceMeters, 0);
      expect(model.undoCount, 0);

      const target = Offset(-1.125, -1.125);
      await tester.tapAt(workspace.screen(tester, target));
      await tester.pumpAndSettle();
      expect(drag.currentPointModel, target);
      expect(drag.ghostCadFrame!.toModel(drag.basePointCad!), target);
      expect(model.project.cadUnderlays['s'], same(config));
      await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
      await tester.pumpAndSettle();
      final moved = model.project.cadUnderlays['s']!;
      final movedFrame = BimCoordinateFrame(
        origin: Offset(moved.lockedCadOriginX!, moved.lockedCadOriginY!),
        unitsPerMeter: moved.unitsPerMeter!,
      );
      expect(movedFrame.toModel(const Offset(5000, 10000)), target);
      expect(moved.maskPolygon, [
        for (final point in config.maskPolygon!) point + target,
      ]);
      expect(model.undoCount, 1);
      final restored = ArchitectProject.fromJson(model.project.toJson());
      expect(
        restored.cadUnderlays['s']!.lockedCadOriginX,
        moved.lockedCadOriginX,
      );
      expect(restored.cadUnderlays['s']!.maskPolygon, moved.maskPolygon);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.cadUnderlays['s'], same(config));
      model.redo();
      await tester.pumpAndSettle();
      expect(
        model.project.cadUnderlays['s']!.lockedCadOriginX,
        moved.lockedCadOriginX,
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
