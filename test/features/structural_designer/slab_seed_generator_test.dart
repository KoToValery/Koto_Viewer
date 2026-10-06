import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_seed_generator.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'slab_corner_and_projection_test.dart' show document;

List<Offset> rectangle(double y) => [
  Offset(0, y),
  Offset(1000, y),
  const Offset(1000, 1000),
  const Offset(0, 1000),
];

void main() {
  test('main slab snaps only to owned wall layer, retaining manual slabs', () {
    final doc = document([
      const DxfLine(p1: Offset.zero, p2: Offset(1000, 0), layer: 'BIM_Walls_2'),
      const DxfLine(p1: Offset(0, 9), p2: Offset(1000, 9), layer: 'BIM_Walls'),
    ]);
    final manual = StructuralSlab(id: 'manual', polygon: rectangle(10));
    final result = SlabSeedGenerator.generate(
      metadata: {
        'layers': ['BIM_Walls_2'],
        'wallLayer': 'BIM_Walls_2',
        'slabEnvelope': {
          'contours': [
            rectangle(10).map((p) => [p.dx, p.dy]).toList(),
          ],
        },
      },
      document: doc,
      storeyId: 's',
      existing: [manual],
      unitsPerMeter: 1000,
      thickness: .25,
    );
    expect(result.single.polygon, rectangle(0));
    expect(manual.polygon, rectangle(10));
  });
  test('strict 20 mm threshold and shared corners, without inward steps', () {
    final target = [(Offset.zero, const Offset(1000, 0))];
    expect(
      SlabSeedGenerator.snap(rectangle(19.9), target, 20, .001),
      rectangle(0),
    );
    expect(
      SlabSeedGenerator.snap(rectangle(20), target, 20, .001),
      rectangle(20),
    );
    expect(
      SlabSeedGenerator.snap(rectangle(21), target, 20, .001),
      rectangle(21),
    );
  });
  test('perpendicular and disjoint references cannot attract an edge', () {
    expect(
      SlabSeedGenerator.snap(
        rectangle(10),
        [
          (const Offset(500, 0), const Offset(500, 100)),
          (const Offset(2000, 0), const Offset(3000, 0)),
        ],
        20,
        .001,
      ),
      rectangle(10),
    );
  });
  test('rejects self intersections, cleans duplicate vertices', () {
    expect(
      SlabSeedGenerator.snap(
        [
          Offset.zero,
          const Offset(100, 100),
          const Offset(0, 100),
          const Offset(100, 0),
        ],
        [],
        20,
        .001,
      ),
      isNull,
    );
    expect(
      SlabSeedGenerator.snap([...rectangle(0), Offset.zero], [], 20, .001),
      rectangle(0),
    );
  });
  test(
    'aligned source geometry, projection snapping, persistence and manual edits',
    () {
      final metadata = <String, dynamic>{
        'sourceToProject': {
          'scale': 2.0,
          'translation': [100.0, 200.0],
        },
        'slabEnvelope': {
          'contours': [
            [
              [0, 0],
              [500, 0],
              [500, 500],
              [0, 500],
            ],
          ],
        },
        'slabProjections': [
          {
            'contour': [
              [0, -200],
              [500, -200],
              [500, -5],
              [0, -5],
            ],
          },
        ],
      };
      List<StructuralSlab> generate(List<StructuralSlab> existing) =>
          SlabSeedGenerator.generate(
            metadata: metadata,
            document: document([]),
            storeyId: 's',
            existing: existing,
            unitsPerMeter: 1000,
            thickness: .23,
          );
      final slabs = generate([]);
      expect(slabs.length, 2);
      expect(slabs.first.polygon.first, const Offset(100, 200));
      final expected = [
        const Offset(100, -200),
        const Offset(1100, -200),
        const Offset(1100, 200),
        const Offset(100, 200),
      ];
      for (var i = 0; i < expected.length; i++) {
        expect((slabs.last.polygon[i] - expected[i]).distance, lessThan(1e-8));
      }
      final edited = StructuralSlab.fromJson(
        slabs.first
            .copyWith(
              thickness: .3,
              polygon: rectangle(50),
              openings: [rectangle(100)],
            )
            .toJson(),
      );
      expect(generate([edited]), isEmpty);
      expect(edited.thickness, .3);
      expect(edited.polygon, rectangle(50));
      expect(edited.openings.length, 1);
    },
  );
  test('20 mm is independent of CAD drawing units', () {
    for (final scale in [0.001, 0.1, 1.0]) {
      final polygon = rectangle(19).map((p) => p * scale).toList();
      final result = SlabSeedGenerator.snap(
        polygon,
        [(Offset.zero, Offset(1000 * scale, 0))],
        20 * scale,
        .001 * scale,
      )!;
      expect(result.first.dy, closeTo(0, 1e-10));
    }
  });
}
