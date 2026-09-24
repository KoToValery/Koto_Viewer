import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/dxf_models.dart';

/// Internal fast growing binary buffer for KCAD serialization.
class _KcadBinaryBuffer {
  Uint8List _buffer;
  int _offset = 0;
  late ByteData _byteData;

  _KcadBinaryBuffer([int initialCapacity = 2 * 1024 * 1024])
      : _buffer = Uint8List(initialCapacity) {
    _byteData = ByteData.sublistView(_buffer);
  }

  int get length => _offset;

  void _ensureCapacity(int needed) {
    if (_offset + needed > _buffer.length) {
      int newCap = _buffer.length * 2;
      while (newCap < _offset + needed) {
        newCap *= 2;
      }
      final newBuf = Uint8List(newCap);
      newBuf.setRange(0, _offset, _buffer);
      _buffer = newBuf;
      _byteData = ByteData.sublistView(_buffer);
    }
  }

  void writeUint8(int v) {
    _ensureCapacity(1);
    _byteData.setUint8(_offset++, v);
  }

  void writeInt8(int v) {
    _ensureCapacity(1);
    _byteData.setInt8(_offset++, v);
  }

  void writeUint16(int v) {
    _ensureCapacity(2);
    _byteData.setUint16(_offset, v, Endian.little);
    _offset += 2;
  }

  void writeInt16(int v) {
    _ensureCapacity(2);
    _byteData.setInt16(_offset, v, Endian.little);
    _offset += 2;
  }

  void writeUint32(int v) {
    _ensureCapacity(4);
    _byteData.setUint32(_offset, v, Endian.little);
    _offset += 4;
  }

  void writeInt32(int v) {
    _ensureCapacity(4);
    _byteData.setInt32(_offset, v, Endian.little);
    _offset += 4;
  }

  void writeInt64(int v) {
    _ensureCapacity(8);
    _byteData.setInt64(_offset, v, Endian.little);
    _offset += 8;
  }

  void writeFloat64(double v) {
    _ensureCapacity(8);
    _byteData.setFloat64(_offset, v, Endian.little);
    _offset += 8;
  }

  void writeFloat32(double v) {
    _ensureCapacity(4);
    _byteData.setFloat32(_offset, v, Endian.little);
    _offset += 4;
  }

  /// Compact integer encoding: 2 bytes if < 0xFFFF, else 0xFFFF + 4 bytes.
  void writeCount(int count) {
    if (count < 0xFFFF) {
      writeUint16(count);
    } else {
      writeUint16(0xFFFF);
      writeUint32(count);
    }
  }

  void writeBytes(List<int> bytes) {
    _ensureCapacity(bytes.length);
    _buffer.setRange(_offset, _offset + bytes.length, bytes);
    _offset += bytes.length;
  }

  Uint8List toUint8List() {
    return Uint8List.sublistView(_buffer, 0, _offset);
  }
}

/// Collects and assigns 0-based IDs to unique strings to deduplicate text in CAD drawings.
/// Backed by HashMap for strict O(1) amortized deduplication.
class _StringTableWriter {
  final Map<String, int> _stringToId = {};
  final List<String> _strings = [];

  int getId(String s) {
    return _stringToId.putIfAbsent(s, () {
      final id = _strings.length;
      _strings.add(s);
      return id;
    });
  }

  void writeTo(_KcadBinaryBuffer buf) {
    buf.writeUint32(_strings.length);
    for (int i = 0; i < _strings.length; i++) {
      final bytes = utf8.encode(_strings[i]);
      buf.writeCount(bytes.length);
      buf.writeBytes(bytes);
    }
  }
}

/// Binary Entity Type Codes
class KcadEntityType {
  static const int line = 1;
  static const int point = 2;
  static const int circle = 3;
  static const int arc = 4;
  static const int ellipse = 5;
  static const int lwPolyline = 6;
  static const int polyline = 7;
  static const int spline = 8;
  static const int text = 9;
  static const int mText = 10;
  static const int solid = 11;
  static const int hatch = 12;
  static const int insert = 13;
  static const int dimension = 14;
  static const int leader = 15;
}

