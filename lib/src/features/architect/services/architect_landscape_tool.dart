import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';

/// Unified controller and geometry helper for the Landscape tool category:
/// Terrain (`terrain`), Pathway with Automatic Curb (`pathway`),
/// Vegetation (`vegetation`), and Site Fence / Gabion / Retaining Wall (`siteFence`).
class ArchitectLandscapeTool {
  // --- Terrain State ---
  ArchitectTerrainState terrainState = ArchitectTerrainState.proposed;
  ArchitectTerrainDraftMode terrainMode = ArchitectTerrainDraftMode.boundary;
  double terrainElevation = -0.15;

  // --- Pathway State ---
  double pathwayWidth = 1.50;
  ArchitectPathwayCurbMode pathwayCurbMode = ArchitectPathwayCurbMode.both;
  double pathwayCurbWidth = 0.15;
  double pathwayCurbHeight = 0.12;
  ArchitectPavingMaterial pathwayMaterial = ArchitectPavingMaterial.stoneSlabs;
  bool pathwayClosed = false;

  // --- Vegetation State ---
  ArchitectPlantSpecies plantSpecies = ArchitectPlantSpecies.deciduousCanopy;
  ArchitectVegetationPlacementMode plantPlacementMode =
      ArchitectVegetationPlacementMode.single;
  double plantCrownDiameter = 4.0;
  double plantHeight = 5.5;
  double plantRowSpacing = 4.0;
  double hedgeWidth = 0.60;

  // --- Site Fence State ---
  ArchitectSiteFencePreset fencePreset = ArchitectSiteFencePreset.piersAndSlats;
  double fenceHeight = 1.80;
  double fenceThickness = 0.25;
  double fencePierSpacing = 2.50;

  // --- Active Polyline/Polygon Draft Chain ---
  final List<Offset> draftPoints = <Offset>[];

  void clearDraft() => draftPoints.clear();

  void undoLastPoint() {
    if (draftPoints.isNotEmpty) {
      draftPoints.removeLast();
    }
  }

  void applySpeciesDefaults(ArchitectPlantSpecies species) {
    plantSpecies = species;
    switch (species) {
      case ArchitectPlantSpecies.deciduousCanopy:
        plantCrownDiameter = 4.2;
        plantHeight = 5.8;
        if (plantPlacementMode == ArchitectVegetationPlacementMode.hedge) {
          plantPlacementMode = ArchitectVegetationPlacementMode.single;
        }
      case ArchitectPlantSpecies.deciduousMinimal:
        plantCrownDiameter = 3.6;
        plantHeight = 5.0;
        if (plantPlacementMode == ArchitectVegetationPlacementMode.hedge) {
          plantPlacementMode = ArchitectVegetationPlacementMode.single;
        }
      case ArchitectPlantSpecies.coniferPine:
        plantCrownDiameter = 3.2;
        plantHeight = 6.5;
        if (plantPlacementMode == ArchitectVegetationPlacementMode.hedge) {
          plantPlacementMode = ArchitectVegetationPlacementMode.single;
        }
      case ArchitectPlantSpecies.columnarCypress:
        plantCrownDiameter = 1.2;
        plantHeight = 4.5;
        plantRowSpacing = 1.8;
        if (plantPlacementMode == ArchitectVegetationPlacementMode.hedge) {
          plantPlacementMode = ArchitectVegetationPlacementMode.single;
        }
      case ArchitectPlantSpecies.ornamentalPalm:
        plantCrownDiameter = 3.5;
        plantHeight = 5.2;
        if (plantPlacementMode == ArchitectVegetationPlacementMode.hedge) {
          plantPlacementMode = ArchitectVegetationPlacementMode.single;
        }
      case ArchitectPlantSpecies.shrubCluster:
        plantCrownDiameter = 1.4;
        plantHeight = 1.1;
        plantRowSpacing = 1.5;
        if (plantPlacementMode == ArchitectVegetationPlacementMode.hedge) {
          plantPlacementMode = ArchitectVegetationPlacementMode.single;
        }
      case ArchitectPlantSpecies.trimmedHedge:
        plantPlacementMode = ArchitectVegetationPlacementMode.hedge;
        hedgeWidth = 0.60;
        plantHeight = 1.30;
    }
  }

