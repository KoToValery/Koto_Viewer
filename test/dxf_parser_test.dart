import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_color_table.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_math.dart';

void main() {
  group('DXF Parser Tests', () {
    test('Parses LINE, CIRCLE, ARC, and ELLIPSE correctly', () {
      const dxfContent = '''
0
SECTION
2
ENTITIES
0
LINE
8
Walls
10
0.0
20
0.0
11
100.0
21
50.0
62
1
0
CIRCLE
8
Furniture
10
50.0
20
25.0
40
15.0
62
3
0
ARC
8
Doors
10
20.0
20
20.0
40
10.0
50
0.0
51
90.0
0
ELLIPSE
8
Curves
10
60.0
20
60.0
11
20.0
21
0.0
40
0.5
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);

      expect(doc.entities.length, 4);

      final line = doc.entities[0] as DxfLine;
      expect(line.layer, 'Walls');
      expect(line.p1, const Offset(0, 0));
      expect(line.p2, const Offset(100, 50));
      expect(line.colorIndex, 1);

      final circle = doc.entities[1] as DxfCircle;
      expect(circle.layer, 'Furniture');
      expect(circle.center, const Offset(50, 25));
      expect(circle.radius, 15.0);

      final arc = doc.entities[2] as DxfArc;
      expect(arc.layer, 'Doors');
      expect(arc.center, const Offset(20, 20));
      expect(arc.radius, 10.0);
      expect(arc.startAngleDeg, 0.0);
      expect(arc.endAngleDeg, 90.0);

      final ellipse = doc.entities[3] as DxfEllipse;
      expect(ellipse.center, const Offset(60, 60));
      expect(ellipse.minorRatio, 0.5);
    });

    test('Parses LWPOLYLINE with Bulge (curves) and SPLINE', () {
      const dxfContent = '''
0
SECTION
2
ENTITIES
0
LWPOLYLINE
8
Boundary
70
1
90
3
10
0.0
20
0.0
42
1.0
10
10.0
20
0.0
42
0.0
10
10.0
20
10.0
0
SPLINE
8
Contours
71
3
10
0.0
20
0.0
10
5.0
20
10.0
10
10.0
20
0.0
10
15.0
20
10.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.entities.length, 2);

      final poly = doc.entities[0] as DxfLwPolyline;
      expect(poly.isClosed, isTrue);
      expect(poly.vertices.length, 3);
      expect(poly.vertices[0].bulge, 1.0);
      expect(poly.vertices[1].bulge, 0.0);

      // Verify bulge arc generation
      final arcPoints = DxfMath.generateBulgeArcPoints(
        poly.vertices[0].offset,
        poly.vertices[1].offset,
        poly.vertices[0].bulge,
      );
      expect(arcPoints.length, greaterThan(2));

      final spline = doc.entities[1] as DxfSpline;
      expect(spline.degree, 3);
      expect(spline.controlPoints.length, 4);

      // Verify spline evaluation
      final splinePoints = DxfMath.evaluateSpline(spline.degree, spline.controlPoints);
      expect(splinePoints.length, greaterThan(10));
    });

    test('Parses TEXT and MTEXT with Cyrillic / Unicode and format cleaning', () {
      const dxfContent = '''
0
SECTION
2
ENTITIES
0
TEXT
8
Annotations
1
\\U+041F\\U+041B\\U+0410\\U+041D %%d45%%p0.05
10
12.0
20
34.0
40
3.5
50
45.0
0
MTEXT
8
Notes
1
{\\fArial|b0|i0;Room \\P102\\P%%c150}
10
50.0
20
60.0
40
2.5
71
1
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.entities.length, 2);

      final text = doc.entities[0] as DxfText;
      expect(text.text, 'ПЛАН °45±0.05');
      expect(text.insertPoint, const Offset(12, 34));
      expect(text.height, 3.5);
      expect(text.rotationDeg, 45.0);

      final mtext = doc.entities[1] as DxfMText;
      expect(mtext.cleanText, 'Room \n102\n⌀150');
      expect(mtext.insertPoint, const Offset(50, 60));
      expect(mtext.height, 2.5);
    });

    test('Parses BLOCKS and INSERT references', () {
      const dxfContent = '''
0
SECTION
2
BLOCKS
0
BLOCK
2
DOOR_90
10
0.0
20
0.0
0
LINE
8
DoorLayer
10
0.0
20
0.0
11
0.0
20
90.0
0
ARC
8
DoorLayer
10
0.0
20
0.0
40
90.0
50
0.0
51
90.0
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
DOOR_90
10
100.0
20
200.0
41
1.5
42
1.5
50
45.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);

      expect(doc.blocks.containsKey('DOOR_90'), isTrue);
      final block = doc.blocks['DOOR_90']!;
      expect(block.entities.length, 2);

      expect(doc.entities.length, 1);
      final insert = doc.entities[0] as DxfInsert;
      expect(insert.blockName, 'DOOR_90');
      expect(insert.insertPoint, const Offset(100, 200));
      expect(insert.scaleX, 1.5);
      expect(insert.scaleY, 1.5);
      expect(insert.rotationDeg, 45.0);
    });

    test('Parses LAYER table and resolves AutoCAD ACI Colors', () {
      const dxfContent = '''
0
SECTION
2
TABLES
0
TABLE
2
LAYER
0
LAYER
2
Electrical
62
5
0
LAYER
2
Plumbing
62
4
420
65280
0
ENDTAB
0
ENDSEC
0
SECTION
2
ENTITIES
0
LINE
8
Electrical
10
0.0
20
0.0
11
5.0
20
5.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);

      expect(doc.layers.containsKey('Electrical'), isTrue);
      expect(doc.layers['Electrical']!.colorIndex, 5); // Blue

      expect(doc.layers.containsKey('Plumbing'), isTrue);
      expect(doc.layers['Plumbing']!.trueColor, 65280); // 0x00FF00 Green

      final resolvedBlue = DxfColorTable.resolveColor(colorIndex: 5, isDarkBackground: true);
      expect(resolvedBlue, const Color(0xFF0000FF));

      final resolvedTrueColor = DxfColorTable.resolveColor(trueColor: 65280, isDarkBackground: true);
      expect(resolvedTrueColor, const Color(0xFF00FF00));
    });
  });
}
