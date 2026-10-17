// === SECTION: TABLE OF CONTENTS ===
// 1. Enums (ArchitectRoofPreset, ArchitectRoofLayerRole, ArchitectRoofMaterial, ArchitectRoofEavesCut, AutoRoofType)
// 2. ArchitectRoofLayer (Individual roof layer specification)
// 3. ArchitectRoofTimberSpec (Carpentry: battens, counter-battens, rafters, purlins, fascia)
// 4. ArchitectRoofAssembly (Complete multi-layer + timber roof build-up & presets)
// 5. ArchitectRoofPlane (3D sloped roof plane polygon, eaves reference, elevation math)

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

// === SECTION: ENUMS ===

enum ArchitectRoofPreset {
  pitchedTiles,
  warmPitched,
  standingSeam,
  flatWarm,
  custom;

  String label(AppLocalizations l10n) => switch (this) {
    ArchitectRoofPreset.pitchedTiles => l10n.architectRoofPresetPitchedTiles,
    ArchitectRoofPreset.warmPitched => l10n.architectRoofPresetWarmPitched,
    ArchitectRoofPreset.standingSeam => l10n.architectRoofPresetStandingSeam,
    ArchitectRoofPreset.flatWarm => l10n.architectRoofPresetFlatWarm,
    ArchitectRoofPreset.custom => l10n.architectRoofPresetCustom,
  };
}

enum ArchitectRoofLayerRole {
  covering,
  battens,
  counterBattens,
  underlayment,
  boarding,
  rafters,
  insulation,
  vapourBarrier,
  structure,
  interior;

  String label(AppLocalizations l10n) => switch (this) {
    ArchitectRoofLayerRole.covering => l10n.architectRoofRoleCovering,
    ArchitectRoofLayerRole.battens => l10n.architectRoofRoleBattens,
    ArchitectRoofLayerRole.counterBattens => l10n.architectRoofRoleCounterBattens,
    ArchitectRoofLayerRole.underlayment => l10n.architectRoofRoleUnderlayment,
    ArchitectRoofLayerRole.boarding => l10n.architectRoofRoleBoarding,
    ArchitectRoofLayerRole.rafters => l10n.architectRoofRoleRafters,
    ArchitectRoofLayerRole.insulation => l10n.architectRoofRoleInsulation,
    ArchitectRoofLayerRole.vapourBarrier => l10n.architectRoofRoleVapourBarrier,
    ArchitectRoofLayerRole.structure => l10n.architectRoofRoleStructure,
    ArchitectRoofLayerRole.interior => l10n.architectRoofRoleInterior,
  };
}

enum ArchitectRoofMaterial {
  clayTiles,
  concreteTiles,
  metalSeam,
  bitumenShingles,
  timberBoarding,
  osb,
  breathableMembrane,
  vapourBarrier,
  mineralWool,
  xps,
  waterproofing,
  slopeScreed,
  rcSlab,
  plasterboard;

  String label(AppLocalizations l10n) => switch (this) {
    ArchitectRoofMaterial.clayTiles => l10n.architectRoofMatClayTiles,
    ArchitectRoofMaterial.concreteTiles => l10n.architectRoofMatConcreteTiles,
    ArchitectRoofMaterial.metalSeam => l10n.architectRoofMatMetalSeam,
    ArchitectRoofMaterial.bitumenShingles => l10n.architectRoofMatBitumenShingles,
    ArchitectRoofMaterial.timberBoarding => l10n.architectRoofMatTimberBoarding,
    ArchitectRoofMaterial.osb => l10n.architectRoofMatOsb,
    ArchitectRoofMaterial.breathableMembrane => l10n.architectRoofMatBreathableMembrane,
    ArchitectRoofMaterial.vapourBarrier => l10n.architectRoofMatVapourBarrier,
    ArchitectRoofMaterial.mineralWool => l10n.architectRoofMatMineralWool,
    ArchitectRoofMaterial.xps => l10n.architectRoofMatXps,
    ArchitectRoofMaterial.waterproofing => l10n.architectRoofMatWaterproofing,
    ArchitectRoofMaterial.slopeScreed => l10n.architectRoofMatSlopeScreed,
    ArchitectRoofMaterial.rcSlab => l10n.architectRoofMatRcSlab,
    ArchitectRoofMaterial.plasterboard => l10n.architectRoofMatPlasterboard,
  };
}

