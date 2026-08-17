import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/stl_parser.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/obj_parser.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/glb_gltf_parser.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/rendering/cad_3d_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('3D Math & Geometry Tests', () {
    test('Vector3 arithmetic and vector operations', () {
      const v1 = Vector3(1, 2, 3);
      const v2 = Vector3(4, 5, 6);

      final add = v1 + v2;
      expect(add.x, 5);
      expect(add.y, 7);
      expect(add.z, 9);

      final sub = v2 - v1;
      expect(sub.x, 3);
      expect(sub.y, 3);
      expect(sub.z, 3);

      final dot = v1.dot(v2); // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
      expect(dot, 32);

      const vx = Vector3(1, 0, 0);
      const vy = Vector3(0, 1, 0);
      final cross = vx.cross(vy);
      expect(cross.x, 0);
      expect(cross.y, 0);
      expect(cross.z, 1);

      expect(Vector3(3, 4, 0).length, 5);
      expect(Vector3(0, 5, 0).normalized().y, 1);
    });

    test('Triangle3D and BoundingBox3D calculations', () {
      final tri = Triangle3D(
        v0: const Vector3(0, 0, 0),
        v1: const Vector3(10, 0, 0),
        v2: const Vector3(0, 10, 0),
      );

      expect(tri.area, 50.0);
      expect(tri.centroid.x, closeTo(3.333, 0.01));
      expect(tri.centroid.y, closeTo(3.333, 0.01));
      expect(tri.centroid.z, 0.0);
      expect(tri.normal.z, 1.0); // Facing +Z

      final mesh = Mesh3D(name: 'TestMesh', triangles: [tri]);
      expect(mesh.bounds.sizeX, 10.0);
      expect(mesh.bounds.sizeY, 10.0);
      expect(mesh.bounds.sizeZ, 0.0);
      expect(mesh.surfaceArea, 50.0);
    });
  });

  group('3D Parsers Tests', () {
    test('StlParser parses ASCII STL format', () {
      const asciiStl = '''
solid test_cube
  facet normal 0.0 0.0 1.0
    outer loop
      vertex 0.0 0.0 10.0
      vertex 10.0 0.0 10.0
      vertex 10.0 10.0 10.0
    endloop
  endfacet
  facet normal 0.0 0.0 1.0
    outer loop
      vertex 0.0 0.0 10.0
      vertex 10.0 10.0 10.0
      vertex 0.0 10.0 10.0
    endloop
  endfacet
endsolid test_cube
''';

      final bytes = Uint8List.fromList(utf8.encode(asciiStl));
      final mesh = StlParser.parseFromBytes(bytes, name: 'test.stl');

      expect(mesh.triangleCount, 2);
      expect(mesh.bounds.sizeX, 10.0);
      expect(mesh.bounds.sizeY, 10.0);
      expect(mesh.bounds.min.z, 10.0);
      expect(mesh.bounds.max.z, 10.0);
    });

    test('StlParser parses Binary STL format', () {
      // 80 bytes header + 4 bytes uint32 count (1 triangle) + 50 bytes triangle data
      final buffer = Uint8List(84 + 50);
      final byteData = ByteData.sublistView(buffer);

      // Triangle count = 1
      byteData.setUint32(80, 1, Endian.little);

      // Normal (0, 0, 1)
      byteData.setFloat32(84, 0.0, Endian.little);
      byteData.setFloat32(88, 0.0, Endian.little);
      byteData.setFloat32(92, 1.0, Endian.little);

      // Vertex 0: (0, 0, 5)
      byteData.setFloat32(96, 0.0, Endian.little);
      byteData.setFloat32(100, 0.0, Endian.little);
      byteData.setFloat32(104, 5.0, Endian.little);

      // Vertex 1: (20, 0, 5)
      byteData.setFloat32(108, 20.0, Endian.little);
      byteData.setFloat32(112, 0.0, Endian.little);
      byteData.setFloat32(116, 5.0, Endian.little);

      // Vertex 2: (0, 30, 5)
      byteData.setFloat32(120, 0.0, Endian.little);
      byteData.setFloat32(124, 30.0, Endian.little);
      byteData.setFloat32(128, 5.0, Endian.little);

      final mesh = StlParser.parseFromBytes(buffer, name: 'binary.stl');

      expect(mesh.triangleCount, 1);
      expect(mesh.bounds.sizeX, 20.0);
      expect(mesh.bounds.sizeY, 30.0);
      expect(mesh.bounds.min.z, 5.0);
    });

    test('ObjParser parses Wavefront OBJ format with quad triangulation', () {
      const objContent = '''
# Wavefront OBJ sample quad
v 0.0 0.0 0.0
v 10.0 0.0 0.0
v 10.0 10.0 0.0
v 0.0 10.0 0.0
vn 0.0 0.0 1.0
f 1//1 2//1 3//1 4//1
''';

      final bytes = Uint8List.fromList(utf8.encode(objContent));
      final mesh = ObjParser.parseFromBytes(bytes, name: 'quad.obj');

      // Quad should be triangulated into 2 triangles
      expect(mesh.triangleCount, 2);
      expect(mesh.bounds.sizeX, 10.0);
      expect(mesh.bounds.sizeY, 10.0);
      expect(mesh.surfaceArea, 100.0);
    });

    test('GlbGltfParser parses GLB header and structure', () {
      // Create minimal valid GLTF JSON
      final gltfMap = {
        'asset': {'version': '2.0'},
        'accessors': [
          {
            'bufferView': 0,
            'byteOffset': 0,
            'componentType': 5126, // Float
            'count': 3,
            'type': 'VEC3',
          }
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 0, 'byteLength': 36}
        ],
        'meshes': [
          {
            'primitives': [
              {
                'attributes': {'POSITION': 0}
              }
            ]
          }
        ]
      };

      final jsonStr = json.encode(gltfMap);
      final jsonBytes = utf8.encode(jsonStr);

      // Vertex buffer data: 3 vertices (0,0,0), (10,0,0), (0,10,0)
      final binBytes = Uint8List(36);
      final bd = ByteData.sublistView(binBytes);
      bd.setFloat32(0, 0.0, Endian.little);
      bd.setFloat32(4, 0.0, Endian.little);
      bd.setFloat32(8, 0.0, Endian.little);

      bd.setFloat32(12, 10.0, Endian.little);
      bd.setFloat32(16, 0.0, Endian.little);
      bd.setFloat32(20, 0.0, Endian.little);

      bd.setFloat32(24, 0.0, Endian.little);
      bd.setFloat32(28, 10.0, Endian.little);
      bd.setFloat32(32, 0.0, Endian.little);

      // Pad JSON chunk to 4-byte boundary
      final jsonPad = (4 - (jsonBytes.length % 4)) % 4;
      final paddedJsonLen = jsonBytes.length + jsonPad;

      // Build GLB binary
      final totalLen = 12 + 8 + paddedJsonLen + 8 + binBytes.length;
      final glb = Uint8List(totalLen);
      final glbBd = ByteData.sublistView(glb);

      // Header
      glb[0] = 0x67; glb[1] = 0x6C; glb[2] = 0x54; glb[3] = 0x46; // "glTF"
      glbBd.setUint32(4, 2, Endian.little); // version 2
      glbBd.setUint32(8, totalLen, Endian.little);

      // Chunk 0: JSON
      glbBd.setUint32(12, paddedJsonLen, Endian.little);
      glbBd.setUint32(16, 0x4E4F534A, Endian.little); // "JSON"
      glb.setRange(20, 20 + jsonBytes.length, jsonBytes);

      // Chunk 1: BIN
      final binChunkOffset = 20 + paddedJsonLen;
      glbBd.setUint32(binChunkOffset, binBytes.length, Endian.little);
      glbBd.setUint32(binChunkOffset + 4, 0x004E4942, Endian.little); // "BIN"
      glb.setRange(binChunkOffset + 8, binChunkOffset + 8 + binBytes.length, binBytes);

      final mesh = GlbGltfParser.parseFromBytes(glb, name: 'triangle.glb');

      expect(mesh.triangleCount, 1);
      expect(mesh.bounds.sizeX, 10.0);
      expect(mesh.bounds.sizeY, 10.0);
    });
  });

  group('Cad3DCamera & File Type Tests', () {
    test('Cad3DCamera view presets and orbit math', () {
      final camera = Cad3DCamera();
      expect(camera.zoom, 1.0);

      camera.setPreset(Cad3DViewPreset.top);
      expect(camera.yaw, 0.0);
      expect(camera.pitch, closeTo(1.57, 0.01));

      camera.setPreset(Cad3DViewPreset.isometric);
      expect(camera.yaw, closeTo(0.785, 0.01));

      camera.zoomBy(1.5);
      expect(camera.zoom, 1.5);

      camera.reset();
      expect(camera.zoom, 1.0);
    });

    test('PdfItem correctly identifies 3D file formats (STL, OBJ, GLTF, GLB)', () {
      final stlItem = PdfItem(
        path: '/storage/part.stl',
        name: 'part.stl',
        sizeInBytes: 1024,
        lastOpened: DateTime.now(),
      );

      final objItem = PdfItem(
        path: '/storage/model.obj',
        name: 'model.obj',
        sizeInBytes: 2048,
        lastOpened: DateTime.now(),
      );

      final glbItem = PdfItem(
        path: '/storage/asset.glb',
        name: 'asset.glb',
        sizeInBytes: 4096,
        lastOpened: DateTime.now(),
      );

      final gltfItem = PdfItem(
        path: '/storage/scene.gltf',
        name: 'scene.gltf',
        sizeInBytes: 8192,
        lastOpened: DateTime.now(),
      );

      expect(stlItem.fileType, KotoFileType.stl);
      expect(stlItem.is3d, isTrue);
      expect(stlItem.isCad, isFalse);

      expect(objItem.fileType, KotoFileType.obj);
      expect(objItem.is3d, isTrue);

      expect(glbItem.fileType, KotoFileType.glb);
      expect(glbItem.is3d, isTrue);

      expect(gltfItem.fileType, KotoFileType.gltf);
      expect(gltfItem.is3d, isTrue);
    });
  });
}
