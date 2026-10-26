import 'architect_material_layer.dart';
export 'architect_material_layer.dart';
import 'architect_wall_system.dart';
export 'architect_wall_system.dart';
// === SECTION: ARCHITECTURAL WALL TYPE MODELS ===
import 'dart:ui';
import '../../../core/l10n/generated/app_localizations.dart';

enum WallCoreMaterial { brick, concrete, timber, panel }

enum WallInsulationMaterial { xps, eps, stoneWool }

/// Semantic usage and classification of an architectural wall.
enum WallUsage {
  /// Exterior façade wall (e.g. 25 cm brick + thermal insulation EPS).
  exterior,

  /// Interior partition wall (e.g. 12 cm single brick).
  interior,

  /// Reinforced concrete shear wall or load-bearing wall.
  bearing,

  /// Balcony or terrace parapet / balustrade edge.
  parapet,
}

/// Finishing style for balcony parapets.
enum ParapetFinish {
  /// Solid parapet topped with protective coping cap.
  cap,

  /// Parapet topped with steel handrail pipe on posts in the top 15 cm.
  handrailPipes,
}

/// Parametric definition of an architectural wall type.
class ArchitectWallType {
  final ArchitectWallSystem system;
  final String id;
  final List<ArchitectMaterialLayer> layers;
  final ArchitectWallLocation? location;
  final bool loadBearing;
  final String name;
  final String? labelId;

  /// Explicit project types survive even when unnamed and not yet placed.
  final bool isCatalogType;
  final WallUsage usage;
  final double _totalThickness; // in meters (e.g. 0.37 m)
  final double _brickThickness; // in meters (e.g. 0.25 m or 0.12 m)
  final double _insulationThickness; // in meters (e.g. 0.12 m EPS or 0.0)
  final double? customHeight; // used for parapets (e.g. 1.05 m or 1.20 m)
  final ParapetFinish? parapetFinish;
  final int colorValue;

  const ArchitectWallType({
    this.system = const ArchitectWallSystem(),
    required this.id,
    required this.name,
    this.labelId,
    this.isCatalogType = true,
    required this.usage,
    required double totalThickness,
    double brickThickness = 0.25,
    double insulationThickness = 0.0,
    this.customHeight,
    this.parapetFinish,
    this.colorValue = 0xFF78909C,
    this.layers = const [],
    this.location,
    this.loadBearing = false,
  }) : _totalThickness = totalThickness,
       _brickThickness = brickThickness,
       _insulationThickness = insulationThickness;

  double get totalThickness =>
      system.additionalDepth +
      (layers.isEmpty
      ? _totalThickness
      : layers.fold<double>(0, (v, l) => v + l.thickness));
  double get brickThickness => layers.isEmpty
      ? _brickThickness
      : layers
            .where((l) => l.role == ArchitectLayerRole.core)
            .fold(0, (v, l) => v + l.thickness);
  double get insulationThickness => layers.isEmpty
      ? _insulationThickness
      : layers
            .where((l) => l.role == ArchitectLayerRole.insulation)
            .fold(0, (v, l) => v + l.thickness);
  ArchitectWallLocation get resolvedLocation =>
      location ??
      (usage == WallUsage.exterior || usage == WallUsage.parapet
          ? ArchitectWallLocation.exterior
          : ArchitectWallLocation.interior);
  List<ArchitectMaterialLayer> get resolvedLayers => layers.isNotEmpty
      ? layers
      : [
          if (insulationThickness > 0)
            ArchitectMaterialLayer(
              id: 'insulation',
              material: ArchitectMaterial.eps,
              role: ArchitectLayerRole.insulation,
              thickness: insulationThickness,
            ),
          ArchitectMaterialLayer(
            id: 'core',
            material: usage == WallUsage.bearing
                ? ArchitectMaterial.concrete
                : ArchitectMaterial.brick,
            role: ArchitectLayerRole.core,
            thickness: totalThickness - insulationThickness,
          ),
        ];

  bool get isFactoryPreset =>
      labelId == null &&
      const {
        'ext_25_12_eps',
        'int_12_partition',
        'ext_25_brick',
        'bearing_25_concrete',
        'parapet_12',
      }.contains(id);
  bool get isLoadBearing =>
      layers.isEmpty && usage == WallUsage.bearing ? true : loadBearing;
  bool get isParapet => usage == WallUsage.parapet;
  bool get hasInsulation => insulationThickness > 0.001;

