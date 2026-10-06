import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';

WallAxisDetectionResult walls(List<List<Offset>> paths, {double scale = 1}) {
  final pairs = <WallPairCandidate>[];
  for (final path in paths) {
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1] * scale, b = path[i] * scale;
      final d = b - a;
      final normal = Offset(-d.dy, d.dx) / d.distance * (125 * scale);
      WallSegment face(Offset n) => WallSegment(
        start: a + n,
        end: b + n,
        angleRad: math.atan2(d.dy, d.dx),
        offsetFromOrigin: 0,
        length: d.distance,
        sourceLayer: 'walls',
      );
      pairs.add(
        WallPairCandidate(
          segmentA: face(normal),
          segmentB: face(-normal),
          perpendicularDistance: 250 * scale,
          overlapLength: d.distance,
          centerlineStart: a,
          centerlineEnd: b,
        ),
      );
    }
  }
  return WallAxisDetectionResult(
    evaluatedGroups: const [],
    detectedScale: scale,
    detectedUnitName: 'test',
    targetThicknessMm: 250,
    rawCenterlines: const [],
    bridgedCenterlines: const [],
    snappedCenterlines: const [],
    wallContourSegments: const [],
    selectedWallPairs: pairs,
  );
}

List<Offset> rectangle(double x, double y, double w, double h) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x + w, y + h),
  Offset(x, y + h),
  Offset(x, y),
];

double area(List<Offset> ring) {
  var sum = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i], b = ring[(i + 1) % ring.length];
    sum += a.dx * b.dy - a.dy * b.dx;
  }
  return sum.abs() / 2;
}

