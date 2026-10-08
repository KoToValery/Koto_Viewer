import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/services/slab_edit_validation.dart';

List<Offset> box(double x, double y, double w, double h) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x + w, y + h),
  Offset(x, y + h),
];
void main() {
  test('pulling a slab edge through a stair opening is rejected', () {
    final slab = StructuralSlab(
      id: 's',
      polygon: box(0, 0, 10, 10),
      openings: [box(7, 2, 2, 3)],
    );
    final changed = slab.dynamicPullEdge(edgeIndex: 1, distance: -2);
    expect(SlabEditValidation.accepts([slab], changed, 1), isFalse);
    expect(slab.polygon, box(0, 0, 10, 10));
  });
  test(
    'isolated gesture cannot separate a shared boundary or overlap neighbour',
    () {
      final a = StructuralSlab(id: 'a', polygon: box(0, 0, 4, 4));
      final b = StructuralSlab(id: 'b', polygon: box(4, 0, 4, 4));
      for (final d in [-1.0, 1.0]) {
        expect(
          SlabEditValidation.accepts(
            [a, b],
            a.dynamicPullEdge(edgeIndex: 1, distance: d),
            1,
          ),
          isFalse,
        );
      }
      expect(
        SlabEditValidation.accepts(
          [a, b],
          a.dynamicPullEdge(edgeIndex: 3, distance: 1),
          1,
        ),
        isTrue,
      );
    },
  );
  test('removing collinear points retains shared topology and opening', () {
    final a = StructuralSlab(
      id: 'a',
      polygon: [
        const Offset(0, 0),
        const Offset(2, 0),
        const Offset(4, 0),
        const Offset(4, 4),
        const Offset(0, 4),
      ],
      openings: [box(1, 1, 1, 1)],
    );
    final b = StructuralSlab(id: 'b', polygon: box(4, 0, 4, 4));
    expect(
      SlabEditValidation.accepts(
        [a, b],
        a.copyWith(polygon: StructuralSlab.cleanPolygon(a.polygon)),
        1,
      ),
      isTrue,
    );
  });
  test('short adjacent edges move by requested distance in all CAD units', () {
    for (final scale in [1.0, 100.0, 1000.0]) {
      final slab = StructuralSlab(
        id: 's',
        polygon: box(0, 0, .2 * scale, .2 * scale),
        openings: [box(.05 * scale, .05 * scale, .1 * scale, .1 * scale)],
      );
      final moved = slab.dynamicPullEdge(
        edgeIndex: 1,
        distance: .01 * scale,
        minDistanceCad: .001 * scale,
      );
      expect(moved.polygon[1].dx, closeTo(.21 * scale, 1e-8));
      final hole = slab.dynamicPullOpeningEdge(
        openingIndex: 0,
        edgeIndex: 1,
        distance: .01 * scale,
        minDistanceCad: .001 * scale,
      );
      expect(hole.openings[0][1].dx, closeTo(.16 * scale, 1e-8));
    }
  });
}
