import 'dart:ui' show Rect;
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_projection_detector.dart';

WallPairCandidate pair(Offset a, Offset b, Offset c, Offset d) {
  final u = (b - a) / (b - a).distance, n = Offset(-u.dy, u.dx);
  double dot(Offset p) => (p - a).dx * u.dx + (p - a).dy * u.dy;
  final offset = (c - a).dx * n.dx + (c - a).dy * n.dy;
  final lo = math.max(0.0, math.min(dot(c), dot(d))),
      hi = math.min((b - a).distance, math.max(dot(c), dot(d)));
  WallSegment segment(Offset x, Offset y) => WallSegment(
    start: x,
    end: y,
    angleRad: math.atan2(u.dy, u.dx),
    offsetFromOrigin: 0,
    length: (y - x).distance,
    sourceLayer: 'walls',
  );
  return WallPairCandidate(
    segmentA: segment(a, b),
    segmentB: segment(c, d),
    perpendicularDistance: offset.abs(),
    overlapLength: hi - lo,
    centerlineStart: a + u * lo + n * offset / 2,
    centerlineEnd: a + u * hi + n * offset / 2,
  );
}

WallAxisDetectionResult rectangle({bool junction = false, double angle = 0}) {
  Offset tr(Offset p) => Offset(
    p.dx * math.cos(angle) - p.dy * math.sin(angle),
    p.dx * math.sin(angle) + p.dy * math.cos(angle),
  );
  final faces = <List<Offset>>[
    if (!junction)
      const [
        Offset(0, 0),
        Offset(10000, 0),
        Offset(250, 250),
        Offset(9750, 250),
      ],
    if (junction) ...[
      const [
        Offset(0, 0),
        Offset(10000, 0),
        Offset(250, 250),
        Offset(4875, 250),
      ],
      const [
        Offset(0, 0),
        Offset(10000, 0),
        Offset(5125, 250),
        Offset(9750, 250),
      ],
      const [
        Offset(4875, 250),
        Offset(4875, 7750),
        Offset(5125, 250),
        Offset(5125, 7750),
      ],
    ],
    const [
      Offset(10000, 0),
      Offset(10000, 8000),
      Offset(9750, 250),
      Offset(9750, 7750),
    ],
    const [
      Offset(10000, 8000),
      Offset(0, 8000),
      Offset(9750, 7750),
      Offset(250, 7750),
    ],
    const [Offset(0, 8000), Offset(0, 0), Offset(250, 7750), Offset(250, 250)],
  ];
  return WallAxisDetectionResult(
    evaluatedGroups: const [],
    detectedScale: 1,
    detectedUnitName: 'mm',
    targetThicknessMm: 250,
    rawCenterlines: const [],
    bridgedCenterlines: const [],
    snappedCenterlines: const [],
    wallContourSegments: const [],
    selectedWallPairs: faces
        .map((f) => pair(tr(f[0]), tr(f[1]), tr(f[2]), tr(f[3])))
        .toList(),
  );
}

bool inside(Offset p, List<Offset> ring) {
  var value = false;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i], b = ring[(i + 1) % ring.length];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      value = !value;
    }
  }
  return value;
}

DxfDocument document(List<DxfEntity> entities) => DxfDocument(
  layers: {'outline': DxfLayer(name: 'outline')},
  blocks: {},
  entities: entities,
  headerVars: {},
  bounds: const Rect.fromLTRB(-2000, -2000, 12000, 10000),
  entityStats: {},
);
void main() {
  test('actual mitred faces retain all four outer corners', () {
    final result = SlabEnvelopeDetector.detect(rectangle());
    expect(result.contours, hasLength(1));
    for (final p in [
      const Offset(30, 30),
      const Offset(9970, 30),
      const Offset(9970, 7970),
      const Offset(30, 7970),
    ]) {
      expect(
        inside(p, result.contours.single),
        isTrue,
        reason: 'missing corner $p',
      );
    }
    expect(result.contours.single.length, 4);
  });
  test('continuous outer face stays straight at T junction', () {
    final result = SlabEnvelopeDetector.detect(rectangle(junction: true));
    expect(inside(const Offset(5000, 30), result.contours.single), isTrue);
    expect(result.contours.single.length, 4);
  });
  test('mitre repair also works on rotated walls', () {
    const angle = 0.4;
    final result = SlabEnvelopeDetector.detect(rectangle(angle: angle));
    final p = Offset(
      30 * math.cos(angle) - 30 * math.sin(angle),
      30 * math.sin(angle) + 30 * math.cos(angle),
    );
    expect(inside(p, result.contours.single), isTrue);
  });
  const envelope = SlabEnvelopeResult(
    [
      [Offset(0, 0), Offset(10000, 0), Offset(10000, 8000), Offset(0, 8000)],
    ],
    [],
    25,
    1,
  );
  List<DxfEntity> outline({double offset = 0, String? lineType}) => [
    DxfLine(
      p1: Offset(1000, offset),
      p2: Offset(1000, -1500 + offset),
      layer: 'outline',
      lineType: lineType,
    ),
    DxfLine(
      p1: Offset(1000, -1500 + offset),
      p2: Offset(5000, -1500 + offset),
      layer: 'outline',
      lineType: lineType,
    ),
    DxfLine(
      p1: Offset(5000, -1500 + offset),
      p2: Offset(5000, offset),
      layer: 'outline',
      lineType: lineType,
    ),
  ];
  test('external open chain closes along facade as one candidate', () {
    final found = SlabProjectionDetector.detect(
      document(outline()),
      envelope,
      1,
    );
    expect(found, hasLength(1));
    expect(found.single.area, closeTo(6000000, 1));
    expect(found.single.toJson()['kind'], 'externalArea');
  });
  test('unattached geometry is not a balcony proposal', () {
    expect(
      SlabProjectionDetector.detect(
        document(outline(offset: -1000)),
        envelope,
        1,
      ),
      isEmpty,
    );
  });
  test('dashed and interior geometry is excluded', () {
    expect(
      SlabProjectionDetector.detect(
        document(outline(lineType: 'DASHED')),
        envelope,
        1,
      ),
      isEmpty,
    );
    expect(
      SlabProjectionDetector.detect(
        document(outline(offset: 4000)),
        envelope,
        1,
      ),
      isEmpty,
    );
  });
}
