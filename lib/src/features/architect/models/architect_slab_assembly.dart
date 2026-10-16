import 'dart:convert';

enum SlabUsage {
  foundation,
  ground,
  basement,
  intermediate,
  coldAttic,
  insulatedCeiling,
  warmRoof,
  invertedRoof,
  terrace,
}

enum SlabMaterial {
  concrete,
  tile,
  tileAdhesive,
  parquet,
  underlay,
  screed,
  peFoil,
  xps,
  floorInsulation,
  acousticWool,
  mineralWool,
  roofInsulation,
  waterproofing,
  vapourBarrier,
  breathableMembrane,
  geotextile,
  gravel,
  ballast,
  compactedFill,
  blindingConcrete,
  plaster,
  protectiveRender,
  plasterboard,
  adhesive,
  custom,
}

enum SlabLayerRole {
  finish,
  adhesive,
  screed,
  separation,
  insulation,
  acoustic,
  waterproofing,
  vapourControl,
  slope,
  ceiling,
  base,
  fill,
  protection,
}

/// All dimensions are metres. Lists are ordered from the highest surface down.
class ArchitectSlabLayer {
  final String id;
  final SlabMaterial material;
  final SlabLayerRole role;
  final double thickness;
  final double slopePercent;
  final String customName;
  final bool finishPackage;

  const ArchitectSlabLayer({
    required this.id,
    required this.material,
    required this.role,
    required this.thickness,
    this.slopePercent = 0,
    this.customName = '',
    this.finishPackage = false,
  });

  ArchitectSlabLayer copyWith({
    String? id,
    SlabMaterial? material,
    SlabLayerRole? role,
    double? thickness,
    double? slopePercent,
    String? customName,
    bool? finishPackage,
  }) => ArchitectSlabLayer(
    id: id ?? this.id,
    material: material ?? this.material,
    role: role ?? this.role,
    thickness: thickness ?? this.thickness,
    slopePercent: slopePercent ?? this.slopePercent,
    customName: customName ?? this.customName,
    finishPackage: finishPackage ?? this.finishPackage,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'material': material.name,
    'role': role.name,
    'thickness': thickness,
    'slopePercent': slopePercent,
    'customName': customName,
    'finishPackage': finishPackage,
  };
  factory ArchitectSlabLayer.fromJson(Map<String, dynamic> j) =>
      ArchitectSlabLayer(
        id: j['id'] as String,
        material: SlabMaterial.values.byName(j['material'] as String),
        role: SlabLayerRole.values.byName(j['role'] as String),
        thickness: (j['thickness'] as num).toDouble(),
        slopePercent: (j['slopePercent'] as num?)?.toDouble() ?? 0,
        customName: j['customName'] as String? ?? '',
        finishPackage: j['finishPackage'] as bool? ?? false,
      );

  List<Object> get signature => [
    material.name,
    role.name,
    (thickness * 1e9).round(),
    (slopePercent * 1e6).round(),
    customName,
  ];
}

class ArchitectSlabAssembly {
  final String id;
  final String customName;
  final SlabUsage usage;
  final List<ArchitectSlabLayer> above;
  final List<ArchitectSlabLayer> below;
  const ArchitectSlabAssembly({
    required this.id,
    required this.usage,
    this.customName = '',
    this.above = const [],
    this.below = const [],
  });

  bool get hasSlope => above.any((l) => l.slopePercent > 0);
  double get upperThickness => above.fold(0, (a, l) => a + l.thickness);
  double get lowerThickness => below.fold(0, (a, l) => a + l.thickness);
  ArchitectSlabAssembly copyWith({
    String? id,
    String? customName,
    SlabUsage? usage,
    List<ArchitectSlabLayer>? above,
    List<ArchitectSlabLayer>? below,
  }) => ArchitectSlabAssembly(
    id: id ?? this.id,
    customName: customName ?? this.customName,
    usage: usage ?? this.usage,
    above: above ?? this.above,
    below: below ?? this.below,
  );

  void validate() {
    final all = [...above, ...below];
    if (id.isEmpty ||
        all.map((l) => l.id).toSet().length != all.length ||
        all.any(
          (l) =>
              l.id.isEmpty ||
              !l.thickness.isFinite ||
              l.thickness <= 0 ||
              !l.slopePercent.isFinite ||
              l.slopePercent < 0 ||
              l.slopePercent > 100 ||
              (l.material == SlabMaterial.custom &&
                  l.customName.trim().isEmpty),
        ) ||
        below.any((l) => l.slopePercent != 0) ||
        above.where((l) => l.slopePercent > 0).length > 1) {
      throw ArgumentError('Invalid slab assembly');
    }
  }

  String signature(double concreteThickness) => jsonEncode([
    above.map((l) => l.signature).toList(),
    ['concrete', (concreteThickness * 1e9).round()],
    below.map((l) => l.signature).toList(),
  ]);
  Map<String, dynamic> toJson() => {
    'id': id,
    'customName': customName,
    'usage': usage.name,
    'above': above.map((l) => l.toJson()).toList(),
    'below': below.map((l) => l.toJson()).toList(),
  };
  factory ArchitectSlabAssembly.fromJson(
    Map<String, dynamic> j,
  ) => ArchitectSlabAssembly(
    id: j['id'] as String,
    customName: j['customName'] as String? ?? '',
    usage: SlabUsage.values.byName(j['usage'] as String),
    above: (j['above'] as List? ?? [])
        .map(
          (l) =>
              ArchitectSlabLayer.fromJson(Map<String, dynamic>.from(l as Map)),
        )
        .toList(),
    below: (j['below'] as List? ?? [])
        .map(
          (l) =>
              ArchitectSlabLayer.fromJson(Map<String, dynamic>.from(l as Map)),
        )
        .toList(),
  );
}

