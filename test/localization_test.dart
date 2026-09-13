import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/services/locale_service.dart';
import 'package:kotoview/src/core/l10n/l10n_extensions.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/file_source_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Defaults to system locale (null)', () async {
      await LocaleService.init();
      expect(LocaleService.currentLocaleNotifier.value, isNull);
      expect(LocaleService.isCurrentLocale(null), isTrue);
      expect(LocaleService.isCurrentLocale('bg'), isFalse);
    });

    test('Can set and persist Bulgarian locale', () async {
      await LocaleService.init();
      await LocaleService.setLocale(const Locale('bg'));

      expect(LocaleService.currentLocaleNotifier.value?.languageCode, equals('bg'));
      expect(LocaleService.isCurrentLocale('bg'), isTrue);

      // Re-init from prefs
      await LocaleService.init();
      expect(LocaleService.currentLocaleNotifier.value?.languageCode, equals('bg'));
    });

    test('Can switch back to system default', () async {
      await LocaleService.setLocale(const Locale('en'));
      expect(LocaleService.isCurrentLocale('en'), isTrue);

      await LocaleService.setLocale(null);
      expect(LocaleService.currentLocaleNotifier.value, isNull);
      expect(LocaleService.isCurrentLocale(null), isTrue);
    });

    test('Supported languages registry is complete and contains BG and EN', () {
      final codes = LocaleService.supportedLanguages.map((l) => l.languageCode).toList();
      expect(codes, contains(null)); // System default
      expect(codes, contains('bg'));
      expect(codes, contains('en'));
    });
  });

  group('AppLocalizations Strings Verification', () {
    testWidgets('English strings and parameters resolve correctly', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l10n.browseFiles, equals('Browse Files'));
      expect(l10n.recentFiles, equals('Recent Files'));
      expect(l10n.customFolder, equals('Custom Folder'));
      expect(l10n.loadingCad, equals('Loading CAD drawing...'));
      expect(l10n.loadingWordDoc, equals('Loading Word document...'));
      expect(l10n.loadingComic, equals('Loading comic book...'));
      expect(l10n.fitWidth, equals('Fit Width'));
      expect(l10n.jumpToPage, equals('Jump to Page'));
      expect(l10n.pageIndicator(3, 15), equals('Page 3 of 15'));
      expect(l10n.statusReadingFile('25.4'), equals('Reading file (25.4 MB)...'));
      expect(l10n.statusExtractingPage(2, 20), equals('Extracting page 2 of 20...'));
      expect(l10n.resumedAtPage(2, 10), equals('Resumed at Page 2 of 10'));
      expect(l10n.fileNotFoundOrInaccessible, equals('File not found or cannot be accessed.'));
      expect(l10n.comicRar5NotSupported, contains('RAR5'));
      expect(l10n.comicRarNotSupported, contains('RAR'));
      expect(l10n.comicArchiveCorrupted, equals('Comic book archive is corrupted or unreadable.'));
      expect(l10n.unsupportedFileFormat('sample.xyz'), equals('Unsupported file format: sample.xyz'));
      expect(l10n.convertingDwgTitle, equals('Converting DWG...'));
      expect(l10n.convertingPresentationTitle, equals('Converting Presentation...'));
      expect(l10n.errorLoadingSpreadsheet('corrupt'), equals('Error loading Excel file: corrupt'));
      expect(l10n.errorLoadingMarkdown('bad format'), equals('Error loading markdown: bad format'));
      expect(l10n.errorReadingWordDocument('fail'), equals('Error reading Word document: fail'));
      expect(l10n.errorReadingTextFile('fail'), equals('Error reading text file: fail'));
      expect(l10n.resumedReadingPosition, equals('Resumed reading position'));
      expect(l10n.woffNotSupported, equals('WOFF/WOFF2 preview is not supported. Please convert to TTF or OTF first.'));
      expect(l10n.errorLoading3dModel('fail'), equals('Error loading 3D model: fail'));
      expect(l10n.failedToParse3dMesh, equals('Failed to parse 3D mesh.'));
      expect(l10n.retry, equals('Retry'));
      expect(l10n.bimStoreysAndCategories, equals('BIM Storeys & Categories'));
      expect(l10n.properties3d, equals('3D Properties'));
      expect(l10n.errorLoadingDxf('corrupt'), equals('Error opening DXF file: corrupt'));
      expect(l10n.failedToSaveDxf('disk full'), equals('Failed to save DXF: disk full'));
      expect(l10n.savedDxf('plan.dxf'), equals('Saved DXF: plan.dxf'));
      expect(l10n.errorImportingDxf('bad layer'), equals('Error importing DXF: bad layer'));
      expect(l10n.importedDxfSuccess(42, 'blocks.dxf'), equals('Successfully imported 42 entities from blocks.dxf'));
      expect(l10n.fitScreen, equals('Fit Screen'));
      expect(l10n.printPreviewUnavailable('printer offline'), equals('Print preview unavailable: printer offline'));
      expect(l10n.errorReadingHpgl('bad cmd'), equals('Error reading HPGL plotter file: bad cmd'));
      expect(l10n.errorReadingPcb('bad header'), equals('Error reading PCB project: bad header'));
      expect(l10n.errorReadingCdr('bad container'), equals('Error reading CorelDRAW file: bad container'));
      expect(l10n.couldNotExportPng('write error'), equals('Could not export PNG: write error'));
      expect(l10n.printError('offline'), equals('Print error: offline'));
      expect(l10n.errorReadingEps('invalid header'), equals('Error reading EPS file: invalid header'));
      expect(l10n.errorLoadingSvg('xml error'), equals('Error loading SVG: xml error'));
      expect(l10n.errorLoadingRoute('bad gpx'), equals('Could not load route file: bad gpx'));
      expect(l10n.centeredOnWaypoint('Peak A'), equals('Centered on: Peak A'));
    });

    testWidgets('Bulgarian strings and parameters resolve correctly', (tester) async {
      late AppLocalizations l10n;
      late BuildContext buildCtx;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              buildCtx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l10n.browseFiles, equals('Преглед на файлове'));
      expect(l10n.recentFiles, equals('Скорошни'));
      expect(l10n.customFolder, equals('Папка'));
      expect(l10n.loadingCad, equals('Зареждане на CAD чертеж...'));
      expect(l10n.convertingDwg, equals('Конвертиране и зареждане на DWG...'));
      expect(l10n.loadingWordDoc, equals('Зареждане на Word документ...'));
      expect(l10n.loadingComic, equals('Зареждане на комикс...'));
      expect(l10n.fitWidth, equals('По ширината'));
      expect(l10n.jumpToPage, equals('Към страница'));
      expect(l10n.cancel, equals('Отказ'));
      expect(l10n.pageIndicator(3, 15), equals('Страница 3 от 15'));
      expect(l10n.statusReadingFile('25.4'), equals('Четене на файл (25.4 MB)...'));
      expect(l10n.statusExtractingPage(2, 20), equals('Разархивиране на страница 2 от 20...'));
      expect(l10n.resumedAtPage(2, 10), equals('Възобновено от страница 2 от 10'));
      expect(l10n.fileNotFoundOrInaccessible, equals('Файлът не е намерен или няма достъп до него.'));
      expect(l10n.comicRar5NotSupported, contains('RAR5'));
      expect(l10n.comicRarNotSupported, contains('RAR'));
      expect(l10n.comicArchiveCorrupted, equals('Архивът на комикса е повреден или нечетлив.'));
      expect(l10n.unsupportedFileFormat('sample.xyz'), equals('Неподдържан файлов формат: sample.xyz'));
      expect(l10n.convertingDwgTitle, equals('Конвертиране на DWG...'));
      expect(l10n.convertingPresentationTitle, equals('Конвертиране на презентация...'));
      expect(l10n.errorLoadingSpreadsheet('corrupt'), equals('Грешка при зареждане на Excel файл: corrupt'));
      expect(l10n.errorLoadingMarkdown('bad format'), equals('Грешка при зареждане на markdown: bad format'));
      expect(l10n.errorReadingWordDocument('fail'), equals('Грешка при четене на Word документ: fail'));
      expect(l10n.errorReadingTextFile('fail'), equals('Грешка при четене на текстов файл: fail'));
      expect(l10n.resumedReadingPosition, equals('Възобновена позиция на четене'));
      expect(l10n.woffNotSupported, equals('Прегледът на WOFF/WOFF2 не се поддържа. Моля, първо конвертирайте в TTF или OTF.'));
      expect(l10n.errorLoading3dModel('fail'), equals('Грешка при зареждане на 3D модел: fail'));
      expect(l10n.failedToParse3dMesh, equals('Неуспешно разчитане на 3D геометрията.'));
      expect(l10n.retry, equals('Опитай отново'));
      expect(l10n.bimStoreysAndCategories, equals('BIM етажи и категории'));
      expect(l10n.properties3d, equals('3D Свойства'));
      expect(l10n.errorLoadingDxf('corrupt'), equals('Грешка при отваряне на DXF файл: corrupt'));
      expect(l10n.failedToSaveDxf('disk full'), equals('Грешка при запис на DXF: disk full'));
      expect(l10n.savedDxf('plan.dxf'), equals('Записан DXF: plan.dxf'));
      expect(l10n.errorImportingDxf('bad layer'), equals('Грешка при импортиране на DXF: bad layer'));
      expect(l10n.importedDxfSuccess(42, 'blocks.dxf'), equals('Успешно импортирани 42 обекта от blocks.dxf'));
      expect(l10n.fitScreen, equals('Побиране в екрана'));
      expect(l10n.printPreviewUnavailable('printer offline'), equals('Прегледът за печат е недостъпен: printer offline'));
      expect(l10n.errorReadingHpgl('bad cmd'), equals('Грешка при четене на HPGL плотерен файл: bad cmd'));
      expect(l10n.errorReadingPcb('bad header'), equals('Грешка при четене на платка (PCB): bad header'));
      expect(l10n.errorReadingCdr('bad container'), equals('Грешка при четене на CorelDRAW файл: bad container'));
      expect(l10n.couldNotExportPng('write error'), equals('Неуспешен експорт на PNG: write error'));
      expect(l10n.printError('offline'), equals('Грешка при печат: offline'));
      expect(l10n.errorReadingEps('invalid header'), equals('Грешка при четене на EPS файл: invalid header'));
      expect(l10n.errorLoadingSvg('xml error'), equals('Грешка при зареждане на SVG: xml error'));
      expect(l10n.errorLoadingRoute('bad gpx'), equals('Грешка при зареждане на маршрут: bad gpx'));
      expect(l10n.centeredOnWaypoint('Връх А'), equals('Центрирано върху: Връх А'));

      // Test category labels in Bulgarian
      expect(FileCategory.all.localizedLabel(buildCtx), equals('Всички'));
      expect(FileCategory.cad2d.localizedLabel(buildCtx), equals('2D CAD'));
      expect(FileCategory.cad3d.localizedLabel(buildCtx), equals('3D Модели'));
      expect(FileCategory.documents.localizedLabel(buildCtx), equals('Документи'));

      // Test sort and mode in Bulgarian
      expect(FileSourceMode.recent.localizedLabel(buildCtx), equals('Скорошни'));
      expect(SortOption.date.localizedLabel(buildCtx), equals('Дата на промяна'));
      expect(SortOption.name.localizedLabel(buildCtx), equals('Име на файл'));
    });
  });
}
