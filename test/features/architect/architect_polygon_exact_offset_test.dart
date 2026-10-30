import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_displacement.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_editor.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_scene_geometry.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_hatch_editing_regression_test.dart' as hatches;
import 'architect_polygon_editor_test.dart' as shapes;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectCommandController seeded(CadPrimitiveType type) {
  final model = editing.seeded(
    ArchitectStorey(
      id: 's',
      name: '',
      cadPrimitives: [
        hatches.hatch.copyWith(
          type: type,
          holes: type == CadPrimitiveType.hatch ? [hatches.hole] : [],
        ),
      ],
    ),
  );
  model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
  addTearDown(model.dispose);
  return model;
}

Future<void> edit(WidgetTester tester, CadPrimitiveType type) async {
  if (type == CadPrimitiveType.hatch) {
    await workspace.wallTap(tester, const Offset(1, 1));
  } else {
    await shapes.tool(tester, Icons.crop_square_rounded);
    await editing.contextHold(tester, const Offset(1, 1));
    for (
      var page = 0;
      page < 8 &&
          find
              .byKey(const ValueKey('architect-radial-edit'))
              .evaluate()
              .isEmpty;
      page++
    ) {
      await tester.tap(find.byKey(const ValueKey('architect-radial-more')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('architect-radial-edit')));
  }
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('polygon-exact-offset')));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<IconButton>(find.byKey(const ValueKey('polygon-exact-offset')))
        .isSelected,
    isTrue,
  );
}

