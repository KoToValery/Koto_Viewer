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
import 'architect_wall_compositions_test.dart' as data;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 360.0, 1200.0]) {
    for (final language in ['bg', 'en']) {
      testWidgets(
        'Categorized wall picker selects and restores a type at $width in $language',
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
          expect(
            find.byKey(const ValueKey('wall-drawing-mode')),
            findsOneWidget,
          );
          expect(find.byType(ChoiceChip), findsNothing);
          expect(find.text(l10n.architectWallThickness), findsNothing);

          await tester.tap(picker);
          await tester.pumpAndSettle();
          expect(find.text(l10n.wallCategoryExterior), findsOneWidget);
          expect(find.text(l10n.wallCategoryInterior), findsOneWidget);
          expect(find.text(l10n.wallCategoryParapet), findsOneWidget);
          expect(
            find.byKey(const ValueKey('architect-wall-type-parapet_12')),
            findsNothing,
          );
          await tester.tap(
            find.byKey(const ValueKey('wall-category-interior')),
          );
          await tester.pumpAndSettle();
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
          expect(find.byType(ChoiceChip), findsNothing);
          expect(
            find.byKey(const ValueKey('wall-drawing-mode')),
            findsOneWidget,
          );
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

  testWidgets(
    'Draft variant creation is independent, survives later additions and supports Undo',
    (tester) async {
      final model = ArchitectCommandController(
        data
            .project([data.wall('existing', Offset.zero, const Offset(4, 0))])
            .copyWith(
              wallTypes: ArchitectWallType.standardCatalog(),
              units: ArchitectUnit.centimeters,
            ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool_ui.choose(tester, Icons.line_weight_rounded);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-draft-layers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      expect(
        model.canUndo,
        isFalse,
        reason: 'An unchanged variant must not create a duplicate',
      );
      await tester.tap(find.byKey(const ValueKey('wall-draft-layers')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('wall-layer-thickness-insulation')),
        '15',
      );
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      final first = model.project.wallTypes.last;
      expect(first.totalThickness, closeTo(.40, 1e-10));
      expect(first.name, isEmpty);
      expect(
        model.project.activeStorey.walls.single.toJson(),
        data.wall('existing', Offset.zero, const Offset(4, 0)).toJson(),
      );
      expect(workspace.overlay(tester).activeWallTypeId, first.id);
      expect(model.undoCount, 1);
      await tester.tap(find.byKey(const ValueKey('wall-draft-layers')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('wall-layer-thickness-insulation')),
        '18',
      );
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      expect(model.project.wallTypes.any((t) => t.id == first.id), isTrue);
      expect(model.project.wallTypes.length, 7);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.wallTypes.length, 6);
      expect(model.project.wallTypes.last.id, first.id);
      expect(tester.takeException(), isNull);
    },
  );
}
