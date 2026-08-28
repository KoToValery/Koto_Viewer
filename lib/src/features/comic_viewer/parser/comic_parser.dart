import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import '../models/comic_models.dart';

class ComicParser {
  const ComicParser._();

  static const List<String> _supportedImageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
    '.gif',
    '.avif',
  ];

  static Future<ComicBook> parseFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Comic book file not found: $filePath');
    }
    final bytes = await file.readAsBytes();
    final fileName = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, fileName: fileName, filePath: filePath);
  }

  static ComicBook parseFromBytes(
    Uint8List bytes, {
    required String fileName,
    required String filePath,
  }) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      try {
        archive = TarDecoder().decodeBytes(bytes);
      } catch (e) {
        throw Exception('Could not decode comic archive: $e');
      }
    }

    if (archive.isEmpty) {
      throw Exception('Comic archive is empty.');
    }

    final List<ArchiveFile> imageFiles = [];
    ArchiveFile? comicInfoFile;

    for (final file in archive) {
      if (!file.isFile) continue;
      final rawName = file.name.replaceAll('\\', '/');
      final baseName = rawName.split('/').last;
      final lower = baseName.toLowerCase();

      // Skip OS metadata & hidden files
      if (lower.startsWith('__macosx') ||
          lower.startsWith('.') ||
          lower.endsWith('.ds_store') ||
          lower.endsWith('thumbs.db')) {
        continue;
      }

      if (lower == 'comicinfo.xml' || lower == 'metadata.xml') {
        comicInfoFile = file;
        continue;
      }

      if (_isImageFile(lower)) {
        imageFiles.add(file);
      }
    }

    if (imageFiles.isEmpty) {
      throw Exception('No comic page images found inside the archive.');
    }

    // Sort pages in natural alphanumeric order
    imageFiles.sort((a, b) => _naturalCompare(a.name, b.name));

    final List<ComicPage> pages = [];
    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final fileBytes = file.content is List<int>
          ? Uint8List.fromList(file.content as List<int>)
          : Uint8List(0);

      if (fileBytes.isNotEmpty) {
        pages.add(ComicPage(
          pageIndex: i,
          fileName: file.name.split('/').last,
          bytes: fileBytes,
        ));
      }
    }

    if (pages.isEmpty) {
      throw Exception('Failed to extract comic pages.');
    }

    final defaultTitle = _extractCleanTitle(fileName);
    final metadata = _parseMetadata(comicInfoFile, defaultTitle, pages.length);

    return ComicBook(
      title: metadata.title.isNotEmpty ? metadata.title : defaultTitle,
      filePath: filePath,
      pages: pages,
      metadata: metadata,
    );
  }

  static bool _isImageFile(String lowerName) {
    for (final ext in _supportedImageExtensions) {
      if (lowerName.endsWith(ext)) return true;
    }
    return false;
  }

  static String _extractCleanTitle(String fileName) {
    var name = fileName;
    for (final ext in ['.cbz', '.cbr', '.cbt', '.cb7', '.zip', '.rar', '.tar']) {
      if (name.toLowerCase().endsWith(ext)) {
        name = name.substring(0, name.length - ext.length);
        break;
      }
    }
    return name.replaceAll('_', ' ').trim();
  }

  static ComicMetadata _parseMetadata(ArchiveFile? file, String fallbackTitle, int pageCount) {
    if (file == null) {
      return ComicMetadata(
        title: fallbackTitle,
        pageCount: pageCount,
      );
    }

    try {
      final content = file.content is List<int>
          ? utf8.decode(file.content as List<int>, allowMalformed: true)
          : file.content.toString();

      final doc = xml.XmlDocument.parse(content);
      final root = doc.rootElement;

      String? getTagText(String tagName) {
        final el = root.findElements(tagName).firstOrNull;
        return el?.innerText.trim();
      }

      final title = getTagText('Title') ?? fallbackTitle;
      final series = getTagText('Series');
      final number = getTagText('Number');
      final summary = getTagText('Summary') ?? getTagText('Notes');
      final writer = getTagText('Writer');
      final penciller = getTagText('Penciller');
      final genre = getTagText('Genre');
      final publisher = getTagText('Publisher');
      final year = int.tryParse(getTagText('Year') ?? '');
      final month = int.tryParse(getTagText('Month') ?? '');

      final mangaTag = getTagText('Manga')?.toLowerCase() ?? '';
      final isManga = mangaTag.contains('yes') || mangaTag.contains('righttoleft');

      return ComicMetadata(
        title: title.isNotEmpty ? title : fallbackTitle,
        series: series,
        number: number,
        summary: summary,
        writer: writer,
        penciller: penciller,
        genre: genre,
        year: year,
        month: month,
        publisher: publisher,
        isManga: isManga,
        pageCount: pageCount,
      );
    } catch (_) {
      return ComicMetadata(
        title: fallbackTitle,
        pageCount: pageCount,
      );
    }
  }

  /// Natural Alphanumeric Sort comparator (e.g. page_2 < page_10)
  static int _naturalCompare(String a, String b) {
    final regex = RegExp(r'(\d+|\D+)');
    final aMatches = regex.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final bMatches = regex.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();

    final minLen = aMatches.length < bMatches.length ? aMatches.length : bMatches.length;
    for (int i = 0; i < minLen; i++) {
      final aChunk = aMatches[i];
      final bChunk = bMatches[i];

      final aNum = int.tryParse(aChunk);
      final bNum = int.tryParse(bChunk);

      if (aNum != null && bNum != null) {
        if (aNum != bNum) return aNum.compareTo(bNum);
      } else {
        final strComp = aChunk.compareTo(bChunk);
        if (strComp != 0) return strComp;
      }
    }
    return aMatches.length.compareTo(bMatches.length);
  }
}
