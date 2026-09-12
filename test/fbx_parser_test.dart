import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/fbx_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FBX ASCII Parser Tests', () {
    test('parses basic ASCII FBX with quad face', () {
      const asciiFbx = '''
; FBX 7.4.0 project file
GlobalSettings:  {
	Version: 1000
	Properties70:  {
		P: "UpAxis", "int", "Integer", "", 2
	}
}
Objects:  {
	Geometry: 1001, "Geometry::Plane", "Mesh" {
		Vertices: *12 {
			a: 0.0, 0.0, 0.0, 10.0, 0.0, 0.0, 10.0, 10.0, 0.0, 0.0, 10.0, 0.0
		}
		PolygonVertexIndex: *4 {
			a: 0, 1, 2, -4
		}
	}
}
''';
      final bytes = Uint8List.fromList(utf8.encode(asciiFbx));
      final mesh = FbxParser.parseFromBytes(bytes, name: 'plane.fbx');

      expect(mesh.name, 'plane.fbx');
      expect(mesh.triangleCount, 2); // 1 quad = 2 triangles
      expect(mesh.bounds.sizeX, 10.0);
      expect(mesh.bounds.sizeY, 10.0);
      expect(mesh.bounds.sizeZ, 0.0);
    });

    test('parses ASCII FBX with multi-polygon cube and negative terminal indices', () {
      const asciiCube = '''
; FBX 7.3.0
Objects:  {
	Geometry: 2002, "Geometry::Box", "Mesh" {
		Vertices: *24 {
			a: 0,0,0, 10,0,0, 10,10,0, 0,10,0,
			   0,0,10, 10,0,10, 10,10,10, 0,10,10
		}
		PolygonVertexIndex: *24 {
			a: 0,1,2,-4,
			   4,7,6,-6,
			   0,4,5,-2,
			   1,5,6,-3,
			   2,6,7,-4,
			   3,7,4,-1
		}
	}
}
''';
      final bytes = Uint8List.fromList(utf8.encode(asciiCube));
      final mesh = FbxParser.parseFromBytes(bytes, name: 'cube.fbx');

      // 6 quad faces * 2 triangles = 12 triangles
      expect(mesh.triangleCount, 12);
      expect(mesh.bounds.sizeX, 10.0);
      expect(mesh.bounds.sizeY, 10.0);
      expect(mesh.bounds.sizeZ, 10.0);
    });

    test('throws FormatException on ASCII FBX with no geometry', () {
      const emptyFbx = '''
; FBX 7.4.0 project file
GlobalSettings:  {
	Version: 1000
}
Objects:  {
}
''';
      final bytes = Uint8List.fromList(utf8.encode(emptyFbx));
      expect(
        () => FbxParser.parseFromBytes(bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('FBX Binary Parser Tests', () {
    test('detects Binary FBX header and parses uncompressed binary geometry', () {
      final buffer = _createBinaryFbx(
        version: 7400,
        vertices: [
          0.0, 0.0, 0.0,
          10.0, 0.0, 0.0,
          10.0, 10.0, 0.0,
          0.0, 10.0, 0.0,
        ],
        indices: [0, 1, 2, -4], // 1 quad
        upAxis: 2,
        compress: false,
      );

      final mesh = FbxParser.parseFromBytes(buffer, name: 'binary_plane.fbx');

      expect(mesh.name, 'binary_plane.fbx');
      expect(mesh.triangleCount, 2);
      expect(mesh.bounds.sizeX, 10.0);
      expect(mesh.bounds.sizeY, 10.0);
    });

    test('parses Binary FBX with zlib compressed arrays', () {
      final buffer = _createBinaryFbx(
        version: 7400,
        vertices: [
          0.0, 0.0, 0.0,
          5.0, 0.0, 0.0,
          5.0, 5.0, 0.0,
          0.0, 5.0, 0.0,
        ],
        indices: [0, 1, 2, -4],
        upAxis: 2,
        compress: true,
      );

      final mesh = FbxParser.parseFromBytes(buffer, name: 'compressed_plane.fbx');

      expect(mesh.triangleCount, 2);
      expect(mesh.bounds.sizeX, 5.0);
      expect(mesh.bounds.sizeY, 5.0);
    });

    test('parses 64-bit Binary FBX (version >= 7500)', () {
      final buffer = _createBinaryFbx(
        version: 7500,
        vertices: [
          0.0, 0.0, 0.0,
          20.0, 0.0, 0.0,
          20.0, 20.0, 0.0,
        ],
        indices: [0, 1, -3], // 1 triangle
        upAxis: 2,
        compress: false,
      );

      final mesh = FbxParser.parseFromBytes(buffer, name: 'fbx7500.fbx');

      expect(mesh.triangleCount, 1);
      expect(mesh.bounds.sizeX, 20.0);
      expect(mesh.bounds.sizeY, 20.0);
    });
  });

  group('FBX Integration & FileType Tests', () {
    test('PdfItem correctly recognizes .fbx files as 3D CAD', () {
      final item = PdfItem(
        path: 'C:/models/sample_car.fbx',
        name: 'sample_car.fbx',
        sizeInBytes: 1024,
        lastOpened: DateTime.now(),
      );

      expect(item.fileType, KotoFileType.fbx);
      expect(item.is3d, isTrue);
      expect(item.isFbx, isTrue);
    });

    test('inspect 1.fbx real file with materials and subdivision', () {
      final file = File(r'C:\Users\Creator\Dropbox\test_files\1.fbx');
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final mesh = FbxParser.parseFromBytes(bytes, name: '1.fbx');
        expect(mesh.triangleCount, greaterThan(1000));
        
        // Verify colors are extracted and assigned
        final coloredTris = mesh.triangles.where((t) => t.color != null).toList();
        expect(coloredTris.isNotEmpty, isTrue);

        final uniqueColors = mesh.triangles.map((t) => t.color).whereType<Color>().toSet();
        expect(uniqueColors.length, greaterThanOrEqualTo(5));
      }
    });
  });
}

class _FbxRawNode {
  final String name;
  final List<Uint8List> properties;
  final List<_FbxRawNode> children;

  _FbxRawNode(this.name, {this.properties = const [], this.children = const []});

  int computeLength(bool is64Bit) {
    final headerSize = is64Bit ? 25 : 13;
    final nameLen = utf8.encode(name).length;
    final propLen = properties.fold(0, (sum, p) => sum + p.length);
    int childrenLen = 0;
    for (final c in children) {
      childrenLen += c.computeLength(is64Bit);
    }
    if (children.isNotEmpty) {
      childrenLen += headerSize; // null sentinel for end of children
    }
    return headerSize + nameLen + propLen + childrenLen;
  }

  Uint8List serialize(int startOffset, bool is64Bit) {
    final headerSize = is64Bit ? 25 : 13;
    final nameBytes = utf8.encode(name);
    final propBytesBuilder = BytesBuilder();
    for (final p in properties) {
      propBytesBuilder.add(p);
    }
    final propBytes = propBytesBuilder.toBytes();

    final totalLen = computeLength(is64Bit);
    final endOffset = startOffset + totalLen;

    final headerData = ByteData(headerSize);
    if (is64Bit) {
      headerData.setUint64(0, endOffset, Endian.little);
      headerData.setUint64(8, properties.length, Endian.little);
      headerData.setUint64(16, propBytes.length, Endian.little);
      headerData.setUint8(24, nameBytes.length);
    } else {
      headerData.setUint32(0, endOffset, Endian.little);
      headerData.setUint32(4, properties.length, Endian.little);
      headerData.setUint32(8, propBytes.length, Endian.little);
      headerData.setUint8(12, nameBytes.length);
    }

    final out = BytesBuilder();
    out.add(headerData.buffer.asUint8List());
    out.add(nameBytes);
    out.add(propBytes);

    int childCursor = startOffset + headerSize + nameBytes.length + propBytes.length;
    for (final c in children) {
      final childBytes = c.serialize(childCursor, is64Bit);
      out.add(childBytes);
      childCursor += childBytes.length;
    }
    if (children.isNotEmpty) {
      out.add(Uint8List(headerSize)); // null sentinel
    }

    return out.toBytes();
  }
}

/// Helper to build a valid Binary FBX byte stream (v7400 32-bit or v7500 64-bit)
Uint8List _createBinaryFbx({
  required int version,
  required List<double> vertices,
  required List<int> indices,
  required int upAxis,
  required bool compress,
}) {
  final is64Bit = version >= 7500;
  final headerSize = is64Bit ? 25 : 13;

  // Helper to serialize double array ('d')
  Uint8List encodeDoubleArray(List<double> values, bool compress) {
    final rawData = ByteData(values.length * 8);
    for (int i = 0; i < values.length; i++) {
      rawData.setFloat64(i * 8, values[i], Endian.little);
    }
    final rawBytes = rawData.buffer.asUint8List();

    final pb = BytesBuilder();
    pb.addByte('d'.codeUnitAt(0));

    final arrayLen = values.length;
    final int encoding = compress ? 1 : 0;
    final payloadBytes = compress ? Uint8List.fromList(zlib.encode(rawBytes)) : rawBytes;

    final header = ByteData(12);
    header.setUint32(0, arrayLen, Endian.little);
    header.setUint32(4, encoding, Endian.little);
    header.setUint32(8, payloadBytes.length, Endian.little);

    pb.add(header.buffer.asUint8List());
    pb.add(payloadBytes);
    return pb.toBytes();
  }

  // Helper to serialize int32 array ('i')
  Uint8List encodeIntArray(List<int> values, bool compress) {
    final rawData = ByteData(values.length * 4);
    for (int i = 0; i < values.length; i++) {
      rawData.setInt32(i * 4, values[i], Endian.little);
    }
    final rawBytes = rawData.buffer.asUint8List();

    final pb = BytesBuilder();
    pb.addByte('i'.codeUnitAt(0));

    final arrayLen = values.length;
    final int encoding = compress ? 1 : 0;
    final payloadBytes = compress ? Uint8List.fromList(zlib.encode(rawBytes)) : rawBytes;

    final header = ByteData(12);
    header.setUint32(0, arrayLen, Endian.little);
    header.setUint32(4, encoding, Endian.little);
    header.setUint32(8, payloadBytes.length, Endian.little);

    pb.add(header.buffer.asUint8List());
    pb.add(payloadBytes);
    return pb.toBytes();
  }

  Uint8List encodeString(String str) {
    final strBytes = utf8.encode(str);
    final pb = BytesBuilder();
    pb.addByte('S'.codeUnitAt(0));
    final header = ByteData(4)..setUint32(0, strBytes.length, Endian.little);
    pb.add(header.buffer.asUint8List());
    pb.add(strBytes);
    return pb.toBytes();
  }

  Uint8List encodeInt32(int val) {
    final pb = BytesBuilder();
    pb.addByte('I'.codeUnitAt(0));
    final data = ByteData(4)..setInt32(0, val, Endian.little);
    pb.add(data.buffer.asUint8List());
    return pb.toBytes();
  }

  // GlobalSettings
  final pUpAxis = _FbxRawNode('P', properties: [
    encodeString('UpAxis'),
    encodeString('int'),
    encodeString('Integer'),
    encodeString(''),
    encodeInt32(upAxis),
  ]);
  final props70 = _FbxRawNode('Properties70', children: [pUpAxis]);
  final globalSettings = _FbxRawNode('GlobalSettings', children: [props70]);

  // Build Geometry tree
  final vertNode = _FbxRawNode('Vertices', properties: [encodeDoubleArray(vertices, compress)]);
  final polyNode = _FbxRawNode('PolygonVertexIndex', properties: [encodeIntArray(indices, compress)]);
  final geomNode = _FbxRawNode('Geometry', children: [vertNode, polyNode]);
  final objectsNode = _FbxRawNode('Objects', children: [geomNode]);

  final bytesBuilder = BytesBuilder();

  // 1. Magic 23-byte header
  bytesBuilder.add(const [
    0x4B, 0x61, 0x79, 0x64, 0x61, 0x72, 0x61, 0x20,
    0x46, 0x42, 0x58, 0x20, 0x42, 0x69, 0x6E, 0x61,
    0x72, 0x79, 0x20, 0x20, 0x00, 0x1A, 0x00,
  ]);

  // 2. Version (uint32)
  final versionBytes = ByteData(4)..setUint32(0, version, Endian.little);
  bytesBuilder.add(versionBytes.buffer.asUint8List());

  // 3. Serialized GlobalSettings node starting at offset 27
  final gsBytes = globalSettings.serialize(27, is64Bit);
  bytesBuilder.add(gsBytes);

  // 4. Serialized Objects node starting after GlobalSettings
  final objectsBytes = objectsNode.serialize(27 + gsBytes.length, is64Bit);
  bytesBuilder.add(objectsBytes);

  // 5. Root sentinel
  bytesBuilder.add(Uint8List(headerSize));

  return bytesBuilder.toBytes();
}
