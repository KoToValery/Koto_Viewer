import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_polygon_geometry.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_polygon_editor.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  const outer = [Offset(0, 0), Offset(8, 0), Offset(8, 6), Offset(0, 6)];
  const hole = [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)];

  test(
    'common editor and native slab vertex operation agree without losing holes',
    () {
      const original = StructuralSlab(
        id: 'slab',
        polygon: outer,
        openings: [hole],
        openingTypes: [SlabOpeningType.elevator],
        thickness: .27,
        topElevation: 9,
        isFloorSlab: true,
      );
      final editor = BimPolygonEditor<Offset>(
        pointOf: (p) => p,
        isSnapped: (_) => false,
      );
      expect(editor.startVertex('slab', outer, 1), isTrue);
      editor.update(const Offset(9, 0), (p) => p, 0);
      final native = original.moveVertex(1, const Offset(9, 0));
      expect(native.polygon, editor.preview);
      expect(native.openings, original.openings);
      expect(native.openingTypes, original.openingTypes);
      expect(native.thickness, .27);
      expect(native.topElevation, 9);
      expect(native.isFloorSlab, isTrue);
      editor.update(const Offset(1, 7), (p) => p, 0);
      expect(editor.invalid, isTrue);
      expect(original.moveVertex(1, const Offset(1, 7)), same(original));
      editor.cancel();
      expect(editor.active, isFalse);
      expect(original.polygon, outer);
    },
  );

  test('outer and opening edge extension use one geometric operation', () {
    const slab = StructuralSlab(
      id: 's',
      polygon: outer,
      openings: [hole],
      openingTypes: [SlabOpeningType.staircase],
    );
    final outside = slab.dynamicPullEdge(edgeIndex: 1, distance: 1);
    expect(outside.openings, [hole]);
    final opening = slab.dynamicPullOpeningEdge(
      openingIndex: 0,
      edgeIndex: 1,
      distance: .2,
    );
    final standalone = const StructuralSlab(
      id: 'o',
      polygon: hole,
    ).dynamicPullEdge(edgeIndex: 1, distance: .2);
    expect(opening.openings.single, standalone.polygon);
    expect(opening.openingTypes, [SlabOpeningType.staircase]);
  });

  test(
    'slab rotation carries its holes and preserves ownership/type/elevation',
    () {
      const slab = StructuralSlab(
        id: 's',
        polygon: outer,
        openings: [hole],
        openingTypes: [SlabOpeningType.elevator],
        thickness: .23,
        topElevation: 7,
        isFloorSlab: true,
      );
      final rotated = slab.rotate(90);
      expect(rotated.openings, isNot(slab.openings));
      expect(
        StructuralSlab.calculateArea(rotated.openings.single),
        closeTo(1, 1e-9),
      );
      expect(rotated.netArea, closeTo(slab.netArea, 1e-9));
      expect(rotated.openingTypes, slab.openingTypes);
      expect(rotated.isFloorSlab, isTrue);
      expect(rotated.topElevation, 7);
      expect(rotated.thickness, .23);
    },
  );

  test(
    'area stays accurate far from origin, in either contour orientation',
    () {
      final far = outer.map((p) => p + const Offset(1e10, -1e10)).toList();
      expect(BimPolygonGeometry.signedArea(far), 48);
      expect(StructuralSlab.calculateArea(far.reversed.toList()), 48);
    },
  );
}
