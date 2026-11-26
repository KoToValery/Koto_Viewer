// === SECTION: ARCHITECT UNDERLAY HUD BARS & CALIBRATION DIALOGS ===

import 'package:flutter/material.dart';

import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_underlay_models.dart';
import 'architect_numeric_keypad.dart';

/// The underlay HUD keeps drafting actions in reach and uses the ambient theme.
class ArchitectCadUnderlayBar extends StatelessWidget {
  final ArchitectCadUnderlayConfig? config;
  final List<ArchitectCadUnderlayConfig> underlays;
  final bool? isSitePlan;
  final bool isBusy;
  final bool canResetOrientation;
  final VoidCallback onAddUnderlay;
  final ValueChanged<String>? onSelectUnderlay;
  final ValueChanged<(String, bool)>? onToggleUnderlayVisibility;
  final VoidCallback onMove;
  final VoidCallback onOpenScale;
  final VoidCallback? onEditOrientation;
  final VoidCallback? onResetOrientation;
  final void Function(Offset globalPosition)? onOpenContextMenu;

  const ArchitectCadUnderlayBar({
    super.key,
    required this.config,
    this.underlays = const [],
    this.isSitePlan,
    required this.isBusy,
    this.canResetOrientation = false,
    required this.onAddUnderlay,
    this.onSelectUnderlay,
    this.onToggleUnderlayVisibility,
    required this.onMove,
    required this.onOpenScale,
    this.onEditOrientation,
    this.onResetOrientation,
    this.onOpenContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final add = isBusy ? null : onAddUnderlay;
    final items = underlays.isNotEmpty
        ? underlays
        : [?config];
    final cad = config ?? (items.isNotEmpty ? items.first : null);
    final site = isSitePlan ?? (cad?.kind == ArchitectUnderlayKind.geodetic);
    final addTooltip = isSitePlan == null
        ? null
        : (site
              ? l.architectUnderlayAddGeodeticTooltip
              : l.architectUnderlayAddTechnicalTooltip);
    return _UnderlayToolbar(
      children: cad == null
          ? [
              if (isSitePlan != null) _UnderlayRoleBadge(isSitePlan: site),
              _addUnderlayButton(context, add, tooltip: addTooltip),
            ]
          : [
              _UnderlayRoleBadge(
                isSitePlan: site,
                discipline: site ? null : cad.discipline,
              ),
              Flexible(
                child: items.length <= 1 || onSelectUnderlay == null
                    ? _UnderlayName(cad.fileName, visible: cad.visible)
                    : _UnderlayMultiSelector<ArchitectCadUnderlayConfig>(
                        tooltip: l.architectUnderlayChooseCad,
                        enabled: !isBusy,
                        items: items,
                        selectedId: cad.effectiveId,
                        idOf: (item) => item.effectiveId,
                        labelOf: (item) => site
                            ? item.fileName
                            : '${item.discipline.label(l)} · ${item.fileName}',
                        visibleOf: (item) => item.visible,
                        displayName: cad.fileName,
                        selectedVisible: cad.visible,
                        onSelect: onSelectUnderlay!,
                        onToggleVisibility: onToggleUnderlayVisibility,
                      ),
              ),
              _addUnderlayButton(
                context,
                add,
                compact: true,
                tooltip: addTooltip,
              ),
              _action(
                context,
                l.architectSelectionMove,
                AppIconId.move,
                isBusy || !cad.visible ? null : onMove,
              ),
              _action(
                context,
                l.architectUnderlayScale,
                AppIconId.measure,
                isBusy ? null : onOpenScale,
              ),
              if (site && onEditOrientation != null)
                _action(
                  context,
                  l.architectUnderlayEditOrientation,
                  AppIconId.compass,
                  isBusy || !cad.visible ? null : onEditOrientation,
                  buttonKey: const ValueKey(
                    'architect-underlay-edit-orientation',
                  ),
                ),
              if (site && onResetOrientation != null)
                _action(
                  context,
                  l.architectUnderlayResetOrientation,
                  AppIconId.refresh,
                  isBusy || !cad.visible || !canResetOrientation
                      ? null
                      : onResetOrientation,
                  buttonKey: const ValueKey(
                    'architect-underlay-reset-orientation',
                  ),
                ),
              _more(context, isBusy ? null : onOpenContextMenu),
            ],
    );
  }
}

class ArchitectRasterUnderlayBar extends StatelessWidget {
  final List<ArchitectRasterUnderlay> underlays;
  final ArchitectRasterUnderlay? selectedUnderlay;
  final bool? isSitePlan;
  final int calibrationStep;
  final bool isBusy;
  final bool canResetOrientation;
  final VoidCallback onAddUnderlay;
  final ValueChanged<String> onSelectUnderlay;
  final ValueChanged<(String, bool)>? onToggleUnderlayVisibility;
  final VoidCallback onMove;
  final VoidCallback onStartCalibration;
  final VoidCallback onCancelCalibration;
  final VoidCallback? onEditOrientation;
  final VoidCallback? onResetOrientation;
  final void Function(Offset globalPosition)? onOpenContextMenu;

