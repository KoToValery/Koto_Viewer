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

void main() {
  testWidgets(
    'BIM touch measurement previews above the finger, commits on release and cancels pinch',
    (tester) async {
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
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            title: 'Measure',
            initialProject: const StructuralProject(
              storeys: [StoreyLevel(id: 'g', name: 'Ground')],
            ),
            bimContext: StructuralBimContext(
              underlaysByStorey: {'g': doc},
              projectBounds: doc.bounds,
              cadUnitsPerMeter: 1,
              onProjectChanged: (_) {},
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
          .onSelectTool(StructuralDrawTool.measure);
      await tester.pumpAndSettle();
      Structural2dPainter plan() =>
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) =>
                          w is CustomPaint && w.painter is Structural2dPainter,
                    ),
                  )
                  .painter
              as Structural2dPainter;
      final first = await tester.startGesture(const Offset(400, 400));
      await tester.pump();
      final pointer = tester
          .widget<StructuralPointerOverlay>(
            find.byType(StructuralPointerOverlay),
          )
          .painter;
      expect(pointer.touchPos - pointer.targetPos, const Offset(0, 56));
      expect(plan().measurementStartCad, isNull);
      final start = plan().currentCursorCad;
      await first.up();
      await tester.pump();
      expect(plan().measurementStartCad, start);

      final second = await tester.startGesture(const Offset(600, 400));
      await second.moveTo(const Offset(650, 450));
      await tester.pump(const Duration(milliseconds: 350));
      final preview = tester
          .widget<StructuralPointerOverlay>(
            find.byType(StructuralPointerOverlay),
          )
          .painter;
      expect(preview.liveDimensionText, isNotNull);
      final end = plan().currentCursorCad;
      await second.up();
      await tester.pump();
      expect(plan().activeMeasurement?.$1, start);
      expect(plan().activeMeasurement?.$2, end);
      expect(plan().measurementStartCad, isNull);

      final a = await tester.startGesture(const Offset(400, 400), pointer: 3);
      await tester.pump();
      final b = await tester.startGesture(const Offset(600, 400), pointer: 4);
      await tester.pump();
      await a.moveTo(const Offset(380, 400));
      await b.moveTo(const Offset(620, 400));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(plan().measurementStartCad, isNull);
      expect(plan().activeMeasurement?.$1, start);
      expect(plan().activeMeasurement?.$2, end);
      expect(find.byType(StructuralPointerOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
