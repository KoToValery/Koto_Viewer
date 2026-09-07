import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a user-saved bookmark within a document, book, or comic.
class BookmarkItem {
  final String id;
  final int page;
  final int? chapter;
  final int? miniPage;
  final int? blockIndex;
  final int? charOffset;
  final String label;
  final String snippet;
  final DateTime createdAt;

  BookmarkItem({
    required this.id,
    required this.page,
    this.chapter,
    this.miniPage,
    this.blockIndex,
    this.charOffset,
    required this.label,
    required this.snippet,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'page': page,
    if (chapter != null) 'chapter': chapter,
    if (miniPage != null) 'miniPage': miniPage,
    if (blockIndex != null) 'blockIndex': blockIndex,
    if (charOffset != null) 'charOffset': charOffset,
    'label': label,
    'snippet': snippet,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    page: json['page'] as int? ?? 1,
    chapter: json['chapter'] as int?,
    miniPage: json['miniPage'] as int?,
    blockIndex: json['blockIndex'] as int?,
    charOffset: json['charOffset'] as int?,
    label: json['label'] as String? ?? 'Bookmark',
    snippet: json['snippet'] as String? ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
        : DateTime.now(),
  );
}

/// Stores reading progress (last opened position, resilient mini-page locator, bookmarks).
class ReadingProgress {
  final String filePath;
  final int page;
  final int? chapter;
  final int? miniPage;
  final int? blockIndex;
  final int? charOffset;
  final double scrollOffset;
  final double progressFraction;
  final DateTime updatedAt;
  final List<BookmarkItem> bookmarks;

  ReadingProgress({
    required this.filePath,
    required this.page,
    this.chapter,
    this.miniPage,
    this.blockIndex,
    this.charOffset,
    this.scrollOffset = 0.0,
    this.progressFraction = 0.0,
    required this.updatedAt,
    this.bookmarks = const [],
  });

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'page': page,
    if (chapter != null) 'chapter': chapter,
    if (miniPage != null) 'miniPage': miniPage,
    if (blockIndex != null) 'blockIndex': blockIndex,
    if (charOffset != null) 'charOffset': charOffset,
    'scrollOffset': scrollOffset,
    'progressFraction': progressFraction,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
  };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) => ReadingProgress(
    filePath: json['filePath'] as String? ?? '',
    page: json['page'] as int? ?? 1,
    chapter: json['chapter'] as int?,
    miniPage: json['miniPage'] as int?,
    blockIndex: json['blockIndex'] as int?,
    charOffset: json['charOffset'] as int?,
    scrollOffset: (json['scrollOffset'] as num?)?.toDouble() ?? 0.0,
    progressFraction: (json['progressFraction'] as num?)?.toDouble() ?? 0.0,
    updatedAt: json['updatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
        : DateTime.now(),
    bookmarks: (json['bookmarks'] as List<dynamic>?)
            ?.map((b) => BookmarkItem.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList() ??
        const [],
  );
}

/// Persistent service managing reading progress & bookmarks using SharedPreferences.
class ReadingProgressService {
  static const String _prefPrefix = 'koto_reading_progress_';

  static String _keyForPath(String filePath) {
    return '$_prefPrefix${filePath.hashCode}';
  }

  /// Saves or updates the current reading progress for a given file.
  static Future<void> saveProgress(
    String filePath, {
    int? page,
    int? chapter,
    int? miniPage,
    int? blockIndex,
    int? charOffset,
    double? scrollOffset,
    double? progressFraction,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForPath(filePath);

      // Fetch existing if available to preserve bookmarks
      final existing = await getProgress(filePath);
      final bookmarks = existing?.bookmarks ?? <BookmarkItem>[];

      final progress = ReadingProgress(
        filePath: filePath,
        page: page ?? existing?.page ?? 1,
        chapter: chapter ?? existing?.chapter,
        miniPage: miniPage ?? existing?.miniPage,
        blockIndex: blockIndex ?? existing?.blockIndex,
        charOffset: charOffset ?? existing?.charOffset,
        scrollOffset: scrollOffset ?? existing?.scrollOffset ?? 0.0,
        progressFraction: progressFraction ?? existing?.progressFraction ?? 0.0,
        updatedAt: DateTime.now(),
        bookmarks: bookmarks,
      );

      await prefs.setString(key, jsonEncode(progress.toJson()));
    } catch (_) {}
  }

  /// Retrieves the saved progress for [filePath], or null if none exists.
  static Future<ReadingProgress?> getProgress(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForPath(filePath);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;

      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        return ReadingProgress.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Adds a bookmark to the given file.
  static Future<void> addBookmark(String filePath, BookmarkItem bookmark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForPath(filePath);
      final existing = await getProgress(filePath);

      final currentBookmarks = List<BookmarkItem>.from(existing?.bookmarks ?? []);
      // Prevent exact duplicate (same page/chapter/miniPage)
      currentBookmarks.removeWhere((b) =>
          b.page == bookmark.page &&
          b.chapter == bookmark.chapter &&
          b.miniPage == bookmark.miniPage);
      currentBookmarks.insert(0, bookmark);

      final progress = ReadingProgress(
        filePath: filePath,
        page: existing?.page ?? bookmark.page,
        chapter: existing?.chapter ?? bookmark.chapter,
        miniPage: existing?.miniPage ?? bookmark.miniPage,
        blockIndex: existing?.blockIndex ?? bookmark.blockIndex,
        charOffset: existing?.charOffset ?? bookmark.charOffset,
        scrollOffset: existing?.scrollOffset ?? 0.0,
        progressFraction: existing?.progressFraction ?? 0.0,
        updatedAt: DateTime.now(),
        bookmarks: currentBookmarks,
      );

      await prefs.setString(key, jsonEncode(progress.toJson()));
    } catch (_) {}
  }

  /// Removes a bookmark by its ID.
  static Future<void> removeBookmark(String filePath, String bookmarkId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForPath(filePath);
      final existing = await getProgress(filePath);
      if (existing == null) return;

      final currentBookmarks = List<BookmarkItem>.from(existing.bookmarks);
      currentBookmarks.removeWhere((b) => b.id == bookmarkId);

      final progress = ReadingProgress(
        filePath: filePath,
        page: existing.page,
        chapter: existing.chapter,
        miniPage: existing.miniPage,
        blockIndex: existing.blockIndex,
        charOffset: existing.charOffset,
        scrollOffset: existing.scrollOffset,
        progressFraction: existing.progressFraction,
        updatedAt: DateTime.now(),
        bookmarks: currentBookmarks,
      );

      await prefs.setString(key, jsonEncode(progress.toJson()));
    } catch (_) {}
  }

  /// Checks if a given position is bookmarked.
  static Future<bool> isBookmarked(
    String filePath, {
    int? page,
    int? chapter,
    int? miniPage,
  }) async {
    final progress = await getProgress(filePath);
    if (progress == null) return false;

    return progress.bookmarks.any((b) {
      if (chapter != null && b.chapter != null) {
        if (b.chapter != chapter) return false;
      }
      if (miniPage != null && b.miniPage != null) {
        return b.miniPage == miniPage;
      }
      if (page != null) {
        return b.page == page;
      }
      return false;
    });
  }

  /// Gets all bookmarks for [filePath].
  static Future<List<BookmarkItem>> getBookmarks(String filePath) async {
    final progress = await getProgress(filePath);
    return progress?.bookmarks ?? const [];
  }

  /// Clears all reading progress and bookmarks for [filePath].
  static Future<void> clear(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyForPath(filePath));
    } catch (_) {}
  }
}
