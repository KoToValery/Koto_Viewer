import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_magnetic_alignment_helper.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_3d_mesh_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StructuralShearWall Model Tests', () {
    test('center and rotationRad getters calculate correctly', () {
      const wall = StructuralShearWall(
        id: 'w1',
        name: 'Ш1',
        start: Offset(2.0, 3.0),
        end: Offset(6.0, 3.0),
        thickness: 0.25,
      );

      expect(wall.center, equals(const Offset(4.0, 3.0)));
      expect(wall.length, closeTo(4.0, 1e-4));
      expect(wall.rotationRad, closeTo(0.0, 1e-4));
      expect(wall.angleRad, equals(wall.rotationRad));
    });

    test('relocating shear wall to new center keeps length and rotation', () {
      const wall = StructuralShearWall(
        id: 'w1',
        name: 'Ш1',
        start: Offset(0.0, 0.0),
        end: Offset(0.0, 3.0), // length 3.0, vertical
        thickness: 0.25,
      );

      final newCenter = const Offset(10.0, 10.0);
      final halfLen = wall.length / 2.0;
      final rot = wall.rotationRad;
      final u = Offset(math.cos(rot), math.sin(rot));
      final updatedWall = wall.copyWith(
        start: newCenter - u * halfLen,
        end: newCenter + u * halfLen,
      );

      expect(updatedWall.center, equals(newCenter));
      expect(updatedWall.length, closeTo(3.0, 1e-4));
      expect(updatedWall.rotationRad, closeTo(math.pi / 2, 1e-4));
      expect(updatedWall.start, equals(const Offset(10.0, 8.5)));
      expect(updatedWall.end, equals(const Offset(10.0, 11.5)));
    });
  });

  group('StructuralMagneticAlignmentHelper Tests', () {
    const axis1 = StructuralGridAxis(
      id: 'a1',
      name: '1',
      start: Offset(0, -10),
      end: Offset(0, 10),
    );
    const axisA = StructuralGridAxis(
      id: 'aA',
      name: 'A',
      start: Offset(-10, 0),
      end: Offset(10, 0),
    );

    final storey = StoreyLevel(
      id: 's1',
      name: 'Floor 1',
      elevation: 0.0,
      height: 3.0,
      gridAxes: const [axis1, axisA],
      columns: const [
        StructuralColumn(
          id: 'col1',
          name: 'К1',
          center: Offset(5.0, 5.0),
          width: 0.30,
          height: 0.30,
        ),
      ],
      shearWalls: const [
        StructuralShearWall(
          id: 'wall1',
          name: 'Ш1',
          start: Offset(8.0, -2.0),
          end: Offset(8.0, 2.0), // vertical wall along x = 8
          thickness: 0.25,
        ),
      ],
      beams: const [],
      slabs: const [],
    );

    test('alignColumn snaps to grid axis intersection when close to (0,0)', () {
      final result = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: const Offset(0.08, 0.06), // ~0.1m away from (0,0)
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      expect(result!.snappedCenter.dx, closeTo(0.0, 1e-3));
      expect(result.snappedCenter.dy, closeTo(0.0, 1e-3));
      expect(result.guideLines.length, greaterThanOrEqualTo(2)); // Both axis guides
    });

    test('alignColumn snaps to single grid axis line', () {
      final result = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: const Offset(0.05, 7.0), // Close to axis 1 at x = 0
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      expect(result!.snappedCenter.dx, closeTo(0.0, 1e-3));
      expect(result.snappedCenter.dy, closeTo(7.0, 1e-3));
    });

    test('alignColumn magnetically aligns to another column X coordinate', () {
      // col1 is at (5.0, 5.0). Placing near x = 5.05, y = 12.0
      final result = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: const Offset(5.05, 12.0),
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      expect(result!.snappedCenter.dx, closeTo(5.0, 1e-3));
      expect(result.snappedCenter.dy, closeTo(12.0, 1e-3));
      expect(result.guideLines.isNotEmpty, isTrue);
    });

    test('alignShearWall snaps to grid axis', () {
      // Placing vertical wall (rotation pi/2) near axis 1 at x = 0.06
      final result = StructuralMagneticAlignmentHelper.alignShearWall(
        rawCenter: const Offset(0.06, 4.0),
        wallLength: 2.0,
        wallThickness: 0.25,
        wallRotationRad: math.pi / 2,
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      expect(result!.snappedCenter.dx, closeTo(0.0, 1e-3));
      expect(result.snappedCenter.dy, closeTo(4.0, 1e-3));
    });

    test('alignShearWall snaps collinear to existing shear wall', () {
      // wall1 is at x = 8.0 from y = -2 to 2. Placing another vertical wall near x = 8.04, y = 6.0
      final result = StructuralMagneticAlignmentHelper.alignShearWall(
        rawCenter: const Offset(8.04, 6.0),
        wallLength: 2.0,
        wallThickness: 0.25,
        wallRotationRad: math.pi / 2,
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      expect(result!.snappedCenter.dx, closeTo(8.0, 1e-3));
      expect(result.snappedCenter.dy, closeTo(6.0, 1e-3));
    });
  });

  group('Structural 3D Mesh Builder - Ceiling Level Positioning', () {
    test('slabs and beams sit at ceiling level (zTop = elevation + storeyHeight)', () {
      final storey = StoreyLevel(
        id: 's1',
        name: 'Floor 1',
        elevation: 0.0,
        height: 3.0,
        columns: const [
          StructuralColumn(
            id: 'c1',
            center: Offset(0, 0),
            width: 0.30,
            height: 0.30,
          ),
        ],
        shearWalls: const [],
        beams: const [
          StructuralBeam(
            id: 'b1',
            start: Offset(0, 0),
            end: Offset(4, 0),
            width: 0.25,
            depth: 0.50,
          ),
        ],
        slabs: const [
          StructuralSlab(
            id: 'sl1',
            thickness: 0.20,
            polygon: [
              Offset(0, 0),
              Offset(4, 0),
              Offset(4, 4),
              Offset(0, 4),
            ],
          ),
        ],
      );

      final project = StructuralProject(
        storeys: [storey],
      );

      final mesh = Structural3dMeshBuilder.buildProjectMesh(project);

      // Verify that triangles are generated
      expect(mesh.triangles.isNotEmpty, isTrue);

      // Find the maximum Z across all triangle vertices
      double maxZ = -double.infinity;
      for (final t in mesh.triangles) {
        maxZ = math.max(maxZ, math.max(t.v0.z, math.max(t.v1.z, t.v2.z)));
      }

      // Column height is 3.0, so the top of the columns and the slab ceiling is at Z = 3.0
      expect(maxZ, closeTo(3.0, 1e-3));

      // Check that slab triangles have top surface at Z = 3.0 (ceiling) and bottom surface at Z = 2.80
      final ceilingTriangles = mesh.triangles.where((t) =>
        (t.v0.z - 3.0).abs() < 1e-3 &&
        (t.v1.z - 3.0).abs() < 1e-3 &&
        (t.v2.z - 3.0).abs() < 1e-3
      ).toList();
      expect(ceilingTriangles.isNotEmpty, isTrue, reason: 'Slab top surface must be at ceiling level Z = 3.0');

      final slabBottomTriangles = mesh.triangles.where((t) =>
        (t.v0.z - 2.80).abs() < 1e-3 &&
        (t.v1.z - 2.80).abs() < 1e-3 &&
        (t.v2.z - 2.80).abs() < 1e-3
      ).toList();
      expect(slabBottomTriangles.isNotEmpty, isTrue, reason: 'Slab bottom surface must be at Z = 2.80 (3.0 - 0.20)');
    });
  });
}
