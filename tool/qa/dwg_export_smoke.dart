// Headless Android end-to-end export test; never a product entry point.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/core/services/dwg_export_service.dart';
import 'package:kotoview/src/core/services/dwg_reader_service.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_dwg_export.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/services/structural_persistence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final l = await AppLocalizations.delegate.load(const Locale('bg'));
    final now = DateTime.now();
    const view = ArchitectSavedDrawing(
      id: 'plan:s',
      sourceId: 's',
      kind: ArchitectDrawingKind.plan,
    );
    final project = ArchitectProject(
      id: 'qa-export',
      name: 'Къща',
      createdAt: now,
      updatedAt: now,
      activeStoreyId: 's',
      units: ArchitectUnit.millimeters,
      storeys: const [
        ArchitectStorey(
          id: 's',
          name: 'Етаж',
          walls: [
            ArchitectWall(
              id: 'wall',
              startPoint: Offset.zero,
              endPoint: Offset(6, 0),
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
                id: 'place',
                drawingId: 'plan:s',
                anchor: Offset(-1, -1),
                frame: Rect.fromLTWH(20, 20, 130, 100),
              ),
            ],
          ),
        ],
      ),
    );
    final directory = await Directory(
      '/data/user/0/com.koto.kotoviewer/cache/dwg_export_qa',
    ).create(recursive: true);
    final views = await ArchitectDwgExport.exportViews(project, [view], l);
    final plan = await File(
      '${directory.path}/План 🏠.dwg',
    ).writeAsBytes(views.values.single);
    final planDoc = await DwgReaderService.read(plan.path);
    if (planDoc.headerVars[r'$INSUNITS'] != '4' ||
        planDoc.entities.whereType<DxfLwPolyline>().isEmpty) {
      throw StateError('Architecture geometry/units were lost');
    }
    print('DWG_EXPORT_ANDROID_ARCH_PASS entities=${planDoc.entities.length}');

    final sheets = await ArchitectDwgExport.exportSheets(
      project,
      project.document.sheets,
      l,
    );
    final sheet = await File(
      '${directory.path}/Лист.dwg',
    ).writeAsBytes(sheets.values.single);
    final sheetDoc = await DwgReaderService.read(sheet.path);
    if (!sheetDoc.layouts.contains('A-01') ||
        !sheetDoc.entities.whereType<DxfViewport>().any((v) => v.isActive)) {
      throw StateError('Native layout/viewport was lost');
    }
    print('DWG_EXPORT_ANDROID_SHEET_PASS layouts=${sheetDoc.layouts}');

    final bim = BimWorkProject(
      id: 'qa-bim',
      name: 'Конструкция',
      createdAt: now,
      updatedAt: now,
      structuralUnitsPerMeter: 1000,
      storeys: const [
        BimStoreyUnderlay(storeyId: 's', name: 'Етаж', elevation: 0),
      ],
    );
    const structural = StructuralProject(
      storeys: [
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
    final bimFile = await BimExportService.exportStoreyDwg(
      project: bim,
      structural: structural,
      storeyId: 's',
      outputDirectory: directory,
    );
    final bimDoc = await DwgReaderService.read(bimFile.path);
    if (!bimDoc.entities.any((e) => e.layer == 'S-COL')) {
      throw StateError('Structural geometry missing');
    }
    print('DWG_EXPORT_ANDROID_BIM_PASS entities=${bimDoc.entities.length}');

    final structuralFile = await StructuralPersistenceService.exportToDwgFile(
      project: structural,
      baseName: 'Самостоятелен етаж',
      cadUnitsPerMeter: 1000,
      outputDirectory: directory,
    );
    final structuralDoc = await DwgReaderService.read(structuralFile.path);
    if (structuralDoc.headerVars[r'$INSUNITS'] != '4' ||
        !structuralDoc.entities.whereType<DxfText>().any(
          (t) => t.text.contains('К1'),
        )) {
      throw StateError('Standalone BIM units or Cyrillic labels were lost');
    }
    print('DWG_EXPORT_ANDROID_STRUCTURAL_PASS');

    // Input > 1 MB proves that no large byte array crosses Android Binder.
    const count = 22000;
    final buffer = StringBuffer(
      '0\nSECTION\n2\nHEADER\n9\n\$ACADVER\n1\nAC1027\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n',
    );
    for (var i = 0; i < count; i++) {
      buffer.write(
        '0\nLINE\n8\nQA\n10\n$i.12345\n20\n0\n30\n0\n11\n${i + 1}.12345\n21\n10\n31\n0\n',
      );
    }
    buffer.write('0\nENDSEC\n0\nEOF\n');
    final large = Uint8List.fromList(utf8.encode(buffer.toString()));
    if (large.length < 1024 * 1024) {
      throw StateError('Transport fixture too small');
    }
    var cancelled = false;
    final timer = Timer(
      const Duration(milliseconds: 1),
      () => cancelled = true,
    );
    try {
      await DwgExportService.encode(large, isCancelled: () => cancelled);
      throw StateError('Cancelled export was published');
    } on DwgExportCancelled {
      print('DWG_EXPORT_ANDROID_CANCEL_PASS');
    } finally {
      timer.cancel();
    }

    final data = await DwgExportService.encode(large);
    final largeFile = await File(
      '${directory.path}/large.dwg',
    ).writeAsBytes(data);
    final largeDoc = await DwgReaderService.read(largeFile.path);
    if (largeDoc.entities.length != count) {
      throw StateError('Large export lost entities');
    }
    if (directory.listSync().any((f) => !f.path.endsWith('.dwg'))) {
      throw StateError('Intermediate export files leaked');
    }
    print(
      'DWG_EXPORT_ANDROID_PASS inputBytes=${large.length} largeEntities=$count intermediates=0',
    );
  } catch (error, stack) {
    print('DWG_EXPORT_ANDROID_FAILED $error\n$stack');
  }
}
