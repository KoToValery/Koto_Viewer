import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/mesh_3d.dart';

/// Parser for Wavefront OBJ 3D files.
class ObjParser {
  static Future<Mesh3D> parseFromFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final name = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, name: name);
  }

  static Mesh3D parseFromBytes(Uint8List bytes, {String name = 'Model.obj'}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = text.split(RegExp(r'\r?\n'));

    final List<Vector3> vertices = [];
    final List<Vector3> normals = [];
    final List<Triangle3D> triangles = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (trimmed.startsWith('v ')) {
        // Vertex: v x y z
        final parts = trimmed.substring(2).trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final x = double.tryParse(parts[0]) ?? 0;
          final y = double.tryParse(parts[1]) ?? 0;
          final z = double.tryParse(parts[2]) ?? 0;
          vertices.add(Vector3(x, y, z));
        }
      } else if (trimmed.startsWith('vn ')) {
        // Normal: vn nx ny nz
        final parts = trimmed.substring(3).trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final nx = double.tryParse(parts[0]) ?? 0;
          final ny = double.tryParse(parts[1]) ?? 0;
          final nz = double.tryParse(parts[2]) ?? 0;
          normals.add(Vector3(nx, ny, nz).normalized());
        }
      } else if (trimmed.startsWith('f ')) {
        // Face: f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3 ...
        final parts = trimmed.substring(2).trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final List<int> vIndices = [];
          final List<int?> nIndices = [];

          for (final part in parts) {
            final sub = part.split('/');
            if (sub.isNotEmpty && sub[0].isNotEmpty) {
              int vIdx = int.tryParse(sub[0]) ?? 0;
              // 1-based indexing & negative indexing support
              if (vIdx > 0) {
                vIdx = vIdx - 1;
              } else if (vIdx < 0) {
                vIdx = vertices.length + vIdx;
              }
              vIndices.add(vIdx);

              int? nIdx;
              if (sub.length >= 3 && sub[2].isNotEmpty) {
                final rawN = int.tryParse(sub[2]) ?? 0;
                if (rawN > 0) {
                  nIdx = rawN - 1;
                } else if (rawN < 0) {
                  nIdx = normals.length + rawN;
                }
              }
              nIndices.add(nIdx);
            }
          }

          // Fan triangulation for polygons with >= 3 vertices
          if (vIndices.length >= 3) {
            for (int i = 1; i < vIndices.length - 1; i++) {
              final i0 = vIndices[0];
              final i1 = vIndices[i];
              final i2 = vIndices[i + 1];

              if (i0 >= 0 && i0 < vertices.length &&
                  i1 >= 0 && i1 < vertices.length &&
                  i2 >= 0 && i2 < vertices.length) {
                final v0 = vertices[i0];
                final v1 = vertices[i1];
                final v2 = vertices[i2];

                Vector3? faceNormal;
                final n0 = nIndices[0];
                if (n0 != null && n0 >= 0 && n0 < normals.length) {
                  faceNormal = normals[n0];
                }

                triangles.add(Triangle3D(
                  v0: v0,
                  v1: v1,
                  v2: v2,
                  normal: faceNormal,
                ));
              }
            }
          }
        }
      }
    }

    return Mesh3D(name: name, triangles: triangles);
  }
}
