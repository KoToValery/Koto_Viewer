import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/mesh_3d.dart';

/// Loads static glTF 2.0 scenes, preserving material/texture data.
/// Coordinates remain in metre-based, Y-up space unless [convertToZUp] is
/// requested. No centering or size normalization is applied to the asset.
class GlbGltfParser {
  static Future<Mesh3D> parseFromFile(
    String filePath, {
    bool convertToZUp = false,
  }) async {
    final file = File(filePath).absolute;
    final (json, binary) = _decode(await file.readAsBytes());
    final resources = <String, Uint8List>{};
    // Sidecars stay local to the asset directory; never fetch remote resources.
    final directory = file.parent.uri;
    for (final collection in ['buffers', 'images']) {
      for (final item in _list(json[collection])) {
        final uriText = _map(item)['uri'];
        if (uriText is! String || uriText.startsWith('data:')) continue;
        if (resources.containsKey(uriText)) continue;
        final uri = Uri.parse(uriText);
        final resolved = directory.resolveUri(uri).normalizePath();
        if (uri.hasScheme ||
            uri.hasAuthority ||
            uri.hasQuery ||
            uri.hasFragment ||
            !resolved.toString().startsWith(directory.toString()) ||
            Uri.decodeComponent(uri.path).contains('\\') ||
            Uri.decodeComponent(uri.path).split('/').contains('..')) {
          throw const FormatException('Invalid local glTF resource URI');
        }
        resources[uriText] = await File.fromUri(resolved).readAsBytes();
      }
    }
    return _GltfReader(
      json,
      binary,
      (uri) => resources[uri]!,
      convertToZUp,
    ).build(file.uri.pathSegments.last);
  }

  /// External URIs require a resolver. Embedded GLB and data URIs need none.
  static Mesh3D parseFromBytes(
    Uint8List bytes, {
    String name = 'Model.glb',
    bool convertToZUp = false,
    Uint8List Function(String uri)? resourceResolver,
  }) {
    final (json, binary) = _decode(bytes);
    return _GltfReader(
      json,
      binary,
      resourceResolver,
      convertToZUp,
    ).build(name);
  }

  static (Map<String, dynamic>, Uint8List?) _decode(Uint8List bytes) {
    Uint8List jsonBytes = bytes;
    Uint8List? binary;
    if (bytes.length >= 4 &&
        ByteData.sublistView(bytes).getUint32(0, Endian.little) == 0x46546c67) {
      if (bytes.length < 20) {
        throw const FormatException('Truncated GLB header');
      }
      final data = ByteData.sublistView(bytes);
      if (data.getUint32(4, Endian.little) != 2 ||
          data.getUint32(8, Endian.little) != bytes.length) {
        throw const FormatException('Invalid GLB version or length');
      }
      var offset = 12;
      var hasJson = false;
      while (offset < bytes.length) {
        if (offset + 8 > bytes.length) {
          throw const FormatException('Truncated GLB chunk header');
        }
        final length = data.getUint32(offset, Endian.little);
        final type = data.getUint32(offset + 4, Endian.little);
        final start = offset + 8;
        if (length % 4 != 0 || start + length > bytes.length) {
          throw const FormatException('Invalid GLB chunk length');
        }
        if (!hasJson && type != 0x4e4f534a) {
          throw const FormatException('GLB must begin with a JSON chunk');
        }
        if (type == 0x4e4f534a) {
          if (hasJson) throw const FormatException('Duplicate GLB JSON chunk');
          jsonBytes = Uint8List.sublistView(bytes, start, start + length);
          hasJson = true;
        } else if (type == 0x004e4942) {
          if (binary != null) {
            throw const FormatException('Duplicate GLB BIN chunk');
          }
          binary = Uint8List.sublistView(bytes, start, start + length);
        }
        // Unknown chunks are ignored as required by glTF.
        offset = start + length;
      }
    }
    // Accept zero padding from older exporters as well as standard spaces.
    final json = _map(
      jsonDecode(utf8.decode(jsonBytes).replaceFirst(RegExp(r'\x00+$'), '')),
    );
    final asset = _map(json['asset']);
    if (asset['version'] != '2.0' ||
        (asset['minVersion'] != null && asset['minVersion'] != '2.0')) {
      throw const FormatException('Unsupported glTF asset version');
    }
    return (json, binary);
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Expected a glTF object');
}

List<dynamic> _list(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value;
  throw const FormatException('Expected a glTF array');
}

int _integer(dynamic value) {
  if (value is int && value >= 0) return value;
  throw const FormatException('Expected a nonnegative glTF integer');
}

double _number(dynamic value) {
  if (value is num && value.isFinite) return value.toDouble();
  throw const FormatException('Expected a finite glTF number');
}

List<double> _numbers(dynamic value, List<double> defaults) {
  if (value == null) return defaults;
  final values = _list(value);
  if (values.length != defaults.length) {
    throw const FormatException('Invalid glTF vector length');
  }
  return List.unmodifiable(values.map(_number));
}

T _at<T>(List<T> values, dynamic index) {
  final i = _integer(index);
  if (i >= values.length) {
    throw const FormatException('glTF index out of range');
  }
  return values[i];
}

class _GltfReader {
  final Map<String, dynamic> json;
  final Uint8List? binary;
  final Uint8List Function(String uri)? resolver;
  final bool zUp;
  final buffers = <Uint8List>[];
  final accessorCache = <int, List<List<double>>>{};
  final materialCache = <int, MeshMaterial>{};
  final textureCache = <int, MeshTexture>{};
  late final views = _list(json['bufferViews']);
  late final accessors = _list(json['accessors']);
  late final meshes = _list(json['meshes']);
  late final nodes = _list(json['nodes']);
  final triangles = <Triangle3D>[];
  final groups = <ElementMeshGroup>[];

