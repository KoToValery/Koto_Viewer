import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import '../geometry/nurbs_surface.dart';
import '../models/mesh_3d.dart';
import 'ifc_parser.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

class _StepSubEntity {
  final String type;
  final String params;
  _StepSubEntity(this.type, this.params);
}

class _StepEntity {
  final int id;
  final List<_StepSubEntity> subEntities;
  _StepEntity(this.id, this.subEntities);

  bool hasType(String type) => subEntities.any((s) => s.type == type);
  _StepSubEntity? getSub(String type) =>
      subEntities.where((s) => s.type == type).firstOrNull;
}

class _StepAxisPlacement {
  final Vector3 origin;
  final Vector3 axis; // Z
  final Vector3 refDirection; // X

  const _StepAxisPlacement({
    required this.origin,
    required this.axis,
    required this.refDirection,
  });

  Vector3 get yAxis => axis.cross(refDirection).normalized();
}

class _StepBSplineCurve {
  final int degree;
  final List<int> controlPointIds;
  final List<double> knots;
  final List<double>? weights;
  final bool isClosed;

  const _StepBSplineCurve({
    required this.degree,
    required this.controlPointIds,
    required this.knots,
    this.weights,
    this.isClosed = false,
  });

  Vector3 evaluate(double u, Map<int, Vector3> pointMap) {
    if (controlPointIds.isEmpty) return Vector3.zero;
    final n = controlPointIds.length - 1;
    final p = degree;
    if (n < p || knots.length < n + p + 2) {
      return pointMap[controlPointIds.first] ?? Vector3.zero;
    }
    final clampedU = u.clamp(knots[p], knots[n + 1]);
    final s = NurbsSurface.findKnotSpan(n, p, clampedU, knots);

    final cp4 = List<Vector4>.generate(controlPointIds.length, (i) {
      final pt = pointMap[controlPointIds[i]] ?? Vector3.zero;
      final w = (weights != null && i < weights!.length) ? weights![i] : 1.0;
      return Vector4(pt.x * w, pt.y * w, pt.z * w, w);
    });

    final res4 = NurbsSurface.deBoor1D(p, cp4, knots, clampedU, s);
    return res4.toVector3();
  }

  double findParameterForPoint(Vector3 pt, Map<int, Vector3> pointMap) {
    if (controlPointIds.isEmpty) return 0.0;
    final n = controlPointIds.length - 1;
    final p = degree;
    if (n < p || knots.length < n + p + 2) return 0.0;
    final uMin = knots[p];
    final uMax = knots[n + 1];
    final span = uMax - uMin;
    if (span.abs() < 1e-12) return uMin;

    final ptStart = evaluate(uMin, pointMap);
    if ((ptStart - pt).lengthSquared < 1e-6) return uMin;

    final ptEnd = evaluate(uMax, pointMap);
    if ((ptEnd - pt).lengthSquared < 1e-6) return uMax;

    const steps = 36;
    var bestU = uMin;
    var bestDistSq = double.infinity;

    for (int i = 0; i <= steps; i++) {
      final u = uMin + span * (i / steps);
      final evalPt = evaluate(u, pointMap);
      final dSq = (evalPt - pt).lengthSquared;
      if (dSq < bestDistSq) {
        bestDistSq = dSq;
        bestU = u;
      }
    }

    final stepSize = span / steps;
    var low = (bestU - stepSize).clamp(uMin, uMax);
    var high = (bestU + stepSize).clamp(uMin, uMax);

    for (int iter = 0; iter < 12; iter++) {
      final m1 = low + (high - low) * (1.0 / 3.0);
      final m2 = low + (high - low) * (2.0 / 3.0);
      final d1 = (evaluate(m1, pointMap) - pt).lengthSquared;
      final d2 = (evaluate(m2, pointMap) - pt).lengthSquared;
      if (d1 < d2) {
        high = m2;
      } else {
        low = m1;
      }
    }

    return (low + high) / 2.0;
  }

  List<Vector3> sampleSegment(
    Vector3 vFrom,
    Vector3 vTo,
    Map<int, Vector3> pointMap, {
    int minSamples = 4,
    int maxSamples = 32,
  }) {
    if (controlPointIds.isEmpty) return [vFrom, vTo];
    final n = controlPointIds.length - 1;
    final p = degree;
    if (n < p || knots.length < n + p + 2) return [vFrom, vTo];

    final uFrom = findParameterForPoint(vFrom, pointMap);
    final uTo = findParameterForPoint(vTo, pointMap);

    final uMin = knots[p];
    final uMax = knots[n + 1];
    final totalSpan = (uMax - uMin).abs();
    final segSpan = (uTo - uFrom).abs();
    final ratio = totalSpan > 1e-12 ? (segSpan / totalSpan) : 1.0;

    final spans = math.max(1, n - p + 1);
    final count = (spans * 2 * ratio).round().clamp(minSamples, maxSamples);

    final pts = <Vector3>[vFrom];
    for (int i = 1; i < count; i++) {
      final t = i / count;
      final u = uFrom + (uTo - uFrom) * t;
      pts.add(evaluate(u, pointMap));
    }
    pts.add(vTo);
    return pts;
  }

  List<Vector3> sample(
    Map<int, Vector3> pointMap, {
    int samplesPerSpan = 2,
    int minSamples = 24,
    int maxSamples = 64,
  }) {
    if (controlPointIds.isEmpty) return [];
    if (controlPointIds.length == 1) {
      final pt = pointMap[controlPointIds.first];
      return pt != null ? [pt] : [];
    }
    final n = controlPointIds.length - 1;
    final p = degree;
    if (n < p || knots.length < n + p + 2) {
      return controlPointIds.map((id) => pointMap[id] ?? Vector3.zero).toList();
    }
    final uMin = knots[p];
    final uMax = knots[n + 1];
    if ((uMax - uMin).abs() < 1e-12) {
      return [pointMap[controlPointIds.first] ?? Vector3.zero];
    }

    final spans = math.max(1, n - p + 1);
    final count = (spans * samplesPerSpan).clamp(minSamples, maxSamples);
    final pts = <Vector3>[];
    for (int i = 0; i <= count; i++) {
      final t = i / count;
      final u = uMin + (uMax - uMin) * t;
      pts.add(evaluate(u, pointMap));
    }
    return pts;
  }
}


class _StepMatrix4 {
  final List<double> m;
  const _StepMatrix4(this.m);

