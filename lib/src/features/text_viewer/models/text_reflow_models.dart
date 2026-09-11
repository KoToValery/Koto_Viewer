import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reading themes for TXT Reflow / E-Book mode.
enum TextReflowTheme {
  light,
  sepia,
  dark,
  amoled,
}

extension TextReflowThemeExtension on TextReflowTheme {
  String get label {
    switch (this) {
      case TextReflowTheme.light:
        return 'Light Paper';
      case TextReflowTheme.sepia:
        return 'Warm Sepia';
      case TextReflowTheme.dark:
        return 'Dark Charcoal';
      case TextReflowTheme.amoled:
        return 'Pure Black';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case TextReflowTheme.light:
        return const Color(0xFFFAF8F5);
      case TextReflowTheme.sepia:
        return const Color(0xFFF4ECD8);
      case TextReflowTheme.dark:
        return const Color(0xFF1E2022);
      case TextReflowTheme.amoled:
        return const Color(0xFF000000);
    }
  }

  Color get textColor {
    switch (this) {
      case TextReflowTheme.light:
        return const Color(0xFF262626);
      case TextReflowTheme.sepia:
        return const Color(0xFF433422);
      case TextReflowTheme.dark:
        return const Color(0xFFE2E8F0);
      case TextReflowTheme.amoled:
        return const Color(0xFFECEFF1);
    }
  }

  Color get surfaceColor {
    switch (this) {
      case TextReflowTheme.light:
        return const Color(0xFFFFFFFF);
      case TextReflowTheme.sepia:
        return const Color(0xFFEAE0C8);
      case TextReflowTheme.dark:
        return const Color(0xFF2D3238);
      case TextReflowTheme.amoled:
        return const Color(0xFF141414);
    }
  }

  Color get accentColor {
    switch (this) {
      case TextReflowTheme.light:
        return const Color(0xFF2563EB);
      case TextReflowTheme.sepia:
        return const Color(0xFF8D5B18);
      case TextReflowTheme.dark:
        return const Color(0xFF38BDF8);
      case TextReflowTheme.amoled:
        return const Color(0xFF60A5FA);
    }
  }
}

/// Fonts supported for e-book style reading.
enum TextReflowFont {
  serif,
  sans,
  mono,
}

extension TextReflowFontExtension on TextReflowFont {
  String get label {
    switch (this) {
      case TextReflowFont.serif:
        return 'Serif (Book)';
      case TextReflowFont.sans:
        return 'Sans-Serif (Modern)';
      case TextReflowFont.mono:
        return 'Monospace (Clean)';
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
      case TextReflowFont.serif:
        return GoogleFonts.merriweather(
          fontSize: fontSize,
          color: color,
          height: height,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        );
      case TextReflowFont.sans:
        return GoogleFonts.inter(
          fontSize: fontSize,
          color: color,
          height: height,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        );
      case TextReflowFont.mono:
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

/// Reading page flow mode: paginated (swipe/tap like Kindle) or continuous vertical scroll.
enum TextReflowMode {
  paginated,
  continuous,
}

extension TextReflowModeExtension on TextReflowMode {
  String get label {
    switch (this) {
      case TextReflowMode.paginated:
        return 'Pages (Swipe)';
      case TextReflowMode.continuous:
        return 'Continuous Scroll';
    }
  }
}

/// Customizable reading settings for TXT Reflow mode.
class TextReflowSettings {
  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final TextReflowTheme theme;
  final TextReflowFont font;
  final TextReflowMode mode;
  final TextAlign textAlign;

  const TextReflowSettings({
    this.fontSize = 17.0,
    this.lineHeight = 1.6,
    this.horizontalPadding = 20.0,
    this.theme = TextReflowTheme.sepia,
    this.font = TextReflowFont.serif,
    this.mode = TextReflowMode.paginated,
    this.textAlign = TextAlign.left,
  });

  TextReflowSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    TextReflowTheme? theme,
    TextReflowFont? font,
    TextReflowMode? mode,
    TextAlign? textAlign,
  }) {
    return TextReflowSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      theme: theme ?? this.theme,
      font: font ?? this.font,
      mode: mode ?? this.mode,
      textAlign: textAlign ?? this.textAlign,
    );
  }
}

enum TextReflowBlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  quote,
  divider,
}

/// A structured block of text in reflow view (e.g. heading, paragraph, quote).
class TextReflowBlock {
  final TextReflowBlockType type;
  final String text;
  final bool isBold;
  final bool isItalic;

  const TextReflowBlock({
    required this.type,
    required this.text,
    this.isBold = false,
    this.isItalic = false,
  });
}

/// Represents a chapter or section in a text document.
class TextReflowChapter {
  final int index;
  final String title;
  final String rawText;
  final List<TextReflowBlock> blocks;
  final int wordCount;

  const TextReflowChapter({
    required this.index,
    required this.title,
    required this.rawText,
    required this.blocks,
    required this.wordCount,
  });
}

/// A mini-page calculated dynamically to fit exact screen dimensions.
class TextReflowPage {
  final int chapterIndex;
  final int pageIndex;
  final int totalPagesInChapter;
  final String chapterTitle;
  final List<TextReflowBlock> blocks;
  final int startBlockIndex;
  final int startCharOffset;
  final String snippet;

  const TextReflowPage({
    required this.chapterIndex,
    required this.pageIndex,
    required this.totalPagesInChapter,
    required this.chapterTitle,
    required this.blocks,
    required this.startBlockIndex,
    required this.startCharOffset,
    required this.snippet,
  });
}

/// Result of paginating a chapter with an anchor.
class TextReflowPaginationResult {
  final List<TextReflowPage> pages;
  final int anchorPageIndex;

  const TextReflowPaginationResult({
    required this.pages,
    required this.anchorPageIndex,
  });
}