  _GltfReader(this.json, this.binary, this.resolver, this.zUp);

  Uint8List _resource(String uri) {
    if (uri.startsWith('data:')) return UriData.parse(uri).contentAsBytes();
    if (resolver == null) {
      throw const FormatException('External glTF resource requires a resolver');
    }
    return resolver!(uri);
  }

  Mesh3D build(String name) {
    const supported = {
      'KHR_materials_unlit',
      'KHR_texture_transform',
      'KHR_mesh_quantization',
    };
    for (final extension in _list(json['extensionsRequired'])) {
      if (!supported.contains(extension)) {
        throw FormatException(
          'Unsupported required glTF extension: $extension',
        );
      }
    }
    final bufferDefs = _list(json['buffers']);
    // Compatibility with old geometry-only GLBs lacking buffers[].
    if (bufferDefs.isEmpty && binary != null) buffers.add(binary!);
    for (var i = 0; i < bufferDefs.length; i++) {
      final def = _map(bufferDefs[i]);
      final uri = def['uri'];
      final bytes = uri is String ? _resource(uri) : (i == 0 ? binary : null);
      final length = _integer(def['byteLength']);
      if (bytes == null || length > bytes.length) {
        throw const FormatException('Missing or truncated glTF buffer');
      }
      buffers.add(Uint8List.sublistView(bytes, 0, length));
    }
    if (nodes.isEmpty && _list(json['scenes']).isEmpty) {
      // Existing callers and older exporters also supply geometry-only files.
      for (var i = 0; i < meshes.length; i++) {
        _mesh(i, _identity, 'gltf/mesh/$i');
      }
    } else {
      final parents = List<int>.filled(nodes.length, -1);
      for (var i = 0; i < nodes.length; i++) {
        for (final child in _list(_map(nodes[i])['children'])) {
          _at(nodes, child);
          final c = _integer(child);
          if (parents[c] != -1) {
            throw const FormatException('glTF node has multiple parents');
          }
          parents[c] = i;
        }
      }
      final state = List<int>.filled(nodes.length, 0);
      void validate(int i) {
        if (state[i] == 1) {
          throw const FormatException('Cyclic glTF node hierarchy');
        }
        if (state[i] == 2) return;
        state[i] = 1;
        for (final child in _list(_map(nodes[i])['children'])) {
          validate(_integer(child));
        }
        state[i] = 2;
      }

      for (var i = 0; i < nodes.length; i++) {
        validate(i);
      }
      final scenes = _list(json['scenes']);
      final roots = scenes.isNotEmpty
          ? _list(_map(_at(scenes, json['scene'] ?? 0))['nodes'])
          : [
              for (var i = 0; i < nodes.length; i++)
                if (parents[i] == -1) i,
            ];
      final visited = <int>{};
      void visit(int i, List<double> parent) {
        final node = _map(_at(nodes, i));
        if (!visited.add(i)) {
          throw const FormatException('Repeated glTF scene node');
        }
        final world = _multiply(parent, _transform(node));
        if (node['mesh'] != null) {
          if (node['skin'] != null) {
            throw const FormatException(
              'Skinned glTF meshes require a skinning renderer',
            );
          }
          final mesh = _map(_at(meshes, node['mesh']));
          if (_list(
            node['weights'] ?? mesh['weights'],
          ).any((w) => _number(w) != 0)) {
            throw const FormatException(
              'Weighted glTF morph targets are unsupported',
            );
          }
          _mesh(_integer(node['mesh']), world, 'gltf/node/$i');
        }
        for (final child in _list(node['children'])) {
          visit(_integer(child), world);
        }
      }

      for (final root in roots) {
        final i = _integer(root);
        _at(nodes, i);
        if (parents[i] != -1) {
          throw const FormatException('glTF scene root has a parent');
        }
        visit(i, _identity);
      }
    }
    return Mesh3D(name: name, triangles: triangles, groups: groups);
  }

