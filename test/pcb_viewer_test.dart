import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/pcb_viewer/models/pcb_models.dart';
import 'package:kotoview/src/features/pcb_viewer/parser/gerber_parser.dart';
import 'package:kotoview/src/features/pcb_viewer/parser/drill_parser.dart';

void main() {
  group('PCB File Type Identification Tests', () {
    test('PdfItem correctly identifies Gerber layers and Drill files', () {
      final gbrItem = PdfItem(
        path: '/storage/emulated/0/Download/esp32_board-F_Cu.gbr',
        name: 'esp32_board-F_Cu.gbr',
        sizeInBytes: 154000,
        lastOpened: DateTime.now(),
      );
      expect(gbrItem.fileType, equals(KotoFileType.gbr));
      expect(gbrItem.isGerber, isTrue);
      expect(gbrItem.isPcb, isTrue);
      expect(gbrItem.isVector, isTrue);

      final gtlItem = PdfItem(
        path: '/storage/emulated/0/Download/layer1.gtl',
        name: 'layer1.gtl',
        sizeInBytes: 80000,
        lastOpened: DateTime.now(),
      );
      expect(gtlItem.fileType, equals(KotoFileType.gbr));

      final drlItem = PdfItem(
        path: '/storage/emulated/0/Download/esp32_board.drl',
        name: 'esp32_board.drl',
        sizeInBytes: 12000,
        lastOpened: DateTime.now(),
      );
      expect(drlItem.fileType, equals(KotoFileType.drl));
      expect(drlItem.isDrill, isTrue);
      expect(drlItem.isPcb, isTrue);

      final xlnItem = PdfItem(
        path: '/storage/emulated/0/Download/through_holes.xln',
        name: 'through_holes.xln',
        sizeInBytes: 15000,
        lastOpened: DateTime.now(),
      );
      expect(xlnItem.fileType, equals(KotoFileType.drl));
    });
  });

  group('Gerber RS-274X Parser Tests', () {
    test('Parses format spec, aperture definitions, tracks, flash pads, and copper regions', () {
      const gbrContent = '''%FSLAX44Y44*%
%MOMM*%
%LPD*%
%ADD10C,0.2500*%
%ADD11R,1.5000X1.0000*%
%ADD12C,0.8000*%
G04 Layer: Top Copper*
G54D10*
X100000Y100000D02*
X500000Y100000D01*
X500000Y400000D01*
D11*
X100000Y100000D03*
X500000Y400000D03*
G36*
X200000Y200000D02*
X300000Y200000D01*
X300000Y300000D01*
X200000Y300000D01*
G37*
M02*
''';

      final bytes = Uint8List.fromList(utf8.encode(gbrContent));
      final doc = GerberParser.parse(bytes, fileName: 'esp32_board-F_Cu.gbr');

      expect(doc.layerType, equals(PcbLayerType.copperTop));
      expect(doc.trackCount, equals(2)); // 2 linear tracks
      expect(doc.padCount, equals(2)); // 2 flashed rectangular pads
      expect(doc.regionCount, equals(1)); // 1 copper polygon pour

      // Bounding box in mm
      expect(doc.boundingBox.minX, lessThanOrEqualTo(10.0));
      expect(doc.boundingBox.maxX, greaterThanOrEqualTo(50.0));
      expect(doc.boundingBox.minY, lessThanOrEqualTo(10.0));
      expect(doc.boundingBox.maxY, greaterThanOrEqualTo(40.0));
      expect(doc.boundingBox.widthMm, greaterThan(35.0));
      expect(doc.boundingBox.heightMm, greaterThan(25.0));
    });

    test('Identifies board outline Edge_Cuts layer', () {
      const gbrContent = '''%FSLAX44Y44*%
%MOMM*%
%ADD10C,0.15*%
D10*
X0Y0D02*
X1000000Y0D01*
X1000000Y800000D01*
X0Y800000D01*
X0Y0D01*
M02*
''';
      final bytes = Uint8List.fromList(utf8.encode(gbrContent));
      final doc = GerberParser.parse(bytes, fileName: 'board_edge_cuts.gbr');

      expect(doc.layerType, equals(PcbLayerType.edgeCuts));
      expect(doc.trackCount, equals(4));
      expect(doc.boundingBox.widthMm, closeTo(100.0, 1.0));
      expect(doc.boundingBox.heightMm, closeTo(80.0, 1.0));
    });
  });

  group('Excellon Drill Parser Tests', () {
    test('Parses tool sizes and drill hole coordinates', () {
      const drlContent = '''; Drill file
M48
METRIC
T01C0.8
T02C1.2
T03C3.2
%
T01
X10.0Y10.0
X20.0Y10.0
X30.0Y10.0
T02
X50.0Y50.0
X60.0Y50.0
T03
X5.0Y5.0
X95.0Y5.0
X95.0Y75.0
X5.0Y75.0
M30
''';

      final bytes = Uint8List.fromList(utf8.encode(drlContent));
      final doc = DrillParser.parse(bytes, fileName: 'board_drills.drl');

      expect(doc.layerType, equals(PcbLayerType.drill));
      expect(doc.drillHoles.length, equals(9));
      expect(doc.holeCount, equals(9));

      // Check tool 1 holes
      final t1Holes = doc.drillHoles.where((h) => h.toolId == 1).toList();
      expect(t1Holes.length, equals(3));
      expect(t1Holes.first.diameterMm, equals(0.8));

      // Check tool 3 mounting holes (3.2 mm)
      final t3Holes = doc.drillHoles.where((h) => h.toolId == 3).toList();
      expect(t3Holes.length, equals(4));
      expect(t3Holes.first.diameterMm, equals(3.2));

      expect(doc.boundingBox.widthMm, greaterThan(80.0));
      expect(doc.boundingBox.heightMm, greaterThan(65.0));
    });
  });
}
