import 'package:kotoview/src/features/bim_editing/widgets/bim_transform_renderer.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/widgets/element_palette_bar.dart';

void main() {
  testWidgets('menu sizes follow preset and selected element rotation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const source = DxfLine(
      p1: Offset(0, 0),
      p2: Offset(10, 10),
      colorIndex: 1,
      lineWeight: .70,
    );
    final document = DxfDocument(
      entities: [source],
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
          title: 'Display',
          initialCadBounds: document.bounds,
          initialProject: const StructuralProject(
            storeys: [
              StoreyLevel(
                id: 'g',
                name: 'g',
                columns: [
                  StructuralColumn(
                    id: 'c',
                    center: Offset(3, 5),
                    width: .25,
                    height: .30,
                  ),
                ],
                shearWalls: [
                  StructuralShearWall(
                    id: 'w',
                    start: Offset(6, 5),
                    end: Offset(7.5, 5),
                    thickness: .25,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    ElementPaletteBar palette() =>
        tester.widget<ElementPaletteBar>(find.byType(ElementPaletteBar));
    Structural2dPainter plan() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<Structural2dPainter>()
        .first;
    final underlay = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<DxfPainter>()
        .first;
    expect(underlay.drawingColorOverride, const Color(0xFF92979C));
    expect(underlay.drawingStrokeWidthOverride, .8);
    expect(source.colorIndex, 1);
    expect(source.lineWeight, .70);
    palette().onSelectTool(StructuralDrawTool.column);
    await tester.pumpAndSettle();
    expect(find.text('25×30 cm'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.rotate_90_degrees_ccw));
    await tester.pumpAndSettle();
    expect(find.text('30×25 cm'), findsOneWidget);
    palette().onSelectTool(StructuralDrawTool.shearWall);
    await tester.pumpAndSettle();
    expect(find.text('25×150 cm'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.rotate_90_degrees_ccw));
    await tester.pumpAndSettle();
    expect(find.text('150×25 cm'), findsOneWidget);
    expect(palette().currentWallLength, 1.5);
    expect(palette().currentWallThickness, .25);
    final selectTool = palette().onSelectTool;
    selectTool(StructuralDrawTool.column);
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byType(BimTransformRenderer).first);
    await tester.tapAt(origin + plan().cadToScene(const Offset(3, 5)));
    await tester.pumpAndSettle();
    expect(find.textContaining('25 x 30 cm'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.rotate_right_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('30 x 25 cm'), findsOneWidget);
    expect(
      plan().currentStorey.columns.single.rotationRad,
      closeTo(math.pi / 2, 1e-8),
    );
    selectTool(StructuralDrawTool.shearWall);
    await tester.pumpAndSettle();
    await tester.tapAt(origin + plan().cadToScene(const Offset(6.75, 5)));
    await tester.pumpAndSettle();
    expect(find.textContaining('150 x 25 cm'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.rotate_right_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('25 x 150 cm'), findsOneWidget);
    expect(plan().currentStorey.shearWalls.single.length, closeTo(1.5, 1e-8));
    expect(tester.takeException(), isNull);
  });
}