  /// Bounds are checked against declared buffer/view lengths, not backing bytes.
  Uint8List _view(dynamic index) {
    final view = _map(_at(views, index));
    final buffer = _at(buffers, view['buffer']);
    final start = _integer(view['byteOffset'] ?? 0);
    final length = _integer(view['byteLength']);
    if (start + length > buffer.length) {
      throw const FormatException('glTF buffer view exceeds its buffer');
    }
    return Uint8List.sublistView(buffer, start, start + length);
  }

  List<List<double>> _accessor(dynamic index) {
    final i = _integer(index);
    return accessorCache.putIfAbsent(i, () {
      final a = _map(_at(accessors, i));
      final count = _integer(a['count']);
      final components = switch (a['type']) {
        'SCALAR' => 1,
        'VEC2' => 2,
        'VEC3' => 3,
        'VEC4' => 4,
        _ => throw const FormatException('Unsupported glTF accessor type'),
      };
      final type = _integer(a['componentType']);
      final size = switch (type) {
        5120 || 5121 => 1,
        5122 || 5123 => 2,
        5125 || 5126 => 4,
        _ => throw const FormatException('Unsupported glTF component type'),
      };
      final normalized = a['normalized'] == true;
      final offset = _integer(a['byteOffset'] ?? 0);
      List<List<double>> result;
      if (a['bufferView'] != null) {
        final view = _map(_at(views, a['bufferView']));
        final stride = _integer(view['byteStride'] ?? components * size);
        final data = ByteData.sublistView(_view(a['bufferView']));
        _checkRange(
          data.lengthInBytes,
          offset,
          count,
          stride,
          components * size,
        );
        if (stride % size != 0 || offset % size != 0) {
          throw const FormatException('Misaligned glTF accessor');
        }
        result = List.generate(
          count,
          (j) => List.generate(
            components,
            (k) => _component(
              data,
              offset + j * stride + k * size,
              type,
              normalized,
            ),
          ),
        );
      } else {
        if (count > 10000000 || offset != 0) {
          throw const FormatException('Invalid zero-filled glTF accessor');
        }
        result = List.generate(
          count,
          (_) => List<double>.filled(components, 0),
        );
      }
      if (a['sparse'] != null) {
        final sparse = _map(a['sparse']);
        final n = _integer(sparse['count']);
        if (n > count) throw const FormatException('Invalid glTF sparse count');
        final indices = _map(sparse['indices']);
        final values = _map(sparse['values']);
        final it = _integer(indices['componentType']);
        final isize = switch (it) {
          5121 => 1,
          5123 => 2,
          5125 => 4,
          _ => throw const FormatException('Invalid glTF sparse index type'),
        };
        final idata = ByteData.sublistView(_view(indices['bufferView']));
        final vdata = ByteData.sublistView(_view(values['bufferView']));
        final io = _integer(indices['byteOffset'] ?? 0);
        final vo = _integer(values['byteOffset'] ?? 0);
        _checkRange(idata.lengthInBytes, io, n, isize, isize);
        _checkRange(
          vdata.lengthInBytes,
          vo,
          n,
          components * size,
          components * size,
        );
        var previous = -1;
        for (var j = 0; j < n; j++) {
          final target = _component(idata, io + j * isize, it, false).toInt();
          if (target <= previous || target >= count) {
            throw const FormatException('Invalid glTF sparse index');
          }
          previous = target;
          result[target] = List.generate(
            components,
            (k) => _component(
              vdata,
              vo + (j * components + k) * size,
              type,
              normalized,
            ),
          );
        }
      }
      return result;
    });
  }