enum ArchitectRoofEavesCut {
  plumb,
  square,
  horizontalBox;

  String label(AppLocalizations l10n) => switch (this) {
    ArchitectRoofEavesCut.plumb => l10n.architectRoofEavesCutPlumb,
    ArchitectRoofEavesCut.square => l10n.architectRoofEavesCutSquare,
    ArchitectRoofEavesCut.horizontalBox => l10n.architectRoofEavesCutBox,
  };
}

enum AutoRoofType {
  gable,
  hip,
  shed,
  flat;

  String label(AppLocalizations l10n) => switch (this) {
    AutoRoofType.gable => l10n.architectRoofAutoGable,
    AutoRoofType.hip => l10n.architectRoofAutoHip,
    AutoRoofType.shed => l10n.architectRoofAutoShed,
    AutoRoofType.flat => l10n.architectRoofAutoFlat,
  };
}

// === SECTION: ROOF LAYER ===

/// Ordered from top exterior covering down to interior ceiling lining.
/// All dimensions are in metres.
class ArchitectRoofLayer {
  final String id;
  final ArchitectRoofLayerRole role;
  final ArchitectRoofMaterial material;
  final double thickness;
  final bool isBetweenRafters;

  const ArchitectRoofLayer({
    required this.id,
    required this.role,
    required this.material,
    required this.thickness,
    this.isBetweenRafters = false,
  });

  ArchitectRoofLayer copyWith({
    String? id,
    ArchitectRoofLayerRole? role,
    ArchitectRoofMaterial? material,
    double? thickness,
    bool? isBetweenRafters,
  }) => ArchitectRoofLayer(
    id: id ?? this.id,
    role: role ?? this.role,
    material: material ?? this.material,
    thickness: thickness ?? this.thickness,
    isBetweenRafters: isBetweenRafters ?? this.isBetweenRafters,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'material': material.name,
    'thickness': thickness,
    'isBetweenRafters': isBetweenRafters,
  };

  factory ArchitectRoofLayer.fromJson(Map<String, dynamic> json) =>
      ArchitectRoofLayer(
        id: json['id'] as String? ?? 'layer',
        role: ArchitectRoofLayerRole.values.byName(
          json['role'] as String? ?? ArchitectRoofLayerRole.covering.name,
        ),
        material: ArchitectRoofMaterial.values.byName(
          json['material'] as String? ?? ArchitectRoofMaterial.clayTiles.name,
        ),
        thickness: (json['thickness'] as num?)?.toDouble() ?? 0.04,
        isBetweenRafters: json['isBetweenRafters'] as bool? ?? false,
      );
}

// === SECTION: TIMBER CARPENTRY SPECIFICATION ===

/// Parametric specification for structural timber elements rendered in 3D and sections:
/// battens (летви), counter-battens (контралетви), rafters (ребра),
/// wall plate / Mauerlat (мауерлат), ridge purlin (билова столица), and fascia board (челна дъска).
class ArchitectRoofTimberSpec {
  final bool hasBattens;
  final double battenWidth; // along slope (m), e.g. 0.05
  final double battenHeight; // perpendicular to slope (m), e.g. 0.04
  final double battenSpacing; // centre-to-centre along slope (m), e.g. 0.33

  final bool hasCounterBattens;
  final double counterBattenWidth; // across slope (m), e.g. 0.05
  final double counterBattenHeight; // perpendicular to slope (m), e.g. 0.05

  final bool hasRafters;
  final double rafterWidth; // across slope (m), e.g. 0.08
  final double rafterHeight; // perpendicular to slope (m), e.g. 0.16
  final double rafterSpacing; // centre-to-centre across slope (m), e.g. 0.60

  final bool hasWallPlate;
  final double wallPlateWidth; // horizontal width (m), e.g. 0.14
  final double wallPlateHeight; // vertical height (m), e.g. 0.14

  final bool hasRidgePurlin;
  final double ridgePurlinWidth; // horizontal width (m), e.g. 0.16
  final double ridgePurlinHeight; // vertical height (m), e.g. 0.20

  final bool hasFasciaBoard;
  final double fasciaThickness; // thickness at eaves (m), e.g. 0.025

