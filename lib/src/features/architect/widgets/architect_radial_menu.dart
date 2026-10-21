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
  final Rect clusterRect;

  const ArchitectRadialLayout(
    this.targets,
    this.badge, [
    this.clusterRect = Rect.zero,
  ]);

  List<Rect> get occupied => [
    badge.inflate(8),
    if (clusterRect != Rect.zero) clusterRect.inflate(6),
    for (final target in targets)
      Rect.fromCenter(center: target, width: 68, height: 68),
  ];

  static ArchitectRadialLayout compute({
    required Size size,
    required Offset center,
    required int count,
    bool hasTitle = false,
  }) {
    if (count == 0) {
      final defaultBadge = Rect.fromLTWH(
        (center.dx - 18).clamp(
          12.0,
          math.max(12.0, size.width - 48).toDouble(),
        ),
        (center.dy - 18).clamp(
          12.0,
          math.max(12.0, size.height - 48).toDouble(),
        ),
        36,
        36,
      );
      return ArchitectRadialLayout(const [], defaultBadge);
    }

    const buttonSize = 52.0;
    const spacing = 8.0;
    const margin = 12.0;
    const titleHeight = 36.0;
    const titleGap = 8.0;

    final n = count;

    // Determine number of rows and columns for a compact multi-row layout.
    // Optimal packing: max 4 columns to fit comfortably on mobile screen widths without overflowing.
    final maxColsPossible = math.max(
      1,
      ((size.width - 2 * margin + spacing) / (buttonSize + spacing)).floor(),
    );
    final maxCols = math.min(maxColsPossible, 4);

    int numRows;
    if (n <= maxCols) {
      numRows = 1;
    } else if (n <= maxCols * 2 && maxCols >= 3) {
      numRows = 2;
    } else {
      numRows = (n / maxCols).ceil();
    }
    numRows = math.max(1, math.min(numRows, n));

    final basePerRow = n ~/ numRows;
    final remainder = n % numRows;

    final maxItemsInAnyRow = basePerRow + (remainder > 0 ? 1 : 0);
    final clusterWidth =
        maxItemsInAnyRow * buttonSize + (maxItemsInAnyRow - 1) * spacing;
    final clusterHeight = numRows * buttonSize + (numRows - 1) * spacing;

    final titleWidth = hasTitle
        ? math
              .min(240.0, math.max(clusterWidth, 120.0).toDouble())
              .clamp(margin, size.width - 2 * margin)
        : 36.0;

    final totalMenuHeight = hasTitle
        ? titleHeight + titleGap + clusterHeight
        : clusterHeight;

    final spaceAbove =
        center.dy - totalMenuHeight - (hasTitle ? 16.0 : 36.0) - margin;
    final spaceBelow =
        (size.height - margin) -
        (center.dy + totalMenuHeight + (hasTitle ? 16.0 : 36.0));

    final bool placeBelow;
    if (spaceAbove >= 60.0) {
      placeBelow = false;
    } else if (spaceBelow >= 60.0) {
      placeBelow = true;
    } else {
      placeBelow = spaceBelow > spaceAbove;
    }

    final double clusterLeft = (center.dx - clusterWidth / 2).clamp(
      margin,
      math.max(margin, size.width - margin - clusterWidth).toDouble(),
    );

    double buttonsTop;
    Rect badgeRect;

    if (hasTitle) {
      final titleLeft = (clusterLeft + (clusterWidth - titleWidth) / 2).clamp(
        margin,
        math.max(margin, size.width - margin - titleWidth).toDouble(),
      );
      if (placeBelow) {
        double badgeTop = (center.dy + 16.0).clamp(
          margin,
          math.max(margin, size.height - margin - totalMenuHeight).toDouble(),
        );
        buttonsTop = badgeTop + titleHeight + titleGap;
        if (buttonsTop + clusterHeight > size.height - margin) {
          final delta = (buttonsTop + clusterHeight) - (size.height - margin);
          buttonsTop -= delta;
          badgeTop -= delta;
        }
        badgeRect = Rect.fromLTWH(titleLeft, badgeTop, titleWidth, titleHeight);
      } else {
        buttonsTop = (center.dy - 16.0 - clusterHeight).clamp(
          margin + titleHeight + titleGap,
          math
              .max(
                margin + titleHeight + titleGap,
                size.height - margin - clusterHeight,
              )
              .toDouble(),
        );
        final badgeTop = buttonsTop - titleGap - titleHeight;
        badgeRect = Rect.fromLTWH(titleLeft, badgeTop, titleWidth, titleHeight);
      }
    } else {
      final anchorX = (center.dx - 18.0).clamp(
        margin,
        math.max(margin, size.width - margin - 36.0).toDouble(),
      );
      final anchorY = (center.dy - 18.0).clamp(
        margin,
        math.max(margin, size.height - margin - 36.0).toDouble(),
      );
      badgeRect = Rect.fromLTWH(anchorX, anchorY, 36.0, 36.0);

      if (placeBelow) {
        buttonsTop = badgeRect.bottom + titleGap;
        if (buttonsTop + clusterHeight > size.height - margin) {
          final delta = (buttonsTop + clusterHeight) - (size.height - margin);
          buttonsTop -= delta;
          if (badgeRect.bottom > buttonsTop - titleGap) {
            badgeRect = Rect.fromLTWH(
              anchorX,
              buttonsTop - titleGap - 36.0,
              36.0,
              36.0,
            );
          }
        }
      } else {
        buttonsTop = badgeRect.top - titleGap - clusterHeight;
        if (buttonsTop < margin) {
          final delta = margin - buttonsTop;
          buttonsTop += delta;
          if (badgeRect.top < buttonsTop + clusterHeight + titleGap) {
            badgeRect = Rect.fromLTWH(
              anchorX,
              buttonsTop + clusterHeight + titleGap,
              36.0,
              36.0,
            );
          }
        }
      }
    }

    badgeRect = Rect.fromLTWH(
      badgeRect.left.clamp(
        margin,
        math.max(margin, size.width - margin - badgeRect.width).toDouble(),
      ),
      badgeRect.top.clamp(
        margin,
        math.max(margin, size.height - margin - badgeRect.height).toDouble(),
      ),
      badgeRect.width,
      badgeRect.height,
    );

    final clusterRect = Rect.fromLTWH(
      clusterLeft,
      buttonsTop,
      clusterWidth,
      clusterHeight,
    );

    final targets = <Offset>[];
    for (int r = 0; r < numRows; r++) {
      final inThisRow = basePerRow + (r < remainder ? 1 : 0);
      final thisRowWidth = inThisRow * buttonSize + (inThisRow - 1) * spacing;
      final rowLeft = clusterLeft + (clusterWidth - thisRowWidth) / 2;

      for (int c = 0; c < inThisRow; c++) {
        final targetX = rowLeft + c * (buttonSize + spacing) + buttonSize / 2;
        final targetY =
            buttonsTop + r * (buttonSize + spacing) + buttonSize / 2;
        targets.add(Offset(targetX, targetY));
      }
    }

    return ArchitectRadialLayout(targets, badgeRect, clusterRect);
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
            if (layout.clusterRect != Rect.zero)
              Positioned.fromRect(
                rect: layout.clusterRect.inflate(6),
                child: IgnorePointer(
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xEE181C26),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0x3300E5FF),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