  List<List<double>> _attribute(dynamic index, String type, [int? count]) {
    final a = _map(_at(accessors, index));
    if (a['type'] != type) {
      throw const FormatException('Invalid glTF attribute type');
    }
    final values = _accessor(index);
    if (count != null && values.length != count) {
      throw const FormatException('glTF attribute counts do not match');
    }
    return values;
  }

  void _mesh(int index, List<double> world, String id) {
    final mesh = _map(_at(meshes, index));
    final faces = <Triangle3D>[];
    final mirrored = _determinant(world) < 0;
    for (final primitive in _list(mesh['primitives'])) {
      final p = _map(primitive);
      final mode = _integer(p['mode'] ?? 4);
      if (mode > 6) throw const FormatException('Invalid glTF primitive mode');
      if (mode < 4) continue; // Points/lines have no surface triangles.
      final attrs = _map(p['attributes']);
      final positions = _attribute(attrs['POSITION'], 'VEC3');
      final vertices = positions
          .map((v) => _axis(_point(world, _vector(v))))
          .toList();
      final normals = attrs['NORMAL'] == null
          ? null
          : _attribute(
              attrs['NORMAL'],
              'VEC3',
              vertices.length,
            ).map((v) => _axis(_normal(world, _vector(v)))).toList();
      final uvSets = <int, List<Offset>>{};
      for (final attr in attrs.entries) {
        if (RegExp(r'^TEXCOORD_\d+$').hasMatch(attr.key)) {
          uvSets[int.parse(attr.key.substring(9))] = _attribute(
            attr.value,
            'VEC2',
            vertices.length,
          ).map((v) => Offset(v[0], v[1])).toList();
        }
      }
      List<List<double>>? colors;
      if (attrs['COLOR_0'] != null) {
        final a = _map(_at(accessors, attrs['COLOR_0']));
        if (a['type'] != 'VEC3' && a['type'] != 'VEC4') {
          throw const FormatException('Invalid glTF color type');
        }
        colors = _attribute(
          attrs['COLOR_0'],
          a['type'] as String,
          vertices.length,
        );
      }
      final material = p['material'] == null
          ? const MeshMaterial()
          : _material(p['material']);
      for (final binding in [
        material.baseColorTexture,
        material.normalTexture,
        material.metallicRoughnessTexture,
        material.occlusionTexture,
        material.emissiveTexture,
      ]) {
        if (binding != null && !uvSets.containsKey(binding.texCoord)) {
          throw const FormatException('Missing glTF texture coordinate set');
        }
      }
      List<int> indices;
      if (p['indices'] == null) {
        indices = List.generate(vertices.length, (i) => i);
      } else {
        final a = _map(_at(accessors, p['indices']));
        if (![5121, 5123, 5125].contains(a['componentType']) ||
            a['normalized'] == true) {
          throw const FormatException('Invalid glTF index component type');
        }
        indices = _attribute(
          p['indices'],
          'SCALAR',
        ).map((v) => v[0].toInt()).toList();
      }
      if (indices.any((i) => i >= vertices.length)) {
        throw const FormatException('glTF vertex index out of range');
      }
      if (mode == 4 && indices.length % 3 != 0) {
        throw const FormatException('Incomplete glTF triangle');
      }
      void face(int a, int b, int c) {
        if (mirrored) {
          final swap = b;
          b = c;
          c = swap;
        }
        final order = [a, b, c];
        final v0 = vertices[a], v1 = vertices[b], v2 = vertices[c];
        if ((v1 - v0).cross(v2 - v0).lengthSquared == 0) return;
        final linearColors = [
          for (final i in order)
            [
              for (var k = 0; k < 4; k++)
                material.baseColorFactor[k] *
                    (colors == null || k >= colors[i].length
                        ? 1
                        : colors[i][k]),
            ],
        ];
        final vertexColors = colors == null
            ? null
            : linearColors.map((v) => _displayColor(v, material)).toList();
        final average = [
          for (var k = 0; k < 4; k++)
            (linearColors[0][k] + linearColors[1][k] + linearColors[2][k]) / 3,
        ];
        final vn = normals == null ? null : [for (final i in order) normals[i]];
        faces.add(
          Triangle3D(
            v0: v0,
            v1: v1,
            v2: v2,
            normal: vn == null ? null : (vn[0] + vn[1] + vn[2]).normalized(),
            color: _displayColor(average, material),
            isDoubleSided: material.doubleSided,
            material: material,
            vertexColors: vertexColors,
            linearVertexColors: colors == null
                ? null
                : [
                    for (final i in order)
                      [...colors[i], if (colors[i].length == 3) 1.0],
                  ],
            vertexNormals: vn,
            textureCoordinates: {
              for (final entry in uvSets.entries)
                entry.key: [for (final i in order) entry.value[i]],
            },
          ),
        );
      }

      if (mode == 4) {
        for (var i = 0; i + 2 < indices.length; i += 3) {
          face(indices[i], indices[i + 1], indices[i + 2]);
        }
      } else {
        for (var i = 2; i < indices.length; i++) {
          if (mode == 6) {
            face(indices[0], indices[i - 1], indices[i]);
          } else if (i.isEven) {
            face(indices[i - 2], indices[i - 1], indices[i]);
          } else {
            face(indices[i - 1], indices[i - 2], indices[i]);
          }
        }
      }
    }
    if (faces.isNotEmpty) {
      triangles.addAll(faces);
      groups.add(ElementMeshGroup(id: id, triangles: faces));
    }
  }

