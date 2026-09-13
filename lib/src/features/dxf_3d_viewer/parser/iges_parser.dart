import 'dart:io';
import 'package:flutter/foundation.dart';
import '../geometry/nurbs_surface.dart';
import '../models/mesh_3d.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

/// Representation of an IGES Directory Entry (2 lines of 80 characters).
class _IgesDirectoryEntry {
  final int deIndex;
  final int entityType;
  final int paramPtr;
  final int transformMatrixDe;
  final int formNumber;

  _IgesDirectoryEntry({
    required this.deIndex,
    required this.entityType,
    required this.paramPtr,
    this.transformMatrixDe = 0,
    this.formNumber = 0,
  });
}

/// 3x4 Affine Transformation Matrix (Entity 124 in IGES).
class _IgesTransform {
  final double r11, r12, r13, t1;
  final double r21, r22, r23, t2;
  final double r31, r32, r33, t3;

  const _IgesTransform({
    this.r11 = 1.0, this.r12 = 0.0, this.r13 = 0.0, this.t1 = 0.0,
    this.r21 = 0.0, this.r22 = 1.0, this.r23 = 0.0, this.t2 = 0.0,
    this.r31 = 0.0, this.r32 = 0.0, this.r33 = 1.0, this.t3 = 0.0,
  });

  Vector3 transform(Vector3 p) {
    return Vector3(
      r11 * p.x + r12 * p.y + r13 * p.z + t1,
      r21 * p.x + r22 * p.y + r23 * p.z + t2,
      r31 * p.x + r32 * p.y + r33 * p.z + t3,
    );
  }
}

/// Pure-Dart ANSI IGES 5.3 (.iges, .igs) 3D CAD Parser with NURBS Surface Evaluation.
class IgesParser {
  /// Parse IGES from file path in background isolate
  static Future<Mesh3D> parseFromFile(String filePath) async {
    return compute(_parseIgesFileCompute, filePath);
  }

