import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_underlay_service.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_asset_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_loader.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

DxfDocument drawing(double x) => DxfDocument(
  blocks: const {},
  headerVars: const {},
  entityStats: const {},
  layers: {
    'walls': DxfLayer(name: 'walls'),
    'notes': DxfLayer(name: 'notes'),
  },
  entities: [
    DxfLine(layer: 'walls', p1: Offset(x, 0), p2: Offset(x + 5, 0)),
    DxfLine(layer: 'notes', p1: Offset(x, 2), p2: Offset(x + 5, 2)),
  ],
  bounds: Rect.fromLTWH(x, 0, 5, 2),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late BimProjectLibraryService library;
  late ArchitectUnderlayService service;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('architect_snapshot_');
    library = BimProjectLibraryService(customRootDir: temp);
    service = ArchitectUnderlayService(libraryService: library);
  });
  tearDown(() async => temp.delete(recursive: true));

  Future<File> source(String dir, double x) async {
    final file = File('${temp.path}/$dir/plan.kcad');
    await file.parent.create(recursive: true);
    await KcadService.exportKcadFile(drawing(x), file.path);
    return file;
  }

  test(
    'aligned fallback capture preserves geometry and effective frame',
    () async {
      const frame = BimCoordinateFrame(
        origin: Offset(100, 200),
        unitsPerMeter: 1000,
      );
      final config = await service.captureCadSnapshot(
        projectId: 'owner',
        storeyId: 's',
        document: drawing(35),
        frame: frame,
      );
      expect(config.externalSourcePath, isNull);
      expect(config.lockedCadOriginX, 100);
      expect(config.lockedCadOriginY, 200);
      expect(config.unitsPerMeter, 1000);
      final restored = await service.loadSavedCadUnderlay(
        config,
        projectId: 'owner',
      );
      expect(restored!.entities.whereType<DxfLine>().first.p1.dx, 35);
    },
  );

  test(
    'equal filenames remain separate snapshots and refresh keeps crop',
    () async {
      final a = await service.importOrReloadCadUnderlay(
        projectId: 'a',
        storeyId: 's',
        sourceFile: await source('a_source', 0),
      );
      final b = await service.importOrReloadCadUnderlay(
        projectId: 'b',
        storeyId: 's',
        sourceFile: await source('b_source', 20),
      );
      expect(a.config.internalCopyPath, isNot(contains(temp.path)));
      final crop = [
        const Offset(0, 0),
        const Offset(3, 0),
        const Offset(3, 2),
        const Offset(0, 2),
      ];
      final refreshed = await service.importOrReloadCadUnderlay(
        projectId: 'a',
        storeyId: 's',
        sourceFile: await source('changed', 10),
        existingConfig: a.config.copyWith(maskPolygon: crop, opacity: .7),
      );
      expect(refreshed.config.maskPolygon, crop);
      expect(refreshed.config.opacity, .7);
      expect(refreshed.config.autoReload, isFalse);
      expect(
        (await service.loadSavedCadUnderlay(
          a.config,
          projectId: 'a',
        ))!.entities.whereType<DxfLine>().first.p1.dx,
        0,
      );
      expect(
        (await service.loadSavedCadUnderlay(
          b.config,
          projectId: 'b',
        ))!.entities.whereType<DxfLine>().first.p1.dx,
        20,
      );
      await expectLater(
        service.importOrReloadCadUnderlay(
          projectId: 'a',
          storeyId: 's',
          sourceFile: File('${temp.path}/missing.kcad'),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await service.loadSavedCadUnderlay(refreshed.config, projectId: 'a'),
        isNotNull,
      );
    },
  );

  test(
    'legacy adoption prefers exact current root and never guesses a filename',
    () async {
      final old = await library.getProjectDirectory('old');
      final current = await library.getProjectDirectory('current');
      final oldFile = await File(
        '${old.path}/underlays/cad/plan.dxf',
      ).create(recursive: true);
      await oldFile.writeAsString('old');
      final local = await File(
        '${current.path}/underlays/cad/plan.dxf',
      ).create(recursive: true);
      await local.writeAsString('current');
      expect(
        await (await BimProjectAssetService.resolve(
          current,
          oldFile.path,
        ))!.readAsString(),
        'current',
      );
      await local.delete();
      final adopted = await BimProjectAssetService.resolve(
        current,
        oldFile.path,
      );
      expect(adopted!.path, startsWith(current.path));
      expect(await oldFile.exists(), isTrue);
      expect(
        await BimProjectAssetService.resolve(current, 'underlays/missing.kcad'),
        isNull,
      );
      expect(
        await BimProjectAssetService.resolve(
          current,
          '../old/underlays/cad/plan.dxf',
        ),
        isNull,
      );
    },
  );

  test(
    'content cache identity and queued write survive same-name edits and filtering',
    () async {
      final one = await File(
        '${temp.path}/one/plan.dxf',
      ).create(recursive: true);
      final two = await File(
        '${temp.path}/two/plan.dxf',
      ).create(recursive: true);
      await one.writeAsString('AAAA');
      await two.writeAsString('BBBB');
      final time = DateTime(2026);
      await one.setLastModified(time);
      await two.setLastModified(time);
      expect(
        await KcadService.getCachePath(one),
        isNot(await KcadService.getCachePath(two)),
      );
      final doc = drawing(0);
      final write = KcadService.saveKcadCache(one, doc);
      doc.layers['notes']!.isVisible = false;
      doc.entities.clear();
      await write;
      final cached = await KcadService.tryLoadCachedKcad(one);
      expect(cached!.layers['notes']!.isVisible, isTrue);
      expect(cached.entities, hasLength(2));
    },
  );

  test(
    'architectural original mode ignores persisted structural filters',
    () async {
      var project = await library.createProject(
        name: 'Same',
        storeys: const [
          BimStoreyUnderlay(storeyId: 's', name: '0', elevation: 0),
        ],
      );
      final storey = await library.attachUnderlayFile(
        project.id,
        's',
        await source('source', 0),
      );
      project = (await library.loadProject(project.id))!.copyWith(
        storeys: [
          storey.copyWith(layerVisibility: {'notes': false, 'walls': true}),
        ],
      );
      await library.saveProjectManifest(project);
      final loaded = await BimUnderlayLoader.loadAndAlign(
        project: project,
        libraryService: library,
        mode: BimUnderlayLoadMode.architecturalOriginal,
      );
      final doc = loaded.underlaysByStorey['s']!;
      expect(doc.entities, hasLength(2));
      expect(doc.layers['notes']!.isVisible, isTrue);
      expect(doc.layers.keys.any((n) => n.startsWith('BIM_')), isFalse);
      expect(
        (await library.loadProject(
          project.id,
        ))!.storeys.single.layerVisibility['notes'],
        isFalse,
      );
    },
  );

  test(
    'library normalizes owner ID and portable package includes architectural assets',
    () async {
      final initial = ArchitectProject.starterWithCatalog(
        name: 'Same',
        storeyCount: 1,
      );
      final project = await library.createProject(
        name: 'Same',
        storeys: const [
          BimStoreyUnderlay(storeyId: 's', name: '0', elevation: 0),
        ],
        projectType: BimProjectType.architectural,
      );
      final cad = await service.importOrReloadCadUnderlay(
        projectId: project.id,
        storeyId: 's',
        sourceFile: await source('source', 0),
      );
      final root = await library.getProjectDirectory(project.id);
      await File(
        '${root.path}/underlays/raster/image.png',
      ).create(recursive: true).then((f) => f.writeAsBytes([1, 2, 3]));
      final arch = initial.copyWith(
        id: 'legacy_wrong_id',
        cadUnderlays: {'s': cad.config},
        rasterUnderlays: [
          const ArchitectRasterUnderlay(
            id: 'r',
            storeyId: 's',
            fileName: 'image.png',
            internalImagePath: 'underlays/raster/image.png',
            imageWidthPx: 1,
            imageHeightPx: 1,
          ),
        ],
      );
      await library.saveArchitectProject(project.id, arch);
      final saved = (await library.loadArchitectProject(project.id))!;
      expect(saved.id, project.id);
      final zip = await BimExportService.exportArchitecturalProjectZip(
        project: project,
        architect: saved,
        outputDirectory: temp,
        libraryService: library,
      );
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final json =
          jsonDecode(
                utf8.decode(
                  archive.files
                          .singleWhere((f) => f.name == 'architectural.json')
                          .content
                      as List<int>,
                ),
              )
              as Map;
      final config = (json['cadUnderlays'] as Map)['s'] as Map;
      expect(config.containsKey('externalSourcePath'), isFalse);
      expect(
        archive.files.any((f) => f.name == config['internalCopyPath']),
        isTrue,
      );
      expect(
        archive.files.any((f) => f.name == config['kcadCachePath']),
        isTrue,
      );
      expect(
        archive.files.any((f) => f.name == 'underlays/raster/image.png'),
        isTrue,
      );
      expect(
        utf8.decode(
          archive.files
                  .singleWhere((f) => f.name == 'architectural.json')
                  .content
              as List<int>,
        ),
        isNot(contains(temp.path)),
      );
    },
  );
}
