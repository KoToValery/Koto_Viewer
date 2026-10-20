import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'architect_editing_test.dart' as editing;

void main() {
  group('Smart Tracking Guides and Perpendicular Alignment', () {
    test('ArchitectWallAlignment.point generates continuous guide line with catchment', () {
      final wall = ArchitectWall(
        id: 'wall-ref',
        startPoint: const Offset(5, 0),
        endPoint: const Offset(5, 6),
        thickness: 0.25,
      );

      // Raw point near x = 5 (within 22px / scale = 0.44m at scale = 50)
      const raw = Offset(5.1, 10.0);
      final (snapped, guides) = ArchitectWallAlignment.point(
        raw,
        [wall],
        50.0, // scale
      );

      // Should snap to x = 5 (the longitudinal face/centerline extension)
      expect(snapped.dx, closeTo(5.0, 0.15));
      expect(guides, isNotEmpty);

      // Guide line must stretch continuously from the reference wall to the snapped point
      final guide = guides.first;
      final minY = guide.$1.dy < guide.$2.dy ? guide.$1.dy : guide.$2.dy;
      final maxY = guide.$1.dy > guide.$2.dy ? guide.$1.dy : guide.$2.dy;
      // It should span at least from the wall (y <= 6) to the point (y >= 10)
      expect(minY, lessThanOrEqualTo(6.0));
      expect(maxY, greaterThanOrEqualTo(10.0));
    });

    test('ArchitectWallSnap.resolve snaps to mental extension of nearby perpendicular wall', () {
      // Wall A is horizontal, extending from (0, 4) to (4, 4)
      final wallA = ArchitectWall(
        id: 'wall-a',
        startPoint: const Offset(0, 4),
        endPoint: const Offset(4, 4),
        thickness: 0.25,
      );

      // Wall B is perpendicular (vertical), extending from (6, -2) to (6, 2)
      // Centerline at x = 6.0, exterior faces at x = 5.875 and x = 6.125
      final wallB = ArchitectWall(
        id: 'wall-b',
        startPoint: const Offset(6, -2),
        endPoint: const Offset(6, 2),
        thickness: 0.25,
      );

      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [wallA, wallB],
        ),
      );
      addTearDown(model.dispose);

      // 1. Moving endpoint of wallA near the exterior face (5.875)
      final snapFace = ArchitectWallSnap.resolve(
        raw: const Offset(5.88, 4.0),
        magnetic: true,
        anchor: const Offset(0, 4),
        project: model.project,
        scale: 40.0,
        referenceDirections: const [Offset(1, 0), Offset(0, 1)],
      );

      expect(snapFace.isSnapped, isTrue);
      expect(snapFace.snapLabel, equals('Perpendicular'));
      expect(snapFace.point.dx, closeTo(5.875, 0.01));
      expect(snapFace.point.dy, closeTo(4.0, 0.01));
      expect(snapFace.magneticGuides.length, equals(2));

      // 2. Moving endpoint of wallA near the centerline (6.0)
      final snapCenter = ArchitectWallSnap.resolve(
        raw: const Offset(6.005, 4.0),
        magnetic: true,
        anchor: const Offset(0, 4),
        project: model.project,
        scale: 40.0,
        referenceDirections: const [Offset(1, 0), Offset(0, 1)],
      );

      expect(snapCenter.isSnapped, isTrue);
      expect(snapCenter.snapLabel, equals('Perpendicular'));
      expect(snapCenter.point.dx, closeTo(6.0, 0.01));
      expect(snapCenter.point.dy, closeTo(4.0, 0.01));
      expect(snapCenter.magneticGuides.length, equals(2));

      final rayGuide = snapCenter.magneticGuides[0];
      final perpGuide = snapCenter.magneticGuides[1];

      // Ray guide starts at anchor (0, 4)
      expect(rayGuide.$1.dx, closeTo(0.0, 1e-3));
      expect(rayGuide.$1.dy, closeTo(4.0, 1e-3));
      expect(rayGuide.$2.dx, greaterThanOrEqualTo(6.0));

      // Perpendicular guide connects from wallB (y <= 2) to crossing (y >= 4)
      final perpMinY = perpGuide.$1.dy < perpGuide.$2.dy ? perpGuide.$1.dy : perpGuide.$2.dy;
      final perpMaxY = perpGuide.$1.dy > perpGuide.$2.dy ? perpGuide.$1.dy : perpGuide.$2.dy;
      expect(perpMinY, lessThanOrEqualTo(2.0));
      expect(perpMaxY, greaterThanOrEqualTo(4.0));
    });

    test('ArchitectWallSnap.resolve snaps to transverse end cap of parallel wall', () {
      // Wall B is parallel at y = 5, from (10, 5) to (15, 5)
      // Wall B's startPoint is at x = 10.
      final wallB = ArchitectWall(
        id: 'wall-b',
        startPoint: const Offset(10, 5),
        endPoint: const Offset(15, 5),
        thickness: 0.25,
      );

      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [wallB],
        ),
      );
      addTearDown(model.dispose);

      // Drafting wall from (0, 0) towards x = 10
      final snap = ArchitectWallSnap.resolve(
        raw: const Offset(9.98, 0.0),
        magnetic: true,
        anchor: Offset.zero,
        project: model.project,
        scale: 40.0,
      );

      expect(snap.isSnapped, isTrue);
      expect(snap.snapLabel, equals('Perpendicular'));
      expect(snap.point.dx, closeTo(10.0, 0.05));
      expect(snap.magneticGuides.length, equals(2));
    });
  });
}