  void applyFencePresetDefaults(ArchitectSiteFencePreset preset) {
    fencePreset = preset;
    switch (preset) {
      case ArchitectSiteFencePreset.piersAndSlats:
        fenceHeight = 1.80;
        fenceThickness = 0.25;
        fencePierSpacing = 2.50;
      case ArchitectSiteFencePreset.gabionFence:
        fenceHeight = 1.80;
        fenceThickness = 0.40;
        fencePierSpacing = 2.50;
      case ArchitectSiteFencePreset.gabionRetaining:
        fenceHeight = 1.50;
        fenceThickness = 0.80;
        fencePierSpacing = 3.00;
      case ArchitectSiteFencePreset.modernLouvers:
        fenceHeight = 1.80;
        fenceThickness = 0.18;
        fencePierSpacing = 2.20;
      case ArchitectSiteFencePreset.classicIron:
        fenceHeight = 1.75;
        fenceThickness = 0.24;
        fencePierSpacing = 2.60;
      case ArchitectSiteFencePreset.rcRetaining:
        fenceHeight = 1.60;
        fenceThickness = 0.30;
        fencePierSpacing = 3.00;
    }
  }

  bool canCommit(String toolName) {
    return switch (toolName) {
      'terrain' => switch (terrainMode) {
        ArchitectTerrainDraftMode.boundary ||
        ArchitectTerrainDraftMode.pad =>
          draftPoints.length >= 3,
        ArchitectTerrainDraftMode.contour => draftPoints.length >= 2,
        ArchitectTerrainDraftMode.spot => false,
      },
      'pathway' => draftPoints.length >= (pathwayClosed ? 3 : 2),
      'vegetation' =>
        plantPlacementMode != ArchitectVegetationPlacementMode.single &&
            draftPoints.length >= 2,
      'siteFence' => draftPoints.length >= 2,
      _ => false,
    };
  }

  /// Handles a canvas tap in world coordinates.
  /// Returns an updated [ArchitectProject] when a single-tap element is placed
  /// (or when a closed boundary/pad is closed by tapping the start vertex),
  /// or `null` when the tap simply appends to [draftPoints].
  ArchitectProject? handleTap({
    required String toolName,
    required Offset worldPoint,
    required ArchitectProject project,
    double closeThresholdWorld = 0.35,
  }) {
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    switch (toolName) {
      case 'terrain':
        if (terrainMode == ArchitectTerrainDraftMode.spot) {
          final spot = ArchitectTerrainSpot(
            id: 'terr_spot_$nowMicros',
            position: worldPoint,
            elevation: terrainElevation,
          );
          final surface = _targetSurface(project);
          final nextSurface = surface.copyWith(
            spots: [...surface.spots, spot],
          );
          return _updateSurface(project, nextSurface);
        }
        if ((terrainMode == ArchitectTerrainDraftMode.boundary ||
                terrainMode == ArchitectTerrainDraftMode.pad) &&
            draftPoints.length >= 3 &&
            (worldPoint - draftPoints.first).distance <= closeThresholdWorld) {
          return commitDraft(toolName: toolName, project: project);
        }
        draftPoints.add(worldPoint);
        return null;

      case 'pathway':
        if (pathwayClosed &&
            draftPoints.length >= 3 &&
            (worldPoint - draftPoints.first).distance <= closeThresholdWorld) {
          return commitDraft(toolName: toolName, project: project);
        }
        draftPoints.add(worldPoint);
        return null;

      case 'vegetation':
        if (plantPlacementMode == ArchitectVegetationPlacementMode.single &&
            plantSpecies != ArchitectPlantSpecies.trimmedHedge) {
          final item = ArchitectVegetationItem(
            id: 'vege_$nowMicros',
            species: plantSpecies,
            position: worldPoint,
            crownDiameter: plantCrownDiameter,
            height: plantHeight,
          );
          final storey = project.activeStorey;
          return project.updateActiveStorey(
            storey.copyWith(vegetation: [...storey.vegetation, item]),
          );
        }
        draftPoints.add(worldPoint);
        return null;

      case 'siteFence':
        draftPoints.add(worldPoint);
        return null;

      default:
        return null;
    }
  }