/// Serializes a [DxfDocument] into ultra-compact, high-performance KCAD binary format.
class KcadWriter {
  static const List<int> magicBytes = [0x4B, 0x43, 0x41, 0x44]; // 'K', 'C', 'A', 'D'
  /// Version 2: Relative Origin Float32 coordinates & compact count encoding.
  static const int currentVersion = 2;

  /// Flags: bit 0: isCompressed
  static const int flagCompressed = 1;

  /// Serializes [document] to KCAD binary data.
  /// If [compress] is true (default), the payload is compressed with native C zlib.
  static Uint8List write(DxfDocument document, {bool compress = true}) {
    final stringTable = _StringTableWriter();

    // 1. First pass: Collect all strings from tables, blocks, and entities (Hash-backed O(1))
    _collectStrings(document, stringTable);

    // 2. Build uncompressed body payload
    final bodyBuf = _KcadBinaryBuffer(4 * 1024 * 1024);

    // Write String Table
    stringTable.writeTo(bodyBuf);

    // Write Tables: TextStyles, LineTypes, Layers, HeaderVars, EntityStats
    _writeTables(document, stringTable, bodyBuf);

    // Write Blocks (blocks use local (0,0) origin)
    _writeBlocks(document, stringTable, bodyBuf);

    // Write Document Bounds & Global Reference Origin (Float64 for UTM / geodetic precision)
    final double originX = document.bounds.left;
    final double originY = document.bounds.top;
    bodyBuf.writeFloat64(document.bounds.left);
    bodyBuf.writeFloat64(document.bounds.top);
    bodyBuf.writeFloat64(document.bounds.right);
    bodyBuf.writeFloat64(document.bounds.bottom);

    // Write Root Entities (geometry stored in Float32 relative to originX, originY)
    bodyBuf.writeCount(document.entities.length);
    for (int i = 0; i < document.entities.length; i++) {
      _writeEntity(document.entities[i], stringTable, bodyBuf, originX, originY);
    }

    final rawBody = bodyBuf.toUint8List();

    // 3. Compress if requested
    final Uint8List payload;
    final int flags;
    if (compress) {
      payload = Uint8List.fromList(zlib.encode(rawBody));
      flags = flagCompressed;
    } else {
      payload = rawBody;
      flags = 0;
    }

    // 4. Header:
    // [0..3]: Magic 'KCAD' (4 bytes)
    // [4..5]: Version (uint16)
    // [6..7]: Flags (uint16)
    // [8..11]: Uncompressed body size (uint32)
    // [12..15]: Payload size (uint32)
    final headerBuf = _KcadBinaryBuffer(16 + payload.length);
    headerBuf.writeBytes(magicBytes);
    headerBuf.writeUint16(currentVersion);
    headerBuf.writeUint16(flags);
    headerBuf.writeUint32(rawBody.length);
    headerBuf.writeUint32(payload.length);
    headerBuf.writeBytes(payload);

    return headerBuf.toUint8List();
  }

  /// Writes [document] directly to a file on disk.
  static Future<void> writeToFile(File file, DxfDocument document, {bool compress = true}) async {
    final bytes = write(document, compress: compress);
    await file.writeAsBytes(bytes, flush: true);
  }

  static void _collectStrings(DxfDocument doc, _StringTableWriter st) {
    for (final entry in doc.headerVars.entries) {
      st.getId(entry.key);
      st.getId(entry.value);
    }
    for (final style in doc.textStyles.values) {
      st.getId(style.name);
      if (style.fontFile != null) st.getId(style.fontFile!);
    }
    for (final key in doc.lineTypes.keys) {
      st.getId(key);
    }
    for (final layer in doc.layers.values) {
      st.getId(layer.name);
      if (layer.lineType != null) st.getId(layer.lineType!);
    }
    for (final key in doc.entityStats.keys) {
      st.getId(key);
    }
    for (final block in doc.blocks.values) {
      st.getId(block.name);
      for (final e in block.entities) {
        _collectEntityStrings(e, st);
      }
    }
    for (final e in doc.entities) {
      _collectEntityStrings(e, st);
    }
  }

