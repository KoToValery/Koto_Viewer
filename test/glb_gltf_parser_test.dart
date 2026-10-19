import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/glb_gltf_parser.dart';

void main() {
  group('glTF scenes', () {
    test('uses the selected scene, composes parents, and instances meshes', () {
      final a = _Asset();
      a.json['nodes'] = [
        {
          'translation': [10, 0, 0],
          'children': [1, 2],
        },
        {
          'mesh': 0,
          'scale': [2, 3, 1],
        },
        {
          'mesh': 0,
          'translation': [0, 5, 0],
        },
        {
          'mesh': 0,
          'translation': [100, 0, 0],
        },
      ];
      a.json['scenes'] = [
        {
          'nodes': [3],
        },
        {
          'nodes': [0],
        },
      ];
      a.json['scene'] = 1;
      final m = a.parse();
      expect(m.triangleCount, 2);
      expect(m.groups!.map((g) => g.id), ['gltf/node/1', 'gltf/node/2']);
      _point(m.triangles[0].v1, 12, 0, 0);
      _point(m.triangles[0].v2, 10, 3, 0);
      _point(m.triangles[1].v2, 10, 6, 0);
      expect(m.bounds.max.x, 12);
      expect(m.groups![1].bounds.min.y, 5);
    });

    test('rotates using quaternions and composes column-major matrices', () {
      final a = _Asset();
      a.json['nodes'] = [
        {
          'matrix': [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 5, 6, 7, 1],
          'children': [1],
        },
        {
          'mesh': 0,
          'rotation': [0, 0, math.sqrt(0.5), math.sqrt(0.5)],
        },
      ];
      final t = a.parse().triangles.single;
      _point(t.v1, 5, 7, 7);
      _point(t.v2, 4, 6, 7);
    });

    test('transforms vertex normals with the inverse transpose', () {
      final a = _Asset();
      a.attrs['NORMAL'] = a.values(List.generate(3, (_) => [1, 1, 0]));
      a.json['nodes'] = [
        {
          'mesh': 0,
          'scale': [2, 1, 1],
        },
      ];
      final t = a.parse().triangles.single;
      _point(t.normal, 1 / math.sqrt(5), 2 / math.sqrt(5), 0);
      expect(t.vertexNormals, hasLength(3));
    });

    test('mirroring reverses winding, UV and normal vertex order together', () {
      final a = _Asset();
      a.attrs['TEXCOORD_0'] = a.values([
        [0, 0],
        [1, 0],
        [0, 1],
      ]);
      a.attrs['NORMAL'] = a.values([
        [0, 0, 1],
        [0, 0, 1],
        [0, 0, 1],
      ]);
      a.json['nodes'] = [
        {
          'mesh': 0,
          'scale': [-1, 1, 1],
        },
      ];
      final t = a.parse().triangles.single;
      _point(t.v1, 0, 1, 0);
      _point(t.v2, -1, 0, 0);
      expect(
        (t.v1 - t.v0).cross(t.v2 - t.v0).normalized().dot(t.normal),
        closeTo(1, 1e-8),
      );
      expect(t.textureCoordinates[0], [
        Offset.zero,
        const Offset(0, 1),
        const Offset(1, 0),
      ]);
    });

    test('optional Z-up conversion preserves metric size and origin', () {
      final a = _Asset();
      a.json['nodes'] = [
        {
          'mesh': 0,
          'translation': [4, 5, 6],
        },
      ];
      final m = GlbGltfParser.parseFromBytes(a.glb(), convertToZUp: true);
      _point(m.triangles.single.v0, 4, -6, 5);
      _point(m.triangles.single.v2, 4, -6, 6);
      _point(m.triangles.single.normal, 0, -1, 0);
      expect(m.bounds.sizeX, 1);
      expect(m.bounds.sizeZ, 1);
    });

    test('empty selected scene does not render unused meshes', () {
      final a = _Asset();
      a.json['scenes'] = [
        {'nodes': <int>[]},
      ];
      expect(a.parse().triangles, isEmpty);
    });

    test('rejects cyclic, repeated, and invalid node references', () {
      for (final nodes in [
        [
          {
            'children': [1],
          },
          {
            'children': [0],
          },
        ],
        [
          {
            'children': [2],
          },
          {
            'children': [2],
          },
          {'mesh': 0},
        ],
        [
          {
            'children': [-1],
          },
        ],
      ]) {
        final a = _Asset()..json['nodes'] = nodes;
        expect(a.parse, throwsFormatException);
      }
      final a = _Asset()
        ..json['scenes'] = [
          {
            'nodes': [0, 0],
          },
        ];
      expect(a.parse, throwsFormatException);
    });

    test(
      'rejects skinning and nonzero morph weights rather than deforming silently',
      () {
        for (final node in [
          {'mesh': 0, 'skin': 0},
          {
            'mesh': 0,
            'weights': [1],
          },
        ]) {
          final a = _Asset()..json['nodes'] = [node];
          expect(a.parse, throwsFormatException);
        }
      },
    );
  });

  group('glTF accessors and topology', () {
    test('reads interleaved positions with view and accessor offsets', () {
      final a = _Asset();
      a.attrs['POSITION'] = a.values(
        [
          [0, 0, 0],
          [2, 0, 0],
          [0, 3, 0],
        ],
        stride: 20,
        offset: 4,
      );
      final m = a.parse();
      expect(m.bounds.sizeX, 2);
      expect(m.bounds.sizeY, 3);
    });

    test('reads all three unsigned index widths', () {
      for (final type in [5121, 5123, 5125]) {
        final a = _Asset();
        a.primitive['indices'] = a.values([
          [2],
          [0],
          [1],
        ], type: type);
        final t = a.parse().triangles.single;
        _point(t.v0, 0, 1, 0);
        expect(t.normal.z, 1);
      }
    });

    test(
      'applies sparse values to both zero-filled and populated accessors',
      () {
        for (final withBase in [false, true]) {
          final a = _Asset();
          final position = a.accessors[0];
          if (!withBase) position.remove('bufferView');
          final indices = a.append(Uint8List.fromList([1, 2]));
          final values = a.values([
            [2, 0, 0],
            [0, 3, 0],
          ]);
          position['sparse'] = {
            'count': 2,
            'indices': {'bufferView': indices, 'componentType': 5121},
            'values': {'bufferView': a.accessors[values]['bufferView']},
          };
          final m = a.parse();
          expect(m.bounds.sizeX, 2);
          expect(m.bounds.sizeY, 3);
        }
      },
    );

    test('reads signed and unsigned normalized integer attributes', () {
      final a = _Asset();
      a.attrs['NORMAL'] = a.values(
        [
          [0, 0, 127],
          [0, 0, 127],
          [0, 0, 127],
        ],
        type: 5120,
        normalized: true,
      );
      a.attrs['TEXCOORD_0'] = a.values(
        [
          [0, 0],
          [65535, 0],
          [0, 65535],
        ],
        type: 5123,
        normalized: true,
      );
      final t = a.parse().triangles.single;
      expect(t.normal.z, 1);
      expect(t.textureCoordinates[0]![1], const Offset(1, 0));
    });

    test('triangulates strips and fans with consistent winding', () {
      for (final mode in [5, 6]) {
        final a = _Asset();
        a.attrs['POSITION'] = a.values(
          mode == 5
              ? [
                  [0, 0, 0],
                  [1, 0, 0],
                  [0, 1, 0],
                  [1, 1, 0],
                ]
              : [
                  [0, 0, 0],
                  [1, 0, 0],
                  [1, 1, 0],
                  [0, 1, 0],
                ],
        );
        a.primitive['mode'] = mode;
        final m = a.parse();
        expect(m.triangleCount, 2);
        expect(m.surfaceArea, 1);
        expect(m.triangles.every((t) => t.normal.z > 0.99), isTrue);
      }
    });

    test('skips line primitives and degenerate strip connectors', () {
      final a = _Asset()..primitive['mode'] = 1;
      expect(a.parse().triangles, isEmpty);
      a.primitive['mode'] = 5;
      a.primitive['indices'] = a.values([
        [0],
        [1],
        [2],
        [2],
        [2],
      ], type: 5121);
      expect(a.parse().triangleCount, 1);
    });

    test('rejects accessor reads outside the declared view', () {
      final a = _Asset();
      a.views[0]['byteLength'] = 12;
      // Backing buffer still contains all 36 bytes.
      expect(a.parse, throwsFormatException);
    });

    test('rejects invalid indices, attribute counts, strides, and NaN', () {
      final cases = <void Function(_Asset)>[
        (a) => a.primitive['indices'] = -1,
        (a) => a.primitive['indices'] = a.values([
          [0],
          [1],
          [9],
        ], type: 5123),
        (a) => a.attrs['NORMAL'] = a.values([
          [0, 0, 1],
        ]),
        (a) => a.views[0]['byteStride'] = 4,
        (a) => a.attrs['POSITION'] = a.values([
          [double.nan, 0, 0],
          [1, 0, 0],
          [0, 1, 0],
        ]),
      ];
      for (final mutate in cases) {
        final a = _Asset();
        mutate(a);
        expect(a.parse, throwsFormatException);
      }
    });
  });

  group('glTF materials and textures', () {
    test('preserves PBR properties and converts linear colors to sRGB', () {
      final a = _Asset();
      a.json['materials'] = [
        {
          'name': 'Oak',
          'doubleSided': true,
          'alphaMode': 'BLEND',
          'pbrMetallicRoughness': {
            'baseColorFactor': [0.5, 0.25, 0, 0.4],
            'metallicFactor': 0.1,
            'roughnessFactor': 0.8,
          },
          'emissiveFactor': [0.1, 0.2, 0.3],
          'extensions': {'KHR_materials_unlit': {}},
        },
      ];
      a.primitive['material'] = 0;
      final t = a.parse().triangles.single;
      expect(t.color!.r, closeTo(0.735357, 1e-5));
      expect(t.color!.a, closeTo(0.4, 1e-6));
      expect(t.isDoubleSided, isTrue);
      expect(t.material!.name, 'Oak');
      expect(t.material!.metallicFactor, 0.1);
      expect(t.material!.roughnessFactor, 0.8);
      expect(t.material!.emissiveFactor, [0.1, 0.2, 0.3]);
      expect(t.material!.unlit, isTrue);
    });

    test('honors OPAQUE and MASK alpha behavior', () {
      for (final mode in ['OPAQUE', 'MASK']) {
        final a = _Asset();
        a.json['materials'] = [
          {
            'alphaMode': mode,
            'pbrMetallicRoughness': {
              'baseColorFactor': [1, 1, 1, 0.1],
            },
          },
        ];
        a.primitive['material'] = 0;
        expect(a.parse().triangles.single.color!.a, mode == 'OPAQUE' ? 1 : 0);
      }
    });

    test('multiplies normalized vertex colors by material factors', () {
      final a = _Asset();
      a.attrs['COLOR_0'] = a.values(
        [
          [255, 0, 0, 128],
          [0, 255, 0, 128],
          [0, 0, 255, 128],
        ],
        type: 5121,
        normalized: true,
      );
      a.json['materials'] = [
        {
          'alphaMode': 'BLEND',
          'pbrMetallicRoughness': {
            'baseColorFactor': [0.5, 1, 1, 0.5],
          },
        },
      ];
      a.primitive['material'] = 0;
      final t = a.parse().triangles.single;
      expect(t.vertexColors![0].r, closeTo(0.735357, 1e-5));
      expect(t.vertexColors![1].g, closeTo(1, 1e-12));
      expect(t.vertexColors![2].b, closeTo(1, 1e-12));
      expect(t.color!.a, closeTo(128 / 255 * 0.5, 1e-6));
    });

    test(
      'retains embedded image, sampler, all PBR bindings and UV transform',
      () {
        final a = _Asset();
        final image = a.append(Uint8List.fromList([137, 80, 78, 71]));
        a.json['images'] = [
          {'bufferView': image, 'mimeType': 'image/png'},
        ];
        a.json['samplers'] = [
          {'wrapS': 33071, 'wrapT': 33648, 'magFilter': 9729},
        ];
        a.json['textures'] = [
          {'source': 0, 'sampler': 0},
        ];
        final info = {
          'index': 0,
          'extensions': {
            'KHR_texture_transform': {
              'texCoord': 1,
              'offset': [0.25, 0.5],
              'scale': [2, 3],
              'rotation': 0.75,
            },
          },
        };
        a.attrs['TEXCOORD_1'] = a.values([
          [0, 0],
          [1, 0],
          [0, 1],
        ]);
        a.json['materials'] = [
          {
            'pbrMetallicRoughness': {
              'baseColorTexture': info,
              'metallicRoughnessTexture': info,
            },
            'normalTexture': {...info, 'scale': 0.6},
            'occlusionTexture': {...info, 'strength': 0.7},
            'emissiveTexture': info,
          },
        ];
        a.primitive['material'] = 0;
        final t = a.parse().triangles.single;
        final m = t.material!;
        final binding = m.baseColorTexture!;
        expect(binding.texture.bytes, [137, 80, 78, 71]);
        expect(binding.texture.mimeType, 'image/png');
        expect(binding.texture.wrapS, 33071);
        expect(binding.texture.wrapT, 33648);
        expect(binding.texture.magFilter, 9729);
        expect(binding.texCoord, 1);
        expect(binding.offset, const Offset(0.25, 0.5));
        expect(binding.scale, const Offset(2, 3));
        expect(binding.rotation, 0.75);
        expect(m.normalScale, 0.6);
        expect(m.occlusionStrength, 0.7);
        expect(m.normalTexture!.texture, same(binding.texture));
        expect(m.metallicRoughnessTexture!.texture, same(binding.texture));
        expect(m.emissiveTexture!.texture, same(binding.texture));
        expect(t.textureCoordinates[1], hasLength(3));
      },
    );

    test('loads a data URI image', () {
      final a = _Asset();
      a.addTexture('data:image/png;base64,iVBORw==');
      final t = a.parse().triangles.single;
      expect(t.material!.baseColorTexture!.texture.bytes, [137, 80, 78, 71]);
    });
  });

  group('glTF resources and containers', () {
    test('loads data URI buffers and caller-resolved external buffers', () {
      final a = _Asset();
      a.updateBuffer();
      final buffer = (a.json['buffers'] as List).first as Map;
      buffer['uri'] =
          'data:application/octet-stream;base64,${base64Encode(a.binary)}';
      expect(GlbGltfParser.parseFromBytes(a.jsonBytes()).triangleCount, 1);
      buffer['uri'] = 'mesh.bin';
      expect(
        () => GlbGltfParser.parseFromBytes(a.jsonBytes()),
        throwsFormatException,
      );
      expect(
        GlbGltfParser.parseFromBytes(
          a.jsonBytes(),
          resourceResolver: (uri) {
            expect(uri, 'mesh.bin');
            return a.binary;
          },
        ).triangleCount,
        1,
      );
    });

    test(
      'loads relative local buffers and images with encoded filenames',
      () async {
        final dir = await Directory.systemTemp.createTemp('koto_gltf_');
        addTearDown(() => dir.delete(recursive: true));
        final a = _Asset();
        a.updateBuffer();
        (a.json['buffers'] as List).first['uri'] = 'mesh%20data.bin';
        a.addTexture('image%20data.png');
        await File('${dir.path}/mesh data.bin').writeAsBytes(a.binary);
        await File(
          '${dir.path}/image data.png',
        ).writeAsBytes([137, 80, 78, 71]);
        // addTexture adds UV data, so refresh the buffer after adding it.
        a.updateBuffer();
        await File('${dir.path}/mesh data.bin').writeAsBytes(a.binary);
        final file = await File(
          '${dir.path}/scene.gltf',
        ).writeAsBytes(a.jsonBytes());
        final m = await GlbGltfParser.parseFromFile(
          file.path,
          convertToZUp: true,
        );
        expect(m.name, 'scene.gltf');
        expect(m.bounds.sizeZ, 1);
        expect(m.triangles.single.material!.baseColorTexture!.texture.bytes, [
          137,
          80,
          78,
          71,
        ]);
      },
    );

    test('rejects remote or escaping sidecar paths', () async {
      final dir = await Directory.systemTemp.createTemp('koto_gltf_');
      addTearDown(() => dir.delete(recursive: true));
      for (final uri in [
        'https://example.com/mesh.bin',
        '../mesh.bin',
        '%2e%2e/mesh.bin',
      ]) {
        final a = _Asset();
        a.updateBuffer();
        (a.json['buffers'] as List).first['uri'] = uri;
        final file = await File(
          '${dir.path}/scene.gltf',
        ).writeAsBytes(a.jsonBytes());
        await expectLater(
          GlbGltfParser.parseFromFile(file.path),
          throwsFormatException,
        );
      }
    });

    test('rejects truncated headers, bad version, lengths and chunk types', () {
      final a = _Asset();
      final bytes = a.glb();
      final variants = <Uint8List>[
        Uint8List.sublistView(bytes, 0, 4),
        Uint8List.sublistView(bytes, 0, bytes.length - 1),
      ];
      for (final offset in [4, 8, 12, 16]) {
        final copy = Uint8List.fromList(bytes);
        ByteData.sublistView(copy).setUint32(offset, 3, Endian.little);
        variants.add(copy);
      }
      for (final data in variants) {
        expect(() => GlbGltfParser.parseFromBytes(data), throwsFormatException);
      }
    });

    test(
      'ignores unknown chunks and rejects unsupported required extensions',
      () {
        final a = _Asset();
        final glb = a.glb();
        final extended = Uint8List(glb.length + 12)..setAll(0, glb);
        final bd = ByteData.sublistView(extended);
        bd.setUint32(8, extended.length, Endian.little);
        bd.setUint32(glb.length, 4, Endian.little);
        bd.setUint32(glb.length + 4, 0x12345678, Endian.little);
        expect(GlbGltfParser.parseFromBytes(extended).triangleCount, 1);
        a.json['extensionsRequired'] = ['KHR_draco_mesh_compression'];
        expect(a.parse, throwsFormatException);
      },
    );
  });
}

