import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_parallel_alignment_helper.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Structural Slab - Polygon Cleaning & Spike Elimination', () {
    test('cleanPolygon collapses duplicate adjacent vertices within minDistance', () {
      final raw = [
        const Offset(0, 0),
        const Offset(5, 0),
        const Offset(5.01, 0.01), // duplicate
        const Offset(5, 5),
        const Offset(0, 5),
      ];
      final cleaned = StructuralSlab.cleanPolygon(raw, minDistance: 0.05);
      expect(cleaned.length, equals(4));
      expect(cleaned, equals([
        const Offset(0, 0),
        const Offset(5, 0),
        const Offset(5, 5),
        const Offset(0, 5),
      ]));
    });

    test('cleanPolygon eliminates collinear orphan vertices along a straight edge', () {
      final raw = [
        const Offset(0, 0),
        const Offset(2.5, 0), // orphan midpoint on straight edge
        const Offset(5, 0),
        const Offset(5, 5),
        const Offset(0, 5),
      ];
      final cleaned = StructuralSlab.cleanPolygon(raw);
      expect(cleaned.length, equals(4));
      expect(cleaned.contains(const Offset(2.5, 0)), isFalse);
    });

    test('cleanPolygon eliminates acute spikes and needle fold-backs', () {
      final rawWithSpike = [
        const Offset(0, 0),
        const Offset(5, 0),
        const Offset(5.02, 3.0), // needle spike jutting out
        const Offset(5.0, 0.05), // returning back immediately
        const Offset(5, 5),
        const Offset(0, 5),
      ];
      final cleaned = StructuralSlab.cleanPolygon(rawWithSpike, minDistance: 0.01);
      // The acute needle fold-back should be eliminated
      expect(cleaned.length, lessThanOrEqualTo(5));
      expect(cleaned.contains(const Offset(5.02, 3.0)), isFalse);
    });

    test('removeVertex and cleanPolygon merges vertices cleanly', () {
      const slab = StructuralSlab(
        id: 'slab1',
        polygon: [
          Offset(0, 0),
          Offset(3, 0),
          Offset(6, 0), // intermediate vertex to merge
          Offset(6, 4),
          Offset(0, 4),
        ],
      );
      final removed = slab.removeVertex(1);
      expect(removed, isNotNull);
      final cleaned = StructuralSlab.cleanPolygon(removed!.polygon);
      expect(cleaned.length, equals(4));
      expect(cleaned[0], equals(const Offset(0, 0)));
      expect(cleaned[1], equals(const Offset(6, 0)));
    });
  });

  group('Structural Slab - offsetEdge (ArchiCAD-Style Parallel Edge Movement)', () {
    test('offsetEdge outward expands edge parallel and extends adjacent edges cleanly', () {
      // 4x4 square (CCW: (0,0) -> (4,0) -> (4,4) -> (0,4))
      const slab = StructuralSlab(
        id: 'slab1',
        polygon: [
          Offset(0, 0),
          Offset(4, 0),
          Offset(4, 4),
          Offset(0, 4),
        ],
      );
      // Edge 1 is from (4,0) to (4,4). Normal is (+1, 0).
      // Offset outward by 1.0 -> X of that edge should move from 4.0 to 5.0.
      final offsetSlab = slab.offsetEdge(edgeIndex: 1, distance: 1.0);
      expect(offsetSlab.polygon.length, equals(4));
      expect(offsetSlab.polygon[1], equals(const Offset(5, 0)));
      expect(offsetSlab.polygon[2], equals(const Offset(5, 4)));
      expect(offsetSlab.polygon[0], equals(const Offset(0, 0)));
      expect(offsetSlab.polygon[3], equals(const Offset(0, 4)));
    });

    test('offsetEdge inward retracts edge parallel and trims adjacent edges without spikes', () {
      // 6x6 square (CCW)
      const slab = StructuralSlab(
        id: 'slab1',
        polygon: [
          Offset(0, 0),
          Offset(6, 0),
          Offset(6, 6),
          Offset(0, 6),
        ],
      );
      // Edge 2 is from (6,6) to (0,6). Normal is (0, +1).
      // Inward retraction by -2.0 -> Y of top edge becomes 4.0.
      final offsetSlab = slab.offsetEdge(edgeIndex: 2, distance: -2.0);
      expect(offsetSlab.polygon.length, equals(4));
      expect(offsetSlab.polygon[2], equals(const Offset(6, 4)));
      expect(offsetSlab.polygon[3], equals(const Offset(0, 4)));
    });
  });

  group('SlabParallelAlignmentHelper - Magnetic Parallel Snapping', () {
    test('snaps to parallel edge of another slab within tolerance', () {
      // Active slab edge being dragged: edge from (0, 0) to (0, 5) with normal (1, 0)
      final edgeV1 = const Offset(0, 0);
      final edgeV2 = const Offset(0, 5);
      final normal = const Offset(1, 0);

      // Target slab with parallel edge along X = 3 (from (3, 0) to (3, 8))
      const targetSlab = StructuralSlab(
        id: 'target_slab',
        polygon: [
          Offset(3, 0),
          Offset(8, 0),
          Offset(8, 8),
          Offset(3, 8),
        ],
      );

      final storey = StoreyLevel(
        id: 'storey1',
        name: 'Floor 1',
        elevation: 0,
        height: 3,
        slabs: [targetSlab],
      );

      // Raw distance dragged is 2.9 m (near 3.0 m, within tolerance 0.2 m)
      final snap = SlabParallelAlignmentHelper.findParallelEdgeAlignment(
        edgeV1: edgeV1,
        edgeV2: edgeV2,
        gripNormal: normal,
        rawDistance: 2.9,
        toleranceCad: 0.2,
        activeStorey: storey,
      );

      expect(snap, isNotNull);
      expect(snap!.distance, closeTo(3.0, 1e-3));
      expect(snap.source, equals('slab'));
    });

    test('snaps to parallel beam within tolerance', () {
      // Dragging horizontal edge from (0, 2) to (6, 2) with normal (0, 1)
      final edgeV1 = const Offset(0, 2);
      final edgeV2 = const Offset(6, 2);
      final normal = const Offset(0, 1);

      // Beam along Y = 5 from (0, 5) to (10, 5)
      const beam = StructuralBeam(
        id: 'beam1',
        start: Offset(0, 5),
        end: Offset(10, 5),
        width: 0.25,
        depth: 0.50,
      );

      final storey = StoreyLevel(
        id: 'storey1',
        name: 'Floor 1',
        elevation: 0,
        height: 3,
        beams: [beam],
      );

      // Raw distance is 2.95 m (expected snap to 3.0 m)
      final snap = SlabParallelAlignmentHelper.findParallelEdgeAlignment(
        edgeV1: edgeV1,
        edgeV2: edgeV2,
        gripNormal: normal,
        rawDistance: 2.95,
        toleranceCad: 0.15,
        activeStorey: storey,
      );

      expect(snap, isNotNull);
      expect(snap!.distance, closeTo(3.0, 1e-3));
      expect(snap.source, equals('beam'));
    });

    test('ignores non-parallel elements', () {
      // Dragging vertical edge from (0, 0) to (0, 5) with normal (1, 0)
      final edgeV1 = const Offset(0, 0);
      final edgeV2 = const Offset(0, 5);
      final normal = const Offset(1, 0);

      // Perpendicular beam along X axis: from (0, 0) to (5, 0)
      const beam = StructuralBeam(
        id: 'beam_perp',
        start: Offset(0, 0),
        end: Offset(5, 0),
      );

      final storey = StoreyLevel(
        id: 'storey1',
        name: 'Floor 1',
        elevation: 0,
        height: 3,
        beams: [beam],
      );

      final snap = SlabParallelAlignmentHelper.findParallelEdgeAlignment(
        edgeV1: edgeV1,
        edgeV2: edgeV2,
        gripNormal: normal,
        rawDistance: 2.0,
        toleranceCad: 0.5,
        activeStorey: storey,
      );

      expect(snap, isNull);
    });

    test('ignores parallel elements outside tolerance distance', () {
      final edgeV1 = const Offset(0, 0);
      final edgeV2 = const Offset(0, 5);
      final normal = const Offset(1, 0);

      const targetSlab = StructuralSlab(
        id: 'far_slab',
        polygon: [
          Offset(10, 0),
          Offset(15, 0),
          Offset(15, 5),
          Offset(10, 5),
        ],
      );

      final storey = StoreyLevel(
        id: 'storey1',
        name: 'Floor 1',
        elevation: 0,
        height: 3,
        slabs: [targetSlab],
      );

      // Drag distance 2.0 m, target is at 10.0 m (diff = 8.0 m > tolerance 0.2 m)
      final snap = SlabParallelAlignmentHelper.findParallelEdgeAlignment(
        edgeV1: edgeV1,
        edgeV2: edgeV2,
        gripNormal: normal,
        rawDistance: 2.0,
        toleranceCad: 0.2,
        activeStorey: storey,
      );

      expect(snap, isNull);
    });
  });
}
