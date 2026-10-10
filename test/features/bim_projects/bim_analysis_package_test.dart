import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_loader.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_service.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/structural_designer/analysis/initial_scheme_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';

String drawing(double units, Offset origin) {
  final b = StringBuffer('0\nSECTION\n2\nHEADER\n9\n');
  b.writeln(r'$INSUNITS');
  b.write(
    '70\n${units == 1000 ? 4 : 6}\n0\nENDSEC\n0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n1\n0\nLAYER\n2\nwalls\n70\n0\n62\n7\n6\nCONTINUOUS\n0\nENDTAB\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n',
  );
  void line(Offset a, Offset c) => b.write(
    '0\nLINE\n8\nwalls\n10\n${a.dx}\n20\n${a.dy}\n11\n${c.dx}\n21\n${c.dy}\n',
  );
  for (final inset in [0.0, .25]) {
    final points = [
      Offset(inset, inset),
      Offset(10 - inset, inset),
      Offset(10 - inset, 8 - inset),
      Offset(inset, 8 - inset),
    ].map((p) => p * units + origin).toList();
    for (var i = 0; i < 4; i++) {
      line(points[i], points[(i + 1) % 4]);
    }
  }
  b.write('0\nENDSEC\n0\nEOF\n');
  return b.toString();
}

Offset point(List p) =>
    Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
