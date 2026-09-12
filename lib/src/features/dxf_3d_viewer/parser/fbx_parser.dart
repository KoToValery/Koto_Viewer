import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../models/mesh_3d.dart';

/// Representation of an FBX AST Node.
class FbxNode {
  final String name;
  final List<dynamic> properties;
  final List<FbxNode> children;

  FbxNode({
    required this.name,
    this.properties = const [],
    this.children = const [],
  });

  FbxNode? findChild(String childName) {
    for (final c in children) {
      if (c.name.toLowerCase() == childName.toLowerCase()) return c;
    }
    return null;
  }

  List<FbxNode> findChildren(String childName) {
    return children
        .where((c) => c.name.toLowerCase() == childName.toLowerCase())
        .toList();
  }

  FbxNode? findDescendant(String descendantName) {
    final direct = findChild(descendantName);
    if (direct != null) return direct;
    for (final c in children) {
      final found = c.findDescendant(descendantName);
      if (found != null) return found;
    }
    return null;
  }

  List<FbxNode> findAllDescendants(String descendantName) {
    final List<FbxNode> results = [];
    final lower = descendantName.toLowerCase();
    for (final c in children) {
      if (c.name.toLowerCase() == lower) {
        results.add(c);
      }
      results.addAll(c.findAllDescendants(descendantName));
    }
    return results;
  }
}

/// High-performance parser for Autodesk FBX 3D files (both Binary and ASCII).
class FbxParser {
  static const List<int> _binaryHeader = [
    0x4B, 0x61, 0x79, 0x64, 0x61, 0x72, 0x61, 0x20, // "Kaydara "
    0x46, 0x42, 0x58, 0x20, 0x42, 0x69, 0x6E, 0x61, // "FBX Bina"
    0x72, 0x79, 0x20, 0x20, 0x00, 0x1A, 0x00,       // "ry  \0\x1a\0"
  ];

  /// Parse FBX file path in background isolate for smooth UI responsiveness
  static Future<Mesh3D> parseFromFile(String filePath) async {
    return compute(_parseFbxFileCompute, filePath);
  }

