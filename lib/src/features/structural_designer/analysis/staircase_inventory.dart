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
          if (level > 0) {
            gaps.add(
              StaircaseGap(
                StaircaseRequirement.opening,
                coreId: core.id,
                storeyId: floor.id,
              ),
            );
          }
          continue;
        }
        final reserved = floor.copyWith(staircaseZones: {core.id: zone});
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
        final legacy = project.floorSlabStoreyFor(floor);
        final owners = <StoreyLevel>[
          floor.copyWith(
            slabs: floor.slabs.where((s) => s.isFloorSlab).toList(),
          ),
          ?legacy,
        ];
        StaircaseOpeningOwner? match;
        for (final owner in owners) {
          for (final slab in owner.slabs) {
            final finishedLevel =
                owner.structuralElevationFor(slab) +
                (slab.floorFinish ?? owner.floorFinishThickness);
            if (!finishedLevel.isFinite ||
                (finishedLevel - floor.elevation).abs() > .01) {
              continue;
            }
            if (SlabTopologyAnalyzer.analyze([slab], scale).issue !=
                SlabTopologyIssue.none) {
              continue;
            }
            for (var i = 0; i < slab.openings.length; i++) {
              final key = '${owner.id}/${slab.id}/$i';
              if (slab.getOpeningType(i) != SlabOpeningType.staircase ||
                  used.contains(key)) {
                continue;
              }
              final opening = slab.openings[i];
              final area =
                  StructuralSlab.calculateArea(opening) / (scale * scale);
              final contact = SlabContactGeometry.measure(opening, [
                StructuralSlab(id: 'zone', polygon: zone),
              ], scale);
              if (contact != null &&
                  area > 1e-10 &&
                  (contact.areaM2 - area).abs() <= area * 1e-7) {
                match = StaircaseOpeningOwner(
                  core.id,
                  floor.id,
                  owner.id,
                  slab.id,
                  i,
                );
                break;
              }
            }
            if (match != null) break;
          }
          if (match != null) break;
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