  const ArchitectRoofTimberSpec({
    this.hasBattens = true,
    this.battenWidth = 0.05,
    this.battenHeight = 0.04,
    this.battenSpacing = 0.33,
    this.hasCounterBattens = true,
    this.counterBattenWidth = 0.05,
    this.counterBattenHeight = 0.05,
    this.hasRafters = true,
    this.rafterWidth = 0.08,
    this.rafterHeight = 0.16,
    this.rafterSpacing = 0.60,
    this.hasWallPlate = true,
    this.wallPlateWidth = 0.14,
    this.wallPlateHeight = 0.14,
    this.hasRidgePurlin = true,
    this.ridgePurlinWidth = 0.16,
    this.ridgePurlinHeight = 0.20,
    this.hasFasciaBoard = true,
    this.fasciaThickness = 0.025,
  });

  static const none = ArchitectRoofTimberSpec(
    hasBattens: false,
    hasCounterBattens: false,
    hasRafters: false,
    hasWallPlate: false,
    hasRidgePurlin: false,
    hasFasciaBoard: false,
  );

  ArchitectRoofTimberSpec copyWith({
    bool? hasBattens,
    double? battenWidth,
    double? battenHeight,
    double? battenSpacing,
    bool? hasCounterBattens,
    double? counterBattenWidth,
    double? counterBattenHeight,
    bool? hasRafters,
    double? rafterWidth,
    double? rafterHeight,
    double? rafterSpacing,
    bool? hasWallPlate,
    double? wallPlateWidth,
    double? wallPlateHeight,
    bool? hasRidgePurlin,
    double? ridgePurlinWidth,
    double? ridgePurlinHeight,
    bool? hasFasciaBoard,
    double? fasciaThickness,
  }) => ArchitectRoofTimberSpec(
    hasBattens: hasBattens ?? this.hasBattens,
    battenWidth: battenWidth ?? this.battenWidth,
    battenHeight: battenHeight ?? this.battenHeight,
    battenSpacing: battenSpacing ?? this.battenSpacing,
    hasCounterBattens: hasCounterBattens ?? this.hasCounterBattens,
    counterBattenWidth: counterBattenWidth ?? this.counterBattenWidth,
    counterBattenHeight: counterBattenHeight ?? this.counterBattenHeight,
    hasRafters: hasRafters ?? this.hasRafters,
    rafterWidth: rafterWidth ?? this.rafterWidth,
    rafterHeight: rafterHeight ?? this.rafterHeight,
    rafterSpacing: rafterSpacing ?? this.rafterSpacing,
    hasWallPlate: hasWallPlate ?? this.hasWallPlate,
    wallPlateWidth: wallPlateWidth ?? this.wallPlateWidth,
    wallPlateHeight: wallPlateHeight ?? this.wallPlateHeight,
    hasRidgePurlin: hasRidgePurlin ?? this.hasRidgePurlin,
    ridgePurlinWidth: ridgePurlinWidth ?? this.ridgePurlinWidth,
    ridgePurlinHeight: ridgePurlinHeight ?? this.ridgePurlinHeight,
    hasFasciaBoard: hasFasciaBoard ?? this.hasFasciaBoard,
    fasciaThickness: fasciaThickness ?? this.fasciaThickness,
  );

  Map<String, dynamic> toJson() => {
    'hasBattens': hasBattens,
    'battenWidth': battenWidth,
    'battenHeight': battenHeight,
    'battenSpacing': battenSpacing,
    'hasCounterBattens': hasCounterBattens,
    'counterBattenWidth': counterBattenWidth,
    'counterBattenHeight': counterBattenHeight,
    'hasRafters': hasRafters,
    'rafterWidth': rafterWidth,
    'rafterHeight': rafterHeight,
    'rafterSpacing': rafterSpacing,
    'hasWallPlate': hasWallPlate,
    'wallPlateWidth': wallPlateWidth,
    'wallPlateHeight': wallPlateHeight,
    'hasRidgePurlin': hasRidgePurlin,
    'ridgePurlinWidth': ridgePurlinWidth,
    'ridgePurlinHeight': ridgePurlinHeight,
    'hasFasciaBoard': hasFasciaBoard,
    'fasciaThickness': fasciaThickness,
  };

