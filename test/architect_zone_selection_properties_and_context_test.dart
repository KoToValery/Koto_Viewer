import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_zone_properties_card.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testZone = ArchitectZone(
    id: 'zone-1',
    number: '1',
    name: 'Living Room',
    category: ArchitectZoneCategory.living,
    polygon: const [
      Offset(0, 0),
      Offset(5, 0),
      Offset(5, 4),
      Offset(0, 4),
    ],
    floorFinish: 'Laminate',
    wallFinish: 'Latex paint',
    ceilingFinish: 'Latex paint',
    clearHeight: 2.60,
    targetArea: 20.0,
    isAutoBoundary: true,
  );

  final testProject = ArchitectProject(
    id: 'proj-1',
    name: 'Test Project',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    activeStoreyId: 'storey-1',
    storeys: [
      ArchitectStorey(
        id: 'storey-1',
        name: 'Ground Floor',
        elevation: 0.0,
        height: 2.80,
        zones: [testZone],
      ),
    ],
  );

  test('ArchitectSelection schema exposes zone clearHeight and targetArea', () {
    final fields = ArchitectSelection.fields(testProject, 'zone-1');
    expect(fields['clearHeight'], 2.60);
    expect(fields['targetArea'], 20.0);
  });

  test('SetArchitectElementProperties updates all zone settings cleanly', () {
    final cmd = SetArchitectElementProperties(
      storeyId: 'storey-1',
      elementIds: {'zone-1'},
      values: {
        'clearHeight': 2.85,
        'targetArea': 22.5,
      },
      textValues: {
        'number': '102',
        'name': 'Master Bedroom',
        'category': 'bedroom',
        'floorFinish': 'Parquet',
        'wallFinish': 'Faience',
        'ceilingFinish': 'Gypsum Board',
        'isAutoBoundary': 'false',
      },
    );

    final updated = cmd.apply(testProject);
    final updatedZone = updated.activeStorey.zones.firstWhere((z) => z.id == 'zone-1');

    expect(updatedZone.number, '102');
    expect(updatedZone.name, 'Master Bedroom');
    expect(updatedZone.category, ArchitectZoneCategory.bedroom);
    expect(updatedZone.clearHeight, 2.85);
    expect(updatedZone.targetArea, 22.5);
    expect(updatedZone.floorFinish, 'Parquet');
    expect(updatedZone.wallFinish, 'Faience');
    expect(updatedZone.ceilingFinish, 'Gypsum Board');
    expect(updatedZone.isAutoBoundary, false);
  });

  test('BimEditAction.schedule has valid label and icon in EN and BG', () async {
    final enL10n = await AppLocalizations.delegate.load(const Locale('en'));
    final bgL10n = await AppLocalizations.delegate.load(const Locale('bg'));

    expect(BimEditActions.icon(BimEditAction.schedule), Icons.table_chart_rounded);
    expect(BimEditActions.label(BimEditAction.schedule, enL10n), 'Room Schedule');
    expect(BimEditActions.label(BimEditAction.schedule, bgL10n), 'Таблица на помещенията');
  });

  testWidgets('ArchitectElementPropertiesDialog renders all zone properties and actions', (tester) async {
    bool scheduleOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => ArchitectElementPropertiesDialog(
                    project: testProject,
                    elementIds: {'zone-1'},
                    onScheduleTable: () => scheduleOpened = true,
                    onApply: (v, t) => true,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Tap to open properties dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify dialog title
    expect(find.text('Properties'), findsOneWidget);

    // Verify schedule table button
    expect(find.byKey(const ValueKey('architect-property-schedule-table')), findsOneWidget);

    // Verify category dropdown
    expect(find.byKey(const ValueKey('architect-property-category-living')), findsOneWidget);

    // Verify number and name fields
    expect(find.byKey(const ValueKey('architect-property-number-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('architect-property-name-Living Room')), findsOneWidget);

    // Verify clear height and target area number fields
    expect(find.byKey(const ValueKey('architect-property-clearHeight')), findsOneWidget);
    expect(find.byKey(const ValueKey('architect-property-targetArea')), findsOneWidget);

    // Verify finish fields
    expect(find.byKey(const ValueKey('architect-property-floorFinish-Laminate')), findsOneWidget);
    expect(find.byKey(const ValueKey('architect-property-wallFinish-Latex paint')), findsOneWidget);
    expect(find.byKey(const ValueKey('architect-property-ceilingFinish-Latex paint')), findsOneWidget);

    // Verify boundary auto switch
    expect(find.byKey(const ValueKey('architect-property-isAutoBoundary')), findsOneWidget);

    // Verify floating card is NOT used here
    expect(find.byType(ArchitectZonePropertiesCard), findsNothing);

    // Tap schedule table button
    await tester.tap(find.byKey(const ValueKey('architect-property-schedule-table')));
    await tester.pumpAndSettle();
    expect(scheduleOpened, isTrue);
  });
}