  static Mesh3D _parseIgesFileCompute(String filePath) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final name = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, name: name);
  }

  static Mesh3D parseFromBytes(Uint8List bytes, {String name = 'Model.iges'}) {
    final text = _decodeText(bytes);
    return _parseIgesText(text, name: name);
  }

  static String _decodeText(Uint8List bytes) {
    return UniversalEncodingService.decodeBytes(bytes);
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

    // Parse Parameter Data Section into map of line number -> concatenated parameter string
    final Map<int, String> parameterMap = {};
    int currentRecordStartLine = 1;
    final sb = StringBuffer();

    for (int lineIdx = 0; lineIdx < pLines.length; lineIdx++) {
      final pLine = pLines[lineIdx];
      final lineSeqMatch = RegExp(r'P\s*(\d+)\s*$', caseSensitive: false).firstMatch(pLine);
      final pLineNumber = lineSeqMatch != null
          ? (int.tryParse(lineSeqMatch.group(1)!) ?? (lineIdx + 1))
          : (lineIdx + 1);

      if (sb.isEmpty) {
        currentRecordStartLine = pLineNumber;
      }

      // Find where data columns end (usually column 64)
      String dataPart = pLine;
      if (lineSeqMatch != null) {
        dataPart = pLine.substring(0, lineSeqMatch.start).trimRight();
        final lastFieldMatch = RegExp(r'\s+\d+\s*$').firstMatch(dataPart);
        if (lastFieldMatch != null && lastFieldMatch.start >= 30) {
          dataPart = dataPart.substring(0, lastFieldMatch.start);
        }
      } else if (pLine.length >= 64) {
        dataPart = pLine.substring(0, 64);
      }

      sb.write(dataPart);
      if (dataPart.contains(';')) {
        final record = sb.toString();
        parameterMap[currentRecordStartLine] = record;
        sb.clear();
      }
    }
    if (sb.isNotEmpty) {
      parameterMap[currentRecordStartLine] = sb.toString();
    }

    // Parse Directory Entries
    final Map<int, _IgesDirectoryEntry> deMap = {};
    for (int i = 0; i + 1 < dLines.length; i += 2) {
      final line1 = dLines[i];
      final line2 = dLines[i + 1];
      if (line1.length < 16) continue;

      final deIndex = i + 1; // 1-based Directory Entry pointer: 1, 3, 5, ...
      final entityType = int.tryParse(line1.substring(0, line1.length >= 8 ? 8 : line1.length).trim()) ?? 0;
      final paramPtr = int.tryParse(line1.length >= 16 ? line1.substring(8, 16).trim() : '') ?? (i ~/ 2 + 1);

      int transformDe = 0;
      if (line1.length >= 56) {
        transformDe = int.tryParse(line1.substring(48, 56).trim()) ?? 0;
      }

      int formNum = 0;
      if (line2.length >= 40) {
        formNum = int.tryParse(line2.substring(32, 40).trim()) ?? 0;
      }

      deMap[deIndex] = _IgesDirectoryEntry(
        deIndex: deIndex,
        entityType: entityType,
        paramPtr: paramPtr,
        transformMatrixDe: transformDe,
        formNumber: formNum,
      );
    }

    // Pass 1: Parse Transformation Matrices (Entity 124)
    final Map<int, _IgesTransform> transforms = {};
    for (final de in deMap.values) {
      if (de.entityType == 124) {
        final paramData = parameterMap[de.paramPtr] ?? '';
        final params = _splitIgesParams(paramData);
        final offset = (params.isNotEmpty && params[0] == '124') ? 1 : 0;
        if (params.length >= offset + 12) {
          final r11 = _parseIgesDouble(params[offset], 1.0);
          final r12 = _parseIgesDouble(params[offset + 1], 0.0);
          final r13 = _parseIgesDouble(params[offset + 2], 0.0);
          final t1  = _parseIgesDouble(params[offset + 3], 0.0);
          final r21 = _parseIgesDouble(params[offset + 4], 0.0);
          final r22 = _parseIgesDouble(params[offset + 5], 1.0);
          final r23 = _parseIgesDouble(params[offset + 6], 0.0);
          final t2  = _parseIgesDouble(params[offset + 7], 0.0);
          final r31 = _parseIgesDouble(params[offset + 8], 0.0);
          final r32 = _parseIgesDouble(params[offset + 9], 0.0);
          final r33 = _parseIgesDouble(params[offset + 10], 1.0);
          final t3  = _parseIgesDouble(params[offset + 11], 0.0);
          transforms[de.deIndex] = _IgesTransform(
            r11: r11, r12: r12, r13: r13, t1: t1,
            r21: r21, r22: r22, r23: r23, t2: t2,
            r31: r31, r32: r32, r33: r33, t3: t3,
          );
        }
      }
    }

    final List<Triangle3D> triangles = [];
    final List<Vector3> allVertices = [];
    final Set<int> evaluatedSurfaces = {};

    // Helper to evaluate an Entity 128 Rational B-Spline Surface
    void evaluateNurbsSurface(int deIndex, List<String> params, _IgesTransform? transform) {
      final offset = (params.isNotEmpty && params[0] == '128') ? 1 : 0;
      if (params.length < offset + 9) return;

      final k1 = int.tryParse(params[offset]) ?? 0;
      final k2 = int.tryParse(params[offset + 1]) ?? 0;
      final m1 = int.tryParse(params[offset + 2]) ?? 0; // degree u
      final m2 = int.tryParse(params[offset + 3]) ?? 0; // degree v
      final prop1 = int.tryParse(params[offset + 4]) ?? 0; // closed u
      final prop2 = int.tryParse(params[offset + 5]) ?? 0; // closed v
      // prop3: rational flag

      final nuKnots = k1 + m1 + 2;
      final nvKnots = k2 + m2 + 2;

      int cur = offset + 9;
      final List<double> knotsU = [];
      for (int k = 0; k < nuKnots && cur < params.length; k++, cur++) {
        knotsU.add(_parseIgesDouble(params[cur], 0.0));
      }

      final List<double> knotsV = [];
      for (int k = 0; k < nvKnots && cur < params.length; k++, cur++) {
        knotsV.add(_parseIgesDouble(params[cur], 0.0));
      }

      final nu = k1 + 1;
      final nv = k2 + 1;

      // Weights grid W(i, j): i = 0..k1, j = 0..k2. First index varies fastest in IGES.
      final List<List<double>> weights = List.generate(
        nu,
        (_) => List.filled(nv, 1.0),
      );
      for (int j = 0; j < nv; j++) {
        for (int i = 0; i < nu; i++) {
          if (cur < params.length) {
            weights[i][j] = _parseIgesDouble(params[cur], 1.0);
            cur++;
          }
        }
      }

      // Control points grid P(i, j): X, Y, Z. First index varies fastest in IGES.
      final List<List<Vector3>> controlPoints = List.generate(
        nu,
        (_) => List.filled(nv, Vector3.zero),
      );
      for (int j = 0; j < nv; j++) {
        for (int i = 0; i < nu; i++) {
          if (cur + 2 < params.length) {
            final x = _parseIgesDouble(params[cur]);
            final y = _parseIgesDouble(params[cur + 1]);
            final z = _parseIgesDouble(params[cur + 2]);
            var pt = Vector3(x, y, z);
            if (transform != null) {
              pt = transform.transform(pt);
            }
            controlPoints[i][j] = pt;
            cur += 3;
          }
        }
      }

      // Parameter bounds U0, U1, V0, V1
      double? u0, u1, v0, v1;
      if (cur < params.length) u0 = _parseIgesDouble(params[cur++]);
      if (cur < params.length) u1 = _parseIgesDouble(params[cur++]);
      if (cur < params.length) v0 = _parseIgesDouble(params[cur++]);
      if (cur < params.length) v1 = _parseIgesDouble(params[cur++]);

      final nurbs = NurbsSurface(
        degreeU: m1,
        degreeV: m2,
        knotsU: knotsU,
        knotsV: knotsV,
        controlPoints: controlPoints,
        weights: weights,
        isClosedU: prop1 == 1,
        isClosedV: prop2 == 1,
      );

      final surfTriangles = nurbs.tessellate(
        domainUMin: u0,
        domainUMax: u1,
        domainVMin: v0,
        domainVMax: v1,
      );
      triangles.addAll(surfTriangles);
      evaluatedSurfaces.add(deIndex);
    }

    // Pass 2: Parse Entities and generate 3D Geometry
    for (final de in deMap.values) {
      final paramData = parameterMap[de.paramPtr] ?? parameterMap.values.elementAtOrNull(de.deIndex ~/ 2) ?? '';
      final params = _splitIgesParams(paramData);
      final transform = transforms[de.transformMatrixDe];

      // 1. Entity 128: Rational B-Spline Surface (NURBS Surface)
      if (de.entityType == 128) {
        if (!evaluatedSurfaces.contains(de.deIndex)) {
          evaluateNurbsSurface(de.deIndex, params, transform);
        }
      }
      // 2. Entity 144: Trimmed (Parametric) Surface
      else if (de.entityType == 144) {
        final offset = (params.isNotEmpty && params[0] == '144') ? 1 : 0;
        if (params.length > offset) {
          final surfaceDePtr = int.tryParse(params[offset]) ?? 0;
          if (surfaceDePtr > 0 && !evaluatedSurfaces.contains(surfaceDePtr)) {
            final targetDe = deMap[surfaceDePtr];
            if (targetDe != null && targetDe.entityType == 128) {
              final surfParams = _splitIgesParams(parameterMap[targetDe.paramPtr] ?? '');
              final surfTransform = transforms[targetDe.transformMatrixDe] ?? transform;
              evaluateNurbsSurface(surfaceDePtr, surfParams, surfTransform);
            }
          }
        }
      }
      // 3. Entity 126: Rational B-Spline Curve (NURBS Curve)
      else if (de.entityType == 126) {
        final offset = (params.isNotEmpty && params[0] == '126') ? 1 : 0;
        if (params.length >= offset + 7) {
          final k = int.tryParse(params[offset]) ?? 0;
          final m = int.tryParse(params[offset + 1]) ?? 0; // degree
          final nKnots = k + m + 2;

          int cur = offset + 7;
          final List<double> knots = [];
          for (int i = 0; i < nKnots && cur < params.length; i++, cur++) {
            knots.add(_parseIgesDouble(params[cur]));
          }

          final nCp = k + 1;
          final List<double> weights = [];
          for (int i = 0; i < nCp && cur < params.length; i++, cur++) {
            weights.add(_parseIgesDouble(params[cur], 1.0));
          }

          final List<Vector3> cps = [];
          for (int i = 0; i < nCp && cur + 2 < params.length; i++, cur += 3) {
            var pt = Vector3(
              _parseIgesDouble(params[cur]),
              _parseIgesDouble(params[cur + 1]),
              _parseIgesDouble(params[cur + 2]),
            );
            if (transform != null) {
              pt = transform.transform(pt);
            }
            cps.add(pt);
          }

          if (cps.length >= 2) {
            final curve = NurbsCurve3D(degree: m, knots: knots, controlPoints: cps, weights: weights);
            final curvePts = curve.samplePoints(samples: 24);
            for (int p = 0; p + 1 < curvePts.length; p++) {
              final p1 = curvePts[p];
              final p2 = curvePts[p + 1];
              const offsetVec = Vector3(0.05, 0.05, 0.05);
              triangles.add(Triangle3D(v0: p1, v1: p2, v2: p2 + offsetVec, isDoubleSided: true));
            }
          }
        }
      }
      // 4. Entity 106: Copious Data (Triangles / Point list / Line strip)
      else if (de.entityType == 106) {
        if (params.length >= 4) {
          final List<Vector3> pts = [];
          final startIdx = (params.length >= 6 && params[0] == '106') ? 3 : 1;
          for (int p = startIdx; p + 2 < params.length; p += 3) {
            final x = _parseIgesDouble(params[p]);
            final y = _parseIgesDouble(params[p + 1]);
            final z = _parseIgesDouble(params[p + 2]);
            var pt = Vector3(x, y, z);
            if (transform != null) {
              pt = transform.transform(pt);
            }
            pts.add(pt);
            allVertices.add(pt);
          }

          if (pts.length >= 3) {
            for (int t = 0; t + 2 < pts.length; t += 3) {
              triangles.add(Triangle3D(v0: pts[t], v1: pts[t + 1], v2: pts[t + 2], isDoubleSided: true));
            }
          }
        }
      }
      // 5. Entity 110: 3D Line
      else if (de.entityType == 110) {
        final offset = (params.isNotEmpty && params[0] == '110') ? 1 : 0;
        if (params.length >= offset + 6) {
          final x1 = _parseIgesDouble(params[offset]);
          final y1 = _parseIgesDouble(params[offset + 1]);
          final z1 = _parseIgesDouble(params[offset + 2]);
          final x2 = _parseIgesDouble(params[offset + 3]);
          final y2 = _parseIgesDouble(params[offset + 4]);
          final z2 = _parseIgesDouble(params[offset + 5]);

          var p1 = Vector3(x1, y1, z1);
          var p2 = Vector3(x2, y2, z2);
          if (transform != null) {
            p1 = transform.transform(p1);
            p2 = transform.transform(p2);
          }
          allVertices.add(p1);
          allVertices.add(p2);

          const offsetVec = Vector3(0.05, 0.05, 0.05);
          triangles.add(Triangle3D(v0: p1, v1: p2, v2: p2 + offsetVec, isDoubleSided: true));
        }
      }
      // 6. Entity 116: 3D Point
      else if (de.entityType == 116) {
        final offset = (params.isNotEmpty && params[0] == '116') ? 1 : 0;
        if (params.length >= offset + 3) {
          final x = _parseIgesDouble(params[offset]);
          final y = _parseIgesDouble(params[offset + 1]);
          final z = _parseIgesDouble(params[offset + 2]);
          var pt = Vector3(x, y, z);
          if (transform != null) {
            pt = transform.transform(pt);
          }
          allVertices.add(pt);
        }
      }
    }

    // Fallback: only if no structured triangles were formed from surfaces, lines or meshes
    if (triangles.isEmpty && allVertices.length >= 3) {
      for (int i = 0; i + 2 < allVertices.length; i += 3) {
        triangles.add(
          Triangle3D(
            v0: allVertices[i],
            v1: allVertices[i + 1],
            v2: allVertices[i + 2],
            isDoubleSided: true,
          ),
        );
      }
    }

    return Mesh3D(name: name, triangles: triangles);
  }

  static double _parseIgesDouble(String str, [double defaultValue = 0.0]) {
    if (str.isEmpty) return defaultValue;
    final normalized = str.replaceAll('D', 'E').replaceAll('d', 'e');
    return double.tryParse(normalized) ?? defaultValue;
  }

  static List<String> _splitIgesParams(String data) {
    final clean = data.replaceAll(';', '').trim();
    if (clean.isEmpty) return [];
    return clean.split(',').map((s) => s.trim()).toList();
  }
}
