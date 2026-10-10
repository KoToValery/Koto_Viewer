import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';
import 'package:kotoview/src/features/structural_designer/models/slab_topology.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_axis_support_grid.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_wall_support_filter.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_seed_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_topology_analyzer.dart';
import 'features/structural_designer/slab_envelope_detector_test.dart'
    as geometry;
import 'features/structural_designer/slab_corner_and_projection_test.dart'
    as polygon;

WallAxisDetectionResult fixture(
  Map data,
  Offset Function(dynamic) transform,
  double factor,
) {
  WallSegment face(List values) {
    final a = transform(values.sublist(0, 2)), b = transform(values.sublist(2));
    return WallSegment(
      start: a,
      end: b,
      angleRad: math.atan2((b - a).dy, (b - a).dx),
      offsetFromOrigin: 0,
      length: (b - a).distance,
      sourceLayer: 'walls',
    );
  }

  return WallAxisDetectionResult(
    evaluatedGroups: const [],
    detectedScale: .1 * factor,
    detectedUnitName: 'test',
    targetThicknessMm: 250,
    rawCenterlines: const [],
    bridgedCenterlines: const [],
    snappedCenterlines: const [],
    wallContourSegments: const [],
    selectedWallPairs: [
      for (final w in data['walls'])
        WallPairCandidate(
          segmentA: face(w['a']),
          segmentB: face(w['b']),
          perpendicularDistance: (w['thickness'] as num).toDouble() * factor,
          overlapLength:
              (transform((w['center'] as List).sublist(2)) -
                      transform((w['center'] as List).sublist(0, 2)))
                  .distance,
          centerlineStart: transform((w['center'] as List).sublist(0, 2)),
          centerlineEnd: transform((w['center'] as List).sublist(2)),
        ),
    ],
  );
}

