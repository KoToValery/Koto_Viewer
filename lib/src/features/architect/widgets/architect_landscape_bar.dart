import 'package:flutter/material.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';
import '../models/architect_project.dart';
import '../rendering/architect_2d_painter.dart';
import '../services/architect_landscape_tool.dart';

/// Streamlined contextual sub-bar for the Landscape (`Ландшафт`) tools:
/// Terrain, Contour (`Авто-контур` / `Сплайн`), Pathway, Street, Vegetation, and Site Fence.
class ArchitectLandscapeBar extends StatelessWidget {
  final ArchitectTool activeTool;
  final ArchitectLandscapeTool landscapeTool;
  final ArchitectProject? project;
  final VoidCallback onChanged;
  final ValueChanged<ArchitectTerrainState> onTerrainStateChanged;
  final VoidCallback? onCommitDraft;
  final VoidCallback? onUndoPoint;
  final VoidCallback? onCancelDraft;
  final VoidCallback? onSyncTerrainFromGeodesy;
  final VoidCallback? onCreateProposedFromExisting;
  final ValueChanged<double>? onDatumUpdated;
  final ValueChanged<double>? onContourIntervalUpdated;
  final VoidCallback? onEditSelectedElevation;
  final bool hasSelectedContourOrSpot;
  final bool hasSelectedTerrain;
  final bool terrainSubModeActive;
  final ValueChanged<ArchitectTerrainDraftMode>? onTerrainModeSelected;
  final VoidCallback? onTriggerChamfer;
  final VoidCallback? onTriggerFillet;
  final VoidCallback? onOrientBuilding;

  const ArchitectLandscapeBar({
    super.key,
    required this.activeTool,
    required this.landscapeTool,
    this.project,
    required this.onChanged,
    required this.onTerrainStateChanged,
    this.onCommitDraft,
    this.onUndoPoint,
    this.onCancelDraft,
    this.onSyncTerrainFromGeodesy,
    this.onCreateProposedFromExisting,
    this.onDatumUpdated,
    this.onContourIntervalUpdated,
    this.onEditSelectedElevation,
    this.hasSelectedContourOrSpot = false,
    this.hasSelectedTerrain = false,
    this.terrainSubModeActive = false,
    this.onTerrainModeSelected,
    this.onTriggerChamfer,
    this.onTriggerFillet,
    this.onOrientBuilding,
  });

  ArchitectLandscapeTool get controller => landscapeTool;

