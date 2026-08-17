import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/svg_viewer/svg_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SVG Vector Support Tests', () {
    test('PdfItem correctly identifies .svg and .SVG file types', () {
      final svgItem = PdfItem(
        path: '/storage/emulated/0/Download/drawing.svg',
        name: 'drawing.svg',
        sizeInBytes: 1024,
        lastOpened: DateTime.now(),
      );

      final upperSvgItem = PdfItem(
        path: '/storage/emulated/0/Download/FLOOR_PLAN.SVG',
        name: 'FLOOR_PLAN.SVG',
        sizeInBytes: 2048,
        lastOpened: DateTime.now(),
      );

      expect(svgItem.fileType, equals(KotoFileType.svg));
      expect(svgItem.isSvg, isTrue);
      expect(svgItem.isCad, isFalse);
      expect(svgItem.fileExtension, equals('svg'));

      expect(upperSvgItem.fileType, equals(KotoFileType.svg));
      expect(upperSvgItem.isSvg, isTrue);
      expect(upperSvgItem.isCad, isFalse);
      expect(upperSvgItem.fileExtension, equals('svg'));
    });

    test('SvgCanvasTheme properties and dark mode detection', () {
      expect(SvgCanvasTheme.darkCad.isDark, isTrue);
      expect(SvgCanvasTheme.blueprint.isDark, isTrue);
      expect(SvgCanvasTheme.pureBlack.isDark, isTrue);
      expect(SvgCanvasTheme.lightStudio.isDark, isFalse);
      expect(SvgCanvasTheme.pureWhite.isDark, isFalse);
    });

    test('SvgMetadata element counting and calculation', () {
      const metadata = SvgMetadata(
        width: 800,
        height: 600,
        viewBox: Rect.fromLTWH(0, 0, 800, 600),
        pathCount: 15,
        shapeCount: 8,
        textCount: 4,
      );

      expect(metadata.width, 800);
      expect(metadata.height, 600);
      expect(metadata.totalElements, 27);
    });
  });
}
