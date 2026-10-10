import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/geometric_window_detector.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';

WallPairCandidate wall(Offset a, Offset b, double width) {
  final d = b - a, u = d / d.distance, n = Offset(-u.dy, u.dx);
  WallSegment face(double sign) => WallSegment(
    start: a + n * width / 2 * sign,
    end: b + n * width / 2 * sign,
    angleRad: math.atan2(u.dy, u.dx),
    offsetFromOrigin: 0,
    length: d.distance,
    sourceLayer: 'geometry',
  );
  return WallPairCandidate(
    segmentA: face(1),
    segmentB: face(-1),
    perpendicularDistance: width,
    overlapLength: d.distance,
    centerlineStart: a,
    centerlineEnd: b,
  );
}

DxfDocument drawing(List<DxfEntity> strokes) => DxfDocument(
  entities: strokes,
  layers: {'geometry': DxfLayer(name: 'geometry')},
  blocks: {},
  headerVars: {},
  bounds: const Rect.fromLTWH(-10000, -10000, 20000, 20000),
  entityStats: {},
);
void main() {
  test(
    'actual BIM excerpts produce two facade openings and no cross-facade barrier',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/bim_package_facade_window_alignment.json',
                ).readAsStringSync(),
              )
              as Map;
      Offset point(List p) =>
          Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
      WallSegment segment(List p) {
        final a = point(p.sublist(0, 2)), b = point(p.sublist(2, 4)), d = b - a;
        return WallSegment(
          start: a,
          end: b,
          angleRad: math.atan2(d.dy, d.dx),
          offsetFromOrigin: 0,
          length: d.distance,
          sourceLayer: 'geometry',
        );
      }

      final pairs = <WallPairCandidate>[
        for (final p in fixture['wallPairs'])
          WallPairCandidate(
            segmentA: segment(p['a']),
            segmentB: segment(p['b']),
            perpendicularDistance: (p['thickness'] as num).toDouble(),
            overlapLength:
                (point(p['center'].sublist(2, 4)) -
                        point(p['center'].sublist(0, 2)))
                    .distance,
            centerlineStart: point(p['center'].sublist(0, 2)),
            centerlineEnd: point(p['center'].sublist(2, 4)),
          ),
      ];
      final doc = drawing([
        for (final s in fixture['strokes'])
          DxfLine(
            p1: point(s.sublist(0, 2)),
            p2: point(s.sublist(2, 4)),
            layer: 'geometry',
          ),
      ]);
      final found = GeometricWindowDetector.detect(
        doc,
        pairs,
        (fixture['scale'] as num).toDouble(),
      );
      expect(found, hasLength(2));
      final rows = found.map((w) => w.start.dy).toList()..sort();
      expect(rows[0], closeTo(-451.34628447585476, 1e-6));
      expect(rows[1], closeTo(-321.34628447585476, 1e-6));
    },
  );
  for (final units in [1.0, 100.0, 1000.0]) {
    for (final angle in [0.0, .43, math.pi / 2]) {
      for (final mirror in [1.0, -1.0]) {
        Offset tr(Offset p) {
          final x = p.dx * mirror, y = p.dy;
          return Offset(
                    x * math.cos(angle) - y * math.sin(angle),
                    x * math.sin(angle) + y * math.cos(angle),
                  ) *
                  units +
              const Offset(1234, -5678);
        }

        List<DxfLine> glazing(double end) => [
          for (final y in [-.04, .02])
            DxfLine(
              p1: tr(Offset(0, y)),
              p2: tr(Offset(end, y)),
              layer: 'geometry',
            ),
        ];
        test(
          'offset facades cannot form a averaged window barrier: $units/$angle/$mirror',
          () {
            final found = GeometricWindowDetector.detect(drawing(glazing(2)), [
              wall(tr(const Offset(-.4, 0)), tr(Offset.zero), .25 * units),
              wall(
                tr(const Offset(5, 1.3)),
                tr(const Offset(6, 1.3)),
                .25 * units,
              ),
            ], units / 1000);
            expect(
              found,
              isEmpty,
              reason:
                  'Glazing on one facade must not join a wall 1.3 m away from its axis.',
            );
          },
        );
        for (final thicker in [false, true]) {
          test(
            'inset glazing keeps the matching facade face: $units/$angle/$mirror/$thicker',
            () {
              final offset = thicker ? .05 : 0.0;
              final found = GeometricWindowDetector.detect(
                drawing(glazing(2)),
                [
                  wall(tr(const Offset(-.4, 0)), tr(Offset.zero), .25 * units),
                  wall(
                    tr(Offset(2, offset)),
                    tr(Offset(3, offset)),
                    (thicker ? .35 : .25) * units,
                  ),
                ],
                units / 1000,
              );
              expect(found, hasLength(1));
              expect(
                found.single.thickness,
                closeTo((thicker ? .35 : .25) * units, 1e-6),
              );
              expect(
                found.single.barrierPolygon.every(
                  (p) => p.dx.isFinite && p.dy.isFinite,
                ),
                true,
              );
            },
          );
        }
      }
    }
  }
}
