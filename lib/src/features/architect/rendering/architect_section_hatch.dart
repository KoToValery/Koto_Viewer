import '../models/architect_hatch_pattern.dart';
import '../models/architect_slab_assembly.dart';
import '../models/architect_wall_type.dart';

/// Material conventions shared by section previews and published drawings.
/// Thin membranes and hollow metal profiles use their outlines alone.
class ArchitectSectionHatch {
  static ArchitectHatchPattern preset(String id) =>
      ArchitectHatchPattern.presets.firstWhere((p) => p.id == id);

  static ArchitectHatchPattern? slab(SlabMaterial material) =>
      switch (material) {
        SlabMaterial.concrete ||
        SlabMaterial.blindingConcrete ||
        SlabMaterial.gravel ||
        SlabMaterial.ballast => preset('concrete'),
        SlabMaterial.parquet => preset('wood'),
        SlabMaterial.mineralWool || SlabMaterial.acousticWool => preset('dots'),
        SlabMaterial.xps ||
        SlabMaterial.floorInsulation ||
        SlabMaterial.roofInsulation => preset('diagonalCross'),
        SlabMaterial.compactedFill => preset('earth'),
        SlabMaterial.tile || SlabMaterial.screed => preset('diagonal'),
        SlabMaterial.plaster ||
        SlabMaterial.protectiveRender ||
        SlabMaterial.plasterboard ||
        SlabMaterial.tileAdhesive ||
        SlabMaterial.adhesive ||
        SlabMaterial.underlay => preset('reverseDiagonal'),
        SlabMaterial.peFoil ||
        SlabMaterial.waterproofing ||
        SlabMaterial.vapourBarrier ||
        SlabMaterial.breathableMembrane ||
        SlabMaterial.geotextile ||
        SlabMaterial.custom => null,
      };

  static ArchitectHatchPattern wall(ArchitectMaterial material) =>
      switch (material) {
        ArchitectMaterial.brick => preset('brick'),
        ArchitectMaterial.concrete => preset('concrete'),
        ArchitectMaterial.timber => preset('wood'),
        ArchitectMaterial.panel ||
        ArchitectMaterial.xps ||
        ArchitectMaterial.pir => preset('diagonalCross'),
        ArchitectMaterial.eps || ArchitectMaterial.stoneWool => preset('dots'),
        ArchitectMaterial.tile || ArchitectMaterial.stone => preset('diagonal'),
        ArchitectMaterial.steel => preset('metal'),
        ArchitectMaterial.plaster ||
        ArchitectMaterial.render ||
        ArchitectMaterial.plasterboard => preset('reverseDiagonal'),
      };

  static ArchitectHatchPattern core(WallCoreMaterial material) =>
      switch (material) {
        WallCoreMaterial.brick => preset('brick'),
        WallCoreMaterial.concrete => preset('concrete'),
        WallCoreMaterial.timber => preset('wood'),
        WallCoreMaterial.panel => preset('diagonalCross'),
      };
}
