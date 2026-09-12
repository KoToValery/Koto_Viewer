import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/file_source_service.dart';
import 'package:kotoview/src/features/image_viewer/image_viewer_screen.dart';

void main() {
  group('Raster Image Model & Type Detection Tests', () {
    test('PdfItem correctly identifies raster image file extensions', () {
      final extensions = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'];
      for (final ext in extensions) {
        final item = PdfItem(
          path: '/storage/images/photo.$ext',
          name: 'photo.$ext',
          sizeInBytes: 1024,
          lastOpened: DateTime.now(),
        );

        expect(item.fileType, equals(KotoFileType.image),
            reason: 'Extension .$ext should map to KotoFileType.image');
        expect(item.isImage, isTrue,
            reason: 'item.isImage should be true for .$ext');
      }
    });

    test('PdfItem.isImage returns true for ICO and PSD files as well', () {
      final icoItem = PdfItem(
        path: '/icons/favicon.ico',
        name: 'favicon.ico',
        sizeInBytes: 256,
        lastOpened: DateTime.now(),
      );
      expect(icoItem.fileType, equals(KotoFileType.ico));
      expect(icoItem.isImage, isTrue);

      final psdItem = PdfItem(
        path: '/designs/banner.psd',
        name: 'banner.psd',
        sizeInBytes: 10240,
        lastOpened: DateTime.now(),
      );
      expect(psdItem.fileType, equals(KotoFileType.psd));
      expect(psdItem.isImage, isTrue);
    });

    test('FileSourceService.isSupportedFile returns true for all raster image types', () {
      expect(FileSourceService.isSupportedFile('test.png'), isTrue);
      expect(FileSourceService.isSupportedFile('photo.jpg'), isTrue);
      expect(FileSourceService.isSupportedFile('picture.jpeg'), isTrue);
      expect(FileSourceService.isSupportedFile('graphic.webp'), isTrue);
      expect(FileSourceService.isSupportedFile('animation.gif'), isTrue);
      expect(FileSourceService.isSupportedFile('bitmap.bmp'), isTrue);
      expect(FileSourceService.isSupportedFile('ICON.PNG'), isTrue);
    });
  });

  group('ImageViewerScreen Widget Tests', () {
    late Directory tempDir;
    late File testPngFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('koto_img_test_');
      testPngFile = File('${tempDir.path}/sample_test.png');

      // Create a minimal 2x2 PNG image using package:image
      final image = img.Image(width: 2, height: 2);
      image.setPixelRgba(0, 0, 255, 0, 0, 255);
      image.setPixelRgba(1, 0, 0, 255, 0, 255);
      image.setPixelRgba(0, 1, 0, 0, 255, 255);
      image.setPixelRgba(1, 1, 255, 255, 0, 255);

      final pngBytes = Uint8List.fromList(img.encodePng(image));
      testPngFile.writeAsBytesSync(pngBytes);
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('ImageViewerScreen loads and displays a PNG image', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageViewerScreen(filePath: testPngFile.path),
          ),
        );

        for (int i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(InteractiveViewer).evaluate().isNotEmpty) break;
        }
      });

      // Should display file name in AppBar
      expect(find.text('sample_test.png'), findsOneWidget);

      // Should find InteractiveViewer
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Floating zoom controls should be present
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.fit_screen_outlined), findsOneWidget);

      // Rotate and flip controls should be present
      expect(find.byIcon(Icons.rotate_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flip_rounded), findsOneWidget);
    });

    testWidgets('ImageViewerScreen opens properties bottom sheet', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageViewerScreen(filePath: testPngFile.path),
          ),
        );

        for (int i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(InteractiveViewer).evaluate().isNotEmpty) break;
        }
      });

      // Tap properties button
      final infoBtn = find.byIcon(Icons.info_outline_rounded);
      expect(infoBtn, findsOneWidget);
      await tester.tap(infoBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify bottom sheet content
      expect(find.text('Image Properties'), findsOneWidget);
      expect(find.text('Format:'), findsOneWidget);
      expect(find.text('Resolution:'), findsOneWidget);
      expect(find.text('File Size:'), findsOneWidget);
    });

    testWidgets('ImageViewerScreen toggles rotation, background mode, and pixelated mode', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageViewerScreen(filePath: testPngFile.path),
          ),
        );

        for (int i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(InteractiveViewer).evaluate().isNotEmpty) break;
        }
      });

      // 1. Rotate 90 degrees
      final rotateBtn = find.byIcon(Icons.rotate_right_rounded);
      expect(rotateBtn, findsOneWidget);
      await tester.tap(rotateBtn);
      await tester.pump();

      // 2. Toggle background mode (Checkerboard -> Dark -> Light)
      final bgBtn = find.byTooltip('Background: Checkerboard');
      expect(bgBtn, findsOneWidget);
      await tester.tap(bgBtn);
      await tester.pump();
      expect(find.byTooltip('Background: Dark'), findsOneWidget);

      await tester.tap(find.byTooltip('Background: Dark'));
      await tester.pump();
      expect(find.byTooltip('Background: Light'), findsOneWidget);

      // 3. Toggle crisp/pixelated rendering
      final pixelBtn = find.byIcon(Icons.blur_linear_rounded);
      expect(pixelBtn, findsOneWidget);
      await tester.tap(pixelBtn);
      await tester.pump();
      expect(find.byIcon(Icons.grain_rounded), findsOneWidget);
    });
  });
}
