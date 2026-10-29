import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_wall_type.dart';

extension WallCoreMaterialLabel on WallCoreMaterial {
  String label(AppLocalizations l) => switch (this) {
    WallCoreMaterial.brick => l.architectMaterialBrick,
    WallCoreMaterial.aeratedConcrete => l.wallMaterialAeratedConcrete,
    WallCoreMaterial.concrete => l.architectMaterialConcrete,
    WallCoreMaterial.timber => l.architectMaterialTimber,
    WallCoreMaterial.panel => l.architectMaterialPanel,
  };
}

extension WallInsulationMaterialLabel on WallInsulationMaterial {
  String label(AppLocalizations l) => switch (this) {
    WallInsulationMaterial.xps => l.architectInsulationXps,
    WallInsulationMaterial.eps => l.architectInsulationEps,
    WallInsulationMaterial.stoneWool => l.architectInsulationStoneWool,
  };
}
