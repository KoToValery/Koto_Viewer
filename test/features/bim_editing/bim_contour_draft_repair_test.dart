import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_contour_repair.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_polygon_geometry.dart';

void main() {
  test(
    'Uncrossing keeps every corner of a bowtie in either drawing direction',
    () {
      const ring = [Offset.zero, Offset(6, 4), Offset(0, 4), Offset(6, 0)];
      for (final raw in [ring, ring.reversed.toList()]) {
        final repaired = BimContourRepair.uncrossDraftPolygon(raw);
        expect(repaired, isNotNull);
        expect(repaired, unorderedEquals(ring));
        expect(repaired!.first, raw.first);
        expect(BimPolygonGeometry.valid(repaired), isTrue);
        expect(BimPolygonGeometry.signedArea(repaired).abs(), 24);
      }
      expect(ring[1], const Offset(6, 4));
    },
  );

  test('Several crossings are removed without adding or deleting corners', () {
    const ring = [
      Offset(0, 3),
      Offset(5, 0),
      Offset(2, 5),
      Offset(2, 0),
      Offset(5, 3),
    ];
    final repaired = BimContourRepair.uncrossDraftPolygon(ring);
    expect(repaired, unorderedEquals(ring));
    expect(BimPolygonGeometry.valid(repaired!), isTrue);
  });

  test('Valid concave rooms keep their exact boundary and area', () {
    const ring = [
      Offset.zero,
      Offset(6, 0),
      Offset(6, 1),
      Offset(1, 1),
      Offset(1, 6),
      Offset(0, 6),
    ];
    expect(BimContourRepair.uncrossDraftPolygon(ring), ring);
    expect(BimPolygonGeometry.signedArea(ring).abs(), 11);
  });

  test(
    'Ambiguous pinches, collinear rings and nonfinite points are rejected',
    () {
      const pinched = [
        Offset.zero,
        Offset(4, 0),
        Offset(2, 2),
        Offset(4, 4),
        Offset(0, 4),
        Offset(2, 2),
      ];
      expect(BimContourRepair.uncrossDraftPolygon(pinched), isNull);
      expect(
        BimContourRepair.uncrossDraftPolygon(const [
          Offset.zero,
          Offset(1, 0),
          Offset(2, 0),
        ]),
        isNull,
      );
      expect(
        BimContourRepair.uncrossDraftPolygon(const [
          Offset.zero,
          Offset(double.nan, 1),
          Offset(0, 3),
        ]),
        isNull,
      );
      expect(pinched.length, 6);
    },
  );
}
