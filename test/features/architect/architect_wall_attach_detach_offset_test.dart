import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_offset_dialog.dart';

void main() {
  group('Architect Wall Attach & Detach & Offset Tests', () {
    test('ConnectArchitectWallsAtVertex connects two intersecting walls at vertex', () {
      final wallA = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        thickness: 0.25,
      );
      final wallB = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(5, 4),
        endPoint: const Offset(5, 1),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(
        id: 'storey1',
        name: 'Storey 1',
        elevation: 0,
        height: 2.8,
        walls: [wallA, wallB],
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeStoreyId: 'storey1',
        storeys: [storey],
      );

      final cmd = ConnectArchitectWallsAtVertex(
        storeyId: 'storey1',
        wallIds: {'w1', 'w2'},
        primaryWallId: 'w1',
      );

      final updated = cmd.apply(project);
      final s = updated.storeys.first;
      final updatedA = s.walls.firstWhere((w) => w.id == 'w1');
      final updatedB = s.walls.firstWhere((w) => w.id == 'w2');

      // Common vertex should be (5, 0)
      expect(updatedA.endPoint, const Offset(5, 0));
      expect(updatedB.endPoint, const Offset(5, 0));
      expect(updatedA.connectEnd, isTrue);
      expect(updatedB.connectEnd, isTrue);
    });

    test('ConnectArchitectWallsAtVertex connects third wall to existing cluster vertex', () {
      // Wall 1 and 2 already share vertex at (5, 0)
      final wallA = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        thickness: 0.25,
        connectEnd: true,
      );
      final wallB = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(5, 5),
        endPoint: const Offset(5, 0),
        thickness: 0.25,
        connectEnd: true,
      );
      // Wall 3 starts nearby and aims towards the corner
      final wallC = ArchitectWall(
        id: 'w3',
        startPoint: const Offset(8, 3),
        endPoint: const Offset(6, 1),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(
        id: 'storey1',
        name: 'Storey 1',
        elevation: 0,
        height: 2.8,
        walls: [wallA, wallB, wallC],
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeStoreyId: 'storey1',
        storeys: [storey],
      );

      // Connect connected wall w1 with unconnected wall w3
      final cmd = ConnectArchitectWallsAtVertex(
        storeyId: 'storey1',
        wallIds: {'w1', 'w3'},
        primaryWallId: 'w1',
      );

      final updated = cmd.apply(project);
      final s = updated.storeys.first;
      final updatedC = s.walls.firstWhere((w) => w.id == 'w3');

      // Wall 3's end should snap directly to the existing cluster vertex (5, 0)!
      expect(updatedC.endPoint, const Offset(5, 0));
      expect(updatedC.connectEnd, isTrue);
    });

    test('SetArchitectWallConnection detaches walls', () {
      final wall = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        thickness: 0.25,
        connectStart: true,
        connectEnd: true,
      );

      final storey = ArchitectStorey(
        id: 'storey1',
        name: 'Storey 1',
        elevation: 0,
        height: 2.8,
        walls: [wall],
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeStoreyId: 'storey1',
        storeys: [storey],
      );

      final cmd = SetArchitectWallConnection(
        storeyId: 'storey1',
        wallIds: {'w1'},
        connected: false,
      );

      final updated = cmd.apply(project);
      final updatedWall = updated.storeys.first.walls.first;

      expect(updatedWall.connectStart, isFalse);
      expect(updatedWall.connectEnd, isFalse);
      expect(updatedWall.isDetached, isTrue);
    });

    test('BimElementOffsetOptions copyWith functionality', () {
      const original = BimElementOffsetOptions(1.5, true);
      final modified = original.copyWith(distance: 2.0);
      expect(modified.distance, 2.0);
      expect(modified.copy, isTrue);

      final modifiedCopy = original.copyWith(copy: false);
      expect(modifiedCopy.distance, 1.5);
      expect(modifiedCopy.copy, isFalse);
    });
  });
}
