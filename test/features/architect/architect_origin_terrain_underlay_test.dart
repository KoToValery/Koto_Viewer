import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_landscape_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_terrain_move_overlay.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_underlay_bar.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_viewport_controller.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_workspace_interaction_test.dart' as workspace;

DxfDocument _cadDoc() => DxfDocument(
  entities: [
    DxfLine(layer: '0', p1: Offset.zero, p2: const Offset(10, 0)),
    DxfLine(layer: '0', p1: const Offset(10, 0), p2: const Offset(10, 8)),
    DxfLine(layer: '0', p1: const Offset(10, 8), p2: const Offset(0, 8)),
    DxfLine(layer: '0', p1: const Offset(0, 8), p2: Offset.zero),
  ],
  layers: {'0': DxfLayer(name: '0')},
  blocks: const {},
  bounds: const Rect.fromLTWH(0, 0, 10, 8),
  entityStats: const {},
  headerVars: const {},
);

ArchitectProject _siteTerrainProject() {
  final starter = ArchitectProject.starterWithCatalog(
    name: 'Site Terrain Test',
    storeyCount: 1,
  );
  final siteId = starter.siteStorey!.id;
  return starter.copyWith(
    activeStoreyId: siteId,
    existingTerrain: ArchitectTerrainSurface(
      state: ArchitectTerrainState.existing,
      boundaries: const [
        ArchitectTerrainBoundary(
          id: 'bnd_main',
          polygon: [
            Offset(0, 0),
            Offset(10, 0),
            Offset(10, 10),
            Offset(0, 10),
          ],
          autoInterpolateElevation: true,
        ),
        ArchitectTerrainBoundary(
          id: 'pad_main',
          polygon: [
            Offset(2, 2),
            Offset(4, 2),
            Offset(4, 4),
            Offset(2, 4),
          ],
          elevation: 1.5,
          isFlatPad: true,
          hostBoundaryId: 'bnd_main',
        ),
        ArchitectTerrainBoundary(
          id: 'hole_main',
          polygon: [
            Offset(6, 6),
            Offset(8, 6),
            Offset(8, 8),
            Offset(6, 8),
          ],
          isHole: true,
          hostBoundaryId: 'bnd_main',
        ),
      ],
      contours: const [
        ArchitectTerrainContour(
          id: 'cnt_main',
          points: [Offset(1, 5), Offset(5, 5), Offset(9, 5)],
          elevation: 1.0,
          isSpline: true,
          hostBoundaryId: 'bnd_main',
        ),
        ArchitectTerrainContour(
          id: 'cnt_legacy',
          points: [Offset(1, 7), Offset(9, 7)],
          elevation: 2.0,
        ),
      ],
      spots: const [
        ArchitectTerrainSpot(
          id: 'spot_main',
          position: Offset(3, 8),
          elevation: 2.5,
          hostBoundaryId: 'bnd_main',
        ),
      ],
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Workspace origin X marker', () {
    test('defaults paintOrigin=false for publication and paints origin at (0,0) when enabled', () {
      final project = ArchitectProject.starterWithCatalog(name: 'Origin', storeyCount: 1);
      final vp = BimViewportController();

      final defaultPainter = Architect2dPainter(
        project: project,
        viewport: vp,
        paintGrid: false,
        activeTool: ArchitectTool.pan,
      );
      expect(defaultPainter.paintOrigin, isFalse);

      final originPainter = Architect2dPainter(
        project: project,
        viewport: vp,
        paintGrid: false,
        paintOrigin: true,
        activeTool: ArchitectTool.pan,
      );
      expect(originPainter.paintOrigin, isTrue);

      final rec = ui.PictureRecorder();
      originPainter.paint(Canvas(rec), const Size(400, 300));
      rec.endRecording().dispose();
    });

    testWidgets('live ArchitectWorkspaceScreen enables paintOrigin on model layer', (tester) async {
      final starter = ArchitectProject.starterWithCatalog(name: 'Live Origin', storeyCount: 1);
      final model = ArchitectCommandController(starter);
      addTearDown(model.dispose);

      await workspace.open(tester, model);

      final modelPainter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<Architect2dPainter>()
          .firstWhere((p) => p.layer == ArchitectPaintLayer.model);
      expect(modelPainter.paintOrigin, isTrue);
    });
  });

  group('Underlay separation between Site Plan and Floor Plans', () {
    test('legacy geodetic CAD JSON defaults shareToGroundStoreys to false while explicit true round-trips', () {
      final legacyGeo = ArchitectCadUnderlayConfig.fromJson({
        'storeyId': 'site',
        'fileName': 'geodesy.dwg',
        'internalCopyPath': 'underlays/geo.dwg',
        'isGeodetic': true,
      });
      expect(legacyGeo.kind, ArchitectUnderlayKind.geodetic);
      expect(legacyGeo.shareToGroundStoreys, isFalse);

      final explicitShared = legacyGeo.copyWith(shareToGroundStoreys: true);
      final decodedShared = ArchitectCadUnderlayConfig.fromJson(explicitShared.toJson());
      expect(decodedShared.shareToGroundStoreys, isTrue);
    });

    testWidgets('showArchitectUnderlayContextMenu includes Add for floor-plan CAD underlays', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showArchitectUnderlayContextMenu(
                  context: ctx,
                  globalPosition: const Offset(100, 100),
                  isCad: true,
                  visible: true,
                  isSitePlan: false,
                ),
                child: const Text('Menu'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets(
      'floor plan Underlay bar stays ready to add technical underlays even when Site Plan has a shared geodetic underlay',
      (tester) async {
        final starter = ArchitectProject.starterWithCatalog(
          name: 'Floor Technical Add',
          storeyCount: 1,
        );
        final siteId = starter.siteStorey!.id;
        final groundId = starter.storeys.firstWhere((s) => s.isBuildingStorey).id;
        final project = starter.copyWith(
          activeStoreyId: groundId,
          cadUnderlays: {
            siteId: ArchitectCadUnderlayConfig(
              id: 'geo_site',
              storeyId: siteId,
              fileName: 'geodesy_site.dwg',
              internalCopyPath: '',
              kind: ArchitectUnderlayKind.geodetic,
              isGeodetic: true,
              shareToGroundStoreys: true,
            ),
          },
        );
        final model = ArchitectCommandController(project);
        addTearDown(model.dispose);

        await workspace.open(tester, model, underlays: {siteId: _cadDoc()});

        // Switch palette to Underlays -> selects cadUnderlay tool
        final palette = tester.widget<ArchitectToolPalette>(
          find.byType(ArchitectToolPalette),
        );
        palette.onToolChanged(ArchitectTool.cadUnderlay);
        await tester.pumpAndSettle();

        final bar = tester.widget<ArchitectCadUnderlayBar>(
          find.byType(ArchitectCadUnderlayBar),
        );
        expect(bar.config, isNull);
        expect(bar.underlays, isEmpty);
        expect(bar.isSitePlan, isFalse);
        expect(find.text('geodesy_site.dwg'), findsNothing);
        expect(find.text('Add'), findsOneWidget);
      },
    );
  });

  group('Terrain-linked contours, spots, pads & holes', () {
    test('MoveArchitectElement and MoveArchitectElements move linked contours, spots, pads, and holes once', () {
      var project = _siteTerrainProject();
      final siteId = project.siteStorey!.id;

      // Add a second separate terrain parcel that must NOT move when moving bnd_main.
      project = project.copyWith(
        existingTerrain: project.existingTerrain.copyWith(
          boundaries: [
            ...project.existingTerrain.boundaries,
            const ArchitectTerrainBoundary(
              id: 'bnd_other',
              polygon: [
                Offset(50, 50),
                Offset(60, 50),
                Offset(60, 60),
                Offset(50, 60),
              ],
            ),
          ],
          contours: [
            ...project.existingTerrain.contours,
            const ArchitectTerrainContour(
              id: 'cnt_other',
              points: [Offset(51, 55), Offset(59, 55)],
              elevation: 3.0,
              hostBoundaryId: 'bnd_other',
            ),
          ],
        ),
      );

      const delta = Offset(4, -3);

      // Selecting BOTH bnd_main and cnt_main must move each item once (not 2*delta!).
      final movedBoth = MoveArchitectElements(
        storeyId: siteId,
        elementIds: const {'bnd_main', 'cnt_main'},
        delta: delta,
      ).apply(project);

      final ex = movedBoth.existingTerrain;
      expect(ex.boundaries.firstWhere((b) => b.id == 'bnd_main').polygon.first, delta);
      expect(ex.boundaries.firstWhere((b) => b.id == 'pad_main').polygon.first, const Offset(2, 2) + delta);
      expect(ex.boundaries.firstWhere((b) => b.id == 'hole_main').polygon.first, const Offset(6, 6) + delta);
      expect(ex.contours.firstWhere((c) => c.id == 'cnt_main').points.first, const Offset(1, 5) + delta);
      expect(ex.contours.firstWhere((c) => c.id == 'cnt_legacy').points.first, const Offset(1, 7) + delta);
      expect(ex.spots.firstWhere((s) => s.id == 'spot_main').position, const Offset(3, 8) + delta);

      // Other parcel stays put!
      expect(ex.boundaries.firstWhere((b) => b.id == 'bnd_other').polygon.first, const Offset(50, 50));
      expect(ex.contours.firstWhere((c) => c.id == 'cnt_other').points.first, const Offset(51, 55));

      // Moving ONLY a single contour leaves the outer boundary untouched.
      final movedContourOnly = MoveArchitectElement(
        storeyId: siteId,
        elementId: 'cnt_main',
        delta: const Offset(1, 2),
      ).apply(project);
      expect(
        movedContourOnly.existingTerrain.boundaries
            .firstWhere((b) => b.id == 'bnd_main')
            .polygon
            .first,
        Offset.zero,
      );
      expect(
        movedContourOnly.existingTerrain.contours
            .firstWhere((c) => c.id == 'cnt_main')
            .points
            .first,
        const Offset(2, 7),
      );
    });

    test('adoptingUnlinkedMembersFor, cloneAsProposed, and changeTerrainState preserve contour links', () {
      const preSurface = ArchitectTerrainSurface(
        contours: [
          ArchitectTerrainContour(
            id: 'cnt_pre',
            points: [Offset(2, 2), Offset(8, 2)],
            elevation: 1.0,
          ),
        ],
        spots: [
          ArchitectTerrainSpot(
            id: 'sp_pre',
            position: Offset(5, 5),
            elevation: 1.5,
          ),
        ],
      );
      const outer = ArchitectTerrainBoundary(
        id: 'bnd_new',
        polygon: [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
      );
      final adopted = preSurface
          .copyWith(boundaries: [outer])
          .adoptingUnlinkedMembersFor(outer);
      expect(adopted.contours.single.hostBoundaryId, 'bnd_new');
      expect(adopted.spots.single.hostBoundaryId, 'bnd_new');

      final proposed = adopted.cloneAsProposed();
      final propBndId = proposed.boundaries.single.id;
      expect(proposed.contours.single.hostBoundaryId, propBndId);
      expect(proposed.spots.single.hostBoundaryId, propBndId);

      // JSON round-trip preserves hostBoundaryId.
      final decoded = ArchitectTerrainSurface.fromJson(proposed.toJson());
      expect(decoded.contours.single.hostBoundaryId, propBndId);
      expect(decoded.spots.single.hostBoundaryId, propBndId);

      // changeTerrainState migrates boundary + linked contours/spots together.
      final base = ArchitectProject.starterWithCatalog(name: 'State', storeyCount: 1)
          .copyWith(existingTerrain: adopted);
      final switched = ArchitectLandscapeTool.changeTerrainState(
        base,
        'bnd_new',
        ArchitectTerrainState.proposed,
      );
      expect(switched, isNotNull);
      expect(switched!.project.existingTerrain.isEmpty, isTrue);
      expect(switched.project.proposedTerrain.boundaries, hasLength(1));
      expect(switched.project.proposedTerrain.contours, hasLength(1));
      expect(switched.project.proposedTerrain.spots, hasLength(1));
    });

    test('deleteSelected deletes outer terrain together with linked contours, spots, pads, and holes', () {
      final project = _siteTerrainProject();

      // Deleting an individual contour keeps the outer boundary and other members intact.
      final afterSingleContourDelete = ArchitectLandscapeTool.deleteSelected(
        project: project,
        selectedIds: const {'cnt_main'},
      );
      expect(
        afterSingleContourDelete.existingTerrain.boundaries
            .any((b) => b.id == 'bnd_main'),
        isTrue,
      );
      expect(
        afterSingleContourDelete.existingTerrain.contours
            .any((c) => c.id == 'cnt_main'),
        isFalse,
      );
      expect(
        afterSingleContourDelete.existingTerrain.spots
            .any((s) => s.id == 'spot_main'),
        isTrue,
      );

      // Deleting the outer boundary removes the boundary + all linked contours, spots, pads & holes.
      final afterBoundaryDelete = ArchitectLandscapeTool.deleteSelected(
        project: project,
        selectedIds: const {'bnd_main'},
      );
      expect(afterBoundaryDelete.existingTerrain.boundaries, isEmpty);
      expect(afterBoundaryDelete.existingTerrain.contours, isEmpty);
      expect(afterBoundaryDelete.existingTerrain.spots, isEmpty);
    });
  });

  group('Terrain center free-move handle and 2-point Drag', () {
    testWidgets('selecting terrain shows center move badge and dragging it moves terrain + linked contours in one commit', (tester) async {
      final project = _siteTerrainProject();
      final model = ArchitectCommandController(project);
      addTearDown(model.dispose);

      await workspace.open(tester, model);

      // Select terrain boundary on its edge (0, 5)
      await tester.tapAt(workspace.screen(tester, const Offset(0, 5)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('architect-terrain-move-handle')), findsOneWidget);
      expect(find.byType(ArchitectTerrainMoveOverlay), findsOneWidget);

      // Drag center handle from (5, 5) to (9, 7) -> delta (+4, +2)
      final startScreen = workspace.screen(tester, const Offset(5, 5));
      final endScreen = workspace.screen(tester, const Offset(9, 7));
      final gesture = await tester.startGesture(startScreen);
      await tester.pump();
      await gesture.moveTo(endScreen);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final ex = model.project.existingTerrain;
      expect(ex.boundaries.firstWhere((b) => b.id == 'bnd_main').polygon.first.dx, closeTo(4.0, 0.25));
      expect(ex.boundaries.firstWhere((b) => b.id == 'bnd_main').polygon.first.dy, closeTo(2.0, 0.25));
      expect(ex.contours.firstWhere((c) => c.id == 'cnt_main').points.first.dx, closeTo(5.0, 0.25));
      expect(ex.contours.firstWhere((c) => c.id == 'cnt_main').points.first.dy, closeTo(7.0, 0.25));
      expect(ex.spots.firstWhere((s) => s.id == 'spot_main').position.dx, closeTo(7.0, 0.25));
      expect(ex.spots.firstWhere((s) => s.id == 'spot_main').position.dy, closeTo(10.0, 0.25));
      expect(model.undoCount, 1);

      // Single Undo restores boundary, contours, pads, holes & spots together.
      model.undo();
      await tester.pumpAndSettle();
      expect(
        model.project.existingTerrain.contours.firstWhere((c) => c.id == 'cnt_main').points.first,
        const Offset(1, 5),
      );
    });

    testWidgets('2-point Drag tool moves terrain boundary and linked contours cleanly on Apply', (tester) async {
      final project = _siteTerrainProject();
      final model = ArchitectCommandController(project);
      addTearDown(model.dispose);

      await workspace.open(tester, model);

      // Select terrain boundary on its edge (0, 5)
      await tester.tapAt(workspace.screen(tester, const Offset(0, 5)));
      await tester.pumpAndSettle();

      // Activate Drag tool via palette callback (same flow as Drag button)
      final palette = tester.widget<ArchitectToolPalette>(
        find.byType(ArchitectToolPalette),
      );
      palette.onToolChanged(ArchitectTool.drag);
      await tester.pumpAndSettle();

      // Pick base point at (5, 5), target point at (8, 5) -> delta (+3, 0)
      await tester.tapAt(workspace.screen(tester, const Offset(5, 5)));
      await tester.pump();
      await tester.tapAt(workspace.screen(tester, const Offset(8, 5)));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
      await tester.pumpAndSettle();

      final ex = model.project.existingTerrain;
      expect(ex.boundaries.firstWhere((b) => b.id == 'bnd_main').polygon.first.dx, closeTo(3.0, 0.25));
      expect(ex.contours.firstWhere((c) => c.id == 'cnt_main').points.first.dx, closeTo(4.0, 0.25));
      expect(ex.spots.firstWhere((s) => s.id == 'spot_main').position.dx, closeTo(6.0, 0.25));
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
