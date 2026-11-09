import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/icons/app_icon_catalog.dart';
import 'package:kotoview/src/features/architect/models/architect_layer.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_underlay_models.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_geodetic_detector.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_catalog.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

void main() {
  group('Architect Underlays & Geodesy Tests', () {
    test('2-point raster calibration computes exact scale, P1 invariance, and deskew', () {
      const initial = ArchitectRasterUnderlay(
        id: 'rast_1',
        storeyId: 'storey_0',
        fileName: 'survey_scan.png',
        internalImagePath: '/project/underlays/raster/survey_scan.png',
        imageWidthPx: 2000,
        imageHeightPx: 1500,
        position: Offset(0, 0),
        metersPerPixel: 0.01,
        rotationRad: 0.0,
      );

      // Pick two points in local model space that are currently 2.0 m apart at a 30 deg angle
      const p1 = Offset(2.0, 5.0);
      final p2 = Offset(
        2.0 + 2.0 * math.cos(math.pi / 6),
        5.0 + 2.0 * math.sin(math.pi / 6),
      );

      // Verify local pixel coordinates of p1 and p2 before calibration
      final localP1 = initial.localToPixel(p1);
      final localP2 = initial.localToPixel(p2);

      // Calibrate to 10.0 m real distance and align horizontally
      final calibratedHoriz = initial.calibrateTwoPoint(
        localP1: p1,
        localP2: p2,
        realDistanceMeters: 10.0,
        alignMode: ArchitectRasterAlignMode.horizontal,
      );

      final newWorldP1 = calibratedHoriz.pixelToLocal(localP1);
      final newWorldP2 = calibratedHoriz.pixelToLocal(localP2);

      // 1. P1 must remain anchored at p1
      expect((newWorldP1 - p1).distance, lessThan(1e-6));
      // 2. Distance between P1 and P2 in model space must now be 10.0 m
      expect((newWorldP2 - newWorldP1).distance, closeTo(10.0, 1e-6));
      // 3. Vector P1 -> P2 must be horizontal (dy == 0, dx > 0)
      expect((newWorldP2.dy - newWorldP1.dy).abs(), lessThan(1e-6));
      expect(newWorldP2.dx - newWorldP1.dx, closeTo(10.0, 1e-6));

      // Calibrate to 8.5 m real distance and align vertically
      final calibratedVert = initial.calibrateTwoPoint(
        localP1: p1,
        localP2: p2,
        realDistanceMeters: 8.5,
        alignMode: ArchitectRasterAlignMode.vertical,
      );
      final vertWorldP1 = calibratedVert.pixelToLocal(localP1);
      final vertWorldP2 = calibratedVert.pixelToLocal(localP2);
      expect((vertWorldP1 - p1).distance, lessThan(1e-6));
      expect((vertWorldP2 - vertWorldP1).distance, closeTo(8.5, 1e-6));
      expect((vertWorldP2.dx - vertWorldP1.dx).abs(), lessThan(1e-6));
    });

    test('Geodetic detector finds contours and spot elevations geometrically and locks CRS origin across files', () {
      // Create a DXF document in BGS 2005 coordinates (X ~ 318500, Y ~ 4728400) on unstandardized layer '0'
      const baseX = 318500.0;
      const baseY = 4728400.0;

      final contour1 = DxfLwPolyline(
        vertices: const [
          DxfPolylineVertex(x: baseX - 15, y: baseY - 10),
          DxfPolylineVertex(x: baseX - 5, y: baseY - 8),
          DxfPolylineVertex(x: baseX + 5, y: baseY - 6),
          DxfPolylineVertex(x: baseX + 15, y: baseY - 5),
        ],
        isClosed: false,
        layer: '0',
        elevation: 542.5,
      );

      final contour2Major = DxfLwPolyline(
        vertices: const [
          DxfPolylineVertex(x: baseX - 15, y: baseY + 2),
          DxfPolylineVertex(x: baseX - 4, y: baseY + 4),
          DxfPolylineVertex(x: baseX + 6, y: baseY + 5),
          DxfPolylineVertex(x: baseX + 15, y: baseY + 7),
        ],
        isClosed: false,
        layer: '0',
        elevation: 0.0,
      );

      // Text label on contour2Major giving its elevation (2D DXF contour without Z)
      final contour2Label = DxfText(
        insertPoint: const Offset(baseX - 4, baseY + 4.1),
        text: '545.00',
        height: 0.5,
        layer: '0',
      );

      // Spot elevation marker (point + numeric label)
      final spotMarker = DxfPoint(
        point: const Offset(baseX + 2.0, baseY - 1.0),
        layer: '0',
      );
      final spotText = DxfText(
        insertPoint: const Offset(baseX + 2.2, baseY - 0.9),
        text: '543.75',
        height: 0.4,
        layer: '0',
      );

      final doc1 = DxfDocument(
        entities: [
          contour1,
          contour2Major,
          contour2Label,
          spotMarker,
          spotText,
        ],
        layers: {'0': DxfLayer(name: '0')},
        blocks: const {},
        headerVars: const {},
        entityStats: const {},
        bounds: const Rect.fromLTRB(
          baseX - 15,
          baseY - 10,
          baseX + 15,
          baseY + 7,
        ),
      );

      final res1 = ArchitectGeodeticDetector.analyzeDocument(
        doc: doc1,
        storeyId: 'storey_0',
      );

      expect(res1.isGeodetic, isTrue);
      expect(res1.contours.length, 2);
      expect(
        res1.contours.map((c) => c.elevation),
        containsAll([542.5, 545.0]),
      );
      final major = res1.contours.firstWhere((c) => c.elevation == 545.0);
      expect(major.isMajor, isTrue);
      expect(res1.spotElevations.isNotEmpty, isTrue);
      expect(res1.spotElevations.first.elevation, closeTo(543.75, 1e-4));

      // Now simulate replacing/updating the underlay with a DIFFERENTLY NAMED geodetic file
      // that has additional distant annotations (changing doc.bounds significantly),
      // while passing existingSurvey so CRS origin remains locked!
      final doc2WithShiftedBounds = DxfDocument(
        entities: [
          contour1,
          contour2Major,
          contour2Label,
          spotMarker,
          spotText,
        ],
        layers: {'0': DxfLayer(name: '0')},
        blocks: const {},
        headerVars: const {},
        entityStats: const {},
        bounds: const Rect.fromLTRB(
          baseX - 15,
          baseY - 10,
          baseX + 450, // Far annotation shifts bounding box center by +217.5 m!
          baseY + 300,
        ),
      );

      final res2 = ArchitectGeodeticDetector.analyzeDocument(
        doc: doc2WithShiftedBounds,
        storeyId: 'storey_0',
        existingSurvey: res1.survey,
      );

      // Reference origin and model-space contour points must NOT shift!
      expect(res2.frame.origin, equals(res1.frame.origin));
      expect(
        res2.contours.first.points.first,
        equals(res1.contours.first.points.first),
      );
    });

    test('Project serialization, storey scoping, layers, and tool catalog', () {
      final defaults = ArchitectLayer.defaultLayers();
      expect(
        defaults.map((l) => l.id),
        containsAll([
          ArchitectLayer.cadUnderlayLayerId,
          ArchitectLayer.rasterUnderlayLayerId,
          ArchitectLayer.geodesyLayerId,
        ]),
      );

      final catalogTools = ArchitectToolCategory.underlays.tools;
      expect(
        catalogTools,
        containsAll([ArchitectTool.cadUnderlay, ArchitectTool.rasterUnderlay]),
      );
      expect(ArchitectToolCategory.underlays.iconId, AppIconId.cadUnderlay);

      final starter = ArchitectProject.starter(
        name: 'Test Project',
        storeyCount: 2,
      );
      final s0 = starter.storeys[0].id;
      final s1 = starter.storeys[1].id;

      final project = starter.copyWith(
        cadUnderlays: {
          s0: ArchitectCadUnderlayConfig(
            storeyId: s0,
            fileName: 'geodesy.dxf',
            externalSourcePath: '/ext/geodesy.dxf',
            internalCopyPath: '/proj/underlays/cad/geodesy.dxf',
            lockedCadOriginX: 318500,
            lockedCadOriginY: 4728400,
            unitsPerMeter: 1.0,
            isGeodetic: true,
          ),
        },
        rasterUnderlays: [
          ArchitectRasterUnderlay(
            id: 'r0',
            storeyId: s0,
            fileName: 'scan.png',
            internalImagePath: '/proj/underlays/raster/scan.png',
            imageWidthPx: 1000,
            imageHeightPx: 800,
          ),
        ],
        geodeticSurvey: ArchitectGeodeticSurvey(
          coordinateSystemId: 'bgs2005',
          geodeticOriginX: 318500,
          geodeticOriginY: 4728400,
          contours: [
            ArchitectGeodeticContour(
              id: 'c0',
              storeyId: s0,
              points: const [Offset(-5, 0), Offset(5, 0)],
              elevation: 542.5,
            ),
          ],
          spotElevations: [
            ArchitectGeodeticPoint(
              id: 'p0',
              storeyId: s0,
              position: const Offset(1, 2),
              geodeticX: 318501,
              geodeticY: 4728402,
              elevation: 543.1,
            ),
          ],
        ),
      );

      final restored = ArchitectProject.fromJson(project.toJson());
      // Strictly attached to storey s0, not s1
      expect(restored.cadUnderlayForStorey(s0)?.fileName, 'geodesy.dxf');
      expect(restored.cadUnderlayForStorey(s1), isNull);
      expect(restored.rasterUnderlaysForStorey(s0).length, 1);
      expect(restored.rasterUnderlaysForStorey(s1), isEmpty);
      expect(restored.geodeticSurvey?.contoursForStorey(s0).length, 1);
      expect(restored.geodeticSurvey?.contoursForStorey(s1), isEmpty);
      expect(restored.geodeticSurvey?.pointsForStorey(s0).length, 1);
      expect(restored.geodeticSurvey?.pointsForStorey(s1), isEmpty);
    });

    test('CAD underlay control point positioning calculates exact origin and maps P_cad to P_model', () {
      // Base point in CAD coordinates (e.g. intersection of axes A and 1 in millimeters: 50,000 mm, 30,000 mm)
      const pCad = Offset(50000.0, 30000.0);
      const unitsPerMeter = 1000.0; // 1000 mm = 1 m

      // Insertion point on architectural drawing (e.g. model origin or column at (12.5 m, 8.0 m))
      const pModel = Offset(12.5, 8.0);

      // Origin calculation:
      // toModel(cad) = (cad - origin) / unitsPerMeter = model
      // => origin = cad - model * unitsPerMeter
      final originX = pCad.dx - pModel.dx * unitsPerMeter;
      final originY = pCad.dy - pModel.dy * unitsPerMeter;
      final frame = BimCoordinateFrame(
        origin: Offset(originX, originY),
        unitsPerMeter: unitsPerMeter,
      );

      // Verify that the CAD base point maps exactly to the chosen model insertion point
      final mappedModel = frame.toModel(pCad);
      expect((mappedModel - pModel).distance, lessThan(1e-9));

      // Verify reverse mapping: toCad(pModel) returns pCad
      final mappedCad = frame.toCad(pModel);
      expect((mappedCad - pCad).distance, lessThan(1e-9));

      // Test with custom scale (e.g. imperial or geodetic 1 unit = 1 m)
      const pCadGeodetic = Offset(318520.45, 4728415.80);
      const pModelGeodetic = Offset(0.0, 0.0);
      const scaleGeodetic = 1.0;
      final frameGeodetic = BimCoordinateFrame(
        origin: pCadGeodetic - pModelGeodetic * scaleGeodetic,
        unitsPerMeter: scaleGeodetic,
      );
      expect((frameGeodetic.toModel(pCadGeodetic) - pModelGeodetic).distance, lessThan(1e-9));
    });
  });
}