  factory ArchitectRoofTimberSpec.fromJson(Map<String, dynamic> json) =>
      ArchitectRoofTimberSpec(
        hasBattens: json['hasBattens'] as bool? ?? true,
        battenWidth: (json['battenWidth'] as num?)?.toDouble() ?? 0.05,
        battenHeight: (json['battenHeight'] as num?)?.toDouble() ?? 0.04,
        battenSpacing: (json['battenSpacing'] as num?)?.toDouble() ?? 0.33,
        hasCounterBattens: json['hasCounterBattens'] as bool? ?? true,
        counterBattenWidth:
            (json['counterBattenWidth'] as num?)?.toDouble() ?? 0.05,
        counterBattenHeight:
            (json['counterBattenHeight'] as num?)?.toDouble() ?? 0.05,
        hasRafters: json['hasRafters'] as bool? ?? true,
        rafterWidth: (json['rafterWidth'] as num?)?.toDouble() ?? 0.08,
        rafterHeight: (json['rafterHeight'] as num?)?.toDouble() ?? 0.16,
        rafterSpacing: (json['rafterSpacing'] as num?)?.toDouble() ?? 0.60,
        hasWallPlate: json['hasWallPlate'] as bool? ?? true,
        wallPlateWidth: (json['wallPlateWidth'] as num?)?.toDouble() ?? 0.14,
        wallPlateHeight: (json['wallPlateHeight'] as num?)?.toDouble() ?? 0.14,
        hasRidgePurlin: json['hasRidgePurlin'] as bool? ?? true,
        ridgePurlinWidth:
            (json['ridgePurlinWidth'] as num?)?.toDouble() ?? 0.16,
        ridgePurlinHeight:
            (json['ridgePurlinHeight'] as num?)?.toDouble() ?? 0.20,
        hasFasciaBoard: json['hasFasciaBoard'] as bool? ?? true,
        fasciaThickness: (json['fasciaThickness'] as num?)?.toDouble() ?? 0.025,
      );
}

// === SECTION: ROOF ASSEMBLY & PRESETS ===

class ArchitectRoofAssembly {
  final ArchitectRoofPreset preset;
  final List<ArchitectRoofLayer> layers;
  final ArchitectRoofTimberSpec timber;

  const ArchitectRoofAssembly({
    required this.preset,
    required this.layers,
    required this.timber,
  });

