import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_reader.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_writer.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_display_settings.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: DIMSTYLE Table Parsing and Generative Dimensions', () {
    test('Parse DIMSTYLE table from DXF string', () {
      const dxfContent = '''
0
SECTION
2
TABLES
0
TABLE
2
DIMSTYLE
70
2
0
DIMSTYLE
2
ARCH_M100
70
0
40
2.0
41
3.5
42
1.2
44
2.4
140
2.5
142
1.5
147
0.8
342
_ARCHTICK
0
DIMSTYLE
2
MECH_ISO
70
0
40
1.0
41
2.5
42
0.625
44
1.25
140
3.0
142
0.0
147
0.625
0
ENDTAB
0
ENDSEC
0
SECTION
2
ENTITIES
0
DIMENSION
2
*D10
3
ARCH_M100
70
0
10
50.0
20
120.0
30
0.0
11
50.0
21
125.0
31
0.0
13
0.0
23
0.0
33
0.0
14
100.0
24
0.0
34
0.0
50
0.0
1
<> mm
0
DIMENSION
3
MECH_ISO
70
1
10
10.0
20
60.0
30
0.0
11
30.0
21
70.0
31
0.0
13
0.0
23
50.0
33
0.0
14
60.0
24
90.0
34
0.0
50
33.69
1
Custom text
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);

      // 1. Verify DIMSTYLE table
      expect(doc.dimStyles.length, equals(2));
      expect(doc.dimStyles.containsKey('ARCH_M100'), isTrue);
      expect(doc.dimStyles.containsKey('MECH_ISO'), isTrue);

      final archStyle = doc.dimStyles['ARCH_M100']!;
      expect(archStyle.name, equals('ARCH_M100'));
      expect(archStyle.dimScale, equals(2.0));
      expect(archStyle.dimAsz, equals(3.5));
      expect(archStyle.dimExo, equals(1.2));
      expect(archStyle.dimExe, equals(2.4));
      expect(archStyle.dimTxt, equals(2.5));
      expect(archStyle.dimTsz, equals(1.5));
      expect(archStyle.dimGap, equals(0.8));
      expect(archStyle.dimBlk, equals('_ARCHTICK'));
      expect(archStyle.isArchitecturalTick, isTrue);
      expect(archStyle.effectiveArrowSize, equals(3.0)); // dimTsz (1.5) * dimScale (2.0)
      expect(archStyle.effectiveTextHeight, equals(5.0)); // dimTxt (2.5) * dimScale (2.0)
      expect(archStyle.effectiveExtensionOffset, equals(2.4)); // dimExo (1.2) * dimScale (2.0)
      expect(archStyle.effectiveExtensionExtension, equals(4.8)); // dimExe (2.4) * dimScale (2.0)

      final mechStyle = doc.dimStyles['MECH_ISO']!;
      expect(mechStyle.name, equals('MECH_ISO'));
      expect(mechStyle.dimScale, equals(1.0));
      expect(mechStyle.dimTsz, equals(0.0));
      expect(mechStyle.isArchitecturalTick, isFalse);
      expect(mechStyle.effectiveArrowSize, equals(2.5)); // dimAsz (2.5) * 1.0

      // 2. Verify DIMENSION entities
      expect(doc.entities.length, equals(2));

      final dim1 = doc.entities[0] as DxfDimension;
      expect(dim1.styleName, equals('ARCH_M100'));
      expect(dim1.blockName, equals('*D10'));
      expect(dim1.defPoint1, equals(const Offset(50.0, 120.0)));
      expect(dim1.textPoint, equals(const Offset(50.0, 125.0)));
      expect(dim1.defPoint2, equals(const Offset(0.0, 0.0)));
      expect(dim1.defPoint3, equals(const Offset(100.0, 0.0)));
      expect(dim1.rotationDeg, equals(0.0));
      expect(dim1.textOverride, equals('<> mm'));

      final dim2 = doc.entities[1] as DxfDimension;
      expect(dim2.styleName, equals('MECH_ISO'));
      expect(dim2.blockName, isNull);
      expect(dim2.dimType, equals(1)); // Aligned
      expect(dim2.defPoint1, equals(const Offset(10.0, 60.0)));
      expect(dim2.defPoint2, equals(const Offset(0.0, 50.0)));
      expect(dim2.defPoint3, equals(const Offset(60.0, 90.0)));
      expect(dim2.textOverride, equals('Custom text'));
    });

    test('Generative Dimension Rendering Fallback when block *D... is missing', () {
      const dimStyleTick = DxfDimStyle(
        name: 'ARCH_TICK',
        dimScale: 1.0,
        dimAsz: 3.0,
        dimTsz: 2.0, // Architectural tick
        dimExo: 1.0,
        dimExe: 2.0,
        dimTxt: 3.0,
      );

      const dimStyleArrow = DxfDimStyle(
        name: 'STANDARD_ARROW',
        dimScale: 1.0,
        dimAsz: 2.5,
        dimTsz: 0.0, // Arrowheads
        dimExo: 0.625,
        dimExe: 1.25,
        dimTxt: 2.5,
      );

      final entities = <DxfEntity>[
        // Horizontal linear dimension with architectural tick
        const DxfDimension(
          dimType: 0,
          defPoint1: Offset(50.0, 60.0),
          textPoint: Offset(50.0, 63.0),
          defPoint2: Offset(0.0, 0.0),
          defPoint3: Offset(100.0, 0.0),
          rotationDeg: 0.0,
          textOverride: '<>',
          styleName: 'ARCH_TICK',
        ),
        // Aligned dimension with arrows
        const DxfDimension(
          dimType: 1,
          defPoint1: Offset(20.0, 80.0),
          textPoint: Offset(40.0, 95.0),
          defPoint2: Offset(10.0, 40.0),
          defPoint3: Offset(70.0, 120.0),
          styleName: 'STANDARD_ARROW',
        ),
        // Radius dimension (dimType 4)
        const DxfDimension(
          dimType: 4,
          defPoint1: Offset(150.0, 50.0), // Point on circumference
          textPoint: Offset(170.0, 70.0), // Center or text point
          defPoint2: Offset(100.0, 50.0), // Center point
          styleName: 'STANDARD_ARROW',
        ),
      ];

      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: const {}, // No blocks! Generative fallback must trigger!
        entities: entities,
        headerVars: const {},
        entityStats: const {},
        bounds: const Rect.fromLTRB(-10, -10, 250, 250),
        dimStyles: {
          'ARCH_TICK': dimStyleTick,
          'STANDARD_ARROW': dimStyleArrow,
        },
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = DxfPainter(
        document: doc,
        settings: const DxfDisplaySettings(),
        theme: DxfCanvasTheme.darkCad,
        currentScale: 1.0,
      );

      // Render to canvas - must complete cleanly without throwing exceptions
      expect(
        () => painter.paint(canvas, const Size(800, 600)),
        returnsNormally,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('KCAD v4 Binary Round-Trip with DIMSTYLE and Dimension Extended Fields', () {
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0', colorIndex: 7)},
        blocks: const {},
        entities: [
          const DxfDimension(
            dimType: 0,
            defPoint1: Offset(25.0, 50.0),
            defPoint2: Offset(0.0, 10.0),
            defPoint3: Offset(50.0, 10.0),
            textPoint: Offset(25.0, 55.0),
            rotationDeg: 90.0,
            textOverride: '50.00 mm',
            styleName: 'CUSTOM_STYLE',
          ),
        ],
        headerVars: const {r'$ACADVER': 'AC1027'},
        entityStats: const {},
        bounds: const Rect.fromLTRB(0, 0, 100, 100),
        dimStyles: {
          'CUSTOM_STYLE': const DxfDimStyle(
            name: 'CUSTOM_STYLE',
            dimScale: 1.5,
            dimAsz: 4.0,
            dimExo: 0.8,
            dimExe: 1.6,
            dimTxt: 3.2,
            dimTsz: 2.1,
            dimGap: 0.9,
            dimBlk: 'MY_TICK',
          ),
        },
      );

      final bytes = KcadWriter.write(doc, compress: true);
      final decoded = KcadReader.read(bytes);

      // Verify DimStyles
      expect(decoded.dimStyles.containsKey('CUSTOM_STYLE'), isTrue);
      final ds = decoded.dimStyles['CUSTOM_STYLE']!;
      expect(ds.name, equals('CUSTOM_STYLE'));
      expect(ds.dimScale, closeTo(1.5, 1e-4));
      expect(ds.dimAsz, closeTo(4.0, 1e-4));
      expect(ds.dimExo, closeTo(0.8, 1e-4));
      expect(ds.dimExe, closeTo(1.6, 1e-4));
      expect(ds.dimTxt, closeTo(3.2, 1e-4));
      expect(ds.dimTsz, closeTo(2.1, 1e-4));
      expect(ds.dimGap, closeTo(0.9, 1e-4));
      expect(ds.dimBlk, equals('MY_TICK'));
      expect(ds.isArchitecturalTick, isTrue);

      // Verify Dimension Entity
      expect(decoded.entities.length, equals(1));
      final dim = decoded.entities.first as DxfDimension;
      expect(dim.styleName, equals('CUSTOM_STYLE'));
      expect(dim.rotationDeg, closeTo(90.0, 1e-4));
      expect(dim.textOverride, equals('50.00 mm'));
      expect(dim.defPoint1.dx, closeTo(25.0, 1e-3));
      expect(dim.defPoint1.dy, closeTo(50.0, 1e-3));
      expect(dim.defPoint2?.dx, closeTo(0.0, 1e-3));
      expect(dim.defPoint2?.dy, closeTo(10.0, 1e-3));
      expect(dim.defPoint3?.dx, closeTo(50.0, 1e-3));
      expect(dim.defPoint3?.dy, closeTo(10.0, 1e-3));
      expect(dim.textPoint.dx, closeTo(25.0, 1e-3));
      expect(dim.textPoint.dy, closeTo(55.0, 1e-3));
    });
  });
}
