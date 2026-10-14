import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_editing_test.dart' as editing;

void main() {
  group('Wall step extrusion (MoveArchitectElements)', () {
    test('Moving a middle wall segment collinear to its neighbors generates perpendicular return walls', () {
      // Create 3 collinear walls along Y = 0:
      // w1: (0, 0) -> (2, 0)
      // w2: (2, 0) -> (4, 0)  <-- we move this one up by dy = 2
      // w3: (4, 0) -> (6, 0)
      final w1 = editing.wall('w1', const Offset(0, 0), const Offset(2, 0));
      final w2 = editing.wall('w2', const Offset(2, 0), const Offset(4, 0));
      final w3 = editing.wall('w3', const Offset(4, 0), const Offset(6, 0));

      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [w1, w2, w3],
        ),
      );
      addTearDown(model.dispose);

      // Execute MoveArchitectElements on w2 with delta (0, 2)
      model.execute(
        const MoveArchitectElements(
          storeyId: 's',
          elementIds: {'w2'},
          delta: Offset(0, 2),
        ),
      );

      final storey = model.project.activeStorey;
      // Should now have 5 walls: w1, w3, moved w2, and 2 new return walls!
      expect(storey.walls.length, 5);

      final movedW2 = storey.walls.firstWhere((w) => w.id == 'w2');
      expect(movedW2.startPoint, const Offset(2, 2));
      expect(movedW2.endPoint, const Offset(4, 2));

      // w1 and w3 endpoints remain intact
      final postW1 = storey.walls.firstWhere((w) => w.id == 'w1');
      expect(postW1.startPoint, const Offset(0, 0));
      expect(postW1.endPoint, const Offset(2, 0));

      final postW3 = storey.walls.firstWhere((w) => w.id == 'w3');
      expect(postW3.startPoint, const Offset(4, 0));
      expect(postW3.endPoint, const Offset(6, 0));

      // Return walls connect (2, 0) to (2, 2) and (4, 0) to (4, 2)
      final returnWalls = storey.walls.where((w) => w.id != 'w1' && w.id != 'w2' && w.id != 'w3').toList();
      expect(returnWalls.length, 2);

      final r1 = returnWalls.firstWhere(
        (w) => (w.startPoint == const Offset(2, 0) && w.endPoint == const Offset(2, 2)) ||
               (w.startPoint == const Offset(2, 2) && w.endPoint == const Offset(2, 0)),
      );
      final r2 = returnWalls.firstWhere(
        (w) => (w.startPoint == const Offset(4, 0) && w.endPoint == const Offset(4, 2)) ||
               (w.startPoint == const Offset(4, 2) && w.endPoint == const Offset(4, 0)),
      );
      expect(r1, isNotNull);
      expect(r2, isNotNull);
    });

    test('Internal wall without insulation does not move or stretch connected external wall with insulation', () {
      // External wall with 10cm insulation from (0, 0) to (10, 0)
      final extWall = ArchitectWall(
        id: 'ext',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.35,
        insulationThicknessOverride: 0.10,
        connectStart: true,
        connectEnd: true,
      );
      // Internal wall without insulation touching at (5, 0) and running down to (5, -4)
      final intWall = ArchitectWall(
        id: 'int',
        startPoint: const Offset(5, 0),
        endPoint: const Offset(5, -4),
        thickness: 0.15,
        connectStart: true,
        connectEnd: true,
      );

      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [extWall, intWall],
        ),
      );
      addTearDown(model.dispose);

      // Move internal wall horizontally by dx = 2
      model.execute(
        const MoveArchitectElements(
          storeyId: 's',
          elementIds: {'int'},
          delta: Offset(2, 0),
        ),
      );

      final storey = model.project.activeStorey;
      final postExt = storey.walls.firstWhere((w) => w.id == 'ext');
      // The external wall must NOT stretch or move its endpoints!
      expect(postExt.startPoint, const Offset(0, 0));
      expect(postExt.endPoint, const Offset(10, 0));

      final postInt = storey.walls.firstWhere((w) => w.id == 'int');
      expect(postInt.startPoint, const Offset(7, 0));
      expect(postInt.endPoint, const Offset(7, -4));
    });

    test('Extruding an external wall segment with insulation preserves insulation on connecting walls without inversion', () {
      // 3 collinear external walls along Y = 0 with insulation facing upwards (exteriorSide: left, normal (0, 1)):
      // w1: (0, 0) -> (2, 0)
      // w2: (2, 0) -> (4, 0)  <-- we extrude this outwards by dy = 2 (in direction of exterior)
      // w3: (4, 0) -> (6, 0)
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(2, 0),
        thickness: 0.35,
        exteriorSide: WallExteriorSide.left,
        insulationThicknessOverride: 0.10,
        connectStart: true,
        connectEnd: true,
      );
      final w2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(2, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.35,
        exteriorSide: WallExteriorSide.left,
        insulationThicknessOverride: 0.10,
        connectStart: true,
        connectEnd: true,
      );
      final w3 = ArchitectWall(
        id: 'w3',
        startPoint: const Offset(4, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.35,
        exteriorSide: WallExteriorSide.left,
        insulationThicknessOverride: 0.10,
        connectStart: true,
        connectEnd: true,
      );

      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [w1, w2, w3],
        ),
      );
      addTearDown(model.dispose);

      // Extrude w2 outwards by delta (0, 2)
      model.execute(
        const MoveArchitectElements(
          storeyId: 's',
          elementIds: {'w2'},
          delta: Offset(0, 2),
        ),
      );

      final storey = model.project.activeStorey;
      expect(storey.walls.length, 5);

      final returnWalls = storey.walls.where((w) => w.id != 'w1' && w.id != 'w2' && w.id != 'w3').toList();
      expect(returnWalls.length, 2);

      // Return wall at x=2 connecting (2, 0) to (2, 2):
      // Its exterior normal must point to the left (dx < 0, away from the protrusion)
      final leftReturn = returnWalls.firstWhere(
        (w) => (w.startPoint.dx - 2.0).abs() < 1e-4 && (w.endPoint.dx - 2.0).abs() < 1e-4,
      );
      expect(leftReturn.exteriorNormal.dx, lessThan(0.0), reason: 'Left return wall insulation must face outside (left)');

      // Return wall at x=4 connecting (4, 0) to (4, 2):
      // Its exterior normal must point to the right (dx > 0, away from the protrusion)
      final rightReturn = returnWalls.firstWhere(
        (w) => (w.startPoint.dx - 4.0).abs() < 1e-4 && (w.endPoint.dx - 4.0).abs() < 1e-4,
      );
      expect(rightReturn.exteriorNormal.dx, greaterThan(0.0), reason: 'Right return wall insulation must face outside (right)');
    });
  });
}
