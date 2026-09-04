import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_color_table.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_display_settings.dart';
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

    test('Strips AutoCAD DWG->DXF service formatting codes (-ql;, t0;, \\pxql, etc.)', () {
      const dxfContent = '''
0
SECTION
2
ENTITIES
0
MTEXT
8
Layer1
1
\\pxql,t0;Кота +3.50
10
0.0
20
0.0
0
MTEXT
8
Layer1
1
{\\fArial|b0|i0|c204|p34;\\C7;\\H0.25x;\\pi-0.5,l0.5,t0;-ql;,t0;Вход А}
10
10.0
20
10.0
0
TEXT
8
Layer1
1
-ql;,t0;Стая 105
10
20.0
20
20.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.entities.length, 3);

      final mtext1 = doc.entities[0] as DxfMText;
      expect(mtext1.cleanText, 'Кота +3.50');

      final mtext2 = doc.entities[1] as DxfMText;
      expect(mtext2.cleanText, 'Вход А');

      final text3 = doc.entities[2] as DxfText;
      expect(text3.text, 'Стая 105');
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
21
5.0
0
LINE
8
Plumbing
10
10.0
20
10.0
11
15.0
21
15.0
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

    test('Parses HATCH with circular boundary edge without center chord', () {
      const dxfContent = '''
0
SECTION
2
ENTITIES
0
HATCH
8
Landscaping
2
SOLID
70
1
91
1
92
2
93
1
72
2
10
50.0
20
50.0
40
25.0
50
0.0
51
360.0
73
1
97
0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.entities.length, 1);

      final hatch = doc.entities[0] as DxfHatch;
      expect(hatch.boundaryPaths.length, 1);
      final loop = hatch.boundaryPaths[0];
      expect(loop.length, greaterThan(6));

      // Check all points are on circle circumference (r=25 from (50,50)), NOT at center
      for (final pt in loop) {
        final distToCenter = (pt - const Offset(50, 50)).distance;
        expect((distToCenter - 25.0).abs(), lessThan(0.01));
      }
    });

    test('DxfDisplaySettings serialization and defaults', () {
      const defaultSettings = DxfDisplaySettings();
      expect(defaultSettings.lineThicknessScale, 1.0);
      expect(defaultSettings.measurementScale, 1.4);
      expect(defaultSettings.pointSize, 2.0);
      expect(defaultSettings.pointStyle, DxfPointStyle.none);

      final modified = defaultSettings.copyWith(
        lineThicknessScale: 1.8,
        measurementScale: 0.8,
        pointSize: 6.0,
        pointStyle: DxfPointStyle.circleDot,
      );

      final jsonStr = modified.toJson();
      final restored = DxfDisplaySettings.fromJson(jsonStr);

      expect(restored.lineThicknessScale, 1.8);
      expect(restored.measurementScale, 0.8);
      expect(restored.pointSize, 6.0);
      expect(restored.pointStyle, DxfPointStyle.circleDot);
    });

    test('Parses 3DFACE entity correctly', () {
      const dxfContent = '''
0
SECTION
2
ENTITIES
0
3DFACE
8
Terrain
10
0.0
20
0.0
30
10.0
11
10.0
21
0.0
31
12.0
12
10.0
22
10.0
32
15.0
13
0.0
23
10.0
33
11.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.entities.length, 1);
      expect(doc.entities[0], isA<DxfSolid>());
      final face = doc.entities[0] as DxfSolid;
      expect(face.layer, 'Terrain');
      expect(face.p0, const Offset(0, 0));
      expect(face.p1, const Offset(10, 0));
      expect(face.p2, const Offset(10, 10));
      expect(face.p3, const Offset(0, 10));
    });

    test('Decodes diverse Cyrillic formats: Unicode, MIF, ASCII codes, and Mojibake', () {
      const dxfContent = '''
0
SECTION
2
ENTITIES
0
TEXT
8
Layer1
1
\\M+5C0\\M+5F0\\M+5F5\\M+5E8
10
0.0
20
0.0
0
TEXT
8
Layer2
1
%%192%%240%%245%%232
10
10.0
20
10.0
0
TEXT
8
Layer3
1
Àðõèòåêòóðà
10
20.0
20
20.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.entities.length, 3);

      final t1 = doc.entities[0] as DxfText;
      expect(t1.text, 'Архи');

      final t2 = doc.entities[1] as DxfText;
      expect(t2.text, 'Архи');

      final t3 = doc.entities[2] as DxfText;
      expect(t3.text, 'Архитектура');
    });

    test('Parses STYLE table with text style definitions', () {
      const dxfContent = '''
0
SECTION
2
TABLES
0
TABLE
2
STYLE
0
STYLE
2
STANDARD
70
0
40
0.0
3
Arial.ttf
0
STYLE
2
ARCHICAD
70
0
40
2.0
3
Times.ttf
0
STYLE
2
VERTICAL_STYLE
70
4
40
1.0
3
Gothic.shx
0
ENDTAB
0
ENDSEC
0
SECTION
2
ENTITIES
0
TEXT
8
Layer1
1
Test Text
7
ARCHICAD
10
0.0
20
0.0
40
5.0
0
MTEXT
8
Layer2
1
Multi-line Text
7
STANDARD
10
10.0
20
10.0
40
3.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);

      // Verify text styles were parsed
      expect(doc.textStyles.length, 3);
      expect(doc.textStyles.containsKey('STANDARD'), isTrue);
      expect(doc.textStyles.containsKey('ARCHICAD'), isTrue);
      expect(doc.textStyles.containsKey('VERTICAL_STYLE'), isTrue);

      // Verify STANDARD style
      final standardStyle = doc.textStyles['STANDARD']!;
      expect(standardStyle.name, 'STANDARD');
      expect(standardStyle.heightScale, 1.0); // 0.0 should be converted to 1.0
      expect(standardStyle.fontFile, 'Arial.ttf');
      expect(standardStyle.isVertical, false);

      // Verify ARCHICAD style with 2.0 scale factor
      final archicadStyle = doc.textStyles['ARCHICAD']!;
      expect(archicadStyle.name, 'ARCHICAD');
      expect(archicadStyle.heightScale, 2.0);
      expect(archicadStyle.fontFile, 'Times.ttf');
      expect(archicadStyle.isVertical, false);

      // Verify VERTICAL_STYLE
      final verticalStyle = doc.textStyles['VERTICAL_STYLE']!;
      expect(verticalStyle.name, 'VERTICAL_STYLE');
      expect(verticalStyle.heightScale, 1.0);
      expect(verticalStyle.fontFile, 'Gothic.shx');
      expect(verticalStyle.isVertical, true);

      // Verify TEXT entity has style reference
      final text = doc.entities[0] as DxfText;
      expect(text.style, 'ARCHICAD');
      expect(text.height, 5.0);

      // Verify MTEXT entity has style reference
      final mtext = doc.entities[1] as DxfMText;
      expect(mtext.style, 'STANDARD');
      expect(mtext.height, 3.0);
    });

    test('Does not load layers without objects in them (empty layers)', () {
      const dxfContent = '''0
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
ActiveLayer
62
1
0
LAYER
2
EmptyLayer1
62
2
0
LAYER
2
EmptyLayer2
62
3
0
LAYER
2
BlockOnlyLayer
62
4
0
ENDTAB
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
0
LINE
8
BlockOnlyLayer
10
0.0
20
0.0
11
10.0
21
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
LINE
8
ActiveLayer
10
0.0
20
0.0
11
20.0
21
20.0
0
INSERT
2
TEST_BLOCK
8
ActiveLayer
10
50.0
20
50.0
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);

      // Only layers with objects should be loaded
      expect(doc.layers.containsKey('ActiveLayer'), isTrue);
      expect(doc.layers.containsKey('BlockOnlyLayer'), isTrue);

      // Empty layers must NOT be loaded
      expect(doc.layers.containsKey('EmptyLayer1'), isFalse);
      expect(doc.layers.containsKey('EmptyLayer2'), isFalse);

      expect(doc.layers.length, 2);
    });

    test('Accurately parses layer visibility according to AutoCAD standards (visible, hidden, frozen)', () {
      const dxfContent = '''0
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
VisibleLayer
62
3
70
0
0
LAYER
2
HiddenLayer
62
-5
70
0
0
LAYER
2
FrozenLayer
62
2
70
1
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
VisibleLayer
10
0.0
20
0.0
11
1.0
21
1.0
0
LINE
8
HiddenLayer
10
2.0
20
2.0
11
3.0
21
3.0
0
LINE
8
FrozenLayer
10
4.0
20
4.0
11
5.0
21
5.0
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);

      expect(doc.layers['VisibleLayer']?.isVisible, isTrue);
      expect(doc.layers['VisibleLayer']?.isFrozen, isFalse);

      expect(doc.layers['HiddenLayer']?.isVisible, isFalse);
      expect(doc.layers['HiddenLayer']?.isFrozen, isFalse);

      expect(doc.layers['FrozenLayer']?.isVisible, isFalse);
      expect(doc.layers['FrozenLayer']?.isFrozen, isTrue);
    });

    test('Applies authentic DWG layer state metadata (KOTO_DWG_LAYERS)', () {
      const dxfContent = '''999
KOTO_DWG_LAYERS:Active1=+;Hidden1=-;Frozen1=f+;FrozenHidden1=f-
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
Active1
62
-7
0
LAYER
2
Hidden1
62
-7
0
LAYER
2
Frozen1
62
-7
0
LAYER
2
FrozenHidden1
62
-7
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
Active1
10
0.0
20
0.0
11
1.0
21
1.0
0
LINE
8
Hidden1
10
0.0
20
0.0
11
1.0
21
1.0
0
LINE
8
Frozen1
10
0.0
20
0.0
11
1.0
21
1.0
0
LINE
8
FrozenHidden1
10
0.0
20
0.0
11
1.0
21
1.0
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);

      expect(doc.layers['Active1']?.isVisible, isTrue);
      expect(doc.layers['Active1']?.isFrozen, isFalse);

      expect(doc.layers['Hidden1']?.isVisible, isFalse);
      expect(doc.layers['Hidden1']?.isFrozen, isFalse);

      expect(doc.layers['Frozen1']?.isVisible, isFalse);
      expect(doc.layers['Frozen1']?.isFrozen, isTrue);

      expect(doc.layers['FrozenHidden1']?.isVisible, isFalse);
      expect(doc.layers['FrozenHidden1']?.isFrozen, isTrue);
    });

    test('Preserves default layer 0 when drawing is completely empty', () {
      const dxfContent = '''0
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
0
62
7
0
LAYER
2
EmptyLayer
62
1
0
ENDTAB
0
ENDSEC
0
SECTION
2
ENTITIES
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.layers.length, 1);
      expect(doc.layers.containsKey('0'), isTrue);
      expect(doc.layers.containsKey('EmptyLayer'), isFalse);
    });

    test('Real converted AutoCAD file (OVK_converted.dxf) excludes empty layers and keeps active layers visible', () {
      final file = File('test_files/OVK_converted.dxf');
      if (file.existsSync()) {
        final content = UniversalEncodingService.decodeBytes(file.readAsBytesSync());
        final doc = DxfParser.parseString(content);
        // Empty layers must not be loaded: original has 332 layers, only ~150 have entities
        expect(doc.layers.length, lessThan(200));
        expect(doc.layers.length, greaterThan(50));

        final visible = doc.layers.values.where((l) => l.isVisible).toList();
        print('OVK visible layers (${visible.length}): ${visible.map((l) => l.name).toList()}');

        // Active layers must be visible, NOT hidden by default
        final visibleCount = visible.length;
        expect(visibleCount, greaterThan(50));

        // Specific empty layer from templates must not be loaded
        expect(doc.layers.containsKey('zasnemane_Pen_No__7'), isFalse);
        expect(doc.layers.containsKey('Fills_Pen_No__252'), isFalse);

        // Specific active layer with entities must be loaded and visible
        expect(doc.layers.containsKey('стени_Pen_No__1'), isTrue);
        expect(doc.layers['стени_Pen_No__1']!.isVisible, isTrue);
      }
    });

    test('Real converted file (Archicad_export_converted.dxf) has visible layers and excludes empty layers', () {
      final file = File('test_files/Archicad_export_converted.dxf');
      if (file.existsSync()) {
        final content = UniversalEncodingService.decodeBytes(file.readAsBytesSync());
        final doc = DxfParser.parseString(content);
        expect(doc.layers.isNotEmpty, isTrue);
        final visibleCount = doc.layers.values.where((l) => l.isVisible).length;
        expect(visibleCount, doc.layers.length);
      }
    });
  });
}

