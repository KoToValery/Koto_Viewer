import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../bim_editing/geometry/bim_transform_2d.dart';
import '../models/architect_contour.dart';
import '../models/architect_elevation.dart';
import '../models/architect_project.dart';
import 'architect_rotation.dart';

/// Shared Project North / True North orientation math and atomic model
/// alignment for Site Plan, ground storeys (`<= ±0.00`), 2D camera, and sheets.
///
/// Sign convention:
/// - Both [ArchitectNorthSymbol.angle] and [BimCoordinateFrame.rotationRadians]
///   measure clockwise radians from plan-up (`-Y`) in Y-down model space.
/// - Viewing a Site Plan in True North therefore rotates the viewport/sheet by
///   `-northAngle`, returning the geodetic survey underlay to its original 0°.
abstract final class ArchitectSiteOrientation {
  static const double _eps = 1e-9;

  /// Normalizes [radians] into `(-pi, pi]`.
  static double normalizeAngle(double radians) {
    if (!radians.isFinite) return 0.0;
    var a = radians % (2 * math.pi);
    if (a > math.pi) a -= 2 * math.pi;
    if (a <= -math.pi) a += 2 * math.pi;
    return a.abs() < _eps ? 0.0 : a;
  }

  /// True North camera/sheet rotation in radians (`-northAngle`).
  static double trueNorthViewRotationRad(ArchitectProject project) {
    final north = project.northSymbol?.angle ?? 0.0;
    return normalizeAngle(-north);
  }

  /// True North sheet rotation in degrees (`-northAngle * 180 / pi`).
  static double trueNorthSheetRotationDeg(ArchitectProject project) =>
      trueNorthViewRotationRad(project) * 180.0 / math.pi;

  /// Returns an ISO-readable local text rotation angle (in model coordinates)
  /// for a label aligned to [lineAngleRad] when the view is rotated by
  /// [viewRotationRad]. Guarantees text never renders upside down on screen or
  /// on a rotated sheet.
  static double readableLineAngle(
    double lineAngleRad, {
    double viewRotationRad = 0.0,
  }) {
    final net = normalizeAngle(lineAngleRad + viewRotationRad);
    // Upside down if pointing left (`net > pi/2 + tol` or `net <= -pi/2 + tol`).
    if (net > math.pi / 2 + 0.02 || net <= -math.pi / 2 + 0.02) {
      return normalizeAngle(lineAngleRad + math.pi);
    }
    return normalizeAngle(lineAngleRad);
  }

