import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/mesh_3d.dart';

/// High-performance parser for GLB (Binary glTF) and GLTF 3D assets.
class GlbGltfParser {
  static Future<Mesh3D> parseFromFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final name = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, name: name);
  }

  static Mesh3D parseFromBytes(Uint8List bytes, {String name = 'Model.glb'}) {
    if (bytes.length >= 12 &&
        bytes[0] == 0x67 &&
        bytes[1] == 0x6C &&
        bytes[2] == 0x54 &&
        bytes[3] == 0x46) {
      // Magic "glTF"
      return _parseGlb(bytes, name: name);
    } else {
      // JSON glTF
      return _parseGltf(bytes, name: name);
    }
  }

  static Mesh3D _parseGlb(Uint8List bytes, {required String name}) {
    final byteData = ByteData.sublistView(bytes);

    // Header: magic (4), version (4), length (4)
    // Chunk 0: JSON
    final jsonChunkLength = byteData.getUint32(12, Endian.little);
    final jsonBytes = bytes.sublist(20, 20 + jsonChunkLength);
    final jsonStr = utf8.decode(jsonBytes);
    final Map<String, dynamic> gltf = json.decode(jsonStr) as Map<String, dynamic>;

    // Chunk 1: BIN buffer (if present)
    Uint8List? binBuffer;
    int offset = 20 + jsonChunkLength;
    if (offset + 8 <= bytes.length) {
      final binChunkLength = byteData.getUint32(offset, Endian.little);
      final binOffset = offset + 8;
      if (binOffset + binChunkLength <= bytes.length) {
        binBuffer = bytes.sublist(binOffset, binOffset + binChunkLength);
      } else {
        binBuffer = bytes.sublist(binOffset);
      }
    }

    return _buildMeshFromGltfJson(gltf, [binBuffer ?? Uint8List(0)], name: name);
  }

  static Mesh3D _parseGltf(Uint8List bytes, {required String name}) {
    final jsonStr = utf8.decode(bytes, allowMalformed: true);
    final Map<String, dynamic> gltf = json.decode(jsonStr) as Map<String, dynamic>;

    // Extract buffers (embedded base64 data URIs)
    final List<Uint8List> buffers = [];
    if (gltf['buffers'] is List) {
      for (final buf in gltf['buffers'] as List) {
        if (buf is Map && buf['uri'] is String) {
          final uri = buf['uri'] as String;
          if (uri.startsWith('data:')) {
            final base64Str = uri.split(',').last;
            buffers.add(base64.decode(base64Str));
          } else {
            buffers.add(Uint8List(0));
          }
        } else {
          buffers.add(Uint8List(0));
        }
      }
    }

    return _buildMeshFromGltfJson(gltf, buffers, name: name);
  }

  static Mesh3D _buildMeshFromGltfJson(
    Map<String, dynamic> gltf,
    List<Uint8List> buffers, {
    required String name,
  }) {
    final accessors = (gltf['accessors'] as List?) ?? [];
    final bufferViews = (gltf['bufferViews'] as List?) ?? [];
    final meshes = (gltf['meshes'] as List?) ?? [];

    final List<Triangle3D> triangles = [];

    for (final meshObj in meshes) {
      if (meshObj is! Map) continue;
      final primitives = (meshObj['primitives'] as List?) ?? [];

      for (final prim in primitives) {
        if (prim is! Map) continue;
        final attributes = (prim['attributes'] as Map?) ?? {};
        final posAccessorIdx = attributes['POSITION'] as int?;
        final normAccessorIdx = attributes['NORMAL'] as int?;
        final indicesAccessorIdx = prim['indices'] as int?;

        if (posAccessorIdx == null || posAccessorIdx >= accessors.length) continue;

        // Read Positions
        final posList = _readVector3List(accessors[posAccessorIdx], bufferViews, buffers);
        final normList = normAccessorIdx != null && normAccessorIdx < accessors.length
            ? _readVector3List(accessors[normAccessorIdx], bufferViews, buffers)
            : <Vector3>[];

        if (indicesAccessorIdx != null && indicesAccessorIdx < accessors.length) {
          // Indexed Triangles
          final indices = _readIndexList(accessors[indicesAccessorIdx], bufferViews, buffers);
          for (int i = 0; i + 2 < indices.length; i += 3) {
            final i0 = indices[i];
            final i1 = indices[i + 1];
            final i2 = indices[i + 2];

            if (i0 < posList.length && i1 < posList.length && i2 < posList.length) {
              final v0 = posList[i0];
              final v1 = posList[i1];
              final v2 = posList[i2];
              final norm = i0 < normList.length ? normList[i0] : null;

              triangles.add(Triangle3D(v0: v0, v1: v1, v2: v2, normal: norm));
            }
          }
        } else {
          // Direct Triangles
          for (int i = 0; i + 2 < posList.length; i += 3) {
            final v0 = posList[i];
            final v1 = posList[i + 1];
            final v2 = posList[i + 2];
            final norm = i < normList.length ? normList[i] : null;

            triangles.add(Triangle3D(v0: v0, v1: v1, v2: v2, normal: norm));
          }
        }
      }
    }

    return Mesh3D(name: name, triangles: triangles);
  }

  static List<Vector3> _readVector3List(
    dynamic accessorObj,
    List<dynamic> bufferViews,
    List<Uint8List> buffers,
  ) {
    if (accessorObj is! Map) return [];
    final bufferViewIdx = accessorObj['bufferView'] as int?;
    final count = (accessorObj['count'] as int?) ?? 0;
    final accByteOffset = (accessorObj['byteOffset'] as int?) ?? 0;

    if (bufferViewIdx == null || bufferViewIdx >= bufferViews.length) return [];
    final bv = bufferViews[bufferViewIdx];
    if (bv is! Map) return [];

    final bufferIdx = (bv['buffer'] as int?) ?? 0;
    final bvByteOffset = (bv['byteOffset'] as int?) ?? 0;
    final byteStride = (bv['byteStride'] as int?) ?? 12; // 3 * float32

    if (bufferIdx >= buffers.length) return [];
    final buffer = buffers[bufferIdx];
    final byteData = ByteData.sublistView(buffer);

    final List<Vector3> result = [];
    int currentOffset = bvByteOffset + accByteOffset;

    for (int i = 0; i < count; i++) {
      if (currentOffset + 12 <= buffer.length) {
        final x = byteData.getFloat32(currentOffset, Endian.little);
        final y = byteData.getFloat32(currentOffset + 4, Endian.little);
        final z = byteData.getFloat32(currentOffset + 8, Endian.little);
        result.add(Vector3(x, y, z));
      }
      currentOffset += byteStride;
    }

    return result;
  }

  static List<int> _readIndexList(
    dynamic accessorObj,
    List<dynamic> bufferViews,
    List<Uint8List> buffers,
  ) {
    if (accessorObj is! Map) return [];
    final bufferViewIdx = accessorObj['bufferView'] as int?;
    final count = (accessorObj['count'] as int?) ?? 0;
    final componentType = (accessorObj['componentType'] as int?) ?? 5123; // default uint16
    final accByteOffset = (accessorObj['byteOffset'] as int?) ?? 0;

    if (bufferViewIdx == null || bufferViewIdx >= bufferViews.length) return [];
    final bv = bufferViews[bufferViewIdx];
    if (bv is! Map) return [];

    final bufferIdx = (bv['buffer'] as int?) ?? 0;
    final bvByteOffset = (bv['byteOffset'] as int?) ?? 0;

    if (bufferIdx >= buffers.length) return [];
    final buffer = buffers[bufferIdx];
    final byteData = ByteData.sublistView(buffer);

    final List<int> indices = [];
    int offset = bvByteOffset + accByteOffset;

    for (int i = 0; i < count; i++) {
      if (componentType == 5123) {
        // UNSIGNED_SHORT (16-bit)
        if (offset + 2 <= buffer.length) {
          indices.add(byteData.getUint16(offset, Endian.little));
          offset += 2;
        }
      } else if (componentType == 5125) {
        // UNSIGNED_INT (32-bit)
        if (offset + 4 <= buffer.length) {
          indices.add(byteData.getUint32(offset, Endian.little));
          offset += 4;
        }
      } else if (componentType == 5121) {
        // UNSIGNED_BYTE (8-bit)
        if (offset + 1 <= buffer.length) {
          indices.add(byteData.getUint8(offset));
          offset += 1;
        }
      }
    }

    return indices;
  }
}
