import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';
import 'slab_envelope_detector_test.dart' show walls;
import 'slab_corner_and_projection_test.dart' show document;

void main() {
  final paths = [
    [const Offset(0, 0), const Offset(4000, 0)],
    [
      const Offset(6750, 0),
      const Offset(10000, 0),
      const Offset(10000, 8000),
      const Offset(0, 8000),
      const Offset(0, 0),
    ],
  ];
  for (final mirrored in [false, true]) {
    for (final scale in [1.0, .001]) {
      test('wide glazing closes facade: mirrored=$mirrored scale=$scale', () {
        Offset transform(Offset p) {
          final x = mirrored ? 10000 - p.dx : p.dx;
          const angle = .37;
          return Offset(
            x * math.cos(angle) - p.dy * math.sin(angle),
            x * math.sin(angle) + p.dy * math.cos(angle),
          );
        }

        final doc = document([
          for (final y in [-20.0, 20.0])
            DxfLine(
              p1: transform(Offset(4000, y)) * scale,
              p2: transform(Offset(6000, y)) * scale,
              layer: 'glazing',
            ),
        ]);
        final result = SlabEnvelopeDetector.detect(
          walls(
            paths.map((p) => p.map(transform).toList()).toList(),
            scale: scale,
          ),
          document: doc,
        );
        expect(result.contours, hasLength(1));
        expect(result.assumedGaps.single.wideOpeningEvidence, isTrue);
      });
    }
  }
  test('wide passage without paired frame evidence remains open', () {
    for (final count in [0, 1]) {
      final doc = document([
        if (count == 1) const DxfLine(p1: Offset(4000, 0), p2: Offset(6000, 0)),
      ]);
      expect(
        SlabEnvelopeDetector.detect(walls(paths), document: doc).contours,
        isEmpty,
      );
    }
  });
  test('dashed marks and a wall return do not close a passage', () {
    final dashed = document([
      for (final y in [-20.0, 20.0])
        DxfLine(p1: Offset(4000, y), p2: Offset(6000, y), lineType: 'DASHED'),
    ]);
    expect(
      SlabEnvelopeDetector.detect(walls(paths), document: dashed).contours,
      isEmpty,
    );
    final solid = document([
      for (final y in [-20.0, 20.0])
        DxfLine(p1: Offset(4000, y), p2: Offset(6000, y)),
    ]);
    final result = SlabEnvelopeDetector.detect(
      walls([
        ...paths,
        [const Offset(4000, 0), const Offset(4000, 1000)],
      ]),
      document: solid,
    );
    expect(result.assumedGaps, isEmpty);
  });

  group('3.5m - 4.0m Vitrina & Dimension Geometric Detection', () {
    final widePaths = [
      [const Offset(0, 0), const Offset(4000, 0)],
      [
        const Offset(7500, 0),
        const Offset(10000, 0),
        const Offset(10000, 8000),
        const Offset(0, 8000),
        const Offset(0, 0),
      ],
    ];

    test('3.5m vitrina with multi-sash mullions on wall layer (стени) closes slab without breaking', () {
      // 3.5m clear opening (x: 4000 to 7500).
      // Glazing lines and 3 vertical mullions (dividing into 4 sashes of ~875mm).
      // All entities placed on the exact same layer as walls ('стени' / Archicad Worksheet convention).
      final doc = document([
        const DxfLine(
          p1: Offset(4000, -20),
          p2: Offset(7500, -20),
          layer: 'стени',
        ),
        const DxfLine(
          p1: Offset(4000, 20),
          p2: Offset(7500, 20),
          layer: 'стени',
        ),
        // Mullions / шпроси (transverse lines across thickness)
        const DxfLine(
          p1: Offset(4875, -50),
          p2: Offset(4875, 50),
          layer: 'стени',
        ),
        const DxfLine(
          p1: Offset(5750, -50),
          p2: Offset(5750, 50),
          layer: 'стени',
        ),
        const DxfLine(
          p1: Offset(6625, -50),
          p2: Offset(6625, 50),
          layer: 'стени',
        ),
      ]);

      final wallDetection = walls(widePaths);
      final result = SlabEnvelopeDetector.detect(wallDetection, document: doc);

      // The 3.5m vitrina must close the slab into a single complete envelope
      expect(result.contours, hasLength(1));
      expect(result.assumedGaps, hasLength(1));
      expect(result.assumedGaps.single.wideOpeningEvidence, isTrue);

      // Verify windows are NOT converted to structural walls
      expect(
        wallDetection.wallContourSegments.any(
          (s) => s.$1.dx >= 4000 && s.$2.dx <= 7500 && s.$1.dy.abs() <= 50,
        ),
        isFalse,
      );
    });

    test('3.5m vitrina with single centerline glazing and dimension witness ticks closes slab', () {
      // Single glazing line + perpendicular dimension ticks / witness markers at the jambs
      final doc = document([
        const DxfLine(
          p1: Offset(4000, 0),
          p2: Offset(7500, 0),
          layer: '0',
        ),
        const DxfLine(
          p1: Offset(4000, -150),
          p2: Offset(4000, 150),
          layer: '0',
        ),
        const DxfLine(
          p1: Offset(7500, -150),
          p2: Offset(7500, 150),
          layer: '0',
        ),
      ]);

      final result = SlabEnvelopeDetector.detect(walls(widePaths), document: doc);
      expect(result.contours, hasLength(1));
      expect(result.assumedGaps, hasLength(1));
      expect(result.assumedGaps.single.wideOpeningEvidence, isTrue);
    });

    test('3.5m wide open passage without geometric window evidence leaves slab open', () {
      // Completely empty opening
      final emptyDoc = document([]);
      expect(
        SlabEnvelopeDetector.detect(walls(widePaths), document: emptyDoc).contours,
        isEmpty,
      );

      // Single threshold line without frame pairs or mullions
      final singleLineDoc = document([
        const DxfLine(p1: Offset(4000, 0), p2: Offset(7500, 0)),
      ]);
      expect(
        SlabEnvelopeDetector.detect(walls(widePaths), document: singleLineDoc).contours,
        isEmpty,
      );
    });
  });
}