  void _notifyChanged() {
    controller.notifyChanged();
    onChanged.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: landscapeTool,
      builder: (context, _) {
        final l = context.l10n;
        final colors = Theme.of(context).colorScheme;
        final hasDraft = controller.draftPoints.isNotEmpty;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                if (activeTool == ArchitectTool.contour)
                  ..._buildContourControls(context, l, colors)
                else if (activeTool == ArchitectTool.terrain)
                  ..._buildTerrainControls(context, l, colors)
                else if (activeTool == ArchitectTool.pathway)
                  ..._buildPathwayControls(context, l, colors)
                else if (activeTool == ArchitectTool.street)
                  ..._buildStreetControls(context, l, colors)
                else if (activeTool == ArchitectTool.vegetation)
                  ..._buildVegetationControls(context, l, colors)
                else if (activeTool == ArchitectTool.siteFence)
                  ..._buildSiteFenceControls(context, l, colors),
                if (hasDraft && onUndoPoint != null) ...[
                  const SizedBox(width: 6),
                  _divider(colors),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('architect-landscape-undo-point'),
                    tooltip: l.architectZoneUndoPoint,
                    visualDensity: VisualDensity.compact,
                    onPressed: onUndoPoint,
                    icon: AppIcon(
                      AppIconId.undo,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildStateAndDatumPrefix(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    return [
      _chip(
        colors: colors,
        selected: controller.terrainState == ArchitectTerrainState.existing,
        label: l.architectTerrainStateExisting,
        onTap: () => onTerrainStateChanged(ArchitectTerrainState.existing),
      ),
      const SizedBox(width: 4),
      _chip(
        colors: colors,
        selected: controller.terrainState == ArchitectTerrainState.proposed,
        label: l.architectTerrainStateProposed,
        onTap: () => onTerrainStateChanged(ArchitectTerrainState.proposed),
      ),
      const SizedBox(width: 6),
      _divider(colors),
      const SizedBox(width: 6),
    ];
  }

  double _effectiveDatum() {
    if (project != null) {
      final active = controller.terrainState == ArchitectTerrainState.existing
          ? project!.existingTerrain
          : project!.proposedTerrain;
      if (active.datumElevation.abs() > 1e-4) return active.datumElevation;
      final other = controller.terrainState == ArchitectTerrainState.existing
          ? project!.proposedTerrain
          : project!.existingTerrain;
      if (other.datumElevation.abs() > 1e-4) return other.datumElevation;
    }
    return controller.terrainDatumElevation;
  }

  BimDistanceUnit get _elevUnit => project != null
      ? terrainElevationUnit(project!.units, project!.levelUnits)
      : BimDistanceUnit.meters;

  double _effectiveContourIntervalMeters() {
    if (project != null) {
      final active = controller.terrainState == ArchitectTerrainState.existing
          ? project!.existingTerrain
          : project!.proposedTerrain;
      if (active.contourInterval > 1e-4) return active.contourInterval;
      final other = controller.terrainState == ArchitectTerrainState.existing
          ? project!.proposedTerrain
          : project!.existingTerrain;
      if (other.contourInterval > 1e-4) return other.contourInterval;
    }
    return controller.contourInterval;
  }

  Widget _contourIntervalChip(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    final elevUnit = _elevUnit;
    final intervalMeters = _effectiveContourIntervalMeters();
    final displayVal = elevUnit.toUnit(intervalMeters);
    return Tooltip(
      message: l.architectTerrainContourIntervalHint,
      child: ActionChip(
        key: const ValueKey('architect-terrain-contour-interval'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: Icon(Icons.unfold_more_rounded, size: 15, color: colors.primary),
        label: Text(
          '${l.architectTerrainContourIntervalShort}: ${displayVal.toStringAsFixed(2)} ${elevUnit.symbol}',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        onPressed: () async {
          final res = await BimNumericKeypad.showInputDialog(
            context,
            title: l.architectTerrainContourInterval,
            initialText: displayVal.toStringAsFixed(2),
            unitLabel: elevUnit.symbol,
            decimals: 3,
            min: 0.0,
            allowNegative: false,
          );
          if (res != null) {
            final meters = elevUnit.fromUnit(res);
            final cleanMeters = meters <= 1e-4
                ? 0.0
                : double.parse(meters.toStringAsFixed(4));
            controller.contourInterval = cleanMeters;
            onContourIntervalUpdated?.call(cleanMeters);
            _notifyChanged();
          }
        },
      ),
    );
  }

  List<Widget> _buildDatumAndQuickActionsSuffix(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    final datum = _effectiveDatum();
    final elevUnit = _elevUnit;
    final datumDisplay = elevUnit.toUnit(datum);
    final editDisplay = elevUnit.toUnit(controller.contourAbsoluteElevation);
    return [
      ActionChip(
        key: const ValueKey('architect-terrain-datum'),
        visualDensity: VisualDensity.compact,
        avatar: Icon(Icons.height_rounded, size: 15, color: colors.primary),
        label: Text(
          '±0.00: ${datumDisplay.toStringAsFixed(2)} ${elevUnit.symbol}',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        onPressed: () => _promptDatumKeypad(context, l, datum),
      ),
      const SizedBox(width: 6),
      _contourIntervalChip(context, l, colors),
      if (onOrientBuilding != null) ...[
        const SizedBox(width: 6),
        Tooltip(
          message: l.architectSiteOrientBuildingTooltip,
          child: ActionChip(
            key: const ValueKey('architect-site-orient-building'),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: AppIcon(
              AppIconId.compass,
              size: 15,
              color: colors.primary,
            ),
            label: Text(
              l.architectSiteOrientBuilding,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onOrientBuilding,
          ),
        ),
      ],
      if (onCreateProposedFromExisting != null &&
          project != null &&
          project!.existingTerrain.isNotEmpty &&
          project!.proposedTerrain.isEmpty) ...[
        const SizedBox(width: 6),
        ActionChip(
          key: const ValueKey('architect-terrain-create-proposed'),
          visualDensity: VisualDensity.compact,
          avatar: AppIcon(
            AppIconId.duplicate,
            size: 15,
            color: colors.primary,
          ),
          label: Text(
            l.architectTerrainCreateProposed,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          onPressed: onCreateProposedFromExisting,
        ),
      ],
      if (hasSelectedContourOrSpot && onEditSelectedElevation != null) ...[
        const SizedBox(width: 6),
        ActionChip(
          key: const ValueKey('architect-terrain-edit-elevation'),
          visualDensity: VisualDensity.compact,
          avatar: Icon(Icons.edit_rounded, size: 15, color: colors.primary),
          label: Text(
            '${l.architectTerrainEditElevation}: ${editDisplay.toStringAsFixed(2)} ${elevUnit.symbol}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          onPressed: onEditSelectedElevation,
        ),
      ],
    ];
  }

  List<Widget> _buildContourControls(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    final elevUnit = _elevUnit;
    final elevDisplay = elevUnit.toUnit(controller.contourAbsoluteElevation);
    final stepMeters = _effectiveContourIntervalMeters();
    final stepDisplay = stepMeters > 1e-4 ? elevUnit.toUnit(stepMeters) : null;
    return [
      Tooltip(
        message: l.architectSplineTraceContourHint,
        child: ChoiceChip(
          key: const ValueKey('architect-contour-auto-trace'),
          selected: controller.contourAutoTrace,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          avatar: const Icon(Icons.auto_fix_high, size: 15),
          label: Text(
            l.architectSplineTraceContour,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight:
                  controller.contourAutoTrace ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onSelected: (_) {
            controller.contourAutoTrace = true;
            controller.clearDraft();
            _notifyChanged();
          },
        ),
      ),
      const SizedBox(width: 4),
      ChoiceChip(
        key: const ValueKey('architect-contour-manual-spline'),
        selected: !controller.contourAutoTrace,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: const AppIcon(AppIconId.spline, size: 15),
        label: Text(
          l.architectToolSpline,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight:
                !controller.contourAutoTrace ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onSelected: (_) {
          controller.contourAutoTrace = false;
          controller.clearDraft();
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
      _divider(colors),
      const SizedBox(width: 6),
      _numericChip(
        context: context,
        key: const ValueKey('architect-contour-elevation'),
        colors: colors,
        title: l.architectTerrainContourElevationTitle,
        label:
            '${l.architectTerrainElevationLabel} ${elevDisplay.toStringAsFixed(2)} ${elevUnit.symbol}',
        initialValue: elevDisplay,
        unitLabel: elevUnit.symbol,
        decimals: 3,
        allowNegative: true,
        stepDelta: stepDisplay,
        onSubmitted: (val) {
          final meters = elevUnit.fromUnit(val);
          controller.contourAbsoluteElevation = meters;
          controller.terrainElevation = meters - controller.terrainDatumElevation;
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
      _contourIntervalChip(context, l, colors),
      const SizedBox(width: 6),
      ChoiceChip(
        key: const ValueKey('architect-contour-major'),
        selected: controller.contourMajor,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        label: Text(
          l.architectTerrainContourMajor,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: controller.contourMajor ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onSelected: (_) {
          controller.contourMajor = !controller.contourMajor;
          _notifyChanged();
        },
      ),
      const SizedBox(width: 4),
      ChoiceChip(
        key: const ValueKey('architect-contour-closed'),
        selected: controller.contourClosed,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        label: Text(
          l.architectTerrainContourClosed,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: controller.contourClosed ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onSelected: (_) {
          controller.contourClosed = !controller.contourClosed;
          _notifyChanged();
        },
      ),
      if (hasSelectedContourOrSpot && onEditSelectedElevation != null) ...[
        const SizedBox(width: 6),
        ActionChip(
          key: const ValueKey('architect-terrain-edit-elevation'),
          visualDensity: VisualDensity.compact,
          avatar: Icon(Icons.edit_rounded, size: 15, color: colors.primary),
          label: Text(
            '${l.architectTerrainEditElevation}: ${elevDisplay.toStringAsFixed(2)} ${elevUnit.symbol}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          onPressed: onEditSelectedElevation,
        ),
      ],
    ];
  }

  static const List<ArchitectTerrainDraftMode> _terrainDrawModes = [
    ArchitectTerrainDraftMode.boundary,
    ArchitectTerrainDraftMode.boundaryRect,
  ];

  static const List<ArchitectTerrainDraftMode> _terrainObjectModes = [
    ArchitectTerrainDraftMode.pad,
    ArchitectTerrainDraftMode.hole,
    ArchitectTerrainDraftMode.spot,
    ArchitectTerrainDraftMode.contour,
    ArchitectTerrainDraftMode.pickContour,
  ];

  List<Widget> _buildTerrainControls(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    final showObjectCommands = hasSelectedTerrain || terrainSubModeActive;
    if (!showObjectCommands) {
      return [
        ..._buildStateAndDatumPrefix(context, l, colors),
        for (final mode in _terrainDrawModes) ...[
          _chip(
            colors: colors,
            selected: controller.terrainMode == mode,
            label: _terrainModeLabel(l, mode),
            onTap: () {
              if (onTerrainModeSelected != null) {
                onTerrainModeSelected!(mode);
              } else {
                controller.terrainMode = mode;
                controller.clearDraft();
                _notifyChanged();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ];
    }

    return [
      ..._buildStateAndDatumPrefix(context, l, colors),
      for (final mode in _terrainObjectModes) ...[
        _chip(
          colors: colors,
          selected: controller.terrainMode == mode,
          label: _terrainModeLabel(l, mode),
          onTap: () {
            if (onTerrainModeSelected != null) {
              onTerrainModeSelected!(mode);
            } else {
              controller.terrainMode = mode;
              controller.clearDraft();
              _notifyChanged();
            }
          },
        ),
        const SizedBox(width: 4),
      ],
      const SizedBox(width: 2),
      _divider(colors),
      const SizedBox(width: 6),
      if (controller.terrainMode == ArchitectTerrainDraftMode.pad) ...[
        Builder(
          builder: (context) {
            final datum = _effectiveDatum();
            final elevUnit = _elevUnit;
            final padAbsMeters = controller.terrainElevation + datum;
            final padAbsDisplay = elevUnit.toUnit(padAbsMeters);
            final padRelDisplay = elevUnit.toUnit(controller.terrainElevation);
            final label = datum.abs() > 1e-4
                ? '${l.architectTerrainElevationLabel} ${padAbsDisplay.toStringAsFixed(2)} ${elevUnit.symbol}'
                : '${l.architectTerrainElevationLabel} ${_formatSignedUnit(padRelDisplay, elevUnit.symbol)}';
            return _numericChip(
              context: context,
              key: const ValueKey('architect-terrain-pad-elevation'),
              colors: colors,
              title: l.architectTerrainElevationLabel,
              label: label,
              initialValue: padAbsDisplay,
              unitLabel: elevUnit.symbol,
              decimals: 3,
              allowNegative: true,
              onSubmitted: (val) {
                final absMeters = elevUnit.fromUnit(val);
                controller.terrainDatumElevation = datum;
                controller.contourAbsoluteElevation = absMeters;
                controller.terrainElevation =
                    double.parse((absMeters - datum).toStringAsFixed(4));
                _notifyChanged();
              },
            );
          },
        ),
        const SizedBox(width: 6),
      ],
      ..._buildDatumAndQuickActionsSuffix(context, l, colors),
    ];
  }

  Future<void> _promptDatumKeypad(
    BuildContext context,
    AppLocalizations l,
    double initialDatumMeters,
  ) async {
    final elevUnit = _elevUnit;
    final initialDisplay = elevUnit.toUnit(initialDatumMeters);
    final res = await BimNumericKeypad.showInputDialog(
      context,
      title: l.architectTerrainDatumDialogTitle,
      initialText: initialDisplay.toStringAsFixed(2),
      unitLabel: elevUnit.symbol,
      decimals: 3,
      allowNegative: true,
    );
    if (res != null) {
      final resMeters = elevUnit.fromUnit(res);
      controller.terrainDatumElevation = resMeters;
      if (controller.contourAbsoluteElevation != 0.0) {
        controller.terrainElevation =
            controller.contourAbsoluteElevation - resMeters;
      } else {
        controller.contourAbsoluteElevation =
            controller.terrainElevation + resMeters;
      }
      onDatumUpdated?.call(resMeters);
      _notifyChanged();
    }
  }

  List<Widget> _buildPathwayControls(
    BuildContext context,
    AppLocalizations l,
    ColorScheme colors,
  ) {
    return [
      _popupChip<ArchitectPavingMaterial>(
        key: const ValueKey('architect-pathway-material'),
        colors: colors,
        label: _pavingMaterialLabel(l, controller.pathwayMaterial),
        values: ArchitectPavingMaterial.values,
        selected: controller.pathwayMaterial,
        itemLabel: (m) => _pavingMaterialLabel(l, m),
        onSelected: (m) {
          controller.pathwayMaterial = m;
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
      _numericChip(
        context: context,
        key: const ValueKey('architect-pathway-width'),
        colors: colors,
        title: l.architectPathwayWidth,
        label:
            '${l.architectPathwayWidth}: ${controller.pathwayWidth.toStringAsFixed(2)} m',
        initialValue: controller.pathwayWidth,
        unitLabel: 'm',
        min: 0.40,
        max: 12.0,
        onSubmitted: (v) {
          controller.pathwayWidth = v.clamp(0.40, 12.0);
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
      _popupChip<ArchitectPathwayCurbMode>(
        key: const ValueKey('architect-pathway-curb'),
        colors: colors,
        label: _curbModeLabel(l, controller.pathwayCurbMode),
        values: ArchitectPathwayCurbMode.values,
        selected: controller.pathwayCurbMode,
        itemLabel: (c) => _curbModeLabel(l, c),
        onSelected: (c) {
          controller.pathwayCurbMode = c;
          _notifyChanged();
        },
      ),
      if (controller.pathwayCurbMode != ArchitectPathwayCurbMode.none) ...[
        const SizedBox(width: 6),
        _numericChip(
          context: context,
          key: const ValueKey('architect-pathway-curb-width'),
          colors: colors,
          title: l.architectPathwayCurbWidth,
          label: '${(controller.pathwayCurbWidth * 100).round()} cm',
          initialValue: controller.pathwayCurbWidth * 100,
          unitLabel: 'cm',
          decimals: 0,
          min: 6,
          max: 35,
          onSubmitted: (v) {
            controller.pathwayCurbWidth = (v / 100.0).clamp(0.06, 0.35);
            _notifyChanged();
          },
        ),
      ],
      const SizedBox(width: 6),
      _chip(
        colors: colors,
        selected: controller.pathwayClosed,
        label: l.architectPathwayClosedPad,
        onTap: () {
          controller.pathwayClosed = !controller.pathwayClosed;
          _notifyChanged();
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
      _numericChip(
        context: context,
        key: const ValueKey('architect-street-width'),
        colors: colors,
        title: l.architectStreetRoadWidth,
        label:
            '${l.architectStreetRoadWidth}: ${controller.streetRoadWidth.toStringAsFixed(2)} m',
        initialValue: controller.streetRoadWidth,
        unitLabel: 'm',
        min: 2.50,
        max: 30.0,
        onSubmitted: (v) {
          controller.streetRoadWidth = v.clamp(2.50, 30.0);
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
      _popupChip<ArchitectRoadMarkingStyle>(
        key: const ValueKey('architect-street-marking'),
        colors: colors,
        label: controller.streetMarkingStyle.label(l),
        values: ArchitectRoadMarkingStyle.values,
        selected: controller.streetMarkingStyle,
        itemLabel: (s) => s.label(l),
        onSelected: (s) {
          controller.streetMarkingStyle = s;
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
      _chip(
        colors: colors,
        selected: controller.streetHasLeftSidewalk,
        label: l.architectStreetSidewalkLeft,
        onTap: () {
          controller.streetHasLeftSidewalk = !controller.streetHasLeftSidewalk;
          _notifyChanged();
        },
      ),
      const SizedBox(width: 4),
      _chip(
        colors: colors,
        selected: controller.streetHasRightSidewalk,
        label: l.architectStreetSidewalkRight,
        onTap: () {
          controller.streetHasRightSidewalk =
              !controller.streetHasRightSidewalk;
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
      _chip(
        colors: colors,
        selected: controller.streetClosed,
        label: l.architectPathwayClosedPad,
        onTap: () {
          controller.streetClosed = !controller.streetClosed;
          _notifyChanged();
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
      _popupChip<ArchitectPlantSpecies>(
        key: const ValueKey('architect-vegetation-species'),
        colors: colors,
        label: _speciesLabel(l, controller.plantSpecies),
        values: ArchitectPlantSpecies.values,
        selected: controller.plantSpecies,
        itemLabel: (s) => _speciesLabel(l, s),
        onSelected: (s) {
          controller.applySpeciesDefaults(s);
          controller.clearDraft();
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
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
            _notifyChanged();
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
            _notifyChanged();
          },
        ),
        const SizedBox(width: 6),
        _numericChip(
          context: context,
          key: const ValueKey('architect-vegetation-crown'),
          colors: colors,
          title: l.architectVegetationCrownDiameter,
          label:
              '${l.architectVegetationCrownDiameter} ${controller.plantCrownDiameter.toStringAsFixed(1)} m',
          initialValue: controller.plantCrownDiameter,
          unitLabel: 'm',
          decimals: 1,
          min: 0.4,
          max: 16.0,
          onSubmitted: (v) {
            controller.plantCrownDiameter = v.clamp(0.4, 16.0);
            _notifyChanged();
          },
        ),
        if (controller.plantPlacementMode ==
            ArchitectVegetationPlacementMode.row) ...[
          const SizedBox(width: 6),
          _numericChip(
            context: context,
            key: const ValueKey('architect-vegetation-spacing'),
            colors: colors,
            title: l.architectVegetationRowSpacing,
            label:
                '${l.architectVegetationRowSpacing}: ${controller.plantRowSpacing.toStringAsFixed(1)} m',
            initialValue: controller.plantRowSpacing,
            unitLabel: 'm',
            decimals: 1,
            min: 0.5,
            max: 25.0,
            onSubmitted: (v) {
              controller.plantRowSpacing = v.clamp(0.5, 25.0);
              _notifyChanged();
            },
          ),
        ],
      ] else ...[
        _numericChip(
          context: context,
          key: const ValueKey('architect-vegetation-hedge-width'),
          colors: colors,
          title: l.architectPathwayWidth,
          label:
              '${l.architectPathwayWidth}: ${controller.hedgeWidth.toStringAsFixed(2)} m',
          initialValue: controller.hedgeWidth,
          unitLabel: 'm',
          min: 0.30,
          max: 2.50,
          onSubmitted: (v) {
            controller.hedgeWidth = v.clamp(0.30, 2.50);
            _notifyChanged();
          },
        ),
      ],
      const SizedBox(width: 6),
      _numericChip(
        context: context,
        key: const ValueKey('architect-vegetation-height'),
        colors: colors,
        title: l.architectVegetationHeight,
        label:
            '${l.architectVegetationHeight}: ${controller.plantHeight.toStringAsFixed(1)} m',
        initialValue: controller.plantHeight,
        unitLabel: 'm',
        decimals: 1,
        min: 0.4,
        max: 24.0,
        onSubmitted: (v) {
          controller.plantHeight = v.clamp(0.4, 24.0);
          _notifyChanged();
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
      _popupChip<ArchitectSiteFencePreset>(
        key: const ValueKey('architect-fence-preset'),
        colors: colors,
        label: _fencePresetLabel(l, controller.fencePreset),
        values: ArchitectSiteFencePreset.values,
        selected: controller.fencePreset,
        itemLabel: (p) => _fencePresetLabel(l, p),
        onSelected: (p) {
          controller.applyFencePresetDefaults(p);
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
      _numericChip(
        context: context,
        key: const ValueKey('architect-fence-height'),
        colors: colors,
        title: l.architectFenceHeight,
        label:
            '${l.architectFenceHeight} ${controller.fenceHeight.toStringAsFixed(2)} m',
        initialValue: controller.fenceHeight,
        unitLabel: 'm',
        min: 0.50,
        max: 4.50,
        onSubmitted: (v) {
          controller.fenceHeight = v.clamp(0.50, 4.50);
          _notifyChanged();
        },
      ),
      const SizedBox(width: 6),
      _numericChip(
        context: context,
        key: const ValueKey('architect-fence-thickness'),
        colors: colors,
        title: l.architectFenceThickness,
        label:
            '${l.architectFenceThickness} ${(controller.fenceThickness * 100).round()} cm',
        initialValue: controller.fenceThickness * 100,
        unitLabel: 'cm',
        decimals: 0,
        min: 12,
        max: 150,
        onSubmitted: (v) {
          controller.fenceThickness = (v / 100.0).clamp(0.12, 1.50);
          _notifyChanged();
        },
      ),
      if (controller.fencePreset != ArchitectSiteFencePreset.rcRetaining &&
          controller.fencePreset != ArchitectSiteFencePreset.gabionRetaining) ...[
        const SizedBox(width: 6),
        _numericChip(
          context: context,
          key: const ValueKey('architect-fence-spacing'),
          colors: colors,
          title: l.architectFencePierSpacing,
          label:
              '${l.architectFencePierSpacing}: ${controller.fencePierSpacing.toStringAsFixed(1)} m',
          initialValue: controller.fencePierSpacing,
          unitLabel: 'm',
          decimals: 1,
          min: 1.20,
          max: 6.00,
          onSubmitted: (v) {
            controller.fencePierSpacing = v.clamp(1.20, 6.00);
            _notifyChanged();
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

  Widget _popupChip<T>({
    required Key key,
    required ColorScheme colors,
    required String label,
    required List<T> values,
    required T selected,
    required String Function(T) itemLabel,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      key: key,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final v in values)
          CheckedPopupMenuItem<T>(
            value: v,
            checked: v == selected,
            child: Text(itemLabel(v)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.secondaryContainer.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: colors.onSecondaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _numericChip({
    required BuildContext context,
    required Key key,
    required ColorScheme colors,
    required String title,
    required String label,
    required double initialValue,
    required String unitLabel,
    int decimals = 2,
    double? min,
    double? max,
    double? stepDelta,
    bool allowNegative = false,
    required ValueChanged<double> onSubmitted,
  }) {
    return ActionChip(
      key: key,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
      onPressed: () async {
        final res = await BimNumericKeypad.showInputDialog(
          context,
          title: title,
          initialText: initialValue.toStringAsFixed(decimals),
          unitLabel: unitLabel,
          decimals: decimals,
          min: min,
          max: max,
          stepDelta: stepDelta,
          allowNegative: allowNegative,
        );
        if (res != null) onSubmitted(res);
      },
    );
  }

  Widget _divider(ColorScheme colors) => Container(
    width: 1,
    height: 22,
    color: colors.outlineVariant,
  );

  static String _formatSignedUnit(double v, String unitSymbol) {
    if (v.abs() < 1e-4) return '±0.00 $unitSymbol';
    return '${v > 0 ? "+" : ""}${v.toStringAsFixed(2)} $unitSymbol';
  }

  static String _terrainModeLabel(
    AppLocalizations l,
    ArchitectTerrainDraftMode mode,
  ) => switch (mode) {
    ArchitectTerrainDraftMode.boundary => l.architectTerrainModeBoundary,
    ArchitectTerrainDraftMode.boundaryRect =>
      l.architectTerrainModeBoundaryRect,
    ArchitectTerrainDraftMode.pickContour => l.architectTerrainModePickContour,
    ArchitectTerrainDraftMode.contour => l.architectTerrainModeContour,
    ArchitectTerrainDraftMode.spot => l.architectTerrainModeSpot,
    ArchitectTerrainDraftMode.pad => l.architectTerrainModePad,
    ArchitectTerrainDraftMode.hole => l.architectTerrainModeHole,
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
