import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_network.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_exterior_resolver.dart';

void main() {
  group('ArchitectWallArc and Wall intersections growable list tests', () {
    test('lineIntersections returns growable list even with no intersections', () {
      const arc = ArchitectWallArc(Offset(0, 0), Offset(4, 0), 1.0);
      // Line far away from the arc circle
      final hits = arc.lineIntersections(const Offset(10, 10), const Offset(12, 12));
      expect(hits, isEmpty);
      // Verify list is growable and does not throw Unsupported operation
      expect(() => hits.add(const Offset(0, 0)), returnsNormally);
      expect(hits.length, 1);
    });

    test('arcIntersections returns growable list even with no intersections', () {
      const arc1 = ArchitectWallArc(Offset(0, 0), Offset(2, 0), 1.0);
      const arc2 = ArchitectWallArc(Offset(10, 10), Offset(12, 10), 1.0);
      final hits = arc1.arcIntersections(arc2);
      expect(hits, isEmpty);
      // Verify list is growable
      expect(() => hits.add(const Offset(5, 5)), returnsNormally);
      expect(hits.length, 1);
    });

    test('ArchitectWall.intersections returns growable list in all modes', () {
      final straight = ArchitectWall(
        id: 's1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final curved = ArchitectWall(
        id: 'c1',
        startPoint: const Offset(0, 5),
        endPoint: const Offset(4, 5),
        arcBulge: 0.5,
        thickness: 0.25,
      );

      final hits1 = straight.intersections(curved);
      expect(() => hits1.add(const Offset(1, 1)), returnsNormally);

      final hits2 = curved.intersections(straight);
      expect(() => hits2.add(const Offset(2, 2)), returnsNormally);

      final hits3 = straight.intersections(straight);
      expect(() => hits3.add(const Offset(3, 3)), returnsNormally);

      final hits4 = curved.intersections(curved);
      expect(() => hits4.add(const Offset(4, 4)), returnsNormally);
    });
  });

  group('ArchitectWallNetwork junctions and body with curved walls', () {
    test('junctions does not throw when straight wall meets curved wall endpoint or face', () {
      // Curved wall from (0, 0) to (4, 0) with bulge 0.5
      final curved = ArchitectWall(
        id: 'w_curved',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        arcBulge: 0.5,
        thickness: 0.25,
      );

      // Straight wall with startPoint touching the curved wall at (0, 0)
      final straightTouching = ArchitectWall(
        id: 'w_straight',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(0, 3),
        thickness: 0.25,
      );

      // Neither should throw during junctions or body calculation
      expect(
        () => ArchitectWallNetwork.junctions([curved, straightTouching]),
        returnsNormally,
      );

      final bodyPath = ArchitectWallNetwork.body([curved, straightTouching]);
      expect(bodyPath, isNotNull);
      expect(bodyPath.getBounds().isEmpty, isFalse);
    });

    test('junctions does not throw when straight wall touches curved wall face with no line-circle intersections', () {
      final curved = ArchitectWall(
        id: 'w_curved',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        arcBulge: 0.4,
        thickness: 0.30,
      );

      // Point inside curved wall thickness corridor but where ray doesn't intersect arc circle within finite bounds
      final touchPoint = curved.arc!.pointAt(0.5);
      final straight = ArchitectWall(
        id: 'w_t',
        startPoint: touchPoint,
        endPoint: touchPoint + const Offset(0, 2),
        thickness: 0.25,
      );

      expect(
        () => ArchitectWallNetwork.junctions([curved, straight]),
        returnsNormally,
      );

      final path = ArchitectWallNetwork.body([curved, straight]);
      expect(path, isNotNull);
    });
  });

  group('ArchitectWallExteriorResolver & CommandController with curved walls', () {
    test('ArchitectWallExteriorResolver resolves without throwing on non-intersecting curved walls', () {
      final curved = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        arcBulge: 0.5,
        thickness: 0.25,
      );
      final straight = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(0, 5),
        endPoint: const Offset(4, 5),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(id: 's', name: 'Storey 1', walls: [curved, straight]);
      final resolved = ArchitectWallExteriorResolver.resolveStorey(storey);
      expect(resolved.walls.length, 2);
    });
  });
}