  Vector3 _axis(Vector3 v) => zUp ? Vector3(v.x, -v.z, v.y) : v;

  MeshMaterial _material(dynamic index) =>
      materialCache.putIfAbsent(_integer(index), () {
        final m = _map(_at(_list(json['materials']), index));
        final pbr = m['pbrMetallicRoughness'] == null
            ? <String, dynamic>{}
            : _map(m['pbrMetallicRoughness']);
        final alpha = m['alphaMode'] ?? 'OPAQUE';
        if (!['OPAQUE', 'MASK', 'BLEND'].contains(alpha)) {
          throw const FormatException('Invalid glTF alpha mode');
        }
        return MeshMaterial(
          name: m['name'] as String?,
          baseColorFactor: _numbers(pbr['baseColorFactor'], const [1, 1, 1, 1]),
          metallicFactor: _number(pbr['metallicFactor'] ?? 1),
          roughnessFactor: _number(pbr['roughnessFactor'] ?? 1),
          emissiveFactor: _numbers(m['emissiveFactor'], const [0, 0, 0]),
          alphaMode: alpha as String,
          alphaCutoff: _number(m['alphaCutoff'] ?? 0.5),
          doubleSided: m['doubleSided'] == true,
          unlit:
              m['extensions'] is Map &&
              (m['extensions'] as Map).containsKey('KHR_materials_unlit'),
          baseColorTexture: _binding(pbr['baseColorTexture']),
          metallicRoughnessTexture: _binding(pbr['metallicRoughnessTexture']),
          normalTexture: _binding(m['normalTexture']),
          occlusionTexture: _binding(m['occlusionTexture']),
          emissiveTexture: _binding(m['emissiveTexture']),
          normalScale: _number(
            m['normalTexture'] == null
                ? 1
                : _map(m['normalTexture'])['scale'] ?? 1,
          ),
          occlusionStrength: _number(
            m['occlusionTexture'] == null
                ? 1
                : _map(m['occlusionTexture'])['strength'] ?? 1,
          ),
        );
      });

