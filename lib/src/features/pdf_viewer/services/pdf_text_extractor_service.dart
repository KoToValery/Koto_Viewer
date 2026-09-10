import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/pdf_reflow_models.dart';
import 'pdf_ocr_service.dart';

/// Coordinates digital text extraction, OCR fallback, and disk/memory caching for PDF pages.
class PdfTextExtractorService {
  final String filePath;
  final Map<int, PdfPageReflowData> _memoryCache = {};
  String? _cacheDirectoryPath;

  PdfTextExtractorService({required this.filePath});

  /// Initializes the disk cache directory for this file.
  Future<String> _getCacheDir() async {
    if (_cacheDirectoryPath != null) return _cacheDirectoryPath!;
    try {
      final baseDir = await getApplicationSupportDirectory();
      final fileHash = filePath.hashCode.abs().toString();
      final dir = Directory('${baseDir.path}/pdf_reflow_cache/$fileHash');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDirectoryPath = dir.path;
      return _cacheDirectoryPath!;
    } catch (_) {
      final temp = await getTemporaryDirectory();
      final fileHash = filePath.hashCode.abs().toString();
      final dir = Directory('${temp.path}/pdf_reflow_cache/$fileHash');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDirectoryPath = dir.path;
      return _cacheDirectoryPath!;
    }
  }

  /// Extracts structured reflow data for [pageNumber].
  /// Uses memory cache -> disk cache -> digital PDF text extraction -> OCR fallback.
  Future<PdfPageReflowData> getPageData(PdfDocument document, int pageNumber) async {
    // 1. Memory cache
    if (_memoryCache.containsKey(pageNumber)) {
      return _memoryCache[pageNumber]!;
    }

    // 2. Disk cache
    final diskData = await _loadFromDiskCache(pageNumber);
    if (diskData != null) {
      _memoryCache[pageNumber] = diskData;
      return diskData;
    }

    // 3. Extract from PDF document
    if (pageNumber < 1 || pageNumber > document.pages.length) {
      return PdfPageReflowData.empty(pageNumber, message: 'Invalid page number');
    }

    final page = document.pages[pageNumber - 1];

    try {
      // Check digital text layer first
      final raw = await page.loadText();
      final rawText = raw?.fullText ?? '';

      // If page has substantial text, format digital paragraphs
      if (rawText.trim().length >= 25) {
        final blocks = _parseDigitalTextToBlocks(rawText);
        final pageData = PdfPageReflowData(
          pageNumber: pageNumber,
          blocks: blocks,
          rawText: rawText,
          isScannedOcr: false,
          isLoaded: true,
        );
        _memoryCache[pageNumber] = pageData;
        await _saveToDiskCache(pageData);
        return pageData;
      }

      // Page is scanned or has minimal text -> Trigger on-device OCR
      debugPrint('[PdfTextExtractor] Page $pageNumber has no digital text. Running OCR...');
      final ocrBlocks = await PdfOcrService.performOcrOnPage(page);

      final pageData = PdfPageReflowData(
        pageNumber: pageNumber,
        blocks: ocrBlocks,
        rawText: ocrBlocks.map((b) => b.text).join('\n\n'),
        isScannedOcr: true,
        isLoaded: true,
      );

      _memoryCache[pageNumber] = pageData;
      await _saveToDiskCache(pageData);
      return pageData;
    } catch (e, stack) {
      debugPrint('[PdfTextExtractor] Error extracting page $pageNumber: $e\n$stack');
      return PdfPageReflowData.empty(pageNumber, message: 'Failed to extract text: $e');
    }
  }

  /// Parses raw extracted PDF text into natural paragraphs and detected headings.
  List<PdfReflowBlock> _parseDigitalTextToBlocks(String fullText) {
    final blocks = <PdfReflowBlock>[];

    // Normalize Windows/Mac line endings
    final normalized = fullText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Split on double newlines to find paragraphs
    final rawParagraphs = normalized.split(RegExp(r'\n{2,}'));

    for (var rawPara in rawParagraphs) {
      final trimmed = rawPara.trim();
      if (trimmed.isEmpty) continue;

      final mergedLines = PdfOcrService.cleanReflowText(trimmed);

      if (mergedLines.isEmpty) continue;

      // Heading heuristic: short line, no trailing period, or all uppercase
      final isHeading = mergedLines.length < 60 &&
          !mergedLines.endsWith('.') &&
          (mergedLines == mergedLines.toUpperCase() ||
              mergedLines.startsWith(RegExp(r'^(Chapter|Section|Article|\d+\.|\b[IVXLCDM]+\.)', caseSensitive: false)));

      blocks.add(PdfReflowBlock(
        text: mergedLines,
        isHeading: isHeading,
        isOcr: false,
      ));
    }

    return blocks;
  }

  Future<PdfPageReflowData?> _loadFromDiskCache(int pageNumber) async {
    try {
      final cacheDir = await _getCacheDir();
      final cacheFile = File('$cacheDir/page_$pageNumber.json');
      if (!await cacheFile.exists()) return null;

      final jsonStr = await cacheFile.readAsString();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final rawBlocks = map['blocks'] as List<dynamic>? ?? [];
      final blocks = rawBlocks.map((b) {
        return PdfReflowBlock(
          text: b['text'] as String? ?? '',
          isHeading: b['isHeading'] as bool? ?? false,
          isOcr: b['isOcr'] as bool? ?? false,
        );
      }).toList();

      return PdfPageReflowData(
        pageNumber: map['pageNumber'] as int? ?? pageNumber,
        blocks: blocks,
        rawText: map['rawText'] as String? ?? '',
        isScannedOcr: map['isScannedOcr'] as bool? ?? false,
        isLoaded: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToDiskCache(PdfPageReflowData data) async {
    try {
      final cacheDir = await _getCacheDir();
      final cacheFile = File('$cacheDir/page_${data.pageNumber}.json');

      final map = {
        'pageNumber': data.pageNumber,
        'rawText': data.rawText,
        'isScannedOcr': data.isScannedOcr,
        'blocks': data.blocks.map((b) => {
          'text': b.text,
          'isHeading': b.isHeading,
          'isOcr': b.isOcr,
        }).toList(),
      };

      await cacheFile.writeAsString(jsonEncode(map));
    } catch (_) {}
  }

  void clearMemoryCache() {
    _memoryCache.clear();
  }
}
