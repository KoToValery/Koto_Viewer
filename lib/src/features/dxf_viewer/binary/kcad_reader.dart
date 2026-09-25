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
  int offset = 0;

  _KcadBinaryReader(this.buffer) : byteData = ByteData.sublistView(buffer);

  int get remaining => buffer.length - offset;

  void skip(int bytes) {
    offset += bytes;
  }

  int readUint8() => byteData.getUint8(offset++);
  int readInt8() => byteData.getInt8(offset++);

  int readUint16() {
    final v = byteData.getUint16(offset, Endian.little);
    offset += 2;
    return v;
  }

  int readInt16() {
    final v = byteData.getInt16(offset, Endian.little);
    offset += 2;
    return v;
  }

  int readUint32() {
    final v = byteData.getUint32(offset, Endian.little);
    offset += 4;
    return v;
  }

  int readInt32() {
    final v = byteData.getInt32(offset, Endian.little);
    offset += 4;
    return v;
  }

  int readInt64() {
    final v = byteData.getInt64(offset, Endian.little);
    offset += 8;
    return v;
  }

  double readFloat64() {
    final v = byteData.getFloat64(offset, Endian.little);
    offset += 8;
    return v;
  }

  double readFloat32() {
    final v = byteData.getFloat32(offset, Endian.little);
    offset += 4;
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
    final slice = Uint8List.sublistView(buffer, offset, offset + length);
    offset += length;
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
  final bool isPaperSpace;
  final String layoutName;

  const _EntityBaseData({
    required this.layer,
    this.colorIndex,
    this.trueColor,
    this.lineType,
    this.lineWeight,
    this.lineTypeScale,
    this.isPaperSpace = false,
    this.layoutName = 'Model',
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
    if (version < 1 || version > 5) {
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
      final trueColor = hasTrueColor ? bodyReader.readUint32() : null;
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

    // DimStyles (v4+)
    final Map<String, DxfDimStyle> dimStyles = {};
    if (version >= 4) {
      final dimStyleCount = bodyReader.readCount();
      for (int i = 0; i < dimStyleCount; i++) {
        final name = stringTable[bodyReader.readUint32()];
        final dimScale = bodyReader.readFloat32();
        final dimAsz = bodyReader.readFloat32();
        final dimExo = bodyReader.readFloat32();
        final dimExe = bodyReader.readFloat32();
        final dimTxt = bodyReader.readFloat32();
        final dimTsz = bodyReader.readFloat32();
        final dimGap = bodyReader.readFloat32();
        final hasBlk = bodyReader.readUint8() != 0;
        final dimBlk = hasBlk ? stringTable[bodyReader.readUint32()] : null;
        dimStyles[name] = DxfDimStyle(
          name: name,
          dimScale: dimScale,
          dimAsz: dimAsz,
          dimExo: dimExo,
          dimExe: dimExe,
          dimTxt: dimTxt,
          dimTsz: dimTsz,
          dimGap: dimGap,
          dimBlk: dimBlk,
        );
      }
    }

    // 6. Read Blocks
    final blockCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
    final Map<String, DxfBlock> blocks = {};
    for (int i = 0; i < blockCount; i++) {
      final blockName = stringTable[bodyReader.readUint32()];
      final baseX = bodyReader.readFloat64();
      final baseY = bodyReader.readFloat64();
      final entityCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
      final blockEntities = <DxfEntity>[];
      for (int e = 0; e < entityCount; e++) {
        // Block entities are decoded with local origin (0, 0)
        final entity = _readEntity(stringTable, bodyReader, version, 0.0, 0.0);
        if (entity != null) {
          blockEntities.add(entity);
        }
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

    // Reference Origin for Root Entities (Version 2 & 3)
    final double originX = bounds.left;
    final double originY = bounds.top;

    // 8. Read Root Entities
    final rootEntityCount = isV2 ? bodyReader.readCount() : bodyReader.readUint32();
    final entities = <DxfEntity>[];
    for (int i = 0; i < rootEntityCount; i++) {
      final entity = _readEntity(stringTable, bodyReader, version, originX, originY);
      if (entity != null) {
        entities.add(entity);
      }
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
      dimStyles: dimStyles,
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
    final trueColor = (flags & 2) != 0 ? reader.readUint32() : null;
    final lineType = (flags & 4) != 0 ? stringTable[reader.readUint32()] : null;
    final lineWeight = (flags & 8) != 0
        ? (isV2 ? reader.readFloat32() : reader.readFloat64())
        : null;
    final lineTypeScale = (flags & 16) != 0
        ? (isV2 ? reader.readFloat32() : reader.readFloat64())
        : null;

    final isPaperSpace = (flags & 32) != 0;
    final layoutName = (flags & 64) != 0
        ? stringTable[reader.readUint32()]
        : (isPaperSpace ? 'Layout1' : 'Model');

    return _EntityBaseData(
      layer: layer,
      colorIndex: colorIndex,
      trueColor: trueColor,
      lineType: lineType,
      lineWeight: lineWeight,
      lineTypeScale: lineTypeScale,
      isPaperSpace: isPaperSpace,
      layoutName: layoutName,
    );
  }

  static DxfEntity? _readEntity(
    List<String> stringTable,
    _KcadBinaryReader reader,
    int version,
    double ox,
    double oy,
  ) {
    final typeCode = reader.readUint8();
    final bool isV2 = version >= 2;
    final int payloadLength;
    final int entityEndOffset;

    if (version >= 3) {
      payloadLength = reader.readUint32();
      entityEndOffset = reader.offset + payloadLength;
    } else {
      payloadLength = 0;
      entityEndOffset = 0;
    }

    if (typeCode < 1 || typeCode > 18) {
      if (version >= 3) {
        // Forward compatibility: safely skip the unknown entity payload
        reader.offset = entityEndOffset;
        return null;
      }
      throw FormatException('Unknown KCAD entity type code: $typeCode');
    }

    final base = _readBase(stringTable, reader, isV2);
    final DxfEntity entity = _readEntityPayload(
      typeCode,
      base,
      stringTable,
      reader,
      isV2,
      ox,
      oy,
      version,
    );

    if (version >= 3 && reader.offset != entityEndOffset) {
      // Seek to the end of the entity payload in case of extra fields in a future revision
      reader.offset = entityEndOffset;
    }

    return entity;
  }

  static DxfEntity _readEntityPayload(
    int typeCode,
    _EntityBaseData base,
    List<String> stringTable,
    _KcadBinaryReader reader,
    bool isV2,
    double ox,
    double oy,
    int version,
  ) {
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
        final List<DxfAttribute> attributes = [];
        if (version >= 5 && reader.offset < reader.buffer.length) {
          final attrCount = reader.readCount();
          for (int a = 0; a < attrCount; a++) {
            final tag = stringTable[reader.readUint32()];
            final val = stringTable[reader.readUint32()];
            final isInv = reader.readUint8() != 0;
            final isConst = reader.readUint8() != 0;
            attributes.add(DxfAttribute(
              tag: tag,
              value: val,
              isInvisible: isInv,
              isConstant: isConst,
            ));
          }
        }
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
          attributes: attributes,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
        );

      case KcadEntityType.attdef:
        final tag = stringTable[reader.readUint32()];
        final text = stringTable[reader.readUint32()];
        final hasPrompt = reader.readUint8() != 0;
        final prompt = hasPrompt ? stringTable[reader.readUint32()] : null;
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
        final flags = reader.readInt32();
        return DxfAttdef(
          tag: tag,
          text: text,
          prompt: prompt,
          insertPoint: Offset(ix, iy),
          alignPoint: alignPoint,
          height: height,
          rotationDeg: rotation,
          hAlign: hAlign,
          vAlign: vAlign,
          style: style,
          flags: flags,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
        Offset? p3;
        double rotationDeg = 0.0;
        String? styleName;
        if (version >= 4) {
          final hasP3 = reader.readUint8() != 0;
          if (hasP3) {
            p3 = Offset(
              ox + reader.readFloat32(),
              oy + reader.readFloat32(),
            );
          }
          rotationDeg = reader.readFloat32();
          final hasStyle = reader.readUint8() != 0;
          if (hasStyle) {
            styleName = stringTable[reader.readUint32()];
          }
        }
        return DxfDimension(
          dimType: dimType,
          defPoint1: p1,
          defPoint2: p2,
          defPoint3: p3,
          textPoint: tp,
          rotationDeg: rotationDeg,
          textOverride: textOverride,
          blockName: blockName,
          styleName: styleName,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
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
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
        );

      case KcadEntityType.mLeader:
        final rawText = stringTable[reader.readUint32()];
        final cleanText = stringTable[reader.readUint32()];
        final textHeight = reader.readFloat32();
        final hasTextWidth = reader.readUint8() != 0;
        final textWidth = hasTextWidth ? reader.readFloat32() : null;
        final hasArrowhead = reader.readUint8() != 0;
        final arrowheadSize = reader.readFloat32();
        final doglegLength = reader.readFloat32();

        final hasConn = reader.readUint8() != 0;
        final connPoint = hasConn
            ? Offset(
                isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
                isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
              )
            : null;

        final hasDoglegDir = reader.readUint8() != 0;
        final doglegDir = hasDoglegDir
            ? Offset(reader.readFloat32(), reader.readFloat32())
            : null;

        final hasTextPos = reader.readUint8() != 0;
        final textPos = hasTextPos
            ? Offset(
                isV2 ? ox + reader.readFloat32() : reader.readFloat64(),
                isV2 ? oy + reader.readFloat32() : reader.readFloat64(),
              )
            : null;

        final lineCount = isV2 ? reader.readCount() : reader.readUint32();
        final leaderLines = <List<Offset>>[];
        for (int l = 0; l < lineCount; l++) {
          final ptCount = isV2 ? reader.readCount() : reader.readUint32();
          final pts = List<Offset>.filled(ptCount, Offset.zero);
          for (int p = 0; p < ptCount; p++) {
            final x = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
            final y = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
            pts[p] = Offset(x, y);
          }
          leaderLines.add(pts);
        }

        return DxfMLeader(
          leaderLines: leaderLines,
          connectionPoint: connPoint,
          doglegDirection: doglegDir,
          doglegLength: doglegLength,
          textPosition: textPos,
          rawText: rawText,
          cleanText: cleanText,
          textHeight: textHeight,
          textWidth: textWidth,
          hasArrowhead: hasArrowhead,
          arrowheadSize: arrowheadSize,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
        );

      case KcadEntityType.viewport:
        final cx = isV2 ? ox + reader.readFloat32() : reader.readFloat64();
        final cy = isV2 ? oy + reader.readFloat32() : reader.readFloat64();
        final width = isV2 ? reader.readFloat32() : reader.readFloat64();
        final height = isV2 ? reader.readFloat32() : reader.readFloat64();
        final viewCx = isV2 ? reader.readFloat32() : reader.readFloat64();
        final viewCy = isV2 ? reader.readFloat32() : reader.readFloat64();
        final viewHeight = isV2 ? reader.readFloat32() : reader.readFloat64();
        final status = reader.readInt32();
        final viewportId = reader.readInt32();
        final twistAngleDeg = isV2 ? reader.readFloat32() : reader.readFloat64();
        return DxfViewport(
          center: Offset(cx, cy),
          width: width,
          height: height,
          viewCenter: Offset(viewCx, viewCy),
          viewHeight: viewHeight,
          status: status,
          viewportId: viewportId,
          twistAngleDeg: twistAngleDeg,
          layer: base.layer,
          colorIndex: base.colorIndex,
          trueColor: base.trueColor,
          lineType: base.lineType,
          lineWeight: base.lineWeight,
          lineTypeScale: base.lineTypeScale,
          isPaperSpace: base.isPaperSpace,
          layoutName: base.layoutName,
        );

      default:
        throw FormatException('Unknown KCAD entity type code: $typeCode');
    }
  }
}