  static Mesh3D _parseFbxFileCompute(String filePath) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final name = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, name: name);
  }

  /// Parse FBX from bytes buffer (auto-detects Binary vs ASCII)
  static Mesh3D parseFromBytes(Uint8List bytes, {String name = 'Model.fbx'}) {
    if (_isBinaryFbx(bytes)) {
      return _parseBinaryFbx(bytes, name: name);
    } else {
      return _parseAsciiFbx(bytes, name: name);
    }
  }

  static bool _isBinaryFbx(Uint8List bytes) {
    if (bytes.length < _binaryHeader.length) return false;
    for (int i = 0; i < _binaryHeader.length; i++) {
      if (bytes[i] != _binaryHeader[i]) return false;
    }
    return true;
  }

  // ==========================================
  // BINARY FBX PARSER
  // ==========================================

  static Mesh3D _parseBinaryFbx(Uint8List bytes, {required String name}) {
    if (bytes.length < 27) {
      throw const FormatException('Invalid FBX binary file: buffer too small');
    }

    final byteData = ByteData.sublistView(bytes);
    final version = byteData.getUint32(23, Endian.little);
    final is64Bit = version >= 7500;

    final rootChildren = <FbxNode>[];
    int offset = 27;

    final headerSize = is64Bit ? 25 : 13;

    while (offset + headerSize <= bytes.length) {
      final node = _readBinaryNode(bytes, byteData, offset, is64Bit);
      if (node == null) {
        // Null sentinel record encountered (indicates end of root level nodes)
        break;
      }
      rootChildren.add(node.node);
      if (node.endOffset <= offset) {
        // Prevent infinite loops on corrupted records
        offset += headerSize;
      } else {
        offset = node.endOffset;
      }
    }

    final root = FbxNode(name: 'Root', children: rootChildren);
    return _buildMeshFromFbxTree(root, name: name);
  }

  static _BinaryNodeResult? _readBinaryNode(
    Uint8List bytes,
    ByteData byteData,
    int offset,
    bool is64Bit,
  ) {
    final headerSize = is64Bit ? 25 : 13;
    if (offset + headerSize > bytes.length) return null;

    int endOffset;
    int numProperties;
    int propertyListLen;
    int nameLen;

    if (is64Bit) {
      endOffset = byteData.getUint64(offset, Endian.little);
      numProperties = byteData.getUint64(offset + 8, Endian.little);
      propertyListLen = byteData.getUint64(offset + 16, Endian.little);
      nameLen = byteData.getUint8(offset + 24);
    } else {
      endOffset = byteData.getUint32(offset, Endian.little);
      numProperties = byteData.getUint32(offset + 4, Endian.little);
      propertyListLen = byteData.getUint32(offset + 8, Endian.little);
      nameLen = byteData.getUint8(offset + 12);
    }

    // Check for NULL sentinel record (endOffset == 0 and numProperties == 0)
    if (endOffset == 0 && numProperties == 0 && propertyListLen == 0 && nameLen == 0) {
      return null;
    }

    int cursor = offset + headerSize;
    if (cursor + nameLen > bytes.length) return null;

    final nameBytes = bytes.sublist(cursor, cursor + nameLen);
    final nodeName = utf8.decode(nameBytes, allowMalformed: true);
    cursor += nameLen;

    // Read properties
    final properties = <dynamic>[];
    for (int p = 0; p < numProperties && cursor < bytes.length; p++) {
      final typeCode = String.fromCharCode(bytes[cursor]);
      cursor += 1;

      final propResult = _readBinaryProperty(bytes, byteData, cursor, typeCode);
      properties.add(propResult.value);
      cursor = propResult.nextOffset;
    }

    // Read child nodes if any exist before endOffset
    final children = <FbxNode>[];
    if (cursor < endOffset && endOffset <= bytes.length) {
      while (cursor + headerSize <= endOffset) {
        final childResult = _readBinaryNode(bytes, byteData, cursor, is64Bit);
        if (childResult == null) {
          // Null record sentinel indicates end of children for this node
          cursor += headerSize;
          break;
        }
        children.add(childResult.node);
        if (childResult.endOffset <= cursor) {
          cursor += headerSize;
        } else {
          cursor = childResult.endOffset;
        }
      }
    }

    return _BinaryNodeResult(
      node: FbxNode(name: nodeName, properties: properties, children: children),
      endOffset: endOffset,
    );
  }

  static _BinaryPropertyResult _readBinaryProperty(
    Uint8List bytes,
    ByteData byteData,
    int offset,
    String typeCode,
  ) {
    switch (typeCode) {
      case 'Y': // int16
        final val = byteData.getInt16(offset, Endian.little);
        return _BinaryPropertyResult(value: val, nextOffset: offset + 2);

      case 'C': // bool (1 byte)
        final val = byteData.getUint8(offset) != 0;
        return _BinaryPropertyResult(value: val, nextOffset: offset + 1);

      case 'I': // int32
        final val = byteData.getInt32(offset, Endian.little);
        return _BinaryPropertyResult(value: val, nextOffset: offset + 4);

      case 'F': // float32
        final val = byteData.getFloat32(offset, Endian.little);
        return _BinaryPropertyResult(value: val, nextOffset: offset + 4);

      case 'D': // float64 (double)
        final val = byteData.getFloat64(offset, Endian.little);
        return _BinaryPropertyResult(value: val, nextOffset: offset + 8);

      case 'L': // int64
        final val = byteData.getInt64(offset, Endian.little);
        return _BinaryPropertyResult(value: val, nextOffset: offset + 8);

      case 'S': // String (uint32 length + utf-8 bytes)
        final strLen = byteData.getUint32(offset, Endian.little);
        final start = offset + 4;
        final end = math.min(start + strLen, bytes.length);
        final str = utf8.decode(bytes.sublist(start, end), allowMalformed: true);
        return _BinaryPropertyResult(value: str, nextOffset: start + strLen);

      case 'R': // Raw binary buffer (uint32 length + raw bytes)
        final rawLen = byteData.getUint32(offset, Endian.little);
        final start = offset + 4;
        final end = math.min(start + rawLen, bytes.length);
        final raw = bytes.sublist(start, end);
        return _BinaryPropertyResult(value: raw, nextOffset: start + rawLen);

      // Array Types: 'f', 'd', 'l', 'i', 'b'
      case 'f':
      case 'd':
      case 'l':
      case 'i':
      case 'b':
        final arrayLength = byteData.getUint32(offset, Endian.little);
        final encoding = byteData.getUint32(offset + 4, Endian.little);
        final compressedLength = byteData.getUint32(offset + 8, Endian.little);

        final dataStart = offset + 12;
        final nextOffset = dataStart + compressedLength;

        Uint8List arrayBytes;
        if (encoding == 1) {
          // Compressed using zlib / deflate
          final compressedData = bytes.sublist(dataStart, math.min(nextOffset, bytes.length));
          try {
            arrayBytes = Uint8List.fromList(zlib.decode(compressedData));
          } catch (_) {
            try {
              arrayBytes = Uint8List.fromList(ZLibDecoder().decodeBytes(compressedData));
            } catch (_) {
              arrayBytes = Uint8List.fromList(ZLibDecoder().decodeBytes(compressedData, verify: false));
            }
          }
        } else {
          // Uncompressed raw bytes
          final dataEnd = math.min(dataStart + compressedLength, bytes.length);
          arrayBytes = bytes.sublist(dataStart, dataEnd);
        }

        final arrayData = ByteData.sublistView(arrayBytes);
        final dynamic parsedArray;

        switch (typeCode) {
          case 'f':
            final list = Float32List(arrayLength);
            for (int i = 0; i < arrayLength && (i * 4 + 4) <= arrayBytes.length; i++) {
              list[i] = arrayData.getFloat32(i * 4, Endian.little);
            }
            parsedArray = list;
            break;
          case 'd':
            final list = Float64List(arrayLength);
            for (int i = 0; i < arrayLength && (i * 8 + 8) <= arrayBytes.length; i++) {
              list[i] = arrayData.getFloat64(i * 8, Endian.little);
            }
            parsedArray = list;
            break;
          case 'i':
            final list = Int32List(arrayLength);
            for (int i = 0; i < arrayLength && (i * 4 + 4) <= arrayBytes.length; i++) {
              list[i] = arrayData.getInt32(i * 4, Endian.little);
            }
            parsedArray = list;
            break;
          case 'l':
            final list = Int64List(arrayLength);
            for (int i = 0; i < arrayLength && (i * 8 + 8) <= arrayBytes.length; i++) {
              list[i] = arrayData.getInt64(i * 8, Endian.little);
            }
            parsedArray = list;
            break;
          case 'b':
            final list = Uint8List(arrayLength);
            for (int i = 0; i < arrayLength && i < arrayBytes.length; i++) {
              list[i] = arrayBytes[i];
            }
            parsedArray = list;
            break;
          default:
            parsedArray = arrayBytes;
        }

        return _BinaryPropertyResult(value: parsedArray, nextOffset: nextOffset);

      default:
        // Unknown property type; advance safely
        return _BinaryPropertyResult(value: null, nextOffset: offset);
    }
  }

  // ==========================================
  // FBX TREE TO MESH3D CONVERTER
  // ==========================================

  static String _cleanFbxName(String raw) {
    var s = raw;
    if (s.contains('::')) {
      s = s.split('::').last;
    }
    // Remove trailing " Material", " Geometry", " Model"
    s = s.replaceAll(RegExp(r'\s+(Material|Geometry|Model)$', caseSensitive: false), '');
    return s.trim();
  }

  static Mesh3D _buildMeshFromFbxTree(FbxNode root, {required String name}) {
    // 1. Detect coordinate system (UpAxis)
    // UpAxis: 0 = X, 1 = Y, 2 = Z. Default in FBX / Maya is often 1 (Y-up).
    int upAxis = 1;
    final globalSettings = root.findDescendant('GlobalSettings');
    if (globalSettings != null) {
      final props = globalSettings.findChild('Properties70');
      if (props != null) {
        for (final pNode in props.findChildren('P')) {
          if (pNode.properties.isNotEmpty && pNode.properties[0] == 'UpAxis') {
            if (pNode.properties.length >= 5 && pNode.properties[4] is num) {
              upAxis = (pNode.properties[4] as num).toInt();
            }
          }
        }
      }
    }

    final objectsNode = root.findChild('Objects') ?? root;

    // 2. Parse Materials
    final Map<dynamic, Color> materialColorsById = {};
    final Map<String, Color> materialColorsByName = {};

    for (final child in objectsNode.children) {
      if (child.name.toLowerCase() == 'material') {
        dynamic matId;
        String? matName;
        if (child.properties.isNotEmpty) {
          matId = child.properties[0];
          if (child.properties.length > 1) {
            matName = child.properties[1].toString();
          }
        }

        Color? matColor;
        final props70 = child.findChild('Properties70');
        if (props70 != null) {
          double? r, g, b, alpha;
          for (final p in props70.findChildren('P')) {
            if (p.properties.isEmpty) continue;
            final propName = p.properties[0].toString();
            if ((propName == 'DiffuseColor' || propName == 'Diffuse') && p.properties.length >= 7) {
              final pr = (p.properties[4] as num?)?.toDouble();
              final pg = (p.properties[5] as num?)?.toDouble();
              final pb = (p.properties[6] as num?)?.toDouble();
              if (pr != null && pg != null && pb != null) {
                r = pr;
                g = pg;
                b = pb;
              }
            } else if (propName == 'Color' && p.properties.length >= 7) {
              r ??= (p.properties[4] as num?)?.toDouble();
              g ??= (p.properties[5] as num?)?.toDouble();
              b ??= (p.properties[6] as num?)?.toDouble();
            } else if ((propName == 'Opacity' || propName == 'TransparencyFactor') && p.properties.length >= 5) {
              final val = (p.properties[4] as num?)?.toDouble();
              if (val != null) {
                if (propName == 'TransparencyFactor') {
                  alpha = (1.0 - val).clamp(0.0, 1.0);
                } else {
                  alpha = val.clamp(0.0, 1.0);
                }
              }
            }
          }

          if (r != null && g != null && b != null) {
            matColor = Color.from(
              alpha: alpha ?? 1.0,
              red: r.clamp(0.0, 1.0),
              green: g.clamp(0.0, 1.0),
              blue: b.clamp(0.0, 1.0),
            );
          }
        }

        if (matColor != null) {
          if (matId != null) {
            materialColorsById[matId] = matColor;
          }
          if (matName != null && matName.isNotEmpty) {
            final clean = _cleanFbxName(matName).toLowerCase();
            materialColorsByName[clean] = matColor;
          }
        }
      }
    }

    // 3. Parse Connections
    final Map<dynamic, List<dynamic>> parentToChildren = {};
    final Map<dynamic, List<dynamic>> childToParents = {};
    final connNode = root.findChild('Connections');
    if (connNode != null) {
      for (final c in connNode.findChildren('C')) {
        if (c.properties.length >= 3) {
          final childId = c.properties[1];
          final parentId = c.properties[2];
          parentToChildren.putIfAbsent(parentId, () => []).add(childId);
          childToParents.putIfAbsent(childId, () => []).add(parentId);
        }
      }
    }

    // 4. Find all Geometry nodes (Mesh type)
    final List<FbxNode> geomNodes = [];

    for (final child in objectsNode.children) {
      if (child.name.toLowerCase() == 'geometry') {
        geomNodes.add(child);
      } else if (child.findChild('Vertices') != null &&
          child.findChild('PolygonVertexIndex') != null) {
        geomNodes.add(child);
      }
    }

    if (geomNodes.isEmpty) {
      // Fallback search across all descendants
      final anyGeom = root.findAllDescendants('Geometry');
      if (anyGeom.isNotEmpty) {
        geomNodes.addAll(anyGeom);
      } else {
        // Search for any node having Vertices and PolygonVertexIndex
        if (root.findAllDescendants('Vertices').isNotEmpty &&
            root.findAllDescendants('PolygonVertexIndex').isNotEmpty) {
          geomNodes.add(root);
        }
      }
    }

    final List<Triangle3D> allTriangles = [];

    for (final geom in geomNodes) {
      final verticesNode = geom.findChild('Vertices');
      final polyIndexNode = geom.findChild('PolygonVertexIndex');

      if (verticesNode == null || polyIndexNode == null) continue;
      if (verticesNode.properties.isEmpty || polyIndexNode.properties.isEmpty) continue;

      final rawVertices = verticesNode.properties[0];
      final rawIndices = polyIndexNode.properties[0];

      if (rawVertices is! List || rawIndices is! List) continue;

      // Extract raw 3D vertices
      final List<Vector3> vertices = [];
      for (int i = 0; i + 2 < rawVertices.length; i += 3) {
        final double x = (rawVertices[i] as num).toDouble();
        final double y = (rawVertices[i + 1] as num).toDouble();
        final double z = (rawVertices[i + 2] as num).toDouble();

        if (upAxis == 1) {
          // Convert Y-up to Z-up: (x, y, z) -> (x, -z, y)
          // Preserves positive determinant (handedness)
          vertices.add(Vector3(x, -z, y));
        } else {
          // Z-up or standard
          vertices.add(Vector3(x, y, z));
        }
      }

      if (vertices.isEmpty) continue;

      // Resolve Geometry Color via Material Connections or Name Matching
      dynamic geomId;
      String? geomName;
      if (geom.properties.isNotEmpty) {
        geomId = geom.properties[0];
        if (geom.properties.length > 1) {
          geomName = geom.properties[1].toString();
        }
      }

      Color? geomColor;
      if (geomId != null) {
        final parentModels = childToParents[geomId] ?? [];
        for (final pModel in parentModels) {
          final siblings = parentToChildren[pModel] ?? [];
          for (final sib in siblings) {
            if (materialColorsById.containsKey(sib)) {
              geomColor = materialColorsById[sib];
              break;
            }
          }
          if (geomColor != null) break;
        }

        geomColor ??= materialColorsById[geomId];
        if (geomColor == null) {
          for (final p in (childToParents[geomId] ?? [])) {
            if (materialColorsById.containsKey(p)) {
              geomColor = materialColorsById[p];
              break;
            }
          }
        }
        if (geomColor == null) {
          for (final ch in (parentToChildren[geomId] ?? [])) {
            if (materialColorsById.containsKey(ch)) {
              geomColor = materialColorsById[ch];
              break;
            }
          }
        }
      }

      if (geomColor == null && geomName != null && geomName.isNotEmpty) {
        final clean = _cleanFbxName(geomName).toLowerCase();
        geomColor = materialColorsByName[clean];
        if (geomColor == null) {
          for (final entry in materialColorsByName.entries) {
            if (clean.contains(entry.key) || entry.key.contains(clean)) {
              geomColor = entry.value;
              break;
            }
          }
        }
      }

      // Optional Normals
      List<Vector3>? normals;
      String? normalMapping;
      final normalElem = geom.findChild('LayerElementNormal');
      if (normalElem != null) {
        final normalsNode = normalElem.findChild('Normals');
        final mappingNode = normalElem.findChild('MappingInformationType');
        final refNode = normalElem.findChild('ReferenceInformationType');
        final normalIndicesNode = normalElem.findChild('NormalsIndex') ?? normalElem.findChild('NormalIndex');

        if (mappingNode != null && mappingNode.properties.isNotEmpty) {
          normalMapping = mappingNode.properties[0].toString();
        }
        if (normalsNode != null && normalsNode.properties.isNotEmpty) {
          final rawNormals = normalsNode.properties[0];
          if (rawNormals is List) {
            final parsedNormals = <Vector3>[];
            for (int i = 0; i + 2 < rawNormals.length; i += 3) {
              final nx = (rawNormals[i] as num).toDouble();
              final ny = (rawNormals[i + 1] as num).toDouble();
              final nz = (rawNormals[i + 2] as num).toDouble();
              if (upAxis == 1) {
                parsedNormals.add(Vector3(nx, -nz, ny).normalized());
              } else {
                parsedNormals.add(Vector3(nx, ny, nz).normalized());
              }
            }

            final isIndexToDirect = refNode != null &&
                refNode.properties.isNotEmpty &&
                refNode.properties[0].toString().toLowerCase() == 'indextodirect';

            if (isIndexToDirect && normalIndicesNode != null && normalIndicesNode.properties.isNotEmpty) {
              final rawNormIndices = normalIndicesNode.properties[0];
              if (rawNormIndices is List) {
                normals = [];
                for (int i = 0; i < rawNormIndices.length; i++) {
                  final idx = (rawNormIndices[i] as num).toInt();
                  if (idx >= 0 && idx < parsedNormals.length) {
                    normals.add(parsedNormals[idx]);
                  } else {
                    normals.add(Vector3.zero);
                  }
                }
              } else {
                normals = parsedNormals;
              }
            } else {
              normals = parsedNormals;
            }
          }
        }
      }

      // Triangulate polygons from PolygonVertexIndex
      // In FBX, polygons are sequences of indices where the final vertex of each polygon is:
      // index = -index - 1 (bitwise NOT ~index)
      final List<int> polyIndices = [];

      for (int i = 0; i < rawIndices.length; i++) {
        final rawVal = (rawIndices[i] as num).toInt();
        final bool isLast = rawVal < 0;
        final int actualIndex = isLast ? (-rawVal - 1) : rawVal;

        polyIndices.add(actualIndex);

        if (isLast) {
          // Polygon complete! Triangulate n-gon via fan triangulation
          if (polyIndices.length >= 3) {
            final baseIdx = i - polyIndices.length + 1;
            for (int t = 1; t < polyIndices.length - 1; t++) {
              final i0 = polyIndices[0];
              final i1 = polyIndices[t];
              final i2 = polyIndices[t + 1];

              if (i0 < vertices.length && i1 < vertices.length && i2 < vertices.length) {
                final v0 = vertices[i0];
                final v1 = vertices[i1];
                final v2 = vertices[i2];

                Vector3? normal;
                if (normals != null && normals.isNotEmpty) {
                  if (normalMapping == 'ByPolygonVertex') {
                    final n0 = baseIdx;
                    final n1 = baseIdx + t;
                    final n2 = baseIdx + t + 1;
                    if (n0 < normals.length && n1 < normals.length && n2 < normals.length) {
                      final sum = normals[n0] + normals[n1] + normals[n2];
                      normal = sum.lengthSquared > 1e-6 ? sum.normalized() : normals[n0];
                    } else if (n1 < normals.length) {
                      normal = normals[n1];
                    }
                  } else if (normalMapping == 'ByVertex' || normalMapping == 'ByControlPoint') {
                    if (i0 < normals.length && i1 < normals.length && i2 < normals.length) {
                      final sum = normals[i0] + normals[i1] + normals[i2];
                      normal = sum.lengthSquared > 1e-6 ? sum.normalized() : normals[i0];
                    } else if (i0 < normals.length) {
                      normal = normals[i0];
                    }
                  }
                }

                allTriangles.add(Triangle3D(
                  v0: v0,
                  v1: v1,
                  v2: v2,
                  normal: normal,
                  color: geomColor,
                ));
              }
            }
          }
          polyIndices.clear();
        }
      }
    }

    if (allTriangles.isEmpty) {
      throw const FormatException('No 3D mesh geometry found in FBX file.');
    }

    return Mesh3D(name: name, triangles: allTriangles);
  }

  // ==========================================
  // ASCII FBX PARSER
  // ==========================================

  static Mesh3D _parseAsciiFbx(Uint8List bytes, {required String name}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final List<Triangle3D> allTriangles = [];

    // UpAxis detection in ASCII
    int upAxis = 1;
    final upAxisMatch = RegExp(r'P:\s*"UpAxis",\s*"int",\s*"Integer",\s*"",\s*([0-2])', caseSensitive: false)
        .firstMatch(text);
    if (upAxisMatch != null) {
      upAxis = int.tryParse(upAxisMatch.group(1) ?? '1') ?? 1;
    }

    // Extract all pairs of Vertices and PolygonVertexIndex in the ASCII text
    final verticesRegex = RegExp(
      r'Vertices:\s*(?:\*\d+\s*\{\s*a:\s*)?([0-9\.\,\-\s\+eE]+)(?:\s*\})?',
      multiLine: true,
    );
    final polyIndexRegex = RegExp(
      r'PolygonVertexIndex:\s*(?:\*\d+\s*\{\s*a:\s*)?([0-9\.\,\-\s\+eE]+)(?:\s*\})?',
      multiLine: true,
    );

    final vertMatches = verticesRegex.allMatches(text).toList();
    final polyMatches = polyIndexRegex.allMatches(text).toList();

    final count = math.min(vertMatches.length, polyMatches.length);

    for (int m = 0; m < count; m++) {
      final vertStr = vertMatches[m].group(1) ?? '';
      final polyStr = polyMatches[m].group(1) ?? '';

      // Parse vertices
      final rawVertices = _parseNumberList(vertStr);
      final List<Vector3> vertices = [];
      for (int i = 0; i + 2 < rawVertices.length; i += 3) {
        final x = rawVertices[i];
        final y = rawVertices[i + 1];
        final z = rawVertices[i + 2];
        if (upAxis == 1) {
          vertices.add(Vector3(x, -z, y));
        } else {
          vertices.add(Vector3(x, y, z));
        }
      }

      if (vertices.isEmpty) continue;

      // Parse polygon indices
      final rawIndices = _parseIntList(polyStr);
      final List<int> polyIndices = [];

      for (int i = 0; i < rawIndices.length; i++) {
        final rawVal = rawIndices[i];
        final bool isLast = rawVal < 0;
        final int actualIndex = isLast ? (-rawVal - 1) : rawVal;

        polyIndices.add(actualIndex);

        if (isLast) {
          if (polyIndices.length >= 3) {
            for (int t = 1; t < polyIndices.length - 1; t++) {
              final i0 = polyIndices[0];
              final i1 = polyIndices[t];
              final i2 = polyIndices[t + 1];

              if (i0 < vertices.length && i1 < vertices.length && i2 < vertices.length) {
                allTriangles.add(Triangle3D(
                  v0: vertices[i0],
                  v1: vertices[i1],
                  v2: vertices[i2],
                ));
              }
            }
          }
          polyIndices.clear();
        }
      }
    }

    if (allTriangles.isEmpty) {
      throw const FormatException('No 3D mesh geometry found in ASCII FBX file.');
    }

    return Mesh3D(name: name, triangles: allTriangles);
  }

  static List<double> _parseNumberList(String str) {
    final List<double> result = [];
    final matches = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?').allMatches(str);
    for (final m in matches) {
      final v = double.tryParse(m.group(0)!);
      if (v != null) result.add(v);
    }
    return result;
  }

  static List<int> _parseIntList(String str) {
    final List<int> result = [];
    final matches = RegExp(r'[-+]?[0-9]+').allMatches(str);
    for (final m in matches) {
      final v = int.tryParse(m.group(0)!);
      if (v != null) result.add(v);
    }
    return result;
  }
}

class _BinaryNodeResult {
  final FbxNode node;
  final int endOffset;

  _BinaryNodeResult({required this.node, required this.endOffset});
}

class _BinaryPropertyResult {
  final dynamic value;
  final int nextOffset;

  _BinaryPropertyResult({required this.value, required this.nextOffset});
}
