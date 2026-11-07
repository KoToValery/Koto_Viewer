import 'architect_element_group.dart';
export 'architect_element_group.dart';
import 'architect_layer.dart';
export 'architect_layer.dart';
import 'architect_line_style.dart';
import 'architect_hatch_pattern.dart';
import 'architect_document.dart';
export 'architect_document.dart';
import 'architect_slab_assembly.dart';
import 'architect_roof.dart';
export 'architect_roof.dart';
import 'architect_section.dart';
import 'architect_section_visibility.dart';
import 'architect_elevation.dart';
import '../../bim_editing/properties/bim_distance_unit.dart';
export '../../bim_editing/properties/bim_distance_unit.dart';
import 'dart:ui';
import '../../structural_designer/models/structural_element.dart';
import 'architect_column.dart';
import 'architect_elements.dart';
export 'architect_elements.dart' show ArchitectCutDisplayMode;
import 'architect_grid_preset.dart';
import 'architect_wall.dart';
import 'architect_door.dart';
import 'architect_wall_type.dart';
import 'architect_zone.dart';
import 'architect_fenestration_style.dart';
import 'architect_component.dart';
import 'architect_floor_drain.dart';
import 'architect_decorative_element.dart';
import 'architect_underlay_models.dart';
import 'architect_landscape_models.dart';
export 'architect_component.dart';
export 'architect_decorative_element.dart';
export 'architect_underlay_models.dart';
export 'architect_landscape_models.dart';

typedef ArchitectUnit = BimDistanceUnit;

/// Paper-space dimension text sizes; model geometry is always in metres.
enum ArchitectDimensionScale {
  scale20(20),
  scale50(50),
  scale100(100),
  scale200(200),
  scale500(500);

  final int denominator;
  const ArchitectDimensionScale(this.denominator);

  double get textHeightMm => ArchitectDrawingScale(denominator).defaultTextMm;

  double paperToModel(double millimeters) => millimeters * denominator / 1000;
  double get textHeight => paperToModel(textHeightMm);
  String get ratio => '1:$denominator';
}

/// Represents an architectural storey level with its height, elevation, walls, zones,
/// and comprehensive architectural drafting elements.
class ArchitectStorey {
  final List<ArchitectElementGroup> _groups;
  Set<String> get groupableIds => {
    ...walls.map((e) => e.id),
    ...columns.map((e) => e.id),
    ...beams.map((e) => e.id),
    ...slabs.map((e) => e.id),
    ...roofs.map((e) => e.id),
    ...openings.map((e) => e.id),
    ...stairs.map((e) => e.id),
    ...dimensions.map((e) => e.id),
    ...elevationMarkers.map((e) => e.id),
    ...annotations.map((e) => e.id),
    ...cadPrimitives.map((e) => e.id),
    ...components.map((e) => e.id),
    ...floorDrains.map((e) => e.id),
    ...decorativeElements.map((e) => e.id),
    ...pathways.map((e) => e.id),
    ...vegetation.map((e) => e.id),
    ...siteFences.map((e) => e.id),
    ...streets.map((e) => e.id),
    ...zones.where((e) => !e.isAutoBoundary).map((e) => e.id),
  };
  List<ArchitectElementGroup> get groups => _groups.isEmpty
      ? const []
      : ArchitectElementGroup.normalize(_groups, groupableIds);
  ArchitectElementGroup? groupFor(String id) =>
      groups.where((g) => g.elementIds.contains(id)).firstOrNull;
  Set<String> expandGroups(Set<String> selection) {
    final result = Set<String>.of(selection);
    for (final group in groups) {
      if (group.elementIds.any(selection.contains)) {
        result.addAll(group.elementIds);
      }
    }
    return result;
  }

  final String id;
  final String name;
  final double elevation; // in meters (кота готов под)
  final double height; // finished floor to next finished floor, in meters
  final double
  cutPlaneHeight; // floor plan cut plane height above storey elevation (default 1.20 m)
  final double floorFinishThickness; // default 0.05 m
  final List<ArchitectWall> walls;
  final List<ArchitectZone> _zones;
  List<ArchitectZone> get zones => ArchitectZone.normalizeMemberships(_zones);
  final List<ArchitectColumn> columns;
  final List<ArchitectBeam> beams;
  final List<ArchitectSlab> slabs;
  final List<ArchitectRoofPlane> roofs;
  final List<ArchitectOpening> openings;
  final List<ArchitectStair> stairs;
  final List<ArchitectDimension> dimensions;
  final List<ArchitectElevationMarker> elevationMarkers;
  final List<ArchitectAnnotation> annotations;
  final List<ArchitectCadPrimitive> cadPrimitives;
  final List<ArchitectComponentInstance> components;
  final List<ArchitectFloorDrain> floorDrains;
  final List<ArchitectDecorativeElement> decorativeElements;
  final List<ArchitectPathway> pathways;
  final List<ArchitectVegetationItem> vegetation;
  final List<ArchitectSiteFence> siteFences;
  final List<ArchitectStreet> streets;
  final Offset? zoneScheduleOrigin;
  final bool isRoof;

  const ArchitectStorey({
    List<ArchitectElementGroup> groups = const [],
    required this.id,
    required this.name,
    this.elevation = 0.0,
    this.height = 2.80,
    this.cutPlaneHeight = 1.20,
    this.floorFinishThickness = 0.05,
    this.isRoof = false,
    this.walls = const [],
    List<ArchitectZone> zones = const [],
    this.columns = const [],
    this.beams = const [],
    this.slabs = const [],
    this.roofs = const [],
    this.openings = const [],
    this.stairs = const [],
    this.dimensions = const [],
    this.elevationMarkers = const [],
    this.annotations = const [],
    this.cadPrimitives = const [],
    this.components = const [],
    this.floorDrains = const [],
    this.decorativeElements = const [],
    this.pathways = const [],
    this.vegetation = const [],
    this.siteFences = const [],
    this.streets = const [],
    this.zoneScheduleOrigin,
  }) : _zones = zones,
       _groups = groups;

