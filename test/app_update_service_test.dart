import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/app_update_service.dart';
import 'package:kotoview/src/core/l10n/l10n_extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService Tests', () {
    setUp(() {
      AppUpdateService.isCheckingNotifier.value = false;
      AppUpdateService.isUpdateDownloadedNotifier.value = false;
      AppUpdateService.installStatusNotifier.value = null;
    });

    test('Initial states and constants are configured properly', () {
      expect(AppUpdateService.autoCheckInterval, const Duration(hours: 24));
      expect(AppUpdateService.isCheckingNotifier.value, isFalse);
      expect(AppUpdateService.isUpdateDownloadedNotifier.value, isFalse);
      expect(AppUpdateService.installStatusNotifier.value, isNull);
    });

    testWidgets('Non-Android platforms complete startup check safely without errors',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bg'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppUpdateService.checkForUpdateAtStartup(
                      context: context,
                      messenger: ScaffoldMessenger.of(context),
                    );
                  },
                  child: const Text('Check Startup'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check Startup'));
      await tester.pumpAndSettle();

      // On non-Android test runner, no exception should be thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('Manual check on non-Android shows localized upToDate message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bg'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppUpdateService.checkForUpdateManually(
                      context: context,
                      messenger: ScaffoldMessenger.of(context),
                    );
                  },
                  child: const Text('Manual Check'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Manual Check'));
      await tester.pumpAndSettle();

      // Verifies Bulgarian localization in SnackBar
      expect(find.text('Използвате най-новата версия на KoToViewer.'), findsOneWidget);
    });

    testWidgets('simulateDownloadedUpdateForTesting displays restart SnackBar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bg'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppUpdateService.simulateDownloadedUpdateForTesting(context);
                  },
                  child: const Text('Simulate Update'),
                );
              },
            ),
          ),
        ),
      );

      expect(AppUpdateService.isUpdateDownloadedNotifier.value, isFalse);

      await tester.tap(find.text('Simulate Update'));
      await tester.pumpAndSettle();

      // State is marked downloaded
      expect(AppUpdateService.isUpdateDownloadedNotifier.value, isTrue);

      // SnackBar shows localized restart message and action
      expect(
        find.text('Новата версия е изтеглена. Рестартирайте приложението, за да я приложите.'),
        findsOneWidget,
      );
      expect(find.text('Рестартиране'), findsOneWidget);
    });

    testWidgets('English localization verifies all update strings', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l10n.checkForUpdates, 'Check for Updates');
      expect(l10n.checkingForUpdates, 'Checking for updates...');
      expect(l10n.updateAvailableTitle, 'Update Available');
      expect(l10n.updateAvailableMessage,
          'A new version of KoToViewer is available on Google Play.');
      expect(l10n.updateNow, 'Update Now');
      expect(l10n.updateDownloadedSnackbar,
          'A new version has been downloaded. Restart the app to apply it.');
      expect(l10n.restartToUpdate, 'Restart');
      expect(l10n.appUpToDate, 'You are using the latest version of KoToViewer.');
      expect(l10n.updateCheckFailed, 'Could not check for updates via Google Play.');
      expect(l10n.openPlayStore, 'Open Google Play');
    });

    testWidgets('Bulgarian localization verifies all update strings', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bg'),
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l10n.checkForUpdates, 'Проверка за нова версия');
      expect(l10n.checkingForUpdates, 'Проверка за нова версия...');
      expect(l10n.updateAvailableTitle, 'Налична е нова версия');
      expect(l10n.updateAvailableMessage,
          'Налична е нова версия на KoToViewer в Google Play.');
      expect(l10n.updateNow, 'Актуализиране');
      expect(l10n.updateDownloadedSnackbar,
          'Новата версия е изтеглена. Рестартирайте приложението, за да я приложите.');
      expect(l10n.restartToUpdate, 'Рестартиране');
      expect(l10n.appUpToDate, 'Използвате най-новата версия на KoToViewer.');
      expect(l10n.updateCheckFailed, 'Неуспешна проверка за нова версия през Google Play.');
      expect(l10n.openPlayStore, 'Отвори Google Play');
    });
  });
}
