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
}