  factory ArchitectRoofAssembly.fromPreset(ArchitectRoofPreset preset) {
    switch (preset) {
      case ArchitectRoofPreset.pitchedTiles:
      case ArchitectRoofPreset.custom:
        return const ArchitectRoofAssembly(
          preset: ArchitectRoofPreset.pitchedTiles,
          timber: ArchitectRoofTimberSpec(
            hasBattens: true,
            battenWidth: 0.05,
            battenHeight: 0.04,
            battenSpacing: 0.33,
            hasCounterBattens: true,
            counterBattenWidth: 0.05,
            counterBattenHeight: 0.05,
            hasRafters: true,
            rafterWidth: 0.08,
            rafterHeight: 0.16,
            rafterSpacing: 0.60,
            hasWallPlate: true,
            wallPlateWidth: 0.14,
            wallPlateHeight: 0.14,
            hasRidgePurlin: true,
            ridgePurlinWidth: 0.16,
            ridgePurlinHeight: 0.20,
            hasFasciaBoard: true,
            fasciaThickness: 0.025,
          ),
          layers: [
            ArchitectRoofLayer(
              id: 'covering',
              role: ArchitectRoofLayerRole.covering,
              material: ArchitectRoofMaterial.clayTiles,
              thickness: 0.04,
            ),
            ArchitectRoofLayer(
              id: 'battens',
              role: ArchitectRoofLayerRole.battens,
              material: ArchitectRoofMaterial.timberBoarding,
              thickness: 0.04,
            ),
            ArchitectRoofLayer(
              id: 'counter_battens',
              role: ArchitectRoofLayerRole.counterBattens,
              material: ArchitectRoofMaterial.timberBoarding,
              thickness: 0.05,
            ),
            ArchitectRoofLayer(
              id: 'membrane',
              role: ArchitectRoofLayerRole.underlayment,
              material: ArchitectRoofMaterial.breathableMembrane,
              thickness: 0.003,
            ),
            ArchitectRoofLayer(
              id: 'boarding',
              role: ArchitectRoofLayerRole.boarding,
              material: ArchitectRoofMaterial.timberBoarding,
              thickness: 0.025,
            ),
            ArchitectRoofLayer(
              id: 'rafters',
              role: ArchitectRoofLayerRole.rafters,
              material: ArchitectRoofMaterial.timberBoarding,
              thickness: 0.16,
            ),
          ],
        );

      case ArchitectRoofPreset.warmPitched:
        return const ArchitectRoofAssembly(
          preset: ArchitectRoofPreset.warmPitched,
          timber: ArchitectRoofTimberSpec(
            hasBattens: true,
            battenWidth: 0.05,
            battenHeight: 0.04,
            battenSpacing: 0.33,
            hasCounterBattens: true,
            counterBattenWidth: 0.05,
            counterBattenHeight: 0.05,
            hasRafters: true,
            rafterWidth: 0.08,
            rafterHeight: 0.18,
            rafterSpacing: 0.60,
            hasWallPlate: true,
            wallPlateWidth: 0.14,
            wallPlateHeight: 0.14,
            hasRidgePurlin: true,
            ridgePurlinWidth: 0.16,
            ridgePurlinHeight: 0.20,
            hasFasciaBoard: true,
            fasciaThickness: 0.025,
          ),
          layers: [
            ArchitectRoofLayer(
              id: 'covering',
              role: ArchitectRoofLayerRole.covering,
              material: ArchitectRoofMaterial.clayTiles,
              thickness: 0.04,
            ),
            ArchitectRoofLayer(
              id: 'battens',
              role: ArchitectRoofLayerRole.battens,
              material: ArchitectRoofMaterial.timberBoarding,
              thickness: 0.04,
            ),
            ArchitectRoofLayer(
              id: 'counter_battens',
              role: ArchitectRoofLayerRole.counterBattens,
              material: ArchitectRoofMaterial.timberBoarding,
              thickness: 0.05,
            ),
            ArchitectRoofLayer(
              id: 'membrane',
              role: ArchitectRoofLayerRole.underlayment,
              material: ArchitectRoofMaterial.breathableMembrane,
              thickness: 0.003,
            ),
            ArchitectRoofLayer(
              id: 'boarding',
              role: ArchitectRoofLayerRole.boarding,
              material: ArchitectRoofMaterial.osb,
              thickness: 0.022,
            ),
            ArchitectRoofLayer(
              id: 'insulation_rafters',
              role: ArchitectRoofLayerRole.insulation,
              material: ArchitectRoofMaterial.mineralWool,
              thickness: 0.18,
              isBetweenRafters: true,
            ),
            ArchitectRoofLayer(
              id: 'vapour',
              role: ArchitectRoofLayerRole.vapourBarrier,
              material: ArchitectRoofMaterial.vapourBarrier,
              thickness: 0.002,
            ),
            ArchitectRoofLayer(
              id: 'interior',
              role: ArchitectRoofLayerRole.interior,
              material: ArchitectRoofMaterial.plasterboard,
              thickness: 0.015,
            ),
          ],
        );

      case ArchitectRoofPreset.standingSeam:
        return const ArchitectRoofAssembly(
          preset: ArchitectRoofPreset.standingSeam,
          timber: ArchitectRoofTimberSpec(
            hasBattens: true,
            battenWidth: 0.05,
            battenHeight: 0.03,
            battenSpacing: 0.25,
            hasCounterBattens: true,
            counterBattenWidth: 0.05,
            counterBattenHeight: 0.05,
            hasRafters: true,
            rafterWidth: 0.08,
            rafterHeight: 0.16,
            rafterSpacing: 0.60,
            hasWallPlate: true,
            wallPlateWidth: 0.14,
            wallPlateHeight: 0.14,
            hasRidgePurlin: true,
            ridgePurlinWidth: 0.16,
            ridgePurlinHeight: 0.20,
            hasFasciaBoard: true,
            fasciaThickness: 0.025,
          ),
          layers: [
            ArchitectRoofLayer(
              id: 'covering',
              role: ArchitectRoofLayerRole.covering,
              material: ArchitectRoofMaterial.metalSeam,
              thickness: 0.025,
            ),
            ArchitectRoofLayer(
              id: 'membrane',
              role: ArchitectRoofLayerRole.underlayment,
              material: ArchitectRoofMaterial.breathableMembrane,
              thickness: 0.003,
            ),
            ArchitectRoofLayer(
              id: 'battens',
              role: ArchitectRoofLayerRole.battens,
              material: ArchitectRoofMaterial.timberBoarding,
              thickness: 0.03,
            ),
            ArchitectRoofLayer(
              id: 'counter_battens',
              role: ArchitectRoofLayerRole.counterBattens,
              material: ArchitectRoofMaterial.timberBoarding,
              thickness: 0.05,
            ),
            ArchitectRoofLayer(
              id: 'insulation_rafters',
              role: ArchitectRoofLayerRole.insulation,
              material: ArchitectRoofMaterial.mineralWool,
              thickness: 0.16,
              isBetweenRafters: true,
            ),
            ArchitectRoofLayer(
              id: 'vapour',
              role: ArchitectRoofLayerRole.vapourBarrier,
              material: ArchitectRoofMaterial.vapourBarrier,
              thickness: 0.002,
            ),
            ArchitectRoofLayer(
              id: 'interior',
              role: ArchitectRoofLayerRole.interior,
              material: ArchitectRoofMaterial.plasterboard,
              thickness: 0.015,
            ),
          ],
        );

      case ArchitectRoofPreset.flatWarm:
        return const ArchitectRoofAssembly(
          preset: ArchitectRoofPreset.flatWarm,
          timber: ArchitectRoofTimberSpec.none,
          layers: [
            ArchitectRoofLayer(
              id: 'waterproofing',
              role: ArchitectRoofLayerRole.covering,
              material: ArchitectRoofMaterial.waterproofing,
              thickness: 0.01,
            ),
            ArchitectRoofLayer(
              id: 'screed',
              role: ArchitectRoofLayerRole.boarding,
              material: ArchitectRoofMaterial.slopeScreed,
              thickness: 0.06,
            ),
            ArchitectRoofLayer(
              id: 'insulation',
              role: ArchitectRoofLayerRole.insulation,
              material: ArchitectRoofMaterial.xps,
              thickness: 0.16,
            ),
            ArchitectRoofLayer(
              id: 'vapour',
              role: ArchitectRoofLayerRole.vapourBarrier,
              material: ArchitectRoofMaterial.vapourBarrier,
              thickness: 0.003,
            ),
            ArchitectRoofLayer(
              id: 'structure',
              role: ArchitectRoofLayerRole.structure,
              material: ArchitectRoofMaterial.rcSlab,
              thickness: 0.18,
            ),
          ],
        );
    }
  }

