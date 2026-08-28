import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum EbookFormat { epub, fb2, mobi }

enum EbookThemeMode {
  light,
  sepia,
  dark,
  amoled,
}

extension EbookThemeModeExtension on EbookThemeMode {
  String get label {
    switch (this) {
      case EbookThemeMode.light:
        return 'Light';
      case EbookThemeMode.sepia:
        return 'Warm Sepia';
      case EbookThemeMode.dark:
        return 'Dark Charcoal';
      case EbookThemeMode.amoled:
        return 'Pure Black';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case EbookThemeMode.light:
        return const Color(0xFFFAF8F5);
      case EbookThemeMode.sepia:
        return const Color(0xFFF4ECD8);
      case EbookThemeMode.dark:
        return const Color(0xFF1E2022);
      case EbookThemeMode.amoled:
        return const Color(0xFF000000);
    }
  }

  Color get textColor {
    switch (this) {
      case EbookThemeMode.light:
        return const Color(0xFF262626);
      case EbookThemeMode.sepia:
        return const Color(0xFF433422);
      case EbookThemeMode.dark:
        return const Color(0xFFE2E8F0);
      case EbookThemeMode.amoled:
        return const Color(0xFFECEFF1);
    }
  }

  Color get surfaceColor {
    switch (this) {
      case EbookThemeMode.light:
        return const Color(0xFFFFFFFF);
      case EbookThemeMode.sepia:
        return const Color(0xFFEAE0C8);
      case EbookThemeMode.dark:
        return const Color(0xFF2D3238);
      case EbookThemeMode.amoled:
        return const Color(0xFF141414);
    }
  }

  Color get accentColor {
    switch (this) {
      case EbookThemeMode.light:
        return const Color(0xFF2563EB);
      case EbookThemeMode.sepia:
        return const Color(0xFF8D5B18);
      case EbookThemeMode.dark:
        return const Color(0xFF38BDF8);
      case EbookThemeMode.amoled:
        return const Color(0xFF60A5FA);
    }
  }
}

enum EbookFontFamily {
  serif,
  sans,
  monospace,
}

extension EbookFontFamilyExtension on EbookFontFamily {
  String get label {
    switch (this) {
      case EbookFontFamily.serif:
        return 'Serif (Book)';
      case EbookFontFamily.sans:
        return 'Sans-Serif (Modern)';
      case EbookFontFamily.monospace:
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
      case EbookFontFamily.serif:
        return GoogleFonts.merriweather(
          fontSize: fontSize,
          color: color,
          height: height,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        );
      case EbookFontFamily.sans:
        return GoogleFonts.inter(
          fontSize: fontSize,
          color: color,
          height: height,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        );
      case EbookFontFamily.monospace:
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

class EbookSettings {
  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final EbookThemeMode themeMode;
  final EbookFontFamily fontFamily;
  final TextAlign textAlign;

  const EbookSettings({
    this.fontSize = 17.0,
    this.lineHeight = 1.65,
    this.horizontalPadding = 20.0,
    this.themeMode = EbookThemeMode.sepia,
    this.fontFamily = EbookFontFamily.serif,
    this.textAlign = TextAlign.left,
  });

  EbookSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    EbookThemeMode? themeMode,
    EbookFontFamily? fontFamily,
    TextAlign? textAlign,
  }) {
    return EbookSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      themeMode: themeMode ?? this.themeMode,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: textAlign ?? this.textAlign,
    );
  }
}

class EbookMetadata {
  final String title;
  final List<String> authors;
  final String? description;
  final String? language;
  final String? publisher;
  final String? publicationDate;
  final String? genre;
  final Uint8List? coverBytes;

  const EbookMetadata({
    required this.title,
    this.authors = const [],
    this.description,
    this.language,
    this.publisher,
    this.publicationDate,
    this.genre,
    this.coverBytes,
  });

  String get authorString => authors.isNotEmpty ? authors.join(', ') : 'Unknown Author';
}

enum EbookBlockType {
  heading1,
  heading2,
  heading3,
  paragraph,
  quote,
  epigraph,
  poem,
  image,
  divider,
}

class EbookBlock {
  final EbookBlockType type;
  final String text;
  final String? imageKey;
  final Uint8List? imageBytes;
  final bool isBold;
  final bool isItalic;

  const EbookBlock({
    required this.type,
    this.text = '',
    this.imageKey,
    this.imageBytes,
    this.isBold = false,
    this.isItalic = false,
  });
}

class EbookChapter {
  final int index;
  final String title;
  final String rawText;
  final List<EbookBlock> blocks;
  final int wordCount;

  const EbookChapter({
    required this.index,
    required this.title,
    required this.rawText,
    required this.blocks,
    required this.wordCount,
  });
}

class EbookBook {
  final String title;
  final String filePath;
  final EbookFormat format;
  final EbookMetadata metadata;
  final List<EbookChapter> chapters;
  final Map<String, Uint8List> images;
  final int totalWordCount;

  const EbookBook({
    required this.title,
    required this.filePath,
    required this.format,
    required this.metadata,
    required this.chapters,
    this.images = const {},
    required this.totalWordCount,
  });

  int get chapterCount => chapters.length;

  int get estimatedReadTimeMinutes => (totalWordCount / 200).ceil();
}
