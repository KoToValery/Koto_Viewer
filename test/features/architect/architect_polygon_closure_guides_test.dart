import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_contour_drafting_geometry.dart';

void main() {
  group('Polygon closure orthogonal snap (calculatePolygonClosureOrthoSnap)', () {
    test('Snaps 4th point orthogonally to 1st point for a rectangle (4 points closure)', () {
      // Points 1, 2, 3: (0,0), (5,0), (5,3)
      // Closing 4th point should be at (0, 3) to form a perpendicular closure with (0,0) and (5,3)
      final points = [
        const Offset(0, 0),
        const Offset(5, 0),
        const Offset(5, 3),
      ];

      // Raw pointer near (0, 3), e.g. (-0.05, 3.08)
      final raw = const Offset(-0.05, 3.08);
      final result = BimContourDraftingGeometry.calculatePolygonClosureOrthoSnap(
        points: points,
        raw: raw,
        tolerance: 0.30,
      );

      expect(result.isSnapped, isTrue);
      expect(result.point, const Offset(0, 3));
      expect(result.magneticGuides, hasLength(2));
      // First guide along Y=3 from (5,3) through (0,3)
      expect(result.magneticGuides[0].$1.dy, 3.0);
      expect(result.magneticGuides[0].$2.dy, 3.0);
      // Second guide along X=0 from (0,3) to (0,0)
      expect(result.magneticGuides[1].$1.dx, 0.0);
      expect(result.magneticGuides[1].$2.dx, 0.0);
    });

    test('Snaps 6th point orthogonally to 1st point for complex L-shaped room (5-9 points)', () {
      // L-shape with 5 existing points:
      // P1: (0, 0)
      // P2: (6, 0)
      // P3: (6, 4)
      // P4: (4, 4)
      // P5: (4, 2)
      // Closing point P6 should snap to (0, 2) to orthogonally align with P5(4,2) and P1(0,0)
      final points = [
        const Offset(0, 0),
        const Offset(6, 0),
        const Offset(6, 4),
        const Offset(4, 4),
        const Offset(4, 2),
      ];

      final raw = const Offset(0.08, 1.95);
      final result = BimContourDraftingGeometry.calculatePolygonClosureOrthoSnap(
        points: points,
        raw: raw,
        tolerance: 0.30,
      );

      expect(result.isSnapped, isTrue);
      expect(result.point, const Offset(0, 2));
      expect(result.magneticGuides, hasLength(2));
    });

    test('Does not snap if pointer is far beyond tolerance', () {
      final points = [
        const Offset(0, 0),
        const Offset(5, 0),
        const Offset(5, 3),
      ];

      final raw = const Offset(2.0, 3.0); // Far from (0,3)
      final result = BimContourDraftingGeometry.calculatePolygonClosureOrthoSnap(
        points: points,
        raw: raw,
        tolerance: 0.30,
      );

      expect(result.isSnapped, isFalse);
    });

    test('Requires at least 3 points', () {
      final points = [
        const Offset(0, 0),
        const Offset(5, 0),
      ];
      final result = BimContourDraftingGeometry.calculatePolygonClosureOrthoSnap(
        points: points,
        raw: const Offset(0, 3),
        tolerance: 0.30,
      );
      expect(result.isSnapped, isFalse);
    });
  });
}
