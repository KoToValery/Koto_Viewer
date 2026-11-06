import '../../../core/l10n/generated/app_localizations.dart';
import 'architect_zone.dart';

/// Only user overrides are persisted. Built-in labels always come from ARB.
class ArchitectZonePresets {
  final Map<String, String> overrides;
  const ArchitectZonePresets([this.overrides = const {}]);

  String categoryName(ArchitectZoneCategory category, AppLocalizations l10n) =>
      overrides['category.${category.name}'] ?? category.localizedName(l10n);

  String defaultFloorFinish(
    ArchitectZoneCategory category,
    AppLocalizations l10n,
  ) {
    if (overrides.containsKey('category.${category.name}.floor')) {
      return overrides['category.${category.name}.floor']!;
    }
    final builtIn = builtInDefaultFloorFinish(category, l10n);
    final defaults = const ArchitectZonePresets().finishes('floor', l10n);
    final index = defaults.indexOf(builtIn);
    if (index >= 0 && overrides.containsKey('floor.$index')) {
      return overrides['floor.$index']!;
    }
    return builtIn;
  }

  String defaultWallFinish(
    ArchitectZoneCategory category,
    AppLocalizations l10n,
  ) {
    if (overrides.containsKey('category.${category.name}.wall')) {
      return overrides['category.${category.name}.wall']!;
    }
    final builtIn = builtInDefaultWallFinish(category, l10n);
    final defaults = const ArchitectZonePresets().finishes('wall', l10n);
    final index = defaults.indexOf(builtIn);
    if (index >= 0 && overrides.containsKey('wall.$index')) {
      return overrides['wall.$index']!;
    }
    return builtIn;
  }

  String defaultCeilingFinish(
    ArchitectZoneCategory category,
    AppLocalizations l10n,
  ) {
    if (overrides.containsKey('category.${category.name}.ceiling')) {
      return overrides['category.${category.name}.ceiling']!;
    }
    final builtIn = builtInDefaultCeilingFinish(category, l10n);
    final defaults = const ArchitectZonePresets().finishes('ceiling', l10n);
    final index = defaults.indexOf(builtIn);
    if (index >= 0 && overrides.containsKey('ceiling.$index')) {
      return overrides['ceiling.$index']!;
    }
    return builtIn;
  }

  static String builtInDefaultFloorFinish(
    ArchitectZoneCategory category,
    AppLocalizations l10n,
  ) {
    switch (category) {
      case ArchitectZoneCategory.bathroom:
        return l10n.architectZoneFloorTerracotta;
      case ArchitectZoneCategory.kitchen:
      case ArchitectZoneCategory.corridor:
      case ArchitectZoneCategory.storage:
      case ArchitectZoneCategory.terrace:
        return l10n.architectZoneFloorGranite;
      case ArchitectZoneCategory.living:
      case ArchitectZoneCategory.bedroom:
      case ArchitectZoneCategory.office:
      case ArchitectZoneCategory.custom:
        return l10n.architectZoneFloorLaminate;
    }
  }

  static String builtInDefaultWallFinish(
    ArchitectZoneCategory category,
    AppLocalizations l10n,
  ) {
    switch (category) {
      case ArchitectZoneCategory.bathroom:
        return l10n.architectZoneWallFaience;
      case ArchitectZoneCategory.kitchen:
        return '${l10n.architectZoneWallLatex} / ${l10n.architectZoneWallFaience}';
      case ArchitectZoneCategory.living:
      case ArchitectZoneCategory.bedroom:
      case ArchitectZoneCategory.corridor:
      case ArchitectZoneCategory.office:
      case ArchitectZoneCategory.storage:
      case ArchitectZoneCategory.terrace:
      case ArchitectZoneCategory.custom:
        return l10n.architectZoneWallLatex;
    }
  }

  static String builtInDefaultCeilingFinish(
    ArchitectZoneCategory category,
    AppLocalizations l10n,
  ) {
    switch (category) {
      case ArchitectZoneCategory.bathroom:
        return l10n.architectZoneCeilingGypsum;
      default:
        return l10n.architectZoneCeilingLatex;
    }
  }

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

  ArchitectZonePresets withCategoryDefaults({
    required ArchitectZoneCategory category,
    String? name,
    String? floorFinish,
    String? wallFinish,
    String? ceilingFinish,
    required AppLocalizations l10n,
  }) {
    final map = Map<String, String>.from(overrides);
    final defaultName = category.localizedName(l10n);
    if (name != null && name.trim().isNotEmpty && name.trim() != defaultName) {
      map['category.${category.name}'] = name.trim();
    } else {
      map.remove('category.${category.name}');
    }

    final defFloor = builtInDefaultFloorFinish(category, l10n);
    if (floorFinish != null &&
        floorFinish.trim().isNotEmpty &&
        floorFinish.trim() != defFloor) {
      map['category.${category.name}.floor'] = floorFinish.trim();
    } else {
      map.remove('category.${category.name}.floor');
    }

    final defWall = builtInDefaultWallFinish(category, l10n);
    if (wallFinish != null &&
        wallFinish.trim().isNotEmpty &&
        wallFinish.trim() != defWall) {
      map['category.${category.name}.wall'] = wallFinish.trim();
    } else {
      map.remove('category.${category.name}.wall');
    }

    final defCeiling = builtInDefaultCeilingFinish(category, l10n);
    if (ceilingFinish != null &&
        ceilingFinish.trim().isNotEmpty &&
        ceilingFinish.trim() != defCeiling) {
      map['category.${category.name}.ceiling'] = ceilingFinish.trim();
    } else {
      map.remove('category.${category.name}.ceiling');
    }

    return ArchitectZonePresets(Map.unmodifiable(map));
  }

  ArchitectZonePresets resetCategory(ArchitectZoneCategory category) {
    final map = Map<String, String>.from(overrides);
    map.remove('category.${category.name}');
    map.remove('category.${category.name}.floor');
    map.remove('category.${category.name}.wall');
    map.remove('category.${category.name}.ceiling');
    return ArchitectZonePresets(Map.unmodifiable(map));
  }

  ArchitectZonePresets resetAll() => const ArchitectZonePresets();

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
