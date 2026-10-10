import 'dart:math' as math;
import 'drawing_frame_detector.dart';
import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import 'wall_axis_detector.dart';

/// Intelligent CAD layer filter for the BIM Structural Designer module.
///
/// Implements prioritized filtering to isolate structural walls and slabs:
/// 1. If White layers with geometry exist and have lineweights:
///    Keep ONLY the thickest White layer(s) ("Най-дебелия бял цвят"), hiding all others.
/// 2. If lines have no thickness:
///    Keep ALL White layers ("остават всички бели"), hiding non-white layers.
/// 3. If NO White layers exist in the drawing (or only empty/non-model layers):
///    Geometrically detects wall pairs (without hardcoded keywords) and retains structural slabs/columns.
class StructuralUnderlayFilter {
  const StructuralUnderlayFilter._();

  /// Checks if a layer (or its constituent entities) is White.
  ///
  /// In AutoCAD / DXF:
  /// - ACI 7 is White (rendered white on dark CAD backgrounds).
  /// - ACI 255 is pure White (0xFFFFFF).
  /// - ACI 0 is ByBlock (defaults to White).
  /// - TrueColor (24-bit 0x00RRGGBB) with R, G, B >= 220 is White.
  static bool isWhiteLayer(DxfLayer layer, [List<DxfEntity>? layerEntities]) {
    // 1. TrueColor (Group 420): 24-bit integer 0x00RRGGBB
    if (layer.trueColor != null && layer.trueColor! > 0) {
      final rgb = layer.trueColor! & 0x00FFFFFF;
      final r = (rgb >> 16) & 0xFF;
      final g = (rgb >> 8) & 0xFF;
      final b = rgb & 0xFF;
      if (r >= 220 && g >= 220 && b >= 220) return true;
      return false; // Explicit non-white TrueColor
    }

    // 2. AutoCAD Color Index (ACI)
    final idx = layer.colorIndex.abs();
    if (idx == 7 || idx == 255 || idx == 0) {
      // If entities exist, check whether they override the layer color away from white
      if (layerEntities != null && layerEntities.isNotEmpty) {
        if (layerEntities.every((e) => e is DxfHatch)) return false;
        int nonWhiteEntities = 0;
        int whiteEntities = 0;
        for (final e in layerEntities) {
          if (e.colorIndex != null && e.colorIndex != 256 && e.colorIndex != 0) {
            final eIdx = e.colorIndex!.abs();
            if (eIdx == 7 || eIdx == 255) {
              whiteEntities++;
            } else {
              nonWhiteEntities++;
            }
          } else if (e.trueColor != null && e.trueColor! > 0) {
            final rgb = e.trueColor! & 0x00FFFFFF;
            final r = (rgb >> 16) & 0xFF;
            final g = (rgb >> 8) & 0xFF;
            final b = rgb & 0xFF;
            if (r >= 220 && g >= 220 && b >= 220) {
              whiteEntities++;
            } else {
              nonWhiteEntities++;
            }
          } else {
            whiteEntities++; // Inherits layer's white color
          }
        }
        if (whiteEntities == 0 && nonWhiteEntities > 0) return false;
      }
      return true;
    }

    // 3. Layer colorIndex is non-white (e.g. 1-6, 8-254),
    // but check if majority of entities on this layer are explicitly White
    if (layerEntities != null && layerEntities.isNotEmpty) {
      int whiteCount = 0;
      for (final e in layerEntities) {
        if (e.colorIndex != null) {
          final eIdx = e.colorIndex!.abs();
          if (eIdx == 7 || eIdx == 255) whiteCount++;
        } else if (e.trueColor != null && e.trueColor! > 0) {
          final rgb = e.trueColor! & 0x00FFFFFF;
          final r = (rgb >> 16) & 0xFF;
          final g = (rgb >> 8) & 0xFF;
          final b = rgb & 0xFF;
          if (r >= 220 && g >= 220 && b >= 220) whiteCount++;
        }
      }
      if (whiteCount > (layerEntities.length * 0.5)) return true;
    }

    return false;
  }

  /// Calculates effective lineweight (thickness) of a layer in millimeters.
  static double getLayerThickness(DxfLayer layer, [List<DxfEntity>? layerEntities]) {
    double lw = layer.customLineweight ?? layer.lineweight ?? 0.0;
    if (layer.isThick && lw < 0.35) {
      lw = 0.70;
    }
    if (layerEntities != null && layerEntities.isNotEmpty) {
      for (final e in layerEntities) {
        if (e.lineWeight != null && e.lineWeight! > lw) {
          lw = e.lineWeight!;
        }
      }
    }
    return lw > 0 ? lw : 0.0;
  }

