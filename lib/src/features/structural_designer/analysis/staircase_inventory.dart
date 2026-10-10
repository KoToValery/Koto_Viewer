import 'dart:ui';
import '../models/structural_element.dart';
import '../models/slab_topology.dart';
import 'slab_contact_geometry.dart';
import 'slab_topology_analyzer.dart';
import 'support_placement_rules.dart';

enum StaircaseRequirement { review, scope, circulation, opening, support }

class StaircaseGap {
  final StaircaseRequirement requirement;
  final String? coreId;
  final String? storeyId;
  const StaircaseGap(this.requirement, {this.coreId, this.storeyId});
}

class StaircaseOpeningOwner {
  final String coreId, arrivalStoreyId, ownerStoreyId, slabId;
  final int openingIndex;
  const StaircaseOpeningOwner(
    this.coreId,
    this.arrivalStoreyId,
    this.ownerStoreyId,
    this.slabId,
    this.openingIndex,
  );
}

/// Checks the persisted owner model, never a transient ceiling snapshot.
class StaircaseInventory {
  final List<StaircaseGap> gaps;
  final List<StaircaseOpeningOwner> openings;
  const StaircaseInventory(this.gaps, this.openings);
  bool get ready => gaps.isEmpty;
  static bool validZone(List<Offset> polygon, double scale) =>
      scale.isFinite &&
      scale > 0 &&
      polygon.length >= 3 &&
      SlabTopologyAnalyzer.analyze([
            StructuralSlab(id: 'zone', polygon: polygon),
          ], scale).issue ==
          SlabTopologyIssue.none;
  static List<StoreyLevel> levels(
    StructuralProject project,
    StaircaseCore core,
  ) {
    final starts = project.storeys
        .where((s) => s.id == core.startStoreyId)
        .toList();
    final ends = project.storeys
        .where((s) => s.id == core.endStoreyId)
        .toList();
    if (starts.length != 1 ||
        ends.length != 1 ||
        !starts.single.elevation.isFinite ||
        !ends.single.elevation.isFinite ||
        starts.single.elevation >= ends.single.elevation) {
      return [];
    }
    return project.storeys
        .where(
          (s) =>
              s.elevation >= starts.single.elevation &&
              s.elevation <= ends.single.elevation,
        )
        .toList()
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
  }

  /// Existing typed cuts are evidence independently of circulation reservations.
  static List<StaircaseOpeningOwner> physicalOpenings(
    StructuralProject project,
    StoreyLevel floor,
    double scale,
  ) {
    final legacy = project.floorSlabStoreyFor(floor);
    final owners = [
      floor.copyWith(slabs: floor.slabs.where((s) => s.isFloorSlab).toList()),
      ?legacy,
    ];
    return [
      for (final owner in owners)
        for (final slab in owner.slabs)
          if ((owner.structuralElevationFor(slab) +
                          (slab.floorFinish ?? owner.floorFinishThickness) -
                          floor.elevation)
                      .abs() <=
                  .01 &&
              SlabTopologyAnalyzer.analyze([slab], scale).issue ==
                  SlabTopologyIssue.none)
            for (var i = 0; i < slab.openings.length; i++)
              if (slab.getOpeningType(i) == SlabOpeningType.staircase)
                StaircaseOpeningOwner('', floor.id, owner.id, slab.id, i),
    ];
  }

  static List<Offset> polygon(
    StructuralProject project,
    StaircaseOpeningOwner ref,
  ) => project.storeys
      .firstWhere((s) => s.id == ref.ownerStoreyId)
      .slabs
      .firstWhere((s) => s.id == ref.slabId)
      .openings[ref.openingIndex];

  /// Propose scopes from existing manual cuts; the user still reviews the start,
  /// end and circulation on every level. This never creates a physical cut.
  static StructuralProject adoptExisting(
    StructuralProject project,
    double scale,
  ) {
    if (project.staircases.isNotEmpty) return project;
    final floors = project.storeys.toList()
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    final groups = <List<StaircaseOpeningOwner>>[];
    for (final floor in floors.skip(1)) {
      for (final ref in physicalOpenings(project, floor, scale)) {
        List<StaircaseOpeningOwner>? group;
        for (final candidate in groups) {
          if (candidate.any((r) => r.arrivalStoreyId == floor.id)) continue;
          final contact = SlabContactGeometry.measure(polygon(project, ref), [
            StructuralSlab(
              id: 'stair',
              polygon: polygon(project, candidate.last),
            ),
          ], scale);
          if (contact != null && contact.areaM2 > .05) {
            group = candidate;
            break;
          }
        }
        if (group == null) {
          group = [];
          groups.add(group);
        }
        group.add(ref);
      }
    }
    if (groups.isEmpty) return project;
    final cores = <StaircaseCore>[];
    for (final group in groups) {
      final first = floors.indexWhere(
        (s) => s.id == group.first.arrivalStoreyId,
      );
      final id =
          'manual_stair_${group.first.ownerStoreyId}_${group.first.slabId}_${group.first.openingIndex}';
      cores.add(
        StaircaseCore(
          id: id,
          name: '${cores.length + 1}',
          startStoreyId: floors[first - 1].id,
          endStoreyId: group.last.arrivalStoreyId,
        ),
      );
    }
    return project.copyWith(staircases: cores, staircaseReviewComplete: false);
  }

