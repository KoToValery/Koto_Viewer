// === SECTION: ARCHITECT STOREY COPY SERVICE ===
// Table of Contents:
// 1. SERVICE ENTRY POINT (copyElements)
// 2. ELEMENT CLONING ENGINE (Walls, Openings, Columns, Slabs, Zones, Stairs, Dimensions, etc.)
// 3. GROUP & LAYER TRANSFER (Groups, ElementLayers, Document Overrides)
// 4. STOREY ASSEMBLY (Merge vs Replace composition)

import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_floor_drain.dart';
import '../models/architect_zone.dart';
import '../models/architect_storey_copy_types.dart';
import 'architect_element_id.dart';

/// Pure logic engine for copying architectural layouts and elements across storeys.
class ArchitectStoreyCopyService {
  const ArchitectStoreyCopyService._();

  /// Executes copying according to the provided [options].
  /// Returns the updated [ArchitectProject] and a [StoreyCopyResult] summary.
  static (ArchitectProject, StoreyCopyResult) copyElements(
    ArchitectProject project,
    StoreyCopyOptions options,
  ) {
    if (options.targetStoreyIds.isEmpty || options.elementTypes.isEmpty) {
      return (project, StoreyCopyResult.empty);
    }

    final sourceStorey = project.storeys
        .where((s) => s.id == options.sourceStoreyId)
        .firstOrNull;
    if (sourceStorey == null) {
      return (project, StoreyCopyResult.empty);
    }

    final selectedFilter = options.selectedElementIds;
    bool shouldInclude(String id) =>
        selectedFilter == null || selectedFilter.contains(id);

    final knownStoreyIds = project.storeys.map((storey) => storey.id).toSet();
    final additionalStoreys = [
      for (final storey in options.additionalStoreys)
        if (knownStoreyIds.add(storey.id)) storey,
    ];
    // A cancelled dialog never calls this service; an invalid copy must not
    // publish the levels staged inside it either.
    if (additionalStoreys.isNotEmpty &&
        !options.elementTypes.any(
          (type) =>
              type.countInStorey(sourceStorey, filterIds: selectedFilter) > 0,
        )) {
      return (project, StoreyCopyResult.empty);
    }
    final currentProject = additionalStoreys.isEmpty
        ? project
        : project
              .copyWith(
                storeys: [
                  ...project.storeys.where((storey) => !storey.isRoof),
                  ...additionalStoreys,
                  ...project.storeys.where((storey) => storey.isRoof),
                ],
              )
              .syncRoofElevation();
    final targetStoreyIds = currentProject.storeys
        .where(
          (storey) =>
              storey.id != sourceStorey.id &&
              options.targetStoreyIds.contains(storey.id),
        )
        .map((storey) => storey.id)
        .toSet();
    if (targetStoreyIds.isEmpty) {
      return (project, StoreyCopyResult.empty);
    }
    var updatedElementLayers = Map<String, String>.of(project.elementLayers);
    var updatedDocument = project.document;

    final breakdown = <ArchitectStoreyElementType, int>{};
    var totalCopiedAcrossAllTargets = 0;

    final updatedStoreys = <ArchitectStorey>[];

    for (final storey in currentProject.storeys) {
      if (!targetStoreyIds.contains(storey.id)) {
        updatedStoreys.add(storey);
        continue;
      }

      final targetStorey = storey;
      final deltaElev = targetStorey.elevation - sourceStorey.elevation;
      final idMap = <String, String>{};

      // 1. Walls (including doors and windows)
      final clonedWalls = <ArchitectWall>[];
      if (options.elementTypes.contains(ArchitectStoreyElementType.walls)) {
        for (final wall in sourceStorey.walls) {
          if (!shouldInclude(wall.id)) continue;
          final newWallId = ArchitectElementId.next('wall');
          idMap[wall.id] = newWallId;

          final wallHeight =
              options.adjustWallHeights && wall.followStoreyHeight
              ? wall.effectiveHeight(targetStorey.height)
              : wall.height;

          final clonedDoors = wall.doors.map((door) {
            final newDoorId = ArchitectElementId.next('door');
            idMap[door.id] = newDoorId;
            return door.copyWith(
              id: newDoorId,
              wallId: newWallId,
              uuid: ArchitectElementId.next('UUID'),
            );
          }).toList();

          final clonedWindows = wall.windows.map((window) {
            final newWinId = ArchitectElementId.next('window');
            idMap[window.id] = newWinId;
            return window.copyWith(
              id: newWinId,
              wallId: newWallId,
              uuid: ArchitectElementId.next('UUID'),
            );
          }).toList();

          clonedWalls.add(
            wall.copyWith(
              id: newWallId,
              height: wallHeight,
              doors: clonedDoors,
              windows: clonedWindows,
            ),
          );
        }
        breakdown[ArchitectStoreyElementType.walls] =
            (breakdown[ArchitectStoreyElementType.walls] ?? 0) +
            clonedWalls.length;
      }

      // 2. Columns
      final clonedColumns = <ArchitectColumn>[];
      if (options.elementTypes.contains(ArchitectStoreyElementType.columns)) {
        for (final col in sourceStorey.columns) {
          if (!shouldInclude(col.id)) continue;
          final newColId = ArchitectElementId.next('col');
          idMap[col.id] = newColId;

          final colHeight =
              options.adjustWallHeights &&
                  ((col.height ?? sourceStorey.height) - sourceStorey.height)
                          .abs() <
                      0.05
              ? targetStorey.height
              : col.height;

          clonedColumns.add(col.copyWith(id: newColId, height: colHeight));
        }
        breakdown[ArchitectStoreyElementType.columns] =
            (breakdown[ArchitectStoreyElementType.columns] ?? 0) +
            clonedColumns.length;
      }

      // 3. Beams
      final clonedBeams = <ArchitectBeam>[];
      if (options.elementTypes.contains(ArchitectStoreyElementType.beams)) {
        for (final beam in sourceStorey.beams) {
          if (!shouldInclude(beam.id)) continue;
          final newBeamId = ArchitectElementId.next('beam');
          idMap[beam.id] = newBeamId;
          clonedBeams.add(beam.copyWith(id: newBeamId));
        }
        breakdown[ArchitectStoreyElementType.beams] =
            (breakdown[ArchitectStoreyElementType.beams] ?? 0) +
            clonedBeams.length;
      }

      // 4. Slabs
      final clonedSlabs = <ArchitectSlab>[];
      if (options.elementTypes.contains(ArchitectStoreyElementType.slabs)) {
        for (final slab in sourceStorey.slabs) {
          if (!shouldInclude(slab.id)) continue;
          final newSlabId = ArchitectElementId.next('slab');
          idMap[slab.id] = newSlabId;
          clonedSlabs.add(slab.copyWith(id: newSlabId));
        }
        breakdown[ArchitectStoreyElementType.slabs] =
            (breakdown[ArchitectStoreyElementType.slabs] ?? 0) +
            clonedSlabs.length;
      }

      // 5. Zones (Rooms & Apartments)
      final clonedZones = <ArchitectZone>[];
      if (options.elementTypes.contains(ArchitectStoreyElementType.zones)) {
        for (final zone in sourceStorey.zones) {
          if (!shouldInclude(zone.id)) continue;
          final newZoneId = ArchitectElementId.next('zone');
          idMap[zone.id] = newZoneId;
          clonedZones.add(zone.copyWith(id: newZoneId));
        }
        breakdown[ArchitectStoreyElementType.zones] =
            (breakdown[ArchitectStoreyElementType.zones] ?? 0) +
            clonedZones.length;
      }

      // 6. Stairs
      final clonedStairs = <ArchitectStair>[];
      if (options.elementTypes.contains(ArchitectStoreyElementType.stairs)) {
        for (final stair in sourceStorey.stairs) {
          if (!shouldInclude(stair.id)) continue;
          final newStairId = ArchitectElementId.next('stair');
          idMap[stair.id] = newStairId;

          clonedStairs.add(stair.copyWith(id: newStairId));
        }
        breakdown[ArchitectStoreyElementType.stairs] =
            (breakdown[ArchitectStoreyElementType.stairs] ?? 0) +
            clonedStairs.length;
      }

      // 7. Slab Openings / Shafts
      final clonedOpenings = <ArchitectOpening>[];
      if (options.elementTypes.contains(ArchitectStoreyElementType.openings)) {
        for (final op in sourceStorey.openings) {
          if (!shouldInclude(op.id)) continue;
          final newOpId = ArchitectElementId.next('opening');
          idMap[op.id] = newOpId;
          clonedOpenings.add(op.copyWith(id: newOpId));
        }
        breakdown[ArchitectStoreyElementType.openings] =
            (breakdown[ArchitectStoreyElementType.openings] ?? 0) +
            clonedOpenings.length;
      }

      // 8. Dimensions
      final clonedDimensions = <ArchitectDimension>[];
      if (options.elementTypes.contains(
        ArchitectStoreyElementType.dimensions,
      )) {
        for (final dim in sourceStorey.dimensions) {
          if (!shouldInclude(dim.id)) continue;
          final newDimId = ArchitectElementId.next('dim');
          idMap[dim.id] = newDimId;
          clonedDimensions.add(dim.copyWith(id: newDimId));
        }
        breakdown[ArchitectStoreyElementType.dimensions] =
            (breakdown[ArchitectStoreyElementType.dimensions] ?? 0) +
            clonedDimensions.length;
      }

      // 9. Elevation Markers
      final clonedMarkers = <ArchitectElevationMarker>[];
      if (options.elementTypes.contains(
        ArchitectStoreyElementType.elevationMarkers,
      )) {
        for (final marker in sourceStorey.elevationMarkers) {
          if (!shouldInclude(marker.id)) continue;
          final newMarkerId = ArchitectElementId.next('elev');
          idMap[marker.id] = newMarkerId;

          final shiftedElevation = options.adjustLevelMarkers
              ? marker.elevation + deltaElev
              : marker.elevation;

          clonedMarkers.add(
            marker.copyWith(id: newMarkerId, elevation: shiftedElevation),
          );
        }
        breakdown[ArchitectStoreyElementType.elevationMarkers] =
            (breakdown[ArchitectStoreyElementType.elevationMarkers] ?? 0) +
            clonedMarkers.length;
      }

      // 10. Annotations
      final clonedAnnotations = <ArchitectAnnotation>[];
      if (options.elementTypes.contains(
        ArchitectStoreyElementType.annotations,
      )) {
        for (final ann in sourceStorey.annotations) {
          if (!shouldInclude(ann.id)) continue;
          final newAnnId = ArchitectElementId.next('ann');
          idMap[ann.id] = newAnnId;
          clonedAnnotations.add(ann.copyWith(id: newAnnId));
        }
        breakdown[ArchitectStoreyElementType.annotations] =
            (breakdown[ArchitectStoreyElementType.annotations] ?? 0) +
            clonedAnnotations.length;
      }

      // 11. CAD Primitives
      final clonedCadPrimitives = <ArchitectCadPrimitive>[];
      if (options.elementTypes.contains(
        ArchitectStoreyElementType.cadPrimitives,
      )) {
        for (final prim in sourceStorey.cadPrimitives) {
          if (!shouldInclude(prim.id)) continue;
          final newCadId = ArchitectElementId.next('cad');
          idMap[prim.id] = newCadId;
          clonedCadPrimitives.add(prim.copyWith(id: newCadId));
        }
        breakdown[ArchitectStoreyElementType.cadPrimitives] =
            (breakdown[ArchitectStoreyElementType.cadPrimitives] ?? 0) +
            clonedCadPrimitives.length;
      }

      // 12. Components (Furniture, fixtures)
      final clonedComponents = <ArchitectComponentInstance>[];
      if (options.elementTypes.contains(
        ArchitectStoreyElementType.components,
      )) {
        for (final comp in sourceStorey.components) {
          if (!shouldInclude(comp.id)) continue;
          final newCompId = ArchitectElementId.next('comp');
          idMap[comp.id] = newCompId;
          clonedComponents.add(comp.copyWith(id: newCompId));
        }
        breakdown[ArchitectStoreyElementType.components] =
            (breakdown[ArchitectStoreyElementType.components] ?? 0) +
            clonedComponents.length;
      }

      // 13. Floor Drains
      final clonedFloorDrains = <ArchitectFloorDrain>[];
      if (options.elementTypes.contains(
        ArchitectStoreyElementType.floorDrains,
      )) {
        for (final drain in sourceStorey.floorDrains) {
          if (!shouldInclude(drain.id)) continue;
          final newDrainId = ArchitectElementId.next('drain');
          idMap[drain.id] = newDrainId;
          clonedFloorDrains.add(drain.copyWith(id: newDrainId));
        }
        breakdown[ArchitectStoreyElementType.floorDrains] =
            (breakdown[ArchitectStoreyElementType.floorDrains] ?? 0) +
            clonedFloorDrains.length;
      }

      // 14. Decorative Elements
      final clonedDecorative = <ArchitectDecorativeElement>[];
      if (options.elementTypes.contains(
        ArchitectStoreyElementType.decorativeElements,
      )) {
        for (final decor in sourceStorey.decorativeElements) {
          if (!shouldInclude(decor.id)) continue;
          final newDecorId = ArchitectElementId.next('decor');
          idMap[decor.id] = newDecorId;
          clonedDecorative.add(decor.copyWith(id: newDecorId));
        }
        breakdown[ArchitectStoreyElementType.decorativeElements] =
            (breakdown[ArchitectStoreyElementType.decorativeElements] ?? 0) +
            clonedDecorative.length;
      }

      // 15. Roofs
      final clonedRoofs = <ArchitectRoofPlane>[];
      if (options.elementTypes.contains(ArchitectStoreyElementType.roofs)) {
        for (final roof in sourceStorey.roofs) {
          if (!shouldInclude(roof.id)) continue;
          final newRoofId = ArchitectElementId.next('roof');
          idMap[roof.id] = newRoofId;
          clonedRoofs.add(roof.copyWith(id: newRoofId));
        }
        breakdown[ArchitectStoreyElementType.roofs] =
            (breakdown[ArchitectStoreyElementType.roofs] ?? 0) +
            clonedRoofs.length;
      }

      // Element Groups Remapping
      final clonedGroups = <ArchitectElementGroup>[];
      if (options.preserveGroups) {
        for (final group in sourceStorey.groups) {
          final mappedMembers = group.elementIds
              .map((id) => idMap[id])
              .whereType<String>()
              .toSet();
          if (mappedMembers.length >= 2) {
            clonedGroups.add(
              ArchitectElementGroup(
                id: ArchitectElementId.next('group'),
                elementIds: mappedMembers,
              ),
            );
          }
        }
      }

      // Element Layers Remapping
      for (final entry in idMap.entries) {
        final existingLayer = project.elementLayers[entry.key];
        if (existingLayer != null) {
          updatedElementLayers[entry.value] = existingLayer;
        }
      }

      // Document Overrides Remapping
      updatedDocument = updatedDocument.copyElementOverrides(idMap);

      final totalOnThisTarget =
          clonedWalls.length +
          clonedColumns.length +
          clonedBeams.length +
          clonedSlabs.length +
          clonedZones.length +
          clonedStairs.length +
          clonedOpenings.length +
          clonedDimensions.length +
          clonedMarkers.length +
          clonedAnnotations.length +
          clonedCadPrimitives.length +
          clonedComponents.length +
          clonedFloorDrains.length +
          clonedDecorative.length +
          clonedRoofs.length;

      totalCopiedAcrossAllTargets += totalOnThisTarget;

      // Assemble next target storey according to mode (replace vs merge)
      final isReplace = options.mode == StoreyCopyMode.replace;
      bool isTypeSelected(ArchitectStoreyElementType t) =>
          options.elementTypes.contains(t);

      final nextWalls = isTypeSelected(ArchitectStoreyElementType.walls)
          ? (isReplace ? clonedWalls : [...targetStorey.walls, ...clonedWalls])
          : targetStorey.walls;

      final nextColumns = isTypeSelected(ArchitectStoreyElementType.columns)
          ? (isReplace
                ? clonedColumns
                : [...targetStorey.columns, ...clonedColumns])
          : targetStorey.columns;

      final nextBeams = isTypeSelected(ArchitectStoreyElementType.beams)
          ? (isReplace ? clonedBeams : [...targetStorey.beams, ...clonedBeams])
          : targetStorey.beams;

      final nextSlabs = isTypeSelected(ArchitectStoreyElementType.slabs)
          ? (isReplace ? clonedSlabs : [...targetStorey.slabs, ...clonedSlabs])
          : targetStorey.slabs;

      final nextZones = isTypeSelected(ArchitectStoreyElementType.zones)
          ? (isReplace ? clonedZones : [...targetStorey.zones, ...clonedZones])
          : targetStorey.zones;

      final nextStairs = isTypeSelected(ArchitectStoreyElementType.stairs)
          ? (isReplace
                ? clonedStairs
                : [...targetStorey.stairs, ...clonedStairs])
          : targetStorey.stairs;

      final nextOpenings = isTypeSelected(ArchitectStoreyElementType.openings)
          ? (isReplace
                ? clonedOpenings
                : [...targetStorey.openings, ...clonedOpenings])
          : targetStorey.openings;

      final nextDimensions =
          isTypeSelected(ArchitectStoreyElementType.dimensions)
          ? (isReplace
                ? clonedDimensions
                : [...targetStorey.dimensions, ...clonedDimensions])
          : targetStorey.dimensions;

      final nextMarkers =
          isTypeSelected(ArchitectStoreyElementType.elevationMarkers)
          ? (isReplace
                ? clonedMarkers
                : [...targetStorey.elevationMarkers, ...clonedMarkers])
          : targetStorey.elevationMarkers;

      final nextAnnotations =
          isTypeSelected(ArchitectStoreyElementType.annotations)
          ? (isReplace
                ? clonedAnnotations
                : [...targetStorey.annotations, ...clonedAnnotations])
          : targetStorey.annotations;

      final nextCadPrimitives =
          isTypeSelected(ArchitectStoreyElementType.cadPrimitives)
          ? (isReplace
                ? clonedCadPrimitives
                : [...targetStorey.cadPrimitives, ...clonedCadPrimitives])
          : targetStorey.cadPrimitives;

      final nextComponents =
          isTypeSelected(ArchitectStoreyElementType.components)
          ? (isReplace
                ? clonedComponents
                : [...targetStorey.components, ...clonedComponents])
          : targetStorey.components;

      final nextFloorDrains =
          isTypeSelected(ArchitectStoreyElementType.floorDrains)
          ? (isReplace
                ? clonedFloorDrains
                : [...targetStorey.floorDrains, ...clonedFloorDrains])
          : targetStorey.floorDrains;

      final nextDecorative =
          isTypeSelected(ArchitectStoreyElementType.decorativeElements)
          ? (isReplace
                ? clonedDecorative
                : [...targetStorey.decorativeElements, ...clonedDecorative])
          : targetStorey.decorativeElements;

      final nextRoofs = isTypeSelected(ArchitectStoreyElementType.roofs)
          ? (isReplace ? clonedRoofs : [...targetStorey.roofs, ...clonedRoofs])
          : targetStorey.roofs;

      final nextGroups = options.preserveGroups
          ? (isReplace
                ? clonedGroups
                : [...targetStorey.groups, ...clonedGroups])
          : targetStorey.groups;

      updatedStoreys.add(
        targetStorey.copyWith(
          walls: nextWalls,
          columns: nextColumns,
          beams: nextBeams,
          slabs: nextSlabs,
          zones: nextZones,
          stairs: nextStairs,
          openings: nextOpenings,
          dimensions: nextDimensions,
          elevationMarkers: nextMarkers,
          annotations: nextAnnotations,
          cadPrimitives: nextCadPrimitives,
          components: nextComponents,
          floorDrains: nextFloorDrains,
          decorativeElements: nextDecorative,
          roofs: nextRoofs,
          groups: nextGroups,
        ),
      );
    }

    final updatedProject = currentProject.copyWith(
      storeys: updatedStoreys,
      elementLayers: updatedElementLayers,
      document: updatedDocument,
      updatedAt: DateTime.now(),
    );

    final result = StoreyCopyResult(
      totalCopied: totalCopiedAcrossAllTargets,
      targetStoreyCount: targetStoreyIds.length,
      breakdown: breakdown,
    );

    return (updatedProject, result);
  }
}
