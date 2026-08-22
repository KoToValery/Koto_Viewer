import 'dart:convert';
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
  });
}
