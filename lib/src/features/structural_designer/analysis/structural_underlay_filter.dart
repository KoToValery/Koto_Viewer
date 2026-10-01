import '../../dxf_viewer/models/dxf_models.dart';

/// Intelligent CAD layer filter for the BIM Structural Designer module.
///
/// Implements prioritized filtering to isolate structural walls and slabs:
/// 1. If White layers with geometry exist and have lineweights:
///    Keep ONLY the thickest White layer(s) ("Най-дебелия бял цвят"), hiding all others.
/// 2. If lines have no thickness:
///    Keep ALL White layers ("остават всички бели"), hiding non-white layers.
/// 3. If NO White layers exist in the drawing (or only empty/non-model layers):
///    Fallback to structural keywords: 'wall', 'slab', 'плоча', 'стена', 'stena', etc.
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
      'hatch', 'штрих',
      'furn', 'мебел',
      'dim', 'размер',
      'text', 'текст',
      'annot',
      'door', 'врати', 'врата',
      'win', 'прозор',
      'glass', 'стъкло',
      'сан', 'plumb',
      'elec', 'ел',
    ];
    for (final kw in thinKeywords) {
      if (name.contains(kw)) return true;
    }
    return false;
  }

  /// Checks if a layer name matches structural element keywords (wall, slab, column, etc.)
  /// Supports English, Bulgarian (Cyrillic), and Bulgarian (Latinized/transliterated).
  static bool matchesStructuralKeyword(String layerName) {
    final name = layerName.toLowerCase();
    if (isNegativeKeyword(name)) return false;

    const structuralKeywords = [
      // English
      'wall', 'walls',
      'slab', 'slabs',
      'col', 'column', 'columns',
      'beam', 'beams',
      'pillar', 'pillars',
      'foundation',
      'shearwall', 'shear_wall',
      'structure', 'structural',
      'construction',

      // Bulgarian (Cyrillic)
      'стена', 'стени', 'стен',
      'плоча', 'плочи', 'плоч',
      'колона', 'колони',
      'греда', 'греди',
      'стб', 'носещ', 'носещи', 'носеща',
      'структура',
      'фундамент',
      'зид', 'зидария',
      'бетон',
      'шайба', 'шайби', // Bulgarian structural engineering term for shear walls
      'констр', 'конструкция',

      // Bulgarian (Latinized / Transliterated)
      'stena', 'steni',
      'plocha', 'ploca', 'plochi', 'ploci',
      'kolona', 'koloni',
      'greda', 'gredi',
      'zid', 'zidar',
      'beton',
      'shaiba', 'shaibi',
      'konstr',
    ];

    for (final kw in structuralKeywords) {
      if (name.contains(kw)) return true;
    }
    return false;
  }

  /// Determines the set of layer names that should remain visible for the structural underlay.
  ///
  /// Filtering logic:
  /// 1. Finds all White layers that actually contain entities.
  /// 2. If White layers exist:
  ///    - If any have thickness > 0: isolates the thickest White layers (max lineweight).
  ///    - If none have thickness: keeps all White layers.
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

    // Check if any layers explicitly match structural keywords
    final keywordLayers = candidateList
        .where((l) => matchesStructuralKeyword(l.name))
        .toList();

    if (whiteLayers.isNotEmpty) {
      // Calculate max thickness among white layers
      double maxWhiteLw = 0.0;
      for (final l in whiteLayers) {
        final lw = getLayerThickness(l, entitiesByLayer[l.name]);
        if (lw > maxWhiteLw) maxWhiteLw = lw;
      }

      if (maxWhiteLw > 0.0) {
        // "Най-дебелия Бял цвят да остава, всички други се скриват."
        final hasWhiteKeywords = whiteLayers.any((l) => matchesStructuralKeyword(l.name));
        final thickestWhite = whiteLayers.where((l) {
          final lw = getLayerThickness(l, entitiesByLayer[l.name]);
          if (hasWhiteKeywords) {
            // When structural keyword layers are present, keep all white structural layers
            if (matchesStructuralKeyword(l.name)) return true;
            return false;
          }
          return lw >= maxWhiteLw - 0.005;
        }).toList();

        return thickestWhite.map((l) => l.name).toSet();
      } else {
        // "Ако нямат линиите дебелина- остават всички бели"
        return whiteLayers.map((l) => l.name).toSet();
      }
    }

    // Step 2: "ако няма бели тогава ще филтрираме по думи wall, slab, плоча,стена,stena и т.н."
    return keywordLayers.map((l) => l.name).toSet();
  }
}
