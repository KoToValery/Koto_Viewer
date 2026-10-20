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
                final height =
                    ArchitectRoofGeometry.resolveAttachedBaseElevationOffset(
                      roof: roof,
                      storey: floor,
                      lowerStorey: ArchitectRoofGeometry.supportingWallStorey(
                        next,
                        floor,
                      ),
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
