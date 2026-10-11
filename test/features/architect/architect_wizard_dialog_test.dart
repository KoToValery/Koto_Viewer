import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/widgets/architect_project_wizard_dialog.dart';

void main() {
  Widget buildTestDialog({
    Locale locale = const Locale('en'),
    void Function(ArchitectProject?)? onResult,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await ArchitectProjectWizardDialog.show(
                context,
                initialProjectName: 'Modern Residence',
              );
              onResult?.call(result);
            },
            child: const Text('Open Wizard'),
          ),
        ),
      ),
    );
  }

  testWidgets('ArchitectProjectWizardDialog 3-step flow and unit selection in English', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ArchitectProject? createdProject;

    await tester.pumpWidget(
      buildTestDialog(
        locale: const Locale('en'),
        onResult: (res) => createdProject = res,
      ),
    );
    await tester.pumpAndSettle();

    // Open wizard dialog
    await tester.tap(find.text('Open Wizard'));
    await tester.pumpAndSettle();

    // --- STEP 0: UNITS & PROJECT NAME ---
    expect(find.text('New Architectural Project'), findsOneWidget);
    expect(find.text('1. Units'), findsOneWidget);
    expect(find.text('2. Storeys & Grid'), findsOneWidget);
    expect(find.text('3. Walls & Sizing'), findsOneWidget);

    // Cancel on left, Next on right
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // Toggle unit to Imperial (Feet)
    final imperialChip = find.text('Imperial (ft, in)');
    expect(imperialChip, findsOneWidget);
    await tester.tap(imperialChip);
    await tester.pumpAndSettle();

    // Verify feet / inches chips are visible
    expect(find.text('Feet (ft)'), findsOneWidget);
    expect(find.text('Inches (in)'), findsOneWidget);

    // Switch back to Metric (Centimeters)
    final metricChip = find.text('Metric (m, cm, mm)');
    await tester.tap(metricChip);
    await tester.pumpAndSettle();

    final cmChip = find.text('Centimeters (cm)');
    expect(cmChip, findsOneWidget);
    await tester.tap(cmChip);
    await tester.pumpAndSettle();

    // Advance to Step 1
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // --- STEP 1: STOREYS & GRID ---
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Storeys & Heights'), findsOneWidget);
    expect(find.text('1 Storey'), findsOneWidget);
    expect(find.text('2 Storeys'), findsOneWidget);

    // Select 5 storeys
    final fiveStoreysChip = find.text('5 Storeys');
    expect(fiveStoreysChip, findsOneWidget);
    await tester.tap(fiveStoreysChip);
    await tester.pumpAndSettle();

    // Advance to Step 2
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // --- STEP 2: WALLS & SIZING ---
    expect(find.text('Wall Types & Balcony Parapet'), findsOneWidget);
    expect(find.text('Create Project & Start'), findsOneWidget);

    // Verify height is 1.20 m (120 cm) because storeys >= 5
    expect(find.textContaining('above 5th storey'), findsOneWidget);

    // Finish wizard and create project
    await tester.tap(find.text('Create Project & Start'));
    await tester.pumpAndSettle();

    // Dialog closed and project created
    expect(find.byType(Dialog), findsNothing);
    expect(createdProject, isNotNull);
    expect(createdProject!.name, 'Modern Residence');
    expect(createdProject!.units, ArchitectUnit.centimeters);
    expect(createdProject!.storeys.length, 5);
    expect(createdProject!.wallTypes.isNotEmpty, isTrue);

    final parapet = createdProject!.wallTypes.firstWhere((w) => w.id == 'parapet_12');
    expect(parapet.customHeight, 1.20);
  });

  testWidgets('ArchitectProjectWizardDialog localized in Bulgarian with Step navigation pills', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ArchitectProject? createdProject;

    await tester.pumpWidget(
      buildTestDialog(
        locale: const Locale('bg'),
        onResult: (res) => createdProject = res,
      ),
    );
    await tester.pumpAndSettle();

    // Open wizard dialog
    await tester.tap(find.text('Open Wizard'));
    await tester.pumpAndSettle();

    // Title in Bulgarian
    expect(find.text('Нов архитектурен проект'), findsOneWidget);
    expect(find.text('1. Единици'), findsOneWidget);
    expect(find.text('2. Етажи и оси'), findsOneWidget);
    expect(find.text('3. Размери на стени'), findsOneWidget);
    expect(find.text('Отказ'), findsOneWidget);
    expect(find.text('Напред'), findsOneWidget);

    // Tap directly on Step 3 indicator pill to jump to walls
    await tester.tap(find.text('3. Размери на стени'));
    await tester.pumpAndSettle();

    // Verify Step 3 UI in Bulgarian
    expect(find.text('Типове стени и парапет'), findsOneWidget);
    expect(find.text('Създай проект и започни'), findsOneWidget);

    // Tap Create
    await tester.tap(find.text('Създай проект и започни'));
    await tester.pumpAndSettle();

    expect(createdProject, isNotNull);
    expect(createdProject!.units, ArchitectUnit.meters);
  });
}