  /// Checks if a layer name matches obvious non-structural clutter (hatches, furniture, text, dimensions).
  static bool isNegativeKeyword(String layerName) {
    final name = layerName.toLowerCase();
    const thinKeywords = [
      'defpoints',
      'hatch', 'штрих', 'щрих',
      'fill', 'запълване', 'плътно',
      'pattern',
      'insul', 'изолац', 'изолация', 'xps', 'eps', 'стиропор', 'вата', 'термо',
      'furn', 'мебел', 'обзавеждане', 'interior',
      'dim', 'размер', 'размери',
      'text', 'текст', 'надпис', 'надписи',
      'annot',
      'door', 'врати', 'врата',
      'win', 'прозор',
      'glass', 'стъкло',
      'сан', 'plumb', 'санитария',
      'elec', 'ел',
      'стълби', 'стълба', 'стълбище', 'stairs', 'stair', 'staircase', 'steps',
      'парапет', 'парапети', 'railing', 'railings', 'balustrade', 'handrail',
      'линии', 'линия',
      'border', 'ramka', 'рамка', 'sheet', 'лист', 'format', 'формат', 'stamp', 'печат',
      'антетка', 'antetka', 'таблица', 'таблици', 'table', 'подпис', 'подписи', 'sign',
      'котировки', 'котировка', 'разрези', 'разрез', 'section', 'sections',
    ];
    for (final kw in thinKeywords) {
      if (name.contains(kw)) return true;
    }
    // Check whole tokens for generic "line" / "lines" / "коти" to avoid substring collision with outline, guideline, etc.
    final tokens = name.split(RegExp(r'[^a-zA-Z0-9а-яА-Я]+'));
    if (tokens.contains('line') || tokens.contains('lines') || tokens.contains('линия') || tokens.contains('линии') || tokens.contains('коти')) {
      return true;
    }
    return false;
  }

  /// Checks if a layer name matches non-wall and non-slab structural element keywords (column, beam, shear wall, etc.)
  /// Supports English, Bulgarian (Cyrillic), and Bulgarian (Latinized/transliterated).
  /// Note: Walls and slabs are detected geometrically without hardcoded keywords.
  static bool matchesStructuralKeyword(String layerName) {
    final name = layerName.toLowerCase();
    if (isNegativeKeyword(name)) return false;

    const structuralKeywords = [
      // English
      'col', 'cols', 'column', 'columns',
      'beam', 'beams',
      'pillar', 'pillars',
      'shear', 'shearwall', 'shear_wall',
      'rc_col', 'rc_wall',
      'foundation',
      'structure', 'structural',
      'construction',

      // Bulgarian (Cyrillic)
      'колона', 'колони',
      'шайба', 'шайби',
      'греда', 'греди',
      'стб', 'сб', 'к-', 'ш-', 'к_', 'ш_',
      'структура',
      'фундамент',
      'констр', 'конструкция',

      // Bulgarian (Latinized / Transliterated)
      'kolona', 'koloni',
      'shaiba', 'shayba',
      'stb',
      'greda', 'gredi',
      'konstr',
    ];

    for (final kw in structuralKeywords) {
      if (name.contains(kw)) return true;
    }
    return false;
  }

  /// Auxiliary dictionary check for slab keywords.
  /// Note: Primary slab detection is purely geometric via [detectSlabLayers].
  static bool matchesSlabKeyword(String layerName) {
    final name = layerName.toLowerCase();
    if (isNegativeKeyword(name)) return false;

    const keywords = [
      'slab', 'slabs',
      'плоча', 'плочи', 'плоч',
      'plocha', 'ploca', 'plochi', 'ploci',
    ];
    for (final kw in keywords) {
      if (name.contains(kw)) return true;
    }
    return false;
  }

