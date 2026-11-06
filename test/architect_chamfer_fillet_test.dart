import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/services/architect_chamfer_fillet.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';

void main() {
  group('ArchitectChamferFillet - Polygons', () {
    test('polygonChamfer bevels a single corner of a square correctly', () {
      final square = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];

      // Chamfer corner 1 (10, 0) with distance 2.0
      final result = ArchitectChamferFillet.polygonChamfer(
        square,
        vertexIndex: 1,
        distance: 2.0,
      );

      // Should have 5 points: 0, (8,0), (10,2), 2, 3
      expect(result.length, 5);
      expect(result[0], const Offset(0, 0));
      expect(result[1], const Offset(8, 0));
      expect(result[2], const Offset(10, 2));
      expect(result[3], const Offset(10, 10));
      expect(result[4], const Offset(0, 10));
    });

    test('polygonChamfer bevels all corners when vertexIndex is null', () {
      final square = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];

      final result = ArchitectChamferFillet.polygonChamfer(
        square,
        distance: 2.0,
      );

      // 4 corners -> 8 points
      expect(result.length, 8);
    });

    test('polygonFillet rounds corner with circular arc points', () {
      final square = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];

      // Fillet corner 1 (10,0) with radius 2.0, 4 segments
      final result = ArchitectChamferFillet.polygonFillet(
        square,
        vertexIndex: 1,
        radius: 2.0,
        segments: 4,
      );

      // Arc has 5 points (0..4), replacing vertex 1
      // Total points: 1 (point 0) + 5 (arc) + 2 (points 2,3) = 8
      expect(result.length, 8);

      // Tangent points should be (8, 0) and (10, 2)
      expect((result[1] - const Offset(8, 0)).distance, lessThan(1e-4));
      expect((result[5] - const Offset(10, 2)).distance, lessThan(1e-4));

      // Mid arc point should be distance 2 from center (8, 2)
      final center = const Offset(8, 2);
      for (var i = 1; i <= 5; i++) {
        expect((result[i] - center).distance, closeTo(2.0, 1e-4));
      }
    });

    test('polygonChamfer handles open polylines without touching endpoints', () {
      final polyline = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
      ];

      final result = ArchitectChamferFillet.polygonChamfer(
        polyline,
        distance: 1.0,
        isClosed: false,
      );

      expect(result.first, const Offset(0, 0));
      expect(result.last, const Offset(10, 10));
      expect(result.length, 4); // Endpoint 0, two chamfer points at corner 1, endpoint 2
    });
  });

  group('ArchitectChamferFillet - Walls', () {
    test('wallPairChamfer creates bevel connector between perpendicular walls', () {
      final wallA = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.25,
      );
      final wallB = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(10, 0),
        endPoint: const Offset(10, 10),
        thickness: 0.25,
      );

      final res = ArchitectChamferFillet.wallPairChamfer(
        wallA,
        wallB,
        distance: 2.0,
      );

      expect(res, isNotNull);
      // Wall A should be shortened to (8, 0)
      expect(res!.wallA.endPoint, const Offset(8, 0));
      // Wall B should start at (10, 2)
      expect(res.wallB.startPoint, const Offset(10, 2));
      // Connector wall connects (8, 0) to (10, 2)
      expect(res.connector.startPoint, const Offset(8, 0));
      expect(res.connector.endPoint, const Offset(10, 2));
      expect(res.connector.thickness, 0.25);
    });

    test('wallPairFillet creates curved connector with correct arc bulge', () {
      final wallA = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.25,
      );
      final wallB = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(10, 0),
        endPoint: const Offset(10, 10),
        thickness: 0.25,
      );

      final res = ArchitectChamferFillet.wallPairFillet(
        wallA,
        wallB,
        radius: 2.0,
      );

      expect(res, isNotNull);
      expect((res!.wallA.endPoint - const Offset(8, 0)).distance, lessThan(1e-4));
      expect((res.wallB.startPoint - const Offset(10, 2)).distance, lessThan(1e-4));
      expect(res.connector.isCurved, isTrue);
      expect(res.connector.arcBulge.abs(), greaterThan(0));
    });
  });

  group('ArchitectChamferFillet - CAD Lines', () {
    test('linePairChamfer bevels intersection of two CAD lines', () {
      final lineA = ArchitectCadPrimitive(
        id: 'c1',
        type: CadPrimitiveType.line,
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
      );
      final lineB = ArchitectCadPrimitive(
        id: 'c2',
        type: CadPrimitiveType.line,
        startPoint: const Offset(5, 0),
        endPoint: const Offset(5, 5),
      );

      final res = ArchitectChamferFillet.linePairChamfer(
        lineA,
        lineB,
        distance: 1.0,
      );

      expect(res, isNotNull);
      expect(res!.lineA.endPoint, const Offset(4, 0));
      expect(res.lineB.startPoint, const Offset(5, 1));
      expect(res.connector.startPoint, const Offset(4, 0));
      expect(res.connector.endPoint, const Offset(5, 1));
    });
  });
}
