import '../models/architect_project.dart';
import '../models/architect_column.dart';
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
            for (final original in floor.roofs)
              (() {
                var roof = original;
                roof.assembly.panels?.validate(
                  slope: roof.slopeDegrees,
                  mansard: roof.isMansard,
                );
                final previousRoof = old[roof.id];
                if (roof.assembly.panels != null &&
                    previousRoof?.assembly.panels == null &&
                    roof.assembly.panels!.columnIds.isEmpty &&
                    !roof.placementResolved) {
                  final support = ArchitectRoofGeometry.supportingSteelStorey(
                    next,
                    floor,
                  );
                  final ids = <String>[
                    for (final c
                        in support?.columns ?? const <ArchitectColumn>[])
                      if (roof.bounds.inflate(.3).contains(c.position)) c.id,
                  ];
                  if (ids.isNotEmpty) {
                    roof = roof.copyWith(
                      assembly: ArchitectRoofAssembly.panelRoof(
                        roof.assembly.panels!.copyWith(columnIds: ids),
                      ),
                    );
                    changed = true;
                  }
                }
                final panelSupportChanged =
                    roof.assembly.panels != null &&
                    previous != null &&
                    (previousRoof?.assembly.panels == null ||
                        previousRoof!.assembly.panels!.columnIds.length !=
                            roof.assembly.panels!.columnIds.length ||
                        !previousRoof.assembly.panels!.columnIds
                            .toSet()
                            .containsAll(roof.assembly.panels!.columnIds) ||
                        roof.assembly.panels!.columnIds.any((id) {
                          final a = next.storeys
                              .expand((f) => f.columns)
                              .where((c) => c.id == id)
                              .firstOrNull;
                          final b = previous.storeys
                              .expand((f) => f.columns)
                              .where((c) => c.id == id)
                              .firstOrNull;
                          final af = next.storeys
                              .where((f) => f.columns.any((c) => c.id == id))
                              .firstOrNull;
                          final bf = previous.storeys
                              .where((f) => f.columns.any((c) => c.id == id))
                              .firstOrNull;
                          return a?.position != b?.position ||
                              af?.elevation != bf?.elevation ||
                              (a?.height == null && af?.height != bf?.height) ||
                              a?.height != b?.height ||
                              a?.baseOffset != b?.baseOffset;
                        }));
                final reattach =
                    old.containsKey(roof.id) &&
                    !old[roof.id]!.attachToWalls &&
                    roof.attachToWalls;
                if (!roof.attachToWalls ||
                    (!reattach &&
                        !panelSupportChanged &&
                        (roof.placementResolved || old.containsKey(roof.id)))) {
                  return roof;
                }
                final height =
                    ArchitectRoofGeometry.resolveAttachedBaseElevationOffset(
                      project: next,
                      roof: roof,
                      storey: floor,
                      lowerStorey: roof.assembly.panels != null
                          ? ArchitectRoofGeometry.supportingSteelStorey(
                              next,
                              floor,
                            )
                          : ArchitectRoofGeometry.supportingWallStorey(
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
