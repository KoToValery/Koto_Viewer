import 'architect_contour.dart';
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
import 'architect_roof_drainage.dart';
export 'architect_roof_drainage.dart';
import 'architect_roof_panel.dart';
export 'architect_roof_panel.dart';

// === SECTION: ENUMS ===

enum ArchitectRoofPreset {
  pitchedTiles,
  warmPitched,
  standingSeam,
  flatWarm,
  custom,
  logTimber,
  sandwichPitched,
  sandwichMembrane;

  String label(AppLocalizations l10n) => switch (this) {
    ArchitectRoofPreset.pitchedTiles => l10n.architectRoofPresetPitchedTiles,
    ArchitectRoofPreset.warmPitched => l10n.architectRoofPresetWarmPitched,
    ArchitectRoofPreset.standingSeam => l10n.architectRoofPresetStandingSeam,
    ArchitectRoofPreset.flatWarm => l10n.architectRoofPresetFlatWarm,
    ArchitectRoofPreset.custom => l10n.architectRoofPresetCustom,
    ArchitectRoofPreset.logTimber => l10n.architectRoofPresetLogTimber,
    ArchitectRoofPreset.sandwichPitched => l10n.roofPanelPitched,
    ArchitectRoofPreset.sandwichMembrane => l10n.roofPanelMembrane,
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
    ArchitectRoofLayerRole.counterBattens =>
      l10n.architectRoofRoleCounterBattens,
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
  plasterboard,
  steel,
  pir;

  String label(AppLocalizations l10n) => switch (this) {
    ArchitectRoofMaterial.clayTiles => l10n.architectRoofMatClayTiles,
    ArchitectRoofMaterial.concreteTiles => l10n.architectRoofMatConcreteTiles,
    ArchitectRoofMaterial.metalSeam => l10n.architectRoofMatMetalSeam,
    ArchitectRoofMaterial.bitumenShingles =>
      l10n.architectRoofMatBitumenShingles,
    ArchitectRoofMaterial.timberBoarding => l10n.architectRoofMatTimberBoarding,
    ArchitectRoofMaterial.osb => l10n.architectRoofMatOsb,
    ArchitectRoofMaterial.breathableMembrane =>
      l10n.architectRoofMatBreathableMembrane,
    ArchitectRoofMaterial.vapourBarrier => l10n.architectRoofMatVapourBarrier,
    ArchitectRoofMaterial.mineralWool => l10n.architectRoofMatMineralWool,
    ArchitectRoofMaterial.xps => l10n.architectRoofMatXps,
    ArchitectRoofMaterial.waterproofing => l10n.architectRoofMatWaterproofing,
    ArchitectRoofMaterial.slopeScreed => l10n.architectRoofMatSlopeScreed,
    ArchitectRoofMaterial.rcSlab => l10n.architectRoofMatRcSlab,
    ArchitectRoofMaterial.plasterboard => l10n.architectRoofMatPlasterboard,
    ArchitectRoofMaterial.steel => l10n.wallMaterialSteel,
    ArchitectRoofMaterial.pir => l10n.wallMaterialPir,
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

  final bool hasRingBeam;
  final double
  ringBeamHeight; // vertical height of concrete belt under wall plate (m), e.g. 0.10

  final bool hasRidgePurlin;
  final double ridgePurlinWidth; // horizontal width (m), e.g. 0.16
  final double ridgePurlinHeight; // vertical height (m), e.g. 0.20

  final bool hasFasciaBoard;
  final double fasciaThickness; // thickness at eaves (m), e.g. 0.025

  final bool hasMetalFlashing;

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
    this.hasRingBeam = true,
    this.ringBeamHeight = 0.10,
    this.hasRidgePurlin = true,
    this.ridgePurlinWidth = 0.16,
    this.ridgePurlinHeight = 0.20,
    this.hasFasciaBoard = true,
    this.fasciaThickness = 0.025,
    this.hasMetalFlashing = true,
  });

