import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_roof_tool.dart';
import 'architect_roof_number_field.dart';

class ArchitectRoofBar extends StatelessWidget {
  final ArchitectRoofTool tool;
  final ArchitectRoofPlane? selectedRoof;
  final int? selectedEdgeIndex;
  final ValueChanged<AutoRoofType> onAutoRoof;
  final VoidCallback onOpenLayersDialog;
  final VoidCallback? onOpenAssemblyDialog,
      onSwitchEavesEdge,
      onFlipSlopeDirection,
      onSetSelectedEdgeAsEaves;
  final ValueChanged<double>? onSelectedRoofSlopeChanged,
      onSelectedRoofOverhangChanged;
  final ValueChanged<ArchitectRoofQuickValue>? onApplySlope, onApplyOverhang;
  final VoidCallback? onToggleSlopeLocked, onMatchRidgeHeight, onToggleMansard;
  final ValueChanged<double>? onSelectedRoofUpperSlopeChanged,
      onSelectedRoofBreakDistanceChanged;
  final VoidCallback? onFinishPolygon, onUndoDraftPoint, onCancelDraft;
  final int groupCount;
  final ArchitectUnit unit;
  const ArchitectRoofBar({
    super.key,
    required this.tool,
    this.selectedRoof,
    this.selectedEdgeIndex,
    required this.onAutoRoof,
    required this.onOpenLayersDialog,
    this.onOpenAssemblyDialog,
    this.onSwitchEavesEdge,
    this.onFlipSlopeDirection,
    this.onSetSelectedEdgeAsEaves,
    this.onSelectedRoofSlopeChanged,
    this.onSelectedRoofOverhangChanged,
    this.onApplySlope,
    this.onApplyOverhang,
    this.onToggleSlopeLocked,
    this.onMatchRidgeHeight,
    this.onToggleMansard,
    this.onSelectedRoofUpperSlopeChanged,
    this.onSelectedRoofBreakDistanceChanged,
    this.onFinishPolygon,
    this.onUndoDraftPoint,
    this.onCancelDraft,
    this.groupCount = 1,
    this.unit = ArchitectUnit.centimeters,
  });

