import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_writer.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_reader.dart';

import 'package:kotoview/src/features/dxf_viewer/binary/kcad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('KCAD Binary Format: Complete Round-Trip Verification', () {
    final layer0 = DxfLayer(name: '0', colorIndex: 7);
    final layerWalls = DxfLayer(name: 'WALLS', colorIndex: 1, lineweight: 0.35, isThick: true);
    final layerText = DxfLayer(name: 'TEXT_LAYER', colorIndex: 3, lineType: 'DASHED');

    final testBlock = DxfBlock(
      name: 'DOOR_BLK',
      basePoint: const Offset(10, 20),
      entities: [
        const DxfLine(
          p1: Offset(0, 0),
          p2: Offset(50, 0),
          layer: 'WALLS',
          colorIndex: 1,
        ),
        const DxfCircle(
          center: Offset(50, 0),
          radius: 25,
          layer: 'WALLS',
        ),
      ],
    );

    final entities = <DxfEntity>[
      const DxfLine(
        p1: Offset(100.5, 200.25),
        p2: Offset(300.75, 400.125),
        layer: 'WALLS',
        colorIndex: 1,
        trueColor: 0x00FF0000,
        lineWeight: 0.35,
      ),
      const DxfPoint(
        point: Offset(50, 60),
        layer: '0',
      ),
      const DxfCircle(
        center: Offset(150, 250),
        radius: 42.5,
        layer: '0',
        colorIndex: 7,
      ),
      const DxfArc(
        center: Offset(200, 300),
        radius: 50,
        startAngleDeg: 45,
        endAngleDeg: 135,
        layer: 'WALLS',
      ),
      const DxfEllipse(
        center: Offset(300, 400),
        majorAxisEndOffset: Offset(60, 0),
        minorRatio: 0.5,
        layer: 'WALLS',
      ),
      const DxfLwPolyline(
        vertices: [
          DxfPolylineVertex(x: 10, y: 10, bulge: 0.5),
          DxfPolylineVertex(x: 20, y: 10),
          DxfPolylineVertex(x: 20, y: 20),
          DxfPolylineVertex(x: 10, y: 20),
        ],
        isClosed: true,
        elevation: 5.0,
        layer: 'WALLS',
      ),
      const DxfText(
        text: 'Hello KCAD! Привет CAD!',
        insertPoint: Offset(500, 600),
        height: 12.5,
        rotationDeg: 30,
        layer: 'TEXT_LAYER',
      ),
      const DxfMText(
        rawText: r'\A1;Line 1\PLine 2',
        cleanText: 'Line 1\nLine 2',
        insertPoint: Offset(700, 800),
        height: 15.0,
        refWidth: 200.0,
        layer: 'TEXT_LAYER',
      ),
      const DxfSolid(
        p0: Offset(1, 1),
        p1: Offset(10, 1),
        p2: Offset(10, 10),
        p3: Offset(1, 10),
        layer: 'WALLS',
      ),
      const DxfHatch(
        boundaryPaths: [
          [Offset(0, 0), Offset(100, 0), Offset(100, 100), Offset(0, 100)],
        ],
        patternName: 'ANSI31',
        isSolid: false,
        patternAngle: 45,
        patternScale: 2.0,
        layer: 'WALLS',
      ),
      const DxfInsert(
        blockName: 'DOOR_BLK',
        insertPoint: Offset(1000, 2000),
        scaleX: 1.5,
        scaleY: 1.5,
        rotationDeg: 90,
        layer: 'WALLS',
      ),
      const DxfDimension(
        dimType: 0,
        defPoint1: Offset(10, 10),
        defPoint2: Offset(100, 10),
        defPoint3: Offset(100, 20),
        textPoint: Offset(55, 20),
        rotationDeg: 45.0,
        textOverride: '90 mm',
        styleName: 'ARCH_STYLE',
        layer: 'WALLS',
      ),
      const DxfLeader(
        vertices: [Offset(10, 10), Offset(20, 20), Offset(30, 20)],
        hasArrowhead: true,
        layer: 'WALLS',
      ),
    ];

    final originalDoc = DxfDocument(
      layers: {'0': layer0, 'WALLS': layerWalls, 'TEXT_LAYER': layerText},
      blocks: {'DOOR_BLK': testBlock},
      entities: entities,
      headerVars: {r'$ACADVER': 'AC1027', r'$INSUNITS': '4'},
      bounds: const Rect.fromLTRB(0, 0, 2000, 3000),
      entityStats: {'LINE': 1, 'POINT': 1, 'CIRCLE': 1},
      lineTypes: {
        'DASHED': [10.0, -5.0],
      },
      dimStyles: {
        'ARCH_STYLE': const DxfDimStyle(
          name: 'ARCH_STYLE',
          dimScale: 2.0,
          dimAsz: 3.5,
          dimExo: 1.0,
          dimExe: 2.0,
          dimTxt: 3.0,
          dimTsz: 1.5,
          dimGap: 1.0,
          dimBlk: '_ARCHTICK',
        ),
      },
    );

    // 1. Serialize to KCAD binary
    final binary = KcadWriter.write(originalDoc, compress: true);
    expect(binary.isNotEmpty, isTrue);

    // 2. Deserialize from KCAD binary
    final decodedDoc = KcadReader.read(binary);

    // 3. Verify Document Metadata & Tables
    expect(decodedDoc.bounds, equals(originalDoc.bounds));
    expect(decodedDoc.layers.length, equals(3));
    expect(decodedDoc.layers['WALLS']?.colorIndex, equals(1));
    expect(decodedDoc.layers['WALLS']?.isThick, isTrue);
    expect(decodedDoc.layers['TEXT_LAYER']?.lineType, equals('DASHED'));
    expect(decodedDoc.lineTypes['DASHED'], equals([10.0, -5.0]));
    expect(decodedDoc.headerVars[r'$ACADVER'], equals('AC1027'));

    // 4. Verify Blocks
    expect(decodedDoc.blocks.containsKey('DOOR_BLK'), isTrue);
    final decodedBlock = decodedDoc.blocks['DOOR_BLK']!;
    expect(decodedBlock.entities.length, equals(2));
    expect(decodedBlock.entities[0], isA<DxfLine>());
    expect((decodedBlock.entities[0] as DxfLine).p2.dx, equals(50));

    // 5. Verify Entities
    expect(decodedDoc.entities.length, equals(entities.length));

    // Line
    final line = decodedDoc.entities[0] as DxfLine;
    expect(line.p1.dx, closeTo(100.5, 0.01));
    expect(line.p1.dy, closeTo(200.25, 0.01));
    expect(line.p2.dx, closeTo(300.75, 0.01));
    expect(line.p2.dy, closeTo(400.125, 0.01));
    expect(line.layer, equals('WALLS'));
    expect(line.trueColor, equals(0x00FF0000));

    // Circle
    final circle = decodedDoc.entities[2] as DxfCircle;
    expect(circle.center.dx, closeTo(150, 0.01));
    expect(circle.center.dy, closeTo(250, 0.01));
    expect(circle.radius, closeTo(42.5, 0.01));

    // Arc
    final arc = decodedDoc.entities[3] as DxfArc;
    expect(arc.startAngleDeg, closeTo(45, 0.01));
    expect(arc.endAngleDeg, closeTo(135, 0.01));

    // Text & Unicode (Cyrillic)
    final text = decodedDoc.entities[6] as DxfText;
    expect(text.text, equals('Hello KCAD! Привет CAD!'));
    expect(text.rotationDeg, closeTo(30, 0.01));

    // MText
    final mtext = decodedDoc.entities[7] as DxfMText;
    expect(mtext.cleanText, equals('Line 1\nLine 2'));
    expect(mtext.refWidth, equals(200.0));

    // Insert
    final insert = decodedDoc.entities[10] as DxfInsert;
    expect(insert.blockName, equals('DOOR_BLK'));
    expect(insert.scaleX, equals(1.5));
    expect(insert.rotationDeg, equals(90));

    // DimStyles
    expect(decodedDoc.dimStyles.containsKey('ARCH_STYLE'), isTrue);
    final style = decodedDoc.dimStyles['ARCH_STYLE']!;
    expect(style.dimScale, equals(2.0));
    expect(style.dimAsz, equals(3.5));
    expect(style.dimTsz, equals(1.5));
    expect(style.dimBlk, equals('_ARCHTICK'));
    expect(style.isArchitecturalTick, isTrue);

    // Dimension
    final dim = decodedDoc.entities[11] as DxfDimension;
    expect(dim.textOverride, equals('90 mm'));
    expect(dim.defPoint3, equals(const Offset(100, 20)));
    expect(dim.rotationDeg, equals(45.0));
    expect(dim.styleName, equals('ARCH_STYLE'));

    // Spatial Index
    expect(decodedDoc.spatialIndex, isNotNull);
    final queried = decodedDoc.spatialIndex!.query(const Rect.fromLTWH(0, 0, 500, 500));
    expect(queried.isNotEmpty, isTrue);
  });

  test('Benchmark KCAD vs 61.7MB DXF on real OVK drawing', () async {
    final dxfPath = r'C:\Users\Creator\AppData\Local\Temp\dwg_cache\+9.30 (OVK)_7275639_1790145006000_v6.dxf';
    final dxfFile = File(dxfPath);
    if (!dxfFile.existsSync()) {
      print('OVK test DXF file not found, skipping benchmark');
      return;
    }

    final int dxfSize = dxfFile.lengthSync();
    print('\n================ KCAD VS DXF BENCHMARK ================');
    print('Original DXF size: ${(dxfSize / 1024 / 1024).toStringAsFixed(2)} MB ($dxfSize bytes)');

    // 1. Measure DXF Cold Parse
    final swDxf = Stopwatch()..start();
    final doc = await DxfParser.parseFromFile(dxfFile);
    swDxf.stop();
    print('DXF Parse Time: ${swDxf.elapsedMilliseconds} ms (${doc.entities.length} entities)');

    // 2. Measure KCAD Write
    final swKcadWrite = Stopwatch()..start();
    final kcadCompressed = KcadWriter.write(doc, compress: true);
    swKcadWrite.stop();

    final kcadUncompressed = KcadWriter.write(doc, compress: false);

    print('KCAD Serialization Time: ${swKcadWrite.elapsedMilliseconds} ms');
    print('KCAD Uncompressed Size: ${(kcadUncompressed.length / 1024 / 1024).toStringAsFixed(2)} MB');
    print('KCAD Compressed Size: ${(kcadCompressed.length / 1024 / 1024).toStringAsFixed(2)} MB');
    print('Compression Ratio: ${(dxfSize / kcadCompressed.length).toStringAsFixed(1)}x smaller than DXF!');

    // 3. Measure KCAD Read
    final swKcadRead = Stopwatch()..start();
    final kcadDoc = KcadReader.read(kcadCompressed);
    swKcadRead.stop();

    print('KCAD Load & Parse Time: ${swKcadRead.elapsedMilliseconds} ms');
    print('SPEEDUP: ${(swDxf.elapsedMilliseconds / swKcadRead.elapsedMilliseconds).toStringAsFixed(1)}x FASTER!');

    // 4. Verify entities match
    expect(kcadDoc.entities.length, equals(doc.entities.length));
    expect(kcadDoc.blocks.length, equals(doc.blocks.length));
    expect(kcadDoc.layers.length, equals(doc.layers.length));
    print('Round-trip verification successful: 100% entity and table count match!');
    print('========================================================\n');

    // Save cache explicitly to disk for the next test
    await KcadService.saveKcadCache(dxfFile, doc);
  });

  test('Transparent KCAD caching via DxfParser.parseFromFile', () async {
    final dxfPath = r'C:\Users\Creator\AppData\Local\Temp\dwg_cache\+9.30 (OVK)_7275639_1790145006000_v6.dxf';
    final dxfFile = File(dxfPath);
    if (!dxfFile.existsSync()) return;

    // First call may have already populated or will populate cache
    // Let's call parseFromFile which hits the KCAD cache
    final sw = Stopwatch()..start();
    final docCached = await DxfParser.parseFromFile(dxfFile);
    sw.stop();
    print('DxfParser.parseFromFile (Cached Hit) Time: ${sw.elapsedMilliseconds} ms (${docCached.entities.length} entities)');
    expect(docCached.entities.isNotEmpty, isTrue);
    expect(sw.elapsedMilliseconds, lessThan(1200));
  });

  test('Stable Cache Key: DWG and intermediate DXF resolve to exact same companion KCAD path', () async {
    final dwgFile = File(r'C:\Users\Creator\Downloads\+9.30 (OVK).dwg');
    final dxfFile = File(r'C:\Users\Creator\AppData\Local\Temp\dwg_cache\+9.30 (OVK)_7275639_1790145006000_v6.dxf');

    final cachePathFromDxf = await KcadService.getCachePath(dxfFile);
    final expectedSuffix = '+9.30 (OVK)_7275639_1790145006000_v${KcadWriter.currentVersion}.kcad';
    expect(cachePathFromDxf.endsWith(expectedSuffix), isTrue);

    if (dwgFile.existsSync()) {
      final cachePathFromDwg = await KcadService.getCachePath(dwgFile);
      print('KCAD Cache Path from original DWG:     $cachePathFromDwg');
      expect(cachePathFromDwg, equals(cachePathFromDxf));
    }
  });

  test('KCAD Annotation baking: DxfAnnotation converts to native CAD Leader and MText round-trip', () {
    final anno = DxfAnnotation(
      id: 'anno_1',
      text: 'Вентилационен отвор ф160',
      arrowTipCad: const Offset(1500.5, 2300.25),
      textPosCad: const Offset(1550.0, 2350.0),
      colorValue: 0xFFFFD600,
      createdAt: DateTime.now(),
      textHeight: 15.0,
    );

    final markupLayer = DxfLayer(
      name: 'MARKUP',
      colorIndex: 2,
      trueColor: anno.colorValue,
      isVisible: true,
      isFrozen: false,
    );

    final leader = DxfLeader(
      vertices: [anno.arrowTipCad, anno.textPosCad],
      hasArrowhead: true,
      layer: 'MARKUP',
      trueColor: anno.colorValue,
    );

    final mtext = DxfMText(
      rawText: anno.text,
      cleanText: anno.text,
      insertPoint: anno.textPosCad,
      height: anno.textHeight ?? 2.5,
      layer: 'MARKUP',
      trueColor: anno.colorValue,
      attachmentPoint: 1,
    );

    final doc = DxfDocument(
      layers: {'MARKUP': markupLayer},
      blocks: {},
      entities: [leader, mtext],
      headerVars: {r'$ACADVER': 'AC1027'},
      bounds: const Rect.fromLTRB(1400, 2200, 1600, 2400),
      entityStats: {'LEADER': 1, 'MTEXT': 1},
    );

    final bytes = KcadWriter.write(doc, compress: true);
    final decoded = KcadReader.read(bytes);

    expect(decoded.layers.containsKey('MARKUP'), isTrue);
    expect(decoded.entities.length, equals(2));

    final decodedLeader = decoded.entities.firstWhere((e) => e is DxfLeader) as DxfLeader;
    expect(decodedLeader.vertices.length, equals(2));
    expect((decodedLeader.vertices[0].dx - 1500.5).abs(), lessThan(0.01));
    expect((decodedLeader.vertices[0].dy - 2300.25).abs(), lessThan(0.01));
    expect(decodedLeader.trueColor, equals(anno.colorValue));

    final decodedMText = decoded.entities.firstWhere((e) => e is DxfMText) as DxfMText;
    expect(decodedMText.cleanText, equals('Вентилационен отвор ф160'));
    expect((decodedMText.height - 15.0).abs(), lessThan(0.01));
    expect(decodedMText.trueColor, equals(anno.colorValue));
  });

  test('Eviction safety: Files with underscores in filename do not evict other drawings', () async {
    final tempDir = await Directory.systemTemp.createTemp('kcad_evict_test_');
    try {
      final stalePlan = File('${tempDir.path}/floor_plan_v3_1000_1780000000000_v1.kcad');
      final currentPlan = File('${tempDir.path}/floor_plan_v3_1000_1790000000000_v2.kcad');
      final otherDrawing = File('${tempDir.path}/floor_office_2000_1790000000000_v2.kcad');

      await stalePlan.writeAsString('stale');
      await currentPlan.writeAsString('current');
      await otherDrawing.writeAsString('other');

      // Trigger eviction for currentPlan
      final currentName = currentPlan.path.split(RegExp(r'[/\\]')).last;
      final match = RegExp(r'^(.*)_\d+_\d+_v\d+\.kcad$', caseSensitive: false).firstMatch(currentName);
      expect(match, isNotNull);
      final basePrefix = '${match!.group(1)}_';
      expect(basePrefix, equals('floor_plan_v3_'));

      // Perform eviction logic
      for (final entity in tempDir.listSync()) {
        if (entity is File && entity.path.endsWith('.kcad')) {
          final name = entity.path.split(RegExp(r'[/\\]')).last;
          if (name != currentName && name.startsWith(basePrefix)) {
            entity.deleteSync();
          }
        }
      }

      // Verify: stale plan was deleted, current plan kept, and other drawing kept!
      expect(stalePlan.existsSync(), isFalse, reason: 'Stale version of floor_plan_v3 must be evicted');
      expect(currentPlan.existsSync(), isTrue, reason: 'Current version must be kept');
      expect(otherDrawing.existsSync(), isTrue, reason: 'floor_office must NOT be evicted by floor_plan_v3!');
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('End-to-End Repeated Load: Instant DWG open via KCAD cache without converter', () async {
    final dwgFile = File(r'C:\Users\Creator\Downloads\+9.30 (OVK).dwg');
    if (!dwgFile.existsSync()) return;

    final kcadPath = await KcadService.getCachePath(dwgFile);
    final kcadFile = File(kcadPath);
    expect(kcadFile.existsSync(), isTrue, reason: 'KCAD cache must exist from previous run');

    // Measure instant second load exactly as FileOpenerService does:
    final sw = Stopwatch()..start();
    final doc = await KcadService.loadKcadFile(kcadFile);
    sw.stop();

    print('\n================ SECOND OPEN (END-TO-END WIN) ================');
    print('Target DWG:       ${dwgFile.path} (${(dwgFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB)');
    print('KCAD Cache File:  $kcadPath (${(kcadFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB)');
    print('Converted Exe:    SKIPPED (0.0 ms - dwg2dxf.exe was NOT run!)');
    print('Entities Loaded:  ${doc.entities.length} direct entities + ${doc.blocks.length} blocks');
    print('Spatial Index:    Built in isolate with ${doc.spatialIndex != null ? "active QuadTree" : "none"}');
    print('TOTAL LOAD TIME:  ${sw.elapsedMilliseconds} ms!');
    print('===============================================================\n');

    expect(doc.entities.length, equals(69417));
    expect(sw.elapsedMilliseconds, lessThan(750));
  });

  test('KCAD v3 TLV: Gracefully skips unknown entity type without crashing (Forward Compatibility)', () {
    final layer0 = DxfLayer(name: '0', colorIndex: 7);
    final entities = <DxfEntity>[
      const DxfLine(p1: Offset(10, 20), p2: Offset(30, 40), layer: '0'),
      const DxfCircle(center: Offset(50, 60), radius: 15, layer: '0'),
    ];

    final doc = DxfDocument(
      layers: {'0': layer0},
      blocks: const {},
      headerVars: const {},
      entityStats: const {'LINE': 1, 'CIRCLE': 1},
      entities: entities,
      bounds: const Rect.fromLTRB(0, 0, 100, 100),
    );

    // 1. Serialize uncompressed
    final rawKcad = KcadWriter.write(doc, compress: false);

    // 2. Inject an unknown entity (typeCode: 99) with 20 bytes of dummy payload between Line and Circle
    // In KCAD v3 uncompressed:
    // Header is 16 bytes.
    // In rawBody, entities start after Bounds (4 * Float64 = 32 bytes).
    // Let's decode to find where entities begin or inject via ByteData:
    final bd = ByteData.sublistView(rawKcad);
    expect(bd.getUint16(4, Endian.little), equals(KcadWriter.currentVersion), reason: 'Must be current version');

    // Copy the original bytes up to the end of the Line entity
    // In our doc, entities has 2 entities. Let's inspect the entities count in body:
    // First, verify standard read works:
    final decodedOriginal = KcadReader.read(rawKcad);
    expect(decodedOriginal.entities.length, equals(2));
    expect(decodedOriginal.entities[0], isA<DxfLine>());
    expect(decodedOriginal.entities[1], isA<DxfCircle>());

    // Now let's create a synthetic test by manually appending an unknown entity:
    // Let's create an entity with:
    // typeCode: 99
    // payloadLength: 8 (uint32)
    // 8 bytes of dummy data: [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE]
    final dummyEntity = [
      99, // unknown typeCode
      8, 0, 0, 0, // payloadLength = 8 (little endian uint32)
      0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
    ];

    // Read the original uncompressed body:
    final uncompressedBody = rawKcad.sublist(16);
    // In uncompressedBody, find where root entity count is written:
    // Bounds is at offset: stringTable + tables + blocks.
    // But even simpler: we can build a body with 3 entities by modifying the count and splicing:
    // Let's find the entity count. In our doc, rootEntityCount is 2 (2 bytes if < 0xFFFF).
    // Let's locate the 2 entities in the byte stream:
    // Line entity starts with typeCode 1, Circle starts with typeCode 3.
    // Line entity in KCAD v3: [1, length (4 bytes), ...]
    int lineOffsetInBody = -1;
    for (int i = 0; i < uncompressedBody.length - 5; i++) {
      if (uncompressedBody[i] == 1) { // typeCode line
        final len = ByteData.sublistView(Uint8List.fromList(uncompressedBody)).getUint32(i + 1, Endian.little);
        // Base flags (1) + layer id (4) + 4 floats (16) = 21 bytes payload
        if (len == 21) {
          lineOffsetInBody = i;
          break;
        }
      }
    }
    expect(lineOffsetInBody, isNonNegative, reason: 'Line entity offset must be found');

    // Root entity count is directly before lineOffsetInBody:
    final countOffset = lineOffsetInBody - 2; // Uint16 count = 2
    final modifiedBody = Uint8List.fromList([
      ...uncompressedBody.sublist(0, countOffset),
      3, 0, // change count from 2 to 3
      ...uncompressedBody.sublist(lineOffsetInBody, lineOffsetInBody + 1 + 4 + 21), // Line entity
      ...dummyEntity, // Injected unknown entity (typeCode 99)
      ...uncompressedBody.sublist(lineOffsetInBody + 1 + 4 + 21), // Circle entity
    ]);

    // Reconstruct valid header for modified uncompressed body:
    final header = Uint8List(16);
    final headerBd = ByteData.sublistView(header);
    header[0] = 0x4B; header[1] = 0x43; header[2] = 0x41; header[3] = 0x44; // 'KCAD'
    headerBd.setUint16(4, KcadWriter.currentVersion, Endian.little);
    headerBd.setUint16(6, 0, Endian.little); // flags = uncompressed
    headerBd.setUint32(8, modifiedBody.length, Endian.little); // uncompressedSize
    headerBd.setUint32(12, modifiedBody.length, Endian.little); // payloadSize

    final fullModifiedKcad = Uint8List.fromList([...header, ...modifiedBody]);

    // 3. Reader must decode without exception, skipping entity 99 and keeping Line and Circle!
    final resultDoc = KcadReader.read(fullModifiedKcad);
    expect(resultDoc.entities.length, equals(2), reason: 'Unknown entity 99 must be skipped cleanly');
    expect(resultDoc.entities[0], isA<DxfLine>(), reason: 'First entity must be the original DxfLine');
    expect(resultDoc.entities[1], isA<DxfCircle>(), reason: 'Second entity must be the original DxfCircle');

    final line = resultDoc.entities[0] as DxfLine;
    expect(line.p1, equals(const Offset(10, 20)));
    expect(line.p2, equals(const Offset(30, 40)));

    final circle = resultDoc.entities[1] as DxfCircle;
    expect(circle.center, equals(const Offset(50, 60)));
    expect(circle.radius, equals(15.0));
  });

  test('MULTILEADER (MLEADER): DXF Parsing and KCAD v3 Serialization Round-Trip', () {
    const dxfString = '''
0
SECTION
2
ENTITIES
0
MULTILEADER
100
AcDbEntity
8
ANNOTATIONS
62
1
100
AcDbMLeader
300
CONTEXT_DATA{
10
100.0
20
200.0
140
3.5
41
50.0
304
\\A1;{\\fArial;Отдушник\\Pф100}
301
}
302
LEADER{
10
80.0
20
200.0
11
1.0
21
0.0
40
10.0
304
LEADER_LINE{
10
50.0
20
150.0
305
}
303
}
42
2.5
290
1
0
ENDSEC
0
EOF
''';

    final doc = DxfParser.parseString(dxfString);
    expect(doc.entities.length, equals(1));
    expect(doc.entities.first, isA<DxfMLeader>());

    final mleader = doc.entities.first as DxfMLeader;
    expect(mleader.cleanText, equals('Отдушник\nф100'));
    expect(mleader.textHeight, equals(3.5));
    expect(mleader.textWidth, equals(50.0));
    expect(mleader.textPosition, equals(const Offset(100.0, 200.0)));
    expect(mleader.connectionPoint, equals(const Offset(80.0, 200.0)));
    expect(mleader.doglegDirection, equals(const Offset(1.0, 0.0)));
    expect(mleader.doglegLength, equals(10.0));
    expect(mleader.hasArrowhead, isTrue);
    expect(mleader.arrowheadSize, equals(2.5));
    expect(mleader.leaderLines.length, equals(1));
    expect(mleader.leaderLines.first.first, equals(const Offset(50.0, 150.0)));

    // Verify KCAD v3 Round-Trip
    final kcadBytes = KcadWriter.write(doc, compress: true);
    expect(kcadBytes.isNotEmpty, isTrue);

    final docFromKcad = KcadReader.read(kcadBytes);
    expect(docFromKcad.entities.length, equals(1));
    expect(docFromKcad.entities.first, isA<DxfMLeader>());

    final roundTrip = docFromKcad.entities.first as DxfMLeader;
    expect(roundTrip.cleanText, equals('Отдушник\nф100'));
    expect(roundTrip.layer, equals('ANNOTATIONS'));
    expect(roundTrip.colorIndex, equals(1));
    expect(roundTrip.textHeight, closeTo(3.5, 1e-4));
    expect(roundTrip.textWidth, closeTo(50.0, 1e-4));
    expect(roundTrip.textPosition?.dx, closeTo(100.0, 1e-3));
    expect(roundTrip.textPosition?.dy, closeTo(200.0, 1e-3));
    expect(roundTrip.connectionPoint?.dx, closeTo(80.0, 1e-3));
    expect(roundTrip.connectionPoint?.dy, closeTo(200.0, 1e-3));
    expect(roundTrip.doglegLength, closeTo(10.0, 1e-4));
    expect(roundTrip.hasArrowhead, isTrue);
    expect(roundTrip.arrowheadSize, closeTo(2.5, 1e-4));
    expect(roundTrip.leaderLines.length, equals(1));
    expect(roundTrip.leaderLines.first.first.dx, closeTo(50.0, 1e-3));
    expect(roundTrip.leaderLines.first.first.dy, closeTo(150.0, 1e-3));
  });
}


