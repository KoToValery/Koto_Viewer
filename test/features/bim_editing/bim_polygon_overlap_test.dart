import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_polygon_overlap.dart';

List<Offset> rectangle(double x, double y, double width, double height) => [
  Offset(x, y),
  Offset(x + width, y),
  Offset(x + width, y + height),
  Offset(x, y + height),
];

double overlap(List<Offset> a, List<Offset> b) =>
    BimPolygonOverlap(a).intersectionArea(BimPolygonOverlap(b));

void main() {
  test('Identical, contained, disjoint and boundary-only polygons', () {
    final a = rectangle(0, 0, 5, 5);
    expect(overlap(a, a), closeTo(25, 1e-9));
    expect(overlap(a, rectangle(1, 1, 2, 2)), closeTo(4, 1e-9));
    expect(overlap(a, rectangle(8, 1, 2, 2)), 0);
    expect(overlap(a, rectangle(5, 1, 2, 2)), 0);
    expect(overlap(a, rectangle(5, 5, 2, 2)), 0);
    expect(overlap(a, []), 0);
    expect(overlap(a, const [Offset.zero, Offset(1, 0), Offset(2, 0)]), 0);
  });

  test('Slanted boundaries use polygon intersection, with either winding', () {
    const a = [Offset(0, 0), Offset(4, 0), Offset(0, 4)];
    const b = [Offset(1, 0), Offset(5, 0), Offset(1, 4)];
    for (final first in [a, a.reversed.toList()]) {
      for (final second in [b, b.reversed.toList()]) {
        expect(overlap(first, second), closeTo(4.5, 1e-9));
        expect(overlap(second, first), closeTo(4.5, 1e-9));
      }
    }
  });

  test(
    'Concave outlines with a notch can produce disconnected intersections',
    () {
      const u = [
        Offset(0, 0),
        Offset(6, 0),
        Offset(6, 6),
        Offset(4, 6),
        Offset(4, 2),
        Offset(2, 2),
        Offset(2, 6),
        Offset(0, 6),
      ];
      expect(overlap(u, rectangle(1, 3, 4, 1)), closeTo(2, 1e-9));
      expect(overlap(u, rectangle(2, 3, 2, 1)), closeTo(0, 1e-9));
      expect(overlap(u, u), closeTo(28, 1e-9));
      expect(overlap(u.reversed.toList(), u), closeTo(28, 1e-9));
    },
  );

  test('Two concave polygons intersect in separate pieces', () {
    const a = [
      Offset(0, 0),
      Offset(4, 0),
      Offset(4, 1),
      Offset(1, 1),
      Offset(1, 4),
      Offset(0, 4),
    ];
    const b = [
      Offset(0, 3),
      Offset(3, 3),
      Offset(3, 0),
      Offset(4, 0),
      Offset(4, 4),
      Offset(0, 4),
    ];
    for (var start = 0; start < a.length; start++) {
      final shifted = [...a.skip(start), ...a.take(start)];
      expect(overlap(shifted, b), closeTo(2, 1e-9));
      expect(overlap(b.reversed.toList(), shifted), closeTo(2, 1e-9));
    }
  });

  test('Collinear vertices and large drawing coordinates preserve area', () {
    const a = [
      Offset(0, 0),
      Offset(2, 0),
      Offset(4, 0),
      Offset(4, 4),
      Offset(0, 4),
      Offset(0, 0),
    ];
    final b = rectangle(3, 1, 4, 2);
    const offset = Offset(1000000, -1000000);
    expect(overlap(a, b), closeTo(2, 1e-9));
    expect(
      overlap(
        a.map((p) => p + offset).toList(),
        b.map((p) => p + offset).toList(),
      ),
      closeTo(2, 1e-8),
    );
  });
}
