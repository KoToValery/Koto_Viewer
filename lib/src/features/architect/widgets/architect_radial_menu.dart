// === SECTION: ARCHITECT RADIAL CONTEXT MENU ===
import 'architect_radial_layout.dart';
export 'architect_radial_layout.dart';
import 'package:flutter/material.dart';
import '../../bim_editing/widgets/bim_edit_actions.dart';
export '../../bim_editing/widgets/bim_edit_actions.dart' show BimEditAction;

typedef ArchitectRadialAction = BimEditAction;

class ArchitectRadialMenuItem {
  final ArchitectRadialAction action;
  final IconData icon;
  final String label;
  final Color color;
  final String? tooltip;

  const ArchitectRadialMenuItem({
    required this.action,
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
  });
}

/// Adaptive fan/radial contextual menu shown on element long-press.
/// Fans away from user's palm and screen edges.
class ArchitectRadialMenu extends StatefulWidget {
  final Offset center;
  final List<ArchitectRadialMenuItem> items;
  final ValueChanged<ArchitectRadialAction> onActionSelected;
  final VoidCallback onDismiss;
  final String? title;
  final List<Rect> elementBounds;

  const ArchitectRadialMenu({
    super.key,
    required this.center,
    required this.items,
    required this.onActionSelected,
    required this.onDismiss,
    this.title,
    this.elementBounds = const [],
  });

  @override
  State<ArchitectRadialMenu> createState() => _ArchitectRadialMenuState();
}

class _ArchitectRadialMenuState extends State<ArchitectRadialMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _select(ArchitectRadialAction action) {
    widget.onActionSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = ArchitectRadialLayout.compute(
          size: constraints.biggest,
          center: widget.center,
          count: widget.items.length,
          hasTitle: widget.title != null,
          elementBounds: widget.elementBounds,
        );
        final targets = layout.targets;
        if (targets.isEmpty) return const SizedBox.shrink();
        final titleLeft = layout.badge.left,
            titleTop = layout.badge.top,
            titleWidth = layout.badge.width;
        final n = widget.items.length;
        final menu = Stack(
          children: [
            if (widget.title == null)
              Positioned.fromRect(
                rect: layout.badge,
                child: const IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      key: ValueKey('architect-radial-title'),
                      width: 3,
                      height: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF00A7B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.title != null)
              Positioned(
                left: titleLeft,
                top: titleTop,
                child: IgnorePointer(
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      key: const ValueKey('architect-radial-title'),
                      padding: widget.title != null
                          ? const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            )
                          : null,
                      width: titleWidth,
                      height: layout.badge.height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: const Color(0xEE1E242C),
                        border: Border.all(
                          color: const Color(0xFF00E5FF),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: widget.title != null
                            ? Tooltip(
                                message: widget.title!,
                                child: Text(
                                  widget.title!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : const ContainerDot(),
                      ),
                    ),
                  ),
                ),
              ),
            for (var i = 0; i < n; i++)
              _buildRadialButton(
                item: widget.items[i],
                target: targets[i],
                buttonSize: layout.buttonSize,
              ),
          ],
        );
        if (layout.contentHeight > constraints.maxHeight) {
          return SingleChildScrollView(
            key: const ValueKey('architect-radial-scroll'),
            child: SizedBox(
              width: constraints.maxWidth,
              height: layout.contentHeight,
              child: menu,
            ),
          );
        }
        return menu;
      },
    );
  }

  Widget _buildRadialButton({
    required ArchitectRadialMenuItem item,
    required Offset target,
    required double buttonSize,
  }) {
    final btnSize = buttonSize;
    return Positioned(
      left: target.dx - btnSize / 2,
      top: target.dy - btnSize / 2,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Material(
          color: const Color(0xF21C1E26),
          shape: CircleBorder(
            side: BorderSide(
              color: item.color.withValues(alpha: .85),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shadowColor: Colors.black26,
          child: Tooltip(
            message: item.tooltip ?? item.label,
            child: InkWell(
              key: ValueKey('architect-radial-${item.action.name}'),
              onTap: () => _select(item.action),
              borderRadius: BorderRadius.circular(btnSize / 2),
              child: SizedBox(
                width: btnSize,
                height: btnSize,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BimEditingSymbol(
                      item.action,
                      fallback: item.icon,
                      size: 19,
                      color: item.color,
                    ),
                    const SizedBox(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContainerDot extends StatelessWidget {
  const ContainerDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
