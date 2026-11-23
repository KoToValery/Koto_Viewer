import 'dart:ui';

import 'package:flutter/material.dart' show FilledButton, Icons, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_landscape_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_selection_candidates.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  group('Dedicated Terrain / Site Plan (План Терен)', () {
    testWidgets('terrain properties move the contour to the other surface', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final starter = ArchitectProject.starterWithCatalog(
        name: 'Terrain classification',
        storeyCount: 1,
        groundHeight: 3,
        typicalHeight: 3,
      );
      const contour = ArchitectTerrainContour(
        id: 'classified-contour',
        points: [Offset(-4, 0), Offset(4, 0)],
        elevation: 2,
        rawAbsoluteElevation: 102,
      );
      final model = ArchitectCommandController(
        starter.copyWith(
          activeStoreyId: starter.siteStorey!.id,
          existingTerrain: const ArchitectTerrainSurface(
            datumElevation: 100,
            contours: [contour],
          ),
          proposedTerrain: const ArchitectTerrainSurface(
            datumElevation: 200,
            state: ArchitectTerrainState.proposed,
          ),
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.near_me_outlined);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-selection-properties')));
      await tester.pumpAndSettle();

      final l = lookupAppLocalizations(const Locale('en'));
      final dialog = find.byKey(const ValueKey('architect-terrain-properties'));
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(l.architectTerrainContourPropertiesTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-contour-prop-elevation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-contour-prop-major')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-contour-prop-closed')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('architect-contour-prop-elevation')),
      );
      await tester.pumpAndSettle();
      for (final key in ['1', '0', '5', '.', '5']) {
        await tester.tap(find.byKey(ValueKey('bim-number-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-contour-prop-major')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: dialog, matching: find.text(l.architectTerrainStateProposed)));
      await tester.pumpAndSettle();
      expect(model.project.existingTerrain.contours, hasLength(1));
      await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, l.applyAction)));
      await tester.pumpAndSettle();
      expect(model.project.existingTerrain.contours, isEmpty);
      final proposed = model.project.proposedTerrain;
      expect(proposed.contours.single.id, contour.id);
      expect(proposed.contours.single.isMajor, isTrue);
      // Moving between surfaces preserves relative elevation above the target datum (200 + 5.5 = 205.5).
      expect(proposed.contours.single.rawAbsoluteElevation, closeTo(205.5, 1e-4));
      expect(proposed.contours.single.points, contour.points);
      expect(proposed.contours.single.effectiveRelative(proposed.datumElevation), closeTo(5.5, 1e-4));

      // Deleting the selected contour removes it cleanly and supports undo
      await tester.tap(find.byKey(const ValueKey('architect-selection-delete')));
      await tester.pumpAndSettle();
      expect(model.project.proposedTerrain.contours, isEmpty);
      expect(model.project.existingTerrain.contours, isEmpty);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.proposedTerrain.contours.single.id, contour.id);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.proposedTerrain.contours, isEmpty);
      expect(model.project.existingTerrain.contours.single.id, contour.id);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deleting a selected terrain boundary removes it and supports undo', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final starter = ArchitectProject.starterWithCatalog(
        name: 'Terrain delete test',
        storeyCount: 1,
        groundHeight: 3,
        typicalHeight: 3,
      );
      const boundary = ArchitectTerrainBoundary(
        id: 'bnd-del',
        polygon: [
          Offset(-4, -4),
          Offset(4, -4),
          Offset(4, 4),
          Offset(-4, 4),
        ],
        autoInterpolateElevation: true,
      );
      final model = ArchitectCommandController(
        starter.copyWith(
          activeStoreyId: starter.siteStorey!.id,
          existingTerrain: const ArchitectTerrainSurface(
            boundaries: [boundary],
          ),
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.near_me_outlined);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(0, -4));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-selection-delete')));
      await tester.pumpAndSettle();
      expect(model.project.existingTerrain.boundaries, isEmpty);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.existingTerrain.boundaries.single.id, boundary.id);
      expect(tester.takeException(), isNull);
    });

    testWidgets('freehand terrain drafting snaps to first point and closes boundary', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final starter = ArchitectProject.starterWithCatalog(
        name: 'Terrain snap start test',
        storeyCount: 1,
        groundHeight: 3,
        typicalHeight: 3,
      );
      final model = ArchitectCommandController(
        starter.copyWith(activeStoreyId: starter.siteStorey!.id),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);

      await tester.tap(find.byKey(const ValueKey('architect-tool-category')));
      await tester.pumpAndSettle();
      final landscapeCat = find.byKey(
        const ValueKey('architect-category-landscape'),
      );
      await tester.ensureVisible(landscapeCat);
      await tester.tap(landscapeCat);
      await tester.pumpAndSettle();

      await workspace.wallTap(tester, const Offset(1, 1));
      await workspace.wallTap(tester, const Offset(5, 1));
      await workspace.wallTap(tester, const Offset(5, 5));
      expect(model.project.existingTerrain.boundaries, isEmpty);

      // Tap near the first point (1, 1) -> snaps to first point and closes the boundary!
      await workspace.wallTap(tester, const Offset(1.15, 1.12));
      await tester.pumpAndSettle();

      expect(model.project.existingTerrain.boundaries, hasLength(1));
      expect(model.project.existingTerrain.boundaries.single.polygon, hasLength(3));
      expect(tester.takeException(), isNull);
    });

    test(
      'starter factories and ensureSiteStorey create storey_site automatically and protect it from floor math/deletion',
      () {
        final starter = ArchitectProject.starterWithCatalog(
          name: 'Site Project',
          storeyCount: 2,
          groundHeight: 3.0,
          typicalHeight: 2.8,
        );

        expect(starter.siteStorey, isNotNull);
        expect(starter.siteStorey!.isSite, isTrue);
        expect(starter.siteStorey!.isBuildingStorey, isFalse);
        expect(starter.orderedPlanStoreys.first.id, starter.roofStorey!.id);
        expect(starter.orderedPlanStoreys.last.id, starter.siteStorey!.id);
        expect(starter.highestWallStorey!.isBuildingStorey, isTrue);

        // Adding a storey above ignores siteStorey elevation/order and preserves it at the bottom.
        final withThird = starter.addStoreyAbove(height: 2.8);
        expect(withThird.orderedPlanStoreys.last.id, starter.siteStorey!.id);
        expect(withThird.roofStorey!.elevation, closeTo(8.6, 1e-4));

        // Deleting storey_site is disallowed.
        final afterDeleteAttempt = withThird.deleteStorey(starter.siteStorey!.id);
        expect(afterDeleteAttempt.siteStorey, isNotNull);
      },
    );

    test(
      'terrain contours and boundaries are hidden and non-selectable on ±0.00, underground levels, and roof plan',
      () {
        final basement = const ArchitectStorey(
          id: 'basement',
          name: '-2.80',
          elevation: -2.80,
          height: 2.80,
        );
        final ground = ArchitectStorey(
          id: 'ground',
          name: '±0.00',
          elevation: 0.0,
          height: 3.0,
          walls: const [
            ArchitectWall(
              id: 'w1',
              startPoint: Offset(0, 0),
              endPoint: Offset(6, 0),
              thickness: 0.25,
            ),
            ArchitectWall(
              id: 'w2',
              startPoint: Offset(6, 0),
              endPoint: Offset(6, 4),
              thickness: 0.25,
            ),
            ArchitectWall(
              id: 'w3',
              startPoint: Offset(6, 4),
              endPoint: Offset(0, 4),
              thickness: 0.25,
            ),
            ArchitectWall(
              id: 'w4',
              startPoint: Offset(0, 4),
              endPoint: Offset(0, 0),
              thickness: 0.25,
            ),
          ],
        );

        final project = ArchitectProject(
          id: 'p_vis',
          name: 'Visibility Test',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          storeys: [basement, ground],
          activeStoreyId: 'ground',
          proposedTerrain: const ArchitectTerrainSurface(
            state: ArchitectTerrainState.proposed,
            contours: [
              ArchitectTerrainContour(
                id: 'cnt_1',
                points: [Offset(-4, 2), Offset(10, 2)],
                elevation: 0.5,
              ),
            ],
            boundaries: [
              ArchitectTerrainBoundary(
                id: 'bnd_1',
                polygon: [
                  Offset(-5, -5),
                  Offset(12, -5),
                  Offset(12, 10),
                  Offset(-5, 10),
                ],
                elevation: 0.0,
              ),
            ],
          ),
        ).ensureRoofStorey().ensureSiteStorey();

        final l = lookupAppLocalizations(const Locale('bg'));

        // On ±0.00, underground (-2.80), and Roof: no contour text / no hit test / no terrain candidate tools.
        for (final storeyId in [
          'ground',
          'basement',
          project.roofStorey!.id,
        ]) {
          final scoped = project.copyWith(activeStoreyId: storeyId);
          expect(
            ArchitectLandscapeTool.hitTestLandscapeElement(
              project: scoped,
              storey: scoped.activeStorey,
              worldPoint: const Offset(3, 2),
              hitTolerance: 0.5,
            ),
            isNull,
          );
          expect(
            ArchitectSelectionCandidates.tools(scoped).containsKey('cnt_1'),
            isFalse,
          );
          final scene = ArchitectDrawingPublisher.build(
            scoped,
            ArchitectSavedDrawing(
              id: 'plan:$storeyId',
              sourceId: storeyId,
              kind: ArchitectDrawingKind.plan,
              roof: storeyId == project.roofStorey!.id,
            ),
            100,
            l,
          );
          final siteTexts = scene.operations
              .whereType<ArchitectVectorText>()
              .where((t) => t.sources.contains('cnt_1'));
          expect(siteTexts, isEmpty);
        }

        // On storey_site: contour is hit-tested, listed in selection tools, and rendered.
        final onSite = project.copyWith(activeStoreyId: project.siteStorey!.id);
        expect(
          ArchitectLandscapeTool.hitTestLandscapeElement(
            project: onSite,
            storey: onSite.activeStorey,
            worldPoint: const Offset(3, 2),
            hitTolerance: 0.5,
          ),
          'cnt_1',
        );
        expect(
          ArchitectSelectionCandidates.tools(onSite).containsKey('cnt_1'),
          isTrue,
        );
        final siteScene = ArchitectDrawingPublisher.build(
          onSite,
          ArchitectSavedDrawing(
            id: 'plan:${onSite.siteStorey!.id}',
            sourceId: onSite.siteStorey!.id,
            kind: ArchitectDrawingKind.plan,
            sitePlan: true,
          ),
          200,
          l,
        );
        final siteTexts = siteScene.operations
            .whereType<ArchitectVectorText>()
            .where((t) => t.sources.contains('cnt_1'));
        expect(siteTexts, isNotEmpty);
      },
    );

    test(
      'site plan renders exterior building outline, exterior door entrance marker, and dashed erker/balcony without roof lines',
      () {
        const entranceDoor = ArchitectDoor(
          id: 'door_ent_1',
          wallId: 'w_south',
          offsetRatio: 0.5,
          width: 1.0,
          uuid: 'u_door_1',
        );
        final basement = const ArchitectStorey(
          id: 'basement',
          name: '-2.80',
          elevation: -2.80,
          height: 2.80,
          walls: [
            ArchitectWall(
              id: 'bw1',
              startPoint: Offset(-1, -1),
              endPoint: Offset(7, -1),
              thickness: 0.25,
            ),
          ],
        );
        final ground = ArchitectStorey(
          id: 'ground',
          name: '±0.00',
          elevation: 0.0,
          height: 3.0,
          walls: [
            ArchitectWall(
              id: 'w_south',
              startPoint: const Offset(0, 0),
              endPoint: const Offset(6, 0),
              thickness: 0.25,
              doors: const [entranceDoor],
            ),
            const ArchitectWall(
              id: 'w_east',
              startPoint: Offset(6, 0),
              endPoint: Offset(6, 4),
              thickness: 0.25,
            ),
            const ArchitectWall(
              id: 'w_north',
              startPoint: Offset(6, 4),
              endPoint: Offset(0, 4),
              thickness: 0.25,
            ),
            const ArchitectWall(
              id: 'w_west',
              startPoint: Offset(0, 4),
              endPoint: Offset(0, 0),
              thickness: 0.25,
            ),
          ],
        );
        final upper = ArchitectStorey(
          id: 'upper',
          name: '+3.00',
          elevation: 3.0,
          height: 2.80,
          zones: [
            ArchitectZone(
              id: 'z_balcony',
              name: 'Балкон',
              category: ArchitectZoneCategory.terrace,
              polygon: const [
                Offset(1, 4),
                Offset(5, 4),
                Offset(5, 5.5),
                Offset(1, 5.5),
              ],
            ),
          ],
        );
        final roofStorey = ArchitectStorey(
          id: 'storey_roof',
          name: 'Покривни линии',
          elevation: 5.80,
          isRoof: true,
          roofs: [
            ArchitectRoofPlane(
              id: 'roof_1',
              storeyId: 'storey_roof',
              points: const [
                Offset(-0.6, -0.6),
                Offset(6.6, -0.6),
                Offset(6.6, 4.6),
                Offset(-0.6, 4.6),
              ],
              eavesOverhang: 0.6,
            ),
          ],
        );

        final project = ArchitectProject(
          id: 'p_underlay',
          name: 'Site Underlay',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          storeys: [basement, ground, upper, roofStorey],
          activeStoreyId: 'ground',
        ).ensureSiteStorey();

        final onSite = project.copyWith(activeStoreyId: project.siteStorey!.id);
        final l = lookupAppLocalizations(const Locale('bg'));
        final drawing = ArchitectSavedDrawing(
          id: 'plan:${onSite.siteStorey!.id}',
          sourceId: onSite.siteStorey!.id,
          kind: ArchitectDrawingKind.plan,
          sitePlan: true,
          scale: 200,
        );

        final scene = ArchitectDrawingPublisher.build(onSite, drawing, 200, l);
        final paths = scene.operations.whereType<ArchitectVectorPath>().toList();

        // 1. Exterior ground building outline is drawn (not basement wall bw1).
        final outlines = paths
            .where((op) => op.role == 'siteBuildingOutline')
            .toList();
        expect(outlines, isNotEmpty);
        expect(outlines.first.sources.contains('w_south'), isTrue);
        expect(outlines.first.sources.contains('bw1'), isFalse);

        // 2. Entrance door on exterior wall is marked.
        final entrances = paths
            .where((op) => op.role == 'siteEntrance')
            .toList();
        expect(entrances, isNotEmpty);
        expect(entrances.first.sources, contains('door_ent_1'));

        // 3. Upper balcony / erker overhang is drawn with dashed overhang role.
        final overhangs = paths.where((op) => op.role == 'overhang').toList();
        expect(overhangs, isNotEmpty);

        // 4. Roof lines and roof overhead are NOT drawn on the site plan.
        expect(
          paths.where((op) => op.role == 'roofOverhead' || op.sources.contains('roof_1')),
          isEmpty,
        );

        // 5. Snap geometry on site plan exposes ground building walls & corners.
        final snap = ArchitectSnapGeometry.of(onSite);
        final nearbyCorner = snap.query(const Offset(0, 0), 0.3);
        expect(nearbyCorner, isNotEmpty);

        // 6. Saved drawing serialization & localized sheet drawing title.
        final restored = ArchitectSavedDrawing.fromJson(drawing.toJson());
        expect(restored.sitePlan, isTrue);
        expect(restored.scale, 200);
        expect(ArchitectSheetLayout.drawingName(restored, l), l.architectSitePlan);
      },
    );
  });
}
