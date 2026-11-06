import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_decorative_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';

void main() {
  ArchitectProject sampleProject() {
    final wall = ArchitectWall(
      id: 'wall_1',
      startPoint: const Offset(0, 0),
      endPoint: const Offset(6, 0),
      thickness: 0.30,
      height: 3.00,
    );
    final storey = ArchitectStorey(
      id: 'storey_1',
      name: 'Ground Floor',
      elevation: 0.0,
      height: 3.00,
      walls: [wall],
    );
    final now = DateTime(2026, 1, 1);
    return ArchitectProject(
      id: 'proj_decor',
      name: 'Decorative Test Project',
      createdAt: now,
      updatedAt: now,
      storeys: [storey],
      activeStoreyId: 'storey_1',
      sections: const [
        ArchitectSection(
          id: 'sec_1',
          name: 'A-A',
          start: Offset(3, -2),
          end: Offset(3, 2),
        ),
      ],
      elevations: const [
        ArchitectElevation(
          id: 'elev_1',
          start: Offset(0, -3),
          end: Offset(6, -3),
        ),
      ],
    );
  }

  group('3D Decorative Elements Model & Geometry', () {
    test('Preset catalog and JSON round-trip preserve all properties', () {
      final catalog = ArchitectDecorativeElement.standardCatalog();
      expect(catalog.length, greaterThanOrEqualTo(7));

      for (final preset in catalog) {
        final json = preset.toJson();
        final restored = ArchitectDecorativeElement.fromJson(json);
        expect(restored.id, preset.id);
        expect(restored.spanLength, closeTo(preset.spanLength, 1e-6));
        expect(restored.height, closeTo(preset.height, 1e-6));
        expect(restored.depth, closeTo(preset.depth, 1e-6));
        expect(restored.material, preset.material);

        final mesh = ArchitectDecorativeGeometry.buildLocalMesh(restored);
        expect(mesh, isNotEmpty);
      }
    });

    test(
      'In-Context Facade Drafting snaps to wall and creates 5cm 3D element',
      () {
        var project = sampleProject();
        final elev = project.elevations.first;

        final created = ArchitectDecorativeGeometry.createFromElevation(
          id: 'decor_frame_1',
          project: project,
          view: elev,
          viewContour: const [
            Offset(-0.6, 1.0),
            Offset(0.6, 1.0),
            Offset(0.6, 2.2),
            Offset(-0.6, 2.2),
          ],
          depth: 0.05,
          frameWidth: 0.12,
          material: ArchitectDecorativeMaterial.eps,
        );

        expect(created.storeyId, 'storey_1');
        expect(created.element.hostWallId, 'wall_1');
        expect(created.element.depth, closeTo(0.05, 1e-6));
        expect(created.element.spanLength, closeTo(1.20, 1e-6));
        expect(created.element.height, closeTo(1.20, 1e-6));
        expect(created.element.frameWidth, closeTo(0.12, 1e-6));
        expect(created.element.showOnPlan, isFalse);

        project = CreateArchitectDecorativeElement(
          storeyId: created.storeyId,
          element: created.element,
        ).apply(project);

        expect(project.activeStorey.decorativeElements.length, 1);

        // Verify projection in Facade (Elevation)
        final facadeDrawing = ArchitectBuildingElevation.build(project, elev);
        expect(facadeDrawing.elementPaths.containsKey('decor_frame_1'), isTrue);

        // Verify stretching left/right on the Facade
        final stretched = ArchitectProjectionEditing.stretchDecorative(
          project,
          'decor_frame_1',
          0.40,
          elev.right,
          isLeft: false,
        );
        final updatedDecor = stretched.activeStorey.decorativeElements.single;
        expect(updatedDecor.spanLength, closeTo(1.60, 1e-6));

        // Verify clearance measures (Left, Right, Sill, Head)
        final measures = ArchitectProjectionEditing.measures(
          stretched,
          'decor_frame_1',
          elev.centre,
          elev.right,
        );
        expect(measures.length, 4);
      },
    );

    test(
      'In-Context Section Drafting extrudes along wall and slices in section',
      () {
        var project = sampleProject();
        final sec = project.sections.first;

        final created = ArchitectDecorativeGeometry.createFromSection(
          id: 'decor_cornice_1',
          project: project,
          cut: sec,
          sectionProfile: const [
            Offset(1.65, 2.75),
            Offset(1.85, 2.75),
            Offset(1.85, 3.00),
            Offset(1.65, 3.00),
          ],
          spanLength: 2.50,
          material: ArchitectDecorativeMaterial.stone,
        );

        expect(created.element.spanLength, closeTo(2.50, 1e-6));
        expect(created.element.depth, closeTo(0.20, 1e-6));
        expect(created.element.height, closeTo(0.25, 1e-6));

        project = CreateArchitectDecorativeElement(
          storeyId: created.storeyId,
          element: created.element,
        ).apply(project);

        final sectionGeom = ArchitectBuildingSection.build(project, sec);
        expect(sectionGeom.elementPaths.containsKey('decor_cornice_1'), isTrue);
        expect(
          sectionGeom.regions.any((r) => r.sourceId == 'decor_cornice_1'),
          isTrue,
        );
      },
    );

    test(
      '2-Axis 3D Boolean Intersection builds solid from custom front + side profiles',
      () {
        final bracket = ArchitectDecorativeElement.standardCatalog().firstWhere(
          (e) => e.id == 'preset_bracket',
        );
        // Customize front contour into a tapered keystone/arch shape as well
        final dualSculpted = bracket.copyWith(
          frontPolygon: const [
            Offset(0.03, 0.0),
            Offset(0.11, 0.0),
            Offset(0.14, 0.36),
            Offset(0.0, 0.36),
          ],
        );
        final mesh = ArchitectDecorativeGeometry.buildLocalMesh(dualSculpted);
        expect(mesh, isNotEmpty);
      },
    );

    test('Plan visibility defaults to false and toggles via command', () {
      var project = sampleProject();
      expect(project.showDecorativeOnPlan, isFalse);

      final preset = ArchitectDecorativeElement.standardCatalog().first;
      project = CreateArchitectDecorativeElement(
        storeyId: 'storey_1',
        element: preset.copyWith(id: 'decor_1'),
      ).apply(project);

      expect(
        ArchitectSelection.outline(project, 'decor_1').getBounds().isEmpty,
        isFalse,
      );

      project = const SetArchitectShowDecorativeOnPlan(true).apply(project);
      expect(project.showDecorativeOnPlan, isTrue);
    });
  });
}
