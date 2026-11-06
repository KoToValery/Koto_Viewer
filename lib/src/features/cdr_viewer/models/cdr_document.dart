import 'package:kotoview/src/core/l10n/l10n_extensions.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Canvas Theme for CDR Vector Viewport.
enum CdrCanvasTheme {
  darkCad(Color(0xFF1E1E1E), Color(0xFF2E2E2E)),
  lightStudio(Color(0xFFF5F5F7), Color(0xFFE2E2E6)),
  blueprint(Color(0xFF0D253A), Color(0xFF194364)),
  pureWhite(Color(0xFFFFFFFF), Color(0xFFE0E0E0)),
  checkerboard(Color(0xFF2A2A2A), Color(0xFF383838));

  final Color background;
  final Color gridColor;

  const CdrCanvasTheme(this.background, this.gridColor);

  String localizedLabel(AppLocalizations l) => switch (this) {
    CdrCanvasTheme.darkCad => l.commandOptionDarkCad,
    CdrCanvasTheme.lightStudio => l.commandOptionLightStudio,
    CdrCanvasTheme.blueprint => l.cad3dThemeBlueprint,
    CdrCanvasTheme.pureWhite => l.commandOptionPureWhite,
    CdrCanvasTheme.checkerboard => l.commandOptionTransparencyGrid,
  };

  bool get isDark => background.computeLuminance() < 0.5;
}

/// Parsed CorelDRAW (.cdr) document representation.
class CdrDocument {
  /// Rasterized vector graphics bytes (PNG or BMP) extracted from the CDR container.
  final Uint8List imageBytes;

  /// Width in pixels of the graphic.
  final int? width;

  /// Height in pixels of the graphic.
  final int? height;

  /// Creating CorelDRAW application version (e.g. "CorelDRAW 2022", "CorelDRAW X7").
  final String generator;

  /// Document title if specified in metadata.
  final String? title;

  /// Number of pages in the document.
  final int pageCount;

  /// Total file size in bytes.
  final int fileSizeBytes;

  /// True if modern ZIP-based CorelDRAW container (X4 to 2024), false if legacy RIFF.
  final bool isZipBased;

  const CdrDocument({
    required this.imageBytes,
    this.width,
    this.height,
    required this.generator,
    this.title,
    this.pageCount = 1,
    this.fileSizeBytes = 0,
    required this.isZipBased,
  });

  String get formattedDimensions {
    if (width != null && height != null && width! > 0 && height! > 0) {
      return '$width × $height px';
    }
    return 'Vector Graphics';
  }

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