  String get elevationLabel {
    if (elevation.abs() < 1e-4) return '±0.00';
    final sign = elevation > 0 ? '+' : '';
    return '$sign${elevation.toStringAsFixed(2)}';
  }

  ArchitectStorey copyWith({
    List<ArchitectElementGroup>? groups,
    String? id,
    String? name,
    double? elevation,
    double? height,
    double? cutPlaneHeight,
    double? floorFinishThickness,
    bool? isRoof,
    List<ArchitectWall>? walls,
    List<ArchitectZone>? zones,
    List<ArchitectColumn>? columns,
    List<ArchitectBeam>? beams,
    List<ArchitectSlab>? slabs,
    List<ArchitectRoofPlane>? roofs,
    List<ArchitectOpening>? openings,
    List<ArchitectStair>? stairs,
    List<ArchitectDimension>? dimensions,
    List<ArchitectElevationMarker>? elevationMarkers,
    List<ArchitectAnnotation>? annotations,
    List<ArchitectCadPrimitive>? cadPrimitives,
    List<ArchitectComponentInstance>? components,
    List<ArchitectFloorDrain>? floorDrains,
    List<ArchitectDecorativeElement>? decorativeElements,
    List<ArchitectPathway>? pathways,
    List<ArchitectVegetationItem>? vegetation,
    List<ArchitectSiteFence>? siteFences,
    List<ArchitectStreet>? streets,
    Offset? zoneScheduleOrigin,
    bool clearZoneScheduleOrigin = false,
  }) => ArchitectStorey(
    groups: groups ?? _groups,
    id: id ?? this.id,
    name: name ?? this.name,
    elevation: elevation ?? this.elevation,
    height: height ?? this.height,
    cutPlaneHeight: cutPlaneHeight ?? this.cutPlaneHeight,
    floorFinishThickness: floorFinishThickness ?? this.floorFinishThickness,
    isRoof: isRoof ?? this.isRoof,
    walls: height == null
        ? (walls ?? this.walls)
        : [
            for (final wall in walls ?? this.walls)
              wall.copyWith(height: wall.effectiveHeight(height)),
          ],
    zones: zones ?? this.zones,
    columns: columns ?? this.columns,
    beams: beams ?? this.beams,
    slabs: slabs ?? this.slabs,
    roofs: roofs ?? this.roofs,
    openings: openings ?? this.openings,
    stairs: stairs ?? this.stairs,
    dimensions: dimensions ?? this.dimensions,
    elevationMarkers: elevationMarkers ?? this.elevationMarkers,
    annotations: annotations ?? this.annotations,
    cadPrimitives: cadPrimitives ?? this.cadPrimitives,
    components: components ?? this.components,
    floorDrains: floorDrains ?? this.floorDrains,
    decorativeElements: decorativeElements ?? this.decorativeElements,
    pathways: pathways ?? this.pathways,
    vegetation: vegetation ?? this.vegetation,
    siteFences: siteFences ?? this.siteFences,
    streets: streets ?? this.streets,
    zoneScheduleOrigin: clearZoneScheduleOrigin
        ? null
        : (zoneScheduleOrigin ?? this.zoneScheduleOrigin),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (groups.isNotEmpty) 'groups': groups.map((g) => g.toJson()).toList(),
    'name': name,
    'elevation': elevation,
    'height': height,
    'cutPlaneHeight': cutPlaneHeight,
    'floorFinishThickness': floorFinishThickness,
    if (isRoof) 'isRoof': true,
    'walls': walls
        .map((w) => w.copyWith(height: w.effectiveHeight(height)).toJson())
        .toList(),
    'zones': zones.map((z) => z.toJson()).toList(),
    'columns': columns.map((c) => c.toJson()).toList(),
    'beams': beams.map((b) => b.toJson()).toList(),
    'slabs': slabs.map((s) => s.toJson()).toList(),
    'roofs': roofs.map((r) => r.toJson()).toList(),
    'openings': openings.map((o) => o.toJson()).toList(),
    'stairs': stairs.map((st) => st.toJson()).toList(),
    'dimensions': dimensions.map((d) => d.toJson()).toList(),
    'elevationMarkers': elevationMarkers.map((m) => m.toJson()).toList(),
    'annotations': annotations.map((a) => a.toJson()).toList(),
    'cadPrimitives': cadPrimitives.map((p) => p.toJson()).toList(),
    'components': components.map((c) => c.toJson()).toList(),
    if (floorDrains.isNotEmpty)
      'floorDrains': floorDrains.map((d) => d.toJson()).toList(),
    if (decorativeElements.isNotEmpty)
      'decorativeElements': decorativeElements.map((d) => d.toJson()).toList(),
    if (pathways.isNotEmpty)
      'pathways': pathways.map((p) => p.toJson()).toList(),
    if (vegetation.isNotEmpty)
      'vegetation': vegetation.map((v) => v.toJson()).toList(),
    if (siteFences.isNotEmpty)
      'siteFences': siteFences.map((f) => f.toJson()).toList(),
    if (streets.isNotEmpty)
      'streets': streets.map((s) => s.toJson()).toList(),
    if (zoneScheduleOrigin != null)
      'zoneScheduleOrigin': {
        'x': zoneScheduleOrigin!.dx,
        'y': zoneScheduleOrigin!.dy,
      },
  };

