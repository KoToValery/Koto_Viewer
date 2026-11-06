// === SECTION: ARCHITECTURAL FILTER SELECTION SERVICE & BATCH COMMAND ===
// Table of Contents:
// 1. QUERY & FILTER EVALUATION
// 2. CRITERIA SAMPLING FROM SELECTION (Pipette)
// 3. ATOMIC BATCH MODIFY MODEL COMMAND

import '../models/architect_project.dart';
import '../models/architect_window.dart';
import '../models/architect_door.dart';
import '../models/architect_fenestration_style.dart';
import '../models/architect_filter_criteria.dart';
import 'architect_command_controller.dart';
import 'fenestration_library_service.dart';

class ArchitectFilterSelectionService {
  /// Evaluates the given [criteria] across storeys in [project].
  static List<ArchitectFilterMatch> query(
    ArchitectProject project,
    ArchitectFilterCriteria criteria,
  ) {
    final matches = <ArchitectFilterMatch>[];
    final targetStoreys = switch (criteria.scope) {
      ArchitectFilterScope.allStoreys => project.storeys,
      ArchitectFilterScope.activeStorey => [project.activeStorey],
      ArchitectFilterScope.specificStorey => project.storeys
          .where((s) => s.id == criteria.specificStoreyId)
          .toList(),
    };

    for (final storey in targetStoreys) {
      // 1. Windows & Doors in Walls
      for (final wall in storey.walls) {
        if (criteria.fenestrationKind == null ||
            criteria.fenestrationKind == FenestrationKind.window) {
          for (final win in wall.windows) {
            if (_matchesWindow(win, criteria)) {
              final styleName = win.resolvedStyle?.name ??
                  win.styleId ??
                  'Standard Window';
              matches.add(
                ArchitectFilterMatch(
                  storeyId: storey.id,
                  storeyName: storey.name,
                  storeyElevation: storey.elevation,
                  elementId: win.id,
                  hostWallId: wall.id,
                  kind: 'window',
                  specId: win.specId,
                  width: win.width,
                  height: win.height,
                  sillHeight: win.sillHeight,
                  styleId: win.styleId ?? win.resolvedStyle?.id,
                  displayName: win.specId.isNotEmpty
                      ? '${win.specId} ($styleName)'
                      : '$styleName (${(win.width * 100).round()}x${(win.height * 100).round()})',
                ),
              );
            }
          }
        }

        if (criteria.fenestrationKind == null ||
            criteria.fenestrationKind == FenestrationKind.door) {
          for (final door in wall.doors) {
            if (_matchesDoor(door, criteria)) {
              final styleName = door.resolvedStyle?.name ??
                  door.styleId ??
                  'Standard Door';
              matches.add(
                ArchitectFilterMatch(
                  storeyId: storey.id,
                  storeyName: storey.name,
                  storeyElevation: storey.elevation,
                  elementId: door.id,
                  hostWallId: wall.id,
                  kind: 'door',
                  specId: door.specId,
                  width: door.width,
                  height: door.height,
                  sillHeight: door.sillHeight,
                  styleId: door.styleId ?? door.resolvedStyle?.id,
                  displayName: door.specId.isNotEmpty
                      ? '${door.specId} ($styleName)'
                      : '$styleName (${(door.width * 100).round()}x${(door.height * 100).round()})',
                ),
              );
            }
          }
        }
      }
    }

    return matches;
  }

  static bool _matchesWindow(
    ArchitectWindow win,
    ArchitectFilterCriteria criteria,
  ) {
    if (criteria.widthFilter != null &&
        !criteria.widthFilter!.matches(win.width)) {
      return false;
    }
    if (criteria.heightFilter != null &&
        !criteria.heightFilter!.matches(win.height)) {
      return false;
    }
    if (criteria.sillHeightFilter != null &&
        !criteria.sillHeightFilter!.matches(win.sillHeight)) {
      return false;
    }
    if (criteria.styleIdFilter != null && criteria.styleIdFilter!.isNotEmpty) {
      final effectiveStyleId = win.styleId ?? win.resolvedStyle?.id;
      if (effectiveStyleId != criteria.styleIdFilter) {
        return false;
      }
    }
    if (criteria.specIdFilter != null &&
        !criteria.specIdFilter!.matches(win.specId)) {
      return false;
    }
    return true;
  }

