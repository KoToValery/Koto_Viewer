import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_loader.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

class FailingLibrary extends BimProjectLibraryService {
  bool failSave = false;
  FailingLibrary(Directory root) : super(customRootDir: root);
  @override
  Future<bool> saveProjectManifest(BimWorkProject project) =>
      failSave ? Future.value(false) : super.saveProjectManifest(project);
}

String drawing({bool opening = false}) {
  final b = StringBuffer(
    '0\nSECTION\n2\nHEADER\n9\n\$INSUNITS\n70\n4\n0\nENDSEC\n0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n2\n',
  );
  for (final layer in ['walls', 'slab']) {
    b.write('0\nLAYER\n2\n$layer\n70\n0\n62\n7\n6\nCONTINUOUS\n');
  }
  b.write('0\nENDTAB\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n');
  void line(double x, double y, double xx, double yy, String layer) {
    b.write('0\nLINE\n8\n$layer\n10\n$x\n20\n$y\n11\n$xx\n21\n$yy\n');
  }

  for (final inset in [0.0, 250.0]) {
    if (opening) {
      line(inset, inset, 4000, inset, 'walls');
      line(5000, inset, 10000 - inset, inset, 'walls');
    } else {
      line(inset, inset, 10000 - inset, inset, 'walls');
    }
    line(10000 - inset, inset, 10000 - inset, 8000 - inset, 'walls');
    line(10000 - inset, 8000 - inset, inset, 8000 - inset, 'walls');
    line(inset, 8000 - inset, inset, inset, 'walls');
  }
  line(250, 4000, 9750, 4000, 'walls');
  line(250, 4120, 9750, 4120, 'walls');
  line(0, 0, 10000, 8000, 'slab');
  b.write('0\nENDSEC\n0\nEOF\n');
  return b.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late File source;
  late FailingLibrary lib;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bim_conversion_test_');
    source = await File(
      '${temp.path}/architecture.dxf',
    ).writeAsString(drawing());
    lib = FailingLibrary(temp);
  });
  tearDown(() async => temp.delete(recursive: true));

  test(
    'assumed opening layer and region report survive KCAD and reprocessing',
    () async {
      await source.writeAsString(drawing(opening: true));
      final result = await BimUnderlayConversionService.convert(source);
      addTearDown(result.dispose);
      final baked = await KcadService.loadKcadFile(result.kcadFile);
      final report = BimUnderlayMetadata.read(baked)!['slabEnvelope'];
      expect(report['assumedGaps'], isNotEmpty);
      expect(report['contours'], isNotEmpty);
      expect(
        baked.entities.where((e) => e.layer == 'BIM_Slab_Assumed_Gaps'),
        isNotEmpty,
      );
      BimUnderlayMetadata.setFiltered(baked, false);
      expect(baked.layers['BIM_Slab_Assumed_Gaps']!.isVisible, isFalse);
      final again = await BimUnderlayConversionService.convert(result.kcadFile);
      addTearDown(again.dispose);
      final reloaded = await KcadService.loadKcadFile(again.kcadFile);
      expect(BimUnderlayMetadata.read(reloaded)!['slabEnvelope'], report);
      expect(reloaded.entities.length, baked.entities.length);
    },
  );

  Future<BimWorkProject> project() => lib.createProject(
    name: 'P',
    storeys: const [
      BimStoreyUnderlay(
        storeyId: 's',
        name: '±0.00',
        elevation: 0,
        controlPoint: Offset(100, 200),
      ),
    ],
  );

  test(
    'Two stages preserve originals, bake walls/slabs and persist metadata',
    () async {
      final stages = <BimConversionStage>[];
      final result = await BimUnderlayConversionService.convert(
        source,
        onProgress: stages.add,
      );
      addTearDown(result.dispose);
      final pure = await KcadService.loadKcadFile(result.pureKcadFile);
      final baked = await KcadService.loadKcadFile(result.kcadFile);
      expect(pure.entities.length, 11);
      expect(pure.layers.containsKey('BIM_Walls'), isFalse);
      expect(
        baked.entities.take(11).map((e) => e.layer),
        pure.entities.map((e) => e.layer),
      );
      expect(
        baked.layers['BIM_Walls']!.customLineweight,
        closeTo(0.30, 0.00001),
      );
      expect(baked.entities.where((e) => e.layer == 'BIM_Walls'), isNotEmpty);
      expect(baked.entities.where((e) => e.layer == 'BIM_Slabs').length, 1);
      expect(BimUnderlayMetadata.axes(baked), isNotEmpty);
      expect(
        BimUnderlayMetadata.read(baked)!['slabEnvelope']['status'],
        'needsReview',
      );
      expect(
        baked.entities.where((e) => e.layer == 'BIM_Slab_Candidates'),
        isNotEmpty,
      );
      expect(pure.layers.containsKey('BIM_Slab_Candidates'), isFalse);
      expect(baked.layers.containsKey('BIM_Axis'), isFalse);
      expect(stages, BimConversionStage.values);
      BimUnderlayMetadata.setFiltered(baked, false);
      expect(baked.layers['walls']!.isVisible, isTrue);
      expect(baked.layers['BIM_Walls']!.isVisible, isFalse);
      expect(await result.sourceFile.readAsString(), drawing());
    },
  );

  test(
    'Native KCAD input preserves nested slab inserts and colliding layers',
    () async {
      final doc = DxfParser.parseString(drawing());
      doc.layers['BIM_Walls'] = DxfLayer(name: 'BIM_Walls', colorIndex: 3);
      doc.layers['BIM_Slab_Candidates'] = DxfLayer(
        name: 'BIM_Slab_Candidates',
        colorIndex: 5,
      );
      doc.blocks['slabPart'] = DxfBlock(
        name: 'slabPart',
        basePoint: const Offset(2, 3),
        entities: [
          const DxfCircle(center: Offset(4, 5), radius: 2, layer: 'slab'),
          const DxfLine(p1: Offset.zero, p2: Offset(1, 1), layer: 'walls'),
        ],
      );
      doc.blocks['outer'] = DxfBlock(
        name: 'outer',
        entities: [
          const DxfInsert(
            blockName: 'slabPart',
            insertPoint: Offset(30, 40),
            rotationDeg: 45,
          ),
        ],
      );
      doc.entities.add(
        const DxfInsert(
          blockName: 'outer',
          insertPoint: Offset(50, 60),
          scaleX: 2,
          scaleY: 3,
        ),
      );
      final file = File('${temp.path}/input.kcad');
      await KcadService.exportKcadFile(doc, file.path);
      final result = await BimUnderlayConversionService.convert(file);
      addTearDown(result.dispose);
      final baked = await KcadService.loadKcadFile(result.kcadFile);
      expect(baked.layers['BIM_Walls']!.colorIndex, 3);
      expect(baked.layers['BIM_Slab_Candidates']!.colorIndex, 5);
      expect(
        BimUnderlayMetadata.generatedLayers(baked),
        contains('BIM_Slab_Candidates_1'),
      );
      expect(
        BimUnderlayMetadata.generatedLayers(baked),
        contains('BIM_Walls_1'),
      );
      final clone = baked.entities.whereType<DxfInsert>().firstWhere(
        (e) => e.layer == 'BIM_Slabs',
      );
      expect(clone.insertPoint, const Offset(50, 60));
      expect(clone.scaleX, 2);
      expect(clone.scaleY, 3);
      final nested =
          baked.blocks[clone.blockName]!.entities.single as DxfInsert;
      expect(nested.rotationDeg, 45);
      expect(baked.blocks[nested.blockName]!.entities.single, isA<DxfCircle>());
      expect(baked.blocks['slabPart']!.entities.length, 2);
      final again = await BimUnderlayConversionService.convert(result.kcadFile);
      addTearDown(again.dispose);
      final rebuilt = await KcadService.loadKcadFile(again.kcadFile);
      expect(rebuilt.entities.length, baked.entities.length);
      expect(rebuilt.blocks.length, baked.blocks.length);
    },
  );

  test(
    'Legacy flag migrates once, keeps alignment, then reopens without analysis',
    () async {
      var p = await project();
      final dir = await lib.getProjectDirectory(p.id);
      await Directory('${dir.path}/underlays').create();
      await source.copy('${dir.path}/underlays/legacy.dxf');
      p = p.copyWith(
        alignmentConfirmed: true,
        storeys: [
          p.storeys.single.copyWith(
            underlayFileName: 'underlays/legacy.dxf',
            wallsDetected: true,
            layerVisibility: {'walls': false},
          ),
        ],
      );
      await lib.saveProjectManifest(p);
      final migrated = await lib.prepareUnderlays(p);
      final s = migrated.storeys.single;
      expect(s.isKcad, isTrue);
      expect(s.controlPoint, p.storeys.single.controlPoint);
      expect(s.layerVisibility, p.storeys.single.layerVisibility);
      expect(migrated.alignmentConfirmed, isTrue);
      final reopened = await lib.prepareUnderlays(migrated);
      expect(reopened.storeys.single.underlayFileName, s.underlayFileName);
      final loaded = await BimUnderlayLoader.loadAndAlign(
        project: reopened,
        libraryService: lib,
      );
      expect(
        loaded.underlaysByStorey['s']!.layers['walls']!.isVisible,
        isFalse,
      );
      expect(
        (await lib.loadProject(p.id))!.storeys.single.underlayFileName,
        s.underlayFileName,
      );
    },
  );

  test('Empty result is completed and source remains visible', () async {
    await source.writeAsString(
      '0\nSECTION\n2\nENTITIES\n0\nLINE\n8\nnotes\n10\n0\n20\n0\n11\n1\n21\n1\n0\nENDSEC\n0\nEOF\n',
    );
    final p = await project();
    final s = await lib.attachUnderlayFile(p.id, 's', source);
    expect(s.processing['status'], 'completedEmpty');
    final doc = await lib.loadUnderlay(p.id, s);
    expect(BimUnderlayMetadata.read(doc)?['complete'], isTrue);
    BimUnderlayMetadata.setFiltered(doc, true);
    expect(doc.layers['notes']!.isVisible, isTrue);
  });

  test(
    'Failed publication retains the old manifest and working file',
    () async {
      final p = await project();
      final s = await lib.attachUnderlayFile(p.id, 's', source);
      final old = await lib.getUnderlayFile(p.id, s.underlayFileName!);
      final before = await old!.readAsBytes();
      lib.failSave = true;
      await expectLater(
        lib.attachUnderlayFile(p.id, 's', source),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        (await lib.loadProject(p.id))!.storeys.single.underlayFileName,
        s.underlayFileName,
      );
      expect(await old.readAsBytes(), before);
    },
  );

  test(
    'Corrupt working file recovers from source without changing control point',
    () async {
      final p = await project();
      final s = await lib.attachUnderlayFile(
        p.id,
        's',
        source,
        preserveAlignment: true,
      );
      final file = await lib.getUnderlayFile(p.id, s.underlayFileName!);
      await file!.writeAsString('broken');
      final recovered = await lib.prepareUnderlays(
        (await lib.loadProject(p.id))!,
      );
      expect(
        recovered.storeys.single.underlayFileName,
        isNot(s.underlayFileName),
      );
      expect(recovered.storeys.single.controlPoint, const Offset(100, 200));
      expect(
        BimUnderlayMetadata.read(
          await lib.loadUnderlay(p.id, recovered.storeys.single),
        ),
        isNotNull,
      );
    },
  );

  test(
    'Prepared conversion is reused and DXF/ZIP use saved text source',
    () async {
      final p = await project();
      final result = await BimUnderlayConversionService.convert(source);
      addTearDown(result.dispose);
      await lib.attachUnderlayFile(p.id, 's', source, prepared: result);
      final latest = (await lib.loadProject(p.id))!;
      final stored = await lib.getUnderlayFile(
        p.id,
        latest.storeys.single.underlayFileName!,
      );
      expect(await stored!.readAsBytes(), await result.kcadFile.readAsBytes());
      final structural = (await lib.loadStructuralProject(p.id))!;
      final zip = await BimExportService.exportProjectZip(
        project: latest,
        structural: structural,
        outputDirectory: temp,
        libraryService: lib,
      );
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      expect(
        archive.findFile(latest.storeys.single.underlayFileName!),
        isNotNull,
      );
      expect(archive.findFile('structural.json'), isNotNull);
      final drawingFile = archive.findFile('±0.00_s.dxf')!;
      final exported = DxfParser.parseString(
        utf8.decode(drawingFile.content as List<int>),
      );
      expect(exported.entities.where((e) => e.layer == 'walls').length, 10);
    },
  );

  test(
    'Editing and sorting existing storeys preserve geometry and active ID',
    () async {
      var p = await project();
      var structural = (await lib.loadStructuralProject(p.id))!;
      structural = structural.copyWith(
        storeys: [
          structural.storeys.single.copyWith(
            columns: [
              const StructuralColumn(
                id: 'c',
                center: Offset(10, 20),
                width: 1,
                height: 1,
              ),
            ],
          ),
        ],
      );
      await lib.saveStructuralProject(p.id, structural);
      p = await lib.updateStoreys(p.id, [
        const BimStoreyUnderlay(storeyId: 'b', name: '', elevation: -3.2),
        p.storeys.single.copyWith(elevation: 2.85),
      ]);
      final synced = (await lib.loadStructuralProject(p.id))!;
      expect(synced.activeStorey.id, 's');
      expect(synced.activeStorey.elevation, 2.85);
      expect(synced.activeStorey.columns.single.id, 'c');
      expect(p.storeys.last.controlPoint, const Offset(100, 200));
      await expectLater(
        lib.updateStoreys(p.id, [
          p.storeys.last,
          p.storeys.first.copyWith(elevation: 2.85),
        ]),
        throwsArgumentError,
      );
    },
  );

  test('Cancelled queue job fails without publishing anything', () async {
    await expectLater(
      BimUnderlayConversionService.convert(source, isCancelled: () => true),
      throwsStateError,
    );
    expect((await lib.listProjects()), isEmpty);
  });

  test(
    'Axis seeds are consumed once and deletion survives reopening',
    () async {
      var p = await project();
      await lib.attachUnderlayFile(p.id, 's', source, preserveAlignment: true);
      p = (await lib.loadProject(p.id))!;
      final loaded = await BimUnderlayLoader.loadAndAlign(
        project: p,
        libraryService: lib,
      );
      final initialized = await lib.initializeAxes(
        p,
        (await lib.loadStructuralProject(p.id))!,
        loaded.underlaysByStorey,
      );
      expect(initialized.$1.axisSeedsConsumed, isTrue);
      expect(initialized.$2.effectiveGridAxes, isNotEmpty);
      await lib.saveStructuralProject(
        p.id,
        initialized.$2.copyWithGridAxes([]),
      );
      final reopened = await lib.initializeAxes(
        (await lib.loadProject(p.id))!,
        (await lib.loadStructuralProject(p.id))!,
        loaded.underlaysByStorey,
      );
      expect(reopened.$2.effectiveGridAxes, isEmpty);
    },
  );

  test(
    'Analysis cancellation releases queue and next conversion can complete',
    () async {
      var cancelled = false;
      await expectLater(
        BimUnderlayConversionService.convert(
          source,
          isCancelled: () => cancelled,
          onProgress: (stage) {
            if (stage == BimConversionStage.analysing) cancelled = true;
          },
        ),
        throwsStateError,
      );
      final next = await BimUnderlayConversionService.convert(source);
      addTearDown(next.dispose);
      expect(await next.kcadFile.exists(), isTrue);
    },
  );

  test('Invalid DXF cannot replace the existing revision', () async {
    final p = await project();
    final before = await lib.attachUnderlayFile(p.id, 's', source);
    await source.writeAsString('not a drawing');
    await expectLater(
      lib.attachUnderlayFile(p.id, 's', source),
      throwsFormatException,
    );
    expect(
      (await lib.loadProject(p.id))!.storeys.single.underlayFileName,
      before.underlayFileName,
    );
  });

  test(
    'KCAD-only DXF export reports unsupported source instead of reading binary as text',
    () async {
      final p = await project();
      final input = File('${temp.path}/input.kcad');
      await KcadService.exportKcadFile(
        DxfParser.parseString(drawing()),
        input.path,
      );
      await lib.attachUnderlayFile(p.id, 's', input);
      await expectLater(
        BimExportService.exportStoreyDxf(
          project: (await lib.loadProject(p.id))!,
          structural: (await lib.loadStructuralProject(p.id))!,
          storeyId: 's',
          outputDirectory: temp,
          libraryService: lib,
        ),
        throwsUnsupportedError,
      );
    },
  );

  test('Concurrent publications retain both storey attachments', () async {
    final p = await lib.createProject(
      name: 'Parallel',
      storeys: const [
        BimStoreyUnderlay(storeyId: 'a', name: '', elevation: 0),
        BimStoreyUnderlay(storeyId: 'b', name: '', elevation: 2.8),
      ],
    );
    await Future.wait([
      lib.attachUnderlayFile(p.id, 'a', source),
      lib.attachUnderlayFile(p.id, 'b', source),
    ]);
    final latest = (await lib.loadProject(p.id))!;
    expect(latest.storeys.every((s) => s.isKcad), isTrue);
    expect(latest.storeys.map((s) => s.underlayFileName).toSet().length, 2);
  });

  test(
    'Saved axis seeds follow the same alignment as the underlay geometry',
    () async {
      final p = await lib.createProject(
        name: 'Aligned',
        storeys: const [
          BimStoreyUnderlay(
            storeyId: 'a',
            name: '',
            elevation: 0,
            controlPoint: Offset(100, 200),
          ),
          BimStoreyUnderlay(
            storeyId: 'b',
            name: '',
            elevation: 2.8,
            controlPoint: Offset(500, 600),
          ),
        ],
      );
      await lib.attachUnderlayFile(p.id, 'a', source, preserveAlignment: true);
      await lib.attachUnderlayFile(p.id, 'b', source, preserveAlignment: true);
      final latest = (await lib.loadProject(p.id))!;
      final local = await lib.loadUnderlay(p.id, latest.storeys.last);
      final before = BimUnderlayMetadata.axes(local).first;
      final loaded = await BimUnderlayLoader.loadAndAlign(
        project: latest,
        libraryService: lib,
      );
      final aligned = BimUnderlayMetadata.axes(
        loaded.underlaysByStorey['b']!,
      ).first;
      expect(aligned.start, before.start - const Offset(400, 400));
      expect(aligned.end, before.end - const Offset(400, 400));
    },
  );
}
