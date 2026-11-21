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

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ArchitectLandscapeBar)))!;

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in const [Locale('en'), Locale('bg')]) {
    testWidgets(
      'Planting & all Landscape bar chips update highlight cleanly on sequential taps (${locale.languageCode})',
      (tester) async {
        await _pumpWorkspace(tester, locale: locale);
        await _openLandscapeCategory(tester);

        // 1. Planting (Vegetation): multiple species taps + mode toggle + hedge switch.
        await _selectLandscapeTool(tester, ArchitectTool.vegetation);
        final l10n = _l10n(tester);

        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.deciduousCanopy.label(l10n),
          selected: true,
        );
        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.coniferPine.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectVegetationPlacementMode.single.label(l10n),
          selected: true,
        );
        _expectChipSelected(
          tester,
          ArchitectVegetationPlacementMode.row.label(l10n),
          selected: false,
        );

        await _tapChip(tester, ArchitectPlantSpecies.coniferPine.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.deciduousCanopy.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.coniferPine.label(l10n),
          selected: true,
        );

        await _tapChip(
          tester,
          ArchitectPlantSpecies.columnarCypress.label(l10n),
        );
        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.coniferPine.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.columnarCypress.label(l10n),
          selected: true,
        );

        await _tapChip(tester, ArchitectPlantSpecies.trimmedHedge.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.columnarCypress.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.trimmedHedge.label(l10n),
          selected: true,
        );
        expect(
          _chipFinder(ArchitectVegetationPlacementMode.single.label(l10n)),
          findsNothing,
        );

        await _tapChip(
          tester,
          ArchitectPlantSpecies.deciduousMinimal.label(l10n),
        );
        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.trimmedHedge.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectPlantSpecies.deciduousMinimal.label(l10n),
          selected: true,
        );
        _expectChipSelected(
          tester,
          ArchitectVegetationPlacementMode.single.label(l10n),
          selected: true,
        );

        await _tapChip(
          tester,
          ArchitectVegetationPlacementMode.row.label(l10n),
        );
        _expectChipSelected(
          tester,
          ArchitectVegetationPlacementMode.single.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectVegetationPlacementMode.row.label(l10n),
          selected: true,
        );
        expect(
          find.descendant(
            of: find.byType(ArchitectLandscapeBar),
            matching: find.textContaining(l10n.architectVegetationRowSpacing),
          ),
          findsOneWidget,
        );

        // 2. Site Fence: multiple preset taps + height stepper increment.
        await _selectLandscapeTool(tester, ArchitectTool.siteFence);
        _expectChipSelected(
          tester,
          ArchitectSiteFencePreset.piersAndSlats.label(l10n),
          selected: true,
        );

        await _tapChip(
          tester,
          ArchitectSiteFencePreset.gabionFence.label(l10n),
        );
        _expectChipSelected(
          tester,
          ArchitectSiteFencePreset.piersAndSlats.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectSiteFencePreset.gabionFence.label(l10n),
          selected: true,
        );

        await _tapChip(tester, ArchitectSiteFencePreset.rcRetaining.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectSiteFencePreset.gabionFence.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectSiteFencePreset.rcRetaining.label(l10n),
          selected: true,
        );

        final plusButtons = find.descendant(
          of: find.byType(ArchitectLandscapeBar),
          matching: find.byIcon(Icons.add_rounded),
        );
        expect(
          find.descendant(
            of: find.byType(ArchitectLandscapeBar),
            matching: find.text('${l10n.architectFenceHeight} 1.60 m'),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(plusButtons.first);
        await tester.tap(plusButtons.first);
        await tester.pump();
        expect(
          find.descendant(
            of: find.byType(ArchitectLandscapeBar),
            matching: find.text('${l10n.architectFenceHeight} 1.70 m'),
          ),
          findsOneWidget,
        );

        // 3. Pathway: curb mode + paving material + closed pad toggle.
        await _selectLandscapeTool(tester, ArchitectTool.pathway);
        _expectChipSelected(
          tester,
          ArchitectPathwayCurbMode.both.label(l10n),
          selected: true,
        );
        _expectChipSelected(
          tester,
          ArchitectPavingMaterial.stoneSlabs.label(l10n),
          selected: true,
        );
        _expectChipSelected(tester, l10n.architectPathwayClosedPad, selected: false);

        await _tapChip(tester, ArchitectPathwayCurbMode.left.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectPathwayCurbMode.both.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectPathwayCurbMode.left.label(l10n),
          selected: true,
        );

        await _tapChip(tester, ArchitectPathwayCurbMode.none.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectPathwayCurbMode.left.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectPathwayCurbMode.none.label(l10n),
          selected: true,
        );

        await _tapChip(tester, ArchitectPavingMaterial.cobblePavers.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectPavingMaterial.stoneSlabs.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectPavingMaterial.cobblePavers.label(l10n),
          selected: true,
        );

        await _tapChip(tester, ArchitectPavingMaterial.timberDecking.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectPavingMaterial.cobblePavers.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectPavingMaterial.timberDecking.label(l10n),
          selected: true,
        );

        await _tapChip(tester, l10n.architectPathwayClosedPad);
        _expectChipSelected(tester, l10n.architectPathwayClosedPad, selected: true);

        // 4. Street: marking style + sidewalk & closed loop toggles.
        await _selectLandscapeTool(tester, ArchitectTool.street);
        _expectChipSelected(
          tester,
          ArchitectRoadMarkingStyle.dashed.label(l10n),
          selected: true,
        );
        _expectChipSelected(
          tester,
          l10n.architectStreetSidewalkLeft,
          selected: true,
        );
        _expectChipSelected(
          tester,
          l10n.architectStreetSidewalkRight,
          selected: true,
        );
        _expectChipSelected(tester, l10n.architectPathwayClosedPad, selected: false);

        await _tapChip(tester, ArchitectRoadMarkingStyle.solid.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectRoadMarkingStyle.dashed.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectRoadMarkingStyle.solid.label(l10n),
          selected: true,
        );

        await _tapChip(tester, ArchitectRoadMarkingStyle.none.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectRoadMarkingStyle.solid.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectRoadMarkingStyle.none.label(l10n),
          selected: true,
        );

        await _tapChip(tester, l10n.architectStreetSidewalkLeft);
        _expectChipSelected(
          tester,
          l10n.architectStreetSidewalkLeft,
          selected: false,
        );
        await _tapChip(tester, l10n.architectPathwayClosedPad);
        _expectChipSelected(tester, l10n.architectPathwayClosedPad, selected: true);

        // 5. Terrain: existing/proposed + modes + contour toggles.
        await _selectLandscapeTool(tester, ArchitectTool.terrain);
        _expectChipSelected(
          tester,
          ArchitectTerrainState.existing.label(l10n),
          selected: true,
        );
        _expectChipSelected(
          tester,
          ArchitectTerrainState.proposed.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectTerrainDraftMode.boundary.label(l10n),
          selected: true,
        );

        await _tapChip(tester, ArchitectTerrainState.proposed.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectTerrainState.existing.label(l10n),
          selected: false,
        );
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

        await _tapChip(
          tester,
          ArchitectTerrainDraftMode.pickContour.label(l10n),
        );
        _expectChipSelected(
          tester,
          ArchitectTerrainDraftMode.pickContour.label(l10n),
          selected: true,
        );

        await _tapChip(tester, ArchitectTerrainDraftMode.contour.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectTerrainDraftMode.pickContour.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectTerrainDraftMode.contour.label(l10n),
          selected: true,
        );
        await _tapChip(tester, l10n.architectTerrainContourMajor);
        _expectChipSelected(
          tester,
          l10n.architectTerrainContourMajor,
          selected: true,
        );
        await _tapChip(tester, l10n.architectTerrainContourClosed);
        _expectChipSelected(
          tester,
          l10n.architectTerrainContourClosed,
          selected: true,
        );

        await _tapChip(tester, ArchitectTerrainDraftMode.spot.label(l10n));
        _expectChipSelected(
          tester,
          ArchitectTerrainDraftMode.contour.label(l10n),
          selected: false,
        );
        _expectChipSelected(
          tester,
          ArchitectTerrainDraftMode.spot.label(l10n),
          selected: true,
        );

        expect(tester.takeException(), isNull);
      },
    );
  }
}
