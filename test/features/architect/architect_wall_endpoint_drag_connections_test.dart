import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';

void main() {
  group('ArchitectWall carryConnections endpoint tests', () {
    test('Two connected walls in an L-corner move together when shared corner is moved', () {
      final wall1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
        connectStart: true,
        connectEnd: true,
      );
      final wall2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4, 0),
        endPoint: const Offset(4, 3),
        thickness: 0.25,
        connectStart: true,
        connectEnd: true,
      );

      final project = ArchitectProject.starterWithCatalog(name: 'Test', storeyCount: 1);
      final storey = project.activeStorey.copyWith(walls: [wall1, wall2]);
      final initialProject = project.updateActiveStorey(storey);

      final command = UpdateArchitectWall(
        storeyId: storey.id,
        wall: wall1.copyWith(endPoint: const Offset(5, 1)),
        carryConnections: true,
      );

      final result = command.apply(initialProject);
      final updatedWalls = result.activeStorey.walls;

      final updatedW1 = updatedWalls.firstWhere((w) => w.id == 'w1');
      final updatedW2 = updatedWalls.firstWhere((w) => w.id == 'w2');

      // Wall 1 moved endpoint is (5, 1), fixed endpoint is (0, 0)
      expect(updatedW1.startPoint, const Offset(0, 0));
      expect(updatedW1.endPoint, const Offset(5, 1));

      // Wall 2 connected endpoint carried to (5, 1), opposite endpoint remains (4, 3)
      expect(updatedW2.startPoint, const Offset(5, 1));
      expect(updatedW2.endPoint, const Offset(4, 3));
    });

    test('Three connected walls meeting at a single corner all follow when the corner moves', () {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final w2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4, 0),
        endPoint: const Offset(4, 4),
        thickness: 0.25,
      );
      final w3 = ArchitectWall(
        id: 'w3',
        startPoint: const Offset(4, 0),
        endPoint: const Offset(8, 0),
        thickness: 0.25,
      );

      final project = ArchitectProject.starterWithCatalog(name: 'Test', storeyCount: 1);
      final storey = project.activeStorey.copyWith(walls: [w1, w2, w3]);
      final initialProject = project.updateActiveStorey(storey);

      final command = UpdateArchitectWall(
        storeyId: storey.id,
        wall: w1.copyWith(endPoint: const Offset(5, 2)),
        carryConnections: true,
      );

      final result = command.apply(initialProject);
      final walls = result.activeStorey.walls;

      expect(walls.firstWhere((w) => w.id == 'w1').endPoint, const Offset(5, 2));
      expect(walls.firstWhere((w) => w.id == 'w2').startPoint, const Offset(5, 2));
      expect(walls.firstWhere((w) => w.id == 'w3').startPoint, const Offset(5, 2));

      // Far endpoints remain intact
      expect(walls.firstWhere((w) => w.id == 'w1').startPoint, const Offset(0, 0));
      expect(walls.firstWhere((w) => w.id == 'w2').endPoint, const Offset(4, 4));
      expect(walls.firstWhere((w) => w.id == 'w3').endPoint, const Offset(8, 0));
    });

    test('Detached neighbor wall does NOT follow when corner is moved', () {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
        connectEnd: true,
      );
      final w2Detached = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4, 0),
        endPoint: const Offset(4, 3),
        thickness: 0.25,
        connectStart: false, // Detached at start!
      );

      final project = ArchitectProject.starterWithCatalog(name: 'Test', storeyCount: 1);
      final storey = project.activeStorey.copyWith(walls: [w1, w2Detached]);
      final initialProject = project.updateActiveStorey(storey);

      final command = UpdateArchitectWall(
        storeyId: storey.id,
        wall: w1.copyWith(endPoint: const Offset(5, 1)),
        carryConnections: true,
      );

      final result = command.apply(initialProject);
      final walls = result.activeStorey.walls;

      expect(walls.firstWhere((w) => w.id == 'w1').endPoint, const Offset(5, 1));
      // w2 was detached at start, so it must stay at (4, 0)
      expect(walls.firstWhere((w) => w.id == 'w2').startPoint, const Offset(4, 0));
    });

    test('Intermediate T-junction maintains absolute distance from stationary endpoint', () {
      final mainWall = ArchitectWall(
        id: 'main',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.25,
      );
      final partition = ArchitectWall(
        id: 'partition',
        startPoint: const Offset(3, 0),
        endPoint: const Offset(3, 4),
        thickness: 0.20,
      );

      final project = ArchitectProject.starterWithCatalog(name: 'Test', storeyCount: 1);
      final storey = project.activeStorey.copyWith(walls: [mainWall, partition]);
      final initialProject = project.updateActiveStorey(storey);

      // Extend main wall from 10m to 14m at endPoint; startPoint (0,0) is stationary
      final command = UpdateArchitectWall(
        storeyId: storey.id,
        wall: mainWall.copyWith(endPoint: const Offset(14, 0)),
        carryConnections: true,
      );

      final result = command.apply(initialProject);
      final walls = result.activeStorey.walls;

      final updatedMain = walls.firstWhere((w) => w.id == 'main');
      final updatedPartition = walls.firstWhere((w) => w.id == 'partition');

      expect(updatedMain.endPoint, const Offset(14, 0));
      // Partition must stay anchored at 3m from the stationary (0,0) corner
      expect(updatedPartition.startPoint.dx, closeTo(3.0, 1e-4));
      expect(updatedPartition.startPoint.dy, closeTo(0.0, 1e-4));
    });

    test('Undo restores all carried connected walls in a single step', () {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final w2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4, 0),
        endPoint: const Offset(4, 4),
        thickness: 0.25,
      );

      final project = ArchitectProject.starterWithCatalog(name: 'Test', storeyCount: 1);
      final storey = project.activeStorey.copyWith(walls: [w1, w2]);
      final initialProject = project.updateActiveStorey(storey);

      final controller = ArchitectCommandController(initialProject);

      controller.execute(
        UpdateArchitectWall(
          storeyId: storey.id,
          wall: w1.copyWith(endPoint: const Offset(6, 2)),
          carryConnections: true,
        ),
      );

      expect(controller.project.activeStorey.walls[0].endPoint, const Offset(6, 2));
      expect(controller.project.activeStorey.walls[1].startPoint, const Offset(6, 2));

      // Single undo
      controller.undo();

      expect(controller.project.activeStorey.walls[0].endPoint, const Offset(4, 0));
      expect(controller.project.activeStorey.walls[1].startPoint, const Offset(4, 0));
    });
  });
}