  Color get color => layers.isEmpty
      ? Color(colorValue)
      : layers
            .firstWhere((l) => l.role == ArchitectLayerRole.core)
            .material
            .color;

  /// Resolves the compliant parapet height in meters according to Bulgarian building codes
  /// (Наредба № 7 / Наредба № РД-02-20-2):
  /// - 1.05 m for buildings up to 5 storeys or elevation < 20.0 m.
  /// - 1.20 m for buildings above 5 storeys or fall elevation >= 20.0 m.
  static double resolveParapetHeight({
    required double storeyElevation,
    required int storeyIndex,
  }) {
    if (storeyIndex >= 5 || storeyElevation >= 19.99) {
      return 1.20;
    }
    return 1.05;
  }

  /// Default starter catalog of standard architectural wall types.
  static List<ArchitectWallType> standardCatalog({
    bool includeSpecial = false,
    double parapetHeight = 1.05,
    ParapetFinish parapetFinish = ParapetFinish.cap,
    AppLocalizations? l10n,
  }) {
    return [
      ArchitectWallType(
        id: 'ext_25_12_eps',
        name: '',
        usage: WallUsage.exterior,
        totalThickness: 0.37,
        brickThickness: 0.25,
        insulationThickness: 0.12,
        colorValue: 0xFFEF5350,
      ),
      ArchitectWallType(
        id: 'int_12_partition',
        name: '',
        usage: WallUsage.interior,
        totalThickness: 0.12,
        brickThickness: 0.12,
        insulationThickness: 0.0,
        colorValue: 0xFFFFA726,
      ),
      ArchitectWallType(
        id: 'ext_25_brick',
        name: '',
        usage: WallUsage.exterior,
        totalThickness: 0.25,
        brickThickness: 0.25,
        insulationThickness: 0.0,
        colorValue: 0xFFFF7043,
      ),
      ArchitectWallType(
        id: 'bearing_25_concrete',
        name: '',
        usage: WallUsage.bearing,
        totalThickness: 0.25,
        brickThickness: 0.25,
        insulationThickness: 0.0,
        colorValue: 0xFF78909C,
      ),
      ArchitectWallType(
        id: 'parapet_12',
        name: '',
        usage: WallUsage.parapet,
        totalThickness: 0.12,
        brickThickness: 0.12,
        insulationThickness: 0.0,
        customHeight: parapetHeight,
        parapetFinish: parapetFinish,
        colorValue: 0xFF26A69A,
      ),
      if (includeSpecial)
        const ArchitectWallType(
          id: 'round_logs_240',
          name: '',
          usage: WallUsage.exterior,
          totalThickness: .24,
          location: ArchitectWallLocation.exterior,
          loadBearing: true,
          system: ArchitectWallSystem(kind: ArchitectWallSystemKind.roundLogs),
          layers: [
            ArchitectMaterialLayer(
              id: 'log',
              material: ArchitectMaterial.timber,
              role: ArchitectLayerRole.core,
              thickness: .24,
            ),
          ],
        ),
      if (includeSpecial)
        const ArchitectWallType(
          id: 'stud_partition_100',
          name: '',
          usage: WallUsage.interior,
          totalThickness: .1,
          location: ArchitectWallLocation.interior,
          system: ArchitectWallSystem(kind: ArchitectWallSystemKind.studFrame),
          layers: [
            ArchitectMaterialLayer(
              id: 'board_a',
              material: ArchitectMaterial.plasterboard,
              role: ArchitectLayerRole.finish,
              thickness: .0125,
            ),
            ArchitectMaterialLayer(
              id: 'frame',
              material: ArchitectMaterial.panel,
              role: ArchitectLayerRole.core,
              thickness: .075,
            ),
            ArchitectMaterialLayer(
              id: 'board_b',
              material: ArchitectMaterial.plasterboard,
              role: ArchitectLayerRole.finish,
              thickness: .0125,
            ),
          ],
        ),
      if (includeSpecial)
        const ArchitectWallType(
          id: 'sandwich_100_100',
          name: '',
          usage: WallUsage.exterior,
          totalThickness: .1,
          location: ArchitectWallLocation.exterior,
          system: ArchitectWallSystem(
            kind: ArchitectWallSystemKind.sandwichPanels,
            metalThickness: .003,
          ),
          layers: [
            ArchitectMaterialLayer(
              id: 'skin_a',
              material: ArchitectMaterial.steel,
              role: ArchitectLayerRole.finish,
              thickness: .0005,
            ),
            ArchitectMaterialLayer(
              id: 'panel',
              material: ArchitectMaterial.pir,
              role: ArchitectLayerRole.core,
              thickness: .099,
            ),
            ArchitectMaterialLayer(
              id: 'skin_b',
              material: ArchitectMaterial.steel,
              role: ArchitectLayerRole.finish,
              thickness: .0005,
            ),
          ],
        ),
    ];
  }