WallSegment segment(Map s) => WallSegment(
  start: point(s['start']),
  end: point(s['end']),
  angleRad: (s['angleRad'] as num).toDouble(),
  offsetFromOrigin: (s['offsetFromOrigin'] as num).toDouble(),
  length: (s['length'] as num).toDouble(),
  sourceLayer: s['sourceLayer'],
  sourceColorIndex: s['sourceColorIndex'],
  sourceTrueColor: s['sourceTrueColor'],
  lineweight: (s['lineweight'] as num).toDouble(),
);
WallPairCandidate pair(Map w) => WallPairCandidate(
  segmentA: segment(w['segmentA']),
  segmentB: segment(w['segmentB']),
  perpendicularDistance: (w['perpendicularDistance'] as num).toDouble(),
  overlapLength: (w['overlapLength'] as num).toDouble(),
  centerlineStart: point(w['centerlineStart']),
  centerlineEnd: point(w['centerlineEnd']),
);
Map<String, dynamic> jsonEntry(Archive a, String path) =>
    jsonDecode(utf8.decode(a.findFile(path)!.content as List<int>))
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late BimProjectLibraryService lib;
  late StructuralProject model;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bim_analysis_package_');
    lib = BimProjectLibraryService(
      customRootDir: Directory('${temp.path}/original'),
    );
  });
  tearDown(() async {
    // Only the directory freshly created for this test may be removed.
    expect(
      temp.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      isTrue,
    );
    await temp.delete(recursive: true);
  });
  Future<BimWorkProject> prepare({
    bool two = true,
    bool savedFrame = true,
    bool kcadOnly = false,
  }) async {
    var p = await lib.createProject(
      name: 'Проверка ZIP',
      storeys: [
        const BimStoreyUnderlay(
          storeyId: 'ground',
          name: 'Партер',
          elevation: 0,
          height: 3.2,
          controlPoint: Offset(1000, 2000),
        ),
        if (two)
          const BimStoreyUnderlay(
            storeyId: 'upper',
            name: 'Етаж',
            elevation: 3.2,
            controlPoint: Offset(30, 40),
          ),
      ],
    );
    for (final s in p.storeys) {
      final units = s.storeyId == 'ground' ? 1000.0 : 1.0;
      var file = await File(
        '${temp.path}/${s.storeyId}.dxf',
      ).writeAsString(drawing(units, s.controlPoint!));
      if (kcadOnly) {
        final doc = await DxfParser.parseFromFile(file);
        file = File('${temp.path}/${s.storeyId}.kcad');
        await KcadService.exportKcadFile(doc, file.path);
      }
      await lib.attachUnderlayFile(
        p.id,
        s.storeyId,
        file,
        preserveAlignment: true,
      );
    }
    p = (await lib.loadProject(p.id))!;
    p = p.copyWith(
      storeys: [
        for (final s in p.storeys)
          s.copyWith(layerVisibility: const {'walls': true}),
      ],
      alignmentConfirmed: true,
      referenceStoreyId: 'ground',
      structuralOrigin: savedFrame ? const Offset(100000, 200000) : null,
      structuralUnitsPerMeter: savedFrame ? 1000 : null,
    );
    await lib.saveProjectManifest(p);
    final origin = savedFrame
        ? const Offset(100000, 200000)
        : const Offset(1000, 2000);
    List<Offset> rect(double x, double y, double w, double h) => [
      Offset(x, y),
      Offset(x + w, y),
      Offset(x + w, y + h),
      Offset(x, y + h),
    ].map((q) => q * 1000 + origin).toList();
    model = StructuralProject(
      title: p.name,
      concreteGrade: 'C30/37',
      liveLoad: 3.5,
      deadLoadSuperimposed: 2.2,
      facadeWallLoad: 4.3,
      gridAxes: [
        StructuralGridAxis(
          id: 'axis',
          name: 'А',
          start: origin,
          end: origin + const Offset(10000, 0),
        ),
      ],
      storeys: [
        for (final s in p.storeys)
          StoreyLevel(
            id: s.storeyId,
            name: s.name,
            elevation: s.elevation,
            height: s.height,
            columns: [
              StructuralColumn(
                id: 'c:${s.storeyId}',
                name: 'К1',
                center: origin + const Offset(2000, 2000),
                width: 300,
                height: 400,
                rotationRad: .43,
                generatedBy: 'initial-scheme-v1',
              ),
            ],
            shearWalls: [
              StructuralShearWall(
                id: 'w:${s.storeyId}',
                start: origin + const Offset(1000, 4000),
                end: origin + const Offset(3000, 4000),
                thickness: 250,
              ),
            ],
            beams: [
              StructuralBeam(
                id: 'b:${s.storeyId}',
                start: origin + const Offset(2000, 2000),
                end: origin + const Offset(6000, 2000),
              ),
            ],
            slabs: [
              StructuralSlab(
                id: 'slab:${s.storeyId}',
                polygon: rect(0, 0, 10, 8),
                thickness: .22,
                openings: [rect(4, 3, 1, 2)],
                openingTypes: const [SlabOpeningType.staircase],
              ),
            ],
          ),
      ],
    );
    await lib.saveStructuralProject(p.id, model);
    return p;
  }

  Future<Archive> export(BimWorkProject p) async {
    final file = await BimExportService.exportProjectZip(
      project: p,
      structural: model,
      outputDirectory: Directory('${temp.path}/output'),
      libraryService: lib,
    );
    return ZipDecoder().decodeBytes(await file.readAsBytes());
  }

  test(
    'ZIP restores mixed CAD units, typed model and placement inputs without the original library',
    () async {
      final p = await prepare();
      final originalManifest = await File(
        '${(await lib.getProjectDirectory(p.id)).path}/project.json',
      ).readAsBytes();
      final a = await export(p);
      final inventory = jsonEntry(a, 'package.json'),
          analysis = jsonEntry(a, 'analysis.json');
      expect(inventory['schemaVersion'], 1);
      expect(inventory['cadUnitsPerMeter'], 1000);
      final names = a.files.map((f) => f.name).toSet();
      expect(names.length, a.files.length);
      expect((inventory['files'] as List).length, a.files.length - 1);
      for (final f in inventory['files']) {
        final data = a.findFile(f['path'])!.content as List<int>;
        expect(data.length, f['bytes']);
        expect(sha256.convert(data).toString(), f['sha256']);
        expect((f['path'] as String).contains('\\'), isFalse);
      }
      expect(analysis['projectFrame']['origin'], [100000.0, 200000.0]);
      final floors = analysis['storeys'] as List;
      expect(floors[0]['sourceToProject'], {
        'scale': 1.0,
        'translation': [99000.0, 198000.0],
      });
      expect(floors[1]['sourceToProject'], {
        'scale': 1000.0,
        'translation': [70000.0, 160000.0],
      });
      expect(floors[0]['placementInputs']['wallPairs'], isNotEmpty);
      expect(floors[1]['placementInputs']['wallPairs'], isNotEmpty);
      final recovered = StructuralProject.fromJson(
        jsonEntry(a, 'structural.json'),
      );
      expect(recovered.toJson(), model.toJson());
      expect(
        recovered.storeys.first.slabs.single.getOpeningType(0),
        SlabOpeningType.staircase,
      );
      expect(jsonEntry(a, 'Проверка ZIP_model.bim.json'), model.toJson());
      expect(
        await File(
          '${(await lib.getProjectDirectory(p.id)).path}/project.json',
        ).readAsBytes(),
        originalManifest,
      );

      final foreign = BimProjectLibraryService(
        customRootDir: Directory('${temp.path}/foreign'),
      );
      final target = await foreign.getProjectDirectory(p.id);
      for (final f in a.files.where((f) => f.isFile)) {
        final file = File('${target.path}/${f.name}');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(f.content as List<int>);
      }
      final portable = (await foreign.loadProject(p.id))!;
      final loaded = await BimUnderlayLoader.loadAndAlign(
        project: portable,
        libraryService: foreign,
      );
      expect(loaded.cadUnitsPerMeter, 1000);
      expect(loaded.referenceControlPoint, const Offset(100000, 200000));
      final live = WallAxisDetector.detect(
        loaded.underlaysByStorey['ground']!,
        forceScaleFactor: 1,
      ).selectedWallPairs;
      final saved = (floors[0]['placementInputs']['wallPairs'] as List)
          .map((w) => pair(w as Map))
          .toList();
      final fromJson = InitialSchemeGenerator.generate(
        project: recovered,
        wallPairs: saved,
        scale: 1000,
        options: const InitialSchemeOptions(optimizeLayout: false),
      );
      final fromDrawing = InitialSchemeGenerator.generate(
        project: recovered,
        wallPairs: live,
        scale: 1000,
        options: const InitialSchemeOptions(optimizeLayout: false),
      );
      expect(
        fromJson.assessment!.toMetrics(),
        fromDrawing.assessment!.toMetrics(),
      );
      expect(
        fromJson.columns.map((c) => c.toJson()).toList(),
        fromDrawing.columns.map((c) => c.toJson()).toList(),
      );
      expect(
        fromJson.walls.map((w) => w.toJson()).toList(),
        fromDrawing.walls.map((w) => w.toJson()).toList(),
      );
    },
  );

  test(
    'library ZIP resolves millimetres and exports correctly scaled DXF without an explicit scale',
    () async {
      final p = await prepare(two: false, savedFrame: false);
      final a = await export(p);
      final inventory = jsonEntry(a, 'package.json');
      expect(inventory['cadUnitsPerMeter'], 1000);
      final frame = jsonEntry(a, 'analysis.json')['projectFrame'];
      expect(frame['unitsSource'], 'referenceUnderlay');
      final text = utf8.decode(
        a.findFile('±0.00_ground.dxf')!.content as List<int>,
      );
      // The axis pattern must be 0.75 m, expressed as 750 mm in this local drawing.
      expect(text, contains('750.0'));
      expect(jsonEntry(a, 'project.json')['structuralUnitsPerMeter'], 1000);
    },
  );

  test(
    'KCAD-only project still exports all sources and readable geometry with a documented DXF absence',
    () async {
      final p = await prepare(two: false, kcadOnly: true);
      expect(p.storeys.single.processing['dxf'], isNull);
      final a = await export(p), inventory = jsonEntry(a, 'package.json');
      expect(inventory['drawings'][0]['status'], 'unavailable');
      expect(
        (inventory['warnings'] as List).any(
          (w) => w['code'] == 'derivedDxfUnavailable',
        ),
        isTrue,
      );
      expect(a.findFile(p.storeys.single.underlayFileName!), isNotNull);
      expect(a.findFile(p.storeys.single.processing['source']), isNotNull);
      expect(
        jsonEntry(
          a,
          'analysis.json',
        )['storeys'][0]['placementInputs']['wallPairs'],
        isNotEmpty,
      );
      expect(jsonEntry(a, 'structural.json'), model.toJson());
    },
  );

  test(
    'missing referenced source does not publish a partial ZIP or overwrite the previous package',
    () async {
      final p = await prepare(two: false);
      await export(p);
      final previous = File('${temp.path}/output/Проверка ZIP_BimPackage.zip');
      final before = await previous.readAsBytes();
      final invalid = p.copyWith(
        storeys: [
          p.storeys.single.copyWith(
            processing: {
              ...p.storeys.single.processing,
              'pure': 'underlays/missing.kcad',
            },
          ),
        ],
      );
      await expectLater(export(invalid), throwsA(isA<FileSystemException>()));
      expect(await previous.readAsBytes(), before);
    },
  );

  test(
    'mismatched storey IDs and elevations are explicit export failures',
    () async {
      final p = await prepare(two: false);
      model = model.copyWith(
        storeys: [model.storeys.single.copyWith(id: 'unknown')],
      );
      await expectLater(export(p), throwsStateError);
      model = model.copyWith(
        storeys: [model.storeys.single.copyWith(id: 'ground', elevation: 9)],
      );
      await expectLater(export(p), throwsStateError);
    },
  );

  test('archive paths cannot point outside the packaged project', () async {
    final p = await prepare(two: false);
    for (final path in [
      '../outside.kcad',
      'C:/outside.kcad',
      '/outside.kcad',
    ]) {
      final invalid = p.copyWith(
        storeys: [p.storeys.single.copyWith(underlayFileName: path)],
      );
      await expectLater(export(invalid), throwsArgumentError);
    }
  });

  test(
    'model-only export records assumed units and absent architecture',
    () async {
      final p = BimWorkProject(
        id: 'p',
        name: 'P',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [
          BimStoreyUnderlay(storeyId: 's', name: 'S', elevation: 0),
        ],
      );
      model = const StructuralProject(
        storeys: [StoreyLevel(id: 's', name: 'S')],
      );
      final a = await export(p), inventory = jsonEntry(a, 'package.json');
      final codes = (inventory['warnings'] as List)
          .map((w) => w['code'])
          .toSet();
      expect(codes, containsAll(['unitsAssumed', 'underlayMissing']));
      expect(
        jsonEntry(a, 'analysis.json')['storeys'][0]['geometryStatus'],
        'noUnderlay',
      );
      expect(inventory['drawings'][0]['coordinateSpace'], 'projectCAD');
    },
  );

  test(
    'wall faces and short jamb caps survive metre, centimetre and millimetre drawings',
    () {
      for (final units in [1.0, 100.0, 1000.0]) {
        final doc = DxfParser.parseString(drawing(units, const Offset(0, 0)));
        final detected = WallAxisDetector.detect(
          doc,
          forceScaleFactor: units / 1000,
        );
        expect(detected.selectedWallPairs, hasLength(4));
        expect(detected.wallContourSegments, hasLength(8));
        final w = detected.selectedWallPairs.first;
        final caps = WallAxisDetector.computeClosureSegmentsForPairs([
          w,
        ], cadUnitsPerMillimetre: units / 1000);
        expect(caps, hasLength(2));
        for (final cap in caps) {
          expect((cap.$2 - cap.$1).distance / units, closeTo(.25, 1e-8));
        }
      }
    },
  );

  test(
    'identical sanitized storey names still have distinct drawing entries',
    () async {
      final p = BimWorkProject(
        id: 'p',
        name: 'P',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        structuralUnitsPerMeter: 1,
        storeys: const [
          BimStoreyUnderlay(storeyId: 'a/b', name: 'A', elevation: 0),
          BimStoreyUnderlay(storeyId: 'a?b', name: 'B', elevation: 0),
        ],
      );
      model = const StructuralProject(
        storeys: [
          StoreyLevel(id: 'a/b', name: 'A'),
          StoreyLevel(id: 'a?b', name: 'B'),
        ],
      );
      final a = await export(p),
          drawings = jsonEntry(a, 'package.json')['drawings'] as List;
      expect(drawings.map((d) => d['path']).toSet(), hasLength(2));
      for (final d in drawings) {
        expect(a.findFile(d['path']), isNotNull);
      }
    },
  );
}
