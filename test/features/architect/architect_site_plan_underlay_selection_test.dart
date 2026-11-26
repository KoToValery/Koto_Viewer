import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart'
    show ArchitectTool;
import 'package:kotoview/src/features/architect/rendering/architect_ghost_storey_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_underlay_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_interaction_mode.dart';
import 'package:kotoview/src/features/architect/widgets/architect_site_orientation_overlay.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_underlay_bar.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectToolPalette _palette(WidgetTester tester) =>
    tester.widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette));

DxfDocument _cadDoc() => DxfDocument(
  entities: [
    DxfLine(layer: '0', p1: Offset.zero, p2: const Offset(6, 0)),
    DxfLine(layer: '0', p1: const Offset(6, 0), p2: const Offset(6, 4)),
    DxfLine(layer: '0', p1: const Offset(6, 4), p2: const Offset(0, 4)),
    DxfLine(layer: '0', p1: const Offset(0, 4), p2: Offset.zero),
  ],
  layers: {'0': DxfLayer(name: '0')},
  blocks: const {},
  bounds: const Rect.fromLTWH(0, 0, 6, 4),
  entityStats: const {},
  headerVars: const {},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Direct launch on Site Plan opens directly in the Underlays category',
    (tester) async {
      final starter = ArchitectProject.starterWithCatalog(
        name: 'Site Category',
        storeyCount: 1,
      );
      final siteId = starter.siteStorey!.id;
      final siteFirst = ArchitectCommandController(
        starter.copyWith(activeStoreyId: siteId),
      );
      addTearDown(siteFirst.dispose);
      await workspace.open(tester, siteFirst);
      expect(
        find.byKey(const ValueKey('architect-tools-underlays')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-tool-cadUnderlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-tool-rasterUnderlay')),
        findsOneWidget,
      );
      expect(_palette(tester).activeTool, ArchitectTool.pan);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Switching from a floor plan to Site Plan opens Underlays, and returning to a floor plan restores Edit',
    (tester) async {
      final starter = ArchitectProject.starterWithCatalog(
        name: 'Site Category Switch',
        storeyCount: 1,
      );
      final floorStorey = starter.storeys.firstWhere((s) => s.isBuildingStorey);
      final floorId = floorStorey.id;

      final floorFirst = ArchitectCommandController(
        starter.copyWith(activeStoreyId: floorId),
      );
      addTearDown(floorFirst.dispose);
      await workspace.open(tester, floorFirst);
      expect(
        find.byKey(const ValueKey('architect-tools-selection')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('architect-view-plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Site Plan'));
      await tester.pumpAndSettle();

      expect(floorFirst.project.activeStorey.isSite, isTrue);
      expect(
        find.byKey(const ValueKey('architect-tools-underlays')),
        findsOneWidget,
      );
      expect(_palette(tester).activeTool, ArchitectTool.pan);

      await tester.tap(find.byKey(const ValueKey('architect-view-plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(floorStorey.name).first);
      await tester.pumpAndSettle();

      expect(floorFirst.project.activeStorey.isSite, isFalse);
      expect(
        find.byKey(const ValueKey('architect-tools-selection')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Selecting a geodetic CAD underlay auto-selects CAD Underlay tool and clicking outside deselects it',
    (tester) async {
      final starter = ArchitectProject.starterWithCatalog(
        name: 'Geodetic CAD Select',
        storeyCount: 1,
      );
      final siteId = starter.siteStorey!.id;
      const cadCfg = ArchitectCadUnderlayConfig(
        id: 'geo_cad_1',
        storeyId: 'storey_site',
        fileName: 'survey.dwg',
        internalCopyPath: '',
        unitsPerMeter: 1.0,
        lockedCadOriginX: 0,
        lockedCadOriginY: 0,
        kind: ArchitectUnderlayKind.geodetic,
        isGeodetic: true,
      );
      final model = ArchitectCommandController(
        starter
            .copyWith(activeStoreyId: siteId)
            .withCadUnderlayAdded(cadCfg),
      );
      addTearDown(model.dispose);

      await workspace.open(
        tester,
        model,
        underlays: {siteId: _cadDoc()},
      );
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-4, -3, 14, 10), padding: 100);
      await tester.pumpAndSettle();

      expect(_palette(tester).activeTool, ArchitectTool.pan);
      expect(
        _palette(tester).interactionMode,
        ArchitectInteractionMode.navigation,
      );
      expect(find.byType(ArchitectCadUnderlayBar), findsNothing);

      // Tap inside the geodetic CAD underlay (touch).
      await tester.tapAt(workspace.screen(tester, const Offset(3, 2)));
      await tester.pumpAndSettle();

      expect(_palette(tester).activeTool, ArchitectTool.cadUnderlay);
      expect(
        _palette(tester).interactionMode,
        ArchitectInteractionMode.contextEdit,
      );
      expect(find.byType(ArchitectCadUnderlayBar), findsOneWidget);
      expect(
        find.byKey(const ValueKey('architect-underlay-crop')),
        findsOneWidget,
      );

      // Click outside the underlay -> deselects underlay and returns to Pan.
      await tester.tapAt(
        workspace.screen(tester, const Offset(-3, -2)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(_palette(tester).activeTool, ArchitectTool.pan);
      expect(
        _palette(tester).interactionMode,
        ArchitectInteractionMode.navigation,
      );
      expect(find.byType(ArchitectCadUnderlayBar), findsNothing);
      expect(
        find.byKey(const ValueKey('architect-underlay-crop')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Selecting a technical CAD underlay or raster underlay auto-selects its underlay tool and clicking outside deselects it',
    (tester) async {
      final starter = ArchitectProject.starterWithCatalog(
        name: 'Technical & Raster Select',
        storeyCount: 1,
      );
      final floorId = starter.storeys.firstWhere((s) => s.isBuildingStorey).id;
      final cadCfg = ArchitectCadUnderlayConfig(
        id: 'tech_cad_1',
        storeyId: floorId,
        fileName: 'struct.dwg',
        internalCopyPath: '',
        unitsPerMeter: 1.0,
        lockedCadOriginX: 0,
        lockedCadOriginY: 0,
        kind: ArchitectUnderlayKind.technical,
        discipline: ArchitectTechnicalUnderlayDiscipline.structural,
      );
      final raster = ArchitectRasterUnderlay(
        id: 'raster_1',
        storeyId: floorId,
        fileName: 'sketch.png',
        internalImagePath: '',
        imageWidthPx: 400,
        imageHeightPx: 200,
        position: const Offset(8, 0),
        metersPerPixel: 0.01,
      );
      final model = ArchitectCommandController(
        starter
            .copyWith(
              activeStoreyId: floorId,
              rasterUnderlays: [raster],
            )
            .withCadUnderlayAdded(cadCfg),
      );
      addTearDown(model.dispose);

      await workspace.open(
        tester,
        model,
        underlays: {floorId: _cadDoc()},
      );
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-3, -3, 17, 10), padding: 100);
      await tester.pumpAndSettle();

      // 1. Tap technical CAD underlay on floor plan.
      await tester.tapAt(workspace.screen(tester, const Offset(3, 2)));
      await tester.pumpAndSettle();

      expect(_palette(tester).activeTool, ArchitectTool.cadUnderlay);
      expect(
        _palette(tester).interactionMode,
        ArchitectInteractionMode.contextEdit,
      );
      expect(
        find.byKey(const ValueKey('architect-tools-underlays')),
        findsOneWidget,
      );
      expect(find.byType(ArchitectCadUnderlayBar), findsOneWidget);

      // 2. Tap raster underlay directly from contextEdit -> switches to rasterUnderlay tool.
      await tester.tapAt(workspace.screen(tester, const Offset(10, 1)));
      await tester.pumpAndSettle();

      expect(_palette(tester).activeTool, ArchitectTool.rasterUnderlay);
      expect(
        _palette(tester).interactionMode,
        ArchitectInteractionMode.contextEdit,
      );
      expect(find.byType(ArchitectRasterUnderlayBar), findsOneWidget);
      expect(find.byType(ArchitectCadUnderlayBar), findsNothing);

      // 3. Tap outside -> deselects raster underlay and returns to Pan.
      await tester.tapAt(workspace.screen(tester, const Offset(-2, -2)));
      await tester.pumpAndSettle();

      expect(_palette(tester).activeTool, ArchitectTool.pan);
      expect(
        _palette(tester).interactionMode,
        ArchitectInteractionMode.navigation,
      );
      expect(find.byType(ArchitectRasterUnderlayBar), findsNothing);
      expect(
        find.byKey(const ValueKey('architect-underlay-crop')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Enabling Ghost storeys shows Site Plan geodetic CAD/raster underlays, geodesy, and terrain on building floors without displacing floor neighbors',
    (tester) async {
      final starter = ArchitectProject.starterWithCatalog(
        name: 'Ghost Site Underlay',
        storeyCount: 2,
      );
      final siteId = starter.siteStorey!.id;
      final floors = starter.storeys.where((s) => s.isBuildingStorey).toList()
        ..sort((a, b) => a.elevation.compareTo(b.elevation));
      final groundId = floors.first.id;
      final upperId = floors[1].id;

      final siteCadCfg = ArchitectCadUnderlayConfig(
        id: 'geo_cad_ghost',
        storeyId: siteId,
        fileName: 'geodesy.dwg',
        internalCopyPath: '',
        unitsPerMeter: 1.0,
        lockedCadOriginX: 0,
        lockedCadOriginY: 0,
        kind: ArchitectUnderlayKind.geodetic,
        isGeodetic: true,
        shareToGroundStoreys: false,
      );
      final siteRaster = ArchitectRasterUnderlay(
        id: 'geo_raster_ghost',
        storeyId: siteId,
        fileName: 'site_scan.png',
        internalImagePath: '',
        imageWidthPx: 400,
        imageHeightPx: 200,
        position: Offset.zero,
        metersPerPixel: 0.01,
        kind: ArchitectUnderlayKind.geodetic,
      );
      final project = starter
          .copyWith(
            activeStoreyId: groundId,
            rasterUnderlays: [siteRaster],
            geodeticSurvey: const ArchitectGeodeticSurvey(
              coordinateSystemId: 'localCartesian',
              geodeticOriginX: 0,
              geodeticOriginY: 0,
              contours: [
                ArchitectGeodeticContour(
                  id: 'gc1',
                  storeyId: 'storey_site',
                  elevation: 100.0,
                  points: [Offset(0, 0), Offset(5, 0)],
                ),
              ],
            ),
            existingTerrain: const ArchitectTerrainSurface(
              boundaries: [
                ArchitectTerrainBoundary(
                  id: 'tb1',
                  polygon: [
                    Offset(-2, -2),
                    Offset(8, -2),
                    Offset(8, 6),
                    Offset(-2, 6),
                  ],
                ),
              ],
            ),
          )
          .withCadUnderlayAdded(siteCadCfg);

      // Neighbors of Ground floor should skip siteStorey and include Upper floor.
      expect(
        ArchitectGhostStoreyPainter.neighbors(project).map((s) => s.id),
        [upperId],
      );

      final model = ArchitectCommandController(project);
      addTearDown(model.dispose);

      await workspace.open(
        tester,
        model,
        underlays: {siteId: _cadDoc()},
      );

      ArchitectUnderlayPainter underlayPainter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<ArchitectUnderlayPainter>()
          .single;

      // Before Ghost storeys: site geodetic CAD/raster/geodesy are not rendered on Ground floor.
      expect(underlayPainter().document, isNull);
      expect(underlayPainter().extraCadUnderlays, isEmpty);
      expect(underlayPainter().rasterUnderlays, isEmpty);
      expect(underlayPainter().showGeodesyLayer, isFalse);

      // Toggle Ghost storeys ON.
      await tester.tap(find.byKey(const ValueKey('architect-ghost-storeys')));
      await tester.pumpAndSettle();

      final painter = underlayPainter();
      expect(painter.extraCadUnderlays, hasLength(1));
      expect(painter.extraCadUnderlays.single.config?.effectiveId, 'geo_cad_ghost');
      expect(painter.rasterUnderlays, hasLength(1));
      expect(painter.rasterUnderlays.single.id, 'geo_raster_ghost');
      expect(painter.showGeodesyLayer, isTrue);
      expect(painter.geodeticContours, hasLength(1));
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((w) => w.painter is ArchitectGhostStoreyPainter),
        hasLength(1),
      );

      // Tapping inside the ghost geodetic underlay on Ground floor must NOT select it.
      await tester.tapAt(workspace.screen(tester, const Offset(3, 2)));
      await tester.pumpAndSettle();
      expect(_palette(tester).activeTool, ArchitectTool.pan);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Selected geodetic CAD and raster underlays expose Edit orientation and Reset orientation without phone overflow',
    (tester) async {
      final starter = ArchitectProject.starterWithCatalog(
        name: 'Geodetic Orientation Actions',
        storeyCount: 1,
      );
      final siteId = starter.siteStorey!.id;
      const angle = math.pi / 6; // 30 degrees
      const cadCfg = ArchitectCadUnderlayConfig(
        id: 'geo_cad_orient',
        storeyId: 'storey_site',
        fileName: 'survey_long_name.dwg',
        internalCopyPath: '',
        unitsPerMeter: 1.0,
        lockedCadOriginX: 0,
        lockedCadOriginY: 0,
        rotationRad: angle,
        kind: ArchitectUnderlayKind.geodetic,
        isGeodetic: true,
      );
      final model = ArchitectCommandController(
        starter
            .copyWith(
              activeStoreyId: siteId,
              northSymbol: const ArchitectNorthSymbol(
                position: Offset.zero,
                angle: angle,
              ),
            )
            .withCadUnderlayAdded(cadCfg),
      );
      addTearDown(model.dispose);

      // Test on narrow phone width (360x800) to confirm zero RenderFlex overflow.
      await workspace.open(
        tester,
        model,
        underlays: {siteId: _cadDoc()},
      );
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-4, -3, 12, 10), padding: 60);
      await tester.pumpAndSettle();

      // The redundant top-right "Orient building" pill is removed, while the
      // North/Building view toggle stays available when north angle != 0.
      expect(
        find.byKey(const ValueKey('architect-site-orient-pill')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('architect-site-north-toggle')),
        findsOneWidget,
      );

      // Select the geodetic CAD underlay.
      await tester.tapAt(workspace.screen(tester, const Offset(3, 2)));
      await tester.pumpAndSettle();

      expect(find.byType(ArchitectCadUnderlayBar), findsOneWidget);
      expect(
        find.byKey(const ValueKey('architect-underlay-edit-orientation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-underlay-reset-orientation')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Tap Edit orientation -> opens ArchitectSiteOrientationOverlay, verify
      // full zoom & pan work before picking and during review, then cancel.
      await tester.tap(
        find.byKey(const ValueKey('architect-underlay-edit-orientation')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectSiteOrientationOverlay), findsOneWidget);

      final orientInput = find.byKey(
        const ValueKey('architect-site-orientation-input'),
      );
      final inputCenter = tester.getCenter(orientInput);
      final scaleBeforeZoom = workspace.camera(tester).scale;
      final mouseZoom = TestPointer(9, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouseZoom.hover(inputCenter));
      await tester.sendEventToBinding(mouseZoom.scroll(const Offset(0, -120)));
      await tester.pump();
      expect(workspace.camera(tester).scale, greaterThan(scaleBeforeZoom));

      final originBeforeDrag = workspace.camera(tester).toScreen(Offset.zero);
      await tester.drag(orientInput, const Offset(40, 20));
      await tester.pump();
      expect(
        (workspace.camera(tester).toScreen(Offset.zero) - originBeforeDrag)
            .distance,
        greaterThan(5),
      );

      // Pick start and end points; confirm zoom still works during review.
      await tester.tapAt(workspace.screen(tester, const Offset(1, 1)));
      await tester.pump();
      await tester.tapAt(workspace.screen(tester, const Offset(5, 1)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('architect-site-orientation-apply')),
        findsOneWidget,
      );
      final scaleBeforeReviewZoom = workspace.camera(tester).scale;
      await tester.sendEventToBinding(mouseZoom.scroll(const Offset(0, -120)));
      await tester.pump();
      expect(
        workspace.camera(tester).scale,
        greaterThan(scaleBeforeReviewZoom),
      );

      await tester.tap(
        find.byKey(const ValueKey('architect-site-orientation-close')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectSiteOrientationOverlay), findsNothing);
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-4, -3, 12, 10), padding: 60);
      await tester.pumpAndSettle();

      // Re-select geodetic CAD underlay and tap Reset orientation.
      await tester.tapAt(workspace.screen(tester, const Offset(3, 2)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-underlay-reset-orientation')),
      );
      await tester.pumpAndSettle();

      expect(model.project.northSymbol!.angle.abs(), lessThan(1e-6));
      expect(
        model.project.cadUnderlays[siteId]!.rotationRad.abs(),
        lessThan(1e-6),
      );
      expect(workspace.camera(tester).rotation.abs(), lessThan(1e-6));

      // Undo restores the previous orientation.
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.northSymbol!.angle, closeTo(angle, 1e-6));
      expect(
        model.project.cadUnderlays[siteId]!.rotationRad,
        closeTo(angle, 1e-6),
      );

      // Also verify geodetic raster underlay exposes Edit & Reset orientation.
      const siteRaster = ArchitectRasterUnderlay(
        id: 'geo_raster_orient',
        storeyId: 'storey_site',
        fileName: 'site_photo.png',
        internalImagePath: '',
        imageWidthPx: 400,
        imageHeightPx: 200,
        position: Offset(8, 0),
        metersPerPixel: 0.01,
        rotationRad: 0.4,
        kind: ArchitectUnderlayKind.geodetic,
      );
      model.restore(
        starter.copyWith(
          activeStoreyId: siteId,
          rasterUnderlays: const [siteRaster],
        ),
      );
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(6, -2, 8, 6), padding: 60);
      await tester.pumpAndSettle();

      await tester.tapAt(workspace.screen(tester, const Offset(10, 1)));
      await tester.pumpAndSettle();

      expect(find.byType(ArchitectRasterUnderlayBar), findsOneWidget);
      expect(
        find.byKey(const ValueKey('architect-underlay-edit-orientation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-underlay-reset-orientation')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('architect-underlay-reset-orientation')),
      );
      await tester.pumpAndSettle();
      expect(
        model.project.rasterUnderlays.single.rotationRad.abs(),
        lessThan(1e-6),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
