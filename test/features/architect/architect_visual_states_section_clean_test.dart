import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_floor_drain.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/component_library_service.dart';

void main() {
  group('3 Visual States (Plan / Section / 3D) & Clean Section/Elevation Rules', () {
    test('Diagonal section through a window suppresses 3D background half and normalizes cut', () {
      final wall = ArchitectWall(
        id: 'w_diag_host',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
        height: 2.8,
        windows: const [
          ArchitectWindow(
            id: 'win_diag',
            uuid: 'win_diag_uuid',
            wallId: 'w_diag_host',
            offsetRatio: 0.5,
            width: 1.20,
            height: 1.40,
            sillHeight: 0.85,
            panesCount: 2,
          ),
        ],
      );
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's0',
        storeys: [
          ArchitectStorey(
            id: 's0',
            name: 'Етаж 1',
            elevation: 0,
            height: 2.8,
            walls: [wall],
          ),
        ],
      );

      // Diagonal 45-degree section line cutting across the window and grazing its jamb
      const cut = ArchitectSection(
        id: 'sec_diag',
        start: Offset(1.0, -1.0),
        end: Offset(3.0, 1.0),
      );

      final section = ArchitectBuildingSection.build(project, cut);
      final winPath = section.elementPaths['win_diag'];
      final wallPath = section.elementPaths['w_diag_host'];

      expect(winPath, isNotNull);
      expect(wallPath, isNotNull);
      expect(winPath!.getBounds().height, closeTo(1.40, 1e-3));

      // Zero overlap between the cut window aperture and the host wall
      final overlap = Path.combine(PathOperation.intersect, winPath, wallPath!);
      expect(overlap.getBounds().isEmpty, isTrue);

      // The cut window must NOT produce operation lines in the background elevation
      expect(section.background?.operations ?? const [], isEmpty);

      // The window section region is clean (only top frame, bottom frame, and glazing strip)
      final winRegions = section.regions.where((r) => r.sourceId == 'win_diag').toList();
      expect(winRegions, isNotEmpty);
      final contourCount = winRegions
          .expand((r) => r.path.computeMetrics())
          .length;
      expect(contourCount, lessThanOrEqualTo(4));
    });

    test('Doors on diagonal walls simplify at 10-40 cm and hide below 10 cm', () {
      // Door width = 0.90 m.
      // 1) At ~72 degrees to the view plane (cos(72°) ≈ 0.309), projected width ≈ 0.278 m (in 10..40 cm):
      //    Should render outer contour only (no operation swing chevron).
      final angle72 = 72.0 * 3.141592653589793 / 180.0;
      final len = 3.0;
      final wallMediumOblique = ArchitectWall(
        id: 'w_oblique_med',
        startPoint: const Offset(0, 1),
        endPoint: Offset(len * 0.309, 1 + len * 0.951),
        thickness: 0.25,
        height: 2.8,
        doors: const [
          ArchitectDoor(
            id: 'door_med',
            uuid: 'door_med_uuid',
            wallId: 'w_oblique_med',
            offsetRatio: 0.5,
            width: 0.90,
            height: 2.10,
          ),
        ],
      );

      // 2) Nearly edge-on wall where projected door width is ~0.05 m (< 10 cm):
      //    Should be completely hidden.
      final wallSteepOblique = ArchitectWall(
        id: 'w_oblique_steep',
        startPoint: const Offset(2, 1),
        endPoint: const Offset(2.15, 4.0),
        thickness: 0.25,
        height: 2.8,
        doors: const [
          ArchitectDoor(
            id: 'door_steep',
            uuid: 'door_steep_uuid',
            wallId: 'w_oblique_steep',
            offsetRatio: 0.5,
            width: 0.90,
            height: 2.10,
          ),
        ],
      );

      expect(angle72, greaterThan(1.0));
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's0',
        storeys: [
          ArchitectStorey(
            id: 's0',
            name: 'Етаж 1',
            elevation: 0,
            height: 2.8,
            walls: [wallMediumOblique, wallSteepOblique],
          ),
        ],
      );

      const view = ArchitectElevation(
        id: 'el_front',
        start: Offset(-1, 0),
        end: Offset(4, 0),
      );

      final elevation = ArchitectBuildingElevation.build(project, view);

      // Medium oblique door (10-40 cm) is present as outer contour, without operation swing chevron
      expect(elevation.elementPaths.containsKey('door_med'), isTrue);
      expect(elevation.operations, isEmpty);

      // Steep oblique door (< 10 cm) is completely suppressed
      expect(elevation.elementPaths.containsKey('door_steep'), isFalse);
    });

    test('Furniture components default to hidden in section while floor drains default to visible', () {
      final bedDef = ComponentLibraryService.instance.findDefinition('furniture_bed_double');
      final drainDef = ComponentLibraryService.instance.findDefinition('sanitary_floor_drain');
      final linearDrainDef = ComponentLibraryService.instance.findDefinition('sanitary_linear_drain');

      expect(bedDef?.defaultVisibleInSection, isFalse);
      expect(drainDef?.defaultVisibleInSection, isTrue);
      expect(linearDrainDef?.defaultVisibleInSection, isTrue);

      const bed = ArchitectComponentInstance(
        id: 'comp_bed',
        definitionId: 'furniture_bed_double',
        position: Offset(2.0, 2.0),
      );
      const drainComp = ArchitectComponentInstance(
        id: 'comp_drain',
        definitionId: 'sanitary_floor_drain',
        position: Offset(2.0, 2.0),
      );
      const floorDrain = ArchitectFloorDrain(
        id: 'fd_1',
        polygon: [
          Offset(0, 0),
          Offset(4, 0),
          Offset(4, 4),
          Offset(0, 4),
        ],
        position: Offset(1.0, 2.0),
      );
      const slab = ArchitectSlab(
        id: 'slab_1',
        polygon: [
          Offset(0, 0),
          Offset(4, 0),
          Offset(4, 4),
          Offset(0, 4),
        ],
        thickness: 0.20,
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's0',
        storeys: [
          ArchitectStorey(
            id: 's0',
            name: 'Етаж 1',
            elevation: 0,
            height: 2.8,
            slabs: const [slab],
            floorDrains: const [floorDrain],
            components: const [bed, drainComp],
          ),
        ],
      );

      // Section cutting right through y = 2.0 (intersects bed, drainComp, and floorDrain)
      const cut = ArchitectSection(
        id: 'sec_1',
        start: Offset(0, 2.0),
        end: Offset(4, 2.0),
      );

      final section = ArchitectBuildingSection.build(project, cut);

      // Bed is NOT in section regions (defaultVisibleInSection == false)
      expect(section.regions.any((r) => r.sourceId == 'comp_bed'), isFalse);

      // Both floor drains ARE in section regions with clean 2D profiles
      expect(section.regions.any((r) => r.sourceId == 'fd_1'), isTrue);
      expect(section.regions.any((r) => r.sourceId == 'comp_drain'), isTrue);

      // If user explicitly sets visibleInSection: true on the bed, it appears in section when cut
      final projectWithVisibleBed = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's0',
        storeys: [
          project.storeys.first.copyWith(
            components: [
              bed.copyWith(visibleInSection: true),
              drainComp,
            ],
          ),
        ],
      );
      final sectionWithBed = ArchitectBuildingSection.build(projectWithVisibleBed, cut);
      expect(sectionWithBed.regions.any((r) => r.sourceId == 'comp_bed'), isTrue);
    });
  });
}
