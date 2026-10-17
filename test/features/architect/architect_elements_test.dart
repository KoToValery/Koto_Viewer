import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
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

  group('Constructive Modular Snapping & Opening Clearances Tests', () {
    test('snaps window placement to multiples of wall coreThickness (25/50/150 cm)', () {
      // Wall with 25 cm brick core + 12 cm EPS insulation (total 37 cm)
      const wall = ArchitectWall(
        id: 'w_ext',
        startPoint: Offset(0, 0),
        endPoint: Offset(8, 0),
        thickness: 0.37,
        insulationThicknessOverride: 0.12,
      );
      expect(wall.coreThickness, closeTo(0.25, 1e-6));
      expect(ArchitectOpeningPlacement.modularStepForWall(wall), closeTo(0.25, 1e-6));

      // Place a 1.20 m window near 31 cm from wall start -> snaps left clearance to 25 cm (0.25 m)
      // Left jamb = 0.25 m => center = 0.25 + 0.60 = 0.85 m
      final p25 = ArchitectOpeningPlacement.resolve(
        rawPoint: const Offset(0.91, 0.0),
        walls: [wall],
        openingWidth: 1.20,
      );
      expect(p25, isNotNull);
      expect(p25!.isModularSnap, isTrue);
      expect(p25.clearances.first.isLeft, isTrue);
      expect(p25.clearances.first.distance, closeTo(0.25, 1e-5));
      expect(p25.clearances.first.isModularSnap, isTrue);

      // Place asecond 1.20 m window to the right of the first window ([0.25 .. 1.45]):
      // Suppose cursor aims for ~1.48 m clear distance from first window -> snaps to 1.50 m (150 cm = 6 x 25 cm)
      final wallWithFirst = wall.addWindow(
        ArchitectWindow(
          id: 'win_1',
          wallId: wall.id,
          offsetRatio: p25.offsetRatio,
          width: 1.20,
          uuid: 'u1',
        ),
      );
      // Right jamb of win_1 is at 1.45 m. For 1.50 m clearance, left jamb of win_2 = 2.95 m => center = 3.55 m.
      final p150 = ArchitectOpeningPlacement.resolve(
        rawPoint: const Offset(3.52, 0.0),
        walls: [wallWithFirst],
        openingWidth: 1.20,
      );
      expect(p150, isNotNull);
      expect(p150!.isModularSnap, isTrue);
      final leftToFirstWin = p150.clearances.firstWhere((c) => c.isLeft);
      expect(
        leftToFirstWin.boundaryKind,
        ArchitectOpeningBoundaryKind.neighborOpening,
      );
      expect(leftToFirstWin.referenceElementId, 'win_1');
      expect(leftToFirstWin.distance, closeTo(1.50, 1e-5));
      expect(leftToFirstWin.isModularSnap, isTrue);
    });

    test('computes clearance to intersecting cross wall and edits via SetArchitectOpeningClearance', () {
      const hostWall = ArchitectWall(
        id: 'w_host',
        startPoint: Offset(0, 0),
        endPoint: Offset(8, 0),
        thickness: 0.25,
      );
      // Cross wall at x = 4.0 with 0.25 m thickness (occupies [3.875 .. 4.125] along w_host)
      const crossWall = ArchitectWall(
        id: 'w_cross',
        startPoint: Offset(4, 0),
        endPoint: Offset(4, 4),
        thickness: 0.25,
      );
      final win = const ArchitectWindow(
        id: 'win_edit',
        wallId: 'w_host',
        offsetRatio: 1.10 / 8.0, // center at 1.10 m, width 1.20 m => [0.50 .. 1.70]
        width: 1.20,
        uuid: 'u_edit',
      );
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        elevation: 0,
        height: 3.0,
        walls: [hostWall.addWindow(win), crossWall],
      );
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );

      final clearances = ArchitectOpeningClearance.forOpening(
        wall: storey.walls.first,
        walls: storey.walls,
        openingId: 'win_edit',
        offsetRatio: win.offsetRatio,
        openingWidth: win.width,
      );
      expect(clearances.length, 2);
      final leftGap = clearances.firstWhere((c) => c.isLeft);
      final rightGap = clearances.firstWhere((c) => !c.isLeft);
      expect(leftGap.distance, closeTo(0.50, 1e-4));
      expect(
        rightGap.boundaryKind,
        ArchitectOpeningBoundaryKind.intersectingWall,
      );
      // Right jamb at 1.70 m, cross wall left core face at 4.0 - 0.125 = 3.875 m => distance = 2.175 m
      expect(rightGap.distance, closeTo(2.175, 1e-4));

      // Edit right clearance to cross wall to 0.75 m (75 cm = 3 bricks)
      final controller = ArchitectCommandController(project);
      controller.execute(
        const SetArchitectOpeningClearance(
          storeyId: 's1',
          wallId: 'w_host',
          openingId: 'win_edit',
          isLeft: false,
          distance: 0.75,
        ),
      );
      final updatedWin = controller.project.activeStorey.walls.first.windows.single;
      final updatedClearances = ArchitectOpeningClearance.forOpening(
        wall: controller.project.activeStorey.walls.first,
        walls: controller.project.activeStorey.walls,
        openingId: 'win_edit',
        offsetRatio: updatedWin.offsetRatio,
        openingWidth: updatedWin.width,
      );
      expect(
        updatedClearances.firstWhere((c) => !c.isLeft).distance,
        closeTo(0.75, 1e-4),
      );

      // Undo restores original 0.50 m left clearance
      controller.undo();
      expect(
        controller.project.activeStorey.walls.first.windows.single.offsetRatio,
        closeTo(win.offsetRatio, 1e-6),
      );
    });
  });
}
