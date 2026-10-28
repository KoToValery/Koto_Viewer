import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_section_junctions.dart';

void main() {
  const cut = ArchitectSection(
    id: 'sec-1',
    name: 'A-A',
    start: Offset(2.0, -1.0),
    end: Offset(2.0, 5.0),
  );

  List<Offset> rectPoly(double x0, double y0, double x1, double y1) => [
    Offset(x0, y0),
    Offset(x1, y0),
    Offset(x1, y1),
    Offset(x0, y1),
  ];

  ArchitectProject makeProject(List<ArchitectStorey> storeys) =>
      ArchitectProject(
        id: 'proj-test',
        name: 'Test Project',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: storeys.first.id,
        storeys: storeys,
        sections: const [cut],
      );

  test(
    'defaultUsageForStorey selects ground, basement (5 cm XPS), and intermediate packages by storey context',
    () {
      const basementWall = ArchitectWall(
        id: 'w-bsm',
        startPoint: Offset(0, 0),
        endPoint: Offset(4, 0),
        thickness: 0.30,
        height: 2.70,
        coreMaterialOverride: WallCoreMaterial.concrete,
        location: ArchitectWallLocation.exterior,
      );
      final groundWall = basementWall.copyWith(
        id: 'w-gf',
        coreMaterial: WallCoreMaterial.brick,
      );
      final upperWall = groundWall.copyWith(id: 'w-f1');

      final basement = ArchitectStorey(
        id: 's-bsm',
        name: 'Сутерен',
        elevation: -2.70,
        height: 2.70,
        walls: [basementWall],
        slabs: [
          ArchitectSlab(
            id: 'slab-bsm',
            polygon: rectPoly(0, 0, 4, 4),
            thickness: 0.20,
          ),
        ],
      );
      final ground = ArchitectStorey(
        id: 's-gf',
        name: 'Партер',
        elevation: 0.00,
        height: 3.00,
        walls: [groundWall],
        slabs: [
          ArchitectSlab(
            id: 'slab-gf',
            polygon: rectPoly(0, 0, 4, 4),
            thickness: 0.16,
          ),
        ],
      );
      final firstFloor = ArchitectStorey(
        id: 's-f1',
        name: 'Етаж 1',
        elevation: 3.00,
        height: 3.00,
        walls: [upperWall],
        slabs: [
          ArchitectSlab(
            id: 'slab-f1',
            polygon: rectPoly(0, 0, 4, 4),
            thickness: 0.16,
          ),
        ],
      );

      final multiProject = makeProject([basement, ground, firstFloor]);

      // 1. Lowest storey at -2.70 -> foundation/ground
      expect(
        ArchitectSectionJunctions.defaultUsageForStorey(multiProject, basement),
        SlabUsage.foundation,
      );

      // 2. Ground floor (0.00) above basement (-2.70) -> SlabUsage.basement (5 cm XPS below core)
      expect(
        ArchitectSectionJunctions.defaultUsageForStorey(multiProject, ground),
        SlabUsage.basement,
      );
      final gfAssembly = ArchitectSectionJunctions.resolveEffectiveSlabAssembly(
        multiProject,
        ground,
        ground.slabs.single,
      )!;
      expect(gfAssembly.usage, SlabUsage.basement);
      expect(
        gfAssembly.below.any(
          (l) =>
              l.material == SlabMaterial.xps &&
              (l.thickness - 0.05).abs() < 1e-4,
        ),
        isTrue,
      );

      // 3. Upper floor (3.00) above heated ground floor -> SlabUsage.intermediate
      expect(
        ArchitectSectionJunctions.defaultUsageForStorey(
          multiProject,
          firstFloor,
        ),
        SlabUsage.intermediate,
      );

      // 4. Single-storey building at 0.00 with no basement -> SlabUsage.ground
      final singleProject = makeProject([ground]);
      expect(
        ArchitectSectionJunctions.defaultUsageForStorey(singleProject, ground),
        SlabUsage.ground,
      );
    },
  );

  test(
    'perimeter slab trims at exterior wall core so facade insulation passes in front, and wall core cuts floor finishes',
    () {
      // Cut goes from (2, -1) to (2, 5), so station s = y + 1.0.
      // South exterior wall at y = 0 (s = 1.0), direction = (1, 0), normal = (0, 1).
      // exteriorSide = WallExteriorSide.right -> exteriorSign = -1 -> exteriorNormal = (0, -1) (towards y < 0, s < 1.0).
      // Thickness = 0.36 m: 1 cm ext render + 10 cm EPS + 24 cm brick core + 1 cm int plaster.
      // Wall spans y in [-0.18, +0.18] -> s in [0.82, 1.18].
      // Exterior layers (11 cm) span s in [0.82, 0.93]; Core (24 cm) spans s in [0.93, 1.17]; Int plaster (1 cm) spans [1.17, 1.18].
      const extWall = ArchitectWall(
        id: 'w-south',
        startPoint: Offset(0, 0),
        endPoint: Offset(4, 0),
        thickness: 0.36,
        height: 3.0,
        location: ArchitectWallLocation.exterior,
        exteriorSide: WallExteriorSide.right,
        coreMaterialOverride: WallCoreMaterial.brick,
        layers: [
          ArchitectMaterialLayer(
            id: 'ext-render',
            role: ArchitectLayerRole.finish,
            material: ArchitectMaterial.render,
            thickness: 0.01,
          ),
          ArchitectMaterialLayer(
            id: 'ext-eps',
            role: ArchitectLayerRole.insulation,
            material: ArchitectMaterial.eps,
            thickness: 0.10,
          ),
          ArchitectMaterialLayer(
            id: 'core-brick',
            role: ArchitectLayerRole.core,
            material: ArchitectMaterial.brick,
            thickness: 0.24,
          ),
          ArchitectMaterialLayer(
            id: 'int-plaster',
            role: ArchitectLayerRole.finish,
            material: ArchitectMaterial.plaster,
            thickness: 0.01,
          ),
        ],
      );

      // Interior 25 cm load-bearing wall at y = 2.0 (s = 3.0) and thin 12 cm partition at y = 3.2 (s = 4.2)
      const bearingIntWall = ArchitectWall(
        id: 'w-int-bearing',
        startPoint: Offset(0, 2.0),
        endPoint: Offset(4, 2.0),
        thickness: 0.25,
        height: 3.0,
        location: ArchitectWallLocation.interior,
        loadBearing: true,
        coreMaterialOverride: WallCoreMaterial.brick,
      );
      const thinPartition = ArchitectWall(
        id: 'w-int-thin',
        startPoint: Offset(0, 3.2),
        endPoint: Offset(4, 3.2),
        thickness: 0.12,
        height: 3.0,
        location: ArchitectWallLocation.interior,
        loadBearing: false,
        coreMaterialOverride: WallCoreMaterial.brick,
      );

      // Slab drawn all the way to the outer face of the south wall (y = -0.18, s = 0.82)
      final slab = ArchitectSlab(
        id: 'slab-ground',
        polygon: rectPoly(0, -0.18, 4, 4.0),
        thickness: 0.15,
      );

      final storey = ArchitectStorey(
        id: 's-0',
        name: 'Партер',
        elevation: 0.0,
        height: 3.0,
        walls: const [extWall, bearingIntWall, thinPartition],
        slabs: [slab],
      );
      final project = makeProject([storey]);

      final section = ArchitectBuildingSection.build(project, cut);

      // 1. Slab screed/finish layers must NOT exist inside the wall cores (they are cut by wall cores)
      final screedRegions = section.regions
          .where((r) => r.slab && r.material == SlabMaterial.screed)
          .toList();
      expect(screedRegions, isNotEmpty);
      for (final sr in screedRegions) {
        // Midpoint of exterior wall core (s = 1.05, z = 0.13) must NOT be inside screed
        expect(sr.path.contains(const Offset(1.05, 0.13)), isFalse);
        // Midpoint of interior bearing wall core (s = 3.00, z = 0.13) must NOT be inside screed
        expect(sr.path.contains(const Offset(3.00, 0.13)), isFalse);
        // Midpoint of thin partition wall core (s = 4.20, z = 0.13) must NOT be inside screed
        expect(sr.path.contains(const Offset(4.20, 0.13)), isFalse);
        // Room interior between walls (s = 2.00, z = 0.13) MUST be inside screed
        expect(sr.path.contains(const Offset(2.00, 0.13)), isTrue);
      }

      // 2. Slab concrete core stops at outer face of exterior wall core (s ≈ 0.93), NOT protruding to s = 0.82
      final slabConcrete = section.regions.where(
        (r) => r.sourceId == slab.id && r.material == SlabMaterial.concrete,
      );
      expect(slabConcrete, isNotEmpty);
      for (final rc in slabConcrete) {
        // Point in the exterior insulation zone in front of slab (s = 0.87, z = -0.07) must NOT be concrete
        expect(rc.path.contains(const Offset(0.87, -0.07)), isFalse);
      }

      // 3. Exterior wall has descending XPS foundation insulation in front of the slab and strip foundation
      final xpsRegions = section.regions
          .where((r) => r.material == SlabMaterial.xps)
          .toList();
      expect(xpsRegions, isNotEmpty);
      expect(
        xpsRegions.any((r) => r.path.contains(const Offset(0.87, -0.40))),
        isTrue,
      );

      // 4. Strip foundation exists under exterior wall (s = 1.05, z = -0.50) and 25 cm bearing wall (s = 3.00, z = -0.50),
      //    but NOT under the 12 cm thin partition (s = 4.20, z = -0.50)!
      expect(
        slabConcrete.any((r) => r.path.contains(const Offset(1.05, -0.50))),
        isTrue,
      );
      expect(
        slabConcrete.any((r) => r.path.contains(const Offset(3.00, -0.50))),
        isTrue,
      );
      expect(
        slabConcrete.any((r) => r.path.contains(const Offset(4.20, -0.50))),
        isFalse,
      );

      // 5. Blinding concrete pad exists at the bottom of the strip foundations
      final blindingRegions = section.regions
          .where((r) => r.material == SlabMaterial.blindingConcrete)
          .toList();
      expect(blindingRegions, isNotEmpty);

      // 6. Brick wall on ground slab has horizontal capillary-break waterproofing at [0.00, 0.012]
      final brickWp = section.regions.where(
        (r) =>
            r.sourceId == extWall.id &&
            r.material == SlabMaterial.waterproofing,
      );
      expect(brickWp, isNotEmpty);
      expect(
        brickWp.any((r) => r.path.contains(const Offset(1.05, 0.006))),
        isTrue,
      );
    },
  );

  test(
    'reinforced concrete wall, slab core, and strip foundation merge into a single monolithic contour in drawingRegions',
    () {
      const rcWall = ArchitectWall(
        id: 'w-rc',
        startPoint: Offset(0, 0),
        endPoint: Offset(4, 0),
        thickness: 0.35,
        height: 2.80,
        location: ArchitectWallLocation.exterior,
        exteriorSide: WallExteriorSide.right,
        coreMaterialOverride: WallCoreMaterial.concrete,
        insulationThicknessOverride: 0.10,
      );
      final slab = ArchitectSlab(
        id: 'slab-rc',
        polygon: rectPoly(0, 0, 4, 4),
        thickness: 0.16,
      );
      final storey = ArchitectStorey(
        id: 's-rc',
        name: 'Партер',
        elevation: 0.0,
        height: 2.80,
        walls: const [rcWall],
        slabs: [slab],
      );
      final project = makeProject([storey]);

      final section = ArchitectBuildingSection.build(project, cut);
      final concreteDrawingRegions = section.drawingRegions
          .where((r) => r.material == SlabMaterial.concrete)
          .toList();

      // All RC elements (wall core + slab core + strip foundation) must be unioned into a single drawingRegion!
      expect(concreteDrawingRegions.length, 1);
      final monolithicPath = concreteDrawingRegions.single.path;
      // Contains wall core above slab (z = 1.0), slab core (z = -0.08), and strip foundation (z = -0.50)
      expect(monolithicPath.contains(const Offset(1.05, 1.0)), isTrue);
      expect(monolithicPath.contains(const Offset(2.0, -0.08)), isTrue);
      expect(monolithicPath.contains(const Offset(1.05, -0.50)), isTrue);
    },
  );

  test(
    'log wall, stud-frame wall, and sandwich panel wall generate their constructive base details on slab',
    () {
      const logWall = ArchitectWall(
        id: 'w-log',
        startPoint: Offset(0, 0.5),
        endPoint: Offset(4, 0.5),
        thickness: 0.22,
        height: 2.80,
        location: ArchitectWallLocation.exterior,
        exteriorSide: WallExteriorSide.right,
        coreMaterialOverride: WallCoreMaterial.timber,
        layers: [
          ArchitectMaterialLayer(
            id: 'log-core',
            role: ArchitectLayerRole.core,
            material: ArchitectMaterial.timber,
            thickness: 0.22,
          ),
        ],
        system: ArchitectWallSystem(kind: ArchitectWallSystemKind.roundLogs),
      );
      const frameWall = ArchitectWall(
        id: 'w-frame',
        startPoint: Offset(0, 2.0),
        endPoint: Offset(4, 2.0),
        thickness: 0.16,
        height: 2.80,
        location: ArchitectWallLocation.interior,
        coreMaterialOverride: WallCoreMaterial.timber,
        system: ArchitectWallSystem(kind: ArchitectWallSystemKind.studFrame),
      );
      const panelWall = ArchitectWall(
        id: 'w-panel',
        startPoint: Offset(0, 3.5),
        endPoint: Offset(4, 3.5),
        thickness: 0.12,
        height: 2.80,
        location: ArchitectWallLocation.exterior,
        exteriorSide: WallExteriorSide.left,
        coreMaterialOverride: WallCoreMaterial.panel,
        system: ArchitectWallSystem(
          kind: ArchitectWallSystemKind.sandwichPanels,
        ),
      );

      final slab = ArchitectSlab(
        id: 'slab-sys',
        polygon: rectPoly(0, 0.5, 4, 3.5),
        thickness: 0.15,
      );
      final storey = ArchitectStorey(
        id: 's-sys',
        name: 'Партер',
        elevation: 0.0,
        height: 2.80,
        walls: const [logWall, frameWall, panelWall],
        slabs: [slab],
      );
      final project = makeProject([storey]);

      final section = ArchitectBuildingSection.build(project, cut);

      // 1. Log wall has waterproofing + timber sill plate with diagonals (timberCrossSectionPolygon) at z in [0.01, 0.07]
      final logSill = section.regions.where(
        (r) =>
            r.sourceId == logWall.id &&
            r.timberCrossSectionPolygon != null &&
            r.path.contains(const Offset(1.5, 0.04)),
      );
      expect(logSill, isNotEmpty);

      // 2. Stud-frame wall has bottom sole plate with diagonals at z in [0.01, 0.055]
      final frameSolePlate = section.regions.where(
        (r) =>
            r.sourceId == frameWall.id &&
            r.timberCrossSectionPolygon != null &&
            r.path.contains(const Offset(3.0, 0.03)),
      );
      expect(frameSolePlate, isNotEmpty);

      // 3. Sandwich panel wall has base metal drip flashing at z in [0.0, 0.016]
      final panelFlashing = section.regions.where(
        (r) =>
            r.sourceId == panelWall.id &&
            r.material == SlabMaterial.custom &&
            r.path.getBounds().top >= -1e-4 &&
            r.path.getBounds().bottom <= 0.02,
      );
      expect(panelFlashing, isNotEmpty);
    },
  );

  test(
    'floor finishes continue uninterrupted through zero-sill doorways while wall core is cut above doorway',
    () {
      const wallWithDoor = ArchitectWall(
        id: 'w-door',
        startPoint: Offset(0, 2.0),
        endPoint: Offset(4, 2.0),
        thickness: 0.25,
        height: 2.80,
        coreMaterialOverride: WallCoreMaterial.brick,
        doors: [
          ArchitectDoor(
            id: 'door-1',
            wallId: 'w-door',
            uuid: 'u-door-1',
            specId: 'D1',
            offsetRatio: 0.5, // centered at x = 2.0 (where the section cuts!)
            width: 0.90,
            height: 2.10,
            sillHeight: 0.0,
          ),
        ],
      );
      final slab = ArchitectSlab(
        id: 'slab-door',
        polygon: rectPoly(0, 0, 4, 4),
        thickness: 0.15,
      );
      final storey = ArchitectStorey(
        id: 's-door',
        name: 'Партер',
        elevation: 0.0,
        height: 2.80,
        walls: const [wallWithDoor],
        slabs: [slab],
      );
      final project = makeProject([storey]);

      final section = ArchitectBuildingSection.build(project, cut);
      final screedRegions = section.regions
          .where((r) => r.slab && r.material == SlabMaterial.screed)
          .toList();
      expect(screedRegions, isNotEmpty);
      // At s = 3.0 (y = 2.0, inside the doorway), the floor screed continues uninterrupted!
      expect(
        screedRegions.any((r) => r.path.contains(const Offset(3.0, 0.13))),
        isTrue,
      );
    },
  );
}