  ArchitectWallType copyWith({
    ArchitectWallSystem? system,
    String? id,
    String? name,
    String? labelId,
    bool? isCatalogType,
    WallUsage? usage,
    double? totalThickness,
    double? brickThickness,
    double? insulationThickness,
    double? customHeight,
    ParapetFinish? parapetFinish,
    int? colorValue,
    List<ArchitectMaterialLayer>? layers,
    ArchitectWallLocation? location,
    bool? loadBearing,
  }) => ArchitectWallType(
    system: system ?? this.system,
    id: id ?? this.id,
    layers: layers ?? this.layers,
    location: location ?? this.location,
    loadBearing: loadBearing ?? this.loadBearing,
    name: name ?? this.name,
    labelId: labelId ?? this.labelId,
    isCatalogType: isCatalogType ?? this.isCatalogType,
    usage: usage ?? this.usage,
    totalThickness: totalThickness ?? this.totalThickness,
    brickThickness: brickThickness ?? this.brickThickness,
    insulationThickness: insulationThickness ?? this.insulationThickness,
    customHeight: customHeight ?? this.customHeight,
    parapetFinish: parapetFinish ?? this.parapetFinish,
    colorValue: colorValue ?? this.colorValue,
  );

  Map<String, dynamic> toJson() => {
    if (system.isSpecial) 'system': system.toJson(),
    'id': id,
    'name': name,
    if (labelId != null) 'labelId': labelId,
    'isCatalogType': isCatalogType,
    'usage': usage.name,
    'layers': layers.map((l) => l.toJson()).toList(),
    'location': resolvedLocation.name,
    'loadBearing': loadBearing || usage == WallUsage.bearing,
    'totalThickness': totalThickness,
    'brickThickness': brickThickness,
    'insulationThickness': insulationThickness,
    'customHeight': customHeight,
    'parapetFinish': parapetFinish?.name,
    'colorValue': colorValue,
  };

  factory ArchitectWallType.fromJson(Map<String, dynamic> json) =>
      ArchitectWallType(
        system: ArchitectWallSystem.fromJson(
          json['system'] == null
              ? null
              : Map<String, dynamic>.from(json['system'] as Map),
        ),
        id: json['id'] as String,
        layers: (json['layers'] as List? ?? [])
            .map(
              (l) => ArchitectMaterialLayer.fromJson(
                Map<String, dynamic>.from(l as Map),
              ),
            )
            .toList(),
        location: ArchitectWallLocation.values
            .where((l) => l.name == json['location'])
            .firstOrNull,
        loadBearing: json['loadBearing'] as bool? ?? json['usage'] == 'bearing',
        name: json['name'] as String,
        labelId: json['labelId'] as String?,
        isCatalogType: json['isCatalogType'] as bool? ?? true,
        usage: WallUsage.values.firstWhere(
          (u) => u.name == json['usage'],
          orElse: () => WallUsage.exterior,
        ),
        totalThickness: (json['totalThickness'] as num).toDouble(),
        brickThickness: (json['brickThickness'] as num?)?.toDouble() ?? 0.25,
        insulationThickness:
            (json['insulationThickness'] as num?)?.toDouble() ?? 0.0,
        customHeight: (json['customHeight'] as num?)?.toDouble(),
        parapetFinish: json['parapetFinish'] != null
            ? ParapetFinish.values.firstWhere(
                (p) => p.name == json['parapetFinish'],
                orElse: () => ParapetFinish.cap,
              )
            : null,
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF78909C,
      );
}
