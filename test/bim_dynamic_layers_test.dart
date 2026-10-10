import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/widgets/dxf_layer_sheet.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/widgets/element_palette_bar.dart';
import 'bim_plan_selection_and_manual_stairs_test.dart' as f;
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';

DxfDocument drawing() => DxfDocument(
  entities: [],
  layers: {},
  blocks: {},
  headerVars: {},
  entityStats: {},
  bounds: const Rect.fromLTWH(0, 0, 10, 10),
);

void main() {
  test(
    'migration removes only owned CAD copies and keeps analysis and architecture',
    () {
      final doc = drawing();
      for (final name in [
        'architecture',
        'BIM_Walls',
        'BIM_Slabs',
        'BIM_Slab_Candidates',
        'BIM_Axis',
      ]) {
        doc.layers[name] = DxfLayer(name: name);
        doc.entities.add(
          DxfLine(p1: Offset.zero, p2: const Offset(1, 1), layer: name),
        );
      }
      doc.headerVars[BimUnderlayMetadata.key] = jsonEncode({
        'version': 6,
        'complete': true,
        'wallLayer': 'BIM_Walls',
        'layers': ['BIM_Walls', 'BIM_Slabs', 'BIM_Slab_Candidates'],
        'blocks': [],
        'visibility': {'architecture': true, 'BIM_Axis': true},
        'slabEnvelope': {
          'contours': [
            [
              [0, 0],
              [1, 0],
              [1, 1],
              [0, 1],
            ],
          ],
        },
      });
      BimUnderlayMetadata.ensureDynamicLayers(doc);
      final names = BimUnderlayMetadata.dynamicLayers(doc);
      expect(names, {'axes': 'BIM_Axis_1', 'slabs': 'BIM_Slabs'});
      expect(doc.entities.map((e) => e.layer), [
        'architecture',
        'BIM_Walls',
        'BIM_Axis',
      ]);
      expect(doc.layers.containsKey('BIM_Slab_Candidates'), isFalse);
      expect(
        BimUnderlayMetadata.read(doc)!['slabEnvelope']['contours'],
        hasLength(1),
      );
      doc.layers[names['slabs']]!.isVisible = false;
      BimUnderlayMetadata.setFiltered(doc, true);
      expect(doc.layers[names['axes']]!.isVisible, isTrue);
      expect(doc.layers[names['slabs']]!.isVisible, isFalse);
      BimUnderlayMetadata.setFiltered(doc, false);
      expect(doc.layers['architecture']!.isVisible, isTrue);
      expect(doc.layers[names['axes']]!.isVisible, isTrue);
      BimUnderlayMetadata.ensureDynamicLayers(doc);
      expect(BimUnderlayMetadata.dynamicLayers(doc), names);
    },
  );

  testWidgets(
    'layer switches hide live objects and save visibility without deleting the model',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = drawing();
      var visibility = <String, bool>{};
      final p = f.plates();
      final project = p.copyWith(
        storeys: [
          p.storeys.first.copyWith(
            gridAxes: [
              const StructuralGridAxis(
                id: 'a',
                start: Offset(1, 1),
                end: Offset(1, 9),
                name: '1',
              ),
            ],
          ),
          ...p.storeys.skip(1),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            title: 'Layers',
            initialProject: project,
            bimContext: StructuralBimContext(
              underlaysByStorey: {'g': doc, 'f': doc, 'r': doc},
              projectBounds: doc.bounds,
              cadUnitsPerMeter: 1,
              onProjectChanged: (_) {},
              onLayerVisibilityChanged: (_, value) => visibility = value,
              onWallsDetected: (_) {},
              onExport: (_, _, _) async {},
              onManageStoreys: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Structural2dPainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<Structural2dPainter>()
          .first;
      final before = jsonEncode(painter().currentStorey.toJson());
      tester
          .widget<ElementPaletteBar>(find.byType(ElementPaletteBar))
          .onOpenLayerManager!();
      await tester.pumpAndSettle();
      expect(find.text('BIM_Axis'), findsOneWidget);
      expect(find.text('BIM_Slabs'), findsOneWidget);
      expect(
        tester
            .widget<DxfLayerSheet>(find.byType(DxfLayerSheet))
            .additionalLayerCounts['BIM_Slabs'],
        2,
      );
      for (final switchWidget
          in tester.widgetList<Switch>(find.byType(Switch)).toList()) {
        switchWidget.onChanged!(false);
        await tester.pumpAndSettle();
      }
      expect(painter().showSlabs, isFalse);
      expect(painter().showGridAxes, isFalse);
      expect(visibility['BIM_Slabs'], isFalse);
      expect(visibility['BIM_Axis'], isFalse);
      expect(jsonEncode(painter().currentStorey.toJson()), before);
      expect(doc.entities, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'turning the BIM filter off selects Layers, enabling it keeps the chosen tool',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final doc = drawing();
      doc.layers['BIM_Walls'] = DxfLayer(name: 'BIM_Walls');
      doc.entities.add(
        const DxfLine(p1: Offset(1, 1), p2: Offset(9, 1), layer: 'BIM_Walls'),
      );
      doc.layers['architecture'] = DxfLayer(
        name: 'architecture',
        isVisible: false,
      );
      doc.headerVars[BimUnderlayMetadata.key] = jsonEncode({
        'version': BimUnderlayMetadata.version,
        'complete': true,
        'hasResults': true,
        'wallLayer': 'BIM_Walls',
        'layers': ['BIM_Walls'],
        'visibleLayers': ['BIM_Walls'],
        'visibility': {'architecture': true},
        'blocks': [],
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            title: 'Filter',
            initialProject: f.plates(),
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
      ElementPaletteBar palette() =>
          tester.widget<ElementPaletteBar>(find.byType(ElementPaletteBar));
      palette().onSelectTool(StructuralDrawTool.column);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.filter_alt_rounded));
      await tester.pumpAndSettle();
      expect(palette().activeTool, StructuralDrawTool.layers);
      expect(doc.layers['architecture']!.isVisible, isTrue);
      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();
      expect(palette().activeTool, StructuralDrawTool.layers);
      expect(doc.layers['architecture']!.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
