import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_seed_generator.dart';

bool containsPoint(double x, double y, List ring) {
  var inside = false;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i] as List, b = ring[(i + 1) % ring.length] as List;
    if ((a[1] > y) != (b[1] > y) &&
        x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) {
      inside = !inside;
    }
  }
  return inside;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const path = String.fromEnvironment('BIM_C_DWG');
  test('C DWG envelope regression', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
    final result = await BimUnderlayConversionService.convert(File(path));
    addTearDown(result.dispose);
    final pure = await KcadService.loadKcadFile(result.pureKcadFile);
    final doc = await KcadService.loadKcadFile(result.kcadFile);
    final walls = WallAxisDetector.detect(pure);
    final report = BimUnderlayMetadata.read(doc)!['slabEnvelope'];
    final seeds = SlabSeedGenerator.generate(
      metadata: BimUnderlayMetadata.read(doc)!, document: doc,
      storeyId: 'c', existing: [], unitsPerMeter: walls.detectedScale * 1000,
      thickness: .20,
    );
    expect(seeds.where((s) => s.id.contains('_main_')).length, 1);
    expect(seeds.where((s) => s.id.contains('_projection_')).length, 7);
    await File(
      '${Directory.systemTemp.path}/koto_C_analysis.json',
    ).writeAsString(
      jsonEncode({
        'scale': walls.detectedScale,
        'projections': BimUnderlayMetadata.read(doc)!['slabProjections'],
        'report': report,
        'lines': pure.entities
            .whereType<DxfLine>()
            .map(
              (e) => {
                'a': [e.p1.dx, e.p1.dy],
                'b': [e.p2.dx, e.p2.dy],
                'layer': e.layer,
              },
            )
            .toList(),
        'pairs': walls.selectedWallPairs
            .map(
              (p) => {
                'a': [
                  p.segmentA.start.dx,
                  p.segmentA.start.dy,
                  p.segmentA.end.dx,
                  p.segmentA.end.dy,
                ],
                'b': [
                  p.segmentB.start.dx,
                  p.segmentB.start.dy,
                  p.segmentB.end.dx,
                  p.segmentB.end.dy,
                ],
              },
            )
            .toList(),
      }),
    );
    expect(report['contours'], isNotEmpty);
    final ring = (report['contours'] as List).single as List;
    for (final point in [
      [-1707.0, -34.0],
      [1115.0, -34.0],
      [-1707.0, 1238.0],
      [1115.0, 1238.0],
      [-295.0, -184.0],
    ]) {
      expect(
        containsPoint(point[0], point[1], ring),
        isTrue,
        reason: 'corner or T-junction notch at $point',
      );
    }
    final projections =
        BimUnderlayMetadata.read(doc)!['slabProjections'] as List;
    expect(projections.where((p) => p['kind'] == 'loggiaCandidate').length, 2);
    for (final point in [
      [-389.0, -110.0],
      [-202.0, -110.0],
    ]) {
      expect(
        projections.any(
          (p) =>
              p['kind'] == 'loggiaCandidate' &&
              containsPoint(point[0], point[1], p['contour'] as List),
        ),
        isTrue,
      );
    }
    // Every output edge follows an observed wall-face support line (0.1 mm).
    final faces = walls.selectedWallPairs
        .expand((p) => [p.segmentA, p.segmentB])
        .toList();
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i] as List, b = ring[(i + 1) % ring.length] as List;
      final x = (a[0] + b[0]) / 2, y = (a[1] + b[1]) / 2;
      final supports = [
        ...faces.map((f) => (f.start, f.end)),
        ...walls.wallContourSegments,
        ...walls.closureSegments,
      ];
      final best = supports
          .where((f) => (f.$2 - f.$1).distance > 0)
          .map((f) {
            final d = f.$2 - f.$1;
            return ((x - f.$1.dx) * d.dy - (y - f.$1.dy) * d.dx).abs() /
                d.distance;
          })
          .reduce((a, b) => a < b ? a : b);
      expect(
        best / walls.detectedScale,
        lessThan(0.1),
        reason: 'offset at edge $i',
      );
    }
    for (final p in projections) {
      expect(p['sourceLayer'], '2D Drafting - General');
    }
    // ignore: avoid_print
    print('C projections: ${projections.length}');
    // ignore: avoid_print
    print(
      'C: scale=${walls.detectedScale}; contours=${(report['contours'] as List).length}',
    );
  }, skip: path.isEmpty);
}