  factory ArchitectStorey.fromJson(
    Map<String, dynamic> json,
  ) => ArchitectStorey(
    groups: [
      for (final g in json['groups'] as List? ?? const [])
        if (g is Map)
          ArchitectElementGroup.fromJson(Map<String, dynamic>.from(g)),
    ],
    id: json['id'] as String,
    name: json['name'] as String,
    elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
    height: (json['height'] as num?)?.toDouble() ?? 2.80,
    cutPlaneHeight: (json['cutPlaneHeight'] as num?)?.toDouble() ?? 1.20,
    floorFinishThickness:
        (json['floorFinishThickness'] as num?)?.toDouble() ?? 0.05,
    isRoof: json['isRoof'] as bool? ?? false,
    walls:
        (json['walls'] as List<dynamic>?)
            ?.map(
              (w) => ArchitectWall.fromJson({
                ...w as Map<String, dynamic>,
                if (!w.containsKey('followStoreyHeight'))
                  'followStoreyHeight':
                      ((w['height'] as num?)?.toDouble() ?? 2.80) ==
                      ((json['height'] as num?)?.toDouble() ?? 2.80),
              }),
            )
            .toList() ??
        const [],
    zones:
        (json['zones'] as List<dynamic>?)
            ?.map((z) => ArchitectZone.fromJson(z as Map<String, dynamic>))
            .toList() ??
        const [],
    columns:
        (json['columns'] as List<dynamic>?)
            ?.map((c) => ArchitectColumn.fromJson(c as Map<String, dynamic>))
            .toList() ??
        const [],
    beams:
        (json['beams'] as List<dynamic>?)
            ?.map((b) => ArchitectBeam.fromJson(b as Map<String, dynamic>))
            .toList() ??
        const [],
    slabs:
        (json['slabs'] as List<dynamic>?)
            ?.map((s) => ArchitectSlab.fromJson(s as Map<String, dynamic>))
            .toList() ??
        const [],
    roofs:
        (json['roofs'] as List<dynamic>?)
            ?.map((r) => ArchitectRoofPlane.fromJson(r as Map<String, dynamic>))
            .toList() ??
        const [],
    openings:
        (json['openings'] as List<dynamic>?)
            ?.map((o) => ArchitectOpening.fromJson(o as Map<String, dynamic>))
            .toList() ??
        const [],
    stairs:
        (json['stairs'] as List<dynamic>?)
            ?.map((st) => ArchitectStair.fromJson(st as Map<String, dynamic>))
            .toList() ??
        const [],
    dimensions:
        (json['dimensions'] as List<dynamic>?)
            ?.map((d) => ArchitectDimension.fromJson(d as Map<String, dynamic>))
            .toList() ??
        const [],
    elevationMarkers:
        (json['elevationMarkers'] as List<dynamic>?)
            ?.map(
              (m) =>
                  ArchitectElevationMarker.fromJson(m as Map<String, dynamic>),
            )
            .toList() ??
        const [],
    annotations:
        (json['annotations'] as List<dynamic>?)
            ?.map(
              (a) => ArchitectAnnotation.fromJson(a as Map<String, dynamic>),
            )
            .toList() ??
        const [],
    floorDrains: [
      for (final d in json['floorDrains'] as List? ?? const [])
        if (d is Map)
          ArchitectFloorDrain.fromJson(Map<String, dynamic>.from(d)),
    ],
    decorativeElements: [
      for (final d in json['decorativeElements'] as List? ?? const [])
        if (d is Map)
          ArchitectDecorativeElement.fromJson(Map<String, dynamic>.from(d)),
    ],
    pathways: [
      for (final p in json['pathways'] as List? ?? const [])
        if (p is Map) ArchitectPathway.fromJson(Map<String, dynamic>.from(p)),
    ],
    vegetation: [
      for (final v in json['vegetation'] as List? ?? const [])
        if (v is Map)
          ArchitectVegetationItem.fromJson(Map<String, dynamic>.from(v)),
    ],
    siteFences: [
      for (final f in json['siteFences'] as List? ?? const [])
        if (f is Map) ArchitectSiteFence.fromJson(Map<String, dynamic>.from(f)),
    ],
    streets: [
      for (final s in json['streets'] as List? ?? const [])
        if (s is Map) ArchitectStreet.fromJson(Map<String, dynamic>.from(s)),
    ],
    components:
        (json['components'] as List<dynamic>?)
            ?.map(
              (c) => ArchitectComponentInstance.fromJson(
                c as Map<String, dynamic>,
              ),
            )
            .toList() ??
        const [],
    cadPrimitives:
        (json['cadPrimitives'] as List<dynamic>?)
            ?.map(
              (p) => ArchitectCadPrimitive.fromJson(p as Map<String, dynamic>),
            )
            .toList() ??
        const [],
    zoneScheduleOrigin: json['zoneScheduleOrigin'] != null
        ? Offset(
            ((json['zoneScheduleOrigin'] as Map<String, dynamic>)['x'] as num)
                .toDouble(),
            ((json['zoneScheduleOrigin'] as Map<String, dynamic>)['y'] as num)
                .toDouble(),
          )
        : null,
  );
}

/// The overall structural / construction scheme of an architectural project.
enum ArchitectStructuralScheme {
  flatSlab,
  beamAndSlab,
  sandwichPanels,
  roundLogs,
  studFrame;

  bool get isBeamAndSlab => this == ArchitectStructuralScheme.beamAndSlab;
  bool get isFlatSlab => this == ArchitectStructuralScheme.flatSlab;
  bool get isSandwichPanels => this == ArchitectStructuralScheme.sandwichPanels;
  bool get isRoundLogs => this == ArchitectStructuralScheme.roundLogs;
  bool get isStudFrame => this == ArchitectStructuralScheme.studFrame;
  bool get isMasonry => isFlatSlab || isBeamAndSlab;
}