void _point(Vector3 v, num x, num y, num z) {
  expect(v.x, closeTo(x, 1e-6));
  expect(v.y, closeTo(y, 1e-6));
  expect(v.z, closeTo(z, 1e-6));
}

class _Asset {
  final json = <String, dynamic>{
    'asset': {'version': '2.0'},
  };
  final views = <Map<String, dynamic>>[];
  final accessors = <Map<String, dynamic>>[];
  final attrs = <String, dynamic>{};
  late final primitive = <String, dynamic>{'attributes': attrs};
  final _binary = BytesBuilder();
  Uint8List get binary => _binary.toBytes();

  _Asset() {
    json['bufferViews'] = views;
    json['accessors'] = accessors;
    json['meshes'] = [
      {
        'primitives': [primitive],
      },
    ];
    json['nodes'] = [
      {'mesh': 0},
    ];
    attrs['POSITION'] = values([
      [0, 0, 0],
      [1, 0, 0],
      [0, 1, 0],
    ]);
  }

  int append(Uint8List data, {int? stride}) {
    while (_binary.length % 4 != 0) {
      _binary.addByte(0);
    }
    final index = views.length;
    views.add({
      'buffer': 0,
      'byteOffset': _binary.length,
      'byteLength': data.length,
      'byteStride': ?stride,
    });
    _binary.add(data);
    return index;
  }

