import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_wall_support_filter.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';

WallPairCandidate pair(
  Offset a,
  Offset b,
  Offset c,
  Offset d,
  Offset start,
  Offset end,
  double thickness,
) {
  WallSegment face(Offset a, Offset b) => WallSegment(
    start: a,
    end: b,
    angleRad: math.atan2((b - a).dy, (b - a).dx),
    offsetFromOrigin: 0,
    length: (b - a).distance,
    sourceLayer: 'walls',
  );
  return WallPairCandidate(
    segmentA: face(a, b),
    segmentB: face(c, d),
    centerlineStart: start,
    centerlineEnd: end,
    perpendicularDistance: thickness,
    overlapLength: (end - start).distance,
  );
}

void main() {
  final cap = pair(
    const Offset(0, 0),
    const Offset(4000, 0),
    const Offset(1800, 120),
    const Offset(2050, 120),
    const Offset(1800, 60),
    const Offset(2050, 60),
    120,
  );
  final left = pair(
    const Offset(1740, 0),
    const Offset(1740, 120),
    const Offset(1860, 0),
    const Offset(1860, 120),
    const Offset(1800, 0),
    const Offset(1800, 120),
    120,
  );
  final right = pair(
    const Offset(1990, 0),
    const Offset(1990, 120),
    const Offset(2110, 0),
    const Offset(2110, 120),
    const Offset(2050, 0),
    const Offset(2050, 120),
    120,
  );
  test(
    'an isolated short cap does not become a slab spur',
    () => expect(SlabWallSupportFilter.clean([cap], 1), isEmpty),
  );
  test(
    'a real thin facade step with two wall returns is preserved',
    () => expect(
      SlabWallSupportFilter.clean([cap, left, right], 1),
      contains(cap),
    ),
  );
  test('a short structural jamb is preserved for door bridging', () {
    final jamb = pair(
      const Offset(0, 0),
      const Offset(4000, 0),
      const Offset(1800, 250),
      const Offset(2050, 250),
      const Offset(1800, 125),
      const Offset(2050, 125),
      250,
    );
    expect(SlabWallSupportFilter.clean([jamb], 1), contains(jamb));
  });
}
