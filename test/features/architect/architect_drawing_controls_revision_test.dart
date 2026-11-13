import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/l10n_extensions.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_exact_input_overlay.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_polygon_angle_control.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_shape_dimension_panel.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_distance_drafting_panel.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_hatch_editing_regression_test.dart' as hatches;
import 'architect_polygon_exact_offset_test.dart' as exact;
import 'architect_workspace_interaction_test.dart' as workspace;

Widget app(
  Widget child, {
  String language = 'en',
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  locale: Locale(language),
  theme: ThemeData(useMaterial3: true, brightness: brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<void> tool(WidgetTester tester, ArchitectTool type) async {
  tester
      .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
      .onToolChanged(type);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_DRAWING_REVISION')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('drawing-revision-capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/drawing-revision-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
  });

  for (final language in ['bg', 'en']) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(320, 480), const Size(360, 800)]) {
        testWidgets(
          'Exact shape actions stay visible above palette $language $brightness $size',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final values = [2.0, 3.0];
            var saved = 0;
            await tester.pumpWidget(
              RepaintBoundary(
                key: const ValueKey('drawing-revision-capture'),
                child: app(
                  Scaffold(
                    bottomNavigationBar: const SizedBox(height: 110),
                    body: Builder(
                      builder: (context) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(1.5)),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ArchitectExactInputOverlay(
                                anchor: Offset(
                                  size.width - 10,
                                  size.height - 10,
                                ),
                                child: StatefulBuilder(
                                  builder: (context, update) =>
                                      BimShapeDimensionPanel(
                                        values: values,
                                        labels: [
                                          context.l10n.architectShapeWidth,
                                          context.l10n.architectShapeHeight,
                                        ],
                                        unit: 'cm',
                                        minimum: .1,
                                        onChanged: (i, value) =>
                                            update(() => values[i] = value),
                                        onSave: () => saved++,
                                        onCancel: () {},
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  language: language,
                  brightness: brightness,
                ),
              ),
            );
            await tester.pumpAndSettle();
            final save = tester.getRect(
              find.byKey(const ValueKey('shape-save')),
            );
            expect(save.height, greaterThanOrEqualTo(44));
            expect(save.bottom, lessThanOrEqualTo(size.height - 110));
            await tester.tap(find.byKey(const ValueKey('shape-input-1')));
            await tester.sendKeyEvent(
              LogicalKeyboardKey.digit7,
              character: '7',
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            expect(values, [2, 7]);
            expect(saved, 1);
            expect(find.byType(EditableText), findsNothing);
            await capture(
              tester,
              '$language-${brightness.name}-${size.width.toInt()}',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('Ellipse uses three picks then exact review and one undo', (
    tester,
  ) async {
    final model = workspace.commands();
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await tool(tester, ArchitectTool.cadEllipse);
    const center = Offset(1, 1);
    await workspace.wallTap(tester, center);
    await workspace.wallTap(tester, const Offset(4, 1));
    expect(model.project.activeStorey.cadPrimitives, isEmpty);
    expect(find.byType(BimShapeDimensionPanel), findsNothing);
    await workspace.wallTap(tester, const Offset(3, 3));
    await tester.pumpAndSettle();
    expect(find.byType(BimShapeDimensionPanel), findsOneWidget);
    expect(model.canUndo, isFalse);
    await tester.tap(find.byKey(const ValueKey('shape-input-1')));
    await hatches.key(tester, '1.5');
    await tester.tap(find.byKey(const ValueKey('shape-save')));
    await tester.pumpAndSettle();
    final ellipse = model.project.activeStorey.cadPrimitives.single;
    expect(ellipse.startPoint, center);
    expect(ellipse.radiusX, closeTo(3, 1e-9));
    expect(ellipse.radiusY, closeTo(1.5, 1e-9));
    model.undo();
    expect(model.project.activeStorey.cadPrimitives, isEmpty);
    expect(model.canUndo, isFalse);
    model.redo();
    expect(
      model.project.activeStorey.cadPrimitives.single.toJson(),
      ellipse.toJson(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Manual Hatch takes snapped points without distance checkpoints',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool(tester, ArchitectTool.hatch);
      await tester.tap(find.byKey(const ValueKey('hatch-mode-manual')));
      await tester.pumpAndSettle();
      for (final point in hatches.outer) {
        await workspace.wallTap(tester, point);
        expect(find.byType(BimDistanceDraftingPanel), findsNothing);
        expect(find.byType(BimShapeDimensionPanel), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('hatch-draft-finish')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.single.type,
        CadPrimitiveType.hatch,
      );
      model.undo();
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final slab in [false, true]) {
    testWidgets(
      'Hatch/slab edge gets exact offset without a precision toggle slab=$slab',
      (tester) async {
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: '',
            cadPrimitives: slab ? [] : [hatches.hatch],
            slabs: slab
                ? [const ArchitectSlab(id: 'slab', polygon: hatches.outer)]
                : [],
          ),
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await workspace.wallTap(tester, const Offset(1, 1));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('polygon-edge-move')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('polygon-edge-extendCatheti')),
          findsNothing,
        );
        expect(
          tester
              .widget<ArchitectPolygonAngleControl>(
                find.byType(ArchitectPolygonAngleControl),
              )
              .locked,
          isTrue,
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-polygon-angle-lock')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ArchitectPolygonAngleControl>(
                find.byType(ArchitectPolygonAngleControl),
              )
              .locked,
          isFalse,
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-polygon-angle-lock')),
        );
        await tester.pumpAndSettle();
        final handle = exact.edgeHandle(tester, hatches.outer, 1);
        final original = model.project;
        await exact.drag(tester, handle, handle + const Offset(.5, 0));
        expect(
          find.byKey(const ValueKey('polygon-displacement-keypad')),
          findsOneWidget,
        );
        expect(identical(model.project, original), isTrue);
        await tester.tap(find.byKey(const ValueKey('shape-cancel')));
        await tester.pumpAndSettle();
        expect(identical(model.project, original), isTrue);
        await exact.drag(tester, handle, handle + const Offset(.5, 0));
        await hatches.key(tester, '0.25');
        await tester.tap(find.byKey(const ValueKey('shape-save')));
        await tester.pumpAndSettle();
        final polygon = slab
            ? model.project.activeStorey.slabs.single.polygon
            : model.project.activeStorey.cadPrimitives.single.polygonCorners;
        expect(polygon, hasLength(4));
        expect(polygon[1].dx, closeTo(8.25, 1e-9));
        model.undo();
        expect(identical(model.project, original), isTrue);
        expect(model.canUndo, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Slab toolbar remains manual with undo-point, properties and finish',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool(tester, ArchitectTool.slab);
      expect(
        find.byKey(const ValueKey('slab-draft-properties')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('hatch-mode-auto')), findsNothing);
      for (final point in hatches.outer) {
        await workspace.wallTap(tester, point);
      }
      await tester.tap(find.byKey(const ValueKey('slab-draft-undo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('slab-draft-finish')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.slabs.single.polygon, hasLength(3));
      expect(model.project.activeStorey.slabs.single.label, 'Slab 1');
      model.undo();
      expect(model.project.activeStorey.slabs, isEmpty);
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CAD crop previews without mutation, commits once and can expand again',
    (tester) async {
      final base = workspace.commands();
      final model = ArchitectCommandController(
        base.project.copyWith(
          cadUnderlays: {
            's': const ArchitectCadUnderlayConfig(
              storeyId: 's',
              fileName: 'plan.kcad',
              internalCopyPath: '',
              maskPolygon: [
                Offset(0, 0),
                Offset(8, 0),
                Offset(8, 6),
                Offset(0, 6),
              ],
            ),
          },
        ),
      );
      base.dispose();
      addTearDown(model.dispose);
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        bounds: const Rect.fromLTRB(0, 0, 8, 6),
        entityStats: {},
      );
      // Empty internal path deliberately marks this test-owned source as transient.
      // Rendering still uses the explicitly supplied original document.
      await workspace.open(tester, model, underlays: {'s': doc});
      await workspace.wallTap(tester, const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('architect-underlay-crop')),
        findsOneWidget,
      );
      final original = model.project;
      final handle = ArchitectPolygonEditor.offsetEdgeHandle(
        hatches.outer,
        1,
        workspace.camera(tester).scale,
        workspace.overlay(tester).handleOffsetLength,
      );
      final gesture = await tester.startGesture(
        workspace.screen(tester, handle),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(
        workspace.screen(tester, handle - const Offset(2, 0)),
      );
      await tester.pump();
      expect(identical(model.project, original), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        model.project.cadUnderlays['s']!.maskPolygon![1].dx,
        closeTo(6, 1e-9),
      );
      final smaller = model.project;
      final smallerPolygon = smaller.cadUnderlays['s']!.maskPolygon!;
      final expandHandle = ArchitectPolygonEditor.offsetEdgeHandle(
        smallerPolygon,
        1,
        workspace.camera(tester).scale,
        workspace.overlay(tester).handleOffsetLength,
      );
      await exact.drag(tester, expandHandle, expandHandle + const Offset(1, 0));
      expect(
        model.project.cadUnderlays['s']!.maskPolygon![1].dx,
        closeTo(7, 1e-9),
      );
      model.undo();
      await tester.pumpAndSettle();
      expect(identical(model.project, smaller), isTrue);
      model.undo();
      await tester.pumpAndSettle();
      expect(identical(model.project, original), isTrue);
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Rotated raster crop cancels on pinch and keeps source placement',
    (tester) async {
      final base = workspace.commands();
      final raster = ArchitectRasterUnderlay(
        id: 'raster',
        storeyId: 's',
        fileName: 'image.png',
        internalImagePath: '',
        imageWidthPx: 800,
        imageHeightPx: 600,
        metersPerPixel: .01,
        position: const Offset(2, 1),
        rotationRad: .4,
      );
      final model = ArchitectCommandController(
        base.project.copyWith(rasterUnderlays: [raster]),
      );
      base.dispose();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await workspace.wallTap(
        tester,
        raster.pixelToLocal(const Offset(400, 300)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('architect-underlay-crop')),
        findsOneWidget,
      );
      final original = model.project;
      final polygon = raster.localCorners;
      final grip = ArchitectPolygonEditor.offsetEdgeHandle(
        polygon,
        1,
        workspace.camera(tester).scale,
        workspace.overlay(tester).handleOffsetLength,
      );
      final n =
          Offset(polygon[2].dy - polygon[1].dy, polygon[1].dx - polygon[2].dx) /
          (polygon[2] - polygon[1]).distance;
      final first = await tester.startGesture(
        workspace.screen(tester, grip),
        pointer: 81,
      );
      await first.moveTo(workspace.screen(tester, grip - n));
      await tester.pump();
      final second = await tester.startGesture(
        workspace.screen(tester, raster.position),
        pointer: 82,
      );
      await second.up();
      await first.up();
      await tester.pumpAndSettle();
      expect(identical(model.project, original), isTrue);
      expect(model.canUndo, isFalse);
      // The camera may change during navigation; compute grips again.
      final nextGrip = ArchitectPolygonEditor.offsetEdgeHandle(
        polygon,
        1,
        workspace.camera(tester).scale,
        workspace.overlay(tester).handleOffsetLength,
      );
      await exact.drag(tester, nextGrip, nextGrip - n);
      final cropped = model.project.rasterUnderlays.single;
      expect(cropped.position, raster.position);
      expect(cropped.rotationRad, raster.rotationRad);
      expect(cropped.metersPerPixel, raster.metersPerPixel);
      expect(cropped.maskPolygon, hasLength(4));
      expect(
        (cropped.maskPolygon![1] - polygon[1] + n).distance,
        lessThan(1e-8),
      );
      model.undo();
      expect(identical(model.project, original), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
