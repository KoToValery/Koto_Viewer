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
