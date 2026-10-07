import '../models/structural_element.dart';
import '../models/slab_topology.dart';
import 'slab_topology_analyzer.dart';

enum SchemeReadinessIssue {
  editing,
  missingSlab,
  missingStaircase,
  ambiguousLevels,
  invalidSlabLevel,
  invalidGeometry,
  overlappingSlabs,
  computationLimit,
}

/// Stable owner IDs plus an index valid for this immutable project snapshot.
/// Recompute after edits; never persist this index as an independent link.
class CeilingOpeningReference {
  final String storeyId;
  final String slabId;
  final int openingIndex;
  final SlabOpeningType type;
  final double concreteTop;
  final double concreteSoffit;
  const CeilingOpeningReference({
    required this.storeyId,
    required this.slabId,
    required this.openingIndex,
    required this.type,
    required this.concreteTop,
    required this.concreteSoffit,
  });
}

class StructuralSchemeReadiness {
  final List<SchemeReadinessIssue> issues;
  final List<CeilingOpeningReference> openings;
  final int regionCount;
  const StructuralSchemeReadiness(this.issues, this.openings, this.regionCount);

  /// Geometry prerequisites only; preview confirmation and engineering review
  /// remain required. This does not certify a structural design.
  bool get geometryReady => issues.isEmpty;

  static StructuralSchemeReadiness evaluate(
    StructuralProject project,
    double scale, {
    bool editing = false,
  }) {
    final issues = <SchemeReadinessIssue>{};
    final refs = <CeilingOpeningReference>[];
    if (editing) issues.add(SchemeReadinessIssue.editing);
    if (project.storeys.isEmpty ||
        project.activeStoreyIndex < 0 ||
        project.activeStoreyIndex >= project.storeys.length) {
      return StructuralSchemeReadiness(
        [...issues, SchemeReadinessIssue.ambiguousLevels],
        const [],
        0,
      );
    }
    final active = project.activeStorey;
    if (project.storeys.map((s) => s.id).toSet().length !=
            project.storeys.length ||
        active.slabs.map((s) => s.id).toSet().length != active.slabs.length ||
        project.storeys.any((s) => !s.elevation.isFinite) ||
        project.storeys.any(
          (s) =>
              s.id != active.id &&
              (s.elevation - active.elevation).abs() < 1e-6,
        )) {
      issues.add(SchemeReadinessIssue.ambiguousLevels);
    }
    if (!active.elevation.isFinite ||
        !active.height.isFinite ||
        active.height <= 0) {
      issues.add(SchemeReadinessIssue.invalidSlabLevel);
    }
    if (active.slabs.isEmpty) issues.add(SchemeReadinessIssue.missingSlab);
    final topology = SlabTopologyAnalyzer.analyze(active.slabs, scale);
    switch (topology.issue) {
      case SlabTopologyIssue.invalidGeometry:
        issues.add(SchemeReadinessIssue.invalidGeometry);
      case SlabTopologyIssue.overlappingSlabs:
        issues.add(SchemeReadinessIssue.overlappingSlabs);
      case SlabTopologyIssue.computationLimit:
        issues.add(SchemeReadinessIssue.computationLimit);
      case SlabTopologyIssue.none:
      case SlabTopologyIssue.separateRegions:
        break;
    }
    for (final slab in active.slabs) {
      final top = active.structuralElevationFor(slab);
      final soffit = active.slabSoffitElevationFor(slab);
      if (!top.isFinite ||
          !soffit.isFinite ||
          !slab.thickness.isFinite ||
          slab.thickness <= 0 ||
          soffit <= active.elevation) {
        issues.add(SchemeReadinessIssue.invalidSlabLevel);
      }
      for (var i = 0; i < slab.openings.length; i++) {
        refs.add(
          CeilingOpeningReference(
            storeyId: active.id,
            slabId: slab.id,
            openingIndex: i,
            type: slab.getOpeningType(i),
            concreteTop: top,
            concreteSoffit: soffit,
          ),
        );
      }
    }
    if (!refs.any((r) => r.type == SlabOpeningType.staircase)) {
      issues.add(SchemeReadinessIssue.missingStaircase);
    }
    return StructuralSchemeReadiness(
      List.unmodifiable(issues),
      List.unmodifiable(refs),
      topology.regionCount,
    );
  }
}