void main() {
  final data =
      jsonDecode(
            File(
              'test/fixtures/bim_package_door_slab_walls.json',
            ).readAsStringSync(),
          )
          as Map;
  for (final floor in data['cases']) {
    for (final factor in [.01, 1.0, 10.0]) {
      for (final angle in [0.0, .43]) {
        test(
          'package floor ${floor['level']} keeps its full footprint: units=$factor rotation=$angle',
          () {
            Offset tr(dynamic p) =>
                Offset(
                  (p[0] as num).toDouble() * math.cos(angle) -
                      (p[1] as num).toDouble() * math.sin(angle),
                  (p[0] as num).toDouble() * math.sin(angle) +
                      (p[1] as num).toDouble() * math.cos(angle),
                ) *
                factor;
            final walls = fixture(floor as Map, tr, factor);
            final document = DxfDocument(
              entities: [
                for (final s in floor['strokes'])
                  DxfLine(
                    p1: tr(s.sublist(0, 2)),
                    p2: tr(s.sublist(2, 4)),
                    layer: 'walls',
                  ),
              ],
              layers: {'walls': DxfLayer(name: 'walls')},
              blocks: {},
              headerVars: {},
              bounds: Rect.zero,
              entityStats: {},
            );
            final envelope = SlabEnvelopeDetector.detect(
              walls,
              document: document,
            );
            expect(envelope.contours, hasLength(1));
            final seeds = SlabSeedGenerator.generate(
              metadata: {'slabEnvelope': envelope.toJson()},
              document: DxfDocument.empty(),
              storeyId: 's',
              existing: [],
              unitsPerMeter: 100 * factor,
              thickness: .2,
            );
            expect(seeds, hasLength(1));
            expect(
              SlabTopologyAnalyzer.analyze(seeds, 100 * factor).issue,
              SlabTopologyIssue.none,
            );
            if (floor['level'] == 2.8) {
              final ring = envelope.contours.single;
              for (final point in [
                [-635, 447],
                [-1070, 227],
              ]) {
                expect(
                  polygon.inside(tr(point), ring),
                  isFalse,
                  reason:
                      'An unsupported orphan line must not create an exterior spur',
                );
              }
            }
            if (floor['level'] == 2.8) {
              for (final point in [
                [-635, 447],
                [-1070, 227],
              ]) {
                expect(
                  polygon.inside(tr(point), envelope.contours.single),
                  isFalse,
                  reason:
                      'Orphan wall strokes must not project an exterior spur',
                );
              }
            }
            if (floor['level'] == 0) {
              final ring = seeds.single.polygon;
              expect(
                geometry.area(ring) / (factor * factor * 10000),
                closeTo(74.347498, .001),
              );
              expect(ring.length, 10);
              for (final point in [
                [-900, 450],
                [-800, 520],
                [-700, 420],
                [-600, 0],
                [-900, 0],
                [-600, -370],
              ]) {
                expect(
                  polygon.inside(tr(point), ring),
                  isTrue,
                  reason: '$point must remain inside the floor',
                );
              }
              for (final point in [
                [-700, 500],
                [-160, 0],
                [-900, 610],
              ]) {
                expect(
                  polygon.inside(tr(point), ring),
                  isFalse,
                  reason: '$point is outside or in the real facade recess',
                );
              }
              final cleaned = SlabWallSupportFilter.clean(
                walls.selectedWallPairs,
                walls.detectedScale,
              );
              int index(int original) =>
                  cleaned.indexOf(walls.selectedWallPairs[original]);
              final doors = envelope.assumedGaps.where(
                (g) =>
                    (g.wallA == index(11) && g.wallB == index(12)) ||
                    (g.wallA == index(29) && g.wallB == index(30)),
              );
              expect(doors, hasLength(2));
              for (final door in doors) {
                expect(door.axisSupportIntersections, hasLength(2));
                expect(door.toJson()['confirmedOpening'], isFalse);
              }
            }
          },
        );
      }
    }
  }
  test(
    'nonempty legacy partial cache is recomputed without applying alignment twice',
    () {
      const shift = Offset(500, 250);
      final source = polygon
          .rectangle()
          .selectedWallPairs
          .expand(
            (p) => [
              DxfLine(
                p1: p.segmentA.start * .1 + shift,
                p2: p.segmentA.end * .1 + shift,
                layer: 'walls',
              ),
              DxfLine(
                p1: p.segmentB.start * .1 + shift,
                p2: p.segmentB.end * .1 + shift,
                layer: 'walls',
              ),
            ],
          )
          .toList();
      final document = DxfDocument(
        entities: source,
        layers: {'walls': DxfLayer(name: 'walls')},
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(500, 250, 1000, 800),
        entityStats: {},
      );
      final metadata = {
        'sourceToProject': {
          'scale': 2,
          'translation': [500, 250],
        },
        'slabEnvelope': {
          'version': 5,
          'contours': [
            [
              [0, 0],
              [100, 0],
              [100, 100],
              [0, 100],
            ],
          ],
        },
      };
      final before = jsonEncode(metadata);
      final seeds = SlabSeedGenerator.generate(
        metadata: metadata,
        document: document,
        storeyId: 's',
        existing: [],
        unitsPerMeter: 100,
        thickness: .2,
      );
      expect(seeds, hasLength(1));
      expect(geometry.area(seeds.single.polygon) / 10000, closeTo(80, .001));
      expect(
        polygon.inside(const Offset(1000, 650), seeds.single.polygon),
        isTrue,
      );
      expect(jsonEncode(metadata), before);
    },
  );
  test('empty intersections cannot justify a short-jamb bridge', () {
    final walls = geometry.walls([
      const [Offset(0, 0), Offset(50, 0)],
      const [Offset(950, 0), Offset(2000, 0)],
      const [Offset(0, 1000), Offset(0, 2000)],
      const [Offset(2000, 1000), Offset(2000, 2000)],
    ]);
    final grid = SlabAxisSupportGrid(walls.selectedWallPairs, 1);
    expect(
      grid.supportingIntersections(
        0,
        1,
        const Offset(50, 0),
        const Offset(950, 0),
      ),
      isEmpty,
    );
    expect(SlabEnvelopeDetector.detect(walls).assumedGaps, isEmpty);
  });
  test('a supported short jamb does not close an inward recess', () {
    final walls = geometry.walls([
      const [Offset(0, 0), Offset(50, 0)],
      const [
        Offset(950, 0),
        Offset(1000, 0),
        Offset(1000, 4000),
        Offset(0, 4000),
        Offset(0, 0),
      ],
      const [
        Offset(50, 0),
        Offset(50, 2000),
        Offset(950, 2000),
        Offset(950, 0),
      ],
    ]);
    final envelope = SlabEnvelopeDetector.detect(walls);
    expect(envelope.assumedGaps, isEmpty);
    expect(envelope.contours, hasLength(1));
    expect(
      polygon.inside(const Offset(500, 500), envelope.contours.single),
      isFalse,
    );
    expect(
      polygon.inside(const Offset(500, 3000), envelope.contours.single),
      isTrue,
    );
  });
  test('slightly offset matching faces bridge on their middle axis', () {
    final walls = geometry.walls([
      const [Offset(0, 0), Offset(4000, 0)],
      const [Offset(5000, 20), Offset(10000, 20)],
    ]);
    final gap = SlabEnvelopeDetector.detect(walls).assumedGaps.single;
    expect(gap.start.dy, closeTo(10, .001));
    expect(gap.end.dy, closeTo(10, .001));
  });
}
