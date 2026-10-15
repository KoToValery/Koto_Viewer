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
  offset,
  newPoint,
  rename,
  join,
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
        BimEditAction.offset => l.offsetAction,
        BimEditAction.newPoint => l.bimNewPoint,
        BimEditAction.rename => l.architectRadialRename,
        BimEditAction.join => l.architectRadialJoin,
      };
  static IconData icon(BimEditAction action) => switch (action) {
    BimEditAction.move => Icons.open_with_rounded,
    BimEditAction.edit => Icons.edit_outlined,
    BimEditAction.delete => Icons.delete_outline_rounded,
    BimEditAction.duplicate => Icons.copy_all,
    BimEditAction.rotate => Icons.rotate_right_rounded,
    BimEditAction.flip => Icons.flip_rounded,
    BimEditAction.properties => Icons.tune_rounded,
    BimEditAction.split => Icons.content_cut,
    BimEditAction.offset => Icons.straighten_rounded,
    BimEditAction.newPoint => Icons.add_location_alt_outlined,
    BimEditAction.rename => Icons.drive_file_rename_outline_rounded,
    BimEditAction.join => Icons.call_merge,
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
  });
  final IconData icon;
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
            Icon(icon, size: 15, color: color),
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
