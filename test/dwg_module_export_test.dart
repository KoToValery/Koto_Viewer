import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/core/services/dwg_export_service.dart';
import 'package:kotoview/src/core/services/dwg_reader_service.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_dwg_export.dart';
import 'package:kotoview/src/features/architect/services/architect_export_job.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/services/structural_persistence_service.dart';

const view = ArchitectSavedDrawing(
  id: 'plan:s',
  sourceId: 's',
  kind: ArchitectDrawingKind.plan,
);
ArchitectProject fixture() => ArchitectProject(
  id: 'native-export',
  name: 'Къща',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  units: ArchitectUnit.millimeters,
  storeys: const [
    ArchitectStorey(
      id: 's',
      name: 'Етаж',
      walls: [
        ArchitectWall(id: 'a', startPoint: Offset.zero, endPoint: Offset(6, 0)),
        ArchitectWall(
          id: 'b',
          startPoint: Offset(6, 0),
          endPoint: Offset(6, 5),
        ),
        ArchitectWall(
          id: 'c',
          startPoint: Offset(6, 5),
          endPoint: Offset(0, 5),
        ),
        ArchitectWall(id: 'd', startPoint: Offset(0, 5), endPoint: Offset.zero),
      ],
      zones: [
        ArchitectZone(
          id: 'room',
          name: 'Дневна',
          number: '101',
          category: ArchitectZoneCategory.living,
          polygon: [
            Offset(.2, .2),
            Offset(5.8, .2),
            Offset(5.8, 4.8),
            Offset(.2, 4.8),
          ],
        ),
      ],
    ),
  ],
  document: const ArchitectDocument(
    drawings: [view],
    sheets: [
      ArchitectSheet(
        id: 'sheet',
        number: 'A-01',
        placements: [
          ArchitectDrawingPlacement(
            id: 'p',
            drawingId: 'plan:s',
            frame: Rect.fromLTWH(20, 20, 130, 100),
            anchor: Offset(-1, -1),
            scale: 100,
          ),
        ],
      ),
    ],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const run = bool.fromEnvironment('RUN_DWG_EXPORT_INTEGRATION');
  final enabled = run && Platform.isWindows;
  late Directory temp;
  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('bg'));
    final fonts = FontLoader('ArchitectNoto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await fonts.load();
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dwg_module_export_');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test(
    'architecture DWG preserves editable vectors, units and Cyrillic',
    () async {
      final p = fixture();
      final before = jsonEncode(p.toJson());
      final progress = <double>[];
      final files = await ArchitectDwgExport.exportViews(
        p,
        [view],
        l,
        onProgress: progress.add,
      );
      expect(files.keys.single, endsWith('.dwg'));
      final file = await File(
        '${temp.path}/План 🏠.dwg',
      ).writeAsBytes(files.values.single);
      final doc = await DwgReaderService.read(file.path);
      expect(doc.headerVars[r'$INSUNITS'], '4');
      expect(doc.entities.whereType<DxfLwPolyline>(), isNotEmpty);
      expect(doc.entities.whereType<DxfHatch>(), isNotEmpty);
      expect(
        doc.entities.whereType<DxfMText>().any(
          (t) => t.cleanText.contains('Дневна'),
        ),
        isTrue,
      );
      expect(doc.bounds.width, greaterThan(5900));
      expect(progress.last, 1);
      expect(jsonEncode(p.toJson()), before);
      expect(temp.listSync().length, 1);
    },
    skip: !enabled,
  );

  test('DWG sheets preserve native layouts and viewports', () async {
    final p = fixture();
    final files = await ArchitectDwgExport.exportSheets(
      p,
      p.document.sheets,
      l,
    );
    final file = await File(
      '${temp.path}/Лист.dwg',
    ).writeAsBytes(files.values.single);
    final doc = await DwgReaderService.read(file.path);
    expect(doc.layouts, contains('A-01'));
    final viewport = doc.layoutEntities['A-01']!
        .whereType<DxfViewport>()
        .where((v) => v.isActive)
        .single;
    expect(viewport.width, closeTo(130, 1e-6));
    expect(viewport.height, closeTo(100, 1e-6));
    expect(doc.entities.whereType<DxfLwPolyline>(), isNotEmpty);
  }, skip: !enabled);

  test('cancelled architecture export returns no files', () async {
    await expectLater(
      ArchitectDwgExport.exportViews(
        fixture(),
        [view],
        l,
        isCancelled: () => true,
      ),
      throwsA(isA<ArchitectExportCancelled>()),
    );
  });

  test(
    'standalone BIM exports current storey with native units and Cyrillic',
    () async {
      const project = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'current',
            name: 'Етаж',
            elevation: 0,
            columns: [
              StructuralColumn(
                id: 'column',
                name: 'К1',
                center: Offset(3000, 4000),
                width: 300,
                height: 400,
              ),
            ],
          ),
          StoreyLevel(
            id: 'other',
            name: 'Друг етаж',
            elevation: 3,
            columns: [
              StructuralColumn(
                id: 'other-column',
                name: 'К2',
                center: Offset(100000, 100000),
                width: 300,
                height: 400,
              ),
            ],
          ),
        ],
      );
      final file = await StructuralPersistenceService.exportToDwgFile(
        project: project,
        baseName: 'Конструкция',
        cadUnitsPerMeter: 1000,
        outputDirectory: temp,
      );
      final doc = await DwgReaderService.read(file.path);
      expect(doc.headerVars[r'$INSUNITS'], '4');
      expect(
        doc.entities
            .whereType<DxfLwPolyline>()
            .where((e) => e.layer == 'S-COL')
            .length,
        1,
      );
      expect(
        doc.entities.whereType<DxfText>().any((t) => t.text.contains('К1')),
        isTrue,
      );
      expect(doc.bounds.right, lessThan(10000));
      expect(temp.listSync().length, 1);
    },
    skip: !enabled,
  );

  test(
    'BIM DWG merges original DWG underlay, structural layers and saved units',
    () async {
      final lib = BimProjectLibraryService(
        customRootDir: Directory('${temp.path}/library'),
      );
      var project = await lib.createProject(
        name: 'Конструкция',
        storeys: const [
          BimStoreyUnderlay(storeyId: 's', name: 'Етаж', elevation: 0),
        ],
      );
      const source =
          '0\nSECTION\n2\nHEADER\n9\n\$ACADVER\n1\nAC1027\n9\n\$INSUNITS\n70\n4\n0\nENDSEC\n'
          '0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n1\n0\nLAYER\n2\nARCH\n70\n0\n62\n7\n6\nContinuous\n0\nENDTAB\n0\nENDSEC\n'
          '0\nSECTION\n2\nENTITIES\n0\nLINE\n8\nARCH\n10\n1000\n20\n2000\n30\n0\n11\n7000\n21\n2000\n31\n0\n0\nENDSEC\n0\nEOF\n';
      final original = await File('${temp.path}/Архитектура.dwg').writeAsBytes(
        await DwgExportService.encode(Uint8List.fromList(utf8.encode(source))),
      );
      await lib.attachUnderlayFile(project.id, 's', original);
      project = (await lib.loadProject(project.id))!;
      project = project.copyWith(
        structuralUnitsPerMeter: 1000,
        structuralOrigin: const Offset(1000, 2000),
        storeys: [
          project.storeys.single.copyWith(
            controlPoint: const Offset(1000, 2000),
            layerVisibility: const {'ARCH': false},
          ),
        ],
      );
      final structural = StructuralProject(
        title: project.name,
        storeys: const [
          StoreyLevel(
            id: 's',
            name: 'Етаж',
            elevation: 0,
            columns: [
              StructuralColumn(
                id: 'c',
                name: 'К1',
                center: Offset(3000, 4000),
                width: 300,
                height: 400,
              ),
            ],
          ),
        ],
      );
      final out = await BimExportService.exportStoreyDwg(
        project: project,
        structural: structural,
        storeyId: 's',
        outputDirectory: Directory('${temp.path}/output'),
        libraryService: lib,
      );
      final doc = await DwgReaderService.read(out.path);
      expect(out.path, endsWith('.dwg'));
      expect(doc.layers['ARCH']!.isVisible, isFalse);
      final column = doc.entities
          .whereType<DxfLwPolyline>()
          .where((e) => e.layer == 'S-COL')
          .single
          .getBoundingBox(doc.blocks)!;
      expect(column.left, closeTo(2850, 1e-5));
      expect(column.top, closeTo(3800, 1e-5));
      expect(column.right, closeTo(3150, 1e-5));
      expect(column.bottom, closeTo(4200, 1e-5));
      expect(doc.bounds.right, greaterThanOrEqualTo(7000));
      expect(out.parent.listSync().whereType<File>().length, 1);
      expect(out.parent.listSync().whereType<Directory>(), isEmpty);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
