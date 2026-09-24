import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/dxf_models.dart';
import '../rendering/dxf_quadtree.dart';
import 'kcad_writer.dart';

/// Fast binary reader over [Uint8List] using [ByteData].
class _KcadBinaryReader {
  final Uint8List buffer;
  final ByteData byteData;
  int _offset = 0;

  _KcadBinaryReader(this.buffer) : byteData = ByteData.sublistView(buffer);

  int get offset => _offset;
  int get remaining => buffer.length - _offset;

  int readUint8() => byteData.getUint8(_offset++);
  int readInt8() => byteData.getInt8(_offset++);

  int readUint16() {
    final v = byteData.getUint16(_offset, Endian.little);
    _offset += 2;
    return v;
  }

  int readInt16() {
    final v = byteData.getInt16(_offset, Endian.little);
    _offset += 2;
    return v;
  }

  int readUint32() {
    final v = byteData.getUint32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  int readInt32() {
    final v = byteData.getInt32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  int readInt64() {
    final v = byteData.getInt64(_offset, Endian.little);
    _offset += 8;
    return v;
  }

  double readFloat64() {
    final v = byteData.getFloat64(_offset, Endian.little);
    _offset += 8;
    return v;
  }

  double readFloat32() {
    final v = byteData.getFloat32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  int readCount() {
    final c = readUint16();
    if (c == 0xFFFF) {
      return readUint32();
    }
    return c;
  }

  Uint8List readBytes(int length) {
    final slice = Uint8List.sublistView(buffer, _offset, _offset + length);
    _offset += length;
    return slice;
  }
}

/// Base entity deserialization metadata.
class _EntityBaseData {
  final String layer;
  final int? colorIndex;
  final int? trueColor;
  final String? lineType;
  final double? lineWeight;
  final double? lineTypeScale;

  const _EntityBaseData({
    required this.layer,
    this.colorIndex,
    this.trueColor,
    this.lineType,
    this.lineWeight,
    this.lineTypeScale,
  });
}

/// High-performance reader for KCAD binary files, reconstructing complete [DxfDocument] instances.
class KcadReader {
  /// Reads [DxfDocument] from in-memory KCAD [bytes].
  static DxfDocument read(Uint8List bytes) {
    if (bytes.length < 16) {
      throw const FormatException('Invalid KCAD file: Header too short (<16 bytes)');
    }

    final headerReader = _KcadBinaryReader(bytes);

    // 1. Verify Magic Bytes ('KCAD')
    final m0 = headerReader.readUint8();
    final m1 = headerReader.readUint8();
    final m2 = headerReader.readUint8();
    final m3 = headerReader.readUint8();
    if (m0 != 0x4B || m1 != 0x43 || m2 != 0x41 || m3 != 0x44) {
      throw const FormatException('Invalid KCAD file: Magic bytes mismatch');
    }

    // 2. Read Header
    final version = headerReader.readUint16();
    if (version != 1 && version != 2) {
      throw FormatException('Unsupported KCAD version: $version');
    }

    final flags = headerReader.readUint16();
    final isCompressed = (flags & KcadWriter.flagCompressed) != 0;
    final uncompressedSize = headerReader.readUint32();
    final payloadSize = headerReader.readUint32();

    final payloadBytes = headerReader.readBytes(payloadSize);

    // 3. Decompress body if needed
    final Uint8List bodyBytes;
    if (isCompressed) {
      bodyBytes = Uint8List.fromList(zlib.decode(payloadBytes));
      if (bodyBytes.length != uncompressedSize) {
        debugPrint('KCAD warning: Decompressed size ${bodyBytes.length} != expected $uncompressedSize');
      }
    } else {
      bodyBytes = payloadBytes;
    }

    final bodyReader = _KcadBinaryReader(bodyBytes);
    final isV2 = version >= 2;

    // 4. Read String Table
    final stringTableCount = bodyReader.readUint32();
    final stringTable = List<String>.filled(stringTableCount, '');
    for (int i = 0; i < stringTableCount; i++) {
      final len = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
      final strBytes = bodyReader.readBytes(len);
      stringTable[i] = utf8.decode(strBytes);
    }

    // 5. Read Tables
    // TextStyles
    final styleCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
    final Map<String, DxfTextStyle> textStyles = {};
    for (int i = 0; i < styleCount; i++) {
      final name = stringTable[bodyReader.readUint32()];
      final heightScale = isV2 ? bodyReader.readFloat32() : bodyReader.readFloat64();
      final hasFont = bodyReader.readUint8() != 0;
      final fontFile = hasFont ? stringTable[bodyReader.readUint32()] : null;
      final isVertical = bodyReader.readUint8() != 0;
      textStyles[name] = DxfTextStyle(
        name: name,
        heightScale: heightScale,
        fontFile: fontFile,
        isVertical: isVertical,
      );
    }

    // LineTypes
    final linetypeCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
    final Map<String, List<double>> lineTypes = {};
    for (int i = 0; i < linetypeCount; i++) {
      final name = stringTable[bodyReader.readUint32()];
      final dashesCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
      final dashes = List<double>.filled(dashesCount, 0.0);
      for (int d = 0; d < dashesCount; d++) {
        dashes[d] = isV2 ? bodyReader.readFloat32() : bodyReader.readFloat64();
      }
      lineTypes[name] = dashes;
    }

    // Layers
    final layerCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
    final Map<String, DxfLayer> layers = {};
    for (int i = 0; i < layerCount; i++) {
      final name = stringTable[bodyReader.readUint32()];
      final colorIndex = bodyReader.readInt32();
      final hasTrueColor = bodyReader.readUint8() != 0;
      final trueColor = hasTrueColor ? bodyReader.readInt32() : null;
      final isVisible = bodyReader.readUint8() != 0;
      final isFrozen = bodyReader.readUint8() != 0;
      final hasLineweight = bodyReader.readUint8() != 0;
      final lineweight = hasLineweight
          ? (isV2 ? bodyReader.readFloat32() : bodyReader.readFloat64())
          : null;
      final hasCustomLineweight = bodyReader.readUint8() != 0;
      final customLineweight = hasCustomLineweight
          ? (isV2 ? bodyReader.readFloat32() : bodyReader.readFloat64())
          : null;
      final hasLineType = bodyReader.readUint8() != 0;
      final lineType = hasLineType ? stringTable[bodyReader.readUint32()] : null;
      final isThick = bodyReader.readUint8() != 0;

      layers[name] = DxfLayer(
        name: name,
        colorIndex: colorIndex,
        trueColor: trueColor,
        isVisible: isVisible,
        isFrozen: isFrozen,
        lineweight: lineweight,
        customLineweight: customLineweight,
        lineType: lineType,
        isThick: isThick,
      );
    }

    // HeaderVars
    final headerCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
    final Map<String, String> headerVars = {};
    for (int i = 0; i < headerCount; i++) {
      final k = stringTable[bodyReader.readUint32()];
      final v = stringTable[bodyReader.readUint32()];
      headerVars[k] = v;
    }

    // EntityStats
    final statsCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
    final Map<String, int> entityStats = {};
    for (int i = 0; i < statsCount; i++) {
      final k = stringTable[bodyReader.readUint32()];
      final v = bodyReader.readInt32();
      entityStats[k] = v;
    }

    // 6. Read Blocks
    final blockCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
    final Map<String, DxfBlock> blocks = {};
    for (int i = 0; i < blockCount; i++) {
      final blockName = stringTable[bodyReader.readUint32()];
      final baseX = bodyReader.readFloat64();
      final baseY = bodyReader.readFloat64();
      final entityCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
      final blockEntities = List<DxfEntity>.filled(entityCount, const DxfLine(p1: Offset.zero, p2: Offset.zero));
      for (int e = 0; e < entityCount; e++) {
        // Block entities are decoded with local origin (0, 0)
        blockEntities[e] = _readEntity(stringTable, bodyReader, isV2, 0.0, 0.0);
      }
      blocks[blockName] = DxfBlock(
        name: blockName,
        basePoint: Offset(baseX, baseY),
        entities: blockEntities,
      );
    }

    // 7. Read Document Bounds (Float64 preserved for UTM / geodetic reference)
    final left = bodyReader.readFloat64();
    final top = bodyReader.readFloat64();
    final right = bodyReader.readFloat64();
    final bottom = bodyReader.readFloat64();
    final bounds = Rect.fromLTRB(left, top, right, bottom);

    // Reference Origin for Root Entities (Version 2)
    final double originX = bounds.left;
    final double originY = bounds.top;

    // 8. Read Root Entities
    final rootEntityCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
    final entities = List<DxfEntity>.filled(rootEntityCount, const DxfLine(p1: Offset.zero, p2: Offset.zero));
    for (int i = 0; i < rootEntityCount; i++) {
      entities[i] = _readEntity(stringTable, bodyReader, isV2, originX, originY);
    }

    // 9. Construct DxfDocument and Spatial Index
    final doc = DxfDocument(
      layers: layers,
      blocks: blocks,
      entities: entities,
      headerVars: headerVars,
      textStyles: textStyles,
      bounds: bounds,
      entityStats: entityStats,
      lineTypes: lineTypes,
    );

    doc.spatialIndex = DxfQuadTree.build(doc.entities, doc.blocks, doc.bounds);
    return doc;
  }

  /// Reads [DxfDocument] directly from a KCAD [file].
  static Future<DxfDocument> readFromFile(File file) async {
    final bytes = await file.readAsBytes();
    return read(bytes);
  }

  static _EntityBaseData _readBase(
    List<String> stringTable,
    _KcadBinaryReader reader,
    bool isV2,
  ) {
    final flags = reader.readUint8();
    final layer = stringTable[reader.readUint32()];
    final colorIndex = (flags & 1) != 0 ? reader.readInt32() : null;
    final trueColor = (flags & 2) != 0 ? reader.readInt32() : null;
    final lineType = (flags & 4) != 0 ? stringTable[reader.readUint32()] : null;
    final lineWeight = (flags & 8) != 0
        ? (isV2 ? reader.readFloat32() : reader.readFloat64())
        : null;
    final lineTypeScale = (flags & 16) != 0
        ? (isV2 ? reader.readFloat32() : reader.readFloat64())
        : null;

    return _EntityBaseData(
      layer: layer,
      colorIndex: colorIndex,
      trueColor: trueColor,
      lineType: lineType,
      lineWeight: lineWeight,
      lineTypeScale: lineTypeScale,
    );
  }

  static DxfEntity _readEntity(
    List<String> stringTable,
    _KcadBinaryReader reader,
    bool isV2,
    double ox,
    double oy,
  ) {
    final typeCode = reader.readUint8();
    final base = _readBase(stringTable, reader, isV2);

    switch (typeCode) {
      case KcadEntityType.line:
        final x1 = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final y1 = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        final x2 = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final y2 = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        return DxfLine(
          p1: Offset(x1, y1),
          p2: Offset(x2, y2),
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.point:
        final x = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final y = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        return DxfPoint(
          point: Offset(x, y),
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.circle:
        final cx = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final cy = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        final r = isV2 ? reader.readFloat32() : reader.readFloat64();
        return DxfCircle(
          center: Offset(cx, cy),
          radius: r,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.arc:
        final cx = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final cy = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        final r = isV2 ? reader.readFloat32() : reader.readFloat64();
        final sa = isV2 ? reader.readFloat32() : reader.readFloat64();
        final ea = isV2 ? reader.readFloat32() : reader.readFloat64();
        return DxfArc(
          center: Offset(cx, cy),
          radius: r,
          startAngleDeg: sa,
          endAngleDeg: ea,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.ellipse:
        final cx = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final cy = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        final mx = isV2 ? reader.readFloat32() : reader.readFloat64();
        final my = isV2 ? reader.readFloat32() : reader.readFloat64();
        final ratio = isV2 ? reader.readFloat32() : reader.readFloat64();
        final sp = isV2 ? reader.readFloat32() : reader.readFloat64();
        final ep = isV2 ? reader.readFloat32() : reader.readFloat64();
        return DxfEllipse(
          center: Offset(cx, cy),
          majorAxisEndOffset: Offset(mx, my),
          minorRatio: ratio,
          startParam: sp,
          endParam: ep,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.lwPolyline:
        final isClosed = reader.readUint8() != 0;
        final elevation = isV2 ? reader.readFloat32() : reader.readFloat64();
        final count = isV2 ? reader.readCount() : reader.readUint32();
        final vertices = List<DxfPolylineVertex>.filled(
          count,
          const DxfPolylineVertex(x: 0, y: 0),
        );
        for (int v = 0; v < count; v++) {
          final vx = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
          final vy = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
          final bulge = isV2 ? reader.readFloat32() : reader.readFloat64();
          final sw = isV2 ? reader.readFloat32() : reader.readFloat64();
          final ew = isV2 ? reader.readFloat32() : reader.readFloat64();
          final flags = reader.readInt32();
          vertices[v] = DxfPolylineVertex(
            x: vx,
            y: vy,
            bulge: bulge,
            startWidth: sw,
            endWidth: ew,
            flags: flags,
          );
        }
        return DxfLwPolyline(
          vertices: vertices,
          isClosed: isClosed,
          elevation: elevation,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.polyline:
        final isClosed = reader.readUint8() != 0;
        final is3D = reader.readUint8() != 0;
        final flags = reader.readInt32();
        final count = isV2 ? reader.readCount() : reader.readUint32();
        final vertices = List<DxfPolylineVertex>.filled(
          count,
          const DxfPolylineVertex(x: 0, y: 0),
        );
        for (int v = 0; v < count; v++) {
          final vx = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
          final vy = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
          final bulge = isV2 ? reader.readFloat32() : reader.readFloat64();
          final sw = isV2 ? reader.readFloat32() : reader.readFloat64();
          final ew = isV2 ? reader.readFloat32() : reader.readFloat64();
          final vFlags = reader.readInt32();
          vertices[v] = DxfPolylineVertex(
            x: vx,
            y: vy,
            bulge: bulge,
            startWidth: sw,
            endWidth: ew,
            flags: vFlags,
          );
        }
        return DxfPolyline(
          vertices: vertices,
          isClosed: isClosed,
          is3D: is3D,
          flags: flags,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.spline:
        final degree = reader.readInt32();
        final isClosed = reader.readUint8() != 0;
        final isRational = reader.readUint8() != 0;
        final ctrlCount = isV2 ? reader.readCount() : reader.readUint32();
        final controlPoints = List<Offset>.filled(ctrlCount, Offset.zero);
        for (int i = 0; i < ctrlCount; i++) {
          final x = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
          final y = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
          controlPoints[i] = Offset(x, y);
        }
        final fitCount = isV2 ? reader.readCount() : reader.readUint32();
        final fitPoints = List<Offset>.filled(fitCount, Offset.zero);
        for (int i = 0; i < fitCount; i++) {
          final x = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
          final y = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
          fitPoints[i] = Offset(x, y);
        }
        final knotCount = isV2 ? reader.readCount() : reader.readUint32();
        final knots = List<double>.filled(knotCount, 0.0);
        for (int i = 0; i < knotCount; i++) {
          knots[i] = isV2 ? reader.readFloat32() : reader.readFloat64();
        }
        final weightCount = isV2 ? reader.readCount() : reader.readUint32();
        final weights = List<double>.filled(weightCount, 0.0);
        for (int i = 0; i < weightCount; i++) {
          weights[i] = isV2 ? reader.readFloat32() : reader.readFloat64();
        }
        return DxfSpline(
          degree: degree,
          controlPoints: controlPoints,
          fitPoints: fitPoints,
          knots: knots,
          weights: weights,
          isClosed: isClosed,
          isRational: isRational,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.text:
        final text = stringTable[reader.readUint32()];
        final ix = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final iy = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        final hasAlign = reader.readUint8() != 0;
        final alignPoint = hasAlign
            ? Offset(
                isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
                isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
              )
            : null;
        final height = isV2 ? reader.readFloat32() : reader.readFloat64();
        final rotation = isV2 ? reader.readFloat32() : reader.readFloat64();
        final hAlign = reader.readInt32();
        final vAlign = reader.readInt32();
        final hasStyle = reader.readUint8() != 0;
        final style = hasStyle ? stringTable[reader.readUint32()] : null;
        return DxfText(
          text: text,
          insertPoint: Offset(ix, iy),
          alignPoint: alignPoint,
          height: height,
          rotationDeg: rotation,
          hAlign: hAlign,
          vAlign: vAlign,
          style: style,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.mText:
        final rawText = stringTable[reader.readUint32()];
        final cleanText = stringTable[reader.readUint32()];
        final ix = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final iy = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        final height = isV2 ? reader.readFloat32() : reader.readFloat64();
        final hasRefWidth = reader.readUint8() != 0;
        final refWidth = hasRefWidth
            ? (isV2 ? reader.readFloat32() : reader.readFloat64())
            : null;
        final rotation = isV2 ? reader.readFloat32() : reader.readFloat64();
        final attachmentPoint = reader.readInt32();
        final hasDir = reader.readUint8() != 0;
        final dir = hasDir
            ? Offset(
                isV2 ? reader.readFloat32() : reader.readFloat64(),
                isV2 ? reader.readFloat32() : reader.readFloat64(),
              )
            : null;
        final hasStyle = reader.readUint8() != 0;
        final style = hasStyle ? stringTable[reader.readUint32()] : null;
        final widthFactor = isV2 ? reader.readFloat32() : reader.readFloat64();
        final hasLineSpacing = reader.readUint8() != 0;
        final lineSpacingFactor = hasLineSpacing
            ? (isV2 ? reader.readFloat32() : reader.readFloat64())
            : null;
        return DxfMText(
          rawText: rawText,
          cleanText: cleanText,
          insertPoint: Offset(ix, iy),
          height: height,
          refWidth: refWidth,
          rotationDeg: rotation,
          attachmentPoint: attachmentPoint,
          directionVector: dir,
          style: style,
          widthFactor: widthFactor,
          lineSpacingFactor: lineSpacingFactor,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.solid:
        final p0 = Offset(
          isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
          isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
        );
        final p1 = Offset(
          isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
          isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
        );
        final p2 = Offset(
          isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
          isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
        );
        final p3 = Offset(
          isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
          isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
        );
        return DxfSolid(
          p0: p0,
          p1: p1,
          p2: p2,
          p3: p3,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.hatch:
        final patternName = stringTable[reader.readUint32()];
        final isSolid = reader.readUint8() != 0;
        final patternAngle = isV2 ? reader.readFloat32() : reader.readFloat64();
        final patternScale = isV2 ? reader.readFloat32() : reader.readFloat64();
        final hasTransparency = reader.readUint8() != 0;
        final transparency = hasTransparency
            ? (isV2 ? reader.readFloat32() : reader.readFloat64())
            : null;
        final loopCount = isV2 ? reader.readCount() : reader.readUint32();
        final boundaryPaths = <List<Offset>>[];
        for (int l = 0; l < loopCount; l++) {
          final ptCount = isV2 ? reader.readCount() : reader.readUint32();
          final loop = List<Offset>.filled(ptCount, Offset.zero);
          for (int p = 0; p < ptCount; p++) {
            final x = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
            final y = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
            loop[p] = Offset(x, y);
          }
          boundaryPaths.add(loop);
        }
        final hasPatternLines = reader.readUint8() != 0;
        List<DxfHatchPatternLine>? patternLines;
        if (hasPatternLines) {
          final plCount = isV2 ? reader.readCount() : reader.readUint32();
          patternLines = List<DxfHatchPatternLine>.generate(plCount, (_) {
            final angle = isV2 ? reader.readFloat32() : reader.readFloat64();
            final bx = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
            final by = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
            final pOx = isV2 ? reader.readFloat32() : reader.readFloat64();
            final pOy = isV2 ? reader.readFloat32() : reader.readFloat64();
            final dashesCount = isV2 ? reader.readCount() : reader.readUint32();
            final dashes = List<double>.filled(dashesCount, 0.0);
            for (int d = 0; d < dashesCount; d++) {
              dashes[d] = isV2 ? reader.readFloat32() : reader.readFloat64();
            }
            return DxfHatchPatternLine(
              angle: angle,
              basePoint: Offset(bx, by),
              offset: Offset(pOx, pOy),
              dashes: dashes,
            );
          });
        }
        return DxfHatch(
          boundaryPaths: boundaryPaths,
          patternName: patternName,
          isSolid: isSolid,
          patternAngle: patternAngle,
          patternScale: patternScale,
          transparency: transparency,
          patternLines: patternLines,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.insert:
        final blockName = stringTable[reader.readUint32()];
        final ix = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final iy = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        final sx = isV2 ? reader.readFloat32() : reader.readFloat64();
        final sy = isV2 ? reader.readFloat32() : reader.readFloat64();
        final sz = isV2 ? reader.readFloat32() : reader.readFloat64();
        final rot = isV2 ? reader.readFloat32() : reader.readFloat64();
        final rowCount = reader.readInt32();
        final colCount = reader.readInt32();
        final rowSpacing = isV2 ? reader.readFloat32() : reader.readFloat64();
        final colSpacing = isV2 ? reader.readFloat32() : reader.readFloat64();
        return DxfInsert(
          blockName: blockName,
          insertPoint: Offset(ix, iy),
          scaleX: sx,
          scaleY: sy,
          scaleZ: sz,
          rotationDeg: rot,
          rowCount: rowCount,
          colCount: colCount,
          rowSpacing: rowSpacing,
          colSpacing: colSpacing,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.dimension:
        final dimType = reader.readInt32();
        final p1 = Offset(
          isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
          isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
        );
        final hasP2 = reader.readUint8() != 0;
        final p2 = hasP2
            ? Offset(
                isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
                isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
              )
            : null;
        final tp = Offset(
          isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
          isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
        );
        final hasOverride = reader.readUint8() != 0;
        final textOverride = hasOverride ? stringTable[reader.readUint32()] : null;
        final hasBlock = reader.readUint8() != 0;
        final blockName = hasBlock ? stringTable[reader.readUint32()] : null;
        return DxfDimension(
          dimType: dimType,
          defPoint1: p1,
          defPoint2: p2,
          textPoint: tp,
          textOverride: textOverride,
          blockName: blockName,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      case KcadEntityType.leader:
        final hasArrowhead = reader.readUint8() != 0;
        final vCount = isV2 ? reader.readCount() : reader.readUint32();
        final vertices = List<Offset>.filled(vCount, Offset.zero);
        for (int v = 0; v < vCount; v++) {
          final x = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
          final y = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
          vertices[v] = Offset(x, y);
        }
        return DxfLeader(
          vertices: vertices,
          hasArrowhead: hasArrowhead,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
        );

      default:
        throw FormatException('Unknown KCAD entity type code: $typeCode');
    }
  }
}