  /// True if any building or roof storey already contains drafted geometry.
  static bool hasBuildingGeometry(ArchitectProject project) {
    for (final s in project.storeys) {
      if (s.isSite) continue;
      if (s.walls.isNotEmpty ||
          s.columns.isNotEmpty ||
          s.beams.isNotEmpty ||
          s.slabs.isNotEmpty ||
          s.ceilings.isNotEmpty ||
          s.roofs.isNotEmpty ||
          s.openings.isNotEmpty ||
          s.stairs.isNotEmpty ||
          s.cadPrimitives.isNotEmpty ||
          s.components.isNotEmpty ||
          s.decorativeElements.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Computes the rotation [deltaRad] needed to align the model segment
  /// `[start -> end]` to one of the four orthogonal directions in Project North:
  /// - `quarterTurns = 0`: `+X` (horizontal right / bottom edge)
  /// - `quarterTurns = 1`: `+Y` (vertical down / right edge)
  /// - `quarterTurns = 2`: `-X` (horizontal left / top edge)
  /// - `quarterTurns = 3`: `-Y` (vertical up / left edge)
  static double deltaToAlignSegment(
    Offset start,
    Offset end, {
    int quarterTurns = 0,
  }) {
    final v = end - start;
    if (v.distanceSquared < 1e-12) return 0.0;
    final current = math.atan2(v.dy, v.dx);
    final target = (quarterTurns % 4) * (math.pi / 2);
    return normalizeAngle(target - current);
  }

  /// Atomically rotates the site (geodetic underlay, raster underlays on site,
  /// existing & proposed terrain, geodetic survey, site storey elements, and
  /// [ArchitectNorthSymbol]) around [pivot] by [deltaRad].
  ///
  /// When [rotateBuilding] is true, all building/roof storeys, grid axes,
  /// sections, elevations, and non-site underlays rotate with the site so an
  /// already-drafted building keeps its exact position on the plot.
  static ArchitectProject align({
    required ArchitectProject project,
    required Offset pivot,
    required double deltaRad,
    BimCoordinateFrame fallbackFrame = const BimCoordinateFrame(),
    bool rotateBuilding = false,
    Offset? defaultNorthPosition,
  }) {
    final angle = normalizeAngle(deltaRad);
    if (!pivot.dx.isFinite || !pivot.dy.isFinite || angle.abs() < _eps) {
      return project;
    }

    Offset turn(Offset p) => BimTransform2D.rotate(p, pivot, angle);
    final siteStoreyId = project.siteStorey?.id;

    // 1. Rotate CAD underlays (site only, or all if rotating building too).
    ArchitectCadUnderlayConfig rotateCadConfig(
      ArchitectCadUnderlayConfig cfg,
    ) {
      final nextFrame = cfg.frame(fallbackFrame).rotatingAround(pivot, angle);
      return cfg.withFrame(
        nextFrame,
        transformMask: true,
        fallback: fallbackFrame,
      );
    }

    final nextCadUnderlays = <String, ArchitectCadUnderlayConfig>{
      for (final entry in project.cadUnderlays.entries)
        entry.key:
            (rotateBuilding || entry.key == siteStoreyId || siteStoreyId == null)
            ? rotateCadConfig(entry.value)
            : entry.value,
    };
    final nextTechCadUnderlays = [
      for (final cfg in project.technicalCadUnderlays)
        (rotateBuilding || cfg.storeyId == siteStoreyId)
            ? rotateCadConfig(cfg)
            : cfg,
    ];

    // 2. Rotate Raster underlays (site only, or all if rotating building too).
    final nextRasterUnderlays = [
      for (final raster in project.rasterUnderlays)
        (rotateBuilding || raster.storeyId == siteStoreyId)
            ? raster.rotatingAround(pivot, angle)
            : raster,
    ];

    // 3. Rotate existing & proposed terrain surfaces.
    final nextExistingTerrain = _rotateTerrain(
      project.existingTerrain,
      pivot,
      angle,
    );
    final nextProposedTerrain = _rotateTerrain(
      project.proposedTerrain,
      pivot,
      angle,
    );

    // 4. Rotate geodetic survey contours & spot elevations (model coords only;
    // original geodeticX / geodeticY stay intact!).
    final nextSurvey = project.geodeticSurvey == null
        ? null
        : _rotateGeodeticSurvey(project.geodeticSurvey!, turn);

    // 5. Rotate site storey (and optionally building/roof storeys).
    final nextStoreys = [
      for (final storey in project.storeys)
        (storey.isSite || rotateBuilding)
            ? _rotateStorey(storey, pivot, angle)
            : storey,
    ];

    // 6. Optionally rotate project-wide grid axes, sections, elevations.
    final nextAxes = rotateBuilding
        ? [
            for (final axis in project.gridAxes)
              axis.copyWith(start: turn(axis.start), end: turn(axis.end)),
          ]
        : project.gridAxes;
    final nextSections = rotateBuilding
        ? [
            for (final sec in project.sections)
              sec.copyWith(start: turn(sec.start), end: turn(sec.end)),
          ]
        : project.sections;
    final nextElevations = rotateBuilding
        ? [
            for (final el in project.elevations)
              el.copyWith(start: turn(el.start), end: turn(el.end)),
          ]
        : project.elevations;

    // 7. Update / create ArchitectNorthSymbol with synchronized True North.
    final prevNorth = project.northSymbol;
    final nextNorthAngle = normalizeAngle((prevNorth?.angle ?? 0.0) + angle);
    final nextNorthPos = prevNorth != null
        ? turn(prevNorth.position)
        : (defaultNorthPosition ?? pivot);
    final nextNorth = ArchitectNorthSymbol(
      position: nextNorthPos,
      angle: nextNorthAngle,
    );

    // 8. Synchronize sheet placements locked to True North so existing layouts
    // stay aligned with the updated North angle.
    final nextTrueNorthDeg = normalizeAngle(-nextNorthAngle) * 180.0 / math.pi;
    final nextDocument = project.document.copyWith(
      sheets: [
        for (final sheet in project.document.sheets)
          sheet.copyWith(
            placements: [
              for (final pl in sheet.placements)
                pl.orientation == ArchitectPlacementOrientation.trueNorth
                    ? pl.copyWith(rotation: nextTrueNorthDeg)
                    : pl,
            ],
          ),
      ],
    );

    return project.copyWith(
      storeys: nextStoreys,
      gridAxes: nextAxes,
      sections: nextSections,
      elevations: nextElevations,
      cadUnderlays: nextCadUnderlays,
      technicalCadUnderlays: nextTechCadUnderlays,
      rasterUnderlays: nextRasterUnderlays,
      existingTerrain: nextExistingTerrain,
      proposedTerrain: nextProposedTerrain,
      geodeticSurvey: nextSurvey,
      northSymbol: nextNorth,
      document: nextDocument,
      updatedAt: DateTime.now(),
    );
  }

  static ArchitectTerrainSurface _rotateTerrain(
    ArchitectTerrainSurface surface,
    Offset pivot,
    double angle,
  ) {
    if (surface.isEmpty) return surface;
    Offset turn(Offset p) => BimTransform2D.rotate(p, pivot, angle);
    return surface.copyWith(
      boundaries: [
        for (final b in surface.boundaries)
          b.copyWith(polygon: [for (final p in b.polygon) turn(p)]),
      ],
      contours: [
        for (final c in surface.contours)
          c.copyWith(points: [for (final p in c.points) turn(p)]),
      ],
      spots: [
        for (final sp in surface.spots) sp.copyWith(position: turn(sp.position)),
      ],
    );
  }

  static ArchitectGeodeticSurvey _rotateGeodeticSurvey(
    ArchitectGeodeticSurvey survey,
    Offset Function(Offset) turn,
  ) {
    return ArchitectGeodeticSurvey(
      coordinateSystemId: survey.coordinateSystemId,
      geodeticOriginX: survey.geodeticOriginX,
      geodeticOriginY: survey.geodeticOriginY,
      unitsPerMeter: survey.unitsPerMeter,
      buildingZeroElevation: survey.buildingZeroElevation,
      contours: [
        for (final c in survey.contours)
          ArchitectGeodeticContour(
            id: c.id,
            storeyId: c.storeyId,
            points: [for (final p in c.points) turn(p)],
            elevation: c.elevation,
            isMajor: c.isMajor,
            closed: c.closed,
            sourceLayer: c.sourceLayer,
          ),
      ],
      spotElevations: [
        for (final sp in survey.spotElevations)
          ArchitectGeodeticPoint(
            id: sp.id,
            storeyId: sp.storeyId,
            position: turn(sp.position),
            geodeticX: sp.geodeticX,
            geodeticY: sp.geodeticY,
            elevation: sp.elevation,
            sourceLayer: sp.sourceLayer,
          ),
      ],
    );
  }

  static ArchitectStorey _rotateStorey(
    ArchitectStorey storey,
    Offset pivot,
    double angle,
  ) {
    Offset turn(Offset p) => BimTransform2D.rotate(p, pivot, angle);
    final ids = storey.groupableIds;
    var rotated = ids.isEmpty
        ? storey
        : ArchitectRotation.apply(storey, ids, pivot, angle);

    // Rotate collections not handled by ArchitectRotation.apply:
    // auto-boundary zones, ceilings, decorative elements, pathways, vegetation,
    // site fences, streets, and zoneScheduleOrigin.
    final angleDeg = angle * 180.0 / math.pi;
    rotated = rotated.copyWith(
      zones: [
        for (final z in rotated.zones)
          z.isAutoBoundary
              ? z.copyWith(
                  polygon: [for (final p in z.polygon) turn(p)],
                  seedPoint: z.seedPoint == null ? null : turn(z.seedPoint!),
                )
              : z,
      ],
      ceilings: [
        for (final c in rotated.ceilings)
          c.copyWith(
            polygon: [for (final p in c.polygon) turn(p)],
            holes: ArchitectContour.transform(c.holes, turn),
            gridOrigin: c.gridOrigin == null ? null : turn(c.gridOrigin!),
            gridAngle: (c.gridAngle + angleDeg) % 360,
            seedPoint: c.seedPoint == null ? null : turn(c.seedPoint!),
          ),
      ],
      decorativeElements: [
        for (final d in rotated.decorativeElements)
          d.rotatedInPlan(pivot, angle),
      ],
      pathways: [
        for (final e in rotated.pathways)
          e.copyWith(points: [for (final p in e.points) turn(p)]),
      ],
      vegetation: [
        for (final e in rotated.vegetation)
          e.copyWith(
            position: turn(e.position),
            points: [for (final p in e.points) turn(p)],
          ),
      ],
      siteFences: [
        for (final e in rotated.siteFences)
          e.copyWith(points: [for (final p in e.points) turn(p)]),
      ],
      streets: [
        for (final e in rotated.streets)
          e.copyWith(points: [for (final p in e.points) turn(p)]),
      ],
      zoneScheduleOrigin: rotated.zoneScheduleOrigin == null
          ? null
          : turn(rotated.zoneScheduleOrigin!),
    );
    return rotated;
  }
}
