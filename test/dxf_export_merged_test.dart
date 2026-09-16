import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';
import 'package:kotoview/src/core/services/dxf_exporter_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  group('DxfExporterService.exportMergedDxf', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dxf_merge_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('merges synthetic base DXF with imported DXF and annotations', () async {
      // Create minimal base DXF
      final baseDxfContent = '''  0
SECTION
  2
HEADER
  9
\$ACADVER
  1
AC1027
  0
ENDSEC
  0
SECTION
  2
TABLES
  0
TABLE
  2
LAYER
  0
LAYER
  2
BASE_LAYER
 70
0
 62
7
  0
ENDTAB
  0
ENDSEC
  0
SECTION
  2
BLOCKS
  0
BLOCK
  2
*MODEL_SPACE
 70
0
  0
ENDBLK
  0
ENDSEC
  0
SECTION
  2
ENTITIES
  0
LINE
  8
BASE_LAYER
 10
0.0
 20
0.0
 11
100.0
 21
100.0
  0
ENDSEC
  0
EOF
''';

      // Create imported DXF with a new layer, a custom block, and 2 entities
      final importedDxfContent = '''  0
SECTION
  2
HEADER
  9
\$ACADVER
  1
AC1027
  0
ENDSEC
  0
SECTION
  2
TABLES
  0
TABLE
  2
LAYER
  0
LAYER
  2
IMPORTED_LAYER
 70
0
 62
1
  0
ENDTAB
  0
ENDSEC
  0
SECTION
  2
BLOCKS
  0
BLOCK
  2
*MODEL_SPACE
 70
0
  0
ENDBLK
  0
BLOCK
  2
CUSTOM_BLOCK
 70
0
  0
LINE
  8
IMPORTED_LAYER
 10
0.0
 20
0.0
 11
5.0
 21
5.0
  0
ENDBLK
  0
ENDSEC
  0
SECTION
  2
ENTITIES
  0
CIRCLE
  8
IMPORTED_LAYER
 10
50.0
 20
50.0
 40
25.0
  0
TEXT
  8
IMPORTED_LAYER
 10
30.0
 20
30.0
 40
5.0
  1
Sample Label
  0
ENDSEC
  0
EOF
''';

      final baseFile = File('${tempDir.path}/base.dxf');
      final importedFile = File('${tempDir.path}/imported.dxf');
      final outputFile = File('${tempDir.path}/merged_output.dxf');

      await baseFile.writeAsString(baseDxfContent);
      await importedFile.writeAsString(importedDxfContent);

      final annotation = DxfAnnotation(
        id: 'ann_1',
        arrowTipCad: const Offset(40, 40),
        textPosCad: const Offset(45, 45),
        text: 'Merged Annotation Note',
        createdAt: DateTime.now(),
      );

      final exportedFile = await DxfExporterService.exportMergedDxf(
        baseFile: baseFile,
        importedFiles: [importedFile],
        annotations: [annotation],
        outputFile: outputFile,
      );

      expect(exportedFile.existsSync(), isTrue);

      // Parse the exported DXF back
      final parsedDoc = await DxfParser.parseFromFile(outputFile);

      // Verify layers: both BASE_LAYER and IMPORTED_LAYER must exist
      expect(parsedDoc.layers.containsKey('BASE_LAYER'), isTrue);
      expect(parsedDoc.layers.containsKey('IMPORTED_LAYER'), isTrue);

      // Verify blocks: CUSTOM_BLOCK must exist
      expect(parsedDoc.blocks.containsKey('CUSTOM_BLOCK'), isTrue);

      // Verify entities:
      // Base: 1 LINE
      // Imported: 1 CIRCLE, 1 TEXT
      // Annotations: 1 LEADER, 1 MTEXT
      // Total entities = 5
      expect(parsedDoc.entities.length, equals(5));

      final lines = parsedDoc.entities.whereType<DxfLine>().toList();
      final circles = parsedDoc.entities.whereType<DxfCircle>().toList();
      final texts = parsedDoc.entities.whereType<DxfText>().toList();

      expect(lines.isNotEmpty, isTrue);
      expect(circles.length, equals(1));
      expect(texts.length, equals(1)); // 1 DXF TEXT
      final mtexts = parsedDoc.entities.whereType<DxfMText>().toList();
      expect(mtexts.length, equals(1)); // 1 MTEXT annotation
      final leaders = parsedDoc.entities.whereType<DxfLeader>().toList();
      expect(leaders.length, equals(1)); // 1 LEADER annotation
    });

    test('merges real-world files kartala.dxf and VP.dwg when present', () async {
      final kartalaFile = File(r'C:\Users\Creator\Dropbox\test_files\kartala.dxf');
      final vpDwgFile = File(r'C:\Users\Creator\Dropbox\test_files\VP.dwg');

      if (!kartalaFile.existsSync() || !vpDwgFile.existsSync()) {
        return;
      }

      final vpDxfPath = await DwgConverterService.convertDwgToDxf(vpDwgFile.path);
      final vpDxfFile = File(vpDxfPath);

      final kartalaDoc = await DxfParser.parseFromFile(kartalaFile);
      final vpDoc = await DxfParser.parseFromFile(vpDxfFile);

      final outputFile = File('${tempDir.path}/kartala_plus_vp_merged.dxf');

      await DxfExporterService.exportMergedDxf(
        baseFile: kartalaFile,
        importedFiles: [vpDxfFile],
        annotations: const [],
        outputFile: outputFile,
      );

      expect(outputFile.existsSync(), isTrue);

      final mergedDoc = await DxfParser.parseFromFile(outputFile);
      expect(mergedDoc.totalEntities, equals(kartalaDoc.totalEntities + vpDoc.totalEntities));
      expect(mergedDoc.layers.length, greaterThanOrEqualTo(kartalaDoc.layers.length));
    });
  });
}
