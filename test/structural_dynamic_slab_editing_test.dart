import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';

void main() {
  group('Dynamic Slab Correction & Artifact Prevention Tests', () {
    test('1. dynamicPullEdge on rectangular slab extends corners without orphan vertices', () {
      const initialSlab = StructuralSlab(
        id: 'slab_rect',
        polygon: [
          Offset(0, 0),
          Offset(4, 0),
          Offset(4, 4),
          Offset(0, 4),
        ],
      );

      // Pull right edge (edge index 1: from (4,0) to (4,4)) outward by 1.5m (+X normal)
      final pulledOut = initialSlab.dynamicPullEdge(
        edgeIndex: 1,
        distance: 1.5,
      );

      // Must remain exactly a 4-vertex rectangle with NO orphan collinear points
      expect(pulledOut.polygon.length, equals(4));
      expect(pulledOut.polygon[0], equals(const Offset(0, 0)));
      expect(pulledOut.polygon[1], equals(const Offset(5.5, 0)));
      expect(pulledOut.polygon[2], equals(const Offset(5.5, 4)));
      expect(pulledOut.polygon[3], equals(const Offset(0, 4)));
      expect(StructuralSlab.hasSelfIntersections(pulledOut.polygon), isFalse);
    });

    test('2. dynamicPullEdge inward shrinks slab cleanly without fold-backs or self-intersections', () {
      const initialSlab = StructuralSlab(
        id: 'slab_rect',
        polygon: [
          Offset(0, 0),
          Offset(4, 0),
          Offset(4, 4),
          Offset(0, 4),
        ],
      );

      // Pull right edge inward by 1.5m (distance = -1.5)
      final pulledIn = initialSlab.dynamicPullEdge(
        edgeIndex: 1,
        distance: -1.5,
      );

      // Must remain exactly a 4-vertex rectangle of width 2.5m
      expect(pulledIn.polygon.length, equals(4));
      expect(pulledIn.polygon[0], equals(const Offset(0, 0)));
      expect(pulledIn.polygon[1], equals(const Offset(2.5, 0)));
      expect(pulledIn.polygon[2], equals(const Offset(2.5, 4)));
      expect(pulledIn.polygon[3], equals(const Offset(0, 4)));
      expect(StructuralSlab.hasSelfIntersections(pulledIn.polygon), isFalse);
    });

    test('3. dynamicPullEdge on straight wall sub-segment creates clean cantilever steps', () {
      // Slab with a straight front wall divided into sub-segments (e.g. Balcony insertion)
      const slab = StructuralSlab(
        id: 'slab_balcony',
        polygon: [
          Offset(0, 0),
          Offset(3, 0),
          Offset(7, 0),
          Offset(10, 0),
          Offset(10, 10),
          Offset(0, 10),
        ],
      );

      // Pull edge 1 (from (3,0) to (7,0)) outward by 1.5m (normal is (0, -1))
      final balcony = slab.dynamicPullEdge(
        edgeIndex: 1,
        distance: 1.5,
      );

      // Both neighbor walls are collinear with edge 1, so (3,0) and (7,0) are kept as anchors
      expect(balcony.polygon.length, equals(8));
      expect(balcony.polygon[0], equals(const Offset(0, 0)));
      expect(balcony.polygon[1], equals(const Offset(3, 0))); // Anchor corner
      expect(balcony.polygon[2], equals(const Offset(3, -1.5))); // Stepped corner
      expect(balcony.polygon[3], equals(const Offset(7, -1.5))); // Stepped corner
      expect(balcony.polygon[4], equals(const Offset(7, 0))); // Anchor corner
      expect(balcony.polygon[5], equals(const Offset(10, 0)));
      expect(StructuralSlab.hasSelfIntersections(balcony.polygon), isFalse);
    });

    test('4. cleanPolygon eliminates collinear orphan vertices and micro-spikes', () {
      // Polygon with accidental orphan points along straight edges
      final dirtyPolygon = [
        const Offset(0, 0),
        const Offset(2, 0), // Orphan on straight line (0,0)-(5,0)
        const Offset(5, 0),
        const Offset(5, 2.5), // Orphan on straight line (5,0)-(5,5)
        const Offset(5, 5),
        const Offset(0, 5),
      ];

      final cleaned = StructuralSlab.cleanPolygon(dirtyPolygon);
      expect(cleaned.length, equals(4));
      expect(cleaned[0], equals(const Offset(0, 0)));
      expect(cleaned[1], equals(const Offset(5, 0)));
      expect(cleaned[2], equals(const Offset(5, 5)));
      expect(cleaned[3], equals(const Offset(0, 5)));
    });

    test('5. mergeVertices merges adjacent vertices and collapses edge cleanly', () {
      const slab = StructuralSlab(
        id: 'slab_merge',
        polygon: [
          Offset(0, 0),
          Offset(5, 0),
          Offset(5, 3),
          Offset(5, 5), // Point to merge into (5,3)
          Offset(0, 5),
        ],
      );

      final merged = slab.mergeVertices(fromIndex: 3, toIndex: 2);
      expect(merged, isNotNull);
      expect(merged!.polygon.length, equals(4));
      expect(merged.polygon.contains(const Offset(5, 5)), isFalse);
    });

    test('6. dynamicPullOpeningEdge adjusts slab openings cleanly', () {
      const slab = StructuralSlab(
        id: 'slab_with_op',
        polygon: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
          Offset(0, 10),
        ],
        openings: [
          [
            Offset(2, 2),
            Offset(5, 2),
            Offset(5, 5),
            Offset(2, 5),
          ],
        ],
      );

      final updated = slab.dynamicPullOpeningEdge(
        openingIndex: 0,
        edgeIndex: 1, // edge from (5,2) to (5,5)
        distance: 1.0,
      );

      expect(updated.openings[0].length, equals(4));
      expect(updated.openings[0][1], equals(const Offset(6, 2)));
      expect(updated.openings[0][2], equals(const Offset(6, 5)));
      expect(StructuralSlab.hasSelfIntersections(updated.openings[0]), isFalse);
    });

    test('7. Structural2dPainter respects activeTool modal rendering for slabs', () {
      const slab = StructuralSlab(
        id: 'slab_1',
        polygon: [
          Offset(0, 0),
          Offset(5, 0),
          Offset(5, 5),
          Offset(0, 5),
        ],
      );
      const storey = StoreyLevel(
        id: 's1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 3.0,
        slabs: [slab],
      );

      // Verify that painter compiles and paints without error in column tool mode (slab contour only)
      final painterColumnTool = Structural2dPainter(
        currentStorey: storey,
        activeTool: StructuralDrawTool.column,
        selectedSlabId: 'slab_1',
        cadToScene: (pt) => pt,
        cadScale: 1.0,
      );
      expect(painterColumnTool.activeTool, equals(StructuralDrawTool.column));
      TestWidgetsFlutterBinding.ensureInitialized();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painterColumnTool.paint(canvas, const Size(800, 600)), returnsNormally);

      // Verify that painter compiles and paints without error in slab tool mode (full fill and handles)
      final painterSlabTool = Structural2dPainter(
        currentStorey: storey,
        activeTool: StructuralDrawTool.slab,
        selectedSlabId: 'slab_1',
        cadToScene: (pt) => pt,
        cadScale: 1.0,
      );
      expect(painterSlabTool.activeTool, equals(StructuralDrawTool.slab));
      expect(() => painterSlabTool.paint(canvas, const Size(800, 600)), returnsNormally);
    });
  });
}

