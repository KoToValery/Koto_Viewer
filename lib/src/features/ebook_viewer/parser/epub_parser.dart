import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import '../../../core/services/universal_encoding_service.dart';
import '../models/ebook_models.dart';

class EpubParser {
  const EpubParser._();

  static EbookBook parse(Uint8List bytes, {required String fileName, required String filePath}) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw Exception('Could not open EPUB archive: $e');
    }

    // 1. Locate container.xml
    ArchiveFile? containerFile;
    for (final f in archive) {
      if (f.name.toLowerCase() == 'meta-inf/container.xml') {
        containerFile = f;
        break;
      }
    }

    String opfPath = 'content.opf';
    if (containerFile != null) {
      try {
        final containerXml = _decodeFileContent(containerFile);
        final doc = xml.XmlDocument.parse(containerXml);
        final rootfile = doc.findAllElements('rootfile').firstOrNull;
        if (rootfile != null) {
          final fullPath = rootfile.getAttribute('full-path');
          if (fullPath != null && fullPath.isNotEmpty) {
            opfPath = fullPath.replaceAll('\\', '/');
          }
        }
      } catch (_) {}
    }

    // 2. Locate OPF file
    ArchiveFile? opfFile;
    for (final f in archive) {
      if (f.name.replaceAll('\\', '/').toLowerCase() == opfPath.toLowerCase()) {
        opfFile = f;
        break;
      }
    }

    // Fallback: search for any .opf file in archive
    if (opfFile == null) {
      for (final f in archive) {
        if (f.name.toLowerCase().endsWith('.opf')) {
          opfFile = f;
          opfPath = f.name.replaceAll('\\', '/');
          break;
        }
      }
    }

    if (opfFile == null) {
      throw Exception('Invalid EPUB: package OPF descriptor not found.');
    }

    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';

    final opfContent = _decodeFileContent(opfFile);
    final opfDoc = xml.XmlDocument.parse(opfContent);

    // 3. Parse Metadata
    final metadataEl = opfDoc.findAllElements('metadata').firstOrNull;
    String bookTitle = fileName.replaceAll(RegExp(r'\.[eE][pP][uU][bB]$'), '').replaceAll('_', ' ');
    final List<String> authors = [];
    String? description;
    String? language;
    String? publisher;
    String? pubDate;
    String? coverId;

    if (metadataEl != null) {
      for (final child in metadataEl.children.whereType<xml.XmlElement>()) {
        final name = child.name.local.toLowerCase();
        final text = child.innerText.trim();
        if (name == 'title' && text.isNotEmpty) {
          bookTitle = text;
        } else if ((name == 'creator' || name == 'author') && text.isNotEmpty) {
          authors.add(text);
        } else if (name == 'description' && text.isNotEmpty) {
          description = _stripHtml(text);
        } else if (name == 'language' && text.isNotEmpty) {
          language = text;
        } else if (name == 'publisher' && text.isNotEmpty) {
          publisher = text;
        } else if (name == 'date' && text.isNotEmpty) {
          pubDate = text.split('T').first;
        } else if (name == 'meta') {
          if (child.getAttribute('name') == 'cover') {
            coverId = child.getAttribute('content');
          }
        }
      }
    }

    // 4. Parse Manifest (id -> href, mediaType)
    final Map<String, String> manifestHrefs = {};
    final Map<String, String> manifestMediaTypes = {};
    String? tocHref;

    for (final item in opfDoc.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      final mediaType = item.getAttribute('media-type')?.toLowerCase() ?? '';
      final properties = item.getAttribute('properties')?.toLowerCase() ?? '';

      if (id != null && href != null) {
        manifestHrefs[id] = href;
        manifestMediaTypes[id] = mediaType;
        if (properties.contains('cover-image') || id.toLowerCase().contains('cover')) {
          coverId ??= id;
        }
        if (properties.contains('nav') || id.toLowerCase() == 'ncx' || mediaType.contains('ncx')) {
          tocHref ??= href;
        }
      }
    }

    // 5. Extract Images & Cover
    final Map<String, Uint8List> images = {};
    Uint8List? coverBytes;

    for (final f in archive) {
      if (!f.isFile) continue;
      final rawPath = f.name.replaceAll('\\', '/');
      final lower = rawPath.toLowerCase();
      if (lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.bmp')) {
        final imgBytes = f.content is List<int>
            ? Uint8List.fromList(f.content as List<int>)
            : Uint8List(0);
        if (imgBytes.isNotEmpty) {
          final baseName = rawPath.split('/').last;
          images[rawPath] = imgBytes;
          images[baseName] = imgBytes;

          if (coverId != null && manifestHrefs[coverId] != null) {
            final targetCoverHref = _resolveHref(opfDir, manifestHrefs[coverId]!);
            if (rawPath.toLowerCase() == targetCoverHref.toLowerCase() ||
                baseName.toLowerCase() == targetCoverHref.split('/').last.toLowerCase()) {
              coverBytes = imgBytes;
            }
          }
          if (coverBytes == null && (lower.contains('cover') || baseName.startsWith('cover.'))) {
            coverBytes = imgBytes;
          }
        }
      }
    }

    // 6. Parse Spine in reading order
    final List<String> spineHrefs = [];
    for (final itemref in opfDoc.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null && manifestHrefs.containsKey(idref)) {
        spineHrefs.add(_resolveHref(opfDir, manifestHrefs[idref]!));
      }
    }

    // Fallback: If spine is empty, take all xhtml/html files from manifest
    if (spineHrefs.isEmpty) {
      for (final href in manifestHrefs.values) {
        final lower = href.toLowerCase();
        if (lower.endsWith('.xhtml') || lower.endsWith('.html') || lower.endsWith('.htm')) {
          spineHrefs.add(_resolveHref(opfDir, href));
        }
      }
    }

    // 7. Parse TOC for chapter names if available
    final Map<String, String> tocTitles = {};
    if (tocHref != null) {
      final resolvedToc = _resolveHref(opfDir, tocHref);
      for (final f in archive) {
        if (f.name.replaceAll('\\', '/').toLowerCase() == resolvedToc.toLowerCase()) {
          try {
            final tocXml = _decodeFileContent(f);
            final tocDoc = xml.XmlDocument.parse(tocXml);
            for (final navPoint in tocDoc.findAllElements('navPoint')) {
              final label = navPoint.findAllElements('text').firstOrNull?.innerText.trim();
              final src = navPoint.findAllElements('content').firstOrNull?.getAttribute('src');
              if (label != null && src != null) {
                final cleanSrc = src.split('#').first;
                tocTitles[cleanSrc.toLowerCase()] = label;
                tocTitles[cleanSrc.split('/').last.toLowerCase()] = label;
              }
            }
          } catch (_) {}
          break;
        }
      }
    }

    // 8. Build Chapters
    final List<EbookChapter> chapters = [];
    int totalWords = 0;
    int chapterIndex = 0;

    for (final href in spineHrefs) {
      ArchiveFile? chapterFile;
      for (final f in archive) {
        final normalized = f.name.replaceAll('\\', '/');
        if (normalized.toLowerCase() == href.toLowerCase() ||
            normalized.split('/').last.toLowerCase() == href.split('/').last.toLowerCase()) {
          chapterFile = f;
          break;
        }
      }

      if (chapterFile == null) continue;

      final chapterHtml = _decodeFileContent(chapterFile);
      final hrefBaseName = href.split('/').last.toLowerCase();
      final tocTitle = tocTitles[href.toLowerCase()] ?? tocTitles[hrefBaseName];

      final parsedChapter = _parseChapterContent(
        chapterHtml,
        chapterIndex: chapterIndex,
        fallbackTitle: tocTitle,
        images: images,
      );

      if (parsedChapter.blocks.isNotEmpty) {
        chapters.add(parsedChapter);
        totalWords += parsedChapter.wordCount;
        chapterIndex++;
      }
    }

    if (chapters.isEmpty) {
      throw Exception('Could not extract readable text chapters from EPUB.');
    }

    final metadata = EbookMetadata(
      title: bookTitle,
      authors: authors,
      description: description,
      language: language,
      publisher: publisher,
      publicationDate: pubDate,
      coverBytes: coverBytes,
    );

    return EbookBook(
      title: bookTitle,
      filePath: filePath,
      format: EbookFormat.epub,
      metadata: metadata,
      chapters: chapters,
      images: images,
      totalWordCount: totalWords,
    );
  }

  static String _resolveHref(String baseDir, String href) {
    if (href.startsWith('/')) return href.substring(1);
    final combined = baseDir + href;
    final parts = combined.split('/');
    final resolved = <String>[];
    for (final p in parts) {
      if (p == '.' || p.isEmpty) continue;
      if (p == '..') {
        if (resolved.isNotEmpty) resolved.removeLast();
      } else {
        resolved.add(p);
      }
    }
    return resolved.join('/');
  }

  static String _decodeFileContent(ArchiveFile file) {
    final bytes = file.content is List<int>
        ? Uint8List.fromList(file.content as List<int>)
        : Uint8List(0);
    return UniversalEncodingService.decodeBytes(bytes);
  }

  static EbookChapter _parseChapterContent(
    String html, {
    required int chapterIndex,
    String? fallbackTitle,
    required Map<String, Uint8List> images,
  }) {
    final List<EbookBlock> blocks = [];
    String chapterTitle = fallbackTitle ?? 'Chapter ${chapterIndex + 1}';
    final buffer = StringBuffer();

    try {
      final doc = xml.XmlDocument.parse(_cleanXhtmlForXml(html));
      for (final el in doc.findAllElements('*')) {
        final tag = el.name.local.toLowerCase();

        if (tag == 'h1' || tag == 'h2' || tag == 'h3') {
          final t = _decodeEntities(el.innerText).trim();
          if (t.isNotEmpty) {
            if (fallbackTitle == null && chapterTitle == 'Chapter ${chapterIndex + 1}') {
              chapterTitle = t;
            }
            blocks.add(EbookBlock(
              type: tag == 'h1'
                  ? EbookBlockType.heading1
                  : tag == 'h2'
                      ? EbookBlockType.heading2
                      : EbookBlockType.heading3,
              text: t,
              isBold: true,
            ));
            buffer.writeln(t);
          }
        } else if (tag == 'p') {
          final pText = _decodeEntities(el.innerText).trim();
          if (pText.isNotEmpty) {
            blocks.add(EbookBlock(
              type: EbookBlockType.paragraph,
              text: pText,
            ));
            buffer.writeln(pText);
          }
        } else if (tag == 'blockquote' || tag == 'cite' || tag == 'epigraph') {
          final qText = _decodeEntities(el.innerText).trim();
          if (qText.isNotEmpty) {
            blocks.add(EbookBlock(
              type: EbookBlockType.quote,
              text: qText,
              isItalic: true,
            ));
            buffer.writeln(qText);
          }
        } else if (tag == 'img' || tag == 'image') {
          final src = el.getAttribute('src') ?? el.getAttribute('xlink:href') ?? el.getAttribute('href');
          if (src != null && src.isNotEmpty) {
            final cleanSrc = src.split('/').last.toLowerCase();
            final imgData = images[src] ?? images[cleanSrc];
            if (imgData != null) {
              blocks.add(EbookBlock(
                type: EbookBlockType.image,
                imageKey: src,
                imageBytes: imgData,
              ));
            }
          }
        } else if (tag == 'hr') {
          blocks.add(const EbookBlock(type: EbookBlockType.divider));
        }
      }
    } catch (_) {
      // Fallback regex parser if XML is malformed
      final pRegex = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true);
      for (final match in pRegex.allMatches(html)) {
        final text = _stripHtml(match.group(1) ?? '').trim();
        if (text.isNotEmpty) {
          blocks.add(EbookBlock(type: EbookBlockType.paragraph, text: text));
          buffer.writeln(text);
        }
      }
    }

    final rawText = buffer.toString();
    final words = rawText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return EbookChapter(
      index: chapterIndex,
      title: chapterTitle,
      rawText: rawText,
      blocks: blocks,
      wordCount: words,
    );
  }

  static String _cleanXhtmlForXml(String raw) {
    var s = raw;
    // Remove DOCTYPE to prevent entity resolution issues
    s = s.replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');
    // Ensure self-closing tags are well-formed
    s = s.replaceAllMapped(RegExp(r'<(img|hr|br|meta|link)([^>]*?)(?<!/)>', caseSensitive: false), (m) => '<${m[1]}${m[2]} />');
    return s;
  }

  static String _stripHtml(String html) {
    return _decodeEntities(html.replaceAll(RegExp(r'<[^>]*>'), ' ')).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _decodeEntities(String text) {
    var s = text;
    s = s.replaceAll('&nbsp;', ' ');
    s = s.replaceAll('&quot;', '"');
    s = s.replaceAll('&apos;', "'");
    s = s.replaceAll('&amp;', '&');
    s = s.replaceAll('&lt;', '<');
    s = s.replaceAll('&gt;', '>');
    s = s.replaceAll('&mdash;', '—');
    s = s.replaceAll('&ndash;', '–');
    s = s.replaceAll('&laquo;', '«');
    s = s.replaceAll('&raquo;', '»');
    s = s.replaceAll('&hellip;', '…');
    s = s.replaceAll('&copy;', '©');
    s = s.replaceAll('&reg;', '®');
    s = s.replaceAll('&trade;', '™');

    // Numeric HTML entities (&#1234; or &#xABCD;)
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m[1]!);
      return code != null ? String.fromCharCode(code) : m[0]!;
    });
    s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m[1]!, radix: 16);
      return code != null ? String.fromCharCode(code) : m[0]!;
    });

    return s;
  }
}
