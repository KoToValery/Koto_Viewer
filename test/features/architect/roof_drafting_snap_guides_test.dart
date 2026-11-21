import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_polygon_geometry.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_polygon_editor.dart';

void main() {
  group('ArchitectRoofGeometry.resolveRoofGuideSnap', () {
    final storey = ArchitectStorey(
      id: 'storey-1',
      name: 'Ground Floor',
      elevation: 0.0,
      height: 2.8,
      walls: [
        // L-shaped wall corner at (4, 3)
        const ArchitectWall(
          id: 'w1',
          startPoint: Offset(0, 3),
          endPoint: Offset(4, 3),
        ),
        const ArchitectWall(
          id: 'w2',
          startPoint: Offset(4, 3),
          endPoint: Offset(4, 8),
        ),
      ],
      roofs: const [],
      slabs: const [],
    );

    test('1. Symmetrical hip apex convergence with P0 ray', () {
      // Eaves baseline from (0,0) to (6,0). Anchor is P1 = (6,0).
      // Ray from (6,0) at 135 deg meets ray from (0,0) at 45 deg at apex (3,3).
      final draftPoints = [const Offset(0, 0), const Offset(6, 0)];
      final raw = const Offset(3.1, 2.9); // Cursor near (3, 3)

      final result = ArchitectRoofGeometry.resolveRoofGuideSnap(
        raw: raw,
        anchor: const Offset(6, 0),
        draftPoints: draftPoints,
        activeStorey: storey,
        currentSlopeDegrees: 30.0,
        snapTolerance: 0.35,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isTrue);
      expect(result.snapLabel, 'Hip intersection (45°)');
      expect((result.point - const Offset(3, 3)).distance, lessThan(0.01));

      // Dual magnetic guides: one from anchor (6,0) to apex (3,3), one from P0 (0,0) to apex (3,3)
      expect(result.magneticGuides.length, 2);
      expect((result.magneticGuides[0].$1 - const Offset(6, 0)).distance, lessThan(0.01));
      expect((result.magneticGuides[0].$2 - const Offset(3, 3)).distance, lessThan(0.01));
      expect((result.magneticGuides[1].$1 - const Offset(0, 0)).distance, lessThan(0.01));
      expect((result.magneticGuides[1].$2 - const Offset(3, 3)).distance, lessThan(0.01));
    });

    test('2. Corner hip / valley intersection from wall corner (4,3)', () {
      // Drawing from (1, 0) along 45 deg ray: y = x - 1.
      // Corner at (4, 3) emits 135 deg ray: (4, 3) + t*(-1, 1). Line: y - 3 = -(x - 4) => y = -x + 7.
      // Intersection: x - 1 = -x + 7 => 2x = 8 => x = 4, y = 3.
      // Wait, at x=4, y=3 that is the corner itself!
      // Let's test a corner at (2, 4) emitting 315 deg ray: (2, 4) + t*(1, -1). Line: y - 4 = -(x - 2) => y = -x + 6.
      // Ray from (0, 0) at 45 deg: y = x.
      // Intersection: x = -x + 6 => x = 3, y = 3.
      final wallStorey = ArchitectStorey(
        id: 's2',
        name: 'Level',
        elevation: 0.0,
        height: 2.8,
        walls: [
          const ArchitectWall(
            id: 'w_test',
            startPoint: Offset(2, 4),
            endPoint: Offset(2, 8),
          ),
        ],
      );

      final raw = const Offset(3.05, 2.95);
      final result = ArchitectRoofGeometry.resolveRoofGuideSnap(
        raw: raw,
        anchor: const Offset(0, 0),
        draftPoints: [const Offset(0, 0)],
        activeStorey: wallStorey,
        currentSlopeDegrees: 30.0,
        snapTolerance: 0.35,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isTrue);
      expect(result.snapLabel, 'Corner hip intersection (45°)');
      expect((result.point - const Offset(3, 3)).distance, lessThan(0.02));
      expect(result.magneticGuides.length, 2);
      expect((result.magneticGuides[1].$1 - const Offset(2, 4)).distance, lessThan(0.01));
    });

    test('3. Perpendicular to inner corner (x = 4 from corner (4,3))', () {
      // Eaves baseline is horizontal from (0,0) to (10,0). Eaves unit = (1, 0).
      // Perpendicular direction is (0, 1) (vertical).
      // Inner corner at (4, 3) casts perpendicular line x = 4.
      // Anchor is (0, 0), drawing along 45 deg ray y = x.
      // Intersection is (4, 4)!
      final draftPoints = [const Offset(0, 0), const Offset(10, 0)];
      final raw = const Offset(3.95, 4.05);

      final result = ArchitectRoofGeometry.resolveRoofGuideSnap(
        raw: raw,
        anchor: const Offset(0, 0),
        draftPoints: draftPoints,
        activeStorey: storey,
        currentSlopeDegrees: 30.0,
        snapTolerance: 0.35,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isTrue);
      expect(result.snapLabel, 'Perpendicular to inner corner');
      expect((result.point - const Offset(4, 4)).distance, lessThan(0.02));
      expect(result.magneticGuides.length, 2);
      expect((result.magneticGuides[0].$1 - const Offset(0, 0)).distance, lessThan(0.01));
      expect((result.magneticGuides[1].$1 - const Offset(4, 3)).distance, lessThan(0.01));
    });

    test('4. Ridge parallel alignment through wall corner (3, 3)', () {
      // Eaves baseline from (0,0) to (10,0) (horizontal).
      // Wall corner at (1, 3).
      // Parallel to eaves through (1, 3) is horizontal line y = 3.
      // Ray from (0, 0) at 45 deg meets y = 3 at (3, 3).
      final wallStorey = ArchitectStorey(
        id: 's3',
        name: 'Level',
        elevation: 0.0,
        height: 2.8,
        walls: [
          const ArchitectWall(
            id: 'w3',
            startPoint: Offset(1, 3),
            endPoint: Offset(1, 7),
          ),
        ],
      );

      final draftPoints = [const Offset(0, 0), const Offset(10, 0)];
      final raw = const Offset(2.95, 3.05);

      final result = ArchitectRoofGeometry.resolveRoofGuideSnap(
        raw: raw,
        anchor: const Offset(0, 0),
        draftPoints: draftPoints,
        activeStorey: wallStorey,
        currentSlopeDegrees: 30.0,
        snapTolerance: 0.35,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isTrue);
      // Either ridge alignment or 45 deg ray from (1,3):
      // corner (1,3) emits 45 deg ray => doesn't intersect 45 deg ray from (0,0) because they are parallel!
      // Therefore, ridge alignment y = 3 is the only one intersecting at (3,3)!
      expect(result.snapLabel, 'Ridge / edge alignment');
      expect((result.point - const Offset(3, 3)).distance, lessThan(0.02));
      expect((result.magneticGuides[1].$1 - const Offset(1, 3)).distance, lessThan(0.01));
    });

    test('5. Continuous smooth tracking when far from any intersection', () {
      final draftPoints = [const Offset(0, 0), const Offset(10, 0)];
      // Cursor at (7.0, 7.02) - on 45 deg ray from anchor (0,0), far from corners at (0,3), (4,3), (4,8)
      final raw = const Offset(7.0, 7.02);

      final result = ArchitectRoofGeometry.resolveRoofGuideSnap(
        raw: raw,
        anchor: const Offset(0, 0),
        draftPoints: draftPoints,
        activeStorey: storey,
        currentSlopeDegrees: 30.0,
        snapTolerance: 0.20,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isFalse);
      expect(result.snapLabel, '45° Hip / Ridge');
      expect(result.magneticGuides.length, 1);
      // Continuous projection along ray
      expect((result.point.dx - result.point.dy).abs(), lessThan(0.001));
    });
  });

  group('ArchitectRoofGeometry.resolveRoofVertexDragSnap', () {
    ArchitectProject makeProject({
      required List<ArchitectWall> walls,
      required ArchitectRoofPlane roof,
    }) {
      final ground = ArchitectStorey(
        id: 'ground',
        name: 'Ground',
        elevation: 0,
        height: 2.8,
        walls: walls,
      );
      final roofPlan = ArchitectStorey(
        id: 'roof-plan',
        name: 'Roof',
        elevation: 2.8,
        height: 2.8,
        isRoof: true,
        roofs: [roof],
      );
      return ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [ground, roofPlan],
        activeStoreyId: roofPlan.id,
      );
    }

    test('1. Dual 45° hip intersection when dragging triangular roof apex', () {
      final roof = ArchitectRoofPlane(
        id: 'r1',
        storeyId: 'roof-plan',
        points: const [Offset(0, 0), Offset(6, 0), Offset(2.5, 2.2)],
        eavesEdgeIndex: 0,
        slopeDegrees: 30,
      );
      final project = makeProject(walls: const [], roof: roof);

      final result = ArchitectRoofGeometry.resolveRoofVertexDragSnap(
        raw: const Offset(3.08, 2.95),
        originalPolygon: roof.points,
        vertexIndex: 2,
        roof: roof,
        project: project,
        snapTolerance: 0.35,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isTrue);
      expect(result.snapLabel, 'Hip intersection (45°)');
      expect((result.point - const Offset(3, 3)).distance, lessThan(0.01));
      expect(result.magneticGuides.length, 2);
      expect((result.magneticGuides[0].$1 - const Offset(6, 0)).distance, lessThan(0.01));
      expect((result.magneticGuides[1].$1 - const Offset(0, 0)).distance, lessThan(0.01));
    });

    test('2. Tracks 45° ray and snaps to wall midpoint perpendicular ridge axis', () {
      // 10m x 6m building: short left wall (0,0)-(0,6) has midpoint (0,3),
      // whose perpendicular centerline is y = 3 (the exact ridge line).
      final walls = const [
        ArchitectWall(id: 'w1', startPoint: Offset(0, 0), endPoint: Offset(10, 0)),
        ArchitectWall(id: 'w2', startPoint: Offset(10, 0), endPoint: Offset(10, 6)),
        ArchitectWall(id: 'w3', startPoint: Offset(10, 6), endPoint: Offset(0, 6)),
        ArchitectWall(id: 'w4', startPoint: Offset(0, 6), endPoint: Offset(0, 0)),
      ];
      final roof = ArchitectRoofPlane(
        id: 'r2',
        storeyId: 'roof-plan',
        points: const [Offset(0, 0), Offset(10, 0), Offset(7, 2.5), Offset(3, 2.5)],
        eavesEdgeIndex: 0,
        slopeDegrees: 25,
      );
      final project = makeProject(walls: walls, roof: roof);

      // Dragging vertex 3 (near (3, 3)), moving along 45° from (0,0) to meet y = 3
      final result = ArchitectRoofGeometry.resolveRoofVertexDragSnap(
        raw: const Offset(3.04, 2.98),
        originalPolygon: roof.points,
        vertexIndex: 3,
        roof: roof,
        project: project,
        snapTolerance: 0.35,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isTrue);
      expect((result.point - const Offset(3, 3)).distance, lessThan(0.02));
      expect(result.magneticGuides.length, 2);
    });

    test('3. Continuous 45° ray guide when dragging away from intersections', () {
      final roof = ArchitectRoofPlane(
        id: 'r3',
        storeyId: 'roof-plan',
        points: const [Offset(0, 0), Offset(10, 0), Offset(7, 2), Offset(3, 2)],
        eavesEdgeIndex: 0,
        slopeDegrees: 25,
      );
      final project = makeProject(walls: const [], roof: roof);

      final result = ArchitectRoofGeometry.resolveRoofVertexDragSnap(
        raw: const Offset(2.5, 2.52),
        originalPolygon: roof.points,
        vertexIndex: 3,
        roof: roof,
        project: project,
        snapTolerance: 0.25,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isFalse);
      expect(result.snapLabel, '45° Hip / Ridge');
      expect((result.point.dx - result.point.dy).abs(), lessThan(0.01));
      expect(result.magneticGuides.length, 1);
    });
  });

  group('ArchitectRoofPainterHelper.buildSupportingWallGuides', () {
    test('1. Rectangular walls generate 4 corner 45° bisectors, 2 centerlines, and 2 hip apex intersections', () {
      final storey = ArchitectStorey(
        id: 'ground',
        name: 'Ground',
        elevation: 0,
        height: 2.8,
        walls: const [
          ArchitectWall(id: 'w1', startPoint: Offset(0, 0), endPoint: Offset(10, 0)),
          ArchitectWall(id: 'w2', startPoint: Offset(10, 0), endPoint: Offset(10, 6)),
          ArchitectWall(id: 'w3', startPoint: Offset(10, 6), endPoint: Offset(0, 6)),
          ArchitectWall(id: 'w4', startPoint: Offset(0, 6), endPoint: Offset(0, 0)),
        ],
      );

      final guides = ArchitectRoofPainterHelper.buildSupportingWallGuides(storey);

      expect(guides.bisectors.length, 4);
      expect(guides.midPerpendiculars.length, 2);
      expect(guides.intersections.length, 2);

      // Hip-ridge apexes on a 10x6 rectangle with equal wall thickness lie at y = 3, x = 3 and x = 7
      final xs = guides.intersections.map((p) => p.dx).toList()..sort();
      expect(xs[0], closeTo(3.0, 0.05));
      expect(xs[1], closeTo(7.0, 0.05));
      for (final pt in guides.intersections) {
        expect(pt.dy, closeTo(3.0, 0.05));
      }
    });

    test('2. L-shaped footprint includes inward reflex valley bisector', () {
      final storey = ArchitectStorey(
        id: 'ground-l',
        name: 'Ground',
        elevation: 0,
        height: 2.8,
        walls: const [
          ArchitectWall(id: 'w1', startPoint: Offset(0, 0), endPoint: Offset(10, 0)),
          ArchitectWall(id: 'w2', startPoint: Offset(10, 0), endPoint: Offset(10, 5)),
          ArchitectWall(id: 'w3', startPoint: Offset(10, 5), endPoint: Offset(5, 5)),
          ArchitectWall(id: 'w4', startPoint: Offset(5, 5), endPoint: Offset(5, 10)),
          ArchitectWall(id: 'w5', startPoint: Offset(5, 10), endPoint: Offset(0, 10)),
          ArchitectWall(id: 'w6', startPoint: Offset(0, 10), endPoint: Offset(0, 0)),
        ],
      );

      final guides = ArchitectRoofPainterHelper.buildSupportingWallGuides(storey);

      expect(guides.bisectors.length, 6);
      expect(guides.midPerpendiculars.length, greaterThanOrEqualTo(4));
      expect(guides.intersections, isNotEmpty);
    });
  });

  group('Roof segment & guide line snapping during editing', () {
    ArchitectProject makeRoofProject({
      required List<ArchitectWall> walls,
      required List<ArchitectRoofPlane> roofs,
    }) {
      final ground = ArchitectStorey(
        id: 'ground',
        name: 'Ground',
        elevation: 0,
        height: 2.8,
        walls: walls,
      );
      final roofPlan = ArchitectStorey(
        id: 'roof-plan',
        name: 'Roof',
        elevation: 2.8,
        height: 2.8,
        isRoof: true,
        roofs: roofs,
      );
      return ArchitectProject(
        id: 'p-edit',
        name: 'Edit Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [ground, roofPlan],
        activeStoreyId: roofPlan.id,
      );
    }

    test('1. Vertex drag ray snaps onto another roof plane mid-edge segment', () {
      final r1 = ArchitectRoofPlane(
        id: 'r1',
        storeyId: 'roof-plan',
        points: const [Offset(0, 0), Offset(6, 0), Offset(4, 2)],
        eavesEdgeIndex: 0,
        slopeDegrees: 30,
      );
      // Horizontal ridge segment from (0, 3) to (10, 3) on another roof
      final r2 = ArchitectRoofPlane(
        id: 'r2',
        storeyId: 'roof-plan',
        points: const [Offset(0, 3), Offset(10, 3), Offset(10, 6), Offset(0, 6)],
        eavesEdgeIndex: 2,
        slopeDegrees: 30,
      );
      final project = makeRoofProject(walls: const [], roofs: [r1, r2]);

      final result = ArchitectRoofGeometry.resolveRoofVertexDragSnap(
        raw: const Offset(3.05, 2.95),
        originalPolygon: r1.points,
        vertexIndex: 2,
        roof: r1,
        project: project,
        snapTolerance: 0.30,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isTrue);
      expect((result.point - const Offset(3, 3)).distance, lessThan(0.01));
      expect(result.magneticGuides.length, 2);
    });

    test('2. Vertex drag ray snaps onto supporting wall roof guide line', () {
      final r1 = ArchitectRoofPlane(
        id: 'r1',
        storeyId: 'roof-plan',
        points: const [Offset(0, 0), Offset(6, 0), Offset(4, 2)],
        eavesEdgeIndex: 0,
        slopeDegrees: 30,
      );
      final project = makeRoofProject(walls: const [], roofs: [r1]);
      // Simulated guide line y = 3.5 across the plan
      const guideSegments = [(Offset(0, 3.5), Offset(10, 3.5))];

      final result = ArchitectRoofGeometry.resolveRoofVertexDragSnap(
        raw: const Offset(3.48, 3.45),
        originalPolygon: r1.points,
        vertexIndex: 2,
        roof: r1,
        project: project,
        snapTolerance: 0.30,
        roofGuideSegments: guideSegments,
        hip45Label: () => '45° Hip / Ridge',
        hipAngleLabel: (deg) => '$deg° Hip / Valley',
        hipIntersectionLabel: () => 'Hip intersection (45°)',
        cornerHipIntersectionLabel: () => 'Corner hip intersection (45°)',
        ridgeAlignmentLabel: () => 'Ridge / edge alignment',
        perpToCornerLabel: () => 'Perpendicular to inner corner',
      );

      expect(result, isNotNull);
      expect(result!.isIntersectionSnap, isTrue);
      expect((result.point - const Offset(3.5, 3.5)).distance, lessThan(0.01));
      expect(result.magneticGuides.length, 2);
    });

    test('3. Edge drag snaps collinear to another roof segment across a gap and emits alignment guide', () {
      final edited = ArchitectRoofPlane(
        id: 'r1',
        storeyId: 'roof-plan',
        points: const [Offset(0, 0), Offset(8, 0), Offset(6, 2), Offset(2, 2)],
        eavesEdgeIndex: 0,
        slopeDegrees: 30,
      );
      // Neighboring roof to the right has a parallel ridge edge at y = 3.0
      final neighbor = ArchitectRoofPlane(
        id: 'r2',
        storeyId: 'roof-plan',
        points: const [Offset(12, 0), Offset(18, 0), Offset(15, 3), Offset(14, 3)],
        eavesEdgeIndex: 0,
        slopeDegrees: 30,
      );
      final project = makeRoofProject(walls: const [], roofs: [edited, neighbor]);

      final editor = BimPolygonEditor<ArchitectSnapResult>(
        pointOf: (s) => s.point,
        isSnapped: (s) => s.isSnapped,
      );
      expect(
        editor.startEdge(
          edited.id,
          edited.points,
          2, // top ridge edge (6,2) -> (2,2)
          const Offset(4, 2),
          1.0,
          mode: BimPolygonEdgeMode.extendCatheti,
        ),
        isTrue,
      );

      // Drag edge 2 up near y = 2.94 (within snap tolerance to neighbor's y = 3.0)
      editor.update(
        const Offset(4, 2.94),
        (moving) {
          final snap = ArchitectRoofGeometry.resolveRoofEdgeDragSnap(
            raw: moving,
            originalPolygon: edited.points,
            edgeIndex: 2,
            roof: edited,
            project: project,
            snapTolerance: 0.25,
            ridgeAlignmentLabel: () => 'Ridge / edge alignment',
            edgeLabel: () => 'Edge',
          );
          if (snap == null) return ArchitectSnapResult(point: moving);
          return ArchitectSnapResult(
            point: snap.point,
            isSnapped: true,
            snapLabel: snap.snapLabel,
            magneticGuides: snap.magneticGuides,
          );
        },
        0.25,
      );

      expect(editor.preview, isNotNull);
      expect(editor.preview!.length, 4);
      expect(editor.preview![2].dy, closeTo(3.0, 1e-4));
      expect(editor.preview![3].dy, closeTo(3.0, 1e-4));
      // Preserves 45° hip angles via extendCatheti
      expect(editor.preview![2].dx, closeTo(5.0, 1e-4));
      expect(editor.preview![3].dx, closeTo(3.0, 1e-4));
      expect(editor.activeSnap?.magneticGuides, isNotEmpty);
    });

    test('4. ArchitectSnapHelper.snapFree snaps to roof guide lines and intersections on isRoof storey', () {
      final walls = const [
        ArchitectWall(id: 'w1', startPoint: Offset(0, 0), endPoint: Offset(10, 0)),
        ArchitectWall(id: 'w2', startPoint: Offset(10, 0), endPoint: Offset(10, 6)),
        ArchitectWall(id: 'w3', startPoint: Offset(10, 6), endPoint: Offset(0, 6)),
        ArchitectWall(id: 'w4', startPoint: Offset(0, 6), endPoint: Offset(0, 0)),
      ];
      final project = makeRoofProject(walls: walls, roofs: const []);

      // Near left hip-ridge apex intersection (3, 3) on roof guide lines
      final apexSnap = ArchitectSnapHelper.snapFree(
        rawPoint: const Offset(3.05, 2.96),
        project: project,
        tolerance: 0.20,
      );
      expect(apexSnap.isSnapped, isTrue);
      expect((apexSnap.point - const Offset(3, 3)).distance, lessThan(0.05));

      // Near mid-wall ridge guide line y = 3 at x = 5.5
      final guideEdgeSnap = ArchitectSnapHelper.snapFree(
        rawPoint: const Offset(5.5, 3.06),
        project: project,
        tolerance: 0.20,
      );
      expect(guideEdgeSnap.isSnapped, isTrue);
      expect(guideEdgeSnap.point.dy, closeTo(3.0, 0.05));
    });
  });
}
