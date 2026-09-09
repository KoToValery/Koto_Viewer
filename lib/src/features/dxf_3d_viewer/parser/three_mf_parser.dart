import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/mesh_3d.dart';

class ThreeMfParser {
  /// Parse 3MF from file path in background isolate
  static Future<Mesh3D> parseFromFile(String filePath) async {
    return compute(_parseThreeMfCompute, filePath);
  }

  static Mesh3D _parseThreeMfCompute(String filePath) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final name = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, name: name);
  }

  /// Parse 3MF from bytes buffer
  static Mesh3D parseFromBytes(Uint8List bytes, {String name = 'Model.3mf'}) {
    final archive = ZipDecoder().decodeBytes(bytes);
    
    ArchiveFile? modelFile;
    for (final file in archive) {
      if (file.name.toLowerCase().endsWith('3dmodel.model')) {
        modelFile = file;
        break;
      }
    }

    if (modelFile == null) {
      throw const FormatException('No 3dmodel.model found in 3MF archive');
    }

    final content = String.fromCharCodes(modelFile.content as List<int>);
    final document = XmlDocument.parse(content);
    
    final List<Vector3> allVertices = [];
    final List<Triangle3D> triangles = [];

    final verticesElements = document.findAllElements('vertex');
    for (final vertexEl in verticesElements) {
      final x = double.tryParse(vertexEl.getAttribute('x') ?? '0') ?? 0.0;
      final y = double.tryParse(vertexEl.getAttribute('y') ?? '0') ?? 0.0;
      final z = double.tryParse(vertexEl.getAttribute('z') ?? '0') ?? 0.0;
      allVertices.add(Vector3(x, y, z));
    }

    final trianglesElements = document.findAllElements('triangle');
    for (final triangleEl in trianglesElements) {
      final v1Idx = int.tryParse(triangleEl.getAttribute('v1') ?? '') ?? -1;
      final v2Idx = int.tryParse(triangleEl.getAttribute('v2') ?? '') ?? -1;
      final v3Idx = int.tryParse(triangleEl.getAttribute('v3') ?? '') ?? -1;
      
      if (v1Idx >= 0 && v2Idx >= 0 && v3Idx >= 0 && 
          v1Idx < allVertices.length && 
          v2Idx < allVertices.length && 
          v3Idx < allVertices.length) {
        triangles.add(Triangle3D(
          v0: allVertices[v1Idx],
          v1: allVertices[v2Idx],
          v2: allVertices[v3Idx],
        ));
      }
    }

    return Mesh3D(name: name, triangles: triangles);
  }
}
