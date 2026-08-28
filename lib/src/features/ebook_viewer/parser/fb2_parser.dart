import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import '../../../core/services/universal_encoding_service.dart';
import '../models/ebook_models.dart';

class Fb2Parser {
  const Fb2Parser._();

  static EbookBook parse(Uint8List bytes, {required String fileName, required String filePath}) {
    Uint8List xmlBytes = bytes;

    // Check if it is a ZIP archive containing .fb2 (.fb2.zip or .zip)
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        for (final f in archive) {
          if (f.isFile && f.name.toLowerCase().endsWith('.fb2')) {
            xmlBytes = f.content is List<int>
                ? Uint8List.fromList(f.content as List<int>)
                : Uint8List(0);
            break;
          }
        }
      } catch (_) {}
    }

    final xmlString = UniversalEncodingService.decodeBytes(xmlBytes);
    final doc = xml.XmlDocument.parse(_cleanFb2Xml(xmlString));

    // 1. Extract Binary Images (Base64)
    final Map<String, Uint8List> images = {};
    for (final binary in doc.findAllElements('binary')) {
      final id = binary.getAttribute('id');
      if (id != null && id.isNotEmpty) {
        final base64Content = binary.innerText.replaceAll(RegExp(r'\s+'), '');
        try {
          final decoded = base64.decode(base64Content);
          images[id] = decoded;
          images['#$id'] = decoded;
        } catch (_) {}
      }
    }

    // 2. Parse Description / Metadata
    String bookTitle = fileName.replaceAll(RegExp(r'\.[fF][bB]2(\.[zZ][iI][pP])?$'), '').replaceAll('_', ' ');
    final List<String> authors = [];
    String? description;
    String? language;
    String? publisher;
    String? pubDate;
    String? genre;
    Uint8List? coverBytes;

    final titleInfo = doc.findAllElements('title-info').firstOrNull;
    if (titleInfo != null) {
      final bt = titleInfo.findElements('book-title').firstOrNull?.innerText.trim();
      if (bt != null && bt.isNotEmpty) {
        bookTitle = bt;
      }

      for (final authorEl in titleInfo.findElements('author')) {
        final first = authorEl.findElements('first-name').firstOrNull?.innerText.trim() ?? '';
        final middle = authorEl.findElements('middle-name').firstOrNull?.innerText.trim() ?? '';
        final last = authorEl.findElements('last-name').firstOrNull?.innerText.trim() ?? '';
        final nickname = authorEl.findElements('nickname').firstOrNull?.innerText.trim() ?? '';

        final nameParts = [first, middle, last].where((s) => s.isNotEmpty).join(' ');
        if (nameParts.isNotEmpty) {
          authors.add(nameParts);
        } else if (nickname.isNotEmpty) {
          authors.add(nickname);
        }
      }

      final annotEl = titleInfo.findElements('annotation').firstOrNull;
      if (annotEl != null) {
        description = annotEl.innerText.trim();
      }

      language = titleInfo.findElements('lang').firstOrNull?.innerText.trim();
      genre = titleInfo.findElements('genre').firstOrNull?.innerText.trim();
      pubDate = titleInfo.findElements('date').firstOrNull?.innerText.trim();

      // Cover image
      final coverImg = titleInfo.findAllElements('image').firstOrNull;
      final coverHref = coverImg?.getAttribute('l:href') ?? coverImg?.getAttribute('xlink:href') ?? coverImg?.getAttribute('href');
      if (coverHref != null) {
        final cleanId = coverHref.replaceAll('#', '');
        coverBytes = images[cleanId] ?? images[coverHref];
      }
    }

    // Fallback: first image as cover if none found
    if (coverBytes == null && images.isNotEmpty) {
      coverBytes = images.values.first;
    }

    // 3. Parse Body Sections / Chapters
    final List<EbookChapter> chapters = [];
    int totalWords = 0;
    int chapterIndex = 0;

    final bodies = doc.findAllElements('body').toList();
    final mainBody = bodies.firstOrNull;

    if (mainBody != null) {
      final sections = mainBody.findElements('section').toList();
      if (sections.isNotEmpty) {
        for (final section in sections) {
          final chapter = _parseSection(section, chapterIndex: chapterIndex, images: images);
          if (chapter.blocks.isNotEmpty) {
            chapters.add(chapter);
            totalWords += chapter.wordCount;
            chapterIndex++;
          }
        }
      } else {
        // Flat body with paragraphs
        final chapter = _parseSection(mainBody, chapterIndex: 0, images: images);
        if (chapter.blocks.isNotEmpty) {
          chapters.add(chapter);
          totalWords += chapter.wordCount;
        }
      }
    }

    if (chapters.isEmpty) {
      throw Exception('Could not parse readable sections from FB2 file.');
    }

    final metadata = EbookMetadata(
      title: bookTitle,
      authors: authors,
      description: description,
      language: language,
      publisher: publisher,
      publicationDate: pubDate,
      genre: genre,
      coverBytes: coverBytes,
    );

    return EbookBook(
      title: bookTitle,
      filePath: filePath,
      format: EbookFormat.fb2,
      metadata: metadata,
      chapters: chapters,
      images: images,
      totalWordCount: totalWords,
    );
  }

  static EbookChapter _parseSection(
    xml.XmlElement sectionEl, {
    required int chapterIndex,
    required Map<String, Uint8List> images,
  }) {
    final List<EbookBlock> blocks = [];
    String chapterTitle = 'Chapter ${chapterIndex + 1}';
    final buffer = StringBuffer();

    // Check for title in section
    final titleEl = sectionEl.findElements('title').firstOrNull;
    if (titleEl != null) {
      final t = titleEl.innerText.trim();
      if (t.isNotEmpty) {
        chapterTitle = t;
        blocks.add(EbookBlock(type: EbookBlockType.heading1, text: t, isBold: true));
        buffer.writeln(t);
      }
    }

    for (final node in sectionEl.children) {
      if (node is! xml.XmlElement) continue;
      if (node.name.local.toLowerCase() == 'title') continue;

      final tag = node.name.local.toLowerCase();
      if (tag == 'p') {
        final text = node.innerText.trim();
        if (text.isNotEmpty) {
          blocks.add(EbookBlock(type: EbookBlockType.paragraph, text: text));
          buffer.writeln(text);
        }
      } else if (tag == 'subtitle') {
        final text = node.innerText.trim();
        if (text.isNotEmpty) {
          blocks.add(EbookBlock(type: EbookBlockType.heading2, text: text, isBold: true));
          buffer.writeln(text);
        }
      } else if (tag == 'epigraph' || tag == 'cite') {
        final text = node.innerText.trim();
        if (text.isNotEmpty) {
          blocks.add(EbookBlock(type: EbookBlockType.quote, text: text, isItalic: true));
          buffer.writeln(text);
        }
      } else if (tag == 'poem') {
        final text = node.innerText.trim();
        if (text.isNotEmpty) {
          blocks.add(EbookBlock(type: EbookBlockType.poem, text: text, isItalic: true));
          buffer.writeln(text);
        }
      } else if (tag == 'empty-line') {
        blocks.add(const EbookBlock(type: EbookBlockType.divider));
      } else if (tag == 'image') {
        final href = node.getAttribute('l:href') ?? node.getAttribute('xlink:href') ?? node.getAttribute('href');
        if (href != null) {
          final cleanId = href.replaceAll('#', '');
          final imgData = images[cleanId] ?? images[href];
          if (imgData != null) {
            blocks.add(EbookBlock(type: EbookBlockType.image, imageKey: cleanId, imageBytes: imgData));
          }
        }
      } else if (tag == 'section') {
        // Sub-section recursion
        final sub = _parseSection(node, chapterIndex: chapterIndex, images: images);
        blocks.addAll(sub.blocks);
        buffer.writeln(sub.rawText);
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

  static String _cleanFb2Xml(String raw) {
    return raw.replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');
  }
}
