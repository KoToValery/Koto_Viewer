import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';

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
}