  static const identity = _StepMatrix4([
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);

  static _StepMatrix4 fromPlacement(
    Vector3 origin,
    Vector3 axisZ,
    Vector3 refDirX,
  ) {
    final z = axisZ.normalized();
    final xProj = refDirX - z * refDirX.dot(z);
    final x = xProj.lengthSquared > 1e-9
        ? xProj.normalized()
        : (refDirX.lengthSquared > 1e-9
              ? refDirX.normalized()
              : const Vector3(1, 0, 0));
    final y = z.cross(x).normalized();

    return _StepMatrix4([
      x.x,
      y.x,
      z.x,
      origin.x,
      x.y,
      y.y,
      z.y,
      origin.y,
      x.z,
      y.z,
      z.z,
      origin.z,
      0,
      0,
      0,
      1,
    ]);
  }

  Vector3 transformPoint(Vector3 p) {
    return Vector3(
      m[0] * p.x + m[1] * p.y + m[2] * p.z + m[3],
      m[4] * p.x + m[5] * p.y + m[6] * p.z + m[7],
      m[8] * p.x + m[9] * p.y + m[10] * p.z + m[11],
    );
  }

  _StepMatrix4 multiply(_StepMatrix4 b) {
    final res = List<double>.filled(16, 0.0);
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += m[r * 4 + k] * b.m[k * 4 + c];
        }
        res[r * 4 + c] = sum;
      }
    }
    return _StepMatrix4(res);
  }
}

