import 'dart:typed_data';

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
