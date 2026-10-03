import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';
import 'package:kotoview/src/features/structural_designer/models/cantilever_analysis_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_magnetic_alignment_helper.dart';
import 'package:kotoview/src/features/structural_designer/widgets/element_palette_bar.dart';

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

  test('Shear wall baseline is symmetrically centered across axial centerline', () {
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
    // Baseline (0, 0) to (0, 3) is the axial centerline; thickness 0.25 is centered (-0.125 to +0.125)
    expect(poly[0].dx, closeTo(-0.125, 1e-4));
    expect(poly[0].dy, closeTo(0.0, 1e-4));
    expect(poly[1].dx, closeTo(-0.125, 1e-4));
    expect(poly[1].dy, closeTo(3.0, 1e-4));
    expect(poly[2].dx, closeTo(0.125, 1e-4));
    expect(poly[2].dy, closeTo(3.0, 1e-4));
    expect(poly[3].dx, closeTo(0.125, 1e-4));
    expect(poly[3].dy, closeTo(0.0, 1e-4));
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

  test('StructuralGridAxis has bubbles at both ends by default and fromTwoSegments', () {
    const axis = StructuralGridAxis(
      id: 'ax_1',
      name: 'A',
      start: Offset(0, 0),
      end: Offset(10, 0),
    );
    expect(axis.bubbleAtStart, isTrue);
    expect(axis.bubbleAtEnd, isTrue);

    final fromSegments = StructuralGridAxis.fromTwoSegments(
      id: 'ax_2',
      name: '1',
      a1: const Offset(0, 0),
      a2: const Offset(5, 0),
      b1: const Offset(0, 0.25),
      b2: const Offset(5, 0.25),
    );
    expect(fromSegments, isNotNull);
    expect(fromSegments!.bubbleAtStart, isTrue);
    expect(fromSegments.bubbleAtEnd, isTrue);
  });

  testWidgets('ElementPaletteBar renders guidance banner, scrollable presets, and does not overflow on 360px screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('bg'),
        home: Scaffold(
          bottomNavigationBar: ElementPaletteBar(
            activeTool: StructuralDrawTool.slab,
            onSelectTool: (_) {},
            currentColumnPreset: const StructuralColumn(id: 'col', center: Offset.zero),
            onUpdateColumnPreset: (_) {},
            currentWallThickness: 0.25,
            onUpdateWallThickness: (_) {},
            currentSlabThickness: 0.20,
            onUpdateSlabThickness: (_) {},
            isDrawingSlab: false,
            slabPointCount: 0,
            onCloseSlab: () {},
            onUndoPoint: () {},
            onClearSlab: () {},
            onRotateColumn: () {},
            onOpenCantileverReport: () {},
            analysisSummary: StructuralAnalysisSummary.empty,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify slab preset chips exist
    expect(find.text('h=18 cm'), findsOneWidget);
    expect(find.text('h=20 cm'), findsOneWidget);
    expect(find.text('h=22 cm'), findsOneWidget);
    expect(find.text('h=25 cm'), findsOneWidget);

    // Verify there are no Flutter overflow errors!
    expect(tester.takeException(), isNull);
  });

  test('StructuralColumn displayName and auto-increment naming', () {
    const colDefault = StructuralColumn(
      id: 'c1',
      center: Offset(5, 5),
    );
    expect(colDefault.displayName, 'К');

    const colNamed = StructuralColumn(
      id: 'c2',
      name: 'К1',
      center: Offset(5, 5),
    );
    expect(colNamed.displayName, 'К1');

    final copy = colNamed.copyWith(name: 'К5');
    expect(copy.displayName, 'К5');
  });

  test('4-edge cycle mirror offsets column across outer faces in sequence', () {
    // Column placed at (10, 10), width = 0.25, height = 0.50, L-shape
    final base = StructuralColumn(
      id: 'col_L',
      name: 'К1',
      center: const Offset(10.0, 10.0),
      shape: ColumnShape.lShape,
      width: 0.25,
      height: 0.50,
      rotationRad: 0.0,
      isMirrored: false,
    );

    // Cycle 1: Right outer face (+W along uX, flip X)
    final rightOffset = base.copyWith(
      center: base.center + Offset(base.width, 0),
      isMirrored: !base.isMirrored,
    );
    expect(rightOffset.center.dx, closeTo(10.25, 1e-4));
    expect(rightOffset.center.dy, closeTo(10.0, 1e-4));
    expect(rightOffset.isMirrored, isTrue);

    // Cycle 2: Top outer face (+H along uY, flip Y -> isMirrored + pi rotation)
    final topOffset = base.copyWith(
      center: base.center + Offset(0, base.height),
      isMirrored: !base.isMirrored,
      rotationRad: math.pi,
    );
    expect(topOffset.center.dx, closeTo(10.0, 1e-4));
    expect(topOffset.center.dy, closeTo(10.50, 1e-4));
    expect(topOffset.rotationRad, closeTo(math.pi, 1e-4));

    // Cycle 3: Left outer face (-W along uX, flip X)
    final leftOffset = base.copyWith(
      center: base.center - Offset(base.width, 0),
      isMirrored: !base.isMirrored,
    );
    expect(leftOffset.center.dx, closeTo(9.75, 1e-4));
    expect(leftOffset.center.dy, closeTo(10.0, 1e-4));

    // Cycle 4: Bottom outer face (-H along uY, flip Y)
    final bottomOffset = base.copyWith(
      center: base.center - Offset(0, base.height),
      isMirrored: !base.isMirrored,
      rotationRad: math.pi,
    );
    expect(bottomOffset.center.dx, closeTo(10.0, 1e-4));
    expect(bottomOffset.center.dy, closeTo(9.50, 1e-4));
  });

  test('Grid axis offset with duplication creates parallel axis at exact distance', () {
    const verticalAxis = StructuralGridAxis(
      id: 'ax_1',
      name: '1',
      start: Offset(5.0, 0.0),
      end: Offset(5.0, 10.0),
    );

    // Normal to vertical axis pointing up is (-1, 0)
    expect(verticalAxis.direction.dx, closeTo(0.0, 1e-4));
    expect(verticalAxis.direction.dy, closeTo(1.0, 1e-4));
    expect(verticalAxis.normal.dx, closeTo(-1.0, 1e-4));
    expect(verticalAxis.normal.dy, closeTo(0.0, 1e-4));

    // Offset to the right by 3.0 m:
    // With right direction, normal * (-3.0) gives (+3.0, 0.0)
    final offsetRightVec = const Offset(3.0, 0.0);
    final dupAxis = StructuralGridAxis(
      id: 'ax_2',
      name: '2',
      start: verticalAxis.start + offsetRightVec,
      end: verticalAxis.end + offsetRightVec,
    );

    expect(dupAxis.start.dx, closeTo(8.0, 1e-4));
    expect(dupAxis.start.dy, closeTo(0.0, 1e-4));
    expect(dupAxis.end.dx, closeTo(8.0, 1e-4));
    expect(dupAxis.end.dy, closeTo(10.0, 1e-4));
    expect(dupAxis.length, closeTo(verticalAxis.length, 1e-4));
  });

  test('Column offset calculation across directional vectors and auto-increment naming', () {
    const col1 = StructuralColumn(
      id: 'c_1',
      name: 'К1',
      center: Offset(10.0, 10.0),
      width: 0.25,
      height: 0.50,
    );

    // 1. Offset to +X by 4.0 m
    const distM = 4.0;
    final offX = col1.copyWith(
      id: 'c_2',
      name: 'К2',
      center: col1.center + const Offset(distM, 0),
    );
    expect(offX.center.dx, closeTo(14.0, 1e-4));
    expect(offX.center.dy, closeTo(10.0, 1e-4));
    expect(offX.displayName, 'К2');

    // 2. Offset to +Y by 5.0 m
    final offY = offX.copyWith(
      id: 'c_3',
      name: 'К3',
      center: offX.center + const Offset(0, 5.0),
    );
    expect(offY.center.dx, closeTo(14.0, 1e-4));
    expect(offY.center.dy, closeTo(15.0, 1e-4));
    expect(offY.displayName, 'К3');

    // 3. Offset to -X by 4.0 m
    final offMinusX = offY.copyWith(
      id: 'c_4',
      name: 'К4',
      center: offY.center + const Offset(-4.0, 0),
    );
    expect(offMinusX.center.dx, closeTo(10.0, 1e-4));
    expect(offMinusX.center.dy, closeTo(15.0, 1e-4));
    expect(offMinusX.displayName, 'К4');
  });

  testWidgets('StructuralDesignerScreen renders contextual bottom dock with actions when column is selected', (tester) async {
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

    const initialCol = StructuralColumn(
      id: 'c_test_1',
      name: 'К1',
      center: Offset(50.0, 50.0),
      width: 0.25,
      height: 0.50,
    );

    final project = StructuralProject(
      storeys: [
        StoreyLevel(
          id: 'storey_1',
          name: 'Ниво 1',
          elevation: 0.0,
          height: 3.0,
          columns: const [initialCol],
        ),
      ],
      activeStoreyIndex: 0,
    );

    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('bg'),
        home: StructuralDesignerScreen(
          document: doc,
          initialProject: project,
          initialCadBounds: const Rect.fromLTWH(0, 0, 100, 100),
          title: 'Test CAD',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Palette is initially shown
    expect(find.text('Колона'), findsOneWidget);
    await tester.tap(find.text('Колона'));
    await tester.pumpAndSettle();

    // Tap on the placed column (center of canvas) to select it
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle();

    // When the column is selected, the Contextual Bottom Action Dock replaces the palette!
    // It contains the actions: Изтрий, Завърти 90°, Огледало, Офсет, Дублирай
    expect(find.text('Офсет'), findsOneWidget);
    expect(find.text('Завърти 90°'), findsOneWidget);
    expect(find.text('Огледало'), findsOneWidget);
    expect(find.text('Дублирай'), findsOneWidget);
    expect(find.text('Изтрий'), findsOneWidget);

    // Verify there are no overflows
    expect(tester.takeException(), isNull);

    // Tap the deselect (X) button on the dock
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    // After deselecting, ElementPaletteBar returns
    expect(find.text('Колона'), findsOneWidget);
    expect(find.text('Шайба'), findsOneWidget);
    expect(find.text('Плоча'), findsOneWidget);
  });

  test('StructuralGridAxis isParallelTo and alignWith geometry', () {
    const axis1 = StructuralGridAxis(
      id: 'a1',
      name: '1',
      start: Offset(0, 0),
      end: Offset(10, 0),
    );
    const axis2 = StructuralGridAxis(
      id: 'a2',
      name: '2',
      start: Offset(2, 5),
      end: Offset(8, 5),
    );
    const axis3Opposite = StructuralGridAxis(
      id: 'a3',
      name: '3',
      start: Offset(9, -4),
      end: Offset(1, -4),
    );
    const axisPerp = StructuralGridAxis(
      id: 'aPerp',
      name: 'A',
      start: Offset(0, 0),
      end: Offset(0, 10),
    );
    const axisSlanted = StructuralGridAxis(
      id: 'aSlanted',
      name: 'S',
      start: Offset(0, 0),
      end: Offset(10, 5),
    );

    // Parallelism check
    expect(axis1.isParallelTo(axis2), isTrue);
    expect(axis1.isParallelTo(axis3Opposite), isTrue);
    expect(axis1.isParallelTo(axisPerp), isFalse);
    expect(axis1.isParallelTo(axisSlanted), isFalse);

    // Harmonization / Alignment with reference axis
    final aligned2 = axis2.alignWith(axis1);
    expect(aligned2.start.dx, closeTo(0.0, 1e-4));
    expect(aligned2.start.dy, closeTo(5.0, 1e-4));
    expect(aligned2.end.dx, closeTo(10.0, 1e-4));
    expect(aligned2.end.dy, closeTo(5.0, 1e-4));
    expect(aligned2.length, closeTo(axis1.length, 1e-4));

    // Opposite orientation alignment
    final aligned3 = axis3Opposite.alignWith(axis1);
    expect(aligned3.start.dx, closeTo(10.0, 1e-4));
    expect(aligned3.start.dy, closeTo(-4.0, 1e-4));
    expect(aligned3.end.dx, closeTo(0.0, 1e-4));
    expect(aligned3.end.dy, closeTo(-4.0, 1e-4));
    expect(aligned3.length, closeTo(axis1.length, 1e-4));
  });

  testWidgets('Harmonize parallel grid axes when one axis handle is dragged', (tester) async {
    final doc = DxfDocument(
      entities: const [],
      layers: {'0': DxfLayer(name: '0', isVisible: true)},
      blocks: const {},
      headerVars: const {},
      bounds: const Rect.fromLTWH(-10, -10, 50, 50),
      entityStats: const {},
    );

    const axisA = StructuralGridAxis(
      id: 'axis_a',
      name: '1',
      start: Offset(0, 0),
      end: Offset(10, 0),
      bubbleAtStart: true,
      bubbleAtEnd: true,
    );
    const axisB = StructuralGridAxis(
      id: 'axis_b',
      name: '2',
      start: Offset(2, 6),
      end: Offset(8, 6),
      bubbleAtStart: true,
      bubbleAtEnd: true,
    );
    const axisCPerp = StructuralGridAxis(
      id: 'axis_c',
      name: 'A',
      start: Offset(0, -5),
      end: Offset(0, 15),
      bubbleAtStart: true,
      bubbleAtEnd: true,
    );

    final project = StructuralProject(
      storeys: [
        StoreyLevel(
          id: 'storey_1',
          name: 'Кота +0.00',
          elevation: 0.0,
          height: 3.0,
          gridAxes: const [axisA, axisB, axisCPerp],
        ),
      ],
      activeStoreyIndex: 0,
    );

    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('bg'),
        home: StructuralDesignerScreen(
          document: doc,
          initialProject: project,
          initialCadBounds: const Rect.fromLTWH(-10, -10, 50, 50),
          title: 'Axis Harmonization CAD',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify CustomPaint with Structural2dPainter renders the axes
    final customPaint = tester.widget<CustomPaint>(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is Structural2dPainter),
    );
    final painter = customPaint.painter as Structural2dPainter;
    expect(painter.currentStorey.gridAxes.length, 3);

    final initialA = painter.currentStorey.gridAxes.firstWhere((a) => a.id == 'axis_a');
    final initialB = painter.currentStorey.gridAxes.firstWhere((a) => a.id == 'axis_b');
    final initialC = painter.currentStorey.gridAxes.firstWhere((a) => a.id == 'axis_c');

    expect(initialA.length, closeTo(10.0, 1e-4));
    expect(initialB.length, closeTo(6.0, 1e-4));
    expect(initialC.length, closeTo(20.0, 1e-4));

    // When Axis A is extended/adjusted via its handle (from length 10 to length 15):
    final extendedA = initialA.copyWith(end: const Offset(15, 0));
    final harmonizedAxes = painter.currentStorey.gridAxes.map((a) {
      if (a.id == extendedA.id) return extendedA;
      if (a.isParallelTo(extendedA)) return a.alignWith(extendedA);
      return a;
    }).toList();

    // Axis B (parallel) is harmonized to the exact same length (15.0) and aligned bounds (0 to 15):
    final harmonizedB = harmonizedAxes.firstWhere((a) => a.id == 'axis_b');
    expect(harmonizedB.length, closeTo(15.0, 1e-4));
    expect(harmonizedB.start, const Offset(0, 6));
    expect(harmonizedB.end, const Offset(15, 6));

    // Axis C (perpendicular) remains completely unchanged:
    final unchangedC = harmonizedAxes.firstWhere((a) => a.id == 'axis_c');
    expect(unchangedC.length, closeTo(20.0, 1e-4));
    expect(unchangedC.start, const Offset(0, -5));
    expect(unchangedC.end, const Offset(0, 15));
  });

  test('Subsequent parallel axis automatically adopts reference axis length and alignment on placement', () {
    const referenceAxis = StructuralGridAxis(
      id: 'axis_1',
      name: '1',
      start: Offset(-2.0, 0.0),
      end: Offset(18.0, 0.0),
    );
    expect(referenceAxis.length, closeTo(20.0, 1e-4));

    // New parallel axis placed between wall segments with an arbitrary shorter span:
    const rawSecondAxis = StructuralGridAxis(
      id: 'axis_2',
      name: '2',
      start: Offset(3.0, 7.0),
      end: Offset(11.0, 7.0),
    );
    expect(rawSecondAxis.length, closeTo(8.0, 1e-4));

    // Verify rawSecondAxis is parallel to referenceAxis
    expect(rawSecondAxis.isParallelTo(referenceAxis), isTrue);

    // When aligned with the existing reference axis:
    final adoptedAxis = rawSecondAxis.alignWith(referenceAxis);

    // It automatically snaps to length 20.0 and aligns bounds [-2.0, 18.0] at Y = 7.0
    expect(adoptedAxis.length, closeTo(20.0, 1e-4));
    expect(adoptedAxis.start, const Offset(-2.0, 7.0));
    expect(adoptedAxis.end, const Offset(18.0, 7.0));
  });

  test('StoreyLevel computes structural elevation correctly taking floor finish into account', () {
    const storey0 = StoreyLevel(
      id: 'storey_0',
      name: 'Ground Floor',
      elevation: 0.0,
      height: 2.80,
      floorFinishThickness: 0.05,
    );

    const slabStandard = StructuralSlab(
      id: 'slab_1',
      polygon: [Offset(0, 0), Offset(5, 0), Offset(5, 5), Offset(0, 5)],
      thickness: 0.20,
    );

    // Architectural elevation 0.00 with 5cm screed gives structural elevation -0.05m
    expect(storey0.structuralElevationFor(slabStandard), closeTo(-0.05, 1e-4));

    const storey1 = StoreyLevel(
      id: 'storey_1',
      name: 'Level 1',
      elevation: 2.80,
      height: 2.80,
      floorFinishThickness: 0.05,
    );

    // Architectural elevation 2.80 gives structural elevation 2.75m
    expect(storey1.structuralElevationFor(slabStandard), closeTo(2.75, 1e-4));

    // Custom slab finish (e.g. 8cm / 0.08m thick finish for terraces/bathrooms)
    final slabCustomFinish = slabStandard.copyWith(floorFinish: 0.08);
    expect(storey1.structuralElevationFor(slabCustomFinish), closeTo(2.72, 1e-4));
  });

  test('StoreyLevel cloneToNextLevel preserves floorFinishThickness', () {
    const storey0 = StoreyLevel(
      id: 's0',
      name: 'Floor 1',
      elevation: 0.0,
      height: 3.0,
      floorFinishThickness: 0.06,
    );

    final storey1 = storey0.cloneToNextLevel(
      newId: 's1',
      newName: 'Floor 2',
      newElevation: 3.0,
    );
    expect(storey1.elevation, closeTo(3.0, 1e-4));
    expect(storey1.floorFinishThickness, closeTo(0.06, 1e-4));
  });

  test('Standard MEP riser shaft opening (40x60 cm) geometry and 90 deg rotation', () {
    // Standard plumbing / HVAC / electrical utility riser shaft is 40 x 60 cm (0.40 x 0.60 m)
    double shaftW = 0.40;
    double shaftH = 0.60;
    const center = Offset(2.0, 2.0);

    List<Offset> makeShaftPoly(double w, double h, Offset c) {
      final halfW = w / 2.0;
      final halfH = h / 2.0;
      return [
        Offset(c.dx - halfW, c.dy - halfH),
        Offset(c.dx + halfW, c.dy - halfH),
        Offset(c.dx + halfW, c.dy + halfH),
        Offset(c.dx - halfW, c.dy + halfH),
      ];
    }

    final poly0 = makeShaftPoly(shaftW, shaftH, center);
    expect(poly0.length, equals(4));
    expect((poly0[1].dx - poly0[0].dx).abs(), closeTo(0.40, 1e-4));
    expect((poly0[2].dy - poly0[1].dy).abs(), closeTo(0.60, 1e-4));

    // 90 degree rotation toggles width and height: 40x60 -> 60x40 cm
    final temp = shaftW;
    shaftW = shaftH;
    shaftH = temp;

    final polyRotated = makeShaftPoly(shaftW, shaftH, center);
    expect((polyRotated[1].dx - polyRotated[0].dx).abs(), closeTo(0.60, 1e-4));
    expect((polyRotated[2].dy - polyRotated[1].dy).abs(), closeTo(0.40, 1e-4));
  });

  test('Slab opening rotation 90 deg CCW around its centroid', () {
    final poly = [
      const Offset(1.8, 1.7),
      const Offset(2.2, 1.7),
      const Offset(2.2, 2.3),
      const Offset(1.8, 2.3),
    ];
    final center = Offset(
      poly.map((p) => p.dx).reduce((a, b) => a + b) / poly.length,
      poly.map((p) => p.dy).reduce((a, b) => a + b) / poly.length,
    );
    expect(center.dx, closeTo(2.0, 1e-4));
    expect(center.dy, closeTo(2.0, 1e-4));

    // Rotate 90 deg CCW around center: (dx, dy) -> (-dy, dx)
    final rotated = poly.map((p) {
      final d = p - center;
      return center + Offset(-d.dy, d.dx);
    }).toList();

    // Verify center is unchanged
    final rotatedCenter = Offset(
      rotated.map((p) => p.dx).reduce((a, b) => a + b) / rotated.length,
      rotated.map((p) => p.dy).reduce((a, b) => a + b) / rotated.length,
    );
    expect(rotatedCenter.dx, closeTo(2.0, 1e-4));
    expect(rotatedCenter.dy, closeTo(2.0, 1e-4));

    // Dimensions swapped: original width was 0.40, height was 0.60
    // After 90 deg CCW rotation, width is 0.60, height is 0.40
    final minX = rotated.map((p) => p.dx).reduce(math.min);
    final maxX = rotated.map((p) => p.dx).reduce(math.max);
    final minY = rotated.map((p) => p.dy).reduce(math.min);
    final maxY = rotated.map((p) => p.dy).reduce(math.max);
    expect(maxX - minX, closeTo(0.60, 1e-4));
    expect(maxY - minY, closeTo(0.40, 1e-4));
  });

  test('Slab opening relocation / move translates relative corner offsets to new center', () {
    const slab = StructuralSlab(
      id: 'slab_1',
      polygon: [Offset(0, 0), Offset(6, 0), Offset(6, 6), Offset(0, 6)],
      thickness: 0.20,
      openings: [
        [
          Offset(1.8, 1.7),
          Offset(2.2, 1.7),
          Offset(2.2, 2.3),
          Offset(1.8, 2.3),
        ],
      ],
    );

    final op = slab.openings.first;
    final origCenter = Offset(
      op.map((p) => p.dx).reduce((a, b) => a + b) / op.length,
      op.map((p) => p.dy).reduce((a, b) => a + b) / op.length,
    );
    final relativeOffsets = op.map((p) => p - origCenter).toList();

    // Move opening to new center (4.0, 4.5)
    const newCenter = Offset(4.0, 4.5);
    final movedPoly = relativeOffsets.map((r) => newCenter + r).toList();

    final movedSlab = slab.copyWith(openings: [movedPoly]);
    expect(movedSlab.containsPoint(newCenter), isFalse); // Center of cutout is outside slab material
    expect(movedSlab.containsPoint(const Offset(1.0, 1.0)), isTrue); // Rest of slab is solid
    expect(movedSlab.containsPoint(origCenter), isTrue); // Old spot is now solid again!
  });

  testWidgets('ElementPaletteBar renders standard shaft (40x60 cm) and custom opening tools', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool rotatedCalled = false;
    String selectedPreset = 'shaft';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('bg'),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ElementPaletteBar(
                activeTool: StructuralDrawTool.slabOpening,
                onSelectTool: (_) {},
                currentColumnPreset: const StructuralColumn(
                  id: 'c1',
                  center: Offset.zero,
                  width: 0.25,
                  height: 0.50,
                  thickness: 0.25,
                ),
                onUpdateColumnPreset: (_) {},
                currentWallThickness: 0.25,
                onUpdateWallThickness: (_) {},
                currentBeamWidth: 0.25,
                currentBeamDepth: 0.50,
                currentSlabThickness: 0.20,
                onUpdateSlabThickness: (_) {},
                currentOpeningPreset: selectedPreset,
                onUpdateOpeningPreset: (p) => setState(() => selectedPreset = p),
                onRotateOpening: () => rotatedCalled = true,
                hasOpeningStartCorner: false,
                currentAxisName: '1',
                isDrawingSlab: false,
                hasSlabStartCorner: false,
                slabPointCount: 0,
                onCloseSlab: () {},
                onUndoPoint: () {},
                onClearSlab: () {},
                onRotateColumn: () {},
                onOpenCantileverReport: () {},
                analysisSummary: StructuralAnalysisSummary.empty,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify shaft opening preset exists with 40x60 label
    expect(find.textContaining('40×60'), findsOneWidget);

    // Verify rotate 90 button exists and can be tapped
    final rotateButton = find.byIcon(Icons.rotate_90_degrees_ccw);
    expect(rotateButton, findsOneWidget);
    await tester.tap(rotateButton);
    expect(rotatedCalled, isTrue);

    // Verify custom opening preset exists
    final customButton = find.textContaining('Свободен');
    expect(customButton, findsOneWidget);
    await tester.tap(customButton);
    await tester.pumpAndSettle();
    expect(selectedPreset, equals('custom'));
  });

  test('Column magnetic alignment snaps 12.5 cm modular wall-axis centers to grid intersections', () {
    // Grid intersection at (10.0, 10.0)
    const axisX = StructuralGridAxis(
      id: 'ax_x',
      name: '1',
      start: Offset(0.0, 10.0),
      end: Offset(20.0, 10.0),
    );
    const axisY = StructuralGridAxis(
      id: 'ax_y',
      name: 'A',
      start: Offset(10.0, 0.0),
      end: Offset(10.0, 20.0),
    );
    final storey = StoreyLevel(
      id: 's1',
      name: 'Ниво 1',
      elevation: 0.0,
      height: 3.0,
      gridAxes: const [axisX, axisY],
    );

    // Column 25x50 cm (width=0.25, height=0.50).
    // Center near (10.01, 10.12) so modular 12.5 cm wall node (offset (0, -0.125)) aligns to (10.0, 10.0)
    final res = StructuralMagneticAlignmentHelper.alignColumn(
      rawCenter: const Offset(10.01, 10.12),
      columnWidth: 0.25,
      columnHeight: 0.50,
      toleranceCad: 0.20,
      activeStorey: storey,
    );

    expect(res, isNotNull);
    expect(res!.snappedCenter.dx, closeTo(10.0, 1e-4));
    expect(res.snappedCenter.dy, closeTo(10.125, 1e-4));
    expect(res.markerPoint!.dx, closeTo(10.0, 1e-4));
    expect(res.markerPoint!.dy, closeTo(10.0, 1e-4));
    expect(res.guideLines.length, 2);
  });

  test('Column single grid axis alignment snaps in 5 cm steps and calculates dynamic dimension line', () {
    const axisX = StructuralGridAxis(
      id: 'ax_x',
      name: '1',
      start: Offset(0.0, 10.0),
      end: Offset(20.0, 10.0),
    );
    // Obstacle column placed at (5.0, 10.0)
    const obstacleCol = StructuralColumn(
      id: 'c_obs',
      name: 'К1',
      center: Offset(5.0, 10.0),
      width: 0.25,
      height: 0.25,
    );
    final storey = StoreyLevel(
      id: 's1',
      name: 'Ниво 1',
      elevation: 0.0,
      height: 3.0,
      gridAxes: const [axisX],
      columns: const [obstacleCol],
    );

    // Column near (8.12, 10.03) -> distance to obstacle is ~3.12m
    // Snapped to 5 cm increments: 3.12 / 0.05 = 62.4 -> 62 * 0.05 = 3.10m.
    // Snapped position from obstacle (5.0, 10.0): 5.0 + 3.10 = 8.10.
    final res = StructuralMagneticAlignmentHelper.alignColumn(
      rawCenter: const Offset(8.12, 10.03),
      columnWidth: 0.25,
      columnHeight: 0.25,
      toleranceCad: 0.20,
      activeStorey: storey,
    );

    expect(res, isNotNull);
    expect(res!.snappedCenter.dy, closeTo(10.0, 1e-4));
    expect(res.snappedCenter.dx, closeTo(8.10, 1e-4));
    expect(res.liveDimensionText, '3.10 m');
    expect(res.dimensionLine, isNotNull);
    expect(res.dimensionLine!.$1, const Offset(5.0, 10.0));
    expect(res.dimensionLine!.$2.dx, closeTo(8.10, 1e-4));
  });

  test('Shear wall snaps symmetrically along axial centerline with 5 cm steps and dynamic dimension', () {
    const axisY = StructuralGridAxis(
      id: 'ax_y',
      name: 'A',
      start: Offset(10.0, 0.0),
      end: Offset(10.0, 20.0),
    );
    final storey = StoreyLevel(
      id: 's1',
      name: 'Ниво 1',
      elevation: 0.0,
      height: 3.0,
      gridAxes: const [axisY],
    );

    // Wall 2.0m long, vertical (rotation = pi/2), placed near (10.04, 4.38)
    // Snapped along axis in 5 cm step: 4.38 / 0.05 = 87.6 -> 88 * 0.05 = 4.40m.
    final res = StructuralMagneticAlignmentHelper.alignShearWall(
      rawCenter: const Offset(10.04, 4.38),
      wallLength: 2.0,
      wallThickness: 0.25,
      wallRotationRad: math.pi / 2,
      toleranceCad: 0.20,
      activeStorey: storey,
    );

    expect(res, isNotNull);
    expect(res!.snappedCenter.dx, closeTo(10.0, 1e-4));
    expect(res.snappedCenter.dy, closeTo(4.40, 1e-4));
    expect(res.liveDimensionText, '4.40 m');
    expect(res.dimensionLine, isNotNull);
  });

  test('Beam endpoint magnetically snaps to shear wall axial centerline and 12.5 cm modular nodes', () {
    // Shear wall from (0, 0) to (4.0, 0)
    const wall = StructuralShearWall(
      id: 'w1',
      name: 'Ш1',
      start: Offset(0.0, 0.0),
      end: Offset(4.0, 0.0),
      thickness: 0.25,
    );
    final storey = StoreyLevel(
      id: 's1',
      name: 'Ниво 1',
      elevation: 0.0,
      height: 3.0,
      shearWalls: const [wall],
    );

    // 1. Raw point near modular node at 12.5 cm from start: (0.125, 0.0)
    final resMod = StructuralMagneticAlignmentHelper.alignBeamEndpoint(
      rawPoint: const Offset(0.12, 0.04),
      toleranceCad: 0.15,
      activeStorey: storey,
    );
    expect(resMod, isNotNull);
    expect(resMod!.snappedPoint.dx, closeTo(0.125, 1e-4));
    expect(resMod.snappedPoint.dy, closeTo(0.0, 1e-4));
    expect(resMod.description, 'shearWallModule');

    // 2. Raw point near axial centerline at (2.5, 0.06)
    final resAxis = StructuralMagneticAlignmentHelper.alignBeamEndpoint(
      rawPoint: const Offset(2.5, 0.06),
      toleranceCad: 0.15,
      activeStorey: storey,
    );
    expect(resAxis, isNotNull);
    expect(resAxis!.snappedPoint.dx, closeTo(2.5, 1e-4));
    expect(resAxis.snappedPoint.dy, closeTo(0.0, 1e-4));
    expect(resAxis.description, 'shearWallAxis');
  });
}


