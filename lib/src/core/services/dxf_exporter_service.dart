import 'dart:convert';
import 'dart:io';
import '../../features/dxf_viewer/models/dxf_models.dart';

/// Service responsible for exporting DXF files with user-added annotations (LEADER + MTEXT)
/// compliant with AutoCAD DXF standards.
class DxfExporterService {
  /// Injects annotations into the DXF content and writes the result to [outputFile].
  static Future<File> saveDxfWithAnnotations({
    required File originalFile,
    required List<DxfAnnotation> annotations,
    required File outputFile,
    double defaultTextHeight = 2.5,
  }) async {
    if (annotations.isEmpty) {
      return originalFile.copy(outputFile.path);
    }

    final bytes = await originalFile.readAsBytes();
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final buffer = StringBuffer();

    // 1. Build the DXF entity block for each annotation
    final entitiesBuffer = StringBuffer();
    for (final anno in annotations) {
      final tipX = anno.arrowTipCad.dx.toStringAsFixed(4);
      final tipY = anno.arrowTipCad.dy.toStringAsFixed(4);
      final textX = anno.textPosCad.dx.toStringAsFixed(4);
      final textY = anno.textPosCad.dy.toStringAsFixed(4);
      final h = (anno.textHeight ?? defaultTextHeight).toStringAsFixed(4);

      // Escape backslashes and special characters for DXF MTEXT
      final sanitizedText = anno.text.replaceAll('\\', '\\\\').replaceAll('\n', '\\P');

      // Map color to AutoCAD ACI color index: Red=1, Yellow=2, Green=3, Cyan=4, Blue=5, Magenta=6, White=7
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
      // Vertex 1: Arrow tip
      entitiesBuffer.writeln('10');
      entitiesBuffer.writeln(tipX);
      entitiesBuffer.writeln('20');
      entitiesBuffer.writeln(tipY);
      entitiesBuffer.writeln('30');
      entitiesBuffer.writeln('0.0');
      // Vertex 2: Text landing position
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

    // 2. Find insertion location in existing DXF
    // We look for the end of the ENTITIES section (before "0\nENDSEC" that follows "2\nENTITIES")
    // or right before "0\nEOF".
    final entitiesIndex = content.indexOf('SECTION\n2\nENTITIES');
    final entitiesIndexCrLf = content.indexOf('SECTION\r\n2\r\nENTITIES');

    if (entitiesIndex != -1) {
      final endSecIndex = content.indexOf('\n0\nENDSEC', entitiesIndex);
      if (endSecIndex != -1) {
        buffer.write(content.substring(0, endSecIndex + 1));
        buffer.write(entitiesBuffer.toString());
        buffer.write(content.substring(endSecIndex + 1));
      } else {
        _insertFallback(content, entitiesBuffer.toString(), buffer);
      }
    } else if (entitiesIndexCrLf != -1) {
      final endSecIndex = content.indexOf('\r\n0\r\nENDSEC', entitiesIndexCrLf);
      if (endSecIndex != -1) {
        buffer.write(content.substring(0, endSecIndex + 2));
        buffer.write(entitiesBuffer.toString().replaceAll('\n', '\r\n'));
        buffer.write(content.substring(endSecIndex + 2));
      } else {
        _insertFallback(content, entitiesBuffer.toString(), buffer);
      }
    } else {
      _insertFallback(content, entitiesBuffer.toString(), buffer);
    }

    await outputFile.writeAsString(buffer.toString(), encoding: utf8);
    return outputFile;
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
