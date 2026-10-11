import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';

void main() {
  group('BimProjectType & Architectural Manifest Tests', () {
    test('BimWorkProject correctly serializes and deserializes architectural type', () {
      final project = BimWorkProject(
        id: 'proj_arch_1',
        name: 'Apartment Building Arch',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        projectType: BimProjectType.architectural,
      );

      final json = project.toJson();
      expect(json['projectType'], 'architectural');
      expect(project.isArchitectural, isTrue);
      expect(project.isStructural, isFalse);
      expect(project.hasUnderlays, isFalse);

      final restored = BimWorkProject.fromJson(json);
      expect(restored.projectType, BimProjectType.architectural);
      expect(restored.isArchitectural, isTrue);
    });

    test('BimWorkProject defaults to structural for backward compatibility', () {
      final json = {
        'id': 'legacy_1',
        'name': 'Legacy Structural Project',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        // No 'projectType' in legacy manifests
      };

      final restored = BimWorkProject.fromJson(json);
      expect(restored.projectType, BimProjectType.structural);
      expect(restored.isStructural, isTrue);
      expect(restored.isArchitectural, isFalse);
    });
  });

  group('Architectural Elements Geometry & 3D Solid Tests', () {
    test('ArchitectColumn rectangular & circular geometry and 3D generation', () {
      final rectCol = ArchitectColumn(
        id: 'col_rect_1',
        position: const Offset(5.0, 5.0),
        shape: ColumnShape.rectangular,
        width: 0.40,
        depth: 0.40,
      );

      expect(rectCol.containsPoint(const Offset(5.1, 5.1)), isTrue);
      expect(rectCol.containsPoint(const Offset(6.0, 6.0)), isFalse);

      final rectTris = rectCol.build3D(storeyElevation: 0.0, storeyHeight: 3.0);
      expect(rectTris.isNotEmpty, isTrue);
      expect(rectTris.length, 12); // 2 per face * 6 faces

      final circCol = ArchitectColumn(
        id: 'col_circ_1',
        position: const Offset(10.0, 10.0),
        shape: ColumnShape.circular,
        width: 0.50,
      );

      expect(circCol.containsPoint(const Offset(10.15, 10.15)), isTrue);
      expect(circCol.containsPoint(const Offset(11.0, 10.0)), isFalse);

      final circTris = circCol.build3D(storeyElevation: 0.0, storeyHeight: 3.0);
      expect(circTris.isNotEmpty, isTrue);
    });

    test('ArchitectWindow hosted on wall and 3D frame generation', () {
      final wall = ArchitectWall(
        id: 'wall_1',
        startPoint: const Offset(0.0, 0.0),
        endPoint: const Offset(6.0, 0.0),
        thickness: 0.25,
      );

      final window = ArchitectWindow(
        id: 'win_1',
        wallId: wall.id,
        offsetRatio: 0.50, // Center of wall (at x=3.0)
        width: 1.40,
        height: 1.50,
        sillHeight: 0.85,
        uuid: 'uuid_win_1',
      );

      final tris = window.build3D(
        wallStart: wall.startPoint,
        wallEnd: wall.endPoint,
        wallThickness: wall.thickness,
        storeyElevation: 0.0,
      );
      expect(tris.isNotEmpty, isTrue);
    });

    test('ArchitectBeam, Slab, and Opening serialization and math', () {
      final beam = ArchitectBeam(
        id: 'bm_1',
        startPoint: const Offset(0.0, 0.0),
        endPoint: const Offset(4.0, 0.0),
        width: 0.25,
        depth: 0.50,
      );
      expect(beam.length, closeTo(4.0, 1e-4));
      expect(beam.polygonCorners.length, 4);

      final slab = ArchitectSlab(
        id: 'sl_1',
        polygon: [
          const Offset(0.0, 0.0),
          const Offset(5.0, 0.0),
          const Offset(5.0, 5.0),
          const Offset(0.0, 5.0),
        ],
        thickness: 0.20,
      );
      expect(slab.area, closeTo(25.0, 1e-4));

      final opening = ArchitectOpening(
        id: 'op_1',
        boundary: [
          const Offset(1.0, 1.0),
          const Offset(2.0, 1.0),
          const Offset(2.0, 2.0),
          const Offset(1.0, 2.0),
        ],
        type: OpeningType.shaft,
      );
      expect(opening.boundary.length, 4);
    });
  });

  group('ArchitectElementTool Interactive Controller Tests', () {
    late ArchitectElementTool tool;
    late ArchitectStorey initialStorey;

    setUp(() {
      tool = ArchitectElementTool();
      initialStorey = ArchitectStorey(
        id: 'storey_1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 3.0,
        walls: [
          const ArchitectWall(
            id: 'w1',
            startPoint: Offset(0, 0),
            endPoint: Offset(10, 0),
            thickness: 0.25,
          ),
        ],
      );
    });

    test('placeColumn and hit test', () {
      final (updatedStorey, col) = tool.placeColumn(
        storey: initialStorey,
        point: const Offset(2.0, 4.0),
      );

      expect(updatedStorey.columns.length, 1);
      expect(updatedStorey.columns.first.id, col.id);

      final hitId = tool.hitTestElement(
        updatedStorey,
        const Offset(2.05, 4.05),
        20.0,
      );
      expect(hitId, col.id);
    });

    test('placeWindow on host wall and hit test', () {
      final res = tool.placeWindow(
        storey: initialStorey,
        point: const Offset(5.0, 0.05),
      );

      expect(res, isNotNull);
      final (updatedStorey, win) = res!;
      expect(updatedStorey.walls.first.windows.length, 1);
      expect(updatedStorey.walls.first.windows.first.id, win.id);

      final hitId = tool.hitTestElement(
        updatedStorey,
        const Offset(5.0, 0.0),
        20.0,
      );
      expect(hitId, win.id);
    });

    test('placeBeam, placeStair, and placeDimension', () {
      final beamRes = tool.placeBeam(
        storey: initialStorey,
        start: const Offset(0, 2),
        end: const Offset(4, 2),
      );
      expect(beamRes, isNotNull);
      var s = beamRes!.$1;
      expect(s.beams.length, 1);

      final stairRes = tool.placeStair(
        storey: s,
        start: const Offset(1, 1),
        end: const Offset(1, 4),
      );
      expect(stairRes, isNotNull);
      s = stairRes!.$1;
      expect(s.stairs.length, 1);

      final dimRes = tool.placeDimension(
        storey: s,
        start: const Offset(0, 0),
        end: const Offset(10, 0),
      );
      expect(dimRes, isNotNull);
      s = dimRes!.$1;
      expect(s.dimensions.length, 1);
    });

    test('deleteElementById removes selected element correctly', () {
      final (s1, col) = tool.placeColumn(
        storey: initialStorey,
        point: const Offset(2.0, 4.0),
      );
      expect(s1.columns.length, 1);

      final s2 = tool.deleteElementById(s1, col.id);
      expect(s2.columns.isEmpty, isTrue);
    });

    test('Slab drafting workflow adds polygon points and finalizes closed slab', () {
      tool.addSlabPoint(const Offset(0, 0));
      tool.addSlabPoint(const Offset(4, 0));
      tool.addSlabPoint(const Offset(4, 4));
      tool.addSlabPoint(const Offset(0, 4));
      expect(tool.slabDraftPoints.length, 4);

      final res = tool.commitSlab(storey: initialStorey);
      expect(res, isNotNull);
      expect(res!.$1.slabs.length, 1);
      expect(res.$1.slabs.first.polygon.length, 4);
      expect(tool.slabDraftPoints.isEmpty, isTrue);
    });
  });
}
