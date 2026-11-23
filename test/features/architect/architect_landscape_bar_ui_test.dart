import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_landscape_bar.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'architect_elevation_ui_test.dart' as qa;

ArchitectCommandController _controller() => ArchitectCommandController(
  ArchitectProject(
    id: 'p-landscape',
    name: 'Landscape UI Test',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    activeStoreyId: 's1',
    storeys: const [ArchitectStorey(id: 's1', name: 'Floor 1')],
  ),
);

BimWorkProject _bimProject() => BimWorkProject(
  id: 'bim-landscape',
  name: 'Landscape UI Test',
  projectType: BimProjectType.architectural,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ArchitectWorkspaceScreen(
        commandController: _controller(),
        bimProject: _bimProject(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openLandscapeCategory(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('architect-tool-category')));
  await tester.pumpAndSettle();
  final landscapeCat = find.byKey(
    const ValueKey('architect-category-landscape'),
  );
  expect(landscapeCat, findsOneWidget);
  await tester.ensureVisible(landscapeCat);
  await tester.tap(landscapeCat);
  await tester.pumpAndSettle();
  expect(find.byType(ArchitectLandscapeBar), findsOneWidget);
}

Future<void> _selectLandscapeTool(
  WidgetTester tester,
  ArchitectTool tool,
) async {
  final btn = find.byKey(ValueKey('architect-tool-${tool.name}'));
  expect(btn, findsOneWidget);
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pump();
}

Finder _chipFinder(String label) => find.ancestor(
  of: find.descendant(
    of: find.byType(ArchitectLandscapeBar),
    matching: find.text(label),
  ),
  matching: find.byType(ChoiceChip),
);

Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = _chipFinder(label);
  expect(chip, findsOneWidget, reason: 'Expected ChoiceChip "$label"');
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pump();
}

void _expectChipSelected(
  WidgetTester tester,
  String label, {
  required bool selected,
}) {
  final chipFinder = _chipFinder(label);
  expect(chipFinder, findsOneWidget, reason: 'Expected ChoiceChip "$label"');
  final chip = tester.widget<ChoiceChip>(chipFinder);
  expect(
    chip.selected,
    selected,
    reason: 'Expected ChoiceChip "$label" selected=$selected',
  );
}

