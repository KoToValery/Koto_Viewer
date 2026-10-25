import 'architect_roof.dart';

enum ArchitectRoofSetting {
  assembly,
  slope,
  overhang,
  eavesCut,
  elevation,
  attachment,
  support,
  upperSlope,
  breakDistance,
  gutterVisible,
  pipesVisible,
  gutterProfile,
  gutterMaterial,
  gutterWidth,
  gutterDepth,
  pipes,
}

/// A settings snapshot plus the fields explicitly changed by the editor.
class ArchitectRoofLayersResult {
  final ArchitectRoofAssembly assembly;
  final double slopeDegrees, eavesOverhang, upperSlopeDegrees;
  final ArchitectRoofEavesCut eavesCut;
  final double? baseElevationOffset, manualSupportDistance, breakDistance;
  final bool attachToWalls, pickDownpipe, applyToGroup, saveForNewRoofs;
  final ArchitectRoofDrainage drainage;
  final Set<ArchitectRoofSetting> changes;
  const ArchitectRoofLayersResult({
    required this.assembly,
    required this.slopeDegrees,
    required this.eavesOverhang,
    required this.eavesCut,
    this.baseElevationOffset,
    this.attachToWalls = true,
    this.manualSupportDistance,
    this.drainage = const ArchitectRoofDrainage(),
    this.pickDownpipe = false,
    this.applyToGroup = false,
    this.saveForNewRoofs = false,
    this.upperSlopeDegrees = 25,
    this.breakDistance,
    this.changes = const {},
  });
}
