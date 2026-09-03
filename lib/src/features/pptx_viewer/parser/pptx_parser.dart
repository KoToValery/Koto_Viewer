import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import '../models/pptx_models.dart';

/// Pure-Dart Microsoft PowerPoint (.pptx) Presentation Parser.
class PptxParser {
  /// Parses bytes of a `.pptx` file into a structured [PptxPresentation].
  static PptxPresentation parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // Build a lookup map of all archive files by normalized name
    final fileMap = <String, ArchiveFile>{};
    for (final f in archive.files) {
      fileMap[f.name.toLowerCase()] = f;
    }

    // Find all slide XML files
    final slideFiles = archive.files.where((f) {
      final name = f.name.toLowerCase();
      return name.startsWith('ppt/slides/slide') && name.endsWith('.xml');
    }).toList();

    if (slideFiles.isEmpty) {
      throw Exception('Invalid PPTX format: No slides found.');
    }

    // Sort slides naturally by number (slide1.xml, slide2.xml, ..., slide10.xml)
    slideFiles.sort((a, b) {
      final numA = _extractSlideNumber(a.name);
      final numB = _extractSlideNumber(b.name);
      return numA.compareTo(numB);
    });

    final List<PptxSlide> slides = [];

    for (int i = 0; i < slideFiles.length; i++) {
      final file = slideFiles[i];
      final xmlString = utf8.decode(file.content as List<int>);
      final slideDoc = xml.XmlDocument.parse(xmlString);

      // Load relationship map for this slide's embedded media
      final relsMap = _loadSlideRelationships(file.name, fileMap);

      final slide = _parseSlide(slideDoc, i + 1, relsMap, fileMap);
      slides.add(slide);
    }