Future<void> drag(
  WidgetTester tester,
  Offset from,
  Offset to, {
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) async {
  final gesture = await tester.startGesture(
    workspace.screen(tester, from),
    kind: kind,
  );
  await gesture.moveTo(workspace.screen(tester, to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Offset edgeHandle(WidgetTester tester, List<Offset> polygon, int index) =>
    ArchitectPolygonEditor.offsetEdgeHandle(
      polygon,
      index,
      workspace.camera(tester).scale,
      workspace.overlay(tester).handleOffsetLength,
    );

Offset vertexHandle(WidgetTester tester, List<Offset> polygon, int index) =>
    ArchitectPolygonEditor.offsetVertexHandle(
      polygon,
      index,
      workspace.camera(tester).scale,
      workspace.overlay(tester).handleOffsetLength,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'Point distance follows the drag direction and always uses the original vertex',
    () {
      final operation = ArchitectPolygonDisplacement.fromDrag(
        polygon: hatches.outer,
        index: 2,
        edge: false,
        target: const Offset(8.3, 6.4),
        mode: ArchitectPolygonEdgeMode.pull,
      )!;
      final next = operation.atDistance(1)!;
      expect((next[2] - const Offset(8.6, 6.8)).distance, lessThan(1e-9));
      expect((next[2] - hatches.outer[2]).distance, closeTo(1, 1e-9));
      expect(operation.atDistance(.5)![2].dx, closeTo(8.3, 1e-9));
      expect(operation.atDistance(-.5)![2].dx, closeTo(7.7, 1e-9));
      expect(operation.atDistance(0), hatches.outer);
      expect(operation.atDistance(double.nan), isNull);
    },
  );

  for (final mode in ArchitectPolygonEdgeMode.values) {
    test('Rotated edge uses signed perpendicular offset in $mode', () {
      Offset turn(Offset p) => Offset(
        p.dx * math.cos(.4) - p.dy * math.sin(.4),
        p.dx * math.sin(.4) + p.dy * math.cos(.4),
      );
      final polygon = hatches.outer.map(turn).toList();
      final origin = (polygon[1] + polygon[2]) / 2;
      final normal = ArchitectPolygonGeometry.normal(polygon, 1);
      final operation = ArchitectPolygonDisplacement.fromDrag(
        polygon: polygon,
        index: 1,
        edge: true,
        target: origin - normal * .5,
        mode: mode,
      )!;
      expect(operation.distance, closeTo(-.5, 1e-9));
      for (final value in [.25, -.25]) {
        final next = operation.atDistance(value)!;
        expect(ArchitectPolygonGeometry.valid(next), isTrue);
        expect(
          next.any((p) => (p - polygon[1] - normal * value).distance < 1e-9),
          isTrue,
        );
      }
    });
  }

  for (final type in [CadPrimitiveType.rect, CadPrimitiveType.hatch]) {
    for (final mode in [
      ArchitectPolygonEdgeMode.pull,
      ArchitectPolygonEdgeMode.move,
    ]) {
      testWidgets(
        '$type edge keypad uses centimetres, previews, cancels and saves with one Undo ($mode)',
        (tester) async {
          final model = seeded(type);
          await workspace.open(tester, model);
          await edit(tester, type);
          await tester.tap(find.byKey(ValueKey('polygon-edge-${mode.name}')));
          await tester.pumpAndSettle();
          final before = model.project;
          final handle = edgeHandle(tester, hatches.outer, 1);
          await drag(tester, handle, handle + const Offset(.5, 0));
          expect(
            find.byKey(const ValueKey('polygon-displacement-keypad')),
            findsOneWidget,
          );
          expect(identical(before, model.project), isTrue);
          await shapes.enter(tester, '25.5');
          expect(
            ArchitectSceneGeometry.boundsOf(
              workspace
                  .overlay(tester)
                  .project
                  .activeStorey
                  .cadPrimitives
                  .single
                  .polygonCorners,
            ).right,
            closeTo(8.255, 1e-9),
          );
          expect(find.byType(EditableText), findsNothing);
          expect(tester.testTextInput.isVisible, isFalse);
          await tester.tap(find.byKey(const ValueKey('shape-cancel')));
          await tester.pumpAndSettle();
          expect(identical(before, model.project), isTrue);
          expect(model.canUndo, isFalse);
          await drag(tester, handle, handle + const Offset(.5, 0));
          await shapes.enter(tester, '25.5');
          await tester.tap(find.byKey(const ValueKey('shape-save')));
          await tester.pumpAndSettle();
          final result = model.project.activeStorey.cadPrimitives.single;
          expect(
            ArchitectSceneGeometry.boundsOf(result.polygonCorners).right,
            closeTo(8.255, 1e-9),
          );
          expect(
            result.polygonCorners,
            hasLength(mode == ArchitectPolygonEdgeMode.pull ? 6 : 4),
          );
          expect(
            result.holes,
            type == CadPrimitiveType.hatch ? [hatches.hole] : [],
          );
          model.undo();
          expect(identical(model.project, before), isTrue);
          expect(model.canUndo, isFalse);
          model.redo();
          expect(
            model.project.activeStorey.cadPrimitives.single.toJson(),
            result.toJson(),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '$type vertex drag fixes direction and keypad sets exact travel',
      (tester) async {
        final model = seeded(type);
        await workspace.open(tester, model);
        await tools.setMagnetic(tester, false);
        await edit(tester, type);
        final before = model.project;
        final handle = vertexHandle(tester, hatches.outer, 2);
        await drag(
          tester,
          handle,
          handle + const Offset(.3, .4),
          kind: PointerDeviceKind.touch,
        );
        expect(
          find.byKey(const ValueKey('polygon-displacement-keypad')),
          findsOneWidget,
        );
        await shapes.enter(tester, '100');
        expect(identical(before, model.project), isTrue);
        final preview = workspace
            .overlay(tester)
            .project
            .activeStorey
            .cadPrimitives
            .single
            .polygonCorners;
        expect((preview[2] - const Offset(8.6, 6.8)).distance, lessThan(1e-9));
        await tester.tap(find.byKey(const ValueKey('shape-save')));
        await tester.pumpAndSettle();
        final result = model.project.activeStorey.cadPrimitives.single;
        expect(
          (result.polygonCorners[2] - hatches.outer[2]).distance,
          closeTo(1, 1e-9),
        );
        expect(result.polygonCorners.take(2), hatches.outer.take(2));
        expect(result.polygonCorners.last, hatches.outer.last);
        model.undo();
        expect(identical(before, model.project), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Hatch opening edits only the picked ring and rejects crossing the host',
    (tester) async {
      final model = seeded(CadPrimitiveType.hatch);
      await workspace.open(tester, model);
      await edit(tester, CadPrimitiveType.hatch);
      await workspace.wallTap(tester, const Offset(3, 2));
      expect(workspace.overlay(tester).polygonEditHoleIndex, 0);
      await tester.tap(find.byKey(const ValueKey('polygon-edge-move')));
      await tester.pumpAndSettle();
      final handle = edgeHandle(tester, hatches.hole, 1);
      await drag(tester, handle, handle + const Offset(.4, 0));
      await shapes.enter(tester, '500');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('shape-save')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('shape-cancel')));
      await tester.pumpAndSettle();
      expect(model.canUndo, isFalse);
      await drag(tester, handle, handle + const Offset(.4, 0));
      await shapes.enter(tester, '25');
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      final result = model.project.activeStorey.cadPrimitives.single;
      expect(result.polygonCorners, hatches.outer);
      expect(
        ArchitectSceneGeometry.boundsOf(result.holes.single).right,
        closeTo(4.25, 1e-9),
      );
      model.undo();
      expect(model.project.activeStorey.cadPrimitives.single.holes, [
        hatches.hole,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Signed input reverses an edge; zero and dismissal leave no Undo entry',
    (tester) async {
      final model = seeded(CadPrimitiveType.hatch);
      await workspace.open(tester, model);
      await edit(tester, CadPrimitiveType.hatch);
      await tester.tap(find.byKey(const ValueKey('polygon-edge-move')));
      await tester.pumpAndSettle();
      final before = model.project;
      final handle = edgeHandle(tester, hatches.outer, 1);
      await drag(tester, handle, handle + const Offset(.5, 0));
      await shapes.enter(tester, '25');
      await tester.tap(find.text('±'));
      await tester.pump();
      expect(
        ArchitectSceneGeometry.boundsOf(
          workspace
              .overlay(tester)
              .project
              .activeStorey
              .cadPrimitives
              .single
              .polygonCorners,
        ).right,
        closeTo(7.75, 1e-9),
      );
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      model.undo();
      await tester.pumpAndSettle();
      expect(identical(before, model.project), isTrue);
      await drag(tester, handle, handle + const Offset(.5, 0));
      await shapes.enter(tester, '0');
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      expect(identical(before, model.project), isTrue);
      expect(model.canUndo, isFalse);
      expect(model.canRedo, isTrue);
      await drag(tester, handle, handle + const Offset(.5, 0));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('polygon-displacement-keypad')),
        findsNothing,
      );
      expect(identical(before, model.project), isTrue);
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['bg', 'en']) {
    for (final type in [CadPrimitiveType.rect, CadPrimitiveType.hatch]) {
      testWidgets(
        'Phone exact offset fits with local keypad: $language $type',
        (tester) async {
          final model = seeded(type);
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const capture = ValueKey('exact-offset-capture');
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: ArchitectWorkspaceScreen(commandController: model),
              ),
            ),
          );
          await tester.pumpAndSettle();
          workspace
              .camera(tester)
              .fit(const Rect.fromLTRB(-2, -2, 12, 10), padding: 40);
          await edit(tester, type);
          final toggle = tester.getRect(
            find.byKey(const ValueKey('polygon-exact-offset')),
          );
          expect(toggle.left, greaterThanOrEqualTo(0));
          expect(toggle.right, lessThanOrEqualTo(360));
          final handle = edgeHandle(tester, hatches.outer, 1);
          await drag(
            tester,
            handle,
            handle + const Offset(1, 0),
            kind: PointerDeviceKind.touch,
          );
          expect(
            find.byKey(const ValueKey('polygon-displacement-keypad')),
            findsOneWidget,
          );
          for (final key in ['shape-key-0', 'shape-save', 'shape-cancel']) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(360));
            expect(rect.bottom, lessThanOrEqualTo(800));
          }
          expect(find.byType(EditableText), findsNothing);
          expect(tester.testTextInput.isVisible, isFalse);
          if (const bool.fromEnvironment('POLYGON_OFFSET_QA')) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(capture),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'scratch/architect_exact_offset_${language}_${type.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.tap(find.byKey(const ValueKey('shape-cancel')));
          await tester.pumpAndSettle();
          expect(model.canUndo, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
