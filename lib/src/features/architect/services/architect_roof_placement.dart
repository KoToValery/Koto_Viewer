import '../models/architect_project.dart';
import 'architect_roof_geometry.dart';

/// Wall attachment is a model placement operation, never a renderer override.
class ArchitectRoofPlacement {
  static ArchitectProject resolve(
    ArchitectProject next, {
    ArchitectProject? previous,
  }) {
    final old = {
      for (final s in previous?.storeys ?? <ArchitectStorey>[])
        for (final r in s.roofs) r.id: r,
    };
    final sorted = [...next.storeys]
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    var changed = false;
    final floors = [
      for (final floor in next.storeys)
        floor.copyWith(
          roofs: [
            for (final roof in floor.roofs)
              (() {
                final reattach =
                    old.containsKey(roof.id) &&
                    !old[roof.id]!.attachToWalls &&
                    roof.attachToWalls;
                if (!roof.attachToWalls ||
                    (!reattach &&
                        (roof.placementResolved || old.containsKey(roof.id)))) {
                  return roof;
                }
                final index = sorted.indexWhere((s) => s.id == floor.id);
                final height =
                    ArchitectRoofGeometry.resolveAttachedBaseElevationOffset(
                      roof: roof,
                      storey: floor,
                      lowerStorey: index > 0 ? sorted[index - 1] : null,
                    );
                changed = true;
                return roof.copyWith(
                  baseElevationOffset: height,
                  placementResolved: true,
                );
              })(),
          ],
        ),
    ];
    return changed ? next.copyWith(storeys: floors) : next;
  }
}
