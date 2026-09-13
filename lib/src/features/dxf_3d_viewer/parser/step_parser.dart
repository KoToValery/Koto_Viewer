import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../geometry/nurbs_surface.dart';
import '../models/mesh_3d.dart';
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
  _StepSubEntity? getSub(String type) => subEntities.where((s) => s.type == type).firstOrNull;
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

/// Pure-Dart ISO 10303-21 STEP (.step, .stp, .p21) 3D Mechanical CAD Parser with NURBS Surface Evaluation.
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

    final List<_StepEntity> entityList = [];
    final Map<int, Vector3> pointMap = {};
    final Map<int, Vector3> directionMap = {};
    final Map<int, _StepAxisPlacement> placementMap = {};
    final Map<int, int> vertexMap = {}; // Vertex ID -> Point ID
    final Map<int, List<int>> polyLoopMap = {}; // Loop ID -> List of Point IDs
    final Map<int, List<int>> edgeCurveMap = {}; // Edge ID -> [StartVertexId, EndVertexId]
    final List<Triangle3D> triangles = [];
    final List<Vector3> allPoints = [];

    // Parse entity structure
    for (final raw in rawEntities) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final entityHeaderMatch = RegExp(r'^#(\d+)\s*=\s*(.*)$', dotAll: true).firstMatch(trimmed);
      if (entityHeaderMatch == null) continue;

      final id = int.tryParse(entityHeaderMatch.group(1)!) ?? 0;
      final rhs = entityHeaderMatch.group(2)!.trim();

      final subs = _parseSubEntities(rhs);
      if (subs.isNotEmpty) {
        entityList.add(_StepEntity(id, subs));
      }
    }

    // Pass 1: Extract Products, Points, Directions, Placements, Vertices, PolyLoops, Edges
    for (final ent in entityList) {
      for (final sub in ent.subEntities) {
        final type = sub.type;
        final params = sub.params;

        if (type == 'PRODUCT') {
          final nameMatch = RegExp(r"'(.*?)'").allMatches(params).toList();
          if (nameMatch.isNotEmpty) {
            final prodName = UniversalEncodingService.decodeIso10303String(nameMatch[0].group(1)!);
            if (prodName.isNotEmpty) name = prodName;
          }
        }
        // A. CARTESIAN_POINT
        else if (type == 'CARTESIAN_POINT') {
          final coordMatch = RegExp(r'\(\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)\s*,\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)(?:\s*,\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?))?\s*\)').firstMatch(params);
          if (coordMatch != null) {
            final x = double.tryParse(coordMatch.group(1)!) ?? 0.0;
            final y = double.tryParse(coordMatch.group(2)!) ?? 0.0;
            final z = double.tryParse(coordMatch.group(3) ?? '0.0') ?? 0.0;
            final pt = Vector3(x, y, z);
            pointMap[ent.id] = pt;
            allPoints.add(pt);
          }
        }
        // B. DIRECTION
        else if (type == 'DIRECTION') {
          final dirMatch = RegExp(r'\(\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)\s*,\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)(?:\s*,\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?))?\s*\)').firstMatch(params);
          if (dirMatch != null) {
            final dx = double.tryParse(dirMatch.group(1)!) ?? 0.0;
            final dy = double.tryParse(dirMatch.group(2)!) ?? 0.0;
            final dz = double.tryParse(dirMatch.group(3) ?? '0.0') ?? 0.0;
            directionMap[ent.id] = Vector3(dx, dy, dz).normalized();
          }
        }
        // C. VERTEX_POINT
        else if (type == 'VERTEX_POINT') {
          final ptIdMatch = RegExp(r'#(\d+)').firstMatch(params);
          if (ptIdMatch != null) {
            final ptId = int.tryParse(ptIdMatch.group(1)!) ?? 0;
            vertexMap[ent.id] = ptId;
          }
        }
        // D. POLY_LOOP
        else if (type == 'POLY_LOOP') {
          final List<int> loopPointIds = [];
          final idMatches = RegExp(r'#(\d+)').allMatches(params);
          for (final m in idMatches) {
            final refId = int.tryParse(m.group(1)!) ?? 0;
            loopPointIds.add(refId);
          }
          if (loopPointIds.isNotEmpty) {
            polyLoopMap[ent.id] = loopPointIds;
          }
        }
        // E. EDGE_CURVE
        else if (type == 'EDGE_CURVE') {
          final idMatches = RegExp(r'#(\d+)').allMatches(params).toList();
          if (idMatches.length >= 2) {
            final v1 = int.tryParse(idMatches[0].group(1)!) ?? 0;
            final v2 = int.tryParse(idMatches[1].group(1)!) ?? 0;
            edgeCurveMap[ent.id] = [v1, v2];
          }
        }
        // F. TRIANGULATED_SURFACE_SET / TRIANGULATED_FACE
        else if (type.contains('TRIANGULATED')) {
          final idMatches = RegExp(r'#(\d+)').allMatches(params).toList();
          if (idMatches.length >= 3) {
            final p1 = pointMap[int.tryParse(idMatches[0].group(1)!) ?? 0];
            final p2 = pointMap[int.tryParse(idMatches[1].group(1)!) ?? 0];
            final p3 = pointMap[int.tryParse(idMatches[2].group(1)!) ?? 0];
            if (p1 != null && p2 != null && p3 != null) {
              triangles.add(Triangle3D(v0: p1, v1: p2, v2: p3, isDoubleSided: true));
            }
          }
        }
      }
    }

    // Resolve AXIS2_PLACEMENT_3D
    for (final ent in entityList) {
      final axisSub = ent.getSub('AXIS2_PLACEMENT_3D');
      if (axisSub != null) {
        final idMatches = RegExp(r'#(\d+)').allMatches(axisSub.params).toList();
        if (idMatches.isNotEmpty) {
          final origId = int.tryParse(idMatches[0].group(1)!) ?? 0;
          final axisId = idMatches.length > 1 ? (int.tryParse(idMatches[1].group(1)!) ?? 0) : 0;
          final refId = idMatches.length > 2 ? (int.tryParse(idMatches[2].group(1)!) ?? 0) : 0;

          final orig = pointMap[origId] ?? Vector3.zero;
          final axis = directionMap[axisId] ?? const Vector3(0, 0, 1);
          final ref = directionMap[refId] ?? const Vector3(1, 0, 0);
          placementMap[ent.id] = _StepAxisPlacement(origin: orig, axis: axis, refDirection: ref);
        }
      }
    }

    // Pass 2: Evaluate NURBS and Analytical Surfaces
    for (final ent in entityList) {
      final hasNurbsSurface = ent.hasType('B_SPLINE_SURFACE_WITH_KNOTS') ||
          ent.hasType('B_SPLINE_SURFACE') ||
          ent.hasType('RATIONAL_B_SPLINE_SURFACE') ||
          ent.hasType('BEZIER_SURFACE');

      if (hasNurbsSurface) {
        _evaluateStepNurbsSurface(ent, pointMap, triangles);
      }

      // Analytical surfaces
      final cylSub = ent.getSub('CYLINDRICAL_SURFACE');
      if (cylSub != null) {
        _evaluateStepCylindricalSurface(cylSub.params, placementMap, triangles);
      }

      final sphereSub = ent.getSub('SPHERICAL_SURFACE');
      if (sphereSub != null) {
        _evaluateStepSphericalSurface(sphereSub.params, placementMap, triangles);
      }

      final coneSub = ent.getSub('CONICAL_SURFACE');
      if (coneSub != null) {
        _evaluateStepConicalSurface(coneSub.params, placementMap, triangles);
      }

      final torusSub = ent.getSub('TOROIDAL_SURFACE');
      if (torusSub != null) {
        _evaluateStepToroidalSurface(torusSub.params, placementMap, triangles);
      }
    }

    // 3. Resolve all POLY_LOOPs into 3D Triangles
    for (final loopIds in polyLoopMap.values) {
      final List<Vector3> loopPts = [];
      for (final refId in loopIds) {
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
          triangles.add(Triangle3D(v0: p0, v1: p1, v2: p2, isDoubleSided: true));
        }
      }
    }

    // 4. Fallback: Only if completely empty and no surfaces or loops were evaluated
    if (triangles.isEmpty && allPoints.length >= 3) {
      for (int i = 0; i < allPoints.length - 2; i += 3) {
        triangles.add(
          Triangle3D(
            v0: allPoints[i],
            v1: allPoints[i + 1],
            v2: allPoints[i + 2],
            isDoubleSided: true,
          ),
        );
      }
    }

    // Wireframe edge lines fallback if only edge curves exist
    if (triangles.isEmpty && edgeCurveMap.isNotEmpty) {
      for (final edge in edgeCurveMap.values) {
        final p1 = pointMap[edge[0]] ?? (vertexMap.containsKey(edge[0]) ? pointMap[vertexMap[edge[0]]] : null);
        final p2 = pointMap[edge[1]] ?? (vertexMap.containsKey(edge[1]) ? pointMap[vertexMap[edge[1]]] : null);
        if (p1 != null && p2 != null) {
          final offset = const Vector3(0.05, 0.05, 0.05);
          triangles.add(Triangle3D(v0: p1, v1: p2, v2: p2 + offset, isDoubleSided: true));
          triangles.add(Triangle3D(v0: p1, v1: p2 + offset, v2: p1 + offset, isDoubleSided: true));
        }
      }
    }

    return Mesh3D(name: name, triangles: triangles);
  }

  static void _evaluateStepNurbsSurface(_StepEntity ent, Map<int, Vector3> pointMap, List<Triangle3D> triangles) {
    int uDeg = 3;
    int vDeg = 3;

    // Search for degrees in any sub-entity params
    for (final sub in ent.subEntities) {
      final degMatch = RegExp(r'\b(\d+)\s*,\s*(\d+)\b').firstMatch(sub.params);
      if (degMatch != null) {
        uDeg = int.tryParse(degMatch.group(1)!) ?? 3;
        vDeg = int.tryParse(degMatch.group(2)!) ?? 3;
        break;
      }
    }

    // Search for 2D control point ID matrix: ((#1, #2), (#3, #4))
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

    // Search for multiplicities and knots: (u_mults), (v_mults), (u_knots), (v_knots)
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

    // Search for rational weights: ((1.0, 1.0), (1.0, 1.0))
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

  static void _evaluateStepCylindricalSurface(String params, Map<int, _StepAxisPlacement> placementMap, List<Triangle3D> triangles) {
    final idMatch = RegExp(r'#(\d+)').firstMatch(params);
    if (idMatch == null) return;
    final placementId = int.tryParse(idMatch.group(1)!) ?? 0;
    final placement = placementMap[placementId];
    if (placement == null) return;

    final radMatch = RegExp(r',\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)\s*\)?$').firstMatch(params);
    final radius = radMatch != null ? (double.tryParse(radMatch.group(1)!) ?? 1.0) : 1.0;
    const height = 10.0;
    const segments = 24;

    final xDir = placement.refDirection.normalized();
    final zDir = placement.axis.normalized();
    final yDir = zDir.cross(xDir).normalized();

    final List<Vector3> bRing = [];
    final List<Vector3> tRing = [];
    for (int i = 0; i <= segments; i++) {
      final theta = (i / segments) * 2.0 * math.pi;
      final radial = xDir * (radius * math.cos(theta)) + yDir * (radius * math.sin(theta));
      bRing.add(placement.origin + radial - zDir * (height * 0.5));
      tRing.add(placement.origin + radial + zDir * (height * 0.5));
    }

    for (int i = 0; i < segments; i++) {
      triangles.add(Triangle3D(v0: bRing[i], v1: bRing[i + 1], v2: tRing[i + 1], isDoubleSided: true));
      triangles.add(Triangle3D(v0: bRing[i], v1: tRing[i + 1], v2: tRing[i], isDoubleSided: true));
    }
  }

  static void _evaluateStepSphericalSurface(String params, Map<int, _StepAxisPlacement> placementMap, List<Triangle3D> triangles) {
    final idMatch = RegExp(r'#(\d+)').firstMatch(params);
    if (idMatch == null) return;
    final placement = placementMap[int.tryParse(idMatch.group(1)!) ?? 0];
    if (placement == null) return;

    final radMatch = RegExp(r',\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)\s*\)?$').firstMatch(params);
    final radius = radMatch != null ? (double.tryParse(radMatch.group(1)!) ?? 1.0) : 1.0;
    const stacks = 16;
    const slices = 24;

    final List<List<Vector3>> grid = [];
    for (int i = 0; i <= stacks; i++) {
      final phi = (i / stacks) * math.pi - math.pi / 2.0;
      final List<Vector3> row = [];
      for (int j = 0; j <= slices; j++) {
        final theta = (j / slices) * 2.0 * math.pi;
        final x = radius * math.cos(phi) * math.cos(theta);
        final y = radius * math.cos(phi) * math.sin(theta);
        final z = radius * math.sin(phi);
        row.add(placement.origin + Vector3(x, y, z));
      }
      grid.add(row);
    }

    for (int i = 0; i < stacks; i++) {
      for (int j = 0; j < slices; j++) {
        final p00 = grid[i][j];
        final p10 = grid[i + 1][j];
        final p11 = grid[i + 1][j + 1];
        final p01 = grid[i][j + 1];
        triangles.add(Triangle3D(v0: p00, v1: p10, v2: p11, isDoubleSided: true));
        triangles.add(Triangle3D(v0: p00, v1: p11, v2: p01, isDoubleSided: true));
      }
    }
  }

  static void _evaluateStepConicalSurface(String params, Map<int, _StepAxisPlacement> placementMap, List<Triangle3D> triangles) {
    final idMatch = RegExp(r'#(\d+)').firstMatch(params);
    if (idMatch == null) return;
    final placement = placementMap[int.tryParse(idMatch.group(1)!) ?? 0];
    if (placement == null) return;

    final numMatches = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?').allMatches(params).toList();
    final radius = numMatches.isNotEmpty ? (double.tryParse(numMatches.last.group(0)!) ?? 1.0) : 1.0;
    const height = 10.0;
    const segments = 24;

    final tip = placement.origin + placement.axis * height;
    final xDir = placement.refDirection.normalized();
    final zDir = placement.axis.normalized();
    final yDir = zDir.cross(xDir).normalized();

    final List<Vector3> bRing = [];
    for (int i = 0; i <= segments; i++) {
      final theta = (i / segments) * 2.0 * math.pi;
      final radial = xDir * (radius * math.cos(theta)) + yDir * (radius * math.sin(theta));
      bRing.add(placement.origin + radial);
    }

    for (int i = 0; i < segments; i++) {
      triangles.add(Triangle3D(v0: bRing[i], v1: bRing[i + 1], v2: tip, isDoubleSided: true));
    }
  }

  static void _evaluateStepToroidalSurface(String params, Map<int, _StepAxisPlacement> placementMap, List<Triangle3D> triangles) {
    final idMatch = RegExp(r'#(\d+)').firstMatch(params);
    if (idMatch == null) return;
    final placement = placementMap[int.tryParse(idMatch.group(1)!) ?? 0];
    if (placement == null) return;

    final nums = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?').allMatches(params).map((m) => double.tryParse(m.group(0)!) ?? 1.0).toList();
    final majorR = nums.length >= 2 ? nums[nums.length - 2] : 5.0;
    final minorR = nums.isNotEmpty ? nums.last : 1.0;
    const uSteps = 24;
    const vSteps = 16;

    final List<List<Vector3>> grid = [];
    for (int i = 0; i <= uSteps; i++) {
      final u = (i / uSteps) * 2.0 * math.pi;
      final List<Vector3> row = [];
      for (int j = 0; j <= vSteps; j++) {
        final v = (j / vSteps) * 2.0 * math.pi;
        final x = (majorR + minorR * math.cos(v)) * math.cos(u);
        final y = (majorR + minorR * math.cos(v)) * math.sin(u);
        final z = minorR * math.sin(v);
        row.add(placement.origin + Vector3(x, y, z));
      }
      grid.add(row);
    }

    for (int i = 0; i < uSteps; i++) {
      for (int j = 0; j < vSteps; j++) {
        final p00 = grid[i][j];
        final p10 = grid[i + 1][j];
        final p11 = grid[i + 1][j + 1];
        final p01 = grid[i][j + 1];
        triangles.add(Triangle3D(v0: p00, v1: p10, v2: p11, isDoubleSided: true));
        triangles.add(Triangle3D(v0: p00, v1: p11, v2: p01, isDoubleSided: true));
      }
    }
  }

  static List<_StepSubEntity> _parseSubEntities(String rhs) {
    final trimmed = rhs.trim();
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      return _parseComplexContent(trimmed.substring(1, trimmed.length - 1).trim());
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
      while (i < content.length && content.codeUnitAt(i) <= 32) i++;
      if (i >= content.length) break;

      final startType = i;
      while (i < content.length && (RegExp(r'[A-Za-z0-9_]').hasMatch(content[i]))) {
        i++;
      }
      final type = content.substring(startType, i).toUpperCase();

      while (i < content.length && content.codeUnitAt(i) <= 32) i++;
      if (i >= content.length || content[i] != '(') {
        if (type.isNotEmpty) subs.add(_StepSubEntity(type, ''));
        continue;
      }
      i++; // consume '('

      int depth = 1;
      final startParam = i;
      while (i < content.length && depth > 0) {
        if (content[i] == '(') depth++;
        else if (content[i] == ')') depth--;
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
    final outerMatch = RegExp(r'\(\s*(\(.*\))\s*\)', dotAll: true).firstMatch(text);
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
