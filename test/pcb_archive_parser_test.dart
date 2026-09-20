import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/pcb_viewer/models/pcb_models.dart';
import 'package:kotoview/src/features/pcb_viewer/parser/pcb_archive_parser.dart';

void main() {
  group('Multi-Layer PCB ZIP Archive Parser Tests (Proteus / Altium / KiCad)', () {
    late Uint8List mockZipBytes;

    setUp(() {
      final archive = Archive();

      // 1. Top Copper (Proteus .TOP)
      const topCopperGerber = '''
%FSLAX24Y24*%
%MOMM*%
%ADD10C,0.3000*%
%ADD11R,1.5000X1.0000*%
D10*
X100000Y100000D02*
X200000Y100000D01*
D11*
X150000Y150000D03*
M02*
''';
      archive.addFile(ArchiveFile('Project.TOP', topCopperGerber.length, utf8.encode(topCopperGerber)));

      // 2. Bottom Copper (Proteus .BOT)
      const botCopperGerber = '''
%FSLAX24Y24*%
%MOMM*%
%ADD10C,0.3000*%
D10*
X100000Y100000D02*
X100000Y200000D01*
M02*
''';
      archive.addFile(ArchiveFile('Project.BOT', botCopperGerber.length, utf8.encode(botCopperGerber)));

      // 3. Top Solder Mask (Proteus .SMT)
      const topMaskGerber = '''
%FSLAX24Y24*%
%MOMM*%
%ADD12R,1.7000X1.2000*%
D12*
X150000Y150000D03*
M02*
''';
      archive.addFile(ArchiveFile('Project.SMT', topMaskGerber.length, utf8.encode(topMaskGerber)));

      // 4. Top Silkscreen (Proteus .SST)
      const topSilkGerber = '''
%FSLAX24Y24*%
%MOMM*%
%ADD13C,0.1500*%
D13*
X120000Y120000D02*
X180000Y120000D01*
M02*
''';
      archive.addFile(ArchiveFile('Project.SST', topSilkGerber.length, utf8.encode(topSilkGerber)));

      // 5. Board Outline / Edge Cuts (Proteus .EDGE)
      const outlineGerber = '''
%FSLAX24Y24*%
%MOMM*%
%ADD14C,0.2000*%
D14*
X0Y0D02*
X500000Y0D01*
X500000Y300000D01*
X0Y300000D01*
X0Y0D01*
M02*
''';
      archive.addFile(ArchiveFile('Project.EDGE', outlineGerber.length, utf8.encode(outlineGerber)));

      // 6. Excellon CNC Drill Holes (.DRL)
      const drillContent = '''
M48
METRIC,TZ
T01C0.800
T02C1.200
%
T01
X10000Y10000
X20000Y10000
T02
X15000Y15000
M30
''';
      archive.addFile(ArchiveFile('Project.DRL', drillContent.length, utf8.encode(drillContent)));

      // 7. Bill of Materials (.CSV)
      const bomCsv = '''
Designator,Value,Footprint,Quantity,Description
R1,10k,0805,1,Resistor SMD
R2,4.7k,0805,1,Resistor SMD
C1,100nF,0603,1,Capacitor Ceramic
U1,ATmega328P,TQFP-32,1,Microcontroller 8-bit
''';
      archive.addFile(ArchiveFile('Bill_of_Materials.csv', bomCsv.length, utf8.encode(bomCsv)));

      final encoder = ZipEncoder();
      mockZipBytes = Uint8List.fromList(encoder.encode(archive)!);
    });

    test('isPcbZip correctly detects PCB Gerber & Drill ZIP archive', () {
      expect(PcbArchiveParser.isPcbZip(mockZipBytes, fileName: 'Proteus_Project.zip'), true);
    });

    test('parseZip parses all Proteus layers into a composite PcbProject', () {
      final project = PcbArchiveParser.parseZip(
        mockZipBytes,
        archiveName: 'Proteus_Project.zip',
        filePath: r'C:\Projects\Proteus_Project.zip',
      );

      expect(project.projectName, 'Proteus_Project');
      expect(project.totalLayers, 6); // TOP, BOT, SMT, SST, EDGE, DRL

      // Verify layer types
      final layerTypes = project.layers.map((l) => l.type).toList();
      expect(layerTypes.contains(PcbLayerType.copperTop), true);
      expect(layerTypes.contains(PcbLayerType.copperBottom), true);
      expect(layerTypes.contains(PcbLayerType.solderMaskTop), true);
      expect(layerTypes.contains(PcbLayerType.silkscreenTop), true);
      expect(layerTypes.contains(PcbLayerType.edgeCuts), true);
      expect(layerTypes.contains(PcbLayerType.drill), true);

      // Verify layer Z-order
      for (int i = 0; i < project.layers.length - 1; i++) {
        expect(project.layers[i].order <= project.layers[i + 1].order, true);
      }

      // Verify BOM parsing
      expect(project.bomEntries.length, 4);
      expect(project.bomEntries[0].designator, 'R1');
      expect(project.bomEntries[0].value, '10k');
      expect(project.bomEntries[0].footprint, '0805');

      expect(project.bomEntries[3].designator, 'U1');
      expect(project.bomEntries[3].value, 'ATmega328P');
      expect(project.bomEntries[3].footprint, 'TQFP-32');

      // Verify global bounding box
      expect(project.boundingBox.widthMm > 0, true);
      expect(project.boundingBox.heightMm > 0, true);
    });

    test('parseZip parses Gerber X2 archives with signed coordinates, macro apertures, and Gerber drills', () {
      final archive = Archive();

      const topCopperX2 = '''
G04 PROTEUS GERBER X2 FILE*
%TF.GenerationSoftware,Labcenter,Proteus,9.1*%
%TF.FileFunction,Copper,L1,Top*%
%FSLAX26Y26*%
%MOIN*%
%AMPPAD011*
4,1,4,-0.03,-0.06,0.03,-0.06,0.03,0.06,-0.03,0.06*%
%ADD10C,0.010000*%
%ADD71PPAD011*%
D10*
X-5093425Y+4084528D02*
X-5069449Y+4056969D01*
D71*
X-5000000Y+4000000D03*
M02*
''';
      archive.addFile(ArchiveFile('Project - CADCAM Top Copper.GBR', topCopperX2.length, utf8.encode(topCopperX2)));

      const drillX2 = '''
G04 PROTEUS GERBER X2 FILE*
%TF.FileFunction,Plated,1,2,PTH*%
%FSLAX26Y26*%
%MOIN*%
%ADD122C,0.020000*%
D122*
X-5000000Y+4000000D03*
M02*
''';
      archive.addFile(ArchiveFile('Project - CADCAM Drill TOP-BOT Plated.GBR', drillX2.length, utf8.encode(drillX2)));

      const profileX2 = '''
G04 PROTEUS GERBER X2 FILE*
%TF.FileFunction,NonPlated,1,2,NPTH*%
%FSLAX26Y26*%
%MOIN*%
%ADD44C,0.004000*%
D44*
X-5100000Y+4000000D02*
X-5100000Y+4100000D01*
X-4900000Y+4100000D01*
X-4900000Y+4000000D01*
X-5100000Y+4000000D01*
M02*
''';
      archive.addFile(ArchiveFile('Project - CADCAM Profile.GBR', profileX2.length, utf8.encode(profileX2)));

      final encoder = ZipEncoder();
      final zipBytes = Uint8List.fromList(encoder.encode(archive)!);

      final project = PcbArchiveParser.parseZip(
        zipBytes,
        archiveName: 'GerberX2_Project.zip',
        filePath: r'C:\Projects\GerberX2_Project.zip',
      );

      expect(project.totalLayers, 3);
      expect(project.layers.any((l) => l.type == PcbLayerType.copperTop), true);
      expect(project.layers.any((l) => l.type == PcbLayerType.drill), true);
      expect(project.layers.any((l) => l.type == PcbLayerType.edgeCuts), true);

      // Verify that coordinates with '+' parsed correctly (non-zero height/width)
      expect(project.boundingBox.widthMm > 0, true);
      expect(project.boundingBox.heightMm > 0, true);
    });

    test('parseZip parses mixed archive containing IFC 3D model, PDF document, and JPG image', () {
      final archive = Archive();

      // 1. IFC 3D BIM Model
      const mockIfc = 'ISO-10303-21;\nHEADER;\nFILE_DESCRIPTION((\'ViewDefinition [CoordinationView]\'),\'2;1\');\nENDSEC;\nDATA;\nENDSEC;\nEND-ISO-10303-21;\n';
      archive.addFile(ArchiveFile('Building_Design.ifc', mockIfc.length, utf8.encode(mockIfc)));

      // 2. PDF Document
      const mockPdf = '%PDF-1.4\n%mock pdf content\n%%EOF';
      archive.addFile(ArchiveFile('Specifications.pdf', mockPdf.length, utf8.encode(mockPdf)));

      // 3. JPG Image
      final mockJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0xFF, 0xD9]);
      archive.addFile(ArchiveFile('Facade_Render.jpg', mockJpg.length, mockJpg));

      final encoder = ZipEncoder();
      final zipBytes = Uint8List.fromList(encoder.encode(archive)!);

      final project = PcbArchiveParser.parseZip(
        zipBytes,
        archiveName: 'Project_Package.zip',
        filePath: r'C:\Projects\Project_Package.zip',
      );

      expect(project.projectName, 'Project_Package');
      expect(project.layers.isEmpty, true);

      // 3D Model (.ifc)
      expect(project.model3DFiles.length, 1);
      expect(project.model3DFiles.first.fileName, 'Building_Design.ifc');
      expect(project.model3DFiles.first.category, PcbFileCategory.model3D);

      // Document (.pdf)
      expect(project.documentFiles.length, 1);
      expect(project.documentFiles.first.fileName, 'Specifications.pdf');
      expect(project.documentFiles.first.category, PcbFileCategory.document);

      // Image (.jpg)
      expect(project.images.length, 1);
      expect(project.images.first.fileName, 'Facade_Render.jpg');

      // Archive Files (All 3)
      expect(project.archiveFiles.length, 3);
    });

    test('isPcbZipArchive and classifyFile accurately detect Proteus, KiCad, FreeCAD, and Altium archives', () async {
      final tempDir = await Directory.systemTemp.createTemp('koto_eda_test_');

      try {
        // 1. Proteus ARES archive (CADCAM *.txt, .pdsprj, BOM, 3D render)
        final proteusZipPath = '${tempDir.path}${Platform.pathSeparator}Proteus_Device.zip';
        final proteusArchive = Archive();
        proteusArchive.addFile(ArchiveFile('Device - CADCAM Top Copper.TXT', 10, utf8.encode('%FSLAX24Y24*%')));
        proteusArchive.addFile(ArchiveFile('Device - CADCAM Bottom Copper.TXT', 10, utf8.encode('%FSLAX24Y24*%')));
        proteusArchive.addFile(ArchiveFile('Device - CADCAM Drill.TXT', 10, utf8.encode('M48\nMETRIC,TZ\nT01C0.8\n%')));
        proteusArchive.addFile(ArchiveFile('Device.pdsprj', 20, utf8.encode('Proteus Project Data')));
        proteusArchive.addFile(ArchiveFile('bom_parts.csv', 15, utf8.encode('Designator,Value\nR1,10k')));
        proteusArchive.addFile(ArchiveFile('render_top.png', 10, Uint8List.fromList([1, 2, 3])));
        proteusArchive.addFile(ArchiveFile('board_model.step', 25, utf8.encode('ISO-10303-21;')));
        await File(proteusZipPath).writeAsBytes(ZipEncoder().encode(proteusArchive)!);

        expect(PcbArchiveParser.isPcbZipArchive(proteusZipPath), isTrue);

        // 2. KiCad archive (.kicad_pcb, .kicad_sch, 3D STEP, BOM, renders)
        final kicadZipPath = '${tempDir.path}${Platform.pathSeparator}KiCad_Project.zip';
        final kicadArchive = Archive();
        kicadArchive.addFile(ArchiveFile('mainboard.kicad_pcb', 30, utf8.encode('(kicad_pcb (version 20211014))')));
        kicadArchive.addFile(ArchiveFile('mainboard.kicad_sch', 20, utf8.encode('(kicad_sch (version 20211123))')));
        kicadArchive.addFile(ArchiveFile('mainboard.kicad_pro', 15, utf8.encode('{"meta": {}}')));
        kicadArchive.addFile(ArchiveFile('mainboard-BOM.csv', 15, utf8.encode('Id,Designator,Footprint\n1,C1,0603')));
        kicadArchive.addFile(ArchiveFile('pcb_render.jpg', 10, Uint8List.fromList([4, 5, 6])));
        kicadArchive.addFile(ArchiveFile('mainboard.step', 35, utf8.encode('ISO-10303-21;')));
        await File(kicadZipPath).writeAsBytes(ZipEncoder().encode(kicadArchive)!);

        expect(PcbArchiveParser.isPcbZipArchive(kicadZipPath), isTrue);

        // 3. FreeCAD PCB archive (.fcstd, board.step, photos)
        final freecadZipPath = '${tempDir.path}${Platform.pathSeparator}FreeCAD_Board.zip';
        final freecadArchive = Archive();
        freecadArchive.addFile(ArchiveFile('pcb_design.fcstd', 50, utf8.encode('FreeCAD binary data')));
        freecadArchive.addFile(ArchiveFile('pcb_board.step', 40, utf8.encode('ISO-10303-21; STEP CAD')));
        freecadArchive.addFile(ArchiveFile('assembled_photo.png', 10, Uint8List.fromList([7, 8, 9])));
        await File(freecadZipPath).writeAsBytes(ZipEncoder().encode(freecadArchive)!);

        expect(PcbArchiveParser.isPcbZipArchive(freecadZipPath), isTrue);

        // 4. Altium archive (.pcbdoc, .schdoc, .gtl, .gbl, .drl, BOM)
        final altiumZipPath = '${tempDir.path}${Platform.pathSeparator}Altium_Hardware.zip';
        final altiumArchive = Archive();
        altiumArchive.addFile(ArchiveFile('Motherboard.PcbDoc', 40, utf8.encode('Altium PCB binary')));
        altiumArchive.addFile(ArchiveFile('Motherboard.SchDoc', 30, utf8.encode('Altium Sch binary')));
        altiumArchive.addFile(ArchiveFile('Motherboard.GTL', 20, utf8.encode('%FSLAX24Y24*%')));
        altiumArchive.addFile(ArchiveFile('Motherboard.DRL', 15, utf8.encode('M48\n')));
        altiumArchive.addFile(ArchiveFile('Bill of Materials.xlsx', 25, utf8.encode('Excel BOM')));
        altiumArchive.addFile(ArchiveFile('3D_Board.step', 30, utf8.encode('ISO-10303-21;')));
        altiumArchive.addFile(ArchiveFile('top_photo.webp', 10, Uint8List.fromList([10, 11])));
        await File(altiumZipPath).writeAsBytes(ZipEncoder().encode(altiumArchive)!);

        expect(PcbArchiveParser.isPcbZipArchive(altiumZipPath), isTrue);

        // 5. Non-PCB Presentation ZIP (Videos, facade photos, pdf presentation) -> MUST BE FALSE for PCB
        final nonPcbZipPath = '${tempDir.path}${Platform.pathSeparator}Architecture_Presentation.zip';
        final nonPcbArchive = Archive();
        nonPcbArchive.addFile(ArchiveFile('01_Walkthrough.mp4', 50, Uint8List.fromList([1, 2, 3])));
        nonPcbArchive.addFile(ArchiveFile('02_Render.jpg', 30, Uint8List.fromList([4, 5])));
        nonPcbArchive.addFile(ArchiveFile('03_FloorPlan.pdf', 20, Uint8List.fromList([6, 7])));
        await File(nonPcbZipPath).writeAsBytes(ZipEncoder().encode(nonPcbArchive)!);

        expect(PcbArchiveParser.isPcbZipArchive(nonPcbZipPath), isFalse);
      } finally {
        try {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {}
      }
    });

    test('classifyFile recognizes FreeCAD, Proteus, Altium and Eagle project types', () {
      expect(PcbArchiveParser.classifyFile('board.fcstd'), PcbFileCategory.sourceCad);
      expect(PcbArchiveParser.classifyFile('circuit.pdsprj'), PcbFileCategory.sourceCad);
      expect(PcbArchiveParser.classifyFile('layout.lyt'), PcbFileCategory.sourceCad);
      expect(PcbArchiveParser.classifyFile('project.pcbdoc'), PcbFileCategory.sourceCad);
      expect(PcbArchiveParser.classifyFile('project.cam'), PcbFileCategory.sourceCad);
      expect(PcbArchiveParser.classifyFile('board.brd'), PcbFileCategory.sourceCad);
      expect(PcbArchiveParser.classifyFile('parts_bom.csv'), PcbFileCategory.bom);
      expect(PcbArchiveParser.classifyFile('assembly_cpl.csv'), PcbFileCategory.assembly);
    });
  });
}


