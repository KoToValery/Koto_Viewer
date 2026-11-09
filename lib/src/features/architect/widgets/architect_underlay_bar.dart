// === SECTION: ARCHITECT UNDERLAY HUD BARS & CALIBRATION DIALOGS ===

import 'package:flutter/material.dart';

import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_underlay_models.dart';

/// Top/bottom HUD bar for the CAD Underlay (`ArchitectTool.cadUnderlay`) tool.
class ArchitectCadUnderlayBar extends StatelessWidget {
  final ArchitectCadUnderlayConfig? config;
  final int contourCount;
  final int spotPointCount;
  final bool isBusy;
  final VoidCallback onImportCad;
  final VoidCallback onReplaceCad;
  final ValueChanged<bool> onToggleAutoReload;
  final ValueChanged<bool> onToggleLockOrigin;
  final VoidCallback onReloadNow;
  final VoidCallback onOpenDxfLayers;
  final VoidCallback onExtractContours;
  final VoidCallback onApplyToTerrain;
  final VoidCallback onRemoveUnderlay;
  final VoidCallback? onReposition;
  final VoidCallback? onOpenScale;
  final void Function(Offset globalPosition)? onOpenMaskMenu;
  final void Function(Offset globalPosition)? onOpenContextMenu;

  const ArchitectCadUnderlayBar({
    super.key,
    required this.config,
    required this.contourCount,
    required this.spotPointCount,
    this.isBusy = false,
    required this.onImportCad,
    required this.onReplaceCad,
    required this.onToggleAutoReload,
    required this.onToggleLockOrigin,
    required this.onReloadNow,
    required this.onOpenDxfLayers,
    required this.onExtractContours,
    required this.onApplyToTerrain,
    required this.onRemoveUnderlay,
    this.onReposition,
    this.onOpenScale,
    this.onOpenMaskMenu,
    this.onOpenContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cfg = config;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xEE1A222D),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(
                AppIconId.cadUnderlay,
                size: 18,
                color: Color(0xFF4FC3F7),
              ),
              const SizedBox(width: 8),
              if (isBusy) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
              ],
              if (cfg == null) ...[
                FilledButton.icon(
                  onPressed: isBusy ? null : onImportCad,
                  icon: const AppIcon(AppIconId.openFile, size: 16),
                  label: Text(l.architectCadUnderlayImport),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Text(
                    l.architectCadUnderlayEmptyHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cfg.fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      if (cfg.isGeodetic && cfg.detectedCrsName != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cfg.detectedCrsName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l.architectCadUnderlayReplaceTooltip,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onReplaceCad,
                    icon: const AppIcon(AppIconId.openFile, size: 15),
                    label: Text(l.architectCadUnderlayReplace),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: l.architectCadUnderlayAutoReloadTooltip,
                  child: FilterChip(
                    selected: cfg.autoReload,
                    onSelected: isBusy ? null : onToggleAutoReload,
                    label: Text(
                      l.architectCadUnderlayAutoReload,
                      style: const TextStyle(fontSize: 12),
                    ),
                    avatar: const AppIcon(AppIconId.sync, size: 15),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: l.architectCadUnderlayOriginLockedTooltip,
                  child: FilterChip(
                    selected: cfg.lockOrigin,
                    onSelected: isBusy ? null : onToggleLockOrigin,
                    label: Text(
                      l.architectCadUnderlayOriginLocked,
                      style: const TextStyle(fontSize: 12),
                    ),
                    avatar: AppIcon(
                      cfg.lockOrigin ? AppIconId.lock : AppIconId.unlock,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: l.architectCadUnderlayReloadNow,
                  onPressed: isBusy ? null : onReloadNow,
                  icon: const AppIcon(
                    AppIconId.refresh,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenDxfLayers,
                  icon: const AppIcon(AppIconId.layers, size: 15),
                  label: Text(l.architectCadUnderlayLayersFilter),
                ),
                const SizedBox(width: 6),
                if (contourCount > 0 || spotPointCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4E342E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l.architectGeodesyBadge(contourCount),
                      style: const TextStyle(
                        color: Color(0xFFFFCCBC),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: onApplyToTerrain,
                    icon: const AppIcon(AppIconId.terrain, size: 15),
                    label: Text(l.architectGeodesyApplyToTerrain),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onExtractContours,
                    icon: const AppIcon(AppIconId.terrain, size: 15),
                    label: Text(l.architectCadUnderlayDetectGeodesy),
                  ),
                ],
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onReposition,
                  icon: const AppIcon(
                    AppIconId.newPoint,
                    size: 15,
                    color: Color(0xFF00E676),
                  ),
                  label: Text(l.architectUnderlayReposition),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onOpenScale,
                  icon: const AppIcon(AppIconId.measure, size: 15),
                  label: Text(l.architectUnderlayScale),
                ),
                const SizedBox(width: 6),
                Builder(
                  builder: (btnCtx) => OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () {
                            final box =
                                btnCtx.findRenderObject() as RenderBox?;
                            final pos = box?.localToGlobal(
                                  Offset(0, box.size.height),
                                ) ??
                                Offset.zero;
                            onOpenMaskMenu?.call(pos);
                          },
                    icon: AppIcon(
                      cfg.hasActiveMask ? AppIconId.crop : AppIconId.cutOpening,
                      size: 15,
                      color:
                          cfg.hasActiveMask ? const Color(0xFF00E5FF) : null,
                    ),
                    label: Text(
                      cfg.hasActiveMask
                          ? '${l.architectUnderlayMask} ●'
                          : l.architectUnderlayMask,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Builder(
                  builder: (btnCtx) => IconButton(
                    tooltip: l.architectUnderlayContextMenu,
                    onPressed: isBusy
                        ? null
                        : () {
                            final box =
                                btnCtx.findRenderObject() as RenderBox?;
                            final pos = box?.localToGlobal(
                                  Offset(0, box.size.height),
                                ) ??
                                Offset.zero;
                            onOpenContextMenu?.call(pos);
                          },
                    icon: const AppIcon(
                      AppIconId.moreVertical,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: l.architectCadUnderlayRemove,
                  onPressed: isBusy ? null : onRemoveUnderlay,
                  icon: const AppIcon(
                    AppIconId.delete,
                    size: 18,
                    color: Colors.redAccent,
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

/// HUD bar for the Raster Underlay (`ArchitectTool.rasterUnderlay`) tool with 2-point calibration.
class ArchitectRasterUnderlayBar extends StatelessWidget {
  final List<ArchitectRasterUnderlay> underlays;
  final ArchitectRasterUnderlay? selectedUnderlay;
  final int calibrationStep; // 0 = idle, 1 = waiting P1, 2 = waiting P2
  final bool isBusy;
  final VoidCallback onImportRaster;
  final ValueChanged<String> onSelectUnderlay;
  final VoidCallback onStartCalibration;
  final VoidCallback onCancelCalibration;
  final ValueChanged<double> onChangeOpacity;
  final VoidCallback onToggleLock;
  final VoidCallback onRotateCcw;
  final VoidCallback onRotateCw;
  final VoidCallback onResetTransform;
  final VoidCallback onDeleteRaster;
  final VoidCallback? onOpenScale;
  final void Function(Offset globalPosition)? onOpenMaskMenu;
  final void Function(Offset globalPosition)? onOpenContextMenu;

  const ArchitectRasterUnderlayBar({
    super.key,
    required this.underlays,
    required this.selectedUnderlay,
    required this.calibrationStep,
    this.isBusy = false,
    required this.onImportRaster,
    required this.onSelectUnderlay,
    required this.onStartCalibration,
    required this.onCancelCalibration,
    required this.onChangeOpacity,
    required this.onToggleLock,
    required this.onRotateCcw,
    required this.onRotateCw,
    required this.onResetTransform,
    required this.onDeleteRaster,
    this.onOpenScale,
    this.onOpenMaskMenu,
    this.onOpenContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sel = selectedUnderlay;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xEE1A222D),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(
                AppIconId.rasterUnderlay,
                size: 18,
                color: Color(0xFFFFB74D),
              ),
              const SizedBox(width: 8),
              if (calibrationStep > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD84315),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    calibrationStep == 1
                        ? l.architectRasterCalibrateStep1
                        : l.architectRasterCalibrateStep2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onCancelCalibration,
                  icon: const AppIcon(
                    AppIconId.close,
                    size: 16,
                    color: Colors.white70,
                  ),
                  label: Text(
                    l.architectRasterCalibrateCancel,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: isBusy ? null : onImportRaster,
                  icon: const AppIcon(AppIconId.imageAdd, size: 16),
                  label: Text(l.architectRasterUnderlayImport),
                ),
                if (underlays.isEmpty) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Text(
                      l.architectRasterUnderlayEmptyHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
                if (underlays.length > 1) ...[
                  const SizedBox(width: 8),
                  for (final u in underlays)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        selected: u.id == sel?.id,
                        onSelected: (_) => onSelectUnderlay(u.id),
                        label: Text(
                          u.fileName,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                ],
                if (sel != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onStartCalibration,
                    icon: const AppIcon(AppIconId.measure, size: 16),
                    label: Text(l.architectRasterCalibrate2Pt),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${l.architectRasterOpacityLabel}: ${(sel.opacity * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Slider(
                      value: sel.opacity.clamp(0.05, 1.0),
                      min: 0.05,
                      max: 1.0,
                      onChanged: onChangeOpacity,
                    ),
                  ),
                  FilterChip(
                    selected: sel.locked,
                    onSelected: (_) => onToggleLock(),
                    avatar: AppIcon(
                      sel.locked ? AppIconId.lock : AppIconId.unlock,
                      size: 15,
                    ),
                    label: Text(
                      sel.locked
                          ? l.architectRasterUnlockPosition
                          : l.architectRasterLockPosition,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '90° CCW',
                    onPressed: sel.locked ? null : onRotateCcw,
                    icon: const AppIcon(
                      AppIconId.rotateLeft,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                  IconButton(
                    tooltip: '90° CW',
                    onPressed: sel.locked ? null : onRotateCw,
                    icon: const AppIcon(
                      AppIconId.rotate,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                  TextButton(
                    onPressed: sel.locked ? null : onResetTransform,
                    child: Text(l.architectRasterResetTransform),
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (btnCtx) => OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () {
                              final box =
                                  btnCtx.findRenderObject() as RenderBox?;
                              final pos = box?.localToGlobal(
                                    Offset(0, box.size.height),
                                  ) ??
                                  Offset.zero;
                              onOpenMaskMenu?.call(pos);
                            },
                      icon: AppIcon(
                        sel.hasActiveMask
                            ? AppIconId.crop
                            : AppIconId.cutOpening,
                        size: 15,
                        color: sel.hasActiveMask
                            ? const Color(0xFF00E5FF)
                            : null,
                      ),
                      label: Text(
                        sel.hasActiveMask
                            ? '${l.architectUnderlayMask} ●'
                            : l.architectUnderlayMask,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (btnCtx) => IconButton(
                      tooltip: l.architectUnderlayContextMenu,
                      onPressed: isBusy
                          ? null
                          : () {
                              final box =
                                  btnCtx.findRenderObject() as RenderBox?;
                              final pos = box?.localToGlobal(
                                    Offset(0, box.size.height),
                                  ) ??
                                  Offset.zero;
                              onOpenContextMenu?.call(pos);
                            },
                      icon: const AppIcon(
                        AppIconId.moreVertical,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.delete,
                    onPressed: onDeleteRaster,
                    icon: const AppIcon(
                      AppIconId.delete,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the 2-Point Calibration dialog asking for the real-world distance in meters
/// and optional horizontal/vertical deskew alignment.
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
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
              if (val != null && val > 0.001) {
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
  required bool hasMask,
  required bool maskEnabled,
}) {
  final l = context.l10n;
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    ),
    items: [
      if (isCad)
        PopupMenuItem(
          value: 'reposition',
          child: Row(
            children: [
              const AppIcon(
                AppIconId.newPoint,
                size: 18,
                color: Color(0xFF00E676),
              ),
              const SizedBox(width: 8),
              Text(l.architectUnderlayReposition),
            ],
          ),
        ),
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            const AppIcon(
              AppIconId.properties,
              size: 18,
              color: Color(0xFFB388FF),
            ),
            const SizedBox(width: 8),
            Text(l.architectUnderlayEdit),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'scale',
        child: Row(
          children: [
            const AppIcon(
              AppIconId.measure,
              size: 18,
              color: Color(0xFF4FC3F7),
            ),
            const SizedBox(width: 8),
            Text(l.architectUnderlayScale),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'mask',
        child: Row(
          children: [
            const AppIcon(
              AppIconId.crop,
              size: 18,
              color: Color(0xFF00E5FF),
            ),
            const SizedBox(width: 8),
            Text(l.architectUnderlayMask),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'remove',
        child: Row(
          children: [
            const AppIcon(
              AppIconId.delete,
              size: 18,
              color: Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Text(l.delete),
          ],
        ),
      ),
    ],
  );
}

/// Displays submenu for mask options: Rectangular, Polygonal, Toggle, Clear
Future<String?> showArchitectUnderlayMaskMenu({
  required BuildContext context,
  required Offset globalPosition,
  required bool hasMask,
  required bool maskEnabled,
}) {
  final l = context.l10n;
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    ),
    items: [
      PopupMenuItem(
        value: 'mask_rect',
        child: Row(
          children: [
            const AppIcon(
              AppIconId.crop,
              size: 18,
              color: Color(0xFF00E5FF),
            ),
            const SizedBox(width: 8),
            Text(l.architectUnderlayMaskRect),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'mask_polygon',
        child: Row(
          children: [
            const AppIcon(
              AppIconId.spline,
              size: 18,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(width: 8),
            Text(l.architectUnderlayMaskPolygon),
          ],
        ),
      ),
      if (hasMask) ...[
        PopupMenuItem(
          value: 'mask_toggle',
          child: Row(
            children: [
              AppIcon(
                maskEnabled ? AppIconId.hidden : AppIconId.visible,
                size: 18,
                color: Colors.amberAccent,
              ),
              const SizedBox(width: 8),
              Text(l.architectUnderlayMaskToggle),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'mask_clear',
          child: Row(
            children: [
              const AppIcon(
                AppIconId.delete,
                size: 18,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Text(l.architectUnderlayMaskClear),
            ],
          ),
        ),
      ],
    ],
  );
}

/// Dialog allowing user to switch CAD units per meter (meters, mm, cm, inches, custom)
/// or trigger 2-point CAD calibration.
Future<double?> showArchitectCadScaleDialog({
  required BuildContext context,
  required double currentUnitsPerMeter,
}) {
  final l = context.l10n;
  var selectedUnits = currentUnitsPerMeter;
  final customController = TextEditingController(
    text: currentUnitsPerMeter.toStringAsFixed(2),
  );
  var isCustom = (currentUnitsPerMeter - 1.0).abs() > 0.001 &&
      (currentUnitsPerMeter - 1000.0).abs() > 0.001 &&
      (currentUnitsPerMeter - 100.0).abs() > 0.001 &&
      (currentUnitsPerMeter - 39.37).abs() > 0.05;

  return showDialog<double>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const AppIcon(
              AppIconId.measure,
              size: 20,
              color: Color(0xFF4FC3F7),
            ),
            const SizedBox(width: 8),
            Text(l.architectUnderlayCadScaleTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.architectUnderlayCadScaleUnitsLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              RadioListTile<double>(
                dense: true,
                value: 1.0,
                groupValue: isCustom ? null : selectedUnits,
                title: Text(l.architectUnderlayCadScaleMeters),
                onChanged: (v) {
                  setDialogState(() {
                    selectedUnits = v!;
                    isCustom = false;
                  });
                },
              ),
              RadioListTile<double>(
                dense: true,
                value: 1000.0,
                groupValue: isCustom ? null : selectedUnits,
                title: Text(l.architectUnderlayCadScaleMm),
                onChanged: (v) {
                  setDialogState(() {
                    selectedUnits = v!;
                    isCustom = false;
                  });
                },
              ),
              RadioListTile<double>(
                dense: true,
                value: 100.0,
                groupValue: isCustom ? null : selectedUnits,
                title: Text(l.architectUnderlayCadScaleCm),
                onChanged: (v) {
                  setDialogState(() {
                    selectedUnits = v!;
                    isCustom = false;
                  });
                },
              ),
              RadioListTile<double>(
                dense: true,
                value: 39.37,
                groupValue: isCustom ? null : selectedUnits,
                title: Text(l.architectUnderlayCadScaleInches),
                onChanged: (v) {
                  setDialogState(() {
                    selectedUnits = v!;
                    isCustom = false;
                  });
                },
              ),
              RadioListTile<bool>(
                dense: true,
                value: true,
                groupValue: isCustom,
                title: Text(l.architectUnderlayCadScaleCustom),
                onChanged: (_) {
                  setDialogState(() => isCustom = true);
                },
              ),
              if (isCustom)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: customController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Units per Meter',
                      border: OutlineInputBorder(),
                    ),
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
              if (isCustom) {
                final raw = customController.text.trim().replaceAll(',', '.');
                final val = double.tryParse(raw);
                if (val != null && val > 0.00001) {
                  Navigator.of(dialogCtx).pop(val);
                }
              } else {
                Navigator.of(dialogCtx).pop(selectedUnits);
              }
            },
            child: Text(l.applyAction),
          ),
        ],
      ),
    ),
  );
}

/// Modal dialog for editing underlay properties (opacity, rotation, lock, remove).
Future<void> showArchitectUnderlayEditDialog({
  required BuildContext context,
  required String title,
  required double initialOpacity,
  required ValueChanged<double> onOpacityChanged,
  VoidCallback? onOpenLayers,
  bool? isAutoReload,
  ValueChanged<bool>? onToggleAutoReload,
  bool? isLockOrigin,
  ValueChanged<bool>? onToggleLockOrigin,
  bool? isLocked,
  VoidCallback? onToggleLock,
  VoidCallback? onRotateCcw,
  VoidCallback? onRotateCw,
  VoidCallback? onRemove,
}) {
  final l = context.l10n;
  var opacity = initialOpacity;

  return showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const AppIcon(
              AppIconId.properties,
              size: 20,
              color: Color(0xFFB388FF),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l.architectRasterOpacityLabel}: ${(opacity * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Slider(
                value: opacity.clamp(0.05, 1.0),
                min: 0.05,
                max: 1.0,
                onChanged: (v) {
                  setDialogState(() => opacity = v);
                  onOpacityChanged(v);
                },
              ),
              const Divider(height: 24),
              if (onOpenLayers != null) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    onOpenLayers();
                  },
                  icon: const AppIcon(AppIconId.layers, size: 16),
                  label: Text(l.architectCadUnderlayLayersFilter),
                ),
                const SizedBox(height: 12),
              ],
              if (isAutoReload != null && onToggleAutoReload != null) ...[
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectCadUnderlayAutoReload),
                  subtitle: Text(l.architectCadUnderlayAutoReloadTooltip),
                  value: isAutoReload,
                  onChanged: (v) {
                    onToggleAutoReload(v);
                    Navigator.of(dialogCtx).pop();
                  },
                ),
              ],
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
              if (onRotateCcw != null && onRotateCw != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          onRotateCcw();
                        },
                        icon: const AppIcon(AppIconId.rotateLeft, size: 16),
                        label: const Text('90° CCW'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          onRotateCw();
                        },
                        icon: const AppIcon(AppIconId.rotate, size: 16),
                        label: const Text('90° CW'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (isLocked != null && onToggleLock != null) ...[
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isLocked
                        ? l.architectRasterLockPosition
                        : l.architectRasterUnlockPosition,
                  ),
                  value: isLocked,
                  onChanged: (_) {
                    onToggleLock();
                    Navigator.of(dialogCtx).pop();
                  },
                ),
              ],
              if (onRemove != null) ...[
                const Divider(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                  ),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    onRemove();
                  },
                  icon: const AppIcon(AppIconId.delete, size: 16),
                  label: Text(l.delete),
                ),
              ],
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
