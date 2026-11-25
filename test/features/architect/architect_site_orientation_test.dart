import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_en.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_layout.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_composer.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_site_orientation.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_viewport_controller.dart';

ArchitectProject _sampleSiteProject({bool withBuildingWall = false}) {
  const siteStorey = ArchitectStorey(
    id: 'site',
    name: 'Site',
    isSite: true,
    siteFences: [
      ArchitectSiteFence(
        id: 'fence_1',
        points: [Offset(0, 0), Offset(10, 0)],
      ),
    ],
  );
  const basement = ArchitectStorey(
    id: 'basement',
    name: 'Basement',
    elevation: -3.0,
  );
  final ground = ArchitectStorey(
    id: 'ground',
    name: 'Ground',
    elevation: 0.0,
    walls: withBuildingWall
        ? [
            ArchitectWall(
              id: 'w1',
              startPoint: const Offset(2, 2),
              endPoint: const Offset(8, 2),
            ),
          ]
        : const [],
  );
  const upper = ArchitectStorey(
    id: 'upper',
    name: 'Floor 2',
    elevation: 3.0,
  );

  const siteCad = ArchitectCadUnderlayConfig(
    storeyId: 'site',
    fileName: 'survey.dxf',
    internalCopyPath: 'underlays/survey.dxf',
    lockedCadOriginX: 0,
    lockedCadOriginY: 0,
    unitsPerMeter: 1.0,
    cadOrientation: true,
    rotationRad: 0.0,
    isGeodetic: true,
    maskPolygon: [
      Offset(-5, -5),
      Offset(15, -5),
      Offset(15, 15),
      Offset(-5, 15),
    ],
  );

  const terrain = ArchitectTerrainSurface(
    state: ArchitectTerrainState.existing,
    boundaries: [
      ArchitectTerrainBoundary(
        id: 'tb1',
        polygon: [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
      ),
    ],
    spots: [
      ArchitectTerrainSpot(id: 'sp1', position: Offset(10, 0), elevation: 1.2),
    ],
  );

  const survey = ArchitectGeodeticSurvey(
    coordinateSystemId: 'BGS2005',
    geodeticOriginX: 320000,
    geodeticOriginY: 4720000,
    spotElevations: [
      ArchitectGeodeticPoint(
        id: 'gp1',
        storeyId: 'site',
        position: Offset(10, 0),
        geodeticX: 320010,
        geodeticY: 4720000,
        elevation: 540.0,
      ),
    ],
  );

  final siteDrawing = const ArchitectSavedDrawing(
    id: 'draw_site',
    sourceId: 'site',
    kind: ArchitectDrawingKind.plan,
    sitePlan: true,
    scale: 200,
  );
  final sheet = ArchitectSheet(
    id: 'sheet_1',
    number: 'A-01',
    placements: [
      const ArchitectDrawingPlacement(
        id: 'pl_site',
        drawingId: 'draw_site',
        frame: Rect.fromLTWH(20, 20, 120, 90),
        anchor: Offset.zero,
        scale: 200,
        orientation: ArchitectPlacementOrientation.trueNorth,
      ),
    ],
  );

  return ArchitectProject(
    id: 'proj_orient',
    name: 'Orientation Test',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    storeys: [siteStorey, basement, ground, upper],
    activeStoreyId: 'site',
    cadUnderlays: const {'site': siteCad},
    existingTerrain: terrain,
    geodeticSurvey: survey,
    document: ArchitectDocument(
      drawings: [siteDrawing],
      sheets: [sheet],
    ),
  );
}

void main() {
  group('ArchitectSiteOrientation', () {
    test('aligns tilted edge to Project North, syncs North, terrain, survey, and True North sheets with full Undo/Redo', () {
      final project = _sampleSiteProject();
      final controller = ArchitectCommandController(project);

      // Suppose a parcel edge runs at +35° clockwise from +X in model space.
      const edgeAngle = 35.0 * math.pi / 180.0;
      const p1 = Offset(0, 0);
      final p2 = Offset(math.cos(edgeAngle) * 10, math.sin(edgeAngle) * 10);

      final delta = ArchitectSiteOrientation.deltaToAlignSegment(p1, p2);
      expect(delta, closeTo(-edgeAngle, 1e-9));

      final aligned = ArchitectSiteOrientation.align(
        project: controller.project,
        pivot: p1,
        deltaRad: delta,
      );
      controller.execute(AlignArchitectSiteOrientation(aligned));

      final after = controller.project;
      // CAD underlay rotation and North symbol angle match identically (mod 2π).
      final siteCad = after.cadUnderlays['site']!;
      expect(
        ArchitectSiteOrientation.normalizeAngle(siteCad.rotationRad),
        closeTo(-edgeAngle, 1e-9),
      );
      expect(after.northSymbol, isNotNull);
      expect(after.northSymbol!.angle, closeTo(-edgeAngle, 1e-9));

      // True North view rotation cancels CAD rotation back to 0°!
      final viewRot = ArchitectSiteOrientation.trueNorthViewRotationRad(after);
      expect(
        ArchitectSiteOrientation.normalizeAngle(viewRot + siteCad.rotationRad),
        closeTo(0.0, 1e-9),
      );

      // Terrain spot and geodetic survey point rotated around pivot, while
      // original geodeticX/Y metadata stay untouched.
      final spot = after.existingTerrain.spots.single.position;
      expect(spot.dx, closeTo(math.cos(-edgeAngle) * 10, 1e-6));
      expect(spot.dy, closeTo(math.sin(-edgeAngle) * 10, 1e-6));
      expect(after.geodeticSurvey!.spotElevations.single.geodeticX, 320010);
      expect(after.geodeticSurvey!.spotElevations.single.position.dx, closeTo(spot.dx, 1e-6));

      // True North sheet placement synced automatically to +35°.
      final pl = after.document.sheets.single.placements.single;
      expect(pl.orientation, ArchitectPlacementOrientation.trueNorth);
      expect(pl.rotation, closeTo(35.0, 1e-6));

      // Undo restores exact original state; Redo reapplies it.
      controller.undo();
      expect(controller.project.northSymbol, isNull);
      expect(controller.project.cadUnderlays['site']!.rotationRad, 0.0);
      controller.redo();
      expect(controller.project.northSymbol!.angle, closeTo(-edgeAngle, 1e-9));
    });

    test('rotates building storeys only when rotateBuilding is true', () {
      final project = _sampleSiteProject(withBuildingWall: true);
      expect(ArchitectSiteOrientation.hasBuildingGeometry(project), isTrue);

      final siteOnly = ArchitectSiteOrientation.align(
        project: project,
        pivot: Offset.zero,
        deltaRad: math.pi / 4,
        rotateBuilding: false,
      );
      final groundWallFixed =
          siteOnly.storeys.firstWhere((s) => s.id == 'ground').walls.single;
      expect(groundWallFixed.startPoint, const Offset(2, 2));

      final withBuilding = ArchitectSiteOrientation.align(
        project: project,
        pivot: Offset.zero,
        deltaRad: math.pi / 2,
        rotateBuilding: true,
      );
      final groundWallRotated =
          withBuilding.storeys.firstWhere((s) => s.id == 'ground').walls.single;
      expect(groundWallRotated.startPoint.dx, closeTo(-2, 1e-6));
      expect(groundWallRotated.startPoint.dy, closeTo(2, 1e-6));
    });
  });

  group('Shared ground-storey survey underlay', () {
    test('inherits Site Plan CAD underlay on storeys <= 0.00 only and respects exclusions', () {
      final project = _sampleSiteProject();

      expect(project.effectiveCadUnderlayForStorey('site')?.fileName, 'survey.dxf');
      expect(project.isSharedCadUnderlayForStorey('site'), isFalse);

      expect(project.effectiveCadUnderlayForStorey('basement')?.fileName, 'survey.dxf');
      expect(project.isSharedCadUnderlayForStorey('basement'), isTrue);
      expect(project.effectiveCadUnderlayOwnerId('basement'), 'site');

      expect(project.effectiveCadUnderlayForStorey('ground')?.fileName, 'survey.dxf');
      expect(project.isSharedCadUnderlayForStorey('ground'), isTrue);

      // Upper storey (> 0.00) does NOT inherit the site underlay.
      expect(project.effectiveCadUnderlayForStorey('upper'), isNull);
      expect(project.isSharedCadUnderlayForStorey('upper'), isFalse);

      // Excluding 'ground' hides it on ground while keeping it on site & basement.
      final excluded = project.copyWith(
        excludedInheritedCadStoreys: {'ground'},
      );
      expect(excluded.effectiveCadUnderlayForStorey('ground'), isNull);
      expect(excluded.effectiveCadUnderlayForStorey('basement'), isNotNull);
      expect(excluded.effectiveCadUnderlayForStorey('site'), isNotNull);

      // Disabling shareToGroundStoreys round-trips through JSON.
      final unsharedCfg = ArchitectCadUnderlayConfig.fromJson(
        project.cadUnderlays['site']!.copyWith(shareToGroundStoreys: false).toJson(),
      );
      expect(unsharedCfg.shareToGroundStoreys, isFalse);
      final unshared = project.copyWith(cadUnderlays: {'site': unsharedCfg});
      expect(unshared.effectiveCadUnderlayForStorey('ground'), isNull);
    });
  });

  group('BimViewportController rotation', () {
    test('maintains exact screen<->model roundtrip, pinned anchor, and rotated visibleRect', () {
      final vp = BimViewportController();
      vp.resize(const Size(400, 800));

      for (final deg in [37.0, 145.0, -62.0, 180.0]) {
        final anchorScreen = const Offset(150, 320);
        final beforeModel = vp.toModel(anchorScreen);
        vp.setRotation(deg * math.pi / 180.0, screenAnchor: anchorScreen);
        final afterModel = vp.toModel(anchorScreen);

        expect(afterModel.dx, closeTo(beforeModel.dx, 1e-6));
        expect(afterModel.dy, closeTo(beforeModel.dy, 1e-6));

        const probe = Offset(12.5, -7.25);
        final roundTrip = vp.toModel(vp.toScreen(probe));
        expect(roundTrip.dx, closeTo(probe.dx, 1e-6));
        expect(roundTrip.dy, closeTo(probe.dy, 1e-6));

        // Pinch-zoom around a focal point keeps the focal model point pinned.
        const focal = Offset(240, 410);
        final focalModel = vp.toModel(focal);
        vp.navigate(previousFocal: focal, focal: focal + const Offset(15, -20), scaleFactor: 1.5);
        final shiftedModel = vp.toModel(focal + const Offset(15, -20));
        expect(shiftedModel.dx, closeTo(focalModel.dx, 1e-6));
        expect(shiftedModel.dy, closeTo(focalModel.dy, 1e-6));

        // visibleRect must contain all 4 screen corners.
        final rect = vp.visibleRect;
        for (final corner in const [
          Offset(0, 0),
          Offset(400, 0),
          Offset(400, 800),
          Offset(0, 800),
        ]) {
          final m = vp.toModel(corner);
          expect(rect.inflate(1e-6).contains(m), isTrue);
        }
      }
    });
  });

  group('Layout True North orientation and text readability', () {
    test('placement orientation serializes cleanly and keeps legacy compatibility', () {
      const trueNorthPl = ArchitectDrawingPlacement(
        id: 'p1',
        drawingId: 'd1',
        frame: Rect.fromLTWH(10, 10, 100, 80),
        anchor: Offset.zero,
        rotation: 25,
        orientation: ArchitectPlacementOrientation.trueNorth,
      );
      final decoded = ArchitectDrawingPlacement.fromJson(trueNorthPl.toJson());
      expect(decoded.orientation, ArchitectPlacementOrientation.trueNorth);
      expect(decoded.rotation, 25);

      // Legacy JSON without 'orientation' field:
      final legacyZero = ArchitectDrawingPlacement.fromJson({
        'id': 'p2',
        'drawingId': 'd1',
        'frame': [0, 0, 50, 50],
        'anchor': [0, 0],
        'rotation': 0,
      });
      expect(legacyZero.orientation, ArchitectPlacementOrientation.projectNorth);

      final legacyCustom = ArchitectDrawingPlacement.fromJson({
        'id': 'p3',
        'drawingId': 'd1',
        'frame': [0, 0, 50, 50],
        'anchor': [0, 0],
        'rotation': 45,
      });
      expect(legacyCustom.orientation, ArchitectPlacementOrientation.custom);
    });

    test('ArchitectDimensionLayout.textAngle stays ISO-readable under view rotation', () {
      const doc = ArchitectDocument();
      // A horizontal model segment (+X) viewed under a 140° rotated camera
      // would be upside down unless flipped by pi.
      const viewRot = 140.0 * math.pi / 180.0;
      final scope = ArchitectTextScope(
        doc,
        'plan:site',
        100,
        40,
        viewRotationRad: viewRot,
      );
      final localAngle = scope.run(
        () => ArchitectDimensionLayout.textAngle(const Offset(1, 0)),
      );
      final net = ArchitectSiteOrientation.normalizeAngle(localAngle + viewRot);
      expect(net.abs(), lessThanOrEqualTo(math.pi / 2 + 1e-6));
    });

    test('ArchitectSheetComposer resolves True North rotation and counter-rotates North letter upright', () {
      final base = _sampleSiteProject();
      final project = ArchitectSiteOrientation.align(
        project: base,
        pivot: Offset.zero,
        deltaRad: -40.0 * math.pi / 180.0,
      );
      final sheet = project.document.sheets.single;
      final place = sheet.placements.single;
      expect(
        ArchitectSheetGeometry.effectiveRotationDeg(place, project),
        closeTo(40.0, 1e-6),
      );

      final l = AppLocalizationsEn();
      final scene = ArchitectSheetComposer.compose(
        project,
        sheet,
        l,
        allowMissing: true,
      );
      // Find the North symbol letter 'N' emitted inside the rotated placement;
      // its final paper-space rotation should be ~0 (upright!).
      final northText = scene.operations
          .whereType<ArchitectVectorText>()
          .where((op) => op.text == l.architectNorthSymbolLetter)
          .firstOrNull;
      expect(northText, isNotNull);
      expect(
        ArchitectSiteOrientation.normalizeAngle(northText!.rotation).abs(),
        lessThan(1e-3),
      );
    });
  });
}