  static bool _matchesDoor(
    ArchitectDoor door,
    ArchitectFilterCriteria criteria,
  ) {
    if (criteria.widthFilter != null &&
        !criteria.widthFilter!.matches(door.width)) {
      return false;
    }
    if (criteria.heightFilter != null &&
        !criteria.heightFilter!.matches(door.height)) {
      return false;
    }
    if (criteria.sillHeightFilter != null &&
        !criteria.sillHeightFilter!.matches(door.sillHeight)) {
      return false;
    }
    if (criteria.styleIdFilter != null && criteria.styleIdFilter!.isNotEmpty) {
      final effectiveStyleId = door.styleId ?? door.resolvedStyle?.id;
      if (effectiveStyleId != criteria.styleIdFilter) {
        return false;
      }
    }
    if (criteria.specIdFilter != null &&
        !criteria.specIdFilter!.matches(door.specId)) {
      return false;
    }
    return true;
  }

  /// Samples criteria from an existing element in [project] (Pipette tool).
  static ArchitectFilterCriteria sampleFromElement(
    ArchitectProject project,
    String elementId, {
    String? storeyId,
  }) {
    final s = storeyId != null
        ? project.storeys.firstWhere(
            (st) => st.id == storeyId,
            orElse: () => project.activeStorey,
          )
        : project.activeStorey;

    for (final wall in s.walls) {
      for (final w in wall.windows) {
        if (w.id == elementId) {
          return ArchitectFilterCriteria(
            scope: ArchitectFilterScope.allStoreys,
            fenestrationKind: FenestrationKind.window,
            widthFilter: DimensionFilterCriteria(value: w.width),
            heightFilter: DimensionFilterCriteria(value: w.height),
            sillHeightFilter: DimensionFilterCriteria(value: w.sillHeight),
            styleIdFilter: w.styleId ?? w.resolvedStyle?.id,
            specIdFilter: w.specId.isNotEmpty
                ? StringFilterCriteria(value: w.specId)
                : null,
          );
        }
      }
      for (final d in wall.doors) {
        if (d.id == elementId) {
          return ArchitectFilterCriteria(
            scope: ArchitectFilterScope.allStoreys,
            fenestrationKind: FenestrationKind.door,
            widthFilter: DimensionFilterCriteria(value: d.width),
            heightFilter: DimensionFilterCriteria(value: d.height),
            sillHeightFilter: DimensionFilterCriteria(value: d.sillHeight),
            styleIdFilter: d.styleId ?? d.resolvedStyle?.id,
            specIdFilter: d.specId.isNotEmpty
                ? StringFilterCriteria(value: d.specId)
                : null,
          );
        }
      }
    }

    return const ArchitectFilterCriteria(
      scope: ArchitectFilterScope.allStoreys,
    );
  }
}

/// Atomic project-wide command for batch element property modification.
class BatchModifyArchitectElementsCommand extends ArchitectModelCommand {
  final List<ArchitectFilterMatch> targetMatches;

  /// When TRUE, existing dimensions (width, height, sill) are strictly preserved
  /// and only the raster / style skin is replaced.
  final bool skinOnly;

  final String? newStyleId;
  final double? newWidth;
  final double? newHeight;
  final double? newSillHeight;
  final String? newSpecId;

  const BatchModifyArchitectElementsCommand({
    required this.targetMatches,
    this.skinOnly = true,
    this.newStyleId,
    this.newWidth,
    this.newHeight,
    this.newSillHeight,
    this.newSpecId,
  });

