import 'dart:convert';
import 'dart:io';
import '../../features/dxf_viewer/models/dxf_models.dart';

/// Service responsible for exporting DXF files, including merging imported DXF drawings
/// (entities, blocks, layers, styles, and line types) and user-added annotations (LEADER + MTEXT)
/// compliant with AutoCAD DXF standards.
class DxfExporterService {
  /// Injects annotations into the DXF content and writes the result to [outputFile].
  /// Backwards-compatible convenience method delegating to [exportMergedDxf].
  static Future<File> saveDxfWithAnnotations({
    required File originalFile,
    required List<DxfAnnotation> annotations,
    required File outputFile,
    double defaultTextHeight = 2.5,
  }) =>
      exportMergedDxf(
        baseFile: originalFile,
        annotations: annotations,
        outputFile: outputFile,
        defaultTextHeight: defaultTextHeight,
      );

  /// Exports a complete DXF file merging [baseFile] with all [importedFiles]
  /// and any user-added [annotations].
  static Future<File> exportMergedDxf({
    required File baseFile,
    List<File> importedFiles = const [],
    List<DxfAnnotation> annotations = const [],
    required File outputFile,
    double defaultTextHeight = 2.5,
  }) async {
    if (importedFiles.isEmpty && annotations.isEmpty) {
      return baseFile.copy(outputFile.path);
    }

    final baseBytes = await baseFile.readAsBytes();
    String baseContent;
    try {
      baseContent = utf8.decode(baseBytes);
    } on FormatException catch (_) {
      baseContent = latin1.decode(baseBytes);
    }

    final le = baseContent.contains('\r\n') ? '\r\n' : '\n';
    String normalizeLe(String text) {
      if (le == '\r\n') {
        return text.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
      } else {
        return text.replaceAll('\r\n', '\n');
      }
    }

    final endSecRegex = RegExp(r'^\s*0\r?\n\s*ENDSEC\s*$', multiLine: true);

    // Track existing definitions in baseContent to avoid duplicate keys
    final existingLayers = _extractTableNames(baseContent, 'LAYER');
    final existingStyles = _extractTableNames(baseContent, 'STYLE');
    final existingLtypes = _extractTableNames(baseContent, 'LTYPE');
    final existingBlocks = _extractBlockNames(baseContent);

    final extraBlocksBuffer = StringBuffer();
    final extraEntitiesBuffer = StringBuffer();
    final extraLayersBuffer = StringBuffer();
    final extraStylesBuffer = StringBuffer();
    final extraLtypesBuffer = StringBuffer();

    // 1. Extract from all imported DXF files
    for (final impFile in importedFiles) {
      if (!await impFile.exists()) continue;
      final bytes = await impFile.readAsBytes();
      String impContent;
      try {
        impContent = utf8.decode(bytes);
      } on FormatException catch (_) {
        impContent = latin1.decode(bytes);
      }

      // A) Extract TABLES (LAYER, STYLE, LTYPE)
      _extractTableEntries(
        source: impContent,
        tableName: 'LAYER',
        existingNames: existingLayers,
        buffer: extraLayersBuffer,
      );
      _extractTableEntries(
        source: impContent,
        tableName: 'STYLE',
        existingNames: existingStyles,
        buffer: extraStylesBuffer,
      );
      _extractTableEntries(
        source: impContent,
        tableName: 'LTYPE',
        existingNames: existingLtypes,
        buffer: extraLtypesBuffer,
      );

      // B) Extract non-model-space BLOCKS
      final impBlocksRegex = RegExp(r'^\s*0\r?\n\s*SECTION\r?\n\s*2\r?\n\s*BLOCKS\s*$', multiLine: true);
      final impBlkStart = impBlocksRegex.firstMatch(impContent);
      if (impBlkStart != null) {
        final impBlkEnd = endSecRegex.firstMatch(impContent.substring(impBlkStart.end));
        if (impBlkEnd != null) {
          final blocksText = impContent.substring(impBlkStart.end, impBlkStart.end + impBlkEnd.start);
          final blockEntryRegex = RegExp(
            r'(^\s*0\r?\n\s*BLOCK\r?\n[\s\S]*?^\s*0\r?\n\s*ENDBLK(?:\r?\n(?!\s*0\r?\n)[^\r\n]*)*\r?\n?)',
            multiLine: true,
          );
          for (final m in blockEntryRegex.allMatches(blocksText)) {
            final chunk = m.group(1)!;
            final nameMatch = RegExp(r'^\s*2\r?\n\s*([^\r\n]+)', multiLine: true).firstMatch(chunk);
            final bName = nameMatch?.group(1)?.trim().toUpperCase() ?? '';
            if (bName.isEmpty ||
                bName.startsWith('*MODEL_SPACE') ||
                bName.startsWith('*PAPER_SPACE') ||
                existingBlocks.contains(bName)) {
              continue;
            }
            extraBlocksBuffer.write(chunk);
            existingBlocks.add(bName);
          }
        }
      }

      // C) Extract ENTITIES
      final impEntitiesRegex = RegExp(r'^\s*0\r?\n\s*SECTION\r?\n\s*2\r?\n\s*ENTITIES\s*$', multiLine: true);
      final impEntStart = impEntitiesRegex.firstMatch(impContent);
      if (impEntStart != null) {
        final impEntEnd = endSecRegex.firstMatch(impContent.substring(impEntStart.end));
        if (impEntEnd != null) {
          final chunk = impContent.substring(impEntStart.end, impEntStart.end + impEntEnd.start);
          extraEntitiesBuffer.write(chunk);
        }
      }
    }

    // 2. Build annotation entities
    if (annotations.isNotEmpty) {
      final annoBuffer = _buildAnnotationEntitiesBuffer(annotations, defaultTextHeight);
      extraEntitiesBuffer.write(annoBuffer.toString());
    }

    // 3. Assemble merged DXF content
    var resultContent = baseContent;

    // A) Insert extra table entries into TABLES
    resultContent = _insertIntoTable(resultContent, 'LAYER', normalizeLe(extraLayersBuffer.toString()), le);
    resultContent = _insertIntoTable(resultContent, 'STYLE', normalizeLe(extraStylesBuffer.toString()), le);
    resultContent = _insertIntoTable(resultContent, 'LTYPE', normalizeLe(extraLtypesBuffer.toString()), le);

    // B) Insert extra blocks into BLOCKS section
    final extraBlocksStr = normalizeLe(extraBlocksBuffer.toString());
    if (extraBlocksStr.trim().isNotEmpty) {
      final bSectionRegex = RegExp(r'^\s*0\r?\n\s*SECTION\r?\n\s*2\r?\n\s*BLOCKS\s*$', multiLine: true);
      final bStart = bSectionRegex.firstMatch(resultContent);
      if (bStart != null) {
        final bEnd = endSecRegex.firstMatch(resultContent.substring(bStart.end));
        if (bEnd != null) {
          final insertIdx = bStart.end + bEnd.start;
          resultContent = resultContent.substring(0, insertIdx) +
              extraBlocksStr +
              resultContent.substring(insertIdx);
        }
      } else {
        // If base content had no BLOCKS section, create it before ENTITIES
        final eSectionRegex = RegExp(r'^\s*0\r?\n\s*SECTION\r?\n\s*2\r?\n\s*ENTITIES\s*$', multiLine: true);
        final eStart = eSectionRegex.firstMatch(resultContent);
        if (eStart != null) {
          final blocksSection = '0${le}SECTION${le}2${le}BLOCKS$le$extraBlocksStr' '0${le}ENDSEC$le';
          resultContent = resultContent.substring(0, eStart.start) +
              blocksSection +
              resultContent.substring(eStart.start);
        }
      }
    }

    // C) Insert extra entities into ENTITIES section
    final extraEntitiesStr = normalizeLe(extraEntitiesBuffer.toString());
    if (extraEntitiesStr.trim().isNotEmpty) {
      final eSectionRegex = RegExp(r'^\s*0\r?\n\s*SECTION\r?\n\s*2\r?\n\s*ENTITIES\s*$', multiLine: true);
      final eStart = eSectionRegex.firstMatch(resultContent);
      if (eStart != null) {
        final eEnd = endSecRegex.firstMatch(resultContent.substring(eStart.end));
        if (eEnd != null) {
          final insertIdx = eStart.end + eEnd.start;
          resultContent = resultContent.substring(0, insertIdx) +
              extraEntitiesStr +
              resultContent.substring(insertIdx);
        }
      } else {
        final fallbackBuffer = StringBuffer();
        _insertFallback(resultContent, extraEntitiesStr, fallbackBuffer);
        resultContent = fallbackBuffer.toString();
      }
    }

    await outputFile.writeAsString(resultContent, encoding: utf8);
    return outputFile;
  }