  /// Total thickness perpendicular to the roof slope (m).
  double get totalThickness =>
      layers.fold<double>(0.0, (sum, l) => sum + l.thickness);

  /// Thickness of all layers above the top of the rafters (covering + battens + counter-battens + boarding).
  double get thicknessAboveRafters {
    var sum = 0.0;
    for (final layer in layers) {
      if (layer.role == ArchitectRoofLayerRole.rafters ||
          layer.isBetweenRafters ||
          layer.role == ArchitectRoofLayerRole.structure) {
        break;
      }
      sum += layer.thickness;
    }
    return sum;
  }

  ArchitectRoofAssembly copyWith({
    ArchitectRoofPreset? preset,
    List<ArchitectRoofLayer>? layers,
    ArchitectRoofTimberSpec? timber,
  }) => ArchitectRoofAssembly(
    preset: preset ?? this.preset,
    layers: layers ?? this.layers.map((l) => l.copyWith()).toList(),
    timber: timber ?? this.timber.copyWith(),
  );

  Map<String, dynamic> toJson() => {
    'preset': preset.name,
    'layers': layers.map((l) => l.toJson()).toList(),
    'timber': timber.toJson(),
  };

  factory ArchitectRoofAssembly.fromJson(Map<String, dynamic> json) {
    final preset = ArchitectRoofPreset.values.byName(
      json['preset'] as String? ?? ArchitectRoofPreset.pitchedTiles.name,
    );
    final rawLayers = json['layers'] as List<dynamic>?;
    final rawTimber = json['timber'] as Map<String, dynamic>?;
    return ArchitectRoofAssembly(
      preset: preset,
      layers: rawLayers != null
          ? rawLayers
                .map(
                  (e) =>
                      ArchitectRoofLayer.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : ArchitectRoofAssembly.fromPreset(preset).layers,
      timber: rawTimber != null
          ? ArchitectRoofTimberSpec.fromJson(rawTimber)
          : ArchitectRoofAssembly.fromPreset(preset).timber,
    );
  }
}

// === SECTION: ROOF PLANE MODEL ===

/// A single sloped or flat roof plane (покривен скат) in 2D plan and 3D space.
///
/// The reference surface `elevationAt(pt)` is the bearing underside of the rafters
/// (or structural top at the eaves line):
/// - At any point on the `eavesEdge`, its base elevation relative to the storey base
///   is `baseElevationOffset` (defaults to `storey.height`, i.e. top of the walls).
/// - Moving inward perpendicular to the `eavesEdge` by horizontal distance `d`,
///   the elevation rises by `d * tan(slopeRadians)`.
class ArchitectRoofPlane {
  final String id;
  final String storeyId;
  List<Offset> points;
  int eavesEdgeIndex;
  double slopeDegrees;
  double baseElevationOffset;
  double eavesOverhang;
  ArchitectRoofEavesCut eavesCut;
  ArchitectRoofAssembly assembly;
  String? roofGroupId;

