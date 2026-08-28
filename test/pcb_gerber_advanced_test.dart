import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/pcb_viewer/parser/gerber_parser.dart';
import 'package:kotoview/src/features/pcb_viewer/models/pcb_models.dart';

void main() {
  group('Gerber Advanced RS-274X Tests (Polygon Macros & Clear Polarity)', () {
    test('Proteus Macro PPAD045 parses as exact stadium oval polygon without clamp', () {
      final file = File('scratch/SuperSense_Gerbers/SuperSense_V5_3_Gerbers/Super_Sense_V5_03_ESP32-C6-Zero_based_PCB - CADCAM Top Solder Resist.GBR');
      if (!file.existsSync()) return;

      final bytes = file.readAsBytesSync();
      final doc = GerberParser.parse(bytes, fileName: file.path);

      final flashes51 = doc.commands.where((c) => c.type == PcbCommandType.flash && c.aperture?.id == 51).toList();
      expect(flashes51.isNotEmpty, true);

      final ap = flashes51.first.aperture!;
      expect(ap.type, PcbApertureType.polygon);
      expect(ap.dimX < 2.0, true, reason: 'Pad width must be ~1.61 mm, NOT 5.08 mm!');
      expect(ap.dimY > 3.0, true, reason: 'Pad height must be ~3.12 mm!');
      expect(ap.polygonPoints != null, true);
      expect(ap.polygonPoints!.length >= 34, true);
    });

    test('Silkscreen preserves 55 clear polarity cutout operations for hollow letters', () {
      final file = File('scratch/SuperSense_Gerbers/SuperSense_V5_3_Gerbers/Super_Sense_V5_03_ESP32-C6-Zero_based_PCB - CADCAM Top Silk Screen.GBR');
      if (!file.existsSync()) return;

      final bytes = file.readAsBytesSync();
      final doc = GerberParser.parse(bytes, fileName: file.path);

      final clearCmds = doc.commands.where((c) => !c.isDark).toList();
      expect(clearCmds.length, 55);
    });
  });
}
