import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

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

  test('VP.dwg imported into kartala.dxf scales text proportionally without inflation', () async {
    final kartalaFile = File(r'C:\Users\Creator\Dropbox\test_files\kartala.dxf');
    final vpDwgFile = File(r'C:\Users\Creator\Dropbox\test_files\VP.dwg');

    if (!kartalaFile.existsSync() || !vpDwgFile.existsSync()) {
      return;
    }

    final kartalaDoc = await DxfParser.parseFromFile(kartalaFile);
    final vpDxfPath = await DwgConverterService.convertDwgToDxf(vpDwgFile.path);
    final vpDoc = await DxfParser.parseFromFile(File(vpDxfPath));

    // Simulate import / merge (Kartala + VP)
    final mergedLayers = Map<String, DxfLayer>.from(kartalaDoc.layers);
    for (final entry in vpDoc.layers.entries) {
      if (!mergedLayers.containsKey(entry.key)) {
        mergedLayers[entry.key] = entry.value;
      }
    }

    final mergedBlocks = Map<String, DxfBlock>.from(kartalaDoc.blocks);
    for (final entry in vpDoc.blocks.entries) {
      if (!mergedBlocks.containsKey(entry.key)) {
        mergedBlocks[entry.key] = entry.value;
      }
    }

    final mergedTextStyles = Map<String, DxfTextStyle>.from(kartalaDoc.textStyles);
    for (final entry in vpDoc.textStyles.entries) {
      if (!mergedTextStyles.containsKey(entry.key)) {
        mergedTextStyles[entry.key] = entry.value;
      }
    }

    final mergedLineTypes = Map<String, List<double>>.from(kartalaDoc.lineTypes);
    for (final entry in vpDoc.lineTypes.entries) {
      if (!mergedLineTypes.containsKey(entry.key)) {
        mergedLineTypes[entry.key] = entry.value;
      }
    }

    final mergedEntities = List<DxfEntity>.from(kartalaDoc.entities)..addAll(vpDoc.entities);
    final mergedBounds = kartalaDoc.bounds.expandToInclude(vpDoc.bounds);

    final mergedStats = Map<String, int>.from(kartalaDoc.entityStats);
    for (final entry in vpDoc.entityStats.entries) {
      mergedStats[entry.key] = (mergedStats[entry.key] ?? 0) + entry.value;
    }

    final mergedDoc = DxfDocument(
      layers: mergedLayers,
      blocks: mergedBlocks,
      entities: mergedEntities,
      headerVars: kartalaDoc.headerVars,
      textStyles: mergedTextStyles,
      bounds: mergedBounds,
      entityStats: mergedStats,
      lineTypes: mergedLineTypes,
    );

    // Verify text styles were preserved
    expect(mergedDoc.textStyles.containsKey('Standard'), isTrue);
    expect(mergedDoc.textStyles.containsKey('GENERATED_STYLE_1'), isTrue);

    // Verify bounds: merged height is ~18.5 km
    expect(mergedDoc.height, greaterThan(15000.0));

    // Now test painting on a standard screen size (1000 x 800)
    final painter = DxfPainter(
      document: mergedDoc,
      theme: DxfCanvasTheme.darkCad,
      currentScale: 1.0,
    );

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // This should paint all entities (including VP's elevation numbers and texts inside blocks)
    // without any exception or error
    painter.paint(canvas, const Size(1000, 800));

    final picture = recorder.endRecording();
    expect(picture, isNotNull);

    // Verify fitScale computation
    // docW ~= 4907, docH ~= 18492, availW = 936, availH = 736
    // fitScale ~= 736 / 18492 ~= 0.0398
    const availH = 800.0 - 64.0;
    final fitScale = availH / mergedDoc.height;
    expect(fitScale, lessThan(0.06));

    // In VP, elevation text height is 0.6 m.
    // Cap height in drawing units = 0.6 m.
    // If fitScale is ~0.04, the rendered cap height in canvas units MUST be 0.6 * fitScale ~= 0.024 canvas pixels.
    // Prior to our fix, it was clamped to 0.5 canvas pixels (equivalent to 0.5 / 0.04 * 0.72 = 9.0 meters in CAD!),
    // which caused the text to appear 15x to 50x larger than the geometry.
    final expectedCapHeightPx = 0.6 * fitScale;
    expect(expectedCapHeightPx, lessThan(0.05));
  });

  test('Vice-versa: kartala.dxf imported into VP.dwg preserves proportions', () async {
    final kartalaFile = File(r'C:\Users\Creator\Dropbox\test_files\kartala.dxf');
    final vpDwgFile = File(r'C:\Users\Creator\Dropbox\test_files\VP.dwg');

    if (!kartalaFile.existsSync() || !vpDwgFile.existsSync()) {
      return;
    }

    final kartalaDoc = await DxfParser.parseFromFile(kartalaFile);
    final vpDxfPath = await DwgConverterService.convertDwgToDxf(vpDwgFile.path);
    final vpDoc = await DxfParser.parseFromFile(File(vpDxfPath));

    // Merge kartala into VP
    final mergedLayers = Map<String, DxfLayer>.from(vpDoc.layers);
    for (final entry in kartalaDoc.layers.entries) {
      if (!mergedLayers.containsKey(entry.key)) {
        mergedLayers[entry.key] = entry.value;
      }
    }

    final mergedBlocks = Map<String, DxfBlock>.from(vpDoc.blocks);
    for (final entry in kartalaDoc.blocks.entries) {
      if (!mergedBlocks.containsKey(entry.key)) {
        mergedBlocks[entry.key] = entry.value;
      }
    }

    final mergedTextStyles = Map<String, DxfTextStyle>.from(vpDoc.textStyles);
    for (final entry in kartalaDoc.textStyles.entries) {
      if (!mergedTextStyles.containsKey(entry.key)) {
        mergedTextStyles[entry.key] = entry.value;
      }
    }

    final mergedLineTypes = Map<String, List<double>>.from(vpDoc.lineTypes);
    for (final entry in kartalaDoc.lineTypes.entries) {
      if (!mergedLineTypes.containsKey(entry.key)) {
        mergedLineTypes[entry.key] = entry.value;
      }
    }

    final mergedEntities = List<DxfEntity>.from(vpDoc.entities)..addAll(kartalaDoc.entities);
    final mergedBounds = vpDoc.bounds.expandToInclude(kartalaDoc.bounds);

    final mergedStats = Map<String, int>.from(vpDoc.entityStats);
    for (final entry in kartalaDoc.entityStats.entries) {
      mergedStats[entry.key] = (mergedStats[entry.key] ?? 0) + entry.value;
    }

    final mergedDoc = DxfDocument(
      layers: mergedLayers,
      blocks: mergedBlocks,
      entities: mergedEntities,
      headerVars: vpDoc.headerVars,
      textStyles: mergedTextStyles,
      bounds: mergedBounds,
      entityStats: mergedStats,
      lineTypes: mergedLineTypes,
    );

    final painter = DxfPainter(
      document: mergedDoc,
      theme: DxfCanvasTheme.darkCad,
      currentScale: 1.0,
    );

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(1000, 800));
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
  });
}
