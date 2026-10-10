import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_projection_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_seed_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_topology_analyzer.dart';
import 'package:kotoview/src/features/structural_designer/models/slab_topology.dart';

DxfDocument document(
  List<DxfEntity> lines, {
  Map<String, DxfBlock> blocks = const {},
}) => DxfDocument(
  entities: lines,
  layers: {'outline': DxfLayer(name: 'outline')},
  blocks: blocks,
  headerVars: {},
  bounds: const Rect.fromLTWH(-20, -20, 40, 40),
  entityStats: {},
);
SlabEnvelopeResult envelope(List<Offset> ring, double scale) =>
    SlabEnvelopeResult([ring], const [], 25 * scale, 1);
void main() {
  final actual =
      jsonDecode(
            File(
              'test/fixtures/bim_package_parapet_projections.json',
            ).readAsStringSync(),
          )
          as Map;
  for (final factor in [.01, 1.0, 10.0]) {
    for (final angle in [0.0, .43]) {
      test(
        'actual divided parapet profiles produce two valid attached balconies: units=$factor rotation=$angle',
        () {
          Offset tr(dynamic p) =>
              Offset(
                (p[0] as num) * math.cos(angle) -
                    (p[1] as num) * math.sin(angle),
                (p[0] as num) * math.sin(angle) +
                    (p[1] as num) * math.cos(angle),
              ) *
              factor;
          final env = SlabEnvelopeResult(
            [
              for (final ring in actual['contours'])
                [for (final p in ring) tr(p)],
            ],
            const [],
            2.5 * factor,
            1,
          );
          final doc = document([
            for (final s in actual['strokes'])
              DxfLine(
                p1: tr(s.sublist(0, 2)),
                p2: tr(s.sublist(2, 4)),
                layer: 'outline',
              ),
          ]);
          final found = SlabProjectionDetector.detect(doc, env, .1 * factor);
          expect(found, hasLength(2));
          expect(found.every((p) => p.hasParapet && p.kind == 'balcony'), true);
          final areas =
              found.map((p) => p.area / (factor * factor * 10000)).toList()
                ..sort();
          expect(areas[0], closeTo(4.8848265625, .001));
          expect(areas[1], closeTo(5.1792779907, .001));
          final seeds = SlabSeedGenerator.generate(
            metadata: {
              'slabEnvelope': env.toJson(),
              'slabProjections': found.map((p) => p.toJson()).toList(),
            },
            document: doc,
            storeyId: 'f',
            existing: [],
            unitsPerMeter: 100 * factor,
            thickness: .2,
            floorOwned: true,
          );
          expect(seeds, hasLength(3));
          expect(seeds.every((s) => s.isFloorSlab), true);
          expect(
            SlabTopologyAnalyzer.analyze(seeds, 100 * factor).issue,
            SlabTopologyIssue.none,
          );
        },
      );
    }
  }
  for (final thickness in [.01, .025, .04, .10, .12, .22]) {
    test(
      'generic double-face rail closes a balcony without layer hints: thickness=$thickness',
      () {
        const main = [Offset(0, 0), Offset(10, 0), Offset(10, 8), Offset(0, 8)];
        final lines = <DxfEntity>[
          const DxfLine(
            p1: Offset(2, 0),
            p2: Offset(2, -1.5),
            layer: 'outline',
          ),
          const DxfLine(
            p1: Offset(2, -1.5),
            p2: Offset(6, -1.5),
            layer: 'outline',
          ),
          const DxfLine(
            p1: Offset(6, -1.5),
            p2: Offset(6, 0),
            layer: 'outline',
          ),
          DxfLine(
            p1: Offset(2 + thickness, 0),
            p2: Offset(2 + thickness, -1.5 + thickness),
            layer: 'outline',
          ),
          DxfLine(
            p1: Offset(2 + thickness, -1.5 + thickness),
            p2: Offset(6 - thickness, -1.5 + thickness),
            layer: 'outline',
          ),
          DxfLine(
            p1: Offset(6 - thickness, -1.5 + thickness),
            p2: Offset(6 - thickness, 0),
            layer: 'outline',
          ),
          // Caps and posts make a raw endpoint graph branch at its corners.
          DxfLine(
            p1: const Offset(2, -1.5),
            p2: Offset(2 + thickness, -1.5 + thickness),
            layer: 'outline',
          ),
          DxfLine(
            p1: const Offset(6, -1.5),
            p2: Offset(6 - thickness, -1.5 + thickness),
            layer: 'outline',
          ),
          DxfLine(
            p1: const Offset(4, -1.5),
            p2: Offset(4, -1.5 + thickness),
            layer: 'outline',
          ),
        ];
        final found = SlabProjectionDetector.detect(
          document(lines),
          envelope(main, .001),
          .001,
        );
        expect(found, hasLength(1));
        expect(found.single.kind, 'balcony');
        expect(found.single.hasParapet, true);
        expect(found.single.area, closeTo(6, .001));
      },
    );
  }
  test(
    'a disconnected outside rail and an internal double profile are not balconies',
    () {
      const main = [Offset(0, 0), Offset(10, 0), Offset(10, 8), Offset(0, 8)];
      final doc = document([
        const DxfLine(p1: Offset(2, -5), p2: Offset(2, -6), layer: 'outline'),
        const DxfLine(p1: Offset(2, -6), p2: Offset(6, -6), layer: 'outline'),
        const DxfLine(p1: Offset(6, -6), p2: Offset(6, -5), layer: 'outline'),
        const DxfLine(
          p1: Offset(2.1, -5),
          p2: Offset(2.1, -5.9),
          layer: 'outline',
        ),
        const DxfLine(
          p1: Offset(2.1, -5.9),
          p2: Offset(5.9, -5.9),
          layer: 'outline',
        ),
        const DxfLine(
          p1: Offset(5.9, -5.9),
          p2: Offset(5.9, -5),
          layer: 'outline',
        ),
        const DxfLine(p1: Offset(2, 2), p2: Offset(6, 2), layer: 'outline'),
        const DxfLine(p1: Offset(2, 2.1), p2: Offset(6, 2.1), layer: 'outline'),
      ]);
      expect(
        SlabProjectionDetector.detect(doc, envelope(main, .001), .001),
        isEmpty,
      );
    },
  );
  test('parapet faces inside a rotated and mirrored block remain usable', () {
    const main = [Offset(0, 0), Offset(10, 0), Offset(10, 8), Offset(0, 8)];
    final entities = <DxfEntity>[
      const DxfLine(p1: Offset(2, 0), p2: Offset(2, -1.5)),
      const DxfLine(p1: Offset(2, -1.5), p2: Offset(6, -1.5)),
      const DxfLine(p1: Offset(6, -1.5), p2: Offset(6, 0)),
      const DxfLine(p1: Offset(2.1, 0), p2: Offset(2.1, -1.4)),
      const DxfLine(p1: Offset(2.1, -1.4), p2: Offset(5.9, -1.4)),
      const DxfLine(p1: Offset(5.9, -1.4), p2: Offset(5.9, 0)),
    ];
    final doc = document(
      [
        const DxfInsert(
          blockName: 'rail',
          insertPoint: Offset.zero,
          scaleX: -1,
          rotationDeg: 90,
          layer: 'outline',
        ),
      ],
      blocks: {
        'rail': DxfBlock(
          name: 'rail',
          basePoint: Offset.zero,
          entities: entities,
        ),
      },
    );
    final transformed = main.map((p) => Offset(-p.dy, -p.dx)).toList();
    final found = SlabProjectionDetector.detect(
      doc,
      envelope(transformed, .001),
      .001,
    );
    expect(found, hasLength(1));
    expect(found.single.area, closeTo(6, .001));
  });
  test('classic polylines in a rotated and mirrored block remain usable', () {
    const main = [Offset(0, 0), Offset(10, 0), Offset(10, 8), Offset(0, 8)];
    final entities = <DxfEntity>[
      const DxfPolyline(
        vertices: [
          DxfPolylineVertex(x: 2, y: 0),
          DxfPolylineVertex(x: 2, y: -1.5),
          DxfPolylineVertex(x: 6, y: -1.5),
          DxfPolylineVertex(x: 6, y: 0),
        ],
      ),
      const DxfPolyline(
        vertices: [
          DxfPolylineVertex(x: 2.1, y: 0),
          DxfPolylineVertex(x: 2.1, y: -1.4),
          DxfPolylineVertex(x: 5.9, y: -1.4),
          DxfPolylineVertex(x: 5.9, y: 0),
        ],
      ),
    ];
    final doc = document(
      [
        const DxfInsert(
          blockName: 'rail',
          insertPoint: Offset.zero,
          scaleX: -1,
          rotationDeg: 90,
          layer: 'outline',
        ),
      ],
      blocks: {
        'rail': DxfBlock(
          name: 'rail',
          basePoint: Offset.zero,
          entities: entities,
        ),
      },
    );
    final transformed = main.map((p) => Offset(-p.dy, -p.dx)).toList();
    final found = SlabProjectionDetector.detect(
      doc,
      envelope(transformed, .001),
      .001,
    );
    expect(found, hasLength(1));
    expect(found.single.area, closeTo(6, .001));
  });
}
