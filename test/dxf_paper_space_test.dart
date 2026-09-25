import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_writer.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_reader.dart';

void main() {
  group('Phase 5: Paper Space & VIEWPORT Layout System', () {
    test('1. Separates Model Space and Paper Space entities by group codes 67 and 410', () {
      const dxfContent = '''0
SECTION
2
HEADER
0
ENDSEC
0
SECTION
2
ENTITIES
0
LINE
8
WALLS
10
100.0
20
100.0
11
200.0
21
200.0
67
0
0
LINE
8
TITLE_BLOCK
10
0.0
20
0.0
11
420.0
21
297.0
67
1
410
A3_Sheet
0
TEXT
8
STAMP
1
PROJECT ALPHA
10
350.0
20
20.0
40
5.0
67
1
410
A3_Sheet
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);

      expect(doc.entities.length, equals(3));

      // Layouts list
      expect(doc.layouts, contains('Model'));
      expect(doc.layouts, contains('A3_Sheet'));
      expect(doc.layouts.length, equals(2));

      // Entity partitioning
      final modelEntities = doc.layoutEntities['Model']!;
      final paperEntities = doc.layoutEntities['A3_Sheet']!;

      expect(modelEntities.length, equals(1));
      expect(modelEntities.first, isA<DxfLine>());
      expect(modelEntities.first.isPaperSpace, isFalse);
      expect(modelEntities.first.layoutName, equals('Model'));

      expect(paperEntities.length, equals(2));
      expect(paperEntities[0].isPaperSpace, isTrue);
      expect(paperEntities[0].layoutName, equals('A3_Sheet'));
      expect(paperEntities[1].isPaperSpace, isTrue);
      expect(paperEntities[1].layoutName, equals('A3_Sheet'));

      // Model bounds must ONLY contain the Model Space line (100,100) -> (200,100)
      // Paper sheet (0,0)->(420,297) must not enlarge model bounds!
      expect(doc.bounds.left, closeTo(100.0, 1e-4));
      expect(doc.bounds.right, closeTo(200.0, 1e-4));
      expect(doc.bounds.top, closeTo(100.0, 1e-4));
      expect(doc.bounds.bottom, closeTo(200.0, 1e-4));

      // Paper layout bounds must correctly reflect the A3 sheet size
      final sheetBounds = doc.layoutBounds['A3_Sheet']!;
      expect(sheetBounds.left, closeTo(0.0, 1e-4));
      expect(sheetBounds.right, closeTo(420.0, 1e-4));
      expect(sheetBounds.top, closeTo(0.0, 1e-4));
      expect(sheetBounds.bottom, closeTo(297.0, 1e-4));
    });

    test('2. Parses VIEWPORT entities with center, size, viewCenter, viewHeight, status, and ID', () {
      const dxfViewportContent = '''0
SECTION
2
ENTITIES
0
VIEWPORT
8
Defpoints
10
210.0
20
148.5
40
280.0
41
190.0
12
150.0
22
100.0
45
50.0
68
1
69
2
51
0.0
67
1
410
Layout1
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfViewportContent);
      expect(doc.entities.length, equals(1));

      final vp = doc.entities.first as DxfViewport;
      expect(vp.isPaperSpace, isTrue);
      expect(vp.layoutName, equals('Layout1'));
      expect(vp.center, equals(const Offset(210.0, 148.5)));
      expect(vp.width, equals(280.0));
      expect(vp.height, equals(190.0));
      expect(vp.viewCenter, equals(const Offset(150.0, 100.0)));
      expect(vp.viewHeight, equals(50.0));
      expect(vp.status, equals(1));
      expect(vp.viewportId, equals(2));
      expect(vp.isActive, isTrue);

      // Model to paper scale factor: height / viewHeight = 190.0 / 50.0 = 3.8
      expect(vp.modelToPaperScale, closeTo(3.8, 1e-5));

      // Paper rectangle bounds
      final paperRect = vp.paperRect;
      expect(paperRect.width, closeTo(280.0, 1e-4));
      expect(paperRect.height, closeTo(190.0, 1e-4));
      expect(paperRect.center, equals(const Offset(210.0, 148.5)));

      // Model space area visible through viewport
      // modelWidth = viewHeight * (width / height) = 50.0 * (280.0 / 190.0) = 73.6842
      final modelBounds = vp.modelBounds;
      expect(modelBounds.center, equals(const Offset(150.0, 100.0)));
      expect(modelBounds.height, closeTo(50.0, 1e-4));
      expect(modelBounds.width, closeTo(50.0 * (280.0 / 190.0), 1e-4));
    });

    test('3. Viewport coordinate mapping transforms Model coordinates into Paper Space', () {
      const vp = DxfViewport(
        center: Offset(200.0, 150.0),
        width: 100.0,
        height: 100.0,
        viewCenter: Offset(1000.0, 500.0),
        viewHeight: 50.0,
        status: 1,
        viewportId: 2,
      );

      // Scale is 100.0 / 50.0 = 2.0
      expect(vp.modelToPaperScale, equals(2.0));

      Offset modelToPaper(Offset modelPt) {
        final scale = vp.modelToPaperScale;
        final px = vp.center.dx + (modelPt.dx - vp.viewCenter.dx) * scale;
        final py = vp.center.dy + (modelPt.dy - vp.viewCenter.dy) * scale;
        return Offset(px, py);
      }

      // Point at view center should map exactly to viewport center on paper
      expect(modelToPaper(const Offset(1000.0, 500.0)), equals(const Offset(200.0, 150.0)));

      // Point offset by (+10, +5) in model space should map to (+20, +10) in paper space
      expect(modelToPaper(const Offset(1010.0, 505.0)), equals(const Offset(220.0, 160.0)));
    });

    test('4. KCAD Binary Format: Round-trip serialization preserves Paper Space & Viewports', () {
      final doc = DxfDocument(
        layers: {
          '0': DxfLayer(name: '0', colorIndex: 7),
          'Model_Layer': DxfLayer(name: 'Model_Layer', colorIndex: 1),
          'Paper_Layer': DxfLayer(name: 'Paper_Layer', colorIndex: 3),
        },
        blocks: {},
        entities: [
          const DxfLine(
            p1: Offset(10, 10),
            p2: Offset(50, 50),
            layer: 'Model_Layer',
            isPaperSpace: false,
            layoutName: 'Model',
          ),
          const DxfViewport(
            center: Offset(210, 148.5),
            width: 200,
            height: 150,
            viewCenter: Offset(30, 30),
            viewHeight: 60,
            status: 1,
            viewportId: 2,
            twistAngleDeg: 15.0,
            layer: 'Paper_Layer',
            isPaperSpace: true,
            layoutName: 'Plan_Layout',
          ),
          const DxfText(
            text: 'SHEET 1 OF 3',
            insertPoint: Offset(350, 20),
            height: 4.0,
            layer: 'Paper_Layer',
            isPaperSpace: true,
            layoutName: 'Plan_Layout',
          ),
        ],
        headerVars: {},
        textStyles: {},
        bounds: const Rect.fromLTWH(10, 10, 40, 40),
        entityStats: {},
      );

      final bytes = KcadWriter.write(doc);
      final restored = KcadReader.read(bytes);

      expect(restored.entities.length, equals(3));
      expect(restored.layouts, contains('Model'));
      expect(restored.layouts, contains('Plan_Layout'));

      // Check Model space entity
      final restoredLine = restored.entities[0] as DxfLine;
      expect(restoredLine.isPaperSpace, isFalse);
      expect(restoredLine.layoutName, equals('Model'));
      expect(restoredLine.p1, equals(const Offset(10, 10)));
      expect(restoredLine.p2, equals(const Offset(50, 50)));

      // Check Viewport entity
      final restoredVp = restored.entities[1] as DxfViewport;
      expect(restoredVp.isPaperSpace, isTrue);
      expect(restoredVp.layoutName, equals('Plan_Layout'));
      expect(restoredVp.center, equals(const Offset(210, 148.5)));
      expect(restoredVp.width, equals(200.0));
      expect(restoredVp.height, equals(150.0));
      expect(restoredVp.viewCenter, equals(const Offset(30, 30)));
      expect(restoredVp.viewHeight, equals(60.0));
      expect(restoredVp.status, equals(1));
      expect(restoredVp.viewportId, equals(2));
      expect(restoredVp.twistAngleDeg, equals(15.0));

      // Check Paper Space Text entity
      final restoredText = restored.entities[2] as DxfText;
      expect(restoredText.isPaperSpace, isTrue);
      expect(restoredText.layoutName, equals('Plan_Layout'));
      expect(restoredText.text, equals('SHEET 1 OF 3'));
      expect(restoredText.insertPoint, equals(const Offset(350, 20)));

      // Check Layout Entities partitioning
      expect(restored.layoutEntities['Model']!.length, equals(1));
      expect(restored.layoutEntities['Plan_Layout']!.length, equals(2));
    });
  });
}