  const ArchitectRasterUnderlayBar({
    super.key,
    required this.underlays,
    required this.selectedUnderlay,
    this.isSitePlan,
    required this.calibrationStep,
    required this.isBusy,
    this.canResetOrientation = false,
    required this.onAddUnderlay,
    required this.onSelectUnderlay,
    this.onToggleUnderlayVisibility,
    required this.onMove,
    required this.onStartCalibration,
    required this.onCancelCalibration,
    this.onEditOrientation,
    this.onResetOrientation,
    this.onOpenContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final raster = selectedUnderlay;
    if (calibrationStep != 0) {
      return _UnderlayToolbar(
        children: [
          Flexible(
            child: Text(
              calibrationStep == 1
                  ? l.architectRasterCalibrateStep1
                  : l.architectRasterCalibrateStep2,
            ),
          ),
          _action(context, l.cancel, AppIconId.close, onCancelCalibration),
        ],
      );
    }

    final add = isBusy ? null : onAddUnderlay;
    final site = isSitePlan ?? (raster?.kind == ArchitectUnderlayKind.geodetic);
    final addTooltip = isSitePlan == null
        ? null
        : (site
              ? l.architectUnderlayAddGeodeticTooltip
              : l.architectUnderlayAddTechnicalTooltip);
    return _UnderlayToolbar(
      children: raster == null
          ? [
              if (isSitePlan != null) _UnderlayRoleBadge(isSitePlan: site),
              _addUnderlayButton(context, add, tooltip: addTooltip),
            ]
          : [
              _UnderlayRoleBadge(
                isSitePlan: site,
                discipline: site ? null : raster.discipline,
              ),
              Flexible(
                child: underlays.length <= 1
                    ? _UnderlayName(raster.fileName, visible: raster.visible)
                    : _UnderlayMultiSelector<ArchitectRasterUnderlay>(
                        tooltip: l.architectRasterChooseUnderlay,
                        enabled: !isBusy,
                        items: underlays,
                        selectedId: raster.id,
                        idOf: (item) => item.id,
                        labelOf: (item) => site
                            ? item.fileName
                            : '${item.discipline.label(l)} · ${item.fileName}',
                        visibleOf: (item) => item.visible,
                        displayName: raster.fileName,
                        selectedVisible: raster.visible,
                        onSelect: onSelectUnderlay,
                        onToggleVisibility: onToggleUnderlayVisibility,
                      ),
              ),
              _addUnderlayButton(
                context,
                add,
                compact: true,
                tooltip: addTooltip,
              ),
              _action(
                context,
                l.architectSelectionMove,
                AppIconId.move,
                isBusy || raster.locked || !raster.visible ? null : onMove,
              ),
              _action(
                context,
                l.architectUnderlayScale,
                AppIconId.measure,
                isBusy || raster.locked || !raster.visible
                    ? null
                    : onStartCalibration,
              ),
              if (site && onEditOrientation != null)
                _action(
                  context,
                  l.architectUnderlayEditOrientation,
                  AppIconId.compass,
                  isBusy || raster.locked || !raster.visible
                      ? null
                      : onEditOrientation,
                  buttonKey: const ValueKey(
                    'architect-underlay-edit-orientation',
                  ),
                ),
              if (site && onResetOrientation != null)
                _action(
                  context,
                  l.architectUnderlayResetOrientation,
                  AppIconId.refresh,
                  isBusy ||
                          raster.locked ||
                          !raster.visible ||
                          !canResetOrientation
                      ? null
                      : onResetOrientation,
                  buttonKey: const ValueKey(
                    'architect-underlay-reset-orientation',
                  ),
                ),
              _more(context, isBusy ? null : onOpenContextMenu),
            ],
    );
  }
}

class _UnderlayRoleBadge extends StatelessWidget {
  final bool isSitePlan;
  final ArchitectTechnicalUnderlayDiscipline? discipline;

