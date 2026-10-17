import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'architect_dimension_chain_test.dart' as dimensions;
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Dimension "New point" (Нова точка) context menu & bar actions', () {
    testWidgets(
      'Radial menu on a selected dimension contains newPoint action and enters point addition mode',
      (tester) async {
        const wall = ArchitectWall(
          id: 'w1',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
          thickness: 0.25,
        );
        final dimension = ArchitectDimensionChain.build(
          id: 'dim1',
          style: ArchitectDimensionStyle.exterior,
          direction: const Offset(1, 0),
          offset: 1.0,
          anchors: const [
            ArchitectDimensionAnchor(point: Offset(0, 0)),
            ArchitectDimensionAnchor(point: Offset(4, 0)),
          ],
        );
        final storey = ArchitectStorey(
          id: 's1',
          name: 'Level 1',
          walls: const [wall],
          dimensions: [dimension],
        );
        final model = editing.seeded(storey);
        addTearDown(model.dispose);

        await workspace.open(tester, model);
        await tool_ui.prepare(tester, Icons.pan_tool_rounded);
        await tester.tap(find.byIcon(Icons.pan_tool_rounded));
        await tester.pumpAndSettle();

        // Select the dimension by tapping on it
        final dimCenter = (dimension.lineStart + dimension.lineEnd) / 2;
        await workspace.wallTap(tester, dimCenter);
        expect(workspace.overlay(tester).selectedElementIds, {'dim1'});

        // Long press to open radial menu
        final held = await tester.startGesture(workspace.screen(tester, dimCenter));
        await tester.pump(const Duration(milliseconds: 750));
        await held.up();
        await tester.pumpAndSettle();

        final menu = tester.widget<ArchitectRadialMenu>(
          find.byType(ArchitectRadialMenu),
        );
        expect(
          menu.items.map((i) => i.action),
          containsAllInOrder([
            ArchitectRadialAction.newPoint,
            ArchitectRadialAction.move,
            ArchitectRadialAction.properties,
            ArchitectRadialAction.delete,
          ]),
        );

        // Select newPoint action from radial menu
        menu.onActionSelected(ArchitectRadialAction.newPoint);
        await tester.pumpAndSettle();

        // Dimension new-point button in the dimension bar should be visible and active
        expect(find.byKey(const ValueKey('architect-dimension-new-point')), findsOneWidget);
        expect(dimensions.preview(tester), isNotNull);
      },
    );

    testWidgets(
      'Selection bar on a selected dimension contains new point button',
      (tester) async {
        const wall = ArchitectWall(
          id: 'w1',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
          thickness: 0.25,
        );
        final dimension = ArchitectDimensionChain.build(
          id: 'dim1',
          style: ArchitectDimensionStyle.exterior,
          direction: const Offset(1, 0),
          offset: 1.0,
          anchors: const [
            ArchitectDimensionAnchor(point: Offset(0, 0)),
            ArchitectDimensionAnchor(point: Offset(4, 0)),
          ],
        );
        final storey = ArchitectStorey(
          id: 's1',
          name: 'Level 1',
          walls: const [wall],
          dimensions: [dimension],
        );
        final model = editing.seeded(storey);
        addTearDown(model.dispose);

        await workspace.open(tester, model);
        await tool_ui.prepare(tester, Icons.pan_tool_rounded);
        await tester.tap(find.byIcon(Icons.pan_tool_rounded));
        await tester.pumpAndSettle();

        // Select the dimension
        final dimCenter = (dimension.lineStart + dimension.lineEnd) / 2;
        await workspace.wallTap(tester, dimCenter);
        expect(workspace.overlay(tester).selectedElementIds, {'dim1'});

        // Verify both new point and add walls buttons exist in selection bar
        expect(find.byKey(const ValueKey('architect-dimension-new-point')), findsOneWidget);
        expect(find.byKey(const ValueKey('architect-dimension-add-walls')), findsOneWidget);

        // Tapping new-point activates drafting preview
        await tester.tap(find.byKey(const ValueKey('architect-dimension-new-point')));
        await tester.pumpAndSettle();
        expect(dimensions.preview(tester), isNotNull);
      },
    );
  });

  group('Wall face snapping excluding axial lines', () {
    test('ArchitectSnapGeometry tags axial lines and computes wall face line intersections', () {
      // Two intersecting perpendicular walls: W1 horizontal (y=0, x from -2 to 2), W2 vertical (x=0, y from -2 to 2)
      const w1 = ArchitectWall(
        id: 'w1',
        startPoint: Offset(-2, 0),
        endPoint: Offset(2, 0),
        thickness: 0.30,
        insulationThicknessOverride: 0.10,
      );
      const w2 = ArchitectWall(
        id: 'w2',
        startPoint: Offset(0, -2),
        endPoint: Offset(0, 2),
        thickness: 0.30,
        insulationThicknessOverride: 0.10,
      );

      final storey = const ArchitectStorey(
        id: 's1',
        name: 'Floor',
        walls: [w1, w2],
      );
      final project = ArchitectProject(
        id: 'p1',
        name: 'Proj',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's1',
        storeys: [storey],
      );

      final snapGeom = ArchitectSnapGeometry.of(project);

      // Axial lines should be tagged with '@wall-axis:' (centerline + core centerline for exterior walls)
      final axialLines = snapGeom.edges.where((l) => l.owner.startsWith('@wall-axis:')).toList();
      expect(axialLines, hasLength(4));

      // Wall face joint intersections should exist with '@wall-face-joints'
      final faceJoints = snapGeom.alignmentPoints.where((p) => p.owner == '@wall-face-joints').toList();
      expect(faceJoints, isNotEmpty);
    });

    test('ArchitectSnapHelper with excludeWallAxes: true ignores wall centerline and snaps to face intersection', () {
      const w1 = ArchitectWall(
        id: 'w1',
        startPoint: Offset(-2, 0),
        endPoint: Offset(2, 0),
        thickness: 0.30,
      );
      const w2 = ArchitectWall(
        id: 'w2',
        startPoint: Offset(0, -2),
        endPoint: Offset(0, 2),
        thickness: 0.30,
      );

      final storey = const ArchitectStorey(
        id: 's1',
        name: 'Floor',
        walls: [w1, w2],
      );
      final project = ArchitectProject(
        id: 'p1',
        name: 'Proj',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's1',
        storeys: [storey],
      );

      // Outer finish intersection is at (0.15, 0.15)
      final faceSnap = ArchitectSnapHelper.snapFree(
        rawPoint: const Offset(0.152, 0.148),
        project: project,
        tolerance: 0.05,
        excludeWallAxes: true,
      );
      expect(faceSnap.isSnapped, isTrue);
      expect((faceSnap.point - const Offset(0.15, 0.15)).distance, lessThan(0.01));
      expect(faceSnap.snapLabel, anyOf('Intersection', 'Vertex'));

      // Axial snap at (0, 0) should NOT snap to wall-axis line when excludeWallAxes: true
      final axisSnap = ArchitectSnapHelper.snapFree(
        rawPoint: const Offset(0.01, 0.01),
        project: project,
        tolerance: 0.05,
        excludeWallAxes: true,
      );
      expect(axisSnap.magneticGuides.any((g) => (g.$1 - const Offset(-2, 0)).distance < 0.01), isFalse);
    });
  });

  group('Dynamic 30 cm and 40 cm drag snapping', () {
    testWidgets('Dragging dimension near 30 cm and 40 cm snaps with visual labels', (tester) async {
      // Create vertical wall at x=0, and horizontal dimension measuring along x
      const wall = ArchitectWall(
        id: 'w1',
        startPoint: Offset(0, 0),
        endPoint: Offset(0, 4),
        thickness: 0.20,
      );
      final storey = const ArchitectStorey(
        id: 's1',
        name: 'Floor',
        walls: [wall],
      );
      final model = editing.seeded(storey);
      addTearDown(model.dispose);

      await workspace.open(tester, model);

      // Select Dimension tool and switch to chain mode
      await editing.selectTool(tester, 'dimension');
      await tester.tap(find.byKey(const ValueKey('architect-dimension-chain')));
      await tester.pumpAndSettle();

      // Tap on wall to draft dimension
      await workspace.wallTap(tester, const Offset(0, 2));
      await tester.pumpAndSettle();

      // Tap place button to enter _dimensionPlacing mode
      await tester.tap(find.byKey(const ValueKey('architect-dimension-place')));
      await tester.pumpAndSettle();

      // Move mouse pointer near 30 cm offset along normal (Y axis) from baseline (y = 2.0)
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: workspace.screen(tester, const Offset(1.0, 2.0)));
      await gesture.moveTo(workspace.screen(tester, const Offset(1.0, 2.302)));
      await tester.pump();

      final overlay = workspace.overlay(tester);
      // Snap label should indicate 30 cm or 40 cm
      expect(
        overlay.activeSnapLabel,
        anyOf(contains('30 cm'), contains('30 см'), contains('40 cm'), contains('40 см')),
      );
      await gesture.removePointer();
    });

    test('Snap labels localize in Bulgarian and English', () {
      final bg = lookupAppLocalizations(const Locale('bg'));
      final en = lookupAppLocalizations(const Locale('en'));

      expect(bg.architectDimensionSnap30cm, '30 см');
      expect(bg.architectDimensionSnap40cm, '40 см');
      expect(bg.architectDimensionNewPoint, 'Нова точка');

      expect(en.architectDimensionSnap30cm, '30 cm');
      expect(en.architectDimensionSnap40cm, '40 cm');
      expect(en.architectDimensionNewPoint, 'New point');
    });
  });
}