  static Set<String> _extractTableNames(String content, String tableName) {
    final result = <String>{};
    final tStartRegex = RegExp(r'^\s*0\r?\n\s*TABLE\r?\n\s*2\r?\n\s*' + tableName + r'\s*$', multiLine: true);
    final tStart = tStartRegex.firstMatch(content);
    if (tStart == null) return result;
    final endTabRegex = RegExp(r'^\s*0\r?\n\s*ENDTAB\s*$', multiLine: true);
    final tEnd = endTabRegex.firstMatch(content.substring(tStart.end));
    if (tEnd == null) return result;

    final tableText = content.substring(tStart.end, tStart.end + tEnd.start);
    final nameRegex = RegExp(r'^\s*2\r?\n\s*([^\r\n]+)', multiLine: true);
    for (final m in nameRegex.allMatches(tableText)) {
      result.add(m.group(1)!.trim().toUpperCase());
    }
    return result;
  }

  static void _extractTableEntries({
    required String source,
    required String tableName,
    required Set<String> existingNames,
    required StringBuffer buffer,
  }) {
    final tStartRegex = RegExp(r'^\s*0\r?\n\s*TABLE\r?\n\s*2\r?\n\s*' + tableName + r'\s*$', multiLine: true);
    final tStart = tStartRegex.firstMatch(source);
    if (tStart == null) return;
    final endTabRegex = RegExp(r'^\s*0\r?\n\s*ENDTAB\s*$', multiLine: true);
    final tEnd = endTabRegex.firstMatch(source.substring(tStart.end));
    if (tEnd == null) return;

    final tableText = source.substring(tStart.end, tStart.end + tEnd.start);
    final entryRegex = RegExp(
      r'(^\s*0\r?\n\s*' + tableName + r'\r?\n[\s\S]*?)(?=^\s*0\r?\n\s*' + tableName + r'\r?\n|^\s*0\r?\n\s*ENDTAB|$)',
      multiLine: true,
    );
    for (final m in entryRegex.allMatches(tableText)) {
      final chunk = m.group(1)!;
      final nameMatch = RegExp(r'^\s*2\r?\n\s*([^\r\n]+)', multiLine: true).firstMatch(chunk);
      final name = nameMatch?.group(1)?.trim().toUpperCase() ?? '';
      if (name.isNotEmpty && !existingNames.contains(name)) {
        buffer.write(chunk);
        existingNames.add(name);
      }
    }
  }

