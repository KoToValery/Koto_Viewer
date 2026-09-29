import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/cdr_viewer/cdr_viewer_screen.dart';
import 'package:kotoview/src/features/code_viewer/code_viewer_screen.dart';
import 'package:kotoview/src/features/eps_viewer/eps_viewer_screen.dart';
import 'package:kotoview/src/features/hpgl_viewer/hpgl_viewer_screen.dart';
import 'package:kotoview/src/features/markdown_viewer/markdown_viewer_screen.dart';
import 'package:kotoview/src/features/svg_viewer/svg_viewer_screen.dart';
import 'package:kotoview/src/features/text_viewer/text_viewer_screen.dart';

Widget _wrapWithOrientation({
  required Widget child,
  required Size size,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      padding: EdgeInsets.zero,
    ),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('koto_test_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Adaptive AppBar (Landscape 1-Row, Portrait 2-Row) Tests', () {
    testWidgets('MarkdownViewerScreen adapts AppBar bottom and actions', (tester) async {
      final mdFile = File('${tempDir.path}/test.md')..writeAsStringSync('# Title\nContent');

      // 1. Portrait mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: MarkdownViewerScreen(filePath: mdFile.path),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final portraitAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(portraitAppBar.bottom, isNotNull, reason: 'Portrait must have bottom toolbar');
      expect(portraitAppBar.actions, isEmpty, reason: 'Portrait actions in AppBar should be empty');

      // 2. Landscape mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: MarkdownViewerScreen(filePath: mdFile.path),
          size: const Size(800, 400),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final landscapeAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(landscapeAppBar.bottom, isNull, reason: 'Landscape must collapse bottom toolbar');
      expect(landscapeAppBar.actions, isNotEmpty, reason: 'Landscape moves controls to actions');
    });

    testWidgets('CodeViewerScreen adapts AppBar bottom and actions', (tester) async {
      final codeFile = File('${tempDir.path}/test.dart')..writeAsStringSync('void main() {}');

      // 1. Portrait mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: CodeViewerScreen(filePath: codeFile.path),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final portraitAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(portraitAppBar.bottom, isNotNull);
      expect(portraitAppBar.actions, isEmpty);

      // 2. Landscape mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: CodeViewerScreen(filePath: codeFile.path),
          size: const Size(800, 400),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final landscapeAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(landscapeAppBar.bottom, isNull);
      expect(landscapeAppBar.actions, isNotEmpty);
    });

    testWidgets('TextViewerScreen adapts AppBar bottom and actions', (tester) async {
      final txtFile = File('${tempDir.path}/test.txt')..writeAsStringSync('line 1\nline 2');

      // 1. Portrait mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: TextViewerScreen(filePath: txtFile.path),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final portraitAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(portraitAppBar.bottom, isNotNull);
      expect(portraitAppBar.actions, isEmpty);

      // 2. Landscape mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: TextViewerScreen(filePath: txtFile.path),
          size: const Size(800, 400),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final landscapeAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(landscapeAppBar.bottom, isNull);
      expect(landscapeAppBar.actions, isNotEmpty);
    });

    testWidgets('SvgViewerScreen adapts AppBar and contains no floating +/- zoom buttons', (tester) async {
      final svgFile = File('${tempDir.path}/test.svg')
        ..writeAsStringSync('<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40"/></svg>');

      // 1. Portrait mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: SvgViewerScreen(filePath: svgFile.path),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final portraitAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(portraitAppBar.bottom, isNotNull);

      // Verify NO floating '+' and '-' buttons exist in the viewer
      expect(find.byIcon(Icons.add), findsNothing, reason: 'Floating + button must be removed');
      expect(find.byIcon(Icons.remove), findsNothing, reason: 'Floating - button must be removed');

      // 2. Landscape mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: SvgViewerScreen(filePath: svgFile.path),
          size: const Size(800, 400),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final landscapeAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(landscapeAppBar.bottom, isNull);
      expect(landscapeAppBar.actions, isNotEmpty);
    });

    testWidgets('EpsViewerScreen adapts AppBar and contains no floating +/- zoom buttons', (tester) async {
      final epsFile = File('${tempDir.path}/test.eps')..writeAsStringSync('%!PS-Adobe-3.0 EPSF-3.0');

      // 1. Portrait mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: EpsViewerScreen(filePath: epsFile.path),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final portraitAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(portraitAppBar.bottom, isNotNull);

      // Verify NO floating '+' and '-' buttons
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.remove), findsNothing);

      // 2. Landscape mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: EpsViewerScreen(filePath: epsFile.path),
          size: const Size(800, 400),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final landscapeAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(landscapeAppBar.bottom, isNull);
      expect(landscapeAppBar.actions, isNotEmpty);
    });

    testWidgets('HpglViewerScreen adapts AppBar and contains no floating +/- zoom buttons', (tester) async {
      final pltFile = File('${tempDir.path}/test.plt')..writeAsStringSync('IN;SP1;PA0,0;');

      // 1. Portrait mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: HpglViewerScreen(filePath: pltFile.path),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final portraitAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(portraitAppBar.bottom, isNotNull);

      // Verify NO floating '+' and '-' buttons
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.remove), findsNothing);

      // 2. Landscape mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: HpglViewerScreen(filePath: pltFile.path),
          size: const Size(800, 400),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final landscapeAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(landscapeAppBar.bottom, isNull);
      expect(landscapeAppBar.actions, isNotEmpty);
    });

    testWidgets('CdrViewerScreen adapts AppBar and contains no floating +/- zoom buttons', (tester) async {
      final cdrFile = File('${tempDir.path}/test.cdr')..writeAsBytesSync([0x50, 0x4B, 0x05, 0x06, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

      // 1. Portrait mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: CdrViewerScreen(filePath: cdrFile.path),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final portraitAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(portraitAppBar.bottom, isNotNull);

      // Verify NO floating '+' and '-' buttons
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.remove), findsNothing);

      // 2. Landscape mode
      await tester.pumpWidget(
        _wrapWithOrientation(
          child: CdrViewerScreen(filePath: cdrFile.path),
          size: const Size(800, 400),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final landscapeAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(landscapeAppBar.bottom, isNull);
      expect(landscapeAppBar.actions, isNotEmpty);
    });
  });
}
