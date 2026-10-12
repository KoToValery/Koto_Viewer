import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_grid_preset.dart';

extension ArchitectGridPresetLabel on ArchitectGridPreset {
  String label(AppLocalizations l10n) => switch (type) {
    GridPresetType.none => l10n.architectGridNone,
    GridPresetType.custom => l10n.architectGridCustom,
    _ => name,
  };

  String help(AppLocalizations l10n) => switch (type) {
    GridPresetType.parking => l10n.architectGridParkingHelp,
    GridPresetType.residential => l10n.architectGridResidentialHelp,
    GridPresetType.villa => l10n.architectGridVillaHelp,
    GridPresetType.modular => l10n.architectGridModularHelp,
    GridPresetType.custom => l10n.architectGridPickerHelp,
    GridPresetType.none => l10n.architectGridNoneHelp,
  };
}