  static String _insertIntoTable(String content, String tableName, String extraEntries, String le) {
    if (extraEntries.trim().isEmpty) return content;
    final tStartRegex = RegExp(r'^\s*0\r?\n\s*TABLE\r?\n\s*2\r?\n\s*' + tableName + r'\s*$', multiLine: true);
    final tStart = tStartRegex.firstMatch(content);
    if (tStart == null) return content;
    final endTabRegex = RegExp(r'^\s*0\r?\n\s*ENDTAB\s*$', multiLine: true);
    final tEnd = endTabRegex.firstMatch(content.substring(tStart.end));
    if (tEnd == null) return content;

    final insertIdx = tStart.end + tEnd.start;
    return content.substring(0, insertIdx) + extraEntries + content.substring(insertIdx);
  }

  static Set<String> _extractBlockNames(String content) {
    final result = <String>{};
    final bStartRegex = RegExp(r'^\s*0\r?\n\s*SECTION\r?\n\s*2\r?\n\s*BLOCKS\s*$', multiLine: true);
    final bStart = bStartRegex.firstMatch(content);
    if (bStart == null) return result;
    final endSecRegex = RegExp(r'^\s*0\r?\n\s*ENDSEC\s*$', multiLine: true);
    final bEnd = endSecRegex.firstMatch(content.substring(bStart.end));
    if (bEnd == null) return result;

    final blocksText = content.substring(bStart.end, bStart.end + bEnd.start);
    final blockEntryRegex = RegExp(r'^\s*0\r?\n\s*BLOCK\r?\n[\s\S]*?^\s*2\r?\n\s*([^\r\n]+)', multiLine: true);
    for (final m in blockEntryRegex.allMatches(blocksText)) {
      result.add(m.group(1)!.trim().toUpperCase());
    }
    return result;
  }

