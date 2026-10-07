import 'dart:ui';
import '../analysis/slab_topology_analyzer.dart';
import '../models/slab_topology.dart';
import '../models/structural_element.dart';

enum OpeningPlacementIssue {
  none,
  missingSlab,
  invalidGeometry,
  ambiguousOwner,
  missingOpening,
}

class OpeningPlacementResult {
  final OpeningPlacementIssue issue;
  final List<StructuralSlab>? slabs;
  final (String, int)? opening;
  const OpeningPlacementResult(this.issue, {this.slabs, this.opening});
  bool get accepted => issue == OpeningPlacementIssue.none;
}

/// The slab owns its cutouts. Only a whole, strictly contained contour may be
/// attached; no centroid fallback and no implicit cross-storey reassignment.
class SlabOpeningPlacement {
  static OpeningPlacementResult apply({
    required List<StructuralSlab> slabs,
    required List<Offset> polygon,
    required double scale,
    SlabOpeningType type = SlabOpeningType.shaft,
    (String, int)? replacing,
    bool allowTransfer = true,
  }) {
    if (slabs.isEmpty) {
      return const OpeningPlacementResult(OpeningPlacementIssue.missingSlab);
    }
    if (slabs.map((s) => s.id).toSet().length != slabs.length) {
      return const OpeningPlacementResult(OpeningPlacementIssue.ambiguousOwner);
    }
    final updated = List<StructuralSlab>.of(slabs);
    var oldIndex = -1;
    if (replacing != null) {
      oldIndex = slabs.indexWhere((s) => s.id == replacing.$1);
      if (oldIndex < 0 ||
          replacing.$2 < 0 ||
          replacing.$2 >= slabs[oldIndex].openings.length) {
        return const OpeningPlacementResult(
          OpeningPlacementIssue.missingOpening,
        );
      }
      type = slabs[oldIndex].getOpeningType(replacing.$2);
      updated[oldIndex] = slabs[oldIndex].removeOpening(replacing.$2);
    }
    final owners = <int>[];
    for (var i = 0; i < slabs.length; i++) {
      // Ignore existing holes only while resolving the outer-ring owner.
      final probe = slabs[i].copyWith(openings: [polygon]);
      if (SlabTopologyAnalyzer.analyze([probe], scale).issue ==
          SlabTopologyIssue.none) {
        owners.add(i);
      }
    }
    if (owners.length > 1) {
      return const OpeningPlacementResult(OpeningPlacementIssue.ambiguousOwner);
    }
    if (owners.isEmpty || (!allowTransfer && owners.single != oldIndex)) {
      return const OpeningPlacementResult(
        OpeningPlacementIssue.invalidGeometry,
      );
    }
    final target = owners.single;
    late final int openingIndex;
    if (target == oldIndex && replacing != null) {
      // Preserve index and typed metadata on an in-place edit.
      updated[target] = slabs[target].updateOpening(
        replacing.$2,
        polygon,
        type: type,
      );
      openingIndex = replacing.$2;
    } else {
      openingIndex = updated[target].openings.length;
      updated[target] = updated[target].addOpening(polygon, type: type);
    }
    if (SlabTopologyAnalyzer.analyze([updated[target]], scale).issue !=
        SlabTopologyIssue.none) {
      return const OpeningPlacementResult(
        OpeningPlacementIssue.invalidGeometry,
      );
    }
    return OpeningPlacementResult(
      OpeningPlacementIssue.none,
      slabs: List.unmodifiable(updated),
      opening: (updated[target].id, openingIndex),
    );
  }
}