  const _UnderlayRoleBadge({required this.isSitePlan, this.discipline});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 650;
    final roleText = isSitePlan
        ? l.architectUnderlayKindGeodetic
        : (discipline != null &&
                  discipline != ArchitectTechnicalUnderlayDiscipline.general
              ? discipline!.label(l)
              : l.architectUnderlayKindTechnical);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: compact ? 6 : 8),
      child: Tooltip(
        message: isSitePlan
            ? l.architectUnderlayKindGeodetic
            : '${l.architectUnderlayKindTechnical}${discipline != null ? ' · ${discipline!.label(l)}' : ''}',
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 7,
            vertical: compact ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: isSitePlan
                ? colors.tertiaryContainer
                : colors.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSitePlan ? Icons.terrain_outlined : Icons.layers_outlined,
                size: 13,
                color: isSitePlan
                    ? colors.onTertiaryContainer
                    : colors.onSecondaryContainer,
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  roleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSitePlan
                        ? colors.onTertiaryContainer
                        : colors.onSecondaryContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnderlayMultiSelector<T> extends StatelessWidget {
  final String tooltip;
  final bool enabled;
  final List<T> items;
  final String selectedId;
  final String Function(T) idOf;
  final String Function(T) labelOf;
  final bool Function(T) visibleOf;
  final String displayName;
  final bool selectedVisible;
  final ValueChanged<String> onSelect;
  final ValueChanged<(String, bool)>? onToggleVisibility;

  const _UnderlayMultiSelector({
    required this.tooltip,
    required this.enabled,
    required this.items,
    required this.selectedId,
    required this.idOf,
    required this.labelOf,
    required this.visibleOf,
    required this.displayName,
    required this.selectedVisible,
    required this.onSelect,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopupMenuButton<String>(
      tooltip: tooltip,
      enabled: enabled,
      onSelected: onSelect,
      itemBuilder: (menuCtx) => [
        for (final item in items)
          PopupMenuItem<String>(
            value: idOf(item),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: idOf(item) == selectedId
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    labelOf(item),
                    overflow: TextOverflow.ellipsis,
                    style: visibleOf(item)
                        ? null
                        : TextStyle(
                            color: Theme.of(
                              menuCtx,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                  ),
                ),
                if (onToggleVisibility != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: visibleOf(item)
                        ? l.architectUnderlayHide
                        : l.architectUnderlayShow,
                    icon: Icon(
                      visibleOf(item)
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 16,
                    ),
                    onPressed: () {
                      onToggleVisibility!((idOf(item), !visibleOf(item)));
                      Navigator.of(menuCtx).pop();
                    },
                  ),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _UnderlayName(displayName, visible: selectedVisible)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

Widget _addUnderlayButton(
  BuildContext context,
  VoidCallback? onPressed, {
  bool compact = false,
  String? tooltip,
}) {
  final l = context.l10n;
  final effectiveTooltip = tooltip ?? l.architectUnderlayAddTooltip;
  const icon = AppIcon(AppIconId.openFile, size: 18);
  if (compact && MediaQuery.sizeOf(context).width < 650) {
    return IconButton(
      tooltip: effectiveTooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
      onPressed: onPressed,
      icon: icon,
    );
  }
  return Tooltip(
    message: effectiveTooltip,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(l.architectUnderlayAdd),
    ),
  );
}

class _UnderlayName extends StatelessWidget {
  final String name;
  final bool visible;
  const _UnderlayName(this.name, {this.visible = true});

  @override
  Widget build(BuildContext context) {
    final style = visible
        ? null
        : TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            decoration: TextDecoration.lineThrough,
          );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: MediaQuery.sizeOf(context).width < 650 ? 6 : 8,
        end: 4,
      ),
      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}

class ArchitectUnderlayCropBar extends StatelessWidget {
  final bool polygon;
  final VoidCallback? onApply;
  final VoidCallback onCancel;

  const ArchitectUnderlayCropBar({
    super.key,
    required this.polygon,
    required this.onApply,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _UnderlayToolbar(
      children: [
        Flexible(
          child: Tooltip(
            message: polygon
                ? l.architectUnderlayMaskPolyPrompt
                : l.architectUnderlayMaskRectPrompt,
            child: _UnderlayName(
              polygon
                  ? l.architectUnderlayPolygonCrop
                  : l.architectUnderlayRectangleCrop,
            ),
          ),
        ),
        if (polygon)
          _action(
            context,
            l.architectUnderlayMaskFinish,
            AppIconId.confirm,
            onApply,
          ),
        _action(context, l.cancel, AppIconId.close, onCancel),
      ],
    );
  }
}

class _UnderlayToolbar extends StatelessWidget {
  final List<Widget> children;
  const _UnderlayToolbar({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 3,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: colors.onSurface),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

Widget _action(
  BuildContext context,
  String label,
  AppIconId icon,
  VoidCallback? onPressed, {
  Key? buttonKey,
}) {
  final colors = Theme.of(context).colorScheme;
  if (MediaQuery.sizeOf(context).width >= 650 && icon != AppIconId.close) {
    return TextButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: colors.onSurface),
      icon: AppIcon(icon, size: 17),
      label: Text(label),
    );
  }
  if (_showCompactLabels(context) &&
      (icon == AppIconId.move || icon == AppIconId.measure)) {
    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
  return IconButton(
    key: buttonKey,
    tooltip: label,
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
    onPressed: onPressed,
    icon: AppIcon(icon, size: 19),
  );
}

bool _showCompactLabels(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 480 &&
    MediaQuery.textScalerOf(context).scale(14) <= 18;

Widget _more(BuildContext context, void Function(Offset)? open) {
  final label = context.l10n.contextMenuMore;
  return Builder(
    builder: (buttonContext) {
      void openMenu() {
        final box = buttonContext.findRenderObject()! as RenderBox;
        open!(box.localToGlobal(box.size.bottomLeft(Offset.zero)));
      }

      final action = open == null ? null : openMenu;
      if (MediaQuery.sizeOf(context).width >= 650 &&
          _showCompactLabels(context)) {
        return Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: action,
            child: Text(label),
          ),
        );
      }
      return IconButton(
        tooltip: label,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
        icon: const AppIcon(AppIconId.moreVertical, size: 19),
        onPressed: action,
      );
    },
  );
}

/// Two-point raster calibration with optional deskew alignment.
Future<({double distanceMeters, ArchitectRasterAlignMode alignMode})?>
showArchitectRasterCalibrationDialog({
  required BuildContext context,
  required double currentMeasuredMeters,
}) {
  final l = context.l10n;
  final controller = TextEditingController(
    text: currentMeasuredMeters.toStringAsFixed(2),
  );
  var alignMode = ArchitectRasterAlignMode.keepAngle;

  return showDialog<
    ({double distanceMeters, ArchitectRasterAlignMode alignMode})
  >(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(l.architectRasterCalibrateDialogTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.architectRasterCalibrateCurrentDistance(
                  currentMeasuredMeters.toStringAsFixed(3),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.none,
                onTap: () => openArchitectNumericKeypad(
                  context: ctx,
                  controller: controller,
                  title: l.architectRasterCalibrateRealDistanceLabel,
                  unitLabel: 'm',
                  decimals: 3,
                  min: .000001,
                ),
                decoration: InputDecoration(
                  labelText: l.architectRasterCalibrateRealDistanceLabel,
                  border: const OutlineInputBorder(),
                  suffixText: 'm',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.architectRasterAlignModeLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              RadioGroup<ArchitectRasterAlignMode>(
                groupValue: alignMode,
                onChanged: (val) {
                  if (val != null) setDialogState(() => alignMode = val);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ArchitectRasterAlignMode>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: ArchitectRasterAlignMode.keepAngle,
                      title: Text(l.architectRasterAlignKeepAngle),
                    ),
                    RadioListTile<ArchitectRasterAlignMode>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: ArchitectRasterAlignMode.horizontal,
                      title: Text(l.architectRasterAlignHorizontal),
                    ),
                    RadioListTile<ArchitectRasterAlignMode>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: ArchitectRasterAlignMode.vertical,
                      title: Text(l.architectRasterAlignVertical),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              final raw = controller.text.trim().replaceAll(',', '.');
              final val = double.tryParse(raw);
              if (val != null && val.isFinite && val > 0.001) {
                Navigator.of(
                  dialogCtx,
                ).pop((distanceMeters: val, alignMode: alignMode));
              }
            },
            child: Text(l.architectRasterCalibrateApply),
          ),
        ],
      ),
    ),
  );
}

/// Shows a quick page selector when importing a multi-page PDF as a raster underlay.
Future<int?> showArchitectPdfPagePickerDialog({
  required BuildContext context,
  required int pageCount,
}) {
  final l = context.l10n;
  var selectedPage = 1;

  return showDialog<int>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(l.architectRasterSelectPdfPageTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.architectRasterPdfPageLabel(selectedPage, pageCount)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: selectedPage > 1
                      ? () => setDialogState(() => selectedPage--)
                      : null,
                  icon: const AppIcon(AppIconId.chevronLeft),
                ),
                Expanded(
                  child: Slider(
                    value: selectedPage.toDouble(),
                    min: 1,
                    max: pageCount.toDouble(),
                    divisions: (pageCount - 1).clamp(1, 500),
                    label: '$selectedPage',
                    onChanged: (v) =>
                        setDialogState(() => selectedPage = v.round()),
                  ),
                ),
                IconButton(
                  onPressed: selectedPage < pageCount
                      ? () => setDialogState(() => selectedPage++)
                      : null,
                  icon: const AppIcon(AppIconId.chevronRight),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(selectedPage),
            child: Text(l.architectRasterImportPdfButton),
          ),
        ],
      ),
    ),
  );
}

/// Displays the primary underlay context menu with Edit, Scale, Mask, and Remove.
Future<String?> showArchitectUnderlayContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required bool isCad,
  required bool visible,
  bool isSitePlan = false,
  bool canMove = true,
  bool canEditGeometry = true,
  bool hasDocument = true,
  bool hasSurvey = false,
  bool canOrientBuilding = false,
  bool canResetOrientation = false,
}) {
  final l = context.l10n;
  return _showUnderlayMenu(context, globalPosition, [
    if (isSitePlan && canOrientBuilding) ...[
      _entry(
        'orient_building',
        AppIconId.compass,
        l.architectUnderlayEditOrientation,
        enabled: visible && (!isCad || hasDocument),
      ),
      _entry(
        'reset_orientation',
        AppIconId.refresh,
        l.architectUnderlayResetOrientation,
        enabled: canResetOrientation && visible && (!isCad || hasDocument),
      ),
    ],
    _entry(
      'position',
      AppIconId.move,
      l.architectSelectionMove,
      enabled: canMove && visible,
    ),
    _entry(
      'scale',
      AppIconId.measure,
      l.architectUnderlayScale,
      enabled: canEditGeometry,
    ),
    _entry('edit', AppIconId.properties, l.architectUnderlaySettings),
    if (isCad)
      _entry('layers', AppIconId.layers, l.layers, enabled: hasDocument),
    _entry(
      'mask',
      AppIconId.crop,
      l.architectUnderlayCrop,
      enabled: canEditGeometry && visible,
    ),
    _entry(
      'rotate',
      AppIconId.rotate,
      l.rotate,
      enabled: canEditGeometry && visible && (!isCad || hasDocument),
    ),
    _entry(
      'visibility',
      visible ? AppIconId.hidden : AppIconId.visible,
      visible ? l.architectUnderlayHide : l.architectUnderlayShow,
    ),
    if (isCad) ...[
      const PopupMenuDivider(),
      _entry('replace', AppIconId.openFile, l.architectCadReplaceAccept),
      _entry('reload', AppIconId.refresh, l.architectCadUnderlayReloadNow),
      if (isSitePlan && hasSurvey)
        _entry('terrain', AppIconId.terrain, l.architectGeodesyApplyToTerrain),
    ] else
      _entry('add', AppIconId.imageAdd, l.architectUnderlayAdd),
    const PopupMenuDivider(),
    _entry('remove', AppIconId.delete, l.delete),
  ]);
}

