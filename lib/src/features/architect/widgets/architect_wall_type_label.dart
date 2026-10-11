import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_wall_type.dart';

extension ArchitectWallTypeLabel on ArchitectWallType {
  String compactLabel(AppLocalizations l10n) {
    final label = switch (id) {
      'ext_25_12_eps' => l10n.architectWallExterior,
      'int_12_partition' => l10n.architectWallPartition,
      'ext_25_brick' => l10n.architectWallBrick,
      'bearing_25_concrete' => l10n.architectWallConcrete,
      'parapet_12' => l10n.architectWallParapet,
      _ => null,
    };
    if (label == null) return name;
    final core = (brickThickness * 100).round();
    final insulation = hasInsulation
        ? '+${(insulationThickness * 100).round()}'
        : '';
    return '$label $core$insulation';
  }
}