/// Catalogs contain identifiers and dimensions only; UI resolves ARB messages.
class ArchitectSlabCatalog {
  static List<ArchitectSlabLayer> finish({
    bool parquet = false,
    bool wet = false,
  }) => [
    if (parquet) ...[
      const ArchitectSlabLayer(
        id: 'finish',
        material: SlabMaterial.parquet,
        role: SlabLayerRole.finish,
        finishPackage: true,
        thickness: .015,
      ),
      const ArchitectSlabLayer(
        id: 'finish-bed',
        material: SlabMaterial.underlay,
        role: SlabLayerRole.finish,
        finishPackage: true,
        thickness: .003,
      ),
    ] else ...[
      const ArchitectSlabLayer(
        id: 'finish',
        material: SlabMaterial.tile,
        role: SlabLayerRole.finish,
        finishPackage: true,
        thickness: .01,
      ),
      const ArchitectSlabLayer(
        id: 'finish-bed',
        material: SlabMaterial.tileAdhesive,
        role: SlabLayerRole.adhesive,
        finishPackage: true,
        thickness: .005,
      ),
      if (wet)
        const ArchitectSlabLayer(
          id: 'finish-waterproof',
          material: SlabMaterial.waterproofing,
          role: SlabLayerRole.waterproofing,
          finishPackage: true,
          thickness: .002,
        ),
    ],
  ];

  static List<ArchitectSlabAssembly> get presets => [
    for (final usage in SlabUsage.values) preset(usage),
  ];
  static ArchitectSlabAssembly preset(SlabUsage usage) {
    ArchitectSlabLayer l(
      String id,
      SlabMaterial m,
      SlabLayerRole r,
      double d, [
      double slope = 0,
    ]) => ArchitectSlabLayer(
      id: id,
      material: m,
      role: r,
      thickness: d,
      slopePercent: slope,
    );
    final screed = l('screed', SlabMaterial.screed, SlabLayerRole.screed, .05);
    final foil = l(
      'foil',
      SlabMaterial.peFoil,
      SlabLayerRole.separation,
      .0002,
    );
    final thermal = l(
      'thermal',
      SlabMaterial.floorInsulation,
      SlabLayerRole.insulation,
      .10,
    );
    final plaster = l(
      'plaster',
      SlabMaterial.plaster,
      SlabLayerRole.ceiling,
      .015,
    );
    final water = l(
      'waterproof',
      SlabMaterial.waterproofing,
      SlabLayerRole.waterproofing,
      .008,
    );
    final vapour = l(
      'vapour',
      SlabMaterial.vapourBarrier,
      SlabLayerRole.vapourControl,
      .004,
    );
    final slope = l('slope', SlabMaterial.screed, SlabLayerRole.slope, .03, 2);
    final ballast = l('ballast', SlabMaterial.ballast, SlabLayerRole.base, .20);
    final fill = l('fill', SlabMaterial.compactedFill, SlabLayerRole.fill, .20);
    final roof = l(
      'roof-thermal',
      SlabMaterial.roofInsulation,
      SlabLayerRole.insulation,
      .15,
    );
    final xps = l('xps', SlabMaterial.xps, SlabLayerRole.insulation, .15);
    final geo = l(
      'geotextile',
      SlabMaterial.geotextile,
      SlabLayerRole.protection,
      .002,
    );
    final wool = l(
      'wool',
      SlabMaterial.mineralWool,
      SlabLayerRole.insulation,
      .20,
    );
    final (above, below) = switch (usage) {
      SlabUsage.foundation => (
        [...finish(), screed, foil, thermal],
        [
          water,
          l('blinding', SlabMaterial.blindingConcrete, SlabLayerRole.base, .05),
          ballast,
          fill,
        ],
      ),
      SlabUsage.ground => (
        [...finish(), screed, foil, thermal, water],
        [foil.copyWith(id: 'base-foil'), ballast, fill],
      ),
      SlabUsage.basement => (
        [...finish(), screed],
        [
          l('adhesive', SlabMaterial.adhesive, SlabLayerRole.adhesive, .005),
          xps.copyWith(thickness: .05),
          l(
            'render',
            SlabMaterial.protectiveRender,
            SlabLayerRole.protection,
            .005,
          ),
        ],
      ),
      SlabUsage.intermediate => (
        [
          ...finish(),
          screed,
          foil,
          l('acoustic', SlabMaterial.acousticWool, SlabLayerRole.acoustic, .02),
        ],
        [plaster],
      ),
      SlabUsage.coldAttic => (
        [
          l(
            'breathable',
            SlabMaterial.breathableMembrane,
            SlabLayerRole.protection,
            .0005,
          ),
          wool,
          vapour,
        ],
        [plaster],
      ),
      SlabUsage.insulatedCeiling => (
        [...finish(), screed],
        [
          wool,
          vapour,
          l('lining', SlabMaterial.plasterboard, SlabLayerRole.ceiling, .0125),
        ],
      ),
      SlabUsage.warmRoof => ([water, roof, vapour, slope], [plaster]),
      SlabUsage.invertedRoof => (
        [
          l('gravel', SlabMaterial.gravel, SlabLayerRole.protection, .05),
          geo,
          xps,
          water,
          slope,
        ],
        [plaster],
      ),
      SlabUsage.terrace => (
        [...finish(wet: true), screed, foil, roof, vapour, slope],
        [plaster],
      ),
    };
    return ArchitectSlabAssembly(
      id: 'slab-${usage.name}',
      usage: usage,
      above: above,
      below: below,
    );
  }
}
