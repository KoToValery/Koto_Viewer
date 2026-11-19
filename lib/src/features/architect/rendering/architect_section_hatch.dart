import 'dart:ui';

import '../models/architect_hatch_pattern.dart';
import '../models/architect_line_style.dart';
import '../models/architect_line_symbol.dart';
import '../models/architect_slab_assembly.dart';
import '../models/architect_wall_type.dart';

/// Material conventions shared by section previews and published drawings.
/// Finishes and membranes use their outlines alone.
class ArchitectSectionHatch {
  static const densityScale = .55;

  static const _mineralWool = ArchitectHatchPattern(
    id: 'sectionMineralWool',
    name: '_',
    layers: [
      ArchitectHatchLayer(
        angleDeg: 0,
        spacingMm: 2.6,
        shiftMm: 1.8,
        symbolsOnly: true,
        lineStyle: ArchitectLineStyle(
          id: 'sectionWoolLoop',
          name: '_',
          segmentsMm: [],
          symbol: ArchitectLineSymbol(
            shape: ArchitectLineSymbolShape.custom,
            sizeMm: 2.4,
            spacingMm: 3.6,
            strokes: [
              [
                Offset(-.5, .25),
                Offset(-.33, .22),
                Offset(-.20, -.22),
                Offset(-.08, -.34),
                Offset(.08, -.34),
                Offset(.20, -.22),
                Offset(.33, .22),
                Offset(.5, .25),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  static ArchitectHatchPattern preset(String id) =>
      ArchitectHatchPattern.presets.firstWhere((p) => p.id == id);

  static ArchitectHatchPattern? slab(SlabMaterial material) =>
      switch (material) {
        SlabMaterial.aeratedConcrete => preset('aeratedConcrete'),
        SlabMaterial.concrete ||
        SlabMaterial.blindingConcrete => preset('concrete'),
        SlabMaterial.timber => preset('wood'),
        SlabMaterial.mineralWool || SlabMaterial.acousticWool => _mineralWool,
        SlabMaterial.xps => preset('diagonalCross'),
        SlabMaterial.floorInsulation => preset('dots'),
        SlabMaterial.roofInsulation => preset('reverseDiagonal'),
        SlabMaterial.compactedFill => preset('earth'),
        SlabMaterial.tile ||
        SlabMaterial.gravel ||
        SlabMaterial.ballast ||
        SlabMaterial.parquet ||
        SlabMaterial.screed ||
        SlabMaterial.plaster ||
        SlabMaterial.protectiveRender ||
        SlabMaterial.plasterboard ||
        SlabMaterial.tileAdhesive ||
        SlabMaterial.adhesive ||
        SlabMaterial.underlay ||
        SlabMaterial.peFoil ||
        SlabMaterial.waterproofing ||
        SlabMaterial.vapourBarrier ||
        SlabMaterial.breathableMembrane ||
        SlabMaterial.geotextile ||
        SlabMaterial.custom => null,
      };

  static ArchitectHatchPattern? wall(ArchitectMaterial material) =>
      switch (material) {
        ArchitectMaterial.brick => preset('brick'),
        ArchitectMaterial.aeratedConcrete => preset('aeratedConcrete'),
        ArchitectMaterial.concrete => preset('concrete'),
        ArchitectMaterial.timber => preset('wood'),
        ArchitectMaterial.panel ||
        ArchitectMaterial.xps => preset('diagonalCross'),
        ArchitectMaterial.pir => preset('reverseDiagonal'),
        ArchitectMaterial.eps => preset('dots'),
        ArchitectMaterial.stoneWool => _mineralWool,
        ArchitectMaterial.plaster ||
        ArchitectMaterial.render ||
        ArchitectMaterial.plasterboard ||
        ArchitectMaterial.tile ||
        ArchitectMaterial.stone ||
        ArchitectMaterial.steel => null,
      };

  static ArchitectHatchPattern core(WallCoreMaterial material) =>
      switch (material) {
        WallCoreMaterial.brick => preset('brick'),
        WallCoreMaterial.aeratedConcrete => preset('aeratedConcrete'),
        WallCoreMaterial.concrete => preset('concrete'),
        WallCoreMaterial.timber => preset('wood'),
        WallCoreMaterial.panel => preset('diagonalCross'),
      };
}
