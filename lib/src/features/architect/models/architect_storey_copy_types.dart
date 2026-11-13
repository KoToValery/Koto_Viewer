// === SECTION: ARCHITECT STOREY COPY TYPES ===
// Table of Contents:
// 1. ENUMS (ArchitectStoreyElementType, StoreyCopyMode)
// 2. CONFIGURATION OBJECT (StoreyCopyOptions)
// 3. RESULT REPORT (StoreyCopyResult)

import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'architect_project.dart';

/// Categories of architectural and drafting elements that can be transferred across storeys.
enum ArchitectStoreyElementType {
  walls,
  columns,
  beams,
  slabs,
  zones,
  stairs,
  openings,
  dimensions,
  elevationMarkers,
  annotations,
  cadPrimitives,
  components,
  floorDrains,
  decorativeElements,
  roofs;

  /// Human-readable localized label.
  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case ArchitectStoreyElementType.walls:
        return l.architectCategoryWalls;
      case ArchitectStoreyElementType.columns:
        return l.architectCategoryColumns;
      case ArchitectStoreyElementType.beams:
        return l.architectCategoryBeams;
      case ArchitectStoreyElementType.slabs:
        return l.architectCategorySlabs;
      case ArchitectStoreyElementType.zones:
        return l.architectCategoryZones;
      case ArchitectStoreyElementType.stairs:
      case ArchitectStoreyElementType.openings:
        return l.architectCategoryStairsOpenings;
      case ArchitectStoreyElementType.dimensions:
      case ArchitectStoreyElementType.elevationMarkers:
        return l.architectCategoryDimensions;
      case ArchitectStoreyElementType.annotations:
      case ArchitectStoreyElementType.cadPrimitives:
        return l.architectCategoryDrafting2D;
      case ArchitectStoreyElementType.components:
      case ArchitectStoreyElementType.floorDrains:
      case ArchitectStoreyElementType.decorativeElements:
        return l.architectCategoryComponents;
      case ArchitectStoreyElementType.roofs:
        return l.architectCategoryRoofs;
    }
  }

  /// Counts matching elements on a given storey.
  int countInStorey(ArchitectStorey storey, {Set<String>? filterIds}) {
    bool include(String id) => filterIds == null || filterIds.contains(id);

    switch (this) {
      case ArchitectStoreyElementType.walls:
        return storey.walls.where((w) => include(w.id)).length;
      case ArchitectStoreyElementType.columns:
        return storey.columns.where((c) => include(c.id)).length;
      case ArchitectStoreyElementType.beams:
        return storey.beams.where((b) => include(b.id)).length;
      case ArchitectStoreyElementType.slabs:
        return storey.slabs.where((s) => include(s.id)).length;
      case ArchitectStoreyElementType.zones:
        return storey.zones.where((z) => include(z.id)).length;
      case ArchitectStoreyElementType.stairs:
        return storey.stairs.where((s) => include(s.id)).length;
      case ArchitectStoreyElementType.openings:
        return storey.openings.where((o) => include(o.id)).length;
      case ArchitectStoreyElementType.dimensions:
        return storey.dimensions.where((d) => include(d.id)).length;
      case ArchitectStoreyElementType.elevationMarkers:
        return storey.elevationMarkers.where((m) => include(m.id)).length;
      case ArchitectStoreyElementType.annotations:
        return storey.annotations.where((a) => include(a.id)).length;
      case ArchitectStoreyElementType.cadPrimitives:
        return storey.cadPrimitives.where((p) => include(p.id)).length;
      case ArchitectStoreyElementType.components:
        return storey.components.where((c) => include(c.id)).length;
      case ArchitectStoreyElementType.floorDrains:
        return storey.floorDrains.where((d) => include(d.id)).length;
      case ArchitectStoreyElementType.decorativeElements:
        return storey.decorativeElements.where((d) => include(d.id)).length;
      case ArchitectStoreyElementType.roofs:
        return storey.roofs.where((r) => include(r.id)).length;
    }
  }

  /// Default core architectural element categories for typical floor copying.
  static const Set<ArchitectStoreyElementType> defaultTypicalCategories = {
    ArchitectStoreyElementType.walls,
    ArchitectStoreyElementType.columns,
    ArchitectStoreyElementType.beams,
    ArchitectStoreyElementType.slabs,
    ArchitectStoreyElementType.zones,
    ArchitectStoreyElementType.stairs,
    ArchitectStoreyElementType.openings,
    ArchitectStoreyElementType.dimensions,
    ArchitectStoreyElementType.elevationMarkers,
    ArchitectStoreyElementType.annotations,
    ArchitectStoreyElementType.cadPrimitives,
    ArchitectStoreyElementType.components,
    ArchitectStoreyElementType.floorDrains,
    ArchitectStoreyElementType.decorativeElements,
  };
}

