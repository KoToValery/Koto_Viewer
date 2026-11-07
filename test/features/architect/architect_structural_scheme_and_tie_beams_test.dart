import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_hatch_pattern.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_section_hatch.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. ArchitectStructuralScheme Model & Serialization', () {
    test('defaults to flatSlab and 0.45 perimeter beam depth', () {
      final project = ArchitectProject.starter(name: 'Test Project');
      expect(project.structuralScheme, ArchitectStructuralScheme.flatSlab);
      expect(project.structuralScheme.isFlatSlab, isTrue);
      expect(project.structuralScheme.isMasonry, isTrue);
      expect(project.perimeterBeamDepth, 0.45);
    });

    test('serializes and deserializes structuralScheme and perimeterBeamDepth', () {
      final starter = ArchitectProject.starter(
        name: 'Beam & Slab Project',
        structuralScheme: ArchitectStructuralScheme.beamAndSlab,
        perimeterBeamDepth: 0.50,
      );
      final json = starter.toJson();
      expect(json['structuralScheme'], 'beamAndSlab');
      expect(json['perimeterBeamDepth'], 0.50);

      final revived = ArchitectProject.fromJson(json);
      expect(revived.structuralScheme, ArchitectStructuralScheme.beamAndSlab);
      expect(revived.structuralScheme.isBeamAndSlab, isTrue);
      expect(revived.perimeterBeamDepth, 0.50);
    });

    test('supports all structural schemes in copyWith', () {
      var project = ArchitectProject.starter(name: 'Testing');
      for (final scheme in ArchitectStructuralScheme.values) {
        project = project.copyWith(structuralScheme: scheme);
        expect(project.structuralScheme, scheme);
      }
    });
  });

  group('2. Dedicated Aerated Concrete Hatch Pattern', () {
    test('aeratedConcrete preset exists with 45° solid and dashed alternating layers', () {
      final preset = ArchitectHatchPattern.presets.firstWhere(
        (p) => p.id == 'aeratedConcrete',
      );
      expect(preset, isNotNull);
      expect(preset.layers.length, 2);
      expect(preset.layers[0].angleDeg, 45.0);
      expect(preset.layers[1].angleDeg, 45.0);
      expect(preset.layers[1].phaseMm, 1.8);
      expect(preset.layers[1].lineStyle.segmentsMm, [2.0, 1.6]);
    });

    test('ArchitectSectionHatch maps aerated concrete correctly', () {
      final wallHatch = ArchitectSectionHatch.wall(ArchitectMaterial.aeratedConcrete);
      expect(wallHatch.id, 'aeratedConcrete');

      final coreHatch = ArchitectSectionHatch.core(WallCoreMaterial.aeratedConcrete);
      expect(coreHatch.id, 'aeratedConcrete');

      final slabHatch = ArchitectSectionHatch.slab(SlabMaterial.aeratedConcrete);
      expect(slabHatch?.id, 'aeratedConcrete');
    });
  });

  group('3. Intermediate RC Tie Beams on Tall Masonry Walls', () {
    test('tall brick wall (>3.00m) generates 0.20m concrete tie beam breaks in 3D solids', () {
      final wall = ArchitectWall(
        id: 'tall_brick_wall',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        height: 4.50, // 4.50 m clear height (>3.00 m)
        thickness: 0.25,
        wallTypeId: 'ext_25_12_eps',
      );
      final storey = ArchitectStorey(
        id: 'storey_0',
        name: 'Ground',
        elevation: 0.0,
        height: 4.50,
        walls: [wall],
      );
      final project = ArchitectProject.starter(
        name: 'Tall Wall Project',
        groundHeight: 4.50,
      ).copyWith(storeys: [storey], activeStoreyId: 'storey_0');

      final solids = ArchitectWallSolids.build(
        storey,
        project.wallTypes,
        project: project,
      );

      // Verify that at least one solid has concrete material for the intermediate tie beam
      final concreteCoreSolids = solids.where(
        (s) =>
            s.wall.id == wall.id &&
            s.layer.role == ArchitectLayerRole.core &&
            s.layer.material == ArchitectMaterial.concrete,
      ).toList();

      expect(concreteCoreSolids, isNotEmpty);
      final beltSolid = concreteCoreSolids.first;
      expect(beltSolid.bottom, closeTo(3.00, 0.05));
      expect(beltSolid.top, closeTo(3.20, 0.05));
      expect((beltSolid.top - beltSolid.bottom), closeTo(0.20, 0.01));
    });

    test('building section generates concrete tie beam region and continues brick above', () {
      final wall = ArchitectWall(
        id: 'tall_wall_section',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        height: 4.00,
        thickness: 0.25,
        wallTypeId: 'ext_25_12_eps',
      );
      final storey = ArchitectStorey(
        id: 'storey_0',
        name: 'Ground',
        elevation: 0.0,
        height: 4.00,
        walls: [wall],
      );
      final cut = ArchitectSection(
        id: 'sec_1',
        name: 'Section A-A',
        start: const Offset(3, -2),
        end: const Offset(3, 2),
      );
      final project = ArchitectProject.starter(
        name: 'Section Tall Wall Project',
        groundHeight: 4.00,
      ).copyWith(storeys: [storey], sections: [cut]);

      final section = ArchitectBuildingSection.build(project, cut);

      // Verify intermediate belt region is generated with concrete
      final beltRegions = section.regions.where(
        (r) => r.sourceId.contains('belt_1') && r.material == SlabMaterial.concrete,
      ).toList();

      expect(beltRegions, isNotEmpty);
      final beltBounds = beltRegions.first.path.getBounds();
      expect(beltBounds.top, closeTo(3.00, 0.05));
      expect(beltBounds.bottom, closeTo(3.20, 0.05));
      expect(beltBounds.height, closeTo(0.20, 0.01));
    });
  });

  group('4. Window Spandrel Infill (flatSlab vs beamAndSlab)', () {
    test('flatSlab scheme fills window spandrel up to slab underside with aerated concrete', () {
      final window = ArchitectWindow(
        id: 'win_flat',
        uuid: 'uuid_win_flat',
        wallId: 'wall_win_flat',
        offsetRatio: 0.5,
        width: 1.50,
        height: 1.40,
        sillHeight: 0.90, // window top at 2.30 m
      );
      final wall = ArchitectWall(
        id: 'wall_win_flat',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        height: 2.80,
        thickness: 0.25,
        wallTypeId: 'ext_25_12_eps',
        windows: [window],
      );
      final storey0 = ArchitectStorey(
        id: 'storey_0',
        name: 'Ground',
        elevation: 0.0,
        height: 2.80,
        walls: [wall],
      );
      final slab = ArchitectSlab(
        id: 'slab_1',
        polygon: [
          const Offset(-1, -1),
          const Offset(7, -1),
          const Offset(7, 3),
          const Offset(-1, 3),
        ],
      );
      final storey1 = ArchitectStorey(
        id: 'storey_1',
        name: 'Storey 1',
        elevation: 2.80,
        height: 2.80,
        slabs: [slab],
      );
      final cut = ArchitectSection(
        id: 'sec_flat',
        name: 'Section Flat',
        start: const Offset(3, -2),
        end: const Offset(3, 2),
      );
      final project = ArchitectProject.starter(
        name: 'Flat Slab Project',
        structuralScheme: ArchitectStructuralScheme.flatSlab,
      ).copyWith(
        storeys: [storey0, storey1],
        sections: [cut],
        structuralScheme: ArchitectStructuralScheme.flatSlab,
      );

      final section = ArchitectBuildingSection.build(project, cut);

      // Verify that aerated concrete infill region exists above the window
      final infillRegions = section.regions.where(
        (r) =>
            r.sourceId.contains('aerated_infill') &&
            r.material == SlabMaterial.aeratedConcrete,
      ).toList();

      expect(infillRegions, isNotEmpty);
      final infillBounds = infillRegions.first.path.getBounds();
      expect(infillBounds.top, closeTo(2.30, 0.05)); // Window head
      expect(infillBounds.bottom, closeTo(2.60, 0.05)); // Up to slab core bottom (2.80 - 0.20m slab)
    });

    test('beamAndSlab scheme places exterior drop beam and fills remaining space with aerated concrete', () {
      final window = ArchitectWindow(
        id: 'win_beam',
        uuid: 'uuid_win_beam',
        wallId: 'wall_win_beam',
        offsetRatio: 0.5,
        width: 1.50,
        height: 1.30,
        sillHeight: 0.90, // window head at 2.20 m
      );
      final wall = ArchitectWall(
        id: 'wall_win_beam',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        height: 3.00,
        thickness: 0.25,
        wallTypeId: 'ext_25_12_eps',
        windows: [window],
      );
      final storey0 = ArchitectStorey(
        id: 'storey_0',
        name: 'Ground',
        elevation: 0.0,
        height: 3.00,
        walls: [wall],
      );
      final slab = ArchitectSlab(
        id: 'slab_1',
        polygon: [
          const Offset(-1, -1),
          const Offset(7, -1),
          const Offset(7, 3),
          const Offset(-1, 3),
        ],
      );
      final storey1 = ArchitectStorey(
        id: 'storey_1',
        name: 'Storey 1',
        elevation: 3.00,
        height: 2.80,
        slabs: [slab],
      );
      final cut = ArchitectSection(
        id: 'sec_beam',
        name: 'Section Beam',
        start: const Offset(3, -2),
        end: const Offset(3, 2),
      );
      final project = ArchitectProject.starter(
        name: 'Beam and Slab Project',
        structuralScheme: ArchitectStructuralScheme.beamAndSlab,
        perimeterBeamDepth: 0.50,
      ).copyWith(
        storeys: [storey0, storey1],
        sections: [cut],
        structuralScheme: ArchitectStructuralScheme.beamAndSlab,
        perimeterBeamDepth: 0.50,
      );

      final section = ArchitectBuildingSection.build(project, cut);

      // Verify drop beam region exists under slab
      final beamRegions = section.regions.where(
        (r) =>
            r.sourceId.contains('drop_beam') &&
            r.material == SlabMaterial.concrete,
      ).toList();
      expect(beamRegions, isNotEmpty);

      // Verify aerated concrete infill region exists between window head and beam bottom
      final infillRegions = section.regions.where(
        (r) =>
            r.sourceId.contains('aerated_infill') &&
            r.material == SlabMaterial.aeratedConcrete,
      ).toList();
      expect(infillRegions, isNotEmpty);
    });
  });
}
