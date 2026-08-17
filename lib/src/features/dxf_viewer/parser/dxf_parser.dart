import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/dxf_models.dart';
import '../rendering/dxf_math.dart';

/// Represents a single DXF Group Code and Value pair.
class _DxfPair {
  final int code;
  final String value;

  const _DxfPair(this.code, this.value);

  int get intValue => int.tryParse(value.trim()) ?? 0;
  double get doubleValue => double.tryParse(value.trim()) ?? 0.0;
}

/// High-performance, robust ASCII DXF Parser.
class DxfParser {
  const DxfParser();

  /// Parse DXF from File (runs in background isolate via compute for large files).
  static Future<DxfDocument> parseFromFile(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    String content;
    try {
      // 1. Strict UTF-8 decoding
      content = utf8.decode(bytes);
    } catch (_) {
      // 2. If file contains 8-bit ANSI bytes (e.g. Windows-1251 Cyrillic from AutoCAD / ArchiCAD)
      content = _decodeWindows1251(bytes);
    }
    // For large files (>200KB), parse in background isolate
    if (content.length > 200 * 1024) {
      return compute(_parseStringCompute, content);
    }
    return parseString(content);
  }

  /// Decodes raw Windows-1251 (CP1251) byte stream to UTF-8 String.
  static String _decodeWindows1251(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        buffer.writeCharCode(b);
      } else if (b >= 0xC0 && b <= 0xDF) {
        // Cyrillic Capital Letters А .. Я
        buffer.writeCharCode(0x0410 + (b - 0xC0));
      } else if (b >= 0xE0 && b <= 0xFF) {
        // Cyrillic Small Letters а .. я
        buffer.writeCharCode(0x0430 + (b - 0xE0));
      } else {
        switch (b) {
          case 0xA8: buffer.writeCharCode(0x0401); break; // Ё
          case 0xB8: buffer.writeCharCode(0x0451); break; // ё
          case 0xB9: buffer.writeCharCode(0x2116); break; // №
          case 0xA1: buffer.writeCharCode(0x040E); break; // Ў
          case 0xA2: buffer.writeCharCode(0x045E); break; // ў
          case 0xAA: buffer.writeCharCode(0x0404); break; // Є
          case 0xBA: buffer.writeCharCode(0x0454); break; // є
          case 0xAF: buffer.writeCharCode(0x0407); break; // Ї
          case 0xBF: buffer.writeCharCode(0x0457); break; // ї
          case 0xB2: buffer.writeCharCode(0x0406); break; // І
          case 0xB3: buffer.writeCharCode(0x0456); break; // і
          case 0xA4: buffer.writeCharCode(0x00A4); break; // ¤
          case 0xA7: buffer.writeCharCode(0x00A7); break; // §
          case 0xAB: buffer.writeCharCode(0x00AB); break; // «
          case 0xBB: buffer.writeCharCode(0x00BB); break; // »
          case 0xB0: buffer.writeCharCode(0x00B0); break; // °
          case 0xB1: buffer.writeCharCode(0x00B1); break; // ±
          case 0x88: buffer.writeCharCode(0x20AC); break; // €
          case 0x93: buffer.writeCharCode(0x201C); break; // “
          case 0x94: buffer.writeCharCode(0x201D); break; // ”
          case 0x96: buffer.writeCharCode(0x2013); break; // –
          case 0x97: buffer.writeCharCode(0x2014); break; // —
          default:
            buffer.writeCharCode(b);
        }
      }
    }
    return buffer.toString();
  }

  /// Entry point for compute isolate.
  static DxfDocument _parseStringCompute(String content) {
    return parseString(content);
  }

  /// Parses DXF string content.
  static DxfDocument parseString(String content) {
    final pairs = _tokenize(content);
    return _parsePairs(pairs);
  }

  /// Tokenize DXF content into group code & value pairs.
  static List<_DxfPair> _tokenize(String content) {
    final List<_DxfPair> pairs = [];
    final lines = LineSplitter.split(content).toList(growable: false);
    final int len = lines.length;

    for (int i = 0; i < len - 1; i += 2) {
      final codeStr = lines[i].trim();
      final code = int.tryParse(codeStr);
      if (code == null) {
        // Misaligned pair, attempt single step recovery
        i--;
        continue;
      }
      final value = lines[i + 1];
      pairs.add(_DxfPair(code, value));
    }
    return pairs;
  }

  /// Main parser loop through sections.
  static DxfDocument _parsePairs(List<_DxfPair> pairs) {
    final Map<String, DxfLayer> layers = {};
    final Map<String, DxfBlock> blocks = {};
    final List<DxfEntity> entities = [];
    final Map<String, String> headerVars = {};
    final Map<String, int> entityStats = {};

    // Ensure default layer "0" exists
    layers['0'] = DxfLayer(name: '0', colorIndex: 7);

    int idx = 0;
    final int total = pairs.length;

    while (idx < total) {
      final pair = pairs[idx];

      if (pair.code == 0 && pair.value.trim().toUpperCase() == 'SECTION') {
        idx++;
        if (idx >= total) break;
        final secNamePair = pairs[idx];
        final secName = secNamePair.value.trim().toUpperCase();
        idx++;

        if (secName == 'HEADER') {
          idx = _parseHeaderSection(pairs, idx, headerVars);
        } else if (secName == 'TABLES') {
          idx = _parseTablesSection(pairs, idx, layers);
        } else if (secName == 'BLOCKS') {
          idx = _parseBlocksSection(pairs, idx, blocks);
        } else if (secName == 'ENTITIES') {
          idx = _parseEntitiesSection(pairs, idx, entities, entityStats);
        } else {
          // Skip other sections
          while (idx < total) {
            if (pairs[idx].code == 0 && pairs[idx].value.trim().toUpperCase() == 'ENDSEC') {
              idx++;
              break;
            }
            idx++;
          }
        }
      } else {
        idx++;
      }
    }

    // Compute bounding box (filtering out origin outliers e.g. (0,0) in BGS2005 drawings)
    final List<Rect> validBoxes = [];
    for (final entity in entities) {
      final b = entity.getBoundingBox(blocks);
      if (b != null && b.isFinite && !b.isEmpty) {
        validBoxes.add(b);
      }
    }

    // Auto-register layers referenced by entities or blocks
    void ensureLayer(String layerName) {
      final name = layerName.trim();
      if (name.isNotEmpty && !layers.containsKey(name)) {
        final colorIdx = ((name.hashCode.abs()) % 7) + 1;
        layers[name] = DxfLayer(name: name, colorIndex: colorIdx);
      }
    }

    for (final entity in entities) {
      ensureLayer(entity.layer);
    }
    for (final block in blocks.values) {
      for (final entity in block.entities) {
        ensureLayer(entity.layer);
      }
    }

    Rect? bounds;
    if (validBoxes.isNotEmpty) {
      List<Rect> filteredBoxes = validBoxes;
      if (validBoxes.length > 3) {
        final centersX = validBoxes.map((b) => b.center.dx).toList()..sort();
        final centersY = validBoxes.map((b) => b.center.dy).toList()..sort();
        final medianX = centersX[centersX.length ~/ 2];
        final medianY = centersY[centersY.length ~/ 2];

        final distances = validBoxes.map((b) => (b.center - Offset(medianX, medianY)).distance).toList()..sort();
        final medianDist = distances[distances.length ~/ 2];
        final maxAllowedDist = math.max(50000.0, medianDist * 50.0);

        final nonOutliers = validBoxes.where((b) => (b.center - Offset(medianX, medianY)).distance <= maxAllowedDist).toList();
        if (nonOutliers.isNotEmpty) {
          filteredBoxes = nonOutliers;
        }
      }

      for (final b in filteredBoxes) {
        bounds = bounds == null ? b : bounds.expandToInclude(b);
      }
    }

    // If still null or infinite, fallback
    bounds ??= const Rect.fromLTWH(0, 0, 100, 100);

    return DxfDocument(
      layers: layers,
      blocks: blocks,
      entities: entities,
      headerVars: headerVars,
      bounds: bounds,
      entityStats: entityStats,
    );
  }

  /// Parses HEADER section.
  static int _parseHeaderSection(
    List<_DxfPair> pairs,
    int startIdx,
    Map<String, String> headerVars,
  ) {
    int idx = startIdx;
    final int total = pairs.length;
    String? currentVar;

    while (idx < total) {
      final pair = pairs[idx];
      if (pair.code == 0 && pair.value.trim().toUpperCase() == 'ENDSEC') {
        idx++;
        break;
      }

      if (pair.code == 9) {
        currentVar = pair.value.trim().toUpperCase();
      } else if (currentVar != null) {
        headerVars[currentVar] = pair.value.trim();
      }
      idx++;
    }
    return idx;
  }

  /// Parses TABLES section (specifically LAYER table).
  static int _parseTablesSection(
    List<_DxfPair> pairs,
    int startIdx,
    Map<String, DxfLayer> layers,
  ) {
    int idx = startIdx;
    final int total = pairs.length;

    while (idx < total) {
      final pair = pairs[idx];
      if (pair.code == 0 && pair.value.trim().toUpperCase() == 'ENDSEC') {
        idx++;
        break;
      }

      if (pair.code == 0 && pair.value.trim().toUpperCase() == 'TABLE') {
        idx++;
        String tabName = '';
        while (idx < total && pairs[idx].code != 0) {
          if (pairs[idx].code == 2) {
            tabName = pairs[idx].value.trim().toUpperCase();
          }
          idx++;
        }

        if (tabName == 'LAYER') {
          idx = _parseLayerTable(pairs, idx, layers);
        } else {
          // Skip other tables
          while (idx < total) {
            if (pairs[idx].code == 0 && pairs[idx].value.trim().toUpperCase() == 'ENDTAB') {
              idx++;
              break;
            }
            idx++;
          }
        }
      } else {
        idx++;
      }
    }
    return idx;
  }

  /// Parses LAYER table entries.
  static int _parseLayerTable(
    List<_DxfPair> pairs,
    int startIdx,
    Map<String, DxfLayer> layers,
  ) {
    int idx = startIdx;
    final int total = pairs.length;

    while (idx < total) {
      final pair = pairs[idx];
      if (pair.code == 0 && pair.value.trim().toUpperCase() == 'ENDTAB') {
        idx++;
        break;
      }

      if (pair.code == 0 && pair.value.trim().toUpperCase() == 'LAYER') {
        idx++;
        String layerName = '0';
        int colorIndex = 7;
        int? trueColor;
        bool isVisible = true;
        bool isFrozen = false;
        double? lineweight;

        while (idx < total && pairs[idx].code != 0) {
          final p = pairs[idx];
          switch (p.code) {
            case 2:
              layerName = p.value.trim();
              break;
            case 62:
              final c = p.intValue;
              if (c < 0) {
                isVisible = false;
                colorIndex = c.abs();
              } else {
                colorIndex = c;
              }
              break;
            case 420:
              trueColor = p.intValue;
              break;
            case 70:
              final flags = p.intValue;
              if ((flags & 1) != 0) isFrozen = true;
              break;
            case 370:
              lineweight = p.doubleValue / 100.0; // In mm
              break;
          }
          idx++;
        }

        layers[layerName] = DxfLayer(
          name: layerName,
          colorIndex: colorIndex,
          trueColor: trueColor,
          isVisible: isVisible,
          isFrozen: isFrozen,
          lineweight: lineweight,
        );
      } else {
        idx++;
      }
    }
    return idx;
  }

  /// Parses BLOCKS section.
  static int _parseBlocksSection(
    List<_DxfPair> pairs,
    int startIdx,
    Map<String, DxfBlock> blocks,
  ) {
    int idx = startIdx;
    final int total = pairs.length;

    while (idx < total) {
      final pair = pairs[idx];
      if (pair.code == 0 && pair.value.trim().toUpperCase() == 'ENDSEC') {
        idx++;
        break;
      }

      if (pair.code == 0 && pair.value.trim().toUpperCase() == 'BLOCK') {
        idx++;
        String blockName = '';
        double baseX = 0.0;
        double baseY = 0.0;

        while (idx < total && pairs[idx].code != 0) {
          final p = pairs[idx];
          switch (p.code) {
            case 2:
              blockName = p.value.trim();
              break;
            case 10:
              baseX = p.doubleValue;
              break;
            case 20:
              baseY = p.doubleValue;
              break;
          }
          idx++;
        }

        final List<DxfEntity> blockEntities = [];
        while (idx < total) {
          if (pairs[idx].code == 0 && pairs[idx].value.trim().toUpperCase() == 'ENDBLK') {
            idx++;
            break;
          }

          if (pairs[idx].code == 0) {
            final (entity, nextIdx) = _parseEntity(pairs, idx);
            if (entity != null) {
              blockEntities.add(entity);
            }
            idx = nextIdx;
          } else {
            idx++;
          }
        }

        if (blockName.isNotEmpty) {
          blocks[blockName] = DxfBlock(
            name: blockName,
            basePoint: Offset(baseX, baseY),
            entities: blockEntities,
          );
        }
      } else {
        idx++;
      }
    }
    return idx;
  }

  /// Parses ENTITIES section.
  static int _parseEntitiesSection(
    List<_DxfPair> pairs,
    int startIdx,
    List<DxfEntity> entities,
    Map<String, int> entityStats,
  ) {
    int idx = startIdx;
    final int total = pairs.length;

    while (idx < total) {
      final pair = pairs[idx];
      if (pair.code == 0 && pair.value.trim().toUpperCase() == 'ENDSEC') {
        idx++;
        break;
      }

      if (pair.code == 0) {
        final (entity, nextIdx) = _parseEntity(pairs, idx);
        if (entity != null) {
          entities.add(entity);
          entityStats[entity.typeName] = (entityStats[entity.typeName] ?? 0) + 1;
        }
        idx = nextIdx;
      } else {
        idx++;
      }
    }
    return idx;
  }

  /// Parses a single entity starting at pairs[startIdx] where pairs[startIdx].code == 0.
  static (DxfEntity?, int) _parseEntity(List<_DxfPair> pairs, int startIdx) {
    final entityType = pairs[startIdx].value.trim().toUpperCase();
    int idx = startIdx + 1;
    final int total = pairs.length;

    // Collect properties until next entity code 0
    final entityPairs = <_DxfPair>[];
    while (idx < total && pairs[idx].code != 0) {
      entityPairs.add(pairs[idx]);
      idx++;
    }

    // Common attributes
    String layer = '0';
    int? colorIndex;
    int? trueColor;
    String? lineType;
    double? lineWeight;

    for (final p in entityPairs) {
      switch (p.code) {
        case 8:
          layer = p.value.trim();
          break;
        case 62:
          colorIndex = p.intValue;
          break;
        case 420:
          trueColor = p.intValue;
          break;
        case 6:
          lineType = p.value.trim();
          break;
        case 370:
          lineWeight = p.doubleValue / 100.0;
          break;
      }
    }

    DxfEntity? entity;

    switch (entityType) {
      case 'LINE':
        double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
        for (final p in entityPairs) {
          switch (p.code) {
            case 10:
              x1 = p.doubleValue;
              break;
            case 20:
              y1 = p.doubleValue;
              break;
            case 11:
              x2 = p.doubleValue;
              break;
            case 21:
              y2 = p.doubleValue;
              break;
          }
        }
        entity = DxfLine(
          p1: Offset(x1, y1),
          p2: Offset(x2, y2),
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'POINT':
        double x = 0, y = 0;
        for (final p in entityPairs) {
          switch (p.code) {
            case 10:
              x = p.doubleValue;
              break;
            case 20:
              y = p.doubleValue;
              break;
          }
        }
        entity = DxfPoint(
          point: Offset(x, y),
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'CIRCLE':
        double cx = 0, cy = 0, r = 0;
        for (final p in entityPairs) {
          switch (p.code) {
            case 10:
              cx = p.doubleValue;
              break;
            case 20:
              cy = p.doubleValue;
              break;
            case 40:
              r = p.doubleValue;
              break;
          }
        }
        entity = DxfCircle(
          center: Offset(cx, cy),
          radius: r,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'ARC':
        double cx = 0, cy = 0, r = 0, startA = 0, endA = 360;
        for (final p in entityPairs) {
          switch (p.code) {
            case 10:
              cx = p.doubleValue;
              break;
            case 20:
              cy = p.doubleValue;
              break;
            case 40:
              r = p.doubleValue;
              break;
            case 50:
              startA = p.doubleValue;
              break;
            case 51:
              endA = p.doubleValue;
              break;
          }
        }
        entity = DxfArc(
          center: Offset(cx, cy),
          radius: r,
          startAngleDeg: startA,
          endAngleDeg: endA,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'ELLIPSE':
        double cx = 0, cy = 0, dx = 0, dy = 0, ratio = 1.0, sp = 0, ep = 2 * math.pi;
        for (final p in entityPairs) {
          switch (p.code) {
            case 10:
              cx = p.doubleValue;
              break;
            case 20:
              cy = p.doubleValue;
              break;
            case 11:
              dx = p.doubleValue;
              break;
            case 21:
              dy = p.doubleValue;
              break;
            case 40:
              ratio = p.doubleValue;
              break;
            case 41:
              sp = p.doubleValue;
              break;
            case 42:
              ep = p.doubleValue;
              break;
          }
        }
        entity = DxfEllipse(
          center: Offset(cx, cy),
          majorAxisEndOffset: Offset(dx, dy),
          minorRatio: ratio,
          startParam: sp,
          endParam: ep,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'LWPOLYLINE':
        bool isClosed = false;
        double elevation = 0.0;
        final List<DxfPolylineVertex> vertices = [];
        double currentX = 0;
        double currentY = 0;
        double currentBulge = 0;
        double currentStartWidth = 0;
        double currentEndWidth = 0;
        bool hasVertex = false;

        void flushVertex() {
          if (hasVertex) {
            vertices.add(DxfPolylineVertex(
              x: currentX,
              y: currentY,
              bulge: currentBulge,
              startWidth: currentStartWidth,
              endWidth: currentEndWidth,
            ));
            currentBulge = 0;
            currentStartWidth = 0;
            currentEndWidth = 0;
          }
        }

        for (final p in entityPairs) {
          switch (p.code) {
            case 70:
              isClosed = (p.intValue & 1) != 0;
              break;
            case 38:
              elevation = p.doubleValue;
              break;
            case 10:
              flushVertex();
              currentX = p.doubleValue;
              hasVertex = true;
              break;
            case 20:
              currentY = p.doubleValue;
              break;
            case 42:
              currentBulge = p.doubleValue;
              break;
            case 40:
              currentStartWidth = p.doubleValue;
              break;
            case 41:
              currentEndWidth = p.doubleValue;
              break;
          }
        }
        flushVertex();

        entity = DxfLwPolyline(
          vertices: vertices,
          isClosed: isClosed,
          elevation: elevation,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'POLYLINE':
        int flags = 0;
        for (final p in entityPairs) {
          if (p.code == 70) flags = p.intValue;
        }
        final bool isClosed = (flags & 1) != 0;
        final bool is3D = (flags & 8) != 0;

        final List<DxfPolylineVertex> vertices = [];
        // Read subsequent VERTEX entities until SEQEND
        while (idx < total) {
          if (pairs[idx].code == 0) {
            final nextType = pairs[idx].value.trim().toUpperCase();
            if (nextType == 'SEQEND') {
              idx++;
              // Consume SEQEND pairs
              while (idx < total && pairs[idx].code != 0) {
                idx++;
              }
              break;
            } else if (nextType == 'VERTEX') {
              idx++;
              double vx = 0, vy = 0, vBulge = 0;
              while (idx < total && pairs[idx].code != 0) {
                final vp = pairs[idx];
                switch (vp.code) {
                  case 10:
                    vx = vp.doubleValue;
                    break;
                  case 20:
                    vy = vp.doubleValue;
                    break;
                  case 42:
                    vBulge = vp.doubleValue;
                    break;
                }
                idx++;
              }
              vertices.add(DxfPolylineVertex(x: vx, y: vy, bulge: vBulge));
            } else {
              break;
            }
          } else {
            idx++;
          }
        }

        entity = DxfPolyline(
          vertices: vertices,
          isClosed: isClosed,
          is3D: is3D,
          flags: flags,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'SPLINE':
        int degree = 3;
        int flags = 0;
        final List<Offset> controlPoints = [];
        final List<Offset> fitPoints = [];
        final List<double> knots = [];
        final List<double> weights = [];

        double tempCx = 0, tempCy = 0;
        double tempFx = 0, tempFy = 0;

        for (final p in entityPairs) {
          switch (p.code) {
            case 71:
              degree = p.intValue;
              break;
            case 70:
              flags = p.intValue;
              break;
            case 10:
              tempCx = p.doubleValue;
              break;
            case 20:
              tempCy = p.doubleValue;
              controlPoints.add(Offset(tempCx, tempCy));
              break;
            case 11:
              tempFx = p.doubleValue;
              break;
            case 21:
              tempFy = p.doubleValue;
              fitPoints.add(Offset(tempFx, tempFy));
              break;
            case 40:
              knots.add(p.doubleValue);
              break;
            case 41:
              weights.add(p.doubleValue);
              break;
          }
        }

        entity = DxfSpline(
          degree: degree,
          controlPoints: controlPoints,
          fitPoints: fitPoints,
          knots: knots,
          weights: weights,
          isClosed: (flags & 1) != 0,
          isRational: (flags & 4) != 0,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'TEXT':
        String text = '';
        double ix = 0, iy = 0;
        double? ax, ay;
        double height = 2.5;
        double rotation = 0;
        int hAlign = 0;
        int vAlign = 0;
        String? style;

        for (final p in entityPairs) {
          switch (p.code) {
            case 1:
              text = p.value;
              break;
            case 10:
              ix = p.doubleValue;
              break;
            case 20:
              iy = p.doubleValue;
              break;
            case 11:
              ax = p.doubleValue;
              break;
            case 21:
              ay = p.doubleValue;
              break;
            case 40:
              height = p.doubleValue;
              break;
            case 50:
              rotation = p.doubleValue;
              break;
            case 72:
              hAlign = p.intValue;
              break;
            case 73:
              vAlign = p.intValue;
              break;
            case 7:
              style = p.value.trim();
              break;
          }
        }

        final clean = _cleanCadText(text);
        entity = DxfText(
          text: clean,
          insertPoint: Offset(ix, iy),
          alignPoint: (ax != null && ay != null) ? Offset(ax, ay) : null,
          height: height > 0 ? height : 2.5,
          rotationDeg: rotation,
          hAlign: hAlign,
          vAlign: vAlign,
          style: style,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'MTEXT':
        final textBuffer = StringBuffer();
        double ix = 0, iy = 0;
        double height = 2.5;
        double? refWidth;
        double rotation = 0;
        int attachPoint = 1;
        double? dirX, dirY;

        for (final p in entityPairs) {
          switch (p.code) {
            case 3:
            case 1:
              textBuffer.write(p.value);
              break;
            case 10:
              ix = p.doubleValue;
              break;
            case 20:
              iy = p.doubleValue;
              break;
            case 40:
              height = p.doubleValue;
              break;
            case 41:
              refWidth = p.doubleValue;
              break;
            case 50:
              rotation = p.doubleValue;
              break;
            case 71:
              attachPoint = p.intValue;
              break;
            case 11:
              dirX = p.doubleValue;
              break;
            case 21:
              dirY = p.doubleValue;
              break;
          }
        }

        // If direction vector is given, compute rotation from it
        if (dirX != null && dirY != null && (dirX != 0 || dirY != 0)) {
          rotation = math.atan2(dirY, dirX) * 180.0 / math.pi;
        }

        final rawText = textBuffer.toString();
        final cleanText = _cleanMText(rawText);

        entity = DxfMText(
          rawText: rawText,
          cleanText: cleanText,
          insertPoint: Offset(ix, iy),
          height: height > 0 ? height : 2.5,
          refWidth: refWidth,
          rotationDeg: rotation,
          attachmentPoint: attachPoint,
          directionVector: (dirX != null && dirY != null) ? Offset(dirX, dirY) : null,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case '3DFACE':
      case 'SOLID':
      case 'TRACE':
        double x0 = 0, y0 = 0, x1 = 0, y1 = 0, x2 = 0, y2 = 0, x3 = 0, y3 = 0;
        bool has3 = false;
        for (final p in entityPairs) {
          switch (p.code) {
            case 10:
              x0 = p.doubleValue;
              break;
            case 20:
              y0 = p.doubleValue;
              break;
            case 11:
              x1 = p.doubleValue;
              break;
            case 21:
              y1 = p.doubleValue;
              break;
            case 12:
              x2 = p.doubleValue;
              break;
            case 22:
              y2 = p.doubleValue;
              break;
            case 13:
              x3 = p.doubleValue;
              has3 = true;
              break;
            case 23:
              y3 = p.doubleValue;
              break;
          }
        }
        if (!has3) {
          x3 = x2;
          y3 = y2;
        }
        entity = DxfSolid(
          p0: Offset(x0, y0),
          p1: Offset(x1, y1),
          p2: Offset(x2, y2),
          p3: Offset(x3, y3),
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'HATCH':
        String patternName = 'SOLID';
        bool isSolid = true;
        double patternAngle = 0;
        double patternScale = 1;
        final boundaryPaths = _parseHatchBoundaryPaths(entityPairs);

        for (final p in entityPairs) {
          switch (p.code) {
            case 2:
              patternName = p.value.trim();
              break;
            case 70:
              isSolid = (p.intValue & 1) != 0;
              break;
            case 52:
              patternAngle = p.doubleValue;
              break;
            case 41:
              patternScale = p.doubleValue;
              break;
          }
        }

        entity = DxfHatch(
          boundaryPaths: boundaryPaths,
          patternName: patternName,
          isSolid: isSolid,
          patternAngle: patternAngle,
          patternScale: patternScale,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'INSERT':
        String blockName = '';
        double ix = 0, iy = 0;
        double sx = 1.0, sy = 1.0, sz = 1.0;
        double rotation = 0;
        int rowCount = 1, colCount = 1;
        double rowSpacing = 0, colSpacing = 0;

        for (final p in entityPairs) {
          switch (p.code) {
            case 2:
              blockName = p.value.trim();
              break;
            case 10:
              ix = p.doubleValue;
              break;
            case 20:
              iy = p.doubleValue;
              break;
            case 41:
              sx = p.doubleValue;
              break;
            case 42:
              sy = p.doubleValue;
              break;
            case 43:
              sz = p.doubleValue;
              break;
            case 50:
              rotation = p.doubleValue;
              break;
            case 70:
              colCount = p.intValue;
              break;
            case 71:
              rowCount = p.intValue;
              break;
            case 44:
              colSpacing = p.doubleValue;
              break;
            case 45:
              rowSpacing = p.doubleValue;
              break;
          }
        }

        entity = DxfInsert(
          blockName: blockName,
          insertPoint: Offset(ix, iy),
          scaleX: sx != 0 ? sx : 1.0,
          scaleY: sy != 0 ? sy : 1.0,
          scaleZ: sz != 0 ? sz : 1.0,
          rotationDeg: rotation,
          colCount: colCount > 0 ? colCount : 1,
          rowCount: rowCount > 0 ? rowCount : 1,
          colSpacing: colSpacing,
          rowSpacing: rowSpacing,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'DIMENSION':
        int dimType = 0;
        double dx1 = 0, dy1 = 0, tx = 0, ty = 0;
        double? dx2, dy2;
        String? textOverride;
        String? blockName;

        for (final p in entityPairs) {
          switch (p.code) {
            case 70:
              dimType = p.intValue;
              break;
            case 10:
              dx1 = p.doubleValue;
              break;
            case 20:
              dy1 = p.doubleValue;
              break;
            case 11:
              tx = p.doubleValue;
              break;
            case 21:
              ty = p.doubleValue;
              break;
            case 13:
              dx2 = p.doubleValue;
              break;
            case 23:
              dy2 = p.doubleValue;
              break;
            case 1:
              textOverride = p.value;
              break;
            case 2:
              blockName = p.value.trim();
              break;
          }
        }

        entity = DxfDimension(
          dimType: dimType,
          defPoint1: Offset(dx1, dy1),
          textPoint: Offset(tx, ty),
          defPoint2: (dx2 != null && dy2 != null) ? Offset(dx2, dy2) : null,
          textOverride: textOverride != null ? _cleanCadText(textOverride) : null,
          blockName: blockName,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;

      case 'LEADER':
        final List<Offset> leaderVertices = [];
        bool hasArrow = true;
        double tempLx = 0;

        for (final p in entityPairs) {
          switch (p.code) {
            case 71:
              hasArrow = (p.intValue & 1) != 0;
              break;
            case 10:
              tempLx = p.doubleValue;
              break;
            case 20:
              leaderVertices.add(Offset(tempLx, p.doubleValue));
              break;
          }
        }

        entity = DxfLeader(
          vertices: leaderVertices,
          hasArrowhead: hasArrow,
          layer: layer,
          colorIndex: colorIndex,
          trueColor: trueColor,
          lineType: lineType,
          lineWeight: lineWeight,
        );
        break;
    }

    return (entity, idx);
  }

  /// Cleans CAD TEXT string, decoding unicode escape sequences, Cyrillic codepages, and CAD special codes.
  static String _cleanCadText(String text) {
    var result = text;

    // 1. Decode Unicode escape sequences: \U+XXXX or \U+XXXXXXXX (e.g. \U+0410 -> А)
    result = result.replaceAllMapped(
      RegExp(r'\\[Uu]\+([0-9a-fA-F]{4,8})'),
      (match) {
        final hex = match.group(1);
        if (hex != null) {
          final code = int.tryParse(hex, radix: 16);
          if (code != null) {
            return String.fromCharCode(code);
          }
        }
        return match.group(0)!;
      },
    );

    // 2. Decode AutoCAD MIF Cyrillic escape sequences: \M+5XXXX or \M+5XX (e.g. \M+5C0 -> А)
    result = result.replaceAllMapped(
      RegExp(r'\\[Mm]\+5([0-9a-fA-F]{2,4})'),
      (match) {
        final hex = match.group(1);
        if (hex != null) {
          final code = int.tryParse(hex, radix: 16);
          if (code != null) {
            final byteVal = code & 0xFF;
            if (byteVal >= 0xC0 && byteVal <= 0xDF) {
              return String.fromCharCode(0x0410 + (byteVal - 0xC0));
            } else if (byteVal >= 0xE0 && byteVal <= 0xFF) {
              return String.fromCharCode(0x0430 + (byteVal - 0xE0));
            } else if (byteVal == 0xA8) {
              return 'Ё';
            } else if (byteVal == 0xB8) {
              return 'ё';
            } else if (byteVal == 0xB9) {
              return '№';
            }
          }
        }
        return match.group(0)!;
      },
    );

    // 3. Decode AutoCAD ASCII decimal codes for Cyrillic: %%192 .. %%255
    result = result.replaceAllMapped(
      RegExp(r'%%([0-9]{3})'),
      (match) {
        final numStr = match.group(1);
        if (numStr != null) {
          final code = int.tryParse(numStr);
          if (code != null) {
            if (code >= 192 && code <= 223) {
              return String.fromCharCode(0x0410 + (code - 192)); // А..Я
            } else if (code >= 224 && code <= 255) {
              return String.fromCharCode(0x0430 + (code - 224)); // а..я
            } else if (code == 168) {
              return 'Ё';
            } else if (code == 184) {
              return 'ё';
            } else if (code == 185) {
              return '№';
            }
          }
        }
        return match.group(0)!;
      },
    );

    // 4. Standard CAD special symbols
    result = result.replaceAll(RegExp(r'%%[dD]'), '°');
    result = result.replaceAll(RegExp(r'%%[pP]'), '±');
    result = result.replaceAll(RegExp(r'%%[cC]'), '⌀');
    result = result.replaceAll(RegExp(r'%%[uUoOkK]'), '');
    result = result.replaceAll(RegExp(r'%%%'), '%');

    // 5. Auto-repair Mojibake (Latin-1 misinterpreted Windows-1251 Cyrillic)
    result = _repairCyrillicMojibake(result);

    // 6. Clean any embedded MTEXT codes/leftovers if present
    if (result.contains('\\') || result.contains(';') || result.contains('ql;') || result.contains('t0;')) {
      result = _stripMTextFormattingCodes(result);
    }

    return result;
  }

  /// Automatically detects and repairs Latin-1 Mojibake into Cyrillic.
  /// (e.g. "Àðõèòåêòóðà" -> "Архитектура")
  static String _repairCyrillicMojibake(String text) {
    if (text.isEmpty) return text;

    int mojibakeCount = 0;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0xC0 && code <= 0xFF) {
        mojibakeCount++;
      } else if (code >= 0x0400 && code <= 0x04FF) {
        return text;
      }
    }

    if (mojibakeCount > 0) {
      final buffer = StringBuffer();
      for (int i = 0; i < text.length; i++) {
        final code = text.codeUnitAt(i);
        if (code >= 0xC0 && code <= 0xDF) {
          buffer.writeCharCode(0x0410 + (code - 0xC0));
        } else if (code >= 0xE0 && code <= 0xFF) {
          buffer.writeCharCode(0x0430 + (code - 0xE0));
        } else if (code == 0xA8) {
          buffer.writeCharCode(0x0401);
        } else if (code == 0xB8) {
          buffer.writeCharCode(0x0451);
        } else if (code == 0xB9) {
          buffer.writeCharCode(0x2116);
        } else {
          buffer.writeCharCode(code);
        }
      }
      return buffer.toString();
    }

    return text;
  }

  /// Cleans MTEXT formatted string, stripping formatting codes, service tags (-ql;, t0;, etc.), and resolving newlines.
  static String _cleanMText(String text) {
    var result = text;

    // First decode unicode and Cyrillic
    result = _cleanCadText(result);

    // Strip all MTEXT formatting codes and service tags
    result = _stripMTextFormattingCodes(result);

    return result.trim();
  }

  /// Thoroughly strips AutoCAD MTEXT formatting sequences and residual service tokens.
  /// (e.g. \fArial...;, \C7;, \H0.25x;, \pxql,t0;, \pi-0.5,l0.5,t0;, -ql;, t0;, \S1/2;)
  static String _stripMTextFormattingCodes(String text) {
    var result = text;

    // 1. Simplify stacked fractions: \S1/2; or \S1^2; or \S1#2; -> 1/2 or 1^2
    result = result.replaceAllMapped(
      RegExp(r'\\[Ss]([^;]+);'),
      (match) => match.group(1)?.replaceAll('^', '') ?? '',
    );

    // 2. Repeatedly strip all standard AutoCAD backslash formatting sequences ending with semicolon:
    // e.g. \f...;, \F...;, \C...;, \c...;, \H...;, \W...;, \Q...;, \T...;, \A...;, \px...;, \pi...;, \pt...;, \ps...;
    // Repeat until fixed point to handle nested formatting blocks
    String prev;
    int iterations = 0;
    do {
      prev = result;
      // Strip backslash formatting codes ending in semicolon
      result = result.replaceAll(RegExp(r'\\[a-zA-Z0-9_\-]+[^;]*;', caseSensitive: false), '');
      // Strip formatting toggles without semicolon: \L, \l, \O, \o, \K, \k, \X, \x
      result = result.replaceAll(RegExp(r'\\[LlOoKkXx]'), '');
      // Strip residual braces
      result = result.replaceAll('{', '').replaceAll('}', '');
      iterations++;
    } while (result != prev && iterations < 10);

    // 3. Replace paragraph breaks \P with real newlines
    result = result.replaceAll(RegExp(r'\\[Pp]'), '\n');
    result = result.replaceAll(RegExp(r'\\~'), ' ');

    // 4. Strip leftover paragraph formatting tags from DWG/DXF converters
    // such as: -ql;, ql;, qc;, qr;, qj;, qd;, t0;, ,t0;, \pt0;, i0;, l0;, c0;, b0;, etc.
    // e.g. "-ql;,t0;Text" or ",t0;Text" or "Text -ql;,t0;"
    result = result.replaceAll(
      RegExp(
        r'(?:^|[\s,;\\])-?(?:ql|qc|qr|qj|qd|t\d+(?:\.\d+)?|i-?\d+(?:\.\d+)?|l\d+(?:\.\d+)?|c\d+|x\d+|b\d+|p\d+);',
        caseSensitive: false,
      ),
      '',
    );

    // Clean up any remaining leading/trailing commas or semicolons from stripped tags
    result = result.replaceAll(RegExp(r'^[,\s;]+'), '');

    // Remove remaining escaped backslashes
    result = result.replaceAll(r'\\', r'\');

    return result.trim();
  }

  /// Parses HATCH boundary path loops from entity pairs.
  static List<List<Offset>> _parseHatchBoundaryPaths(List<_DxfPair> pairs) {
    final List<List<Offset>> paths = [];
    final int len = pairs.length;
    int i = 0;

    while (i < len) {
      if (pairs[i].code == 92) {
        final flag = pairs[i].intValue;
        final bool isPolyline = (flag & 4) != 0;
        i++;

        if (isPolyline) {
          int hasBulge = 0;
          int isClosed = 1;

          while (i < len && pairs[i].code != 93 && pairs[i].code != 10 && pairs[i].code != 92) {
            if (pairs[i].code == 72) hasBulge = pairs[i].intValue;
            if (pairs[i].code == 73) isClosed = pairs[i].intValue;
            i++;
          }
          if (i < len && pairs[i].code == 93) {
            i++;
          }

          final List<DxfPolylineVertex> vertices = [];
          double vx = 0, vy = 0, vBulge = 0;
          bool hasV = false;

          void flushV() {
            if (hasV) {
              vertices.add(DxfPolylineVertex(x: vx, y: vy, bulge: vBulge));
              vBulge = 0;
            }
          }

          while (i < len && pairs[i].code != 92 && pairs[i].code != 97 && pairs[i].code != 75) {
            final p = pairs[i];
            if (p.code == 10) {
              flushV();
              vx = p.doubleValue;
              hasV = true;
            } else if (p.code == 20) {
              vy = p.doubleValue;
            } else if (p.code == 42 && hasBulge != 0) {
              vBulge = p.doubleValue;
            }
            i++;
          }
          flushV();

          if (vertices.isNotEmpty) {
            final List<Offset> loopPoints = [];
            final count = vertices.length;
            final endIdx = isClosed != 0 ? count : count - 1;
            for (int k = 0; k < endIdx; k++) {
              final v1 = vertices[k];
              final v2 = vertices[(k + 1) % count];
              if (v1.bulge.abs() > 1e-6) {
                final arcPts = DxfMath.generateBulgeArcPoints(v1.offset, v2.offset, v1.bulge);
                if (loopPoints.isNotEmpty && arcPts.isNotEmpty && (loopPoints.last - arcPts.first).distanceSquared < 1e-10) {
                  loopPoints.addAll(arcPts.skip(1));
                } else {
                  loopPoints.addAll(arcPts);
                }
              } else {
                if (loopPoints.isEmpty || (loopPoints.last - v1.offset).distanceSquared > 1e-10) {
                  loopPoints.add(v1.offset);
                }
                loopPoints.add(v2.offset);
              }
            }
            if (loopPoints.isNotEmpty) {
              paths.add(loopPoints);
            }
          }
        } else {
          // Non-polyline boundary: sequence of edges
          if (i < len && pairs[i].code == 93) {
            i++;
          }

          final List<Offset> loopPoints = [];
          while (i < len && pairs[i].code != 92 && pairs[i].code != 97 && pairs[i].code != 75) {
            if (pairs[i].code == 72) {
              final edgeType = pairs[i].intValue;
              i++;
              if (edgeType == 1) {
                // Line edge: 10, 20 (start), 11, 21 (end)
                double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
                while (i < len && pairs[i].code != 72 && pairs[i].code != 92 && pairs[i].code != 97 && pairs[i].code != 75) {
                  final p = pairs[i];
                  if (p.code == 10) {
                    x1 = p.doubleValue;
                  } else if (p.code == 20) {
                    y1 = p.doubleValue;
                  } else if (p.code == 11) {
                    x2 = p.doubleValue;
                  } else if (p.code == 21) {
                    y2 = p.doubleValue;
                  }
                  i++;
                }
                if (loopPoints.isEmpty || (loopPoints.last - Offset(x1, y1)).distanceSquared > 1e-10) {
                  loopPoints.add(Offset(x1, y1));
                }
                loopPoints.add(Offset(x2, y2));
              } else if (edgeType == 2) {
                // Circular arc edge: 10, 20 (center), 40 (r), 50 (startA), 51 (endA), 73 (isCCW)
                double cx = 0, cy = 0, r = 0, startA = 0, endA = 360;
                bool isCCW = true;
                while (i < len && pairs[i].code != 72 && pairs[i].code != 92 && pairs[i].code != 97 && pairs[i].code != 75) {
                  final p = pairs[i];
                  if (p.code == 10) {
                    cx = p.doubleValue;
                  } else if (p.code == 20) {
                    cy = p.doubleValue;
                  } else if (p.code == 40) {
                    r = p.doubleValue;
                  } else if (p.code == 50) {
                    startA = p.doubleValue;
                  } else if (p.code == 51) {
                    endA = p.doubleValue;
                  } else if (p.code == 73) {
                    isCCW = p.intValue != 0;
                  }
                  i++;
                }
                if (r > 0) {
                  double sweep = isCCW ? (endA - startA) : (startA - endA);
                  if (sweep <= 0) sweep += 360.0;
                  final int segs = (32 * (sweep / 360.0)).clamp(8, 48).toInt();
                  final double step = (sweep * math.pi / 180.0) / segs;
                  final double startRad = startA * math.pi / 180.0;
                  final double dir = isCCW ? 1.0 : -1.0;

                  for (int s = 0; s <= segs; s++) {
                    final double rad = startRad + s * step * dir;
                    final pt = Offset(cx + r * math.cos(rad), cy + r * math.sin(rad));
                    if (loopPoints.isEmpty || (loopPoints.last - pt).distanceSquared > 1e-10) {
                      loopPoints.add(pt);
                    }
                  }
                }
              } else if (edgeType == 3) {
                // Elliptic arc edge
                double cx = 0, cy = 0, mx = 0, my = 0, ratio = 1.0, sp = 0, ep = 2 * math.pi;
                while (i < len && pairs[i].code != 72 && pairs[i].code != 92 && pairs[i].code != 97 && pairs[i].code != 75) {
                  final p = pairs[i];
                  if (p.code == 10) {
                    cx = p.doubleValue;
                  } else if (p.code == 20) {
                    cy = p.doubleValue;
                  } else if (p.code == 11) {
                    mx = p.doubleValue;
                  } else if (p.code == 21) {
                    my = p.doubleValue;
                  } else if (p.code == 40) {
                    ratio = p.doubleValue;
                  } else if (p.code == 50) {
                    sp = p.doubleValue;
                  } else if (p.code == 51) {
                    ep = p.doubleValue;
                  }
                  i++;
                }
                final pts = DxfMath.generateEllipsePoints(
                  Offset(cx, cy),
                  Offset(mx, my),
                  ratio,
                  startParam: sp,
                  endParam: ep,
                  segments: 32,
                );
                for (final pt in pts) {
                  if (loopPoints.isEmpty || (loopPoints.last - pt).distanceSquared > 1e-10) {
                    loopPoints.add(pt);
                  }
                }
              } else {
                i++;
              }
            } else {
              i++;
            }
          }
          if (loopPoints.isNotEmpty) {
            paths.add(loopPoints);
          }
        }
      } else {
        i++;
      }
    }
    return paths;
  }
}
