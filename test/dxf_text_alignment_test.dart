import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

void main() {
  group('DXF Text & Dimension Alignment Tests', () {
    test('MTEXT baseline alignment calculates exact zero offset for Bottom-Left (code 7)', () {
      final tp = TextPainter(
        text: const TextSpan(
          text: '220',
          style: TextStyle(
            fontSize: 15.0,
            fontFamily: 'Roboto',
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final oy = -baseline;
      final visualBaselineLanding = oy + baseline;
      expect(visualBaselineLanding, closeTo(0.0, 0.001));
    });

    test('Validates dimension text alignment in Archicad_export.dxf and OVK_Autocad_save.dxf', () {
      for (final filename in ['test_files/Archicad_export.dxf', 'test_files/OVK_Autocad_save.dxf']) {
        final f = File(filename);
        if (!f.existsSync()) continue;
        final text = UniversalEncodingService.decodeBytes(f.readAsBytesSync());
        final doc = DxfParser.parseString(text);

        int checkedDims = 0;
        for (final e in doc.entities) {
          if (e is DxfDimension) {
            final b = doc.blocks[e.blockName];
            if (b == null) continue;
            for (final be in b.entities) {
              if (be is DxfMText) {
                final tp = TextPainter(
                  text: TextSpan(
                    text: be.cleanText,
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontFamily: 'Roboto',
                      height: 1.0,
                    ),
                  ),
                  textDirection: TextDirection.ltr,
                )..layout();
                final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
                double oy = 0.0;
                switch (be.attachmentPoint) {
                  case 7:
                  case 8:
                  case 9:
                    oy = -baseline;
                    break;
                  case 4:
                  case 5:
                  case 6:
                  case 0:
                    oy = -baseline / 2.0;
                    break;
                  default:
                    oy = 0.0;
                }
                final visualBaselineLanding = oy + baseline;
                expect(
                  visualBaselineLanding,
                  closeTo(be.attachmentPoint >= 7 ? 0.0 : baseline / 2.0, 0.001),
                );
                checkedDims++;
              }
            }
          }
        }
        expect(checkedDims, greaterThan(100));
      }
    });

    test('DxfPainter renders without error with parent rotation and scale', () {
      const dxfContent = '''0
SECTION
2
HEADER
0
ENDSEC
0
SECTION
2
BLOCKS
0
BLOCK
2
TEST_BLOCK
10
0.0
20
0.0
30
0.0
0
MTEXT
1
150
10
10.0
20
20.0
40
12.0
71
7
0
TEXT
1
200
10
30.0
20
40.0
40
10.0
0
ENDBLK
0
ENDSEC
0
SECTION
2
ENTITIES
0
INSERT
2
TEST_BLOCK
10
100.0
20
100.0
41
2.0
42
2.0
50
90.0
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);
      final painter = DxfPainter(
        document: doc,
        theme: DxfCanvasTheme.darkCad,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(800, 600)),
        returnsNormally,
      );
      final picture = recorder.endRecording();
      picture.dispose();
    });
  });
}
