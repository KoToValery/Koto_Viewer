import 'package:flutter/material.dart';

/// Matches Material control colors to the structural workspace's dark menus.
ThemeData structuralDarkMenuTheme(BuildContext context) {
  final parent = Theme.of(context);
  const colors = ColorScheme.dark(
    primary: Color(0xFF00E5FF),
    onPrimary: Color(0xFF141414),
    secondaryContainer: Color(0xFF294650),
    onSecondaryContainer: Colors.white,
    surface: Color(0xFF1E1E24),
    onSurface: Colors.white,
    onSurfaceVariant: Colors.white70,
    outline: Colors.white54,
  );
  return ThemeData.from(
    colorScheme: colors,
    useMaterial3: parent.useMaterial3,
    textTheme: parent.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    ),
  ).copyWith(platform: parent.platform);
}
