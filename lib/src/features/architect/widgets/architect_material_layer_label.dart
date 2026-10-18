import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_material_layer.dart';

extension ArchitectLayerMaterialLabel on ArchitectMaterial {
  String label(AppLocalizations l) => switch (this) {
    ArchitectMaterial.brick => l.architectMaterialBrick,
    ArchitectMaterial.concrete => l.architectMaterialConcrete,
    ArchitectMaterial.timber => l.architectMaterialTimber,
    ArchitectMaterial.panel => l.architectMaterialPanel,
    ArchitectMaterial.eps => l.architectInsulationEps,
    ArchitectMaterial.xps => l.architectInsulationXps,
    ArchitectMaterial.stoneWool => l.architectInsulationStoneWool,
    ArchitectMaterial.plaster => l.wallMaterialPlaster,
    ArchitectMaterial.render => l.wallMaterialRender,
    ArchitectMaterial.plasterboard => l.wallMaterialBoard,
    ArchitectMaterial.tile => l.slabMatTile,
    ArchitectMaterial.stone => l.wallMaterialStone,
  };
}

extension ArchitectLayerRoleLabel on ArchitectLayerRole {
  String label(AppLocalizations l) => switch (this) {
    ArchitectLayerRole.core => l.wallLayerCore,
    ArchitectLayerRole.insulation => l.wallLayerInsulation,
    ArchitectLayerRole.finish => l.wallLayerFinish,
  };
}
