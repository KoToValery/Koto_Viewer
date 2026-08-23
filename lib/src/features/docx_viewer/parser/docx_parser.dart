import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import '../models/docx_models.dart';

/// Helper style representation parsed from word/styles.xml.
class _DocxParsedStyle {
  final double? indentLeft;
  final double? spaceBefore;
  final double? spaceAfter;
  final double? fontSize;
  final bool? isBold;
  final TextAlign? alignment;

  const _DocxParsedStyle({
    this.indentLeft,
    this.spaceBefore,
    this.spaceAfter,
    this.fontSize,
    this.isBold,
    this.alignment,
  });
}

/// Helper numbering level format parsed from word/numbering.xml.
class _DocxNumberingLvl {
  final String text;
  final double indentLeft;
  final double hanging;

  const _DocxNumberingLvl({
    required this.text,
    this.indentLeft = 54.0,
    this.hanging = 18.0,
  });
}

/// Pure-Dart Word Document (.docx) Parser with 1:1 Page Geometry,
/// Styles, Numbering, Logos/Images, Page Frames, and Table Borders.
class DocxParser {
  /// Parses bytes of a .docx file into a structured [DocxDocument].
  static DocxDocument parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXmlFile = archive.findFile('word/document.xml');

    if (documentXmlFile == null) {
      throw Exception('Invalid DOCX format: word/document.xml missing.');
    }

    // 1. Extract Images and Relationship Mapping
    final Map<String, Uint8List> imagesMap = {};
    final Map<String, String> relsMap = {};