  MeshTextureBinding? _binding(dynamic value) {
    if (value == null) return null;
    final info = _map(value);
    final extensions = info['extensions'] == null
        ? <String, dynamic>{}
        : _map(info['extensions']);
    final transform = extensions['KHR_texture_transform'] == null
        ? <String, dynamic>{}
        : _map(extensions['KHR_texture_transform']);
    final offset = _numbers(transform['offset'], const [0, 0]);
    final scale = _numbers(transform['scale'], const [1, 1]);
    return MeshTextureBinding(
      texture: _texture(info['index']),
      texCoord: _integer(transform['texCoord'] ?? info['texCoord'] ?? 0),
      offset: Offset(offset[0], offset[1]),
      scale: Offset(scale[0], scale[1]),
      rotation: _number(transform['rotation'] ?? 0),
    );
  }

  MeshTexture _texture(dynamic index) =>
      textureCache.putIfAbsent(_integer(index), () {
        final t = _map(_at(_list(json['textures']), index));
        final image = _map(_at(_list(json['images']), t['source']));
        final sampler = t['sampler'] == null
            ? <String, dynamic>{}
            : _map(_at(_list(json['samplers']), t['sampler']));
        final uri = image['uri'] as String?;
        final bytes = uri == null ? _view(image['bufferView']) : _resource(uri);
        return MeshTexture(
          bytes: bytes,
          mimeType:
              image['mimeType'] as String? ??
              (uri != null && uri.startsWith('data:')
                  ? UriData.parse(uri).mimeType
                  : null),
          wrapS: _integer(sampler['wrapS'] ?? 10497),
          wrapT: _integer(sampler['wrapT'] ?? 10497),
          magFilter: sampler['magFilter'] == null
              ? null
              : _integer(sampler['magFilter']),
          minFilter: sampler['minFilter'] == null
              ? null
              : _integer(sampler['minFilter']),
        );
      });
}

void _checkRange(
  int length,
  int offset,
  int count,
  int stride,
  int elementSize,
) {
  if (stride < elementSize ||
      offset > length ||
      (count > 0 && offset + (count - 1) * stride + elementSize > length)) {
    throw const FormatException('glTF accessor exceeds its buffer view');
  }
}

double _component(ByteData d, int offset, int type, bool normalized) {
  final value = switch (type) {
    5120 => d.getInt8(offset).toDouble(),
    5121 => d.getUint8(offset).toDouble(),
    5122 => d.getInt16(offset, Endian.little).toDouble(),
    5123 => d.getUint16(offset, Endian.little).toDouble(),
    5125 => d.getUint32(offset, Endian.little).toDouble(),
    5126 => d.getFloat32(offset, Endian.little),
    _ => throw const FormatException('Invalid glTF component type'),
  };
  if (!value.isFinite) throw const FormatException('Nonfinite glTF component');
  if (!normalized) return value;
  return switch (type) {
    5120 => math.max(value / 127, -1).toDouble(),
    5121 => value / 255,
    5122 => math.max(value / 32767, -1).toDouble(),
    5123 => value / 65535,
    _ => throw const FormatException('Invalid normalized glTF component'),
  };
}

Color _displayColor(List<double> linear, MeshMaterial material) {
  double srgb(double v) =>
      v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
  final alpha = material.alphaMode == 'OPAQUE'
      ? 1.0
      : material.alphaMode == 'MASK'
      ? (linear[3] >= material.alphaCutoff ? 1.0 : 0.0)
      : linear[3];
  return Color.from(
    alpha: alpha.clamp(0, 1),
    red: srgb(linear[0].clamp(0, 1)),
    green: srgb(linear[1].clamp(0, 1)),
    blue: srgb(linear[2].clamp(0, 1)),
  );
}

const _identity = <double>[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];

List<double> _multiply(List<double> a, List<double> b) => [
  for (var col = 0; col < 4; col++)
    for (var row = 0; row < 4; row++)
      a[row] * b[col * 4] +
          a[4 + row] * b[col * 4 + 1] +
          a[8 + row] * b[col * 4 + 2] +
          a[12 + row] * b[col * 4 + 3],
];

List<double> _transform(Map<String, dynamic> node) {
  if (node['matrix'] != null) {
    if (node['translation'] != null ||
        node['rotation'] != null ||
        node['scale'] != null) {
      throw const FormatException('glTF matrix and TRS are mutually exclusive');
    }
    final m = _numbers(node['matrix'], _identity);
    if (m[3] != 0 || m[7] != 0 || m[11] != 0 || m[15] != 1) {
      throw const FormatException('Invalid glTF affine matrix');
    }
    return m;
  }
  final t = _numbers(node['translation'], const [0, 0, 0]);
  final s = _numbers(node['scale'], const [1, 1, 1]);
  final q = _numbers(node['rotation'], const [0, 0, 0, 1]);
  final length = math.sqrt(q.fold<double>(0, (sum, v) => sum + v * v));
  if (length < 1e-12) throw const FormatException('Invalid glTF quaternion');
  final x = q[0] / length,
      y = q[1] / length,
      z = q[2] / length,
      w = q[3] / length;
  return [
    (1 - 2 * (y * y + z * z)) * s[0],
    2 * (x * y + z * w) * s[0],
    2 * (x * z - y * w) * s[0],
    0,
    2 * (x * y - z * w) * s[1],
    (1 - 2 * (x * x + z * z)) * s[1],
    2 * (y * z + x * w) * s[1],
    0,
    2 * (x * z + y * w) * s[2],
    2 * (y * z - x * w) * s[2],
    (1 - 2 * (x * x + y * y)) * s[2],
    0,
    t[0],
    t[1],
    t[2],
    1,
  ];
}

Vector3 _vector(List<double> v) => Vector3(v[0], v[1], v[2]);
Vector3 _point(List<double> m, Vector3 v) => Vector3(
  m[0] * v.x + m[4] * v.y + m[8] * v.z + m[12],
  m[1] * v.x + m[5] * v.y + m[9] * v.z + m[13],
  m[2] * v.x + m[6] * v.y + m[10] * v.z + m[14],
);
double _determinant(List<double> m) =>
    m[0] * (m[5] * m[10] - m[9] * m[6]) -
    m[4] * (m[1] * m[10] - m[9] * m[2]) +
    m[8] * (m[1] * m[6] - m[5] * m[2]);

Vector3 _normal(List<double> m, Vector3 v) {
  // Cofactor matrix / determinant is the inverse transpose of the linear part.
  final det = _determinant(m);
  if (det.abs() < 1e-15) return Vector3.zero;
  return (Vector3(
            (m[5] * m[10] - m[9] * m[6]) * v.x +
                (m[9] * m[2] - m[1] * m[10]) * v.y +
                (m[1] * m[6] - m[5] * m[2]) * v.z,
            (m[8] * m[6] - m[4] * m[10]) * v.x +
                (m[0] * m[10] - m[8] * m[2]) * v.y +
                (m[4] * m[2] - m[0] * m[6]) * v.z,
            (m[4] * m[9] - m[8] * m[5]) * v.x +
                (m[8] * m[1] - m[0] * m[9]) * v.y +
                (m[0] * m[5] - m[4] * m[1]) * v.z,
          ) /
          det)
      .normalized();
}