Future<void> _selectPopupOption(
  WidgetTester tester,
  String popupKey,
  String itemText,
) async {
  final popup = find.byKey(ValueKey(popupKey));
  expect(popup, findsOneWidget);
  await tester.ensureVisible(popup);
  await tester.tap(popup);
  await tester.pumpAndSettle();
  final item = find.text(itemText).last;
  await tester.tap(item);
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ArchitectLandscapeBar)))!;

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in const [Locale('en'), Locale('bg')]) {
    testWidgets(
      'Streamlined Landscape bar controls & Contour Auto-trace / Spline modes work cleanly (${locale.languageCode})',
      (tester) async {
        await _pumpWorkspace(tester, locale: locale);
        await _openLandscapeCategory(tester);
        final l10n = _l10n(tester);

        // Verify removed clutter is absent from ArchitectLandscapeBar
        expect(
          find.byKey(const ValueKey('architect-terrain-sync-geodesy')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('architect-landscape-fillet')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('architect-landscape-chamfer')),
          findsNothing,
        );

        // 1. Contour tool (Хоризонтал): Auto-trace vs Manual Spline toggle,
        // and terrain-only controls (Existing/Proposed, ±0.00 datum, Create Proposed) are excluded.
        await _selectLandscapeTool(tester, ArchitectTool.contour);
        expect(
          find.byKey(const ValueKey('architect-terrain-datum')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('architect-terrain-create-proposed')),
          findsNothing,
        );
        expect(
          _chipFinder(ArchitectTerrainState.existing.label(l10n)),
          findsNothing,
        );
        expect(
          _chipFinder(ArchitectTerrainState.proposed.label(l10n)),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('architect-contour-elevation')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-terrain-contour-interval')),
          findsOneWidget,
        );
        expect(
          find.text('${l10n.architectTerrainContourIntervalShort}: 0.00 m'),
          findsOneWidget,
        );
        // Set Δh = 0.50 m directly via keypad dialog and verify step nudge buttons appear in elevation dialog
        final intervalChip = find.byKey(
          const ValueKey('architect-terrain-contour-interval'),
        );
        await tester.ensureVisible(intervalChip);
        await tester.tap(intervalChip);
        await tester.pumpAndSettle();
        for (final key in ['0', '.', '5']) {
          await tester.tap(find.byKey(ValueKey('bim-number-key-$key')));
          await tester.pump();
        }
        await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
        await tester.pumpAndSettle();
        expect(
          find.text('${l10n.architectTerrainContourIntervalShort}: 0.50 m'),
          findsOneWidget,
        );
        final contourElevChip = find.byKey(
          const ValueKey('architect-contour-elevation'),
        );
        await tester.ensureVisible(contourElevChip);
        await tester.tap(contourElevChip);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('bim-numeric-step-minus')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('bim-numeric-step-plus')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('bim-numeric-step-plus')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('architect-contour-major')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-contour-closed')),
          findsOneWidget,
        );
        final autoChip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('architect-contour-auto-trace')),
        );
        final manualChip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('architect-contour-manual-spline')),
        );
        expect(autoChip.selected, isTrue);
        expect(manualChip.selected, isFalse);

        final manualFinder = find.byKey(
          const ValueKey('architect-contour-manual-spline'),
        );
        await tester.ensureVisible(manualFinder);
        await tester.tap(manualFinder);
        await tester.pump();
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const ValueKey('architect-contour-auto-trace')),
              )
              .selected,
          isFalse,
        );
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const ValueKey('architect-contour-manual-spline')),
              )
              .selected,
          isTrue,
        );

        // 2. Vegetation: compact species popup + placement mode chips
        await _selectLandscapeTool(tester, ArchitectTool.vegetation);
        _expectChipSelected(
          tester,
          ArchitectVegetationPlacementMode.single.label(l10n),
          selected: true,
        );
        await _selectPopupOption(
          tester,
          'architect-vegetation-species',
          ArchitectPlantSpecies.trimmedHedge.label(l10n),
        );
        expect(
          _chipFinder(ArchitectVegetationPlacementMode.single.label(l10n)),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('architect-vegetation-hedge-width')),
          findsOneWidget,
        );

        await _selectPopupOption(
          tester,
          'architect-vegetation-species',
          ArchitectPlantSpecies.coniferPine.label(l10n),
        );
        await _tapChip(
          tester,
          ArchitectVegetationPlacementMode.row.label(l10n),
        );
        _expectChipSelected(
          tester,
          ArchitectVegetationPlacementMode.row.label(l10n),
          selected: true,
        );
        expect(
          find.byKey(const ValueKey('architect-vegetation-spacing')),
          findsOneWidget,
        );

        // 3. Site Fence: compact preset popup + height/thickness chips
        await _selectLandscapeTool(tester, ArchitectTool.siteFence);
        await _selectPopupOption(
          tester,
          'architect-fence-preset',
          ArchitectSiteFencePreset.rcRetaining.label(l10n),
        );
        expect(
          find.descendant(
            of: find.byType(ArchitectLandscapeBar),
            matching: find.text('${l10n.architectFenceHeight} 1.60 m'),
          ),
          findsOneWidget,
        );

        // 4. Pathway: compact material & curb popups + closed pad toggle
        await _selectLandscapeTool(tester, ArchitectTool.pathway);
        await _selectPopupOption(
          tester,
          'architect-pathway-curb',
          ArchitectPathwayCurbMode.none.label(l10n),
        );
        expect(
          find.byKey(const ValueKey('architect-pathway-curb-width')),
          findsNothing,
        );
        await _selectPopupOption(
          tester,
          'architect-pathway-material',
          ArchitectPavingMaterial.timberDecking.label(l10n),
        );
        await _tapChip(tester, l10n.architectPathwayClosedPad);
        _expectChipSelected(
          tester,
          l10n.architectPathwayClosedPad,
          selected: true,
        );

        // 5. Street: marking popup + sidewalk & closed toggles
        await _selectLandscapeTool(tester, ArchitectTool.street);
        await _selectPopupOption(
          tester,
          'architect-street-marking',
          ArchitectRoadMarkingStyle.solid.label(l10n),
        );
        await _tapChip(tester, l10n.architectStreetSidewalkLeft);
        _expectChipSelected(
          tester,
          l10n.architectStreetSidewalkLeft,
          selected: false,
        );

        // 6. Terrain: only draw-related commands (Existing/Proposed + Boundary/Rectangular) when drafting new terrain
        await _selectLandscapeTool(tester, ArchitectTool.terrain);
        _expectChipSelected(
          tester,
          ArchitectTerrainState.existing.label(l10n),
          selected: true,
        );
        await _tapChip(tester, ArchitectTerrainState.proposed.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectTerrainState.proposed.label(l10n),
          selected: true,
        );
        await _tapChip(
          tester,
          ArchitectTerrainDraftMode.boundaryRect.label(l10n),
        );
        _expectChipSelected(
          tester,
          ArchitectTerrainDraftMode.boundaryRect.label(l10n),
          selected: true,
        );
        expect(
          _chipFinder(ArchitectTerrainDraftMode.boundary.label(l10n)),
          findsOneWidget,
        );
        // Secondary object commands are hidden until an existing terrain object is selected
        for (final hiddenMode in const [
          ArchitectTerrainDraftMode.pad,
          ArchitectTerrainDraftMode.hole,
          ArchitectTerrainDraftMode.spot,
          ArchitectTerrainDraftMode.contour,
          ArchitectTerrainDraftMode.pickContour,
        ]) {
          expect(_chipFinder(hiddenMode.label(l10n)), findsNothing);
        }
        expect(
          find.byKey(const ValueKey('architect-terrain-datum')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('architect-terrain-create-proposed')),
          findsNothing,
        );

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Imperial project uses ft for contour interval Δh and converts to meters cleanly', (tester) async {
    final ctrl = ArchitectCommandController(
      ArchitectProject(
        id: 'p-imp',
        name: 'Imperial Terrain Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        units: BimDistanceUnit.inches,
        levelUnits: BimDistanceUnit.feet,
        activeStoreyId: 's1',
        storeys: const [ArchitectStorey(id: 's1', name: 'Floor 1')],
      ),
    );
    addTearDown(ctrl.dispose);

    tester.view.physicalSize = const Size(500, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(
          commandController: ctrl,
          bimProject: _bimProject(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openLandscapeCategory(tester);
    await _selectLandscapeTool(tester, ArchitectTool.contour);
    final l10n = _l10n(tester);

    expect(
      find.text('${l10n.architectTerrainContourIntervalShort}: 0.00 ft'),
      findsOneWidget,
    );
    final chip = find.byKey(const ValueKey('architect-terrain-contour-interval'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bim-number-key-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
    await tester.pumpAndSettle();

    expect(
      find.text('${l10n.architectTerrainContourIntervalShort}: 1.00 ft'),
      findsOneWidget,
    );
    // Stored internally in meters: 1 ft = 0.3048 m
    expect(ctrl.project.existingTerrain.contourInterval, closeTo(0.3048, 1e-4));
    expect(tester.takeException(), isNull);
  });
}