  static void _collectEntityStrings(DxfEntity e, _StringTableWriter st) {
    st.getId(e.layer);
    if (e.lineType != null) st.getId(e.lineType!);

    if (e is DxfText) {
      st.getId(e.text);
      if (e.style != null) st.getId(e.style!);
    } else if (e is DxfMText) {
      st.getId(e.rawText);
      st.getId(e.cleanText);
      if (e.style != null) st.getId(e.style!);
    } else if (e is DxfHatch) {
      st.getId(e.patternName);
    } else if (e is DxfInsert) {
      st.getId(e.blockName);
    } else if (e is DxfDimension) {
      if (e.textOverride != null) st.getId(e.textOverride!);
      if (e.blockName != null) st.getId(e.blockName!);
    }
  }

  static void _writeTables(DxfDocument doc, _StringTableWriter st, _KcadBinaryBuffer buf) {
    // 1. TextStyles
    buf.writeCount(doc.textStyles.length);
    for (final s in doc.textStyles.values) {
      buf.writeUint32(st.getId(s.name));
      buf.writeFloat32(s.heightScale);
      buf.writeUint8(s.fontFile != null ? 1 : 0);
      if (s.fontFile != null) buf.writeUint32(st.getId(s.fontFile!));
      buf.writeUint8(s.isVertical ? 1 : 0);
    }

    // 2. LineTypes
    buf.writeCount(doc.lineTypes.length);
    for (final entry in doc.lineTypes.entries) {
      buf.writeUint32(st.getId(entry.key));
      buf.writeCount(entry.value.length);
      for (final d in entry.value) {
        buf.writeFloat32(d);
      }
    }

    // 3. Layers
    buf.writeCount(doc.layers.length);
    for (final l in doc.layers.values) {
      buf.writeUint32(st.getId(l.name));
      buf.writeInt32(l.colorIndex);
      buf.writeUint8(l.trueColor != null ? 1 : 0);
      if (l.trueColor != null) buf.writeUint32(l.trueColor!);
      buf.writeUint8(l.isVisible ? 1 : 0);
      buf.writeUint8(l.isFrozen ? 1 : 0);
      buf.writeUint8(l.lineweight != null ? 1 : 0);
      if (l.lineweight != null) buf.writeFloat32(l.lineweight!);
      buf.writeUint8(l.customLineweight != null ? 1 : 0);
      if (l.customLineweight != null) buf.writeFloat32(l.customLineweight!);
      buf.writeUint8(l.lineType != null ? 1 : 0);
      if (l.lineType != null) buf.writeUint32(st.getId(l.lineType!));
      buf.writeUint8(l.isThick ? 1 : 0);
    }

    // 4. HeaderVars
    buf.writeCount(doc.headerVars.length);
    for (final entry in doc.headerVars.entries) {
      buf.writeUint32(st.getId(entry.key));
      buf.writeUint32(st.getId(entry.value));
    }

    // 5. EntityStats
    buf.writeCount(doc.entityStats.length);
    for (final entry in doc.entityStats.entries) {
      buf.writeUint32(st.getId(entry.key));
      buf.writeInt32(entry.value);
    }
  }

  static void _writeBlocks(DxfDocument doc, _StringTableWriter st, _KcadBinaryBuffer buf) {
    buf.writeCount(doc.blocks.length);
    for (final b in doc.blocks.values) {
      buf.writeUint32(st.getId(b.name));
      buf.writeFloat64(b.basePoint.dx);
      buf.writeFloat64(b.basePoint.dy);
      buf.writeCount(b.entities.length);
      for (int i = 0; i < b.entities.length; i++) {
        // Blocks have local coordinates relative to basePoint, ox=0, oy=0
        _writeEntity(b.entities[i], st, buf, 0.0, 0.0);
      }
    }
  }

