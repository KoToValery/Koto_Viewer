import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/coordinate_system.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/widgets/dxf_import_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  testWidgets('DxfImportDialog renders "Import" button and "Import into Drawing" title', (tester) async {
    final currentDoc = DxfDocument(
      layers: {'0': DxfLayer(name: '0', colorIndex: 7)},
      blocks: {},
      entities: [],
      headerVars: {},
      entityStats: const {},
      bounds: const Rect.fromLTWH(0, 0, 100, 100),
    );
    final importedDoc = DxfDocument(
      layers: {'1': DxfLayer(name: '1', colorIndex: 1)},
      blocks: {},
      entities: [
        const DxfLine(
          p1: Offset(10, 10),
          p2: Offset(20, 20),
          layer: '1',
        ),
      ],
      headerVars: {},
      entityStats: const {},
      bounds: const Rect.fromLTWH(10, 10, 10, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DxfImportDialog(
            file: File('test_drawing.dwg'),
            currentDoc: currentDoc,
            importedDoc: importedDoc,
            activeCrs: CoordinateSystem.bgs2005Cadastral,
          ),
        ),
      ),
    );

    expect(find.text('Import into Drawing'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Import DXF'), findsNothing);
    expect(find.text('Import DXF into Drawing'), findsNothing);
    expect(find.text('test_drawing.dwg'), findsOneWidget);
  });

  test('DWG file converts to DXF and merges correctly on import', () async {
    final dwgFile = File(r'C:\Users\Creator\Dropbox\test_files\VP.dwg');
    if (!dwgFile.existsSync()) return;

    // Simulate the import conversion logic
    final convertedDxfPath = await DwgConverterService.convertDwgToDxf(dwgFile.path);
    final importedDoc = await DxfParser.parseFromFile(File(convertedDxfPath));

    expect(importedDoc.entities.isNotEmpty, isTrue);

    // Merge into an existing document
    final existingDoc = DxfDocument(
      layers: {'EXISTING': DxfLayer(name: 'EXISTING', colorIndex: 3)},
      blocks: {},
      entities: [
        const DxfLine(
          p1: Offset(322800, 4640500),
          p2: Offset(322850, 4640550),
          layer: 'EXISTING',
        ),
      ],
      headerVars: {},
      entityStats: const {},
      bounds: const Rect.fromLTRB(322800, 4640500, 322850, 4640550),
    );

    final mergedLayers = Map<String, DxfLayer>.from(existingDoc.layers);
    for (final entry in importedDoc.layers.entries) {
      if (!mergedLayers.containsKey(entry.key)) {
        mergedLayers[entry.key] = entry.value;
      }
    }

    final mergedEntities = List<DxfEntity>.from(existingDoc.entities)..addAll(importedDoc.entities);
    final mergedBounds = existingDoc.bounds.expandToInclude(importedDoc.bounds);

    final mergedDoc = DxfDocument(
      layers: mergedLayers,
      blocks: Map<String, DxfBlock>.from(existingDoc.blocks)..addAll(importedDoc.blocks),
      entities: mergedEntities,
      headerVars: existingDoc.headerVars,
      entityStats: const {},
      bounds: mergedBounds,
    );

    expect(mergedDoc.entities.length, equals(existingDoc.entities.length + importedDoc.entities.length));
    expect(mergedDoc.layers.containsKey('EXISTING'), isTrue);
    expect(mergedDoc.layers.containsKey('C-TOPO-MAJR'), isTrue);
  });
}
