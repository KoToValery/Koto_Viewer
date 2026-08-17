import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/mesh_3d.dart';

/// Pure-Dart ANSI IGES 5.3 (.iges, .igs) 3D CAD Parser.
class IgesParser {
  static Future<Mesh3D> parseFromFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final name = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, name: name);
  }

  static Mesh3D parseFromBytes(Uint8List bytes, {String name = 'Model.iges'}) {
    final text = _decodeText(bytes);
    return _parseIgesText(text, name: name);
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static Mesh3D _parseIgesText(String rawText, {String name = 'Model.iges'}) {
    final lines = rawText.split(RegExp(r'\r?\n'));

    final List<String> dLines = [];
    final List<String> pLines = [];

    // Separate lines by section indicator (D = Directory, P = Parameter)
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      String? sectionChar;

      if (line.length >= 73 && 'SDGPTsdgpt'.contains(line[72])) {
        sectionChar = line[72].toUpperCase();
      } else {
        final match = RegExp(r'([SDGPTsdgpt])\s*\d+\s*$').firstMatch(line);
        if (match != null) {
          sectionChar = match.group(1)!.toUpperCase();
        }
      }

      if (sectionChar == 'D') {
        dLines.add(line);
      } else if (sectionChar == 'P') {
        pLines.add(line);
      }
    }

    // Parse Parameter Data Section into map of pointer -> parameter string
    final Map<int, String> parameterMap = {};
    int currentPointer = 1;
    final sb = StringBuffer();

    for (final pLine in pLines) {
      // Find where the trailing pointer/section starts (usually column 64 or before 'P')
      String dataPart = pLine;
      final pMatch = RegExp(r'P\s*\d+\s*$', caseSensitive: false).firstMatch(pLine);
      if (pMatch != null) {
        dataPart = pLine.substring(0, pMatch.start).trimRight();
        // Remove DE pointer in cols 65-72 if present
        final lastFieldMatch = RegExp(r'\s+\d+\s*$').firstMatch(dataPart);
        if (lastFieldMatch != null && lastFieldMatch.start >= 30) {
          dataPart = dataPart.substring(0, lastFieldMatch.start);
        }
      } else if (pLine.length >= 64) {
        dataPart = pLine.substring(0, 64);
      }

      sb.write(dataPart);
      if (dataPart.contains(';')) {
        parameterMap[currentPointer] = sb.toString();
        sb.clear();
        currentPointer++;
      }
    }
    if (sb.isNotEmpty) {
      parameterMap[currentPointer] = sb.toString();
    }

    final List<Triangle3D> triangles = [];
    final List<Vector3> allVertices = [];

    // Parse Directory Entry pairs
    for (int i = 0; i + 1 < dLines.length; i += 2) {
      final line1 = dLines[i];
      if (line1.length < 16) continue;

      final typeStr = line1.substring(0, 8).trim();
      final paramPtrStr = line1.substring(8, 16).trim();

      final entityType = int.tryParse(typeStr) ?? 0;
      final paramPtr = int.tryParse(paramPtrStr) ?? (i ~/ 2 + 1);

      final paramData = parameterMap[paramPtr] ?? parameterMap.values.elementAtOrNull(i ~/ 2) ?? '';
      final params = _splitIgesParams(paramData);

      // 1. Entity 106: Copious Data (Triangles / Point list / Line strip)
      if (entityType == 106) {
        if (params.length >= 4) {
          final List<Vector3> pts = [];
          final startIdx = (params.length >= 6 && params[0] == '106') ? 3 : 1;
          for (int p = startIdx; p + 2 < params.length; p += 3) {
            final x = double.tryParse(params[p]) ?? 0.0;
            final y = double.tryParse(params[p + 1]) ?? 0.0;
            final z = double.tryParse(params[p + 2]) ?? 0.0;
            final pt = Vector3(x, y, z);
            pts.add(pt);
            allVertices.add(pt);
          }

          if (pts.length >= 3) {
            for (int t = 0; t + 2 < pts.length; t += 3) {
              triangles.add(Triangle3D(v0: pts[t], v1: pts[t + 1], v2: pts[t + 2]));
            }
          }
        }
      }
      // 2. Entity 110: 3D Line
      else if (entityType == 110) {
        if (params.length >= 7) {
          final x1 = double.tryParse(params[1]) ?? 0.0;
          final y1 = double.tryParse(params[2]) ?? 0.0;
          final z1 = double.tryParse(params[3]) ?? 0.0;
          final x2 = double.tryParse(params[4]) ?? 0.0;
          final y2 = double.tryParse(params[5]) ?? 0.0;
          final z2 = double.tryParse(params[6]) ?? 0.0;

          final p1 = Vector3(x1, y1, z1);
          final p2 = Vector3(x2, y2, z2);
          allVertices.add(p1);
          allVertices.add(p2);

          final offset = Vector3(0.05, 0.05, 0.05);
          triangles.add(Triangle3D(v0: p1, v1: p2, v2: p2 + offset));
        }
      }
      // 3. Entity 116: 3D Point
      else if (entityType == 116) {
        if (params.length >= 4) {
          final x = double.tryParse(params[1]) ?? 0.0;
          final y = double.tryParse(params[2]) ?? 0.0;
          final z = double.tryParse(params[3]) ?? 0.0;
          allVertices.add(Vector3(x, y, z));
        }
      }
      // 4. Entity 128 / 144 / 186: Surfaces / Solids (Extract coordinate control mesh)
      else if (entityType == 128 || entityType == 144 || entityType == 186) {
        final List<Vector3> surfacePoints = [];
        for (int p = 1; p + 2 < params.length; p += 3) {
          final x = double.tryParse(params[p]);
          final y = double.tryParse(params[p + 1]);
          final z = double.tryParse(params[p + 2]);
          if (x != null && y != null && z != null) {
            surfacePoints.add(Vector3(x, y, z));
          }
        }
        if (surfacePoints.length >= 3) {
          for (int t = 0; t + 2 < surfacePoints.length; t += 3) {
            triangles.add(
              Triangle3D(
                v0: surfacePoints[t],
                v1: surfacePoints[t + 1],
                v2: surfacePoints[t + 2],
              ),
            );
          }
        }
      }
    }

    // Fallback: If no structured triangles were formed, triangulate raw collected 3D vertices
    if (triangles.isEmpty && allVertices.length >= 3) {
      for (int i = 0; i + 2 < allVertices.length; i += 3) {
        triangles.add(
          Triangle3D(
            v0: allVertices[i],
            v1: allVertices[i + 1],
            v2: allVertices[i + 2],
          ),
        );
      }
    }

    return Mesh3D(name: name, triangles: triangles);
  }

  static List<String> _splitIgesParams(String data) {
    final clean = data.replaceAll(';', '').trim();
    return clean.split(',').map((s) => s.trim()).toList();
  }
}
