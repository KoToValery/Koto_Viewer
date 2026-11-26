import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../models/architect_project.dart';

/// Candidate contour curve detected under the lifted pointer on a CAD underlay.
class ArchitectPickedContourCandidate {
  final List<Offset> points;
  final bool closed;
  final double? suggestedElevation;
  final String? sourceLayer;
  final Offset? anchorPoint;

  const ArchitectPickedContourCandidate({
    required this.points,
    this.closed = false,
    this.suggestedElevation,
    this.sourceLayer,
    this.anchorPoint,
  });
}

/// Unified controller and geometry helper for the Landscape tool category:
/// Terrain (`terrain`), Pathway with Automatic Curb (`pathway`),
/// Vegetation (`vegetation`), and Site Fence / Gabion / Retaining Wall (`siteFence`).
class ArchitectLandscapeTool extends ChangeNotifier {
  // --- Terrain State ---
  ArchitectTerrainState terrainState = ArchitectTerrainState.existing;
  ArchitectTerrainDraftMode terrainMode = ArchitectTerrainDraftMode.boundary;
  double terrainElevation = 0.0;
  double terrainDatumElevation = 0.0;
  double contourInterval = 0.0;
  double contourAbsoluteElevation = 0.0;
  bool contourClosed = false;
  bool contourMajor = false;
  bool contourAutoTrace = true;
  ArchitectPickedContourCandidate? pickedContourPreview;

  /// True when the active tool/mode picks an existing/underlay contour with the lifted pointer.
  bool isPickingContour(String toolName) =>
      (toolName == 'terrain' &&
          terrainMode == ArchitectTerrainDraftMode.pickContour) ||
      (toolName == 'contour' && contourAutoTrace && draftPoints.isEmpty);

  /// True when tapping near the first draft point closes/commits the drafted loop.
  bool canCloseDraftToStart(String toolName) => switch (toolName) {
    'terrain' =>
      terrainMode == ArchitectTerrainDraftMode.boundary ||
          terrainMode == ArchitectTerrainDraftMode.pad ||
          terrainMode == ArchitectTerrainDraftMode.hole ||
          terrainMode == ArchitectTerrainDraftMode.contour,
    'contour' => true,
    'pathway' => pathwayClosed,
    'street' => streetClosed,
    _ => false,
  };

  /// True when drafting an orthogonal/polygonal closed boundary (not a spline contour).
  bool isClosedPolygonDraft(String toolName) => switch (toolName) {
    'terrain' =>
      terrainMode == ArchitectTerrainDraftMode.boundary ||
          terrainMode == ArchitectTerrainDraftMode.pad ||
          terrainMode == ArchitectTerrainDraftMode.hole,
    'pathway' => pathwayClosed,
    'street' => streetClosed,
    _ => false,
  };

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
  ArchitectFenceSlopeMode fenceSlopeMode = ArchitectFenceSlopeMode.stepped;

  // --- Street State ---
  double streetRoadWidth = 6.00;
  double streetCurbWidth = 0.15;
  double streetCurbHeight = 0.12;
  bool streetHasLeftSidewalk = true;
  double streetLeftSidewalkWidth = 1.50;
  bool streetHasRightSidewalk = true;
  double streetRightSidewalkWidth = 1.50;
  ArchitectRoadMarkingStyle streetMarkingStyle =
      ArchitectRoadMarkingStyle.dashed;
  double streetMarkingWidth = 0.12;
  ArchitectPavingMaterial streetRoadMaterial = ArchitectPavingMaterial.asphalt;
  ArchitectPavingMaterial streetSidewalkMaterial =
      ArchitectPavingMaterial.cobblePavers;
  bool streetClosed = false;

  // --- Active Polyline/Polygon Draft Chain ---
  final List<Offset> draftPoints = <Offset>[];
  int _revision = 0;

  /// Increments on every controller notification so UI state tuples and listeners
  /// detect any landscape tool property or draft mutation cleanly.
  int get revision => _revision;

  bool get isDrafting => draftPoints.isNotEmpty;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

  /// Notifies attached listeners after external property mutations.
  void notifyChanged() => notifyListeners();

  void clearDraft() {
    draftPoints.clear();
    pickedContourPreview = null;
    notifyListeners();
  }

