import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/components/definitions/service_components.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_service_snap.dart';

void main() {
  group('ArchitectServiceSnap - Risers & Chimneys Snap Tests', () {
    const wall1 = ArchitectWall(
      id: 'w1',
      startPoint: Offset(0, 0),
      endPoint: Offset(6, 0),
      thickness: 0.25,
      height: 2.8,
    );

    const wall2 = ArchitectWall(
      id: 'w2',
      startPoint: Offset(6, 0),
      endPoint: Offset(6, 6),
      thickness: 0.25,
      height: 2.8,
    );

    final project = ArchitectProject(
      id: 'test_prj',
      name: 'Test Project',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      storeys: [
        ArchitectStorey(
          id: 's1',
          name: 'Ground Floor',
          walls: [wall1, wall2],
        ),
      ],
      activeStoreyId: 's1',
    );

    test('Snaps flush to interior face of horizontal wall and aligns angle', () {
      final snap = ArchitectServiceSnap.resolve(
        raw: const Offset(3.0, 0.2),
        project: project,
        width: 0.40,
        depth: 0.40,
        tolerance: 0.5,
      );

      expect(snap.point.dx, closeTo(3.0, 0.05));
      expect(snap.point.dy, closeTo(0.325, 0.01));
      expect(snap.angleDeg, isNotNull);
      expect(snap.angleDeg! % 180, closeTo(0.0, 1.0));
      expect(snap.snapLabel, contains('Wall face'));
    });

    test('Snaps flush to exterior face of horizontal wall', () {
      final snap = ArchitectServiceSnap.resolve(
        raw: const Offset(3.0, -0.2),
        project: project,
        width: 0.40,
        depth: 0.40,
        tolerance: 0.5,
      );

      expect(snap.point.dx, closeTo(3.0, 0.05));
      expect(snap.point.dy, closeTo(-0.325, 0.01));
      expect(snap.snapLabel, contains('Wall face'));
    });

    test('Snaps to internal wall corner where w1 and w2 meet', () {
      final snap = ArchitectServiceSnap.resolve(
        raw: const Offset(5.7, 0.3),
        project: project,
        width: 0.40,
        depth: 0.40,
        tolerance: 0.5,
      );

      expect(snap.point.dx, closeTo(5.675, 0.05));
      expect(snap.point.dy, closeTo(0.325, 0.05));
      expect(snap.snapLabel, contains('Wall corner'));
    });

    test('Snaps flush next to door opening jamb', () {
      final wallWithDoor = wall1.addDoor(
        const ArchitectDoor(
          id: 'd1',
          wallId: 'w1',
          uuid: 'door_uuid',
          offsetRatio: 0.5,
          width: 0.90,
        ),
      );

      final projectWithDoor = ArchitectProject(
        id: 'test_prj',
        name: 'Test Project',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        storeys: [
          ArchitectStorey(
            id: 's1',
            name: 'Ground Floor',
            walls: [wallWithDoor],
          ),
        ],
        activeStoreyId: 's1',
      );

      final snap = ArchitectServiceSnap.resolve(
        raw: const Offset(3.6, 0.25),
        project: projectWithDoor,
        width: 0.40,
        depth: 0.40,
        tolerance: 0.4,
      );

      expect(snap.point.dx, closeTo(3.65, 0.05));
      expect(snap.snapLabel, contains('Opening jamb'));
    });

    test('Footprint calculations on ServiceComponentDefinition return accurate metrics', () {
      final def = ServiceComponentDefinition(ServiceComponentKind.chimney);

      final (w, d) = def.footprint({'width': 0.50, 'depth': 0.50});
      expect(w, 0.50);
      expect(d, 0.50);

      final (dw, dd) = def.footprint();
      expect(dw, 0.36); // Default Schiedel chimney footprint is 0.36 x 0.36
      expect(dd, 0.36);
    });
  });
}
