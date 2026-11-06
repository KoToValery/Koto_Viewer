import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';

void main() {
  group('ArchitectStoreyCopyService', () {
    late ArchitectProject testProject;

    setUp(() {
      final wall1 = ArchitectWall(
        id: 'wall_1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        height: 2.80,
        followStoreyHeight: true,
        doors: const [
          ArchitectDoor(
            id: 'door_1',
            wallId: 'wall_1',
            uuid: 'uuid_d1',
            offsetRatio: 0.33,
            width: 0.90,
            height: 2.05,
          ),
        ],
        windows: const [
          ArchitectWindow(
            id: 'win_1',
            wallId: 'wall_1',
            uuid: 'uuid_w1',
            offsetRatio: 0.66,
            width: 1.40,
            height: 1.50,
          ),
        ],
      );

      final wall2Parapet = const ArchitectWall(
        id: 'wall_parapet',
        startPoint: Offset(6, 0),
        endPoint: Offset(6, 4),
        height: 1.10,
        followStoreyHeight: false,
      );

      final col1 = const ArchitectColumn(
        id: 'col_1',
        position: Offset(0, 0),
        width: 0.30,
        depth: 0.30,
        height: 2.80,
      );

      final slab1 = const ArchitectSlab(
        id: 'slab_1',
        polygon: [
          Offset(0, 0),
          Offset(6, 0),
          Offset(6, 4),
          Offset(0, 4),
        ],
        thickness: 0.20,
      );

      final zone1 = const ArchitectZone(
        id: 'zone_1',
        name: 'Дневна с трапезария',
        category: ArchitectZoneCategory.living,
        polygon: [
          Offset(0, 0),
          Offset(6, 0),
          Offset(6, 4),
          Offset(0, 4),
        ],
      );

      final marker1 = const ArchitectElevationMarker(
        id: 'marker_1',
        position: Offset(3, 2),
        elevation: 0.00,
      );

      final group1 = const ArchitectElementGroup(
        id: 'grp_1',
        elementIds: {'wall_1', 'col_1'},
      );

      final storey1 = ArchitectStorey(
        id: 'storey_1',
        name: 'Етаж 1 (Кота ±0.00)',
        elevation: 0.00,
        height: 2.80,
        walls: [wall1, wall2Parapet],
        columns: [col1],
        slabs: [slab1],
        zones: [zone1],
        elevationMarkers: [marker1],
        groups: [group1],
      );

      final storey2 = const ArchitectStorey(
        id: 'storey_2',
        name: 'Етаж 2 (Кота +2.80)',
        elevation: 2.80,
        height: 3.20, // Different height to test height adaptation!
      );

      final storey3 = const ArchitectStorey(
        id: 'storey_3',
        name: 'Етаж 3 (Кота +6.00)',
        elevation: 6.00,
        height: 2.80,
      );

      testProject = ArchitectProject(
        id: 'test_proj',
        name: 'Тестова сграда',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeys: [storey1, storey2, storey3],
        activeStoreyId: 'storey_1',
      );
    });

    test('copies full typical floor layout across multiple target storeys', () {
      final options = const StoreyCopyOptions(
        sourceStoreyId: 'storey_1',
        targetStoreyIds: {'storey_2', 'storey_3'},
        mode: StoreyCopyMode.replace,
        adjustWallHeights: true,
        adjustLevelMarkers: true,
        preserveGroups: true,
      );

      final (updatedProject, result) =
          ArchitectStoreyCopyService.copyElements(testProject, options);

      expect(result.targetStoreyCount, 2);
      expect(result.totalCopied, greaterThan(0));

      final s2 = updatedProject.storeys.firstWhere((s) => s.id == 'storey_2');
      final s3 = updatedProject.storeys.firstWhere((s) => s.id == 'storey_3');

      // Check Storey 2
      expect(s2.walls.length, 2);
      expect(s2.columns.length, 1);
      expect(s2.slabs.length, 1);
      expect(s2.zones.length, 1);
      expect(s2.elevationMarkers.length, 1);

      // Check IDs are brand new
      expect(s2.walls.first.id, isNot('wall_1'));
      expect(s2.columns.first.id, isNot('col_1'));
      expect(s2.slabs.first.id, isNot('slab_1'));
      expect(s2.zones.first.id, isNot('zone_1'));

      // Check hosted door & window remapping to new wall ID
      final copiedWall1 = s2.walls.firstWhere((w) => w.doors.isNotEmpty);
      expect(copiedWall1.doors.length, 1);
      expect(copiedWall1.windows.length, 1);
      expect(copiedWall1.doors.first.wallId, copiedWall1.id);
      expect(copiedWall1.windows.first.wallId, copiedWall1.id);
      expect(copiedWall1.doors.first.id, isNot('door_1'));
      expect(copiedWall1.windows.first.id, isNot('win_1'));

      // Check Storey 3
      expect(s3.walls.length, 2);
      expect(s3.columns.length, 1);
      expect(s3.slabs.length, 1);
    });

    test('wall height adapts when followStoreyHeight is true and target height differs', () {
      final options = const StoreyCopyOptions(
        sourceStoreyId: 'storey_1',
        targetStoreyIds: {'storey_2'},
        mode: StoreyCopyMode.replace,
        adjustWallHeights: true,
      );

      final (updatedProject, _) =
          ArchitectStoreyCopyService.copyElements(testProject, options);

      final s2 = updatedProject.storeys.firstWhere((s) => s.id == 'storey_2');

      // Wall 1 had followStoreyHeight: true, so height should match storey_2 (3.20m)
      final wall1Copy = s2.walls.firstWhere((w) => w.followStoreyHeight);
      expect(wall1Copy.height, 3.20);

      // Parapet wall had followStoreyHeight: false, so height should stay 1.10m
      final parapetCopy = s2.walls.firstWhere((w) => !w.followStoreyHeight);
      expect(parapetCopy.height, 1.10);
    });

    test('elevation markers shift by delta Z to reflect target storey elevation', () {
      final options = const StoreyCopyOptions(
        sourceStoreyId: 'storey_1',
        targetStoreyIds: {'storey_2', 'storey_3'},
        adjustLevelMarkers: true,
      );

      final (updatedProject, _) =
          ArchitectStoreyCopyService.copyElements(testProject, options);

      final s2 = updatedProject.storeys.firstWhere((s) => s.id == 'storey_2');
      final s3 = updatedProject.storeys.firstWhere((s) => s.id == 'storey_3');

      // Source marker was 0.00 on storey 0.00
      // Target 2 elevation is 2.80 -> marker should be 2.80
      expect(s2.elevationMarkers.single.elevation, 2.80);

      // Target 3 elevation is 6.00 -> marker should be 6.00
      expect(s3.elevationMarkers.single.elevation, 6.00);
    });

    test('element groups are preserved with mapped member IDs', () {
      final options = const StoreyCopyOptions(
        sourceStoreyId: 'storey_1',
        targetStoreyIds: {'storey_2'},
        preserveGroups: true,
      );

      final (updatedProject, _) =
          ArchitectStoreyCopyService.copyElements(testProject, options);

      final s2 = updatedProject.storeys.firstWhere((s) => s.id == 'storey_2');
      expect(s2.groups.length, 1);
      final clonedGroup = s2.groups.first;
      expect(clonedGroup.id, isNot('grp_1'));

      // Members must match the new cloned wall and column IDs
      final newWallId = s2.walls.firstWhere((w) => w.followStoreyHeight).id;
      final newColId = s2.columns.first.id;
      expect(clonedGroup.elementIds, containsAll([newWallId, newColId]));
    });

    test('selective copying transfers only requested element IDs', () {
      final options = const StoreyCopyOptions(
        sourceStoreyId: 'storey_1',
        targetStoreyIds: {'storey_2'},
        selectedElementIds: {'col_1'}, // Only column, no walls or slabs
      );

      final (updatedProject, _) =
          ArchitectStoreyCopyService.copyElements(testProject, options);

      final s2 = updatedProject.storeys.firstWhere((s) => s.id == 'storey_2');
      expect(s2.columns.length, 1);
      expect(s2.walls, isEmpty);
      expect(s2.slabs, isEmpty);
      expect(s2.zones, isEmpty);
    });

    test('replace mode clears existing category elements; merge mode appends', () {
      // Give storey_2 an existing column and wall
      final oldStorey2 = testProject.storeys
          .firstWhere((s) => s.id == 'storey_2')
          .copyWith(
            columns: const [
              ArchitectColumn(
                id: 'old_col',
                position: Offset(10, 10),
                width: 0.40,
                depth: 0.40,
              ),
            ],
            walls: const [
              ArchitectWall(
                id: 'old_wall',
                startPoint: Offset(10, 10),
                endPoint: Offset(12, 10),
              ),
            ],
          );

      final projWithExisting = testProject.copyWith(
        storeys: [
          testProject.storeys[0],
          oldStorey2,
          testProject.storeys[2],
        ],
      );

      // 1. Replace mode with walls only
      final replaceOptions = const StoreyCopyOptions(
        sourceStoreyId: 'storey_1',
        targetStoreyIds: {'storey_2'},
        elementTypes: {ArchitectStoreyElementType.walls},
        mode: StoreyCopyMode.replace,
      );

      final (afterReplace, _) = ArchitectStoreyCopyService.copyElements(
        projWithExisting,
        replaceOptions,
      );
      final s2Replaced = afterReplace.storeys.firstWhere((s) => s.id == 'storey_2');
      // old_wall was replaced with 2 cloned walls
      expect(s2Replaced.walls.any((w) => w.id == 'old_wall'), isFalse);
      expect(s2Replaced.walls.length, 2);
      // columns was NOT in elementTypes, so old_col remains!
      expect(s2Replaced.columns.any((c) => c.id == 'old_col'), isTrue);

      // 2. Merge mode
      final mergeOptions = const StoreyCopyOptions(
        sourceStoreyId: 'storey_1',
        targetStoreyIds: {'storey_2'},
        elementTypes: {ArchitectStoreyElementType.walls},
        mode: StoreyCopyMode.merge,
      );

      final (afterMerge, _) = ArchitectStoreyCopyService.copyElements(
        projWithExisting,
        mergeOptions,
      );
      final s2Merged = afterMerge.storeys.firstWhere((s) => s.id == 'storey_2');
      // old_wall is still present, plus 2 cloned walls -> 3 walls total
      expect(s2Merged.walls.any((w) => w.id == 'old_wall'), isTrue);
      expect(s2Merged.walls.length, 3);
    });

    test('Undo and Redo via ArchitectCommandController', () {
      final controller = ArchitectCommandController(testProject);
      addTearDown(controller.dispose);

      final options = const StoreyCopyOptions(
        sourceStoreyId: 'storey_1',
        targetStoreyIds: {'storey_2'},
      );

      controller.execute(CopyArchitectElementsAcrossStoreys(options));
      expect(
        controller.project.storeys
            .firstWhere((s) => s.id == 'storey_2')
            .walls
            .length,
        2,
      );

      // Undo
      controller.undo();
      expect(
        controller.project.storeys
            .firstWhere((s) => s.id == 'storey_2')
            .walls,
        isEmpty,
      );

      // Redo
      controller.redo();
      expect(
        controller.project.storeys
            .firstWhere((s) => s.id == 'storey_2')
            .walls
            .length,
        2,
      );
    });

    test('batchAddTypicalStoreys stacks elevations accurately', () {
      final expanded = testProject.batchAddTypicalStoreys(
        count: 3,
        typicalHeight: 3.00,
        namePrefix: 'Типов етаж',
      );

      // Initial storeys: 0.00 (h=2.80), 2.80 (h=3.20), 6.00 (h=2.80).
      // Top was storey_3 at elevation 6.00 with height 2.80 -> next starts at 8.80
      final normal = expanded.storeys.where((s) => !s.isRoof).toList()
        ..sort((a, b) => a.elevation.compareTo(b.elevation));

      expect(normal.length, 6);
      expect(normal[3].elevation, 8.80);
      expect(normal[4].elevation, closeTo(11.80, 1e-4));
      expect(normal[5].elevation, closeTo(14.80, 1e-4));
    });
  });
}
