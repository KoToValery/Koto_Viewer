import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_linetype_helper.dart';

void main() {
  group('DxfLinetypeHelper Tests', () {
    test('Resolves Dotted / Punktir linetype from name', () {
      expect(DxfLinetypeHelper.resolvePattern('DOTTED'), DxfLinetypeHelper.dottedPattern);
      expect(DxfLinetypeHelper.resolvePattern('DOT'), DxfLinetypeHelper.dottedPattern);
      expect(DxfLinetypeHelper.resolvePattern('_DOTTED_'), DxfLinetypeHelper.dottedPattern);
      expect(DxfLinetypeHelper.resolvePattern('punktir'), DxfLinetypeHelper.dottedPattern);
      expect(DxfLinetypeHelper.resolvePattern('ACAD_ISO01W100'), DxfLinetypeHelper.dottedPattern);
    });

    test('Resolves Dashed linetype from name', () {
      expect(DxfLinetypeHelper.resolvePattern('DASHED'), DxfLinetypeHelper.dashedPattern);
      expect(DxfLinetypeHelper.resolvePattern('DASH'), DxfLinetypeHelper.dashedPattern);
      expect(DxfLinetypeHelper.resolvePattern('_DASHED_'), DxfLinetypeHelper.dashedPattern);
      expect(DxfLinetypeHelper.resolvePattern('ACAD_ISO02W100'), DxfLinetypeHelper.dashedPattern);
    });

    test('Resolves Dash-Dot (Chain / Точка и къса линия) linetype', () {
      expect(DxfLinetypeHelper.resolvePattern('DASHDOT'), DxfLinetypeHelper.dashDotPattern);
      expect(DxfLinetypeHelper.resolvePattern('DASH_DOT'), DxfLinetypeHelper.dashDotPattern);
      expect(DxfLinetypeHelper.resolvePattern('CHAIN'), DxfLinetypeHelper.dashDotPattern);
      expect(DxfLinetypeHelper.resolvePattern('ACAD_ISO04W100'), DxfLinetypeHelper.dashDotPattern);
    });

    test('Resolves Dash-Dot-Dot (Divide / Двойна точка) linetype', () {
      expect(DxfLinetypeHelper.resolvePattern('DIVIDE'), DxfLinetypeHelper.dashDotDotPattern);
      expect(DxfLinetypeHelper.resolvePattern('DASHDOTDOT'), DxfLinetypeHelper.dashDotDotPattern);
      expect(DxfLinetypeHelper.resolvePattern('DASH_2_DOT'), DxfLinetypeHelper.dashDotDotPattern);
      expect(DxfLinetypeHelper.resolvePattern('ACAD_ISO05W100'), DxfLinetypeHelper.dashDotDotPattern);
    });

    test('Resolves Centerline (Осова линия) and Phantom linetypes', () {
      expect(DxfLinetypeHelper.resolvePattern('CENTER'), DxfLinetypeHelper.centerPattern);
      expect(DxfLinetypeHelper.resolvePattern('CENTERLINE'), DxfLinetypeHelper.centerPattern);
      expect(DxfLinetypeHelper.resolvePattern('OSOVA'), DxfLinetypeHelper.centerPattern);
      expect(DxfLinetypeHelper.resolvePattern('PHANTOM'), DxfLinetypeHelper.phantomPattern);
      expect(DxfLinetypeHelper.resolvePattern('HIDDEN'), DxfLinetypeHelper.hiddenPattern);
      expect(DxfLinetypeHelper.resolvePattern('BORDER'), DxfLinetypeHelper.borderPattern);
    });

    test('Returns null for Continuous / Solid / BYLAYER with no layer override', () {
      expect(DxfLinetypeHelper.resolvePattern('CONTINUOUS'), isNull);
      expect(DxfLinetypeHelper.resolvePattern('SOLID'), isNull);
      expect(DxfLinetypeHelper.resolvePattern('BYLAYER'), isNull);
      expect(DxfLinetypeHelper.resolvePattern(null), isNull);
    });

    test('Resolves BYLAYER linetype from layer linetype', () {
      expect(
        DxfLinetypeHelper.resolvePattern('BYLAYER', layerLineType: 'DASHED'),
        DxfLinetypeHelper.dashedPattern,
      );
      expect(
        DxfLinetypeHelper.resolvePattern(null, layerLineType: 'DOT'),
        DxfLinetypeHelper.dottedPattern,
      );
      expect(
        DxfLinetypeHelper.resolvePattern('BYLAYER', layerLineType: 'CENTER'),
        DxfLinetypeHelper.centerPattern,
      );
    });

    test('Generates dashed path segments accurately', () {
      final linePath = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0);

      final dashed = DxfLinetypeHelper.createDashedPath(
        linePath,
        DxfLinetypeHelper.dashedPattern,
        scale: 1.0,
      );

      final bounds = dashed.getBounds();
      expect(bounds.left, closeTo(0, 0.1));
      expect(bounds.right, greaterThan(80));
    });
  });

  group('ArchiCAD Hatch & Shadow Transparency Tests', () {
    test('Parses layer lineType from LAYER table', () {
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
A-WALL-HIDDEN
70
0
62
3
6
HIDDEN
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
A-WALL-HIDDEN
10
0.0
20
0.0
11
100.0
21
0.0
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.layers.containsKey('A-WALL-HIDDEN'), isTrue);
      expect(doc.layers['A-WALL-HIDDEN']?.lineType, 'HIDDEN');
      expect(doc.entities.first.layer, 'A-WALL-HIDDEN');
    });

    test('Parses ArchiCAD shadow fill with ~10% transparency', () {
      const dxfContent = '''0
SECTION
2
ENTITIES
0
HATCH
8
A-SHADOWS
2
10%
70
1
92
7
72
0
73
1
93
4
10
0.0
20
0.0
10
100.0
20
0.0
10
100.0
20
100.0
10
0.0
20
100.0
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.entities.length, 1);
      final hatch = doc.entities.first as DxfHatch;
      expect(hatch.patternName, '10%');
      expect(hatch.isSolid, isTrue);
      expect(hatch.transparency, 0.10);
      expect(hatch.boundaryPaths.length, 1);
      expect(hatch.boundaryPaths.first.length, 5);
    });

    test('Resolves ArchiCAD "Dot & Dashed" as dash-dot pattern', () {
      expect(DxfLinetypeHelper.resolvePattern('Dot & Dashed'), DxfLinetypeHelper.dashDotPattern);
      expect(DxfLinetypeHelper.resolvePattern('Dot&Dashed'), DxfLinetypeHelper.dashDotPattern);
      expect(DxfLinetypeHelper.resolvePattern('DOT_DASH'), DxfLinetypeHelper.dashDotPattern);
    });

    test('Resolves custom LTYPE from DXF table definitions', () {
      final customTypes = <String, List<double>>{
        'LTYPE004': [25.0, 10.0, 2.0, 10.0],
        '40': [15.0, 8.0],
      };
      expect(
        DxfLinetypeHelper.resolvePattern('LTYPE004', customLineTypes: customTypes),
        [25.0, 10.0, 2.0, 10.0],
      );
      expect(
        DxfLinetypeHelper.resolvePattern('40', customLineTypes: customTypes),
        [15.0, 8.0],
      );
    });

    test('Parses LTYPE table and Cyrillic СЕНКИ shadow hatch from DXF', () {
      const dxfContent = '''0
SECTION
2
TABLES
0
TABLE
2
LTYPE
0
LTYPE
2
Dot & Dashed
70
0
3
- - - - -
72
65
73
4
40
67.0
49
35.28
49
-17.64
49
0.0
49
-14.11
0
ENDTAB
0
ENDSEC
0
SECTION
2
ENTITIES
0
HATCH
8
fill
2
\\U+0421\\U+0415\\U+041D\\U+041A\\U+0418
70
0
92
3
72
0
73
1
93
4
10
0.0
20
0.0
10
100.0
20
0.0
10
100.0
20
100.0
10
0.0
20
100.0
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.lineTypes.containsKey('Dot & Dashed'), isTrue);
      expect(doc.lineTypes['Dot & Dashed']?.length, 4);

      expect(doc.entities.length, 1);
      final hatch = doc.entities.first as DxfHatch;
      expect(hatch.patternName, 'СЕНКИ');
      expect(hatch.isSolid, isTrue);
      expect(hatch.transparency, 0.10);
      expect(hatch.boundaryPaths.length, 1);
      expect(hatch.boundaryPaths.first.length, 4);
    });

    test('Parses ArchiCAD shadow layer name with 10% transparency', () {
      const dxfContent = '''0
SECTION
2
ENTITIES
0
HATCH
8
ARCHI_SHADOW_LAYER
2
SOLID
70
1
92
7
72
0
73
1
93
3
10
0.0
20
0.0
10
50.0
20
0.0
10
50.0
20
50.0
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);
      final hatch = doc.entities.first as DxfHatch;
      expect(hatch.transparency, 0.10);
    });

    test('Parses 25%, 50%, and 75% percentage fills', () {
      const dxfContent = '''0
SECTION
2
ENTITIES
0
HATCH
8
0
2
25%
70
1
0
HATCH
8
0
2
50%
70
1
0
HATCH
8
0
2
75%
70
1
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.entities.length, 3);
      expect((doc.entities[0] as DxfHatch).transparency, 0.25);
      expect((doc.entities[1] as DxfHatch).transparency, 0.50);
      expect((doc.entities[2] as DxfHatch).transparency, 0.75);
    });

    test('Parses explicit DXF 32-bit transparency group code 440', () {
      const dxfContent = '''0
SECTION
2
ENTITIES
0
HATCH
8
0
2
SOLID
70
1
440
33554458
0
ENDSEC
0
EOF''';

      final doc = DxfParser.parseString(dxfContent);
      final hatch = doc.entities.first as DxfHatch;
      // 33554458 in hex is 0x0200001A (alpha = 26 -> 26/255 ~ 0.10)
      expect(hatch.transparency, closeTo(26 / 255.0, 0.01));
    });
  });
}
