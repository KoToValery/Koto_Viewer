/// Drawing rules are independent of the model's physical visibility in 3D.
enum ArchitectSectionCategory { gutters, downpipes }

enum ArchitectSectionDisplay {
  cutAndProjection,
  cutOnly,
  hidden;

  bool get showsCut => this != hidden;
  bool get showsProjection => this == cutAndProjection;
}

/// Sparse category rules: absent entries inherit project rules, then the
/// print-first default. The same rules serve every section drawing/export.
class ArchitectSectionVisibility {
  final Map<ArchitectSectionCategory, ArchitectSectionDisplay> categories;

  const ArchitectSectionVisibility({this.categories = const {}});

  ArchitectSectionDisplay modeFor(
    ArchitectSectionCategory category, {
    ArchitectSectionVisibility? defaults,
  }) =>
      categories[category] ??
      defaults?.modeFor(category) ??
      ArchitectSectionDisplay.cutOnly;

  ArchitectSectionVisibility resolved(ArchitectSectionVisibility defaults) =>
      ArchitectSectionVisibility(
        categories: Map.unmodifiable({
          for (final category in ArchitectSectionCategory.values)
            category: modeFor(category, defaults: defaults),
        }),
      );

  /// Null restores inheritance for this category.
  ArchitectSectionVisibility withMode(
    ArchitectSectionCategory category,
    ArchitectSectionDisplay? mode,
  ) {
    final next = {...categories};
    if (mode == null) {
      next.remove(category);
    } else {
      next[category] = mode;
    }
    return ArchitectSectionVisibility(categories: Map.unmodifiable(next));
  }

  Map<String, dynamic> toJson() => {
    for (final entry in categories.entries) entry.key.name: entry.value.name,
  };

  factory ArchitectSectionVisibility.fromJson(Object? json) {
    if (json is! Map) return const ArchitectSectionVisibility();
    final rules = <ArchitectSectionCategory, ArchitectSectionDisplay>{};
    for (final category in ArchitectSectionCategory.values) {
      final mode = ArchitectSectionDisplay.values
          .where((mode) => mode.name == json[category.name])
          .firstOrNull;
      if (mode != null) rules[category] = mode;
    }
    return ArchitectSectionVisibility(categories: Map.unmodifiable(rules));
  }
}