  /// Commits the current multi-point [draftPoints] chain and clears the draft.
  ArchitectProject? commitDraft({
    required String toolName,
    required ArchitectProject project,
  }) {
    if (!canCommit(toolName)) return null;
    final pts = List<Offset>.unmodifiable(draftPoints);
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    draftPoints.clear();

    switch (toolName) {
      case 'terrain':
        final surface = _targetSurface(project);
        if (terrainMode == ArchitectTerrainDraftMode.boundary ||
            terrainMode == ArchitectTerrainDraftMode.pad) {
          final boundary = ArchitectTerrainBoundary(
            id: 'terr_bnd_$nowMicros',
            polygon: pts,
            elevation: terrainElevation,
            isCutoutPad: terrainMode == ArchitectTerrainDraftMode.pad,
          );
          return _updateSurface(
            project,
            surface.copyWith(boundaries: [...surface.boundaries, boundary]),
          );
        } else if (terrainMode == ArchitectTerrainDraftMode.contour) {
          final contour = ArchitectTerrainContour(
            id: 'terr_cnt_$nowMicros',
            points: pts,
            elevation: terrainElevation,
          );
          return _updateSurface(
            project,
            surface.copyWith(contours: [...surface.contours, contour]),
          );
        }
        return null;

      case 'pathway':
        final pathway = ArchitectPathway(
          id: 'path_$nowMicros',
          points: pts,
          width: pathwayWidth,
          curbMode: pathwayCurbMode,
          curbWidth: pathwayCurbWidth,
          curbHeight: pathwayCurbHeight,
          material: pathwayMaterial,
          closed: pathwayClosed,
        );
        final storey = project.activeStorey;
        return project.updateActiveStorey(
          storey.copyWith(pathways: [...storey.pathways, pathway]),
        );

      case 'vegetation':
        final storey = project.activeStorey;
        if (plantSpecies == ArchitectPlantSpecies.trimmedHedge ||
            plantPlacementMode == ArchitectVegetationPlacementMode.hedge) {
          final hedge = ArchitectVegetationItem(
            id: 'hedge_$nowMicros',
            species: ArchitectPlantSpecies.trimmedHedge,
            position: pts.first,
            crownDiameter: hedgeWidth,
            height: plantHeight,
            points: pts,
            hedgeWidth: hedgeWidth,
          );
          return project.updateActiveStorey(
            storey.copyWith(vegetation: [...storey.vegetation, hedge]),
          );
        }
        // Row placement along chain
        final rowItems = <ArchitectVegetationItem>[];
        final step = plantRowSpacing.clamp(0.5, 50.0);
        int idx = 0;
        for (int i = 0; i < pts.length - 1; i++) {
          final a = pts[i];
          final b = pts[i + 1];
          final segLen = (b - a).distance;
          if (segLen < 1e-4) continue;
          final u = (b - a) / segLen;
          final startD = i == 0 ? 0.0 : step;
          for (double d = startD; d <= segLen + 1e-4; d += step) {
            final pos = a + u * math.min(d, segLen);
            rowItems.add(
              ArchitectVegetationItem(
                id: 'vege_${nowMicros}_${idx++}',
                species: plantSpecies,
                position: pos,
                crownDiameter: plantCrownDiameter,
                height: plantHeight,
              ),
            );
          }
        }
        if (rowItems.isEmpty) return null;
        return project.updateActiveStorey(
          storey.copyWith(vegetation: [...storey.vegetation, ...rowItems]),
        );

      case 'siteFence':
        final fence = ArchitectSiteFence(
          id: 'fence_$nowMicros',
          points: pts,
          preset: fencePreset,
          height: fenceHeight,
          thickness: fenceThickness,
          pierSpacing: fencePierSpacing,
        );
        final storey = project.activeStorey;
        return project.updateActiveStorey(
          storey.copyWith(siteFences: [...storey.siteFences, fence]),
        );

      default:
        return null;
    }
  }

