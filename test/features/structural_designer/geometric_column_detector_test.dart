import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_column_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';

void main() {
  test('Archicad export detects all columns/shear walls and seals slab envelope', () async {
    final file = File('test_files/Archicad_export.dxf');
    expect(file.existsSync(), isTrue, reason: 'Archicad_export.dxf must exist');

    final content = UniversalEncodingService.decodeBytes(file.readAsBytesSync());
    final doc = DxfParser.parseString(content);

    final wallsResult = WallAxisDetector.detect(doc);
    print('Detected scale: ${wallsResult.detectedScale}');
    print('Wall pairs: ${wallsResult.selectedWallPairs.length}');
    print('Wall contour segments: ${wallsResult.wallContourSegments.length}');
    expect(wallsResult.detectedColumns.length, equals(18));
    expect(wallsResult.detectedColumns.every((c) => c.sourceLayer == 'колони'), isTrue);

    final slabResult = SlabEnvelopeDetector.detect(wallsResult, document: doc);
    print('Slab envelope contours: ${slabResult.contours.length}');
    print('Slab envelope diagnostics: ${slabResult.diagnostics}');
    print('Slab assumed gaps: ${slabResult.assumedGaps.length}');
    print('Region reports: ${slabResult.regionReports.length}');
    for (final r in slabResult.regionReports) {
      print('  Region ${r['index']}: walls=${r['wallCount']}, contours=${r['contourCount']}, diag=${r['diagnostics']}, usesAssumedGaps=${r['usesAssumedGaps']}');
    }
    expect(slabResult.contours.isNotEmpty, isTrue);
    final ring = slabResult.contours.first;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in ring) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    print('Contour 0 bounds: ($minX, $minY) to ($maxX, $maxY)');
    expect(minX, closeTo(0.0, 1.0));
    expect(minY, closeTo(0.0, 1.0));
    expect(maxX, closeTo(902.0, 5.0));
    expect(maxY, closeTo(1434.0, 5.0));
  });
}
