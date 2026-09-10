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

class _Plane3D {
  final Vector3 origin;
  final Vector3 normal;
  const _Plane3D({required this.origin, required this.normal});
}

class _Obb {
  final Vector3 pMin;
  final Vector3 pMax;
  final Vector3 nX;
  final Vector3 nY;
  final Vector3 nZ;
  _Obb(this.pMin, this.pMax, this.nX, this.nY, this.nZ);
}

class _IfcGeometrySolver {
  final Map<int, _RawIfcEntity> entityMap;
  final Map<int, Vector3> pointCache = {};
  final Map<int, _Transform3D> placementCache = {};
  final Map<int, Color> itemToStyledColor = {};
  final Map<int, Color> materialToStyledColor = {};
  final Map<int, Color> elementToMaterialColor = {};

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

    // 2.2. Parse Surface Styles (IFCSTYLEDITEM -> IFCSURFACESTYLE -> IFCCOLOURRGB)
    for (final ent in entityMap.values) {
      if (ent.type == 'IFCSTYLEDITEM') {
        final params = ent.splitParams;
        if (params.isNotEmpty) {
          final itemId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
          if (itemId != null && params.length > 1) {
            final color = _resolveStyleColorFromParam(params[1]);
            if (color != null) {
              itemToStyledColor[itemId] = color;
            }
          }
        }
      }
    }

    // 2.3. Parse Material Definition Representations (IFCMATERIALDEFINITIONREPRESENTATION)
    // Maps IFCMATERIAL -> IFCSTYLEDREPRESENTATION -> IFCSTYLEDITEM -> IFCSURFACESTYLE -> IFCCOLOURRGB
    for (final ent in entityMap.values) {
      if (ent.type == 'IFCMATERIALDEFINITIONREPRESENTATION') {
        final params = ent.splitParams;
        if (params.length >= 4) {
          final repsParam = params[2];
          final matId = int.tryParse(params[3].replaceAll(RegExp(r'[#\s]'), ''));
          if (matId != null) {
            final color = _resolveStyleColorFromParam(repsParam);
            if (color != null) {
              materialToStyledColor[matId] = color;
            }
          }
        }
      }
    }

