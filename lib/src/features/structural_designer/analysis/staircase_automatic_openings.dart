import 'dart:ui';
import '../../bim_projects/services/bim_underlay_conversion_service.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/structural_element.dart';
import '../services/slab_opening_placement.dart';
import 'slab_contact_geometry.dart';
import 'staircase_assemblies.dart';
import 'staircase_geometry_detector.dart';
import 'staircase_inventory.dart';
import 'staircase_opening_contours.dart';
import 'structural_underlay_source.dart';

class DetectedStairOpening {
  final String storeyId;
  final List<Offset> circulation;
  final List<List<Offset>> contours;
  const DetectedStairOpening(this.storeyId, this.circulation, this.contours);
}

class AutomaticStairCuts {
  final StructuralProject project;
  final int added;
  const AutomaticStairCuts(this.project, this.added);
}

/// One operation over the arrival plans. Never cuts the first floor, projects
/// a lower-floor cut into a roof, or substitutes a tread hull for a CAD contour.
class StaircaseAutomaticOpenings {
  static List<DetectedStairOpening> detect(
    StructuralProject project,
    Map<String, DxfDocument> documents,
    double scale,
  ) {
    if (!scale.isFinite || scale <= 0) return [];
    final floors = project.storeys.toList()
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    final geometry = <String, StairGeometryResult>{};
    for (final floor in floors) {
      final doc = documents[floor.id];
      if (doc != null) {
        geometry[floor.id] = StaircaseGeometryDetector.detect(
          StructuralUnderlaySource.original(
            doc,
            metadata: BimUnderlayMetadata.read(doc),
          ),
          scale,
        );
      }
    }
    final result = <DetectedStairOpening>[];
    for (var i = 1; i < floors.length; i++) {
      final floor = floors[i], current = geometry[floor.id];
      if (current == null || current.limited) continue;
      final lower = geometry[floors[i - 1].id];
      final flights = [
        ...current.flights,
        if (lower != null && !lower.limited) ...lower.flights,
      ];
      final evidence = StairGeometryResult(
        flights,
        current.strokes,
        boundaryStrokes: current.boundaryStrokes,
      );
      for (final family in StaircaseAssembly.group(flights, scale)) {
        final contours = StaircaseOpeningContours.findAssembly(
          evidence,
          family.flights,
          scale,
        );
        // A lower flight is location evidence only: an actual contour is needed
        // on the arrival plan. Absence does not mean a roof must have a hole.
        final ownEvidence = family.flights.any(current.flights.contains);
        if (!ownEvidence && contours.isEmpty) continue;
        final area =
            StructuralSlab.calculateArea(family.circulation) / (scale * scale);
        double score(List<Offset> contour) {
          final contact = SlabContactGeometry.measure(contour, [
            StructuralSlab(id: 'stairs', polygon: family.circulation),
          ], scale);
          final cutArea =
              StructuralSlab.calculateArea(contour) / (scale * scale);
          return area > 0
              ? (contact?.areaM2 ?? 0) / area - (cutArea / area - 1).abs() * .1
              : 0;
        }

        contours.sort((a, b) => score(b).compareTo(score(a)));
        result.add(
          DetectedStairOpening(floor.id, family.circulation, contours),
        );
      }
    }
    return result;
  }

  static bool _matches(
    StructuralProject project,
    StaircaseOpeningOwner ref,
    DetectedStairOpening target,
    double scale,
  ) {
    final contact = SlabContactGeometry.measure(
      StaircaseInventory.polygon(project, ref),
      [StructuralSlab(id: 'stairs', polygon: target.circulation)],
      scale,
    );
    return contact != null && contact.areaM2 > .05;
  }

  static Set<String> missing(
    StructuralProject project,
    List<DetectedStairOpening> targets,
    double scale,
  ) {
    final missing = {
      for (final g in StaircaseInventory.evaluateOpenings(project, scale).gaps)
        g.storeyId!,
    };
    final used = <String>{};
    for (final target in targets) {
      final floor = project.storeys.firstWhere((s) => s.id == target.storeyId);
      final refs = StaircaseInventory.physicalOpenings(project, floor, scale);
      final found = refs
          .where(
            (r) =>
                !used.contains(
                  '${r.ownerStoreyId}/${r.slabId}/${r.openingIndex}',
                ) &&
                _matches(project, r, target, scale),
          )
          .firstOrNull;
      if (found == null) {
        missing.add(floor.id);
      } else {
        used.add(
          '${found.ownerStoreyId}/${found.slabId}/${found.openingIndex}',
        );
      }
    }
    return missing;
  }

  static AutomaticStairCuts apply(
    StructuralProject project,
    List<DetectedStairOpening> targets,
    double scale, {
    Set<String>? storeyIds,
  }) {
    var updated = project, added = 0;
    if (!scale.isFinite || scale <= 0 || project.storeys.isEmpty) {
      return AutomaticStairCuts(project, 0);
    }
    final first = project.storeys.reduce(
      (a, b) => a.elevation < b.elevation ? a : b,
    );
    for (final target in targets) {
      if (target.storeyId == first.id ||
          (storeyIds != null && !storeyIds.contains(target.storeyId))) {
        continue;
      }
      final floor = updated.storeys.firstWhere((s) => s.id == target.storeyId);
      if (StaircaseInventory.physicalOpenings(
        updated,
        floor,
        scale,
      ).any((r) => _matches(updated, r, target, scale))) {
        continue;
      }
      final legacy = updated.floorSlabStoreyFor(floor);
      final owners = [
        floor.copyWith(slabs: floor.slabs.where((s) => s.isFloorSlab).toList()),
        ?legacy,
      ];
      var accepted = false;
      for (final contour in target.contours) {
        for (final owner in owners) {
          final eligible = owner.slabs
              .where(
                (slab) =>
                    (owner.structuralElevationFor(slab) +
                            (slab.floorFinish ?? owner.floorFinishThickness) -
                            floor.elevation)
                        .abs() <=
                    .01,
              )
              .toList();
          final placement = SlabOpeningPlacement.apply(
            slabs: eligible,
            polygon: contour,
            scale: scale,
            type: SlabOpeningType.staircase,
          );
          if (!placement.accepted) continue;
          final replacements = {
            for (final slab in placement.slabs!) slab.id: slab,
          };
          updated = updated.copyWith(
            storeys: [
              for (final s in updated.storeys)
                s.id == owner.id
                    ? s.copyWith(
                        slabs: [
                          for (final slab in s.slabs)
                            replacements[slab.id] ?? slab,
                        ],
                      )
                    : s,
            ],
          );
          added++;
          accepted = true;
          break;
        }
        if (accepted) break;
      }
    }
    return AutomaticStairCuts(updated, added);
  }
}
