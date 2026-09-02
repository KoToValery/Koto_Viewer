import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

void main() {
  group('Archicad Origin Detection Heuristic', () {
    test('Should detect Archicad from explicit ACADVER marker', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          '\$ACADVER': 'ARCHICAD_24',
        },
        textStyles: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should detect Archicad from DWGCODEPAGE marker', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          '\$DWGCODEPAGE': 'ANSI_1250_ARCHICAD',
        },
        textStyles: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should detect Archicad from text styles with 2.0 scale factors', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'STANDARD': const DxfTextStyle(name: 'STANDARD', heightScale: 2.0),
          'TEXT1': const DxfTextStyle(name: 'TEXT1', heightScale: 2.0),
          'TEXT2': const DxfTextStyle(name: 'TEXT2', heightScale: 1.5),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      // 2 out of 3 styles have 2.0 scale (66% > 50% threshold)
      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should NOT detect Archicad when only one style with 2.0 scale', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'STANDARD': const DxfTextStyle(name: 'STANDARD', heightScale: 2.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      // Only 1 style - need at least 2 styles for this heuristic
      expect(doc.isArchicadOrigin, isFalse);
    });

    test('Should detect Archicad from text style naming pattern AC_', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'AC_TEXT': const DxfTextStyle(name: 'AC_TEXT', heightScale: 1.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should detect Archicad from text style naming pattern AC-', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'AC-STANDARD': const DxfTextStyle(name: 'AC-STANDARD', heightScale: 1.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should detect Archicad from style name containing ARCHICAD', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'ARCHICAD_TEXT': const DxfTextStyle(name: 'ARCHICAD_TEXT', heightScale: 1.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should detect Archicad from DIMSCALE=2.0 + text style with 2.0 scale', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          '\$DIMSCALE': '2.0',
        },
        textStyles: {
          'STANDARD': const DxfTextStyle(name: 'STANDARD', heightScale: 2.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should detect Archicad from LTSCALE=2.0 + text style with 2.0 scale', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          '\$LTSCALE': '2.0',
        },
        textStyles: {
          'STANDARD': const DxfTextStyle(name: 'STANDARD', heightScale: 2.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should NOT detect Archicad from pure AutoCAD file (no markers)', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          '\$ACADVER': 'AC1027',
          '\$DIMSCALE': '1.0',
          '\$LTSCALE': '1.0',
        },
        textStyles: {
          'STANDARD': const DxfTextStyle(name: 'STANDARD', heightScale: 1.0),
          'ARIAL': const DxfTextStyle(name: 'ARIAL', heightScale: 1.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isFalse);
    });

    test('Should NOT detect Archicad when scale factors are normal (1.0)', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'STANDARD': const DxfTextStyle(name: 'STANDARD', heightScale: 1.0),
          'TEXT1': const DxfTextStyle(name: 'TEXT1', heightScale: 1.0),
          'TEXT2': const DxfTextStyle(name: 'TEXT2', heightScale: 1.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isFalse);
    });

    test('Should NOT detect Archicad from DIMSCALE=2.0 alone (no text styles)', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          '\$DIMSCALE': '2.0',
        },
        textStyles: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      // Conservative: DIMSCALE=2.0 alone is not enough without supporting evidence
      expect(doc.isArchicadOrigin, isFalse);
    });

    test('Should handle floating point variance in scale detection (1.99)', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'STANDARD': const DxfTextStyle(name: 'STANDARD', heightScale: 1.99),
          'TEXT1': const DxfTextStyle(name: 'TEXT1', heightScale: 2.01),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      // Both styles have scales close to 2.0 (within 1.95-2.05 range)
      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should NOT detect Archicad when less than 50% of styles have 2.0 scale', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'STANDARD': const DxfTextStyle(name: 'STANDARD', heightScale: 2.0),
          'TEXT1': const DxfTextStyle(name: 'TEXT1', heightScale: 1.0),
          'TEXT2': const DxfTextStyle(name: 'TEXT2', heightScale: 1.0),
          'TEXT3': const DxfTextStyle(name: 'TEXT3', heightScale: 1.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      // Only 1 out of 4 styles (25% < 50% threshold)
      expect(doc.isArchicadOrigin, isFalse);
    });

    test('Preservation case: BricsCAD file should NOT be detected as Archicad', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          '\$ACADVER': 'AC1021',
        },
        textStyles: {
          'STANDARD': const DxfTextStyle(name: 'STANDARD', heightScale: 1.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isFalse);
    });

    test('Should detect Archicad from layer names with Pen_No', () {
      final doc = DxfDocument(
        layers: {
          'стени_Pen_No__1': DxfLayer(name: 'стени_Pen_No__1', colorIndex: 1),
          'Квадратура_Pen_No__5': DxfLayer(name: 'Квадратура_Pen_No__5', colorIndex: 5),
        },
        blocks: {},
        entities: [],
        headerVars: {
          '\$ACADVER': 'AC1032',
        },
        textStyles: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should detect Archicad from layer names with AC_ or GS_', () {
      final doc = DxfDocument(
        layers: {
          'AC_WALLS': DxfLayer(name: 'AC_WALLS', colorIndex: 1),
        },
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Should detect Archicad from block names with Archicad or Graphisoft', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {
          'GSPROP_OBJECT_1': DxfBlock(name: 'GSPROP_OBJECT_1', basePoint: Offset.zero, entities: []),
        },
        entities: [],
        headerVars: {},
        textStyles: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);
    });

    test('Preservation case: Empty file should NOT be detected as Archicad', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isFalse);
    });
  });
}