    return PptxPresentation(slides: slides);
  }

  /// Parses the relationship XML for a slide and returns a map of rId → target path.
  static Map<String, String> _loadSlideRelationships(
    String slidePath,
    Map<String, ArchiveFile> fileMap,
  ) {
    // slidePath e.g.: "ppt/slides/slide1.xml"
    // rels file:      "ppt/slides/_rels/slide1.xml.rels"
    final parts = slidePath.split('/');
    final fileName = parts.last;
    parts.removeLast();
    final relsPath = '${parts.join('/')}/_rels/$fileName.rels';

    final relsFile = fileMap[relsPath.toLowerCase()];
    if (relsFile == null) return {};

    try {
      final relsXml = utf8.decode(relsFile.content as List<int>);
      final doc = xml.XmlDocument.parse(relsXml);
      final map = <String, String>{};
      for (final rel in doc.findAllElements('Relationship')) {
        final id     = rel.getAttribute('Id') ?? '';
        final target = rel.getAttribute('Target') ?? '';
        if (id.isNotEmpty && target.isNotEmpty) {
          map[id] = target;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static int _extractSlideNumber(String path) {
    final match = RegExp(r'slide(\d+)\.xml$', caseSensitive: false).firstMatch(path);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  static PptxSlide _parseSlide(
    xml.XmlDocument doc,
    int slideNumber,
    Map<String, String> relsMap,
    Map<String, ArchiveFile> fileMap,
  ) {
    String? title;
    final List<PptxShape> shapes = [];
    final List<PptxTable> tables = [];
    final List<PptxImage> images = [];

    // Find spTree
    final spTree = doc.findAllElements('p:spTree').firstOrNull;
    if (spTree == null) {
      return PptxSlide(slideNumber: slideNumber, shapes: const []);
    }

    for (final child in spTree.children.whereType<xml.XmlElement>()) {
      final localName = child.name.local;

      if (localName == 'sp') {
        // Shape or Text Box
        final shape = _parseShape(child);
        if (shape.paragraphs.isNotEmpty) {
          if (shape.isTitle && (title == null || title.isEmpty)) {
            title = shape.plainText;
          } else {
            shapes.add(shape);
          }
        }
      } else if (localName == 'graphicFrame') {
        // Graphic frame (tables, charts, diagrams)
        final tblElem = child.findAllElements('a:tbl').firstOrNull;
        if (tblElem != null) {
          final table = _parseTable(tblElem);
          if (table.rows.isNotEmpty) {
            tables.add(table);
          }
        }
      } else if (localName == 'pic') {
        // Embedded picture — extract via relationship
        final image = _extractImage(child, relsMap, fileMap);
        if (image != null) images.add(image);
      }
    }

    return PptxSlide(
      slideNumber: slideNumber,
      title: title,
      shapes: shapes,
      tables: tables,
      images: images,
    );
  }

  /// Supported image MIME types / extensions in PPTX media.
  static const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.tiff', '.tif'};

  /// Extracts embedded image bytes from a `<p:pic>` element.
  static PptxImage? _extractImage(
    xml.XmlElement picElement,
    Map<String, String> relsMap,
    Map<String, ArchiveFile> fileMap,
  ) {
    try {
      // <p:pic><p:blipFill><a:blip r:embed="rId2"/></p:blipFill></p:pic>
      final blip = picElement.findAllElements('a:blip').firstOrNull;
      if (blip == null) return null;

      // r:embed attribute holds the relationship ID
      final rId = blip.getAttribute('r:embed') ??
          blip.getAttribute('embed') ??
          blip.attributes
              .where((a) => a.name.local == 'embed')
              .map((a) => a.value)
              .firstOrNull;
      if (rId == null || rId.isEmpty) return null;

      // Resolve rId to target path via relationships
      final target = relsMap[rId];
      if (target == null || target.isEmpty) return null;

      // Target is relative to ppt/slides/ → resolve to ppt/media/...
      // Common forms: "../media/image1.png" or "media/image1.png"
      String mediaPath;
      if (target.startsWith('../')) {
        mediaPath = 'ppt/${target.substring(3)}';
      } else if (target.startsWith('/')) {
        mediaPath = target.substring(1);
      } else {
        mediaPath = 'ppt/slides/$target';
      }

      final ext = _imageExtensions.firstWhere(
        (e) => mediaPath.toLowerCase().endsWith(e),
        orElse: () => '',
      );
      if (ext.isEmpty) return null; // not a supported image type

      final archiveFile = fileMap[mediaPath.toLowerCase()];
      if (archiveFile == null) return null;

      final bytes = archiveFile.content;
      if (bytes == null || (bytes as List).isEmpty) return null;

      return PptxImage(bytes: Uint8List.fromList(bytes as List<int>));
    } catch (_) {
      return null;
    }
  }

  static PptxShape _parseShape(xml.XmlElement spElement) {
    // 1. Check if title placeholder
    bool isTitle = false;
    final ph = spElement.findAllElements('p:ph').firstOrNull;
    if (ph != null) {
      final phType = (ph.getAttribute('type') ?? '').toLowerCase();
      if (phType == 'title' || phType == 'ctrtitle' || phType == 'sub_title') {
        isTitle = true;
      }
    }

    final cNvPr = spElement.findAllElements('p:cNvPr').firstOrNull;
    final shapeName = cNvPr?.getAttribute('name');
    if (shapeName != null && shapeName.toLowerCase().contains('title')) {
      isTitle = true;
    }

    final txBody = spElement.findElements('p:txBody').firstOrNull;
    if (txBody == null) {
      return PptxShape(name: shapeName, isTitle: isTitle, paragraphs: const []);
    }

    final List<PptxParagraph> paragraphs = [];

    for (final p in txBody.findElements('a:p')) {
      final parsedP = _parseParagraph(p);
      if (parsedP.runs.isNotEmpty) {
        paragraphs.add(parsedP);
      }
    }

    return PptxShape(
      name: shapeName,
      isTitle: isTitle,
      paragraphs: paragraphs,
    );
  }

  static PptxParagraph _parseParagraph(xml.XmlElement pElement) {
    final pPr = pElement.findElements('a:pPr').firstOrNull;
    bool isBullet = false;
    int bulletLevel = 0;
    TextAlign align = TextAlign.start;

    if (pPr != null) {
      final lvlStr = pPr.getAttribute('lvl');
      if (lvlStr != null) {
        bulletLevel = int.tryParse(lvlStr) ?? 0;
      }

      final buNone = pPr.findElements('a:buNone').firstOrNull;
      if (buNone == null) {
        if (bulletLevel > 0 ||
            pPr.findElements('a:buChar').isNotEmpty ||
            pPr.findElements('a:buAutoNum').isNotEmpty ||
            pPr.findElements('a:buBlip').isNotEmpty) {
          isBullet = true;
        }
      }

      final algn = pPr.getAttribute('algn');
      if (algn != null) {
        switch (algn) {
          case 'ctr':
            align = TextAlign.center;
            break;
          case 'r':
            align = TextAlign.right;
            break;
          case 'just':
            align = TextAlign.justify;
            break;
        }
      }
    }

    final List<PptxRun> runs = [];

    for (final child in pElement.children.whereType<xml.XmlElement>()) {
      if (child.name.local == 'r') {
        final run = _parseRun(child);
        if (run.text.isNotEmpty) {
          runs.add(run);
        }
      } else if (child.name.local == 'br') {
        runs.add(const PptxRun(text: '\n'));
      }
    }

    return PptxParagraph(
      runs: runs,
      isBullet: isBullet,
      bulletLevel: bulletLevel,
      alignment: align,
    );
  }

  static PptxRun _parseRun(xml.XmlElement rElement) {
    final rPr = rElement.findElements('a:rPr').firstOrNull;
    bool bold = false;
    bool italic = false;
    bool underline = false;
    Color? color;
    double? fontSize;

    if (rPr != null) {
      final b = rPr.getAttribute('b');
      bold = (b == '1' || b == 'true');

      final i = rPr.getAttribute('i');
      italic = (i == '1' || i == 'true');

      final u = rPr.getAttribute('u');
      underline = (u != null && u != 'none');

      // Font size in hundredths of a point (e.g. 2400 = 24pt)
      final sz = rPr.getAttribute('sz');
      if (sz != null) {
        final pt = double.tryParse(sz);
        if (pt != null && pt > 0) {
          fontSize = pt / 100.0;
        }
      }

      // Solid fill color: <a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>
      final solidFill = rPr.findElements('a:solidFill').firstOrNull;
      if (solidFill != null) {
        final srgb = solidFill.findElements('a:srgbClr').firstOrNull;
        if (srgb != null) {
          final hex = srgb.getAttribute('val');
          if (hex != null && hex.length == 6) {
            final intVal = int.tryParse(hex, radix: 16);
            if (intVal != null && intVal != 0x000000) {
              color = Color(0xFF000000 | intVal);
            }
          }
        }
      }
    }

    final t = rElement.findElements('a:t').firstOrNull;
    final text = t?.innerText ?? '';

    return PptxRun(
      text: text,
      isBold: bold,
      isItalic: italic,
      isUnderline: underline,
      color: color,
      fontSize: fontSize,
    );
  }

  static PptxTable _parseTable(xml.XmlElement tblElement) {
    final List<PptxTableRow> rows = [];

    for (final tr in tblElement.findElements('a:tr')) {
      final List<PptxTableCell> cells = [];
      for (final tc in tr.findElements('a:tc')) {
        final List<PptxParagraph> cellParagraphs = [];
        final txBody = tc.findElements('a:txBody').firstOrNull;
        if (txBody != null) {
          for (final p in txBody.findElements('a:p')) {
            final parsedP = _parseParagraph(p);
            if (parsedP.runs.isNotEmpty) {
              cellParagraphs.add(parsedP);
            }
          }
        }

        Color? cellBg;
        final tcPr = tc.findElements('a:tcPr').firstOrNull;
        if (tcPr != null) {
          final solidFill = tcPr.findElements('a:solidFill').firstOrNull;
          if (solidFill != null) {
            final srgb = solidFill.findElements('a:srgbClr').firstOrNull;
            if (srgb != null) {
              final hex = srgb.getAttribute('val');
              if (hex != null && hex.length == 6) {
                final intVal = int.tryParse(hex, radix: 16);
                if (intVal != null) {
                  cellBg = Color(0xFF000000 | intVal);
                }
              }
            }
          }
        }

        cells.add(PptxTableCell(paragraphs: cellParagraphs, backgroundColor: cellBg));
      }
      rows.add(PptxTableRow(cells: cells));
    }

    return PptxTable(rows: rows);
  }
}
