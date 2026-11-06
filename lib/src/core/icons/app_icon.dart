import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_icon_catalog.dart';

export 'app_icon_catalog.dart';

/// A command symbol. Labels belong to the enclosing button or menu entry;
/// an optional standalone label must already be localized by the caller.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.id, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
  });

  /// Bridge for existing data-driven category/renderer objects. Command
  /// descriptors and new call sites should supply a semantic [AppIconId].
  AppIcon.fromMaterial(
    IconData? icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
  }) : id = AppIcons.fromMaterial(icon);

  final AppIconId id;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final dimension = size ?? theme.size ?? 24;
    final foreground = color ?? theme.color ?? Colors.black;
    final effectiveColor = foreground.withValues(
      alpha: foreground.a * (theme.opacity ?? 1),
    );
    final image = SvgPicture.asset(
      id.assetPath,
      width: dimension,
      height: dimension,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      matchTextDirection: const {
        AppIconId.back,
        AppIconId.forward,
        AppIconId.chevronLeft,
        AppIconId.chevronRight,
        AppIconId.firstPage,
        AppIconId.lastPage,
        AppIconId.undo,
        AppIconId.redo,
      }.contains(id),
      placeholderBuilder: (_) => SizedBox.square(dimension: dimension),
    );
    return SizedBox.square(
      dimension: dimension,
      child: textDirection == null
          ? image
          : Directionality(textDirection: textDirection!, child: image),
    );
  }
}

/// Adds a command symbol without changing the menu value or selection marker.
class AppMenuLabel extends StatelessWidget {
  const AppMenuLabel({super.key, required this.icon, required this.child});

  final AppIconId icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(icon, size: 20),
      const SizedBox(width: 8),
      Flexible(child: child),
    ],
  );
}