    final relsFile = archive.findFile('word/_rels/document.xml.rels');
    if (relsFile != null) {
      try {
        final relsStr = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
        final relsDoc = xml.XmlDocument.parse(relsStr);
        for (final rel in relsDoc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null) {
            relsMap[id] = target;
          }
        }
      } catch (_) {}
    }

    // Load actual image bytes
    for (final entry in archive) {
      if (entry.isFile && entry.name.startsWith('word/media/')) {
        final fileName = entry.name.replaceFirst('word/', '');
        imagesMap[fileName] = Uint8List.fromList(entry.content as List<int>);
        // Also map just the bare filename e.g. media/image1.png
        imagesMap[entry.name] = imagesMap[fileName]!;
      }
    }

    // 2. Parse word/styles.xml
    final Map<String, _DocxParsedStyle> stylesMap = {};
    final stylesFile = archive.findFile('word/styles.xml');
    if (stylesFile != null) {
      try {
        final stylesStr = utf8.decode(stylesFile.content as List<int>, allowMalformed: true);
        final stylesDoc = xml.XmlDocument.parse(stylesStr);
        for (final styleElem in stylesDoc.findAllElements('w:style')) {
          final styleId = styleElem.getAttribute('w:styleId');
          if (styleId != null) {
            stylesMap[styleId] = _parseStyleElement(styleElem);
          }
        }
      } catch (_) {}
    }

    // 3. Parse word/numbering.xml
    final Map<String, _DocxNumberingLvl> numberingMap = {};
    final numberingFile = archive.findFile('word/numbering.xml');
    if (numberingFile != null) {
      try {
        final numStr = utf8.decode(numberingFile.content as List<int>, allowMalformed: true);
        final numDoc = xml.XmlDocument.parse(numStr);
        _parseNumberingDoc(numDoc, numberingMap);
      } catch (_) {}
    }

    // 4. Parse word/document.xml
    final xmlString = utf8.decode(documentXmlFile.content as List<int>);
    final documentXml = xml.XmlDocument.parse(xmlString);

    final bodyElement = documentXml.findAllElements('w:body').firstOrNull;
    if (bodyElement == null) {
      return const DocxDocument(blocks: []);
    }

    // Parse Page Settings & Shapes
    final sectPrElement = bodyElement.findElements('w:sectPr').firstOrNull;
    final List<DocxDrawingShape> pageShapes = [];

    // Extract Page Frame Lines from leading paragraphs (e.g. teal frame lines)
    for (final p in bodyElement.findElements('w:p')) {
      for (final line in p.findAllElements('v:line')) {
        final shape = _parseVmlLine(line);
        if (shape != null) pageShapes.add(shape);
      }
    }

    final pageSettings = _parsePageSettings(sectPrElement, pageShapes);

    // Parse Content Blocks
    final List<DocxBlock> blocks = [];

    for (final child in bodyElement.children.whereType<xml.XmlElement>()) {
      if (child.name.local == 'p') {
        final paragraph = _parseParagraph(child, stylesMap, numberingMap, relsMap, imagesMap);
        if (paragraph != null) {
          blocks.add(paragraph);
        }
      } else if (child.name.local == 'tbl') {
        final table = _parseTable(child, stylesMap, numberingMap, relsMap, imagesMap);
        if (table.rows.isNotEmpty) {
          blocks.add(table);
        }
      }
    }

    // Partition into Pages by Page Breaks
    final List<DocxPage> pages = [];
    List<DocxBlock> currentPageBlocks = [];
    int pageNum = 1;

    for (final block in blocks) {
      if (block is DocxParagraph && block.isPageBreak && currentPageBlocks.isNotEmpty) {
        pages.add(DocxPage(
          pageNumber: pageNum++,
          settings: pageSettings,
          blocks: List.unmodifiable(currentPageBlocks),
        ));
        currentPageBlocks = [];
      }
      currentPageBlocks.add(block);
    }

    if (currentPageBlocks.isNotEmpty || pages.isEmpty) {
      pages.add(DocxPage(
        pageNumber: pageNum,
        settings: pageSettings,
        blocks: List.unmodifiable(currentPageBlocks),
      ));
    }

    return DocxDocument(
      blocks: blocks,
      pageSettings: pageSettings,
      pages: pages,
      images: imagesMap,
    );
  }

  static _DocxParsedStyle _parseStyleElement(xml.XmlElement styleElem) {
    double? indentLeft;
    double? spaceBefore;
    double? spaceAfter;
    double? fontSize;
    bool? isBold;
    TextAlign? alignment;

    final pPr = styleElem.findElements('w:pPr').firstOrNull;
    if (pPr != null) {
      final ind = pPr.findElements('w:ind').firstOrNull;
      if (ind != null) {
        final leftDxa = double.tryParse(ind.getAttribute('w:left') ?? '');
        if (leftDxa != null) indentLeft = leftDxa / 20.0;
      }
      final spacing = pPr.findElements('w:spacing').firstOrNull;
      if (spacing != null) {
        final bDxa = double.tryParse(spacing.getAttribute('w:before') ?? '');
        final aDxa = double.tryParse(spacing.getAttribute('w:after') ?? '');
        if (bDxa != null) spaceBefore = bDxa / 20.0;
        if (aDxa != null) spaceAfter = aDxa / 20.0;
      }
      final jc = pPr.findElements('w:jc').firstOrNull;
      if (jc != null) {
        final val = (jc.getAttribute('w:val') ?? '').toLowerCase();
        if (val == 'center') {
          alignment = TextAlign.center;
        } else if (val == 'right') {
          alignment = TextAlign.right;
        } else if (val == 'both' || val == 'justify') {
          alignment = TextAlign.justify;
        }
      }
    }

    final rPr = styleElem.findElements('w:rPr').firstOrNull;
    if (rPr != null) {
      final sz = rPr.findElements('w:sz').firstOrNull;
      if (sz != null) {
        final halfPts = double.tryParse(sz.getAttribute('w:val') ?? '');
        if (halfPts != null) fontSize = halfPts / 2.0;
      }
      if (rPr.findElements('w:b').isNotEmpty) {
        final bVal = rPr.findElements('w:b').first.getAttribute('w:val');
        isBold = (bVal == null || bVal == '1' || bVal == 'true');
      }
    }

    return _DocxParsedStyle(
      indentLeft: indentLeft,
      spaceBefore: spaceBefore,
      spaceAfter: spaceAfter,
      fontSize: fontSize,
      isBold: isBold,
      alignment: alignment,
    );
  }

  static void _parseNumberingDoc(
    xml.XmlDocument numDoc,
    Map<String, _DocxNumberingLvl> numberingMap,
  ) {
    final Map<String, xml.XmlElement> abstractNums = {};
    for (final abs in numDoc.findAllElements('w:abstractNum')) {
      final id = abs.getAttribute('w:abstractNumId');
      if (id != null) abstractNums[id] = abs;
    }

    for (final num in numDoc.findAllElements('w:num')) {
      final numId = num.getAttribute('w:numId');
      final absRef = num.findElements('w:abstractNumId').firstOrNull?.getAttribute('w:val');
      if (numId != null && absRef != null && abstractNums.containsKey(absRef)) {
        final absElem = abstractNums[absRef]!;
        for (final lvl in absElem.findElements('w:lvl')) {
          final ilvl = lvl.getAttribute('w:ilvl') ?? '0';
          final lvlText = lvl.findElements('w:lvlText').firstOrNull?.getAttribute('w:val') ?? '-';
          double indLeft = 54.0;
          double hanging = 18.0;

          final pPr = lvl.findElements('w:pPr').firstOrNull;
          if (pPr != null) {
            final ind = pPr.findElements('w:ind').firstOrNull;
            if (ind != null) {
              final lDxa = double.tryParse(ind.getAttribute('w:left') ?? '');
              final hDxa = double.tryParse(ind.getAttribute('w:hanging') ?? '');
              if (lDxa != null) indLeft = lDxa / 20.0;
              if (hDxa != null) hanging = hDxa / 20.0;
            }
          }

          numberingMap['$numId:$ilvl'] = _DocxNumberingLvl(
            text: lvlText == '%' ? '-' : lvlText,
            indentLeft: indLeft,
            hanging: hanging,
          );
        }
      }
    }
  }

  static DocxDrawingShape? _parseVmlLine(xml.XmlElement line) {
    final fromStr = line.getAttribute('from');
    final toStr = line.getAttribute('to');
    final strokeColorStr = line.getAttribute('strokecolor') ?? 'teal';

    if (fromStr == null || toStr == null) return null;

    final fromOffset = _parsePtOffset(fromStr);
    final toOffset = _parsePtOffset(toStr);

    if (fromOffset == null || toOffset == null) return null;

    // Ignore 0-length points
    if ((fromOffset.dx - toOffset.dx).abs() < 1.0 && (fromOffset.dy - toOffset.dy).abs() < 1.0) {
      return null;
    }

    Color color = const Color(0xFF008080); // Teal default
    if (strokeColorStr.toLowerCase() == 'teal') {
      color = const Color(0xFF008080);
    } else if (strokeColorStr.startsWith('#')) {
      final hex = strokeColorStr.replaceAll('#', '');
      final intVal = int.tryParse(hex, radix: 16);
      if (intVal != null) color = Color(0xFF000000 | intVal);
    }

    return DocxDrawingShape(
      from: fromOffset,
      to: toOffset,
      color: color,
      strokeWidth: 1.2,
      isLine: true,
    );
  }

  static Offset? _parsePtOffset(String str) {
    final parts = str.split(',');
    if (parts.length != 2) return null;
    final x = double.tryParse(parts[0].replaceAll('pt', '').trim());
    final y = double.tryParse(parts[1].replaceAll('pt', '').trim());
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  /// Parses page geometry and margins from `<w:sectPr>` (dimensions in dxa / twips).
  static DocxPageSettings _parsePageSettings(
    xml.XmlElement? sectPr,
    List<DocxDrawingShape> pageShapes,
  ) {
    if (sectPr == null) {
      return DocxPageSettings(pageShapes: pageShapes);
    }

    double widthPt = 595.3;
    double heightPt = 841.9;
    bool isLandscape = false;
    String paperName = 'A4';

    // Page Size (<w:pgSz w:w="11910" w:h="16840"/>)
    final pgSz = sectPr.findElements('w:pgSz').firstOrNull;
    if (pgSz != null) {
      final wDxa = double.tryParse(pgSz.getAttribute('w:w') ?? '');
      final hDxa = double.tryParse(pgSz.getAttribute('w:h') ?? '');
      final orient = (pgSz.getAttribute('w:orient') ?? '').toLowerCase();

      if (wDxa != null && wDxa > 0) widthPt = wDxa / 20.0;
      if (hDxa != null && hDxa > 0) heightPt = hDxa / 20.0;

      if (orient == 'landscape' || widthPt > heightPt) {
        isLandscape = true;
      }

      if ((widthPt - 595.3).abs() < 20 && (heightPt - 841.9).abs() < 20) {
        paperName = 'A4';
      } else if ((widthPt - 612.0).abs() < 20 && (heightPt - 792.0).abs() < 20) {
        paperName = 'Letter';
      } else if ((widthPt - 612.0).abs() < 20 && (heightPt - 1008.0).abs() < 20) {
        paperName = 'Legal';
      } else if ((widthPt - 841.9).abs() < 20 && (heightPt - 1190.6).abs() < 20) {
        paperName = 'A3';
      }
    }

    // Margins (<w:pgMar w:top="480" w:right="1140" w:bottom="280" w:left="1680"/>)
    double topPt = 24.0;
    double rightPt = 57.0;
    double bottomPt = 14.0;
    double leftPt = 84.0;

    final pgMar = sectPr.findElements('w:pgMar').firstOrNull;
    if (pgMar != null) {
      final topDxa = double.tryParse(pgMar.getAttribute('w:top') ?? '');
      final rightDxa = double.tryParse(pgMar.getAttribute('w:right') ?? '');
      final bottomDxa = double.tryParse(pgMar.getAttribute('w:bottom') ?? '');
      final leftDxa = double.tryParse(pgMar.getAttribute('w:left') ?? '');

      if (topDxa != null) topPt = (topDxa / 20.0).clamp(5.0, 150.0);
      if (rightDxa != null) rightPt = (rightDxa / 20.0).clamp(5.0, 150.0);
      if (bottomDxa != null) bottomPt = (bottomDxa / 20.0).clamp(5.0, 150.0);
      if (leftDxa != null) leftPt = (leftDxa / 20.0).clamp(5.0, 150.0);
    }

    return DocxPageSettings(
      widthPt: widthPt,
      heightPt: heightPt,
      isLandscape: isLandscape,
      margins: EdgeInsets.fromLTRB(leftPt, topPt, rightPt, bottomPt),
      paperName: paperName,
      pageShapes: pageShapes,
    );
  }

  static DocxParagraph? _parseParagraph(
    xml.XmlElement pElement,
    Map<String, _DocxParsedStyle> stylesMap,
    Map<String, _DocxNumberingLvl> numberingMap,
    Map<String, String> relsMap,
    Map<String, Uint8List> imagesMap,
  ) {
    final pPr = pElement.findElements('w:pPr').firstOrNull;

    DocxHeadingLevel heading = DocxHeadingLevel.none;
    bool isBullet = false;
    String? listPrefix;
    TextAlign align = TextAlign.start;
    double spaceBefore = 0.0;
    double spaceAfter = 0.0;
    double? lineSpacing;
    double indentLeft = 0.0;
    double indentFirstLine = 0.0;
    final List<double> tabPositions = [];
    bool isPageBreak = false;
    DocxBorder? bottomBorder;

    // Paragraph-level fallback formatting from <w:pPr><w:rPr>
    double? pFontSize;
    String? pFontFamily;
    bool? pBold;
    bool? pItalic;
    Color? pColor;

    // Check Style Inheritance
    String? styleId;
    if (pPr != null) {
      final pStyle = pPr.findElements('w:pStyle').firstOrNull;
      if (pStyle != null) {
        styleId = pStyle.getAttribute('w:val');
      }
    }

    if (styleId != null && stylesMap.containsKey(styleId)) {
      final st = stylesMap[styleId]!;
      if (st.indentLeft != null) indentLeft = st.indentLeft!;
      if (st.spaceBefore != null) spaceBefore = st.spaceBefore!;
      if (st.spaceAfter != null) spaceAfter = st.spaceAfter!;
      if (st.alignment != null) align = st.alignment!;
      if (st.fontSize != null) pFontSize = st.fontSize;
      if (st.isBold != null) pBold = st.isBold;
    }

    if (pPr != null) {
      // 0. Paragraph-level run properties
      final pRPr = pPr.findElements('w:rPr').firstOrNull;
      if (pRPr != null) {
        final szElem = pRPr.findElements('w:sz').firstOrNull;
        if (szElem != null) {
          final halfPts = double.tryParse(szElem.getAttribute('w:val') ?? '');
          if (halfPts != null && halfPts > 0) pFontSize = halfPts / 2.0;
        }
        if (pRPr.findElements('w:b').isNotEmpty) {
          final bVal = pRPr.findElements('w:b').first.getAttribute('w:val');
          pBold = (bVal == null || bVal == '1' || bVal == 'true');
        }
        if (pRPr.findElements('w:i').isNotEmpty) {
          final iVal = pRPr.findElements('w:i').first.getAttribute('w:val');
          pItalic = (iVal == null || iVal == '1' || iVal == 'true');
        }
        final colorElem = pRPr.findElements('w:color').firstOrNull;
        if (colorElem != null) {
          final hex = colorElem.getAttribute('w:val');
          if (hex != null && hex.length == 6 && hex.toLowerCase() != 'auto') {
            final intVal = int.tryParse(hex, radix: 16);
            if (intVal != null && intVal != 0x000000) {
              pColor = Color(0xFF000000 | intVal);
            }
          }
        }
        final rFonts = pRPr.findElements('w:rFonts').firstOrNull;
        if (rFonts != null) {
          pFontFamily = rFonts.getAttribute('w:ascii') ??
              rFonts.getAttribute('w:hAnsi') ??
              rFonts.getAttribute('w:cs');
        }
      }

      // 1. Heading style name
      if (styleId != null) {
        final val = styleId.toLowerCase();
        if (val.contains('title')) {
          heading = DocxHeadingLevel.title;
        } else if (val.contains('heading 1') || val == 'heading1' || val == '1') {
          heading = DocxHeadingLevel.h1;
        } else if (val.contains('heading 2') || val == 'heading2' || val == '2') {
          heading = DocxHeadingLevel.h2;
        } else if (val.contains('heading 3') || val == 'heading3' || val == '3') {
          heading = DocxHeadingLevel.h3;
        } else if (val.contains('heading 4') || val == 'heading4' || val == '4') {
          heading = DocxHeadingLevel.h4;
        }
      }

      // 2. Numbering / Bullet list (<w:numPr>)
      final numPr = pPr.findElements('w:numPr').firstOrNull;
      if (numPr != null) {
        isBullet = true;
        final numId = numPr.findElements('w:numId').firstOrNull?.getAttribute('w:val') ?? '1';
        final ilvl = numPr.findElements('w:ilvl').firstOrNull?.getAttribute('w:val') ?? '0';
        final key = '$numId:$ilvl';

        if (numberingMap.containsKey(key)) {
          final nLvl = numberingMap[key]!;
          listPrefix = nLvl.text;
          indentLeft = nLvl.indentLeft;
        } else {
          listPrefix = '-';
          indentLeft = 40.0;
        }
      }

      // 3. Alignment
      final jc = pPr.findElements('w:jc').firstOrNull;
      if (jc != null) {
        final val = (jc.getAttribute('w:val') ?? '').toLowerCase();
        if (val == 'center') {
          align = TextAlign.center;
        } else if (val == 'right') {
          align = TextAlign.right;
        } else if (val == 'both' || val == 'justify') {
          align = TextAlign.justify;
        }
      }

      // 4. Spacing
      final spacing = pPr.findElements('w:spacing').firstOrNull;
      if (spacing != null) {
        final beforeDxa = double.tryParse(spacing.getAttribute('w:before') ?? '');
        final afterDxa = double.tryParse(spacing.getAttribute('w:after') ?? '');
        final lineDxa = double.tryParse(spacing.getAttribute('w:line') ?? '');

        if (beforeDxa != null) spaceBefore = (beforeDxa / 20.0).clamp(0.0, 72.0);
        if (afterDxa != null) spaceAfter = (afterDxa / 20.0).clamp(0.0, 72.0);
        if (lineDxa != null && lineDxa > 0) lineSpacing = (lineDxa / 240.0).clamp(0.8, 3.0);
      }

      // 5. Indents (Explicit overrides style)
      final ind = pPr.findElements('w:ind').firstOrNull;
      if (ind != null) {
        final leftDxa = double.tryParse(ind.getAttribute('w:left') ?? '');
        final firstLineDxa = double.tryParse(ind.getAttribute('w:firstLine') ?? '');

        if (leftDxa != null) indentLeft = (leftDxa / 20.0).clamp(0.0, 300.0);
        if (firstLineDxa != null) indentFirstLine = (firstLineDxa / 20.0).clamp(-100.0, 100.0);
      }

      // 6. Tab stops (<w:tabs><w:tab w:val="left" w:pos="4299"/></w:tabs>)
      final tabs = pPr.findElements('w:tabs').firstOrNull;
      if (tabs != null) {
        for (final tab in tabs.findElements('w:tab')) {
          final posDxa = double.tryParse(tab.getAttribute('w:pos') ?? '');
          if (posDxa != null && posDxa > 0) {
            tabPositions.add(posDxa / 20.0);
          }
        }
      }

      // 7. Page break
      if (pPr.findElements('w:pageBreakBefore').isNotEmpty) {
        isPageBreak = true;
      }

      // 8. Paragraph bottom border
      final pBdr = pPr.findElements('w:pBdr').firstOrNull;
      if (pBdr != null) {
        final bottomElem = pBdr.findElements('w:bottom').firstOrNull;
        if (bottomElem != null) {
          bottomBorder = _parseBorderElement(bottomElem);
        }
      }
    }

    // Check for Header Box (Logo + Company Text) or Horizontal Divider Bar in Drawing/Pict
    DocxHeaderBox? headerBox;
    DocxImageBlock? imageBlock;

    final drawings = pElement.findAllElements('w:drawing');
    final picts = pElement.findAllElements('w:pict');

    if (drawings.isNotEmpty || picts.isNotEmpty) {
      // 1. Check if it's a Header Box with Image + Textbox
      final txbxElements = pElement.findAllElements('w:txbxContent');
      Uint8List? logoBytes;

      for (final blip in pElement.findAllElements('a:blip')) {
        final rId = blip.getAttribute('r:embed');
        if (rId != null && relsMap.containsKey(rId)) {
          final target = relsMap[rId]!;
          if (imagesMap.containsKey(target) || imagesMap.containsKey('word/$target')) {
            logoBytes = imagesMap[target] ?? imagesMap['word/$target'];
          }
        }
      }
      for (final imgData in pElement.findAllElements('v:imagedata')) {
        final rId = imgData.getAttribute('r:id');
        if (rId != null && relsMap.containsKey(rId)) {
          final target = relsMap[rId]!;
          if (imagesMap.containsKey(target) || imagesMap.containsKey('word/$target')) {
            logoBytes ??= imagesMap[target] ?? imagesMap['word/$target'];
          }
        }
      }

      if (txbxElements.isNotEmpty || logoBytes != null) {
        final List<String> headerLines = [];
        for (final txbx in txbxElements) {
          for (final p in txbx.findAllElements('w:p')) {
            final text = p.findAllElements('w:t').map((e) => e.innerText).join();
            if (text.trim().isNotEmpty && !headerLines.contains(text.trim())) {
              headerLines.add(text.trim());
            }
          }
        }

        if (logoBytes != null || headerLines.isNotEmpty) {
          headerBox = DocxHeaderBox(
            logoBytes: logoBytes,
            logoWidthPt: 85.0,
            logoHeightPt: 65.0,
            headerLines: headerLines,
          );
        }
      }

      // 2. Check for Horizontal Rule Bar (<v:rect fillcolor="#ccc"> or <wps:wsp>)
      for (final rect in pElement.findAllElements('v:rect')) {
        final style = rect.getAttribute('style') ?? '';
        if (style.contains('width:') && (style.contains('height:2') || style.contains('height:1') || style.contains('height:3'))) {
          bottomBorder = const DocxBorder(
            hasBorder: true,
            color: Color(0xFFCCCCCC),
            width: 2.0,
          );
        }
      }
    }

    final List<DocxRun> runs = [];

    for (final child in pElement.children.whereType<xml.XmlElement>()) {
      if (child.name.local == 'r') {
        for (final br in child.findElements('w:br')) {
          if (br.getAttribute('w:type') == 'page') {
            isPageBreak = true;
          }
        }
        if (child.findElements('w:lastRenderedPageBreak').isNotEmpty) {
          isPageBreak = true;
        }

        final parsedRuns = _parseRun(
          child,
          fallbackFontSize: pFontSize,
          fallbackFontFamily: pFontFamily,
          fallbackBold: pBold,
          fallbackItalic: pItalic,
          fallbackColor: pColor,
        );
        for (final run in parsedRuns) {
          if (run.text.isNotEmpty || run.isTab) {
            runs.add(run);
          }
        }
      } else if (child.name.local == 'hyperlink') {
        for (final r in child.findElements('w:r')) {
          final parsedRuns = _parseRun(
            r,
            overrideColor: const Color(0xFF2563EB),
            isUnderline: true,
            fallbackFontSize: pFontSize,
            fallbackFontFamily: pFontFamily,
            fallbackBold: pBold,
            fallbackItalic: pItalic,
          );
          for (final run in parsedRuns) {
            if (run.text.isNotEmpty || run.isTab) {
              runs.add(run);
            }
          }
        }
      }
    }

    // Filter out completely empty paragraphs unless they have spacing or borders
    if (runs.isEmpty && headerBox == null && imageBlock == null && bottomBorder == null && !isPageBreak) {
      if (spaceBefore == 0 && spaceAfter == 0) {
        return null;
      }
    }

    return DocxParagraph(
      runs: runs,
      headingLevel: heading,
      isBullet: isBullet,
      listPrefix: listPrefix,
      alignment: align,
      spaceBefore: spaceBefore,
      spaceAfter: spaceAfter,
      lineSpacing: lineSpacing,
      indentLeft: indentLeft,
      indentFirstLine: indentFirstLine,
      tabPositions: tabPositions,
      isPageBreak: isPageBreak,
      bottomBorder: bottomBorder,
      imageBlock: imageBlock,
      headerBox: headerBox,
    );
  }

  static List<DocxRun> _parseRun(
    xml.XmlElement rElement, {
    Color? overrideColor,
    bool? isUnderline,
    double? fallbackFontSize,
    String? fallbackFontFamily,
    bool? fallbackBold,
    bool? fallbackItalic,
    Color? fallbackColor,
  }) {
    final rPr = rElement.findElements('w:rPr').firstOrNull;

    bool bold = fallbackBold ?? false;
    bool italic = fallbackItalic ?? false;
    bool underline = isUnderline ?? false;
    bool strike = false;
    Color? color = overrideColor ?? fallbackColor;
    double? fontSize = fallbackFontSize;
    String? fontFamily = fallbackFontFamily;
    bool isTab = false;

    if (rPr != null) {
      if (rPr.findElements('w:b').isNotEmpty) {
        final b = rPr.findElements('w:b').first;
        final val = b.getAttribute('w:val');
        bold = (val == null || val == '1' || val == 'true');
      }
      if (rPr.findElements('w:i').isNotEmpty) {
        final i = rPr.findElements('w:i').first;
        final val = i.getAttribute('w:val');
        italic = (val == null || val == '1' || val == 'true');
      }
      if (rPr.findElements('w:u').isNotEmpty) {
        final u = rPr.findElements('w:u').first;
        final val = u.getAttribute('w:val');
        underline = (val == null || val != 'none');
      }
      if (rPr.findElements('w:strike').isNotEmpty) {
        strike = true;
      }

      final colorElem = rPr.findElements('w:color').firstOrNull;
      if (colorElem != null && overrideColor == null) {
        final hex = colorElem.getAttribute('w:val');
        if (hex != null && hex.length == 6 && hex.toLowerCase() != 'auto') {
          final intVal = int.tryParse(hex, radix: 16);
          if (intVal != null && intVal != 0x000000) {
            color = Color(0xFF000000 | intVal);
          }
        }
      }

      final szElem = rPr.findElements('w:sz').firstOrNull;
      if (szElem != null) {
        final halfPts = double.tryParse(szElem.getAttribute('w:val') ?? '');
        if (halfPts != null && halfPts > 0) {
          fontSize = halfPts / 2.0;
        }
      }

      final rFonts = rPr.findElements('w:rFonts').firstOrNull;
      if (rFonts != null) {
        fontFamily = rFonts.getAttribute('w:ascii') ??
            rFonts.getAttribute('w:hAnsi') ??
            rFonts.getAttribute('w:cs');
      }
    }

    if (rPr != null) {
      if (rPr.findElements('w:b').isNotEmpty) {
        final b = rPr.findElements('w:b').first;
        final val = b.getAttribute('w:val');
        bold = (val == null || val == '1' || val == 'true');
      }
      if (rPr.findElements('w:i').isNotEmpty) {
        final i = rPr.findElements('w:i').first;
        final val = i.getAttribute('w:val');
        italic = (val == null || val == '1' || val == 'true');
      }
      if (rPr.findElements('w:u').isNotEmpty) {
        final u = rPr.findElements('w:u').first;
        final val = u.getAttribute('w:val');
        underline = (val == null || val != 'none');
      }
      if (rPr.findElements('w:strike').isNotEmpty) {
        strike = true;
      }

      final colorElem = rPr.findElements('w:color').firstOrNull;
      if (colorElem != null && overrideColor == null) {
        final hex = colorElem.getAttribute('w:val');
        if (hex != null && hex.length == 6 && hex.toLowerCase() != 'auto') {
          final intVal = int.tryParse(hex, radix: 16);
          if (intVal != null && intVal != 0x000000) {
            color = Color(0xFF000000 | intVal);
          }
        }
      }

      final szElem = rPr.findElements('w:sz').firstOrNull;
      if (szElem != null) {
        final halfPts = double.tryParse(szElem.getAttribute('w:val') ?? '');
        if (halfPts != null && halfPts > 0) {
          fontSize = halfPts / 2.0;
        }
      }

      final rFonts = rPr.findElements('w:rFonts').firstOrNull;
      if (rFonts != null) {
        fontFamily = rFonts.getAttribute('w:ascii') ??
            rFonts.getAttribute('w:hAnsi') ??
            rFonts.getAttribute('w:cs');
      }
    }

    final List<DocxRun> parsedRuns = [];
    String currentText = '';

    void addCurrentText() {
      if (currentText.isNotEmpty) {
        parsedRuns.add(DocxRun(
          text: currentText,
          isBold: bold,
          isItalic: italic,
          isUnderline: underline,
          isStrike: strike,
          color: color,
          fontSize: fontSize,
          fontFamily: fontFamily,
          isTab: false,
        ));
        currentText = '';
      }
    }

    for (final child in rElement.children.whereType<xml.XmlElement>()) {
      if (child.name.local == 't') {
        currentText += child.innerText;
      } else if (child.name.local == 'tab') {
        addCurrentText();
        parsedRuns.add(DocxRun(
          text: '',
          isBold: bold,
          isItalic: italic,
          isUnderline: underline,
          isStrike: strike,
          color: color,
          fontSize: fontSize,
          fontFamily: fontFamily,
          isTab: true,
        ));
      } else if (child.name.local == 'br') {
        currentText += '\n';
      }
    }
    addCurrentText();

    return parsedRuns;
  }

  static DocxTable _parseTable(
    xml.XmlElement tblElement,
    Map<String, _DocxParsedStyle> stylesMap,
    Map<String, _DocxNumberingLvl> numberingMap,
    Map<String, String> relsMap,
    Map<String, Uint8List> imagesMap,
  ) {
    DocxTableBorders? tableBorders;
    double? totalTableWidth;
    TextAlign tableAlign = TextAlign.start;

    final tblPr = tblElement.findElements('w:tblPr').firstOrNull;
    if (tblPr != null) {
      final tblBordersElem = tblPr.findElements('w:tblBorders').firstOrNull;
      if (tblBordersElem != null) {
        tableBorders = _parseTableBorders(tblBordersElem);
      }

      final tblW = tblPr.findElements('w:tblW').firstOrNull;
      if (tblW != null) {
        final wDxa = double.tryParse(tblW.getAttribute('w:w') ?? '');
        if (wDxa != null && wDxa > 0) {
          totalTableWidth = wDxa / 20.0;
        }
      }

      final jc = tblPr.findElements('w:jc').firstOrNull;
      if (jc != null) {
        final val = (jc.getAttribute('w:val') ?? '').toLowerCase();
        if (val == 'center') {
          tableAlign = TextAlign.center;
        } else if (val == 'right') {
          tableAlign = TextAlign.right;
        }
      }
    }

    final List<double> columnWidths = [];
    final tblGrid = tblElement.findElements('w:tblGrid').firstOrNull;
    if (tblGrid != null) {
      for (final gridCol in tblGrid.findElements('w:gridCol')) {
        final wDxa = double.tryParse(gridCol.getAttribute('w:w') ?? '');
        if (wDxa != null && wDxa > 0) {
          columnWidths.add(wDxa / 20.0);
        }
      }
    }

    final List<DocxTableRow> rows = [];

    for (final tr in tblElement.findElements('w:tr')) {
      final List<DocxTableCell> cells = [];
      bool isHeaderRow = false;
      double? rowHeightPt;

      final trPr = tr.findElements('w:trPr').firstOrNull;
      if (trPr != null) {
        if (trPr.findElements('w:tblHeader').isNotEmpty) {
          isHeaderRow = true;
        }
        final trHeight = trPr.findElements('w:trHeight').firstOrNull;
        if (trHeight != null) {
          final hDxa = double.tryParse(trHeight.getAttribute('w:val') ?? '');
          if (hDxa != null && hDxa > 0) rowHeightPt = hDxa / 20.0;
        }
      }

      for (final tc in tr.findElements('w:tc')) {
        final List<DocxParagraph> cellParagraphs = [];
        for (final p in tc.findElements('w:p')) {
          final parsedP = _parseParagraph(p, stylesMap, numberingMap, relsMap, imagesMap);
          if (parsedP != null) {
            cellParagraphs.add(parsedP);
          }
        }

        Color? cellBg;
        double? cellWidthPt;
        int colSpan = 1;
        int rowSpan = 1;
        Alignment verticalAlign = Alignment.topLeft;
        DocxCellBorders? cellBorders;

        final tcPr = tc.findElements('w:tcPr').firstOrNull;
        if (tcPr != null) {
          final shd = tcPr.findElements('w:shd').firstOrNull;
          if (shd != null) {
            final hex = shd.getAttribute('w:fill');
            if (hex != null && hex.length == 6 && hex.toLowerCase() != 'auto') {
              final intVal = int.tryParse(hex, radix: 16);
              if (intVal != null) {
                cellBg = Color(0xFF000000 | intVal);
              }
            }
          }

          final tcW = tcPr.findElements('w:tcW').firstOrNull;
          if (tcW != null) {
            final wDxa = double.tryParse(tcW.getAttribute('w:w') ?? '');
            if (wDxa != null && wDxa > 0) cellWidthPt = wDxa / 20.0;
          }

          final gridSpan = tcPr.findElements('w:gridSpan').firstOrNull;
          if (gridSpan != null) {
            final spanVal = int.tryParse(gridSpan.getAttribute('w:val') ?? '');
            if (spanVal != null && spanVal > 1) colSpan = spanVal;
          }

          final vAlign = tcPr.findElements('w:vAlign').firstOrNull;
          if (vAlign != null) {
            final val = (vAlign.getAttribute('w:val') ?? '').toLowerCase();
            if (val == 'center') {
              verticalAlign = Alignment.centerLeft;
            } else if (val == 'bottom') {
              verticalAlign = Alignment.bottomLeft;
            }
          }

          final tcBorders = tcPr.findElements('w:tcBorders').firstOrNull;
          if (tcBorders != null) {
            cellBorders = _parseCellBorders(tcBorders);
          }
        }

        cells.add(DocxTableCell(
          paragraphs: cellParagraphs,
          backgroundColor: cellBg,
          widthPt: cellWidthPt,
          colSpan: colSpan,
          rowSpan: rowSpan,
          verticalAlignment: verticalAlign,
          borders: cellBorders,
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        ));
      }
      rows.add(DocxTableRow(
        cells: cells,
        heightPt: rowHeightPt,
        isHeader: isHeaderRow,
      ));
    }

    return DocxTable(
      rows: rows,
      columnWidths: columnWidths,
      borders: tableBorders,
      totalWidthPt: totalTableWidth,
      alignment: tableAlign,
    );
  }

  static DocxTableBorders _parseTableBorders(xml.XmlElement bordersElem) {
    return DocxTableBorders(
      top: _parseBorderElement(bordersElem.findElements('w:top').firstOrNull),
      bottom: _parseBorderElement(bordersElem.findElements('w:bottom').firstOrNull),
      left: _parseBorderElement(bordersElem.findElements('w:left').firstOrNull),
      right: _parseBorderElement(bordersElem.findElements('w:right').firstOrNull),
      insideH: _parseBorderElement(bordersElem.findElements('w:insideH').firstOrNull),
      insideV: _parseBorderElement(bordersElem.findElements('w:insideV').firstOrNull),
    );
  }

  static DocxCellBorders _parseCellBorders(xml.XmlElement bordersElem) {
    return DocxCellBorders(
      top: _parseBorderElement(bordersElem.findElements('w:top').firstOrNull),
      bottom: _parseBorderElement(bordersElem.findElements('w:bottom').firstOrNull),
      left: _parseBorderElement(bordersElem.findElements('w:left').firstOrNull),
      right: _parseBorderElement(bordersElem.findElements('w:right').firstOrNull),
    );
  }

  static DocxBorder? _parseBorderElement(xml.XmlElement? elem) {
    if (elem == null) return null;

    final val = (elem.getAttribute('w:val') ?? '').toLowerCase();
    if (val == 'none' || val == 'nil' || val == 'off') {
      return DocxBorder.none;
    }

    final szVal = double.tryParse(elem.getAttribute('w:sz') ?? '');
    final width = szVal != null ? (szVal / 8.0).clamp(0.5, 6.0) : 1.0;

    Color color = const Color(0xFF000000);
    final colorAttr = elem.getAttribute('w:color');
    if (colorAttr != null && colorAttr.length == 6 && colorAttr.toLowerCase() != 'auto') {
      final intVal = int.tryParse(colorAttr, radix: 16);
      if (intVal != null) {
        color = Color(0xFF000000 | intVal);
      }
    }

    DocxLineStyle style = DocxLineStyle.single;
    if (val.contains('double')) {
      style = DocxLineStyle.double;
    } else if (val.contains('dash')) {
      style = DocxLineStyle.dashed;
    } else if (val.contains('dot')) {
      style = DocxLineStyle.dotted;
    } else if (val.contains('thick')) {
      style = DocxLineStyle.thick;
    }

    return DocxBorder(
      hasBorder: true,
      color: color,
      width: width,
      style: style,
    );
  }
}
