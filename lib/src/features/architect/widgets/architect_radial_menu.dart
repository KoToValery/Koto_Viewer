// === SECTION: ARCHITECT RADIAL CONTEXT MENU ===
import 'dart:math' as math;
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

/// Shared geometry lets nearby drawing readouts avoid the complete menu.
class ArchitectRadialLayout {
  final List<Offset> targets;
  final Rect badge;
  const ArchitectRadialLayout(this.targets, this.badge);

  List<Rect> get occupied => [
    badge.inflate(8),
    for (final target in targets)
      Rect.fromCenter(center: target, width: 68, height: 68),
  ];

  static ArchitectRadialLayout compute({
    required Size size,
    required Offset center,
    required int count,
    bool hasTitle = false,
  }) {
    final n = count;
    const buttonSize = 52.0, margin = 12.0, separation = 60.0;
    final radius = n < 2
        ? 92.0
        : math.max(92.0, separation / (2 * math.sin(math.pi / (2 * (n - 1)))));
    // A full semicircle keeps neighboring targets separate, including edges.
    // Shift the complete fan into view; never clamp buttons individually.
    final nearLeft = center.dx < radius / 2;
    final nearRight = center.dx > size.width - radius / 2;
    final base = nearLeft
        ? -math.pi / 2
        : nearRight
        ? math.pi / 2
        : center.dy < size.height * .38
        ? 0.0
        : math.pi;
    var targets = List<Offset>.generate(n, (i) {
      final angle = base + (n == 1 ? math.pi / 2 : i * math.pi / (n - 1));
      return center + Offset(math.cos(angle), math.sin(angle)) * radius;
    });
    var bounds = Rect.fromCenter(
      center: targets.first,
      width: buttonSize,
      height: buttonSize,
    );
    for (final target in targets.skip(1)) {
      bounds = bounds.expandToInclude(
        Rect.fromCenter(center: target, width: buttonSize, height: buttonSize),
      );
    }
    if (bounds.width > size.width - 2 * margin ||
        bounds.height > size.height - 2 * margin) {
      // Very narrow/short viewports retain separate touch targets in rows.
      final columns = math.max(
        1,
        ((size.width - 2 * margin) / separation).floor(),
      );
      final count = math.min(columns, n);
      targets = List.generate(
        n,
        (i) => Offset(
          margin + buttonSize / 2 + (i % count) * separation,
          margin + buttonSize / 2 + (i ~/ count) * separation,
        ),
      );
    } else {
      double shift(double low, double high, double maximum) => low < margin
          ? margin - low
          : high > maximum - margin
          ? maximum - margin - high
          : 0;
      final delta = Offset(
        shift(bounds.left, bounds.right, size.width),
        shift(bounds.top, bounds.bottom, size.height),
      );
      targets = targets.map((point) => point + delta).toList();
    }
    final titleWidth = !hasTitle
        ? 36.0
        : math.min(240.0, size.width - 2 * margin);
    final titleLeft = (center.dx - titleWidth / 2).clamp(
      margin,
      size.width - margin - titleWidth,
    );
    double titleTop = (center.dy - 18).clamp(
      margin,
      math.max(margin, size.height - margin - 36),
    );
    if (hasTitle) {
      final buttons = targets
          .map(
            (p) => Rect.fromCenter(
              center: p,
              width: buttonSize,
              height: buttonSize,
            ),
          )
          .toList();
      for (final top in [
        titleTop,
        buttons.map((r) => r.top).reduce(math.min) - 44,
        buttons.map((r) => r.bottom).reduce(math.max) + 8,
        margin,
        size.height - margin - 36,
      ]) {
        final clamped = top
            .clamp(margin, math.max(margin, size.height - margin - 36))
            .toDouble();
        final badge = Rect.fromLTWH(titleLeft, clamped, titleWidth, 36);
        if (!buttons.any((r) => r.overlaps(badge))) {
          titleTop = clamped;
          break;
        }
      }
    }
    return ArchitectRadialLayout(
      targets,
      Rect.fromLTWH(titleLeft, titleTop, titleWidth, 36),
    );
  }
}

/// Adaptive fan/radial contextual menu shown on element long-press.
/// Fans away from user's palm and screen edges.
class ArchitectRadialMenu extends StatefulWidget {
  final Offset center;
  final List<ArchitectRadialMenuItem> items;
  final ValueChanged<ArchitectRadialAction> onActionSelected;
  final VoidCallback onDismiss;
  final String? title;

  const ArchitectRadialMenu({
    super.key,
    required this.center,
    required this.items,
    required this.onActionSelected,
    required this.onDismiss,
    this.title,
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
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
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
        );
        final targets = layout.targets;
        final titleLeft = layout.badge.left,
            titleTop = layout.badge.top,
            titleWidth = layout.badge.width;
        final n = widget.items.length;
        return Stack(
          children: [
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
                    height: 36,
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
              _buildRadialButton(item: widget.items[i], target: targets[i]),
          ],
        );
      },
    );
  }

  Widget _buildRadialButton({
    required ArchitectRadialMenuItem item,
    required Offset target,
  }) {
    const btnSize = 52.0;
    return Positioned(
      left: target.dx - btnSize / 2,
      top: target.dy - btnSize / 2,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Material(
          type: MaterialType.transparency,
          child: Tooltip(
            message: item.tooltip ?? item.label,
            child: InkWell(
              key: ValueKey('architect-radial-${item.action.name}'),
              onTap: () => _select(item.action),
              borderRadius: BorderRadius.circular(btnSize / 2),
              child: Container(
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xF21C1E26),
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.85),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 19, color: item.color),
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