/// Transfer conflict resolution mode on target storeys.
enum StoreyCopyMode {
  /// Clears existing elements of the selected categories on the target storeys before placing new copies.
  /// Ideal for typical floors ensuring clean repetition without overlapping duplicates.
  replace,

  /// Appends newly copied elements without removing existing elements on target storeys.
  merge,
}

/// Options payload configuring element copying across storeys.
class StoreyCopyOptions {
  final String sourceStoreyId;
  final Set<String> targetStoreyIds;
  final Set<ArchitectStoreyElementType> elementTypes;
  final Set<String>? selectedElementIds;

  /// Storeys staged in the copy dialog and committed with the copies in one edit.
  final List<ArchitectStorey> additionalStoreys;
  final StoreyCopyMode mode;
  final bool adjustWallHeights;
  final bool adjustLevelMarkers;
  final bool preserveGroups;

  const StoreyCopyOptions({
    required this.sourceStoreyId,
    required this.targetStoreyIds,
    this.elementTypes = ArchitectStoreyElementType.defaultTypicalCategories,
    this.selectedElementIds,
    this.additionalStoreys = const [],
    this.mode = StoreyCopyMode.replace,
    this.adjustWallHeights = true,
    this.adjustLevelMarkers = true,
    this.preserveGroups = true,
  });

  bool get isSelective =>
      selectedElementIds != null && selectedElementIds!.isNotEmpty;

  StoreyCopyOptions copyWith({
    String? sourceStoreyId,
    Set<String>? targetStoreyIds,
    Set<ArchitectStoreyElementType>? elementTypes,
    Set<String>? selectedElementIds,
    List<ArchitectStorey>? additionalStoreys,
    bool clearSelectedElementIds = false,
    StoreyCopyMode? mode,
    bool? adjustWallHeights,
    bool? adjustLevelMarkers,
    bool? preserveGroups,
  }) => StoreyCopyOptions(
    sourceStoreyId: sourceStoreyId ?? this.sourceStoreyId,
    targetStoreyIds: targetStoreyIds ?? this.targetStoreyIds,
    elementTypes: elementTypes ?? this.elementTypes,
    selectedElementIds: clearSelectedElementIds
        ? null
        : (selectedElementIds ?? this.selectedElementIds),
    additionalStoreys: additionalStoreys ?? this.additionalStoreys,
    mode: mode ?? this.mode,
    adjustWallHeights: adjustWallHeights ?? this.adjustWallHeights,
    adjustLevelMarkers: adjustLevelMarkers ?? this.adjustLevelMarkers,
    preserveGroups: preserveGroups ?? this.preserveGroups,
  );
}

/// Result summary of the storey copying execution.
class StoreyCopyResult {
  final int totalCopied;
  final int targetStoreyCount;
  final Map<ArchitectStoreyElementType, int> breakdown;

  const StoreyCopyResult({
    required this.totalCopied,
    required this.targetStoreyCount,
    required this.breakdown,
  });

  static const empty = StoreyCopyResult(
    totalCopied: 0,
    targetStoreyCount: 0,
    breakdown: {},
  );
}
