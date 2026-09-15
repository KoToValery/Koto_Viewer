import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

void main() {
  group('DXF Text Fixed Height & Scaling Tests', () {
    test('AutoCAD file with fixed height style (12.0) does NOT scale text by 12x', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          r'$ACADVER': 'AC1018',
        },
        textStyles: {
          'Standard': const DxfTextStyle(name: 'Standard', heightScale: 12.0),
          'koti': const DxfTextStyle(name: 'koti', heightScale: 12.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isFalse);

      // Height 40.0 should remain 40.0, NOT become 480.0
      final h40 = DxfPainter.getEffectiveTextHeight(40.0, 'Standard', doc);
      expect(h40, equals(40.0));

      // Height 24.0 should remain 24.0, NOT become 288.0
      final h24 = DxfPainter.getEffectiveTextHeight(24.0, 'Standard', doc);
      expect(h24, equals(24.0));

      // Height 12.0 should remain 12.0, NOT become 144.0
      final h12 = DxfPainter.getEffectiveTextHeight(12.0, 'Standard', doc);
      expect(h12, equals(12.0));
    });

    test('Archicad-originated file with 2.0x style scale correctly applies 2.0x factor', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          r'$ACADVER': 'ARCHICAD_24',
        },
        textStyles: {
          'Standard': const DxfTextStyle(name: 'Standard', heightScale: 2.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);

      // Height 3.5 should become 7.0 for Archicad
      final h = DxfPainter.getEffectiveTextHeight(3.5, 'Standard', doc);
      expect(h, equals(7.0));
    });

    test('Zero height entity falls back to style fixed height or 2.5 default', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'Fixed12': const DxfTextStyle(name: 'Fixed12', heightScale: 12.0),
          'ZeroStyle': const DxfTextStyle(name: 'ZeroStyle', heightScale: 1.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        entityStats: {},
      );

      // Zero height with fixed style returns style height 12.0
      final hFixed = DxfPainter.getEffectiveTextHeight(0.0, 'Fixed12', doc);
      expect(hFixed, equals(12.0));

      // Zero height without fixed style returns default 2.5
      final hDefault = DxfPainter.getEffectiveTextHeight(0.0, 'ZeroStyle', doc);
      expect(hDefault, equals(2.5));
    });
  });
}
