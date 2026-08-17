import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/mesh_3d.dart';

/// High-performance parser for both Binary and ASCII STL files.
class StlParser {
  /// Parse STL from file path
  static Future<Mesh3D> parseFromFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final name = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, name: name);
  }

  /// Parse STL from bytes buffer
  static Mesh3D parseFromBytes(Uint8List bytes, {String name = 'Model.stl'}) {
    if (_isBinaryStl(bytes)) {
      return _parseBinaryStl(bytes, name: name);
    } else {
      return _parseAsciiStl(bytes, name: name);
    }
  }

  static bool _isBinaryStl(Uint8List bytes) {
    if (bytes.length < 84) return false;
    final byteData = ByteData.sublistView(bytes);
    final numTriangles = byteData.getUint32(80, Endian.little);
    final expectedSize = 84 + numTriangles * 50;
    // If the file size exactly matches the binary STL formula, it's binary
    if (bytes.length == expectedSize) return true;

    // Check if the beginning contains "solid"
    final headerStr = utf8.decode(bytes.sublist(0, 80), allowMalformed: true).toLowerCase();
    if (!headerStr.startsWith('solid')) {
      return true;
    }

    // Double check if file contains non-ASCII binary bytes
    for (int i = 0; i < math_min(bytes.length, 512); i++) {
      final b = bytes[i];
      if (b == 0 || (b < 32 && b != 9 && b != 10 && b != 13)) {
        return true;
      }
    }

    return false;
  }

  static int math_min(int a, int b) => a < b ? a : b;

  static Mesh3D _parseBinaryStl(Uint8List bytes, {required String name}) {
    final byteData = ByteData.sublistView(bytes);
    final numTriangles = byteData.getUint32(80, Endian.little);
    final List<Triangle3D> triangles = [];

    int offset = 84;
    for (int i = 0; i < numTriangles && offset + 50 <= bytes.length; i++) {
      final nx = byteData.getFloat32(offset, Endian.little);
      final ny = byteData.getFloat32(offset + 4, Endian.little);
      final nz = byteData.getFloat32(offset + 8, Endian.little);

      final v0x = byteData.getFloat32(offset + 12, Endian.little);
      final v0y = byteData.getFloat32(offset + 16, Endian.little);
      final v0z = byteData.getFloat32(offset + 20, Endian.little);

      final v1x = byteData.getFloat32(offset + 24, Endian.little);
      final v1y = byteData.getFloat32(offset + 28, Endian.little);
      final v1z = byteData.getFloat32(offset + 32, Endian.little);

      final v2x = byteData.getFloat32(offset + 36, Endian.little);
      final v2y = byteData.getFloat32(offset + 40, Endian.little);
      final v2z = byteData.getFloat32(offset + 44, Endian.little);

      final normal = Vector3(nx, ny, nz);
      final v0 = Vector3(v0x, v0y, v0z);
      final v1 = Vector3(v1x, v1y, v1z);
      final v2 = Vector3(v2x, v2y, v2z);

      triangles.add(Triangle3D(
        v0: v0,
        v1: v1,
        v2: v2,
        normal: normal.lengthSquared > 1e-6 ? normal : null,
      ));

      offset += 50; // 50 bytes per triangle
    }

    return Mesh3D(name: name, triangles: triangles);
  }

  static Mesh3D _parseAsciiStl(Uint8List bytes, {required String name}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = text.split(RegExp(r'\r?\n'));

    final List<Triangle3D> triangles = [];
    Vector3? currentNormal;
    final List<Vector3> currentVertices = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('facet normal')) {
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final nx = double.tryParse(parts[2]) ?? 0;
          final ny = double.tryParse(parts[3]) ?? 0;
          final nz = double.tryParse(parts[4]) ?? 0;
          currentNormal = Vector3(nx, ny, nz);
        }
        currentVertices.clear();
      } else if (trimmed.startsWith('vertex')) {
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final x = double.tryParse(parts[1]) ?? 0;
          final y = double.tryParse(parts[2]) ?? 0;
          final z = double.tryParse(parts[3]) ?? 0;
          currentVertices.add(Vector3(x, y, z));
        }
      } else if (trimmed.startsWith('endfacet')) {
        if (currentVertices.length == 3) {
          triangles.add(Triangle3D(
            v0: currentVertices[0],
            v1: currentVertices[1],
            v2: currentVertices[2],
            normal: currentNormal,
          ));
        }
        currentVertices.clear();
        currentNormal = null;
      }
    }

    return Mesh3D(name: name, triangles: triangles);
  }
}
