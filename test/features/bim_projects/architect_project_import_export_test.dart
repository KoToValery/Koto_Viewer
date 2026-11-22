import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/screens/architect_studio_tab.dart';
import 'package:kotoview/src/features/architect/services/architect_underlay_service.dart';
import 'package:kotoview/src/features/architect/services/component_library_service.dart';
import 'package:kotoview/src/features/architect/services/fenestration_library_service.dart';
import 'package:kotoview/src/features/bim_projects/bim_project_library_screen.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_import_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:shared_preferences/shared_preferences.dart';

DxfDocument _sampleDoc(double shift) => DxfDocument(
  blocks: const {},
  headerVars: const {},
  entityStats: const {},
  layers: {
    'walls': DxfLayer(name: 'walls'),
    'hidden_layer': DxfLayer(name: 'hidden_layer', isVisible: false),
  },
  entities: [
    DxfLine(layer: 'walls', p1: Offset(shift, 0), p2: Offset(shift + 8, 0)),
    DxfLine(
      layer: 'hidden_layer',
      p1: Offset(shift, 3),
      p2: Offset(shift + 8, 3),
    ),
  ],
  bounds: Rect.fromLTWH(shift, 0, 8, 3),
);

String _customComponentScript(String id) => jsonEncode({
  'id': id,
  'name': 'Custom Island',
  'category': 'kitchen',
  'defaultParams': {'width': 1.8, 'depth': 0.9, 'height': 0.9},
  'solids': [
    {
      'type': 'box',
      'size': ['width', 'depth', 'height'],
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory sourceRoot;
  late Directory targetRoot;
  late BimProjectLibraryService sourceLibrary;
  late BimProjectLibraryService targetLibrary;
  late ArchitectUnderlayService underlayService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('arch_import_export_');
    sourceRoot = Directory('${tempDir.path}/source_lib')..createSync();
    targetRoot = Directory('${tempDir.path}/target_lib')..createSync();
    sourceLibrary = BimProjectLibraryService(customRootDir: sourceRoot);
    targetLibrary = BimProjectLibraryService(customRootDir: targetRoot);
    underlayService = ArchitectUnderlayService(libraryService: sourceLibrary);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<(BimWorkProject, ArchitectProject)> createRichProject() async {
    const customStyleId = 'custom_arch_import_door_v1';
    const customCompId = 'custom_arch_import_island_v1';
    await ComponentLibraryService.instance.saveCustomScript(
      _customComponentScript(customCompId),
    );
    final baseDoorStyle = FenestrationLibraryService.instance
        .getDoorStyles()
        .first;
    await FenestrationLibraryService.instance.saveStyle(
      baseDoorStyle.copyWith(
        id: customStyleId,
        name: 'Custom Arch Door',
        hasCasing: true,
      ),
    );

    final manifest = await sourceLibrary.createProject(
      name: 'Villa Sync Test',
      location: 'Sofia, Bulgaria',
      projectType: BimProjectType.architectural,
      storeys: const [
        BimStoreyUnderlay(
          storeyId: 'storey_0',
          name: 'Партер',
          elevation: 0.0,
          height: 3.10,
        ),
        BimStoreyUnderlay(
          storeyId: 'storey_1',
          name: 'Етаж 2',
          elevation: 3.10,
          height: 2.85,
        ),
      ],
    );

    // Attach CAD underlay + raster underlay + PDF source inside source project.
    final cadSource = File('${tempDir.path}/cad_input/ground.kcad');
    await cadSource.parent.create(recursive: true);
    await KcadService.exportKcadFile(_sampleDoc(12.5), cadSource.path);
    final cadImported = await underlayService.importOrReloadCadUnderlay(
      projectId: manifest.id,
      storeyId: 'storey_0',
      sourceFile: cadSource,
    );

    final projDir = await sourceLibrary.getProjectDirectory(manifest.id);
    final rasterFile = File('${projDir.path}/underlays/raster/plan_scan.png');
    await rasterFile.parent.create(recursive: true);
    await rasterFile.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
    final pdfFile = File('${projDir.path}/underlays/raster/plan_scan.pdf');
    await pdfFile.writeAsBytes([37, 80, 68, 70, 45, 49, 46, 52]);

    final loadedArch = (await sourceLibrary.loadArchitectProject(manifest.id))!;
    final editedArch = loadedArch
        .copyWith(
          name: 'Villa Sync Renamed',
          units: ArchitectUnit.centimeters,
          distanceDecimals: 1,
          dimensionScale: ArchitectDimensionScale.scale50,
          structuralScheme: ArchitectStructuralScheme.beamAndSlab,
          perimeterBeamDepth: 0.55,
          showDecorativeOnPlan: true,
          gridAxes: const [
            StructuralGridAxis(
              id: 'ax_1',
              name: '1',
              start: Offset(0, -1),
              end: Offset(0, 10),
            ),
          ],
          cadUnderlays: {
            'storey_0': cadImported.config.copyWith(
              opacity: 0.65,
              useOriginalColors: true,
              rotationRad: 0.25,
              maskPolygon: const [
                Offset(0, 0),
                Offset(10, 0),
                Offset(10, 8),
                Offset(0, 8),
              ],
            ),
          },
          rasterUnderlays: const [
            ArchitectRasterUnderlay(
              id: 'rast_1',
              storeyId: 'storey_1',
              fileName: 'plan_scan.png',
              internalImagePath: 'underlays/raster/plan_scan.png',
              sourcePdfPath: 'underlays/raster/plan_scan.pdf',
              pdfPageNumber: 2,
              imageWidthPx: 800,
              imageHeightPx: 600,
              position: Offset(-2, -1),
              metersPerPixel: 0.02,
              rotationRad: 0.1,
              opacity: 0.5,
            ),
          ],
          document: loadedArch.document.copyWith(
            sheets: const [
              ArchitectSheet(
                id: 'sheet_a01',
                name: 'Floor Plan Sheet',
                number: 'A-01',
                author: 'Arch Studio',
                placements: [
                  ArchitectDrawingPlacement(
                    id: 'pl_1',
                    drawingId: 'plan:storey_0',
                    frame: Rect.fromLTWH(20, 20, 200, 150),
                    anchor: Offset(4, 3),
                    scale: 50,
                  ),
                ],
              ),
            ],
          ),
          storeys: [
            loadedArch.storeys
                .firstWhere((s) => s.id == 'storey_0')
                .copyWith(
                  name: 'Партер · ±0.00',
                  walls: const [
                    ArchitectWall(
                      id: 'w1',
                      startPoint: Offset(0, 0),
                      endPoint: Offset(6, 0),
                      thickness: 0.25,
                      doors: [
                        ArchitectDoor(
                          id: 'd1',
                          wallId: 'w1',
                          offsetRatio: 0.35,
                          styleId: customStyleId,
                          uuid: 'door_uuid_1',
                        ),
                      ],
                      windows: [
                        ArchitectWindow(
                          id: 'win1',
                          wallId: 'w1',
                          offsetRatio: 0.75,
                          uuid: 'win_uuid_1',
                        ),
                      ],
                    ),
                  ],
                  columns: const [
                    ArchitectColumn(
                      id: 'col1',
                      position: Offset(0, 0),
                      width: 0.3,
                      depth: 0.3,
                    ),
                  ],
                  slabs: const [
                    ArchitectSlab(
                      id: 'slab1',
                      polygon: [
                        Offset(0, 0),
                        Offset(6, 0),
                        Offset(6, 5),
                        Offset(0, 5),
                      ],
                    ),
                  ],
                  components: const [
                    ArchitectComponentInstance(
                      id: 'comp1',
                      definitionId: customCompId,
                      position: Offset(3, 2.5),
                    ),
                  ],
                ),
            loadedArch.storeys
                .firstWhere((s) => s.id == 'storey_1')
                .copyWith(name: 'Етаж 2 · +3.10'),
            // Add a brand-new 3rd storey in architectural mode to verify manifest sync.
            const ArchitectStorey(
              id: 'storey_2',
              name: 'Етаж 3 · +5.95',
              elevation: 5.95,
              height: 2.80,
            ),
            ...loadedArch.storeys.where((s) => s.isRoof || s.isSite),
          ],
        )
        .syncRoofElevation();

    expect(
      await sourceLibrary.saveArchitectProject(manifest.id, editedArch),
      isTrue,
    );
    final updatedManifest = (await sourceLibrary.loadProject(manifest.id))!;
    final savedArch = (await sourceLibrary.loadArchitectProject(manifest.id))!;
    return (updatedManifest, savedArch);
  }

  test(
    'export and import synchronize architectural project so round-trip is identical',
    () async {
      final (sourceManifest, sourceArch) = await createRichProject();

      // Verify manifest synced the newly added storey_2 and renamed title.
      expect(sourceManifest.name, 'Villa Sync Renamed');
      expect(
        sourceManifest.storeys.map((s) => s.storeyId).toList(),
        ['storey_0', 'storey_1', 'storey_2'],
      );
      expect(sourceManifest.storeys[0].name, 'Партер · ±0.00');

      final exportDir1 = Directory('${tempDir.path}/export1')..createSync();
      final zip1 = await BimExportService.exportArchitecturalProjectZip(
        project: sourceManifest,
        architect: sourceArch,
        outputDirectory: exportDir1,
        libraryService: sourceLibrary,
      );

      // Remove custom library items before importing into clean target library.
      await ComponentLibraryService.instance.deleteCustomScript(
        'custom_arch_import_island_v1',
      );
      await FenestrationLibraryService.instance.deleteStyle(
        'custom_arch_import_door_v1',
      );
      expect(
        ComponentLibraryService.instance.findDefinition(
          'custom_arch_import_island_v1',
        ),
        isNull,
      );
      expect(
        FenestrationLibraryService.instance.getStyleById(
          'custom_arch_import_door_v1',
        ),
        isNull,
      );

      final imported = await BimImportService.importArchitecturalProjectZip(
        zipFile: zip1,
        libraryService: targetLibrary,
      );

      // Verify custom libraries were restored automatically.
      expect(
        ComponentLibraryService.instance.findDefinition(
          'custom_arch_import_island_v1',
        ),
        isNotNull,
      );
      expect(
        FenestrationLibraryService.instance.getStyleById(
          'custom_arch_import_door_v1',
        ),
        isNotNull,
      );
      expect(imported.restoredLibraryItemsCount, 2);

      // Verify ID, manifest, and architectural model are identical.
      expect(imported.project.id, sourceManifest.id);
      expect(imported.project.toJson(), sourceManifest.toJson());
      expect(imported.architect.name, sourceArch.name);
      expect(imported.architect.storeys.length, sourceArch.storeys.length);
      expect(
        imported.architect.storeys.map((s) => s.name).toList(),
        sourceArch.storeys.map((s) => s.name).toList(),
      );
      expect(
        imported.architect.cadUnderlays['storey_0']?.externalSourcePath,
        isNull,
      );

      // Verify persisted CAD underlay loads identically from imported project.
      final targetUnderlayService = ArchitectUnderlayService(
        libraryService: targetLibrary,
      );
      final restoredCad = await targetUnderlayService.loadSavedCadUnderlay(
        imported.architect.cadUnderlays['storey_0']!,
        projectId: imported.project.id,
      );
      expect(restoredCad, isNotNull);
      expect(
        restoredCad!.entities.whereType<DxfLine>().first.p1.dx,
        closeTo(12.5, 1e-6),
      );

      // Re-export the imported project and verify export1 and export2 are identical.
      final exportDir2 = Directory('${tempDir.path}/export2')..createSync();
      final zip2 = await BimExportService.exportArchitecturalProjectZip(
        project: imported.project,
        architect: imported.architect,
        outputDirectory: exportDir2,
        libraryService: targetLibrary,
      );

      final archive1 = ZipDecoder().decodeBytes(await zip1.readAsBytes());
      final archive2 = ZipDecoder().decodeBytes(await zip2.readAsBytes());

      String readText(Archive a, String name) => utf8.decode(
        a.files.singleWhere((f) => f.name == name).content as List<int>,
      );

      expect(
        jsonDecode(readText(archive2, 'project.json')),
        jsonDecode(readText(archive1, 'project.json')),
      );
      expect(
        jsonDecode(readText(archive2, 'architectural.json')),
        jsonDecode(readText(archive1, 'architectural.json')),
      );
      expect(
        jsonDecode(readText(archive2, 'libraries.json')),
        jsonDecode(readText(archive1, 'libraries.json')),
      );

      final pkg1 =
          jsonDecode(readText(archive1, 'package.json'))
              as Map<String, dynamic>;
      final pkg2 =
          jsonDecode(readText(archive2, 'package.json'))
              as Map<String, dynamic>;
      expect(pkg2['format'], pkg1['format']);
      expect(pkg2['version'], pkg1['version']);
      expect(pkg2['projectType'], pkg1['projectType']);
      expect(pkg2['projectId'], pkg1['projectId']);
      expect(pkg2['name'], pkg1['name']);
      expect(pkg2['files'], pkg1['files']);
    },
  );

  test(
    'importing into same library with colliding project ID allocates fresh ID without overwriting',
    () async {
      final (sourceManifest, sourceArch) = await createRichProject();
      final zip = await BimExportService.exportArchitecturalProjectZip(
        project: sourceManifest,
        architect: sourceArch,
        outputDirectory: tempDir,
        libraryService: sourceLibrary,
      );

      // Import into sourceLibrary where sourceManifest.id already exists.
      final duplicate = await BimImportService.importArchitecturalProjectZip(
        zipFile: zip,
        libraryService: sourceLibrary,
      );

      expect(duplicate.project.id, isNot(sourceManifest.id));
      expect(duplicate.project.name, sourceManifest.name);
      expect(duplicate.architect.id, duplicate.project.id);

      final all = await sourceLibrary.listProjects();
      expect(all.length, 2);
      expect(
        all.map((p) => p.id).toSet(),
        {sourceManifest.id, duplicate.project.id},
      );
    },
  );

  test(
    'renameProject keeps project.json and architectural.json names synchronized',
    () async {
      final (manifest, _) = await createRichProject();
      expect(
        await sourceLibrary.renameProject(manifest.id, 'Renamed Villa'),
        isTrue,
      );
      final reloadedManifest = (await sourceLibrary.loadProject(manifest.id))!;
      final reloadedArch = (await sourceLibrary.loadArchitectProject(
        manifest.id,
      ))!;
      expect(reloadedManifest.name, 'Renamed Villa');
      expect(reloadedArch.name, 'Renamed Villa');
    },
  );

  group('BimImportService validation and error handling', () {
    test('rejects invalid ZIP bytes', () async {
      final badFile = File('${tempDir.path}/bad.zip')
        ..writeAsBytesSync([1, 2, 3, 4, 5]);
      await expectLater(
        BimImportService.importArchitecturalProjectZip(
          zipFile: badFile,
          libraryService: targetLibrary,
        ),
        throwsA(
          isA<BimImportException>().having(
            (e) => e.code,
            'code',
            BimImportErrorCode.invalidArchive,
          ),
        ),
      );
    });

    test('rejects archive missing project.json or architectural.json', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('readme.txt', 2, utf8.encode('hi')));
      final zipFile = File('${tempDir.path}/missing.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive)!);
      await expectLater(
        BimImportService.importArchitecturalProjectZip(
          zipFile: zipFile,
          libraryService: targetLibrary,
        ),
        throwsA(
          isA<BimImportException>().having(
            (e) => e.code,
            'code',
            BimImportErrorCode.missingManifest,
          ),
        ),
      );
    });

    test('rejects structural BimPackage ZIPs', () async {
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'package.json',
            0,
            utf8.encode(jsonEncode({'format': 'KotoBimAnalysisPackage'})),
          ),
        );
      final zipFile = File('${tempDir.path}/struct.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive)!);
      await expectLater(
        BimImportService.importArchitecturalProjectZip(
          zipFile: zipFile,
          libraryService: targetLibrary,
        ),
        throwsA(
          isA<BimImportException>().having(
            (e) => e.code,
            'code',
            BimImportErrorCode.unsupportedPackageType,
          ),
        ),
      );
    });

    test('rejects checksum tampering in package.json', () async {
      final (sourceManifest, sourceArch) = await createRichProject();
      final zip = await BimExportService.exportArchitecturalProjectZip(
        project: sourceManifest,
        architect: sourceArch,
        outputDirectory: tempDir,
        libraryService: sourceLibrary,
      );
      final orig = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final tampered = Archive();
      for (final file in orig.files) {
        if (file.name == 'package.json') {
          final pkg =
              jsonDecode(utf8.decode(file.content as List<int>))
                  as Map<String, dynamic>;
          ((pkg['files'] as List).first as Map)['sha256'] = 'deadbeef';
          final bytes = utf8.encode(jsonEncode(pkg));
          tampered.addFile(ArchiveFile('package.json', bytes.length, bytes));
        } else {
          final bytes = file.content as List<int>;
          tampered.addFile(ArchiveFile(file.name, bytes.length, bytes));
        }
      }
      final tamperedFile = File('${tempDir.path}/tampered.zip')
        ..writeAsBytesSync(ZipEncoder().encode(tampered)!);
      await expectLater(
        BimImportService.importArchitecturalProjectZip(
          zipFile: tamperedFile,
          libraryService: targetLibrary,
        ),
        throwsA(
          isA<BimImportException>().having(
            (e) => e.code,
            'code',
            BimImportErrorCode.integrityCheckFailed,
          ),
        ),
      );
    });

    test('rejects path traversal (Zip Slip) entries', () async {
      final bytes = utf8.encode('evil');
      final archive = Archive()
        ..addFile(ArchiveFile('../evil.txt', bytes.length, bytes));
      final zipFile = File('${tempDir.path}/zipslip.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive)!);
      await expectLater(
        BimImportService.importArchitecturalProjectZip(
          zipFile: zipFile,
          libraryService: targetLibrary,
        ),
        throwsA(
          isA<BimImportException>().having(
            (e) => e.code,
            'code',
            BimImportErrorCode.unsafePath,
          ),
        ),
      );
    });

    test('rejects missing referenced underlay asset when package.json is absent', () async {
      final (sourceManifest, sourceArch) = await createRichProject();
      final zip = await BimExportService.exportArchitecturalProjectZip(
        project: sourceManifest,
        architect: sourceArch,
        outputDirectory: tempDir,
        libraryService: sourceLibrary,
      );
      final orig = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final incomplete = Archive();
      for (final file in orig.files) {
        if (file.name == 'package.json' ||
            file.name.endsWith('plan_scan.png')) {
          continue;
        }
        final bytes = file.content as List<int>;
        incomplete.addFile(ArchiveFile(file.name, bytes.length, bytes));
      }
      final incompleteFile = File('${tempDir.path}/incomplete.zip')
        ..writeAsBytesSync(ZipEncoder().encode(incomplete)!);
      await expectLater(
        BimImportService.importArchitecturalProjectZip(
          zipFile: incompleteFile,
          libraryService: targetLibrary,
        ),
        throwsA(
          isA<BimImportException>().having(
            (e) => e.code,
            'code',
            BimImportErrorCode.integrityCheckFailed,
          ),
        ),
      );
    });
  });

  group('UI Import integration on phone viewports', () {
    Future<void> pumpUntilFound(
      WidgetTester tester,
      Finder finder,
    ) async {
      for (var i = 0; i < 120; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .toList();
      final count = await tester.runAsync(
        () async => (await targetLibrary.listProjects()).length,
      );
      fail('Timed out waiting for $finder. libraryCount=$count, texts=$texts');
    }

    for (final lang in ['en', 'bg']) {
      testWidgets(
        'ArchitectStudioTab imports architectural ZIP cleanly ($lang)',
        timeout: const Timeout(Duration(seconds: 10)),
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final zipBytes = await tester.runAsync(() async {
            final (sourceManifest, sourceArch) = await createRichProject();
            final zip = await BimExportService.exportArchitecturalProjectZip(
              project: sourceManifest,
              architect: sourceArch,
              outputDirectory: tempDir,
              libraryService: sourceLibrary,
            );
            return zip.readAsBytes();
          });

          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ArchitectStudioTab(
                  libraryService: targetLibrary,
                  pickImportZipBytes: () async => zipBytes,
                ),
              ),
            ),
          );
          await pumpUntilFound(
            tester,
            find.byKey(const ValueKey('architect-studio-import-zip')),
          );

          await tester.tap(
            find.byKey(const ValueKey('architect-studio-import-zip')),
          );
          await tester.pump();
          await pumpUntilFound(tester, find.text('Villa Sync Renamed'));

          expect(find.text('Villa Sync Renamed'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'BimProjectLibraryScreen imports architectural ZIP from empty state ($lang)',
        timeout: const Timeout(Duration(seconds: 10)),
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final zipBytes = await tester.runAsync(() async {
            final (sourceManifest, sourceArch) = await createRichProject();
            final zip = await BimExportService.exportArchitecturalProjectZip(
              project: sourceManifest,
              architect: sourceArch,
              outputDirectory: tempDir,
              libraryService: sourceLibrary,
            );
            return zip.readAsBytes();
          });

          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BimProjectLibraryScreen(
                libraryService: targetLibrary,
                pickImportZipBytes: () async => zipBytes,
              ),
            ),
          );
          await pumpUntilFound(
            tester,
            find.byKey(const ValueKey('bim-library-empty-import-zip')),
          );

          await tester.tap(
            find.byKey(const ValueKey('bim-library-empty-import-zip')),
          );
          await tester.pump();
          await pumpUntilFound(tester, find.text('Villa Sync Renamed'));

          expect(find.text('Villa Sync Renamed'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