  static StaircaseInventory evaluate(
    StructuralProject project,
    double scale, {
    bool requireReview = false,
  }) {
    if (!requireReview &&
        !project.staircaseReviewComplete &&
        project.staircases.isEmpty) {
      return const StaircaseInventory(
        [],
        [],
      ); // Legacy standalone compatibility.
    }
    if (project.staircases.isEmpty) {
      final adopted = adoptExisting(project, scale);
      if (!identical(adopted, project)) {
        return evaluate(adopted, scale, requireReview: requireReview);
      }
    }
    final gaps = <StaircaseGap>[];
    final refs = <StaircaseOpeningOwner>[];
    if (!project.staircaseReviewComplete) {
      gaps.add(const StaircaseGap(StaircaseRequirement.review));
    }
    final ids = <String>{};
    final used = <String>{};
    for (final core in project.staircases) {
      final floors = levels(project, core);
      if (!ids.add(core.id) ||
          floors.length < 2 ||
          floors.map((s) => s.id).toSet().length != floors.length ||
          floors.map((s) => s.elevation).toSet().length != floors.length) {
        gaps.add(StaircaseGap(StaircaseRequirement.scope, coreId: core.id));
        continue;
      }
      for (var level = 0; level < floors.length; level++) {
        final floor = floors[level];
        final zone = floor.staircaseZones[core.id] ?? const <Offset>[];
        if (!validZone(zone, scale)) {
          gaps.add(
            StaircaseGap(
              StaircaseRequirement.circulation,
              coreId: core.id,
              storeyId: floor.id,
            ),
          );
        }
        final reserved = floor.copyWith(
          staircaseZones: {if (validZone(zone, scale)) core.id: zone},
        );
        if (floor.columns.any(
              (c) => !SupportPlacementRules.circulationFits(
                SupportPlacementRules.columnFootprint(c),
                reserved,
                scale,
              ),
            ) ||
            floor.shearWalls.any(
              (w) => !SupportPlacementRules.circulationFits(
                w.polygonVertices,
                reserved,
                scale,
              ),
            )) {
          gaps.add(
            StaircaseGap(
              StaircaseRequirement.support,
              coreId: core.id,
              storeyId: floor.id,
            ),
          );
        }
        if (level == 0) {
          continue;
        } // A solid starting floor is allowed.
        final candidates = physicalOpenings(project, floor, scale)
            .where(
              (ref) => !used.contains(
                '${ref.ownerStoreyId}/${ref.slabId}/${ref.openingIndex}',
              ),
            )
            .toList();
        StaircaseOpeningOwner? match;
        final manualEvidence =
            [
              for (final other in floors)
                ...physicalOpenings(project, other, scale),
            ].where(
              (ref) =>
                  core.id ==
                  'manual_stair_${ref.ownerStoreyId}_${ref.slabId}_${ref.openingIndex}',
            );
        final anchors = [
          for (final ref in manualEvidence) polygon(project, ref),
          if (validZone(zone, scale)) zone,
          for (final other in floors)
            if (validZone(other.staircaseZones[core.id] ?? [], scale))
              other.staircaseZones[core.id]!,
        ];
        for (final ref in candidates) {
          final hole = polygon(project, ref);
          final overlap = anchors.any((anchor) {
            final contact = SlabContactGeometry.measure(hole, [
              StructuralSlab(id: 'zone', polygon: anchor),
            ], scale);
            return contact != null && contact.areaM2 > .05;
          });
          if (overlap ||
              (anchors.isEmpty &&
                  project.staircases.length == 1 &&
                  candidates.length == 1)) {
            match = StaircaseOpeningOwner(
              core.id,
              floor.id,
              ref.ownerStoreyId,
              ref.slabId,
              ref.openingIndex,
            );
            if (validZone(zone, scale)) {
              final area = StructuralSlab.calculateArea(hole) / (scale * scale);
              final contact = SlabContactGeometry.measure(hole, [
                StructuralSlab(id: 'zone', polygon: zone),
              ], scale);
              if (contact == null ||
                  (contact.areaM2 - area).abs() > area * 1e-7) {
                gaps.add(
                  StaircaseGap(
                    StaircaseRequirement.circulation,
                    coreId: core.id,
                    storeyId: floor.id,
                  ),
                );
              }
            }
            break;
          }
        }
        if (match == null) {
          gaps.add(
            StaircaseGap(
              StaircaseRequirement.opening,
              coreId: core.id,
              storeyId: floor.id,
            ),
          );
        } else {
          refs.add(match);
          used.add(
            '${match.ownerStoreyId}/${match.slabId}/${match.openingIndex}',
          );
        }
      }
    }
    return StaircaseInventory(List.unmodifiable(gaps), List.unmodifiable(refs));
  }
}
