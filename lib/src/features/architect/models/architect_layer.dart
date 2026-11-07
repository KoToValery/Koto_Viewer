// === SECTION: ARCHITECT LAYER MODEL ===

import '../../../core/l10n/generated/app_localizations.dart';

/// Architectural CAD Layer representation.
/// Supports standard predefined layers (walls, doors, slabs, etc.) and custom user layers.
class ArchitectLayer {
  final String id;
  final String name;
  final bool isStandard;
  final bool visible;
  final bool locked;
  final int? colorValue;

  const ArchitectLayer({
    required this.id,
    required this.name,
    this.isStandard = false,
    this.visible = true,
    this.locked = false,
    this.colorValue,
  });

  ArchitectLayer copyWith({
    String? name,
    bool? isStandard,
    bool? visible,
    bool? locked,
    int? colorValue,
    bool clearColor = false,
  }) => ArchitectLayer(
    id: id,
    name: name ?? this.name,
    isStandard: isStandard ?? this.isStandard,
    visible: visible ?? this.visible,
    locked: locked ?? this.locked,
    colorValue: clearColor ? null : (colorValue ?? this.colorValue),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (isStandard) 'isStandard': true,
    if (!visible) 'visible': false,
    if (locked) 'locked': true,
    if (colorValue != null) 'colorValue': colorValue,
  };

  factory ArchitectLayer.fromJson(Map<String, dynamic> json) => ArchitectLayer(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['id'] as String,
    isStandard: json['isStandard'] == true,
    visible: json['visible'] != false,
    locked: json['locked'] == true,
    colorValue: (json['colorValue'] as num?)?.toInt(),
  );

  String localizedName(AppLocalizations l) {
    return switch (id) {
      'A-WALL' => l.architectLayerWalls,
      'A-DOOR' => l.architectLayerDoors,
      'A-WINDOW' => l.architectLayerWindows,
      'A-SLAB' => l.architectLayerSlabs,
      'A-ROOF' => l.architectLayerRoofs,
      'S-COLS' => l.architectLayerColumns,
      'S-BEAM' => l.architectLayerBeams,
      'A-STRS' => l.architectLayerStairs,
      'A-AREA' => l.architectLayerZones,
      'A-DIMS' => l.architectLayerDimensions,
      'A-TEXT' => l.architectLayerText,
      'A-GRID' => l.architectLayerGrid,
      'A-HATCH' => l.architectLayerHatches,
      'A-CAD' => l.architectLayerCad,
      'A-FURN' => l.architectLayerFurniture,
      'A-SITE' => l.architectLayerDrainage,
      'A-XREF' => l.architectLayerCadUnderlay,
      'A-RAST' => l.architectLayerRasterUnderlay,
      'G-TOPO' => l.architectLayerGeodesyContours,
      'L-TERR-EXST' => l.architectLayerTerrainExisting,
      'L-TERR-PROP' => l.architectLayerTerrainProposed,
      'L-PATH' => l.architectLayerPathways,
      'L-VEGE' => l.architectLayerVegetation,
      _ => name,
    };
  }

  static const String wallLayerId = 'A-WALL';
  static const String doorLayerId = 'A-DOOR';
  static const String windowLayerId = 'A-WINDOW';
  static const String slabLayerId = 'A-SLAB';
  static const String roofLayerId = 'A-ROOF';
  static const String columnLayerId = 'S-COLS';
  static const String beamLayerId = 'S-BEAM';
  static const String stairLayerId = 'A-STRS';
  static const String zoneLayerId = 'A-AREA';
  static const String dimensionLayerId = 'A-DIMS';
  static const String textLayerId = 'A-TEXT';
  static const String gridLayerId = 'A-GRID';
  static const String hatchLayerId = 'A-HATCH';
  static const String cadLayerId = 'A-CAD';
  static const String furnitureLayerId = 'A-FURN';
  static const String drainageLayerId = 'A-SITE';
  static const String cadUnderlayLayerId = 'A-XREF';
  static const String rasterUnderlayLayerId = 'A-RAST';
  static const String geodesyLayerId = 'G-TOPO';
  static const String terrainExistingLayerId = 'L-TERR-EXST';
  static const String terrainProposedLayerId = 'L-TERR-PROP';
  static const String pathwayLayerId = 'L-PATH';
  static const String vegetationLayerId = 'L-VEGE';
  static const String streetLayerId = 'L-ROAD';

  static List<ArchitectLayer> defaultLayers() => const [
    ArchitectLayer(id: wallLayerId, name: 'A-WALL', isStandard: true),
    ArchitectLayer(id: doorLayerId, name: 'A-DOOR', isStandard: true),
    ArchitectLayer(id: windowLayerId, name: 'A-WINDOW', isStandard: true),
    ArchitectLayer(id: slabLayerId, name: 'A-SLAB', isStandard: true),
    ArchitectLayer(id: roofLayerId, name: 'A-ROOF', isStandard: true),
    ArchitectLayer(id: columnLayerId, name: 'S-COLS', isStandard: true),
    ArchitectLayer(id: beamLayerId, name: 'S-BEAM', isStandard: true),
    ArchitectLayer(id: stairLayerId, name: 'A-STRS', isStandard: true),
    ArchitectLayer(id: zoneLayerId, name: 'A-AREA', isStandard: true),
    ArchitectLayer(id: dimensionLayerId, name: 'A-DIMS', isStandard: true),
    ArchitectLayer(id: textLayerId, name: 'A-TEXT', isStandard: true),
    ArchitectLayer(id: gridLayerId, name: 'A-GRID', isStandard: true),
    ArchitectLayer(id: hatchLayerId, name: 'A-HATCH', isStandard: true),
    ArchitectLayer(id: cadLayerId, name: 'A-CAD', isStandard: true),
    ArchitectLayer(id: furnitureLayerId, name: 'A-FURN', isStandard: true),
    ArchitectLayer(id: drainageLayerId, name: 'A-SITE', isStandard: true),
    ArchitectLayer(id: cadUnderlayLayerId, name: 'A-XREF', isStandard: true),
    ArchitectLayer(id: rasterUnderlayLayerId, name: 'A-RAST', isStandard: true),
    ArchitectLayer(id: geodesyLayerId, name: 'G-TOPO', isStandard: true),
    ArchitectLayer(
      id: terrainExistingLayerId,
      name: 'L-TERR-EXST',
      isStandard: true,
    ),
    ArchitectLayer(
      id: terrainProposedLayerId,
      name: 'L-TERR-PROP',
      isStandard: true,
    ),
    ArchitectLayer(id: pathwayLayerId, name: 'L-PATH', isStandard: true),
    ArchitectLayer(id: vegetationLayerId, name: 'L-VEGE', isStandard: true),
    ArchitectLayer(id: streetLayerId, name: 'L-ROAD', isStandard: true),
  ];
}