/// The root model for an architectural concept project.
class ArchitectProject {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ArchitectUnit units;
  final int distanceDecimals;
  final ArchitectUnit levelUnits;
  final int levelDecimals;
  final ArchitectDimensionScale dimensionScale;
  final ArchitectDocument document;
  final ArchitectStructuralScheme structuralScheme;
  final double perimeterBeamDepth;
  final List<ArchitectStorey> storeys;
  final String activeStoreyId;
  final List<StructuralGridAxis> gridAxes;
  final List<ArchitectWallType> wallTypes;
  final List<ArchitectLineStyle> lineStyles;
  final List<ArchitectHatchPattern> hatchPatterns;
  final List<ArchitectFenestrationStyle> openingStyles;
  final List<ArchitectSlabAssembly> slabAssemblies;
  final List<ArchitectSection> sections;
  final ArchitectSectionVisibility sectionVisibility;
  final List<ArchitectElevation> elevations;
  final ArchitectNorthSymbol? northSymbol;
  final Map<String, int> slabCompositionNumbers;
  final bool showDecorativeOnPlan;
  final List<ArchitectLayer> layers;
  final Map<String, String> elementLayers;
  final Map<String, ArchitectCadUnderlayConfig> cadUnderlays;
  final List<ArchitectRasterUnderlay> rasterUnderlays;
  final ArchitectGeodeticSurvey? geodeticSurvey;
  final ArchitectTerrainSurface existingTerrain;
  final ArchitectTerrainSurface proposedTerrain;