  static const none = ArchitectRoofTimberSpec(
    hasBattens: false,
    hasCounterBattens: false,
    hasRafters: false,
    hasWallPlate: false,
    hasRingBeam: false,
    hasRidgePurlin: false,
    hasFasciaBoard: false,
    hasMetalFlashing: false,
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
    bool? hasRingBeam,
    double? ringBeamHeight,
    bool? hasRidgePurlin,
    double? ridgePurlinWidth,
    double? ridgePurlinHeight,
    bool? hasFasciaBoard,
    double? fasciaThickness,
    bool? hasMetalFlashing,
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
    hasRingBeam: hasRingBeam ?? this.hasRingBeam,
    ringBeamHeight: ringBeamHeight ?? this.ringBeamHeight,
    hasRidgePurlin: hasRidgePurlin ?? this.hasRidgePurlin,
    ridgePurlinWidth: ridgePurlinWidth ?? this.ridgePurlinWidth,
    ridgePurlinHeight: ridgePurlinHeight ?? this.ridgePurlinHeight,
    hasFasciaBoard: hasFasciaBoard ?? this.hasFasciaBoard,
    fasciaThickness: fasciaThickness ?? this.fasciaThickness,
    hasMetalFlashing: hasMetalFlashing ?? this.hasMetalFlashing,
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
    'hasRingBeam': hasRingBeam,
    'ringBeamHeight': ringBeamHeight,
    'hasRidgePurlin': hasRidgePurlin,
    'ridgePurlinWidth': ridgePurlinWidth,
    'ridgePurlinHeight': ridgePurlinHeight,
    'hasFasciaBoard': hasFasciaBoard,
    'fasciaThickness': fasciaThickness,
    'hasMetalFlashing': hasMetalFlashing,
  };

  factory ArchitectRoofTimberSpec.fromJson(
    Map<String, dynamic> json,
  ) => ArchitectRoofTimberSpec(
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
    hasRingBeam: json['hasRingBeam'] as bool? ?? true,
    ringBeamHeight: (json['ringBeamHeight'] as num?)?.toDouble() ?? 0.10,
    hasRidgePurlin: json['hasRidgePurlin'] as bool? ?? true,
    ridgePurlinWidth: (json['ridgePurlinWidth'] as num?)?.toDouble() ?? 0.16,
    ridgePurlinHeight: (json['ridgePurlinHeight'] as num?)?.toDouble() ?? 0.20,
    hasFasciaBoard: json['hasFasciaBoard'] as bool? ?? true,
    fasciaThickness: (json['fasciaThickness'] as num?)?.toDouble() ?? 0.025,
    hasMetalFlashing: json['hasMetalFlashing'] as bool? ?? true,
  );
}

// === SECTION: ROOF ASSEMBLY & PRESETS ===

class ArchitectRoofAssembly {
  final ArchitectRoofPanelSpec? panels;
  final ArchitectRoofPreset preset;
  final List<ArchitectRoofLayer> layers;
  final ArchitectRoofTimberSpec timber;

  const ArchitectRoofAssembly({
    this.panels,
    required this.preset,
    required this.layers,
    required this.timber,
  });

