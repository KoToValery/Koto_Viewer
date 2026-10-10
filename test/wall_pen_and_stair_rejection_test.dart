import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';

List<DxfEntity> pair(double y, {double? pen, String layer = 'plan'}) => [
  DxfLine(p1: Offset(0, y), p2: Offset(4000, y), layer: layer, lineWeight: pen),
  DxfLine(
    p1: Offset(0, y + 250),
    p2: Offset(4000, y + 250),
    layer: layer,
    lineWeight: pen,
  ),
];
DxfDocument doc(
  List<DxfEntity> entities, {
  Map<String, DxfLayer>? layers,
  Map<String, DxfBlock> blocks = const {},
}) => DxfDocument(
  entities: entities,
  layers: layers ?? {'plan': DxfLayer(name: 'plan')},
  blocks: blocks,
  headerVars: {},
  bounds: const Rect.fromLTWH(0, 0, 6000, 6000),
  entityStats: {},
);
void main() {
  for (final pen in [.20, .25, .30]) {
    test(
      'thin treads on the same layer cannot become walls alongside $pen mm cut lines',
      () {
        final d = doc([...pair(0, pen: pen), ...pair(2000, pen: .13)]);
        final r = WallAxisDetector.detect(d, forceScaleFactor: 1);
        expect(r.hasWallsFound, isTrue);
        expect(r.selectedWallPairs, hasLength(1));
        expect(
          r.selectedWallPairs.single.segmentA.lineweight,
          closeTo(pen, 1e-8),
        );
        expect(
          r.selectedWallPairs.single.centerlineStart.dy,
          closeTo(125, 1e-8),
        );
      },
    );
  }
  test('explicit hairlines never inherit a thick layer pen', () {
    final d = doc(
      [...pair(0), ...pair(2000, pen: 0)],
      layers: {'plan': DxfLayer(name: 'plan', lineweight: .30)},
    );
    final r = WallAxisDetector.detect(d, forceScaleFactor: 1);
    expect(r.selectedWallPairs, hasLength(1));
    expect(r.selectedWallPairs.single.centerlineStart.dy, closeTo(125, 1e-8));
  });
  test('ByLayer block children keep their thin pen despite a thick INSERT', () {
    final d = doc(
      [
        ...pair(0, pen: .30),
        const DxfInsert(
          blockName: 'detail',
          insertPoint: Offset.zero,
          layer: 'plan',
          lineWeight: .50,
        ),
      ],
      layers: {
        'plan': DxfLayer(name: 'plan'),
        'detail': DxfLayer(name: 'detail', lineweight: .13),
      },
      blocks: {
        'detail': DxfBlock(
          name: 'detail',
          entities: pair(2000, layer: 'detail'),
        ),
      },
    );
    final r = WallAxisDetector.detect(d, forceScaleFactor: 1);
    expect(r.selectedWallPairs, hasLength(1));
    expect(r.evaluatedGroups.any((g) => g.layerName == 'detail'), isFalse);
  });
  test(
    'regular anonymous treads leave no false end walls when pen data is absent',
    () {
      final d = doc([
        for (var i = 0; i < 6; i++)
          DxfLine(
            p1: Offset(0, 2000 + i * 250),
            p2: Offset(1200, 2000 + i * 250),
            layer: 'plan',
          ),
      ]);
      final r = WallAxisDetector.detect(d, forceScaleFactor: 1);
      expect(r.hasWallsFound, isFalse);
      expect(r.selectedWallPairs, isEmpty);
    },
  );
}
