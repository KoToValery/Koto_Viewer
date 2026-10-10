import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_zone_tool.dart';

void main() {
  group('ArchitectZoneGeometry Tests', () {
    test('cleanPolygon eliminates collinear orphan vertices along straight edges', () {
      // Rectangle with an orphan collinear point at (5, 0) between (0, 0) and (10, 0)
      final withOrphan = [
        const Offset(0, 0),
        const Offset(5, 0), // Orphan point on straight line
        const Offset(10, 0),
        const Offset(10, 8),
        const Offset(0, 8),
      ];

      final cleaned = ArchitectZoneGeometry.cleanPolygon(withOrphan);
      expect(cleaned.length, 4);
      expect(cleaned, contains(const Offset(0, 0)));
      expect(cleaned, contains(const Offset(10, 0)));
      expect(cleaned, contains(const Offset(10, 8)));
      expect(cleaned, contains(const Offset(0, 8)));
      expect(cleaned.contains(const Offset(5, 0)), isFalse);
    });

    test('cleanPolygon eliminates duplicate micro-distance vertices (< 5 cm)', () {
      final withDuplicates = [
        const Offset(0, 0),
        const Offset(0.01, 0.01), // duplicate micro point
        const Offset(10, 0),
        const Offset(10, 8),
        const Offset(0, 8),
      ];

      final cleaned = ArchitectZoneGeometry.cleanPolygon(withDuplicates);
      expect(cleaned.length, 4);
    });

    test('cleanPolygon eliminates needle fold-back spikes', () {
      final withSpike = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(12, 0), // needle point forward
        const Offset(10, 0), // doubled back
        const Offset(10, 8),
        const Offset(0, 8),
      ];

      final cleaned = ArchitectZoneGeometry.cleanPolygon(withSpike);
      expect(cleaned.length, 4);
      expect(ArchitectZoneGeometry.hasSelfIntersections(cleaned), isFalse);
    });

    test('hasSelfIntersections identifies bowtie / crossed polygons', () {
      final normalRect = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];
      expect(ArchitectZoneGeometry.hasSelfIntersections(normalRect), isFalse);

      final bowtie = [
        const Offset(0, 0),
        const Offset(10, 10),
        const Offset(10, 0),
        const Offset(0, 10),
      ];
      expect(ArchitectZoneGeometry.hasSelfIntersections(bowtie), isTrue);
    });

    test('extrudeEdge preserves existing endpoints and forms two new vertices', () {
      final rect = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 8),
        const Offset(0, 8),
      ];

      // Extrude edge 0 (from (0,0) to (10,0)) outward by 2 meters (negative y in canvas coords or normal)
      final extruded = ArchitectZoneGeometry.extrudeEdge(
        polygon: rect,
        edgeIndex: 0,
        distance: 2.0,
      );

      expect(extruded, isNotNull);
      // Original 4 points are preserved, and 2 new vertices form the step -> total 6 vertices
      expect(extruded!.length, 6);
      expect(extruded, contains(const Offset(0, 0)));
      expect(extruded, contains(const Offset(10, 0)));
      expect(ArchitectZoneGeometry.hasSelfIntersections(extruded), isFalse);
    });

    test('calculateOrthoSnap snaps within ±6° to exact horizontal or vertical', () {
      const anchor = Offset(10, 10);

      // Slightly angled horizontal: dx = 5, dy = 0.2 (approx 2.3°)
      final nearH = ArchitectZoneGeometry.calculateOrthoSnap(
        anchor: anchor,
        raw: const Offset(15, 10.2),
      );
      expect(nearH.isSnapped, isTrue);
      expect(nearH.type, ArchitectOrthoType.horizontal);
      expect(nearH.point.dy, 10.0); // Exact horizontal snap to anchor.dy!
      expect(nearH.point.dx, 15.0);

      // Slightly angled vertical: dx = 0.3, dy = 6 (approx 87°)
      final nearV = ArchitectZoneGeometry.calculateOrthoSnap(
        anchor: anchor,
        raw: const Offset(10.3, 16.0),
      );
      expect(nearV.isSnapped, isTrue);
      expect(nearV.type, ArchitectOrthoType.vertical);
      expect(nearV.point.dx, 10.0); // Exact vertical snap to anchor.dx!
      expect(nearV.point.dy, 16.0);
    });
  });

  group('ArchitectZoneTool Drafting Tests', () {
    test('point-by-point drawing workflow with close snap at start vertex', () {
      final tool = ArchitectZoneTool();
      final project = ArchitectProject.starter(name: 'Test Project');

      expect(tool.isDrafting, isFalse);

      // 1. Start with first point P0 at (0, 0)
      tool.start(const Offset(0, 0));
      expect(tool.isDrafting, isTrue);
      expect(tool.pointCount, 1);
      expect(tool.canClose, isFalse);

      // 2. Add second point P1 at (6, 0)
      tool.addPoint(const Offset(6, 0));
      expect(tool.pointCount, 2);
      expect(tool.canClose, isFalse);

      // 3. Add third point P2 at (6, 5)
      tool.addPoint(const Offset(6, 5));
      expect(tool.pointCount, 3);
      expect(tool.canClose, isTrue);

      // 4. Add fourth point P3 at (0, 5)
      tool.addPoint(const Offset(0, 5));
      expect(tool.pointCount, 4);

      // 5. Update pointer near first point (0, 0) with snap tolerance
      tool.updatePointer(
        rawModelPoint: const Offset(0.05, 0.05),
        project: project,
        currentScale: 40.0,
      );
      expect(tool.isClosingSnap, isTrue);
      expect(tool.candidatePoint, const Offset(0, 0));

      // 6. Commit zone
      final zone = tool.commit(
        category: ArchitectZoneCategory.living,
        defaultName: 'Дневна',
      );

      expect(zone, isNotNull);
      expect(zone!.polygon.length, 4);
      expect(zone.area, closeTo(30.0, 0.1));
      expect(tool.isDrafting, isFalse); // reset after commit
    });

    test('undo last point correctly pops vertices', () {
      final tool = ArchitectZoneTool();
      tool.start(const Offset(0, 0));
      tool.addPoint(const Offset(5, 0));
      tool.addPoint(const Offset(5, 5));

      expect(tool.pointCount, 3);
      tool.undoLastPoint();
      expect(tool.pointCount, 2);
      expect(tool.points.last, const Offset(5, 0));

      tool.undoLastPoint();
      expect(tool.pointCount, 1);
      tool.undoLastPoint();
      expect(tool.isDrafting, isFalse); // fully cancelled
    });

    test('rejects self-intersecting segments during drafting', () {
      final tool = ArchitectZoneTool();
      tool.start(const Offset(0, 0));
      tool.addPoint(const Offset(10, 0));
      tool.addPoint(const Offset(10, 10));
      tool.addPoint(const Offset(5, -5)); // Crosses segment from (0,0) to (10,0)

      expect(tool.pointStatus, ZoneDraftingPointStatus.selfIntersects);
    });
  });

  group('ArchitectZoneTool Extrude Tests', () {
    test('interactive edge midpoint extrusion creates new vertices and preserves old ones', () {
      final zone = ArchitectZone(
        id: 'zone_1',
        name: 'Спалня',
        category: ArchitectZoneCategory.bedroom,
        polygon: const [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 8),
          Offset(0, 8),
        ],
      );

      final tool = ArchitectZoneTool();
      final started = tool.startExtrude(
        zone: zone,
        edgeIndex: 0,
        pointerModel: const Offset(5, 0),
      );
      expect(started, isTrue);
      expect(tool.isExtruding, isTrue);

      // Drag outward by 2.0 meters
      tool.updateExtrudePointer(const Offset(5, -2.0));
      expect(tool.extrudeDistance.abs(), closeTo(2.0, 0.1));
      expect(tool.extrudePreviewPolygon, isNotNull);
      expect(tool.extrudePreviewPolygon!.length, 6);

      // Commit
      final result = tool.commitExtrude();
      expect(result, isNotNull);
      final (updatedZone, _) = result!;
      expect(updatedZone.polygon.length, 6);
      expect(updatedZone.polygon, contains(const Offset(0, 0)));
      expect(updatedZone.polygon, contains(const Offset(10, 0)));
      expect(tool.isExtruding, isFalse);
    });

    test('rectangle draft mode creates 4-point rectangle in 2 clicks', () {
      final tool = ArchitectZoneTool();
      tool.draftMode = ArchitectZoneDraftMode.rectangle;

      // Click 1: First corner
      tool.addDraftingPoint(const Offset(2, 3));
      expect(tool.draftPointCount, 1);
      expect(tool.canCloseDraft, isFalse);

      // Mouse moves to (8, 7)
      final project = ArchitectProject.starter(name: 'Test', storeyCount: 1);
      tool.updateDraftingPointer(
        rawModelPoint: const Offset(8, 7),
        project: project,
        currentScale: 40.0,
      );
      expect(tool.previewRectangle.length, 4);
      expect(tool.liveArea, closeTo(24.0, 0.01));

      // Click 2: Second corner
      final added = tool.addDraftingPoint(const Offset(8, 7));
      expect(added, isTrue);
      expect(tool.draftPointCount, 4);

      // Commit
      final zone = tool.commitDrafting(
        category: ArchitectZoneCategory.bedroom,
        defaultName: 'Bedroom',
      );
      expect(zone, isNotNull);
      expect(zone!.polygon.length, 4);
      expect(zone.area, closeTo(24.0, 0.01));
    });
  });

  group('GPS_Mapping Zone Transform & Edit Mode Tests', () {
    test('calculateCentroid accurately computes visual center', () {
      const rect = [
        Offset(0, 0),
        Offset(10, 0),
        Offset(10, 6),
        Offset(0, 6),
      ];
      final centroid = ArchitectZoneGeometry.calculateCentroid(rect);
      expect(centroid.dx, closeTo(5.0, 1e-4));
      expect(centroid.dy, closeTo(3.0, 1e-4));
    });

    test('rotatePolygon rotates polygon around center', () {
      const rect = [
        Offset(0, 0),
        Offset(10, 0),
        Offset(10, 6),
        Offset(0, 6),
      ];
      final center = ArchitectZoneGeometry.calculateCentroid(rect);
      final rotated90 = ArchitectZoneGeometry.rotatePolygon(rect, 90.0, center);

      expect(rotated90.length, 4);
      final newCenter = ArchitectZoneGeometry.calculateCentroid(rotated90);
      expect(newCenter.dx, closeTo(center.dx, 1e-4));
      expect(newCenter.dy, closeTo(center.dy, 1e-4));
      // Area is preserved under rotation
      expect(ArchitectZoneGeometry.calculateArea(rotated90),
          closeTo(ArchitectZoneGeometry.calculateArea(rect), 1e-4));
    });

    test('translatePolygon shifts all vertices uniformly', () {
      const rect = [
        Offset(0, 0),
        Offset(10, 0),
        Offset(10, 6),
        Offset(0, 6),
      ];
      final moved = ArchitectZoneGeometry.translatePolygon(rect, const Offset(3.5, -2.0));
      expect(moved[0], const Offset(3.5, -2.0));
      expect(moved[1], const Offset(13.5, -2.0));
      expect(moved[2], const Offset(13.5, 4.0));
      expect(moved[3], const Offset(3.5, 4.0));
    });

    test('offsetPolygon expands and shrinks boundary polygon', () {
      const rect = [
        Offset(0, 0),
        Offset(10, 0),
        Offset(10, 6),
        Offset(0, 6),
      ];
      final initialArea = ArchitectZoneGeometry.calculateArea(rect); // 60 m²

      // Expand by 0.5m
      final expanded = ArchitectZoneGeometry.offsetPolygon(rect, 0.5);
      final expandedArea = ArchitectZoneGeometry.calculateArea(expanded);
      expect(expandedArea, greaterThan(initialArea));

      // Shrink by 0.5m
      final shrunk = ArchitectZoneGeometry.offsetPolygon(rect, -0.5);
      final shrunkArea = ArchitectZoneGeometry.calculateArea(shrunk);
      expect(shrunkArea, lessThan(initialArea));
    });

    test('alignPolygonToNearest2D squares corners to exact 90°', () {
      // Slightly distorted 4-corner box (e.g. hand-drawn or GPS jitter)
      const skewed = [
        Offset(0.05, 0.1),
        Offset(9.9, 0.0),
        Offset(10.1, 6.05),
        Offset(0.0, 5.95),
      ];

      final aligned = ArchitectZoneGeometry.alignPolygonToNearest2D(skewed);
      expect(aligned.length, 4);

      // Check angles: each corner should form a 90° angle
      for (int i = 0; i < 4; i++) {
        final pPrev = aligned[(i + 3) % 4];
        final pCurr = aligned[i];
        final pNext = aligned[(i + 1) % 4];

        final v1 = pPrev - pCurr;
        final v2 = pNext - pCurr;
        final dot = v1.dx * v2.dx + v1.dy * v2.dy;
        final cosAngle = dot / (v1.distance * v2.distance);
        expect(cosAngle.abs(), closeTo(0.0, 0.02)); // dot product near 0 = 90°
      }
    });

    test('ArchitectZoneTool autoAlignZone and undoAutoAlignZone workflow', () {
      final zone = ArchitectZone(
        id: 'zone_skewed',
        name: 'Хореография',
        category: ArchitectZoneCategory.living,
        polygon: const [
          Offset(0.05, 0.1),
          Offset(9.9, 0.0),
          Offset(10.1, 6.05),
          Offset(0.0, 5.95),
        ],
      );

      final tool = ArchitectZoneTool();
      tool.startEditingZone(zone);
      expect(tool.isEditingZone, isTrue);
      expect(tool.canUndoAutoAlign, isFalse);

      // Auto align
      final aligned = tool.autoAlignZone();
      expect(aligned, isTrue);
      expect(tool.canUndoAutoAlign, isTrue);
      expect(tool.canUndoEdit, isTrue);

      // Undo auto align
      final undone = tool.undoAutoAlignZone();
      expect(undone, isTrue);
      expect(tool.canUndoAutoAlign, isFalse);
      expect(tool.editingPolygon![0], const Offset(0.05, 0.1));
    });

    test('ArchitectZoneTool rotation slider, undo/redo stack, and whole zone move', () {
      final zone = ArchitectZone(
        id: 'zone_transform',
        name: 'Офис',
        category: ArchitectZoneCategory.office,
        polygon: const [
          Offset(0, 0),
          Offset(8, 0),
          Offset(8, 5),
          Offset(0, 5),
        ],
      );

      final tool = ArchitectZoneTool();
      tool.startEditingZone(zone);

      // 1. Quick step rotation +15°
      tool.applyRotationStep(15.0);
      expect(tool.canUndoEdit, isTrue);
      expect(tool.editingPolygon![0].dx, isNot(closeTo(0.0, 1e-3)));

      // Undo
      tool.undoEditAction();
      expect(tool.editingPolygon![0], const Offset(0, 0));
      expect(tool.canRedoEdit, isTrue);

      // Redo
      tool.redoEditAction();
      expect(tool.canRedoEdit, isFalse);

      // 2. Move whole zone mode
      tool.toggleMoveWholeZoneMode();
      expect(tool.isMoveWholeZoneMode, isTrue);

      tool.startMovingZone(const Offset(4, 2.5));
      tool.updateMovingZone(const Offset(6, 4.5)); // Delta (2, 2)
      expect(tool.moveDistanceMeters, greaterThan(1.0));

      tool.finishMovingZone();
      expect(tool.canUndoEdit, isTrue);

      // Commit
      final committed = tool.commitEditingZone();
      expect(committed, isNotNull);
      expect(tool.isEditingZone, isFalse);
    });
  });
}
