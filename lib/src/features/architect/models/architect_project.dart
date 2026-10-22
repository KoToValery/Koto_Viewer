import 'architect_line_style.dart';
import 'architect_document.dart';
export 'architect_document.dart';
import 'architect_slab_assembly.dart';
import 'architect_roof.dart';
export 'architect_roof.dart';
import 'architect_section.dart';
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
export 'architect_component.dart';

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
  final Offset? zoneScheduleOrigin;
  final bool isRoof;

  const ArchitectStorey({
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
    this.zoneScheduleOrigin,
  }) : _zones = zones;

  String get elevationLabel {
    if (elevation.abs() < 1e-4) return '±0.00';
    final sign = elevation > 0 ? '+' : '';
    return '$sign${elevation.toStringAsFixed(2)}';
  }

  ArchitectStorey copyWith({
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
    Offset? zoneScheduleOrigin,
    bool clearZoneScheduleOrigin = false,
  }) => ArchitectStorey(
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
    zoneScheduleOrigin: clearZoneScheduleOrigin
        ? null
        : (zoneScheduleOrigin ?? this.zoneScheduleOrigin),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
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
    if (zoneScheduleOrigin != null)
      'zoneScheduleOrigin': {
        'x': zoneScheduleOrigin!.dx,
        'y': zoneScheduleOrigin!.dy,
      },
  };

  factory ArchitectStorey.fromJson(
    Map<String, dynamic> json,
  ) => ArchitectStorey(
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

/// The root model for an architectural concept project.
class ArchitectProject {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ArchitectUnit units;
  final int distanceDecimals;
  final ArchitectDimensionScale dimensionScale;
  final ArchitectDocument document;
  final List<ArchitectStorey> storeys;
  final String activeStoreyId;
  final List<StructuralGridAxis> gridAxes;
  final List<ArchitectWallType> wallTypes;
  final List<ArchitectLineStyle> lineStyles;
  final List<ArchitectFenestrationStyle> openingStyles;
  final List<ArchitectSlabAssembly> slabAssemblies;
  final List<ArchitectSection> sections;
  final List<ArchitectElevation> elevations;
  final ArchitectNorthSymbol? northSymbol;
  final Map<String, int> slabCompositionNumbers;

  const ArchitectProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.units = ArchitectUnit.meters,
    this.distanceDecimals = 2,
    this.dimensionScale = ArchitectDimensionScale.scale100,
    this.document = const ArchitectDocument(),
    required this.storeys,
    required this.activeStoreyId,
    this.gridAxes = const [],
    this.wallTypes = const [],
    this.lineStyles = const [],
    this.openingStyles = const [],
    this.slabAssemblies = const [],
    this.sections = const [],
    this.elevations = const [],
    this.northSymbol,
    this.slabCompositionNumbers = const {},
  });

  String formatLength(double meters) =>
      units.format(meters, decimals: distanceDecimals);

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
    ArchitectDimensionScale? dimensionScale,
    ArchitectDocument? document,
    List<ArchitectStorey>? storeys,
    String? activeStoreyId,
    List<StructuralGridAxis>? gridAxes,
    List<ArchitectWallType>? wallTypes,
    List<ArchitectLineStyle>? lineStyles,
    List<ArchitectFenestrationStyle>? openingStyles,
    List<ArchitectSlabAssembly>? slabAssemblies,
    List<ArchitectSection>? sections,
    List<ArchitectElevation>? elevations,
    ArchitectNorthSymbol? northSymbol,
    bool clearNorthSymbol = false,
    Map<String, int>? slabCompositionNumbers,
  }) => ArchitectProject(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    units: units ?? this.units,
    distanceDecimals: distanceDecimals ?? this.distanceDecimals,
    dimensionScale: dimensionScale ?? this.dimensionScale,
    document: document ?? this.document,
    storeys: storeys ?? this.storeys,
    activeStoreyId: activeStoreyId ?? this.activeStoreyId,
    gridAxes: gridAxes ?? this.gridAxes,
    wallTypes: wallTypes ?? this.wallTypes,
    lineStyles: lineStyles ?? this.lineStyles,
    openingStyles: openingStyles ?? this.openingStyles,
    slabAssemblies: slabAssemblies ?? this.slabAssemblies,
    sections: sections ?? this.sections,
    elevations: elevations ?? this.elevations,
    northSymbol: clearNorthSymbol ? null : northSymbol ?? this.northSymbol,
    slabCompositionNumbers:
        slabCompositionNumbers ?? this.slabCompositionNumbers,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'units': units.name,
    'distanceDecimals': distanceDecimals,
    'dimensionScale': dimensionScale.denominator,
    'document': document.toJson(),
    'storeys': storeys.map((s) => s.toJson()).toList(),
    'activeStoreyId': activeStoreyId,
    'gridAxes': gridAxes.map((a) => a.toJson()).toList(),
    'wallTypes': wallTypes.map((w) => w.toJson()).toList(),
    'lineStyles': lineStyles.map((s) => s.toJson()).toList(),
    'openingStyles': openingStyles.map((o) => o.toJson()).toList(),
    'slabAssemblies': slabAssemblies.map((a) => a.toJson()).toList(),
    'sections': sections.map((a) => a.toJson()).toList(),
    'elevations': elevations.map((a) => a.toJson()).toList(),
    if (northSymbol != null) 'northSymbol': northSymbol!.toJson(),
    'slabCompositionNumbers': slabCompositionNumbers,
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
    storeys:
        (json['storeys'] as List<dynamic>?)
            ?.map((s) => ArchitectStorey.fromJson(s as Map<String, dynamic>))
            .toList() ??
        const [],
    activeStoreyId: json['activeStoreyId'] as String? ?? '',
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
    openingStyles:
        (json['openingStyles'] as List<dynamic>?)
            ?.map(
              (o) => ArchitectFenestrationStyle.fromJson(
                o as Map<String, dynamic>,
              ),
            )
            .toList() ??
        const [],
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
      storeys: storeys,
      activeStoreyId: storeys.isNotEmpty ? storeys.first.id : 'default',
      gridAxes: axes,
      wallTypes: wallTypes ?? ArchitectWallType.standardCatalog(),
    );
  }
}
