import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_boundary_refiner.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_seed_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_topology_analyzer.dart';
import 'package:kotoview/src/features/structural_designer/models/slab_topology.dart';
import 'features/structural_designer/slab_corner_and_projection_test.dart'
    as geometry;

void main() {
  final data =
      jsonDecode(
            File(
              'test/fixtures/bim_package_slab_boundaries.json',
            ).readAsStringSync(),
          )
          as Map;
  for (final fixture in data['cases'] as List) {
    for (final factor in [.01, 1.0, 10.0]) {
      test(
        'real package ${fixture['storage'] ?? 'dxf'} level ${fixture['level']} emits a valid source-aligned slab at unit factor $factor',
        () {
          Offset transform(dynamic p) =>
              Offset(p[0] as double, p[1] as double) * factor;
          final raster = (fixture['raster'] as List).map(transform).toList();
          final footprints = (fixture['footprints'] as List)
              .map((p) => (p as List).map(transform).toList())
              .toList();
          final diagnostics = <String>{};
          final scale = (fixture['scale'] as num).toDouble() * factor;
          final result = SlabBoundaryRefiner.refine(
            raster,
            footprints,
            (fixture['cell'] as num).toDouble() * factor,
            scale,
            diagnostics: diagnostics,
          );
          expect(result, isNotNull);
          final doc = DxfDocument.empty();
          final metadata = {
            'slabEnvelope': {
              'version': 5,
              'contours': [
                result!.map((p) => [p.dx, p.dy]).toList(),
              ],
            },
          };
          final seeds = SlabSeedGenerator.generate(
            metadata: metadata,
            document: doc,
            storeyId: 's',
            existing: [],
            unitsPerMeter: scale * 1000,
            thickness: .2,
          );
          expect(seeds, hasLength(1));
          expect(
            SlabTopologyAnalyzer.analyze(seeds, scale * 1000).issue,
            SlabTopologyIssue.none,
          );
          if (fixture['level'] == 0.0) {
            expect(diagnostics, contains('discardedPointContactArtifacts'));
          }
          // Every resulting edge remains on one of the observed footprint lines.
          for (var i = 0; i < result.length; i++) {
            final a = result[i], b = result[(i + 1) % result.length];
            expect(
              footprints.any((p) {
                for (var j = 0; j < p.length; j++) {
                  final c = p[j], v = p[(j + 1) % p.length] - c;
                  if (v.distance == 0) continue;
                  double distance(Offset q) =>
                      (v.dx * (q - c).dy - v.dy * (q - c).dx).abs() /
                      v.distance;
                  if (distance(a) < scale * .0001 &&
                      distance(b) < scale * .0001) {
                    return true;
                  }
                }
                return false;
              }),
              isTrue,
            );
          }
        },
      );
    }
  }
  for (final extent in [.2, 10.0]) {
    test(
      'point-only attachment of $extent metres is ${extent < 1 ? 'excluded as an artifact' : 'left unresolved'}',
      () {
        final main = [
          const Offset(0, 0),
          const Offset(10, 0),
          const Offset(10, 10),
          const Offset(0, 10),
        ];
        final spur = [
          const Offset(10, 10),
          Offset(10 + extent, 10),
          Offset(10 + extent, 10 + extent),
          Offset(10, 10 + extent),
        ];
        const cell = .025;
        final outline = [
          const Offset(-cell, -cell),
          const Offset(10 + cell, -cell),
          const Offset(10 + cell, 10 - cell),
          Offset(10 + extent + cell, 10 - cell),
          Offset(10 + extent + cell, 10 + extent + cell),
          Offset(10 - cell, 10 + extent + cell),
          const Offset(10 - cell, 10 + cell),
          const Offset(-cell, 10 + cell),
        ];
        final raster = <Offset>[];
        for (var i = 0; i < outline.length; i++) {
          final a = outline[i], b = outline[(i + 1) % outline.length];
          final count = math.max(1, ((b - a).distance / cell).ceil());
          for (var k = 0; k < count; k++) {
            raster.add(a + (b - a) * (k / count));
          }
        }
        final diagnostics = <String>{};
        final refined = SlabBoundaryRefiner.refine(
          raster,
          [main, spur],
          cell,
          .001,
          diagnostics: diagnostics,
        );
        if (extent < 1) {
          expect(refined, isNotNull);
          expect(diagnostics, contains('discardedPointContactArtifacts'));
        } else {
          expect(refined, isNull);
        }
      },
    );
  }
  test(
    'old empty envelope rebuilds from original aligned geometry without applying alignment twice',
    () {
      const shift = Offset(500, 250);
      final original = geometry
          .rectangle()
          .selectedWallPairs
          .expand(
            (p) => [
              DxfLine(
                p1: p.segmentA.start * .1 + shift,
                p2: p.segmentA.end * .1 + shift,
                layer: 'source',
              ),
              DxfLine(
                p1: p.segmentB.start * .1 + shift,
                p2: p.segmentB.end * .1 + shift,
                layer: 'source',
              ),
            ],
          )
          .toList();
      final document = DxfDocument(
        entities: [
          ...original,
          const DxfLine(
            p1: Offset(100000, 100000),
            p2: Offset(200000, 100000),
            layer: 'BIM_Walls',
          ),
        ],
        layers: {
          'source': DxfLayer(name: 'source', isVisible: false),
          'BIM_Walls': DxfLayer(name: 'BIM_Walls'),
        },
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 200000, 200000),
        entityStats: {},
      );
      final metadata = <String, dynamic>{
        'layers': ['BIM_Walls'],
        'visibility': {'source': true},
        'sourceToProject': {
          'scale': 2,
          'translation': [500, 250],
        },
        'slabEnvelope': {'version': 4, 'contours': []},
      };
      final before = jsonEncode(metadata);
      final result = SlabSeedGenerator.generate(
        metadata: metadata,
        document: document,
        storeyId: 's',
        existing: [],
        unitsPerMeter: 100,
        thickness: .2,
      );
      expect(result, hasLength(1));
      expect(result.single.bounds.left, closeTo(500, .001));
      expect(result.single.bounds.top, closeTo(250, .001));
      expect(result.single.bounds.right, closeTo(1500, .001));
      expect(result.single.bounds.bottom, closeTo(1050, .001));
      expect(
        SlabTopologyAnalyzer.analyze(result, 100).issue,
        SlabTopologyIssue.none,
      );
      expect(jsonEncode(metadata), before);
      expect(document.layers['source']!.isVisible, isFalse);
      expect(document.entities, hasLength(original.length + 1));
    },
  );
  test('self-touching source contour cannot be returned as a valid seed', () {
    final seeds = SlabSeedGenerator.generate(
      metadata: {
        'slabEnvelope': {
          'version': 5,
          'contours': [
            [
              [0, 0],
              [4, 0],
              [4, 4],
              [2, 4],
              [2, 6],
              [4, 6],
              [4, 4],
              [0, 4],
            ],
          ],
        },
      },
      document: DxfDocument.empty(),
      storeyId: 's',
      existing: [],
      unitsPerMeter: 1,
      thickness: .2,
    );
    expect(seeds, isEmpty);
  });
}
