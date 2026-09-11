import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/errors/app_error_handler.dart';
import 'package:kotoview/src/core/errors/global_crash_widget.dart';
import 'package:kotoview/src/core/errors/error_log_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppErrorHandler.clearErrors();
  });

  group('AppErrorHandler Unit Tests', () {
    test('Records error and adds to history', () {
      expect(AppErrorHandler.errors.isEmpty, isTrue);

      AppErrorHandler.recordError(
        Exception('Test failure in binary CAD parser'),
        StackTrace.current,
        context: 'cad_parser_test',
        isFatal: true,
      );

      expect(AppErrorHandler.errors.length, 1);
      final record = AppErrorHandler.errors.first;
      expect(record.error.toString(), contains('Test failure in binary CAD parser'));
      expect(record.errorContext, 'cad_parser_test');
      expect(record.isFatal, isTrue);
      expect(record.stackTrace, isNotNull);
    });

    test('Clear errors empties the history', () {
      AppErrorHandler.recordError('Sample error', null);
      expect(AppErrorHandler.errors.length, 1);

      AppErrorHandler.clearErrors();
      expect(AppErrorHandler.errors.isEmpty, isTrue);
    });

    test('exportErrorReport contains error details', () {
      AppErrorHandler.recordError(
        FormatException('Invalid DWG header stream'),
        StackTrace.current,
        context: 'dwg_ffi',
      );

      final report = AppErrorHandler.exportErrorReport();
      expect(report, contains('KoToViewer Error Report'));
      expect(report, contains('Invalid DWG header stream'));
      expect(report, contains('dwg_ffi'));
    });

    test('Maintains maxStoredErrors limit', () {
      for (int i = 0; i < AppErrorHandler.maxStoredErrors + 20; i++) {
        AppErrorHandler.recordError('Error #$i', null);
      }
      expect(AppErrorHandler.errors.length, AppErrorHandler.maxStoredErrors);
    });
  });

  group('GlobalCrashWidget Tests', () {
    testWidgets('GlobalCrashWidget displays friendly error UI and toggles details', (tester) async {
      final details = FlutterErrorDetails(
        exception: StateError('Unexpected null pointer in custom canvas painter'),
        stack: StackTrace.fromString('line 1: custom_painter.dart\nline 2: viewer.dart'),
        context: ErrorDescription('while building CAD viewer'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlobalCrashWidget(details: details),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and friendly description
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.textContaining('The application encountered an unexpected issue'), findsOneWidget);

      // Check action buttons
      expect(find.text('Go to Home'), findsOneWidget);
      expect(find.text('Copy Report'), findsOneWidget);

      // Initially, detailed stack trace container is collapsed
      expect(find.text('Show technical details'), findsOneWidget);
      expect(find.textContaining('custom_painter.dart'), findsNothing);

      // Tap to expand technical details
      await tester.tap(find.text('Show technical details'));
      await tester.pumpAndSettle();

      expect(find.text('Hide technical details'), findsOneWidget);
      expect(find.textContaining('custom_painter.dart'), findsOneWidget);
    });
  });

  group('ErrorLogDialog Tests', () {
    testWidgets('ErrorLogDialog shows empty state when no errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorLogDialog(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Error Log'), findsOneWidget);
      expect(find.text('No errors recorded'), findsOneWidget);
    });

    testWidgets('ErrorLogDialog shows logged errors and allows clearing', (tester) async {
      AppErrorHandler.recordError(
        'Corrupt DXF entity EOF reached prematurely',
        StackTrace.current,
        context: 'dxf_parser',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorLogDialog(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Error Log'), findsOneWidget);
      expect(find.textContaining('Corrupt DXF entity EOF'), findsOneWidget);
      expect(find.text('dxf_parser'), findsOneWidget);

      // Clear logs
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('No errors recorded'), findsOneWidget);
    });
  });
}
