import 'package:flutter/material.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_2d_painter.dart';
import '../services/architect_landscape_tool.dart';

/// Contextual sub-bar for the Landscape (`Ландшафт`) tools:
/// Terrain, Pathway with Automatic Curb, Vegetation, and Site Fence / Gabion.
class ArchitectLandscapeBar extends StatelessWidget {
  final ArchitectTool activeTool;
  final ArchitectLandscapeTool landscapeTool;
  final VoidCallback onChanged;
  final VoidCallback? onCommitDraft;
  final VoidCallback? onUndoPoint;
  final VoidCallback? onCancelDraft;
  final VoidCallback? onSyncTerrainFromGeodesy;
  final VoidCallback? onTriggerChamfer;
  final VoidCallback? onTriggerFillet;

  const ArchitectLandscapeBar({
    super.key,
    required this.activeTool,
    required this.landscapeTool,
    required this.onChanged,
    this.onCommitDraft,
    this.onUndoPoint,
    this.onCancelDraft,
    this.onSyncTerrainFromGeodesy,
    this.onTriggerChamfer,
    this.onTriggerFillet,
  });

  ArchitectLandscapeTool get controller => landscapeTool;
  VoidCallback? get onUndoDraftPoint => onUndoPoint;
  VoidCallback? get onSyncFromGeodesy => onSyncTerrainFromGeodesy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final canCommit = controller.canCommit(activeTool.name);
    final hasDraft = controller.draftPoints.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeTool == ArchitectTool.terrain ||
                activeTool == ArchitectTool.contour)
              ..._buildTerrainControls(context, l, colors)
            else if (activeTool == ArchitectTool.pathway)
              ..._buildPathwayControls(context, l, colors)
            else if (activeTool == ArchitectTool.street)
              ..._buildStreetControls(context, l, colors)
            else if (activeTool == ArchitectTool.vegetation)
              ..._buildVegetationControls(context, l, colors)
            else if (activeTool == ArchitectTool.siteFence)
              ..._buildSiteFenceControls(context, l, colors),
            if (onTriggerFillet != null || onTriggerChamfer != null) ...[
              const SizedBox(width: 8),
              _divider(colors),
              const SizedBox(width: 4),
              if (onTriggerFillet != null)
                IconButton(
                  key: const ValueKey('architect-landscape-fillet'),
                  tooltip: l.architectFillet,
                  visualDensity: VisualDensity.compact,
                  onPressed: onTriggerFillet,
                  icon: const AppIcon(AppIconId.fillet, size: 18),
                ),
              if (onTriggerChamfer != null)
                IconButton(
                  key: const ValueKey('architect-landscape-chamfer'),
                  tooltip: l.architectChamfer,
                  visualDensity: VisualDensity.compact,
                  onPressed: onTriggerChamfer,
                  icon: const AppIcon(AppIconId.chamfer, size: 18),
                ),
            ],
            if (hasDraft) ...[
              const SizedBox(width: 8),
              _divider(colors),
              const SizedBox(width: 6),
              if (canCommit && onCommitDraft != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('architect-landscape-commit'),
                    onPressed: onCommitDraft,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      l.architectZoneClose,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              if (onUndoDraftPoint != null)
                IconButton(
                  key: const ValueKey('architect-landscape-undo-point'),
                  tooltip: l.architectZoneUndoPoint,
                  visualDensity: VisualDensity.compact,
                  onPressed: onUndoDraftPoint,
                  icon: AppIcon(
                    AppIconId.undo,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              if (onCancelDraft != null)
                IconButton(
                  key: const ValueKey('architect-landscape-cancel'),
                  tooltip: l.cancel,
                  visualDensity: VisualDensity.compact,
                  onPressed: onCancelDraft,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.error,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTerrainControls(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    final isContourMode = activeTool == ArchitectTool.contour ||
        controller.terrainMode == ArchitectTerrainDraftMode.contour;
    final isSpotMode = controller.terrainMode == ArchitectTerrainDraftMode.spot;

    return [
      _chip(
        colors: colors,
        selected: controller.terrainState == ArchitectTerrainState.existing,
        label: l.architectTerrainStateExisting,
        onTap: () {
          controller.terrainState = ArchitectTerrainState.existing;
          onChanged();
        },
      ),
      const SizedBox(width: 4),
      _chip(
        colors: colors,
        selected: controller.terrainState == ArchitectTerrainState.proposed,
        label: l.architectTerrainStateProposed,
        onTap: () {
          controller.terrainState = ArchitectTerrainState.proposed;
          onChanged();
        },
      ),
      const SizedBox(width: 8),
      _divider(colors),
      const SizedBox(width: 8),
      if (activeTool != ArchitectTool.contour) ...[
        for (final mode in ArchitectTerrainDraftMode.values) ...[
          _chip(
            colors: colors,
            selected: controller.terrainMode == mode,
            label: _terrainModeLabel(l, mode),
            onTap: () {
              controller.terrainMode = mode;
              controller.clearDraft();
              onChanged();
            },
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 4),
        _divider(colors),
        const SizedBox(width: 8),
      ],
      // Project Datum (±0.00 Level) Button
      ActionChip(
        key: const ValueKey('architect-terrain-datum'),
        visualDensity: VisualDensity.compact,
        avatar: Icon(Icons.height_rounded, size: 15, color: colors.primary),
        label: Text(
          '${l.architectTerrainDatum}: ${controller.terrainDatumElevation.toStringAsFixed(2)} m',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        onPressed: () => _promptDatumDialog(context, l),
      ),
      const SizedBox(width: 8),
      _divider(colors),
      const SizedBox(width: 8),
      if (isContourMode || isSpotMode) ...[
        // Absolute Elevation stepper & tap-to-edit
        _stepper(
          colors: colors,
          label:
              '${l.architectTerrainAbsoluteElevation}: ${controller.contourAbsoluteElevation.toStringAsFixed(2)} m',
          onDec: () {
            controller.contourAbsoluteElevation =
                ((controller.contourAbsoluteElevation - 0.50) * 100).round() / 100.0;
            controller.terrainElevation = controller.contourAbsoluteElevation -
                controller.terrainDatumElevation;
            onChanged();
          },
          onInc: () {
            controller.contourAbsoluteElevation =
                ((controller.contourAbsoluteElevation + 0.50) * 100).round() / 100.0;
            controller.terrainElevation = controller.contourAbsoluteElevation -
                controller.terrainDatumElevation;
            onChanged();
          },
          onTapLabel: () => _promptAbsoluteElevationDialog(context, l),
        ),
        const SizedBox(width: 4),
        // Relative Elevation feedback chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '(${l.architectTerrainRelativeElevation}: ${_formatSignedMeters(controller.terrainElevation)})',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ),
        if (isContourMode) ...[
          const SizedBox(width: 4),
          _chip(
            colors: colors,
            selected: controller.contourMajor,
            label: l.architectTerrainContourMajor,
            onTap: () {
              controller.contourMajor = !controller.contourMajor;
              onChanged();
            },
          ),
          const SizedBox(width: 4),
          _chip(
            colors: colors,
            selected: controller.contourClosed,
            label: l.architectTerrainContourClosed,
            onTap: () {
              controller.contourClosed = !controller.contourClosed;
              onChanged();
            },
          ),
        ],
      ] else ...[
        _stepper(
          colors: colors,
          label:
              '${l.architectTerrainElevationLabel} ${_formatSignedMeters(controller.terrainElevation)}',
          onDec: () {
            controller.terrainElevation =
                ((controller.terrainElevation - 0.10) * 100).round() / 100.0;
            controller.contourAbsoluteElevation =
                controller.terrainElevation + controller.terrainDatumElevation;
            onChanged();
          },
          onInc: () {
            controller.terrainElevation =
                ((controller.terrainElevation + 0.10) * 100).round() / 100.0;
            controller.contourAbsoluteElevation =
                controller.terrainElevation + controller.terrainDatumElevation;
            onChanged();
          },
        ),
      ],
      if (onSyncFromGeodesy != null) ...[
        const SizedBox(width: 8),
        ActionChip(
          key: const ValueKey('architect-terrain-sync-geodesy'),
          visualDensity: VisualDensity.compact,
          avatar: AppIcon(
            AppIconId.terrain,
            size: 15,
            color: colors.primary,
          ),
          label: Text(
            l.architectTerrainFromGeodesy,
            style: const TextStyle(fontSize: 11.5),
          ),
          onPressed: onSyncFromGeodesy,
        ),
      ],
    ];
  }

  Future<void> _promptDatumDialog(
    BuildContext context,
    AppLocalizations l,
  ) async {
    final textController = TextEditingController(
      text: controller.terrainDatumElevation.toStringAsFixed(2),
    );
    final res = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.architectTerrainDatumDialogTitle),
        content: TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.architectTerrainDatum,
            suffixText: 'm',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(
                textController.text.replaceAll(',', '.'),
              );
              Navigator.pop(ctx, val);
            },
            child: Text(l.ok),
          ),
        ],
      ),
    );
    if (res != null) {
      controller.terrainDatumElevation = res;
      if (controller.contourAbsoluteElevation != 0.0) {
        controller.terrainElevation =
            controller.contourAbsoluteElevation - res;
      } else {
        controller.contourAbsoluteElevation =
            controller.terrainElevation + res;
      }
      onChanged();
    }
  }

  Future<void> _promptAbsoluteElevationDialog(
    BuildContext context,
    AppLocalizations l,
  ) async {
    final textController = TextEditingController(
      text: controller.contourAbsoluteElevation.toStringAsFixed(2),
    );
    final res = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.architectTerrainAbsoluteElevation),
        content: TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.architectTerrainAbsoluteElevation,
            suffixText: 'm',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(
                textController.text.replaceAll(',', '.'),
              );
              Navigator.pop(ctx, val);
            },
            child: Text(l.ok),
          ),
        ],
      ),
    );
    if (res != null) {
      controller.contourAbsoluteElevation = res;
      controller.terrainElevation = res - controller.terrainDatumElevation;
      onChanged();
    }
  }

  List<Widget> _buildPathwayControls(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    return [
      _stepper(
        colors: colors,
        label:
            '${l.architectPathwayWidth}: ${controller.pathwayWidth.toStringAsFixed(2)} m',
        onDec: () {
          controller.pathwayWidth = (controller.pathwayWidth - 0.10).clamp(
            0.40,
            12.0,
          );
          onChanged();
        },
        onInc: () {
          controller.pathwayWidth = (controller.pathwayWidth + 0.10).clamp(
            0.40,
            12.0,
          );
          onChanged();
        },
      ),
      const SizedBox(width: 8),
      _divider(colors),
      const SizedBox(width: 8),
      for (final curb in ArchitectPathwayCurbMode.values) ...[
        _chip(
          colors: colors,
          selected: controller.pathwayCurbMode == curb,
          label: _curbModeLabel(l, curb),
          onTap: () {
            controller.pathwayCurbMode = curb;
            onChanged();
          },
        ),
        const SizedBox(width: 4),
      ],
      if (controller.pathwayCurbMode != ArchitectPathwayCurbMode.none) ...[
        const SizedBox(width: 4),
        _stepper(
          colors: colors,
          label:
              '${l.architectPathwayCurbWidth}: ${(controller.pathwayCurbWidth * 100).round()} cm',
          onDec: () {
            controller.pathwayCurbWidth = (controller.pathwayCurbWidth - 0.02)
                .clamp(0.06, 0.35);
            onChanged();
          },
          onInc: () {
            controller.pathwayCurbWidth = (controller.pathwayCurbWidth + 0.02)
                .clamp(0.06, 0.35);
            onChanged();
          },
        ),
      ],
      const SizedBox(width: 8),
      _divider(colors),
      const SizedBox(width: 8),
      for (final mat in ArchitectPavingMaterial.values) ...[
        _chip(
          colors: colors,
          selected: controller.pathwayMaterial == mat,
          label: _pavingMaterialLabel(l, mat),
          onTap: () {
            controller.pathwayMaterial = mat;
            onChanged();
          },
        ),
        const SizedBox(width: 4),
      ],
      const SizedBox(width: 4),
      _chip(
        colors: colors,
        selected: controller.pathwayClosed,
        label: l.architectPathwayClosedPad,
        onTap: () {
          controller.pathwayClosed = !controller.pathwayClosed;
          onChanged();
        },
      ),
    ];
  }

  List<Widget> _buildStreetControls(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    return [
      _stepper(
        colors: colors,
        label:
            '${l.architectStreetRoadWidth}: ${controller.streetRoadWidth.toStringAsFixed(2)} m',
        onDec: () {
          controller.streetRoadWidth =
              (controller.streetRoadWidth - 0.50).clamp(2.50, 30.0);
          onChanged();
        },
        onInc: () {
          controller.streetRoadWidth =
              (controller.streetRoadWidth + 0.50).clamp(2.50, 30.0);
          onChanged();
        },
      ),
      const SizedBox(width: 8),
      _divider(colors),
      const SizedBox(width: 8),
      for (final style in ArchitectRoadMarkingStyle.values) ...[
        _chip(
          colors: colors,
          selected: controller.streetMarkingStyle == style,
          label: style.label(l),
          onTap: () {
            controller.streetMarkingStyle = style;
            onChanged();
          },
        ),
        const SizedBox(width: 4),
      ],
      const SizedBox(width: 4),
      _divider(colors),
      const SizedBox(width: 8),
      _chip(
        colors: colors,
        selected: controller.streetHasLeftSidewalk,
        label: l.architectStreetSidewalkLeft,
        onTap: () {
          controller.streetHasLeftSidewalk = !controller.streetHasLeftSidewalk;
          onChanged();
        },
      ),
      if (controller.streetHasLeftSidewalk) ...[
        const SizedBox(width: 4),
        _stepper(
          colors: colors,
          label: '${controller.streetLeftSidewalkWidth.toStringAsFixed(2)} m',
          onDec: () {
            controller.streetLeftSidewalkWidth =
                (controller.streetLeftSidewalkWidth - 0.20).clamp(0.40, 8.0);
            onChanged();
          },
          onInc: () {
            controller.streetLeftSidewalkWidth =
                (controller.streetLeftSidewalkWidth + 0.20).clamp(0.40, 8.0);
            onChanged();
          },
        ),
      ],
      const SizedBox(width: 6),
      _chip(
        colors: colors,
        selected: controller.streetHasRightSidewalk,
        label: l.architectStreetSidewalkRight,
        onTap: () {
          controller.streetHasRightSidewalk =
              !controller.streetHasRightSidewalk;
          onChanged();
        },
      ),
      if (controller.streetHasRightSidewalk) ...[
        const SizedBox(width: 4),
        _stepper(
          colors: colors,
          label: '${controller.streetRightSidewalkWidth.toStringAsFixed(2)} m',
          onDec: () {
            controller.streetRightSidewalkWidth =
                (controller.streetRightSidewalkWidth - 0.20).clamp(0.40, 8.0);
            onChanged();
          },
          onInc: () {
            controller.streetRightSidewalkWidth =
                (controller.streetRightSidewalkWidth + 0.20).clamp(0.40, 8.0);
            onChanged();
          },
        ),
      ],
      const SizedBox(width: 8),
      _divider(colors),
      const SizedBox(width: 8),
      _stepper(
        colors: colors,
        label:
            '${l.architectStreetCurb}: ${(controller.streetCurbWidth * 100).round()} cm',
        onDec: () {
          controller.streetCurbWidth =
              (controller.streetCurbWidth - 0.02).clamp(0.08, 0.40);
          onChanged();
        },
        onInc: () {
          controller.streetCurbWidth =
              (controller.streetCurbWidth + 0.02).clamp(0.08, 0.40);
          onChanged();
        },
      ),
      const SizedBox(width: 6),
      _chip(
        colors: colors,
        selected: controller.streetClosed,
        label: l.architectPathwayClosedPad,
        onTap: () {
          controller.streetClosed = !controller.streetClosed;
          onChanged();
        },
      ),
    ];
  }

  List<Widget> _buildVegetationControls(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    return [
      for (final sp in ArchitectPlantSpecies.values) ...[
        _chip(
          colors: colors,
          selected: controller.plantSpecies == sp,
          label: _speciesLabel(l, sp),
          onTap: () {
            controller.applySpeciesDefaults(sp);
            controller.clearDraft();
            onChanged();
          },
        ),
        const SizedBox(width: 4),
      ],
      const SizedBox(width: 4),
      _divider(colors),
      const SizedBox(width: 8),
      if (controller.plantSpecies != ArchitectPlantSpecies.trimmedHedge) ...[
        _chip(
          colors: colors,
          selected:
              controller.plantPlacementMode ==
              ArchitectVegetationPlacementMode.single,
          label: l.architectVegetationModeSingle,
          onTap: () {
            controller.plantPlacementMode =
                ArchitectVegetationPlacementMode.single;
            controller.clearDraft();
            onChanged();
          },
        ),
        const SizedBox(width: 4),
        _chip(
          colors: colors,
          selected:
              controller.plantPlacementMode ==
              ArchitectVegetationPlacementMode.row,
          label: l.architectVegetationModeRow,
          onTap: () {
            controller.plantPlacementMode =
                ArchitectVegetationPlacementMode.row;
            controller.clearDraft();
            onChanged();
          },
        ),
        const SizedBox(width: 8),
        _stepper(
          colors: colors,
          label:
              '${l.architectVegetationCrownDiameter} ${controller.plantCrownDiameter.toStringAsFixed(1)} m',
          onDec: () {
            controller.plantCrownDiameter =
                (controller.plantCrownDiameter - 0.2).clamp(0.4, 16.0);
            onChanged();
          },
          onInc: () {
            controller.plantCrownDiameter =
                (controller.plantCrownDiameter + 0.2).clamp(0.4, 16.0);
            onChanged();
          },
        ),
        const SizedBox(width: 6),
        if (controller.plantPlacementMode ==
            ArchitectVegetationPlacementMode.row) ...[
          _stepper(
            colors: colors,
            label:
                '${l.architectVegetationRowSpacing}: ${controller.plantRowSpacing.toStringAsFixed(1)} m',
            onDec: () {
              controller.plantRowSpacing = (controller.plantRowSpacing - 0.5)
                  .clamp(0.5, 25.0);
              onChanged();
            },
            onInc: () {
              controller.plantRowSpacing = (controller.plantRowSpacing + 0.5)
                  .clamp(0.5, 25.0);
              onChanged();
            },
          ),
          const SizedBox(width: 6),
        ],
      ] else ...[
        _stepper(
          colors: colors,
          label:
              '${l.architectPathwayWidth}: ${controller.hedgeWidth.toStringAsFixed(2)} m',
          onDec: () {
            controller.hedgeWidth = (controller.hedgeWidth - 0.10).clamp(
              0.30,
              2.50,
            );
            onChanged();
          },
          onInc: () {
            controller.hedgeWidth = (controller.hedgeWidth + 0.10).clamp(
              0.30,
              2.50,
            );
            onChanged();
          },
        ),
        const SizedBox(width: 6),
      ],
      _stepper(
        colors: colors,
        label:
            '${l.architectVegetationHeight}: ${controller.plantHeight.toStringAsFixed(1)} m',
        onDec: () {
          controller.plantHeight = (controller.plantHeight - 0.3).clamp(
            0.4,
            24.0,
          );
          onChanged();
        },
        onInc: () {
          controller.plantHeight = (controller.plantHeight + 0.3).clamp(
            0.4,
            24.0,
          );
          onChanged();
        },
      ),
    ];
  }

  List<Widget> _buildSiteFenceControls(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    return [
      for (final preset in ArchitectSiteFencePreset.values) ...[
        _chip(
          colors: colors,
          selected: controller.fencePreset == preset,
          label: _fencePresetLabel(l, preset),
          onTap: () {
            controller.applyFencePresetDefaults(preset);
            onChanged();
          },
        ),
        const SizedBox(width: 4),
      ],
      const SizedBox(width: 4),
      _divider(colors),
      const SizedBox(width: 8),
      _stepper(
        colors: colors,
        label:
            '${l.architectFenceHeight} ${controller.fenceHeight.toStringAsFixed(2)} m',
        onDec: () {
          controller.fenceHeight = (controller.fenceHeight - 0.10).clamp(
            0.50,
            4.50,
          );
          onChanged();
        },
        onInc: () {
          controller.fenceHeight = (controller.fenceHeight + 0.10).clamp(
            0.50,
            4.50,
          );
          onChanged();
        },
      ),
      const SizedBox(width: 6),
      _stepper(
        colors: colors,
        label:
            '${l.architectFenceThickness} ${(controller.fenceThickness * 100).round()} cm',
        onDec: () {
          controller.fenceThickness = (controller.fenceThickness - 0.05).clamp(
            0.12,
            1.50,
          );
          onChanged();
        },
        onInc: () {
          controller.fenceThickness = (controller.fenceThickness + 0.05).clamp(
            0.12,
            1.50,
          );
          onChanged();
        },
      ),
      if (controller.fencePreset != ArchitectSiteFencePreset.rcRetaining &&
          controller.fencePreset != ArchitectSiteFencePreset.gabionRetaining) ...[
        const SizedBox(width: 6),
        _stepper(
          colors: colors,
          label:
              '${l.architectFencePierSpacing}: ${controller.fencePierSpacing.toStringAsFixed(1)} m',
          onDec: () {
            controller.fencePierSpacing = (controller.fencePierSpacing - 0.20)
                .clamp(1.20, 6.00);
            onChanged();
          },
          onInc: () {
            controller.fencePierSpacing = (controller.fencePierSpacing + 0.20)
                .clamp(1.20, 6.00);
            onChanged();
          },
        ),
      ],
    ];
  }

  Widget _chip({
    required ColorScheme colors,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      selected: selected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _stepper({
    required ColorScheme colors,
    required String label,
    required VoidCallback onDec,
    required VoidCallback onInc,
    VoidCallback? onTapLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onDec,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.remove_rounded, size: 15),
            ),
          ),
          InkWell(
            onTap: onTapLabel,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onInc,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.add_rounded, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme colors) => Container(
    width: 1,
    height: 22,
    color: colors.outlineVariant,
  );

  static String _formatSignedMeters(double m) {
    if (m.abs() < 1e-4) return '±0.00 m';
    return '${m > 0 ? "+" : ""}${m.toStringAsFixed(2)} m';
  }

  static String _terrainModeLabel(
    AppLocalizations l,
    ArchitectTerrainDraftMode mode,
  ) => switch (mode) {
    ArchitectTerrainDraftMode.boundary => l.architectTerrainModeBoundary,
    ArchitectTerrainDraftMode.hole => l.architectTerrainModeHole,
    ArchitectTerrainDraftMode.contour => l.architectTerrainModeContour,
    ArchitectTerrainDraftMode.spot => l.architectTerrainModeSpot,
    ArchitectTerrainDraftMode.pad => l.architectTerrainModePad,
  };

  static String _curbModeLabel(
    AppLocalizations l,
    ArchitectPathwayCurbMode mode,
  ) => switch (mode) {
    ArchitectPathwayCurbMode.both => l.architectPathwayCurbBoth,
    ArchitectPathwayCurbMode.left => l.architectPathwayCurbLeft,
    ArchitectPathwayCurbMode.right => l.architectPathwayCurbRight,
    ArchitectPathwayCurbMode.none => l.architectPathwayCurbNone,
  };

  static String _pavingMaterialLabel(
    AppLocalizations l,
    ArchitectPavingMaterial mat,
  ) => switch (mat) {
    ArchitectPavingMaterial.stoneSlabs => l.architectPathwayMatStoneSlabs,
    ArchitectPavingMaterial.cobblePavers => l.architectPathwayMatCobblePavers,
    ArchitectPavingMaterial.timberDecking => l.architectPathwayMatTimberDecking,
    ArchitectPavingMaterial.gravel => l.architectPathwayMatGravel,
    ArchitectPavingMaterial.asphalt => l.architectPathwayMatAsphalt,
    ArchitectPavingMaterial.grassGrid => l.architectPathwayMatGrassGrid,
  };

  static String _speciesLabel(
    AppLocalizations l,
    ArchitectPlantSpecies sp,
  ) => switch (sp) {
    ArchitectPlantSpecies.deciduousCanopy => l.architectPlantDeciduousCanopy,
    ArchitectPlantSpecies.deciduousMinimal => l.architectPlantDeciduousMinimal,
    ArchitectPlantSpecies.coniferPine => l.architectPlantConiferPine,
    ArchitectPlantSpecies.columnarCypress => l.architectPlantColumnarCypress,
    ArchitectPlantSpecies.ornamentalPalm => l.architectPlantOrnamentalPalm,
    ArchitectPlantSpecies.shrubCluster => l.architectPlantShrubCluster,
    ArchitectPlantSpecies.trimmedHedge => l.architectPlantTrimmedHedge,
    ArchitectPlantSpecies.artisticLowPoly => l.architectPlantArtisticLowPoly,
  };

  static String _fencePresetLabel(
    AppLocalizations l,
    ArchitectSiteFencePreset preset,
  ) => switch (preset) {
    ArchitectSiteFencePreset.piersAndSlats =>
      l.architectFencePresetPiersAndSlats,
    ArchitectSiteFencePreset.gabionFence => l.architectFencePresetGabionFence,
    ArchitectSiteFencePreset.gabionRetaining =>
      l.architectFencePresetGabionRetaining,
    ArchitectSiteFencePreset.modernLouvers =>
      l.architectFencePresetModernLouvers,
    ArchitectSiteFencePreset.classicIron => l.architectFencePresetClassicIron,
    ArchitectSiteFencePreset.rcRetaining => l.architectFencePresetRcRetaining,
  };
}