  void setPickedContourPreview(ArchitectPickedContourCandidate? candidate) {
    pickedContourPreview = candidate;
    notifyListeners();
  }

  void undoLastPoint() {
    if (draftPoints.isNotEmpty) {
      draftPoints.removeLast();
      notifyListeners();
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
      case ArchitectPlantSpecies.artisticLowPoly:
        plantCrownDiameter = 3.8;
        plantHeight = 5.6;
        if (plantPlacementMode == ArchitectVegetationPlacementMode.hedge) {
          plantPlacementMode = ArchitectVegetationPlacementMode.single;
        }
    }
    notifyListeners();
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
    notifyListeners();
  }

  bool canCommit(String toolName) {
    return switch (toolName) {
      'terrain' => switch (terrainMode) {
        ArchitectTerrainDraftMode.boundary ||
        ArchitectTerrainDraftMode.hole ||
        ArchitectTerrainDraftMode.pad =>
          draftPoints.length >= 3,
        ArchitectTerrainDraftMode.boundaryRect => draftPoints.length >= 2,
        ArchitectTerrainDraftMode.contour => draftPoints.length >= 2,
        ArchitectTerrainDraftMode.pickContour ||
        ArchitectTerrainDraftMode.spot => false,
      },
      'contour' => draftPoints.length >= 2,
      'pathway' => draftPoints.length >= (pathwayClosed ? 3 : 2),
      'street' => draftPoints.length >= (streetClosed ? 3 : 2),
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
        if (terrainMode == ArchitectTerrainDraftMode.boundaryRect) {
          if (draftPoints.isEmpty) {
            draftPoints.add(worldPoint);
            return null;
          }
          final a = draftPoints.first;
          final b = worldPoint;
          if ((a.dx - b.dx).abs() < 0.1 || (a.dy - b.dy).abs() < 0.1) {
            return null;
          }
          draftPoints.add(b);
          return commitDraft(toolName: toolName, project: project);
        }
        if ((terrainMode == ArchitectTerrainDraftMode.boundary ||
                terrainMode == ArchitectTerrainDraftMode.pad ||
                terrainMode == ArchitectTerrainDraftMode.hole) &&
            draftPoints.length >= 3 &&
            (worldPoint - draftPoints.first).distance <= closeThresholdWorld) {
          return commitDraft(toolName: toolName, project: project);
        }
        if (terrainMode == ArchitectTerrainDraftMode.contour &&
            draftPoints.length >= 3 &&
            (worldPoint - draftPoints.first).distance <= closeThresholdWorld) {
          contourClosed = true;
          return commitDraft(toolName: toolName, project: project);
        }
        if (terrainMode == ArchitectTerrainDraftMode.pickContour) {
          return null;
        }
        draftPoints.add(worldPoint);
        return null;

      case 'contour':
        if (draftPoints.length >= 3 &&
            (worldPoint - draftPoints.first).distance <= closeThresholdWorld) {
          contourClosed = true;
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
          final storey = project.landscapeTargetStorey;
          return project.updateStorey(
            storey.copyWith(vegetation: [...storey.vegetation, item]),
            recalculateAbove: false,
          );
        }
        draftPoints.add(worldPoint);
        return null;

      case 'siteFence':
        draftPoints.add(worldPoint);
        return null;

      case 'street':
        if (streetClosed &&
            draftPoints.length >= 3 &&
            (worldPoint - draftPoints.first).distance <= closeThresholdWorld) {
          return commitDraft(toolName: toolName, project: project);
        }
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
        if (terrainMode == ArchitectTerrainDraftMode.boundaryRect &&
            pts.length >= 2) {
          final a = pts.first;
          final b = pts.last;
          final minX = math.min(a.dx, b.dx);
          final maxX = math.max(a.dx, b.dx);
          final minY = math.min(a.dy, b.dy);
          final maxY = math.max(a.dy, b.dy);
          final rectPoly = [
            Offset(minX, minY),
            Offset(maxX, minY),
            Offset(maxX, maxY),
            Offset(minX, maxY),
          ];
          final boundary = ArchitectTerrainBoundary(
            id: 'terr_bnd_$nowMicros',
            polygon: rectPoly,
            elevation: 0.0,
            autoInterpolateElevation: true,
          );
          return _updateSurface(
            project,
            surface.copyWith(
              datumElevation: _resolvedDatum(project),
              boundaries: [...surface.boundaries, boundary],
            ),
          );
        }
        if (terrainMode == ArchitectTerrainDraftMode.boundary ||
            terrainMode == ArchitectTerrainDraftMode.hole ||
            terrainMode == ArchitectTerrainDraftMode.pad) {
          final isOuter = terrainMode == ArchitectTerrainDraftMode.boundary;
          final isHole = terrainMode == ArchitectTerrainDraftMode.hole;
          final bndId = 'terr_bnd_$nowMicros';
          final nextSpots = isHole
              ? surface.withHoleVertexSpots(
                  holeId: bndId,
                  points: pts,
                  fallbackRelativeElevation: terrainElevation,
                )
              : surface.spots;
          final boundary = ArchitectTerrainBoundary(
            id: bndId,
            polygon: pts,
            elevation: isOuter ? 0.0 : terrainElevation,
            isCutoutPad: terrainMode == ArchitectTerrainDraftMode.pad,
            isHole: isHole,
            autoInterpolateElevation: isOuter,
          );
          return _updateSurface(
            project,
            surface.copyWith(
              datumElevation: _resolvedDatum(project),
              boundaries: [...surface.boundaries, boundary],
              spots: nextSpots,
            ),
          );
        } else if (terrainMode == ArchitectTerrainDraftMode.contour) {
          final datum = _resolvedDatum(project);
          final effectiveElevation = contourAbsoluteElevation != 0.0
              ? (contourAbsoluteElevation - datum)
              : terrainElevation;
          final contour = ArchitectTerrainContour(
            id: 'terr_cnt_$nowMicros',
            points: pts,
            elevation: effectiveElevation,
            rawAbsoluteElevation: contourAbsoluteElevation != 0.0
                ? contourAbsoluteElevation
                : (effectiveElevation + datum),
            closed: contourClosed,
            isMajor: contourMajor,
            isSpline: true,
          );
          return _updateSurface(
            project,
            surface.copyWith(
              datumElevation: datum,
              contours: [...surface.contours, contour],
            ),
          );
        }
        return null;

      case 'contour':
        final surface = _targetSurface(project);
        final datum = _resolvedDatum(project);
        final effectiveElevation = contourAbsoluteElevation != 0.0
            ? (contourAbsoluteElevation - datum)
            : terrainElevation;
        final contour = ArchitectTerrainContour(
          id: 'terr_cnt_$nowMicros',
          points: pts,
          elevation: effectiveElevation,
          rawAbsoluteElevation: contourAbsoluteElevation != 0.0
              ? contourAbsoluteElevation
              : (effectiveElevation + datum),
          closed: contourClosed,
          isMajor: contourMajor,
          isSpline: true,
        );
        return _updateSurface(
          project,
          surface.copyWith(
            datumElevation: datum,
            contours: [...surface.contours, contour],
          ),
        );

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
        final storey = project.landscapeTargetStorey;
        return project.updateStorey(
          storey.copyWith(pathways: [...storey.pathways, pathway]),
          recalculateAbove: false,
        );

      case 'vegetation':
        final storey = project.landscapeTargetStorey;
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
          return project.updateStorey(
            storey.copyWith(vegetation: [...storey.vegetation, hedge]),
            recalculateAbove: false,
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
        return project.updateStorey(
          storey.copyWith(vegetation: [...storey.vegetation, ...rowItems]),
          recalculateAbove: false,
        );

      case 'siteFence':
        final fence = ArchitectSiteFence(
          id: 'fence_$nowMicros',
          points: pts,
          preset: fencePreset,
          height: fenceHeight,
          thickness: fenceThickness,
          pierSpacing: fencePierSpacing,
          slopeMode: fenceSlopeMode,
        );
        final storey = project.landscapeTargetStorey;
        return project.updateStorey(
          storey.copyWith(siteFences: [...storey.siteFences, fence]),
          recalculateAbove: false,
        );

      case 'street':
        final street = ArchitectStreet(
          id: 'street_$nowMicros',
          points: pts,
          closed: streetClosed,
          roadWidth: streetRoadWidth,
          curbWidth: streetCurbWidth,
          curbHeight: streetCurbHeight,
          hasLeftSidewalk: streetHasLeftSidewalk,
          leftSidewalkWidth: streetLeftSidewalkWidth,
          hasRightSidewalk: streetHasRightSidewalk,
          rightSidewalkWidth: streetRightSidewalkWidth,
          markingStyle: streetMarkingStyle,
          markingWidth: streetMarkingWidth,
          roadMaterial: streetRoadMaterial,
          sidewalkMaterial: streetSidewalkMaterial,
        );
        final storey = project.landscapeTargetStorey;
        return project.updateStorey(
          storey.copyWith(streets: [...storey.streets, street]),
          recalculateAbove: false,
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
    final userDatum = project.existingTerrain.datumElevation.abs() > 1e-4
        ? project.existingTerrain.datumElevation
        : (project.proposedTerrain.datumElevation.abs() > 1e-4
            ? project.proposedTerrain.datumElevation
            : terrainDatumElevation);
    var syncedExisting = ArchitectTerrainSurface.fromGeodeticSurvey(
      survey,
      state: ArchitectTerrainState.existing,
    );
    if (userDatum.abs() > 1e-4) {
      syncedExisting = syncedExisting.withDatumElevation(userDatum);
    }
    var nextProposed = project.proposedTerrain.isEmpty
        ? ArchitectTerrainSurface.fromGeodeticSurvey(
            survey,
            state: ArchitectTerrainState.proposed,
          )
        : project.proposedTerrain;
    if (userDatum.abs() > 1e-4 && project.proposedTerrain.isEmpty) {
      nextProposed = nextProposed.withDatumElevation(userDatum);
    }
    return project.copyWith(
      existingTerrain: syncedExisting,
      proposedTerrain: nextProposed,
      updatedAt: DateTime.now(),
    );
  }

  double _resolvedDatum(ArchitectProject project) {
    final target = _targetSurface(project);
    if (target.datumElevation.abs() > 1e-4) return target.datumElevation;
    final other = terrainState == ArchitectTerrainState.existing
        ? project.proposedTerrain
        : project.existingTerrain;
    if (other.datumElevation.abs() > 1e-4) return other.datumElevation;
    return terrainDatumElevation;
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

  /// Clones `existingTerrain` into `proposedTerrain` (1-click Proposed from Existing).
  static ArchitectProject cloneExistingToProposed(ArchitectProject project) {
    if (project.existingTerrain.isEmpty) return project;
    return project.copyWith(
      proposedTerrain: project.existingTerrain.cloneAsProposed(),
      updatedAt: DateTime.now(),
    );
  }

  /// Updates the building ±0.00 datum elevation on both Existing and Proposed
  /// terrain surfaces while preserving all contours' and spots' absolute geodetic elevations.
  static ArchitectProject updateSurfaceDatum(
    ArchitectProject project, {
    required ArchitectTerrainState state,
    required double newDatum,
  }) {
    final nextExisting = project.existingTerrain.withDatumElevation(newDatum);
    final nextProposed = project.proposedTerrain.withDatumElevation(newDatum);
    return project.copyWith(
      existingTerrain: nextExisting,
      proposedTerrain: nextProposed,
      updatedAt: DateTime.now(),
    );
  }

  static ArchitectProject updateSurfaceContourInterval(
    ArchitectProject project, {
    required double intervalMeters,
    required bool manual,
  }) {
    final clean = intervalMeters <= 1e-4 ? 0.0 : double.parse(intervalMeters.toStringAsFixed(4));
    final isManual = clean > 1e-4 && manual;
    return project.copyWith(
      existingTerrain: project.existingTerrain.copyWith(
        contourInterval: clean,
        contourIntervalManual: isManual,
      ),
      proposedTerrain: project.proposedTerrain.copyWith(
        contourInterval: clean,
        contourIntervalManual: isManual,
      ),
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

    // 2. Streets on active storey
    if (project.isLayerVisible(ArchitectLayer.streetLayerId)) {
      for (final street in storey.streets.reversed) {
        if (!project.isElementVisible(
          street.id,
          ArchitectLayer.streetLayerId,
        )) {
          continue;
        }
        if (street.containsPoint(worldPoint, tolerance: hitTolerance)) {
          return street.id;
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

    // 4. Proposed & Existing terrain elements (visible & interactive only on Site Plan)
    if (storey.isSite) {
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
          if (_hitPolyline(
            contour.resolvedPolyline(samplesPerSpan: 8),
            worldPoint,
            hitTolerance,
            closed: contour.closed,
          )) {
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
    }

    return null;
  }

  static bool isLandscapeElementId(ArchitectProject project, String id) {
    for (final storey in [project.activeStorey, ?project.siteStorey]) {
      if (storey.streets.any((s) => s.id == id) ||
          storey.pathways.any((p) => p.id == id) ||
          storey.vegetation.any((v) => v.id == id) ||
          storey.siteFences.any((f) => f.id == id)) {
        return true;
      }
    }
    return project.activeStorey.isSite && terrainStateOf(project, id) != null;
  }

  static bool _containsTerrainElement(ArchitectTerrainSurface surface, String id) =>
      surface.boundaries.any((b) => b.id == id) ||
      surface.contours.any((c) => c.id == id) ||
      surface.spots.any((s) => s.id == id);

  static ArchitectTerrainState? terrainStateOf(
    ArchitectProject project,
    String id,
  ) {
    final proposed = _containsTerrainElement(project.proposedTerrain, id);
    final existing = _containsTerrainElement(project.existingTerrain, id);
    if (proposed &&
        (!existing || project.isLayerVisible(ArchitectLayer.terrainProposedLayerId))) {
      return ArchitectTerrainState.proposed;
    }
    return existing ? ArchitectTerrainState.existing : null;
  }

  static ({ArchitectProject project, String elementId})? changeTerrainState(
    ArchitectProject project,
    String id,
    ArchitectTerrainState state,
  ) {
    final current = terrainStateOf(project, id);
    if (current == null || current == state) return null;
    final toExisting = state == ArchitectTerrainState.existing;
    final source = toExisting ? project.proposedTerrain : project.existingTerrain;
    final target = toExisting ? project.existingTerrain : project.proposedTerrain;
    // Older projects can have matching IDs on both surfaces after survey sync.
    var targetId = id;
    for (var suffix = 1;
        _containsTerrainElement(target, targetId) ||
            (targetId != id && _containsTerrainElement(source, targetId));
        suffix++) {
      targetId = '$id-${state.name}-$suffix';
    }
    final nextSource = _deleteFromSurface(source, {id});
    final nextTarget = target.copyWith(
      boundaries: [
        ...target.boundaries,
        for (final boundary in source.boundaries)
          if (boundary.id == id) boundary.copyWith(id: targetId),
      ],
      contours: [
        ...target.contours,
        for (final contour in source.contours)
          if (contour.id == id)
            contour.copyWith(
              id: targetId,
              elevation: contour.effectiveRelative(source.datumElevation),
              rawAbsoluteElevation: contour.rawAbsoluteElevation == null
                  ? null
                  : target.toAbsoluteElevation(contour.effectiveRelative(source.datumElevation)),
            ),
      ],
      spots: [
        ...target.spots,
        for (final spot in source.spots)
          if (spot.id == id)
            spot.copyWith(
              id: targetId,
              elevation: spot.effectiveRelative(source.datumElevation),
              rawAbsoluteElevation: spot.rawAbsoluteElevation == null
                  ? null
                  : target.toAbsoluteElevation(spot.effectiveRelative(source.datumElevation)),
            ),
      ],
    );
    return (
      project: project.copyWith(
        existingTerrain: toExisting ? nextTarget : nextSource,
        proposedTerrain: toExisting ? nextSource : nextTarget,
        updatedAt: DateTime.now(),
      ),
      elementId: targetId,
    );
  }

  static ArchitectProject translateSelected({
    required ArchitectProject project,
    required Set<String> selectedIds,
    required Offset delta,
  }) {
    if (selectedIds.isEmpty || delta == Offset.zero) return project;
    final storey = project.landscapeTargetStorey;
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

    final nextStreets = [
      for (final s in storey.streets)
        if (selectedIds.contains(s.id))
          () {
            storeyChanged = true;
            return s.copyWith(
              points: [for (final pt in s.points) pt + delta],
            );
          }()
        else
          s,
    ];

    var updated = storeyChanged
        ? project.updateStorey(
            storey.copyWith(
              pathways: nextPathways,
              vegetation: nextVegetation,
              siteFences: nextFences,
              streets: nextStreets,
            ),
            recalculateAbove: false,
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
    final storey = project.landscapeTargetStorey;
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
      streets: storey.streets
          .where((s) => !selectedIds.contains(s.id))
          .toList(),
    );
    return project
        .updateStorey(nextStorey, recalculateAbove: false)
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
    final deletedHolePrefixes = [
      for (final b in surface.boundaries)
        if (selectedIds.contains(b.id) && b.isHole) '${b.id}_pt_',
    ];
    return surface.copyWith(
      boundaries: surface.boundaries
          .where((b) => !selectedIds.contains(b.id))
          .toList(),
      contours: surface.contours
          .where((c) => !selectedIds.contains(c.id))
          .toList(),
      spots: surface.spots
          .where(
            (s) =>
                !selectedIds.contains(s.id) &&
                !deletedHolePrefixes.any((prefix) => s.id.startsWith(prefix)),
          )
          .toList(),
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

  // ===========================================================================
  // PROPERTY SYNCHRONIZATION WITH SELECTED ELEMENT
  // ===========================================================================

  void loadFromPathway(ArchitectPathway pathway) {
    pathwayWidth = pathway.width;
    pathwayCurbMode = pathway.curbMode;
    pathwayCurbWidth = pathway.curbWidth;
    pathwayCurbHeight = pathway.curbHeight;
    pathwayMaterial = pathway.material;
    pathwayClosed = pathway.closed;
    notifyListeners();
  }

  void loadFromStreet(ArchitectStreet street) {
    streetRoadWidth = street.roadWidth;
    streetCurbWidth = street.curbWidth;
    streetCurbHeight = street.curbHeight;
    streetHasLeftSidewalk = street.hasLeftSidewalk;
    streetLeftSidewalkWidth = street.leftSidewalkWidth;
    streetHasRightSidewalk = street.hasRightSidewalk;
    streetRightSidewalkWidth = street.rightSidewalkWidth;
    streetMarkingStyle = street.markingStyle;
    streetMarkingWidth = street.markingWidth;
    streetRoadMaterial = street.roadMaterial;
    streetSidewalkMaterial = street.sidewalkMaterial;
    streetClosed = street.closed;
    notifyListeners();
  }

  void loadFromFence(ArchitectSiteFence fence) {
    fencePreset = fence.preset;
    fenceHeight = fence.height;
    fenceThickness = fence.thickness;
    fencePierSpacing = fence.pierSpacing;
    fenceSlopeMode = fence.slopeMode;
    notifyListeners();
  }

  void loadFromVegetation(ArchitectVegetationItem veg) {
    plantSpecies = veg.species;
    plantCrownDiameter = veg.crownDiameter;
    plantHeight = veg.height;
    hedgeWidth = veg.hedgeWidth;
    notifyListeners();
  }

  void loadFromTerrainBoundary(ArchitectTerrainBoundary bnd, ArchitectTerrainState state, {double datum = 0.0}) {
    terrainState = state;
    terrainMode = bnd.isHole
        ? ArchitectTerrainDraftMode.hole
        : (bnd.isFlatPad
            ? ArchitectTerrainDraftMode.pad
            : ArchitectTerrainDraftMode.boundary);
    terrainElevation = bnd.elevation;
    terrainDatumElevation = datum;
    contourAbsoluteElevation = bnd.elevation + datum;
    notifyListeners();
  }

  void loadFromTerrainContour(ArchitectTerrainContour cnt, ArchitectTerrainState state, {double datum = 0.0}) {
    terrainState = state;
    terrainMode = ArchitectTerrainDraftMode.contour;
    terrainElevation = cnt.elevation;
    terrainDatumElevation = datum;
    contourAbsoluteElevation = cnt.effectiveAbsolute(datum);
    contourClosed = cnt.closed;
    contourMajor = cnt.isMajor;
    notifyListeners();
  }

  void loadFromTerrainSpot(ArchitectTerrainSpot spot, ArchitectTerrainState state, {double datum = 0.0}) {
    terrainState = state;
    terrainMode = ArchitectTerrainDraftMode.spot;
    terrainElevation = spot.elevation;
    terrainDatumElevation = datum;
    contourAbsoluteElevation = spot.effectiveAbsolute(datum);
    notifyListeners();
  }

  // ===========================================================================
  // 90° ORTHOGONAL & PERPENDICULAR SNAPPING
  // ===========================================================================

  /// Calculates magnetic orthogonal ($0^\circ, 90^\circ, 180^\circ, 270^\circ$) and
  /// perpendicular ($90^\circ$ relative to previous segment) snapping guides for drafting.
  static (Offset snappedPoint, String? label, List<(Offset, Offset)> guides) resolveDraftSnapping({
    required List<Offset> points,
    required Offset rawPoint,
    required double toleranceMeters,
  }) {
    if (points.isEmpty) return (rawPoint, null, const []);
    final anchor = points.last;
    final delta = rawPoint - anchor;
    final dist = delta.distance;
    if (dist < 1e-4) return (anchor, null, const []);

    final candidates = <({Offset point, String label, List<(Offset, Offset)> guides, double diff})>[];

    // 1. Perpendicular (90 deg) relative to previous segment (if >= 2 points)
    if (points.length >= 2) {
      final prev = points[points.length - 2];
      final seg = anchor - prev;
      final segLen = seg.distance;
      if (segLen > 1e-4) {
        final uSeg = seg / segLen;
        // Two perpendicular normals: left and right
        final normals = [Offset(-uSeg.dy, uSeg.dx), Offset(uSeg.dy, -uSeg.dx)];
        for (final n in normals) {
          final projDist = delta.dx * n.dx + delta.dy * n.dy;
          if (projDist > 0) {
            final projPoint = anchor + n * projDist;
            final dErr = (rawPoint - projPoint).distance;
            if (dErr <= toleranceMeters) {
              final guideSpan = math.max(projDist * 1.5, 4.0);
              candidates.add((
                point: projPoint,
                label: '90° ⊥',
                guides: [(anchor - n * (guideSpan * 0.2), anchor + n * guideSpan)],
                diff: dErr,
              ));
            }
          }
        }
      }
    }

    // 2. Global orthogonal axes (0°, 90°, 180°, 270°)
    for (final (dir, deg) in [
      (const Offset(1, 0), '0°'),
      (const Offset(0, 1), '90°'),
      (const Offset(-1, 0), '180°'),
      (const Offset(0, -1), '270°'),
    ]) {
      final projDist = delta.dx * dir.dx + delta.dy * dir.dy;
      if (projDist > 0) {
        final projPoint = anchor + dir * projDist;
        final dErr = (rawPoint - projPoint).distance;
        if (dErr <= toleranceMeters) {
          final guideSpan = math.max(projDist * 1.5, 4.0);
          candidates.add((
            point: projPoint,
            label: deg,
            guides: [(anchor - dir * (guideSpan * 0.2), anchor + dir * guideSpan)],
            diff: dErr,
          ));
        }
      }
    }

    if (candidates.isEmpty) return (rawPoint, null, const []);
    candidates.sort((a, b) => a.diff.compareTo(b.diff));
    final best = candidates.first;
    return (best.point, best.label, best.guides);
  }

  /// Splits a polyline chain into two sub-chains along the intersection with cut line [cutStart]->[cutEnd].
  static (List<Offset>, List<Offset>)? splitPolyline(
    List<Offset> points,
    Offset cutStart,
    Offset cutEnd,
  ) {
    if (points.length < 2) return null;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final hit = BimLineGeometry.intersection(
        cutStart,
        cutEnd,
        a,
        b,
        firstFinite: false,
        secondFinite: true,
      );
      if (hit != null && (hit - a).distance > 1e-3 && (hit - b).distance > 1e-3) {
        final part1 = [...points.sublist(0, i + 1), hit];
        final part2 = [hit, ...points.sublist(i + 1)];
        return (part1, part2);
      }
    }
    return null;
  }
}
