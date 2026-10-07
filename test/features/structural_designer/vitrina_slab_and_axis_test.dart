import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/structural_designer/analysis/geometric_window_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';

DxfDocument _createTestDoc({
  required Map<String, DxfLayer> layers,
  required List<DxfEntity> entities,
  Rect bounds = const Rect.fromLTWH(0, 0, 1000, 1000),
}) {
  return DxfDocument(
    layers: Map<String, DxfLayer>.from(layers),
    blocks: const {},
    entities: List<DxfEntity>.from(entities),
    headerVars: const {},
    bounds: bounds,
    entityStats: const {},
  );
}

void main() {
  group('Vitrina Slab Detection & Dynamic Axis Tests', () {
    test('1. Dynamic axes are NOT created for 12 cm partition walls', () {
      // Create a test document with:
      // - One 25 cm structural masonry wall at X = 0 (Y from 0 to 4000)
      // - One 12 cm partition wall at X = 2000 (Y from 0 to 3000)
      final wallLayer = DxfLayer(name: 'WALLS', colorIndex: 7, isVisible: true);
      final doc = _createTestDoc(
        layers: {'WALLS': wallLayer},
        entities: const [
          // 250mm structural wall
          DxfLine(p1: Offset(0, 0), p2: Offset(0, 4000), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 0), p2: Offset(250, 4000), layer: 'WALLS'),
          // 120mm interior partition wall
          DxfLine(p1: Offset(2000, 0), p2: Offset(2000, 3000), layer: 'WALLS'),
          DxfLine(p1: Offset(2120, 0), p2: Offset(2120, 3000), layer: 'WALLS'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 2120, 4000),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);

      // Selected wall pairs still record both the 25cm wall and 12cm partition wall
      expect(result.selectedWallPairs.length, 2);
      final has25 = result.selectedWallPairs.any((p) => (p.perpendicularDistance / result.detectedScale - 250).abs() < 20);
      final has12 = result.selectedWallPairs.any((p) => (p.perpendicularDistance / result.detectedScale - 120).abs() < 20);
      expect(has25, isTrue, reason: '25cm structural wall should be in selectedWallPairs');
      expect(has12, isTrue, reason: '12cm partition wall should be in selectedWallPairs for contours');

      // But snappedCenterlines (used for dynamic axes) MUST ONLY contain the 25cm structural wall!
      expect(result.snappedCenterlines.length, 1);
      final structuralCenterlineX = (result.snappedCenterlines.first.$1.dx + result.snappedCenterlines.first.$2.dx) / 2.0;
      expect(structuralCenterlineX, closeTo(125.0, 5.0), reason: 'Axis must be at 125mm (center of 25cm wall)');

      // Dynamic axes generated from snappedCenterlines must NOT have an axis for the 12cm wall
      final axes = WallAxisDetector.convertToStructuralGridAxes(
        result.snappedCenterlines,
        isBulgarian: true,
        scale: result.detectedScale,
      );
      expect(axes.length, 1);
      expect(axes.first.start.dx, closeTo(125.0, 5.0));
    });

    test('2. 0.dxf: partition walls at 12 cm do not generate duplicate or unwanted dynamic axes', () {
      final file = File('test_files/0.dxf');
      expect(file.existsSync(), isTrue);

      final content = UniversalEncodingService.decodeBytes(file.readAsBytesSync());
      final doc = DxfParser.parseString(content);

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);

      // Ensure that NO snapped centerline has thickness < 180 mm
      final generatedAxes = WallAxisDetector.convertToStructuralGridAxes(
        result.snappedCenterlines,
        scale: result.detectedScale,
        isBulgarian: false,
        collinearToleranceMm: 120.0,
        minTotalWallLengthM: 0.80,
      );
      expect(generatedAxes.isNotEmpty, isTrue);

      // Ensure no axes are placed within ~15cm of each other (which previously occurred due to 12cm partition walls)
      for (int i = 0; i < generatedAxes.length; i++) {
        for (int j = i + 1; j < generatedAxes.length; j++) {
          final a1 = generatedAxes[i];
          final a2 = generatedAxes[j];
          if (a1.isParallelTo(a2, toleranceRad: 0.05)) {
            final dist = a1.distanceToSegment((a2.start + a2.end) / 2.0);
            expect(dist / result.detectedScale, greaterThan(250.0),
                reason: 'Parallel axes "${a1.name}" and "${a2.name}" are too close (${dist / result.detectedScale}mm), indicating a partition wall axis');
          }
        }
      }
    });

    test('3. Vitrina opening connects one part of the facade wall straight to the other without skewing', () {
      // Synthetic facade with:
      // - Wall A (Y = 0 to 1000, X = 0 to 250)
      // - Window opening (Y = 1000 to 2500) with window frame lines
      // - Wall B (Y = 2500 to 5000, X = 0 to 250)
      // - Perpendicular enclosing walls to form a room
      final wallLayer = DxfLayer(name: 'WALLS', colorIndex: 7, isVisible: true);
      final winLayer = DxfLayer(name: 'WINDOWS', colorIndex: 4, isVisible: true);

      final doc = _createTestDoc(
        layers: {'WALLS': wallLayer, 'WINDOWS': winLayer},
        entities: const [
          // Wall A along west facade
          DxfLine(p1: Offset(0, 0), p2: Offset(0, 1000), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 0), p2: Offset(250, 1000), layer: 'WALLS'),
          // Window opening (1.50m) between Y=1000 and Y=2500 with glazing lines
          DxfLine(p1: Offset(80, 1000), p2: Offset(80, 2500), layer: 'WINDOWS'),
          DxfLine(p1: Offset(170, 1000), p2: Offset(170, 2500), layer: 'WINDOWS'),
          // Transverse frame profiles
          DxfLine(p1: Offset(50, 1000), p2: Offset(200, 1000), layer: 'WINDOWS'),
          DxfLine(p1: Offset(50, 2500), p2: Offset(200, 2500), layer: 'WINDOWS'),
          // Wall B along west facade
          DxfLine(p1: Offset(0, 2500), p2: Offset(0, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 2500), p2: Offset(250, 5000), layer: 'WALLS'),
          // Top wall
          DxfLine(p1: Offset(0, 5000), p2: Offset(4000, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 4750), p2: Offset(4000, 4750), layer: 'WALLS'),
          // East wall
          DxfLine(p1: Offset(4000, 0), p2: Offset(4000, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(3750, 0), p2: Offset(3750, 5000), layer: 'WALLS'),
          // Bottom wall
          DxfLine(p1: Offset(0, 0), p2: Offset(4000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 250), p2: Offset(4000, 250), layer: 'WALLS'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 4000, 5000),
      );

      final wallsResult = WallAxisDetector.detect(doc);
      expect(wallsResult.hasWallsFound, isTrue);

      final windows = GeometricWindowDetector.detect(doc, wallsResult.selectedWallPairs, wallsResult.detectedScale);
      expect(windows.isNotEmpty, isTrue, reason: 'Window opening between Wall A and Wall B must be detected');

      final win = windows.first;
      // Opening must be strictly vertical (aligned with the facade direction)
      final dxWin = (win.end.dx - win.start.dx).abs();
      expect(dxWin, closeTo(0.0, 1e-4), reason: 'Window corridor centerline must be strictly collinear with the wall without lateral skew');

      // Barrier polygon faces must also be strictly vertical (no skew)
      for (int i = 0; i < win.barrierPolygon.length; i++) {
        final p1 = win.barrierPolygon[i];
        final p2 = win.barrierPolygon[(i + 1) % win.barrierPolygon.length];
        final isOrthogonal = (p1.dx - p2.dx).abs() < 1e-3 || (p1.dy - p2.dy).abs() < 1e-3;
        expect(isOrthogonal, isTrue, reason: 'Barrier polygon edges across the vitrina must be strictly orthogonal');
      }

      // Slab envelope detection
      final slabResult = SlabEnvelopeDetector.detect(wallsResult, document: doc);
      expect(slabResult.contours.isNotEmpty, isTrue);

      // The slab contour along the west facade (X ~ 0) must bridge the window opening strictly vertically
      final contour = slabResult.contours.first;
      for (int i = 0; i < contour.length; i++) {
        final p1 = contour[i];
        final p2 = contour[(i + 1) % contour.length];
        final isOrthogonal = (p1.dx - p2.dx).abs() < 1e-2 || (p1.dy - p2.dy).abs() < 1e-2;
        expect(isOrthogonal, isTrue, reason: 'Slab boundary edge ($p1 -> $p2) must be strictly orthogonal (no skewed / tilted lines across vitrines)');
      }
    });

    test('4. 0.dxf: slab envelope contour edges are strictly orthogonal and straight across facade vitrines', () {
      final file = File('test_files/0.dxf');
      expect(file.existsSync(), isTrue);

      final content = UniversalEncodingService.decodeBytes(file.readAsBytesSync());
      final doc = DxfParser.parseString(content);

      final wallsResult = WallAxisDetector.detect(doc);
      final slabResult = SlabEnvelopeDetector.detect(wallsResult, document: doc);
      expect(slabResult.contours.isNotEmpty, isTrue);

      // Verify contour edges in 0.dxf (orthogonal building) have no skewed/diagonal lines
      final contour = slabResult.contours.first;
      for (int i = 0; i < contour.length; i++) {
        final p1 = contour[i];
        final p2 = contour[(i + 1) % contour.length];
        final dx = (p2.dx - p1.dx).abs();
        final dy = (p2.dy - p1.dy).abs();
        final isOrthogonal = dx < 1e-2 || dy < 1e-2;
        expect(isOrthogonal, isTrue,
            reason: 'Slab contour edge from $p1 to $p2 must be strictly orthogonal, found dx=$dx, dy=$dy');
      }
    });

    test('5. Architectural principle: face-to-face jambs ("лице в лице") vs non-facing parallel walls', () {
      final wallLayer = DxfLayer(name: 'WALLS', colorIndex: 7, isVisible: true);
      final winLayer = DxfLayer(name: 'WINDOWS', colorIndex: 4, isVisible: true);

      // Two collinear walls facing each other with an opening between them
      final docFacing = _createTestDoc(
        layers: {'WALLS': wallLayer, 'WINDOWS': winLayer},
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(2000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 250), p2: Offset(2000, 250), layer: 'WALLS'),
          // 2.0m window opening from X=2000 to X=4000
          DxfLine(p1: Offset(2000, 100), p2: Offset(4000, 100), layer: 'WINDOWS'),
          DxfLine(p1: Offset(2000, 150), p2: Offset(4000, 150), layer: 'WINDOWS'),
          DxfLine(p1: Offset(4000, 0), p2: Offset(6000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(4000, 250), p2: Offset(6000, 250), layer: 'WALLS'),
        ],
      );

      final resultFacing = WallAxisDetector.detect(docFacing);
      final windowsFacing = GeometricWindowDetector.detect(
        docFacing,
        resultFacing.selectedWallPairs,
        resultFacing.detectedScale,
      );
      expect(windowsFacing.length, 1, reason: 'Face-to-face collinear jambs across hole must be detected as window');

      // Now create two parallel walls where jambs do NOT face each other along the axis
      // (one wall is behind the other with a lateral offset)
      final docNonFacing = _createTestDoc(
        layers: {'WALLS': wallLayer, 'WINDOWS': winLayer},
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(2000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 250), p2: Offset(2000, 250), layer: 'WALLS'),
          // Parallel wall but laterally offset by 800mm, not collinear
          DxfLine(p1: Offset(2000, 800), p2: Offset(4000, 800), layer: 'WALLS'),
          DxfLine(p1: Offset(2000, 1050), p2: Offset(4000, 1050), layer: 'WALLS'),
        ],
      );

      final resultNonFacing = WallAxisDetector.detect(docNonFacing);
      final windowsNonFacing = GeometricWindowDetector.detect(
        docNonFacing,
        resultNonFacing.selectedWallPairs,
        resultNonFacing.detectedScale,
      );
      expect(windowsNonFacing.isEmpty, isTrue, reason: 'Non-collinear offset walls must not create an opening');
    });

    test('6. Architectural principle: open courtyard recess with perpendicular return walls without glazing is NOT bridged', () {
      // Courtyard with perpendicular side walls going inward into the building depth
      final wallLayer = DxfLayer(name: 'WALLS', colorIndex: 7, isVisible: true);
      final doc = _createTestDoc(
        layers: {'WALLS': wallLayer},
        entities: const [
          // Left facade wall at X=0..250, Y from 0 to 1500
          DxfLine(p1: Offset(0, 0), p2: Offset(0, 1500), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 0), p2: Offset(250, 1500), layer: 'WALLS'),
          // Left perpendicular return wall extending inward (+X direction) at Y=1250..1500
          DxfLine(p1: Offset(250, 1250), p2: Offset(2000, 1250), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 1500), p2: Offset(2000, 1500), layer: 'WALLS'),
          // Back wall of courtyard at X=2000..2250, Y from 1250 to 3750
          DxfLine(p1: Offset(2000, 1250), p2: Offset(2000, 3750), layer: 'WALLS'),
          DxfLine(p1: Offset(2250, 1250), p2: Offset(2250, 3750), layer: 'WALLS'),
          // Right perpendicular return wall extending inward (+X direction) at Y=3500..3750
          DxfLine(p1: Offset(250, 3500), p2: Offset(2000, 3500), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 3750), p2: Offset(2000, 3750), layer: 'WALLS'),
          // Right facade wall at X=0..250, Y from 3500 to 5000
          DxfLine(p1: Offset(0, 3500), p2: Offset(0, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 3500), p2: Offset(250, 5000), layer: 'WALLS'),
          // Closing outer walls of building
          DxfLine(p1: Offset(0, 0), p2: Offset(4000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 250), p2: Offset(4000, 250), layer: 'WALLS'),
          DxfLine(p1: Offset(4000, 0), p2: Offset(4000, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(3750, 0), p2: Offset(3750, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 5000), p2: Offset(4000, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 4750), p2: Offset(4000, 4750), layer: 'WALLS'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 4000, 5000),
      );

      final wallsResult = WallAxisDetector.detect(doc);
      // No glazing across mouth -> GeometricWindowDetector must NOT detect any window
      final windows = GeometricWindowDetector.detect(doc, wallsResult.selectedWallPairs, wallsResult.detectedScale);
      expect(windows.isEmpty, isTrue, reason: 'Unglazed courtyard mouth must NOT be detected as a window opening');

      // Slab detection must NOT bridge straight across X=0 between Y=1500 and Y=3500
      final slabResult = SlabEnvelopeDetector.detect(wallsResult, document: doc);
      expect(slabResult.contours.isNotEmpty, isTrue);

      final contour = slabResult.contours.first;
      // The courtyard is open: there must be contour points entering the courtyard (> X = 500)
      final hasInwardPoints = contour.any((p) => p.dx > 1000 && p.dy > 1400 && p.dy < 3600);
      expect(hasInwardPoints, isTrue,
          reason: 'Slab boundary must follow the perpendicular walls inward into the courtyard instead of bridging across the mouth');
    });

    test('7. Architectural principle: recess WITH glazed vitrina bridges straight along facade axis', () {
      final wallLayer = DxfLayer(name: 'WALLS', colorIndex: 7, isVisible: true);
      final winLayer = DxfLayer(name: 'WINDOWS', colorIndex: 4, isVisible: true);

      final doc = _createTestDoc(
        layers: {'WALLS': wallLayer, 'WINDOWS': winLayer},
        entities: const [
          // Left facade wall at X=0..250, Y from 0 to 1500
          DxfLine(p1: Offset(0, 0), p2: Offset(0, 1500), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 0), p2: Offset(250, 1500), layer: 'WALLS'),
          // Left perpendicular return wall extending inward at Y=1250..1500
          DxfLine(p1: Offset(250, 1250), p2: Offset(2000, 1250), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 1500), p2: Offset(2000, 1500), layer: 'WALLS'),
          // Back wall of recess at X=2000..2250, Y from 1250 to 3750
          DxfLine(p1: Offset(2000, 1250), p2: Offset(2000, 3750), layer: 'WALLS'),
          DxfLine(p1: Offset(2250, 1250), p2: Offset(2250, 3750), layer: 'WALLS'),
          // Right perpendicular return wall extending inward at Y=3500..3750
          DxfLine(p1: Offset(250, 3500), p2: Offset(2000, 3500), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 3750), p2: Offset(2000, 3750), layer: 'WALLS'),
          // Right facade wall at X=0..250, Y from 3500 to 5000
          DxfLine(p1: Offset(0, 3500), p2: Offset(0, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 3500), p2: Offset(250, 5000), layer: 'WALLS'),
          // Closing outer walls
          DxfLine(p1: Offset(0, 0), p2: Offset(4000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 250), p2: Offset(4000, 250), layer: 'WALLS'),
          DxfLine(p1: Offset(4000, 0), p2: Offset(4000, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(3750, 0), p2: Offset(3750, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 5000), p2: Offset(4000, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 4750), p2: Offset(4000, 4750), layer: 'WALLS'),

          // Glazed vitrina spanning the facade opening at X=125, Y from 1500 to 3500
          DxfLine(p1: Offset(80, 1500), p2: Offset(80, 3500), layer: 'WINDOWS'),
          DxfLine(p1: Offset(170, 1500), p2: Offset(170, 3500), layer: 'WINDOWS'),
          DxfLine(p1: Offset(50, 1500), p2: Offset(200, 1500), layer: 'WINDOWS'),
          DxfLine(p1: Offset(50, 3500), p2: Offset(200, 3500), layer: 'WINDOWS'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 4000, 5000),
      );

      final wallsResult = WallAxisDetector.detect(doc);
      // Glazed vitrina across recess -> GeometricWindowDetector DOES detect it
      final windows = GeometricWindowDetector.detect(doc, wallsResult.selectedWallPairs, wallsResult.detectedScale);
      expect(windows.isNotEmpty, isTrue, reason: 'Glazed vitrina across recess mouth must be detected');

      final slabResult = SlabEnvelopeDetector.detect(wallsResult, document: doc);
      expect(slabResult.contours.isNotEmpty, isTrue);

      // The glazed vitrina bridges the facade: contour remains straight along the west facade (X ~ 0)
      final contour = slabResult.contours.first;
      for (int i = 0; i < contour.length; i++) {
        final p1 = contour[i];
        final p2 = contour[(i + 1) % contour.length];
        final isOrthogonal = (p1.dx - p2.dx).abs() < 1e-2 || (p1.dy - p2.dy).abs() < 1e-2;
        expect(isOrthogonal, isTrue, reason: 'Slab boundary edge must be strictly orthogonal across vitrina');
      }
    });
  });
}
