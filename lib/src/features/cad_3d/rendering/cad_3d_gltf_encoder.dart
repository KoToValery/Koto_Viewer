import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/mesh_3d.dart';

/// Builds a self-contained glTF render asset for Filament's material loader.
/// The CAD mesh remains in model units; only the uploaded copy is centered and
/// normalized to the same 20-unit extent as the procedural GPU path.
class Cad3DGltfEncoder {
  static Uint8List encode(
    Mesh3D mesh, {
    bool flatShaded = false,
    Color defaultColor = const Color(0xffffffff),
  }) => _Encoder(mesh, flatShaded, defaultColor).encode();
}

class _Encoder {
  final Mesh3D mesh;
  final bool flatShaded;
  final Color defaultColor;
  final binary = BytesBuilder(copy: false);
  final views = <Map<String, dynamic>>[];
  final accessors = <Map<String, dynamic>>[];
  final materials = <Map<String, dynamic>>[];
  final images = <Map<String, dynamic>>[];
  final textures = <Map<String, dynamic>>[];
  final samplers = <Map<String, dynamic>>[];
  final textureIndices = Map<MeshTexture, int>.identity();
  final extensions = <String>{};

  _Encoder(this.mesh, this.flatShaded, this.defaultColor);

  Uint8List encode() {
    final batches = <(MeshMaterial?, bool, bool), List<Triangle3D>>{};
    for (final t in mesh.triangles) {
      if (t.area < 1e-16) continue;
      final key = (
        t.material,
        t.isDoubleSided,
        t.material == null && (t.color?.a ?? 1) < .999,
      );
      (batches[key] ??= []).add(t);
    }
    final primitives = <Map<String, dynamic>>[];
    final center = mesh.bounds.center;
    final scale = 20 / math.max(mesh.bounds.maxDimension, 1e-4);
    for (final batch in batches.entries) {
      final source = batch.key.$1;
      final materialIndex = materials.length;
      materials.add(_material(source, batch.key.$2, batch.key.$3));
      final faces = batch.value;
      for (var start = 0; start < faces.length; start += 20000) {
        final end = math.min(start + 20000, faces.length);
        final count = (end - start) * 3;
        final positions = Float32List(count * 3);
        final normals = Float32List(count * 3);
        final colors = Float32List(count * 4);
        final sets = <int>{};
        for (var i = start; i < end; i++) {
          sets.addAll(faces[i].textureCoordinates.keys);
        }
        final uvs = {for (final set in sets) set: Float32List(count * 2)};
        final min = List<double>.filled(3, double.infinity);
        final max = List<double>.filled(3, double.negativeInfinity);
        var vertex = 0;
        for (var i = start; i < end; i++) {
          final t = faces[i];
          final points = [t.v0, t.v1, t.v2];
          final faceNormal = (t.v1 - t.v0).cross(t.v2 - t.v0).normalized();
          for (var k = 0; k < 3; k++, vertex++) {
            final p = (points[k] - center) * scale;
            final authoredNormal = t.vertexNormals?[k];
            final n =
                !flatShaded &&
                    authoredNormal != null &&
                    authoredNormal.lengthSquared > 1e-12
                ? authoredNormal.normalized()
                : faceNormal;
            positions.setAll(vertex * 3, [p.x, p.y, p.z]);
            normals.setAll(vertex * 3, [n.x, n.y, n.z]);
            for (var axis = 0; axis < 3; axis++) {
              min[axis] = math.min(min[axis], positions[vertex * 3 + axis]);
              max[axis] = math.max(max[axis], positions[vertex * 3 + axis]);
            }
            // glTF expects linear vertex factors. Display colors have already
            // been multiplied by baseColorFactor; using them again darkens it.
            final factor =
                t.linearVertexColors?[k] ??
                (source != null
                    ? const [1.0, 1.0, 1.0, 1.0]
                    : _linearColor(
                        t.vertexColors?[k] ?? t.color ?? defaultColor,
                      ));
            colors.setAll(vertex * 4, factor);
            for (final entry in uvs.entries) {
              final uv = t.textureCoordinates[entry.key]?[k] ?? Offset.zero;
              entry.value.setAll(vertex * 2, [uv.dx, uv.dy]);
            }
          }
        }
        final attributes = <String, int>{
          'POSITION': _attribute(positions, 3, min: min, max: max),
          'NORMAL': _attribute(normals, 3),
          'COLOR_0': _attribute(colors, 4),
          for (final entry in uvs.entries)
            'TEXCOORD_${entry.key}': _attribute(entry.value, 2),
        };
        primitives.add({'attributes': attributes, 'material': materialIndex});
      }
    }
    final json = <String, dynamic>{
      'asset': {'version': '2.0'},
      'scene': 0,
      'scenes': [
        {
          'nodes': [0],
        },
      ],
      'nodes': [
        {'mesh': 0},
      ],
      'meshes': [
        {'primitives': primitives},
      ],
      'buffers': [
        {'byteLength': binary.length},
      ],
      'bufferViews': views,
      'accessors': accessors,
      'materials': materials,
      if (textures.isNotEmpty) 'textures': textures,
      if (images.isNotEmpty) 'images': images,
      if (samplers.isNotEmpty) 'samplers': samplers,
      if (extensions.isNotEmpty) 'extensionsUsed': extensions.toList(),
    };
    final jsonBytes = utf8.encode(jsonEncode(json));
    final jsonLength = (jsonBytes.length + 3) & ~3;
    final binLength = (binary.length + 3) & ~3;
    final result = Uint8List(28 + jsonLength + binLength);
    final header = ByteData.sublistView(result);
    header.setUint32(0, 0x46546c67, Endian.little);
    header.setUint32(4, 2, Endian.little);
    header.setUint32(8, result.length, Endian.little);
    header.setUint32(12, jsonLength, Endian.little);
    header.setUint32(16, 0x4e4f534a, Endian.little);
    result.fillRange(20, 20 + jsonLength, 32);
    result.setAll(20, jsonBytes);
    header.setUint32(20 + jsonLength, binLength, Endian.little);
    header.setUint32(24 + jsonLength, 0x004e4942, Endian.little);
    result.setAll(28 + jsonLength, binary.takeBytes());
    return result;
  }