Future<String?> showArchitectUnderlayMaskMenu({
  required BuildContext context,
  required Offset globalPosition,
  required bool hasMask,
  required bool maskEnabled,
}) {
  final l = context.l10n;
  return _showUnderlayMenu(context, globalPosition, [
    _entry('mask_rect', AppIconId.crop, l.architectUnderlayRectangleCrop),
    _entry('mask_polygon', AppIconId.spline, l.architectUnderlayPolygonCrop),
    if (hasMask) ...[
      _entry(
        'mask_toggle',
        maskEnabled ? AppIconId.hidden : AppIconId.visible,
        maskEnabled ? l.architectUnderlayHideCrop : l.architectUnderlayShowCrop,
      ),
      _entry('mask_clear', AppIconId.delete, l.architectUnderlayRemoveCrop),
    ],
  ]);
}

PopupMenuItem<String> _entry(
  String value,
  AppIconId icon,
  String label, {
  bool enabled = true,
}) => PopupMenuItem<String>(
  value: value,
  enabled: enabled,
  child: ListTile(
    dense: true,
    minLeadingWidth: 20,
    contentPadding: EdgeInsets.zero,
    leading: AppIcon(icon, size: 18),
    title: Text(label),
  ),
);

Future<String?> _showUnderlayMenu(
  BuildContext context,
  Offset globalPosition,
  List<PopupMenuEntry<String>> items,
) {
  final overlay =
      Overlay.of(context, rootOverlay: true).context.findRenderObject()!
          as RenderBox;
  final point = overlay.globalToLocal(globalPosition);
  return showMenu<String>(
    context: context,
    useRootNavigator: true,
    position: RelativeRect.fromSize(point & Size.zero, overlay.size),
    items: items,
  );
}

