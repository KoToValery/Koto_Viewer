import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_contour_interval_predictor.dart';
import 'package:kotoview/src/features/architect/services/architect_landscape_tool.dart';

void main() {
  group('Contour Interval (Δh) Inference & Gradient Prediction', () {
    test('inferIntervalMeters returns step after 2 distinct contours and handles skipped levels', () {
      const datum = 450.0;
      const single = [
        ArchitectTerrainContour(
          id: 'c1',
          points: [Offset(0, 0), Offset(10, 0)],
          elevation: 0.0,
          rawAbsoluteElevation: 450.0,
        ),
      ];
      expect(
        ArchitectContourIntervalPredictor.inferIntervalMeters(
          single,
          datumElevation: datum,
        ),
        isNull,
      );

      const twoContours = [
        ...single,
        ArchitectTerrainContour(
          id: 'c2',
          points: [Offset(0, 5), Offset(10, 5)],
          elevation: 0.5,
          rawAbsoluteElevation: 450.5,
        ),
      ];
      expect(
        ArchitectContourIntervalPredictor.inferIntervalMeters(
          twoContours,
          datumElevation: datum,
        ),
        closeTo(0.5, 1e-6),
      );

      // Even if a user digitized 450.0 -> 451.0 -> 450.5 out of order, min diff is 0.50m
      const outOfOrder = [
        ArchitectTerrainContour(
          id: 'a',
          points: [Offset(0, 0), Offset(10, 0)],
          elevation: 0.0,
          rawAbsoluteElevation: 450.0,
        ),
        ArchitectTerrainContour(
          id: 'b',
          points: [Offset(0, 10), Offset(10, 10)],
          elevation: 1.0,
          rawAbsoluteElevation: 451.0,
        ),
        ArchitectTerrainContour(
          id: 'c',
          points: [Offset(0, 5), Offset(10, 5)],
          elevation: 0.5,
          rawAbsoluteElevation: 450.5,
        ),
      ];
      expect(
        ArchitectContourIntervalPredictor.inferIntervalMeters(
          outOfOrder,
          datumElevation: datum,
        ),
        closeTo(0.5, 1e-6),
      );
    });

    test('predicts upward above middle contour and downward below middle contour', () {
      const surface = ArchitectTerrainSurface(
        datumElevation: 450.0,
        contours: [
          // Middle contour at y = 10 -> 450.0
          ArchitectTerrainContour(
            id: 'c_mid',
            points: [Offset(0, 10), Offset(20, 10)],
            elevation: 0.0,
            rawAbsoluteElevation: 450.0,
          ),
          // Next contour going up at y = 15 -> 450.5
          ArchitectTerrainContour(
            id: 'c_up1',
            points: [Offset(0, 15), Offset(20, 15)],
            elevation: 0.5,
            rawAbsoluteElevation: 450.5,
          ),
          // Next contour going up at y = 20 -> 451.0
          ArchitectTerrainContour(
            id: 'c_up2',
            points: [Offset(0, 20), Offset(20, 20)],
            elevation: 1.0,
            rawAbsoluteElevation: 451.0,
          ),
        ],
      );

      // Continuing upwards past c_up2 (y = 25) -> 451.5
      final predUp = ArchitectContourIntervalPredictor.predictNextAbsoluteElevation(
        surface: surface,
        candidatePoints: const [Offset(0, 25), Offset(20, 25)],
        candidateClosed: false,
        fallbackAbsoluteElevation: 451.0,
      );
      expect(predUp, closeTo(451.5, 1e-4));

      // Returning to middle contour c_mid (y = 10) and picking below it (y = 5) -> 449.5!
      final predDown =
          ArchitectContourIntervalPredictor.predictNextAbsoluteElevation(
            surface: surface,
            candidatePoints: const [Offset(0, 5), Offset(20, 5)],
            candidateClosed: false,
            fallbackAbsoluteElevation: 451.0,
          );
      expect(predDown, closeTo(449.5, 1e-4));
    });

    test('predicts intermediate elevation when filling skipped contour between two contours', () {
      const surface = ArchitectTerrainSurface(
        datumElevation: 450.0,
        contourInterval: 0.5,
        contourIntervalManual: true,
        contours: [
          ArchitectTerrainContour(
            id: 'c1',
            points: [Offset(0, 10), Offset(20, 10)],
            elevation: 0.0,
            rawAbsoluteElevation: 450.0,
          ),
          ArchitectTerrainContour(
            id: 'c3',
            points: [Offset(0, 20), Offset(20, 20)],
            elevation: 1.0,
            rawAbsoluteElevation: 451.0,
          ),
        ],
      );

      final predMid = ArchitectContourIntervalPredictor.predictNextAbsoluteElevation(
        surface: surface,
        candidatePoints: const [Offset(0, 14), Offset(20, 14)],
        candidateClosed: false,
        fallbackAbsoluteElevation: 451.0,
      );
      expect(predMid, closeTo(450.5, 1e-4));
    });

    test('predicts inward concentric closed contours going higher on hill', () {
      List<Offset> ring(double r) => [
        Offset(-r, 0),
        Offset(0, -r),
        Offset(r, 0),
        Offset(0, r),
      ];
      final surface = ArchitectTerrainSurface(
        datumElevation: 100.0,
        contours: [
          ArchitectTerrainContour(
            id: 'r10',
            points: ring(10),
            closed: true,
            elevation: 0.0,
            rawAbsoluteElevation: 100.0,
          ),
          ArchitectTerrainContour(
            id: 'r6',
            points: ring(6),
            closed: true,
            elevation: 0.5,
            rawAbsoluteElevation: 100.5,
          ),
        ],
      );

      final predPeak = ArchitectContourIntervalPredictor.predictNextAbsoluteElevation(
        surface: surface,
        candidatePoints: ring(2),
        candidateClosed: true,
        fallbackAbsoluteElevation: 100.5,
      );
      expect(predPeak, closeTo(101.0, 1e-4));
    });

    test('terrainElevationUnit uses meters for metric units and feet for imperial units', () {
      expect(terrainElevationUnit(BimDistanceUnit.meters), BimDistanceUnit.meters);
      expect(
        terrainElevationUnit(BimDistanceUnit.centimeters),
        BimDistanceUnit.meters,
      );
      expect(
        terrainElevationUnit(BimDistanceUnit.millimeters),
        BimDistanceUnit.meters,
      );
      expect(terrainElevationUnit(BimDistanceUnit.feet), BimDistanceUnit.feet);
      expect(terrainElevationUnit(BimDistanceUnit.inches), BimDistanceUnit.feet);
      expect(
        terrainElevationUnit(BimDistanceUnit.meters, BimDistanceUnit.inches),
        BimDistanceUnit.feet,
      );
    });

    test('ArchitectTerrainSurface serializes contourInterval and updates via ArchitectLandscapeTool', () {
      const surface = ArchitectTerrainSurface(
        contourInterval: 0.5,
        contourIntervalManual: true,
      );
      final restored = ArchitectTerrainSurface.fromJson(surface.toJson());
      expect(restored.contourInterval, closeTo(0.5, 1e-6));
      expect(restored.contourIntervalManual, isTrue);

      final base = ArchitectProject.starterWithCatalog(
        name: 'Interval Sync',
        storeyCount: 1,
      );
      final updated = ArchitectLandscapeTool.updateSurfaceContourInterval(
        base,
        intervalMeters: 0.5,
        manual: true,
      );
      expect(updated.existingTerrain.contourInterval, closeTo(0.5, 1e-6));
      expect(updated.existingTerrain.contourIntervalManual, isTrue);
      expect(updated.proposedTerrain.contourInterval, closeTo(0.5, 1e-6));
      expect(updated.proposedTerrain.contourIntervalManual, isTrue);
    });
  });
}
