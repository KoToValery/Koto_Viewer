import 'dart:ui';

/// Shared building-layer vocabulary; element placement and slopes belong to adapters.
enum ArchitectMaterial {
  brick,
  concrete,
  timber,
  panel,
  eps,
  xps,
  stoneWool,
  plaster,
  render,
  plasterboard,
  tile,
  stone,
  steel,
  pir,
}

enum ArchitectLayerRole { core, insulation, finish }

enum ArchitectWallLocation { exterior, interior }

class ArchitectMaterialLayer {
  final String id;
  final ArchitectMaterial material;
  final ArchitectLayerRole role;
  final double thickness;
  const ArchitectMaterialLayer({
    required this.id,
    required this.material,
    required this.role,
    required this.thickness,
  });
  ArchitectMaterialLayer copyWith({
    String? id,
    ArchitectMaterial? material,
    ArchitectLayerRole? role,
    double? thickness,
  }) => ArchitectMaterialLayer(
    id: id ?? this.id,
    material: material ?? this.material,
    role: role ?? this.role,
    thickness: thickness ?? this.thickness,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'material': material.name,
    'role': role.name,
    'thickness': thickness,
  };
  factory ArchitectMaterialLayer.fromJson(Map<String, dynamic> j) =>
      ArchitectMaterialLayer(
        id: j['id'] as String,
        material: ArchitectMaterial.values.byName(j['material'] as String),
        role: ArchitectLayerRole.values.byName(j['role'] as String),
        thickness: (j['thickness'] as num).toDouble(),
      );
  static void validate(List<ArchitectMaterialLayer> layers) {
    final cores = [
      for (var i = 0; i < layers.length; i++)
        if (layers[i].role == ArchitectLayerRole.core) i,
    ];
    if (layers.isEmpty ||
        layers.length > 20 ||
        layers.map((l) => l.id).toSet().length != layers.length ||
        layers.any(
          (l) => l.id.isEmpty || !l.thickness.isFinite || l.thickness <= 0,
        ) ||
        cores.isEmpty ||
        cores.last - cores.first + 1 != cores.length) {
      throw ArgumentError('Invalid layer composition');
    }
    if (layers
        .where((l) => l.role == ArchitectLayerRole.core)
        .any(
          (l) => !{
            ArchitectMaterial.brick,
            ArchitectMaterial.concrete,
            ArchitectMaterial.timber,
            ArchitectMaterial.panel,
            ArchitectMaterial.pir,
          }.contains(l.material),
        )) {
      throw ArgumentError('Invalid core material');
    }
  }
}

extension ArchitectMaterialAppearance on ArchitectMaterial {
  Color get color => switch (this) {
    ArchitectMaterial.brick => const Color(0xFFC98E73),
    ArchitectMaterial.concrete => const Color(0xFF9FAEB5),
    ArchitectMaterial.timber => const Color(0xFFD7A86E),
    ArchitectMaterial.panel => const Color(0xFFC4C9CF),
    ArchitectMaterial.steel => const Color(0xFFAAB2B8),
    ArchitectMaterial.pir => const Color(0xFFF0E8CE),
    ArchitectMaterial.eps => const Color(0xFFF3E8BF),
    ArchitectMaterial.xps => const Color(0xFF80CBC4),
    ArchitectMaterial.stoneWool => const Color(0xFFB8C880),
    ArchitectMaterial.plaster ||
    ArchitectMaterial.render => const Color(0xFFE6E1D8),
    ArchitectMaterial.plasterboard => const Color(0xFFCFD6DD),
    ArchitectMaterial.tile => const Color(0xFFBC9D88),
    ArchitectMaterial.stone => const Color(0xFF8D9295),
  };
  ArchitectLayerRole get defaultRole => switch (this) {
    ArchitectMaterial.brick ||
    ArchitectMaterial.concrete ||
    ArchitectMaterial.timber ||
    ArchitectMaterial.pir ||
    ArchitectMaterial.panel => ArchitectLayerRole.core,
    ArchitectMaterial.eps ||
    ArchitectMaterial.xps ||
    ArchitectMaterial.stoneWool => ArchitectLayerRole.insulation,
    _ => ArchitectLayerRole.finish,
  };
}

/// Instance-local facade region. Absolute base is in project metres.
class ArchitectWallPlinth {
  final bool enabled;
  final double baseElevation, height;
  final ArchitectMaterial finish;
  const ArchitectWallPlinth({
    this.enabled = false,
    this.baseElevation = 0,
    this.height = .5,
    this.finish = ArchitectMaterial.render,
  });
  ArchitectWallPlinth copyWith({
    bool? enabled,
    double? baseElevation,
    double? height,
    ArchitectMaterial? finish,
  }) => ArchitectWallPlinth(
    enabled: enabled ?? this.enabled,
    baseElevation: baseElevation ?? this.baseElevation,
    height: height ?? this.height,
    finish: finish ?? this.finish,
  );
  void validate() {
    if (!baseElevation.isFinite ||
        !height.isFinite ||
        height <= 0 ||
        !{
          ArchitectMaterial.render,
          ArchitectMaterial.tile,
          ArchitectMaterial.stone,
        }.contains(finish)) {
      throw ArgumentError('Invalid plinth');
    }
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'baseElevation': baseElevation,
    'height': height,
    'finish': finish.name,
  };
  factory ArchitectWallPlinth.fromJson(Map<String, dynamic> j) =>
      ArchitectWallPlinth(
        enabled: j['enabled'] as bool? ?? false,
        baseElevation: (j['baseElevation'] as num?)?.toDouble() ?? 0,
        height: (j['height'] as num?)?.toDouble() ?? .5,
        finish: ArchitectMaterial.values.byName(
          j['finish'] as String? ?? 'render',
        ),
      );
}

/// Only explicitly edited fields are propagated to a multi-wall selection.
class ArchitectWallPlinthPatch {
  final bool? enabled;
  final double? baseElevation, height;
  final ArchitectMaterial? finish;
  const ArchitectWallPlinthPatch({
    this.enabled,
    this.baseElevation,
    this.height,
    this.finish,
  });
  bool get isEmpty =>
      enabled == null &&
      baseElevation == null &&
      height == null &&
      finish == null;
  ArchitectWallPlinth apply(ArchitectWallPlinth value) {
    final next = value.copyWith(
      enabled: enabled,
      baseElevation: baseElevation,
      height: height,
      finish: finish,
    );
    next.validate();
    return next;
  }
}
