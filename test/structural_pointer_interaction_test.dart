import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_pointer_interaction.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_magnetic_alignment_helper.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';

void main() {
  test(
    'snap displacement is capped in screen pixels and real CAD dimensions',
    () {
      for (final scale in [1.0, 100.0, 1000.0]) {
        for (final zoom in [.1, 1.0, 10.0]) {
          for (final mouse in [true, false]) {
            final pixels = 100 * zoom / scale;
            final tolerance = StructuralPointerInteraction.snapToleranceCad(
              isMouse: mouse,
              pixelsPerCadUnit: pixels,
              cadUnitsPerMeter: scale,
            );
            expect(
              tolerance * pixels,
              lessThanOrEqualTo(mouse ? 8.00001 : 12.00001),
            );
            expect(tolerance / scale, lessThanOrEqualTo(.200001));
          }
        }
      }
      expect(
        StructuralPointerInteraction.accepts(
          Offset.zero,
          const Offset(.09, .09),
          .1,
        ),
        isFalse,
      );
    },
  );
  test(
    'a previous snap cannot expand acquisition during interactive dragging',
    () {
      const floor = StoreyLevel(
        id: 'f',
        name: 'f',
        gridAxes: [
          StructuralGridAxis(
            id: 'x',
            name: '1',
            start: Offset(0, -10),
            end: Offset(0, 10),
          ),
        ],
      );
      final bounded = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: const Offset(.26, 4),
        columnWidth: .1,
        columnHeight: .1,
        toleranceCad: .2,
        maxCorrectionCad: .2,
        previousSnappedCenter: const Offset(0, 4),
        activeStorey: floor,
      );
      expect(bounded, isNull);
      final near = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: const Offset(.01, 4),
        columnWidth: .1,
        columnHeight: .1,
        toleranceCad: .2,
        maxCorrectionCad: .2,
        activeStorey: floor,
      );
      expect(near, isNotNull);
    },
  );
  test('interactive wall dragging preserves its chosen angle', () {
    const floor = StoreyLevel(
      id: 'f',
      name: 'f',
      gridAxes: [
        StructuralGridAxis(
          id: 'x',
          name: 'A',
          start: Offset(-10, 0),
          end: Offset(10, 0),
        ),
      ],
    );
    final result = StructuralMagneticAlignmentHelper.alignShearWall(
      rawCenter: const Offset(4, .05),
      wallLength: 2,
      wallThickness: .25,
      wallRotationRad: .1,
      toleranceCad: .2,
      maxCorrectionCad: .2,
      allowRotationSnap: false,
      activeStorey: floor,
    );
    expect(
      result == null || (result.snappedRotationRad! - .1).abs() < 1e-8,
      isTrue,
    );
  });
  test('a corner marker never becomes the element insertion point', () {
    const painter = StructuralPointerPainter(
      touchPos: Offset(100, 250),
      targetPos: Offset(100, 186),
      snappedPos: Offset(90, 170),
      placementPos: Offset(110, 190),
      activeTool: StructuralDrawTool.column,
      previewElementPolygon: [
        Offset(90, 170),
        Offset(130, 170),
        Offset(130, 210),
        Offset(90, 210),
      ],
    );
    expect(painter.effectivePlacementPosition, const Offset(110, 190));
  });
  for (final mouse in [false, true]) {
    testWidgets(
      'dragging an L section preserves grab position and commits its ghost: mouse=$mouse',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const column = StructuralColumn(
          id: 'c',
          center: Offset(5, 5),
          width: .5,
          height: .6,
          shape: ColumnShape.lShape,
          thickness: .20,
          rotationRad: .37,
        );
        final document = DxfDocument(
          entities: [],
          layers: {},
          blocks: {},
          headerVars: {},
          bounds: const Rect.fromLTWH(0, 0, 10, 10),
          entityStats: {},
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StructuralDesignerScreen(
              document: document,
              initialProject: const StructuralProject(
                storeys: [
                  StoreyLevel(id: 'f', name: 'f', columns: [column]),
                ],
              ),
              initialCadBounds: document.bounds,
              title: 'pointer-test',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.tap(find.text(l.toolColumn));
        await tester.pumpAndSettle();
        Structural2dPainter model() => tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<Structural2dPainter>()
            .first;
        StructuralPointerPainter pointer() => tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<StructuralPointerPainter>()
            .first;
        final origin = tester.getTopLeft(find.byType(InteractiveViewer).first);
        final oldScreen = model().cadToScene(column.center);
        final gesture = await tester.startGesture(
          origin + oldScreen + const Offset(7, 4),
          kind: mouse ? PointerDeviceKind.mouse : PointerDeviceKind.touch,
        );
        await tester.pump(const Duration(milliseconds: 650));
        expect(
          (pointer().effectivePlacementPosition - oldScreen).distance,
          lessThan(1e-6),
        );
        expect(pointer().previewElementPolygon, hasLength(6));
        const delta = Offset(70, 36);
        await gesture.moveBy(delta);
        await tester.pump();
        final ghost = pointer();
        expect(
          (ghost.effectivePlacementPosition - oldScreen - delta).distance,
          lessThan(1e-6),
        );
        expect(ghost.showDetailLoupe, !mouse);
        final expectedPolygon = List<Offset>.of(ghost.previewElementPolygon!);
        await gesture.up();
        await tester.pumpAndSettle();
        final placed = model().currentStorey.columns.single;
        expect(placed.rotationRad, column.rotationRad);
        final actual = placed.polygonVertices.map(model().cadToScene).toList();
        for (var i = 0; i < actual.length; i++) {
          expect((actual[i] - expectedPolygon[i]).distance, lessThan(1e-6));
        }
        await tester.tap(find.byTooltip(l.undoAction).first);
        await tester.pumpAndSettle();
        expect(model().currentStorey.columns.single.center, column.center);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'shear wall face reference is previewed and committed at the same location',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const wall = StructuralShearWall(
        id: 'w',
        start: Offset(4, 4),
        end: Offset(6, 6),
        thickness: .25,
        referenceLine: ShearWallReferenceLine.leftFace,
      );
      final doc = DxfDocument(
        entities: [],
        layers: {},
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
        entityStats: {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            initialProject: const StructuralProject(
              storeys: [
                StoreyLevel(id: 'f', name: 'f', shearWalls: [wall]),
              ],
            ),
            initialCadBounds: doc.bounds,
            title: 'wall-pointer',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l.toolShearWall));
      await tester.pumpAndSettle();
      Structural2dPainter model() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<Structural2dPainter>()
          .first;
      StructuralPointerPainter pointer() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<StructuralPointerPainter>()
          .first;
      final start = model().cadToScene(wall.center);
      final origin = tester.getTopLeft(find.byType(InteractiveViewer).first);
      final gesture = await tester.startGesture(
        origin + start + const Offset(5, 2),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(
        (pointer().effectivePlacementPosition - start).distance,
        lessThan(1e-6),
      );
      await gesture.moveBy(const Offset(50, 20));
      await tester.pump();
      final before = List<Offset>.of(pointer().previewElementPolygon!);
      await gesture.up();
      await tester.pumpAndSettle();
      final placed = model().currentStorey.shearWalls.single;
      expect(placed.rotationRad, closeTo(math.pi / 4, 1e-8));
      expect(placed.referenceLine, ShearWallReferenceLine.leftFace);
      final after = placed.polygonVertices.map(model().cadToScene).toList();
      for (var i = 0; i < before.length; i++) {
        expect((before[i] - after[i]).distance, lessThan(1e-6));
      }
    },
  );
  testWidgets(
    'corner snapping previews the element center and commits the same polygon',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = DxfDocument(
        entities: const [DxfCircle(center: Offset(5, 5), radius: .01)],
        layers: {},
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
        entityStats: {'CIRCLE': 1},
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            initialProject: const StructuralProject(
              storeys: [StoreyLevel(id: 'f', name: 'f')],
            ),
            initialCadBounds: doc.bounds,
            title: 'corner-pointer',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l.toolColumn));
      await tester.pumpAndSettle();
      Structural2dPainter model() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<Structural2dPainter>()
          .first;
      StructuralPointerPainter pointer() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<StructuralPointerPainter>()
          .first;
      final origin = tester.getTopLeft(find.byType(InteractiveViewer).first);
      final gesture = await tester.startGesture(
        origin + model().cadToScene(const Offset(5.14, 5.16)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      final ghost = pointer();
      expect(ghost.snappedPos, isNotNull);
      expect(
        (ghost.effectivePlacementPosition - ghost.snappedPos!).distance,
        greaterThan(5),
      );
      expect(
        ghost.previewElementPolygon!.any(
          (p) => (p - ghost.snappedPos!).distance < 1e-6,
        ),
        isTrue,
      );
      final before = List<Offset>.of(ghost.previewElementPolygon!);
      await gesture.up();
      await tester.pumpAndSettle();
      final after = model().currentStorey.columns.single.polygonVertices
          .map(model().cadToScene)
          .toList();
      for (var i = 0; i < before.length; i++) {
        expect((before[i] - after[i]).distance, lessThan(1e-6));
      }
    },
  );
}