void main() {
  test('crossing wall prevents an assumed opening', () {
    final result = SlabEnvelopeDetector.detect(
      walls([
        const [Offset(0, 0), Offset(4000, 0)],
        const [Offset(5000, 0), Offset(10000, 0)],
        const [Offset(4500, -1000), Offset(4500, 1000)],
      ]),
    );
    expect(result.assumedGaps, isEmpty);
  });
  test('parallel offset wall ends are not joined', () {
    final result = SlabEnvelopeDetector.detect(
      walls([
        const [Offset(0, 0), Offset(4000, 0)],
        const [Offset(5000, 100), Offset(10000, 100)],
      ]),
    );
    expect(result.assumedGaps, isEmpty);
  });
  test('region budget explicitly reports skipped work', () {
    final result = SlabEnvelopeDetector.detect(
      walls([for (var i = 0; i < 65; i++) rectangle(i * 20000, 0, 2000, 2000)]),
    );
    expect(result.regionReports, hasLength(64));
    expect(result.skippedRegions, 1);
    expect(result.diagnostics, contains('regionLimitReached'));
  });
  List<List<Offset>> facadeGap(double gap) => [
    const [Offset(0, 0), Offset(4000, 0)],
    [
      Offset(4000 + gap, 0),
      const Offset(10000, 0),
      const Offset(10000, 8000),
      const Offset(0, 8000),
      Offset.zero,
    ],
  ];
  test('matching facade gap yields a marked hypothesis and baseline', () {
    final result = SlabEnvelopeDetector.detect(walls(facadeGap(1000)));
    expect(result.contours, hasLength(1));
    expect(result.assumedGaps, hasLength(1));
    expect(result.regionReports.single['baselineContours'], isEmpty);
    expect(result.regionReports.single['usesAssumedGaps'], isTrue);
    expect(result.toJson()['version'], 2);
    expect(result.assumedGaps.single.toJson()['confirmedOpening'], isFalse);
  });
  test('wide opening stays unresolved', () {
    final result = SlabEnvelopeDetector.detect(walls(facadeGap(2000)));
    expect(result.assumedGaps, isEmpty);
    expect(result.contours, isEmpty);
  });
  test('return at a gap blocks closure across a recess', () {
    final result = SlabEnvelopeDetector.detect(
      walls([
        ...facadeGap(1000),
        const [Offset(4000, 0), Offset(4000, 1000)],
      ]),
    );
    expect(result.assumedGaps, isEmpty);
  });
  test('distant buildings are analysed at local resolution', () {
    final result = SlabEnvelopeDetector.detect(
      walls([
        rectangle(0, 0, 10000, 8000),
        rectangle(1000000, 1000000, 10000, 8000),
      ]),
    );
    expect(result.contours, hasLength(2));
    expect(result.regionReports, hasLength(2));
    expect(result.cellSize, 25);
  });
  test('hypothesis geometry scales with drawing units', () {
    final mm = SlabEnvelopeDetector.detect(walls(facadeGap(1000)));
    final m = SlabEnvelopeDetector.detect(walls(facadeGap(1000), scale: 0.001));
    expect(m.assumedGaps, hasLength(1));
    expect(
      area(mm.contours.single) / 1e6,
      closeTo(area(m.contours.single), 0.001),
    );
  });
  test(
    'closed walls yield bounded approximate envelope with review metadata',
    () {
      final result = SlabEnvelopeDetector.detect(
        walls([rectangle(0, 0, 10000, 8000)]),
      );
      expect(result.contours, hasLength(1));
      expect(area(result.contours.single), closeTo(10250 * 8250, 2000000));
      expect(result.toJson()['status'], 'needsReview');
      expect(
        result.diagnostics,
        contains('courtyardsAndSlabOpeningsUnclassified'),
      );
    },
  );
  test('open facade is not silently bridged', () {
    final result = SlabEnvelopeDetector.detect(
      walls([
        [
          const Offset(1000, 0),
          const Offset(10000, 0),
          const Offset(10000, 8000),
          const Offset(0, 8000),
          const Offset(0, 0),
        ],
      ]),
    );
    expect(result.contours, isEmpty);
    expect(result.diagnostics, contains('noEnclosedSpace'));
  });
  test('concave recess is retained rather than convex hull', () {
    final result = SlabEnvelopeDetector.detect(
      walls([
        const [
          Offset(0, 0),
          Offset(10000, 0),
          Offset(10000, 4000),
          Offset(4000, 4000),
          Offset(4000, 8000),
          Offset(0, 8000),
          Offset(0, 0),
        ],
      ]),
    );
    expect(result.contours, hasLength(1));
    expect(area(result.contours.single), lessThan(65000000));
    expect(result.contours.single.length, greaterThanOrEqualTo(6));
  });
  test('separate buildings remain separate, isolated wall discarded', () {
    final result = SlabEnvelopeDetector.detect(
      walls([
        rectangle(0, 0, 4000, 4000),
        rectangle(8000, 0, 4000, 4000),
        const [Offset(0, 7000), Offset(12000, 7000)],
      ]),
    );
    expect(result.contours, hasLength(2));
  });
  test('millimetre and metre inputs produce equivalent areas', () {
    final paths = [rectangle(0, 0, 10000, 8000)];
    final mm = SlabEnvelopeDetector.detect(walls(paths));
    final m = SlabEnvelopeDetector.detect(walls(paths, scale: 0.001));
    expect(
      area(mm.contours.single) / 1e6,
      closeTo(area(m.contours.single), 0.001),
    );
  });
  test(
    'courtyard remains explicitly unclassified, not a confirmed filled slab',
    () {
      final result = SlabEnvelopeDetector.detect(
        walls([
          rectangle(0, 0, 10000, 10000),
          rectangle(3000, 3000, 4000, 4000),
        ]),
      );
      expect(result.enclosedRegionCount, 2);
      expect(result.toJson()['status'], 'needsReview');
      expect(
        result.diagnostics,
        contains('courtyardsAndSlabOpeningsUnclassified'),
      );
    },
  );
  test('large extents refuse coarse grid which could erase thin walls', () {
    final result = SlabEnvelopeDetector.detect(
      walls([rectangle(0, 0, 1000000, 1000000)]),
    );
    expect(result.contours, isEmpty);
    expect(result.diagnostics, contains('drawingTooLargeSelectSmallerRegion'));
  });
  test('empty and invalid scale do not create geometry', () {
    expect(
      SlabEnvelopeDetector.detect(WallAxisDetectionResult.empty).contours,
      isEmpty,
    );
    expect(
      SlabEnvelopeDetector.detect(walls([], scale: double.nan)).diagnostics,
      contains('invalidScale'),
    );
  });
  test('rotation and reversed wall directions preserve a closed proposal', () {
    final angle = math.pi / 6;
    final path = rectangle(0, 0, 10000, 8000).reversed
        .map(
          (p) => Offset(
            p.dx * math.cos(angle) - p.dy * math.sin(angle) + 100000,
            p.dx * math.sin(angle) + p.dy * math.cos(angle) - 50000,
          ),
        )
        .toList();
    final result = SlabEnvelopeDetector.detect(walls([path]));
    expect(result.contours, hasLength(1));
    expect(area(result.contours.single), closeTo(10250 * 8250, 2500000));
  });
  test('local facade projection is retained for review', () {
    final result = SlabEnvelopeDetector.detect(
      walls([
        const [
          Offset(0, 0),
          Offset(4000, 0),
          Offset(4000, -500),
          Offset(5000, -500),
          Offset(5000, 0),
          Offset(10000, 0),
          Offset(10000, 8000),
          Offset(0, 8000),
          Offset(0, 0),
        ],
      ]),
    );
    expect(result.contours, hasLength(1));
    expect(
      result.contours.single.map((p) => p.dy).reduce(math.min),
      lessThan(-600),
    );
  });
}
