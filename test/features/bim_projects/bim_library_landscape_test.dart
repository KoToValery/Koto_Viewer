import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_projects/bim_project_library_screen.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';

class EmptyProjectLibrary extends BimProjectLibraryService {
  @override
  Future<List<BimWorkProject>> listProjects() async => [];
}

void main() {
  for (final locale in ['bg', 'en']) {
    testWidgets('Empty library rotates to landscape without overflow ($locale)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final l = await AppLocalizations.delegate.load(Locale(locale));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BimProjectLibraryScreen(libraryService: EmptyProjectLibrary()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.bimProjectNoProjects), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Reproduce the reported viewport: 727.6 x 238.9 after old 32 px padding.
      tester.view.physicalSize = const Size(791.6, 358.9);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.widgetWithText(ElevatedButton, l.bimProjectNew);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      final actionRect = tester.getRect(button);
      expect(viewport.contains(actionRect.center), true);
      expect(
        actionRect.overlaps(tester.getRect(find.byType(FloatingActionButton))),
        false,
      );
      expect(button.hitTestable(), findsOneWidget);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Short landscape viewport supports larger text and bottom insets',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(792, 320);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final l = await AppLocalizations.delegate.load(const Locale('bg'));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.5),
              padding: const EdgeInsets.only(bottom: 24),
            ),
            child: child!,
          ),
          home: BimProjectLibraryScreen(libraryService: EmptyProjectLibrary()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.widgetWithText(ElevatedButton, l.bimProjectNew);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      expect(
        tester
            .getRect(button)
            .overlaps(tester.getRect(find.byType(FloatingActionButton))),
        false,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
