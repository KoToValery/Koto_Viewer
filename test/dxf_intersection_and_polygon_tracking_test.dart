import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_segment_snap.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_vertex_snap.dart';

DxfDocument drawing(
  List<DxfEntity> entities, {
  Map<String, DxfBlock> blocks = const {},
  bool visible = true,
}) => DxfDocument(
  entities: entities,
  blocks: blocks,
  layers: {
    'axes': DxfLayer(name: 'axes', isVisible: visible, lineType: 'DASHDOT'),
  },
  headerVars: {},
  bounds: const Rect.fromLTWH(-10, -10, 20, 20),
  entityStats: {},
);
void main() {
  for (final units in [1.0, 100.0, 1000.0]) {
    for (final angle in [0.0, .43, math.pi / 2]) {
      Offset tr(Offset p) =>
          Offset(
                p.dx * math.cos(angle) - p.dy * math.sin(angle),
                p.dx * math.sin(angle) + p.dy * math.cos(angle),
              ) *
              units +
          const Offset(600000, 400000);
      test('CAD dash-dot intersections are exact at $units/$angle', () {
        final doc = drawing([
          DxfLine(
            p1: tr(const Offset(-3, 0)),
            p2: tr(const Offset(7, 0)),
            layer: 'axes',
          ),
          DxfPolyline(
            vertices: [
              for (final p in [const Offset(0, -4), const Offset(0, 8)])
                DxfPolylineVertex(x: tr(p).dx, y: tr(p).dy),
            ],
            layer: 'axes',
          ),
        ]);
        final snap = DxfSnapHelper.findSnapPoint(
          document: doc,
          cadPoint: tr(const Offset(.02, .03)),
          toleranceCad: .1 * units,
          includeIntersections: true,
        )!;
        expect(snap.type, DxfSnapType.intersection);
        expect((snap.point - tr(Offset.zero)).distance, lessThan(1e-6 * units));
      });
      test(
        'rotated wall tracking uses previous point without a distant jump at $units/$angle',
        () {
          final previous = tr(Offset.zero), expected = tr(const Offset(0, 3));
          final result = SlabVertexSnap.align(
            raw: tr(const Offset(.03, 3)),
            previous: previous,
            edges: [(tr(const Offset(-3, 0)), tr(const Offset(7, 0)))],
            tolerance: .05 * units,
          );
          expect(
            (result.snap!.point - expected).distance,
            lessThan(1e-6 * units),
          );
          expect(result.guides.last, (previous, result.snap!.point));
          expect(
            SlabVertexSnap.align(
              raw: tr(const Offset(1.5, 3)),
              previous: previous,
              edges: [(tr(const Offset(-3, 0)), tr(const Offset(7, 0)))],
              tolerance: .05 * units,
            ).snap,
            isNull,
          );
        },
      );
    }
  }
  test(
    'line extensions, parallel lines, hidden layers and paper-space cannot create intersections',
    () {
      for (final doc in [
        drawing([
          const DxfLine(p1: Offset(-5, 0), p2: Offset(-1, 0), layer: 'axes'),
          const DxfLine(p1: Offset(0, -5), p2: Offset(0, 5), layer: 'axes'),
        ]),
        drawing([
          const DxfLine(p1: Offset(-5, 0), p2: Offset(5, 0), layer: 'axes'),
          const DxfLine(p1: Offset(-5, .04), p2: Offset(5, .04), layer: 'axes'),
        ]),
        drawing([
          const DxfLine(p1: Offset(-5, 0), p2: Offset(5, 0), layer: 'axes'),
          const DxfLine(p1: Offset(0, -5), p2: Offset(0, 5), layer: 'axes'),
        ], visible: false),
        drawing([
          const DxfLine(p1: Offset(-5, 0), p2: Offset(5, 0), layer: 'axes'),
          const DxfLine(
            p1: Offset(0, -5),
            p2: Offset(0, 5),
            layer: 'axes',
            isPaperSpace: true,
          ),
        ]),
        drawing([
          const DxfLwPolyline(
            vertices: [
              DxfPolylineVertex(x: -5, y: 0, bulge: 1),
              DxfPolylineVertex(x: 5, y: 0),
            ],
            layer: 'axes',
          ),
          const DxfLine(p1: Offset(0, -5), p2: Offset(0, 5), layer: 'axes'),
        ]),
      ]) {
        expect(
          DxfSegmentSnap.nearestIntersection(
            document: doc,
            point: Offset.zero,
            tolerance: .1,
          ),
          isNull,
        );
      }
    },
  );
  test(
    'nested, mirrored and nonuniformly scaled block axes inherit visibility',
    () {
      final doc = drawing(
        [
          const DxfInsert(
            blockName: 'outer',
            insertPoint: Offset(10, 20),
            rotationDeg: 30,
            scaleX: 2,
            scaleY: .5,
            layer: 'axes',
          ),
        ],
        blocks: {
          'outer': DxfBlock(
            name: 'outer',
            basePoint: Offset.zero,
            entities: [
              DxfInsert(
                blockName: 'inner',
                insertPoint: Offset(1, 2),
                scaleX: -1,
                rotationDeg: 90,
              ),
            ],
          ),
          'inner': DxfBlock(
            name: 'inner',
            basePoint: Offset.zero,
            entities: [
              DxfLine(p1: Offset(-3, 0), p2: Offset(7, 0)),
              DxfLine(p1: Offset(0, -4), p2: Offset(0, 8)),
            ],
          ),
        },
      );
      final expected = Offset(
        10 + 2 * math.cos(math.pi / 6) - math.sin(math.pi / 6),
        20 + 2 * math.sin(math.pi / 6) + math.cos(math.pi / 6),
      );
      final result = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: expected + const Offset(.02, .01),
        toleranceCad: .1,
        includeIntersections: true,
      )!;
      expect(result.type, DxfSnapType.intersection);
      expect((result.point - expected).distance, lessThan(1e-8));
      doc.layers['axes']!.isVisible = false;
      expect(
        DxfSegmentSnap.nearestIntersection(
          document: doc,
          point: expected,
          tolerance: .1,
        ),
        isNull,
      );
    },
  );
}
