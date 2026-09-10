import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reading themes for PDF Reflow mode.
enum PdfReflowTheme {
  light,
  sepia,
  dark,
  amoled,
}

extension PdfReflowThemeExtension on PdfReflowTheme {
  String get label {
    switch (this) {
      case PdfReflowTheme.light:
        return 'Light';
      case PdfReflowTheme.sepia:
        return 'Warm Sepia';
      case PdfReflowTheme.dark:
        return 'Dark Charcoal';
      case PdfReflowTheme.amoled:
        return 'Pure Black';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case PdfReflowTheme.light:
        return const Color(0xFFFAF8F5);
      case PdfReflowTheme.sepia:
        return const Color(0xFFF4ECD8);
      case PdfReflowTheme.dark:
        return const Color(0xFF1E2022);
      case PdfReflowTheme.amoled:
        return const Color(0xFF000000);
    }
  }

  Color get textColor {
    switch (this) {
      case PdfReflowTheme.light:
        return const Color(0xFF262626);
      case PdfReflowTheme.sepia:
        return const Color(0xFF433422);
      case PdfReflowTheme.dark:
        return const Color(0xFFE2E8F0);
      case PdfReflowTheme.amoled:
        return const Color(0xFFECEFF1);
    }
  }

  Color get surfaceColor {
    switch (this) {
      case PdfReflowTheme.light:
        return const Color(0xFFFFFFFF);
      case PdfReflowTheme.sepia:
        return const Color(0xFFEAE0C8);
      case PdfReflowTheme.dark:
        return const Color(0xFF2D3238);
      case PdfReflowTheme.amoled:
        return const Color(0xFF141414);
    }
  }

  Color get accentColor {
    switch (this) {
      case PdfReflowTheme.light:
        return const Color(0xFF2563EB);
      case PdfReflowTheme.sepia:
        return const Color(0xFF8D5B18);
      case PdfReflowTheme.dark:
        return const Color(0xFF38BDF8);
      case PdfReflowTheme.amoled:
        return const Color(0xFF60A5FA);
    }
  }
}

/// Font families supported for e-book style reflow reading.
enum PdfReflowFont {
  serif,
  sans,
  mono,
}

extension PdfReflowFontExtension on PdfReflowFont {
  String get label {
    switch (this) {
      case PdfReflowFont.serif:
        return 'Serif (Book)';
      case PdfReflowFont.sans:
        return 'Sans-Serif (Modern)';
      case PdfReflowFont.mono:
        return 'Monospace';
    }
  }

  TextStyle getTextStyle({
    required double fontSize,
    required Color color,
    required double height,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    switch (this) {
      case PdfReflowFont.serif:
        return GoogleFonts.merriweather(
          fontSize: fontSize,
          color: color,
          height: height,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        );
      case PdfReflowFont.sans:
        return GoogleFonts.inter(
          fontSize: fontSize,
          color: color,
          height: height,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        );
      case PdfReflowFont.mono:
        return GoogleFonts.jetBrainsMono(
          fontSize: fontSize * 0.92,
          color: color,
          height: height,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        );
    }
  }
}

/// User customizable reading settings for PDF Reflow.
class PdfReflowSettings {
  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final PdfReflowTheme theme;
  final PdfReflowFont font;
  final TextAlign textAlign;
  final bool isContinuous;

  const PdfReflowSettings({
    this.fontSize = 17.0,
    this.lineHeight = 1.6,
    this.horizontalPadding = 20.0,
    this.theme = PdfReflowTheme.sepia,
    this.font = PdfReflowFont.serif,
    this.textAlign = TextAlign.left,
    this.isContinuous = false,
  });

  PdfReflowSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    PdfReflowTheme? theme,
    PdfReflowFont? font,
    TextAlign? textAlign,
    bool? isContinuous,
  }) {
    return PdfReflowSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      theme: theme ?? this.theme,
      font: font ?? this.font,
      textAlign: textAlign ?? this.textAlign,
      isContinuous: isContinuous ?? this.isContinuous,
    );
  }
}

/// A structured block of text in reflow view (e.g. heading, paragraph).
class PdfReflowBlock {
  final String text;
  final bool isHeading;
  final bool isOcr;

  const PdfReflowBlock({
    required this.text,
    this.isHeading = false,
    this.isOcr = false,
  });
}

/// Extracted and structured content for a single PDF page.
class PdfPageReflowData {
  final int pageNumber;
  final List<PdfReflowBlock> blocks;
  final String rawText;
  final bool isScannedOcr;
  final bool isLoaded;
  final String? errorMessage;

  const PdfPageReflowData({
    required this.pageNumber,
    required this.blocks,
    required this.rawText,
    this.isScannedOcr = false,
    this.isLoaded = true,
    this.errorMessage,
  });

  factory PdfPageReflowData.loading(int pageNumber) {
    return PdfPageReflowData(
      pageNumber: pageNumber,
      blocks: const [],
      rawText: '',
      isLoaded: false,
    );
  }

  factory PdfPageReflowData.empty(int pageNumber, {String? message}) {
    return PdfPageReflowData(
      pageNumber: pageNumber,
      blocks: const [],
      rawText: '',
      isLoaded: true,
      errorMessage: message,
    );
  }
}