/// Pure-Dart ISO 10303-21 STEP (.step, .stp, .p21) 3D Mechanical CAD Parser with B-Rep, Assemblies, and NURBS.
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
    final cleanText = rawText.replaceAll(
      RegExp(r'/\*.*?\*/', dotAll: true),
      '',
    );

    // 2. Tokenize entities by ';'
    final rawEntities = cleanText.split(';');

    final List<_StepEntity> entityList = [];
    final Map<int, Vector3> pointMap = {};
    final Map<int, Vector3> directionMap = {};
    final Map<int, _StepAxisPlacement> placementMap = {};
    final Map<int, int> vertexMap = {}; // Vertex ID -> Point ID
    final Map<int, (int, double)> circleMap =
        {}; // Circle ID -> (Placement ID, radius)
    final Map<int, (int, int, int, bool)> edgeCurveMap =
        {}; // Edge ID -> (startV, endV, curveId, sameSense)
    final Map<int, (int, bool)> orientedEdgeMap =
        {}; // OrientedEdge ID -> (edgeCurveId, orientation)
    final Map<int, List<int>> edgeLoopMap =
        {}; // Loop ID -> List of OrientedEdge IDs
    final Map<int, List<int>> polyLoopMap = {}; // Loop ID -> List of Point IDs
    final Map<int, int> faceBoundMap = {}; // Bound ID -> Loop ID
    final Map<int, (List<int>, int, bool)> faceMap =
        {}; // Face ID -> (Loop IDs, surfaceId, sameSense)
    final Map<int, List<int>> shellMap = {}; // Shell ID -> List of Face IDs
    final Map<int, int> solidMap = {}; // Solid ID -> Shell ID
    final Map<int, List<int>> shapeRepMap = {}; // Rep ID -> List of item IDs
    final Map<int, (int, int)> transformMap =
        {}; // IDT ID -> (fromPlacementId, toPlacementId)
    final List<(int, int, int)> repRels =
        []; // (fromRepId, toRepId, transformId)
    final Map<int, Color> rgbMap = {}; // Colour ID -> Color
    final Map<int, Color> itemColorMap = {}; // Item ID -> Color
    final Map<int, int> curveBasisMap = {}; // Curve ID -> Basis Curve ID
    final Map<int, (int, double)> cylindricalSurfaceMap = {}; // Surf ID -> (Placement ID, radius)
    final Map<int, _StepBSplineCurve> bSplineCurveMap = {};
    final Map<int, (int, double)> vectorMap = {}; // Vector ID -> (dirId, length)
    final Map<int, (int, int)> extrusionSurfaceMap = {}; // Surf ID -> (curveId, vectorId)
    final Map<int, String> entityParamsMap = {};

    String? rootProductName;

    // Parse entity structure
    for (final raw in rawEntities) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final entityHeaderMatch = RegExp(
        r'^#(\d+)\s*=\s*(.*)$',
        dotAll: true,
      ).firstMatch(trimmed);
      if (entityHeaderMatch == null) continue;

      final id = int.tryParse(entityHeaderMatch.group(1)!) ?? 0;
      final rhs = entityHeaderMatch.group(2)!.trim();
      entityParamsMap[id] = rhs;

      final subs = _parseSubEntities(rhs);
      if (subs.isNotEmpty) {
        entityList.add(_StepEntity(id, subs));
      }
    }

    // Pass 1: Extract Products, Points, Directions, Placements, Vertices, Edges, Shells, Solids
    for (final ent in entityList) {
      for (final sub in ent.subEntities) {
        final type = sub.type;
        final params = sub.params;

        if (type == 'PRODUCT') {
          final nameMatch = RegExp(r"'(.*?)'").allMatches(params).toList();
          if (nameMatch.isNotEmpty) {
            final prodName = UniversalEncodingService.decodeIso10303String(
              nameMatch[0].group(1)!,
            );
            if (prodName.isNotEmpty) {
              rootProductName ??= prodName;
            }
          }
        } else if (type == 'CARTESIAN_POINT') {
          const fp = r'[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?';
          final coordMatch = RegExp(
            r'\(\s*(' +
                fp +
                r')\s*,\s*(' +
                fp +
                r')(?:,\s*(' +
                fp +
                r'))?\s*\)',
          ).firstMatch(params);
          if (coordMatch != null) {
            final x = double.tryParse(coordMatch.group(1)!) ?? 0.0;
            final y = double.tryParse(coordMatch.group(2)!) ?? 0.0;
            final z = double.tryParse(coordMatch.group(3) ?? '0.0') ?? 0.0;
            pointMap[ent.id] = Vector3(x, y, z);
          }
        } else if (type == 'DIRECTION') {
          const fp = r'[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?';
          final dirMatch = RegExp(
            r'\(\s*(' +
                fp +
                r')\s*,\s*(' +
                fp +
                r')(?:,\s*(' +
                fp +
                r'))?\s*\)',
          ).firstMatch(params);
          if (dirMatch != null) {
            final dx = double.tryParse(dirMatch.group(1)!) ?? 0.0;
            final dy = double.tryParse(dirMatch.group(2)!) ?? 0.0;
            final dz = double.tryParse(dirMatch.group(3) ?? '0.0') ?? 0.0;
            directionMap[ent.id] = Vector3(dx, dy, dz).normalized();
          }
        } else if (type == 'VERTEX_POINT') {
          final ptIdMatch = RegExp(r'#(\d+)').firstMatch(params);
          if (ptIdMatch != null) {
            vertexMap[ent.id] = int.tryParse(ptIdMatch.group(1)!) ?? 0;
          }
        } else if (type == 'CIRCLE') {
          const fp = r'[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?';
          final pMatch = RegExp(r'#(\d+)').firstMatch(params);
          final rMatch = RegExp(r',\s*(' + fp + r')\s*\)?$').firstMatch(params);
          if (pMatch != null) {
            final pId = int.tryParse(pMatch.group(1)!) ?? 0;
            final r = rMatch != null
                ? (double.tryParse(rMatch.group(1)!) ?? 1.0)
                : 1.0;
            circleMap[ent.id] = (pId, r);
          }
        } else if (type == 'TRIMMED_CURVE' || type == 'SURFACE_CURVE' || type == 'SEAM_CURVE') {
          final idMatch = RegExp(r'#(\d+)').firstMatch(params);
          if (idMatch != null) {
            curveBasisMap[ent.id] = int.tryParse(idMatch.group(1)!) ?? 0;
          }
        } else if (type == 'CYLINDRICAL_SURFACE') {
          const fp = r'[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?';
          final pMatch = RegExp(r'#(\d+)').firstMatch(params);
          final rMatch = RegExp(r',\s*(' + fp + r')\s*\)?$').firstMatch(params);
          if (pMatch != null) {
            final pId = int.tryParse(pMatch.group(1)!) ?? 0;
            final r = rMatch != null
                ? (double.tryParse(rMatch.group(1)!) ?? 1.0)
                : 1.0;
            cylindricalSurfaceMap[ent.id] = (pId, r);
          }
        } else if (type == 'VECTOR') {
          final idMatch = RegExp(r'#(\d+)').firstMatch(params);
          const fp = r'[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?';
          final lenMatch = RegExp(r',\s*(' + fp + r')\s*\)?$').firstMatch(params);
          if (idMatch != null) {
            final dId = int.tryParse(idMatch.group(1)!) ?? 0;
            final len = lenMatch != null
                ? (double.tryParse(lenMatch.group(1)!) ?? 1.0)
                : 1.0;
            vectorMap[ent.id] = (dId, len);
          }
        } else if (type == 'SURFACE_OF_LINEAR_EXTRUSION') {
          final idMatches = RegExp(r'#(\d+)').allMatches(params).toList();
          if (idMatches.length >= 2) {
            final cId = int.tryParse(idMatches[0].group(1)!) ?? 0;
            final vId = int.tryParse(idMatches[1].group(1)!) ?? 0;
            extrusionSurfaceMap[ent.id] = (cId, vId);
          }
        } else if (type == 'B_SPLINE_CURVE_WITH_KNOTS' ||
            type == 'B_SPLINE_CURVE' ||
            type == 'BEZIER_CURVE') {
          final curve = _parseBSplineCurve(params);
          if (curve != null) {
            List<double>? weights;
            final ratSub = ent.getSub('RATIONAL_B_SPLINE_CURVE');
            if (ratSub != null) {
              const fp = r'[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?';
              weights = RegExp(fp)
                  .allMatches(ratSub.params)
                  .map((m) => double.tryParse(m.group(0)!) ?? 1.0)
                  .toList();
            }
            bSplineCurveMap[ent.id] = weights != null
                ? _StepBSplineCurve(
                    degree: curve.degree,
                    controlPointIds: curve.controlPointIds,
                    knots: curve.knots,
                    weights: weights,
                    isClosed: curve.isClosed,
                  )
                : curve;
          }
        } else if (type == 'EDGE_CURVE') {
          final idMatches = RegExp(r'#(\d+)').allMatches(params).toList();
          final senseMatch = RegExp(r'\.(T|F)\.').firstMatch(params);
          final sameSense = senseMatch?.group(1) != 'F';
          if (idMatches.length >= 2) {
            final sV = int.tryParse(idMatches[0].group(1)!) ?? 0;
            final eV = int.tryParse(idMatches[1].group(1)!) ?? 0;
            final cId = idMatches.length > 2
                ? (int.tryParse(idMatches[2].group(1)!) ?? 0)
                : 0;
            edgeCurveMap[ent.id] = (sV, eV, cId, sameSense);
          }
        } else if (type == 'ORIENTED_EDGE') {
          final idMatch = RegExp(r'#(\d+)').firstMatch(params);
          final senseMatch = RegExp(r'\.(T|F)\.').firstMatch(params);
          final orientation = senseMatch?.group(1) != 'F';
          if (idMatch != null) {
            orientedEdgeMap[ent.id] = (
              int.tryParse(idMatch.group(1)!) ?? 0,
              orientation,
            );
          }
        } else if (type == 'EDGE_LOOP') {
          final idMatches = RegExp(r'#(\d+)').allMatches(params).toList();
          edgeLoopMap[ent.id] = idMatches
              .map((m) => int.tryParse(m.group(1)!) ?? 0)
              .toList();
        } else if (type == 'POLY_LOOP') {
          final idMatches = RegExp(r'#(\d+)').allMatches(params).toList();
          polyLoopMap[ent.id] = idMatches
              .map((m) => int.tryParse(m.group(1)!) ?? 0)
              .toList();
        } else if (type == 'FACE_BOUND' || type == 'FACE_OUTER_BOUND') {
          final idMatch = RegExp(r'#(\d+)').firstMatch(params);
          if (idMatch != null) {
            faceBoundMap[ent.id] = int.tryParse(idMatch.group(1)!) ?? 0;
          }
        } else if (type == 'ADVANCED_FACE' || type == 'FACE_SURFACE') {
          final boundsMatch = RegExp(r'\((.*?)\)', dotAll: true).firstMatch(params);
          final loopIds = <int>[];
          if (boundsMatch != null) {
            final bIds = RegExp(r'#(\d+)')
                .allMatches(boundsMatch.group(1)!)
                .map((m) => int.tryParse(m.group(1)!) ?? 0);
            for (final bId in bIds) {
              loopIds.add(faceBoundMap[bId] ?? bId);
            }
          }
          final rest = boundsMatch != null
              ? params.substring(boundsMatch.end)
              : params;
          final surfMatch = RegExp(r'#(\d+)').firstMatch(rest);
          final surfId = surfMatch != null
              ? (int.tryParse(surfMatch.group(1)!) ?? 0)
              : 0;
          final senseMatch = RegExp(r'\.(T|F)\.').firstMatch(rest);
          final sameSense = senseMatch?.group(1) != 'F';
          faceMap[ent.id] = (loopIds, surfId, sameSense);
        } else if (type == 'CLOSED_SHELL' || type == 'OPEN_SHELL') {
          final listMatch = RegExp(
            r'\((.*?)\)',
            dotAll: true,
          ).firstMatch(params);
          if (listMatch != null) {
            shellMap[ent.id] = RegExp(r'#(\d+)')
                .allMatches(listMatch.group(1)!)
                .map((m) => int.tryParse(m.group(1)!) ?? 0)
                .toList();
          }
        } else if (type == 'MANIFOLD_SOLID_BREP' ||
            type == 'BREP_WITH_VOIDS' ||
            type == 'FACETED_BREP') {
          final idMatch = RegExp(r'#(\d+)').firstMatch(params);
          if (idMatch != null) {
            solidMap[ent.id] = int.tryParse(idMatch.group(1)!) ?? 0;
          }
        } else if (type == 'SHAPE_REPRESENTATION' ||
            type == 'ADVANCED_BREP_SHAPE_REPRESENTATION') {
          final listMatch = RegExp(
            r'\((.*?)\)',
            dotAll: true,
          ).firstMatch(params);
          if (listMatch != null) {
            shapeRepMap[ent.id] = RegExp(r'#(\d+)')
                .allMatches(listMatch.group(1)!)
                .map((m) => int.tryParse(m.group(1)!) ?? 0)
                .toList();
          }
        } else if (type == 'ITEM_DEFINED_TRANSFORMATION') {
          final idMatches = RegExp(r'#(\d+)').allMatches(params).toList();
          if (idMatches.length >= 2) {
            transformMap[ent.id] = (
              int.tryParse(idMatches[0].group(1)!) ?? 0,
              int.tryParse(idMatches[1].group(1)!) ?? 0,
            );
          }
        } else if (type == 'COLOUR_RGB') {
          const fp = r'[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?';
          final numMatches = RegExp(fp).allMatches(params).toList();
          if (numMatches.length >= 3) {
            final r =
                (double.tryParse(numMatches[numMatches.length - 3].group(0)!) ??
                        0.8)
                    .clamp(0.0, 1.0);
            final g =
                (double.tryParse(numMatches[numMatches.length - 2].group(0)!) ??
                        0.8)
                    .clamp(0.0, 1.0);
            final b =
                (double.tryParse(numMatches[numMatches.length - 1].group(0)!) ??
                        0.8)
                    .clamp(0.0, 1.0);
            rgbMap[ent.id] = Color.from(alpha: 1.0, red: r, green: g, blue: b);
          }
        }
      }
    }

    if (rootProductName != null && rootProductName.isNotEmpty) {
      name = rootProductName;
    }

    // Resolve AXIS2_PLACEMENT_3D
    for (final ent in entityList) {
      final axisSub = ent.getSub('AXIS2_PLACEMENT_3D');
      if (axisSub != null) {
        final idMatches = RegExp(r'#(\d+)').allMatches(axisSub.params).toList();
        if (idMatches.isNotEmpty) {
          final origId = int.tryParse(idMatches[0].group(1)!) ?? 0;
          final axisId = idMatches.length > 1
              ? (int.tryParse(idMatches[1].group(1)!) ?? 0)
              : 0;
          final refId = idMatches.length > 2
              ? (int.tryParse(idMatches[2].group(1)!) ?? 0)
              : 0;

          final orig = pointMap[origId] ?? Vector3.zero;
          final axis = directionMap[axisId] ?? const Vector3(0, 0, 1);
          final ref = directionMap[refId] ?? const Vector3(1, 0, 0);
          placementMap[ent.id] = _StepAxisPlacement(
            origin: orig,
            axis: axis,
            refDirection: ref,
          );
        }
      }
    }

    // Resolve Representation Relationships / CDSR
    for (final ent in entityList) {
      for (final sub in ent.subEntities) {
        if (sub.type == 'REPRESENTATION_RELATIONSHIP' ||
            sub.type == 'SHAPE_REPRESENTATION_RELATIONSHIP') {
          final repMatches = RegExp(
            r'#(\d+)\s*,\s*#(\d+)',
          ).firstMatch(sub.params);
          if (repMatches != null) {
            final fromId = int.tryParse(repMatches.group(1)!) ?? 0;
            final toId = int.tryParse(repMatches.group(2)!) ?? 0;
            int transId = 0;
            final transSub = ent.getSub(
              'REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION',
            );
            if (transSub != null) {
              final tMatch = RegExp(r'#(\d+)').firstMatch(transSub.params);
              if (tMatch != null) transId = int.tryParse(tMatch.group(1)!) ?? 0;
            }
            if (fromId != 0 && toId != 0) {
              repRels.add((fromId, toId, transId));
            }
          }
        }
      }
    }

    // Resolve STYLED_ITEM colors
    Color? findColorInStyleChain(int styleId) {
      var cur = styleId;
      final visited = <int>{};
      while (visited.add(cur)) {
        if (rgbMap.containsKey(cur)) return rgbMap[cur];
        final raw = entityParamsMap[cur];
        if (raw == null) break;
        final idMatch = RegExp(r'#(\d+)').firstMatch(raw);
        if (idMatch == null) break;
        cur = int.tryParse(idMatch.group(1)!) ?? 0;
      }
      return null;
    }

    for (final ent in entityList) {
      final styledSub = ent.getSub('STYLED_ITEM');
      if (styledSub != null) {
        final idMatches = RegExp(
          r'#(\d+)',
        ).allMatches(styledSub.params).toList();
        if (idMatches.length >= 2) {
          final styleId = int.tryParse(idMatches[0].group(1)!) ?? 0;
          final itemId = int.tryParse(idMatches.last.group(1)!) ?? 0;
          final col = findColorInStyleChain(styleId);
          if (col != null) {
            itemColorMap[itemId] = col;
          }
        }
      }
    }

    final List<Triangle3D> triangles = [];

    final handledPolyLoops = <int>{};

    // Helper to extract 3D points from an EDGE_LOOP or POLY_LOOP
    List<Vector3> getLoopPoints(int loopId) {
      if (polyLoopMap.containsKey(loopId)) {
        handledPolyLoops.add(loopId);
        final pIds = polyLoopMap[loopId]!;
        return pIds
            .map(
              (pid) =>
                  pointMap[pid] ??
                  (vertexMap.containsKey(pid)
                      ? pointMap[vertexMap[pid]!]
                      : null),
            )
            .whereType<Vector3>()
            .toList();
      }

      final oEdgeIds = edgeLoopMap[loopId];
      if (oEdgeIds == null || oEdgeIds.isEmpty) return [];

      int resolveBasisCurve(int id) {
        var cur = id;
        final visited = <int>{};
        while (curveBasisMap.containsKey(cur) && visited.add(cur)) {
          cur = curveBasisMap[cur]!;
        }
        return cur;
      }

      final pts = <Vector3>[];
      for (final oeId in oEdgeIds) {
        final oe = orientedEdgeMap[oeId];
        if (oe == null) continue;
        final edgeId = oe.$1;
        final orientation = oe.$2;
        final ec = edgeCurveMap[edgeId];
        if (ec == null) continue;
        final startV = ec.$1;
        final endV = ec.$2;
        final rawCurveId = ec.$3;
        final sameSense = ec.$4;
        final curveId = resolveBasisCurve(rawCurveId);

        final effOrientation = (orientation == sameSense);
        final startPt = pointMap[vertexMap[startV]] ?? pointMap[startV];
        final endPt = pointMap[vertexMap[endV]] ?? pointMap[endV];
        if (startPt == null || endPt == null) continue;

        final vFrom = effOrientation ? startPt : endPt;
        final vTo = effOrientation ? endPt : startPt;

        // Sample B-SPLINE curves delimited precisely between vFrom and vTo
        final bSpline = bSplineCurveMap[curveId];
        if (bSpline != null) {
          final sampled = bSpline.sampleSegment(vFrom, vTo, pointMap);
          for (final p in sampled) {
            if (pts.isEmpty || (pts.last - p).lengthSquared > 1e-8) {
              pts.add(p);
            }
          }
          continue;
        }

        // Sample CIRCLE arcs for smooth cylindrical curves
        final circleData = circleMap[curveId];
        if (circleData != null) {
          final (pId, radius) = circleData;
          final placement = placementMap[pId];
          if (placement != null) {
            final orig = placement.origin;
            final z = placement.axis.normalized();
            final refDir = placement.refDirection;
            final xProj = refDir - z * refDir.dot(z);
            final x = xProj.lengthSquared > 1e-9
                ? xProj.normalized()
                : const Vector3(1, 0, 0);
            final y = z.cross(x).normalized();

            if ((vFrom - vTo).lengthSquared <= 1e-6) {
              // Full circle with single vertex
              const fullSamples = 24;
              for (int s = 0; s < fullSamples; s++) {
                final ang = (s / fullSamples) * 2 * math.pi;
                pts.add(
                  orig +
                      x * (radius * math.cos(ang)) +
                      y * (radius * math.sin(ang)),
                );
              }
              continue;
            } else {
              // Circle arc between vFrom and vTo
              final dFrom = vFrom - orig;
              final dTo = vTo - orig;
              var a0 = math.atan2(dFrom.dot(y), dFrom.dot(x));
              var a1 = math.atan2(dTo.dot(y), dTo.dot(x));

              var diff = a1 - a0;
              if (!effOrientation) {
                while (diff > 0) {
                  diff -= 2 * math.pi;
                }
                while (diff < -2 * math.pi) {
                  diff += 2 * math.pi;
                }
              } else {
                while (diff < 0) {
                  diff += 2 * math.pi;
                }
                while (diff > 2 * math.pi) {
                  diff -= 2 * math.pi;
                }
              }

              if (pts.isEmpty || (pts.last - vFrom).lengthSquared > 1e-8) {
                pts.add(vFrom);
              }
              const samples = 8;
              for (int s = 1; s < samples; s++) {
                final t = s / samples;
                final ang = a0 + diff * t;
                pts.add(
                  orig +
                      x * (radius * math.cos(ang)) +
                      y * (radius * math.sin(ang)),
                );
              }
              continue;
            }
          }
        }

        if (pts.isEmpty || (pts.last - vFrom).lengthSquared > 1e-8) {
          pts.add(vFrom);
        }
      }

      return pts;
    }

    // Triangulate a single face
    List<Triangle3D> triangulateFace(
      int faceId,
      _StepMatrix4 transform, [
      Color? defaultColor,
    ]) {
      final face = faceMap[faceId];
      if (face == null) return [];
      final loopIds = face.$1;
      final surfId = face.$2;
      if (loopIds.isEmpty) return [];

      final faceColor = itemColorMap[faceId] ?? defaultColor;
      final result = <Triangle3D>[];

      final isCylindrical = cylindricalSurfaceMap.containsKey(surfId);
      final cylData = isCylindrical ? cylindricalSurfaceMap[surfId] : null;
      final cylPlacement = cylData != null ? placementMap[cylData.$1] : null;

      final isExtrusion = extrusionSurfaceMap.containsKey(surfId);
      final extData = isExtrusion ? extrusionSurfaceMap[surfId] : null;

      Vector3? extrusionAxis;
      if (isExtrusion && extData != null) {
        final (_, vId) = extData;
        if (vectorMap.containsKey(vId)) {
          final (dId, len) = vectorMap[vId]!;
          final d = directionMap[dId] ?? const Vector3(0, 1, 0);
          extrusionAxis = d * len;
        } else if (directionMap.containsKey(vId)) {
          extrusionAxis = directionMap[vId]!;
        }
      }

      for (final rawLoopId in loopIds) {
        final loopId = faceBoundMap[rawLoopId] ?? rawLoopId;
        final pts = getLoopPoints(loopId);
        if (pts.length < 3) continue;

        final worldPts = pts.map((p) => transform.transformPoint(p)).toList();
        final n = worldPts.length;

        final isExtrudedSurface = (isCylindrical && cylPlacement != null) ||
            (isExtrusion && extrusionAxis != null);

        // If face is on a CYLINDRICAL_SURFACE or SURFACE_OF_LINEAR_EXTRUSION with two rim profiles:
        if (isExtrudedSurface && n >= 6) {
          final Vector3 axisW;
          final Vector3 origW;

          if (isCylindrical && cylPlacement != null) {
            axisW = (transform.transformPoint(cylPlacement.origin + cylPlacement.axis) -
                    transform.transformPoint(cylPlacement.origin))
                .normalized();
            origW = transform.transformPoint(cylPlacement.origin);
          } else {
            axisW = (transform.transformPoint(extrusionAxis!) -
                    transform.transformPoint(Vector3.zero))
                .normalized();
            origW = worldPts.first;
          }

          final heights = worldPts.map((p) => (p - origW).dot(axisW)).toList();
          final minH = heights.reduce(math.min);
          final maxH = heights.reduce(math.max);
          final hSpan = maxH - minH;

          if (hSpan > 1e-4) {
            final tolH = hSpan * 0.05;

            List<Vector3> extractContiguousRun(bool Function(int i) predicate) {
              int startFalse = -1;
              for (int i = 0; i < n; i++) {
                if (!predicate(i)) {
                  startFalse = i;
                  break;
                }
              }
              if (startFalse == -1) {
                return List<Vector3>.from(worldPts);
              }

              final run = <Vector3>[];
              int bestStart = -1;
              int bestLen = 0;
              int curStart = -1;
              int curLen = 0;

              for (int step = 0; step < n; step++) {
                final idx = (startFalse + 1 + step) % n;
                if (predicate(idx)) {
                  if (curLen == 0) curStart = idx;
                  curLen++;
                  if (curLen > bestLen) {
                    bestLen = curLen;
                    bestStart = curStart;
                  }
                } else {
                  curLen = 0;
                }
              }

              if (bestLen > 0) {
                for (int k = 0; k < bestLen; k++) {
                  run.add(worldPts[(bestStart + k) % n]);
                }
              }
              return run;
            }

            final topPts = extractContiguousRun((i) => (maxH - heights[i]) <= tolH);
            final botPts = extractContiguousRun((i) => (heights[i] - minH) <= tolH);

            if (botPts.length >= 2 && topPts.length >= 2) {
              // Match orientation of topPts to botPts if reversed along loop
              final d00 = (botPts.first - topPts.first).lengthSquared;
              final d0N = (botPts.first - topPts.last).lengthSquared;
              final orderedTop = d0N < d00 ? topPts.reversed.toList() : topPts;

              List<Vector3> resample(List<Vector3> pts, int targetCount) {
                if (pts.length == targetCount) return pts;
                if (pts.length < 2) return pts;
                final cumDist = <double>[0.0];
                for (int i = 0; i < pts.length - 1; i++) {
                  cumDist.add(cumDist.last + (pts[i + 1] - pts[i]).length);
                }
                final totalLen = cumDist.last;
                if (totalLen < 1e-9) return List.filled(targetCount, pts.first);

                final res = <Vector3>[pts.first];
                int seg = 0;
                for (int i = 1; i < targetCount - 1; i++) {
                  final targetDist = totalLen * (i / (targetCount - 1));
                  while (seg < cumDist.length - 2 && cumDist[seg + 1] < targetDist) {
                    seg++;
                  }
                  final segLen = cumDist[seg + 1] - cumDist[seg];
                  final t = segLen > 1e-9 ? (targetDist - cumDist[seg]) / segLen : 0.0;
                  res.add(pts[seg] + (pts[seg + 1] - pts[seg]) * t);
                }
                res.add(pts.last);
                return res;
              }

              final mSteps = math.max(botPts.length, orderedTop.length);
              final resBot = resample(botPts, mSteps);
              final resTop = resample(orderedTop, mSteps);

              for (int i = 0; i < mSteps - 1; i++) {
                final b0 = resBot[i];
                final b1 = resBot[i + 1];
                final t0 = resTop[i];
                final t1 = resTop[i + 1];

                if ((b0 - b1).lengthSquared > 1e-8 && (t0 - t1).lengthSquared > 1e-8) {
                  result.add(Triangle3D(v0: b0, v1: b1, v2: t1, color: faceColor, isDoubleSided: true));
                  result.add(Triangle3D(v0: b0, v1: t1, v2: t0, color: faceColor, isDoubleSided: true));
                } else if ((b0 - b1).lengthSquared > 1e-8) {
                  result.add(Triangle3D(v0: b0, v1: b1, v2: t0, color: faceColor, isDoubleSided: true));
                } else if ((t0 - t1).lengthSquared > 1e-8) {
                  result.add(Triangle3D(v0: b0, v1: t1, v2: t0, color: faceColor, isDoubleSided: true));
                }
              }
              continue; // Extruded/cylindrical face triangulated successfully!
            }
          }
        }

        if (n == 3) {
          final p0 = worldPts[0];
          final p1 = worldPts[1];
          final p2 = worldPts[2];
          if ((p1 - p0).cross(p2 - p0).lengthSquared > 1e-8) {
            result.add(
              Triangle3D(
                v0: p0,
                v1: p1,
                v2: p2,
                color: faceColor,
                isDoubleSided: true,
              ),
            );
          }
        } else if (n == 4) {
          final p0 = worldPts[0];
          final p1 = worldPts[1];
          final p2 = worldPts[2];
          final p3 = worldPts[3];
          if ((p1 - p0).cross(p2 - p0).lengthSquared > 1e-8) {
            result.add(
              Triangle3D(
                v0: p0,
                v1: p1,
                v2: p2,
                color: faceColor,
                isDoubleSided: true,
              ),
            );
          }
          if ((p2 - p0).cross(p3 - p0).lengthSquared > 1e-8) {
            result.add(
              Triangle3D(
                v0: p0,
                v1: p2,
                v2: p3,
                color: faceColor,
                isDoubleSided: true,
              ),
            );
          }
        } else {
          // Robust Ear-Clipping triangulation for planar/concave CAD faces
          final polyTris = IfcParser.triangulatePolygon3D(worldPts, color: faceColor);
          if (polyTris.isNotEmpty) {
            result.addAll(polyTris.map((t) => Triangle3D(
                  v0: t.v0,
                  v1: t.v1,
                  v2: t.v2,
                  color: faceColor,
                  isDoubleSided: true,
                )));
          } else {
            // Centroid fan fallback for convex polygons
            Vector3 centroid = Vector3.zero;
            for (final p in worldPts) {
              centroid = centroid + p;
            }
            centroid = centroid * (1.0 / n);

            for (int i = 0; i < n; i++) {
              final p0 = worldPts[i];
              final p1 = worldPts[(i + 1) % n];
              if ((p1 - p0).lengthSquared < 1e-8) continue;
              final edge1 = p0 - centroid;
              final edge2 = p1 - centroid;
              if (edge1.cross(edge2).lengthSquared < 1e-8) continue;
              result.add(
                Triangle3D(
                  v0: centroid,
                  v1: p0,
                  v2: p1,
                  color: faceColor,
                  isDoubleSided: true,
                ),
              );
            }
          }
        }

      }

      return result;
    }

    // Triangulate a shape representation
    List<Triangle3D> triangulateShapeRep(int repId, _StepMatrix4 transform) {
      final itemIds = shapeRepMap[repId] ?? [];
      final result = <Triangle3D>[];

      for (final itemId in itemIds) {
        final shellId = solidMap[itemId] ?? itemId;
        final faceIds =
            shellMap[shellId] ?? (faceMap.containsKey(itemId) ? [itemId] : []);

        final defaultCol =
            itemColorMap[itemId] ??
            (shellId != itemId ? itemColorMap[shellId] : null);

        for (final fId in faceIds) {
          result.addAll(triangulateFace(fId, transform, defaultCol));
        }
      }

      return result;
    }

    // Build assembly transformation graph
    final Map<int, List<(int, _StepMatrix4)>> parentMap = {};
    for (final rel in repRels) {
      final (fromRep, toRep, transId) = rel;
      final trans = transformMap[transId];
      _StepMatrix4 matrix = _StepMatrix4.identity;
      if (trans != null) {
        final (_, toPId) = trans;
        final targetP = placementMap[toPId];
        if (targetP != null) {
          matrix = _StepMatrix4.fromPlacement(
            targetP.origin,
            targetP.axis,
            targetP.refDirection,
          );
        }
      }
      parentMap.putIfAbsent(fromRep, () => []).add((toRep, matrix));
    }

    List<_StepMatrix4> getTransformsToRoot(int repId, [Set<int>? visited]) {
      final currentVisited = visited ?? <int>{};
      if (!currentVisited.add(repId)) return [_StepMatrix4.identity];

      final parents = parentMap[repId];
      if (parents == null || parents.isEmpty) {
        return [_StepMatrix4.identity];
      }

      final result = <_StepMatrix4>[];
      for (final (parentRep, mat) in parents) {
        final parentMats = getTransformsToRoot(
          parentRep,
          Set<int>.from(currentVisited),
        );
        for (final pMat in parentMats) {
          result.add(pMat.multiply(mat));
        }
      }
      return result;
    }

    // Triangulate all shape representations with solids/faces
    for (final repId in shapeRepMap.keys) {
      final items = shapeRepMap[repId]!;
      final hasGeometry = items.any(
        (id) =>
            solidMap.containsKey(id) ||
            shellMap.containsKey(id) ||
            faceMap.containsKey(id),
      );
      if (hasGeometry) {
        final matrices = getTransformsToRoot(repId);
        for (final mat in matrices) {
          triangles.addAll(triangulateShapeRep(repId, mat));
        }
      }
    }

    // If no shape representations were matched, process direct unattached faces
    if (triangles.isEmpty && faceMap.isNotEmpty) {
      for (final faceId in faceMap.keys) {
        triangles.addAll(triangulateFace(faceId, _StepMatrix4.identity));
      }
    }

    // Resolve remaining POLY_LOOPs (Faceted BREP)
    if (polyLoopMap.isNotEmpty) {
      for (final entry in polyLoopMap.entries) {
        if (handledPolyLoops.contains(entry.key)) continue;
        final loopPts = <Vector3>[];
        for (final refId in entry.value) {
          if (pointMap.containsKey(refId)) {
            loopPts.add(pointMap[refId]!);
          } else if (vertexMap.containsKey(refId)) {
            final ptId = vertexMap[refId]!;
            if (pointMap.containsKey(ptId)) {
              loopPts.add(pointMap[ptId]!);
            }
          }
        }
        if (loopPts.length >= 3) {
          final p0 = loopPts[0];
          for (int i = 1; i < loopPts.length - 1; i++) {
            triangles.add(
              Triangle3D(
                v0: p0,
                v1: loopPts[i],
                v2: loopPts[i + 1],
                isDoubleSided: true,
              ),
            );
          }
        }
      }
    }

    // Evaluate standalone NURBS surfaces (when no B-Rep solids were evaluated)
    if (triangles.isEmpty) {
      for (final ent in entityList) {
        final hasNurbsSurface =
            ent.hasType('B_SPLINE_SURFACE_WITH_KNOTS') ||
            ent.hasType('B_SPLINE_SURFACE') ||
            ent.hasType('RATIONAL_B_SPLINE_SURFACE') ||
            ent.hasType('BEZIER_SURFACE');

        if (hasNurbsSurface) {
          _evaluateStepNurbsSurface(ent, pointMap, triangles);
        }
      }
    }

    // Wireframe edge curves fallback if only curves exist
    if (triangles.isEmpty && edgeCurveMap.isNotEmpty) {
      for (final ec in edgeCurveMap.values) {
        final p1 = pointMap[vertexMap[ec.$1]];
        final p2 = pointMap[vertexMap[ec.$2]];
        if (p1 != null && p2 != null) {
          final offset = const Vector3(0.05, 0.05, 0.05);
          triangles.add(
            Triangle3D(v0: p1, v1: p2, v2: p2 + offset, isDoubleSided: true),
          );
          triangles.add(
            Triangle3D(
              v0: p1,
              v1: p2 + offset,
              v2: p1 + offset,
              isDoubleSided: true,
            ),
          );
        }
      }
    }

    return Mesh3D(name: name, triangles: triangles);
  }

  static void _evaluateStepNurbsSurface(
    _StepEntity ent,
    Map<int, Vector3> pointMap,
    List<Triangle3D> triangles,
  ) {
    int uDeg = 3;
    int vDeg = 3;

    for (final sub in ent.subEntities) {
      final degMatch = RegExp(r'\b(\d+)\s*,\s*(\d+)\b').firstMatch(sub.params);
      if (degMatch != null) {
        uDeg = int.tryParse(degMatch.group(1)!) ?? 3;
        vDeg = int.tryParse(degMatch.group(2)!) ?? 3;
        break;
      }
    }

    List<List<int>> cpIdMatrix = [];
    for (final sub in ent.subEntities) {
      final matrix = _parse2DIdList(sub.params);
      if (matrix.isNotEmpty) {
        cpIdMatrix = matrix;
        break;
      }
    }
    if (cpIdMatrix.isEmpty) return;

    final List<List<Vector3>> cpGrid = [];
    for (final row in cpIdMatrix) {
      final List<Vector3> cpRow = [];
      for (final id in row) {
        cpRow.add(pointMap[id] ?? Vector3.zero);
      }
      cpGrid.add(cpRow);
    }
    if (cpGrid.isEmpty || cpGrid[0].isEmpty) return;

    List<double> knotsU = [];
    List<double> knotsV = [];

    for (final sub in ent.subEntities) {
      if (sub.type == 'B_SPLINE_SURFACE_WITH_KNOTS') {
        final numLists = _parseNumberLists(sub.params);
        if (numLists.length >= 4) {
          knotsU = _expandKnots(numLists[0], numLists[2]);
          knotsV = _expandKnots(numLists[1], numLists[3]);
          break;
        }
      }
    }

    List<List<double>>? weightsGrid;
    for (final sub in ent.subEntities) {
      if (sub.type == 'RATIONAL_B_SPLINE_SURFACE') {
        final wLists = _parseNumberLists(sub.params);
        if (wLists.isNotEmpty) {
          weightsGrid = wLists;
          break;
        }
      }
    }

    final nurbs = NurbsSurface(
      degreeU: uDeg,
      degreeV: vDeg,
      knotsU: knotsU,
      knotsV: knotsV,
      controlPoints: cpGrid,
      weights: weightsGrid,
    );

    final surfTris = nurbs.tessellate();
    triangles.addAll(surfTris);
  }

  static _StepBSplineCurve? _parseBSplineCurve(String params) {
    final lists = <String>[];
    int depth = 0;
    int start = -1;
    for (int i = 0; i < params.length; i++) {
      if (params[i] == '(') {
        if (depth == 0) start = i + 1;
        depth++;
      } else if (params[i] == ')') {
        depth--;
        if (depth == 0 && start != -1) {
          lists.add(params.substring(start, i));
          start = -1;
        }
      }
    }

    if (lists.isEmpty) return null;

    final cpMatches = RegExp(r'#(\d+)').allMatches(lists[0]);
    final cpIds = cpMatches.map((m) => int.tryParse(m.group(1)!) ?? 0).toList();
    if (cpIds.isEmpty) return null;

    final firstParen = params.indexOf('(');
    final prefix = firstParen > 0 ? params.substring(0, firstParen) : '';
    final degMatch = RegExp(r',\s*(\d+)\s*$').firstMatch(prefix.trim());
    final degree = int.tryParse(degMatch?.group(1) ?? '') ?? 3;

    List<double> knots = [];
    if (lists.length >= 3) {
      final mults = RegExp(r'\d+')
          .allMatches(lists[1])
          .map((m) => double.tryParse(m.group(0)!) ?? 1.0)
          .toList();
      const fp = r'[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?';
      final rawKnots = RegExp(fp)
          .allMatches(lists[2])
          .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
          .toList();

      knots = _expandKnots(mults, rawKnots);
    } else if (lists.length == 2) {
      const fp = r'[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?';
      knots = RegExp(fp)
          .allMatches(lists[1])
          .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
          .toList();
    }

    if (knots.length < cpIds.length + degree + 1) {
      knots = NurbsSurface.createClampedKnotVector(cpIds.length - 1, degree);
    }

    return _StepBSplineCurve(
      degree: degree,
      controlPointIds: cpIds,
      knots: knots,
    );
  }

  static List<_StepSubEntity> _parseSubEntities(String rhs) {
    final trimmed = rhs.trim();
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      return _parseComplexContent(
        trimmed.substring(1, trimmed.length - 1).trim(),
      );
    }

    final openIdx = trimmed.indexOf('(');
    if (openIdx > 0 && trimmed.endsWith(')')) {
      final type = trimmed.substring(0, openIdx).trim().toUpperCase();
      final params = trimmed.substring(openIdx + 1, trimmed.length - 1).trim();
      return [_StepSubEntity(type, params)];
    }

    return [];
  }

  static List<_StepSubEntity> _parseComplexContent(String content) {
    final List<_StepSubEntity> subs = [];
    int i = 0;
    while (i < content.length) {
      while (i < content.length && content.codeUnitAt(i) <= 32) {
        i++;
      }
      if (i >= content.length) break;

      final startType = i;
      while (i < content.length &&
          (RegExp(r'[A-Za-z0-9_]').hasMatch(content[i]))) {
        i++;
      }
      final type = content.substring(startType, i).toUpperCase();

      while (i < content.length && content.codeUnitAt(i) <= 32) {
        i++;
      }
      if (i >= content.length || content[i] != '(') {
        if (type.isNotEmpty) subs.add(_StepSubEntity(type, ''));
        continue;
      }
      i++; // consume '('

      int depth = 1;
      final startParam = i;
      while (i < content.length && depth > 0) {
        if (content[i] == '(') {
          depth++;
        } else if (content[i] == ')') {
          depth--;
        }
        i++;
      }
      final endParam = depth == 0 ? i - 1 : i;
      final params = content.substring(startParam, endParam).trim();
      subs.add(_StepSubEntity(type, params));
    }
    return subs;
  }

  static List<List<int>> _parse2DIdList(String text) {
    final List<List<int>> matrix = [];
    final outerMatch = RegExp(
      r'\(\s*(\(.*\))\s*\)',
      dotAll: true,
    ).firstMatch(text);
    final content = outerMatch != null ? outerMatch.group(1)! : text;

    final rowMatches = RegExp(r'\(([^()]+)\)').allMatches(content);
    for (final rm in rowMatches) {
      final rowContent = rm.group(1)!;
      final List<int> row = [];
      final idMatches = RegExp(r'#(\d+)').allMatches(rowContent);
      for (final im in idMatches) {
        final ptId = int.tryParse(im.group(1)!) ?? 0;
        row.add(ptId);
      }
      if (row.isNotEmpty) {
        matrix.add(row);
      }
    }
    return matrix;
  }

  static List<List<double>> _parseNumberLists(String text) {
    final List<List<double>> lists = [];
    final matches = RegExp(r'\(([0-9eE\s,.\-+]+)\)').allMatches(text);
    for (final m in matches) {
      final str = m.group(1)!;
      final parts = str.split(',');
      final List<double> nums = [];
      for (final p in parts) {
        final trimmed = p.trim();
        if (trimmed.isNotEmpty) {
          final val = double.tryParse(trimmed);
          if (val != null) nums.add(val);
        }
      }
      if (nums.isNotEmpty) lists.add(nums);
    }
    return lists;
  }

  static List<double> _expandKnots(List<double> mults, List<double> knots) {
    final List<double> full = [];
    for (int i = 0; i < knots.length && i < mults.length; i++) {
      final count = mults[i].round();
      final val = knots[i];
      for (int c = 0; c < count; c++) {
        full.add(val);
      }
    }
    return full;
  }
}
