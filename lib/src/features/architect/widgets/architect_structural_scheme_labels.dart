import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_project.dart';

extension ArchitectStructuralSchemeLabel on ArchitectStructuralScheme {
  String label(AppLocalizations l) => switch (this) {
    ArchitectStructuralScheme.flatSlab => l.architectStructuralSchemeFlatSlab,
    ArchitectStructuralScheme.beamAndSlab =>
      l.architectStructuralSchemeBeamAndSlab,
    ArchitectStructuralScheme.sandwichPanels =>
      l.architectStructuralSchemeSandwichPanels,
    ArchitectStructuralScheme.roundLogs => l.architectStructuralSchemeRoundLogs,
    ArchitectStructuralScheme.studFrame => l.architectStructuralSchemeStudFrame,
  };
}
