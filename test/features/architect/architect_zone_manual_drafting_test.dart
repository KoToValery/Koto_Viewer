import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_zone_tool.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_polygon_geometry.dart';
import 'package:kotoview/src/features/architect/widgets/architect_zone_drafting_bar.dart';
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tool_ui;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('A crossing draft is retained and corrected when committed', () {
    final tool = ArchitectZoneTool();
    addTearDown(tool.dispose);
    const points = [Offset.zero, Offset(6, 4), Offset(0, 4), Offset(6, 0)];
    for (final point in points) {
      expect(tool.addDraftingPoint(point), isTrue);
    }
    expect(tool.hasDraftCrossings, isTrue);
    expect(tool.draftPoints, points);
    expect(tool.liveArea, 24);
    final zone = tool.commitDrafting(
      category: ArchitectZoneCategory.living,
      defaultName: 'Room',
    );
    expect(zone, isNotNull);
    expect(zone!.polygon, unorderedEquals(points));
    expect(zone.area, 24);
    expect(zone.isAutoBoundary, isFalse);
    expect(tool.isDrafting, isFalse);
  });

  test('Unrepairable contours retain the draft and support undoing points', () {
    final tool = ArchitectZoneTool();
    addTearDown(tool.dispose);
    const points = [
      Offset.zero,
      Offset(4, 0),
      Offset(2, 2),
      Offset(4, 4),
      Offset(0, 4),
      Offset(2, 2),
    ];
    for (final point in points) {
      tool.addDraftingPoint(point);
    }
    expect(
      tool.commitDrafting(
        category: ArchitectZoneCategory.living,
        defaultName: 'Room',
      ),
      isNull,
    );
    expect(tool.draftPoints, points);
    tool.undoDraftingPoint();
    expect(tool.draftPointCount, 5);
    expect(
      tool.commitDrafting(
        category: ArchitectZoneCategory.living,
        defaultName: 'Room',
      ),
      isNotNull,
    );
  });

  for (final locale in ['bg', 'en']) {
    testWidgets('Crossing controls fit a phone and remain usable in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tool = ArchitectZoneTool()
        ..placementMode = ArchitectZonePlacementMode.manualPoints;
      addTearDown(tool.dispose);
      for (final point in const [
        Offset.zero,
        Offset(6, 4),
        Offset(0, 4),
        Offset(6, 0),
      ]) {
        tool.addDraftingPoint(point);
      }
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ArchitectZoneDraftingBar(
                tool: tool,
                category: ArchitectZoneCategory.living,
                onClose: () => finished = true,
                onUndo: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          lookupAppLocalizations(
            Locale(locale),
          ).architectZoneCrossingRepairHint,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('zone-draft-close')));
      expect(finished, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Manual zones use the same point snaps and closure as slabs', (
    tester,
  ) async {
    const taps = [Offset.zero, Offset(6, 0), Offset(6, 4), Offset(.08, 4.1)];
    List<Offset>? slabBoundary;
    for (final manualZone in [false, true]) {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool_ui.choose(
        tester,
        manualZone ? Icons.space_dashboard_rounded : Icons.layers_rounded,
      );
      await tester.pumpAndSettle();
      await tool_ui.setMagnetic(tester, false);
      if (manualZone) {
        await tester.tap(
          find.text(
            lookupAppLocalizations(const Locale('en')).architectZoneModeManual,
          ),
        );
        await tester.pumpAndSettle();
      }
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-1, -1, 8, 6), padding: 180);
      await tester.pumpAndSettle();
      for (final point in taps) {
        await workspace.wallTap(tester, point);
      }
      final overlay = workspace.overlay(tester);
      expect(
        manualZone ? overlay.zoneDraftingPoints : overlay.slabDraftPoints,
        const [Offset.zero, Offset(6, 0), Offset(6, 4), Offset(0, 4)],
      );
      await workspace.wallTap(tester, const Offset(.04, .05));
      await tester.pumpAndSettle();
      if (!manualZone) {
        slabBoundary = model.project.activeStorey.slabs.single.polygon;
      } else {
        final zone = model.project.activeStorey.zones.single;
        expect(zone.polygon, slabBoundary);
        expect(zone.isAutoBoundary, isFalse);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'Crossings can be closed with the finish button and undone once',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool_ui.choose(tester, Icons.space_dashboard_rounded);
      await tester.pumpAndSettle();
      await tool_ui.setMagnetic(tester, false);
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l.architectZoneModeManual));
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-1, -1, 8, 6), padding: 180);
      await tester.pumpAndSettle();
      const points = [Offset.zero, Offset(6, 4), Offset(0, 4), Offset(6, 0)];
      for (final point in points) {
        await workspace.wallTap(tester, point);
      }
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).zoneDraftingPoints, points);
      expect(find.text(l.architectZoneCrossingRepairHint), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('zone-draft-close')));
      await tester.pumpAndSettle();
      final zone = model.project.activeStorey.zones.single;
      expect(zone.polygon, unorderedEquals(points));
      expect(zone.area, 24);
      expect(BimPolygonGeometry.valid(zone.polygon), isTrue);
      expect(model.undoCount, 1);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.zones, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