  ArchitectRoofPlane({
    required this.id,
    required this.storeyId,
    required this.points,
    this.eavesEdgeIndex = 0,
    this.slopeDegrees = 22.0,
    this.baseElevationOffset = 2.80,
    this.eavesOverhang = 0.50,
    this.eavesCut = ArchitectRoofEavesCut.plumb,
    ArchitectRoofAssembly? assembly,
    this.roofGroupId,
  }) : assembly =
           assembly ??
           ArchitectRoofAssembly.fromPreset(ArchitectRoofPreset.pitchedTiles);

  int get safeEavesEdgeIndex =>
      points.length < 2 ? 0 : eavesEdgeIndex.clamp(0, points.length - 1);

  (Offset, Offset) get eavesEdge {
    if (points.length < 2) {
      final p = points.isEmpty ? Offset.zero : points.first;
      return (p, p + const Offset(1, 0));
    }
    final i = safeEavesEdgeIndex;
    return (points[i], points[(i + 1) % points.length]);
  }

  /// Unit vector pointing horizontally from the eaves edge inward (upslope).
  Offset get slopeDirection {
    if (points.length < 2) return const Offset(0, -1);
    final (a, b) = eavesEdge;
    final edgeVec = b - a;
    final len = edgeVec.distance;
    if (len < 1e-6) return const Offset(0, -1);
    final u = edgeVec / len;
    final n1 = Offset(-u.dy, u.dx);
    final centroid = this.centroid;
    final mid = (a + b) / 2.0;
    final toCentroid = centroid - mid;
    return (toCentroid.dx * n1.dx + toCentroid.dy * n1.dy) >= 0 ? n1 : -n1;
  }

  double get slopeRadians => slopeDegrees * math.pi / 180.0;

  double get slopePercent => math.tan(slopeRadians) * 100.0;

  /// Horizontal distance from the eaves edge line along `slopeDirection`.
  /// At the eaves outer edge `signedDistanceFromEaves == 0`.
  /// At the supporting wall line (`eavesOverhang` inward), `signedDistanceFromEaves == eavesOverhang`.
  double signedDistanceFromEaves(Offset worldPt) {
    final (a, _) = eavesEdge;
    final dir = slopeDirection;
    final delta = worldPt - a;
    return delta.dx * dir.dx + delta.dy * dir.dy;
  }

  /// Maximum horizontal run of this roof plane from eaves to ridge along `slopeDirection`.
  double get maxSlopeRun {
    if (points.isEmpty) return 0.0;
    var maxDist = 0.0;
    for (final p in points) {
      final d = signedDistanceFromEaves(p);
      if (d > maxDist) maxDist = d;
    }
    return maxDist;
  }

  /// Bearing underside of rafters (or base surface) at [worldPt], relative to storey floor Z.
  /// At the wall support line (`d = eavesOverhang`), the rafter underside sits at `baseElevationOffset`.
  /// Towards the eaves (`d < eavesOverhang`), the plane continues downward so the overhang projects below the wall top!
  double undersideElevationAt(Offset worldPt) {
    final dFromWall = signedDistanceFromEaves(worldPt) - eavesOverhang;
    return baseElevationOffset + dFromWall * math.tan(slopeRadians);
  }

  /// Top exterior surface elevation at [worldPt], relative to storey floor Z.
  double topElevationAt(Offset worldPt) {
    final cosA = math.cos(slopeRadians).clamp(0.1, 1.0);
    final verticalThickness = assembly.totalThickness / cosA;
    return undersideElevationAt(worldPt) + verticalThickness;
  }

