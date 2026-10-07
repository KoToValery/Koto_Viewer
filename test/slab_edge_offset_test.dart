import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/services/slab_edge_offset.dart';

StructuralSlab rectangle(String id, double x, double y, double w, double h) =>
    StructuralSlab(
      id: id,
      polygon: [
        Offset(x, y),
        Offset(x + w, y),
        Offset(x + w, y + h),
        Offset(x, y + h),
      ],
    );

void main() {
  test('parallel shift is independent of units and winding', () {
    for (final scale in [1.0, 100.0, 1000.0]) {
      for (final reversed in [false, true]) {
        var slab = rectangle('s', 0, 0, 4 * scale, 4 * scale);
        if (reversed) {
          slab = slab.copyWith(polygon: slab.polygon.reversed.toList());
        }
        final edge = slab.polygon.indexWhere(
          (p) => p == Offset(4 * scale, reversed ? 4 * scale : 0),
        );
        final changed = SlabEdgeOffset.move(
          slabs: [slab],
          slabId: 's',
          edge: edge,
          metres: .02,
          scale: scale,
        )!.single;
        expect(
          changed.polygon.map((p) => p.dx).reduce((a, b) => a > b ? a : b),
          closeTo(4.02 * scale, 1e-8),
        );
        expect(changed.polygon.length, 4);
      }
    }
  });
  test('a shared edge moves together and inward offset restores geometry', () {
    final slabs = [rectangle('s', 0, 0, 4, 4), rectangle('b', 4, 0, 2, 4)];
    final moved = SlabEdgeOffset.move(
      slabs: slabs,
      slabId: 's',
      edge: 1,
      metres: .2,
      scale: 1,
    )!;
    expect(moved[0].polygon[1], const Offset(4.2, 0));
    expect(moved[1].polygon[0], const Offset(4.2, 0));
    final restored = SlabEdgeOffset.move(
      slabs: moved,
      slabId: 's',
      edge: 1,
      metres: -.2,
      scale: 1,
    )!;
    expect(restored[0].polygon, slabs[0].polygon);
    expect(restored[1].polygon, slabs[1].polygon);
    expect(slabs[0].polygon[1], const Offset(4, 0));
  });
  test('partial shared boundary is rejected without mutating inputs', () {
    final slabs = [rectangle('s', 0, 0, 4, 4), rectangle('b', 4, 1, 2, 2)];
    expect(
      SlabEdgeOffset.move(
        slabs: slabs,
        slabId: 's',
        edge: 1,
        metres: .1,
        scale: 1,
      ),
      isNull,
    );
    expect(slabs[0].polygon[1], const Offset(4, 0));
  });
  test('rejects inverted outline and a cut through an opening', () {
    final slab = rectangle('s', 0, 0, 4, 4).copyWith(
      openings: [
        [
          const Offset(2, 1),
          const Offset(3, 1),
          const Offset(3, 2),
          const Offset(2, 2),
        ],
      ],
    );
    for (final distance in [-5.0, -1.5, double.nan]) {
      expect(
        SlabEdgeOffset.move(
          slabs: [slab],
          slabId: 's',
          edge: 1,
          metres: distance,
          scale: 1,
        ),
        isNull,
      );
    }
  });
  test('oblique edges retain neighbours directions', () {
    const slab = StructuralSlab(
      id: 's',
      polygon: [Offset(0, 0), Offset(4, 0), Offset(6, 4), Offset(2, 4)],
    );
    final moved = SlabEdgeOffset.move(
      slabs: [slab],
      slabId: 's',
      edge: 0,
      metres: 1,
      scale: 1,
    )!.single;
    expect(moved.polygon[0], const Offset(-.5, -1));
    expect(moved.polygon[1], const Offset(3.5, -1));
    expect(moved.polygon[2], slab.polygon[2]);
  });
}