  int values(
    List<List<num>> values, {
    int type = 5126,
    bool normalized = false,
    int? stride,
    int offset = 0,
  }) {
    final size = switch (type) {
      5120 || 5121 => 1,
      5122 || 5123 => 2,
      _ => 4,
    };
    final components = values.first.length;
    final step = stride ?? components * size;
    final data = Uint8List(
      offset + step * (values.length - 1) + components * size,
    );
    final bd = ByteData.sublistView(data);
    for (var i = 0; i < values.length; i++) {
      for (var j = 0; j < components; j++) {
        final p = offset + i * step + j * size;
        final v = values[i][j];
        switch (type) {
          case 5120:
            bd.setInt8(p, v.toInt());
          case 5121:
            bd.setUint8(p, v.toInt());
          case 5122:
            bd.setInt16(p, v.toInt(), Endian.little);
          case 5123:
            bd.setUint16(p, v.toInt(), Endian.little);
          case 5125:
            bd.setUint32(p, v.toInt(), Endian.little);
          default:
            bd.setFloat32(p, v.toDouble(), Endian.little);
        }
      }
    }
    final index = accessors.length;
    accessors.add({
      'bufferView': append(data, stride: stride),
      'componentType': type,
      'count': values.length,
      'type': components == 1 ? 'SCALAR' : 'VEC$components',
      if (normalized) 'normalized': true,
      if (offset != 0) 'byteOffset': offset,
    });
    return index;
  }

