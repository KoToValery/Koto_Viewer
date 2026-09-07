import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/widgets/viewer_loading_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ViewerLoadingScreen Widget Tests', () {
    testWidgets('Renders file name, formatted size, icon, title, and status message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ViewerLoadingScreen(
            fileName: 'Architectural_Plan.pdf',
            fileSizeBytes: 24576000, // ~23.4 MB
            icon: Icons.picture_as_pdf_rounded,
            accentColor: Color(0xFFE53935),
            loadingTitle: 'Зареждане на PDF документ...',
            statusMessage: 'Подготовка на страниците...',
          ),
        ),
      );

      expect(find.text('Architectural_Plan.pdf'), findsOneWidget);
      expect(find.text('23.4 MB'), findsOneWidget);
      expect(find.text('Зареждане на PDF документ...'), findsOneWidget);
      expect(find.text('Подготовка на страниците...'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders determinate progress with percentage badge when progress is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ViewerLoadingScreen(
            fileName: 'Mechanical_Part.fbx',
            fileSizeBytes: 5242880, // 5.0 MB
            icon: Icons.view_in_ar_rounded,
            accentColor: Color(0xFF00E5FF),
            loadingTitle: 'Зареждане на 3D модел...',
            progress: 0.68,
            progressDetails: 'Триангулация: 68%',
          ),
        ),
      );

      expect(find.text('Mechanical_Part.fbx'), findsOneWidget);
      expect(find.text('5.0 MB'), findsOneWidget);
      expect(find.text('68%'), findsOneWidget);
      expect(find.text('Триангулация: 68%'), findsOneWidget);
    });

    testWidgets('Triggers onCancel callback when close button is pressed', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ViewerLoadingScreen(
            fileName: 'Big_Spreadsheet.xlsx',
            fileSizeBytes: 1048576,
            icon: Icons.table_chart_rounded,
            accentColor: const Color(0xFF107C41),
            onCancel: () => cancelled = true,
          ),
        ),
      );

      expect(cancelled, isFalse);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(cancelled, isTrue);
    });
  });

  group('FBX and 3D / Ebook File Type Tests', () {
    test('PdfItem correctly recognizes .fbx files as 3D CAD models', () {
      final item = PdfItem(
        path: '/storage/emulated/0/Download/character_model.fbx',
        name: 'character_model.fbx',
        sizeInBytes: 15728640,
        lastOpened: DateTime.now(),
      );

      expect(item.fileType, equals(KotoFileType.fbx));
      expect(item.is3d, isTrue);
      expect(item.isFbx, isTrue);
      expect(item.category, equals(FileCategory.cad3d));
    });

    test('PdfItem correctly recognizes .fb2 and .fb2.zip as ebooks', () {
      final fb2Item = PdfItem(
        path: '/storage/emulated/0/Books/novel.fb2',
        name: 'novel.fb2',
        sizeInBytes: 4194304,
        lastOpened: DateTime.now(),
      );
      expect(fb2Item.fileType, equals(KotoFileType.fb2));
      expect(fb2Item.isEbook, isTrue);
      expect(fb2Item.category, equals(FileCategory.documents));

      final fb2ZipItem = PdfItem(
        path: '/storage/emulated/0/Books/archive.fb2.zip',
        name: 'archive.fb2.zip',
        sizeInBytes: 2097152,
        lastOpened: DateTime.now(),
      );
      expect(fb2ZipItem.fileType, equals(KotoFileType.fb2));
      expect(fb2ZipItem.isEbook, isTrue);
    });
  });
}