  String _mode(AppLocalizations l) => switch (tool.drawMode) {
    RoofDrawMode.rectangle => l.architectRoofDrawRect,
    RoofDrawMode.polygon => l.architectRoofDrawPoly,
    RoofDrawMode.multiPitch => l.architectRoofDrawMultiPitch,
    RoofDrawMode.mansard => l.architectRoofDrawMansard,
  };
  @override
  Widget build(BuildContext context) {
    final l = context.l10n, roof = selectedRoof;
    final drafting = roof == null && tool.isDrafting;
    final canFinish =
        drafting &&
        tool.draftPoints.length >= 3 &&
        (tool.drawMode == RoofDrawMode.polygon ||
            tool.drawMode == RoofDrawMode.multiPitch);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Material(
          key: const ValueKey('architect-roof-bar'),
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                if (drafting) ...[
                  Expanded(
                    child: canFinish
                        ? FilledButton.icon(
                            key: const ValueKey('roof-poly-finish-front'),
                            onPressed: onFinishPolygon,
                            icon: const Icon(Icons.check),
                            label: Text(l.architectDimensionFinish),
                          )
                        : Text(
                            l.roofUiPoints(tool.draftPoints.length),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  IconButton(
                    key: const ValueKey('roof-draft-undo'),
                    tooltip: l.undoPoint,
                    onPressed: onUndoDraftPoint,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    key: const ValueKey('roof-draft-cancel'),
                    tooltip: l.cancel,
                    onPressed: onCancelDraft,
                    icon: const Icon(Icons.close),
                  ),
                ] else if (roof == null) ...[
                  Expanded(
                    child: PopupMenuButton<String>(
                      key: const ValueKey('roof-create-menu'),
                      tooltip: l.roofUiMethod,
                      onSelected: (v) {
                        if (v.startsWith('auto:')) {
                          onAutoRoof(
                            AutoRoofType.values.byName(v.substring(5)),
                          );
                        } else {
                          tool.setDrawMode(RoofDrawMode.values.byName(v));
                        }
                      },
                      itemBuilder: (_) => [
                        for (final m in RoofDrawMode.values)
                          CheckedPopupMenuItem(
                            key: ValueKey(
                              'roof-mode-${switch (m) {
                                RoofDrawMode.rectangle => 'rect',
                                RoofDrawMode.polygon => 'poly',
                                RoofDrawMode.multiPitch => 'multipitch',
                                RoofDrawMode.mansard => 'mansard',
                              }}',
                            ),
                            value: m.name,
                            checked: tool.drawMode == m,
                            child: Text(switch (m) {
                              RoofDrawMode.rectangle => l.architectRoofDrawRect,
                              RoofDrawMode.polygon => l.architectRoofDrawPoly,
                              RoofDrawMode.multiPitch =>
                                l.architectRoofDrawMultiPitch,
                              RoofDrawMode.mansard =>
                                l.architectRoofDrawMansard,
                            }),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          enabled: false,
                          child: Text(l.architectRoofAuto),
                        ),
                        for (final t in AutoRoofType.values)
                          PopupMenuItem(
                            key: ValueKey('roof-auto-${t.name}'),
                            value: 'auto:${t.name}',
                            child: Text(t.label(l)),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.draw_outlined, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _mode(l),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('roof-open-assembly'),
                      onPressed: onOpenAssemblyDialog ?? onOpenLayersDialog,
                      icon: const Icon(Icons.layers_outlined, size: 18),
                      label: Text(
                        l.roofUiAssembly,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('roof-slope-menu'),
                      onPressed: () async {
                        final result = await showArchitectRoofNumber(
                          context,
                          label: l.architectRoofSlope,
                          value: roof.slopeDegrees,
                          unit: '°',
                          pitch: true,
                          max: 80,
                          groupCount: groupCount,
                        );
                        if (result != null) {
                          if (onApplySlope != null) {
                            onApplySlope!(result);
                          } else {
                            onSelectedRoofSlopeChanged?.call(result.value);
                          }
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.architectRoofSlope,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${roofNumber(roof.slopeDegrees)}°',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('roof-open-assembly'),
                      onPressed: onOpenAssemblyDialog ?? onOpenLayersDialog,
                      icon: const Icon(Icons.layers_outlined, size: 18),
                      label: Text(
                        l.roofUiAssembly,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                if (roof != null &&
                    selectedEdgeIndex != null &&
                    (selectedEdgeIndex != roof.safeEavesEdgeIndex ||
                        roof.reverseSlope))
                  IconButton(
                    key: const ValueKey('roof-set-eaves-edge'),
                    tooltip: l.architectRoofSetEavesHere,
                    onPressed: onSetSelectedEdgeAsEaves,
                    icon: const Icon(Icons.south),
                  ),
                IconButton(
                  key: const ValueKey('roof-open-layers'),
                  tooltip: l.roofUiSettings,
                  onPressed: onOpenLayersDialog,
                  icon: const Icon(Icons.tune),
                ),
                if (roof != null)
                  PopupMenuButton<String>(
                    key: const ValueKey('roof-actions'),
                    tooltip: l.roofUiDetails,
                    onSelected: (v) => switch (v) {
                      'eaves' => onSetSelectedEdgeAsEaves?.call(),
                      'rotate' => onSwitchEavesEdge?.call(),
                      'flip' => onFlipSlopeDirection?.call(),
                      'mansard' => onToggleMansard?.call(),
                      'lock' => onToggleSlopeLocked?.call(),
                      'ridge' => onMatchRidgeHeight?.call(),
                      _ => null,
                    },
                    itemBuilder: (_) => [
                      if (onSwitchEavesEdge != null)
                        PopupMenuItem(
                          key: const ValueKey('roof-rotate-slope'),
                          value: 'rotate',
                          child: Text(l.architectRoofRotateSlope),
                        ),
                      if (onFlipSlopeDirection != null)
                        PopupMenuItem(
                          key: const ValueKey('roof-flip-slope'),
                          value: 'flip',
                          child: Text(l.architectRoofFlipSlope),
                        ),
                      if (onToggleMansard != null)
                        CheckedPopupMenuItem(
                          key: const ValueKey('roof-toggle-mansard'),
                          value: 'mansard',
                          checked: roof.isMansard,
                          child: Text(l.architectRoofIsMansard),
                        ),
                      if (roof.roofGroupId != null &&
                          onToggleSlopeLocked != null)
                        CheckedPopupMenuItem(
                          key: const ValueKey('roof-toggle-slope-lock'),
                          value: 'lock',
                          checked: roof.isSlopeLocked,
                          child: Text(l.architectRoofLinkedSlopes),
                        ),
                      if (groupCount > 1 && onMatchRidgeHeight != null)
                        PopupMenuItem(
                          key: const ValueKey('roof-match-ridge'),
                          value: 'ridge',
                          child: Text(l.architectRoofMatchRidge),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