/// Modal dialog for CAD and raster display and placement settings.
Future<void> showArchitectUnderlayEditDialog({
  required BuildContext context,
  required String title,
  required double initialOpacity,
  required ValueChanged<double> onOpacityChanged,
  bool initialUseOriginalColors = false,
  bool initialUseOriginalLineweights = false,
  ValueChanged<bool>? onUseOriginalColorsChanged,
  ValueChanged<bool>? onUseOriginalLineweightsChanged,
  bool? isVisible,
  ValueChanged<bool>? onVisibilityChanged,
  ArchitectTechnicalUnderlayDiscipline? discipline,
  ValueChanged<ArchitectTechnicalUnderlayDiscipline>? onDisciplineChanged,
  bool? isLockOrigin,
  ValueChanged<bool>? onToggleLockOrigin,
  bool? isLocked,
  VoidCallback? onToggleLock,
  VoidCallback? onRotate,
  VoidCallback? onResetTransform,
}) {
  final l = context.l10n;
  var opacity = initialOpacity;
  var originalColors = initialUseOriginalColors;
  var originalLineweights = initialUseOriginalLineweights;
  var visible = isVisible ?? true;
  var selectedDiscipline = discipline;

  return showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        key: const ValueKey('architect-underlay-properties'),
        title: Row(
          children: [
            const AppIcon(AppIconId.properties, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedDiscipline != null && onDisciplineChanged != null) ...[
                DropdownButtonFormField<ArchitectTechnicalUnderlayDiscipline>(
                  key: const ValueKey('architect-underlay-discipline'),
                  initialValue: selectedDiscipline,
                  decoration: InputDecoration(
                    labelText: l.architectUnderlayDisciplineLabel,
                  ),
                  items: [
                    for (final d in ArchitectTechnicalUnderlayDiscipline.values)
                      DropdownMenuItem(value: d, child: Text(d.label(l))),
                  ],
                  onChanged: (d) {
                    if (d == null) return;
                    setDialogState(() => selectedDiscipline = d);
                    onDisciplineChanged(d);
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (isVisible != null && onVisibilityChanged != null)
                SwitchListTile(
                  key: const ValueKey('architect-underlay-visibility'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectUnderlayShow),
                  value: visible,
                  onChanged: (v) {
                    setDialogState(() => visible = v);
                    onVisibilityChanged(v);
                  },
                ),
              Text(
                '${l.architectRasterOpacityLabel}: ${(opacity * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Slider(
                key: const ValueKey('architect-underlay-opacity'),
                value: opacity.clamp(0.05, 1.0),
                min: 0.05,
                max: 1.0,
                onChanged: (v) {
                  setDialogState(() => opacity = v);
                  onOpacityChanged(v);
                },
              ),
              if (onUseOriginalColorsChanged != null)
                SwitchListTile(
                  key: const ValueKey('architect-underlay-original-colors'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectUnderlayOriginalColors),
                  value: originalColors,
                  onChanged: (value) {
                    setDialogState(() => originalColors = value);
                    onUseOriginalColorsChanged(value);
                  },
                ),
              if (onUseOriginalLineweightsChanged != null)
                SwitchListTile(
                  key: const ValueKey(
                    'architect-underlay-original-lineweights',
                  ),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectUnderlayOriginalLineweights),
                  value: originalLineweights,
                  onChanged: (value) {
                    setDialogState(() => originalLineweights = value);
                    onUseOriginalLineweightsChanged(value);
                  },
                ),
              const Divider(height: 24),
              if (isLockOrigin != null && onToggleLockOrigin != null) ...[
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectCadUnderlayOriginLocked),
                  subtitle: Text(l.architectCadUnderlayOriginLockedTooltip),
                  value: isLockOrigin,
                  onChanged: (v) {
                    onToggleLockOrigin(v);
                    Navigator.of(dialogCtx).pop();
                  },
                ),
              ],
              if (onRotate != null) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    onRotate();
                  },
                  icon: const AppIcon(AppIconId.rotate, size: 16),
                  label: Text(l.rotate),
                ),
                const SizedBox(height: 12),
              ],
              if (isLocked != null && onToggleLock != null) ...[
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectRasterLockPosition),
                  value: isLocked,
                  onChanged: (_) {
                    onToggleLock();
                    Navigator.of(dialogCtx).pop();
                  },
                ),
              ],
              if (onResetTransform != null)
                TextButton(
                  onPressed: onResetTransform,
                  child: Text(l.architectRasterResetTransform),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l.close),
          ),
        ],
      ),
    ),
  );
}
