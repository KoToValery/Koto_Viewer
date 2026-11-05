import 'architect_dialog.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

class ArchitectPropertiesEditorHandle {
  bool Function()? validate;
  bool Function()? isDirty;
}

class _PropertiesLayout extends InheritedWidget {
  final ValueChanged<double>? onDockWidth;
  final ValueChanged<EdgeInsets>? onInsets;
  const _PropertiesLayout({
    required super.child,
    this.onDockWidth,
    this.onInsets,
  });
  @override
  bool updateShouldNotify(_PropertiesLayout oldWidget) =>
      onDockWidth != oldWidget.onDockWidth;
}

/// Transitional adapter for existing forms; their model commands stay intact.
class ArchitectPropertiesDialog extends StatelessWidget {
  final Widget title, content;
  final List<Widget> actions;
  final VoidCallback? onSave;
  final EdgeInsets? insetPadding;
  final bool Function()? isDirty;
  const ArchitectPropertiesDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.insetPadding,
    this.onSave,
    this.isDirty,
  });
  @override
  Widget build(BuildContext context) => ArchitectPropertiesShell(
    title: title is Text
        ? (title as Text).data ?? context.l10n.architectProperties
        : context.l10n.architectProperties,
    isDirty: isDirty,
    onSave: onSave,
    initiallyExpanded: true,
    content: Padding(padding: const EdgeInsets.all(16), child: content),
    actions: actions,
  );
}

/// Shared, touch-first chrome for every architectural property editor.
class ArchitectPropertiesShell extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget content;
  final List<Widget> actions;
  final bool Function()? isDirty;
  final bool initiallyExpanded;
  final Widget? navigation;
  final VoidCallback? onSave;
  const ArchitectPropertiesShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    required this.actions,
    this.navigation,
    this.onSave,
    this.isDirty,
    this.initiallyExpanded = false,
  });

  static ArchitectPropertiesShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<ArchitectPropertiesShellState>();

  @override
  State<ArchitectPropertiesShell> createState() =>
      ArchitectPropertiesShellState();
}

class ArchitectPropertiesShellState extends State<ArchitectPropertiesShell> {
  late bool expanded =
      widget.initiallyExpanded && MediaQuery.sizeOf(context).width < 1000;
  bool _allowPop = false;
  double? _reportedDock;
  EdgeInsets? _reportedInsets;
  void expand() {
    // Automatic expansion is for touch layouts. Desktop keeps its drawing dock.
    if (MediaQuery.sizeOf(context).width >= 1000) return;
    if (!expanded) setState(() => expanded = true);
  }

  Future<void> requestClose() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (widget.isDirty?.call() ?? false) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => architectAlertDialog(
          title: Text(ctx.l10n.propertiesUnsaved),
          content: Text(ctx.l10n.propertiesUnsavedHelp),
          actions: [
            if (widget.onSave != null)
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx, false);
                  widget.onSave!();
                },
                child: Text(ctx.l10n.save),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.propertiesStay),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.propertiesDiscard),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final original = Theme.of(context);
    final dark = original.brightness == Brightness.dark;
    final scheme = original.colorScheme.copyWith(
      surface: dark ? const Color(0xff20242b) : Colors.white,
      onSurface: dark ? const Color(0xffe6e8eb) : const Color(0xff20252d),
      onSurfaceVariant: dark
          ? const Color(0xffb3bac5)
          : const Color(0xff586270),
      outline: dark ? const Color(0xff505965) : const Color(0xffb9c0ca),
      surfaceTint: Colors.transparent,
    );
    final theme = original.copyWith(
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xff292e36) : const Color(0xfff7f8fa),
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
    return Theme(
      data: theme,
      child: PopScope(
        canPop: _allowPop || widget.isDirty == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            if (expanded && MediaQuery.viewInsetsOf(context).bottom == 0) {
              setState(() => expanded = false);
            } else {
              requestClose();
            }
          }
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              final full =
                  expanded ||
                  constraints.maxHeight < 600 ||
                  MediaQuery.viewInsetsOf(context).bottom > 0;
              final height = full || wide
                  ? constraints.maxHeight
                  : constraints.maxHeight * .60;
              final dock = wide && !expanded ? 400.0 : 0.0;
              final insets = EdgeInsets.only(
                right: dock,
                bottom: !wide && !full
                    ? height + MediaQuery.paddingOf(context).bottom
                    : 0,
              );
              if (_reportedInsets != insets) {
                _reportedInsets = insets;
                final report = context
                    .dependOnInheritedWidgetOfExactType<_PropertiesLayout>()
                    ?.onInsets;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) report?.call(insets);
                });
              }
              if (_reportedDock != dock) {
                _reportedDock = dock;
                final report = context
                    .dependOnInheritedWidgetOfExactType<_PropertiesLayout>()
                    ?.onDockWidth;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) report?.call(dock);
                });
              }
              final panel = Align(
                alignment: wide
                    ? Alignment.centerRight
                    : Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: wide && !expanded ? 400 : constraints.maxWidth,
                  height: height,
                  child: Material(
                    key: const ValueKey('properties-surface'),
                    color: scheme.surface,
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: .12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(full || wide ? 0 : 12),
                      ),
                      side: BorderSide(
                        color: scheme.outline.withValues(alpha: .4),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragEnd: (details) {
                            setState(
                              () =>
                                  expanded = (details.primaryVelocity ?? 0) < 0,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (widget.subtitle != null)
                                        Text(
                                          widget.subtitle!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  key: const ValueKey('properties-expand'),
                                  tooltip: full
                                      ? context.l10n.propertiesCollapse
                                      : context.l10n.propertiesExpand,
                                  onPressed: () =>
                                      setState(() => expanded = !expanded),
                                  icon: AppIcon.fromMaterial(
                                    full
                                        ? Icons.close_fullscreen
                                        : Icons.open_in_full,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  key: const ValueKey('properties-close'),
                                  tooltip: context.l10n.close,
                                  onPressed: requestClose,
                                  icon: const AppIcon(
                                    AppIconId.close, size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.navigation != null) widget.navigation!,
                        const Divider(height: 1),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: widget.content,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                          child: OverflowBar(
                            alignment: MainAxisAlignment.end,
                            spacing: 8,
                            overflowSpacing: 4,
                            children: widget.actions,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: requestClose,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  panel,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// No modal barrier: the visible drawing remains available for pan and zoom.
Future<T?> showArchitectProperties<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  ValueChanged<double>? onDockWidth,
  ValueChanged<EdgeInsets>? onInsets,
}) => Navigator.of(context)
    .push<T>(
      _PropertiesRoute<T>(
        (context) => _PropertiesLayout(
          onDockWidth: onDockWidth,
          onInsets: onInsets,
          child: Builder(builder: builder),
        ),
      ),
    )
    .whenComplete(() {
      onDockWidth?.call(0);
      onInsets?.call(EdgeInsets.zero);
    });

class _PropertiesRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  _PropertiesRoute(this.builder);
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);
  @override
  Widget buildModalBarrier() => const IgnorePointer(child: SizedBox.expand());
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: builder(context),
  );
}