  int _view(Uint8List bytes, {int? target}) {
    while (binary.length % 4 != 0) {
      binary.addByte(0);
    }
    final index = views.length;
    views.add({
      'buffer': 0,
      'byteOffset': binary.length,
      'byteLength': bytes.length,
      'target': ?target,
    });
    binary.add(bytes);
    return index;
  }

  int _attribute(
    Float32List values,
    int components, {
    List<double>? min,
    List<double>? max,
  }) {
    final index = accessors.length;
    accessors.add({
      'bufferView': _view(values.buffer.asUint8List(), target: 34962),
      'componentType': 5126,
      'count': values.length ~/ components,
      'type': 'VEC$components',
      'min': ?min,
      'max': ?max,
    });
    return index;
  }

  Map<String, dynamic> _material(
    MeshMaterial? m,
    bool doubleSided,
    bool blend,
  ) {
    if (m?.unlit == true) extensions.add('KHR_materials_unlit');
    return {
      'name': ?m?.name,
      'pbrMetallicRoughness': {
        'baseColorFactor': m?.baseColorFactor ?? const [1, 1, 1, 1],
        'metallicFactor': m?.metallicFactor ?? 0,
        'roughnessFactor': m?.roughnessFactor ?? .72,
        'baseColorTexture': ?_binding(m?.baseColorTexture),
        'metallicRoughnessTexture': ?_binding(m?.metallicRoughnessTexture),
      },
      'emissiveFactor': m?.emissiveFactor ?? const [0, 0, 0],
      'alphaMode': m?.alphaMode ?? (blend ? 'BLEND' : 'OPAQUE'),
      'alphaCutoff': m?.alphaCutoff ?? .5,
      'doubleSided': doubleSided || (m?.doubleSided ?? false),
      if (m?.normalTexture != null)
        'normalTexture': {
          ..._binding(m!.normalTexture)!,
          'scale': m.normalScale,
        },
      if (m?.occlusionTexture != null)
        'occlusionTexture': {
          ..._binding(m!.occlusionTexture)!,
          'strength': m.occlusionStrength,
        },
      'emissiveTexture': ?_binding(m?.emissiveTexture),
      if (m?.unlit == true) 'extensions': {'KHR_materials_unlit': {}},
    };
  }

  Map<String, dynamic>? _binding(MeshTextureBinding? binding) {
    if (binding == null) return null;
    final transformed =
        binding.offset != Offset.zero ||
        binding.scale != const Offset(1, 1) ||
        binding.rotation != 0;
    if (transformed) extensions.add('KHR_texture_transform');
    return {
      'index': textureIndices.putIfAbsent(binding.texture, () {
        final t = binding.texture;
        final image = images.length;
        images.add({'bufferView': _view(t.bytes), 'mimeType': _mimeType(t)});
        final sampler = samplers.length;
        samplers.add({
          'wrapS': t.wrapS,
          'wrapT': t.wrapT,
          'minFilter': ?t.minFilter,
          'magFilter': ?t.magFilter,
        });
        final index = textures.length;
        textures.add({'source': image, 'sampler': sampler});
        return index;
      }),
      'texCoord': binding.texCoord,
      if (transformed)
        'extensions': {
          'KHR_texture_transform': {
            'offset': [binding.offset.dx, binding.offset.dy],
            'scale': [binding.scale.dx, binding.scale.dy],
            'rotation': binding.rotation,
          },
        },
    };
  }

  String _mimeType(MeshTexture t) {
    if (t.mimeType == 'image/png' || t.mimeType == 'image/jpeg') {
      return t.mimeType!;
    }
    if (t.bytes.length >= 4 &&
        t.bytes[0] == 137 &&
        t.bytes[1] == 80 &&
        t.bytes[2] == 78 &&
        t.bytes[3] == 71) {
      return 'image/png';
    }
    if (t.bytes.length >= 2 && t.bytes[0] == 255 && t.bytes[1] == 216) {
      return 'image/jpeg';
    }
    throw const FormatException('Unsupported GPU texture image format');
  }
}

double _linear(double c) =>
    c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();
List<double> _linearColor(Color c) => [
  _linear(c.r),
  _linear(c.g),
  _linear(c.b),
  c.a,
];
