import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_wall_type.dart';

extension ArchitectWallTypeLabel on ArchitectWallType {
  String get _composition {
    String number(double value) => (value * 100)
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    if (layers.any((l) => l.role == ArchitectLayerRole.finish))
      return number(totalThickness);
    final core = number(brickThickness);
    return hasInsulation ? '$core+${number(insulationThickness)}' : core;
  }

  String compactLabel(AppLocalizations l10n) =>
      name.isNotEmpty && labelId != null
      ? name
      : switch (labelId ?? id) {
          'ext_25_12_eps' ||
          'int_12_partition' ||
          'ext_25_brick' => _composition,
          'bearing_25_concrete' => l10n.architectWallConcreteCode(_composition),
          'parapet_12' => l10n.architectWallParapetCode(_composition),
          _ => name.isEmpty ? l10n.wallNewType : name,
        };

  String pickerHelp(AppLocalizations l10n) {
    final title = switch (labelId ?? id) {
      'ext_25_12_eps' => l10n.architectWallExterior,
      'int_12_partition' => l10n.architectWallPartition,
      'ext_25_brick' => l10n.architectWallBrick,
      'bearing_25_concrete' => l10n.architectWallConcrete,
      'parapet_12' => l10n.architectWallParapet,
      _ => name.isEmpty ? l10n.wallNewType : name,
    };
    return l10n.architectWallTypeThicknessHint(title, _composition);
  }
}
