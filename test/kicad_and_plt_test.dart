import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/kicad_viewer/parser/s_expression_parser.dart';
import 'package:kotoview/src/features/kicad_viewer/parser/kicad_pcb_parser.dart';
import 'package:kotoview/src/features/kicad_viewer/parser/kicad_sch_parser.dart';
import 'package:kotoview/src/features/hpgl_viewer/models/hpgl_models.dart';
import 'package:kotoview/src/features/hpgl_viewer/parser/hpgl_parser.dart';

void main() {
  group('Stage 1: File Type Identification Tests', () {
    test('PdfItem correctly identifies KiCad and HPGL plotter files', () {
      final pcbItem = PdfItem(
        path: '/storage/emulated/0/Download/motherboard.kicad_pcb',
        name: 'motherboard.kicad_pcb',
        sizeInBytes: 250000,
        lastOpened: DateTime.now(),
      );
      expect(pcbItem.fileType, equals(KotoFileType.kicad));
      expect(pcbItem.isKicad, isTrue);
      expect(pcbItem.isPcb, isTrue);

      final schItem = PdfItem(
        path: '/storage/emulated/0/Download/power_supply.kicad_sch',
        name: 'power_supply.kicad_sch',
        sizeInBytes: 60000,
        lastOpened: DateTime.now(),
      );
      expect(schItem.fileType, equals(KotoFileType.kicad));

      final pltItem = PdfItem(
        path: '/storage/emulated/0/Download/floor_plan.plt',
        name: 'floor_plan.plt',
        sizeInBytes: 90000,
        lastOpened: DateTime.now(),
      );
      expect(pltItem.fileType, equals(KotoFileType.plt));
      expect(pltItem.isPlotter, isTrue);
      expect(pltItem.isVector, isTrue);

      final hpglItem = PdfItem(
        path: '/storage/emulated/0/Download/drawing.hpgl',
        name: 'drawing.hpgl',
        sizeInBytes: 45000,
        lastOpened: DateTime.now(),
      );
      expect(hpglItem.fileType, equals(KotoFileType.plt));
    });
  });

  group('KiCad S-Expression & PCB Parser Tests', () {
    test('SExpressionParser parses nested expressions, strings, and atoms', () {
      const sexp = '''(kicad_pcb (version 20211014) (generator "pcbnew")
  (general (thickness 1.6))
  (segment (start 100.5 50.2) (end 120.0 50.2) (width 0.25) (layer "F.Cu"))
)''';

      final root = SExpressionParser.parse(sexp);
      expect(root.name, equals('kicad_pcb'));

      final gen = root.findChild('generator');
      expect(gen, isNotNull);
      expect(gen!.name, equals('generator'));
      expect(gen.values.first, equals('pcbnew'));

      final seg = root.findChild('segment');
      expect(seg, isNotNull);
      final start = seg!.findChild('start');
      expect(start!.getDouble(0), equals(100.5));
      expect(start.getDouble(1), equals(50.2));
    });

    test('KicadPcbParser extracts tracks, footprints, pads, vias, and board bounds', () {
      const kicadPcbContent = '''(kicad_pcb (version 20211014) (generator "pcbnew")
  (segment (start 10.0 10.0) (end 50.0 10.0) (width 0.3) (layer "F.Cu"))
  (segment (start 50.0 10.0) (end 50.0 40.0) (width 0.3) (layer "F.Cu"))
  (via (at 50.0 40.0) (size 0.8) (drill 0.4) (layers "F.Cu" "B.Cu"))
  (footprint "Resistor_SMD:R_0805" (layer "F.Cu")
    (at 30.0 25.0 0)
    (pad "1" smd roundrect (at -0.95 0) (size 1.0 1.3) (layers "F.Cu" "F.Mask"))
    (pad "2" smd roundrect (at 0.95 0) (size 1.0 1.3) (layers "F.Cu" "F.Mask"))
  )
  (gr_line (start 0.0 0.0) (end 60.0 0.0) (width 0.15) (layer "Edge.Cuts"))
  (gr_line (start 60.0 0.0) (end 60.0 50.0) (width 0.15) (layer "Edge.Cuts"))
  (gr_line (start 60.0 50.0) (end 0.0 50.0) (width 0.15) (layer "Edge.Cuts"))
  (gr_line (start 0.0 50.0) (end 0.0 0.0) (width 0.15) (layer "Edge.Cuts"))
)''';

      final bytes = Uint8List.fromList(utf8.encode(kicadPcbContent));
      final doc = KicadPcbParser.parse(bytes, fileName: 'test_board.kicad_pcb');

      expect(doc.trackCount, equals(6)); // 2 copper segments + 4 edge cut lines
      expect(doc.padCount, equals(3)); // 2 SMD pads + 1 via pad
      expect(doc.holeCount, equals(1)); // 1 via drill hole
      expect(doc.boundingBox.widthMm, greaterThanOrEqualTo(60.0));
      expect(doc.boundingBox.heightMm, greaterThanOrEqualTo(50.0));
    });

    test('KicadSchParser parses schematic wires and symbols', () {
      const kicadSchContent = '''(kicad_sch (version 20211123) (generator "eeschema")
  (wire (pts (xy 20.0 30.0) (xy 50.0 30.0)))
  (junction (at 50.0 30.0) (diameter 0.9))
  (symbol (lib_id "Device:R") (at 50.0 40.0 0))
)''';

      final bytes = Uint8List.fromList(utf8.encode(kicadSchContent));
      final doc = KicadSchParser.parse(bytes, fileName: 'circuit.kicad_sch');

      expect(doc.commands.length, equals(3)); // 1 wire line + 1 junction + 1 symbol indicator
      expect(doc.boundingBox.widthMm, greaterThan(25.0));
    });
  });

  group('HPGL Plotter Parser Tests', () {
    test('Parses HP-GL commands: pens, pen up/down, coordinates, circles, rectangles', () {
      const hpglContent = '''IN;
SP1;
PW0.3;
PU100,200;
PD500,200,500,600,100,600,100,200;
SP2;
PU300,400;
CI50;
SP3;
PU600,600;
ER100,80;
''';

      final bytes = Uint8List.fromList(utf8.encode(hpglContent));
      final doc = HpglParser.parse(bytes, fileName: 'architectural_plan.plt');

      expect(doc.elements.length, equals(3)); // 1 polygon rectangle + 1 circle + 1 ER rectangle
      expect(doc.penCount, equals(3)); // 3 pens used (SP1, SP2, SP3)
      expect(doc.boundingBox.minX, lessThanOrEqualTo(100.0));
      expect(doc.boundingBox.maxX, greaterThanOrEqualTo(700.0));
      expect(doc.boundingBox.minY, lessThanOrEqualTo(200.0));
      expect(doc.boundingBox.maxY, greaterThanOrEqualTo(680.0));
    });
  });
}