  /// Synchronizes `existingTerrain` (and `proposedTerrain` if empty) from `project.geodeticSurvey`.
  ArchitectProject syncTerrainFromGeodesy(ArchitectProject project) {
    final survey = project.geodeticSurvey;
    if (survey == null ||
        (survey.contours.isEmpty && survey.spotElevations.isEmpty)) {
      return project;
    }
    final syncedExisting = ArchitectTerrainSurface.fromGeodeticSurvey(
      survey,
      state: ArchitectTerrainState.existing,
    );
    final nextProposed = project.proposedTerrain.isEmpty
        ? ArchitectTerrainSurface.fromGeodeticSurvey(
            survey,
            state: ArchitectTerrainState.proposed,
          )
        : project.proposedTerrain;
    return project.copyWith(
      existingTerrain: syncedExisting,
      proposedTerrain: nextProposed,
      updatedAt: DateTime.now(),
    );
  }

  ArchitectTerrainSurface _targetSurface(ArchitectProject project) =>
      terrainState == ArchitectTerrainState.existing
      ? project.existingTerrain
      : project.proposedTerrain;

  ArchitectProject _updateSurface(
    ArchitectProject project,
    ArchitectTerrainSurface surface,
  ) {
    return terrainState == ArchitectTerrainState.existing
        ? project.copyWith(
            existingTerrain: surface,
            updatedAt: DateTime.now(),
          )
        : project.copyWith(
            proposedTerrain: surface,
            updatedAt: DateTime.now(),
          );
  }

  // ===========================================================================
  // HIT-TESTING, SELECTION MOVE & DELETION HELPERS
  // ===========================================================================

  static String? hitTestLandscapeElement({
    required ArchitectProject project,
    required ArchitectStorey storey,
    required Offset worldPoint,
    required double hitTolerance,
  }) {
    // 1. Vegetation items on active storey
    if (project.isLayerVisible(ArchitectLayer.vegetationLayerId)) {
      for (final item in storey.vegetation.reversed) {
        if (!project.isElementVisible(
          item.id,
          ArchitectLayer.vegetationLayerId,
        )) {
          continue;
        }
        if (item.containsPoint(worldPoint, tolerance: hitTolerance)) {
          return item.id;
        }
      }
    }

    // 2. Site fences on active storey
    if (project.isLayerVisible(ArchitectLayer.pathwayLayerId)) {
      for (final fence in storey.siteFences.reversed) {
        if (!project.isElementVisible(
          fence.id,
          ArchitectLayer.pathwayLayerId,
        )) {
          continue;
        }
        if (fence.containsPoint(worldPoint, tolerance: hitTolerance)) {
          return fence.id;
        }
      }

      // 3. Pathways on active storey
      for (final pathway in storey.pathways.reversed) {
        if (!project.isElementVisible(
          pathway.id,
          ArchitectLayer.pathwayLayerId,
        )) {
          continue;
        }
        if (pathway.containsPoint(worldPoint, tolerance: hitTolerance)) {
          return pathway.id;
        }
      }
    }

    // 4. Proposed & Existing terrain elements
    for (final (surface, layerId) in [
      (project.proposedTerrain, ArchitectLayer.terrainProposedLayerId),
      (project.existingTerrain, ArchitectLayer.terrainExistingLayerId),
    ]) {
      if (!project.isLayerVisible(layerId) || surface.isEmpty) continue;
      for (final spot in surface.spots.reversed) {
        if ((spot.position - worldPoint).distance <= hitTolerance * 1.4) {
          return spot.id;
        }
      }
      for (final contour in surface.contours.reversed) {
        if (_hitPolyline(contour.points, worldPoint, hitTolerance)) {
          return contour.id;
        }
      }
      for (final boundary in surface.boundaries.reversed) {
        if (_hitPolyline(
          boundary.polygon,
          worldPoint,
          hitTolerance,
          closed: true,
        )) {
          return boundary.id;
        }
      }
    }

    return null;
  }

  static bool isLandscapeElementId(ArchitectProject project, String id) {
    final storey = project.activeStorey;
    if (storey.pathways.any((p) => p.id == id) ||
        storey.vegetation.any((v) => v.id == id) ||
        storey.siteFences.any((f) => f.id == id)) {
      return true;
    }
    for (final surface in [project.existingTerrain, project.proposedTerrain]) {
      if (surface.boundaries.any((b) => b.id == id) ||
          surface.contours.any((c) => c.id == id) ||
          surface.spots.any((s) => s.id == id)) {
        return true;
      }
    }
    return false;
  }

