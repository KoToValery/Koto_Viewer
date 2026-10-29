import 'architect_projection_test_helper.dart' as projection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_elevations_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_projection_editor.dart';
import 'architect_elevation_test.dart' as fixture;
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_workspace_views_test.dart' as views;
import 'architect_projection_snap_test.dart' as roof_fixture;

Future<void> enterNumber(WidgetTester tester, String value) async {
  await projection.settleProjection(tester);
  final dialog = find.byType(Dialog).last;
  for (final key in value.replaceFirst('-', '').split('')) {
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.byKey(ValueKey('wall-key-$key')),
      ),
    );
    await tester.pump();
  }
  if (value.startsWith('-')) {
    await tester.tap(find.descendant(of: dialog, matching: find.text('±')));
    await tester.pump();
  }
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.byKey(const ValueKey('wall-end')),
    ),
  );
  await projection.settleProjection(tester);
}

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('workspace roof drag snaps the ridge with one undo entry', (
    tester,
  ) async {
    final source = ArchitectCommandController(
      roof_fixture.roofSnapProject().copyWith(
        sections: const [roof_fixture.roofSnapCut],
      ),
    );
    addTearDown(source.dispose);
    await workspace.open(tester, source);
    await views.select(tester, 'section', 'cut');
    final roof = source.project.activeStorey.roofs.last;
    final z = roof.undersideElevationAt(const Offset(6, 2)) + .1;
    // Section views reflect legacy station coordinates: 10 - 7 = 3.
    await workspace.wallTap(tester, Offset(3, -z));
    await projection.settleProjection(tester);
    expect(find.byKey(const ValueKey('projection-roof-snap')), findsOneWidget);
    final start = workspace.screen(tester, Offset(3, -z));
    final scale = workspace.camera(tester).scale;
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(start + Offset(0, .1 * scale));
    await tester.pump();
    await gesture.moveTo(start + Offset(0, .22 * scale));
    await tester.pump();
    expect(source.canUndo, isFalse);
    await gesture.up();
    await projection.settleProjection(tester);
    expect(source.undoCount, 1);
    expect(
      source.project.activeStorey.roofs.last.baseElevationOffset,
      closeTo(3, 1e-5),
    );
    source.undo();
    await projection.settleProjection(tester);
    expect(source.project.activeStorey.roofs.last.baseElevationOffset, 3.25);
    // The toggle is local UI state and never creates model history.
    await tester.tap(find.byKey(const ValueKey('projection-roof-snap')));
    await projection.settleProjection(tester);
    expect(source.canUndo, isFalse);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('projection-roof-snap')),
          )
          .isSelected,
      isFalse,
    );
    final canceled = await tester.startGesture(start);
    await canceled.moveTo(start + Offset(0, .3 * scale));
    await tester.pump();
    await canceled.cancel();
    await projection.settleProjection(tester);
    expect(source.canUndo, isFalse);
    expect(source.project.activeStorey.roofs.last.baseElevationOffset, 3.25);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'main facade edits actual opening and rejects a move through its neighbour',
    (tester) async {
      final source = ArchitectCommandController(fixture.elevationProject());
      addTearDown(source.dispose);
      await workspace.open(tester, source);
      await views.select(tester, 'elevation', fixture.facade.id);
      await workspace.wallTap(tester, const Offset(-2.4, -1.6));
      await projection.settleProjection(tester);
      expect(
        find.byKey(const ValueKey('projection-properties')),
        findsOneWidget,
      );
      for (final key in ['left', 'right', 'sill', 'head']) {
        expect(
          find.byKey(ValueKey('projection-distance-$key')),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('projection-distance-head')));
      await enterNumber(tester, '0.25');
      expect(
        source.project.storeys.first.walls.first.windows.first.sillHeight,
        closeTo(1.15, 1e-6),
      );
      expect(source.undoCount, 1);
      await tester.tap(find.byKey(const ValueKey('projection-move-x')));
      await enterNumber(tester, '2');
      expect(source.undoCount, 1);
      expect(
        source.project.storeys.first.walls.first.windows.first.offsetRatio,
        .2,
      );
      await tester.tap(find.byKey(const ValueKey('projection-properties')));
      await projection.settleProjection(tester);
      expect(find.byType(ArchitectElementPropertiesDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('architect-property-width')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
      await projection.settleProjection(tester);
      source.undo();
      await projection.settleProjection(tester);
      expect(
        source.project.storeys.first.walls.first.windows.first.sillHeight,
        .9,
      );
      expect(source.project.elevations.single.drawing.cadPrimitives, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'main section moves opening vertically and records one drag transaction',
    (tester) async {
      final source = ArchitectCommandController(
        fixture.elevationProject().copyWith(
          sections: const [
            ArchitectSection(
              id: 'cut',
              start: Offset(-1, 0),
              end: Offset(9, 0),
            ),
          ],
        ),
      );
      addTearDown(source.dispose);
      await workspace.open(tester, source);
      await views.select(tester, 'section', 'cut');
      await workspace.wallTap(tester, const Offset(7.4, -1.6));
      await projection.settleProjection(tester);
      expect(
        find.byKey(const ValueKey('projection-properties')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('projection-move-x')), findsNothing);
      final start = workspace.screen(tester, const Offset(7.4, -1.6));
      final scale = workspace.camera(tester).scale;
      final gesture = await tester.startGesture(start);
      await gesture.moveTo(start + Offset(0, -.15 * scale));
      await tester.pump();
      expect(source.canUndo, isFalse);
      await gesture.moveTo(start + Offset(0, -.25 * scale));
      await tester.pump();
      await gesture.up();
      await projection.settleProjection(tester);
      expect(source.undoCount, 1);
      expect(
        source.project.storeys.first.walls.first.windows.first.sillHeight,
        greaterThan(.9),
      );
      expect(
        source.project.storeys.first.walls.first.windows.first.offsetRatio,
        .2,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'phone section snaps roof edges and allows free movement ($locale)',
      (tester) async {
        await qa.phone(tester);
        final source = ArchitectCommandController(
          roof_fixture.roofSnapProject().copyWith(
            sections: const [roof_fixture.roofSnapCut],
          ),
        );
        addTearDown(source.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(
          qa.host(
            ArchitectBuildingSectionsScreen(controller: source),
            locale,
            capture,
          ),
        );
        await projection.settleProjection(tester);
        var editor = tester.widget<ArchitectProjectionEditor>(
          find.byType(ArchitectProjectionEditor),
        );
        final roof = source.project.activeStorey.roofs.last;
        final point = Offset(
          3,
          roof.undersideElevationAt(const Offset(6, 2)) + .1,
        );
        final viewer = tester.widget<InteractiveViewer>(
          find.ancestor(
            of: find.byKey(const ValueKey('building-section-view')),
            matching: find.byType(InteractiveViewer),
          ),
        );
        navigateArchitectProjection(
          viewer.transformationController!,
          Offset.zero,
          3,
          editor.toScreen(point),
        );
        await projection.settleProjection(tester);
        editor = tester.widget<ArchitectProjectionEditor>(
          find.byType(ArchitectProjectionEditor),
        );
        final origin = tester.getTopLeft(
          find.byType(ArchitectProjectionEditor),
        );
        await tester.tapAt(origin + editor.toScreen(point));
        await projection.settleProjection(tester);
        final snapButton = find.byKey(const ValueKey('projection-roof-snap'));
        expect(tester.widget<IconButton>(snapButton).isSelected, isTrue);
        expect(
          tester.widget<IconButton>(snapButton).tooltip,
          locale == 'bg' ? 'Прилепване (Snap): Включено' : 'Snap: Enabled',
        );
        for (final snapEnabled in [true, false]) {
          if (!snapEnabled) {
            await tester.tap(snapButton);
            await projection.settleProjection(tester);
          }
          editor = tester.widget<ArchitectProjectionEditor>(
            find.byType(ArchitectProjectionEditor),
          );
          final start = origin + editor.toScreen(point);
          final gesture = await tester.startGesture(start);
          await gesture.moveTo(start + Offset(0, .1 * editor.scale));
          await tester.pump();
          await gesture.moveTo(start + Offset(0, .22 * editor.scale));
          await tester.pump();
          expect(source.canUndo, isFalse);
          if (snapEnabled) {
            await qa.capturePhone(tester, capture, 'roof-edge-snap-$locale');
          }
          await gesture.up();
          await projection.settleProjection(tester);
          expect(source.undoCount, 1);
          expect(
            source.project.activeStorey.roofs.last.baseElevationOffset,
            closeTo(snapEnabled ? 3 : 3.03, 1e-5),
          );
          source.undo();
          await projection.settleProjection(tester);
        }
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'phone standalone facade exposes editable clearances ($locale)',
      (tester) async {
        await qa.phone(tester);
        final p = fixture.elevationProject();
        final source = ArchitectCommandController(
          p.copyWith(
            storeys: [
              p.storeys.first,
              p.storeys.last.copyWith(
                roofs: [
                  ArchitectRoofPlane(
                    id: 'left-roof',
                    storeyId: 's1',
                    eavesEdgeIndex: 3,
                    points: [
                      const Offset(-.5, -.5),
                      const Offset(4, -.5),
                      const Offset(4, 5.5),
                      const Offset(-.5, 5.5),
                    ],
                    slopeDegrees: 30,
                    eavesOverhang: .5,
                  ),
                  ArchitectRoofPlane(
                    id: 'right-roof',
                    storeyId: 's1',
                    eavesEdgeIndex: 1,
                    points: [
                      const Offset(4, -.5),
                      const Offset(8.5, -.5),
                      const Offset(8.5, 5.5),
                      const Offset(4, 5.5),
                    ],
                    slopeDegrees: 30,
                    eavesOverhang: .5,
                  ),
                ],
              ),
            ],
          ),
        );
        addTearDown(source.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(
          qa.host(
            ArchitectElevationsScreen(controller: source),
            locale,
            capture,
          ),
        );
        await projection.settleProjection(tester);
        await tester.tap(
          find.byKey(const ValueKey('architect-facade-plan-toggle')),
        );
        await projection.settleProjection(tester);
        await qa.capturePhone(
          tester,
          capture,
          'facade-operation-slopes-$locale',
        );
        final editor = tester.widget<ArchitectProjectionEditor>(
          find.byType(ArchitectProjectionEditor),
        );
        final rect = tester.getRect(find.byType(ArchitectProjectionEditor));
        await tester.tapAt(
          rect.topLeft + editor.toScreen(const Offset(-2.4, 1.6)),
        );
        await projection.settleProjection(tester);
        expect(
          find.byKey(const ValueKey('projection-distance-sill')),
          findsOneWidget,
        );
        await qa.capturePhone(tester, capture, 'editable-facade-$locale');
        await tester.tap(
          find.byKey(const ValueKey('projection-distance-sill')),
        );
        await enterNumber(tester, '1.0');
        expect(
          source.project.storeys.first.walls.first.windows.first.sillHeight,
          closeTo(1, 1e-6),
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'phone standalone section exposes native opening properties ($locale)',
      (tester) async {
        await qa.phone(tester);
        final source = ArchitectCommandController(
          fixture.elevationProject().copyWith(
            sections: const [
              ArchitectSection(
                id: 'cut',
                start: Offset(-1, 0),
                end: Offset(9, 0),
              ),
            ],
          ),
        );
        addTearDown(source.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(
          qa.host(
            ArchitectBuildingSectionsScreen(controller: source),
            locale,
            capture,
          ),
        );
        await projection.settleProjection(tester);
        final editor = tester.widget<ArchitectProjectionEditor>(
          find.byType(ArchitectProjectionEditor),
        );
        final rect = tester.getRect(find.byType(ArchitectProjectionEditor));
        await tester.tapAt(
          rect.topLeft + editor.toScreen(const Offset(7.4, 1.6)),
        );
        await projection.settleProjection(tester);
        expect(
          find.byKey(const ValueKey('projection-properties')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('projection-move-z')));
        await enterNumber(tester, '0.1');
        expect(
          source.project.storeys.first.walls.first.windows.first.sillHeight,
          closeTo(1, 1e-6),
        );
        await qa.capturePhone(tester, capture, 'editable-section-$locale');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
