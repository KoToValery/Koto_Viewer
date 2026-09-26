import 'dart:typed_data';
import 'package:flutter/widgets.dart';

enum ComicFitMode {
  fitWidth,
  fitPage,
  fitHeight,
}

extension ComicFitModeExtension on ComicFitMode {
  String get label {
    switch (this) {
      case ComicFitMode.fitWidth:
        return 'Fit Width';
      case ComicFitMode.fitPage:
        return 'Fit Page';
      case ComicFitMode.fitHeight:
        return 'Fit Height';
    }
  }

  BoxFit get boxFit {
    switch (this) {
      case ComicFitMode.fitWidth:
        return BoxFit.fitWidth;
      case ComicFitMode.fitPage:
        return BoxFit.contain;
      case ComicFitMode.fitHeight:
        return BoxFit.fitHeight;
    }
  }
}

enum ComicReadingMode {
  leftToRight,
  rightToLeft, // Manga mode
  verticalContinuous, // Webtoon mode
}

extension ComicReadingModeExtension on ComicReadingMode {
  String get label {
    switch (this) {
      case ComicReadingMode.leftToRight:
        return 'Left to Right (Western)';
      case ComicReadingMode.rightToLeft:
        return 'Right to Left (Manga)';
      case ComicReadingMode.verticalContinuous:
        return 'Vertical Scroll (Webtoon)';
    }
  }

  String get shortLabel {
    switch (this) {
      case ComicReadingMode.leftToRight:
        return 'LTR';
      case ComicReadingMode.rightToLeft:
        return 'Manga';
      case ComicReadingMode.verticalContinuous:
        return 'Webtoon';
    }
  }
}

class ComicPage {
  final int pageIndex;
  final String fileName;
  final Uint8List bytes;

  const ComicPage({
    required this.pageIndex,
    required this.fileName,
    required this.bytes,
  });
}

class ComicMetadata {
  final String title;
  final String? series;
  final String? number;
  final String? summary;
  final String? writer;
  final String? penciller;
  final String? genre;
  final int? year;
  final int? month;
  final String? publisher;
  final bool isManga;
  final int pageCount;

  const ComicMetadata({
    required this.title,
    this.series,
    this.number,
    this.summary,
    this.writer,
    this.penciller,
    this.genre,
    this.year,
    this.month,
    this.publisher,
    this.isManga = false,
    required this.pageCount,
  });
}

class ComicBook {
  final String title;
  final String filePath;
  final List<ComicPage> pages;
  final ComicMetadata metadata;

  const ComicBook({
    required this.title,
    required this.filePath,
    required this.pages,
    required this.metadata,
  });

  int get pageCount => pages.length;
}

enum ComicParseStage {
  opening,
  reading,
  indexing,
  extractingStructure,
  extractingPage,
  finalizing,
}

class ComicParseProgress {
  final double progress;
  final String status;
  final ComicParseStage? stage;
  final String? sizeMb;
  final int? currentPage;
  final int? totalPages;

  const ComicParseProgress({
    required this.progress,
    required this.status,
    this.stage,
    this.sizeMb,
    this.currentPage,
    this.totalPages,
  });
}

/// Thrown when a comic book archive format (such as proprietary RAR or RAR5)
/// cannot be extracted by the built-in decompressor.
class UnsupportedComicArchiveException implements Exception {
  final bool isRar5;
  final bool isRar;
  final String message;

  const UnsupportedComicArchiveException({
    this.isRar5 = false,
    this.isRar = false,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Configuration model for Comic Autoplay / Automated Page Turning.
class ComicAutoplayConfig {
  /// Duration in seconds per page in paged modes (LTR / Manga RTL).
  final double intervalSeconds;

  /// Continuous scrolling speed in pixels per second for Webtoon mode.
  final double webtoonScrollSpeed;

  /// Whether to loop back to the beginning when reaching the end of the comic.
  final bool loop;

  /// Whether to automatically pause autoplay countdown when zoomed in.
  final bool pauseOnZoom;

  const ComicAutoplayConfig({
    this.intervalSeconds = 5.0,
    this.webtoonScrollSpeed = 60.0,
    this.loop = false,
    this.pauseOnZoom = true,
  });

  ComicAutoplayConfig copyWith({
    double? intervalSeconds,
    double? webtoonScrollSpeed,
    bool? loop,
    bool? pauseOnZoom,
  }) {
    return ComicAutoplayConfig(
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      webtoonScrollSpeed: webtoonScrollSpeed ?? this.webtoonScrollSpeed,
      loop: loop ?? this.loop,
      pauseOnZoom: pauseOnZoom ?? this.pauseOnZoom,
    );
  }

  Map<String, dynamic> toJson() => {
    'intervalSeconds': intervalSeconds,
    'webtoonScrollSpeed': webtoonScrollSpeed,
    'loop': loop,
    'pauseOnZoom': pauseOnZoom,
  };

  factory ComicAutoplayConfig.fromJson(Map<String, dynamic> json) => ComicAutoplayConfig(
    intervalSeconds: (json['intervalSeconds'] as num?)?.toDouble() ?? 5.0,
    webtoonScrollSpeed: (json['webtoonScrollSpeed'] as num?)?.toDouble() ?? 60.0,
    loop: json['loop'] as bool? ?? false,
    pauseOnZoom: json['pauseOnZoom'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicAutoplayConfig &&
          runtimeType == other.runtimeType &&
          intervalSeconds == other.intervalSeconds &&
          webtoonScrollSpeed == other.webtoonScrollSpeed &&
          loop == other.loop &&
          pauseOnZoom == other.pauseOnZoom;

  @override
  int get hashCode => Object.hash(intervalSeconds, webtoonScrollSpeed, loop, pauseOnZoom);
}

