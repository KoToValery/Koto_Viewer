import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_exchange_export_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheets_screen.dart';

const _view = ArchitectSavedDrawing(
  id: 'plan:s',
  sourceId: 's',
  kind: ArchitectDrawingKind.plan,
);

ArchitectProject _project() => ArchitectProject(
  id: 'exchange-ui',
  name: 'Проверка',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: const [
    ArchitectStorey(
      id: 's',
      name: 'Етаж 1',
      walls: [
        ArchitectWall(id: 'w', startPoint: Offset.zero, endPoint: Offset(4, 0)),
      ],
    ),
  ],
  document: const ArchitectDocument(
    drawings: [_view],
    sheets: [
      ArchitectSheet(id: 'sheet-a'),
      ArchitectSheet(id: 'sheet-b'),
    ],
  ),
);

class _SavePicker extends FilePicker {
  _SavePicker(this.path);
  final String path;
  Uint8List? saved;
  String? name;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    saved = bytes;
    name = fileName;
    return path;
  }
}

Future<AppLocalizations> _open(
  WidgetTester tester,
  ArchitectExchangeFormat format, {
  String language = 'en',
  bool dark = false,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 740));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showArchitectExchangeExport(
              context,
              project: _project(),
              format: format,
              drawings: const [_view],
              initialSheetId: 'sheet-b',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return AppLocalizations.of(
    tester.element(find.byType(ArchitectExchangeExportDialog)),
  )!;
}

void main() {
  testWidgets('Layouts exposes IFC and source DXF before the first sheet', (
    tester,
  ) async {
    final controller = ArchitectCommandController(
      _project().copyWith(document: const ArchitectDocument()),
    );
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectSheetsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-sheet-more')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.byKey(const ValueKey('architect-sheet-export-dxf-views')),
          )
          .enabled,
      isTrue,
    );
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.byKey(const ValueKey('architect-sheet-export-dxf-sheets')),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('architect-sheet-export-ifc')));
    await tester.pumpAndSettle();
    expect(find.byType(ArchitectExchangeExportDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'bg']) {
    for (final dark in [false, true]) {
      testWidgets('$language ${dark ? 'dark' : 'light'} phone IFC controls', (
        tester,
      ) async {
        final l = await _open(
          tester,
          ArchitectExchangeFormat.ifc,
          language: language,
          dark: dark,
          textScale: 1.5,
        );
        expect(find.text(l.architectExportIfc), findsOneWidget);
        expect(find.text(l.architectExportIfcHint), findsOneWidget);
        expect(find.text('IFC2x3'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('architect-export-ifc-schema')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('IFC4').last);
        await tester.pumpAndSettle();
        expect(find.text('IFC4'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('architect-export-cancel')));
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectExchangeExportDialog), findsNothing);
      });
    }
  }

  testWidgets(
    'DXF selection starts at current sheet and disables empty export',
    (tester) async {
      await _open(tester, ArchitectExchangeFormat.dxfSheets);
      final a = find.byKey(const ValueKey('architect-export-sheet-sheet-a'));
      final b = find.byKey(const ValueKey('architect-export-sheet-sheet-b'));
      expect(tester.widget<CheckboxListTile>(a).value, isFalse);
      expect(tester.widget<CheckboxListTile>(b).value, isTrue);
      await tester.tap(b);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('architect-export-run')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'IFC save closes the job and opens its report on surviving route',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync(
        'architect_exchange_ui_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final picker = _SavePicker('${temp.path}/model.ifc');
      FilePicker.platform = picker;
      final l = await _open(tester, ArchitectExchangeFormat.ifc);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('architect-export-run')));
        await tester.pump();
        for (var i = 0; i < 500 && picker.saved == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        // Let the desktop file write and navigation complete.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(picker.name, endsWith('.ifc'));
      expect(utf8.decode(picker.saved!), contains("FILE_SCHEMA(('IFC2X3'))"));
      expect(File(picker.path).readAsBytesSync(), picker.saved);
      expect(find.byType(ArchitectExchangeExportDialog), findsNothing);
      expect(find.text(l.architectExportReport), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected sheets save as ZIP with separate DXF files', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('architect_exchange_zip_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final picker = _SavePicker('${temp.path}/sheets.zip');
    FilePicker.platform = picker;
    await _open(tester, ArchitectExchangeFormat.dxfSheets);
    await tester.tap(
      find.byKey(const ValueKey('architect-export-sheet-sheet-a')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('architect-export-run')));
      await tester.pump();
      for (var i = 0; i < 500 && picker.saved == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(picker.name, endsWith('.zip'));
    final archive = ZipDecoder().decodeBytes(picker.saved!);
    expect(archive.files, hasLength(2));
    expect(archive.files.map((f) => f.name).toSet(), hasLength(2));
    for (final file in archive.files) {
      expect(file.name, endsWith('.dxf'));
      expect(file.name, isNot(contains('/')));
      expect(utf8.decode(file.content as List<int>), contains('AC1027'));
    }
    expect(find.byType(ArchitectExchangeExportDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
