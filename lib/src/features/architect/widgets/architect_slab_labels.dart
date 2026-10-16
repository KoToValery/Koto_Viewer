import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_slab_assembly.dart';

extension SlabMaterialLabel on SlabMaterial {
  String label(AppLocalizations l) => switch (this) {
    SlabMaterial.concrete => l.slabMatConcrete,
    SlabMaterial.tile => l.slabMatTile,
    SlabMaterial.tileAdhesive => l.slabMatTileAdhesive,
    SlabMaterial.parquet => l.slabMatParquet,
    SlabMaterial.underlay => l.slabMatUnderlay,
    SlabMaterial.screed => l.slabMatScreed,
    SlabMaterial.peFoil => l.slabMatPeFoil,
    SlabMaterial.xps => l.slabMatXps,
    SlabMaterial.floorInsulation => l.slabMatFloorInsulation,
    SlabMaterial.acousticWool => l.slabMatAcousticWool,
    SlabMaterial.mineralWool => l.slabMatMineralWool,
    SlabMaterial.roofInsulation => l.slabMatRoofInsulation,
    SlabMaterial.waterproofing => l.slabMatWaterproofing,
    SlabMaterial.vapourBarrier => l.slabMatVapourBarrier,
    SlabMaterial.breathableMembrane => l.slabMatBreathableMembrane,
    SlabMaterial.geotextile => l.slabMatGeotextile,
    SlabMaterial.gravel => l.slabMatGravel,
    SlabMaterial.ballast => l.slabMatBallast,
    SlabMaterial.compactedFill => l.slabMatCompactedFill,
    SlabMaterial.blindingConcrete => l.slabMatBlindingConcrete,
    SlabMaterial.plaster => l.slabMatPlaster,
    SlabMaterial.protectiveRender => l.slabMatProtectiveRender,
    SlabMaterial.plasterboard => l.slabMatPlasterboard,
    SlabMaterial.adhesive => l.slabMatAdhesive,
    SlabMaterial.custom => l.slabMatCustom,
  };
}

extension SlabUsageLabel on SlabUsage {
  String label(AppLocalizations l) => switch (this) {
    SlabUsage.foundation => l.slabUseFoundation,
    SlabUsage.ground => l.slabUseGround,
    SlabUsage.basement => l.slabUseBasement,
    SlabUsage.intermediate => l.slabUseIntermediate,
    SlabUsage.coldAttic => l.slabUseColdAttic,
    SlabUsage.insulatedCeiling => l.slabUseInsulatedCeiling,
    SlabUsage.warmRoof => l.slabUseWarmRoof,
    SlabUsage.invertedRoof => l.slabUseInvertedRoof,
    SlabUsage.terrace => l.slabUseTerrace,
  };
}

extension SlabLayerRoleLabel on SlabLayerRole {
  String label(AppLocalizations l) => switch (this) {
    SlabLayerRole.finish => l.slabRoleFinish,
    SlabLayerRole.adhesive => l.slabRoleAdhesive,
    SlabLayerRole.screed => l.slabRoleScreed,
    SlabLayerRole.separation => l.slabRoleSeparation,
    SlabLayerRole.insulation => l.slabRoleInsulation,
    SlabLayerRole.acoustic => l.slabRoleAcoustic,
    SlabLayerRole.waterproofing => l.slabRoleWaterproofing,
    SlabLayerRole.vapourControl => l.slabRoleVapourControl,
    SlabLayerRole.slope => l.slabRoleSlope,
    SlabLayerRole.ceiling => l.slabRoleCeiling,
    SlabLayerRole.base => l.slabRoleBase,
    SlabLayerRole.fill => l.slabRoleFill,
    SlabLayerRole.protection => l.slabRoleProtection,
  };
}

extension SlabAssemblyLabel on ArchitectSlabAssembly {
  String label(AppLocalizations l) =>
      customName.isEmpty ? usage.label(l) : customName;
}

extension SlabLayerLabel on ArchitectSlabLayer {
  String label(AppLocalizations l) =>
      customName.isEmpty ? material.label(l) : customName;
}

String formatSlabThickness(double metres) {
  final cm = metres.abs() >= .009999;
  final value = metres * (cm ? 100 : 1000);
  final digits = (value - value.round()).abs() < .0001 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${cm ? 'cm' : 'mm'}';
}