  @override
  ArchitectProject apply(ArchitectProject project) {
    if (targetMatches.isEmpty) return project;

    final byStorey = <String, List<ArchitectFilterMatch>>{};
    for (final m in targetMatches) {
      byStorey.putIfAbsent(m.storeyId, () => []).add(m);
    }

    ArchitectFenestrationStyle? resolvedNewStyle;
    if (newStyleId != null && newStyleId!.isNotEmpty) {
      resolvedNewStyle =
          FenestrationLibraryService.instance.getStyleById(newStyleId!);
    }

    final newStoreys = project.storeys.map((storey) {
      final matches = byStorey[storey.id];
      if (matches == null || matches.isEmpty) return storey;

      final winIds = matches
          .where((m) => m.kind == 'window')
          .map((m) => m.elementId)
          .toSet();
      final doorIds = matches
          .where((m) => m.kind == 'door')
          .map((m) => m.elementId)
          .toSet();

      final updatedWalls = storey.walls.map((wall) {
        final hasTargetWin = wall.windows.any((w) => winIds.contains(w.id));
        final hasTargetDoor = wall.doors.any((d) => doorIds.contains(d.id));
        if (!hasTargetWin && !hasTargetDoor) return wall;

        final updatedWindows = wall.windows.map((win) {
          if (!winIds.contains(win.id)) return win;
          var updated = win;

          // 1. Style / Raster replacement
          if (newStyleId != null && newStyleId!.isNotEmpty) {
            updated = updated.copyWith(
              styleId: newStyleId,
              style: resolvedNewStyle,
            );
            if (!skinOnly && resolvedNewStyle != null) {
              updated = updated.copyWith(
                width: resolvedNewStyle.defaultWidth,
                height: resolvedNewStyle.defaultHeight,
                sillHeight: resolvedNewStyle.defaultSillHeight,
              );
            }
          }

          // 2. Explicit dimension overrides
          if (newWidth != null && newWidth! > 0) {
            updated = updated.copyWith(width: newWidth!);
          }
          if (newHeight != null && newHeight! > 0) {
            updated = updated.copyWith(height: newHeight!);
          }
          if (newSillHeight != null && newSillHeight! >= 0) {
            updated = updated.copyWith(sillHeight: newSillHeight!);
          }

          // 3. Mark / Spec ID override
          if (newSpecId != null && newSpecId!.trim().isNotEmpty) {
            updated = updated.copyWith(specId: newSpecId!.trim());
          }

          // 4. Host wall clearance clamp
          if (wall.length > 0.1) {
            final effectiveWidth = updated.width;
            if (effectiveWidth < wall.length) {
              final minRatio = (effectiveWidth / 2.0) / wall.length;
              final maxRatio =
                  (wall.length - effectiveWidth / 2.0) / wall.length;
              final clampedRatio = updated.offsetRatio.clamp(minRatio, maxRatio);
              updated = updated.copyWith(offsetRatio: clampedRatio);
            }
          }

          return updated;
        }).toList();

        final updatedDoors = wall.doors.map((door) {
          if (!doorIds.contains(door.id)) return door;
          var updated = door;

          // 1. Style / Raster replacement
          if (newStyleId != null && newStyleId!.isNotEmpty) {
            updated = updated.copyWith(
              styleId: newStyleId,
              style: resolvedNewStyle,
            );
            if (!skinOnly && resolvedNewStyle != null) {
              updated = updated.copyWith(
                width: resolvedNewStyle.defaultWidth,
                height: resolvedNewStyle.defaultHeight,
                sillHeight: resolvedNewStyle.defaultSillHeight,
              );
            }
          }

          // 2. Explicit dimension overrides
          if (newWidth != null && newWidth! > 0) {
            updated = updated.copyWith(width: newWidth!);
          }
          if (newHeight != null && newHeight! > 0) {
            updated = updated.copyWith(height: newHeight!);
          }
          if (newSillHeight != null && newSillHeight! >= 0) {
            updated = updated.copyWith(sillHeight: newSillHeight!);
          }

          // 3. Mark / Spec ID override
          if (newSpecId != null && newSpecId!.trim().isNotEmpty) {
            updated = updated.copyWith(specId: newSpecId!.trim());
          }

          // 4. Host wall clearance clamp
          if (wall.length > 0.1) {
            final effectiveWidth = updated.width;
            if (effectiveWidth < wall.length) {
              final minRatio = (effectiveWidth / 2.0) / wall.length;
              final maxRatio =
                  (wall.length - effectiveWidth / 2.0) / wall.length;
              final clampedRatio = updated.offsetRatio.clamp(minRatio, maxRatio);
              updated = updated.copyWith(offsetRatio: clampedRatio);
            }
          }

          return updated;
        }).toList();

        return wall.copyWith(windows: updatedWindows, doors: updatedDoors);
      }).toList();

      return storey.copyWith(walls: updatedWalls);
    }).toList();

    return project.copyWith(storeys: newStoreys);
  }
}
