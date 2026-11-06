// === SECTION: ARCHITECTURAL FILTER & SELECTION CRITERIA MODEL ===
// Table of Contents:
// 1. ENUMS (FilterScope, FilterOperator, FilterStringOperator)
// 2. CRITERIA VALUE OBJECTS (DimensionFilterCriteria, StringFilterCriteria)
// 3. ARCHITECT FILTER CRITERIA ENTITY
// 4. ARCHITECT FILTER MATCH ENTITY

import 'architect_fenestration_style.dart';

/// Scope of storeys to search or apply changes to.
enum ArchitectFilterScope {
  allStoreys,
  activeStorey,
  specificStorey,
}

/// Comparison operator for numeric and metric values.
enum FilterOperator {
  exact,
  greaterThan,
  lessThan,
  any,
}

/// Matching operator for string marks and spec IDs.
enum FilterStringOperator {
  exact,
  contains,
  any,
}

/// Filter condition for metric dimensions (e.g. width, height, sill).
class DimensionFilterCriteria {
  final FilterOperator operator;
  final double value; // in meters
  final double tolerance; // in meters (default 0.005 = 5mm)

  const DimensionFilterCriteria({
    this.operator = FilterOperator.exact,
    required this.value,
    this.tolerance = 0.005,
  });

  bool matches(double candidate) {
    switch (operator) {
      case FilterOperator.any:
        return true;
      case FilterOperator.exact:
        return (candidate - value).abs() <= tolerance;
      case FilterOperator.greaterThan:
        return candidate > value + tolerance;
      case FilterOperator.lessThan:
        return candidate < value - tolerance;
    }
  }

  DimensionFilterCriteria copyWith({
    FilterOperator? operator,
    double? value,
    double? tolerance,
  }) =>
      DimensionFilterCriteria(
        operator: operator ?? this.operator,
        value: value ?? this.value,
        tolerance: tolerance ?? this.tolerance,
      );
}

/// Filter condition for textual specification marks (e.g. "W1", "D2").
class StringFilterCriteria {
  final FilterStringOperator operator;
  final String value;

  const StringFilterCriteria({
    this.operator = FilterStringOperator.exact,
    required this.value,
  });

  bool matches(String candidate) {
    if (operator == FilterStringOperator.any || value.trim().isEmpty) {
      return true;
    }
    final c = candidate.trim().toLowerCase();
    final v = value.trim().toLowerCase();
    switch (operator) {
      case FilterStringOperator.any:
        return true;
      case FilterStringOperator.exact:
        return c == v;
      case FilterStringOperator.contains:
        return c.contains(v);
    }
  }

  StringFilterCriteria copyWith({
    FilterStringOperator? operator,
    String? value,
  }) =>
      StringFilterCriteria(
        operator: operator ?? this.operator,
        value: value ?? this.value,
      );
}

/// Complete criteria bundle for finding and selecting architectural elements.
class ArchitectFilterCriteria {
  final ArchitectFilterScope scope;
  final String? specificStoreyId;

  /// Semantic kind of element to search for (null = any, window, door, etc.).
  final FenestrationKind? fenestrationKind;

  final DimensionFilterCriteria? widthFilter;
  final DimensionFilterCriteria? heightFilter;
  final DimensionFilterCriteria? sillHeightFilter;
  final DimensionFilterCriteria? thicknessFilter;

  /// Specific style/raster ID to filter by, or null for any style.
  final String? styleIdFilter;

  /// Specific mark/specId criteria to match.
  final StringFilterCriteria? specIdFilter;

  const ArchitectFilterCriteria({
    this.scope = ArchitectFilterScope.allStoreys,
    this.specificStoreyId,
    this.fenestrationKind = FenestrationKind.window,
    this.widthFilter,
    this.heightFilter,
    this.sillHeightFilter,
    this.thicknessFilter,
    this.styleIdFilter,
    this.specIdFilter,
  });

  ArchitectFilterCriteria copyWith({
    ArchitectFilterScope? scope,
    String? specificStoreyId,
    FenestrationKind? fenestrationKind,
    bool clearFenestrationKind = false,
    DimensionFilterCriteria? widthFilter,
    bool clearWidthFilter = false,
    DimensionFilterCriteria? heightFilter,
    bool clearHeightFilter = false,
    DimensionFilterCriteria? sillHeightFilter,
    bool clearSillHeightFilter = false,
    DimensionFilterCriteria? thicknessFilter,
    bool clearThicknessFilter = false,
    String? styleIdFilter,
    bool clearStyleIdFilter = false,
    StringFilterCriteria? specIdFilter,
    bool clearSpecIdFilter = false,
  }) =>
      ArchitectFilterCriteria(
        scope: scope ?? this.scope,
        specificStoreyId: specificStoreyId ?? this.specificStoreyId,
        fenestrationKind: clearFenestrationKind
            ? null
            : (fenestrationKind ?? this.fenestrationKind),
        widthFilter:
            clearWidthFilter ? null : (widthFilter ?? this.widthFilter),
        heightFilter:
            clearHeightFilter ? null : (heightFilter ?? this.heightFilter),
        sillHeightFilter: clearSillHeightFilter
            ? null
            : (sillHeightFilter ?? this.sillHeightFilter),
        thicknessFilter: clearThicknessFilter
            ? null
            : (thicknessFilter ?? this.thicknessFilter),
        styleIdFilter:
            clearStyleIdFilter ? null : (styleIdFilter ?? this.styleIdFilter),
        specIdFilter:
            clearSpecIdFilter ? null : (specIdFilter ?? this.specIdFilter),
      );
}

/// Represents an element matched by [ArchitectFilterCriteria].
class ArchitectFilterMatch {
  final String storeyId;
  final String storeyName;
  final double storeyElevation;
  final String elementId;
  final String hostWallId;
  final String kind; // 'window', 'door', 'wall', etc.
  final String specId;
  final double width;
  final double height;
  final double sillHeight;
  final String? styleId;
  final String displayName;

  const ArchitectFilterMatch({
    required this.storeyId,
    required this.storeyName,
    required this.storeyElevation,
    required this.elementId,
    this.hostWallId = '',
    required this.kind,
    this.specId = '',
    this.width = 0,
    this.height = 0,
    this.sillHeight = 0,
    this.styleId,
    required this.displayName,
  });
}
