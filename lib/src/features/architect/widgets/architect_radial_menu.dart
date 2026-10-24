import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/services/ui_settings_service.dart';
import '../../bim_editing/models/bim_context_menu_settings.dart';
import '../../bim_editing/widgets/bim_edit_actions.dart';
import 'architect_radial_layout.dart';
export 'architect_radial_layout.dart';
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

/// Stable eight-slot menu. Availability never determines command positions.
class ArchitectRadialMenu extends StatefulWidget {
  final Offset center;
  final List<ArchitectRadialMenuItem> items;
  final ValueChanged<ArchitectRadialAction> onActionSelected;
  final VoidCallback onDismiss;
  final String? title;
  final List<Rect> elementBounds;
  final BimContextMenuSettings? settings;
  final ValueChanged<int>? onSlotSelected;
  const ArchitectRadialMenu({
    super.key,
    required this.center,
    required this.items,
    required this.onActionSelected,
    required this.onDismiss,
    this.title,
    this.elementBounds = const [],
    this.settings,
    this.onSlotSelected,
  });
  @override
  State<ArchitectRadialMenu> createState() => _ArchitectRadialMenuState();
}

class _ArchitectRadialMenuState extends State<ArchitectRadialMenu> {
  int _page = 0;
  String? _presetId;
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<BimContextMenuSettings>(
    valueListenable: UiSettingsService.contextMenu,
    builder: (context, global, _) {
      final settings = widget.settings ?? global;
      if (_presetId != settings.selectedPresetId) {
        _presetId = settings.selectedPresetId;
        _page = 0;
      }
      final pages = settings.pages;
      _page %= pages.length;
      final l =
          context.l10nOrNull ?? lookupAppLocalizations(const Locale('en'));
      final available = {for (final item in widget.items) item.action: item};
      return LayoutBuilder(
        builder: (context, constraints) {
          final layout = ArchitectRadialLayout.compute(
            size: constraints.biggest,
            center: widget.center,
            mode: settings.mode,
            hasTitle: widget.title != null,
            elementBounds: widget.elementBounds,
          );
          Widget button({
            required Offset target,
            required Key key,
            required String label,
            required String tooltip,
            required Widget icon,
            required VoidCallback? onTap,
            Color? color,
          }) => Positioned(
            left: target.dx - layout.buttonSize / 2,
            top: target.dy - layout.buttonSize / 2,
            child: Semantics(
              button: true,
              enabled: onTap != null,
              label: tooltip,
              child: Tooltip(
                message: tooltip,
                child: Material(
                  color: const Color(0xF21C1E26),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      settings.mode == BimContextMenuMode.circle ? 26 : 8,
                    ),
                    side: BorderSide(
                      color: (color ?? const Color(0xFF90A4AE)).withValues(
                        alpha: onTap == null ? .25 : .85,
                      ),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: key,
                    onTap: onTap,
                    child: SizedBox(
                      width: layout.buttonSize,
                      height: layout.buttonSize,
                      child: Opacity(
                        opacity: onTap == null ? .32 : 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            icon,
                            const SizedBox(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final menu = Stack(
            children: [
              if (widget.title != null)
                Positioned.fromRect(
                  rect: layout.badge,
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        widget.title!,
                        key: const ValueKey('architect-radial-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF00A7B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              for (var i = 0; i < 8; i++) ...[
                Builder(
                  builder: (_) {
                    final action = pages[_page][i];
                    final item = available[action];
                    final color = item?.color ?? const Color(0xFF90A4AE);
                    final label = action == null
                        ? l.contextMenuEmpty
                        : BimEditActions.label(action, l);
                    return button(
                      target: layout.targets[i],
                      key: action == null
                          ? ValueKey('architect-radial-empty-$i')
                          : ValueKey('architect-radial-${action.name}'),
                      label: item?.label ?? label,
                      tooltip: widget.onSlotSelected != null
                          ? l.contextMenuAssignHint
                          : item?.tooltip ?? label,
                      color: color,
                      icon: action == null
                          ? const Icon(
                              Icons.add,
                              size: 19,
                              color: Colors.white70,
                            )
                          : BimEditingSymbol(
                              action,
                              fallback: item?.icon,
                              size: 19,
                              color: color,
                            ),
                      onTap: widget.onSlotSelected != null
                          ? () => widget.onSlotSelected!(i)
                          : item == null
                          ? null
                          : () => widget.onActionSelected(action!),
                    );
                  },
                ),
              ],
              button(
                target: layout.moreTarget,
                key: const ValueKey('architect-radial-more'),
                label: _page == 0
                    ? l.contextMenuMore
                    : '${_page + 1}/${pages.length}',
                tooltip: l.contextMenuPage(_page + 1, pages.length),
                icon: const Icon(
                  Icons.more_horiz,
                  size: 19,
                  color: Colors.white,
                ),
                onTap: widget.onSlotSelected != null
                    ? null
                    : () => setState(() => _page = (_page + 1) % pages.length),
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
    },
  );
}
