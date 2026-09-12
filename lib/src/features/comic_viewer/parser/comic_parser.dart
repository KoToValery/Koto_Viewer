import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
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

  /// Parses a comic book file in a background Isolate, reporting real-time extraction progress.
  static Future<ComicBook> parseFromFile(
    String filePath, {
    void Function(ComicParseProgress progress)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Comic book file not found: $filePath');
    }

    final fileSizeBytes = await file.length();
    final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);

    onProgress?.call(ComicParseProgress(
      progress: 0.05,
      stage: ComicParseStage.opening,
      sizeMb: sizeMb,
      status: 'Opening file ($sizeMb MB)...',
    ));

    final receivePort = ReceivePort();
    final completer = Completer<ComicBook>();

    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        _parseWorker,
        _ParseWorkerRequest(filePath, receivePort.sendPort),
      );

      receivePort.listen((message) {
        if (message is ComicParseProgress) {
          onProgress?.call(message);
        } else if (message is ComicBook) {
          if (!completer.isCompleted) completer.complete(message);
          receivePort.close();
          isolate?.kill(priority: Isolate.immediate);
        } else if (message is Exception || message is Error) {
          if (!completer.isCompleted) completer.completeError(message);
          receivePort.close();
          isolate?.kill(priority: Isolate.immediate);
        } else if (message is String && message.startsWith('ERROR:')) {
          if (!completer.isCompleted) completer.completeError(Exception(message.substring(6)));
          receivePort.close();
          isolate?.kill(priority: Isolate.immediate);
        }
      });

      return await completer.future;
    } catch (e) {
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
      // In-process fallback if isolate spawn fails on any restricted platform
      final bytes = await file.readAsBytes();
      return parseFromBytes(
        bytes,
        fileName: filePath.split(Platform.pathSeparator).last,
        filePath: filePath,
        onProgress: onProgress,
      );
    }
  }

  static ComicBook parseFromBytes(
    Uint8List bytes, {
    required String fileName,
    required String filePath,
    void Function(ComicParseProgress progress)? onProgress,
  }) {
    onProgress?.call(const ComicParseProgress(
      progress: 0.20,
      stage: ComicParseStage.extractingStructure,
      status: 'Extracting archive structure...',
    ));

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      try {
        archive = TarDecoder().decodeBytes(bytes);
      } catch (e) {
        if (_isRar5(bytes)) {
          throw Exception(
            'Този CBR файл е компресиран в RAR5 формат, който не се поддържа от вградения архив декомпресор. '
            'Моля, преобразувайте комикса в .cbz (ZIP) за пълна съвместимост.',
          );
        } else if (_isRar(bytes)) {
          throw Exception(
            'Този CBR файл използва RAR компресия, която не се поддържа от вградения декомпресор. '
            'Моля, преобразувайте архива в .cbz (ZIP) формат.',
          );
        }
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

    final totalPages = imageFiles.length;
    final List<ComicPage> pages = [];
    for (int i = 0; i < totalPages; i++) {
      final file = imageFiles[i];
      final content = file.content;
      final Uint8List fileBytes;
      if (content is Uint8List) {
        fileBytes = content;
      } else if (content is List<int>) {
        fileBytes = Uint8List.fromList(content);
      } else {
        fileBytes = Uint8List(0);
      }

      if (fileBytes.isNotEmpty) {
        pages.add(ComicPage(
          pageIndex: i,
          fileName: file.name.split('/').last,
          bytes: fileBytes,
        ));
      }

      final fraction = 0.25 + 0.70 * ((i + 1) / totalPages);
      onProgress?.call(ComicParseProgress(
        progress: fraction,
        stage: ComicParseStage.extractingPage,
        currentPage: i + 1,
        totalPages: totalPages,
        status: 'Extracting page ${i + 1} of $totalPages...',
      ));
    }

    if (pages.isEmpty) {
      throw Exception('Failed to extract comic pages.');
    }

    onProgress?.call(const ComicParseProgress(
      progress: 0.98,
      stage: ComicParseStage.finalizing,
      status: 'Finalizing pages...',
    ));

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

  /// Checks if bytes start with the RAR5 magic signature (Rar!\x1a\x07\x01\x00)
  static bool _isRar5(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x52 && // 'R'
        bytes[1] == 0x61 && // 'a'
        bytes[2] == 0x72 && // 'r'
        bytes[3] == 0x21 && // '!'
        bytes[4] == 0x1A &&
        bytes[5] == 0x07 &&
        bytes[6] == 0x01 &&
        bytes[7] == 0x00;
  }

  /// Checks if bytes start with the legacy RAR signature (Rar!\x1a\x07)
  static bool _isRar(Uint8List bytes) {
    return bytes.length >= 7 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x61 &&
        bytes[2] == 0x72 &&
        bytes[3] == 0x21 &&
        bytes[4] == 0x1A &&
        bytes[5] == 0x07;
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

class _ParseWorkerRequest {
  final String filePath;
  final SendPort sendPort;

  const _ParseWorkerRequest(this.filePath, this.sendPort);
}

void _parseWorker(_ParseWorkerRequest request) {
  final sendPort = request.sendPort;
  try {
    final file = File(request.filePath);
    if (!file.existsSync()) {
      sendPort.send('ERROR: Comic book file not found: ${request.filePath}');
      return;
    }
    final fileSizeBytes = file.lengthSync();
    final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);

    sendPort.send(ComicParseProgress(
      progress: 0.08,
      stage: ComicParseStage.reading,
      sizeMb: sizeMb,
      status: 'Reading file ($sizeMb MB)...',
    ));

    final bytes = file.readAsBytesSync();

    sendPort.send(const ComicParseProgress(
      progress: 0.20,
      stage: ComicParseStage.indexing,
      status: 'Indexing pages...',
    ));

    final comic = ComicParser.parseFromBytes(
      bytes,
      fileName: request.filePath.split(Platform.pathSeparator).last,
      filePath: request.filePath,
      onProgress: (p) => sendPort.send(p),
    );

    sendPort.send(comic);
  } catch (e) {
    sendPort.send('ERROR: $e');
  }
}
