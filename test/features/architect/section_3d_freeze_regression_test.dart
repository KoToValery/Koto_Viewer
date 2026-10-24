import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_solid_shell.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_junctions.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';

void main() {
  group('Section and 3D Roof Freeze Regression Tests', () {
    test('ArchitectSolidShell handles many overlapping coplanar faces without explosion', () {
      final solidA = <Triangle3D>[];
      final solidB = <Triangle3D>[];
      for (var i = 0; i < 20; i++) {
        final x = i * 0.5;
        solidA.add(Triangle3D(
          v0: Vector3(x, 0, 3.0),
          v1: Vector3(x + 1.0, 0, 3.0),
          v2: Vector3(x + 0.5, 1.0, 3.0),
        ));
        solidB.add(Triangle3D(
          v0: Vector3(x, 0, 3.0),
          v1: Vector3(x + 0.5, 1.0, 3.0),
          v2: Vector3(x + 1.0, 0, 3.0),
        ));
      }
      final sw = Stopwatch()..start();
      final shell = ArchitectSolidShell.build([solidA, solidB]);
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(shell.length, 2);
    });

    test('ArchitectRoofJunctions resolves intersecting roofs without cycle or infinite loop', () {
      final roofA = ArchitectRoofPlane(
        id: 'rA',
        storeyId: 's1',
        roofGroupId: 'grp1',
        points: const [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 5),
          Offset(0, 5),
        ],
        slopeDegrees: 30,
        eavesEdgeIndex: 0,
      );
      final roofB = ArchitectRoofPlane(
        id: 'rB',
        storeyId: 's1',
        roofGroupId: 'grp1',
        points: const [
          Offset(0, 3),
          Offset(10, 3),
          Offset(10, 8),
          Offset(0, 8),
        ],
        slopeDegrees: 30,
        eavesEdgeIndex: 2,
      );
      final sw = Stopwatch()..start();
      final junctions = ArchitectRoofJunctions.resolve([roofA, roofB]);
      expect(sw.elapsedMilliseconds, lessThan(1000));
      expect(junctions.footprints.containsKey('rA'), isTrue);
      expect(junctions.footprints.containsKey('rB'), isTrue);
    });

    test('Architect3dBuilder and ArchitectBuildingSection build project with joined roofs in under 2 seconds', () {
      final wall1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.38,
      );
      final wall2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(10, 0),
        endPoint: const Offset(10, 8),
        thickness: 0.38,
      );
      final wall3 = ArchitectWall(
        id: 'w3',
        startPoint: const Offset(10, 8),
        endPoint: const Offset(0, 8),
        thickness: 0.38,
      );
      final wall4 = ArchitectWall(
        id: 'w4',
        startPoint: const Offset(0, 8),
        endPoint: const Offset(0, 0),
        thickness: 0.38,
      );

      final storey = ArchitectStorey(
        id: 'ground_floor',
        name: 'Ground Floor',
        elevation: 0.0,
        height: 2.8,
        walls: [wall1, wall2, wall3, wall4],
      );

      final roof1 = ArchitectRoofPlane(
        id: 'rf1',
        storeyId: 'roof_floor',
        roofGroupId: 'main_roof',
        points: const [
          Offset(-0.5, -0.5),
          Offset(10.5, -0.5),
          Offset(10.5, 4.0),
          Offset(-0.5, 4.0),
        ],
        slopeDegrees: 25,
        eavesEdgeIndex: 0,
      );
      final roof2 = ArchitectRoofPlane(
        id: 'rf2',
        storeyId: 'roof_floor',
        roofGroupId: 'main_roof',
        points: const [
          Offset(-0.5, 4.0),
          Offset(10.5, 4.0),
          Offset(10.5, 8.5),
          Offset(-0.5, 8.5),
        ],
        slopeDegrees: 25,
        eavesEdgeIndex: 2,
      );

      final roofStorey = ArchitectStorey(
        id: 'roof_floor',
        name: 'Roof',
        elevation: 2.8,
        height: 2.5,
        roofs: [roof1, roof2],
      );

      final section = ArchitectSection(
        id: 'sec_1',
        start: const Offset(-2, 4),
        end: const Offset(12, 4),
      );

      final now = DateTime.now();
      final project = ArchitectProject(
        id: 'test_project',
        name: 'Test Project',
        createdAt: now,
        updatedAt: now,
        storeys: [storey, roofStorey],
        activeStoreyId: 'ground_floor',
        sections: [section],
      );

      // 1. Build 3D mesh - must be fast and produce valid triangles
      final sw3d = Stopwatch()..start();
      final mesh = Architect3dBuilder.buildProjectMesh(project);
      expect(sw3d.elapsedMilliseconds, lessThan(2000));
      expect(mesh.triangles.isNotEmpty, isTrue);

      // 2. Build Section - must be fast and produce section regions
      final swSec = Stopwatch()..start();
      final secDrawing = ArchitectBuildingSection.build(project, section);
      expect(swSec.elapsedMilliseconds, lessThan(2000));
      expect(secDrawing.regions.isNotEmpty, isTrue);
    });
  });
}
