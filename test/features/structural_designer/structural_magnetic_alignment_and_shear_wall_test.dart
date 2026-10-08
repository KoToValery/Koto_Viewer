import 'dart:math' as math;
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

    test('alignColumn snaps 2-DOF simultaneously: X to grid axis and Y to perpendicular column', () {
      // axis1 is at x = 0. col1 is at (5.0, 5.0).
      // Placing near x = 0.05, y = 5.04.
      // Under 2-DOF solver, X snaps to axis1 (0.0) and Y snaps to col1 (5.0).
      final result = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: const Offset(0.05, 5.04),
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      expect(result!.snappedCenter.dx, closeTo(0.0, 1e-3));
      expect(result.snappedCenter.dy, closeTo(5.0, 1e-3));
      expect(result.description, 'gridAxisAndColumn');
      expect(result.guideLines.length, 2);
    });

    test('alignColumn aligns flush left face with another column', () {
      // col1 is at (5.0, 5.0), width=0.30 -> left face is at x = 4.85
      // Placing new column with width=0.50 near left face (x_center ~ 4.85 + 0.25 = 5.10, y = 15.0)
      final result = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: const Offset(5.12, 15.0),
        columnWidth: 0.50,
        columnHeight: 0.50,
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      // Left face of new column (result.dx - 0.25) should equal 4.85
      expect(result!.snappedCenter.dx - 0.25, closeTo(4.85, 1e-3));
    });

    test('alignShearWall snaps end to perpendicular cross axis (T-junction)', () {
      // axis1 is at x = 0, axisA is at y = 0.
      // Placing vertical wall (length=2.0) parallel to axis1 (x ~ 0.05) with bottom end near axisA (center y ~ 1.05)
      // When snapped, bottom end touches y = 0, so center snaps to y = 1.0!
      final result = StructuralMagneticAlignmentHelper.alignShearWall(
        rawCenter: const Offset(0.05, 1.06),
        wallLength: 2.0,
        wallThickness: 0.25,
        wallRotationRad: math.pi / 2,
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      expect(result!.snappedCenter.dx, closeTo(0.0, 1e-3));
      expect(result.snappedCenter.dy, closeTo(1.0, 1e-3));
      expect(result.description, 'gridAxisAndCrossAxis');
    });

    test('StructuralShearWall referenceLine leftFace and rightFace calculate vertices properly', () {
      const wallCenter = StructuralShearWall(
        id: 'w_c',
        start: Offset(0, 0),
        end: Offset(4, 0),
        thickness: 0.25,
        referenceLine: ShearWallReferenceLine.center,
      );
      const wallLeft = StructuralShearWall(
        id: 'w_l',
        start: Offset(0, 0),
        end: Offset(4, 0),
        thickness: 0.25,
        referenceLine: ShearWallReferenceLine.leftFace,
      );

      expect(wallCenter.polygonVertices[0].dy, closeTo(0.125, 1e-4));
      expect(wallCenter.polygonVertices[2].dy, closeTo(-0.125, 1e-4));

      // Left face: baseline (y=0) is one edge, other edge is at y = -0.25 (normal pointing -Y)
      expect(wallLeft.polygonVertices[0].dy, closeTo(0.0, 1e-4));
      expect(wallLeft.polygonVertices[2].dy, closeTo(-0.25, 1e-4));
    });

    test('alignColumn with lockX locks X to anchorCenter and only moves/snaps along Y', () {
      const anchor = Offset(5.0, 5.0);
      const rawCenter = Offset(8.5, 9.95);
      final result = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: rawCenter,
        anchorCenter: anchor,
        axisLockMode: StructuralAxisLockMode.lockX,
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      expect(result!.snappedCenter.dx, closeTo(5.0, 1e-4));
      expect(result.snappedCenter.dy, closeTo(9.95, 1e-2));
    });

    test('alignColumn with lockY locks Y to anchorCenter and only moves/snaps along X', () {
      const anchor = Offset(5.0, 5.0);
      const rawCenter = Offset(0.04, 8.5);
      final result = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: rawCenter,
        anchorCenter: anchor,
        axisLockMode: StructuralAxisLockMode.lockY,
        toleranceCad: 0.20,
        activeStorey: storey,
      );

      expect(result, isNotNull);
      expect(result!.snappedCenter.dy, closeTo(5.0, 1e-4));
      expect(result.snappedCenter.dx, closeTo(0.0, 1e-3));
    });

    test('alignColumn snaps to Equal Spacing between two existing columns', () {
      final multiColStorey = StoreyLevel(
        id: 's2',
        name: 'Floor 1',
        elevation: 0.0,
        height: 3.0,
        columns: const [
          StructuralColumn(id: 'c1', name: 'К1', center: Offset(0.0, 2.0), width: 0.40, height: 0.40),
          StructuralColumn(id: 'c2', name: 'К2', center: Offset(6.0, 2.0), width: 0.40, height: 0.40),
        ],
        shearWalls: const [],
        beams: const [],
        slabs: const [],
      );

      final result = StructuralMagneticAlignmentHelper.alignColumn(
        rawCenter: const Offset(3.05, 2.0),
        toleranceCad: 0.25,
        activeStorey: multiColStorey,
      );

      expect(result, isNotNull);
      expect(result!.description, 'equalSpacing');
      expect(result.snappedCenter.dx, closeTo(3.0, 1e-3));
      expect(result.snappedCenter.dy, closeTo(2.0, 1e-3));
      expect(result.liveDimensionText, isNotNull);
      expect(result.liveDimensionText, contains('='));
    });
  });

  group('NeighborClearDistance & Face-to-Face Calculations', () {
    final corridorStorey = StoreyLevel(
      id: 's_corr',
      name: 'Corridor',
      elevation: 0.0,
      height: 3.0,
      columns: const [
        StructuralColumn(id: 'c_left', name: 'К1', center: Offset(0.0, 0.0), width: 0.40, height: 0.40),
        StructuralColumn(id: 'c_mid', name: 'К2', center: Offset(4.0, 0.0), width: 0.40, height: 0.40),
        StructuralColumn(id: 'c_right', name: 'К3', center: Offset(10.0, 0.0), width: 0.40, height: 0.40),
      ],
      shearWalls: const [],
      beams: const [],
      slabs: const [],
    );

    test('findNeighborClearDistances finds adjacent left and right columns with correct clear distance', () {
      final neighbors = StructuralMagneticAlignmentHelper.findNeighborClearDistances(
        center: const Offset(4.0, 0.0),
        width: 0.40,
        height: 0.40,
        activeStorey: corridorStorey,
        currentElementId: 'c_mid',
        cadUnitsPerMeter: 1.0,
      );

      expect(neighbors.length, 2);
      final left = neighbors.firstWhere((n) => n.direction == 'left');
      final right = neighbors.firstWhere((n) => n.direction == 'right');

      expect(left.currentClearDistanceM, closeTo(3.60, 1e-3));
      expect(left.neighborName, 'К1');

      expect(right.currentClearDistanceM, closeTo(5.60, 1e-3));
      expect(right.neighborName, 'К3');
    });

    test('computeDeltaCad adjusts element position accurately', () {
      const left = NeighborClearDistance(
        direction: 'left',
        neighborName: 'К1',
        currentClearDistanceM: 3.60,
        neighborFacePoint: Offset(0.20, 0.0),
        ourFacePoint: Offset(3.80, 0.0),
        isHorizontal: true,
        sign: 1.0,
      );

      final deltaLeft = left.computeDeltaCad(targetClearDistanceM: 4.00, cadUnitsPerMeter: 1.0);
      expect(deltaLeft.dx, closeTo(0.40, 1e-4));
      expect(deltaLeft.dy, closeTo(0.0, 1e-4));

      const right = NeighborClearDistance(
        direction: 'right',
        neighborName: 'К3',
        currentClearDistanceM: 5.60,
        neighborFacePoint: Offset(9.80, 0.0),
        ourFacePoint: Offset(4.20, 0.0),
        isHorizontal: true,
        sign: -1.0,
      );

      final deltaRight = right.computeDeltaCad(targetClearDistanceM: 5.00, cadUnitsPerMeter: 1.0);
      expect(deltaRight.dx, closeTo(0.60, 1e-4));
      expect(deltaRight.dy, closeTo(0.0, 1e-4));
    });
  });

  group('Structural 3D Mesh Builder - Storey Slab Level Positioning', () {
    test('floor slabs sit at storey level elevation and form the ceiling for the storey below', () {
      final storey1 = StoreyLevel(
        id: 's1',
        name: 'Floor 1',
        elevation: 0.0,
        floorFinishThickness: 0.0,
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

      final storey2 = StoreyLevel(
        id: 's2',
        name: 'Floor 2',
        elevation: 3.0,
        floorFinishThickness: 0.0,
        height: 3.0,
        slabs: const [
          StructuralSlab(
            id: 'sl2',
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
        storeys: [storey1, storey2],
      );

      final mesh = Structural3dMeshBuilder.buildProjectMesh(project);

      // Verify that triangles are generated
      expect(mesh.triangles.isNotEmpty, isTrue);

      // Storey 1 floor slab: top surface at Z = 0.0, soffit at Z = -0.20
      final s1FloorTriangles = mesh.triangles.where((t) =>
        (t.v0.z - 0.0).abs() < 1e-3 &&
        (t.v1.z - 0.0).abs() < 1e-3 &&
        (t.v2.z - 0.0).abs() < 1e-3
      ).toList();
      expect(s1FloorTriangles.isNotEmpty, isTrue, reason: 'Storey 1 floor slab top surface must be at Z = 0.0');

      final s1SoffitTriangles = mesh.triangles.where((t) =>
        (t.v0.z - (-0.20)).abs() < 1e-3 &&
        (t.v1.z - (-0.20)).abs() < 1e-3 &&
        (t.v2.z - (-0.20)).abs() < 1e-3
      ).toList();
      expect(s1SoffitTriangles.isNotEmpty, isTrue, reason: 'Storey 1 floor slab soffit must be at Z = -0.20');

      // Storey 2 slab (ceiling above Storey 1): top surface at Z = 3.0, soffit at Z = 2.80
      final s2CeilingTriangles = mesh.triangles.where((t) =>
        (t.v0.z - 3.0).abs() < 1e-3 &&
        (t.v1.z - 3.0).abs() < 1e-3 &&
        (t.v2.z - 3.0).abs() < 1e-3
      ).toList();
      expect(s2CeilingTriangles.isNotEmpty, isTrue, reason: 'Storey 2 slab top surface must be at Z = 3.0');

      final s2SoffitTriangles = mesh.triangles.where((t) =>
        (t.v0.z - 2.80).abs() < 1e-3 &&
        (t.v1.z - 2.80).abs() < 1e-3 &&
        (t.v2.z - 2.80).abs() < 1e-3
      ).toList();
      expect(s2SoffitTriangles.isNotEmpty, isTrue, reason: 'Storey 2 slab soffit must be at Z = 2.80');
    });
  });
}
