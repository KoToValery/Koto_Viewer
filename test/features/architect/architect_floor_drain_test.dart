import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_floor_drain.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/services/architect_floor_drain_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_floor_drain_commands.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/rendering/architect_floor_drain_mesh.dart';
import 'package:kotoview/src/features/architect/rendering/architect_floor_drain_painter_helper.dart';

void main() {
  group('ArchitectFloorDrain Model & Serialization', () {
    test('JSON roundtrip preserves all properties', () {
      final drain = ArchitectFloorDrain(
        id: 'drain_1',
        polygon: const [
          Offset(0, 0),
          Offset(2.0, 0),
          Offset(2.0, 2.5),
          Offset(0, 2.5),
        ],
        shape: ArchitectDrainShape.linear,
        position: const Offset(1.0, 0.20),
        angle: 0.0,
        size: 0.80,
        width: 0.08,
        slopePercent: 1.5,
      );

      final json = drain.toJson();
      final revived = ArchitectFloorDrain.fromJson(json);

      expect(revived.id, 'drain_1');
      expect(revived.shape, ArchitectDrainShape.linear);
      expect(revived.isLinear, isTrue);
      expect(revived.position, const Offset(1.0, 0.20));
      expect(revived.size, 0.80);
      expect(revived.width, 0.08);
      expect(revived.slopePercent, 1.5);
      expect(revived.polygon.length, 4);
      expect(revived.area, closeTo(5.0, 1e-4));
      expect(revived.centroid, const Offset(1.0, 1.25));
    });

    test('Axis calculation for round and linear shapes', () {
      final roundDrain = ArchitectFloorDrain(
        id: 'round_1',
        polygon: const [Offset(0, 0), Offset(2, 0), Offset(2, 2), Offset(0, 2)],
        shape: ArchitectDrainShape.round,
        position: const Offset(1.0, 1.0),
        size: 0.15,
      );

      final (rA, rB) = roundDrain.axis;
      expect(rA, const Offset(1.0, 1.0));
      expect(rB, const Offset(1.0, 1.0));

      final linearDrain = ArchitectFloorDrain(
        id: 'lin_1',
        polygon: const [Offset(0, 0), Offset(2, 0), Offset(2, 2), Offset(0, 2)],
        shape: ArchitectDrainShape.linear,
        position: const Offset(1.0, 1.0),
        angle: 0.0, // along X
        size: 0.80,
      );

      final (lA, lB) = linearDrain.axis;
      expect(lA, const Offset(0.60, 1.0));
      expect(lB, const Offset(1.40, 1.0));
    });
  });

  group('ArchitectFloorDrainGeometry Fall & Slope Field', () {
    final bathroomPoly = const [
      Offset(0, 0),
      Offset(2.0, 0),
      Offset(2.0, 2.0),
      Offset(0, 2.0),
    ];

    test('Calculates fall correctly based on slope percentage and distance', () {
      final drain = ArchitectFloorDrain(
        id: 'drain_test',
        polygon: bathroomPoly,
        shape: ArchitectDrainShape.round,
        position: const Offset(1.0, 1.0),
        size: 0.20, // radius 0.10
        slopePercent: 2.0, // 2 cm per 1 meter
      );

      // Point at edge of grate (dist = 0.10 from center)
      final pOnGrate = const Offset(1.10, 1.0);
      expect(ArchitectFloorDrainGeometry.distanceToGrate(drain, pOnGrate), closeTo(0.0, 1e-6));
      expect(ArchitectFloorDrainGeometry.fall(drain, pOnGrate), closeTo(0.0, 1e-6));

      // Point 1.0 m away from center -> 0.90 m from grate edge
      final pAway = const Offset(2.0, 1.0);
      expect(ArchitectFloorDrainGeometry.distanceToGrate(drain, pAway), closeTo(0.90, 1e-6));
      // fall = 0.90 * 2.0 / 100 = 0.018 m (18 mm)
      expect(ArchitectFloorDrainGeometry.fall(drain, pAway), closeTo(0.018, 1e-6));
    });

    test('Downhill slope direction vectors point directly towards drain', () {
      final drain = ArchitectFloorDrain(
        id: 'drain_round',
        polygon: bathroomPoly,
        shape: ArchitectDrainShape.round,
        position: const Offset(1.0, 1.0),
      );

      // Point to the right of drain (2.0, 1.0): water should flow left (-X)
      final dirRight = ArchitectFloorDrainGeometry.downhill(drain, const Offset(2.0, 1.0));
      expect(dirRight, isNotNull);
      expect(dirRight!.dx, closeTo(-1.0, 1e-6));
      expect(dirRight.dy, closeTo(0.0, 1e-6));

      // Point below drain (1.0, 2.0): water should flow up (-Y)
      final dirBelow = ArchitectFloorDrainGeometry.downhill(drain, const Offset(1.0, 2.0));
      expect(dirBelow, isNotNull);
      expect(dirBelow!.dx, closeTo(0.0, 1e-6));
      expect(dirBelow.dy, closeTo(-1.0, 1e-6));
    });

    test('Door thresholds are detected and calculate floor height at entry', () {
      final drain = ArchitectFloorDrain(
        id: 'drain_entry',
        polygon: bathroomPoly,
        shape: ArchitectDrainShape.round,
        position: const Offset(1.0, 1.5),
        slopePercent: 1.5,
      );

      // Wall along bottom edge y=0 with a door at x=1.0
      final wall = ArchitectWall(
        id: 'wall_door',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(2.0, 0),
        thickness: 0.15,
        doors: [
          ArchitectDoor(
            id: 'door_1',
            wallId: 'wall_door', uuid: 'u1',
            offsetRatio: 0.5, // at x=1.0
            width: 0.80,
          ),
        ],
      );

      final doors = ArchitectFloorDrainGeometry.thresholds(drain, [wall]);
      expect(doors.length, 1);
      final threshold = doors.first;
      expect(threshold.middle.dx, closeTo(1.0, 0.05));
      expect(threshold.middle.dy, closeTo(0.0, 0.05));
      // fall at threshold should be positive (floor slopes up to doorway)
      expect(threshold.fall, greaterThan(0.01));
    });

    test('Auto placement for linear drain sits along long wall away from door', () {
      final wallWithDoor = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(3.0, 0),
        thickness: 0.20,
        doors: [
          ArchitectDoor(
            id: 'd1',
            wallId: 'w1', uuid: 'u2',
            offsetRatio: 0.5,
            width: 0.90,
          ),
        ],
      );

      final roomPoly = const [
        Offset(0, 0),
        Offset(3.0, 0),
        Offset(3.0, 2.0),
        Offset(0, 2.0),
      ];

      final autoDrain = ArchitectFloorDrainGeometry.autoPlace(
        id: 'auto_linear',
        polygon: roomPoly,
        shape: ArchitectDrainShape.linear,
        walls: [wallWithDoor],
      );

      expect(autoDrain.isLinear, isTrue);
      expect(autoDrain.size, closeTo(0.80, 0.05));
      expect(autoDrain.containsPoint(autoDrain.position), isTrue);
      // Linear drain should not be placed on the door threshold
      expect((autoDrain.position - const Offset(1.5, 0.0)).distance, greaterThan(0.5));
    });
  });

  group('ArchitectFloorDrain Commands & Storey Integration', () {
    test('PlaceArchitectFloorDrain adds to storey and undo/redo works', () {
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project', createdAt: DateTime(2026), updatedAt: DateTime(2026), activeStoreyId: 'floor_1',
        storeys: [
          ArchitectStorey(
            id: 'floor_1',
            name: 'Ground Floor',
            walls: const [],
          ),
        ],
      );

      final drain = ArchitectFloorDrain(
        id: 'drain_placed',
        polygon: const [
          Offset(0, 0),
          Offset(2, 0),
          Offset(2, 2),
          Offset(0, 2),
        ],
        shape: ArchitectDrainShape.round,
        position: const Offset(1, 1),
      );

      final controller = ArchitectCommandController(project);
      controller.execute(PlaceArchitectFloorDrain(storeyId: 'floor_1', drain: drain));

      expect(controller.project.activeStorey.floorDrains.length, 1);
      expect(controller.project.activeStorey.floorDrains.first.id, 'drain_placed');

      // Undo
      controller.undo();
      expect(controller.project.activeStorey.floorDrains.isEmpty, isTrue);

      // Redo
      controller.redo();
      expect(controller.project.activeStorey.floorDrains.length, 1);
    });

    test('UpdateArchitectFloorDrain updates position and recalculates geometry', () {
      final drain = ArchitectFloorDrain(
        id: 'drain_u',
        polygon: const [
          Offset(0, 0),
          Offset(2, 0),
          Offset(2, 2),
          Offset(0, 2),
        ],
        shape: ArchitectDrainShape.round,
        position: const Offset(1, 1),
        slopePercent: 1.5,
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project', createdAt: DateTime(2026), updatedAt: DateTime(2026), activeStoreyId: 'floor_1',
        storeys: [
          ArchitectStorey(
            id: 'floor_1',
            name: 'Ground Floor',
            floorDrains: [drain],
          ),
        ],
      );

      final controller = ArchitectCommandController(project);
      final moved = drain.copyWith(position: const Offset(1.2, 0.8), slopePercent: 2.0);
      controller.execute(UpdateArchitectFloorDrain(storeyId: 'floor_1', drain: moved));

      final active = controller.project.activeStorey.floorDrains.first;
      expect(active.position, const Offset(1.2, 0.8));
      expect(active.slopePercent, 2.0);
    });
  });

  group('ArchitectFloorDrain 3D Mesh Generation', () {
    test('Builds solid sloping floor and round grate mesh', () {
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test', createdAt: DateTime(2026), updatedAt: DateTime(2026), activeStoreyId: 's1',
        storeys: [
          ArchitectStorey(
            id: 's1',
            name: 'L1',
            elevation: 0.0,
            floorFinishThickness: 0.05,
          ),
        ],
      );

      final roundDrain = ArchitectFloorDrain(
        id: 'd_round',
        polygon: const [
          Offset(0, 0),
          Offset(2, 0),
          Offset(2, 2),
          Offset(0, 2),
        ],
        shape: ArchitectDrainShape.round,
        position: const Offset(1, 1),
      );

      final tris = ArchitectFloorDrainMesh.build(project, project.activeStorey, roundDrain);
      expect(tris, isNotEmpty);
      // Floor triangles + round grate rim + spoke slots
      expect(tris.length, greaterThan(50));
    });

    test('Builds solid sloping floor and linear channel grate mesh', () {
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test', createdAt: DateTime(2026), updatedAt: DateTime(2026), activeStoreyId: 's1',
        storeys: [
          ArchitectStorey(
            id: 's1',
            name: 'L1',
            elevation: 0.0,
            floorFinishThickness: 0.05,
          ),
        ],
      );

      final linearDrain = ArchitectFloorDrain(
        id: 'd_linear',
        polygon: const [
          Offset(0, 0),
          Offset(3, 0),
          Offset(3, 2),
          Offset(0, 2),
        ],
        shape: ArchitectDrainShape.linear,
        position: const Offset(1.5, 0.3),
        size: 0.80,
        width: 0.08,
      );

      final tris = ArchitectFloorDrainMesh.build(project, project.activeStorey, linearDrain);
      expect(tris, isNotEmpty);
      expect(tris.length, greaterThan(60));
    });
  });
}
