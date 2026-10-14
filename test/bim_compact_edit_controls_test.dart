import 'package:kotoview/src/features/bim_editing/widgets/bim_transform_renderer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/widgets/element_palette_bar.dart';
import 'package:kotoview/src/features/structural_designer/widgets/structural_offset_dialog.dart';

void main() {
  for (final axis in [false, true]) {
    testWidgets('offset takes its direction from the canvas: axis=$axis', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        entityStats: {},
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
      );
      final changes = <StructuralProject>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            title: 'Offset',
            initialProject:
                StructuralProject(
                  storeys: [
                    StoreyLevel(
                      id: 'g',
                      name: '±0.00',
                      columns: axis
                          ? []
                          : [
                              const StructuralColumn(
                                id: 'c',
                                center: Offset(5, 5),
                              ),
                            ],
                    ),
                  ],
                  gridAxes: axis
                      ? [
                          const StructuralGridAxis(
                            id: 'a',
                            name: '1',
                            start: Offset(5, 2),
                            end: Offset(5, 8),
                          ),
                        ]
                      : [],
                ).copyWithGridAxes(
                  axis
                      ? [
                          const StructuralGridAxis(
                            id: 'a',
                            name: '1',
                            start: Offset(5, 2),
                            end: Offset(5, 8),
                          ),
                        ]
                      : [],
                ),
            bimContext: StructuralBimContext(
              underlaysByStorey: {'g': doc},
              projectBounds: doc.bounds,
              cadUnitsPerMeter: 1,
              onProjectChanged: changes.add,
              onLayerVisibilityChanged: (_, _) {},
              onWallsDetected: (_) {},
              onExport: (_, _, _) async {},
              onManageStoreys: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<ElementPaletteBar>(find.byType(ElementPaletteBar))
          .onSelectTool(StructuralDrawTool.select);
      await tester.pumpAndSettle();
      final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is Structural2dPainter,
      );
      Structural2dPainter plan() =>
          tester.widget<CustomPaint>(paint).painter as Structural2dPainter;
      Offset point(Offset cad) => tester
          .renderObject<RenderBox>(paint)
          .localToGlobal(plan().cadToScene(cad));
      await tester.tapAt(point(const Offset(5, 5)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Offset').last);
      await tester.tap(find.text('Offset').last);
      await tester.pumpAndSettle();
      expect(find.text('Left'), findsNothing);
      expect(find.text('Right'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('structural-offset-distance')),
        axis ? '1' : '100',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Offset'));
      await tester.pumpAndSettle();
      final transform = tester
          .widget<BimTransformRenderer>(find.byType(BimTransformRenderer))
          .transformationController
          .value
          .clone();
      final gesture = await tester.startGesture(point(const Offset(5, 5)));
      await gesture.moveTo(point(const Offset(3, 5)));
      await tester.pump(const Duration(milliseconds: 350));
      if (axis) {
        expect(plan().axisOffsetPreview!.start.dx, closeTo(4, 1e-6));
      } else {
        expect(plan().columnOffsetPreview!.center.dx, closeTo(4, 1e-6));
      }
      expect(
        tester
            .widget<BimTransformRenderer>(find.byType(BimTransformRenderer))
            .transformationController
            .value,
        transform,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Both'));
      await tester.pumpAndSettle();
      if (axis) {
        expect(changes.last.effectiveGridAxes, hasLength(2));
        expect(
          changes.last.effectiveGridAxes.any(
            (a) => (a.start.dx - 4).abs() < 1e-6,
          ),
          true,
        );
      } else {
        expect(changes.last.activeStorey.columns, hasLength(2));
        expect(
          changes.last.activeStorey.columns.last.center,
          const Offset(4, 5),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in ['en', 'bg']) {
    testWidgets(
      'compact offset validates distance and decimal comma: $locale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        double? distance;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      distance = await showStructuralOffsetDialog(
                        context,
                        centimeters: true,
                      ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog.title, isNull);
        expect(
          tester.getSize(find.byType(TextField)).width + 32,
          lessThanOrEqualTo(280),
        );
        expect(find.byType(ChoiceChip), findsNothing);
        final field = find.byKey(const ValueKey('structural-offset-distance'));
        final l = await AppLocalizations.delegate.load(Locale(locale));
        final apply = find.widgetWithText(TextButton, l.offsetAction);
        for (final invalid in ['', '0', '-1', 'NaN', 'Infinity']) {
          await tester.enterText(field, invalid);
          await tester.pump();
          expect(tester.widget<TextButton>(apply).onPressed, isNull);
        }
        await tester.enterText(field, '12,5');
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(distance, .125);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final kind in ['column', 'wall', 'beam']) {
    testWidgets('Drag+ previews, cancels, commits and undoes a $kind copy', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        entityStats: {},
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
      );
      const floor = StoreyLevel(
        id: 'g',
        name: '±0.00',
        columns: [
          StructuralColumn(
            id: 'c',
            name: 'C1',
            center: Offset(5, 5),
            shape: ColumnShape.lShape,
            width: .6,
            height: .8,
            thickness: .2,
            rotationRad: .3,
            isMirrored: true,
          ),
        ],
        shearWalls: [
          StructuralShearWall(
            id: 'w',
            name: 'W1',
            start: Offset(4, 5),
            end: Offset(6, 5),
            thickness: .25,
            isFlipped: true,
            referenceLine: ShearWallReferenceLine.rightFace,
          ),
        ],
        beams: [
          StructuralBeam(
            id: 'b',
            name: 'B1',
            start: Offset(4, 5),
            end: Offset(6, 5),
            width: .35,
            depth: .65,
            isSecondary: true,
          ),
        ],
      );
      final initial = floor.copyWith(
        columns: kind == 'column' ? floor.columns : [],
        shearWalls: kind == 'wall' ? floor.shearWalls : [],
        beams: kind == 'beam' ? floor.beams : [],
      );
      final changed = <StructuralProject>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            title: 'Copies',
            initialProject: StructuralProject(storeys: [initial]),
            bimContext: StructuralBimContext(
              underlaysByStorey: {'g': doc},
              projectBounds: doc.bounds,
              cadUnitsPerMeter: 1,
              onProjectChanged: changed.add,
              onLayerVisibilityChanged: (_, _) {},
              onWallsDetected: (_) {},
              onExport: (_, _, _) async {},
              onManageStoreys: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<ElementPaletteBar>(find.byType(ElementPaletteBar))
          .onSelectTool(StructuralDrawTool.select);
      await tester.pumpAndSettle();
      final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is Structural2dPainter,
      );
      Structural2dPainter plan() =>
          tester.widget<CustomPaint>(paint).painter as Structural2dPainter;
      Offset point(Offset cad) => tester
          .renderObject<RenderBox>(paint)
          .localToGlobal(plan().cadToScene(cad));
      await tester.tapAt(point(const Offset(5, 5)));
      await tester.pumpAndSettle();
      expect(find.text('Position & Nudge'), findsNothing);
      expect(find.text('Clear Distance'), findsNothing);
      await tester.ensureVisible(find.text('Drag+'));
      await tester.tap(find.text('Drag+'));
      await tester.pump();
      final before = changed.length;
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(changed.length, before);
      expect(plan().currentStorey.toJson(), initial.toJson());
      await tester.ensureVisible(find.text('Drag+'));
      await tester.tap(find.text('Drag+'));
      await tester.pump();
      final transform = tester
          .widget<BimTransformRenderer>(find.byType(BimTransformRenderer))
          .transformationController
          .value
          .clone();
      final gesture = await tester.startGesture(
        point(const Offset(5, 5)),
        kind: kind == 'wall'
            ? PointerDeviceKind.touch
            : PointerDeviceKind.mouse,
      );
      await gesture.moveTo(point(const Offset(7, 7)));
      await tester.pump(const Duration(milliseconds: 350));
      expect(changed.length, before);
      expect(
        tester
            .widget<BimTransformRenderer>(find.byType(BimTransformRenderer))
            .transformationController
            .value,
        transform,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      final result = changed.last.activeStorey;
      final originals = switch (kind) {
        'column' => result.columns.map((v) => v.toJson()).toList(),
        'wall' => result.shearWalls.map((v) => v.toJson()).toList(),
        _ => result.beams.map((v) => v.toJson()).toList(),
      };
      expect(originals, hasLength(2));
      final source = originals.first, copy = originals.last;
      expect(source['id'], isNot(copy['id']));
      for (final key in source.keys.where(
        (k) => !['id', 'name', 'center', 'start', 'end'].contains(k),
      )) {
        expect(copy[key], source[key], reason: key);
      }
      if (kind == 'column') {
        expect(result.columns.last.center.dx, closeTo(7, 1e-6));
        expect(result.columns.last.center.dy, closeTo(7, 1e-6));
        expect(result.columns.first.center, const Offset(5, 5));
      } else {
        expect((copy['start'] as Map)['dx'], closeTo(6, 1e-6));
        expect((copy['start'] as Map)['dy'], closeTo(7, 1e-6));
        expect((copy['end'] as Map)['dx'], closeTo(8, 1e-6));
        expect((copy['end'] as Map)['dy'], closeTo(7, 1e-6));
        expect(source['start'], {'dx': 4.0, 'dy': 5.0});
      }
      await tester.tap(find.byIcon(Icons.undo_rounded).first);
      await tester.pumpAndSettle();
      expect(plan().currentStorey.toJson(), initial.toJson());
      if (kind == 'beam') {
        final beforeMove = changed.length;
        final move = await tester.startGesture(
          point(const Offset(5, 5)),
          kind: PointerDeviceKind.mouse,
        );
        await move.moveTo(point(const Offset(6, 6)));
        await tester.pump();
        expect(changed.length, beforeMove);
        expect(plan().currentStorey.beams.single.start, const Offset(5, 6));
        await move.up();
        await tester.pumpAndSettle();
        expect(changed.length, beforeMove + 1);
        expect(changed.last.activeStorey.beams.single.end, const Offset(7, 6));
        await tester.tap(find.byIcon(Icons.undo_rounded).first);
        await tester.pumpAndSettle();
        expect(plan().currentStorey.toJson(), initial.toJson());
      }
      expect(tester.takeException(), isNull);
    });
  }
}