  factory ArchitectRoofAssembly.fromPreset(ArchitectRoofPreset preset) {
    switch (preset) {
      case ArchitectRoofPreset.sandwichPitched:
      case ArchitectRoofPreset.sandwichMembrane:
        return ArchitectRoofAssembly.panelRoof(
          ArchitectRoofPanelSpec(membrane:preset==ArchitectRoofPreset.sandwichMembrane,
            minimumSlope:preset==ArchitectRoofPreset.sandwichMembrane?1.2:4),preset:preset);
      case ArchitectRoofPreset.logTimber:
        final base = ArchitectRoofAssembly.fromPreset(
          ArchitectRoofPreset.warmPitched,
        );
        return base.copyWith(
          preset: preset,
          timber: base.timber.copyWith(hasRingBeam: false),
        );
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
  double get totalThickness => panels?.totalDepth ??
      layers.fold<double>(0.0, (sum, l) => sum + layerDepth(l));

  factory ArchitectRoofAssembly.panelRoof(ArchitectRoofPanelSpec spec,{ArchitectRoofPreset? preset}) =>
    ArchitectRoofAssembly(preset:preset??(spec.membrane?ArchitectRoofPreset.sandwichMembrane:ArchitectRoofPreset.sandwichPitched),
      panels:spec,timber:ArchitectRoofTimberSpec.none,layers:[
        if(spec.membrane) ArchitectRoofLayer(id:'membrane',role:ArchitectRoofLayerRole.covering,
          material:ArchitectRoofMaterial.waterproofing,thickness:spec.membraneThickness),
        ArchitectRoofLayer(id:'outer_skin',role:ArchitectRoofLayerRole.covering,material:ArchitectRoofMaterial.steel,thickness:spec.skin),
        ArchitectRoofLayer(id:'panel_core',role:ArchitectRoofLayerRole.insulation,material:ArchitectRoofMaterial.pir,thickness:spec.thickness-2*spec.skin),
        ArchitectRoofLayer(id:'inner_skin',role:ArchitectRoofLayerRole.interior,material:ArchitectRoofMaterial.steel,thickness:spec.skin),
        ArchitectRoofLayer(id:'steel_frame',role:ArchitectRoofLayerRole.structure,material:ArchitectRoofMaterial.steel,thickness:spec.structureDepth),
      ]);

  /// Insulation occupies the rafter zone, with any unfilled depth remaining air.
  /// It does not reduce the zone below the physical framing depth.
  double layerDepth(ArchitectRoofLayer layer) =>
      timber.hasRafters &&
          (layer.isBetweenRafters ||
              layer.role == ArchitectRoofLayerRole.rafters)
      ? math.max(layer.thickness, timber.rafterHeight)
      : layer.thickness;

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
    ArchitectRoofPanelSpec? panels,
    bool clearPanels=false,
    ArchitectRoofPreset? preset,
    List<ArchitectRoofLayer>? layers,
    ArchitectRoofTimberSpec? timber,
  }) => ArchitectRoofAssembly(
    panels:clearPanels?null:panels??this.panels,
    preset: preset ?? this.preset,
    layers: layers ?? this.layers.map((l) => l.copyWith()).toList(),
    timber: timber ?? this.timber.copyWith(),
  );

