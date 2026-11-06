// === SECTION: ARCHITECTURAL FILTER SELECTION TESTS ===
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_fenestration_style.dart';
import 'package:kotoview/src/features/architect/models/architect_filter_criteria.dart';
import 'package:kotoview/src/features/architect/services/architect_filter_selection_service.dart';
import 'package:kotoview/src/features/architect/services/fenestration_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await FenestrationLibraryService.instance.init();
  });

  ArchitectProject createMultiStoreyTestProject() {
    // Storey 1: Ground floor
    final wall1 = ArchitectWall(
      id: 'w1',
      startPoint: const Offset(0, 0),
      endPoint: const Offset(10, 0),
      thickness: 0.25,
      height: 2.80,
      windows: const [
        ArchitectWindow(
          id: 'win_1_1',
          wallId: 'w1',
          offsetRatio: 0.25,
          width: 1.20,
          height: 1.40,
          sillHeight: 0.85,
          specId: 'W1',
          uuid: 'u_win_1_1',
          styleId: 'win_fixed',
        ),
        ArchitectWindow(
          id: 'win_1_2',
          wallId: 'w1',
          offsetRatio: 0.50,
          width: 1.20,
          height: 1.40,
          sillHeight: 0.85,
          specId: 'W1',
          uuid: 'u_win_1_2',
          styleId: 'win_fixed',
        ),
        ArchitectWindow(
          id: 'win_1_custom',
          wallId: 'w1',
          offsetRatio: 0.80,
          width: 1.80,
          height: 1.60,
          sillHeight: 0.90,
          specId: 'W2',
          uuid: 'u_win_1_custom',
          styleId: 'win_double_casement',
        ),
      ],
      doors: const [
        ArchitectDoor(
          id: 'door_1',
          wallId: 'w1',
          offsetRatio: 0.10,
          width: 0.90,
          height: 2.00,
          uuid: 'u_door_1',
          specId: 'D1',
        ),
      ],
    );

    // Storey 2: Second floor
    final wall2 = ArchitectWall(
      id: 'w2',
      startPoint: const Offset(0, 0),
      endPoint: const Offset(10, 0),
      thickness: 0.25,
      height: 2.80,
      windows: const [
        ArchitectWindow(
          id: 'win_2_1',
          wallId: 'w2',
          offsetRatio: 0.25,
          width: 1.20,
          height: 1.40,
          sillHeight: 0.85,
          specId: 'W1',
          uuid: 'u_win_2_1',
          styleId: 'win_fixed',
        ),
        ArchitectWindow(
          id: 'win_2_2',
          wallId: 'w2',
          offsetRatio: 0.50,
          width: 1.20,
          height: 1.40,
          sillHeight: 0.85,
          specId: 'W1',
          uuid: 'u_win_2_2',
          styleId: 'win_fixed',
        ),
        ArchitectWindow(
          id: 'win_2_3',
          wallId: 'w2',
          offsetRatio: 0.75,
          width: 1.20,
          height: 1.40,
          sillHeight: 0.85,
          specId: 'W1',
          uuid: 'u_win_2_3',
          styleId: 'win_fixed',
        ),
      ],
    );

    // Storey 3: Third floor
    final wall3 = ArchitectWall(
      id: 'w3',
      startPoint: const Offset(0, 0),
      endPoint: const Offset(10, 0),
      thickness: 0.25,
      height: 2.80,
      windows: const [
        ArchitectWindow(
          id: 'win_3_1',
          wallId: 'w3',
          offsetRatio: 0.25,
          width: 1.20,
          height: 1.40,
          sillHeight: 0.85,
          specId: 'W1',
          uuid: 'u_win_3_1',
          styleId: 'win_fixed',
        ),
        ArchitectWindow(
          id: 'win_3_2',
          wallId: 'w3',
          offsetRatio: 0.50,
          width: 1.20,
          height: 1.40,
          sillHeight: 0.85,
          specId: 'W1',
          uuid: 'u_win_3_2',
          styleId: 'win_fixed',
        ),
      ],
    );

    final storeys = [
      ArchitectStorey(
        id: 'storey_1',
        name: 'Floor 1',
        elevation: 0.0,
        height: 2.80,
        walls: [wall1],
      ),
      ArchitectStorey(
        id: 'storey_2',
        name: 'Floor 2',
        elevation: 2.80,
        height: 2.80,
        walls: [wall2],
      ),
      ArchitectStorey(
        id: 'storey_3',
        name: 'Floor 3',
        elevation: 5.60,
        height: 2.80,
        walls: [wall3],
      ),
    ];

    return ArchitectProject(
      id: 'proj_multi',
      name: 'Multi-Storey Tower',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      storeys: storeys,
      activeStoreyId: 'storey_1',
    );
  }

  group('ArchitectFilterSelectionService Query Tests', () {
    test('Queries elements across all storeys with exact width and height', () {
      final project = createMultiStoreyTestProject();

      final criteria = ArchitectFilterCriteria(
        scope: ArchitectFilterScope.allStoreys,
        fenestrationKind: FenestrationKind.window,
        widthFilter: const DimensionFilterCriteria(value: 1.20),
        heightFilter: const DimensionFilterCriteria(value: 1.40),
      );

      final matches = ArchitectFilterSelectionService.query(project, criteria);

      // Floor 1 has 2, Floor 2 has 3, Floor 3 has 2 = 7 total matching windows
      expect(matches.length, equals(7));

      final storeysRepresented = matches.map((m) => m.storeyId).toSet();
      expect(storeysRepresented, containsAll(['storey_1', 'storey_2', 'storey_3']));
    });

    test('Queries elements restricted to active storey', () {
      final project = createMultiStoreyTestProject();

      final criteria = ArchitectFilterCriteria(
        scope: ArchitectFilterScope.activeStorey,
        fenestrationKind: FenestrationKind.window,
        widthFilter: const DimensionFilterCriteria(value: 1.20),
        heightFilter: const DimensionFilterCriteria(value: 1.40),
      );

      final matches = ArchitectFilterSelectionService.query(project, criteria);

      // Only Floor 1 matches (2 windows)
      expect(matches.length, equals(2));
      expect(matches.every((m) => m.storeyId == 'storey_1'), isTrue);
    });

    test('Queries elements by styleId and specId', () {
      final project = createMultiStoreyTestProject();

      final criteria = const ArchitectFilterCriteria(
        scope: ArchitectFilterScope.allStoreys,
        fenestrationKind: FenestrationKind.window,
        styleIdFilter: 'win_double_casement',
        specIdFilter: StringFilterCriteria(value: 'W2'),
      );

      final matches = ArchitectFilterSelectionService.query(project, criteria);

      expect(matches.length, equals(1));
      expect(matches.first.elementId, equals('win_1_custom'));
      expect(matches.first.width, equals(1.80));
    });

    test('Pipette (sampleFromElement) correctly populates criteria from window', () {
      final project = createMultiStoreyTestProject();

      final sampled = ArchitectFilterSelectionService.sampleFromElement(
        project,
        'win_1_custom',
      );

      expect(sampled.fenestrationKind, equals(FenestrationKind.window));
      expect(sampled.widthFilter?.value, equals(1.80));
      expect(sampled.heightFilter?.value, equals(1.60));
      expect(sampled.sillHeightFilter?.value, equals(0.90));
      expect(sampled.styleIdFilter, equals('win_double_casement'));
      expect(sampled.specIdFilter?.value, equals('W2'));
    });
  });

  group('BatchModifyArchitectElementsCommand Tests', () {
    test('Skin-only replacement updates style without changing dimensions', () {
      final project = createMultiStoreyTestProject();

      // Find all 7 standard windows (1.20 x 1.40)
      final criteria = ArchitectFilterCriteria(
        scope: ArchitectFilterScope.allStoreys,
        fenestrationKind: FenestrationKind.window,
        widthFilter: const DimensionFilterCriteria(value: 1.20),
        heightFilter: const DimensionFilterCriteria(value: 1.40),
      );

      final matches = ArchitectFilterSelectionService.query(project, criteria);
      expect(matches.length, equals(7));

      // Execute skin-only replacement to 'win_casement_transom'
      final command = BatchModifyArchitectElementsCommand(
        targetMatches: matches,
        skinOnly: true, // CRITICAL: preserve dimensions!
        newStyleId: 'win_casement_transom',
      );

      final updatedProject = command.apply(project);

      // Verify across all storeys
      for (final storey in updatedProject.storeys) {
        for (final wall in storey.walls) {
          for (final win in wall.windows) {
            if (win.id != 'win_1_custom') {
              // Style is replaced
              expect(win.styleId, equals('win_casement_transom'));
              // Dimensions are strictly preserved!
              expect(win.width, equals(1.20));
              expect(win.height, equals(1.40));
              expect(win.sillHeight, equals(0.85));
            } else {
              // Untargeted window is untouched
              expect(win.styleId, equals('win_double_casement'));
              expect(win.width, equals(1.80));
            }
          }
        }
      }
    });

    test('Batch modification with dimension overrides and new specId', () {
      final project = createMultiStoreyTestProject();

      final criteria = ArchitectFilterCriteria(
        scope: ArchitectFilterScope.allStoreys,
        fenestrationKind: FenestrationKind.window,
        widthFilter: const DimensionFilterCriteria(value: 1.20),
      );

      final matches = ArchitectFilterSelectionService.query(project, criteria);

      final command = BatchModifyArchitectElementsCommand(
        targetMatches: matches,
        skinOnly: true,
        newStyleId: 'win_casement_transom',
        newWidth: 1.50, // Resizing to 1.50m
        newHeight: 1.60, // Resizing to 1.60m
        newSpecId: 'W-MODIFIED',
      );

      final updatedProject = command.apply(project);

      for (final storey in updatedProject.storeys) {
        for (final wall in storey.walls) {
          for (final win in wall.windows) {
            if (win.id != 'win_1_custom') {
              expect(win.styleId, equals('win_casement_transom'));
              expect(win.width, equals(1.50));
              expect(win.height, equals(1.60));
              expect(win.specId, equals('W-MODIFIED'));
            }
          }
        }
      }
    });

    test('Non-skinOnly mode adopts style default dimensions', () {
      final project = createMultiStoreyTestProject();

      final matches = ArchitectFilterSelectionService.query(
        project,
        ArchitectFilterCriteria(
          scope: ArchitectFilterScope.activeStorey,
          widthFilter: const DimensionFilterCriteria(value: 1.80),
        ),
      );
      expect(matches.length, equals(1));

      // Style 'win_triple_casement' has defaultWidth 2.10
      final command = BatchModifyArchitectElementsCommand(
        targetMatches: matches,
        skinOnly: false, // Apply style default dimensions
        newStyleId: 'win_triple_casement',
      );

      final updatedProject = command.apply(project);
      final win = updatedProject.storeys.first.walls.first.windows
          .firstWhere((w) => w.id == 'win_1_custom');

      expect(win.styleId, equals('win_triple_casement'));
      // In non-skinOnly mode, default width of style is adopted
      expect(win.width, equals(2.10));
    });
  });
}
