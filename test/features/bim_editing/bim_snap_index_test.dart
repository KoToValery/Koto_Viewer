import 'dart:ui' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_editing/snapping/bim_snap_resolver.dart';
import 'package:kotoview/src/features/bim_editing/scene/bim_point_index.dart';
import 'package:kotoview/src/features/bim_editing/scene/bim_bounds_index.dart';
import 'package:kotoview/src/features/structural_designer/adapters/structural_snap_scene.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  test('priority and geometric ties are independent of provider order', () {
    const candidates = [
      BimSnapCandidate(
        point: Offset(.02, 0),
        kind: BimSnapKind.midpoint,
        source: 'middle',
      ),
      BimSnapCandidate(
        point: Offset(.10, 0),
        kind: BimSnapKind.endpoint,
        source: 'right',
      ),
      BimSnapCandidate(
        point: Offset(-.10, 0),
        kind: BimSnapKind.endpoint,
        source: 'left',
      ),
      BimSnapCandidate(
        point: Offset(.21, 0),
        kind: BimSnapKind.endpoint,
        source: 'outside',
      ),
    ];
    for (final order in [candidates, candidates.reversed]) {
      final resolver = BimSnapResolver<String>(raw: Offset.zero, radius: .2);
      order.forEach(resolver.consider);
      expect(resolver.best?.source, 'left');
      expect(resolver.best?.point, const Offset(-.10, 0));
    }
  });
  test('anchor exclusion and exact imported coordinates survive selection', () {
    final resolver = BimSnapResolver<int>(
      raw: const Offset(1, 1),
      radius: .2,
      anchor: const Offset(1, 1),
    );
    resolver.consider(
      const BimSnapCandidate(
        point: Offset(1, 1),
        kind: BimSnapKind.endpoint,
        source: 0,
      ),
    );
    resolver.consider(
      const BimSnapCandidate(
        point: Offset(1.0123456789, 1),
        kind: BimSnapKind.endpoint,
        source: 1,
      ),
    );
    expect(resolver.best?.point.dx, 1.0123456789);
  });
  test('bounded point index handles negative and very large queries', () {
    final index = BimPointIndex<int>();
    index.add(const Offset(-.2, -.2), 1);
    index.add(const Offset(1000000, 1000000), 2);
    index.seal();
    expect(index.query(Offset.zero, .3), [1]);
    expect(index.query(Offset.zero, 2000000), unorderedEquals([1, 2]));
    expect(index.query(Offset.zero, double.infinity), isEmpty);
    expect(() => index.add(Offset.zero, 3), throwsStateError);
  });
  test(
    'bounds index includes zero-height edges, circles and overflow exactly once',
    () {
      final index = BimBoundsIndex<String>();
      index.add(const Rect.fromLTRB(-10, 0, 10, 0), 'edge');
      index.add(Rect.fromCircle(center: Offset.zero, radius: 2), 'circle');
      index.add(
        const Rect.fromLTRB(-1000000, -1000000, 1000000, 1000000),
        'long',
      );
      expect(
        index.query(const Rect.fromLTWH(-1, -1, 2, 2)),
        unorderedEquals(['edge', 'circle', 'long']),
      );
      expect(index.query(const Rect.fromLTWH(500, 500, 1, 1)), ['long']);
    },
  );
  test('native scene cache belongs to revision and unit frame', () {
    const project = StructuralProject(
      storeys: [
        StoreyLevel(
          id: 'f',
          name: 'Floor',
          beams: [
            StructuralBeam(
              id: 'beam',
              start: Offset(0, 0),
              end: Offset(1000, 0),
            ),
          ],
        ),
      ],
    );
    final mm = StructuralSnapScene.of(project, 1000);
    expect(identical(mm, StructuralSnapScene.of(project, 1000)), isTrue);
    expect(
      mm
          .query(const Offset(1, 0), .01)
          .any((v) => v.point == const Offset(1, 0)),
      isTrue,
    );
    final metres = StructuralSnapScene.of(project, 1);
    expect(identical(mm, metres), isFalse);
    expect(metres.query(const Offset(1, 0), .01), isEmpty);
    expect(
      identical(mm, StructuralSnapScene.of(project.copyWith(), 1000)),
      isFalse,
    );
  });
}
