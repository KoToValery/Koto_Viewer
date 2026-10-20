import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_layout.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';

const left = ArchitectWall(
  id: 'left',
  startPoint: Offset(0, 0),
  endPoint: Offset(0, 4),
  thickness: .35,
  insulationThicknessOverride: .1,
);
const right = ArchitectWall(
  id: 'right',
  startPoint: Offset(6, 0),
  endPoint: Offset(6, 4),
  thickness: .45,
  insulationThicknessOverride: .2,
  exteriorSide: WallExteriorSide.right,
);
const front = ArchitectWall(
  id: 'front',
  startPoint: Offset(0, 0),
  endPoint: Offset(6, 0),
  thickness: .37,
  insulationThicknessOverride: .12,
  exteriorSide: WallExteriorSide.right,
  windows: [
    ArchitectWindow(
      id: 'w',
      wallId: 'front',
      offsetRatio: 1 / 3,
      width: 1.2,
      uuid: 'w',
    ),
  ],
);
const storey = ArchitectStorey(
  id: 's',
  name: 'Floor',
  walls: [left, right, front],
);
const axes = [
  StructuralGridAxis(
    id: 'a',
    name: '1',
    start: Offset(0, -3),
    end: Offset(0, 5),
  ),
  StructuralGridAxis(
    id: 'b',
    name: '2',
    start: Offset(6, -3),
    end: Offset(6, 5),
  ),
];
ArchitectDimension dimension({bool finish = true}) =>
    ArchitectDimensionChain.build(
      id: 'd',
      direction: const Offset(1, 0),
      offset: -.8,
      anchors: [
        ArchitectDimensionAnchor(point: Offset(finish ? -.225 : -.125, -.245)),
        const ArchitectDimensionAnchor(point: Offset(3, -.245)),
        ArchitectDimensionAnchor(point: Offset(finish ? 6.325 : 6.125, -.245)),
      ],
    );
List<double> lengths(DimensionTier row) => [
  for (final s in row.segments) (s.$2 - s.$1).distance,
];
void expectLengths(DimensionTier row, List<double> expected) =>
    expect(lengths(row), orderedEquals(expected.map((v) => closeTo(v, 1e-8))));

