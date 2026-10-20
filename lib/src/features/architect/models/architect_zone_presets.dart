import '../../../core/l10n/generated/app_localizations.dart';
import 'architect_zone.dart';

/// Only user overrides are persisted. Built-in labels always come from ARB.
class ArchitectZonePresets {
  final Map<String, String> overrides;
  const ArchitectZonePresets([this.overrides = const {}]);

  String categoryName(ArchitectZoneCategory category, AppLocalizations l10n) =>
      overrides['category.${category.name}'] ?? category.localizedName(l10n);

  List<String> finishes(String kind, AppLocalizations l10n) {
    final defaults = switch (kind) {
      'floor' => ArchitectZone.standardFloorFinishes(l10n),
      'wall' => ArchitectZone.standardWallFinishes(l10n),
      'ceiling' => ArchitectZone.standardCeilingFinishes(l10n),
      _ => throw ArgumentError.value(kind),
    };
    return [
      for (var i = 0; i < defaults.length; i++)
        overrides['$kind.$i'] ?? defaults[i],
    ];
  }

  factory ArchitectZonePresets.fromJson(Map<String, dynamic> json) =>
      ArchitectZonePresets(
        Map.unmodifiable({
          for (final entry in json.entries)
            if (entry.value is String &&
                (entry.value as String).trim().isNotEmpty)
              entry.key: (entry.value as String).trim(),
        }),
      );
}
