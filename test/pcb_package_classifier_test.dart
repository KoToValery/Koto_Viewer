import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/pcb_viewer/models/pcb_models.dart';
import 'package:kotoview/src/features/pcb_viewer/parser/pcb_archive_parser.dart';

void main() {
  group('PCB Package Smart File Classifier Tests', () {
    test('classifyFile correctly categorizes arbitrary folder structures and names', () {
      expect(
        PcbArchiveParser.classifyFile('outputs/3D/casing.step'),
        equals(PcbFileCategory.model3D),
      );
      expect(
        PcbArchiveParser.classifyFile('CAM/Gerbers/board-F_Cu.gtl'),
        equals(PcbFileCategory.gerber2D),
      );
      expect(
        PcbArchiveParser.classifyFile('CAM/Drills/board.drl'),
        equals(PcbFileCategory.drill),
      );
      expect(
        PcbArchiveParser.classifyFile('Documentation/schematic_v2.pdf'),
        equals(PcbFileCategory.schematic),
      );
      expect(
        PcbArchiveParser.classifyFile('src/controller.kicad_sch'),
        equals(PcbFileCategory.schematic),
      );
      expect(
        PcbArchiveParser.classifyFile('assembly/pick_and_place.csv'),
        equals(PcbFileCategory.assembly),
      );
      expect(
        PcbArchiveParser.classifyFile('cpl_positions.csv'),
        equals(PcbFileCategory.assembly),
      );
      expect(
        PcbArchiveParser.classifyFile('manufacturing/bom_jlcpcb.csv'),
        equals(PcbFileCategory.bom),
      );
      expect(
        PcbArchiveParser.classifyFile('docs/layer_stackup.pdf'),
        equals(PcbFileCategory.document),
      );
      expect(
        PcbArchiveParser.classifyFile('reports/drc_check.rpt'),
        equals(PcbFileCategory.report),
      );
      expect(
        PcbArchiveParser.classifyFile('README_PRODUCTION.txt'),
        equals(PcbFileCategory.report),
      );
      expect(
        PcbArchiveParser.classifyFile('renders/board_top_3d.png'),
        equals(PcbFileCategory.image),
      );
      expect(
        PcbArchiveParser.classifyFile('source/board.kicad_pcb'),
        equals(PcbFileCategory.sourceCad),
      );
    });

    test('parseZip populates categorized collections for synthetic multi-folder archive', () {
      final archive = Archive();
      archive.addFile(ArchiveFile('3D/model.step', 10, utf8.encode('ISO-10303-21;')));
      archive.addFile(ArchiveFile('Docs/schematic_circuit.pdf', 8, utf8.encode('%PDF-1.4')));
      archive.addFile(ArchiveFile('Docs/layers.pdf', 8, utf8.encode('%PDF-1.4')));
      archive.addFile(ArchiveFile('BOM/bill_of_materials.csv', 20, utf8.encode('Designator,Value\nR1,10k\n')));
      archive.addFile(ArchiveFile('Assembly/cpl_pos.csv', 18, utf8.encode('Designator,X,Y\nR1,10,20\n')));
      archive.addFile(ArchiveFile('Reports/stats.rpt', 15, utf8.encode('Board Statistics')));
      archive.addFile(ArchiveFile('CAD/main.kicad_pcb', 16, utf8.encode('(kicad_pcb (version 4))')));

      final zipData = ZipEncoder().encode(archive);
      expect(zipData, isNotNull);

      final project = PcbArchiveParser.parseZip(
        Uint8List.fromList(zipData!),
        archiveName: 'Project_Package.zip',
        filePath: 'Project_Package.zip',
      );

      expect(project.model3DFiles.length, equals(1));
      expect(project.model3DFiles.first.fileName, equals('3D/model.step'));
      expect(project.model3DFiles.first.category, equals(PcbFileCategory.model3D));

      expect(project.schematicFiles.length, equals(1));
      expect(project.schematicFiles.first.fileName, equals('Docs/schematic_circuit.pdf'));

      expect(project.documentFiles.length, equals(1));
      expect(project.documentFiles.first.fileName, equals('Docs/layers.pdf'));

      expect(project.bomEntries.length, equals(1));
      expect(project.bomEntries.first.designator, equals('R1'));

      expect(project.assemblyFiles.length, equals(1));
      expect(project.assemblyFiles.first.fileName, equals('Assembly/cpl_pos.csv'));

      expect(project.reportFiles.length, equals(1));
      expect(project.reportFiles.first.fileName, equals('Reports/stats.rpt'));

      expect(project.sourceCadFiles.length, equals(1));
      expect(project.sourceCadFiles.first.fileName, equals('CAD/main.kicad_pcb'));
    });

    test('Real KiCad production package zip (esp32_board_Full_Production_Package.zip)', () {
      final realPath = r'H:\My Drive\RABOTNA\KiCAD\RGB_LED_esp32\esp32_board_Full_Production_Package.zip';
      final file = File(realPath);
      if (!file.existsSync()) {
        // Skip if running in environment where drive H: is not mounted
        return;
      }

      final bytes = file.readAsBytesSync();
      final project = PcbArchiveParser.parseZip(
        bytes,
        archiveName: 'esp32_board_Full_Production_Package.zip',
        filePath: realPath,
      );

      // Verify 2D Layers (Gerbers + Drill)
      expect(project.layers.length, greaterThanOrEqualTo(9));

      // Verify 3D Model
      expect(project.model3DFiles.length, equals(1));
      expect(project.model3DFiles.first.fileName, equals('5_3D_Model/esp32_board.step'));
      expect(project.model3DFiles.first.category, equals(PcbFileCategory.model3D));

      // Verify Schematics (both PDF and KiCad schematic)
      expect(project.schematicFiles.length, equals(2));
      final schNames = project.schematicFiles.map((s) => s.fileName).toList();
      expect(schNames, contains('6_Documentation/esp32_board_schematic.pdf'));
      expect(schNames, contains('7_Source_Project/esp32_board.kicad_sch'));

      // Verify BOM (19 unique line items, 28 total component parts)
      expect(project.bomEntries.length, equals(19));
      expect(project.totalComponents, equals(28));

      // Verify Assembly (CPL pos, IPC-D356, XML)
      expect(project.assemblyFiles.length, equals(3));
      final assyNames = project.assemblyFiles.map((a) => a.fileName).toList();
      expect(assyNames, contains('3_Assembly/esp32_board_cpl_pos.csv'));
      expect(assyNames, contains('3_Assembly/esp32_board.d356'));
      expect(assyNames, contains('3_Assembly/esp32_board.xml'));

      // Verify Documentation
      expect(project.documentFiles.length, equals(3));
      final docNames = project.documentFiles.map((d) => d.fileName).toList();
      expect(docNames, contains('6_Documentation/esp32_board_pcb_layers.pdf'));
      expect(docNames, contains('2_Drill/esp32_board-PTH-drl_map.pdf'));
      expect(docNames, contains('2_Drill/esp32_board-NPTH-drl_map.pdf'));

      // Verify Reports
      expect(project.reportFiles.length, equals(3));
      final rptNames = project.reportFiles.map((r) => r.fileName).toList();
      expect(rptNames, contains('esp32_board-drill.rpt'));
      expect(rptNames, contains('README_PACKAGE.txt'));
      expect(rptNames, contains('6_Documentation/esp32_board_board_stats.rpt'));

      // Verify Source CAD
      expect(project.sourceCadFiles.length, equals(2));
      final cadNames = project.sourceCadFiles.map((c) => c.fileName).toList();
      expect(cadNames, contains('7_Source_Project/esp32_board.kicad_pcb'));
      expect(cadNames, contains('7_Source_Project/esp32_board.kicad_pro'));
    });

    test('PdfItem.fileType recognizes .rpt, .step, .kicad_sch as supported types', () {
      expect(PdfItem.fromPath('drill.rpt').fileType, equals(KotoFileType.txt));
      expect(PdfItem.fromPath('board.step').fileType, equals(KotoFileType.step));
      expect(PdfItem.fromPath('schematic.kicad_sch').fileType, equals(KotoFileType.kicad));
      expect(PdfItem.fromPath('board.kicad_pcb').fileType, equals(KotoFileType.kicad));
      expect(PdfItem.fromPath('drawing.pdf').fileType, equals(KotoFileType.pdf));
    });
  });
}