  void addTexture(String uri) {
    json['images'] = [
      {'uri': uri},
    ];
    json['textures'] = [
      {'source': 0},
    ];
    json['materials'] = [
      {
        'pbrMetallicRoughness': {
          'baseColorTexture': {'index': 0},
        },
      },
    ];
    primitive['material'] = 0;
    attrs['TEXCOORD_0'] = values([
      [0, 0],
      [1, 0],
      [0, 1],
    ]);
  }

  void updateBuffer() {
    final previous = json['buffers'];
    json['buffers'] = [
      {
        'byteLength': binary.length,
        if (previous != null && previous[0]['uri'] != null)
          'uri': previous[0]['uri'],
      },
    ];
  }

  Uint8List jsonBytes() => Uint8List.fromList(utf8.encode(jsonEncode(json)));
  Mesh3D parse() => GlbGltfParser.parseFromBytes(glb());

  Uint8List glb() {
    updateBuffer();
    final j = jsonBytes();
    final jl = (j.length + 3) & ~3;
    final b = binary;
    final bl = (b.length + 3) & ~3;
    final result = Uint8List(28 + jl + bl);
    final bd = ByteData.sublistView(result);
    bd.setUint32(0, 0x46546c67, Endian.little);
    bd.setUint32(4, 2, Endian.little);
    bd.setUint32(8, result.length, Endian.little);
    bd.setUint32(12, jl, Endian.little);
    bd.setUint32(16, 0x4e4f534a, Endian.little);
    result.fillRange(20, 20 + jl, 32);
    result.setAll(20, j);
    bd.setUint32(20 + jl, bl, Endian.little);
    bd.setUint32(24 + jl, 0x004e4942, Endian.little);
    result.setAll(28 + jl, b);
    return result;
  }
}