  static void _writeEntity(
    DxfEntity e,
    _StringTableWriter st,
    _KcadBinaryBuffer buf,
    double ox,
    double oy,
  ) {
    int baseFlags = 0;
    if (e.colorIndex != null) baseFlags |= 1;
    if (e.trueColor != null) baseFlags |= 2;
    if (e.lineType != null) baseFlags |= 4;
    if (e.lineWeight != null) baseFlags |= 8;
    if (e.lineTypeScale != null) baseFlags |= 16;

    if (e is DxfLine) {
      buf.writeUint8(KcadEntityType.line);
      _writeBase(e, st, buf, baseFlags);
      buf.writeFloat32(e.p1.dx - ox);
      buf.writeFloat32(e.p1.dy - oy);
      buf.writeFloat32(e.p2.dx - ox);
      buf.writeFloat32(e.p2.dy - oy);
    } else if (e is DxfPoint) {
      buf.writeUint8(KcadEntityType.point);
      _writeBase(e, st, buf, baseFlags);
      buf.writeFloat32(e.point.dx - ox);
      buf.writeFloat32(e.point.dy - oy);
    } else if (e is DxfCircle) {
      buf.writeUint8(KcadEntityType.circle);
      _writeBase(e, st, buf, baseFlags);
      buf.writeFloat32(e.center.dx - ox);
      buf.writeFloat32(e.center.dy - oy);
      buf.writeFloat32(e.radius);
    } else if (e is DxfArc) {
      buf.writeUint8(KcadEntityType.arc);
      _writeBase(e, st, buf, baseFlags);
      buf.writeFloat32(e.center.dx - ox);
      buf.writeFloat32(e.center.dy - oy);
      buf.writeFloat32(e.radius);
      buf.writeFloat32(e.startAngleDeg);
      buf.writeFloat32(e.endAngleDeg);
    } else if (e is DxfEllipse) {
      buf.writeUint8(KcadEntityType.ellipse);
      _writeBase(e, st, buf, baseFlags);
      buf.writeFloat32(e.center.dx - ox);
      buf.writeFloat32(e.center.dy - oy);
      buf.writeFloat32(e.majorAxisEndOffset.dx);
      buf.writeFloat32(e.majorAxisEndOffset.dy);
      buf.writeFloat32(e.minorRatio);
      buf.writeFloat32(e.startParam);
      buf.writeFloat32(e.endParam);
    } else if (e is DxfLwPolyline) {
      buf.writeUint8(KcadEntityType.lwPolyline);
      _writeBase(e, st, buf, baseFlags);
      buf.writeUint8(e.isClosed ? 1 : 0);
      buf.writeFloat32(e.elevation);
      buf.writeCount(e.vertices.length);
      for (final v in e.vertices) {
        buf.writeFloat32(v.x - ox);
        buf.writeFloat32(v.y - oy);
        buf.writeFloat32(v.bulge);
        buf.writeFloat32(v.startWidth);
        buf.writeFloat32(v.endWidth);
        buf.writeInt32(v.flags);
      }
    } else if (e is DxfPolyline) {
      buf.writeUint8(KcadEntityType.polyline);
      _writeBase(e, st, buf, baseFlags);
      buf.writeUint8(e.isClosed ? 1 : 0);
      buf.writeUint8(e.is3D ? 1 : 0);
      buf.writeInt32(e.flags);
      buf.writeCount(e.vertices.length);
      for (final v in e.vertices) {
        buf.writeFloat32(v.x - ox);
        buf.writeFloat32(v.y - oy);
        buf.writeFloat32(v.bulge);
        buf.writeFloat32(v.startWidth);
        buf.writeFloat32(v.endWidth);
        buf.writeInt32(v.flags);
      }
    } else if (e is DxfSpline) {
      buf.writeUint8(KcadEntityType.spline);
      _writeBase(e, st, buf, baseFlags);
      buf.writeInt32(e.degree);
      buf.writeUint8(e.isClosed ? 1 : 0);
      buf.writeUint8(e.isRational ? 1 : 0);
      buf.writeCount(e.controlPoints.length);
      for (final cp in e.controlPoints) {
        buf.writeFloat32(cp.dx - ox);
        buf.writeFloat32(cp.dy - oy);
      }
      buf.writeCount(e.fitPoints.length);
      for (final fp in e.fitPoints) {
        buf.writeFloat32(fp.dx - ox);
        buf.writeFloat32(fp.dy - oy);
      }
      buf.writeCount(e.knots.length);
      for (final k in e.knots) {
        buf.writeFloat32(k);
      }
      buf.writeCount(e.weights.length);
      for (final w in e.weights) {
        buf.writeFloat32(w);
      }
    } else if (e is DxfText) {
      buf.writeUint8(KcadEntityType.text);
      _writeBase(e, st, buf, baseFlags);
      buf.writeUint32(st.getId(e.text));
      buf.writeFloat32(e.insertPoint.dx - ox);
      buf.writeFloat32(e.insertPoint.dy - oy);
      buf.writeUint8(e.alignPoint != null ? 1 : 0);
      if (e.alignPoint != null) {
        buf.writeFloat32(e.alignPoint!.dx - ox);
        buf.writeFloat32(e.alignPoint!.dy - oy);
      }
      buf.writeFloat32(e.height);
      buf.writeFloat32(e.rotationDeg);
      buf.writeInt32(e.hAlign);
      buf.writeInt32(e.vAlign);
      buf.writeUint8(e.style != null ? 1 : 0);
      if (e.style != null) buf.writeUint32(st.getId(e.style!));
    } else if (e is DxfMText) {
      buf.writeUint8(KcadEntityType.mText);
      _writeBase(e, st, buf, baseFlags);
      buf.writeUint32(st.getId(e.rawText));
      buf.writeUint32(st.getId(e.cleanText));
      buf.writeFloat32(e.insertPoint.dx - ox);
      buf.writeFloat32(e.insertPoint.dy - oy);
      buf.writeFloat32(e.height);
      buf.writeUint8(e.refWidth != null ? 1 : 0);
      if (e.refWidth != null) buf.writeFloat32(e.refWidth!);
      buf.writeFloat32(e.rotationDeg);
      buf.writeInt32(e.attachmentPoint);
      buf.writeUint8(e.directionVector != null ? 1 : 0);
      if (e.directionVector != null) {
        buf.writeFloat32(e.directionVector!.dx);
        buf.writeFloat32(e.directionVector!.dy);
      }
      buf.writeUint8(e.style != null ? 1 : 0);
      if (e.style != null) buf.writeUint32(st.getId(e.style!));
      buf.writeFloat32(e.widthFactor);
      buf.writeUint8(e.lineSpacingFactor != null ? 1 : 0);
      if (e.lineSpacingFactor != null) buf.writeFloat32(e.lineSpacingFactor!);
    } else if (e is DxfSolid) {
      buf.writeUint8(KcadEntityType.solid);
      _writeBase(e, st, buf, baseFlags);
      buf.writeFloat32(e.p0.dx - ox);
      buf.writeFloat32(e.p0.dy - oy);
      buf.writeFloat32(e.p1.dx - ox);
      buf.writeFloat32(e.p1.dy - oy);
      buf.writeFloat32(e.p2.dx - ox);
      buf.writeFloat32(e.p2.dy - oy);
      buf.writeFloat32(e.p3.dx - ox);
      buf.writeFloat32(e.p3.dy - oy);
    } else if (e is DxfHatch) {
      buf.writeUint8(KcadEntityType.hatch);
      _writeBase(e, st, buf, baseFlags);
      buf.writeUint32(st.getId(e.patternName));
      buf.writeUint8(e.isSolid ? 1 : 0);
      buf.writeFloat32(e.patternAngle);
      buf.writeFloat32(e.patternScale);
      buf.writeUint8(e.transparency != null ? 1 : 0);
      if (e.transparency != null) buf.writeFloat32(e.transparency!);
      buf.writeCount(e.boundaryPaths.length);
      for (final loop in e.boundaryPaths) {
        buf.writeCount(loop.length);
        for (final pt in loop) {
          buf.writeFloat32(pt.dx - ox);
          buf.writeFloat32(pt.dy - oy);
        }
      }
      buf.writeUint8(e.patternLines != null ? 1 : 0);
      if (e.patternLines != null) {
        buf.writeCount(e.patternLines!.length);
        for (final pl in e.patternLines!) {
          buf.writeFloat32(pl.angle);
          buf.writeFloat32(pl.basePoint.dx - ox);
          buf.writeFloat32(pl.basePoint.dy - oy);
          buf.writeFloat32(pl.offset.dx);
          buf.writeFloat32(pl.offset.dy);
          buf.writeCount(pl.dashes.length);
          for (final d in pl.dashes) {
            buf.writeFloat32(d);
          }
        }
      }
    } else if (e is DxfInsert) {
      buf.writeUint8(KcadEntityType.insert);
      _writeBase(e, st, buf, baseFlags);
      buf.writeUint32(st.getId(e.blockName));
      buf.writeFloat32(e.insertPoint.dx - ox);
      buf.writeFloat32(e.insertPoint.dy - oy);
      buf.writeFloat32(e.scaleX);
      buf.writeFloat32(e.scaleY);
      buf.writeFloat32(e.scaleZ);
      buf.writeFloat32(e.rotationDeg);
      buf.writeInt32(e.rowCount);
      buf.writeInt32(e.colCount);
      buf.writeFloat32(e.rowSpacing);
      buf.writeFloat32(e.colSpacing);
    } else if (e is DxfDimension) {
      buf.writeUint8(KcadEntityType.dimension);
      _writeBase(e, st, buf, baseFlags);
      buf.writeInt32(e.dimType);
      buf.writeFloat32(e.defPoint1.dx - ox);
      buf.writeFloat32(e.defPoint1.dy - oy);
      buf.writeUint8(e.defPoint2 != null ? 1 : 0);
      if (e.defPoint2 != null) {
        buf.writeFloat32(e.defPoint2!.dx - ox);
        buf.writeFloat32(e.defPoint2!.dy - oy);
      }
      buf.writeFloat32(e.textPoint.dx - ox);
      buf.writeFloat32(e.textPoint.dy - oy);
      buf.writeUint8(e.textOverride != null ? 1 : 0);
      if (e.textOverride != null) buf.writeUint32(st.getId(e.textOverride!));
      buf.writeUint8(e.blockName != null ? 1 : 0);
      if (e.blockName != null) buf.writeUint32(st.getId(e.blockName!));
    } else if (e is DxfLeader) {
      buf.writeUint8(KcadEntityType.leader);
      _writeBase(e, st, buf, baseFlags);
      buf.writeUint8(e.hasArrowhead ? 1 : 0);
      buf.writeCount(e.vertices.length);
      for (final v in e.vertices) {
        buf.writeFloat32(v.dx - ox);
        buf.writeFloat32(v.dy - oy);
      }
    }
  }

  static void _writeBase(DxfEntity e, _StringTableWriter st, _KcadBinaryBuffer buf, int flags) {
    buf.writeUint8(flags);
    buf.writeUint32(st.getId(e.layer));
    if ((flags & 1) != 0) buf.writeInt32(e.colorIndex!);
    if ((flags & 2) != 0) buf.writeUint32(e.trueColor!);
    if ((flags & 4) != 0) buf.writeUint32(st.getId(e.lineType!));
    if ((flags & 8) != 0) buf.writeFloat32(e.lineWeight!);
    if ((flags & 16) != 0) buf.writeFloat32(e.lineTypeScale!);
  }
}