  Map<String, dynamic> toJson() => {
    if(panels!=null) 'panels':panels!.toJson(),
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
      panels:json['panels'] is Map?ArchitectRoofPanelSpec.fromJson(json['panels'] as Map):
        (preset==ArchitectRoofPreset.sandwichPitched||preset==ArchitectRoofPreset.sandwichMembrane
          ?ArchitectRoofPanelSpec(membrane:preset==ArchitectRoofPreset.sandwichMembrane,
            minimumSlope:preset==ArchitectRoofPreset.sandwichMembrane?1.2:4):null),
      preset: preset,
      layers: rawLayers != null
          ? rawLayers
                .map(
                  (e) => ArchitectRoofLayer.fromJson(e as Map<String, dynamic>),
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
  final List<List<Offset>> holes;
  final String id;
  final String storeyId;
  List<Offset> points;
  int eavesEdgeIndex;
  bool reverseSlope;
  double slopeDegrees;
  double baseElevationOffset;
  bool attachToWalls;

  /// The initial support height has been materialized in model coordinates.
  bool placementResolved;
  double eavesOverhang;

  /// Horizontal eaves-to-support centreline distance; null follows the walls.
  double? manualSupportDistance;
  ArchitectRoofEavesCut eavesCut;
  ArchitectRoofAssembly assembly;
  String? roofGroupId;
  bool isSlopeLocked;
  final ArchitectRoofDrainage drainage;

  /// Whether this plane has a broken Mansard (Gambrel / пречупен) pitch.
  final bool isMansard;

  /// Slope of the upper roof plane above the knuckle fold line (degrees).
  final double upperSlopeDegrees;

  /// Horizontal distance from the low eaves edge to the knuckle break line (m).
  /// If null, defaults to 45% of `maxSlopeRun`.
  final double? breakDistance;

  ArchitectRoofPlane({
    required this.id,
    this.holes = const [],
    required this.storeyId,
    required this.points,
    this.eavesEdgeIndex = 0,
    this.reverseSlope = false,
    this.slopeDegrees = 22.0,
    this.baseElevationOffset = 2.80,
    this.attachToWalls = true,
    this.placementResolved = false,
    this.eavesOverhang = 0.50,
    this.manualSupportDistance,
    this.eavesCut = ArchitectRoofEavesCut.plumb,
    ArchitectRoofAssembly? assembly,
    this.roofGroupId,
    this.isSlopeLocked = true,
    this.drainage = const ArchitectRoofDrainage(),
    this.isMansard = false,
    this.upperSlopeDegrees = 25.0,
    this.breakDistance,
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

  /// Inward normal of the edge at [edgeIndex] pointing toward the polygon centroid.
  Offset inwardNormalOfEdge(int edgeIndex) {
    if (points.length < 2) return const Offset(0, -1);
    final idx = edgeIndex.clamp(0, points.length - 1);
    final a = points[idx];
    final b = points[(idx + 1) % points.length];
    final edgeVec = b - a;
    final len = edgeVec.distance;
    if (len < 1e-6) return const Offset(0, -1);
    final u = edgeVec / len;
    final n1 = Offset(-u.dy, u.dx);
    final c = centroid;
    final mid = (a + b) / 2.0;
    final toCentroid = c - mid;
    return (toCentroid.dx * n1.dx + toCentroid.dy * n1.dy) >= 0 ? n1 : -n1;
  }

  Offset get _rawEavesInwardNormal => inwardNormalOfEdge(safeEavesEdgeIndex);

  /// Unit vector pointing horizontally from the low eaves side toward the high ridge side (upslope).
  Offset get slopeDirection =>
      reverseSlope ? -_rawEavesInwardNormal : _rawEavesInwardNormal;

  double get slopeRadians => slopeDegrees * math.pi / 180.0;

  double get slopePercent => math.tan(slopeRadians) * 100.0;

  double get upperSlopeRadians => upperSlopeDegrees * math.pi / 180.0;

  double get upperSlopePercent => math.tan(upperSlopeRadians) * 100.0;

  double get minimumBreakDistance => maxSlopeRun > 0.60 ? 0.25 : 0.10;
  double get maximumBreakDistance =>
      maxSlopeRun > 0.60 ? math.max(0.30, maxSlopeRun - 0.25) : 50.0;

  /// Horizontal distance from the low eaves line to the knuckle break line along slope direction.
  double get effectiveBreakDistance {
    final maxRun = maxSlopeRun;
    if (breakDistance != null) {
      return breakDistance!.clamp(minimumBreakDistance, maximumBreakDistance);
    }
    if (maxRun > 1.0) {
      return (maxRun * 0.45).clamp(0.80, math.max(0.80, maxRun - 0.50));
    }
    return 1.80;
  }

  /// The 2D line segment in model space representing the knuckle fold line across this roof plane.
  /// Returns null if this is not a Mansard roof or if the knuckle line does not intersect the polygon.
  (Offset, Offset)? get knuckleSegment {
    if (!isMansard || points.length < 3) return null;
    final k = effectiveBreakDistance;
    final (eavesP0, _) = eavesEdge;
    final rawDir = _rawEavesInwardNormal;
    final rawDist = reverseSlope ? (_maxRawRun - k) : k;
    final centerOnKnuckle = eavesP0 + rawDir * rawDist;
    final knuckleDir = Offset(-rawDir.dy, rawDir.dx);

    final hits = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final hit = _intersectLineWithSegment(centerOnKnuckle, knuckleDir, a, b);
      if (hit != null) {
        if (hits.every((h) => (h - hit).distance > 1e-4)) {
          hits.add(hit);
        }
      }
    }
    if (hits.length < 2) return null;
    hits.sort((p1, p2) {
      final t1 =
          (p1 - centerOnKnuckle).dx * knuckleDir.dx +
          (p1 - centerOnKnuckle).dy * knuckleDir.dy;
      final t2 =
          (p2 - centerOnKnuckle).dx * knuckleDir.dx +
          (p2 - centerOnKnuckle).dy * knuckleDir.dy;
      return t1.compareTo(t2);
    });
    return (hits.first, hits.last);
  }

  /// Midpoint of the knuckle line segment in model space, used as the interactive handle.
  Offset? get knuckleMidpoint {
    final seg = knuckleSegment;
    return seg != null ? (seg.$1 + seg.$2) * 0.5 : null;
  }

  static Offset? _intersectLineWithSegment(
    Offset linePt,
    Offset lineDir,
    Offset a,
    Offset b,
  ) {
    final ab = b - a;
    final denom = ab.dx * lineDir.dy - ab.dy * lineDir.dx;
    if (denom.abs() < 1e-9) return null;
    final delta = linePt - a;
    final t = (delta.dx * lineDir.dy - delta.dy * lineDir.dx) / denom;
    if (t >= -1e-5 && t <= 1.0 + 1e-5) {
      return a + ab * t.clamp(0.0, 1.0);
    }
    return null;
  }

  double get _maxRawRun {
    if (points.isEmpty) return 0.0;
    final (a, _) = eavesEdge;
    final dir = _rawEavesInwardNormal;
    var maxDist = 0.0;
    for (final p in points) {
      final delta = p - a;
      final d = delta.dx * dir.dx + delta.dy * dir.dy;
      if (d > maxDist) maxDist = d;
    }
    return maxDist;
  }

  /// Horizontal distance from the low eaves line along `slopeDirection` (upslope).
  /// At the low eaves outer edge `signedDistanceFromEaves == 0`.
  /// At the supporting wall line (`eavesOverhang` inward), `signedDistanceFromEaves == eavesOverhang`.
  double signedDistanceFromEaves(Offset worldPt) {
    final (a, _) = eavesEdge;
    final rawDir = _rawEavesInwardNormal;
    final delta = worldPt - a;
    final rawDist = delta.dx * rawDir.dx + delta.dy * rawDir.dy;
    return reverseSlope ? (_maxRawRun - rawDist) : rawDist;
  }

  /// Maximum horizontal run of this roof plane from eaves to ridge along `slopeDirection`.
  double get maxSlopeRun => _maxRawRun;

  /// Sets [edgeIndex] as the lower eaves edge from which the roof slopes upward.
  ArchitectRoofPlane withEavesEdge(int edgeIndex) => copyWith(
    eavesEdgeIndex: points.isEmpty ? 0 : edgeIndex.clamp(0, points.length - 1),
    reverseSlope: false,
  );

  /// Cycles the slope direction to the next polygon edge.
  ArchitectRoofPlane nextSlopeEdge() => points.length < 2
      ? this
      : copyWith(
          eavesEdgeIndex: (safeEavesEdgeIndex + 1) % points.length,
          reverseSlope: false,
        );

  /// Reverses the slope direction by 180°. If the polygon has an opposing parallel
  /// edge, switches `eavesEdgeIndex` to that edge; otherwise toggles `reverseSlope`.
  ArchitectRoofPlane flippedSlope() {
    if (points.length < 3) return copyWith(reverseSlope: !reverseSlope);
    final currentDir = slopeDirection;
    int? oppositeIdx;
    var bestDot = -0.85;
    for (var i = 0; i < points.length; i++) {
      if (i == safeEavesEdgeIndex && !reverseSlope) continue;
      final n = inwardNormalOfEdge(i);
      final dot = currentDir.dx * n.dx + currentDir.dy * n.dy;
      if (dot <= bestDot) {
        bestDot = dot;
        oppositeIdx = i;
      }
    }
    if (oppositeIdx != null) {
      return copyWith(eavesEdgeIndex: oppositeIdx, reverseSlope: false);
    }
    return copyWith(reverseSlope: !reverseSlope);
  }

  /// Bearing underside of rafters (or base surface) at [worldPt], relative to storey floor Z.
  /// At the wall support line (`d = eavesOverhang`), the rafter underside sits at `baseElevationOffset`.
  /// Towards the eaves (`d < eavesOverhang`), the plane continues downward so the overhang projects below the wall top!
  double undersideElevationAt(Offset worldPt) {
    final d = signedDistanceFromEaves(worldPt);
    final dFromWall = d - eavesOverhang;
    if (!isMansard) {
      return baseElevationOffset + dFromWall * math.tan(slopeRadians);
    }
    final k = effectiveBreakDistance;
    final zKnuckle =
        baseElevationOffset + (k - eavesOverhang) * math.tan(slopeRadians);
    if (d <= k) {
      return baseElevationOffset + dFromWall * math.tan(slopeRadians);
    } else {
      return zKnuckle + (d - k) * math.tan(upperSlopeRadians);
    }
  }

  /// Top exterior surface elevation at [worldPt], relative to storey floor Z.
  double topElevationAt(Offset worldPt) {
    final d = signedDistanceFromEaves(worldPt);
    final k = effectiveBreakDistance;
    final effectiveSlopeRad = (isMansard && d > k)
        ? upperSlopeRadians
        : slopeRadians;
    final cosA = math.cos(effectiveSlopeRad).clamp(0.1, 1.0);
    final verticalThickness = assembly.totalThickness / cosA;
    return undersideElevationAt(worldPt) + verticalThickness;
  }

  double get eavesUndersideElevation =>
      baseElevationOffset - eavesOverhang * math.tan(slopeRadians);

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
    return sum.abs() * 0.5 - ArchitectContour.area(holes);
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
          (pt.dx <
              (xj - xi) * (pt.dy - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside &&
        !holes.any((h) => (Path()..addPolygon(h, true)).contains(pt));
  }

  ArchitectRoofPlane copyWith({
    String? id,
    List<List<Offset>>? holes,
    String? storeyId,
    List<Offset>? points,
    int? eavesEdgeIndex,
    bool? reverseSlope,
    double? slopeDegrees,
    double? baseElevationOffset,
    bool? attachToWalls,
    bool? placementResolved,
    double? eavesOverhang,
    double? manualSupportDistance,
    bool clearManualSupportDistance = false,
    ArchitectRoofEavesCut? eavesCut,
    ArchitectRoofAssembly? assembly,
    String? roofGroupId,
    bool? isSlopeLocked,
    ArchitectRoofDrainage? drainage,
    bool? isMansard,
    double? upperSlopeDegrees,
    double? breakDistance,
    bool clearBreakDistance = false,
  }) => ArchitectRoofPlane(
    id: id ?? this.id,
    holes: holes ?? this.holes,
    storeyId: storeyId ?? this.storeyId,
    points: points ?? List<Offset>.from(this.points),
    eavesEdgeIndex: eavesEdgeIndex ?? this.eavesEdgeIndex,
    reverseSlope: reverseSlope ?? this.reverseSlope,
    slopeDegrees: slopeDegrees ?? this.slopeDegrees,
    baseElevationOffset: baseElevationOffset ?? this.baseElevationOffset,
    attachToWalls: attachToWalls ?? this.attachToWalls,
    placementResolved: placementResolved ?? this.placementResolved,
    eavesOverhang: eavesOverhang ?? this.eavesOverhang,
    manualSupportDistance: clearManualSupportDistance
        ? null
        : (manualSupportDistance ?? this.manualSupportDistance),
    eavesCut: eavesCut ?? this.eavesCut,
    assembly: assembly ?? this.assembly.copyWith(),
    roofGroupId: roofGroupId ?? this.roofGroupId,
    isSlopeLocked: isSlopeLocked ?? this.isSlopeLocked,
    drainage: drainage ?? this.drainage,
    isMansard: isMansard ?? this.isMansard,
    upperSlopeDegrees: upperSlopeDegrees ?? this.upperSlopeDegrees,
    breakDistance: clearBreakDistance
        ? null
        : (breakDistance ?? this.breakDistance),
  );

  ArchitectRoofPlane clone() => copyWith();

  Map<String, dynamic> toJson() => {
    'id': id,
    if (holes.isNotEmpty) 'holes': ArchitectContour.write(holes),
    'storeyId': storeyId,
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'eavesEdgeIndex': eavesEdgeIndex,
    'reverseSlope': reverseSlope,
    'slopeDegrees': slopeDegrees,
    'baseElevationOffset': baseElevationOffset,
    'attachToWalls': attachToWalls,
    'placementResolved': placementResolved,
    'eavesOverhang': eavesOverhang,
    if (manualSupportDistance != null)
      'manualSupportDistance': manualSupportDistance,
    'eavesCut': eavesCut.name,
    'assembly': assembly.toJson(),
    'roofGroupId': roofGroupId,
    'isSlopeLocked': isSlopeLocked,
    'drainage': drainage.toJson(),
    'isMansard': isMansard,
    'upperSlopeDegrees': upperSlopeDegrees,
    if (breakDistance != null) 'breakDistance': breakDistance,
  };

  factory ArchitectRoofPlane.fromJson(Map<String, dynamic> json) {
    final rawPts = json['points'] as List<dynamic>? ?? const [];
    return ArchitectRoofPlane(
      id: json['id'] as String,
      holes: ArchitectContour.read(json['holes']),
      storeyId: json['storeyId'] as String? ?? 'storey_0',
      points: rawPts.map((e) {
        final m = e as Map<String, dynamic>;
        return Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
      }).toList(),
      eavesEdgeIndex: json['eavesEdgeIndex'] as int? ?? 0,
      reverseSlope: json['reverseSlope'] as bool? ?? false,
      slopeDegrees: (json['slopeDegrees'] as num?)?.toDouble() ?? 22.0,
      baseElevationOffset:
          (json['baseElevationOffset'] as num?)?.toDouble() ?? 2.80,
      attachToWalls: json['attachToWalls'] as bool? ?? true,
      placementResolved: json['placementResolved'] as bool? ?? false,
      eavesOverhang: (json['eavesOverhang'] as num?)?.toDouble() ?? 0.50,
      manualSupportDistance: (json['manualSupportDistance'] as num?)
          ?.toDouble(),
      eavesCut: ArchitectRoofEavesCut.values.byName(
        json['eavesCut'] as String? ?? ArchitectRoofEavesCut.plumb.name,
      ),
      assembly: json['assembly'] != null
          ? ArchitectRoofAssembly.fromJson(
              json['assembly'] as Map<String, dynamic>,
            )
          : ArchitectRoofAssembly.fromPreset(ArchitectRoofPreset.pitchedTiles),
      roofGroupId: json['roofGroupId'] as String?,
      isSlopeLocked: json['isSlopeLocked'] as bool? ?? true,
      drainage: ArchitectRoofDrainage.fromJson(json['drainage'] as Map? ?? {}),
      isMansard: json['isMansard'] as bool? ?? false,
      upperSlopeDegrees:
          (json['upperSlopeDegrees'] as num?)?.toDouble() ?? 25.0,
      breakDistance: (json['breakDistance'] as num?)?.toDouble(),
    );
  }

  String toEncodedJson() => jsonEncode(toJson());
}
