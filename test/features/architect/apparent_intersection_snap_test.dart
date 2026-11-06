import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_segment_snap.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';

void main() {
  group('Apparent / Extended Intersection Snapping (Въображаемо пресичане)', () {
    test('DxfSegmentSnap.extendedIntersection computes virtual corner and guides', () {
      final s1 = (const Offset(0, 0), const Offset(3, 0));
      final s2 = (const Offset(5, 2), const Offset(5, 6));

      final ext = DxfSegmentSnap.extendedIntersection(s1, s2, maxExtension: 10.0);
      expect(ext, isNotNull);
      expect(ext!.point, const Offset(5, 0));
      // Guide 1 extends s1 from endpoint (3, 0) to (5, 0)
      expect(ext.guide1, isNotNull);
      expect(ext.guide1!.$1, const Offset(3, 0));
      expect(ext.guide1!.$2, const Offset(5, 0));
      // Guide 2 extends s2 from endpoint (5, 2) to (5, 0)
      expect(ext.guide2, isNotNull);
      expect(ext.guide2!.$1, const Offset(5, 2));
      expect(ext.guide2!.$2, const Offset(5, 0));
    });

    test('DxfSegmentSnap.extendedIntersection returns null for parallel lines', () {
      final s1 = (const Offset(0, 0), const Offset(4, 0));
      final s2 = (const Offset(0, 2), const Offset(4, 2));

      final ext = DxfSegmentSnap.extendedIntersection(s1, s2, maxExtension: 25.0);
      expect(ext, isNull);
    });

    test('DxfSegmentSnap.extendedIntersection returns null when segments physically cross', () {
      final s1 = (const Offset(0, 2), const Offset(4, 2));
      final s2 = (const Offset(2, 0), const Offset(2, 4));

      // Physically intersecting segments are handled by intersection(), not extendedIntersection()
      final ext = DxfSegmentSnap.extendedIntersection(s1, s2);
      expect(ext, isNull);

      final realInter = DxfSegmentSnap.intersection(s1, s2);
      expect(realInter, const Offset(2, 2));
    });

    test('DxfSegmentSnap.extendedIntersection returns null when extension exceeds maxExtension', () {
      final s1 = (const Offset(0, 0), const Offset(1, 0));
      final s2 = (const Offset(20, 5), const Offset(20, 10));

      // Intersection at (20, 0) requires extending s1 by 19.0 > 10.0
      final ext = DxfSegmentSnap.extendedIntersection(s1, s2, maxExtension: 10.0);
      expect(ext, isNull);
    });

    test('ArchitectSnapHelper snaps to apparent intersection of two non-intersecting walls', () {
      final wallA = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(3, 0),
        thickness: 0.25,
      );
      final wallB = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(5, 2),
        endPoint: const Offset(5, 6),
        thickness: 0.25,
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [
          ArchitectStorey(
            id: 's1',
            name: 'Storey 1',
            walls: [wallA, wallB],
          ),
        ],
        activeStoreyId: 's1',
      );

      // Query near virtual meeting point (5, 0)
      final snap = ArchitectSnapHelper.snapFree(
        project: project,
        rawPoint: const Offset(5.04, -0.03),
        tolerance: 0.20,
      );

      expect(snap.isSnapped, isTrue);
      expect(snap.snapLabel, 'Apparent intersection');
      expect((snap.point - const Offset(5, 0)).distance, lessThan(0.01));
      expect(snap.magneticGuides, isNotEmpty);
    });

    test('ArchitectWallSnap resolves apparent intersection with priority 1', () {
      final wallA = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(3, 0),
        thickness: 0.25,
      );
      final wallB = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(5, 2),
        endPoint: const Offset(5, 6),
        thickness: 0.25,
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [
          ArchitectStorey(
            id: 's1',
            name: 'Storey 1',
            walls: [wallA, wallB],
          ),
        ],
        activeStoreyId: 's1',
      );

      final snap = ArchitectWallSnap.resolve(
        raw: const Offset(5.02, -0.01),
        project: project,
        scale: 100.0,
        capturePixels: 25.0,
      );

      expect(snap.isSnapped, isTrue);
      expect(snap.snapLabel, 'Apparent intersection');
      expect((snap.point - const Offset(5, 0)).distance, lessThan(0.01));
    });

    test('DxfSnapHelper.findSnapPoint detects apparent intersection with extension guides', () {
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: const {},
        entities: [
          DxfLine(
            p1: const Offset(10, 10),
            p2: const Offset(30, 10),
            layer: '0',
          ),
          DxfLine(
            p1: const Offset(50, 20),
            p2: const Offset(50, 60),
            layer: '0',
          ),
        ],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: const {},
      );

      // Virtual meeting point is (50, 10)
      final snap = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(50.4, 9.7),
        toleranceCad: 1.5,
        includeIntersections: true,
      );

      expect(snap, isNotNull);
      expect(snap!.type, DxfSnapType.apparentIntersection);
      expect((snap.point - const Offset(50, 10)).distance, lessThan(0.01));
      expect(snap.extensionGuides, isNotEmpty);
      expect(snap.extensionGuides.length, 2);
    });
  });
}
