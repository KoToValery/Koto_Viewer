import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart' as arch_col;
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';
import 'package:kotoview/src/features/structural_designer/adapters/structural_snap_scene.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  group('Quadrant Snapping (Квадранти)', () {
    test('CAD circle snaps to all 4 cardinal quadrant points and center', () {
      const circle = ArchitectCadPrimitive(
        id: 'c1',
        type: CadPrimitiveType.circle,
        startPoint: Offset(0, 0),
        endPoint: Offset(2, 0), // radius = 2.0
      );
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [
          ArchitectStorey(
            id: 's1',
            name: 'Floor 1',
            cadPrimitives: [circle],
          ),
        ],
        activeStoreyId: 's1',
      );

      // Center
      final centerSnap = ArchitectSnapHelper.snapFree(
        project: project,
        rawPoint: const Offset(0.02, -0.01),
        tolerance: 0.15,
      );
      expect(centerSnap.isSnapped, isTrue);
      expect(centerSnap.snapLabel, 'Center');
      expect((centerSnap.point - Offset.zero).distance, lessThan(1e-9));

      // 4 Quadrants: 0°, 90°, 180°, 270°
      final expectedQuadrants = [
        const Offset(2, 0),
        const Offset(0, 2),
        const Offset(-2, 0),
        const Offset(0, -2),
      ];

      for (final quad in expectedQuadrants) {
        final query = quad + const Offset(0.03, -0.02);
        final snap = ArchitectSnapHelper.snapFree(
          project: project,
          rawPoint: query,
          tolerance: 0.15,
        );
        expect(snap.isSnapped, isTrue);
        expect(snap.snapLabel, 'Quadrant');
        expect((snap.point - quad).distance, lessThan(1e-9));
      }
    });

    test('Circular column in architectural plan provides quadrant snap points', () {
      const col = arch_col.ArchitectColumn(
        id: 'col1',
        position: Offset(5, 5),
        width: 0.50, // diameter = 0.50, radius = 0.25
        depth: 0.50,
        shape: arch_col.ColumnShape.circular,
      );
      final project = ArchitectProject(
        id: 'p2',
        name: 'Column Project',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [
          ArchitectStorey(
            id: 's1',
            name: 'Storey 1',
            columns: [col],
          ),
        ],
        activeStoreyId: 's1',
      );

      // East Quadrant (5.25, 5)
      final snapEast = ArchitectSnapHelper.snapFree(
        project: project,
        rawPoint: const Offset(5.24, 5.01),
        tolerance: 0.10,
      );
      expect(snapEast.isSnapped, isTrue);
      expect(snapEast.snapLabel, 'Quadrant');
      expect((snapEast.point - const Offset(5.25, 5)).distance, lessThan(1e-9));

      // North Quadrant (5, 5.25)
      final snapNorth = ArchitectSnapHelper.snapFree(
        project: project,
        rawPoint: const Offset(4.99, 5.26),
        tolerance: 0.10,
      );
      expect(snapNorth.isSnapped, isTrue);
      expect(snapNorth.snapLabel, 'Quadrant');
      expect((snapNorth.point - const Offset(5, 5.25)).distance, lessThan(1e-9));
    });

    test('Curved wall arc produces quadrant snap for angles within its sweep', () {
      // Arc starting at (2, 0) [0°] to (0, 2) [90°], bulge = tan(90°/4) = tan(22.5°) ~ 0.41421356
      final curvedWall = ArchitectWall(
        id: 'cw1',
        startPoint: const Offset(2, 0),
        endPoint: const Offset(0, 2),
        arcBulge: math.tan(math.pi / 8),
        thickness: 0.25,
      );
      final project = ArchitectProject(
        id: 'p3',
        name: 'Arc Wall Project',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [
          ArchitectStorey(
            id: 's1',
            name: 'Storey 1',
            walls: [curvedWall],
          ),
        ],
        activeStoreyId: 's1',
      );

      final centerSnap = ArchitectSnapHelper.snapFree(
        project: project,
        rawPoint: const Offset(0.01, -0.02),
        tolerance: 0.10,
      );
      expect(centerSnap.isSnapped, isTrue);
      expect(centerSnap.snapLabel, 'Center');
    });

    test('DXF circle landmarks include all 4 quadrants', () {
      final doc = DxfDocument(
        layers: const {},
        blocks: const {},
        headerVars: const {},
        bounds: const Rect.fromLTRB(0, 0, 20, 20),
        entityStats: const {},
        entities: const [
          DxfCircle(
            center: Offset(10, 10),
            radius: 3.0,
          ),
        ],
      );

      // Query near (13, 10) - East quadrant (0°)
      final snapEast = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(13.04, 10.02),
        toleranceCad: 0.20,
      );
      expect(snapEast, isNotNull);
      expect(snapEast!.type, DxfSnapType.quadrant);
      expect((snapEast.point - const Offset(13, 10)).distance, lessThan(1e-9));

      // Query near (10, 13) - North quadrant (90°)
      final snapNorth = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(9.98, 13.03),
        toleranceCad: 0.20,
      );
      expect(snapNorth, isNotNull);
      expect(snapNorth!.type, DxfSnapType.quadrant);
      expect((snapNorth.point - const Offset(10, 13)).distance, lessThan(1e-9));
    });

    test('DXF arc landmarks include quadrants only inside the angular sweep', () {
      // Arc from 45° to 135°, center (0, 0), radius 4.0
      // 90° quadrant (0, 4) is inside; 0°, 180°, 270° are outside
      final doc = DxfDocument(
        layers: const {},
        blocks: const {},
        headerVars: const {},
        bounds: const Rect.fromLTRB(0, 0, 20, 20),
        entityStats: const {},
        entities: const [
          DxfArc(
            center: Offset.zero,
            radius: 4.0,
            startAngleDeg: 45.0,
            endAngleDeg: 135.0,
          ),
        ],
      );

      // Near 90° quadrant (0, 4)
      final snap90 = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(0.03, 3.98),
        toleranceCad: 0.25,
      );
      expect(snap90, isNotNull);
      expect(snap90!.type, DxfSnapType.quadrant);
      expect((snap90.point - const Offset(0, 4)).distance, lessThan(1e-9));

      // Near 0° (4, 0) - outside arc! Should NOT snap to quadrant
      final snap0 = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(3.98, 0.02),
        toleranceCad: 0.25,
      );
      expect(snap0, isNull);
    });

    test('Structural designer circular column provides quadrant landmarks', () {
      const structCol = StructuralColumn(
        id: 'sc1',
        center: Offset(20, 20),
        width: 0.60, // diameter 0.60 -> r = 0.30
        shape: ColumnShape.circular,
      );
      const structProject = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'st1',
            name: 'Storey 1',
            columns: [structCol],
          ),
        ],
      );

      final scene = StructuralSnapScene.of(structProject, 1.0);
      final features = scene.query(const Offset(20.30, 20.0), 0.05).toList();

      expect(features.any((f) => f.kind.name == 'quadrant'), isTrue);
    });
  });
}