  static ArchitectProject translateSelected({
    required ArchitectProject project,
    required Set<String> selectedIds,
    required Offset delta,
  }) {
    if (selectedIds.isEmpty || delta == Offset.zero) return project;
    final storey = project.activeStorey;
    bool storeyChanged = false;

    final nextPathways = [
      for (final p in storey.pathways)
        if (selectedIds.contains(p.id))
          () {
            storeyChanged = true;
            return p.copyWith(
              points: [for (final pt in p.points) pt + delta],
            );
          }()
        else
          p,
    ];

    final nextVegetation = <ArchitectVegetationItem>[
      for (final v in storey.vegetation)
        if (selectedIds.contains(v.id))
          () {
            storeyChanged = true;
            return v.copyWith(
              position: v.position + delta,
              points: [for (final pt in v.points) pt + delta],
            );
          }()
        else
          v,
    ];

    final nextFences = [
      for (final f in storey.siteFences)
        if (selectedIds.contains(f.id))
          () {
            storeyChanged = true;
            return f.copyWith(
              points: [for (final pt in f.points) pt + delta],
            );
          }()
        else
          f,
    ];

    var updated = storeyChanged
        ? project.updateActiveStorey(
            storey.copyWith(
              pathways: nextPathways,
              vegetation: nextVegetation,
              siteFences: nextFences,
            ),
          )
        : project;

    updated = updated.copyWith(
      existingTerrain: _translateSurface(
        updated.existingTerrain,
        selectedIds,
        delta,
      ),
      proposedTerrain: _translateSurface(
        updated.proposedTerrain,
        selectedIds,
        delta,
      ),
    );
    return updated;
  }

  static ArchitectProject deleteSelected({
    required ArchitectProject project,
    required Set<String> selectedIds,
  }) {
    if (selectedIds.isEmpty) return project;
    final storey = project.activeStorey;
    final nextStorey = storey.copyWith(
      pathways: storey.pathways
          .where((p) => !selectedIds.contains(p.id))
          .toList(),
      vegetation: storey.vegetation
          .where((v) => !selectedIds.contains(v.id))
          .toList(),
      siteFences: storey.siteFences
          .where((f) => !selectedIds.contains(f.id))
          .toList(),
    );
    return project
        .updateActiveStorey(nextStorey)
        .copyWith(
          existingTerrain: _deleteFromSurface(
            project.existingTerrain,
            selectedIds,
          ),
          proposedTerrain: _deleteFromSurface(
            project.proposedTerrain,
            selectedIds,
          ),
        );
  }

  static ArchitectTerrainSurface _translateSurface(
    ArchitectTerrainSurface surface,
    Set<String> selectedIds,
    Offset delta,
  ) {
    return surface.copyWith(
      boundaries: [
        for (final b in surface.boundaries)
          selectedIds.contains(b.id)
              ? b.copyWith(polygon: [for (final p in b.polygon) p + delta])
              : b,
      ],
      contours: [
        for (final c in surface.contours)
          selectedIds.contains(c.id)
              ? c.copyWith(points: [for (final p in c.points) p + delta])
              : c,
      ],
      spots: [
        for (final s in surface.spots)
          selectedIds.contains(s.id)
              ? s.copyWith(position: s.position + delta)
              : s,
      ],
    );
  }

  static ArchitectTerrainSurface _deleteFromSurface(
    ArchitectTerrainSurface surface,
    Set<String> selectedIds,
  ) {
    return surface.copyWith(
      boundaries: surface.boundaries
          .where((b) => !selectedIds.contains(b.id))
          .toList(),
      contours: surface.contours
          .where((c) => !selectedIds.contains(c.id))
          .toList(),
      spots: surface.spots.where((s) => !selectedIds.contains(s.id)).toList(),
    );
  }

  static bool _hitPolyline(
    List<Offset> pts,
    Offset p,
    double tol, {
    bool closed = false,
  }) {
    if (pts.length < 2) return false;
    final count = closed ? pts.length : pts.length - 1;
    for (int i = 0; i < count; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final ab = b - a;
      final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
      final t = lenSq < 1e-9
          ? 0.0
          : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq).clamp(
              0.0,
              1.0,
            );
      final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
      if ((p - proj).distance <= tol) return true;
    }
    return false;
  }
}
