import '../../../core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../scene/bim_element_adapter.dart';

enum BimEditAction {
  move,
  edit,
  delete,
  duplicate,
  rotate,
  flip,
  properties,
  split,
  cut,
  cutOpening,
  offset,
  newPoint,
  rename,
  join,
  straighten,
  mirrorMove,
  mirrorCopy,
  schedule,
  group,
  ungroup,
  editGroup,
  openView,
  chamfer,
  fillet,
  detach,
  attach,
  hide,
  curve,
}

class BimEditActions {
  static String label(BimEditAction action, AppLocalizations l) =>
      switch (action) {
        BimEditAction.move => l.architectRadialMove,
        BimEditAction.edit => l.architectRadialEdit,
        BimEditAction.delete => l.architectRadialDelete,
        BimEditAction.duplicate => l.dragDuplicateAction,
        BimEditAction.rotate => l.architectRadialRotate,
        BimEditAction.flip => l.architectRadialFlip,
        BimEditAction.properties => l.architectRadialProperties,
        BimEditAction.split => l.architectRadialSplit,
        BimEditAction.cut => l.architectRadialCut,
        BimEditAction.cutOpening => l.architectCutOpening,
        BimEditAction.offset => l.offsetAction,
        BimEditAction.newPoint => l.bimNewPoint,
        BimEditAction.rename => l.architectRadialRename,
        BimEditAction.join => l.architectRadialJoin,
        BimEditAction.straighten => l.architectWallStraighten,
        BimEditAction.mirrorMove => l.architectMirrorMove,
        BimEditAction.mirrorCopy => l.architectMirrorCopy,
        BimEditAction.schedule => l.architectZoneScheduleTitle,
        BimEditAction.group => l.bimGroup,
        BimEditAction.ungroup => l.bimUngroup,
        BimEditAction.editGroup => l.bimEditGroup,
        BimEditAction.openView => l.architectOpenView,
        BimEditAction.chamfer => l.architectChamfer,
        BimEditAction.fillet => l.architectFillet,
        BimEditAction.detach => l.architectWallDetach,
        BimEditAction.attach => l.architectWallAttach,
        BimEditAction.hide => l.architectUnderlayHide,
        BimEditAction.curve => l.architectLineCurve,
      };
  static AppIconId icon(BimEditAction action) => switch (action) {
    BimEditAction.move => AppIconId.move,
    BimEditAction.edit => AppIconId.edit,
    BimEditAction.delete => AppIconId.delete,
    BimEditAction.duplicate => AppIconId.duplicate,
    BimEditAction.rotate => AppIconId.rotate,
    BimEditAction.flip => AppIconId.flipHorizontal,
    BimEditAction.properties => AppIconId.properties,
    BimEditAction.split => AppIconId.split,
    BimEditAction.cut => AppIconId.cut,
    BimEditAction.cutOpening => AppIconId.cutOpening,
    BimEditAction.offset => AppIconId.offset,
    BimEditAction.newPoint => AppIconId.newPoint,
    BimEditAction.rename => AppIconId.rename,
    BimEditAction.join => AppIconId.join,
    BimEditAction.straighten => AppIconId.straighten,
    BimEditAction.mirrorMove => AppIconId.mirrorMove,
    BimEditAction.mirrorCopy => AppIconId.mirrorCopy,
    BimEditAction.schedule => AppIconId.zoneSchedule,
    BimEditAction.group => AppIconId.group,
    BimEditAction.ungroup => AppIconId.ungroup,
    BimEditAction.editGroup => AppIconId.editGroup,
    BimEditAction.openView => AppIconId.visible,
    BimEditAction.chamfer => AppIconId.chamfer,
    BimEditAction.fillet => AppIconId.fillet,
    BimEditAction.detach => AppIconId.unlink,
    BimEditAction.attach => AppIconId.link,
    BimEditAction.hide => AppIconId.hidden,
    BimEditAction.curve => AppIconId.roundedCorner,
  };
  static Set<BimEditAction> available(BimElementSnapshot element) {
    if (element.readOnly) return const {};
    final caps = element.capabilities;
    return {
      BimEditAction.properties,
      BimEditAction.delete,
      if (caps.contains(BimEditingCapability.translate)) BimEditAction.move,
      if (caps.contains(BimEditingCapability.duplicate))
        BimEditAction.duplicate,
      if (caps.contains(BimEditingCapability.rotate)) BimEditAction.rotate,
      if (caps.contains(BimEditingCapability.mirror)) BimEditAction.flip,
      if (caps.contains(BimEditingCapability.contour) ||
          caps.contains(BimEditingCapability.endpoints))
        BimEditAction.edit,
      if (caps.contains(BimEditingCapability.offset)) BimEditAction.offset,
      if (caps.contains(BimEditingCapability.contour)) BimEditAction.newPoint,
      if (caps.contains(BimEditingCapability.endpoints)) BimEditAction.join,
    };
  }
}

class BimActionButton extends StatelessWidget {
  const BimActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.tooltip,
    this.action,
  });
  final AppIconId icon;
  final BimEditAction? action;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BimEditingSymbol(action, fallback: icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Shared drafting symbols, independent of map/navigation iconography.
class BimEditingSymbol extends StatelessWidget {
  final BimEditAction? action;
  final AppIconId? fallback;
  final double size;
  final Color? color;
  const BimEditingSymbol(
    this.action, {
    super.key,
    this.fallback,
    this.size = 24,
    this.color,
  });
  @override
  Widget build(BuildContext context) => AppIcon(
        fallback ?? BimEditActions.icon(action!),
        size: size,
        color: color,
      );
    }
