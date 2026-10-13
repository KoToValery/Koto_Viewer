import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/bim_editing/scene/bim_element_adapter.dart';
import 'package:kotoview/src/features/architect/adapters/architect_element_adapters.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart'
    as a;
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/structural_designer/adapters/structural_element_adapters.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

const reference = BimElementRef(
  documentId: 'construction:p',
  storeyId: 'g',
  elementId: 'c',
);
const ring = [Offset(0, 0), Offset(4, 0), Offset(4, 3), Offset(0, 3)];

void main() {
  test('Native documents and hosted parts have independent identity', () {
    expect(
      reference,
      const BimElementRef(
        documentId: 'construction:p',
        storeyId: 'g',
        elementId: 'c',
      ),
    );
    expect(
      reference,
      isNot(
        const BimElementRef(
          documentId: 'architect:p',
          storeyId: 'g',
          elementId: 'c',
        ),
      ),
    );
    expect(
      reference,
      isNot(
        const BimElementRef(
          documentId: 'construction:p',
          storeyId: 'g',
          elementId: 'c',
          partId: '0',
        ),
      ),
    );
  });

  for (final units in [1.0, 100.0, 1000.0]) {
    test(
      'Column adapters share metre geometry and preserve every native field: $units',
      () {
        final frame = BimCoordinateFrame(
          origin: const Offset(25000, -47000),
          unitsPerMeter: units,
        );
        final adapter = StructuralColumnEditingAdapter(frame: frame);
        final source = StructuralColumn(
          id: 'c',
          name: 'user',
          generatedBy: 'source',
          center: frame.toCad(const Offset(3, 4)),
          width: .6 * units,
          height: .8 * units,
          shape: ColumnShape.lShape,
          rotationRad: .3,
          thickness: .2 * units,
          isMirrored: true,
        );
        final original = source.toJson();
        const delta = Offset(1.123456789, -2.345678912);
        final moved = adapter.translate(source, delta);
        expect(
          adapter.describe(moved, reference).anchor.dx,
          closeTo(4.123456789, 1e-9),
        );
        expect(
          adapter.describe(moved, reference).anchor.dy,
          closeTo(1.654321088, 1e-9),
        );
        expect(adapter.describe(source, reference).outline, hasLength(6));
        for (final key in original.keys.where((k) => k != 'center')) {
          expect(moved.toJson()[key], original[key], reason: key);
        }
        expect(adapter.translate(source, Offset.zero), same(source));
        final restored = adapter.translate(moved, -delta);
        expect((restored.center - source.center).distance, lessThan(1e-7));
        expect(source.toJson(), original);
        final architect = const a.ArchitectColumn(
          id: 'c',
          position: Offset(3, 4),
          width: .6,
          depth: .8,
          rotationDeg: 30,
          height: 3.1,
          label: 'user',
        );
        const archAdapter = ArchitectColumnEditingAdapter();
        final archMoved = archAdapter.translate(architect, delta);
        expect(
          (archMoved.position - frame.toModel(moved.center)).distance,
          lessThan(1e-9),
        );
        expect(archMoved.rotationDeg, 30);
        expect(archMoved.depth, .8);
        expect(archMoved.height, 3.1);
        expect(archMoved.label, 'user');
        expect(archAdapter.translate(architect, Offset.zero), same(architect));
        expect(
          () => adapter.translate(source, const Offset(double.nan, 0)),
          throwsArgumentError,
        );
      },
    );

    test(
      'Wall, beam, axes and holes preserve domain properties under metre translation: $units',
      () {
        final frame = BimCoordinateFrame(
          origin: const Offset(15000, -40000),
          unitsPerMeter: units,
        );
        final wall = StructuralShearWall(
          id: 'w',
          name: 'wall',
          generatedBy: 'origin',
          start: frame.toCad(Offset.zero),
          end: frame.toCad(const Offset(0, 3)),
          thickness: .25 * units,
          isFlipped: true,
          referenceLine: ShearWallReferenceLine.rightFace,
        );
        final movedWall = StructuralWallEditingAdapter(
          frame: frame,
        ).translate(wall, const Offset(2, 1));
        expect(movedWall.thickness, wall.thickness);
        expect(movedWall.referenceLine, wall.referenceLine);
        expect(movedWall.generatedBy, wall.generatedBy);
        expect(movedWall.isFlipped, true);
        final beam = StructuralBeam(
          id: 'b',
          name: 'user',
          start: wall.start,
          end: wall.end,
          width: .3 * units,
          depth: .6 * units,
          isSecondary: true,
        );
        final movedBeam = StructuralBeamEditingAdapter(
          frame: frame,
        ).translate(beam, const Offset(2, 1));
        expect(movedBeam.width, beam.width);
        expect(movedBeam.depth, beam.depth);
        expect(movedBeam.isSecondary, true);
        final axis = StructuralGridAxis(
          id: 'a',
          name: 'custom',
          start: wall.start,
          end: wall.end,
          bubbleAtStart: false,
          sourceStoreyIds: const ['g', 'f'],
        );
        final movedAxis = StructuralAxisEditingAdapter(
          frame: frame,
        ).translate(axis, const Offset(2, 1));
        expect(movedAxis.sourceStoreyIds, axis.sourceStoreyIds);
        expect(movedAxis.bubbleAtStart, false);
        expect(movedAxis.name, 'custom');
        final slab = StructuralSlab(
          id: 's',
          polygon: ring.map(frame.toCad).toList(),
          openings: [
            ring.map((p) => frame.toCad(p * .1 + const Offset(1, 1))).toList(),
          ],
          openingTypes: const [SlabOpeningType.staircase],
          parentSlabId: 'parent',
          zoneKind: SlabZoneKind.balcony,
          thickness: .27,
          topElevation: 2.45,
          isFloorSlab: true,
          floorFinish: .08,
          colorValue: 0xffaabbcc,
        );
        final slabAdapter = StructuralSlabEditingAdapter(frame: frame);
        final movedSlab = slabAdapter.translate(slab, const Offset(2, 1));
        final original = slab.toJson();
        final moved = movedSlab.toJson();
        for (final key in original.keys.where(
          (k) => !['polygon', 'openings'].contains(k),
        )) {
          expect(moved[key], original[key], reason: key);
        }
        final snapshot = slabAdapter.describe(movedSlab, reference);
        expect(
          (snapshot.outline.first - const Offset(2, 1)).distance,
          lessThan(1e-9),
        );
        expect(
          (snapshot.holes.single.first - const Offset(3, 2)).distance,
          lessThan(1e-9),
        );
        expect(snapshot.holes.single, hasLength(4));
        expect(() => snapshot.outline.add(Offset.zero), throwsUnsupportedError);
        expect(() => snapshot.holes.single.clear(), throwsUnsupportedError);
        expect(
          slabAdapter.describe(slab, reference, readOnly: true).capabilities,
          isEmpty,
        );
      },
    );
  }

  test(
    'Architect contours and line adapters preserve settings and analytic circles',
    () {
      const slab = ArchitectSlab(
        id: 's',
        polygon: ring,
        thickness: .23,
        label: 'typed',
      );
      final moved = const ArchitectSlabEditingAdapter().translate(
        slab,
        const Offset(2, 3),
      );
      expect(moved.polygon.first, const Offset(2, 3));
      expect(moved.thickness, .23);
      expect(moved.label, 'typed');
      const zone = ArchitectZone(
        id: 'z',
        name: 'my zone',
        category: ArchitectZoneCategory.living,
        polygon: ring,
        targetArea: 12,
        customColorValue: 0xff123456,
      );
      final movedZone = const ArchitectZoneEditingAdapter().translate(
        zone,
        const Offset(2, 3),
      );
      expect(movedZone.targetArea, 12);
      expect(movedZone.customColorValue, zone.customColorValue);
      expect(movedZone.name, zone.name);
      const beam = ArchitectBeam(
        id: 'b',
        startPoint: Offset.zero,
        endPoint: Offset(3, 1),
        width: .4,
        depth: .6,
        label: 'beam',
      );
      final movedBeam = const ArchitectBeamEditingAdapter().translate(
        beam,
        const Offset(2, 3),
      );
      expect(movedBeam.endPoint, const Offset(5, 4));
      expect(movedBeam.width, .4);
      expect(movedBeam.depth, .6);
      expect(movedBeam.label, 'beam');
      const circle = a.ArchitectColumn(
        id: 'c',
        position: Offset(1, 2),
        shape: a.ColumnShape.circular,
        width: .6,
      );
      final geometry = const ArchitectColumnEditingAdapter().describe(
        circle,
        reference,
      );
      expect(geometry.outline, isEmpty);
      expect(geometry.circles.single.radius, .3);
      expect(geometry.circles.single.center, circle.position);
    },
  );
}