  /// Geometrically detects slab layers in [document] by checking for closed perimeter
  /// polylines/polygons of architectural building/room dimensions, with keyword matching
  /// as an auxiliary fallback.
  static SlabLayerDetectionResult detectSlabLayers(
    DxfDocument document, {
    Iterable<DxfEntity>? entities,
    Map<String, DxfBlock>? blocks,
  }) {
    final frames = DrawingFrameDetector.documentFrames(document);
    final entityCounts = <String, int>{};
    final entitiesByLayer = <String, List<DxfEntity>>{};
    final allEntities = entities ?? document.entities;
    for (final e in allEntities) {
      if (e.isPaperSpace || frames.contains(e)) continue;
      final name = e.layer.trim();
      entityCounts[name] = (entityCounts[name] ?? 0) + 1;
      entitiesByLayer.putIfAbsent(name, () => []).add(e);
    }
    final allBlocks = blocks ?? document.blocks;
    for (final b in allBlocks.values) {
      for (final e in b.entities) {
        if (frames.contains(e)) continue;
        final name = e.layer.trim();
        entityCounts[name] = (entityCounts[name] ?? 0) + 1;
        entitiesByLayer.putIfAbsent(name, () => []).add(e);
      }
    }

    final detected = <String>[];
    final empty = <String>[];
    bool matchedAny = false;

    for (final layer in document.layers.values) {
      final layerEntities = entitiesByLayer[layer.name] ?? const [];
      final count = entityCounts[layer.name] ?? 0;

      // 1. Geometric detection: check if layer contains closed polyline or line loops
      // with architectural slab dimensions (W >= 1000mm, H >= 1000mm, Area >= 1.0 m²).
      bool hasGeometricSlab = false;
      if (isNegativeKeyword(layer.name)) continue;
      for (final e in layerEntities) {
        if (e is DxfLwPolyline && e.isClosed && e.vertices.length >= 3) {
          final pts = e.vertices.map((v) => Offset(v.x, v.y)).toList();
          final bbox = Rect.fromPoints(
            Offset(pts.map((p) => p.dx).reduce(math.min), pts.map((p) => p.dy).reduce(math.min)),
            Offset(pts.map((p) => p.dx).reduce(math.max), pts.map((p) => p.dy).reduce(math.max)),
          );
          if (bbox.width >= 1000.0 && bbox.height >= 1000.0) {
            hasGeometricSlab = true;
            break;
          }
        } else if (e is DxfPolyline && e.isClosed && e.vertices.length >= 3) {
          final pts = e.vertices.map((v) => Offset(v.x, v.y)).toList();
          final bbox = Rect.fromPoints(
            Offset(pts.map((p) => p.dx).reduce(math.min), pts.map((p) => p.dy).reduce(math.min)),
            Offset(pts.map((p) => p.dx).reduce(math.max), pts.map((p) => p.dy).reduce(math.max)),
          );
          if (bbox.width >= 1000.0 && bbox.height >= 1000.0) {
            hasGeometricSlab = true;
            break;
          }
        }
      }

      final isKeywordMatch = matchesSlabKeyword(layer.name);
      if (hasGeometricSlab || isKeywordMatch) {
        matchedAny = true;
        if (entityCounts.isEmpty || count > 0) {
          detected.add(layer.name);
        } else {
          empty.add(layer.name);
        }
      }
    }

    return SlabLayerDetectionResult(
      detectedLayers: detected,
      emptyLayers: empty,
      foundAny: matchedAny,
    );
  }

