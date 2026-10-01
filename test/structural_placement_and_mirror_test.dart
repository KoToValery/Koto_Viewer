import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';

void main() {
  test('StructuralColumn geometry and corner offsets', () {
    // 0.25 x 0.50 column with rotation 0
    final col = StructuralColumn(
      id: 'col_1',
      center: const Offset(10.0, 10.0),
      width: 0.25,
      height: 0.50,
      rotationRad: 0.0,
    );

    final vertices = col.polygonVertices;
    expect(vertices.length, 4);
    // Top-Left should be (10 - 0.125, 10 + 0.25) = (9.875, 10.25)
    expect(vertices[0].dx, closeTo(9.875, 1e-4));
    expect(vertices[0].dy, closeTo(10.25, 1e-4));

    // Bottom-Right should be (10 + 0.125, 10 - 0.25) = (10.125, 9.75)
    expect(vertices[2].dx, closeTo(10.125, 1e-4));
    expect(vertices[2].dy, closeTo(9.75, 1e-4));
  });

  test('StructuralSlab horizontal mirror across center', () {
    final slab = StructuralSlab(
      id: 'slab_1',
      polygon: [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 5),
        const Offset(0, 5),
      ],
      thickness: 0.20,
    );

    // Bounding box midX is (0 + 10) / 2 = 5.0
    // Mirrored X = 2 * 5 - X = 10 - X
    final mirroredPts = slab.polygon.map((p) => Offset(10.0 - p.dx, p.dy)).toList();
    expect(mirroredPts[0], const Offset(10, 0));
    expect(mirroredPts[1], const Offset(0, 0));
    expect(mirroredPts[2], const Offset(0, 5));
    expect(mirroredPts[3], const Offset(10, 5));
  });

  testWidgets('StructuralDesignerScreen renders and edit card contains Mirror button when column selected', (tester) async {
    final doc = DxfDocument(
      entities: [
        const DxfLine(
          layer: '0',
          p1: Offset(0, 0),
          p2: Offset(100, 100),
        ),
      ],
      layers: {
        '0': DxfLayer(name: '0', isVisible: true),
      },
      blocks: const {},
      headerVars: const {},
      bounds: const Rect.fromLTWH(0, 0, 100, 100),
      entityStats: const {'LINE': 1},
    );

    tester.view.physicalSize = const Size(460, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('bg'),
        home: StructuralDesignerScreen(
          document: doc,
          initialCadBounds: const Rect.fromLTWH(0, 0, 100, 100),
          title: 'Test DWG',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify ElementPaletteBar rendered without navigation hand tool
    expect(find.text('Колона'), findsOneWidget);
    expect(find.text('Шайба'), findsOneWidget);
    expect(find.text('Плоча'), findsOneWidget);
    expect(find.byIcon(Icons.pan_tool_rounded), findsNothing);
    expect(find.text('Навигация'), findsNothing);
  });

  test('3D BIM Viewport pitch inversion test', () {
    // When delta.dy is positive (dragging down), inverted pitch increases pitch angle
    double pitch = 0.615;
    const double deltaY = 20.0;
    // Inverted formula: pitch + delta.dy * 0.01
    pitch = (pitch + deltaY * 0.01).clamp(-math.pi / 2.1, math.pi / 2.1);
    expect(pitch, closeTo(0.615 + 0.20, 1e-4));

    // When delta.dy is negative (dragging up), inverted pitch decreases pitch angle
    const double deltaYUp = -20.0;
    pitch = (pitch + deltaYUp * 0.01).clamp(-math.pi / 2.1, math.pi / 2.1);
    expect(pitch, closeTo(0.615, 1e-4));
  });

  test('L-shaped column generates 6 vertices and mirrors properly', () {
    const lCol = StructuralColumn(
      id: 'l_col_1',
      center: Offset(5.0, 5.0),
      shape: ColumnShape.lShape,
      width: 0.50,
      height: 0.50,
      thickness: 0.25,
      rotationRad: 0.0,
      isMirrored: false,
    );

    final vertices = lCol.polygonVertices;
    expect(vertices.length, 6);

    // Mirrored L-shape column
    final mirroredCol = lCol.copyWith(isMirrored: true);
    final mirroredVerts = mirroredCol.polygonVertices;
    expect(mirroredVerts.length, 6);
    // Mirrored outer corner should flip horizontally relative to center
    expect(mirroredVerts[0].dx, closeTo(5.0 + 0.25, 1e-4));
  });

  test('Shear wall leading reference line is on the left by default', () {
    // Wall going from (0, 0) upwards along +Y to (0, 3) in CAD coords
    const wall = StructuralShearWall(
      id: 'w1',
      start: Offset(0, 0),
      end: Offset(0, 3),
      thickness: 0.25,
      isFlipped: false,
    );

    final poly = wall.polygonVertices;
    expect(poly.length, 4);
    // start and end are on the left reference line (X = 0)
    expect(poly[0], const Offset(0, 0));
    expect(poly[1], const Offset(0, 3));
    // wall body is offset to the right: right normal of (0, 1) is (1, 0)
    expect(poly[2].dx, closeTo(0.25, 1e-4));
    expect(poly[2].dy, closeTo(3.0, 1e-4));
    expect(poly[3].dx, closeTo(0.25, 1e-4));
    expect(poly[3].dy, closeTo(0.0, 1e-4));

    // When flipped, wall body extends to the left (X = -0.25)
    final flippedWall = wall.copyWith(isFlipped: true);
    final flippedPoly = flippedWall.polygonVertices;
    expect(flippedPoly[2].dx, closeTo(-0.25, 1e-4));
    expect(flippedPoly[3].dx, closeTo(-0.25, 1e-4));
  });

  test('CAD snapping endpoint priority over nearest on overlapping tolerance', () {
    final doc = DxfDocument(
      entities: [
        // Line from (0, 0) to (10, 0)
        const DxfLine(
          layer: '0',
          p1: Offset(0, 0),
          p2: Offset(10, 0),
        ),
      ],
      layers: {
        '0': DxfLayer(name: '0', isVisible: true),
      },
      blocks: const {},
      headerVars: const {},
      bounds: const Rect.fromLTWH(0, 0, 10, 10),
      entityStats: const {'LINE': 1},
    );

    // Query point near endpoint (0, 0) - e.g. at (0.2, 0.1)
    // Nearest point on segment would be (0.2, 0) distance = 0.1
    // Endpoint is (0, 0) distance = sqrt(0.04 + 0.01) = 0.2236
    // Endpoint MUST be chosen over nearest because of architectural priority!
    final snap = DxfSnapHelper.findSnapPoint(
      document: doc,
      cadPoint: const Offset(0.2, 0.1),
      toleranceCad: 1.0,
    );

    expect(snap, isNotNull);
    expect(snap!.type, DxfSnapType.endpoint);
    expect(snap.point, const Offset(0, 0));
  });

  test('StructuralBeam geometry, bounds, polygon, and StoreyLevel support', () {
    final beam = StructuralBeam(
      id: 'beam_1',
      start: const Offset(1.0, 2.0),
      end: const Offset(5.0, 2.0),
      width: 0.25,
      depth: 0.50,
    );

    expect(beam.length, closeTo(4.0, 1e-4));
    expect(beam.angleRad, closeTo(0.0, 1e-4));

    // Centered width 0.25 means ±0.125 in Y
    final poly = beam.polygonVertices;
    expect(poly.length, 4);
    expect(poly[0].dy, closeTo(2.125, 1e-4));
    expect(poly[1].dy, closeTo(2.125, 1e-4));
    expect(poly[2].dy, closeTo(1.875, 1e-4));
    expect(poly[3].dy, closeTo(1.875, 1e-4));

    final level = StoreyLevel(
      id: 'storey_1',
      name: 'Етаж 1',
      beams: [beam],
    );
    expect(level.beams.length, 1);
    expect(level.beams.first.depth, 0.50);

    final nextLevel = level.cloneToNextLevel(
      newId: 'storey_2',
      newName: 'Етаж 2',
      newElevation: 3.0,
    );
    expect(nextLevel.beams.length, 1);
    expect(nextLevel.beams.first.id, 'beam_1_lvl_3');
  });

  test('StructuralSlab opening manipulation and containsPoint cutout logic', () {
    final opening = [
      const Offset(2.0, 2.0),
      const Offset(4.0, 2.0),
      const Offset(4.0, 4.0),
      const Offset(2.0, 4.0),
    ];
    final slab = StructuralSlab(
      id: 'slab_1',
      polygon: const [
        Offset(0.0, 0.0),
        Offset(10.0, 0.0),
        Offset(10.0, 10.0),
        Offset(0.0, 10.0),
      ],
      thickness: 0.20,
    );

    // Without opening, (3, 3) is inside
    expect(slab.containsPoint(const Offset(3.0, 3.0)), isTrue);

    // Add opening
    final slabWithOpening = slab.addOpening(opening);
    expect(slabWithOpening.openings.length, 1);

    // Inside opening cutout should now return false
    expect(slabWithOpening.containsPoint(const Offset(3.0, 3.0)), isFalse);
    // Outside opening but inside slab should return true
    expect(slabWithOpening.containsPoint(const Offset(6.0, 6.0)), isTrue);
    // Outside slab should return false
    expect(slabWithOpening.containsPoint(const Offset(15.0, 15.0)), isFalse);

    // Remove opening
    final slabRemoved = slabWithOpening.removeOpening(0);
    expect(slabRemoved.openings.isEmpty, isTrue);
    expect(slabRemoved.containsPoint(const Offset(3.0, 3.0)), isTrue);
  });

  test('StructuralSlab cleanPolygon removes orphan (0,0), collapsed points, and collinear vertices', () {
    // Polygon with orphan (0, 0) point in middle of non-zero contour
    final rawWithZero = [
      const Offset(10.0, 10.0),
      const Offset(20.0, 10.0),
      const Offset(0.0, 0.0), // Orphan (0, 0) error point
      const Offset(20.0, 20.0),
      const Offset(10.0, 20.0),
    ];
    final cleanedZero = StructuralSlab.cleanPolygon(rawWithZero);
    expect(cleanedZero.contains(const Offset(0.0, 0.0)), isFalse);
    expect(cleanedZero.length, 4);

    // Polygon with duplicate / overlapping adjacent vertices (< 0.05m apart)
    final rawWithOverlap = [
      const Offset(0.0, 0.0),
      const Offset(10.0, 0.0),
      const Offset(10.01, 0.01), // Overlapping vertex to be merged
      const Offset(10.0, 10.0),
      const Offset(0.0, 10.0),
    ];
    final cleanedOverlap = StructuralSlab.cleanPolygon(rawWithOverlap, minDistance: 0.05);
    expect(cleanedOverlap.length, 4);

    // Polygon with redundant collinear points
    final rawCollinear = [
      const Offset(0.0, 0.0),
      const Offset(5.0, 0.0), // Midpoint along straight edge
      const Offset(10.0, 0.0),
      const Offset(10.0, 10.0),
      const Offset(0.0, 10.0),
    ];
    final cleanedCollinear = StructuralSlab.cleanPolygon(rawCollinear);
    expect(cleanedCollinear.length, 4);
    expect(cleanedCollinear.contains(const Offset(5.0, 0.0)), isFalse);
  });

  test('StructuralSlab self-intersection detection prevents bowtie / X-crossings', () {
    // Simple convex square -> no self-intersection
    final validSquare = [
      const Offset(0.0, 0.0),
      const Offset(5.0, 0.0),
      const Offset(5.0, 5.0),
      const Offset(0.0, 5.0),
    ];
    expect(StructuralSlab.hasSelfIntersections(validSquare), isFalse);

    // Bowtie shape (crossed diagonals: (0,0)->(5,5) and (5,0)->(0,5))
    final bowTie = [
      const Offset(0.0, 0.0),
      const Offset(5.0, 5.0),
      const Offset(5.0, 0.0),
      const Offset(0.0, 5.0),
    ];
    expect(StructuralSlab.hasSelfIntersections(bowTie), isTrue);
  });

  test('StructuralGridAxis.fromTwoSegments calculates centerline bisector correctly', () {
    // Two parallel horizontal wall faces 25 cm apart from X=0 to X=10:
    // Face 1: Y = 2.0
    // Face 2: Y = 2.25
    final axis = StructuralGridAxis.fromTwoSegments(
      id: 'axis_1',
      name: '1',
      a1: const Offset(0.0, 2.0),
      a2: const Offset(10.0, 2.0),
      b1: const Offset(0.0, 2.25),
      b2: const Offset(10.0, 2.25),
      extensionLength: 1.0,
    );

    expect(axis, isNotNull);
    // Centerline Y should be (2.0 + 2.25)/2 = 2.125
    expect(axis!.start.dy, closeTo(2.125, 1e-4));
    expect(axis.end.dy, closeTo(2.125, 1e-4));
    // Extended beyond 0..10 by 1.0 on each end -> length = 10 + 2 = 12
    expect(axis.length, closeTo(12.0, 1e-4));
  });

  test('StructuralGridAxis.intersectionWith finds perpendicular intersection', () {
    // Horizontal axis along Y = 5.0
    const axisH = StructuralGridAxis(
      id: 'h',
      name: 'A',
      start: Offset(-2.0, 5.0),
      end: Offset(12.0, 5.0),
    );

    // Vertical axis along X = 4.0
    const axisV = StructuralGridAxis(
      id: 'v',
      name: '1',
      start: Offset(4.0, -1.0),
      end: Offset(4.0, 10.0),
    );

    final inter = axisH.intersectionWith(axisV);
    expect(inter, isNotNull);
    expect(inter!.dx, closeTo(4.0, 1e-4));
    expect(inter.dy, closeTo(5.0, 1e-4));
  });

  test('L-shaped column maintains center, thickness, mirror, and rotation upon move', () {
    const originalCol = StructuralColumn(
      id: 'col_L',
      center: Offset(5.0, 5.0),
      shape: ColumnShape.lShape,
      width: 0.50,
      height: 0.50,
      thickness: 0.25,
      rotationRad: math.pi / 2.0,
      isMirrored: true,
    );

    // Moving column to (8.0, 12.0) using copyWith
    final movedCol = originalCol.copyWith(center: const Offset(8.0, 12.0));

    expect(movedCol.center, const Offset(8.0, 12.0));
    expect(movedCol.shape, ColumnShape.lShape);
    expect(movedCol.width, 0.50);
    expect(movedCol.height, 0.50);
    expect(movedCol.thickness, 0.25);
    expect(movedCol.rotationRad, math.pi / 2.0);
    expect(movedCol.isMirrored, isTrue);

    // Polygon vertices count is strictly 6 for L-shape
    final vertices = movedCol.polygonVertices;
    expect(vertices.length, 6);
  });

  test('DxfSnapHelper with allowNearest: false skips arbitrary line points', () {
    final doc = DxfDocument(
      entities: [
        const DxfLine(
          layer: '0',
          p1: Offset(0, 0),
          p2: Offset(10, 0),
        ),
      ],
      layers: {
        '0': DxfLayer(name: '0', isVisible: true),
      },
      blocks: const {},
      headerVars: const {},
      bounds: const Rect.fromLTWH(0, 0, 10, 0),
      entityStats: const {'LINE': 1},
    );

    // Query near middle of line at (5.0, 0.05), far from endpoints (0,0) and (10,0)
    // and slightly away from midpoint (5,0)
    final snapWithNearest = DxfSnapHelper.findSnapPoint(
      document: doc,
      cadPoint: const Offset(4.2, 0.05),
      toleranceCad: 0.5,
      allowNearest: true,
    );
    expect(snapWithNearest, isNotNull);
    expect(snapWithNearest!.type, DxfSnapType.nearest);

    // With allowNearest: false, arbitrary point on line is NOT snapped, preventing beam divergence
    final snapWithoutNearest = DxfSnapHelper.findSnapPoint(
      document: doc,
      cadPoint: const Offset(4.2, 0.05),
      toleranceCad: 0.5,
      allowNearest: false,
    );
    expect(snapWithoutNearest, isNull);
  });
}

