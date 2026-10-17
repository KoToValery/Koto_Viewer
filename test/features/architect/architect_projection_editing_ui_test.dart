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

Future<void> enterNumber(WidgetTester tester, String value) async {
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('projection-number')),
    value,
  );
  await tester.tap(find.byKey(const ValueKey('projection-number-save')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'main facade edits actual opening and rejects a move through its neighbour',
    (tester) async {
      final source = ArchitectCommandController(fixture.elevationProject());
      addTearDown(source.dispose);
      await workspace.open(tester, source);
      await views.select(tester, 'elevation', fixture.facade.id);
      await workspace.wallTap(tester, const Offset(-2.4, -1.6));
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectElementPropertiesDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('architect-property-width')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
      await tester.pumpAndSettle();
      source.undo();
      await tester.pumpAndSettle();
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
      await workspace.wallTap(tester, const Offset(2.6, -1.6));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('projection-properties')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('projection-move-x')), findsNothing);
      final start = workspace.screen(tester, const Offset(2.6, -1.6));
      final scale = workspace.camera(tester).scale;
      final gesture = await tester.startGesture(start);
      await gesture.moveTo(start + Offset(0, -.15 * scale));
      await tester.pump();
      expect(source.canUndo, isFalse);
      await gesture.moveTo(start + Offset(0, -.25 * scale));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
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
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-facade-plan-toggle')),
        );
        await tester.pumpAndSettle();
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
        await tester.pumpAndSettle();
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
        await tester.pumpAndSettle();
        final editor = tester.widget<ArchitectProjectionEditor>(
          find.byType(ArchitectProjectionEditor),
        );
        final rect = tester.getRect(find.byType(ArchitectProjectionEditor));
        await tester.tapAt(
          rect.topLeft + editor.toScreen(const Offset(2.6, 1.6)),
        );
        await tester.pumpAndSettle();
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