  /// Determines the set of layer names that should remain visible for the structural underlay.
  ///
  /// Filtering logic:
  /// 1. Finds all White layers that actually contain entities.
  /// 2. If White layers exist:
  ///    - Isolates thickest White layer(s) (25cm main walls).
  ///    - Preserves 12cm partition walls (same white color or distinct layer with 12cm/partition keywords or secondary wall lineweight).
  ///    - Preserves layers matching slab keywords (slab, плоча, etc.).
  ///    - If none have thickness: keeps all White layers plus partition and slab layers without rigid keyword filtering.
  /// 3. If NO White layers exist in the drawing (or only empty/non-model layers):
  ///    - Falls back to structural keywords (wall, slab, плоча, стена, stena, etc.).
  static Set<String> filterLayers({
    required Iterable<DxfLayer> layers,
    Iterable<DxfEntity>? entities,
    Map<String, DxfBlock>? blocks,
  }) {
    final layerList = layers.toList();
    if (layerList.isEmpty) return {};

    // Group entities and count per layer
    final entitiesByLayer = <String, List<DxfEntity>>{};
    final entityCounts = <String, int>{};

    if (entities != null) {
      for (final e in entities) {
        final name = e.layer.trim();
        entitiesByLayer.putIfAbsent(name, () => []).add(e);
        entityCounts[name] = (entityCounts[name] ?? 0) + 1;
      }
    }

    if (blocks != null) {
      for (final b in blocks.values) {
        for (final e in b.entities) {
          final name = e.layer.trim();
          entitiesByLayer.putIfAbsent(name, () => []).add(e);
          entityCounts[name] = (entityCounts[name] ?? 0) + 1;
        }
      }
    }

    // Only consider non-empty layers when entity count data is available
    final candidateList = entityCounts.isNotEmpty
        ? layerList.where((l) => (entityCounts[l.name] ?? 0) > 0).toList()
        : layerList;

    // Step 1: Find White layers (excluding DEFPOINTS and negative clutter)
    final whiteLayers = candidateList
        .where((l) => !isNegativeKeyword(l.name) && isWhiteLayer(l, entitiesByLayer[l.name]))
        .toList();

    // Geometric slab layer detection (perimeter polylines of building/room scale)
    final docForSlabs = DxfDocument(
      headerVars: const {},
      bounds: Rect.zero,
      entityStats: const {},
      layers: {for (final l in candidateList) l.name: l},
      entities: entities?.toList() ?? const [],
      blocks: blocks ?? {},
    );
    final detectedSlabLayers = detectSlabLayers(docForSlabs, entities: entities, blocks: blocks).detectedLayers.toSet();

    // Check if any layers match structural keywords or geometric slab detection
    final structuralLayers = candidateList
        .where((l) => matchesStructuralKeyword(l.name) || detectedSlabLayers.contains(l.name))
        .toList();

    if (whiteLayers.isNotEmpty) {
      // Calculate max thickness among white layers
      double maxWhiteLw = 0.0;
      for (final l in whiteLayers) {
        final lw = getLayerThickness(l, entitiesByLayer[l.name]);
        if (lw > maxWhiteLw) maxWhiteLw = lw;
      }

      if (maxWhiteLw > 0.0) {
        final preservedWhite = whiteLayers.where((l) {
          final lw = getLayerThickness(l, entitiesByLayer[l.name]);

          // 1. Thickest White layer(s) (main walls)
          if (lw >= maxWhiteLw - 0.005) return true;

          // 2. Structural non-wall elements (slabs, columns, etc.)
          if (matchesStructuralKeyword(l.name) || detectedSlabLayers.contains(l.name)) return true;

          // 3. Secondary wall thickness: 12cm partition walls drawn with medium pen
          // (e.g. 0.20mm - 0.35mm when main walls are 0.50mm - 0.70mm)
          // Preserves medium white walls without any hardcoded keyword!
          if (maxWhiteLw >= 0.35 && lw >= 0.20 && !isNegativeKeyword(l.name)) {
            return true;
          }

          return false;
        }).toList();

        // Also check if any non-white layers match slab or structural elements
        final extraStructuralLayers = candidateList.where((l) =>
            !whiteLayers.contains(l) &&
            (matchesStructuralKeyword(l.name) || detectedSlabLayers.contains(l.name))).map((l) => l.name);

        final result = preservedWhite.map((l) => l.name).toSet();
        result.addAll(extraStructuralLayers);
        return result;
      } else {
        // When lines have no thickness, all white layers stay plus slabs/structural layers
        final extraStructural = candidateList
            .where((l) => matchesStructuralKeyword(l.name) || detectedSlabLayers.contains(l.name))
            .map((l) => l.name);

        final result = whiteLayers.map((l) => l.name).toSet();
        result.addAll(extraStructural);
        return result;
      }
    }

    // Step 2: When NO White layers exist in the drawing:
    // 1. If geometry (entities) is provided, discover walls geometrically via WallAxisDetector (no hardcoded words)
    if (entities != null && entities.isNotEmpty) {
      final doc = DxfDocument(
        headerVars: const {},
        bounds: Rect.zero,
        entityStats: const {},
        layers: {for (final l in candidateList) l.name: l},
        entities: entities.toList(),
        blocks: blocks ?? {},
      );
      final wallResult = WallAxisDetector.detect(doc);
      if (wallResult.hasWallsFound) {
        final detectedWallLayers = wallResult.selectedWallPairs
            .expand((p) => [p.segmentA.sourceLayer, p.segmentB.sourceLayer])
            .toSet();
        final extraStructural = candidateList
            .where((l) => matchesStructuralKeyword(l.name) || detectedSlabLayers.contains(l.name))
            .map((l) => l.name);
        return {...detectedWallLayers, ...extraStructural};
      }
    }

    // 2. Otherwise fall back to non-wall structural elements (slabs, columns, beams)
    return structuralLayers.map((l) => l.name).toSet();
  }
}

/// Result of detecting slab layers by keywords in a CAD underlay drawing.
class SlabLayerDetectionResult {
  /// Layer names matching slab keywords that contain at least 1 entity.
  final List<String> detectedLayers;

  /// Layer names matching slab keywords that contain 0 entities.
  final List<String> emptyLayers;

  /// Whether any layer matched slab keywords (regardless of entity count).
  final bool foundAny;

  const SlabLayerDetectionResult({
    required this.detectedLayers,
    required this.emptyLayers,
    required this.foundAny,
  });

  /// Whether at least one valid, non-empty slab layer was detected.
  bool get hasValidLayers => detectedLayers.isNotEmpty;

  /// Whether slab layers were matched by name but all were completely empty.
  bool get isEmptyMatch => foundAny && detectedLayers.isEmpty;
}
