import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'architect_editing_test.dart' as editing;

void main() {
  group('ArchitectWallSnap - Intersecting Axis snapping', () {
    test('Perpendicular wall snap catches intersecting grid axis crossing', () {
      // Setup grid axis X = 3 (vertical line from (3, -10) to (3, 10))
      final axis = const StructuralGridAxis(
        id: 'A1',
        name: 'A',
        start: Offset(3, -10),
        end: Offset(3, 10),
      );
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: 's'),
        axes: [axis],
      );
      addTearDown(model.dispose);

      // Wall starting at (0, 0) drawing horizontally towards (3, 0)
      // When cursor is near (2.95, 0.05), it should snap to the axis crossing (3, 0)
      final snap = ArchitectWallSnap.resolve(
        raw: const Offset(2.95, 0.05),
        anchor: const Offset(0, 0),
        project: model.project,
        scale: 100,
      );

      expect(snap.isSnapped, isTrue);
      expect((snap.point - const Offset(3, 0)).distance, lessThan(1e-4));
    });

    test('ArchitectSnapHelper ortho guide catches intersecting axis', () {
      final axis = const StructuralGridAxis(
        id: 'A1',
        name: 'A',
        start: Offset(4, -10),
        end: Offset(4, 10),
      );
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: 's'),
        axes: [axis],
      );
      addTearDown(model.dispose);

      // Snap element starting from anchor (0, 0)
      final snap = ArchitectSnapHelper.snapWithAnchor(
        anchor: const Offset(0, 0),
        rawPoint: const Offset(3.92, 0.04),
        project: model.project,
        tolerance: 0.20,
      );

      expect(snap.isSnapped, isTrue);
      expect((snap.point - const Offset(4, 0)).distance, lessThan(1e-4));
    });
  });
}
