import 'architect_tool_test_helper.dart' as tool_ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [360.0, 1200.0]) {
    for (final language in ['bg', 'en']) {
      testWidgets(
        'One wall picker opens upward and restores selection at $width in $language',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          // A reordered catalog must still default to the insulated exterior.
          final catalog = ArchitectWallType.standardCatalog().reversed.toList();
          final commands = ArchitectCommandController(
            ArchitectProject(
              id: 'p',
              name: 'Plan',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              activeStoreyId: 's',
              storeys: [ArchitectStorey(id: 's', name: 'Floor')],
              wallTypes: catalog,
            ),
          );
          addTearDown(commands.dispose);
          final app = MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: commands),
          );
          await tester.pumpWidget(app);
          await tester.pumpAndSettle();
          await tool_ui.choose(tester, Icons.line_weight_rounded);
          await tester.pumpAndSettle();
          final picker = find.byKey(
            const ValueKey('architect-wall-type-picker'),
          );
          final l10n = AppLocalizations.of(tester.element(picker))!;
          expect(
            tester
                .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
                .activeWallType!
                .id,
            'ext_25_12_eps',
          );
          expect(find.text(l10n.architectWallSingle), findsOneWidget);
          expect(find.text(l10n.architectWallChained), findsOneWidget);
          expect(find.byType(ChoiceChip), findsNWidgets(3));
          expect(find.byKey(const ValueKey('architect-wall-arc-mode')), findsOneWidget);
          expect(find.text(l10n.architectWallThickness), findsNothing);

          final pickerTop = tester.getTopLeft(picker).dy;
          await tester.tap(picker);
          await tester.pumpAndSettle();
          for (final type in catalog) {
            final item = find.byKey(ValueKey('architect-wall-type-${type.id}'));
            expect(item, findsOneWidget);
            expect(
              tester.getBottomLeft(item).dy,
              lessThanOrEqualTo(pickerTop + 1),
            );
          }
          await tester.tap(
            find.byKey(
              const ValueKey('architect-wall-type-bearing_25_concrete'),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            workspace.overlay(tester).activeWallTypeId,
            'bearing_25_concrete',
          );
          expect(workspace.overlay(tester).activeWallThickness, .25);
          expect(
            (await SharedPreferences.getInstance()).getString(
              'architect_wall_type',
            ),
            'bearing_25_concrete',
          );
          // All types remain available, but only the selected one occupies the toolbar.
          expect(find.byType(PopupMenuItem<ArchitectWallType>), findsNothing);
          expect(find.byType(ChoiceChip), findsNWidgets(3));
          expect(find.byKey(const ValueKey('architect-wall-arc-mode')), findsOneWidget);
          expect(commands.canUndo, isFalse);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await tester.pumpWidget(app);
          await tester.pumpAndSettle();
          expect(
            workspace.overlay(tester).activeWallTypeId,
            'bearing_25_concrete',
          );
          expect(workspace.overlay(tester).activeWallThickness, .25);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('A missing saved wall type falls back to insulated exterior', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'architect_wall_type': 'removed-custom-wall',
    });
    final commands = workspace.commands();
    addTearDown(commands.dispose);
    await workspace.open(tester, commands);
    expect(workspace.overlay(tester).activeWallTypeId, 'ext_25_12_eps');
    expect(workspace.overlay(tester).activeWallInsulation, .12);
  });
}
