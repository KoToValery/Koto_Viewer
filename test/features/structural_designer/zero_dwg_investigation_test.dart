import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_underlay_filter.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';

void main() {
  test('0.dwg / 0.dxf regression test: clean walls, no insulation/stairs/lines clutter, authentic axes and slab envelope', () async {
    final file = File('test_files/0.dxf');
    expect(file.existsSync(), isTrue, reason: 'test_files/0.dxf must exist');

    final content = UniversalEncodingService.decodeBytes(file.readAsBytesSync());
    final doc = DxfParser.parseString(content);

    // 1. Structural Underlay Filter Verification: isolates cut elements
    final filteredLayers = StructuralUnderlayFilter.filterLayers(
      layers: doc.layers.values,
      entities: doc.entities,
      blocks: doc.blocks,
    );
    expect(filteredLayers.contains('стени'), isTrue);
    expect(filteredLayers.contains('колони'), isTrue);
    expect(filteredLayers.contains('стълби'), isFalse, reason: 'Stairs must be excluded from structural underlay');
    expect(filteredLayers.contains('линии'), isFalse, reason: 'Generic lines/borders must be excluded');
    expect(filteredLayers.contains('обзавеждане'), isFalse, reason: 'Furniture must be excluded');
    expect(filteredLayers.contains('парапет'), isFalse, reason: 'Railings must be excluded');
    expect(filteredLayers.contains('котировки'), isFalse, reason: 'Elevation levels must be excluded');

    // 2. Wall and Column Detection
    final wallsResult = WallAxisDetector.detect(doc);
    expect(wallsResult.hasWallsFound, isTrue);

    // 3. Autonomous Structural Grid Axis Generation along detected walls
    // The program itself generates clean orthogonal structural axes from found wall centerlines.
    final generatedAxes = WallAxisDetector.convertToStructuralGridAxes(
      wallsResult.snappedCenterlines,
      scale: wallsResult.detectedScale,
      isBulgarian: false,
      collinearToleranceMm: 120.0,
      minTotalWallLengthM: 0.80,
    );
    expect(generatedAxes.isNotEmpty, isTrue, reason: 'Axes must be generated from detected walls');

    // Verify all generated axes are strictly orthogonal (vertical or horizontal) - NO chaotic angles!
    for (final axis in generatedAxes) {
      final dx = (axis.end.dx - axis.start.dx).abs();
      final dy = (axis.end.dy - axis.start.dy).abs();
      final isOrthogonal = dx < 1e-3 || dy < 1e-3;
      expect(isOrthogonal, isTrue, reason: 'Generated axis "${axis.name}" must be strictly orthogonal (dx=$dx, dy=$dy)');
    }

    // Verify NO clutter layers in selected wall pairs
    final selectedLayers = wallsResult.selectedWallPairs.map((p) => p.segmentA.sourceLayer).toSet();
    expect(selectedLayers, contains('стени'));
    expect(selectedLayers, contains('колони'));
    expect(selectedLayers.contains('линии'), isFalse, reason: 'Generic lines must NOT be selected as walls');
    expect(selectedLayers.contains('стълби'), isFalse, reason: 'Stairs must NOT be selected as walls');
    expect(selectedLayers.contains('обзавеждане'), isFalse, reason: 'Furniture must NOT be selected as walls');

    // Verify NO insulation (color 30) selected as walls
    final selectedColorsOnWalls = wallsResult.selectedWallPairs
        .where((p) => p.segmentA.sourceLayer == 'стени')
        .map((p) => p.segmentA.sourceColorIndex)
        .toSet();
    expect(selectedColorsOnWalls.contains(30), isFalse, reason: 'Thermal insulation (color 30) must be excluded from wall pairs');
    expect(selectedColorsOnWalls, contains(7));

    // Exactly 45 masonry wall pairs and 17 column/shear wall pairs
    final wallPairsByLayer = <String, int>{};
    for (final p in wallsResult.selectedWallPairs) {
      wallPairsByLayer[p.segmentA.sourceLayer] = (wallPairsByLayer[p.segmentA.sourceLayer] ?? 0) + 1;
    }
    expect(wallPairsByLayer['стени'], equals(45));
    expect(wallPairsByLayer['колони'], equals(17));
    expect(wallsResult.selectedWallPairs.length, equals(62));

    // 4. Slab Envelope Detection
    final slabResult = SlabEnvelopeDetector.detect(wallsResult, document: doc);
    expect(slabResult.contours.isNotEmpty, isTrue, reason: 'Slab envelope contour must be successfully detected');
    expect(slabResult.diagnostics.contains('drawingTooLargeSelectSmallerRegion'), isFalse,
        reason: 'Drawing must not be flagged as too large when border lines are excluded');
    expect(slabResult.contours.first.length, greaterThanOrEqualTo(10), reason: 'Building perimeter must have a substantial polygon');
  });
}
