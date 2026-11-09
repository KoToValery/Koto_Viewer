import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_studio_tab.dart';
import 'package:kotoview/src/features/architect/widgets/architect_project_wizard_dialog.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/screens/structural_studio_tab.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/home/home_screen.dart';

class MockLibraryService extends BimProjectLibraryService {
  final List<BimWorkProject> projects;
  MockLibraryService(this.projects);

  @override
  Future<List<BimWorkProject>> listProjects() async => projects;
}

Widget testApp(Widget home, {Locale locale = const Locale('bg')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('HomeScreen displays 3 module tabs at startup (bg & en)', (tester) async {
    for (final locale in ['bg', 'en']) {
      await tester.pumpWidget(
        testApp(
          HomeScreen(
            onToggleTheme: (_) {},
            isDarkMode: false,
          ),
          locale: Locale(locale),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      final l10n = await AppLocalizations.delegate.load(Locale(locale));

      // Verify the 3 tabs exist in TabBar
      expect(find.text(l10n.moduleAioViewer), findsOneWidget);
      expect(find.text(l10n.moduleArchitectStudio), findsOneWidget);
      expect(find.text(l10n.moduleStructuralBim), findsOneWidget);

      // Verify the heart button (support developer) is gone
      expect(find.byTooltip(l10n.supportDeveloper), findsNothing);
    }
  });

  testWidgets('ArchitectStudioTab does not show alignment buttons or status', (tester) async {
    final now = DateTime.now();
    final mockProjects = [
      BimWorkProject(
        id: 'arch_1',
        name: 'Villa Architectural',
        location: 'Sofia',
        projectType: BimProjectType.architectural,
        createdAt: now,
        updatedAt: now,
        storeys: const [
          BimStoreyUnderlay(
            storeyId: 's1',
            name: '±0.00',
            elevation: 0.0,
            height: 3.0,
          ),
        ],
        alignmentConfirmed: false,
      ),
    ];

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ArchitectStudioTab(
            libraryService: MockLibraryService(mockProjects),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('bg'));

    // Open button should be present
    expect(find.text(l10n.bimProjectOpen), findsOneWidget);

    // "Align drawings" button must NOT be present
    expect(find.text(l10n.bimProjectAlignStoreys), findsNothing);

    // Alignment status badge must NOT be present
    expect(find.text(l10n.bimProjectStatusReady), findsNothing);
    expect(find.text(l10n.bimProjectStatusAlignment), findsNothing);
  });

  testWidgets('StructuralStudioTab displays alignment status and align button', (tester) async {
    final now = DateTime.now();
    final mockProjects = [
      BimWorkProject(
        id: 'struct_1',
        name: 'Building Structural',
        location: 'Plovdiv',
        projectType: BimProjectType.structural,
        createdAt: now,
        updatedAt: now,
        storeys: const [
          BimStoreyUnderlay(
            storeyId: 's1',
            name: '±0.00',
            elevation: 0.0,
            height: 3.0,
          ),
        ],
        alignmentConfirmed: false,
      ),
    ];

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: StructuralStudioTab(
            libraryService: MockLibraryService(mockProjects),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('bg'));

    // Both open model and align buttons must be present
    expect(find.text(l10n.bimProjectOpen), findsOneWidget);
    expect(find.text(l10n.bimProjectAlignStoreys), findsOneWidget);

    // Alignment status badge must be present
    expect(find.text(l10n.bimProjectStatusAlignment), findsOneWidget);
  });

  testWidgets('ArchitectProjectWizardDialog offers Add Overlay for storey', (tester) async {
    await tester.pumpWidget(
      testApp(
        const ArchitectProjectWizardDialog(),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to step 2 (Storeys)
    await tester.tap(find.byKey(const ValueKey('architect-wizard-step-2')));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('bg'));

    // The add overlay button must exist for storey 0
    expect(find.byKey(const ValueKey('architect-wizard-overlay-add-0')), findsOneWidget);
    expect(find.text(l10n.architectWizardAddOverlay), findsOneWidget);
  });
}
