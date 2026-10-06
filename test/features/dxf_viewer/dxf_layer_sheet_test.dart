import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/l10n_extensions.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_reader.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_writer.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/widgets/dxf_layer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DxfDocument createTestDocument(Map<String, DxfLayer> layers, [List<DxfEntity>? entities]) {
    return DxfDocument(
      layers: layers,
      blocks: {},
      entities: entities ??
          layers.keys
              .map((name) => DxfLine(p1: Offset.zero, p2: const Offset(10, 10), layer: name))
              .toList(),
      headerVars: {},
      bounds: const Rect.fromLTWH(0, 0, 100, 100),
      entityStats: {},
    );
  }

  Widget buildTestWidget({
    required DxfDocument document,
    VoidCallback? onLayersChanged,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: DxfLayerSheet(
          document: document,
          onLayersChanged: onLayersChanged ?? () {},
          isDark: false,
        ),
      ),
    );
  }

  group('DxfLayer Lineweight Normalization', () {
    test('DxfLayer normalizes float32 precision noise to 2 decimal places', () {
      final layer = DxfLayer(
        name: 'WALLS',
        customLineweight: 0.30000001192092896,
      );
      expect(layer.customLineweight, equals(0.30));

      layer.customLineweight = 0.3499999940395355;
      expect(layer.customLineweight, equals(0.35));

      layer.customLineweight = 0.11999999731779099;
      expect(layer.customLineweight, equals(0.12));

      layer.customLineweight = 0.699999988079071;
      expect(layer.customLineweight, equals(0.70));

      layer.customLineweight = null;
      expect(layer.customLineweight, isNull);
    });

    test('KCAD Binary serialization round-trips customLineweight cleanly', () {
      final doc = createTestDocument({
        'WALLS': DxfLayer(name: 'WALLS', customLineweight: 0.30),
        'DOORS': DxfLayer(name: 'DOORS', customLineweight: 0.35),
        'WINDOWS': DxfLayer(name: 'WINDOWS', customLineweight: 0.12),
      });

      final bytes = KcadWriter.write(doc);
      final readDoc = KcadReader.read(bytes);

      expect(readDoc.layers['WALLS']?.customLineweight, equals(0.30));
      expect(readDoc.layers['DOORS']?.customLineweight, equals(0.35));
      expect(readDoc.layers['WINDOWS']?.customLineweight, equals(0.12));
    });
  });

  group('DxfLayerSheet Dropdown Safety', () {
    testWidgets('Renders successfully with 0.30000001192092896 without assertion error', (tester) async {
      // Create layer with the exact double value that caused the crash
      final layer = DxfLayer(name: 'WALLS');
      layer.customLineweight = 0.30000001192092896;

      final doc = createTestDocument({'WALLS': layer});

      await tester.pumpWidget(buildTestWidget(document: doc));
      await tester.pumpAndSettle();

      // Verify that no exception was thrown and the sheet rendered
      expect(find.text('WALLS'), findsOneWidget);
      expect(find.byType(DropdownButton<double?>), findsNWidgets(2)); // Global bar + 1 layer
    });

    testWidgets('Renders successfully with various standard lineweights and null', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final doc = createTestDocument({
        'L_NULL': DxfLayer(name: 'L_NULL', customLineweight: null),
        'L_12': DxfLayer(name: 'L_12', customLineweight: 0.12),
        'L_25': DxfLayer(name: 'L_25', customLineweight: 0.25),
        'L_30': DxfLayer(name: 'L_30', customLineweight: 0.30),
        'L_35': DxfLayer(name: 'L_35', customLineweight: 0.35),
        'L_50': DxfLayer(name: 'L_50', customLineweight: 0.50),
        'L_70': DxfLayer(name: 'L_70', customLineweight: 0.70),
      });

      await tester.pumpWidget(buildTestWidget(document: doc));
      await tester.pumpAndSettle();

      expect(find.text('L_NULL'), findsOneWidget);
      expect(find.text('L_30'), findsOneWidget);
      expect(find.text('L_70'), findsOneWidget);
    });

    testWidgets('Renders exotic custom lineweight (e.g. 0.85 mm) without error', (tester) async {
      final layer = DxfLayer(name: 'CUSTOM');
      layer.customLineweight = 0.85;

      final doc = createTestDocument({'CUSTOM': layer});

      await tester.pumpWidget(buildTestWidget(document: doc));
      await tester.pumpAndSettle();

      expect(find.text('CUSTOM'), findsOneWidget);
      expect(find.text('0.85 mm'), findsOneWidget);
    });

    testWidgets('Localizes correctly in Bulgarian', (tester) async {
      final doc = createTestDocument({
        'WALLS': DxfLayer(name: 'WALLS', customLineweight: 0.30),
      });

      await tester.pumpWidget(buildTestWidget(document: doc, locale: const Locale('bg')));
      await tester.pumpAndSettle();

      expect(find.text('CAD Слоеве'), findsOneWidget);
      expect(find.text('Покажи всички'), findsOneWidget);
      expect(find.text('Скрий всички'), findsOneWidget);
      expect(find.text('Дебелина за всички:'), findsOneWidget);
    });
  });
}
