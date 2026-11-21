import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_landscape_models.dart';
import 'package:kotoview/src/features/architect/services/architect_underlay_contour_extractor.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';

DxfDocument _doc(List<DxfEntity> entities, {Map<String, DxfBlock> blocks = const {}}) =>
    DxfDocument(
      entities: entities,
      blocks: blocks,
      layers: {'0': DxfLayer(name: '0'), 'TOPO': DxfLayer(name: 'TOPO')},
      headerVars: const {},
      bounds: const Rect.fromLTRB(-100, -100, 100, 100),
      entityStats: const {},
    );

void main() {
  group('Package 2 — CAD Underlay Contour Extraction', () {
    test('DxfParser preserves 3D POLYLINE VERTEX Z coordinates (code 30)', () {
      const dxf = '''
0
SECTION
2
ENTITIES
0
POLYLINE
8
TOPO
66
1
70
8
0
VERTEX
8
TOPO
10
0.0
20
0.0
30
542.75
0
VERTEX
8
TOPO
10
10.0
20
5.0
30
542.75
0
SEQEND
0
ENDSEC
0
EOF
''';
      final parsed = DxfParser.parseString(dxf);
      final poly = parsed.entities.whereType<DxfPolyline>().single;
      expect(poly.is3D, isTrue);
      expect(poly.vertices.length, 2);
      expect(poly.vertices[0].z, closeTo(542.75, 1e-6));
      expect(poly.vertices[1].z, closeTo(542.75, 1e-6));

      final picked = ArchitectUnderlayContourExtractor.pickAt(
        document: parsed,
        frame: const BimCoordinateFrame(),
        layerVisibility: const {},
        modelPoint: const Offset(5.0, 2.5),
        hitToleranceMeters: 0.5,
      );
      expect(picked, isNotNull);
      expect(picked!.suggestedElevation, closeTo(542.75, 1e-6));
    });

    test('extracts DxfLwPolyline with bulge arcs and DxfSpline curves accurately', () {
      final lw = DxfLwPolyline(
        layer: 'TOPO',
        elevation: 104.5,
        vertices: const [
          DxfPolylineVertex(x: 0, y: 0, bulge: 0.5),
          DxfPolylineVertex(x: 10, y: 0),
        ],
      );
      final spline = DxfSpline(
        layer: 'TOPO',
        degree: 3,
        elevation: 105.0,
        controlPoints: const [
          Offset(0, 10),
          Offset(3, 14),
          Offset(7, 8),
          Offset(12, 12),
        ],
      );
      final doc = _doc([lw, spline]);

      final pickedLw = ArchitectUnderlayContourExtractor.pickAt(
        document: doc,
        frame: const BimCoordinateFrame(),
        layerVisibility: const {},
        modelPoint: const Offset(5, -2.5),
        hitToleranceMeters: 0.5,
      );
      expect(pickedLw, isNotNull);
      expect(pickedLw!.points.length, greaterThan(4)); // expanded bulge arc!
      expect(pickedLw.suggestedElevation, closeTo(104.5, 1e-6));

      final pickedSpline = ArchitectUnderlayContourExtractor.pickAt(
        document: doc,
        frame: const BimCoordinateFrame(),
        layerVisibility: const {},
        modelPoint: const Offset(0.1, 10.0),
        hitToleranceMeters: 0.6,
      );
      expect(pickedSpline, isNotNull);
      expect(pickedSpline!.points.length, greaterThan(10));
      expect(pickedSpline.suggestedElevation, closeTo(105.0, 1e-6));
    });

    test('stitches chained DxfLine/DxfArc, resolves DxfInsert blocks, and bridges inline elevation text gaps', () {
      final blockDoc = _doc(
        [
          // Line 1: (0,0) -> (5,0)
          const DxfLine(layer: 'TOPO', p1: Offset(0, 0), p2: Offset(5, 0)),
          // Text gap at (6.0, 0.0) with label "542.50"
          const DxfText(
            layer: 'TOPO',
            text: '542.50',
            insertPoint: Offset(6.0, 0.0),
            height: 0.5,
          ),
          // Line 2 resumes after text gap: (7,0) -> (12,0)
          const DxfLine(layer: 'TOPO', p1: Offset(7, 0), p2: Offset(12, 0)),
          // Arc connected to (12,0): center (12, 2), radius 2, 270 -> 360 deg (from (12,0) to (14,2))
          const DxfArc(
            layer: 'TOPO',
            center: Offset(12, 2),
            radius: 2,
            startAngleDeg: 270,
            endAngleDeg: 360,
          ),
          // Block instance containing another contour
          const DxfInsert(
            layer: 'TOPO',
            blockName: 'SURVEY_BLK',
            insertPoint: Offset(0, 20),
            scaleX: 2.0,
            scaleY: 2.0,
          ),
        ],
        blocks: {
          'SURVEY_BLK': DxfBlock(
            name: 'SURVEY_BLK',
            entities: const [
              DxfLwPolyline(
                layer: '0',
                elevation: 544.0,
                vertices: [
                  DxfPolylineVertex(x: 0, y: 0),
                  DxfPolylineVertex(x: 5, y: 0),
                  DxfPolylineVertex(x: 5, y: 3),
                ],
              ),
            ],
          ),
        },
      );

      // Aiming on the first line stitches across the text gap AND onto the connected arc!
      final pickedChain = ArchitectUnderlayContourExtractor.pickAt(
        document: blockDoc,
        frame: const BimCoordinateFrame(),
        layerVisibility: const {},
        modelPoint: const Offset(2.0, 0.0),
        hitToleranceMeters: 0.5,
      );
      expect(pickedChain, isNotNull);
      expect(pickedChain!.suggestedElevation, closeTo(542.50, 1e-6));
      expect(pickedChain.points.first.dx, closeTo(0.0, 1e-3));
      expect(pickedChain.points.last.dx, closeTo(14.0, 1e-2));
      expect(pickedChain.points.last.dy, closeTo(2.0, 1e-2));

      // Aiming on the block contour picks the scaled/translated block curve.
      final pickedBlock = ArchitectUnderlayContourExtractor.pickAt(
        document: blockDoc,
        frame: const BimCoordinateFrame(),
        layerVisibility: const {},
        modelPoint: const Offset(5.0, 20.0),
        hitToleranceMeters: 0.5,
      );
      expect(pickedBlock, isNotNull);
      expect(pickedBlock!.suggestedElevation, closeTo(544.0, 1e-6));
      expect(pickedBlock.points.last, const Offset(10.0, 26.0));
    });

    test('clipToBoundaries clips contour cleanly against Terrain outer boundary', () {
      const boundaries = [
        ArchitectTerrainBoundary(
          id: 'b1',
          polygon: [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
          autoInterpolateElevation: true,
        ),
      ];
      final clipped = ArchitectUnderlayContourExtractor.clipToBoundaries(
        points: const [Offset(-5, 5), Offset(15, 5)],
        closed: false,
        boundaries: boundaries,
      );
      expect(clipped.length, 1);
      expect(clipped.single.closed, isFalse);
      expect(clipped.single.points.first.dx, closeTo(0.0, 1e-6));
      expect(clipped.single.points.last.dx, closeTo(10.0, 1e-6));
    });
  });
}
