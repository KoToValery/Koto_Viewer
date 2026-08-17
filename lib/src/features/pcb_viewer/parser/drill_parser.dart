import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/pcb_models.dart';

/// Pure-Dart Excellon CNC Drill File (.drl, .xln) Parser.
class DrillParser {
  /// Parses raw Excellon drill bytes into a [PcbDocument].
  static PcbDocument parse(Uint8List bytes, {String fileName = 'drill.drl'}) {
    final text = _decodeText(bytes);
    return _parseDrillText(text, fileName);
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static PcbDocument _parseDrillText(String text, String fileName) {
    double unitScale = 1.0; // 1.0 for mm, 25.4 for inches
    int decimalPlaces = 4; // default coordinate decimal places

    final Map<int, double> toolTable = {};
    final List<PcbDrillHole> holes = [];

    int activeToolId = 1;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    final lines = text.split(RegExp(r'\r?\n'));

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith(';') || trimmed.startsWith('#')) {
        continue;
      }

      final upper = trimmed.toUpperCase();

      // Units
      if (upper.contains('INCH')) {
        unitScale = 25.4;
      } else if (upper.contains('METRIC')) {
        unitScale = 1.0;
      }

      // Tool Definition (e.g. T01C0.8 or T1C0.0312)
      final toolDefMatch = RegExp(r'T(\d+)(?:[A-Z0-9]+)?C([0-9.]+)').firstMatch(upper);
      if (toolDefMatch != null) {
        final toolId = int.tryParse(toolDefMatch.group(1)!) ?? 1;
        final diamRaw = double.tryParse(toolDefMatch.group(2)!) ?? 0.8;
        toolTable[toolId] = diamRaw * unitScale;
        continue;
      }

      // Tool Selection (e.g. T01 or T1)
      final toolSelectMatch = RegExp(r'^T(\d+)$').firstMatch(upper);
      if (toolSelectMatch != null) {
        activeToolId = int.tryParse(toolSelectMatch.group(1)!) ?? 1;
        continue;
      }

      // Hole Coordinates (X...Y...)
      if (upper.contains('X') || upper.contains('Y')) {
        double? xVal;
        double? yVal;

        final xMatch = RegExp(r'X([+-]?[0-9.]+)').firstMatch(upper);
        if (xMatch != null) {
          final rawStr = xMatch.group(1)!;
          if (rawStr.contains('.')) {
            xVal = (double.tryParse(rawStr) ?? 0.0) * unitScale;
          } else {
            final raw = int.tryParse(rawStr) ?? 0;
            xVal = (raw / math.pow(10, decimalPlaces)) * unitScale;
          }
        }

        final yMatch = RegExp(r'Y([+-]?[0-9.]+)').firstMatch(upper);
        if (yMatch != null) {
          final rawStr = yMatch.group(1)!;
          if (rawStr.contains('.')) {
            yVal = (double.tryParse(rawStr) ?? 0.0) * unitScale;
          } else {
            final raw = int.tryParse(rawStr) ?? 0;
            yVal = (raw / math.pow(10, decimalPlaces)) * unitScale;
          }
        }

        if (xVal != null && yVal != null) {
          final toolDiam = toolTable[activeToolId] ?? 0.8;
          final holePos = Offset(xVal, yVal);
          holes.add(
            PcbDrillHole(
              position: holePos,
              diameterMm: toolDiam,
              toolId: activeToolId,
            ),
          );

          final rad = toolDiam / 2.0;
          if (xVal - rad < minX) minX = xVal - rad;
          if (xVal + rad > maxX) maxX = xVal + rad;
          if (yVal - rad < minY) minY = yVal - rad;
          if (yVal + rad > maxY) maxY = yVal + rad;
        }
      }
    }

    final hasValidBounds = minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite;
    final boundingBox = hasValidBounds
        ? PcbBoundingBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        : PcbBoundingBox.defaultBox;

    return PcbDocument(
      fileName: fileName,
      layerType: PcbLayerType.drill,
      commands: const [],
      drillHoles: holes,
      boundingBox: boundingBox,
    );
  }
}
