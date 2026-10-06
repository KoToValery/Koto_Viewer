import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_column_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_underlay_filter.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';

void main() {
  test('Investigate 0.dwg / 0.dxf geometry, layers, walls, columns, stairs, and axes', () async {
    final file = File('test_files/0.dxf');
    expect(file.existsSync(), isTrue);

    final content = UniversalEncodingService.decodeBytes(file.readAsBytesSync());
    final doc = DxfParser.parseString(content);

    print('=== ALL LAYERS IN 0.DXF ===');
    for (final l in doc.layers.values) {
      final isWhite = StructuralUnderlayFilter.isWhiteLayer(l);
      final isNeg = StructuralUnderlayFilter.isNegativeKeyword(l.name);
      final isStruct = StructuralUnderlayFilter.matchesStructuralKeyword(l.name);
      final thickness = StructuralUnderlayFilter.getLayerThickness(l, doc.entities.where((e) => e.layer == l.name).toList());
      print('Layer "${l.name}": colorIndex=${l.colorIndex}, thick=$thickness, isWhite=$isWhite, isNeg=$isNeg, isStruct=$isStruct');
    }

    final filteredLayers = StructuralUnderlayFilter.filterLayers(
      layers: doc.layers.values,
      entities: doc.entities,
      blocks: doc.blocks,
    );
    print('\n=== UNDERLAY FILTER RESULT ===');
    print('Filtered layers: $filteredLayers');

    print('\n=== LAYER ОСИ ENTITIES ===');
    final osiEntities = doc.entities.where((e) => e.layer.toLowerCase().contains('ос')).toList();
    print('Entities on layer оси: count=${osiEntities.length}');
    for (final e in osiEntities) {
      if (e is DxfLine) {
        final angle = (e.p2 - e.p1).direction * 180 / 3.141592653589793;
        print('  Line: ${e.p1} -> ${e.p2}, len=${(e.p2 - e.p1).distance.toStringAsFixed(1)}, angle=${angle.toStringAsFixed(1)} deg');
      } else if (e is DxfText) {
        print('  Text: "${e.text}" at ${e.insertPoint}');
      } else if (e is DxfMText) {
        print('  MText: "${e.cleanText}" at ${e.insertPoint}');
      } else if (e is DxfCircle) {
        print('  Circle at ${e.center}, r=${e.radius}');
      } else {
        print('  Entity: ${e.typeName}');
      }
    }

    final docAxes = WallAxisDetector.extractGridAxesFromDocument(doc);
    print('extractGridAxesFromDocument: ${docAxes.length} axes found');

    final wallsResult = WallAxisDetector.detect(doc);

    // subsequent code
    print('\n=== WALL AXIS DETECTOR RESULT ===');
    print('Detected scale: ${wallsResult.detectedScale} (${wallsResult.detectedUnitName})');
    print('Target thickness: ${wallsResult.targetThicknessMm} mm');
    print('Best group: ${wallsResult.bestGroup?.layerName}, pairCount=${wallsResult.bestGroup?.pairCount}, score=${wallsResult.bestGroup?.score}');

    print('\n--- Evaluated Groups ---');
    for (final g in wallsResult.evaluatedGroups) {
      print('  Group: "${g.layerName}", color=${g.colorIndex}, pairs=${g.pairCount}, len=${g.totalOverlapLength.toStringAsFixed(1)}m, score=${g.score.toStringAsFixed(1)}');
    }

    print('\n--- Active Selected Wall Pairs ---');
    print('Selected pairs count: ${wallsResult.selectedWallPairs.length}');
    final pairsByLayer = <String, int>{};
    for (final p in wallsResult.selectedWallPairs) {
      pairsByLayer[p.segmentA.sourceLayer] = (pairsByLayer[p.segmentA.sourceLayer] ?? 0) + 1;
    }
    print('Pairs by layer: $pairsByLayer');

    print('\n--- Snapped Centerlines (Axes) ---');
    print('Snapped centerlines count: ${wallsResult.snappedCenterlines.length}');
    for (int i = 0; i < wallsResult.snappedCenterlines.length; i++) {
      final (p1, p2) = wallsResult.snappedCenterlines[i];
      final dx = (p2.dx - p1.dx).abs();
      final dy = (p2.dy - p1.dy).abs();
      final angle = (p2 - p1).direction * 180 / 3.141592653589793;
      print('  Axis $i: $p1 -> $p2, len=${(p2 - p1).distance.toStringAsFixed(1)}, angle=${angle.toStringAsFixed(1)} deg');
    }

    print('\n--- Detected Columns ---');
    print('Detected columns count: ${wallsResult.detectedColumns.length}');
    for (int i = 0; i < wallsResult.detectedColumns.length; i++) {
      final col = wallsResult.detectedColumns[i];
      print('  Col $i: layer="${col.sourceLayer}", bounds=${col.bounds}, isShear=${col.isShearWall}');
    }

    print('\n--- Slab Envelope ---');
    final slabResult = SlabEnvelopeDetector.detect(wallsResult, document: doc);
    print('Slab contours count: ${slabResult.contours.length}');
    print('Diagnostics: ${slabResult.diagnostics}');
    print('Assumed gaps: ${slabResult.assumedGaps.length}');
    for (final r in slabResult.regionReports) {
      print('  Region ${r['index']}: walls=${r['wallCount']}, contours=${r['contourCount']}, diag=${r['diagnostics']}');
    }
  });
}