void main() {
  test(
    'Small insulation labels remain on their row and clear the end ticks',
    () {
      final rows = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension(),
        scale: 100,
        storey: storey,
      );
      final overall = rows[2];
      final first = ArchitectDimensionLayout.segmentTextCenter(
        tier: overall,
        segmentIndex: 0,
        direction: const Offset(1, 0),
        textWidth: .24,
        clearance: .06,
      );
      final last = ArchitectDimensionLayout.segmentTextCenter(
        tier: overall,
        segmentIndex: 2,
        direction: const Offset(1, 0),
        textWidth: .24,
        clearance: .06,
      );
      expect(first.dx + .12, lessThan(overall.line.$1.dx));
      expect(last.dx - .12, greaterThan(overall.line.$2.dx));
      expect(first.dy, overall.line.$1.dy);
      expect(last.dy, overall.line.$1.dy);
      final middle = ArchitectDimensionLayout.segmentTextCenter(
        tier: overall,
        segmentIndex: 1,
        direction: const Offset(1, 0),
        textWidth: .5,
        clearance: .06,
      );
      expect(middle, (overall.segments[1].$1 + overall.segments[1].$2) / 2);
    },
  );
  test(
    'Finish picks use core for opening and wall rows, with separate end insulation on overall',
    () {
      final dim = dimension();
      final rows = ArchitectDimensionLayout.layoutTiers(
        dimension: dim,
        scale: 100,
        storey: storey,
        gridAxes: axes,
      );
      expect(rows.map((r) => r.tierIndex), [1, 2, 3, 4]);
      expectLengths(rows[0], [1.525, 1.2, 3.525]);
      expectLengths(rows[1], [3.125, 3.125]);
      expectLengths(rows[2], [.1, 6.25, .2]);
      expectLengths(rows[3], [6]);
      expect(rows[0].points.first.dx, closeTo(-.125, 1e-9));
      expect(rows[1].points.last.dx, closeTo(6.125, 1e-9));
      expect(rows[2].points.first.dx, closeTo(-.225, 1e-9));
      expect(rows[2].points.last.dx, closeTo(6.325, 1e-9));
      expect(dim.anchors.first.point.dx, -.225);
      expect(rows.first.line.$1.dy, dim.lineStart.dy);
    },
  );

  test(
    'Core and finish selections produce identical rows without a duplicate overall span',
    () {
      final fromFinish = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension(),
        scale: 100,
        storey: storey,
      );
      final fromCore = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension(finish: false),
        scale: 100,
        storey: storey,
      );
      expect(fromCore.map((r) => r.line), fromFinish.map((r) => r.line));
      for (var i = 0; i < fromCore.length; i++) {
        expectLengths(fromCore[i], lengths(fromFinish[i]));
      }
      expect(fromCore[2].segments, hasLength(3));
    },
  );

  test('No insulation adds no zero-size or duplicated segments', () {
    final walls = [
      left.copyWith(thickness: .25, insulationThicknessOverride: 0),
      right.copyWith(thickness: .25, insulationThicknessOverride: 0),
      front,
    ];
    final rows = ArchitectDimensionLayout.layoutTiers(
      dimension: dimension(finish: false),
      scale: 100,
      storey: storey.copyWith(walls: walls),
    );
    expectLengths(rows[2], [6.25]);
    final oneSide = ArchitectDimensionLayout.layoutTiers(
      dimension: dimension(finish: false),
      scale: 100,
      storey: storey.copyWith(walls: [walls[0], right, front]),
    );
    expectLengths(oneSide[2], [6.25, .2]);
  });

  test('Insulation thickness updates only the small overall segments', () {
    final walls = [
      left.copyWith(thickness: .43, insulationThicknessOverride: .18),
      right.copyWith(thickness: .5, insulationThicknessOverride: .25),
      front,
    ];
    final rows = ArchitectDimensionLayout.layoutTiers(
      dimension: dimension(),
      scale: 100,
      storey: storey.copyWith(walls: walls),
    );
    expectLengths(rows[0], [1.525, 1.2, 3.525]);
    expectLengths(rows[1], [3.125, 3.125]);
    expectLengths(rows[2], [.18, 6.25, .25]);
  });

  test(
    'Core bounds work at wall junctions even when picks belong to the parallel facade',
    () {
      final dim = dimension().copyWith(
        anchors: [
          for (final a in dimension().anchors)
            ArchitectDimensionAnchor(
              point: a.point,
              elementId: 'front',
              feature: 'wallFace',
              ratio: a.point.dx / 6,
              side: .98,
            ),
        ],
      );
      final rows = ArchitectDimensionLayout.layoutTiers(
        dimension: dim,
        scale: 100,
        storey: storey,
      );
      expectLengths(rows[0], [1.525, 1.2, 3.525]);
      expectLengths(rows[2], [.1, 6.25, .2]);
    },
  );

  test(
    'Core measurement and insulation segments stay fixed through rotation, reverse picks and zoom',
    () {
      for (final angle in [0.0, math.pi / 2, .61]) {
        Offset rotate(Offset p) => Offset(
          p.dx * math.cos(angle) - p.dy * math.sin(angle),
          p.dx * math.sin(angle) + p.dy * math.cos(angle),
        );
        final walls = [
          for (final w in storey.walls)
            w.copyWith(
              startPoint: rotate(w.startPoint),
              endPoint: rotate(w.endPoint),
            ),
        ];
        for (final reverse in [false, true]) {
          final dim = ArchitectDimensionChain.build(
            id: 'd',
            anchors: [
              for (final a in dimension().anchors) a.at(rotate(a.point)),
            ],
            direction: rotate(Offset(reverse ? -1 : 1, 0)),
            offset: reverse ? .8 : -.8,
          );
          for (final zoom in [10.0, 100.0, 300.0]) {
            final rows = ArchitectDimensionLayout.layoutTiers(
              dimension: dim,
              scale: zoom,
              storey: storey.copyWith(walls: walls),
            );
            expectLengths(
              rows[0],
              reverse ? [3.525, 1.2, 1.525] : [1.525, 1.2, 3.525],
            );
            expectLengths(rows[1], [3.125, 3.125]);
            expectLengths(rows[2], reverse ? [.2, 6.25, .1] : [.1, 6.25, .2]);
          }
        }
      }
    },
  );

  test('Interior dimensions retain their selected faces', () {
    final dim = dimension().copyWith(style: ArchitectDimensionStyle.interior);
    final rows = ArchitectDimensionLayout.layoutTiers(
      dimension: dim,
      scale: 100,
      storey: storey,
    );
    expect(rows, hasLength(1));
    expectLengths(rows.single, [3.225, 3.325]);
  });
}
