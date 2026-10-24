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
      };
  static IconData icon(BimEditAction action) => switch (action) {
    BimEditAction.move => Icons.open_with_rounded,
    BimEditAction.edit => Icons.edit_outlined,
    BimEditAction.delete => Icons.delete_outline_rounded,
    BimEditAction.duplicate => Icons.copy_all,
    BimEditAction.rotate => Icons.rotate_right_rounded,
    BimEditAction.flip => Icons.flip_rounded,
    BimEditAction.properties => Icons.tune_rounded,
    BimEditAction.split => Icons.call_split,
    BimEditAction.cut => Icons.content_cut,
    BimEditAction.cutOpening => Icons.cut_outlined,
    BimEditAction.offset => Icons.straighten_rounded,
    BimEditAction.newPoint => Icons.adjust,
    BimEditAction.rename => Icons.drive_file_rename_outline_rounded,
    BimEditAction.join => Icons.polyline_outlined,
    BimEditAction.straighten => Icons.square_foot,
    BimEditAction.mirrorMove => Icons.flip,
    BimEditAction.mirrorCopy => Icons.copy_all,
    BimEditAction.schedule => Icons.table_chart_rounded,
    BimEditAction.group => Icons.group_work_outlined,
    BimEditAction.ungroup => Icons.workspaces_outline,
    BimEditAction.editGroup => Icons.edit_note,
    BimEditAction.openView => Icons.visibility_outlined,
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
  final IconData icon;
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
  final IconData? fallback;
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
  Widget build(BuildContext context) {
    if (action != BimEditAction.newPoint && action != BimEditAction.join) {
      return Icon(
        fallback ?? BimEditActions.icon(action!),
        size: size,
        color: color,
      );
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DraftingSymbolPainter(
          action!,
          color ?? IconTheme.of(context).color ?? Colors.black,
        ),
      ),
    );
  }
}

class _DraftingSymbolPainter extends CustomPainter {
  final BimEditAction action;
  final Color color;
  const _DraftingSymbolPainter(this.action, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (action == BimEditAction.newPoint) {
      canvas.drawCircle(const Offset(12, 12), 3, paint);
      final ringPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawCircle(const Offset(12, 12), 7.5, ringPaint);
    } else {
      // Existing halves are solid; the proposed perpendicular junction is dashed.
      canvas.drawLine(const Offset(5, 3), const Offset(5, 11), paint);
      canvas.drawLine(const Offset(21, 19), const Offset(13, 19), paint);
      final dashed = Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.butt;
      for (final distance in [0.0, 3.5, 7.0]) {
        final end = (distance + 1.5).clamp(0.0, 8.0);
        canvas.drawLine(Offset(5, 11 + distance), Offset(5, 11 + end), dashed);
        canvas.drawLine(
          Offset(13 - distance, 19),
          Offset(13 - end, 19),
          dashed,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DraftingSymbolPainter old) =>
      old.action != action || old.color != color;
}