  double get eavesUndersideElevation =>
      undersideElevationAt(eavesEdge.$1);

  double get ridgeTopElevation {
    if (points.isEmpty) return baseElevationOffset;
    var maxZ = -double.infinity;
    for (final p in points) {
      final z = topElevationAt(p);
      if (z > maxZ) maxZ = z;
    }
    return maxZ.isFinite ? maxZ : baseElevationOffset;
  }

  Offset get centroid {
    if (points.isEmpty) return Offset.zero;
    var sx = 0.0, sy = 0.0;
    for (final p in points) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / points.length, sy / points.length);
  }

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    var minX = points.first.dx, maxX = points.first.dx;
    var minY = points.first.dy, maxY = points.first.dy;
    for (final p in points.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double get planArea {
    if (points.length < 3) return 0.0;
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() * 0.5;
  }

  double get slopedArea {
    final cosA = math.cos(slopeRadians).clamp(0.1, 1.0);
    return planArea / cosA;
  }

  bool containsPoint(Offset pt) {
    if (points.length < 3) return false;
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final xi = points[i].dx, yi = points[i].dy;
      final xj = points[j].dx, yj = points[j].dy;
      final intersect =
          ((yi > pt.dy) != (yj > pt.dy)) &&
          (pt.dx < (xj - xi) * (pt.dy - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  ArchitectRoofPlane copyWith({
    String? id,
    String? storeyId,
    List<Offset>? points,
    int? eavesEdgeIndex,
    double? slopeDegrees,
    double? baseElevationOffset,
    double? eavesOverhang,
    ArchitectRoofEavesCut? eavesCut,
    ArchitectRoofAssembly? assembly,
    String? roofGroupId,
  }) => ArchitectRoofPlane(
    id: id ?? this.id,
    storeyId: storeyId ?? this.storeyId,
    points: points ?? List<Offset>.from(this.points),
    eavesEdgeIndex: eavesEdgeIndex ?? this.eavesEdgeIndex,
    slopeDegrees: slopeDegrees ?? this.slopeDegrees,
    baseElevationOffset: baseElevationOffset ?? this.baseElevationOffset,
    eavesOverhang: eavesOverhang ?? this.eavesOverhang,
    eavesCut: eavesCut ?? this.eavesCut,
    assembly: assembly ?? this.assembly.copyWith(),
    roofGroupId: roofGroupId ?? this.roofGroupId,
  );

  ArchitectRoofPlane clone() => copyWith();

  Map<String, dynamic> toJson() => {
    'id': id,
    'storeyId': storeyId,
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'eavesEdgeIndex': eavesEdgeIndex,
    'slopeDegrees': slopeDegrees,
    'baseElevationOffset': baseElevationOffset,
    'eavesOverhang': eavesOverhang,
    'eavesCut': eavesCut.name,
    'assembly': assembly.toJson(),
    'roofGroupId': roofGroupId,
  };

  factory ArchitectRoofPlane.fromJson(Map<String, dynamic> json) {
    final rawPts = json['points'] as List<dynamic>? ?? const [];
    return ArchitectRoofPlane(
      id: json['id'] as String,
      storeyId: json['storeyId'] as String? ?? 'storey_0',
      points: rawPts.map((e) {
        final m = e as Map<String, dynamic>;
        return Offset(
          (m['x'] as num).toDouble(),
          (m['y'] as num).toDouble(),
        );
      }).toList(),
      eavesEdgeIndex: json['eavesEdgeIndex'] as int? ?? 0,
      slopeDegrees: (json['slopeDegrees'] as num?)?.toDouble() ?? 22.0,
      baseElevationOffset:
          (json['baseElevationOffset'] as num?)?.toDouble() ?? 2.80,
      eavesOverhang: (json['eavesOverhang'] as num?)?.toDouble() ?? 0.50,
      eavesCut: ArchitectRoofEavesCut.values.byName(
        json['eavesCut'] as String? ?? ArchitectRoofEavesCut.plumb.name,
      ),
      assembly: json['assembly'] != null
          ? ArchitectRoofAssembly.fromJson(
              json['assembly'] as Map<String, dynamic>,
            )
          : ArchitectRoofAssembly.fromPreset(ArchitectRoofPreset.pitchedTiles),
      roofGroupId: json['roofGroupId'] as String?,
    );
  }

  String toEncodedJson() => jsonEncode(toJson());
}