  const ArchitectProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.units = ArchitectUnit.meters,
    this.distanceDecimals = 2,
    this.levelUnits = ArchitectUnit.meters,
    this.levelDecimals = 2,
    this.dimensionScale = ArchitectDimensionScale.scale100,
    this.document = const ArchitectDocument(),
    this.structuralScheme = ArchitectStructuralScheme.flatSlab,
    this.perimeterBeamDepth = 0.45,
    required this.storeys,
    required this.activeStoreyId,
    this.gridAxes = const [],
    this.wallTypes = const [],
    this.lineStyles = const [],
    this.hatchPatterns = const [],
    this.openingStyles = const [],
    this.slabAssemblies = const [],
    this.sections = const [],
    this.sectionVisibility = const ArchitectSectionVisibility(),
    this.elevations = const [],
    this.northSymbol,
    this.slabCompositionNumbers = const {},
    this.showDecorativeOnPlan = false,
    this.layers = const [],
    this.elementLayers = const {},
    this.cadUnderlays = const {},
    this.rasterUnderlays = const [],
    this.geodeticSurvey,
    this.existingTerrain = const ArchitectTerrainSurface(
      state: ArchitectTerrainState.existing,
    ),
    this.proposedTerrain = const ArchitectTerrainSurface(
      state: ArchitectTerrainState.proposed,
    ),
  });

  ArchitectCadUnderlayConfig? cadUnderlayForStorey(String storeyId) =>
      cadUnderlays[storeyId];

  List<ArchitectRasterUnderlay> rasterUnderlaysForStorey(String storeyId) =>
      rasterUnderlays.where((r) => r.storeyId == storeyId).toList();

  List<ArchitectLayer> get effectiveLayers {
    if (layers.isEmpty) return ArchitectLayer.defaultLayers();
    final existingIds = layers.map((l) => l.id).toSet();
    return [
      ...layers,
      for (final std in ArchitectLayer.defaultLayers())
        if (!existingIds.contains(std.id)) std,
    ];
  }

  String elementLayerId(String elementId, String defaultLayerId) {
    final custom = elementLayers[elementId];
    if (custom != null && effectiveLayers.any((l) => l.id == custom)) {
      return custom;
    }
    return defaultLayerId;
  }

  bool isElementVisible(String elementId, String defaultLayerId) {
    final layerId = elementLayerId(elementId, defaultLayerId);
    final layer = effectiveLayers.where((l) => l.id == layerId).firstOrNull;
    return layer?.visible ?? true;
  }

  bool isLayerVisible(String layerId) {
    final layer = effectiveLayers.where((l) => l.id == layerId).firstOrNull;
    return layer?.visible ?? true;
  }

  String formatLength(double meters) =>
      units.format(meters, decimals: distanceDecimals);

  String formatLevel(double metres) =>
      formatArchitectLevel(metres, units: levelUnits, decimals: levelDecimals);

  ArchitectStorey get activeStorey => storeys.firstWhere(
    (s) => s.id == activeStoreyId,
    orElse: () => storeys.isNotEmpty ? storeys.first : _emptyStorey,
  );

  /// All doors across all storeys in this project.
  Iterable<ArchitectDoor> get allDoors =>
      storeys.expand((s) => s.walls).expand((w) => w.doors);

  /// The dedicated roof lines plan storey, if present.
  ArchitectStorey? get roofStorey => storeys.where((s) => s.isRoof).firstOrNull;

  /// The highest non-roof storey with walls (or highest non-roof storey).
  ArchitectStorey? get highestWallStorey {
    final withWalls = storeys
        .where((s) => !s.isRoof && s.walls.isNotEmpty)
        .toList();
    if (withWalls.isNotEmpty) {
      withWalls.sort((a, b) => a.elevation.compareTo(b.elevation));
      return withWalls.last;
    }
    final normal = storeys.where((s) => !s.isRoof).toList();
    if (normal.isNotEmpty) {
      normal.sort((a, b) => a.elevation.compareTo(b.elevation));
      return normal.last;
    }
    return storeys.firstOrNull;
  }

  /// Storeys ordered for the plan menu / tabs:
  /// The roof lines plan always sits at the very top (index 0),
  /// followed by storeys sorted from highest elevation down to lowest.
  List<ArchitectStorey> get orderedPlanStoreys {
    final normal = storeys.where((s) => !s.isRoof).toList()
      ..sort((a, b) => b.elevation.compareTo(a.elevation));
    final roof = roofStorey;
    if (roof == null) return normal;
    return [roof, ...normal];
  }

  /// Ensures a dedicated roof plan storey exists on top of all storeys.
  ArchitectProject ensureRoofStorey() {
    if (roofStorey != null) return syncRoofElevation();
    final top = highestWallStorey ?? (storeys.isNotEmpty ? storeys.last : null);
    final elev = top != null ? (top.elevation + top.height) : 2.80;
    final roof = ArchitectStorey(
      id: 'storey_roof',
      name: 'Покривни линии',
      elevation: elev,
      height: 2.80,
      isRoof: true,
    );
    return copyWith(storeys: [...storeys, roof]);
  }

  /// Synchronizes the elevation of the roof storey so it always floats above the highest normal storey.
  ArchitectProject syncRoofElevation() {
    final roof = roofStorey;
    if (roof == null) return this;
    final normal = storeys.where((s) => !s.isRoof).toList();
    if (normal.isEmpty) return this;
    normal.sort((a, b) => a.elevation.compareTo(b.elevation));
    final top = normal.last;
    final target = top.elevation + top.height;
    if ((roof.elevation - target).abs() < 1e-4) return this;
    return copyWith(
      storeys: [
        for (final s in storeys) s.isRoof ? s.copyWith(elevation: target) : s,
      ],
    );
  }

  /// Appends a new storey above the highest normal storey.
  ArchitectProject addStoreyAbove({
    String? name,
    double height = 2.80,
  }) {
    final normal = storeys.where((s) => !s.isRoof).toList()
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    final top = normal.isNotEmpty ? normal.last : null;
    final elev = top != null ? (top.elevation + top.height) : 0.0;
    final index = normal.length + 1;
    final elevLabel = elev.abs() < 1e-4
        ? '±0.00'
        : (elev > 0 ? '+${elev.toStringAsFixed(2)}' : elev.toStringAsFixed(2));
    final storeyName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : 'Етаж $index · $elevLabel';
    final newStorey = ArchitectStorey(
      id: 'storey_${DateTime.now().millisecondsSinceEpoch}_${normal.length}',
      name: storeyName,
      elevation: elev,
      height: height,
    );
    final nextNormal = [...normal, newStorey];
    final roof = roofStorey;
    final updatedStoreys = roof != null ? [...nextNormal, roof] : nextNormal;
    return copyWith(storeys: updatedStoreys).syncRoofElevation();
  }

  /// Batch adds N consecutive typical storeys above the current top normal storey.
  ArchitectProject batchAddTypicalStoreys({
    required int count,
    double typicalHeight = 2.80,
    String namePrefix = 'Етаж',
  }) {
    if (count <= 0) return this;
    var current = this;
    for (var i = 0; i < count; i++) {
      final normal = current.storeys.where((s) => !s.isRoof).toList()
        ..sort((a, b) => a.elevation.compareTo(b.elevation));
      final top = normal.isNotEmpty ? normal.last : null;
      final elev = top != null ? (top.elevation + top.height) : 0.0;
      final num = normal.length + 1;
      final elevLabel = elev.abs() < 1e-4
          ? '±0.00'
          : (elev > 0 ? '+${elev.toStringAsFixed(2)}' : elev.toStringAsFixed(2));
      final name = '$namePrefix $num · $elevLabel';
      current = current.addStoreyAbove(name: name, height: typicalHeight);
    }
    return current;
  }

  /// Recalculates consecutive floor elevations based on heights, from lowest to highest.
  ArchitectProject recalculateStoreyElevations() {
    final normal = storeys.where((s) => !s.isRoof).toList()
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    if (normal.isEmpty) return this;

    final updated = <ArchitectStorey>[];
    var currentElev = normal.first.elevation;
    for (var i = 0; i < normal.length; i++) {
      final s = normal[i];
      if (i == 0) {
        updated.add(s);
        currentElev += s.height;
      } else {
        updated.add(s.copyWith(elevation: currentElev));
        currentElev += s.height;
      }
    }
    final roof = roofStorey;
    final all = roof != null ? [...updated, roof] : updated;
    return copyWith(storeys: all).syncRoofElevation();
  }

  /// Updates a storey, optionally recalculating elevations of all storeys above it.
  ArchitectProject updateStorey(ArchitectStorey updated, {bool recalculateAbove = true}) {
    final updatedList =
        storeys.map((s) => s.id == updated.id ? updated : s).toList();
    final p = copyWith(storeys: updatedList);
    return recalculateAbove
        ? p.recalculateStoreyElevations()
        : p.syncRoofElevation();
  }

  /// Deletes a storey. Disallows deleting the last remaining normal storey.
  ArchitectProject deleteStorey(String storeyId) {
    final normal = storeys.where((s) => !s.isRoof).toList();
    if (normal.length <= 1 && normal.any((s) => s.id == storeyId)) {
      return this;
    }
    final remaining = storeys.where((s) => s.id != storeyId).toList();
    var nextActiveId = activeStoreyId;
    if (activeStoreyId == storeyId) {
      final remainingNormal = remaining.where((s) => !s.isRoof).toList();
      nextActiveId = remainingNormal.isNotEmpty
          ? remainingNormal.first.id
          : (remaining.firstOrNull?.id ?? 'default');
    }
    return copyWith(storeys: remaining, activeStoreyId: nextActiveId)
        .recalculateStoreyElevations();
  }

  static const _emptyStorey = ArchitectStorey(
    id: 'default',
    name: '±0.00',
    elevation: 0.0,
  );

  ArchitectProject updateActiveStorey(ArchitectStorey updated) {
    final updatedStoreys = storeys
        .map((s) => s.id == updated.id ? updated : s)
        .toList();
    return copyWith(storeys: updatedStoreys, updatedAt: DateTime.now());
  }

  ArchitectProject copyWithGridAxes(List<StructuralGridAxis> newAxes) {
    return copyWith(gridAxes: newAxes, updatedAt: DateTime.now());
  }

  ArchitectProject copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    ArchitectUnit? units,
    int? distanceDecimals,
    ArchitectUnit? levelUnits,
    int? levelDecimals,
    ArchitectDimensionScale? dimensionScale,
    ArchitectDocument? document,
    ArchitectStructuralScheme? structuralScheme,
    double? perimeterBeamDepth,
    List<ArchitectStorey>? storeys,
    String? activeStoreyId,
    List<StructuralGridAxis>? gridAxes,
    List<ArchitectWallType>? wallTypes,
    List<ArchitectLineStyle>? lineStyles,
    List<ArchitectHatchPattern>? hatchPatterns,
    List<ArchitectFenestrationStyle>? openingStyles,
    List<ArchitectSlabAssembly>? slabAssemblies,
    List<ArchitectSection>? sections,
    ArchitectSectionVisibility? sectionVisibility,
    List<ArchitectElevation>? elevations,
    ArchitectNorthSymbol? northSymbol,
    bool clearNorthSymbol = false,
    Map<String, int>? slabCompositionNumbers,
    bool? showDecorativeOnPlan,
    List<ArchitectLayer>? layers,
    Map<String, String>? elementLayers,
    Map<String, ArchitectCadUnderlayConfig>? cadUnderlays,
    List<ArchitectRasterUnderlay>? rasterUnderlays,
    ArchitectGeodeticSurvey? geodeticSurvey,
    bool clearGeodeticSurvey = false,
    ArchitectTerrainSurface? existingTerrain,
    ArchitectTerrainSurface? proposedTerrain,
  }) => ArchitectProject(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    units: units ?? this.units,
    distanceDecimals: distanceDecimals ?? this.distanceDecimals,
    levelUnits: levelUnits ?? this.levelUnits,
    levelDecimals: levelDecimals ?? this.levelDecimals,
    dimensionScale: dimensionScale ?? this.dimensionScale,
    document: document ?? this.document,
    structuralScheme: structuralScheme ?? this.structuralScheme,
    perimeterBeamDepth: perimeterBeamDepth ?? this.perimeterBeamDepth,
    storeys: storeys ?? this.storeys,
    activeStoreyId: activeStoreyId ?? this.activeStoreyId,
    gridAxes: gridAxes ?? this.gridAxes,
    wallTypes: wallTypes ?? this.wallTypes,
    lineStyles: lineStyles ?? this.lineStyles,
    hatchPatterns: hatchPatterns ?? this.hatchPatterns,
    openingStyles: openingStyles ?? this.openingStyles,
    slabAssemblies: slabAssemblies ?? this.slabAssemblies,
    sections: sections ?? this.sections,
    sectionVisibility: sectionVisibility ?? this.sectionVisibility,
    elevations: elevations ?? this.elevations,
    northSymbol: clearNorthSymbol ? null : northSymbol ?? this.northSymbol,
    slabCompositionNumbers:
        slabCompositionNumbers ?? this.slabCompositionNumbers,
    showDecorativeOnPlan: showDecorativeOnPlan ?? this.showDecorativeOnPlan,
    layers: layers ?? this.layers,
    elementLayers: elementLayers ?? this.elementLayers,
    cadUnderlays: cadUnderlays ?? this.cadUnderlays,
    rasterUnderlays: rasterUnderlays ?? this.rasterUnderlays,
    geodeticSurvey: clearGeodeticSurvey
        ? null
        : (geodeticSurvey ?? this.geodeticSurvey),
    existingTerrain: existingTerrain ?? this.existingTerrain,
    proposedTerrain: proposedTerrain ?? this.proposedTerrain,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'units': units.name,
    'distanceDecimals': distanceDecimals,
    'levelUnits': levelUnits.name,
    'levelDecimals': levelDecimals,
    'dimensionScale': dimensionScale.denominator,
    'document': document.toJson(),
    'structuralScheme': structuralScheme.name,
    'perimeterBeamDepth': perimeterBeamDepth,
    'storeys': storeys.map((s) => s.toJson()).toList(),
    'activeStoreyId': activeStoreyId,
    'gridAxes': gridAxes.map((a) => a.toJson()).toList(),
    'wallTypes': wallTypes.map((w) => w.toJson()).toList(),
    'lineStyles': lineStyles.map((s) => s.toJson()).toList(),
    'hatchPatterns': hatchPatterns.map((s) => s.toJson()).toList(),
    'openingStyles': openingStyles.map((o) => o.toJson()).toList(),
    'slabAssemblies': slabAssemblies.map((a) => a.toJson()).toList(),
    'sections': sections.map((a) => a.toJson()).toList(),
    'sectionVisibility': sectionVisibility.toJson(),
    'elevations': elevations.map((a) => a.toJson()).toList(),
    if (northSymbol != null) 'northSymbol': northSymbol!.toJson(),
    'slabCompositionNumbers': slabCompositionNumbers,
    if (showDecorativeOnPlan) 'showDecorativeOnPlan': true,
    if (layers.isNotEmpty) 'layers': layers.map((l) => l.toJson()).toList(),
    if (elementLayers.isNotEmpty) 'elementLayers': elementLayers,
    if (cadUnderlays.isNotEmpty)
      'cadUnderlays': cadUnderlays.map((k, v) => MapEntry(k, v.toJson())),
    if (rasterUnderlays.isNotEmpty)
      'rasterUnderlays': rasterUnderlays.map((r) => r.toJson()).toList(),
    if (geodeticSurvey != null) 'geodeticSurvey': geodeticSurvey!.toJson(),
    if (!existingTerrain.isEmpty) 'existingTerrain': existingTerrain.toJson(),
    if (!proposedTerrain.isEmpty) 'proposedTerrain': proposedTerrain.toJson(),
  };

  factory ArchitectProject.fromJson(
    Map<String, dynamic> json,
  ) => ArchitectProject(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    document: ArchitectDocument.fromProjectJson(json),
    levelUnits:
        ArchitectUnit.values
            .where((u) => u.name == json['levelUnits'])
            .firstOrNull ??
        ArchitectUnit.meters,
    levelDecimals: ((json['levelDecimals'] as num?)?.toInt() ?? 2).clamp(0, 4),
    units: ArchitectUnit.values.firstWhere(
      (u) => u.name == json['units'],
      orElse: () => ArchitectUnit.meters,
    ),
    distanceDecimals:
        ((json['distanceDecimals'] as num?)?.toInt() ??
                (json['units'] == 'centimeters' ||
                        json['units'] == 'millimeters'
                    ? 0
                    : 2))
            .clamp(0, 2),
    dimensionScale: ArchitectDimensionScale.values.firstWhere(
      (scale) => scale.denominator == json['dimensionScale'],
      orElse: () => ArchitectDimensionScale.scale100,
    ),
    structuralScheme: ArchitectStructuralScheme.values.firstWhere(
      (s) => s.name == json['structuralScheme'],
      orElse: () => ArchitectStructuralScheme.flatSlab,
    ),
    perimeterBeamDepth:
        ((json['perimeterBeamDepth'] as num?)?.toDouble() ?? 0.45).clamp(0.20, 1.50),
    storeys:
        (json['storeys'] as List<dynamic>?)
            ?.map((s) => ArchitectStorey.fromJson(s as Map<String, dynamic>))
            .toList() ??
        const [],
    activeStoreyId: json['activeStoreyId'] as String? ?? '',
    sectionVisibility: ArchitectSectionVisibility.fromJson(
      json['sectionVisibility'],
    ),
    slabAssemblies: (json['slabAssemblies'] as List? ?? [])
        .map(
          (a) => ArchitectSlabAssembly.fromJson(
            Map<String, dynamic>.from(a as Map),
          ),
        )
        .toList(),
    sections: (json['sections'] as List? ?? [])
        .map(
          (a) => ArchitectSection.fromJson(Map<String, dynamic>.from(a as Map)),
        )
        .toList(),
    elevations: (json['elevations'] as List? ?? [])
        .map(
          (a) =>
              ArchitectElevation.fromJson(Map<String, dynamic>.from(a as Map)),
        )
        .toList(),
    northSymbol: json['northSymbol'] == null
        ? null
        : ArchitectNorthSymbol.fromJson(
            Map<String, dynamic>.from(json['northSymbol'] as Map),
          ),
    slabCompositionNumbers: (json['slabCompositionNumbers'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    ),
    showDecorativeOnPlan: json['showDecorativeOnPlan'] as bool? ?? false,
    gridAxes:
        (json['gridAxes'] as List<dynamic>?)
            ?.map((a) => StructuralGridAxis.fromJson(a as Map<String, dynamic>))
            .toList() ??
        const [],
    wallTypes:
        (json['wallTypes'] as List<dynamic>?)
            ?.map((w) => ArchitectWallType.fromJson(w as Map<String, dynamic>))
            .toList() ??
        ArchitectWallType.standardCatalog(),
    lineStyles: (json['lineStyles'] as List? ?? [])
        .map(
          (s) =>
              ArchitectLineStyle.fromJson(Map<String, dynamic>.from(s as Map)),
        )
        .where((s) => !s.isPreset)
        .toList(),
    hatchPatterns: (json['hatchPatterns'] as List? ?? [])
        .map(
          (s) => ArchitectHatchPattern.fromJson(
            Map<String, dynamic>.from(s as Map),
          ),
        )
        .where((s) => !s.isPreset)
        .toList(),
    openingStyles:
        (json['openingStyles'] as List<dynamic>?)
            ?.map(
              (o) => ArchitectFenestrationStyle.fromJson(
                o as Map<String, dynamic>,
              ),
            )
            .toList() ??
        const [],
    layers: (json['layers'] as List? ?? [])
        .map((l) => ArchitectLayer.fromJson(Map<String, dynamic>.from(l as Map)))
        .toList(),
    elementLayers: (json['elementLayers'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, v as String),
    ),
    cadUnderlays: {
      for (final entry in (json['cadUnderlays'] as Map? ?? {}).entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: ArchitectCadUnderlayConfig.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
    },
    rasterUnderlays: [
      for (final r in json['rasterUnderlays'] as List? ?? const [])
        if (r is Map)
          ArchitectRasterUnderlay.fromJson(Map<String, dynamic>.from(r)),
    ],
    geodeticSurvey: json['geodeticSurvey'] is Map
        ? ArchitectGeodeticSurvey.fromJson(
            Map<String, dynamic>.from(json['geodeticSurvey'] as Map),
          )
        : null,
    existingTerrain: json['existingTerrain'] is Map
        ? ArchitectTerrainSurface.fromJson(
            Map<String, dynamic>.from(json['existingTerrain'] as Map),
          )
        : const ArchitectTerrainSurface(state: ArchitectTerrainState.existing),
    proposedTerrain: json['proposedTerrain'] is Map
        ? ArchitectTerrainSurface.fromJson(
            Map<String, dynamic>.from(json['proposedTerrain'] as Map),
          )
        : const ArchitectTerrainSurface(state: ArchitectTerrainState.proposed),
  );

  /// Factory creating an architectural project configured from the starter wizard.
  factory ArchitectProject.starterWithCatalog({
    required String name,
    int storeyCount = 2,
    double groundHeight = 3.00,
    double typicalHeight = 2.80,
    ArchitectGridPreset? gridPreset,
    int? customAxesX,
    int? customAxesY,
    double? customSpacingX,
    double? customSpacingY,
    List<double>? spacingsX,
    List<double>? spacingsY,
    List<ArchitectWallType>? wallTypes,
    ArchitectStructuralScheme structuralScheme = ArchitectStructuralScheme.flatSlab,
    double perimeterBeamDepth = 0.45,
    ArchitectUnit units = ArchitectUnit.meters,
  }) {
    final now = DateTime.now();
    final storeys = <ArchitectStorey>[];
    double currentElevation = 0.0;

    for (int i = 0; i < storeyCount; i++) {
      final h = i == 0 ? groundHeight : typicalHeight;
      final name = currentElevation.abs() < 1e-4
          ? '±0.00'
          : '+${currentElevation.toStringAsFixed(2)}';
      storeys.add(
        ArchitectStorey(
          id: 'storey_$i',
          name: name,
          elevation: currentElevation,
          height: h,
        ),
      );
      currentElevation += h;
    }
    storeys.add(
      ArchitectStorey(
        id: 'storey_roof',
        name: 'Покривни линии',
        elevation: currentElevation,
        height: 2.80,
        isRoof: true,
      ),
    );

    final preset = gridPreset ?? ArchitectGridPreset.standardPresets().first;
    final axes = preset.generateAxes(
      customAxesX: customAxesX,
      customAxesY: customAxesY,
      customSpacingX: customSpacingX,
      customSpacingY: customSpacingY,
      spacingsX: spacingsX,
      spacingsY: spacingsY,
    );

    final finalWallTypes =
        wallTypes ??
        ArchitectWallType.standardCatalog(
          parapetHeight: ArchitectWallType.resolveParapetHeight(
            storeyElevation: currentElevation,
            storeyIndex: storeyCount,
          ),
        );

    return ArchitectProject(
      id: 'proj_${now.millisecondsSinceEpoch}',
      name: name,
      createdAt: now,
      updatedAt: now,
      units: units,
      structuralScheme: structuralScheme,
      perimeterBeamDepth: perimeterBeamDepth,
      storeys: storeys,
      activeStoreyId: storeys.isNotEmpty ? storeys.first.id : 'default',
      gridAxes: axes,
      wallTypes: finalWallTypes,
    );
  }

  /// Factory creating a quick starter template project.
  factory ArchitectProject.starter({
    required String name,
    int storeyCount = 2,
    double typicalHeight = 2.80,
    double groundHeight = 3.00,
    int axesX = 4,
    int axesY = 3,
    double spacingX = 4.0,
    double spacingY = 5.0,
    ArchitectStructuralScheme structuralScheme = ArchitectStructuralScheme.flatSlab,
    double perimeterBeamDepth = 0.45,
    List<ArchitectWallType>? wallTypes,
  }) {
    final now = DateTime.now();
    final storeys = <ArchitectStorey>[];
    double currentElevation = 0.0;

    for (int i = 0; i < storeyCount; i++) {
      final h = i == 0 ? groundHeight : typicalHeight;
      final name = currentElevation.abs() < 1e-4
          ? '±0.00'
          : '+${currentElevation.toStringAsFixed(2)}';
      storeys.add(
        ArchitectStorey(
          id: 'storey_$i',
          name: name,
          elevation: currentElevation,
          height: h,
        ),
      );
      currentElevation += h;
    }
    storeys.add(
      ArchitectStorey(
        id: 'storey_roof',
        name: 'Покривни линии',
        elevation: currentElevation,
        height: 2.80,
        isRoof: true,
      ),
    );

    final axes = <StructuralGridAxis>[];
    if (axesX > 0 && axesY > 0) {
      final totalWidth = (axesX - 1) * spacingX;
      final totalHeight = (axesY - 1) * spacingY;
      const margin = 1.5;

      for (int i = 0; i < axesX; i++) {
        final x = i * spacingX;
        axes.add(
          StructuralGridAxis(
            id: 'axis_x_$i',
            name: '${i + 1}',
            start: Offset(x, -margin),
            end: Offset(x, totalHeight + margin),
            bubbleAtStart: true,
            bubbleAtEnd: true,
          ),
        );
      }

      final letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
      for (int j = 0; j < axesY; j++) {
        final y = j * spacingY;
        final label = j < letters.length ? letters[j] : 'Y$j';
        axes.add(
          StructuralGridAxis(
            id: 'axis_y_$j',
            name: label,
            start: Offset(-margin, y),
            end: Offset(totalWidth + margin, y),
            bubbleAtStart: true,
            bubbleAtEnd: true,
          ),
        );
      }
    }

    return ArchitectProject(
      id: 'proj_${now.millisecondsSinceEpoch}',
      name: name,
      createdAt: now,
      updatedAt: now,
      structuralScheme: structuralScheme,
      perimeterBeamDepth: perimeterBeamDepth,
      storeys: storeys,
      activeStoreyId: storeys.isNotEmpty ? storeys.first.id : 'default',
      gridAxes: axes,
      wallTypes: wallTypes ?? ArchitectWallType.standardCatalog(),
    );
  }
}
