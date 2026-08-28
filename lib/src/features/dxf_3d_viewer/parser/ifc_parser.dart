import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/ifc_model.dart';
import '../models/mesh_3d.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

/// Pure-Dart ISO 10303-21 IFC (IFC2X3, IFC4, IFC4X3) BIM Parser.
class IfcParser {
  /// Parse IFC file asynchronously on a background Isolate.
  static Future<IfcModel> parseFromFile(String filePath) {
    return compute(_parseIfcFileCompute, filePath);
  }

  static IfcModel _parseIfcFileCompute(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('IFC file not found: $filePath');
    }

    final bytes = file.readAsBytesSync();
    final text = UniversalEncodingService.decodeBytes(bytes);
    final fileName = filePath.split(Platform.pathSeparator).last;
    return parseFromText(text, defaultName: fileName);
  }

  /// Decodes ISO-10303-21 string escape sequences (\X2\HHHH, \X4\HHHHHHHH, \X\HH, \S\c)
  /// and repairs encoding artifacts for all international languages.
  static String decodeIfcString(String input) {
    return UniversalEncodingService.decodeIso10303String(input);
  }

  /// Parses raw IFC file text into an [IfcModel].
  static IfcModel parseFromText(String rawText, {String defaultName = 'BIM Model'}) {
    // 1. Strip comments /* ... */
    final cleanText = rawText.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

    // 2. Extract schema from header
    String schema = 'IFC2X3';
    final schemaMatch = RegExp(r"FILE_SCHEMA\s*\(\s*\(\s*['\x22]([A-Z0-9_]+)['\x22]\s*\)\s*\)", caseSensitive: false).firstMatch(cleanText);
    if (schemaMatch != null) {
      schema = schemaMatch.group(1)!.toUpperCase();
    }

    // 3. Tokenize entities by ';'
    final rawEntities = cleanText.split(';');

    // Map entity ID -> Parsed record
    final Map<int, _RawIfcEntity> entityMap = {};

    final entityRegex = RegExp(r'#(\d+)\s*=\s*([A-Z0-9_]+)\s*\((.*)\)', dotAll: true);

    String projectName = defaultName;

    for (final raw in rawEntities) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final match = entityRegex.firstMatch(trimmed);
      if (match == null) continue;

      final id = int.tryParse(match.group(1)!) ?? 0;
      final type = match.group(2)!.toUpperCase();
      final params = match.group(3)!.trim();

      entityMap[id] = _RawIfcEntity(id: id, type: type, params: params);

      if (type == 'IFCPROJECT') {
        // e.g. #1 = IFCPROJECT('guid', $, 'Project Name', ...)
        final nameMatch = RegExp(r"'(.*?)'").allMatches(params).toList();
        if (nameMatch.length >= 2) {
          projectName = decodeIfcString(nameMatch[1].group(1)!);
        }
      }
    }

    final solver = _IfcGeometrySolver(entityMap: entityMap);
    return solver.buildModel(projectName: projectName, schema: schema);
  }
}

class _RawIfcEntity {
  final int id;
  final String type;
  final String params;

  _RawIfcEntity({required this.id, required this.type, required this.params});

  List<String> get splitParams => _IfcParamTokenizer.tokenize(params);

  List<int> get referencedIds {
    final List<int> ids = [];
    for (final m in RegExp(r'#(\d+)').allMatches(params)) {
      final id = int.tryParse(m.group(1)!);
      if (id != null) ids.add(id);
    }
    return ids;
  }
}

