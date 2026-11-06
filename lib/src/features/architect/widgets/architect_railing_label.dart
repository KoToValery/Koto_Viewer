import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_wall_type.dart';

extension ArchitectRailingKindLabel on ArchitectRailingKind {
  String label(AppLocalizations l) => switch (this) {
    ArchitectRailingKind.solidCap => l.railingSolidCap,
    ArchitectRailingKind.solidStainless => l.railingSolidStainless,
    ArchitectRailingKind.glassChannel => l.railingGlassChannel,
    ArchitectRailingKind.glassPosts => l.railingGlassPosts,
    ArchitectRailingKind.verticalBars => l.railingVerticalBars,
    ArchitectRailingKind.verticalSlats => l.railingVerticalSlats,
  };
}
