import 'architect_tool_test_helper.dart' as tool_ui;
import 'dart:io';
import 'dart:ui' show ImageByteFormat;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/rendering/architect_scene_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_polygon_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_editor.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';

import 'package:kotoview/src/features/architect/widgets/architect_wall_drafting_panel.dart';
import 'package:kotoview/src/features/architect/widgets/architect_shape_dimension_panel.dart';
import 'package:kotoview/src/features/architect/widgets/architect_numeric_keypad.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

const rectangle = [Offset(0, 0), Offset(6, 0), Offset(6, 4), Offset(0, 4)];
const primitive = ArchitectCadPrimitive(
  id: 'r',
  type: CadPrimitiveType.rect,
  startPoint: Offset.zero,
  endPoint: Offset(6, 4),
);
ArchitectSnapResult free(Offset point) => ArchitectSnapResult(point: point);
Future<void> tool(WidgetTester tester, IconData icon) async {
  await tool_ui.prepare(tester, icon);
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

Future<void> enter(
  WidgetTester tester,
  String value, {
  String prefix = 'shape-key',
}) async {
  for (final key in value.split('')) {
    await tester.tap(find.byKey(ValueKey('$prefix-$key')));
    await tester.pump();
  }
}

List<Offset> contour(ArchitectProject project, bool slab) => slab
    ? project.activeStorey.slabs.single.polygon
    : project.activeStorey.cadPrimitives.single.polygonCorners;

void main() {
  for (final reverse in [false, true]) {
    test(
      'Outward pull preserves old corners, inward pull cleans them ($reverse)',
      () {
        final original = reverse ? rectangle.reversed.toList() : rectangle;
        final edge = reverse ? 1 : 1;
        final expanded = ArchitectPolygonGeometry.pullEdge(original, edge, 2)!;
        expect(expanded, hasLength(6));
        expect(expanded, containsAll(original));
        expect(
          ArchitectPolygonGeometry.signedArea(expanded).abs(),
          closeTo(32, 1e-10),
        );
        expect(ArchitectPolygonGeometry.valid(expanded), isTrue);
        final newEdge = expanded.indexOf(
          reverse ? const Offset(8, 4) : const Offset(8, 0),
        );
        final retracted = ArchitectPolygonGeometry.pullEdge(
          expanded,
          newEdge,
          -1,
        )!;
        expect(retracted, hasLength(6));
        expect(
          ArchitectPolygonGeometry.signedArea(retracted).abs(),
          closeTo(28, 1e-10),
        );
        expect(retracted, isNot(contains(const Offset(8, 0))));
        expect(ArchitectPolygonGeometry.valid(retracted), isTrue);
        final pastOriginal = ArchitectPolygonGeometry.pullEdge(
          expanded,
          newEdge,
          -3,
        )!;
        expect(pastOriginal, hasLength(4));
        expect(ArchitectPolygonGeometry.valid(pastOriginal), isTrue);
        expect(ArchitectPolygonGeometry.pullEdge(original, edge, -6), isNull);
        expect(ArchitectPolygonGeometry.pullEdge(original, edge, -7), isNull);
      },
    );
  }

  test('Rotated and concave contours keep winding and reject crossings', () {
    Offset rotate(Offset p) => Offset(
      p.dx * math.cos(.4) - p.dy * math.sin(.4),
      p.dx * math.sin(.4) + p.dy * math.cos(.4),
    );
    final rotated = rectangle.map(rotate).toList();
    final expanded = ArchitectPolygonGeometry.pullEdge(rotated, 1, 1)!;
    expect(expanded, containsAll(rotated));
    expect(ArchitectPolygonGeometry.signedArea(expanded), closeTo(28, 1e-9));
    const concave = [
      Offset(0, 0),
      Offset(6, 0),
      Offset(6, 2),
      Offset(2, 2),
      Offset(2, 4),
      Offset(0, 4),
    ];
    expect(ArchitectPolygonGeometry.valid(concave), isTrue);
    expect(
      ArchitectPolygonGeometry.moveVertex(concave, 0, const Offset(5, 3)),
      isNull,
    );
    expect(
      ArchitectPolygonGeometry.moveVertex(rectangle, 1, const Offset(0, 4)),
      isNull,
    );
    final triangle = ArchitectPolygonGeometry.moveVertex(
      rectangle,
      1,
      const Offset(6, 4),
    )!;
    expect(triangle, hasLength(3));
    expect(ArchitectPolygonGeometry.valid(triangle), isTrue);
  });

  test('Preserved collinear vertices can be moved into new shape corners', () {
    final expanded = ArchitectPolygonGeometry.pullEdge(rectangle, 1, 2)!;
    final moved = ArchitectPolygonGeometry.moveVertex(
      expanded,
      expanded.indexOf(const Offset(6, 0)),
      const Offset(6, -1),
    )!;
    expect(moved, contains(const Offset(6, -1)));
    expect(ArchitectPolygonGeometry.valid(moved), isTrue);
  });

  test(
    'Shared editor has stable normal pulls and nearest small-handle hit',
    () {
      final editor = ArchitectPolygonEditor();
      expect(
        editor.start('r', rectangle, const Offset(6.03, 2.02), 100),
        isTrue,
      );
      expect(editor.edge, isTrue);
      editor.update(const Offset(8.03, 3.02), free, .1);
      expect(
        editor.preview!.any((p) => (p - const Offset(8, 0)).distance < 1e-10),
        isTrue,
      );
      expect(editor.preview, containsAll(rectangle));
      editor.update(const Offset(-1, 2), free, .1);
      expect(editor.invalid, isTrue);
      expect(ArchitectPolygonGeometry.valid(editor.preview!), isTrue);
      editor.cancel();
      expect(editor.start('r', rectangle, const Offset(.02, .02), 100), isTrue);
      expect(editor.edge, isFalse);
      editor.update(const Offset(7, 3), free, .1);
      expect(editor.invalid, isTrue);
    },
  );

  for (final slab in [false, true]) {
    test(
      'Contour command persists, snaps, moves and Undoes for slab=$slab',
      () {
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: 's',
            cadPrimitives: slab ? [] : [primitive],
            slabs: slab
                ? [
                    const ArchitectSlab(
                      id: 'r',
                      polygon: rectangle,
                      thickness: .23,
                      label: 'Custom',
                    ),
                  ]
                : [],
          ),
        );
        addTearDown(model.dispose);
        final old = model.project;
        final points = ArchitectPolygonGeometry.pullEdge(rectangle, 1, 2)!;
        model.execute(
          UpdateArchitectPolygon(
            storeyId: 's',
            elementId: 'r',
            polygon: points,
          ),
        );
        expect(contour(model.project, slab), points);
        final restored = ArchitectProject.fromJson(model.project.toJson());
        expect(contour(restored, slab), points);
        expect(ArchitectSceneGeometry.projectBounds(restored).right, 8);
        expect(
          ArchitectSelection.outline(
            restored,
            'r',
          ).contains(const Offset(7, 2)),
          isTrue,
        );
        final snap = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(8.02, .02),
          project: restored,
          tolerance: .1,
        );
        expect(snap.point, const Offset(8, 0));
        if (slab) {
          expect(restored.activeStorey.slabs.single.thickness, .23);
        }
        final changed = model.project;
        model.execute(
          const MoveArchitectElement(
            storeyId: 's',
            elementId: 'r',
            delta: Offset(1, 2),
          ),
        );
        expect(
          contour(model.project, slab),
          points.map((p) => p + const Offset(1, 2)).toList(),
        );
        model.undo();
        expect(identical(model.project, changed), isTrue);
        model.undo();
        expect(identical(model.project, old), isTrue);
        model.redo();
        expect(contour(model.project, slab), points);
        final before = model.project;
        expect(
          () => model.execute(
            const UpdateArchitectPolygon(
              storeyId: 's',
              elementId: 'r',
              polygon: [Offset.zero, Offset(6, 4), Offset(6, 0), Offset(0, 4)],
            ),
          ),
          throwsArgumentError,
        );
        expect(identical(model.project, before), isTrue);
      },
    );
  }

  test('Legacy rectangles still decode without a polygon field', () {
    final json = primitive.toJson();
    expect(json.containsKey('polygon'), isFalse);
    expect(ArchitectCadPrimitive.fromJson(json).polygonCorners, rectangle);
  });

  test('Shared number keypad limits decimal input to two places', () {
    String? value;
    for (final key in '12.345'.split('')) {
      value = ArchitectNumericKeypad.edit(value, key);
    }
    expect(value, '12.34');
    value = ArchitectNumericKeypad.edit(value, '⌫');
    expect(ArchitectNumericKeypad.edit(value, '7'), '12.37');
  });

  for (final unit in ArchitectUnit.values) {
    testWidgets(
      'Circle radius panel enters decimal ${unit.symbol} with one Undo',
      (tester) async {
        final model = workspace.commands();
        addTearDown(model.dispose);
        model.restore(model.project.copyWith(units: unit));
        await workspace.open(tester, model);
        await tool(tester, Icons.radio_button_unchecked_rounded);
        await workspace.wallTap(tester, Offset.zero);
        await workspace.wallTap(tester, const Offset(2, 1));
        expect(model.project.activeStorey.cadPrimitives, isEmpty);
        expect(find.byType(ArchitectShapeDimensionPanel), findsOneWidget);
        final panel = tester.widget<ArchitectShapeDimensionPanel>(
          find.byType(ArchitectShapeDimensionPanel),
        );
        expect(panel.unit, unit.symbol);
        expect(
          panel.values.single,
          closeTo(unit.toUnit(math.sqrt(5)), unit.toUnit(.001)),
        );
        await enter(tester, '125.45');
        final old = model.project;
        await tester.tap(find.byKey(const ValueKey('shape-save')));
        await tester.pumpAndSettle();
        final circle = model.project.activeStorey.cadPrimitives.single;
        expect(
          (circle.endPoint - circle.startPoint).distance,
          closeTo(unit.fromUnit(125.45), 1e-9),
        );
        expect(find.byType(ArchitectShapeDimensionPanel), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
        model.undo();
        expect(identical(model.project, old), isTrue);
      },
    );
  }

  testWidgets(
    'Circle panel appears for snapped radius and cancels without a commit',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 's',
          cadPrimitives: [
            ArchitectCadPrimitive(
              id: 'l',
              type: CadPrimitiveType.line,
              startPoint: Offset(2, 1),
              endPoint: Offset(6, 1),
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool(tester, Icons.radio_button_unchecked_rounded);
      await workspace.wallTap(tester, const Offset(3, -.2));
      await workspace.wallTap(tester, const Offset(6.02, 1.02));
      expect(find.byType(ArchitectShapeDimensionPanel), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shape-cancel')));
      await tester.pump();
      expect(model.project.activeStorey.cadPrimitives, hasLength(1));
    },
  );

  testWidgets(
    'Free rectangle enters width and height in cm; camera does not change draft',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
      await workspace.open(tester, model);
      await tool(tester, Icons.crop_square_rounded);
      await workspace.wallTap(tester, const Offset(2, 3));
      await workspace.wallTap(tester, const Offset(5, 5));
      expect(model.project.activeStorey.cadPrimitives, isEmpty);
      await enter(tester, '250.25');
      await tester.tap(find.byKey(const ValueKey('shape-input-1')));
      await enter(tester, '125.75');
      final before = workspace.overlay(tester).activeDraftEnd;
      workspace.camera(tester).panBy(const Offset(15, 10));
      await tester.pump();
      expect(workspace.overlay(tester).activeDraftEnd, before);
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      final r = model.project.activeStorey.cadPrimitives.single;
      expect(r.startPoint, const Offset(2, 3));
      expect(
        (r.endPoint - const Offset(4.5025, 4.2575)).distance,
        lessThan(1e-10),
      );
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  for (final slab in [false, true]) {
    testWidgets(
      'Shared selected handles pull, retract, cancel pinch and Undo for slab=$slab',
      (tester) async {
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: 's',
            cadPrimitives: slab ? [] : [primitive],
            slabs: slab
                ? [
                    const ArchitectSlab(
                      id: 'r',
                      polygon: rectangle,
                      thickness: .23,
                    ),
                  ]
                : [],
          ),
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tool(
          tester,
          slab ? Icons.layers_rounded : Icons.crop_square_rounded,
        );
        await editing.hold(tester, const Offset(3, 2));
        expect(workspace.overlay(tester).selectedElementId, 'r');
        final old = model.project;
        Future<void> pull(Offset from, Offset to) async {
          final gesture = await tester.startGesture(
            workspace.screen(tester, from),
          );
          await tester.pump(const Duration(milliseconds: 281));
          await gesture.moveTo(workspace.screen(tester, to));
          await tester.pump();
          expect(identical(model.project, old), isTrue);
          await gesture.up();
          await tester.pumpAndSettle();
        }

        await pull(const Offset(6, 2), const Offset(8, 2));
        final expanded = contour(model.project, slab);
        expect(expanded, containsAll(rectangle));
        expect(expanded, hasLength(6));
        model.undo();
        await tester.pump();
        expect(identical(model.project, old), isTrue);
        await pull(const Offset(6, 2), const Offset(4, 2));
        expect(contour(model.project, slab), hasLength(4));
        expect(
          ArchitectSceneGeometry.boundsOf(contour(model.project, slab)).right,
          4,
        );
        model.undo();
        await tester.pump();
        final first = await tester.startGesture(
          workspace.screen(tester, const Offset(6, 2)),
          pointer: 71,
        );
        await tester.pump(const Duration(milliseconds: 281));
        await first.moveTo(workspace.screen(tester, const Offset(7, 2)));
        await tester.pump();
        final second = await tester.startGesture(
          workspace.screen(tester, const Offset(3, 2)),
          pointer: 72,
        );
        await second.up();
        await first.up();
        await tester.pumpAndSettle();
        expect(identical(model.project, old), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Wall keypad shares two-place precision and project units', (
    tester,
  ) async {
    var length = 25.0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 250,
              child: ArchitectWallDraftingPanel(
                length: length,
                unit: 'cm',
                keypadInitiallyOpen: true,
                onLength: (v) => length = v,
                onEnd: () {},
                onContinue: () {},
                onUnlock: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('25.00 cm'), findsOneWidget);
    await enter(tester, '25.345', prefix: 'wall-key');
    expect(length, 25.34);
  });

  for (final slab in [false, true]) {
    testWidgets('Phone contour handles and dimensions fit for slab=$slab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capturePreview = bool.fromEnvironment(
        'UPDATE_ARCHITECT_SHAPE_PREVIEW',
      );
      if (capturePreview) {
        await tester.runAsync(() async {
          final font = FontLoader('Roboto')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
                ),
              ),
            );
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      final expanded = ArchitectPolygonGeometry.pullEdge(rectangle, 1, 2)!;
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: '0',
          cadPrimitives: slab
              ? []
              : [
                  primitive.copyWith(
                    polygon: expanded,
                    endPoint: const Offset(8, 4),
                  ),
                ],
          slabs: slab
              ? [
                  ArchitectSlab(
                    id: 'r',
                    polygon: expanded,
                    thickness: .23,
                    label: 'S1',
                  ),
                ]
              : [],
        ),
      );
      addTearDown(model.dispose);
      model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shape-phone-preview'),
          child: MaterialApp(
            locale: const Locale('bg'),
            theme: ThemeData.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tool(
        tester,
        slab ? Icons.layers_rounded : Icons.crop_square_rounded,
      );
      await editing.hold(tester, const Offset(3, 2));
      expect(workspace.overlay(tester).selectedElementId, 'r');
      final input = tester.getRect(
        find.byKey(const ValueKey('architect-viewport-input')),
      );
      for (final p in expanded) {
        expect(input.contains(workspace.screen(tester, p)), isTrue);
      }
      if (capturePreview) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('shape-phone-preview')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ImageByteFormat.png);
          await File(
            'docs/images/architect_${slab ? 'slab' : 'polygon'}_editor_phone.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(
        ArchitectPolygonPainter.vertexColor,
        isNot(ArchitectPolygonPainter.edgeColor),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Phone radius keypad fits and uses decimal centimeters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = workspace.commands();
    addTearDown(model.dispose);
    model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shape-phone-preview'),
        child: MaterialApp(
          locale: const Locale('bg'),
          theme: ThemeData.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: model),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tool(tester, Icons.radio_button_unchecked_rounded);
    await workspace.wallTap(tester, const Offset(-1, -1));
    await workspace.wallTap(tester, const Offset(2, 1));
    await enter(tester, '125.45');
    expect(find.text('125.45 cm'), findsOneWidget);
    final panelRect = tester.getRect(find.byType(ArchitectShapeDimensionPanel));
    expect(panelRect.left, greaterThanOrEqualTo(0));
    expect(panelRect.right, lessThanOrEqualTo(360));
    expect(panelRect.bottom, lessThanOrEqualTo(800));
    if (const bool.fromEnvironment('UPDATE_ARCHITECT_SHAPE_PREVIEW')) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('shape-phone-preview')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ImageByteFormat.png);
        await File(
          'docs/images/architect_radius_phone.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.byKey(const ValueKey('shape-save')));
    await tester.pumpAndSettle();
    final circle = model.project.activeStorey.cadPrimitives.single;
    expect(
      (circle.endPoint - circle.startPoint).distance,
      closeTo(1.2545, 1e-10),
    );
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final slab in [false, true]) {
    testWidgets(
      'Shared vertex handles preserve original split points and merge neighbors for slab=$slab',
      (tester) async {
        final expanded = ArchitectPolygonGeometry.pullEdge(rectangle, 1, 2)!;
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: 's',
            cadPrimitives: slab
                ? []
                : [
                    primitive.copyWith(
                      polygon: expanded,
                      endPoint: const Offset(8, 4),
                    ),
                  ],
            slabs: slab
                ? [ArchitectSlab(id: 'r', polygon: expanded, thickness: .23)]
                : [],
          ),
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tool(
          tester,
          slab ? Icons.layers_rounded : Icons.crop_square_rounded,
        );
        await editing.hold(tester, const Offset(3, 2));
        final old = model.project;
        final gesture = await tester.startGesture(
          workspace.screen(tester, const Offset(6, 0)),
        );
        await tester.pump(const Duration(milliseconds: 281));
        await gesture.moveTo(workspace.screen(tester, const Offset(6, -1)));
        await tester.pump();
        expect(identical(model.project, old), isTrue);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(contour(model.project, slab), contains(const Offset(6, -1)));
        expect(
          ArchitectPolygonGeometry.valid(contour(model.project, slab)),
          isTrue,
        );
        model.undo();
        await tester.pump();
        final merge = await tester.startGesture(
          workspace.screen(tester, const Offset(6, 0)),
        );
        await tester.pump(const Duration(milliseconds: 281));
        await merge.moveTo(workspace.screen(tester, const Offset(8.02, .02)));
        await merge.up();
        await tester.pumpAndSettle();
        final merged = contour(model.project, slab);
        expect(merged, hasLength(5));
        expect(merged, isNot(contains(const Offset(6, 0))));
        expect(ArchitectPolygonGeometry.valid(merged), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'Short edges have accessible midpoint handles despite overlapping corner targets',
    () {
      final editor = ArchitectPolygonEditor();
      const small = [Offset.zero, Offset(.2, 0), Offset(.2, 1), Offset(0, 1)];
      expect(editor.start('r', small, const Offset(.1, 0), 100), isTrue);
      expect(editor.edge, isTrue);
      expect(editor.index, 0);
      editor.cancel();
      expect(editor.start('r', small, const Offset(.01, 0), 100), isTrue);
      expect(editor.edge, isFalse);
      expect(editor.index, 0);
    },
  );
}