class _IfcParamTokenizer {
  static List<String> tokenize(String params) {
    final List<String> tokens = [];
    int depth = 0;
    bool inQuote = false;
    final sb = StringBuffer();

    for (int i = 0; i < params.length; i++) {
      final char = params[i];
      if (char == "'") {
        if (inQuote && i + 1 < params.length && params[i + 1] == "'") {
          // In STEP (ISO-10303-21), single quotes are escaped with ''
          sb.write("'");
          i++;
          continue;
        }
        inQuote = !inQuote;
        sb.write(char);
      } else if (!inQuote && char == '(') {
        depth++;
        sb.write(char);
      } else if (!inQuote && char == ')') {
        depth--;
        sb.write(char);
      } else if (!inQuote && depth == 0 && char == ',') {
        tokens.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    if (sb.isNotEmpty) {
      tokens.add(sb.toString().trim());
    }
    return tokens;
  }
}

class _Transform3D {
  final double m00, m01, m02, tx;
  final double m10, m11, m12, ty;
  final double m20, m21, m22, tz;

  const _Transform3D({
    this.m00 = 1, this.m01 = 0, this.m02 = 0, this.tx = 0,
    this.m10 = 0, this.m11 = 1, this.m12 = 0, this.ty = 0,
    this.m20 = 0, this.m21 = 0, this.m22 = 1, this.tz = 0,
  });

  static const _Transform3D identity = _Transform3D();

  Vector3 transform(Vector3 p) {
    return Vector3(
      m00 * p.x + m01 * p.y + m02 * p.z + tx,
      m10 * p.x + m11 * p.y + m12 * p.z + ty,
      m20 * p.x + m21 * p.y + m22 * p.z + tz,
    );
  }

  _Transform3D multiply(_Transform3D b) {
    return _Transform3D(
      m00: m00 * b.m00 + m01 * b.m10 + m02 * b.m20,
      m01: m00 * b.m01 + m01 * b.m11 + m02 * b.m21,
      m02: m00 * b.m02 + m01 * b.m12 + m02 * b.m22,
      tx:  m00 * b.tx  + m01 * b.ty  + m02 * b.tz  + tx,

      m10: m10 * b.m00 + m11 * b.m10 + m12 * b.m20,
      m11: m10 * b.m01 + m11 * b.m11 + m12 * b.m21,
      m12: m10 * b.m02 + m11 * b.m12 + m12 * b.m22,
      ty:  m10 * b.tx  + m11 * b.ty  + m12 * b.tz  + ty,

      m20: m20 * b.m00 + m21 * b.m10 + m22 * b.m20,
      m21: m20 * b.m01 + m21 * b.m11 + m22 * b.m21,
      m22: m20 * b.m02 + m21 * b.m12 + m22 * b.m22,
      tz:  m20 * b.tx  + m21 * b.ty  + m22 * b.tz  + tz,
    );
  }
}

class _IfcGeometrySolver {
  final Map<int, _RawIfcEntity> entityMap;
  final Map<int, Vector3> pointCache = {};
  final Map<int, _Transform3D> placementCache = {};

  _IfcGeometrySolver({required this.entityMap});

  IfcModel buildModel({required String projectName, required String schema}) {
    // 1. Find all Storeys
    final List<IfcStorey> storeys = [];
    final Map<int, String> elementToStoreyName = {};

    for (final ent in entityMap.values) {
      if (ent.type == 'IFCBUILDINGSTOREY') {
        final params = ent.splitParams;
        String name = 'Level ${storeys.length}';
        if (params.length > 2 && params[2].startsWith("'")) {
          name = IfcParser.decodeIfcString(params[2].replaceAll("'", ""));
        }
        double elevation = 0.0;
        if (params.length > 9) {
          elevation = double.tryParse(params[9].replaceAll("'", "")) ?? 0.0;
        }
        storeys.add(IfcStorey(id: ent.id, name: name, elevation: elevation, elementIds: []));
      }
    }

    // Default storey if none defined
    if (storeys.isEmpty) {
      storeys.add(const IfcStorey(id: 0, name: 'Default Storey', elevation: 0.0, elementIds: []));
    }

    // 2. Spatial relations (IFCRELCONTAINEDINSPATIALSTRUCTURE)
    for (final ent in entityMap.values) {
      if (ent.type == 'IFCRELCONTAINEDINSPATIALSTRUCTURE') {
        final params = ent.splitParams;
        if (params.length >= 5) {
          int? relatingStructureId;
          String elementsParam = '';
          if (params.length >= 6) {
            relatingStructureId = int.tryParse(params[5].replaceAll(RegExp(r'[#\s]'), ''));
            elementsParam = params[4];
          } else {
            relatingStructureId = int.tryParse(params[params.length - 1].replaceAll(RegExp(r'[#\s]'), ''));
            elementsParam = params[params.length - 2];
          }
          if (relatingStructureId != null) {
            final storey = storeys.firstWhere(
              (s) => s.id == relatingStructureId,
              orElse: () => storeys.first,
            );
            final relIds = RegExp(r'#(\d+)').allMatches(elementsParam).map((m) => int.parse(m.group(1)!)).toList();
            for (final elId in relIds) {
              elementToStoreyName[elId] = storey.name;
            }
          }
        }
      }
    }

    // 2.5. Presentation Layer assignments (IFCPRESENTATIONLAYERASSIGNMENT & IFCPRESENTATIONLAYERWITHSTYLE)
    final Map<int, String> itemToLayerName = {};
    final Set<String> layers = {};
    final Set<String> initialHiddenLayers = {};
    for (final ent in entityMap.values) {
      if (ent.type == 'IFCPRESENTATIONLAYERASSIGNMENT' || ent.type == 'IFCPRESENTATIONLAYERWITHSTYLE') {
        final params = ent.splitParams;
        if (params.isNotEmpty) {
          final rawName = params[0].replaceAll("'", "").trim();
          final layerName = IfcParser.decodeIfcString(rawName);
          if (layerName.isNotEmpty && layerName != r'$') {
            layers.add(layerName);
            // Check if hidden or frozen in Archicad / AutoCAD / Revit:
            if (ent.type == 'IFCPRESENTATIONLAYERWITHSTYLE') {
              // Param 4: LayerOn (.F. means turned off), Param 5: LayerFrozen (.T. means frozen)
              if (params.length > 4 && params[4].toUpperCase().contains('.F.')) {
                initialHiddenLayers.add(layerName);
              }
              if (params.length > 5 && params[5].toUpperCase().contains('.T.')) {
                initialHiddenLayers.add(layerName);
              }
            }
            // Element/Shape/Item IDs are in param index 2 e.g. (#100, #101, #102...)
            if (params.length > 2) {
              final assignedIds = RegExp(r'#(\d+)').allMatches(params[2]).map((m) => int.parse(m.group(1)!)).toList();
              for (final id in assignedIds) {
                itemToLayerName[id] = layerName;
              }
            }
          }
        }
      }
    }

    // 3. Find and generate building elements
    final List<IfcElement> elements = [];
    final Set<String> categories = {};

    for (final ent in entityMap.values) {
      final category = _categorizeIfcType(ent.type);
      if (category == null) continue; // Not a renderable building element

      final params = ent.splitParams;
      String globalId = '';
      String name = ent.type.replaceAll('IFC', '');
      if (params.isNotEmpty && params[0].startsWith("'")) {
        globalId = params[0].replaceAll("'", "");
      }
      if (params.length > 2 && params[2].startsWith("'") && params[2].length > 2) {
        name = IfcParser.decodeIfcString(params[2].replaceAll("'", ""));
      }

      final placementId = params.length > 5 ? int.tryParse(params[5].replaceAll(RegExp(r'[#\s]'), '')) : null;
      final shapeRepId = params.length > 6 ? int.tryParse(params[6].replaceAll(RegExp(r'[#\s]'), '')) : null;

      final transform = placementId != null ? _resolvePlacement(placementId) : _Transform3D.identity;
      final color = _getArchitecturalColor(category);

      final triangles = <Triangle3D>[];
      if (shapeRepId != null) {
        triangles.addAll(_resolveShapeRepresentation(shapeRepId, transform, color));
      }

      if (triangles.isNotEmpty) {
        final storeyName = elementToStoreyName[ent.id] ?? storeys.first.name;
        final layer = _resolveElementLayer(ent.id, shapeRepId, itemToLayerName);
        categories.add(category);

        elements.add(IfcElement(
          id: ent.id,
          globalId: globalId,
          name: name,
          ifcType: ent.type,
          category: category,
          storeyName: storeyName,
          layer: layer,
          color: color,
          triangles: triangles,
        ));
      }
    }

    return IfcModel(
      projectName: projectName,
      schema: schema,
      elements: elements,
      storeys: storeys,
      categories: categories,
      layers: layers,
      hiddenLayers: initialHiddenLayers,
    );
  }

  static String? _categorizeIfcType(String type) {
    switch (type) {
      case 'IFCWALL':
      case 'IFCWALLSTANDARDCASE':
      case 'IFCWALLTYPE':
        return 'Wall';
      case 'IFCSLAB':
      case 'IFCSLABSTANDARDCASE':
      case 'IFCFLOOR':
      case 'IFCCOVERING':
      case 'IFCFOOTING':
        return 'Slab';
      case 'IFCCOLUMN':
      case 'IFCCOLUMNSTANDARDCASE':
        return 'Column';
      case 'IFCBEAM':
      case 'IFCBEAMSTANDARDCASE':
        return 'Beam';
      case 'IFCWINDOW':
      case 'IFCWINDOWSTANDARDCASE':
      case 'IFCCURTAINWALL':
        return 'Window';
      case 'IFCDOOR':
      case 'IFCDOORSTANDARDCASE':
        return 'Door';
      case 'IFCROOF':
        return 'Roof';
      case 'IFCSTAIR':
      case 'IFCSTAIRFLIGHT':
      case 'IFCRAMP':
      case 'IFCRAMPFLIGHT':
        return 'Stair';
      case 'IFCRAILING':
        return 'Railing';
      case 'IFCFURNISHINGELEMENT':
      case 'IFCFURNITURE':
        return 'Furniture';
      case 'IFCBUILDINGELEMENTPROXY':
      case 'IFCMEMBER':
      case 'IFCPLATE':
      case 'IFCSITE':
      case 'IFCGEOGRAPHICELEMENT':
        return 'Generic';
      default:
        return null;
    }
  }

  static Color _getArchitecturalColor(String category) {
    switch (category) {
      case 'Wall':
        return const Color(0xFFE5E2DC); // Warm White / Stone
      case 'Slab':
        return const Color(0xFFB8BCC2); // Concrete Gray
      case 'Column':
        return const Color(0xFF7D8B9B); // Structural Gray
      case 'Beam':
        return const Color(0xFF6C7C8C); // Steel Gray
      case 'Window':
        return const Color(0x9972C4EE); // Translucent Sky Blue Glass
      case 'Door':
        return const Color(0xFFA07452); // Wood Brown
      case 'Roof':
        return const Color(0xFFBA5545); // Terracotta Red
      case 'Stair':
        return const Color(0xFF9E9FA4); // Stone Gray
      case 'Railing':
        return const Color(0xFF5A626A); // Dark Metallic Gray
      case 'Furniture':
        return const Color(0xFF4E7D96); // Modern Teal / Marine
      default:
        return const Color(0xFFC0C0C0);
    }
  }

  /// Extracts numbers from parentheses, robust to Archicad trailing dots e.g. (0., -1200., 25.37)
  static List<double> _parseCoordinateList(String params) {
    final parenMatches = RegExp(r'\(([^()]*)\)').allMatches(params);
    for (final m in parenMatches) {
      final inner = m.group(1)!.trim();
      if (inner.isEmpty) continue;
      final parts = inner.split(',');
      final nums = <double>[];
      bool valid = false;
      for (final p in parts) {
        final val = double.tryParse(p.trim());
        if (val != null) {
          nums.add(val);
          valid = true;
        }
      }
      if (valid && nums.isNotEmpty) {
        return nums;
      }
    }
    return [];
  }

  List<Vector3> _parsePointListFromParams(String params) {
    final List<Vector3> points = [];
    final parenMatches = RegExp(r'\(([^()]+)\)').allMatches(params);
    for (final m in parenMatches) {
      final inner = m.group(1)!.trim();
      if (inner.isEmpty) continue;
      final parts = inner.split(',');
      if (parts.length >= 2) {
        final x = double.tryParse(parts[0].trim()) ?? 0.0;
        final y = double.tryParse(parts[1].trim()) ?? 0.0;
        final z = parts.length > 2 ? (double.tryParse(parts[2].trim()) ?? 0.0) : 0.0;
        points.add(Vector3(x, y, z));
      }
    }
    return points;
  }

  /// Resolves the layer of an element by traversing its representation hierarchy (BFS).
  String _resolveElementLayer(int elementId, int? shapeRepId, Map<int, String> itemToLayer) {
    if (itemToLayer.containsKey(elementId)) {
      return itemToLayer[elementId]!;
    }
    if (shapeRepId == null) return '';

    final queue = <int>[shapeRepId];
    final visited = <int>{elementId, shapeRepId};

    while (queue.isNotEmpty) {
      final currId = queue.removeAt(0);
      if (itemToLayer.containsKey(currId)) {
        return itemToLayer[currId]!;
      }
      final shapeEnt = entityMap[currId];
      if (shapeEnt != null) {
        for (final refId in shapeEnt.referencedIds) {
          if (!visited.contains(refId)) {
            visited.add(refId);
            if (itemToLayer.containsKey(refId)) {
              return itemToLayer[refId]!;
            }
            final sub = entityMap[refId];
            if (sub != null) {
              if (sub.type.contains('SHAPE') ||
                  sub.type.contains('REPRESENTATION') ||
                  sub.type.contains('SOLID') ||
                  sub.type.contains('BREP') ||
                  sub.type.contains('MAPPED') ||
                  sub.type.contains('SHELL') ||
                  sub.type.contains('ITEM') ||
                  sub.type.contains('GEOM')) {
                queue.add(refId);
              }
            }
          }
        }
      }
    }

    return '';
  }

  _Transform3D _resolvePlacement(int placementId) {
    if (placementCache.containsKey(placementId)) {
      return placementCache[placementId]!;
    }

    final ent = entityMap[placementId];
    if (ent == null) return _Transform3D.identity;

    if (ent.type == 'IFCLOCALPLACEMENT') {
      final params = ent.splitParams;
      _Transform3D parentTransform = _Transform3D.identity;
      if (params.isNotEmpty && params[0].contains('#')) {
        final parentId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
        if (parentId != null) {
          parentTransform = _resolvePlacement(parentId);
        }
      }

      _Transform3D localTransform = _Transform3D.identity;
      if (params.length > 1 && params[1].contains('#')) {
        final axisId = int.tryParse(params[1].replaceAll(RegExp(r'[#\s]'), ''));
        if (axisId != null) {
          final axisEnt = entityMap[axisId];
          if (axisEnt != null && axisEnt.type == 'IFCAXIS2PLACEMENT2D') {
            localTransform = _resolveAxis2Placement2D(axisId);
          } else {
            localTransform = _resolveAxis2Placement3D(axisId);
          }
        }
      }

      final result = parentTransform.multiply(localTransform);
      placementCache[placementId] = result;
      return result;
    }

    return _Transform3D.identity;
  }

  _Transform3D _resolveAxis2Placement2D(int axisId) {
    final ent = entityMap[axisId];
    if (ent == null) return _Transform3D.identity;

    final params = ent.splitParams;
    Vector3 origin = Vector3.zero;
    Vector3 axisX = const Vector3(1, 0, 0);

    if (params.isNotEmpty && params[0].contains('#')) {
      final ptId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
      if (ptId != null) {
        origin = _resolvePoint(ptId);
      }
    }

    if (params.length > 1 && params[1].contains('#')) {
      final dirId = int.tryParse(params[1].replaceAll(RegExp(r'[#\s]'), ''));
      if (dirId != null) {
        axisX = _resolveDirection(dirId);
      }
    }

    final axisY = Vector3(-axisX.y, axisX.x, 0).normalized();

    return _Transform3D(
      m00: axisX.x, m01: axisY.x, m02: 0, tx: origin.x,
      m10: axisX.y, m11: axisY.y, m12: 0, ty: origin.y,
      m20: 0,       m21: 0,       m22: 1, tz: origin.z,
    );
  }

  _Transform3D _resolveAxis2Placement3D(int axisId) {
    final ent = entityMap[axisId];
    if (ent == null) return _Transform3D.identity;

    final params = ent.splitParams;
    Vector3 origin = Vector3.zero;
    Vector3 axisZ = const Vector3(0, 0, 1);
    Vector3 axisX = const Vector3(1, 0, 0);

    if (params.isNotEmpty && params[0].contains('#')) {
      final ptId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
      if (ptId != null) {
        origin = _resolvePoint(ptId);
      }
    }

    if (params.length > 1 && params[1].contains('#')) {
      final zId = int.tryParse(params[1].replaceAll(RegExp(r'[#\s]'), ''));
      if (zId != null) {
        axisZ = _resolveDirection(zId);
      }
    }

    if (params.length > 2 && params[2].contains('#')) {
      final xId = int.tryParse(params[2].replaceAll(RegExp(r'[#\s]'), ''));
      if (xId != null) {
        axisX = _resolveDirection(xId);
      }
    }

    // Orthogonalize
    axisZ = axisZ.normalized();
    if (axisZ.lengthSquared < 1e-6) axisZ = const Vector3(0, 0, 1);

    // Make axisX perpendicular to axisZ
    axisX = (axisX - axisZ * axisX.dot(axisZ));
    if (axisX.lengthSquared < 1e-6) {
      axisX = (axisZ.x.abs() < 0.9) ? const Vector3(1, 0, 0).cross(axisZ) : const Vector3(0, 1, 0).cross(axisZ);
    }
    axisX = axisX.normalized();

    final axisY = axisZ.cross(axisX).normalized();

    return _Transform3D(
      m00: axisX.x, m01: axisY.x, m02: axisZ.x, tx: origin.x,
      m10: axisX.y, m11: axisY.y, m12: axisZ.y, ty: origin.y,
      m20: axisX.z, m21: axisY.z, m22: axisZ.z, tz: origin.z,
    );
  }

  Vector3 _resolvePoint(int ptId) {
    if (pointCache.containsKey(ptId)) return pointCache[ptId]!;

    final ent = entityMap[ptId];
    if (ent != null && (ent.type == 'IFCCARTESIANPOINT' || ent.type == 'IFCPOINT')) {
      final coords = _parseCoordinateList(ent.params);
      if (coords.isNotEmpty) {
        final x = coords[0];
        final y = coords.length > 1 ? coords[1] : 0.0;
        final z = coords.length > 2 ? coords[2] : 0.0;
        final pt = Vector3(x, y, z);
        pointCache[ptId] = pt;
        return pt;
      }
    }
    return Vector3.zero;
  }

  Vector3 _resolveDirection(int dirId) {
    final ent = entityMap[dirId];
    if (ent != null && ent.type == 'IFCDIRECTION') {
      final coords = _parseCoordinateList(ent.params);
      if (coords.isNotEmpty) {
        final x = coords[0];
        final y = coords.length > 1 ? coords[1] : 0.0;
        final z = coords.length > 2 ? coords[2] : 0.0;
        final dir = Vector3(x, y, z);
        if (dir.lengthSquared > 1e-6) {
          return dir.normalized();
        }
      }
    }
    return const Vector3(0, 0, 1);
  }

  List<Vector3> _resolveCurvePoints(int curveId) {
    final ent = entityMap[curveId];
    if (ent == null) return [];

    // 1. IFCPOLYLINE
    if (ent.type == 'IFCPOLYLINE') {
      final List<Vector3> pts = [];
      for (final ptId in ent.referencedIds) {
        pts.add(_resolvePoint(ptId));
      }
      return pts;
    }

    // 2. IFCINDEXEDPOLYCURVE (IFC4)
    if (ent.type == 'IFCINDEXEDPOLYCURVE') {
      final params = ent.splitParams;
      if (params.isNotEmpty) {
        final ptsListId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
        if (ptsListId != null) {
          final ptsListEnt = entityMap[ptsListId];
          if (ptsListEnt != null) {
            return _parsePointListFromParams(ptsListEnt.params);
          }
        }
      }
    }

    // 3. IFCCOMPOSITECURVE
    if (ent.type == 'IFCCOMPOSITECURVE') {
      final List<Vector3> pts = [];
      for (final segId in ent.referencedIds) {
        final segEnt = entityMap[segId];
        if (segEnt != null) {
          for (final subCurveId in segEnt.referencedIds) {
            final subPts = _resolveCurvePoints(subCurveId);
            for (final sp in subPts) {
              if (pts.isEmpty || pts.last.distanceTo(sp) > 1e-4) {
                pts.add(sp);
              }
            }
          }
        }
      }
      return pts;
    }

    // 4. IFCTRIMMEDCURVE
    if (ent.type == 'IFCTRIMMEDCURVE') {
      final List<Vector3> pts = [];
      for (final id in ent.referencedIds) {
        final sub = entityMap[id];
        if (sub != null && sub.type == 'IFCCARTESIANPOINT') {
          pts.add(_resolvePoint(id));
        }
      }
      if (pts.length >= 2) return pts;
    }

    // 5. IFCCIRCLE
    if (ent.type == 'IFCCIRCLE') {
      final params = ent.splitParams;
      double r = 1.0;
      if (params.length >= 2) {
        r = double.tryParse(params[1].replaceAll(RegExp(r'[#\s]'), '')) ?? 1.0;
      }
      _Transform3D circlePlacement = _Transform3D.identity;
      if (params.isNotEmpty && params[0].contains('#')) {
        final posId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
        if (posId != null) {
          circlePlacement = _resolveAxis2Placement2D(posId);
        }
      }
      const segs = 16;
      final pts = <Vector3>[];
      for (int i = 0; i < segs; i++) {
        final theta = (i / segs) * 2.0 * math.pi;
        pts.add(circlePlacement.transform(Vector3(r * math.cos(theta), r * math.sin(theta), 0)));
      }
      return pts;
    }

    return [];
  }

  List<Vector3> _resolveProfilePoints(int profileId) {
    final ent = entityMap[profileId];
    if (ent == null) return [];

    // A. IFCRECTANGLEPROFILEDEF (Width X, Depth Y)
    if (ent.type == 'IFCRECTANGLEPROFILEDEF') {
      final params = ent.splitParams;
      if (params.length >= 4) {
        int xIdx = 3;
        int yIdx = 4;
        _Transform3D posTransform = _Transform3D.identity;
        if (params.length >= 5) {
          if (params[2].contains('#')) {
            final posId = int.tryParse(params[2].replaceAll(RegExp(r'[#\s]'), ''));
            if (posId != null) {
              final pEnt = entityMap[posId];
              if (pEnt != null && pEnt.type == 'IFCAXIS2PLACEMENT3D') {
                posTransform = _resolveAxis2Placement3D(posId);
              } else {
                posTransform = _resolveAxis2Placement2D(posId);
              }
            }
          }
        } else if (params.length == 4) {
          xIdx = 2;
          yIdx = 3;
        }
        final xDim = double.tryParse(params[xIdx].replaceAll(RegExp(r'[#\s]'), '')) ?? 1.0;
        final yDim = double.tryParse(params[yIdx].replaceAll(RegExp(r'[#\s]'), '')) ?? 1.0;
        final hx = xDim / 2.0;
        final hy = yDim / 2.0;
        return [
          posTransform.transform(Vector3(-hx, -hy, 0)),
          posTransform.transform(Vector3(hx, -hy, 0)),
          posTransform.transform(Vector3(hx, hy, 0)),
          posTransform.transform(Vector3(-hx, hy, 0)),
        ];
      }
    }
    // B. IFCCIRCLEPROFILEDEF (Radius R)
    else if (ent.type == 'IFCCIRCLEPROFILEDEF') {
      final params = ent.splitParams;
      if (params.length >= 3) {
        int rIdx = params.length - 1;
        _Transform3D posTransform = _Transform3D.identity;
        if (params.length >= 4 && params[2].contains('#')) {
          final posId = int.tryParse(params[2].replaceAll(RegExp(r'[#\s]'), ''));
          if (posId != null) {
            final pEnt = entityMap[posId];
            if (pEnt != null && pEnt.type == 'IFCAXIS2PLACEMENT3D') {
              posTransform = _resolveAxis2Placement3D(posId);
            } else {
              posTransform = _resolveAxis2Placement2D(posId);
            }
          }
        }
        final r = double.tryParse(params[rIdx].replaceAll(RegExp(r'[#\s]'), '')) ?? 1.0;
        const segs = 16;
        final List<Vector3> pts = [];
        for (int i = 0; i < segs; i++) {
          final theta = (i / segs) * 2.0 * math.pi;
          pts.add(posTransform.transform(Vector3(r * math.cos(theta), r * math.sin(theta), 0)));
        }
        return pts;
      }
    }
    // C. IFCARBITRARYCLOSEDPROFILEDEF & IFCARBITRARYPROFILEDEFWITHVOIDS
    else if (ent.type == 'IFCARBITRARYCLOSEDPROFILEDEF' || ent.type == 'IFCARBITRARYPROFILEDEFWITHVOIDS') {
      final params = ent.splitParams;
      if (params.length >= 3) {
        final curveId = int.tryParse(params[2].replaceAll(RegExp(r'[#\s]'), ''));
        if (curveId != null) {
          final pts = _resolveCurvePoints(curveId);
          if (pts.length > 1 && pts.first.distanceTo(pts.last) < 1e-4) {
            pts.removeLast();
          }
          return pts;
        }
      }
    }
    // D. Direct reference to curve (Polyline, IndexedPolyCurve, CompositeCurve)
    else {
      final pts = _resolveCurvePoints(profileId);
      if (pts.length > 1 && pts.first.distanceTo(pts.last) < 1e-4) {
        pts.removeLast();
      }
      return pts;
    }

    return [];
  }

  List<Triangle3D> _resolveShapeRepresentation(int shapeId, _Transform3D parentTransform, Color color) {
    final List<Triangle3D> tris = [];
    final ent = entityMap[shapeId];
    if (ent == null) return tris;

    if (ent.type == 'IFCPRODUCTDEFINITIONSHAPE') {
      for (final id in ent.referencedIds) {
        tris.addAll(_resolveShapeRepresentation(id, parentTransform, color));
      }
    } else if (ent.type == 'IFCSHAPEREPRESENTATION') {
      for (final id in ent.referencedIds) {
        tris.addAll(_resolveGeometryItem(id, parentTransform, color));
      }
    } else {
      tris.addAll(_resolveGeometryItem(shapeId, parentTransform, color));
    }

    return tris;
  }

  List<Triangle3D> _resolveGeometryItem(int itemId, _Transform3D transform, Color color) {
    final List<Triangle3D> tris = [];
    final ent = entityMap[itemId];
    if (ent == null) return tris;

    // 1. IFCEXTRUDEDAREASOLID (Walls, Slabs, Beams, Columns)
    if (ent.type == 'IFCEXTRUDEDAREASOLID') {
      tris.addAll(_generateExtrudedSolid(ent, transform, color));
    }
    // 2. IFCFACETEDBREP & IFCSHELLBASEDSURFACEMODEL
    else if (ent.type == 'IFCFACETEDBREP' || ent.type == 'IFCSHELLBASEDSURFACEMODEL' || ent.type == 'IFCFACETEDBREPWITHVOIDS' || ent.type == 'IFCSURFACEMODEL') {
      for (final id in ent.referencedIds) {
        tris.addAll(_generateFacetedBrep(id, transform, color));
      }
    }
    // 3. IFCTRIANGULATEDFACESET (IFC4 direct triangulated mesh)
    else if (ent.type == 'IFCTRIANGULATEDFACESET') {
      tris.addAll(_generateTriangulatedFaceSet(ent, transform, color));
    }
    // 4. IFCPOLYGONALFACESET (IFC4 polygonal mesh)
    else if (ent.type == 'IFCPOLYGONALFACESET') {
      tris.addAll(_generatePolygonalFaceSet(ent, transform, color));
    }
    // 5. IFCBOOLEANCLIPPINGRESULT / IFCBOOLEANRESULT
    else if (ent.type.contains('BOOLEAN')) {
      if (ent.referencedIds.isNotEmpty) {
        tris.addAll(_resolveGeometryItem(ent.referencedIds[0], transform, color));
      }
    }
    // 6. IFCMAPPEDITEM
    else if (ent.type == 'IFCMAPPEDITEM') {
      final params = ent.splitParams;
      if (params.length >= 2) {
        final mapId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
        final opId = int.tryParse(params[1].replaceAll(RegExp(r'[#\s]'), ''));
        _Transform3D mapTransform = _Transform3D.identity;
        if (opId != null) {
          final opEnt = entityMap[opId];
          if (opEnt != null && opEnt.type == 'IFCAXIS2PLACEMENT2D') {
            mapTransform = _resolveAxis2Placement2D(opId);
          } else {
            mapTransform = _resolveAxis2Placement3D(opId);
          }
        }
        if (mapId != null) {
          final mapEnt = entityMap[mapId];
          if (mapEnt != null) {
            for (final refId in mapEnt.referencedIds) {
              tris.addAll(_resolveGeometryItem(refId, transform.multiply(mapTransform), color));
            }
          }
        }
      }
    }

    return tris;
  }

  List<Triangle3D> _generateExtrudedSolid(_RawIfcEntity ent, _Transform3D transform, Color color) {
    final List<Triangle3D> tris = [];
    final params = ent.splitParams;
    if (params.length < 4) return tris;

    final profileId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
    final positionId = int.tryParse(params[1].replaceAll(RegExp(r'[#\s]'), ''));
    final dirId = int.tryParse(params[2].replaceAll(RegExp(r'[#\s]'), ''));
    final depth = double.tryParse(params[3].replaceAll(RegExp(r'[#\s]'), '')) ?? 1.0;

    if (profileId == null) return tris;

    // Local solid transform
    _Transform3D solidTransform = _Transform3D.identity;
    if (positionId != null) {
      final posEnt = entityMap[positionId];
      if (posEnt != null && posEnt.type == 'IFCAXIS2PLACEMENT2D') {
        solidTransform = _resolveAxis2Placement2D(positionId);
      } else {
        solidTransform = _resolveAxis2Placement3D(positionId);
      }
    }
    final compositeTransform = transform.multiply(solidTransform);

    // Extrusion direction
    Vector3 extrudeDir = const Vector3(0, 0, 1);
    if (dirId != null) {
      extrudeDir = _resolveDirection(dirId);
    }
    final extrudeVec = extrudeDir * depth;

    // Resolve 2D Profile into polygon points
    final List<Vector3> polygon = _resolveProfilePoints(profileId);
    if (polygon.length < 3) return tris;

    final int n = polygon.length;
    final List<Vector3> bottom = [];
    final List<Vector3> top = [];

    for (final p in polygon) {
      bottom.add(compositeTransform.transform(p));
      top.add(compositeTransform.transform(p + extrudeVec));
    }

    // 1. Bottom Cap (fan triangulation)
    for (int i = 1; i < n - 1; i++) {
      tris.add(Triangle3D(v0: bottom[0], v1: bottom[i + 1], v2: bottom[i], color: color));
    }

    // 2. Top Cap (fan triangulation with reversed winding)
    for (int i = 1; i < n - 1; i++) {
      tris.add(Triangle3D(v0: top[0], v1: top[i], v2: top[i + 1], color: color));
    }

    // 3. Side Walls
    for (int i = 0; i < n; i++) {
      final next = (i + 1) % n;
      final b0 = bottom[i];
      final b1 = bottom[next];
      final t0 = top[i];
      final t1 = top[next];

      tris.add(Triangle3D(v0: b0, v1: b1, v2: t1, color: color));
      tris.add(Triangle3D(v0: b0, v1: t1, v2: t0, color: color));
    }

    return tris;
  }

  List<Triangle3D> _generateFacetedBrep(int shellOrFaceId, _Transform3D transform, Color color) {
    final List<Triangle3D> tris = [];
    final ent = entityMap[shellOrFaceId];
    if (ent == null) return tris;

    if (ent.type == 'IFCCLOSEDSHELL' || ent.type == 'IFCOPENSHELL' || ent.type == 'IFCFACETEDBREP' || ent.type == 'IFCSHELLBASEDSURFACEMODEL' || ent.type == 'IFCFACETEDBREPWITHVOIDS') {
      for (final faceId in ent.referencedIds) {
        tris.addAll(_generateFacetedBrep(faceId, transform, color));
      }
    } else if (ent.type == 'IFCFACE') {
      for (final boundId in ent.referencedIds) {
        final boundEnt = entityMap[boundId];
        if (boundEnt != null) {
          for (final loopId in boundEnt.referencedIds) {
            final loopEnt = entityMap[loopId];
            if (loopEnt != null && loopEnt.type == 'IFCPOLYLOOP') {
              final pts = loopEnt.referencedIds.map((id) => transform.transform(_resolvePoint(id))).toList();
              if (pts.length >= 3) {
                for (int i = 1; i < pts.length - 1; i++) {
                  tris.add(Triangle3D(v0: pts[0], v1: pts[i], v2: pts[i + 1], color: color));
                }
              }
            }
          }
        }
      }
    }

    return tris;
  }

  List<Triangle3D> _generateTriangulatedFaceSet(_RawIfcEntity ent, _Transform3D transform, Color color) {
    final List<Triangle3D> tris = [];
    final params = ent.splitParams;
    if (params.isEmpty) return tris;

    final coordsId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
    if (coordsId == null) return tris;

    final coordsEnt = entityMap[coordsId];
    if (coordsEnt == null) return tris;

    final rawPoints = _parsePointListFromParams(coordsEnt.params);
    final points = rawPoints.map((p) => transform.transform(p)).toList();
    if (points.length < 3) return tris;

    // Parse indices: ((i1,i2,i3),(i4,i5,i6),...)
    final indexMatches = RegExp(r'\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)').allMatches(ent.params);
    for (final m in indexMatches) {
      final i1 = (int.tryParse(m.group(1)!) ?? 1) - 1;
      final i2 = (int.tryParse(m.group(2)!) ?? 1) - 1;
      final i3 = (int.tryParse(m.group(3)!) ?? 1) - 1;

      if (i1 >= 0 && i1 < points.length &&
          i2 >= 0 && i2 < points.length &&
          i3 >= 0 && i3 < points.length) {
        tris.add(Triangle3D(v0: points[i1], v1: points[i2], v2: points[i3], color: color));
      }
    }

    return tris;
  }

  List<Triangle3D> _generatePolygonalFaceSet(_RawIfcEntity ent, _Transform3D transform, Color color) {
    final List<Triangle3D> tris = [];
    final params = ent.splitParams;
    if (params.isEmpty) return tris;

    final coordsId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
    if (coordsId == null) return tris;

    final coordsEnt = entityMap[coordsId];
    if (coordsEnt == null) return tris;

    final rawPoints = _parsePointListFromParams(coordsEnt.params);
    final points = rawPoints.map((p) => transform.transform(p)).toList();
    if (points.length < 3) return tris;

    // Faces are referenced in param index 2 e.g. (#face1, #face2)
    if (params.length > 2) {
      final faceIds = RegExp(r'#(\d+)').allMatches(params[2]).map((m) => int.parse(m.group(1)!)).toList();
      for (final fId in faceIds) {
        final faceEnt = entityMap[fId];
        if (faceEnt != null) {
          final idxMatches = RegExp(r'(\d+)').allMatches(faceEnt.params).map((m) => int.parse(m.group(1)!) - 1).toList();
          if (idxMatches.length >= 3) {
            for (int i = 1; i < idxMatches.length - 1; i++) {
              final i0 = idxMatches[0];
              final i1 = idxMatches[i];
              final i2 = idxMatches[i + 1];
              if (i0 >= 0 && i0 < points.length &&
                  i1 >= 0 && i1 < points.length &&
                  i2 >= 0 && i2 < points.length) {
                tris.add(Triangle3D(v0: points[i0], v1: points[i1], v2: points[i2], color: color));
              }
            }
          }
        }
      }
    }

    return tris;
  }
}
