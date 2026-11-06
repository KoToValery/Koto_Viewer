import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';

/// Keeps assertions valid for both application SVG commands and framework-owned
/// Material controls (for example an automatically inserted back button).
Finder findCommandIcon(Object? icon, {bool skipOffstage = true}) {
  AppIconId? id;
  if (icon is AppIconId) {
    id = icon;
  } else if (icon is IconData) {
    try {
      id = AppIcons.fromMaterial(icon);
    } on ArgumentError {
      // Test fixtures may include a framework glyph outside the app catalogue.
    }
  }
  return find.byWidgetPredicate(
    (widget) =>
        (widget is AppIcon && id != null && widget.id == id) ||
        (widget is Icon && widget.icon == icon),
    description: 'command icon $icon',
    skipOffstage: skipOffstage,
  );
}

Finder findCommandWidgetWithIcon(Type type, Object icon) =>
    find.ancestor(of: findCommandIcon(icon), matching: find.byType(type));