    // 2.4. Parse Material Associations (IFCRELASSOCIATESMATERIAL -> IFCMATERIAL / LAYERSET / LIST)
    for (final ent in entityMap.values) {
      if (ent.type == 'IFCRELASSOCIATESMATERIAL') {
        final params = ent.splitParams;
        if (params.length >= 6) {
          final elementsParam = params[4];
          final matParam = params[5];
          final matColor = _resolveMaterialColorFromParam(matParam);
          if (matColor != null) {
            final relIds = RegExp(r'#(\d+)').allMatches(elementsParam).map((m) => int.parse(m.group(1)!)).toList();
            for (final elId in relIds) {
              elementToMaterialColor[elId] = matColor;
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

    // 2.6. Parse Wall Openings & Voids (IFCRELVOIDSELEMENT -> IFCOPENINGELEMENT)
    final Map<int, List<int>> elementToVoidOpeningIds = {};
    for (final ent in entityMap.values) {
      if (ent.type == 'IFCRELVOIDSELEMENT') {
        final params = ent.splitParams;
        if (params.length >= 6) {
          final relElId = int.tryParse(params[4].replaceAll(RegExp(r'[#\s]'), ''));
          final openingId = int.tryParse(params[5].replaceAll(RegExp(r'[#\s]'), ''));
          if (relElId != null && openingId != null) {
            elementToVoidOpeningIds.putIfAbsent(relElId, () => []).add(openingId);
          }
        }
      }
    }

    // 2.7. Parse Window/Door Fills (IFCRELFILLSELEMENT -> Opening filled by Window/Door/Proxy)
    final Set<int> fillElementIds = {};
    for (final ent in entityMap.values) {
      if (ent.type == 'IFCRELFILLSELEMENT') {
        final params = ent.splitParams;
        if (params.length >= 6) {
          final elId = int.tryParse(params[5].replaceAll(RegExp(r'[#\s]'), ''));
          if (elId != null) fillElementIds.add(elId);
        }
      }
    }

    // 3. Find and generate building elements
    final List<IfcElement> elements = [];
    final Set<String> categories = {};

    for (final ent in entityMap.values) {
      var category = _categorizeIfcType(ent.type);
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
      final layer = _resolveElementLayer(ent.id, shapeRepId, itemToLayerName);

      final lowerName = name.toLowerCase();
      final lowerLayer = layer.toLowerCase();

      // Intelligent architectural categorization:
      if (lowerLayer.contains('покрив') || lowerLayer.contains('roof') ||
          lowerName.contains('roof') || lowerName.contains('покрив') ||
          lowerName.startsWith('rt ') || ent.params.toUpperCase().contains('.ROOF.')) {
        category = 'Roof';
      } else if (lowerLayer.contains('стълби') || lowerLayer.contains('stair') ||
                 lowerName.contains('stair') || lowerName.contains('стълб') ||
                 lowerName.startsWith('sf ') || lowerName.startsWith('sl ')) {
        category = 'Stair';
      } else if (lowerLayer.contains('обзавеждане') || lowerLayer.contains('furniture') ||
                 lowerName.contains('furniture') || lowerName.contains('обзавеждане') ||
                 lowerName.startsWith('fu ')) {
        category = 'Furniture';
      } else if (lowerLayer.contains('повърхности') || lowerLayer.contains('terrain') ||
                 lowerLayer.contains('site') || ent.type == 'IFCSITE' || ent.type == 'IFCGEOGRAPHICELEMENT') {
        category = 'Site';
      } else if (ent.type == 'IFCBUILDINGELEMENTPROXY' && fillElementIds.contains(ent.id)) {
        if (lowerName.contains('door') || lowerName.contains('врата') || lowerName.contains('doo')) {
          category = 'Door';
        } else {
          category = 'Window';
        }
      }

      final transform = placementId != null ? _resolvePlacement(placementId) : _Transform3D.identity;
      
      // Determine element material color from styled item, material layer set, or default category color
      final defaultColor = _getArchitecturalColor(category);
      final elementColor = itemToStyledColor[ent.id] ?? elementToMaterialColor[ent.id] ?? defaultColor;

      final triangles = <Triangle3D>[];
      if (shapeRepId != null) {
        var rawTris = _resolveShapeRepresentation(shapeRepId, transform, elementColor);

        // Apply Opening Voids (Windows and Doors cut into Walls)
        final openingIds = elementToVoidOpeningIds[ent.id];
        if (openingIds != null && openingIds.isNotEmpty) {
          rawTris = _applyOpeningVoids(rawTris, openingIds);
        }

        final filteredTris = _filterDegenerateTriangles(rawTris);
        for (final t in filteredTris) {
          final bool makeDoubleSided = category == 'Roof' ||
              category == 'Site' ||
              (t.color != null && t.color!.a < 0.99) ||
              t.isDoubleSided;
          if (makeDoubleSided != t.isDoubleSided) {
            triangles.add(Triangle3D(
              v0: t.v0,
              v1: t.v1,
              v2: t.v2,
              normal: t.normal,
              color: t.color,
              isDoubleSided: makeDoubleSided,
            ));
          } else {
            triangles.add(t);
          }
        }
      }

      if (triangles.isNotEmpty) {
        final storeyName = elementToStoreyName[ent.id] ?? storeys.first.name;
        categories.add(category);

        elements.add(IfcElement(
          id: ent.id,
          globalId: globalId,
          name: name,
          ifcType: ent.type,
          category: category,
          storeyName: storeyName,
          layer: layer,
          color: elementColor,
          triangles: triangles,
        ));
      }
    }

    // Prune redundant unclipped duplicate walls (e.g. ArchiCAD phantom wall exports
    // where an unclipped raw box was exported concurrently with a trimmed wall at the exact same location)
    _pruneDuplicateGhostWalls(elements);

    // Filter out layers that do not contain any elements
    final usedLayers = elements.map((e) => e.layer.trim()).where((l) => l.isNotEmpty).toSet();
    if (usedLayers.isNotEmpty) {
      layers.removeWhere((l) => !usedLayers.contains(l));
      initialHiddenLayers.removeWhere((l) => !usedLayers.contains(l));
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
        return 'Generic';
      case 'IFCSITE':
      case 'IFCGEOGRAPHICELEMENT':
        return 'Site';
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
      case 'Site':
        return const Color(0xFF8DA385); // Natural Terrain Sage Green
      default:
        return const Color(0xFFC0C0C0);
    }
  }

  void _pruneDuplicateGhostWalls(List<IfcElement> elements) {
    final toRemove = <int>{};
    final walls = elements.where((e) => e.category == 'Wall').toList();
    for (int i = 0; i < walls.length; i++) {
      for (int j = i + 1; j < walls.length; j++) {
        final w1 = walls[i];
        final w2 = walls[j];
        if (w1.name != w2.name) continue;
        if (w1.storeyName != w2.storeyName) continue;

        final diffMinX = (w1.bounds.min.x - w2.bounds.min.x).abs();
        final diffMaxX = (w1.bounds.max.x - w2.bounds.max.x).abs();
        final diffMinY = (w1.bounds.min.y - w2.bounds.min.y).abs();
        final diffMaxY = (w1.bounds.max.y - w2.bounds.max.y).abs();

        if (diffMinX < 5.0 && diffMaxX < 5.0 && diffMinY < 5.0 && diffMaxY < 5.0) {
          final overlapZ = math.min(w1.bounds.max.z, w2.bounds.max.z) - math.max(w1.bounds.min.z, w2.bounds.min.z);
          if (overlapZ > 10.0) {
            // Overlapping in 3D on the same storey with identical XY footprint:
            // One is a duplicate. Suppress the unclipped raw 12-triangle box that extends higher.
            if (w1.triangles.length == 12 && w1.bounds.max.z > w2.bounds.max.z) {
              toRemove.add(w1.id);
            } else if (w2.triangles.length == 12 && w2.bounds.max.z > w1.bounds.max.z) {
              toRemove.add(w2.id);
            }
          }
        }
      }
    }

    if (toRemove.isNotEmpty) {
      elements.removeWhere((e) => toRemove.contains(e.id));
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

  _Transform3D _resolveCartesianTransformationOperator(int opId) {
    final ent = entityMap[opId];
    if (ent == null) return _Transform3D.identity;

    final params = ent.splitParams;
    Vector3 axis1 = const Vector3(1, 0, 0);
    Vector3 axis2 = const Vector3(0, 1, 0);
    Vector3 axis3 = const Vector3(0, 0, 1);
    Vector3 origin = Vector3.zero;
    double scale = 1.0;

    if (params.isNotEmpty && params[0].contains('#')) {
      final a1Id = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
      if (a1Id != null) axis1 = _resolveDirection(a1Id);
    }
    if (params.length > 1 && params[1].contains('#')) {
      final a2Id = int.tryParse(params[1].replaceAll(RegExp(r'[#\s]'), ''));
      if (a2Id != null) axis2 = _resolveDirection(a2Id);
    }
    if (params.length > 2 && params[2].contains('#')) {
      final ptId = int.tryParse(params[2].replaceAll(RegExp(r'[#\s]'), ''));
      if (ptId != null) origin = _resolvePoint(ptId);
    }
    if (params.length > 3 && !params[3].contains('\$')) {
      scale = double.tryParse(params[3].replaceAll(RegExp(r'[#\s]'), '')) ?? 1.0;
    }
    if (params.length > 4 && params[4].contains('#')) {
      final a3Id = int.tryParse(params[4].replaceAll(RegExp(r'[#\s]'), ''));
      if (a3Id != null) axis3 = _resolveDirection(a3Id);
    } else {
      axis3 = axis1.cross(axis2);
      if (axis3.lengthSquared < 1e-6) axis3 = const Vector3(0, 0, 1);
    }

    axis1 = axis1.normalized() * scale;
    axis2 = axis2.normalized() * scale;
    axis3 = axis3.normalized() * scale;

    return _Transform3D(
      m00: axis1.x, m01: axis2.x, m02: axis3.x, tx: origin.x,
      m10: axis1.y, m11: axis2.y, m12: axis3.y, ty: origin.y,
      m20: axis1.z, m21: axis2.z, m22: axis3.z, tz: origin.z,
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
      final params = ent.splitParams;
      if (params.isEmpty) return [];

      final basisCurveId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
      if (basisCurveId == null) return [];
      final basisEnt = entityMap[basisCurveId];
      if (basisEnt == null) return [];

      // Extract Cartesian trim points if available
      Vector3? trimPt1;
      Vector3? trimPt2;
      double? paramVal1;
      double? paramVal2;

      for (final id in ent.referencedIds) {
        if (id == basisCurveId) continue;
        final sub = entityMap[id];
        if (sub != null && sub.type == 'IFCCARTESIANPOINT') {
          if (trimPt1 == null) {
            trimPt1 = _resolvePoint(id);
          } else {
            trimPt2 = _resolvePoint(id);
          }
        }
      }

      // Check parameter values e.g. IFCPARAMETERVALUE(0.), IFCPARAMETERVALUE(316.04)
      final paramMatches = RegExp(r'IFCPARAMETERVALUE\(\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)\s*\)').allMatches(ent.params).toList();
      if (paramMatches.isNotEmpty) {
        paramVal1 = double.tryParse(paramMatches[0].group(1)!);
        if (paramMatches.length > 1) {
          paramVal2 = double.tryParse(paramMatches[1].group(1)!);
        }
      }

      // Check SenseAgreement (.T. or .F.)
      bool senseAgreement = true;
      if (params.length >= 4) {
        if (params[3].contains('.F.')) {
          senseAgreement = false;
        }
      }

      if (basisEnt.type == 'IFCCIRCLE' || basisEnt.type == 'IFCELLIPSE') {
        final circleParams = basisEnt.splitParams;
        double r1 = 1.0;
        double r2 = 1.0;
        if (circleParams.length >= 2) {
          r1 = double.tryParse(circleParams[1].replaceAll(RegExp(r'[#\s]'), '')) ?? 1.0;
          r2 = r1;
        }
        if (basisEnt.type == 'IFCELLIPSE' && circleParams.length >= 3) {
          r2 = double.tryParse(circleParams[2].replaceAll(RegExp(r'[#\s]'), '')) ?? r1;
        }

        Vector3 center = Vector3.zero;
        Vector3 axisU = const Vector3(1, 0, 0);
        Vector3 axisV = const Vector3(0, 1, 0);

        if (circleParams.isNotEmpty && circleParams[0].contains('#')) {
          final posId = int.tryParse(circleParams[0].replaceAll(RegExp(r'[#\s]'), ''));
          if (posId != null) {
            final posEnt = entityMap[posId];
            if (posEnt != null && posEnt.type == 'IFCAXIS2PLACEMENT2D') {
              final placementParams = posEnt.splitParams;
              if (placementParams.isNotEmpty) {
                final ptId = int.tryParse(placementParams[0].replaceAll(RegExp(r'[#\s]'), ''));
                if (ptId != null) {
                  center = _resolvePoint(ptId);
                }
              }
              if (placementParams.length > 1) {
                final dirId = int.tryParse(placementParams[1].replaceAll(RegExp(r'[#\s]'), ''));
                if (dirId != null) {
                  axisU = _resolveDirection(dirId).normalized();
                  axisV = Vector3(-axisU.y, axisU.x, 0);
                }
              }
            } else if (posEnt != null && posEnt.type == 'IFCAXIS2PLACEMENT3D') {
              final t = _resolveAxis2Placement3D(posId);
              center = t.transform(Vector3.zero);
              axisU = (t.transform(const Vector3(1, 0, 0)) - center).normalized();
              axisV = (t.transform(const Vector3(0, 1, 0)) - center).normalized();
            }
          }
        }

        // Determine start and end angles in the local circle plane
        double startAngle = 0.0;
        double endAngle = 2.0 * math.pi;

        if (trimPt1 != null && trimPt2 != null) {
          final v1 = trimPt1 - center;
          final v2 = trimPt2 - center;
          startAngle = math.atan2(v1.dot(axisV), v1.dot(axisU));
          endAngle = math.atan2(v2.dot(axisV), v2.dot(axisU));
        } else if (paramVal1 != null && paramVal2 != null) {
          if (paramVal2.abs() > 2.0 * math.pi || paramVal1.abs() > 2.0 * math.pi) {
            startAngle = paramVal1 * math.pi / 180.0;
            endAngle = paramVal2 * math.pi / 180.0;
          } else {
            startAngle = paramVal1;
            endAngle = paramVal2;
          }
        }

        // Calculate angular sweep based on senseAgreement
        double sweep = 0.0;
        if (senseAgreement) {
          while (endAngle <= startAngle) {
            endAngle += 2.0 * math.pi;
          }
          sweep = endAngle - startAngle;
        } else {
          while (endAngle >= startAngle) {
            endAngle -= 2.0 * math.pi;
          }
          sweep = endAngle - startAngle;
        }

        // Discretize the arc smoothly (up to 32 segments per full circle, min 4)
        final numSegs = math.max(4, (sweep.abs() / (2.0 * math.pi) * 32).ceil());
        final List<Vector3> arcPts = [];

        for (int i = 0; i <= numSegs; i++) {
          if (i == 0 && trimPt1 != null) {
            arcPts.add(trimPt1);
          } else if (i == numSegs && trimPt2 != null) {
            arcPts.add(trimPt2);
          } else {
            final theta = startAngle + sweep * (i / numSegs);
            final pt = center + axisU * (r1 * math.cos(theta)) + axisV * (r2 * math.sin(theta));
            arcPts.add(pt);
          }
        }

        return arcPts;
      } else if (basisEnt.type == 'IFCLINE') {
        if (trimPt1 != null && trimPt2 != null) {
          return [trimPt1, trimPt2];
        }
      }

      if (trimPt1 != null && trimPt2 != null) {
        return [trimPt1, trimPt2];
      }
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
      final params = ent.splitParams;
      if (params.length > 2) {
        final identifier = params[1].replaceAll("'", "").trim().toLowerCase();
        // Skip 2D lines, footprints, clearances, and bounding boxes which cause rendering artifacts
        if (identifier == 'axis' || identifier == 'footprint' || identifier == 'box' || identifier == 'clearance') {
          return tris;
        }
      }
      for (final id in ent.referencedIds) {
        tris.addAll(_resolveGeometryItem(id, parentTransform, color));
      }
    } else {
      tris.addAll(_resolveGeometryItem(shapeId, parentTransform, color));
    }

    return tris;
  }

  List<Triangle3D> _resolveGeometryItem(int itemId, _Transform3D transform, Color defaultColor) {
    final List<Triangle3D> tris = [];
    final ent = entityMap[itemId];
    if (ent == null) return tris;

    final color = itemToStyledColor[itemId] ?? defaultColor;

    // 1. IFCEXTRUDEDAREASOLID (Walls, Slabs, Beams, Columns)
    if (ent.type == 'IFCEXTRUDEDAREASOLID') {
      tris.addAll(_generateExtrudedSolid(ent, transform, color));
    }
    // 2. IFCFACETEDBREP & IFCSHELLBASEDSURFACEMODEL
    else if (ent.type == 'IFCFACETEDBREP' ||
        ent.type == 'IFCSHELLBASEDSURFACEMODEL' ||
        ent.type == 'IFCFACETEDBREPWITHVOIDS' ||
        ent.type == 'IFCSURFACEMODEL') {
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
    // 5. IFCBOOLEANCLIPPINGRESULT & IFCBOOLEANRESULT
    else if (ent.type.contains('BOOLEAN')) {
      final params = ent.splitParams;
      if (params.length >= 3) {
        final firstId = int.tryParse(params[1].replaceAll(RegExp(r'[#\s]'), ''));
        final secondId = int.tryParse(params[2].replaceAll(RegExp(r'[#\s]'), ''));

        if (firstId != null) {
          // Recursively resolve the first operand (may itself be a chained boolean)
          final firstTris = _resolveGeometryItem(firstId, transform, color);

          if (secondId != null) {
            final secondEnt = entityMap[secondId];
            if (secondEnt != null) {
              // IFCHALFSPACESOLID & IFCPOLYGONALBOUNDEDHALFSPACE: roof / plane trimming
              if (secondEnt.type == 'IFCHALFSPACESOLID' ||
                  secondEnt.type == 'IFCPOLYGONALBOUNDEDHALFSPACE') {
                final halfParams = secondEnt.splitParams;
                if (halfParams.isNotEmpty) {
                  final planeId = int.tryParse(halfParams[0].replaceAll(RegExp(r'[#\s]'), ''));
                  if (planeId != null) {
                    final planeDef = _resolvePlane(planeId, transform);
                    if (planeDef != null) {
                      // Building walls stand on the floor and extend up to the roof.
                      // Roof planes cut off the top of the wall, keeping the base of the wall intact.
                      double minZ = double.infinity;
                      Vector3 basePt = planeDef.origin;
                      for (final t in firstTris) {
                        if (t.v0.z < minZ) { minZ = t.v0.z; basePt = t.v0; }
                        if (t.v1.z < minZ) { minZ = t.v1.z; basePt = t.v1; }
                        if (t.v2.z < minZ) { minZ = t.v2.z; basePt = t.v2; }
                      }
                      final double baseDist = (basePt - planeDef.origin).dot(planeDef.normal);
                      final bool keepPositiveSide = baseDist >= 0;

                      if (secondEnt.type == 'IFCPOLYGONALBOUNDEDHALFSPACE' && halfParams.length >= 4) {
                        final posId = int.tryParse(halfParams[2].replaceAll(RegExp(r'[#\s]'), ''));
                        final polyId = int.tryParse(halfParams[3].replaceAll(RegExp(r'[#\s]'), ''));
                        if (posId != null && polyId != null) {
                          final posPlacement = _resolveAxis2Placement3D(posId);
                          final boundaryTransform = transform.multiply(posPlacement);
                          final boundaryPoly = _resolveCurvePoints(polyId);
                          if (boundaryPoly.length >= 3) {
                            final clipped = _clipTrianglesByBoundedHalfSpace(
                              firstTris,
                              planeDef.origin,
                              planeDef.normal,
                              keepPositiveSide,
                              boundaryPoly,
                              boundaryTransform,
                            );
                            return _filterDegenerateTriangles(clipped);
                          }
                        }
                      }

                      final clipped = _clipTrianglesByPlane(firstTris, planeDef.origin, planeDef.normal, keepPositiveSide);
                      return _filterDegenerateTriangles(clipped);
                    }
                  }
                }
              } else if (secondEnt.type == 'IFCFACETEDBREP' ||
                  secondEnt.type == 'IFCSHELLBASEDSURFACEMODEL' ||
                  secondEnt.type == 'IFCFACETEDBREPWITHVOIDS' ||
                  secondEnt.type == 'IFCCLOSEDSHELL' ||
                  secondEnt.type == 'IFCEXTRUDEDAREASOLID' ||
                  secondEnt.type.contains('BREP') ||
                  secondEnt.type.contains('SOLID')) {
                // CSG Boolean difference with a cutting solid Brep (e.g. Archicad 1.ifc wall-roof cutting body)
                final secondTris = _resolveGeometryItem(secondId, transform, color);
                if (secondTris.isNotEmpty && firstTris.isNotEmpty) {
                  final clipped = _clipMeshByCuttingSolid(firstTris, secondTris);
                  return _filterDegenerateTriangles(clipped);
                }
              }
            }
          }
          return firstTris;
        }
      } else if (ent.referencedIds.isNotEmpty) {
        tris.addAll(_resolveGeometryItem(ent.referencedIds[0], transform, color));
      }
    }
    // 6. IFCMAPPEDITEM (Instances of shared Window / Door / Column geometry)
    else if (ent.type == 'IFCMAPPEDITEM') {
      final params = ent.splitParams;
      if (params.length >= 2) {
        final mapId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
        final opId = int.tryParse(params[1].replaceAll(RegExp(r'[#\s]'), ''));
        _Transform3D mapTransform = _Transform3D.identity;
        if (opId != null) {
          final opEnt = entityMap[opId];
          if (opEnt != null) {
            if (opEnt.type.contains('CARTESIANTRANSFORMATIONOPERATOR')) {
              mapTransform = _resolveCartesianTransformationOperator(opId);
            } else if (opEnt.type == 'IFCAXIS2PLACEMENT2D') {
              mapTransform = _resolveAxis2Placement2D(opId);
            } else {
              mapTransform = _resolveAxis2Placement3D(opId);
            }
          }
        }
        if (mapId != null) {
          final mapEnt = entityMap[mapId];
          if (mapEnt != null) {
            final composite = transform.multiply(mapTransform);
            if (mapEnt.type == 'IFCREPRESENTATIONMAP') {
              // #mapId = IFCREPRESENTATIONMAP(#MappingOrigin, #MappedRepresentation)
              final mapParams = mapEnt.splitParams;
              if (mapParams.length >= 2) {
                final repId = int.tryParse(mapParams[1].replaceAll(RegExp(r'[#\s]'), ''));
                if (repId != null) {
                  tris.addAll(_resolveShapeRepresentation(repId, composite, color));
                }
              }
            } else {
              for (final refId in mapEnt.referencedIds) {
                tris.addAll(_resolveShapeRepresentation(refId, composite, color));
              }
            }
          }
        }
      }
    }

    return tris;
  }

  /// Subtracts window and door opening voids (IFCRELVOIDSELEMENT) from wall geometry.
  /// Slices wall faces against opening void boundaries and removes geometry inside the opening hole.
  List<Triangle3D> _applyOpeningVoids(List<Triangle3D> wallTris, List<int> openingIds) {
    if (wallTris.isEmpty || openingIds.isEmpty) return wallTris;

    final List<_Obb> openingOBBs = [];

    for (final opId in openingIds) {
      final opEnt = entityMap[opId];
      if (opEnt == null) continue;

      final params = opEnt.splitParams;
      final placementId = params.length > 5 ? int.tryParse(params[5].replaceAll(RegExp(r'[#\s]'), '')) : null;
      final shapeRepId = params.length > 6 ? int.tryParse(params[6].replaceAll(RegExp(r'[#\s]'), '')) : null;

      if (shapeRepId != null) {
        // Resolve in LOCAL space to get the accurate unrotated bounding box
        final opTrisLocal = _resolveShapeRepresentation(shapeRepId, _Transform3D.identity, Colors.transparent);
        if (opTrisLocal.isNotEmpty) {
          final ptsLocal = opTrisLocal.expand((t) => [t.v0, t.v1, t.v2]).toList();
          final localBox = BoundingBox3D.fromPoints(ptsLocal);
          
          if (localBox.sizeX > 1.0 && localBox.sizeY > 1.0 && localBox.sizeZ > 1.0) {
            final opTransform = placementId != null ? _resolvePlacement(placementId) : _Transform3D.identity;
            
            final origin = opTransform.transform(Vector3.zero);
            final nX = opTransform.transform(const Vector3(1, 0, 0)) - origin;
            final nY = opTransform.transform(const Vector3(0, 1, 0)) - origin;
            final nZ = opTransform.transform(const Vector3(0, 0, 1)) - origin;
            
            final pMin = opTransform.transform(localBox.min);
            final pMax = opTransform.transform(localBox.max);
            
            // Normalize axes in case of scaling
            final nXNorm = nX * (1.0 / (math.sqrt(nX.lengthSquared) + 1e-12));
            final nYNorm = nY * (1.0 / (math.sqrt(nY.lengthSquared) + 1e-12));
            final nZNorm = nZ * (1.0 / (math.sqrt(nZ.lengthSquared) + 1e-12));
            
            openingOBBs.add(_Obb(pMin, pMax, nXNorm, nYNorm, nZNorm));
          }
        }
      }
    }

    if (openingOBBs.isEmpty) return wallTris;

    var currentTris = wallTris;

    for (final obb in openingOBBs) {
      final toSlice = <Triangle3D>[];
      final unaffected = <Triangle3D>[];

      // Calculate OBB projection ranges along its three axes
      final minXProj = math.min(0.0, (obb.pMax - obb.pMin).dot(obb.nX));
      final maxXProj = math.max(0.0, (obb.pMax - obb.pMin).dot(obb.nX));

      final minYProj = math.min(0.0, (obb.pMax - obb.pMin).dot(obb.nY));
      final maxYProj = math.max(0.0, (obb.pMax - obb.pMin).dot(obb.nY));

      final minZProj = math.min(0.0, (obb.pMax - obb.pMin).dot(obb.nZ));
      final maxZProj = math.max(0.0, (obb.pMax - obb.pMin).dot(obb.nZ));

      const double margin = 2.0; // 2mm margin for intersection

      for (final tri in currentTris) {
        final d0x = (tri.v0 - obb.pMin).dot(obb.nX);
        final d1x = (tri.v1 - obb.pMin).dot(obb.nX);
        final d2x = (tri.v2 - obb.pMin).dot(obb.nX);
        final triMinX = math.min(d0x, math.min(d1x, d2x));
        final triMaxX = math.max(d0x, math.max(d1x, d2x));

        if (triMaxX < minXProj - margin || triMinX > maxXProj + margin) {
          unaffected.add(tri);
          continue;
        }

        final d0y = (tri.v0 - obb.pMin).dot(obb.nY);
        final d1y = (tri.v1 - obb.pMin).dot(obb.nY);
        final d2y = (tri.v2 - obb.pMin).dot(obb.nY);
        final triMinY = math.min(d0y, math.min(d1y, d2y));
        final triMaxY = math.max(d0y, math.max(d1y, d2y));

        if (triMaxY < minYProj - margin || triMinY > maxYProj + margin) {
          unaffected.add(tri);
          continue;
        }

        final d0z = (tri.v0 - obb.pMin).dot(obb.nZ);
        final d1z = (tri.v1 - obb.pMin).dot(obb.nZ);
        final d2z = (tri.v2 - obb.pMin).dot(obb.nZ);
        final triMinZ = math.min(d0z, math.min(d1z, d2z));
        final triMaxZ = math.max(d0z, math.max(d1z, d2z));

        if (triMaxZ < minZProj - margin || triMinZ > maxZProj + margin) {
          unaffected.add(tri);
          continue;
        }

        toSlice.add(tri);
      }

      if (toSlice.isEmpty) {
        continue;
      }

      var sliced = toSlice;

      // Slice along Z (sill and lintel)
      sliced = _sliceByPlane(sliced, obb.pMin, obb.nZ);
      sliced = _sliceByPlane(sliced, obb.pMax, obb.nZ);

      // Slice along Y (jambs)
      sliced = _sliceByPlane(sliced, obb.pMin, obb.nY);
      sliced = _sliceByPlane(sliced, obb.pMax, obb.nY);

      // Slice along X (wall faces)
      sliced = _sliceByPlane(sliced, obb.pMin, obb.nX);
      sliced = _sliceByPlane(sliced, obb.pMax, obb.nX);

      // 2. Discard all sub-triangles whose centroid lies inside the oriented box
      const double eps = 0.5; // 0.5mm tolerance
      final filtered = <Triangle3D>[];
      final discarded = <Triangle3D>[];
      for (final tri in sliced) {
        final c = (tri.v0 + tri.v1 + tri.v2) * (1.0 / 3.0);
        
        final dxMin = (c - obb.pMin).dot(obb.nX);
        final dxMax = (c - obb.pMax).dot(obb.nX);
        
        final dyMin = (c - obb.pMin).dot(obb.nY);
        final dyMax = (c - obb.pMax).dot(obb.nY);
        
        final dzMin = (c - obb.pMin).dot(obb.nZ);
        final dzMax = (c - obb.pMax).dot(obb.nZ);
        
        final bool inside = (dxMin >= -eps && dxMax <= eps &&
                             dyMin >= -eps && dyMax <= eps &&
                             dzMin >= -eps && dzMax <= eps);
        if (!inside) {
          filtered.add(tri);
        } else {
          discarded.add(tri);
        }
      }

      // 3. Generate inner reveal surfaces (sill, lintel, left jamb, right jamb)
      // connecting the wall's front and back surfaces across the opening cutout.
      if (discarded.isNotEmpty) {
        double dMinX = double.infinity, dMaxX = -double.infinity;
        double dMinY = double.infinity, dMaxY = -double.infinity;

        for (final tri in discarded) {
          for (final v in [tri.v0, tri.v1, tri.v2]) {
            final px = (v - obb.pMin).dot(obb.nX);
            final py = (v - obb.pMin).dot(obb.nY);
            if (px < dMinX) dMinX = px;
            if (px > dMaxX) dMaxX = px;
            if (py < dMinY) dMinY = py;
            if (py > dMaxY) dMaxY = py;
          }
        }

        final spanX = dMaxX - dMinX;
        final spanY = dMaxY - dMinY;

        // The through-wall (thickness) axis has the smaller wall span
        final bool xIsThroughWall = spanX < spanY;
        final Vector3 tAxis = xIsThroughWall ? obb.nX : obb.nY;
        final Vector3 jAxis = xIsThroughWall ? obb.nY : obb.nX;
        final double tWallMin = xIsThroughWall ? dMinX : dMinY;
        final double tWallMax = xIsThroughWall ? dMaxX : dMaxY;
        final double jMin = xIsThroughWall ? minYProj : minXProj;
        final double jMax = xIsThroughWall ? maxYProj : maxXProj;
        final double zMin = minZProj;
        final double zMax = maxZProj;

        if (tWallMax - tWallMin > 1.0 && jMax - jMin > 1.0 && zMax - zMin > 1.0) {
          final wallColor = wallTris.first.color;

          void addQuad(Vector3 v0, Vector3 v1, Vector3 v2, Vector3 v3, Vector3 desiredNormal) {
            // Tri 1: v0, v1, v2
            final n1 = (v1 - v0).cross(v2 - v0);
            if (n1.dot(desiredNormal) >= 0) {
              filtered.add(Triangle3D(v0: v0, v1: v1, v2: v2, color: wallColor));
            } else {
              filtered.add(Triangle3D(v0: v0, v1: v2, v2: v1, color: wallColor));
            }

            // Tri 2: v0, v2, v3
            final n2 = (v2 - v0).cross(v3 - v0);
            if (n2.dot(desiredNormal) >= 0) {
              filtered.add(Triangle3D(v0: v0, v1: v2, v2: v3, color: wallColor));
            } else {
              filtered.add(Triangle3D(v0: v0, v1: v3, v2: v2, color: wallColor));
            }
          }

          Vector3 pt(double j, double t, double z) {
            return obb.pMin + jAxis * j + tAxis * t + obb.nZ * z;
          }

          // Lintel (underside of wall above opening, facing downward into opening)
          addQuad(
            pt(jMin, tWallMin, zMax),
            pt(jMax, tWallMin, zMax),
            pt(jMax, tWallMax, zMax),
            pt(jMin, tWallMax, zMax),
            -obb.nZ,
          );

          // Sill (top surface of wall below opening, facing upward into opening)
          addQuad(
            pt(jMin, tWallMin, zMin),
            pt(jMax, tWallMin, zMin),
            pt(jMax, tWallMax, zMin),
            pt(jMin, tWallMax, zMin),
            obb.nZ,
          );

          // Left Jamb (at jMin, facing into opening toward jMax)
          addQuad(
            pt(jMin, tWallMin, zMin),
            pt(jMin, tWallMax, zMin),
            pt(jMin, tWallMax, zMax),
            pt(jMin, tWallMin, zMax),
            jAxis,
          );

          // Right Jamb (at jMax, facing into opening toward jMin)
          addQuad(
            pt(jMax, tWallMin, zMin),
            pt(jMax, tWallMax, zMin),
            pt(jMax, tWallMax, zMax),
            pt(jMax, tWallMin, zMax),
            -jAxis,
          );
        }
      }

      unaffected.addAll(filtered);
      currentTris = unaffected;
    }

    return currentTris;
  }

  /// Slices a set of triangles across a plane, keeping BOTH the positive and negative sides.
  List<Triangle3D> _sliceByPlane(List<Triangle3D> inputTris, Vector3 planePoint, Vector3 planeNormal) {
    if (inputTris.isEmpty) return inputTris;
    final List<Triangle3D> result = [];
    final pos = _clipTrianglesByPlane(inputTris, planePoint, planeNormal, true);
    final neg = _clipTrianglesByPlane(inputTris, planePoint, planeNormal, false);
    result.addAll(pos);
    result.addAll(neg);
    return result;
  }

  _Plane3D? _resolvePlane(int planeId, _Transform3D parentTransform) {
    final ent = entityMap[planeId];
    if (ent == null) return null;

    if (ent.type == 'IFCPLANE') {
      final params = ent.splitParams;
      if (params.isNotEmpty) {
        final posId = int.tryParse(params[0].replaceAll(RegExp(r'[#\s]'), ''));
        if (posId != null) {
          // Resolve the plane's own axis placement in its own coordinate frame.
          // parentTransform is identity when called from IFCHALFSPACESOLID (world-space plane).
          // parentTransform may contain parent transform when needed for relative planes.
          final planePlacement = _resolveAxis2Placement3D(posId);
          final composite = parentTransform.multiply(planePlacement);
          final origin = composite.transform(Vector3.zero);
          // The plane's normal is the Z-axis of its coordinate frame
          final normalRaw = composite.transform(const Vector3(0, 0, 1)) - origin;
          final normalLen = normalRaw.lengthSquared;
          if (normalLen < 1e-10) return null;
          final normal = normalRaw * (1.0 / math.sqrt(normalLen));
          return _Plane3D(origin: origin, normal: normal);
        }
      }
    }
    return null;
  }

  /// Clips triangles against a polygon-bounded half-space.
  /// Only triangles (or parts of triangles) whose projection onto the clipping plane
  /// falls inside the [boundaryPoly] polygon are affected by the clipping.
  /// The rest of the geometry is preserved unchanged.
  List<Triangle3D> _clipTrianglesByBoundedHalfSpace(
    List<Triangle3D> inputTris,
    Vector3 planePoint,
    Vector3 planeNormal,
    bool keepPositiveSide,
    List<Vector3> boundaryPoly,
    _Transform3D boundaryTransform,
  ) {
    if (inputTris.isEmpty) return inputTris;

    final List<Triangle3D> result = [];
    const double eps = 1e-4;

    // Build an inverse transform for projecting world points into the boundary local 2D space
    // We use the boundary plane's XY projection
    final bOrigin = boundaryTransform.transform(Vector3.zero);
    final bAxisX = (boundaryTransform.transform(const Vector3(1, 0, 0)) - bOrigin).normalized();
    final bAxisY = (boundaryTransform.transform(const Vector3(0, 1, 0)) - bOrigin).normalized();

    // 2D bounding box of boundaryPoly with generous tolerance so boundary wall faces are included
    double bMinX = double.infinity, bMaxX = -double.infinity;
    double bMinY = double.infinity, bMaxY = -double.infinity;
    for (final p in boundaryPoly) {
      if (p.x < bMinX) bMinX = p.x;
      if (p.x > bMaxX) bMaxX = p.x;
      if (p.y < bMinY) bMinY = p.y;
      if (p.y > bMaxY) bMaxY = p.y;
    }
    const double tol = 100.0; // 100mm tolerance for boundary CAD edge snapping
    bMinX -= tol; bMaxX += tol;
    bMinY -= tol; bMaxY += tol;

    for (final tri in inputTris) {
      final d0 = (tri.v0 - planePoint).dot(planeNormal);
      final d1 = (tri.v1 - planePoint).dot(planeNormal);
      final d2 = (tri.v2 - planePoint).dot(planeNormal);

      // Classify vertices w.r.t. the infinite clipping plane
      final in0 = keepPositiveSide ? (d0 >= -eps) : (d0 <= eps);
      final in1 = keepPositiveSide ? (d1 >= -eps) : (d1 <= eps);
      final in2 = keepPositiveSide ? (d2 >= -eps) : (d2 <= eps);
      final inCount = (in0 ? 1 : 0) + (in1 ? 1 : 0) + (in2 ? 1 : 0);

      // Project vertices to boundary 2D space
      final p0x = (tri.v0 - bOrigin).dot(bAxisX);
      final p0y = (tri.v0 - bOrigin).dot(bAxisY);
      final p1x = (tri.v1 - bOrigin).dot(bAxisX);
      final p1y = (tri.v1 - bOrigin).dot(bAxisY);
      final p2x = (tri.v2 - bOrigin).dot(bAxisX);
      final p2y = (tri.v2 - bOrigin).dot(bAxisY);

      final triMinX = math.min(p0x, math.min(p1x, p2x));
      final triMaxX = math.max(p0x, math.max(p1x, p2x));
      final triMinY = math.min(p0y, math.min(p1y, p2y));
      final triMaxY = math.max(p0y, math.max(p1y, p2y));

      // Rejection test: if triangle 2D bounding box doesn't overlap boundary polygon box
      if (triMaxX < bMinX || triMinX > bMaxX || triMaxY < bMinY || triMinY > bMaxY) {
        result.add(tri);
        continue;
      }

      final centroid = (tri.v0 + tri.v1 + tri.v2) * (1.0 / 3.0);
      final cx = (centroid - bOrigin).dot(bAxisX);
      final cy = (centroid - bOrigin).dot(bAxisY);
      final insideBoundary = _pointInPolygon2D(cx, cy, boundaryPoly) ||
          _pointInPolygon2D(p0x, p0y, boundaryPoly) ||
          _pointInPolygon2D(p1x, p1y, boundaryPoly) ||
          _pointInPolygon2D(p2x, p2y, boundaryPoly) ||
          (triMinX >= bMinX && triMaxX <= bMaxX && triMinY >= bMinY && triMaxY <= bMaxY);

      if (!insideBoundary) {
        // Triangle is outside the boundary polygon → leave it untouched
        result.add(tri);
        continue;
      }

      // Inside boundary → apply half-space clipping
      if (inCount == 3) {
        result.add(tri);
      } else if (inCount == 0) {
        continue;
      } else if (inCount == 1) {
        if (in0) {
          final i1 = _intersectEdge(tri.v0, tri.v1, d0, d1);
          final i2 = _intersectEdge(tri.v0, tri.v2, d0, d2);
          result.add(Triangle3D(v0: tri.v0, v1: i1, v2: i2, color: tri.color));
        } else if (in1) {
          final i1 = _intersectEdge(tri.v1, tri.v2, d1, d2);
          final i2 = _intersectEdge(tri.v1, tri.v0, d1, d0);
          result.add(Triangle3D(v0: tri.v1, v1: i1, v2: i2, color: tri.color));
        } else {
          final i1 = _intersectEdge(tri.v2, tri.v0, d2, d0);
          final i2 = _intersectEdge(tri.v2, tri.v1, d2, d1);
          result.add(Triangle3D(v0: tri.v2, v1: i1, v2: i2, color: tri.color));
        }
      } else if (inCount == 2) {
        if (!in0) {
          final i1 = _intersectEdge(tri.v1, tri.v0, d1, d0);
          final i2 = _intersectEdge(tri.v2, tri.v0, d2, d0);
          result.add(Triangle3D(v0: tri.v1, v1: tri.v2, v2: i2, color: tri.color));
          result.add(Triangle3D(v0: tri.v1, v1: i2, v2: i1, color: tri.color));
        } else if (!in1) {
          final i1 = _intersectEdge(tri.v2, tri.v1, d2, d1);
          final i2 = _intersectEdge(tri.v0, tri.v1, d0, d1);
          result.add(Triangle3D(v0: tri.v2, v1: tri.v0, v2: i2, color: tri.color));
          result.add(Triangle3D(v0: tri.v2, v1: i2, v2: i1, color: tri.color));
        } else {
          final i1 = _intersectEdge(tri.v0, tri.v2, d0, d2);
          final i2 = _intersectEdge(tri.v1, tri.v2, d1, d2);
          result.add(Triangle3D(v0: tri.v0, v1: tri.v1, v2: i2, color: tri.color));
          result.add(Triangle3D(v0: tri.v0, v1: i2, v2: i1, color: tri.color));
        }
      }
    }
    return result;
  }

  /// Point-in-polygon test in 2D projected space (ray casting).
  bool _pointInPolygon2D(double px, double py, List<Vector3> poly) {
    bool inside = false;
    final int n = poly.length;
    int j = n - 1;

    for (int i = 0; i < n; j = i++) {
      final xi = poly[i].x;
      final yi = poly[i].y;
      final xj = poly[j].x;
      final yj = poly[j].y;

      if (((yi > py) != (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi + 1e-10) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  List<Triangle3D> _clipTrianglesByPlane(
    List<Triangle3D> inputTris,
    Vector3 planePoint,
    Vector3 planeNormal,
    bool keepPositiveSide,
  ) {
    if (inputTris.isEmpty || planeNormal.lengthSquared < 1e-6) return inputTris;

    final List<Triangle3D> result = [];
    const double eps = 1e-5;

    for (final tri in inputTris) {
      final d0 = (tri.v0 - planePoint).dot(planeNormal);
      final d1 = (tri.v1 - planePoint).dot(planeNormal);
      final d2 = (tri.v2 - planePoint).dot(planeNormal);

      final in0 = keepPositiveSide ? (d0 >= -eps) : (d0 <= eps);
      final in1 = keepPositiveSide ? (d1 >= -eps) : (d1 <= eps);
      final in2 = keepPositiveSide ? (d2 >= -eps) : (d2 <= eps);

      final inCount = (in0 ? 1 : 0) + (in1 ? 1 : 0) + (in2 ? 1 : 0);

      if (inCount == 3) {
        result.add(tri);
      } else if (inCount == 0) {
        continue;
      } else if (inCount == 1) {
        if (in0) {
          final i1 = _intersectEdge(tri.v0, tri.v1, d0, d1);
          final i2 = _intersectEdge(tri.v0, tri.v2, d0, d2);
          result.add(Triangle3D(v0: tri.v0, v1: i1, v2: i2, color: tri.color));
        } else if (in1) {
          final i1 = _intersectEdge(tri.v1, tri.v2, d1, d2);
          final i2 = _intersectEdge(tri.v1, tri.v0, d1, d0);
          result.add(Triangle3D(v0: tri.v1, v1: i1, v2: i2, color: tri.color));
        } else {
          final i1 = _intersectEdge(tri.v2, tri.v0, d2, d0);
          final i2 = _intersectEdge(tri.v2, tri.v1, d2, d1);
          result.add(Triangle3D(v0: tri.v2, v1: i1, v2: i2, color: tri.color));
        }
      } else if (inCount == 2) {
        if (!in0) {
          final i1 = _intersectEdge(tri.v1, tri.v0, d1, d0);
          final i2 = _intersectEdge(tri.v2, tri.v0, d2, d0);
          result.add(Triangle3D(v0: tri.v1, v1: tri.v2, v2: i2, color: tri.color));
          result.add(Triangle3D(v0: tri.v1, v1: i2, v2: i1, color: tri.color));
        } else if (!in1) {
          final i1 = _intersectEdge(tri.v2, tri.v1, d2, d1);
          final i2 = _intersectEdge(tri.v0, tri.v1, d0, d1);
          result.add(Triangle3D(v0: tri.v2, v1: tri.v0, v2: i2, color: tri.color));
          result.add(Triangle3D(v0: tri.v2, v1: i2, v2: i1, color: tri.color));
        } else {
          final i1 = _intersectEdge(tri.v0, tri.v2, d0, d2);
          final i2 = _intersectEdge(tri.v1, tri.v2, d1, d2);
          result.add(Triangle3D(v0: tri.v0, v1: tri.v1, v2: i2, color: tri.color));
          result.add(Triangle3D(v0: tri.v0, v1: i2, v2: i1, color: tri.color));
        }
      }
    }

    return result;
  }

  /// Slices a building element (such as an extruded wall) against CSG boolean subtraction solids
  /// (e.g. Archicad IFCBOOLEANRESULT with IFCFACETEDBREP or IFCEXTRUDEDAREASOLID roof trimming bodies).
  List<Triangle3D> _clipMeshByCuttingSolid(List<Triangle3D> meshTris, List<Triangle3D> cuttingTris) {
    if (meshTris.isEmpty || cuttingTris.isEmpty) return meshTris;

    // 1. Group cutting solid triangles into unique cutting planes
    final uniquePlanes = <_Plane3D>[];
    for (final tri in cuttingTris) {
      final edge1 = tri.v1 - tri.v0;
      final edge2 = tri.v2 - tri.v0;
      final rawNorm = edge1.cross(edge2);
      final lenSq = rawNorm.lengthSquared;
      if (lenSq < 1e-8) continue;
      final norm = rawNorm * (1.0 / math.sqrt(lenSq));

      bool exists = false;
      for (final up in uniquePlanes) {
        if (up.normal.dot(norm) > 0.99 && (tri.v0 - up.origin).dot(up.normal).abs() < 2.0) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        uniquePlanes.add(_Plane3D(origin: tri.v0, normal: norm));
      }
    }

    var currentTris = meshTris;

    // 2. Identify wall base reference point (minimum Z) to ensure wall bottom is always preserved
    double minZ = double.infinity;
    Vector3 basePt = Vector3.zero;
    for (final t in meshTris) {
      for (final v in [t.v0, t.v1, t.v2]) {
        if (v.z < minZ) {
          minZ = v.z;
          basePt = v;
        }
      }
    }

    // 3. For each plane of the cutting solid, check if it slices strictly through the mesh
    for (final plane in uniquePlanes) {
      double minD = double.infinity;
      double maxD = -double.infinity;
      for (final t in currentTris) {
        for (final v in [t.v0, t.v1, t.v2]) {
          final d = (v - plane.origin).dot(plane.normal);
          if (d < minD) minD = d;
          if (d > maxD) maxD = d;
        }
      }

      // If the plane slices strictly through the mesh (vertices on both sides)
      // and is a cutting roof/slope plane:
      if (minD < -5.0 && maxD > 5.0 && plane.normal.z.abs() > 0.02 && plane.normal.z.abs() < 0.999) {
        final baseDist = (basePt - plane.origin).dot(plane.normal);
        final bool keepPositiveSide = baseDist >= 0;

        currentTris = _clipTrianglesByPlane(currentTris, plane.origin, plane.normal, keepPositiveSide);
      }
    }

    return _filterDegenerateTriangles(currentTris);
  }

  static Vector3 _intersectEdge(Vector3 pIn, Vector3 pOut, double dIn, double dOut) {
    final denom = dIn - dOut;
    final t = (denom.abs() > 1e-8) ? (dIn / denom).clamp(0.0, 1.0) : 0.5;
    return pIn + (pOut - pIn) * t;
  }

  /// Removes degenerate triangles (zero area or extreme coordinates) to prevent visual spikes.
  /// Degenerate triangles can arise from numerical issues in plane clipping.
  static List<Triangle3D> _filterDegenerateTriangles(List<Triangle3D> tris) {
    if (tris.isEmpty) return tris;
    const double minArea = 0.01;       // min 0.01 mm² (IFC uses mm as unit)
    const double maxCoord = 1e6;       // max 1km from origin (reasonable for any building)
    final List<Triangle3D> result = [];
    for (final tri in tris) {
      // Reject if any vertex coordinate is out of plausible range
      if (tri.v0.x.abs() > maxCoord || tri.v0.y.abs() > maxCoord || tri.v0.z.abs() > maxCoord ||
          tri.v1.x.abs() > maxCoord || tri.v1.y.abs() > maxCoord || tri.v1.z.abs() > maxCoord ||
          tri.v2.x.abs() > maxCoord || tri.v2.y.abs() > maxCoord || tri.v2.z.abs() > maxCoord) {
        continue;
      }
      // Reject if triangle has near-zero area (degenerate)
      final e1 = tri.v1 - tri.v0;
      final e2 = tri.v2 - tri.v0;
      final cross = e1.cross(e2);
      if (cross.lengthSquared < minArea * minArea) continue;
      result.add(tri);
    }
    return result;
  }

  Color? _resolveStyleColorFromParam(String styleParam) {
    final styleIds = RegExp(r'#(\d+)').allMatches(styleParam).map((m) => int.parse(m.group(1)!)).toList();
    final queue = <int>[...styleIds];
    final visited = <int>{...styleIds};

    while (queue.isNotEmpty) {
      final currId = queue.removeAt(0);
      final ent = entityMap[currId];
      if (ent == null) continue;

      if (ent.type == 'IFCSURFACESTYLESHADING' || ent.type == 'IFCSURFACESTYLERENDERING') {
        var c = _extractColourRgbFromParams(ent.params);
        if (c != null) {
          final params = ent.splitParams;
          if (params.length > 1) {
            final t = double.tryParse(params[1].trim());
            if (t != null && t > 0.0) {
              final alpha = ((1.0 - t.clamp(0.0, 1.0)) * 255).round().clamp(10, 255);
              c = c.withAlpha(alpha);
            }
          }
          return c;
        }
      } else if (ent.type == 'IFCCOLOURRGB') {
        final c = _extractColourRgbDirect(ent.params);
        if (c != null) return c;
      }

      for (final refId in ent.referencedIds) {
        if (!visited.contains(refId)) {
          visited.add(refId);
          queue.add(refId);
        }
      }
    }
    return null;
  }

  Color? _extractColourRgbFromParams(String params) {
    for (final m in RegExp(r'#(\d+)').allMatches(params)) {
      final id = int.tryParse(m.group(1)!);
      if (id != null) {
        final rgbEnt = entityMap[id];
        if (rgbEnt != null && rgbEnt.type == 'IFCCOLOURRGB') {
          return _extractColourRgbDirect(rgbEnt.params);
        }
      }
    }
    return null;
  }

  Color? _extractColourRgbDirect(String params) {
    final parts = params.split(',');
    if (parts.length >= 3) {
      int start = 0;
      if (parts.length > 3 && (parts[0].trim().startsWith("'") || parts[0].trim() == r'$')) {
        start = 1;
      }
      final r = double.tryParse(parts[start].trim()) ?? 0.8;
      final g = double.tryParse(parts[start + 1].trim()) ?? 0.8;
      final b = double.tryParse(parts[start + 2].trim()) ?? 0.8;
      return Color.fromARGB(
        255,
        (r * 255).round().clamp(0, 255),
        (g * 255).round().clamp(0, 255),
        (b * 255).round().clamp(0, 255),
      );
    }
    return null;
  }

  Color? _resolveMaterialColorFromParam(String matParam) {
    final matIds = RegExp(r'#(\d+)').allMatches(matParam).map((m) => int.parse(m.group(1)!)).toList();
    for (final mId in matIds) {
      final queue = <int>[mId];
      final visited = <int>{mId};
      final rawNames = <String>[];
      final matchedColors = <Color>[];

      while (queue.isNotEmpty) {
        final currId = queue.removeAt(0);
        if (materialToStyledColor.containsKey(currId)) {
          matchedColors.add(materialToStyledColor[currId]!);
        }

        final matEnt = entityMap[currId];
        if (matEnt == null) continue;

        for (final m in RegExp(r"'([^']*)'").allMatches(matEnt.params)) {
          final decoded = IfcParser.decodeIfcString(m.group(1)!);
          if (decoded.isNotEmpty && decoded != r'$') {
            rawNames.add(decoded);
          }
        }

        for (final refId in matEnt.referencedIds) {
          if (!visited.contains(refId)) {
            visited.add(refId);
            queue.add(refId);
          }
        }
      }

      if (matchedColors.isNotEmpty) {
        return matchedColors.first;
      }

      // Check materials from outside-in (usually first layer is exterior)
      for (final name in rawNames) {
        final col = _mapMaterialNameToColor(name);
        if (col != null) return col;
      }
    }
    return null;
  }

  Color? _mapMaterialNameToColor(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.isEmpty) return null;

    // Plaster / Stucco / White Render / Facade / Insulation
    if (lower.contains('plaster') ||
        lower.contains('stucco') ||
        lower.contains('render') ||
        lower.contains('gypsum') ||
        lower.contains('white') ||
        lower.contains('мазилка') ||
        lower.contains('фасада') ||
        lower.contains('шпакловка') ||
        lower.contains('бял') ||
        lower.contains('eps') ||
        lower.contains('xps') ||
        lower.contains('изолация') ||
        lower.contains('вата') ||
        lower.contains('термо') ||
        lower.contains('putz') ||
        lower.contains('crepi')) {
      return const Color(0xFFF4F0E8); // Clean Crisp Architectural White/Sand Plaster
    }

    // Stone / Plinth / Granite
    if (lower.contains('stone') ||
        lower.contains('plinth') ||
        lower.contains('granite') ||
        lower.contains('marble') ||
        lower.contains('limestone') ||
        lower.contains('masonry') ||
        lower.contains('цокъл') ||
        lower.contains('камък') ||
        lower.contains('гранит') ||
        lower.contains('мрамор') ||
        lower.contains('варовик') ||
        lower.contains('зидария') ||
        lower.contains('buntsteinputz')) {
      return const Color(0xFF78726A); // Textured Natural Stone / Plinth Gray-Brown
    }

    // Wood / Timber / Cladding / Siding
    if (lower.contains('wood') ||
        lower.contains('timber') ||
        lower.contains('cladding') ||
        lower.contains('siding') ||
        lower.contains('cedar') ||
        lower.contains('oak') ||
        lower.contains('pine') ||
        lower.contains('larch') ||
        lower.contains('board') ||
        lower.contains('дърво') ||
        lower.contains('дървен') ||
        lower.contains('дъск') ||
        lower.contains('обшивк') ||
        lower.contains('чам') ||
        lower.contains('дъб') ||
        lower.contains('ламперия') ||
        lower.contains('holz') ||
        lower.contains('bois')) {
      return const Color(0xFFB57E4C); // Rich Natural Architectural Timber / Siding
    }

    // Roof / Tiles / Shingles
    if (lower.contains('tile') ||
        lower.contains('shingle') ||
        lower.contains('roof') ||
        lower.contains('terracotta') ||
        lower.contains('slate') ||
        lower.contains('керемид') ||
        lower.contains('покрив') ||
        lower.contains('битум') ||
        lower.contains('dach') ||
        lower.contains('tuile')) {
      if (lower.contains('slate') ||
          lower.contains('dark') ||
          lower.contains('черн') ||
          lower.contains('сив') ||
          lower.contains('anthracite')) {
        return const Color(0xFF3B424D); // Slate Dark Tile
      }
      return const Color(0xFFA64032); // Terracotta Clay Roof Tile
    }


    // Brick
    if (lower.contains('brick') ||
        lower.contains('klinker') ||
        lower.contains('тухл') ||
        lower.contains('ziegel')) {
      return const Color(0xFFA84838); // Red Fired Brick
    }

    // Concrete / Screed
    if (lower.contains('concrete') ||
        lower.contains('screed') ||
        lower.contains('cement') ||
        lower.contains('бетон') ||
        lower.contains('замазка') ||
        lower.contains('цимент') ||
        lower.contains('beton')) {
      return const Color(0xFFA2A7AC); // Structural Concrete
    }

    // Glass / Glazing
    if (lower.contains('glass') ||
        lower.contains('glazing') ||
        lower.contains('pane') ||
        lower.contains('window') ||
        lower.contains('стъкло') ||
        lower.contains('остъклен') ||
        lower.contains('glas') ||
        lower.contains('verre')) {
      return const Color(0x9964B5F6); // Translucent Sky Blue Glass
    }

    // Metal / Steel / Aluminium
    if (lower.contains('metal') ||
        lower.contains('steel') ||
        lower.contains('alumin') ||
        lower.contains('iron') ||
        lower.contains('sheet') ||
        lower.contains('copper') ||
        lower.contains('zinc') ||
        lower.contains('метал') ||
        lower.contains('стомана') ||
        lower.contains('алуминий') ||
        lower.contains('ламарина') ||
        lower.contains('мед') ||
        lower.contains('цинк') ||
        lower.contains('stahl') ||
        lower.contains('blech') ||
        lower.contains('alu')) {
      return const Color(0xFF64748B); // Architectural Slate/Steel Metal
    }

    return null;
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

    // Local solid transform (orientation + position)
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

    // Extrusion direction is in the SOLID's local coordinate frame (same space as polygon points).
    // We keep it in local space and add it to local polygon points BEFORE applying compositeTransform.
    // compositeTransform (= elementWorldTransform * solidLocalTransform) then correctly rotates
    // and translates everything to world space in one step.
    Vector3 extrudeDir = const Vector3(0, 0, 1); // default: along local Z axis
    if (dirId != null) {
      extrudeDir = _resolveDirection(dirId);
    }
    final extrudeVec = extrudeDir * depth; // stays in local solid space

    // Resolve 2D Profile into polygon points (in solid local space)
    final profileEnt = entityMap[profileId];
    List<Vector3> rawPolygon = _resolveProfilePoints(profileId);
    final List<List<Vector3>> innerHoles = [];

    if (profileEnt != null && profileEnt.type == 'IFCARBITRARYPROFILEDEFWITHVOIDS') {
      final pParams = profileEnt.splitParams;
      if (pParams.length >= 3) {
        final outerId = int.tryParse(pParams[2].replaceAll(RegExp(r'[#\s]'), ''));
        if (outerId != null) {
          rawPolygon = _resolveCurvePoints(outerId);
          if (rawPolygon.length > 1 && rawPolygon.first.distanceTo(rawPolygon.last) < 1e-4) {
            rawPolygon.removeLast();
          }
        }
      }
      if (pParams.length >= 4) {
        final innerIds = RegExp(r'#(\d+)').allMatches(pParams[3]).map((m) => int.parse(m.group(1)!)).toList();
        for (final inId in innerIds) {
          final hPts = _resolveCurvePoints(inId);
          if (hPts.length > 1 && hPts.first.distanceTo(hPts.last) < 1e-4) {
            hPts.removeLast();
          }
          if (hPts.length >= 3) {
            innerHoles.add(hPts);
          }
        }
      }
    }

    if (rawPolygon.length < 3) return tris;

    // Ensure outer 2D Profile polygon has Counter-Clockwise (CCW) winding.
    // If authored in CW order, extruding along +Z produces inward-facing normals on top and side surfaces,
    // which causes backface culling to incorrectly hide the slab's top face and front walls!
    double area2d = 0.0;
    for (int i = 0; i < rawPolygon.length; i++) {
      final p1 = rawPolygon[i];
      final p2 = rawPolygon[(i + 1) % rawPolygon.length];
      area2d += (p1.x * p2.y - p2.x * p1.y);
    }
    final List<Vector3> polygon = area2d < 0 ? rawPolygon.reversed.toList() : rawPolygon;

    final int n = polygon.length;
    final List<Vector3> bottom = [];
    final List<Vector3> top = [];

    for (final p in polygon) {
      bottom.add(compositeTransform.transform(p));              // local → world
      top.add(compositeTransform.transform(p + extrudeVec));   // local+extrude → world
    }

    // 1. Outer Side Walls
    for (int i = 0; i < n; i++) {
      final next = (i + 1) % n;
      final b0 = bottom[i];
      final b1 = bottom[next];
      final t0 = top[i];
      final t1 = top[next];

      tris.add(Triangle3D(v0: b0, v1: b1, v2: t1, color: color));
      tris.add(Triangle3D(v0: b0, v1: t1, v2: t0, color: color));
    }

    // 2. Inner Hole Walls (if profile has voids)
    for (final hole in innerHoles) {
      double hArea = 0.0;
      for (int i = 0; i < hole.length; i++) {
        final p1 = hole[i];
        final p2 = hole[(i + 1) % hole.length];
        hArea += (p1.x * p2.y - p2.x * p1.y);
      }
      final List<Vector3> ccwHole = hArea < 0 ? hole.reversed.toList() : hole;
      final List<Vector3> holeBottom = [];
      final List<Vector3> holeTop = [];
      for (final p in ccwHole) {
        holeBottom.add(compositeTransform.transform(p));
        holeTop.add(compositeTransform.transform(p + extrudeVec));
      }
      final int hn = ccwHole.length;
      for (int i = 0; i < hn; i++) {
        final next = (i + 1) % hn;
        final hb0 = holeBottom[i];
        final hb1 = holeBottom[next];
        final ht0 = holeTop[i];
        final ht1 = holeTop[next];

        // Inner walls facing inward into the opening
        tris.add(Triangle3D(v0: hb0, v1: ht1, v2: hb1, color: color));
        tris.add(Triangle3D(v0: hb0, v1: ht0, v2: ht1, color: color));
      }
    }

    // 3. Bottom and Top Caps (bridging holes if present)
    final capPoly = innerHoles.isNotEmpty ? _bridgePolygonWithHoles(polygon, innerHoles) : polygon;
    final List<Vector3> capBottom = [];
    final List<Vector3> capTop = [];
    for (final p in capPoly) {
      capBottom.add(compositeTransform.transform(p));
      capTop.add(compositeTransform.transform(p + extrudeVec));
    }

    // Bottom Cap: robust ear-clipping triangulation (reversed winding for downward face normal)
    final bottomReversed = capBottom.reversed.toList();
    tris.addAll(_triangulatePolygon3D(bottomReversed, color: color));

    // Top Cap: robust ear-clipping triangulation (upward face normal)
    tris.addAll(_triangulatePolygon3D(capTop, color: color));

    return tris;
  }

  /// Bridges holes into an outer planar polygon using seam cuts
  /// so ear-clipping triangulation seamlessly cuts around the holes.
  List<Vector3> _bridgePolygonWithHoles(List<Vector3> outer, List<List<Vector3>> holes) {
    if (holes.isEmpty) return outer;
    var currentPoly = List<Vector3>.from(outer);

    for (final hole in holes) {
      if (hole.length < 3) continue;

      // Find vertex with maximum X in the hole
      int hMaxIdx = 0;
      double maxHx = hole[0].x;
      for (int i = 1; i < hole.length; i++) {
        if (hole[i].x > maxHx) {
          maxHx = hole[i].x;
          hMaxIdx = i;
        }
      }
      final hPt = hole[hMaxIdx];

      // Find closest vertex on currentPoly
      int bestOuterIdx = 0;
      double minScore = double.infinity;
      for (int i = 0; i < currentPoly.length; i++) {
        final oPt = currentPoly[i];
        final distSq = (oPt.x - hPt.x) * (oPt.x - hPt.x) +
            (oPt.y - hPt.y) * (oPt.y - hPt.y) +
            (oPt.z - hPt.z) * (oPt.z - hPt.z);
        final score = (oPt.x >= hPt.x - 1e-4) ? distSq : distSq + 1e10;
        if (score < minScore) {
          minScore = score;
          bestOuterIdx = i;
        }
      }

      final reorderedHole = <Vector3>[];
      for (int i = 0; i < hole.length; i++) {
        reorderedHole.add(hole[(hMaxIdx + i) % hole.length]);
      }
      reorderedHole.add(reorderedHole.first);

      final newPoly = <Vector3>[];
      for (int i = 0; i <= bestOuterIdx; i++) {
        newPoly.add(currentPoly[i]);
      }
      newPoly.addAll(reorderedHole);
      newPoly.add(currentPoly[bestOuterIdx]);
      for (int i = bestOuterIdx + 1; i < currentPoly.length; i++) {
        newPoly.add(currentPoly[i]);
      }

      currentPoly = newPoly;
    }

    return currentPoly;
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
      List<Vector3>? outerPts;
      final innerHoles = <List<Vector3>>[];

      for (final boundId in ent.referencedIds) {
        final boundEnt = entityMap[boundId];
        if (boundEnt != null) {
          final isOuter = boundEnt.type == 'IFCFACEOUTERBOUND' || outerPts == null;
          for (final loopId in boundEnt.referencedIds) {
            final loopEnt = entityMap[loopId];
            if (loopEnt != null && loopEnt.type == 'IFCPOLYLOOP') {
              final pts = loopEnt.referencedIds.map((id) => transform.transform(_resolvePoint(id))).toList();
              if (pts.length >= 3) {
                if (isOuter && outerPts == null) {
                  outerPts = pts;
                } else {
                  innerHoles.add(pts);
                }
              }
            }
          }
        }
      }

      if (outerPts != null) {
        if (innerHoles.isNotEmpty) {
          final bridged = _bridgePolygonWithHoles(outerPts, innerHoles);
          tris.addAll(_triangulatePolygon3D(bridged, color: color));
        } else {
          tris.addAll(_triangulatePolygon3D(outerPts, color: color));
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
            final facePts = <Vector3>[];
            for (final idx in idxMatches) {
              if (idx >= 0 && idx < points.length) {
                facePts.add(points[idx]);
              }
            }
            if (facePts.length >= 3) {
              tris.addAll(_triangulatePolygon3D(facePts, color: color));
            }
          }
        }
      }
    }

    return tris;
  }

  /// Robust 3D Ear-Clipping Polygon Triangulator.
  /// Handles arbitrary convex, concave, L-shaped, U-shaped, and stepped planar polygons.
  /// Prevents false triangles from shooting across concave indentations or flying outside buildings.
  static List<Triangle3D> _triangulatePolygon3D(List<Vector3> rawPts, {Color? color}) {
    // 0. Filter coincident points to prevent degenerate triangles and infinite loops
    final List<Vector3> pts = [];
    for (int i = 0; i < rawPts.length; i++) {
      if (pts.isEmpty) {
        pts.add(rawPts[i]);
      } else {
        final dX = rawPts[i].x - pts.last.x;
        final dY = rawPts[i].y - pts.last.y;
        final dZ = rawPts[i].z - pts.last.z;
        if ((dX * dX + dY * dY + dZ * dZ) > 1e-6) {
          pts.add(rawPts[i]);
        }
      }
    }
    if (pts.length > 1) {
      final dX = pts.last.x - pts.first.x;
      final dY = pts.last.y - pts.first.y;
      final dZ = pts.last.z - pts.first.z;
      if ((dX * dX + dY * dY + dZ * dZ) < 1e-6) {
        pts.removeLast();
      }
    }

    final n = pts.length;
    if (n < 3) return [];
    if (n == 3) {
      return [Triangle3D(v0: pts[0], v1: pts[1], v2: pts[2], color: color)];
    }

    // 1. Calculate polygon normal via Newell's method
    double nx = 0, ny = 0, nz = 0;
    for (int i = 0; i < n; i++) {
      final cur = pts[i];
      final next = pts[(i + 1) % n];
      nx += (cur.y - next.y) * (cur.z + next.z);
      ny += (cur.z - next.z) * (cur.x + next.x);
      nz += (cur.x - next.x) * (cur.y + next.y);
    }

    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 1e-9) {
      return []; // Collinear or degenerate polygon
    }

    // 2. Choose the best 2D projection plane (drop the axis with largest normal component)
    final ax = nx.abs(), ay = ny.abs(), az = nz.abs();
    int dropAxis = 2; // drop Z (project to XY)
    if (ax >= ay && ax >= az) {
      dropAxis = 0; // drop X (project to YZ)
    } else if (ay >= ax && ay >= az) {
      dropAxis = 1; // drop Y (project to XZ)
    }

    // 3. Project to 2D
    final rawPoly2d = <math.Point<double>>[];
    for (final p in pts) {
      if (dropAxis == 0) {
        rawPoly2d.add(math.Point(p.y, p.z));
      } else if (dropAxis == 1) {
        rawPoly2d.add(math.Point(p.x, p.z));
      } else {
        rawPoly2d.add(math.Point(p.x, p.y));
      }
    }

    // 3.5 Filter collinear points in 2D
    final poly2d = <math.Point<double>>[];
    final cleanPts = <Vector3>[];
    for (int i = 0; i < rawPoly2d.length; i++) {
      if (poly2d.length < 2) {
        poly2d.add(rawPoly2d[i]);
        cleanPts.add(pts[i]);
      } else {
        final prev = poly2d[poly2d.length - 2];
        final curr = poly2d.last;
        final next = rawPoly2d[i];
        final cross = (curr.x - prev.x) * (next.y - prev.y) - (curr.y - prev.y) * (next.x - prev.x);
        final dot = (curr.x - prev.x) * (next.x - curr.x) + (curr.y - prev.y) * (next.y - curr.y);
        if (cross.abs() < 1e-4 && dot > 0) {
          // curr is strictly along the same direction, replace it with next
          poly2d[poly2d.length - 1] = next;
          cleanPts[cleanPts.length - 1] = pts[i];
        } else {
          poly2d.add(next);
          cleanPts.add(pts[i]);
        }
      }
    }
    
    // Check if the first point is collinear with last and second
    while (poly2d.length > 2) {
      final prev = poly2d.last;
      final curr = poly2d.first;
      final next = poly2d[1];
      final cross = (curr.x - prev.x) * (next.y - prev.y) - (curr.y - prev.y) * (next.x - prev.x);
      final dot = (curr.x - prev.x) * (next.x - curr.x) + (curr.y - prev.y) * (next.y - curr.y);
      if (cross.abs() < 1e-4 && dot > 0) {
        poly2d.removeAt(0);
        cleanPts.removeAt(0);
      } else {
        break;
      }
    }
    
    // Also check if the last point is collinear with second to last and first
    while (poly2d.length > 2) {
      final prev = poly2d[poly2d.length - 2];
      final curr = poly2d.last;
      final next = poly2d.first;
      final cross = (curr.x - prev.x) * (next.y - prev.y) - (curr.y - prev.y) * (next.x - prev.x);
      final dot = (curr.x - prev.x) * (next.x - curr.x) + (curr.y - prev.y) * (next.y - curr.y);
      if (cross.abs() < 1e-4 && dot > 0) {
        poly2d.removeLast();
        cleanPts.removeLast();
      } else {
        break;
      }
    }

    if (poly2d.length < 3) return [];
    final nClean = poly2d.length;

    // 4. Compute 2D signed area to determine winding order
    double area2d = 0.0;
    for (int i = 0; i < nClean; i++) {
      final p1 = poly2d[i];
      final p2 = poly2d[(i + 1) % nClean];
      area2d += (p1.x * p2.y - p2.x * p1.y);
    }
    final bool ccw = area2d > 0;

    // 5. Ear clipping loop
    final indices = List<int>.generate(nClean, (i) => i);
    final List<Triangle3D> result = [];

    bool isEar(int prevIdx, int earIdx, int nextIdx, List<int> curIndices) {
      final a = poly2d[prevIdx];
      final b = poly2d[earIdx];
      final c = poly2d[nextIdx];

      // Check convexity
      final cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
      if (ccw ? (cross <= 1e-12) : (cross >= -1e-12)) {
        return false; // Reflex or collinear
      }

      // Check if any other remaining vertex lies inside or on the boundary of triangle ABC
      for (final idx in curIndices) {
        if (idx == prevIdx || idx == earIdx || idx == nextIdx) continue;
        final p = poly2d[idx];

        // Seam duplicate vertices at identical coordinates don't invalidate the ear
        final dSqA = (p.x - a.x) * (p.x - a.x) + (p.y - a.y) * (p.y - a.y);
        final dSqB = (p.x - b.x) * (p.x - b.x) + (p.y - b.y) * (p.y - b.y);
        final dSqC = (p.x - c.x) * (p.x - c.x) + (p.y - c.y) * (p.y - c.y);
        if (dSqA < 1e-6 || dSqB < 1e-6 || dSqC < 1e-6) continue;

        final cp1 = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
        final cp2 = (c.x - b.x) * (p.y - b.y) - (c.y - b.y) * (p.x - b.x);
        final cp3 = (a.x - c.x) * (p.y - c.y) - (a.y - c.y) * (p.x - c.x);

        const eps = 1e-6;
        if (ccw) {
          if (cp1 >= -eps && cp2 >= -eps && cp3 >= -eps) return false;
        } else {
          if (cp1 <= eps && cp2 <= eps && cp3 <= eps) return false;
        }
      }

      return true;
    }

    int count = indices.length;
    int watchdog = count * 3;

    while (count > 3 && watchdog-- > 0) {
      bool earFound = false;

      for (int i = 0; i < count; i++) {
        final prev = indices[(i - 1 + count) % count];
        final ear = indices[i];
        final next = indices[(i + 1) % count];

        if (isEar(prev, ear, next, indices)) {
          result.add(Triangle3D(v0: cleanPts[prev], v1: cleanPts[ear], v2: cleanPts[next], color: color));
          indices.removeAt(i);
          count--;
          earFound = true;
          break;
        }
      }

      if (!earFound) {
        // Fallback: clip the vertex that forms the shortest internal edge,
        // prioritizing convex vertices to prevent cutting outside concave polygonal boundaries.
        int bestIdx = 0;
        double minScore = double.infinity;
        
        for (int i = 0; i < count; i++) {
          final pIdx = indices[(i - 1 + count) % count];
          final earIdx = indices[i];
          final nIdx = indices[(i + 1) % count];
          
          final a = poly2d[pIdx];
          final b = poly2d[earIdx];
          final c = poly2d[nIdx];
          
          final cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
          final bool isConvex = ccw ? (cross > 0) : (cross < 0);
          final distSq = (a.x - c.x) * (a.x - c.x) + (a.y - c.y) * (a.y - c.y);
          final score = isConvex ? distSq : distSq + 1e12;
          
          if (score < minScore) {
            minScore = score;
            bestIdx = i;
          }
        }
        
        final prev = indices[(bestIdx - 1 + count) % count];
        final ear = indices[bestIdx];
        final next = indices[(bestIdx + 1) % count];
        
        result.add(Triangle3D(v0: cleanPts[prev], v1: cleanPts[ear], v2: cleanPts[next], color: color));
        indices.removeAt(bestIdx);
        count--;
      }
    }

    if (indices.length == 3) {
      result.add(Triangle3D(
        v0: cleanPts[indices[0]],
        v1: cleanPts[indices[1]],
        v2: cleanPts[indices[2]],
        color: color,
      ));
    }

    // Ensure all triangle face normals match the true Newell 3D polygon normal
    final polyNorm = Vector3(nx, ny, nz).normalized();
    for (int i = 0; i < result.length; i++) {
      final t = result[i];
      if (t.normal.dot(polyNorm) < 0) {
        result[i] = Triangle3D(
          v0: t.v0,
          v1: t.v2,
          v2: t.v1,
          color: t.color,
          isDoubleSided: t.isDoubleSided,
        );
      }
    }

    return result;
  }
}