  static StringBuffer _buildAnnotationEntitiesBuffer(List<DxfAnnotation> annotations, double defaultTextHeight) {
    final entitiesBuffer = StringBuffer();
    for (final anno in annotations) {
      final tipX = anno.arrowTipCad.dx.toStringAsFixed(4);
      final tipY = anno.arrowTipCad.dy.toStringAsFixed(4);
      final textX = anno.textPosCad.dx.toStringAsFixed(4);
      final textY = anno.textPosCad.dy.toStringAsFixed(4);
      final h = (anno.textHeight ?? defaultTextHeight).toStringAsFixed(4);

      final sanitizedText = anno.text.replaceAll('\\', '\\\\').replaceAll('\n', '\\P');

      int aciColor = 1; // default Red
      if (anno.colorValue == 0xFFFFD600) aciColor = 2; // Yellow
      if (anno.colorValue == 0xFF00E676) aciColor = 3; // Green
      if (anno.colorValue == 0xFF00E5FF) aciColor = 4; // Cyan
      if (anno.colorValue == 0xFFFF4081) aciColor = 6; // Magenta
      if (anno.colorValue == 0xFFFFFFFF) aciColor = 7; // White

      // A) LEADER Entity
      entitiesBuffer.writeln('0');
      entitiesBuffer.writeln('LEADER');
      entitiesBuffer.writeln('5');
      entitiesBuffer.writeln(DateTime.now().microsecondsSinceEpoch.toRadixString(16));
      entitiesBuffer.writeln('100');
      entitiesBuffer.writeln('AcDbLeader');
      entitiesBuffer.writeln('8');
      entitiesBuffer.writeln('MARKUP');
      entitiesBuffer.writeln('62');
      entitiesBuffer.writeln('$aciColor');
      entitiesBuffer.writeln('71');
      entitiesBuffer.writeln('1'); // Arrowhead enabled
      entitiesBuffer.writeln('72');
      entitiesBuffer.writeln('0'); // Straight line segments
      entitiesBuffer.writeln('76');
      entitiesBuffer.writeln('2'); // 2 vertices
      entitiesBuffer.writeln('10');
      entitiesBuffer.writeln(tipX);
      entitiesBuffer.writeln('20');
      entitiesBuffer.writeln(tipY);
      entitiesBuffer.writeln('30');
      entitiesBuffer.writeln('0.0');
      entitiesBuffer.writeln('10');
      entitiesBuffer.writeln(textX);
      entitiesBuffer.writeln('20');
      entitiesBuffer.writeln(textY);
      entitiesBuffer.writeln('30');
      entitiesBuffer.writeln('0.0');

      // B) MTEXT Entity attached to leader
      entitiesBuffer.writeln('0');
      entitiesBuffer.writeln('MTEXT');
      entitiesBuffer.writeln('5');
      entitiesBuffer.writeln((DateTime.now().microsecondsSinceEpoch + 1).toRadixString(16));
      entitiesBuffer.writeln('100');
      entitiesBuffer.writeln('AcDbMText');
      entitiesBuffer.writeln('8');
      entitiesBuffer.writeln('MARKUP');
      entitiesBuffer.writeln('62');
      entitiesBuffer.writeln('$aciColor');
      entitiesBuffer.writeln('10');
      entitiesBuffer.writeln(textX);
      entitiesBuffer.writeln('20');
      entitiesBuffer.writeln(textY);
      entitiesBuffer.writeln('30');
      entitiesBuffer.writeln('0.0');
      entitiesBuffer.writeln('40');
      entitiesBuffer.writeln(h);
      entitiesBuffer.writeln('71');
      entitiesBuffer.writeln('1'); // Top-left attachment
      entitiesBuffer.writeln('1');
      entitiesBuffer.writeln(sanitizedText);
    }
    return entitiesBuffer;
  }

  static void _insertFallback(String content, String entitiesStr, StringBuffer buffer) {
    final eofIndex = content.lastIndexOf('0\nEOF');
    final eofIndexCrLf = content.lastIndexOf('0\r\nEOF');
    if (eofIndex != -1) {
      buffer.write(content.substring(0, eofIndex));
      buffer.writeln('0');
      buffer.writeln('SECTION');
      buffer.writeln('2');
      buffer.writeln('ENTITIES');
      buffer.write(entitiesStr);
      buffer.writeln('0');
      buffer.writeln('ENDSEC');
      buffer.write('0\nEOF\n');
    } else if (eofIndexCrLf != -1) {
      buffer.write(content.substring(0, eofIndexCrLf));
      buffer.write('0\r\nSECTION\r\n2\r\nENTITIES\r\n');
      buffer.write(entitiesStr.replaceAll('\n', '\r\n'));
      buffer.write('0\r\nENDSEC\r\n0\r\nEOF\r\n');
    } else {
      buffer.write(content);
      buffer.writeln();
      buffer.writeln('0');
      buffer.writeln('SECTION');
      buffer.writeln('2');
      buffer.writeln('ENTITIES');
      buffer.write(entitiesStr);
      buffer.writeln('0');
      buffer.writeln('ENDSEC');
      buffer.writeln('0');
      buffer.writeln('EOF');
    }
  }
}
