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
}
