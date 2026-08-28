import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/mesh_3d.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

/// Pure-Dart ISO 10303-21 STEP (.step, .stp, .p21) 3D Mechanical CAD Parser.
class StepParser {
  /// Parse STEP file in background isolate.
  static Future<Mesh3D> parseFromFile(String filePath) async {
    return compute(_parseStepFileCompute, filePath);
  }

  static Mesh3D _parseStepFileCompute(String filePath) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final name = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, name: name);
  }

  static Mesh3D parseFromBytes(Uint8List bytes, {String name = 'Model.step'}) {
    final text = _decodeText(bytes);
    return _parseStepText(text, name: name);
  }

  static String _decodeText(Uint8List bytes) {
    return UniversalEncodingService.decodeBytes(bytes);
  }

  static Mesh3D _parseStepText(String rawText, {String name = 'Model.step'}) {
    // 1. Remove comments /* ... */
    final cleanText = rawText.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

    // 2. Tokenize entities by ';'
    final rawEntities = cleanText.split(';');

    final Map<int, Vector3> pointMap = {};
    final Map<int, int> vertexMap = {}; // Vertex ID -> Point ID
    final Map<int, List<int>> polyLoopMap = {}; // Loop ID -> List of Point IDs
    final Map<int, List<int>> edgeCurveMap = {}; // Edge ID -> [StartVertexId, EndVertexId]
    final List<Triangle3D> triangles = [];
    final List<Vector3> allPoints = [];

    // Entity regex: #123 = TYPE_NAME(params)
    final entityRegex = RegExp(r'#(\d+)\s*=\s*([A-Z0-9_]+)\s*\((.*)\)', dotAll: true);

    for (final raw in rawEntities) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final match = entityRegex.firstMatch(trimmed);
      if (match == null) continue;

      final id = int.tryParse(match.group(1)!) ?? 0;
      final type = match.group(2)!.toUpperCase();
      final params = match.group(3)!.trim();

      if (type == 'PRODUCT') {
        final nameMatch = RegExp(r"'(.*?)'").allMatches(params).toList();
        if (nameMatch.isNotEmpty) {
          final prodName = UniversalEncodingService.decodeIso10303String(nameMatch[0].group(1)!);
          if (prodName.isNotEmpty) name = prodName;
        }
      }

      // A. CARTESIAN_POINT
      if (type == 'CARTESIAN_POINT') {
        // e.g. 'NONE', (10.0, 20.0, 30.0)
        final coordMatch = RegExp(r'\(\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)\s*,\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)(?:\s*,\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?))?\s*\)').firstMatch(params);
        if (coordMatch != null) {
          final x = double.tryParse(coordMatch.group(1)!) ?? 0.0;
          final y = double.tryParse(coordMatch.group(2)!) ?? 0.0;
          final z = double.tryParse(coordMatch.group(3) ?? '0.0') ?? 0.0;
          final pt = Vector3(x, y, z);
          pointMap[id] = pt;
          allPoints.add(pt);
        }
      }
      // B. VERTEX_POINT
      else if (type == 'VERTEX_POINT') {
        // e.g. '', #10
        final ptIdMatch = RegExp(r'#(\d+)').firstMatch(params);
        if (ptIdMatch != null) {
          final ptId = int.tryParse(ptIdMatch.group(1)!) ?? 0;
          vertexMap[id] = ptId;
        }
      }
      // C. POLY_LOOP
      else if (type == 'POLY_LOOP') {
        // e.g. '', (#10, #20, #30, #40)
        final List<int> loopPointIds = [];
        final idMatches = RegExp(r'#(\d+)').allMatches(params);
        for (final m in idMatches) {
          final refId = int.tryParse(m.group(1)!) ?? 0;
          loopPointIds.add(refId);
        }
        if (loopPointIds.isNotEmpty) {
          polyLoopMap[id] = loopPointIds;
        }
      }
      // D. EDGE_CURVE
      else if (type == 'EDGE_CURVE') {
        // e.g. '', #v1, #v2, #curve, .T.
        final idMatches = RegExp(r'#(\d+)').allMatches(params).toList();
        if (idMatches.length >= 2) {
          final v1 = int.tryParse(idMatches[0].group(1)!) ?? 0;
          final v2 = int.tryParse(idMatches[1].group(1)!) ?? 0;
          edgeCurveMap[id] = [v1, v2];
        }
      }
      // E. TRIANGULATED_SURFACE_SET or TRIANGULATED_FACE
      else if (type.contains('TRIANGULATED')) {
        final idMatches = RegExp(r'#(\d+)').allMatches(params).toList();
        if (idMatches.length >= 3) {
          final p1 = pointMap[int.tryParse(idMatches[0].group(1)!) ?? 0];
          final p2 = pointMap[int.tryParse(idMatches[1].group(1)!) ?? 0];
          final p3 = pointMap[int.tryParse(idMatches[2].group(1)!) ?? 0];
          if (p1 != null && p2 != null && p3 != null) {
            triangles.add(Triangle3D(v0: p1, v1: p2, v2: p3));
          }
        }
      }
    }

    // 3. Resolve all POLY_LOOPs into 3D Triangles
    for (final loopIds in polyLoopMap.values) {
      final List<Vector3> loopPts = [];
      for (final refId in loopIds) {
        // May reference a CARTESIAN_POINT directly or through a VERTEX_POINT
        if (pointMap.containsKey(refId)) {
          loopPts.add(pointMap[refId]!);
        } else if (vertexMap.containsKey(refId)) {
          final ptId = vertexMap[refId]!;
          if (pointMap.containsKey(ptId)) {
            loopPts.add(pointMap[ptId]!);
          }
        }
      }

      // Fan triangulation for convex/planar polygons
      if (loopPts.length >= 3) {
        final p0 = loopPts[0];
        for (int i = 1; i < loopPts.length - 1; i++) {
          final p1 = loopPts[i];
          final p2 = loopPts[i + 1];
          triangles.add(Triangle3D(v0: p0, v1: p1, v2: p2));
        }
      }
    }

    // 4. Fallback: If no PolyLoops produced triangles, use Points or Edge curves
    if (triangles.isEmpty && allPoints.length >= 3) {
      for (int i = 0; i < allPoints.length - 2; i += 3) {
        triangles.add(
          Triangle3D(
            v0: allPoints[i],
            v1: allPoints[i + 1],
            v2: allPoints[i + 2],
          ),
        );
      }
    }

    // If only wireframe lines exist, generate thin visual segment prisms
    if (triangles.isEmpty && edgeCurveMap.isNotEmpty) {
      for (final edge in edgeCurveMap.values) {
        final p1 = pointMap[edge[0]] ?? (vertexMap.containsKey(edge[0]) ? pointMap[vertexMap[edge[0]]] : null);
        final p2 = pointMap[edge[1]] ?? (vertexMap.containsKey(edge[1]) ? pointMap[vertexMap[edge[1]]] : null);
        if (p1 != null && p2 != null) {
          final offset = Vector3(0.05, 0.05, 0.05);
          triangles.add(Triangle3D(v0: p1, v1: p2, v2: p2 + offset));
          triangles.add(Triangle3D(v0: p1, v1: p2 + offset, v2: p1 + offset));
        }
      }
    }

    return Mesh3D(name: name, triangles: triangles);
  }
}
