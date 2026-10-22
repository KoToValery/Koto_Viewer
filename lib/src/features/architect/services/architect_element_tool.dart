// === SECTION: ARCHITECTURAL ELEMENT TOOL ===
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'architect_element_id.dart';
import '../adapters/architect_element_adapters.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../rendering/architect_dimension_layout.dart';
import '../models/architect_project.dart';
import '../models/architect_grid_axis.dart';
import '../models/architect_door.dart';
import '../models/architect_wall.dart';
import '../models/architect_window.dart';
import '../models/architect_fenestration_style.dart';
import '../models/architect_zone.dart';
import '../../bim_editing/geometry/bim_transform_2d.dart';
import '../rendering/architect_2d_painter.dart' show ArchitectTool;
import 'architect_wall_relations.dart';

/// Unified controller and interaction manager for specialized architectural drafting elements
/// (windows, columns, beams, slabs, openings, stairs, dimensions, elevation markers, annotations, and CAD primitives).
class ArchitectElementTool extends ChangeNotifier {
  // Window options
  double windowWidth = 1.20;
  double windowHeight = 1.40;
  double windowSill = 0.85;
  ArchitectFenestrationStyle? activeWindowStyle;
  ArchitectFenestrationStyle? activeDoorStyle;

  // Column options
  ColumnShape columnShape = ColumnShape.rectangular;
  double columnWidth = 0.25;
  double columnDepth = 0.25;

  // Beam options
  double beamWidth = 0.25;
  double beamDepth = 0.40;

  // Stair options
  double stairWidth = 1.20;
  int stairSteps = 16;
  ArchitectStairDesign stairDesign = const ArchitectStairDesign();

  // Opening options
  OpeningType openingType = OpeningType.shaft;

  // Slab drafting state
  final List<Offset> slabDraftPoints = [];
  Offset? slabCandidatePoint;

  // Measurement tool state
  Offset? measureStart;
  Offset? measureEnd;

  // ===========================================================================
  // 1. CONFIGURATION SETTERS
  // ===========================================================================

  void setWindowParams({double? width, double? height, double? sill}) {
    if (width != null) windowWidth = width;
    if (height != null) windowHeight = height;
    if (sill != null) windowSill = sill;
    notifyListeners();
  }

  void setWindowStyle(ArchitectFenestrationStyle style) {
    activeWindowStyle = style;
    windowWidth = style.defaultWidth;
    windowHeight = style.defaultHeight;
    windowSill = style.defaultSillHeight;
    notifyListeners();
  }

  void setDoorStyle(ArchitectFenestrationStyle style) {
    activeDoorStyle = style;
    notifyListeners();
  }

  void setColumnParams({ColumnShape? shape, double? width, double? depth}) {
    if (shape != null) columnShape = shape;
    if (width != null) columnWidth = width;
    if (depth != null) columnDepth = depth;
    notifyListeners();
  }

  void setBeamParams({double? width, double? depth}) {
    if (width != null) beamWidth = width;
    if (depth != null) beamDepth = depth;
    notifyListeners();
  }

  void setStairParams({double? width, int? steps, ArchitectStairDesign? design}) {
    if (width != null) stairWidth = width;
    if (steps != null) stairSteps = steps;
    if (design != null) stairDesign = design;
    notifyListeners();
  }

  void setOpeningType(OpeningType type) {
    openingType = type;
    notifyListeners();
  }

  // ===========================================================================
  // 2. WINDOW PLACEMENT
  // ===========================================================================

  (ArchitectStorey, ArchitectWindow)? placeWindow({
    required ArchitectStorey storey,
    required Offset point,
    bool magnetic = true,
  }) {
    final placement = ArchitectOpeningPlacement.resolve(
      rawPoint: point,
      walls: storey.walls,
      openingWidth: windowWidth,
      magnetic: magnetic,
    );
    if (placement == null) return null;

    final targetWall = placement.wall;
    final now = ArchitectElementId.next('element');

    final newWindow = ArchitectWindow(
      id: 'win_$now',
      wallId: targetWall.id,
      offsetRatio: placement.offsetRatio,
      width: windowWidth,
      height: windowHeight,
      sillHeight: windowSill,
      uuid: 'UUID_$now',
      styleId: activeWindowStyle?.id,
      style: activeWindowStyle,
    );

    final updatedWall = targetWall.addWindow(newWindow);
    final updatedWalls = storey.walls
        .map((w) => w.id == updatedWall.id ? updatedWall : w)
        .toList();

    return (storey.copyWith(walls: updatedWalls), newWindow);
  }

  // ===========================================================================
  // 3. COLUMN PLACEMENT
  // ===========================================================================

  (ArchitectStorey, ArchitectColumn) placeColumn({
    required ArchitectStorey storey,
    required Offset point,
    double rotationDeg = 0.0,
    String? label,
    Iterable<ArchitectColumn>? existingColumns,
  }) {
    final now = ArchitectElementId.next('element');
    final effectiveExisting = existingColumns ?? storey.columns;
    final colLabel = label ?? nextColumnLabel(effectiveExisting);
    final newColumn = ArchitectColumn(
      id: 'col_$now',
      position: point,
      shape: columnShape,
      width: columnWidth,
      depth: columnDepth,
      rotationDeg: rotationDeg,
      label: colLabel,
    );

    return (
      storey.copyWith(columns: [...storey.columns, newColumn]),
      newColumn,
    );
  }

  /// Calculates the next sequential column label (e.g. C1, C2, C3 or K1, K2...).
  static String nextColumnLabel(Iterable<ArchitectColumn> existing) {
    var maxNum = 0;
    String prefix = 'C';
    final regex = RegExp(r'^([A-Za-zА-Яа-я]+)?(\d+)$');
    for (final col in existing) {
      final m = regex.firstMatch(col.label.trim());
      if (m != null) {
        if (m.group(1) != null && m.group(1)!.isNotEmpty) {
          prefix = m.group(1)!;
        }
        final val = int.tryParse(m.group(2)!);
        if (val != null && val > maxNum) {
          maxNum = val;
        }
      }
    }
    return '$prefix${maxNum + 1}';
  }

  // ===========================================================================
  // 4. BEAM PLACEMENT
  // ===========================================================================

  (ArchitectStorey, ArchitectBeam)? placeBeam({
    required ArchitectStorey storey,
    required Offset start,
    required Offset end,
  }) {
    if ((end - start).distance < 0.20) return null;
    final now = ArchitectElementId.next('element');
    final newBeam = ArchitectBeam(
      id: 'beam_$now',
      startPoint: start,
      endPoint: end,
      width: beamWidth,
      depth: beamDepth,
    );

    return (storey.copyWith(beams: [...storey.beams, newBeam]), newBeam);
  }

  // ===========================================================================
  // 5. SLAB DRAFTING
  // ===========================================================================

  bool addSlabPoint(Offset point) {
    if (slabDraftPoints.isNotEmpty &&
        (point - slabDraftPoints.last).distance < 0.10) {
      return false;
    }
    slabDraftPoints.add(point);
    notifyListeners();
    return true;
  }

  void updateSlabCandidate(Offset? candidate) {
    slabCandidatePoint = candidate;
    notifyListeners();
  }

  (ArchitectStorey, ArchitectSlab)? commitSlab({
    required ArchitectStorey storey,
    double thickness = 0.16,
  }) {
    if (slabDraftPoints.length < 3) return null;
    final now = ArchitectElementId.next('element');
    final newSlab = ArchitectSlab(
      id: 'slab_$now',
      polygon: List<Offset>.from(slabDraftPoints),
      thickness: thickness,
      label: 'Slab ${storey.slabs.length + 1}',
    );

    slabDraftPoints.clear();
    slabCandidatePoint = null;
    notifyListeners();

    return (storey.copyWith(slabs: [...storey.slabs, newSlab]), newSlab);
  }

  void cancelSlabDrafting() {
    slabDraftPoints.clear();
    slabCandidatePoint = null;
    notifyListeners();
  }

  // ===========================================================================
  // 6. OPENING PLACEMENT
  // ===========================================================================

  (ArchitectStorey, ArchitectOpening)? placeOpening({
    required ArchitectStorey storey,
    required Offset p1,
    required Offset p2,
  }) {
    final rect = Rect.fromPoints(p1, p2);
    if (rect.width < 0.15 || rect.height < 0.15) return null;
    final now = ArchitectElementId.next('element');
    final boundary = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    final newOpening = ArchitectOpening(
      id: 'op_$now',
      boundary: boundary,
      type: openingType,
      label: 'Opening ${storey.openings.length + 1}',
    );

    return (
      storey.copyWith(openings: [...storey.openings, newOpening]),
      newOpening,
    );
  }

  // ===========================================================================
  // 7. STAIR PLACEMENT
  // ===========================================================================

  (ArchitectStorey, ArchitectStair)? placeStair({
    required ArchitectStorey storey,
    required Offset start,
    required Offset end,
  }) {
    if ((end - start).distance < 0.40) return null;
    final now = ArchitectElementId.next('element');
    final newStair = ArchitectStair(
      id: 'stair_$now',
      startPoint: start,
      endPoint: end,
      width: stairWidth,
      stepCount: stairSteps,
    );

    return (storey.copyWith(stairs: [...storey.stairs, newStair]), newStair);
  }

  // ===========================================================================
  // 8. DIMENSION PLACEMENT
  // ===========================================================================

  (ArchitectStorey, ArchitectDimension)? placeDimension({
    required ArchitectStorey storey,
    required Offset start,
    required Offset end,
  }) {
    if ((end - start).distance < 0.10) return null;
    final now = ArchitectElementId.next('element');
    final newDim = ArchitectDimension(
      id: 'dim_$now',
      startPoint: start,
      endPoint: end,
    );

    return (
      storey.copyWith(dimensions: [...storey.dimensions, newDim]),
      newDim,
    );
  }

  // ===========================================================================
  // 9. ELEVATION MARKER PLACEMENT
  // ===========================================================================

  (ArchitectStorey, ArchitectElevationMarker) placeElevationMarker({
    required ArchitectStorey storey,
    required Offset point,
    required double elevation,
  }) {
    final now = ArchitectElementId.next('element');
    final newMarker = ArchitectElevationMarker(
      id: 'elev_$now',
      position: point,
      elevation: elevation,
    );

    return (
      storey.copyWith(
        elevationMarkers: [...storey.elevationMarkers, newMarker],
      ),
      newMarker,
    );
  }

  // ===========================================================================
  // 10. ANNOTATION PLACEMENT
  // ===========================================================================

  (ArchitectStorey, ArchitectAnnotation) placeAnnotation({
    required ArchitectStorey storey,
    required Offset point,
    required String text,
    double fontSize = 0.25,
  }) {
    final now = ArchitectElementId.next('element');
    final newAnnotation = ArchitectAnnotation(
      id: 'ann_$now',
      position: point,
      text: text,
      fontSize: fontSize,
    );

    return (
      storey.copyWith(annotations: [...storey.annotations, newAnnotation]),
      newAnnotation,
    );
  }

  // ===========================================================================
  // 11. CAD PRIMITIVE PLACEMENT
  // ===========================================================================

  (ArchitectStorey, ArchitectCadPrimitive)? placeCadPrimitive({
    required ArchitectStorey storey,
    required CadPrimitiveType type,
    required Offset start,
    required Offset end,
    int colorValue = 0xFF9E9E9E,
    double strokeWidth = 1.0,
  }) {
    if ((end - start).distance < .001) {
      return null;
    }
    final now = ArchitectElementId.next('element');
    final newPrim = ArchitectCadPrimitive(
      id: 'cad_$now',
      type: type,
      startPoint: start,
      endPoint: end,
      colorValue: colorValue,
      strokeWidth: strokeWidth,
    );

    return (
      storey.copyWith(cadPrimitives: [...storey.cadPrimitives, newPrim]),
      newPrim,
    );
  }

  // ===========================================================================
  // 12. ELEMENT HIT TESTING (SELECT TOOL)
  // ===========================================================================

  /// Filter before hit testing so overlapping objects of other tools cannot
  /// capture a selection (including a door's host wall).
  Iterable<String> hitTestElementsForTool(
    ArchitectStorey storey,
    Offset point,
    double scale,
    ArchitectTool tool, {
    List<StructuralGridAxis> gridAxes = const [],
    ArchitectProject? annotationProject,
    String? drawingViewKey,
  }) {
    if (tool == ArchitectTool.select) {
      return hitTestElements(
        storey,
        point,
        scale,
        gridAxes: gridAxes,
        annotationProject: annotationProject,
        drawingViewKey: drawingViewKey,
      );
    }
    final scoped = storey.copyWith(
      walls: [
        if ([
          ArchitectTool.wall,
          ArchitectTool.door,
          ArchitectTool.window,
        ].contains(tool))
          for (final wall in storey.walls)
            wall.copyWith(
              doors: tool == ArchitectTool.door ? wall.doors : [],
              windows: tool == ArchitectTool.window ? wall.windows : [],
            ),
      ],
      columns: tool == ArchitectTool.column ? storey.columns : [],
      beams: tool == ArchitectTool.beam ? storey.beams : [],
      slabs: tool == ArchitectTool.slab ? storey.slabs : [],
      roofs: tool == ArchitectTool.roof ? storey.roofs : [],
      openings: tool == ArchitectTool.opening ? storey.openings : [],
      stairs: tool == ArchitectTool.stair ? storey.stairs : [],
      dimensions: tool == ArchitectTool.dimension ? storey.dimensions : [],
      annotations: tool == ArchitectTool.text ? storey.annotations : [],
      elevationMarkers: tool == ArchitectTool.level
          ? storey.elevationMarkers
          : [],
      components: tool == ArchitectTool.component ? storey.components : [],
      zones: tool == ArchitectTool.zone ? storey.zones : [],
      cadPrimitives: storey.cadPrimitives
          .where(
            (p) => switch (tool) {
              ArchitectTool.cadLine => p.type == CadPrimitiveType.line,
              ArchitectTool.cadRect => p.type == CadPrimitiveType.rect,
              ArchitectTool.cadCircle => p.type == CadPrimitiveType.circle,
              _ => false,
            },
          )
          .toList(),
    );
    return hitTestElements(
      scoped,
      point,
      scale,
      gridAxes: gridAxes,
      dimensionStorey: storey,
      annotationProject: annotationProject,
      drawingViewKey: drawingViewKey,
    ).where((id) => tool == ArchitectTool.wall || !scoped.walls.any((w) => w.id == id));
  }

  String? hitTestForTool(
    ArchitectStorey storey,
    Offset point,
    double scale,
    ArchitectTool tool, {
    List<StructuralGridAxis> gridAxes = const [],
    ArchitectProject? annotationProject,
    String? drawingViewKey,
  }) =>
      hitTestElementsForTool(
        storey,
        point,
        scale,
        tool,
        gridAxes: gridAxes,
        annotationProject: annotationProject,
        drawingViewKey: drawingViewKey,
      ).firstOrNull;

  String? hitTestElement(
    ArchitectStorey storey,
    Offset point,
    double scale, {
    List<StructuralGridAxis> gridAxes = const [],
    ArchitectStorey? dimensionStorey,
    ArchitectProject? annotationProject,
    String? drawingViewKey,
  }) => hitTestElements(
    storey,
    point,
    scale,
    gridAxes: gridAxes,
    dimensionStorey: dimensionStorey,
    annotationProject: annotationProject,
    drawingViewKey: drawingViewKey,
  ).firstOrNull;

  Iterable<String> hitTestElements(
    ArchitectStorey storey,
    Offset point,
    double scale, {
    List<StructuralGridAxis> gridAxes = const [],
    ArchitectStorey? dimensionStorey,
    ArchitectProject? annotationProject,
    String? drawingViewKey,
  }) sync* {
    final tolerance = 14.0 / scale;

    // Check Columns
    for (final col in storey.columns) {
      if (col.containsPoint(point, tolerance: tolerance)) {
        yield col.id;
      }
    }

    // Check Hosted Windows
    for (final wall in storey.walls) {
      for (final win in wall.windows) {
        if (win.containsPoint(
          point,
          wallStart: wall.openingAxis(win.offsetRatio).$1,
          wallEnd: wall.openingAxis(win.offsetRatio).$2,
          wallThickness: wall.thickness,
          tolerance: tolerance,
          exteriorSign: wall.exteriorSign.toDouble(),
        )) {
          yield win.id;
        }
      }
      for (final door in wall.doors) {
        if (door.containsPoint(
          point,
          wallStart: wall.openingAxis(door.offsetRatio).$1,
          wallEnd: wall.openingAxis(door.offsetRatio).$2,
          wallThickness: wall.thickness,
          tolerance: tolerance,
        )) {
          yield door.id;
        }
      }
    }

    // Check Beams
    for (final beam in storey.beams) {
      final dist = _pointToSegmentDistance(
        point,
        beam.startPoint,
        beam.endPoint,
      );
      if (dist <= beam.width / 2.0 + tolerance) {
        yield beam.id;
      }
    }

    // Check Stairs
    for (final stair in storey.stairs) {
      if (stair.plan.contains(point, tolerance)) {
        yield stair.id;
      }
    }

    // Check Openings
    for (final op in storey.openings) {
      if (op.boundary.length >= 2) {
        final r = Rect.fromPoints(
          op.boundary.first,
          op.boundary[2 % op.boundary.length],
        ).inflate(tolerance);
        if (r.contains(point)) {
          yield op.id;
        }
      }
    }

    // Check Dimensions
    for (final dim in storey.dimensions) {
      final tiers = ArchitectDimensionLayout.layoutTiers(
        dimension: dim,
        scale: scale,
        storey: dimensionStorey ?? storey,
        gridAxes: gridAxes,
        dimensionScale: annotationProject?.dimensionScale,
        document: annotationProject?.document,
        viewKey: drawingViewKey ?? 'plan:${storey.id}',
      );
      bool hit = false;
      for (final tier in tiers) {
        if (_pointToSegmentDistance(point, tier.line.$1, tier.line.$2) <=
            tolerance) {
          hit = true;
          break;
        }
      }
      if (hit) {
        yield dim.id;
      }
    }

    // Check Elevation Markers
    for (final el in storey.elevationMarkers) {
      if ((point - el.position).distance <= 0.40 + tolerance) {
        yield el.id;
      }
    }

    // Check Annotations
    for (final ann in storey.annotations) {
      if ((point - ann.position).distance <= 0.60 + tolerance) {
        yield ann.id;
      }
    }

    // Check CAD Primitives
    for (final prim in storey.cadPrimitives) {
      if (prim.type == CadPrimitiveType.line) {
        if (_pointToSegmentDistance(point, prim.startPoint, prim.endPoint) <=
            tolerance) {
          yield prim.id;
        }
      } else if (prim.type == CadPrimitiveType.rect) {
        final points = prim.polygonCorners;
        final path = Path()..addPolygon(points, true);
        if (path.contains(point)) yield prim.id;
        for (var i = 0; i < points.length; i++) {
          if (_pointToSegmentDistance(
                point,
                points[i],
                points[(i + 1) % points.length],
              ) <=
              tolerance) {
            yield prim.id;
          }
        }
      } else if (prim.type == CadPrimitiveType.circle) {
        final rad = (prim.endPoint - prim.startPoint).distance;
        final d = (point - prim.startPoint).distance;
        if ((d - rad).abs() <= tolerance) yield prim.id;
      }
    }

    // Check Walls
    for (final wall in storey.walls) {
      if (wall.containsPoint(point)) {
        yield wall.id;
      }
    }

    // Check Roofs
    for (final roof in storey.roofs.reversed) {
      if (roof.containsPoint(point)) {
        yield roof.id;
      }
    }

    // Check Slabs
    for (final slab in storey.slabs) {
      if (slab.containsPoint(point)) {
        yield slab.id;
      }
    }
  }

  // ===========================================================================
  // 13. ELEMENT DELETION
  // ===========================================================================

  ArchitectStorey deleteElementById(ArchitectStorey storey, String elementId) {
    return storey.copyWith(
      walls: storey.walls
          .map(
            (w) => w.copyWith(
              doors: w.doors.where((d) => d.id != elementId).toList(),
              windows: w.windows.where((win) => win.id != elementId).toList(),
            ),
          )
          .where((w) => w.id != elementId)
          .toList(),
      columns: storey.columns.where((c) => c.id != elementId).toList(),
      beams: storey.beams.where((b) => b.id != elementId).toList(),
      slabs: storey.slabs.where((s) => s.id != elementId).toList(),
      roofs: storey.roofs.where((r) => r.id != elementId).toList(),
      openings: storey.openings.where((o) => o.id != elementId).toList(),
      stairs: storey.stairs.where((s) => s.id != elementId).toList(),
      dimensions: storey.dimensions.where((d) => d.id != elementId).toList(),
      elevationMarkers: storey.elevationMarkers
          .where((e) => e.id != elementId)
          .toList(),
      annotations: storey.annotations.where((a) => a.id != elementId).toList(),
      cadPrimitives: storey.cadPrimitives
          .where((c) => c.id != elementId)
          .toList(),
    );
  }

  // ===========================================================================
  // 14. ELEMENT TRANSFORMS (DUPLICATE, ROTATE, FLIP)
  // ===========================================================================

  (ArchitectStorey, String?) duplicateElementById(
    ArchitectStorey storey,
    String elementId, {
    Offset offset = const Offset(0.5, 0.5),
  }) {
    final newId = ArchitectElementId.next('copy');

    // 1. Column
    final colIndex = storey.columns.indexWhere((c) => c.id == elementId);
    if (colIndex != -1) {
      final col = storey.columns[colIndex];
      final newCol = const ArchitectColumnEditingAdapter().translate(
        col.copyWith(id: newId),
        offset,
      );
      return (storey.copyWith(columns: [...storey.columns, newCol]), newId);
    }

    // 2. Wall
    final wallIndex = storey.walls.indexWhere((w) => w.id == elementId);
    if (wallIndex != -1) {
      final wall = storey.walls[wallIndex];
      final clone = wall.copyWith(
        id: newId,
        doors: [
          for (final door in wall.doors)
            door.copyWith(
              id: ArchitectElementId.next('door'),
              wallId: newId,
              uuid: ArchitectElementId.next('UUID'),
            ),
        ],
        windows: [
          for (final window in wall.windows)
            window.copyWith(
              id: ArchitectElementId.next('window'),
              wallId: newId,
              uuid: ArchitectElementId.next('UUID'),
            ),
        ],
      );
      final newWall = const ArchitectWallEditingAdapter().translate(
        clone,
        offset,
      );
      return (storey.copyWith(walls: [...storey.walls, newWall]), newId);
    }

    // 3. Slab
    final slabIndex = storey.slabs.indexWhere((s) => s.id == elementId);
    if (slabIndex != -1) {
      final slab = storey.slabs[slabIndex];
      final newSlab = const ArchitectSlabEditingAdapter().translate(
        slab.copyWith(id: newId),
        offset,
      );
      return (storey.copyWith(slabs: [...storey.slabs, newSlab]), newId);
    }

    // 3b. Roof
    final roofIndex = storey.roofs.indexWhere((r) => r.id == elementId);
    if (roofIndex != -1) {
      final roof = storey.roofs[roofIndex];
      final newRoof = const ArchitectRoofEditingAdapter().translate(
        roof.copyWith(id: newId),
        offset,
      );
      return (storey.copyWith(roofs: [...storey.roofs, newRoof]), newId);
    }

    // 4. CAD Primitive
    final cadIndex = storey.cadPrimitives.indexWhere((c) => c.id == elementId);
    if (cadIndex != -1) {
      final prim = storey.cadPrimitives[cadIndex];
      final newPrim = const ArchitectCadEditingAdapter().translate(
        prim.copyWith(id: newId),
        offset,
      );
      return (
        storey.copyWith(cadPrimitives: [...storey.cadPrimitives, newPrim]),
        newId,
      );
    }

    // 5. Zone
    final zoneIndex = storey.zones.indexWhere((z) => z.id == elementId);
    if (zoneIndex != -1) {
      final zone = storey.zones[zoneIndex];
      final newZone = const ArchitectZoneEditingAdapter().translate(
        zone.copyWith(id: newId, isAutoBoundary: false, clearScheduleOrigin: true),
        offset,
      );
      return (storey.copyWith(zones: [...storey.zones, newZone]), newId);
    }

    // 6. Beam
    final beamIndex = storey.beams.indexWhere((b) => b.id == elementId);
    if (beamIndex != -1) {
      final beam = storey.beams[beamIndex];
      final newBeam = const ArchitectBeamEditingAdapter().translate(
        beam.copyWith(id: newId),
        offset,
      );
      return (storey.copyWith(beams: [...storey.beams, newBeam]), newId);
    }

    return (storey, null);
  }

  ArchitectStorey rotateElementById(ArchitectStorey storey, String elementId) {
    // 1. Column (rotate 90 degrees)
    final colIndex = storey.columns.indexWhere((c) => c.id == elementId);
    if (colIndex != -1) {
      final col = storey.columns[colIndex];
      final newCols = List<ArchitectColumn>.from(storey.columns);
      newCols[colIndex] = const ArchitectColumnEditingAdapter().rotate(
        col,
        math.pi / 2,
      );
      return storey.copyWith(columns: newCols);
    }

    final beamIndex = storey.beams.indexWhere((b) => b.id == elementId);
    if (beamIndex != -1) {
      final beams = List<ArchitectBeam>.from(storey.beams);
      beams[beamIndex] = const ArchitectBeamEditingAdapter().rotate(
        beams[beamIndex],
        math.pi / 2,
      );
      return storey.copyWith(beams: beams);
    }

    // 2. Wall (rotate 90 degrees around center)
    final wallIndex = storey.walls.indexWhere((w) => w.id == elementId);
    if (wallIndex != -1) {
      final wall = storey.walls[wallIndex];
      final mid = (wall.startPoint + wall.endPoint) / 2;
      final delta = wall.endPoint - wall.startPoint;
      final perp = Offset(-delta.dy, delta.dx) / 2;
      final newWalls = List<ArchitectWall>.from(storey.walls);
      newWalls[wallIndex] = wall.copyWith(
        startPoint: mid - perp,
        endPoint: mid + perp,
      );
      return storey.copyWith(walls: newWalls);
    }

    // 3. Slab (rotate 90 degrees around centroid)
    final slabIndex = storey.slabs.indexWhere((s) => s.id == elementId);
    if (slabIndex != -1) {
      final slab = storey.slabs[slabIndex];
      if (slab.polygon.isNotEmpty) {
        final center =
            slab.polygon.reduce((a, b) => a + b) /
            slab.polygon.length.toDouble();
        final rotatedPoly = slab.polygon.map((p) {
          final rel = p - center;
          return center + Offset(-rel.dy, rel.dx);
        }).toList();
        final newSlabs = List<ArchitectSlab>.from(storey.slabs);
        newSlabs[slabIndex] = slab.copyWith(
          polygon: rotatedPoly,
          slopeDirection: slab.slopeDirection == null ? null : slab.slopeDirection! + math.pi / 2,
        );
        return storey.copyWith(slabs: newSlabs);
      }
    }

    // 3b. Roof (rotate 90 degrees around centroid)
    final roofIndex = storey.roofs.indexWhere((r) => r.id == elementId);
    if (roofIndex != -1) {
      final roof = storey.roofs[roofIndex];
      if (roof.points.isNotEmpty) {
        final center = roof.centroid;
        final rotatedPts = roof.points.map((p) {
          final rel = p - center;
          return center + Offset(-rel.dy, rel.dx);
        }).toList();
        final newRoofs = List<ArchitectRoofPlane>.from(storey.roofs);
        newRoofs[roofIndex] = roof.copyWith(points: rotatedPts);
        return storey.copyWith(roofs: newRoofs);
      }
    }

    // 4. CAD Primitive
    final cadIndex = storey.cadPrimitives.indexWhere((c) => c.id == elementId);
    if (cadIndex != -1) {
      final prim = storey.cadPrimitives[cadIndex];
      final mid = (prim.startPoint + prim.endPoint) / 2;
      final delta = prim.endPoint - prim.startPoint;
      final perp = Offset(-delta.dy, delta.dx) / 2;
      final newCad = List<ArchitectCadPrimitive>.from(storey.cadPrimitives);
      newCad[cadIndex] = prim.copyWith(
        startPoint: mid - perp,
        endPoint: mid + perp,
      );
      return storey.copyWith(cadPrimitives: newCad);
    }

    return storey;
  }

  ArchitectStorey flipElementById(ArchitectStorey storey, String elementId) {
    // 1. Door
    for (var w = 0; w < storey.walls.length; w++) {
      final wall = storey.walls[w];
      final dIdx = wall.doors.indexWhere((d) => d.id == elementId);
      if (dIdx != -1) {
        final door = wall.doors[dIdx];
        final newDoors = List<ArchitectDoor>.from(wall.doors);
        newDoors[dIdx] = door.copyWith(isHingeLeft: !door.isHingeLeft);
        final newWalls = List<ArchitectWall>.from(storey.walls);
        newWalls[w] = wall.copyWith(doors: newDoors);
        return storey.copyWith(walls: newWalls);
      }
    }

    // 2. Wall
    final wallIndex = storey.walls.indexWhere((w) => w.id == elementId);
    if (wallIndex != -1) {
      final wall = storey.walls[wallIndex];
      final newWalls = List<ArchitectWall>.from(storey.walls);
      newWalls[wallIndex] = wall.copyWith(
        startPoint: wall.endPoint,
        endPoint: wall.startPoint,
        arcBulge:-wall.arcBulge,
        doors:[for(final d in wall.doors)d.copyWith(offsetRatio:1-d.offsetRatio,isHingeLeft:!d.isHingeLeft)],
        windows:[for(final w in wall.windows)w.copyWith(offsetRatio:1-w.offsetRatio)],
      );
      return storey.copyWith(walls: newWalls);
    }

    return storey;
  }

  (ArchitectStorey, List<String>) duplicateElementsByIds(
    ArchitectStorey storey,
    Set<String> elementIds, {
    Offset offset = const Offset(0.5, 0.5),
  }) {
    var currentStorey = storey;
    final newIds = <String>[];
    for (final id in elementIds) {
      final (updated, copyId) = duplicateElementById(
        currentStorey,
        id,
        offset: offset,
      );
      if (copyId != null) {
        currentStorey = updated;
        newIds.add(copyId);
      }
    }
    return (currentStorey, newIds);
  }

  ArchitectStorey rotateElementsByIds(
    ArchitectStorey storey,
    Set<String> elementIds,
  ) {
    var currentStorey = storey;
    for (final id in elementIds) {
      currentStorey = rotateElementById(currentStorey, id);
    }
    return currentStorey;
  }

  ArchitectStorey flipElementsByIds(
    ArchitectStorey storey,
    Set<String> elementIds,
  ) {
    var currentStorey = storey;
    for (final id in elementIds) {
      currentStorey = flipElementById(currentStorey, id);
    }
    return currentStorey;
  }

  (ArchitectStorey, String?) mirrorElementById(
    ArchitectStorey storey,
    String elementId, {
    required Offset origin,
    required Offset direction,
    bool isDuplicate = false,
    String? newId,
  }) {
    if (direction.distanceSquared < 1e-12) return (storey, null);
    final targetId =
        isDuplicate ? (newId ?? ArchitectElementId.next('mirror')) : elementId;

    // 1. Column
    final colIndex = storey.columns.indexWhere((c) => c.id == elementId);
    if (colIndex != -1) {
      final col = storey.columns[colIndex];
      final newPos = BimTransform2D.mirror(col.position, origin, direction);
      final rad = col.rotationDeg * math.pi / 180;
      final u = Offset(math.cos(rad), math.sin(rad));
      final mu = BimTransform2D.mirror(u, Offset.zero, direction);
      final newRot = (math.atan2(mu.dy, mu.dx) * 180 / math.pi) % 360;
      final newCol = col.copyWith(
        id: targetId,
        position: newPos,
        rotationDeg: newRot < 0 ? newRot + 360 : newRot,
        label: isDuplicate ? nextColumnLabel(storey.columns) : col.label,
      );
      if (isDuplicate) {
        return (
          storey.copyWith(columns: [...storey.columns, newCol]),
          targetId,
        );
      } else {
        final cols = List<ArchitectColumn>.from(storey.columns);
        cols[colIndex] = newCol;
        return (storey.copyWith(columns: cols), targetId);
      }
    }

    // 2. Wall
    final wallIndex = storey.walls.indexWhere((w) => w.id == elementId);
    if (wallIndex != -1) {
      final wall = storey.walls[wallIndex];
      final newStart = BimTransform2D.mirror(
        wall.startPoint,
        origin,
        direction,
      );
      final newEnd = BimTransform2D.mirror(wall.endPoint, origin, direction);
      final newDoors = [
        for (final d in wall.doors)
          d.copyWith(
            id: isDuplicate ? ArchitectElementId.next('door') : d.id,
            wallId: targetId,
            uuid: isDuplicate ? ArchitectElementId.next('UUID') : d.uuid,
            isHingeLeft: !d.isHingeLeft,
          ),
      ];
      final newWindows = [
        for (final w in wall.windows)
          w.copyWith(
            id: isDuplicate ? ArchitectElementId.next('window') : w.id,
            wallId: targetId,
            uuid: isDuplicate ? ArchitectElementId.next('UUID') : w.uuid,
          ),
      ];
      final newWall = wall.copyWith(
        id: targetId,
        startPoint: newStart,
        endPoint: newEnd,
        arcBulge: -wall.arcBulge,
        exteriorSide: wall.exteriorSide == WallExteriorSide.left
            ? WallExteriorSide.right
            : WallExteriorSide.left,
        doors: newDoors,
        windows: newWindows,
      );
      if (isDuplicate) {
        return (storey.copyWith(walls: [...storey.walls, newWall]), targetId);
      } else {
        final walls = List<ArchitectWall>.from(storey.walls);
        walls[wallIndex] = newWall;
        return (storey.copyWith(walls: walls), targetId);
      }
    }

    // 3. Beam
    final beamIndex = storey.beams.indexWhere((b) => b.id == elementId);
    if (beamIndex != -1) {
      final beam = storey.beams[beamIndex];
      final newBeam = beam.copyWith(
        id: targetId,
        startPoint: BimTransform2D.mirror(beam.startPoint, origin, direction),
        endPoint: BimTransform2D.mirror(beam.endPoint, origin, direction),
      );
      if (isDuplicate) {
        return (storey.copyWith(beams: [...storey.beams, newBeam]), targetId);
      } else {
        final beams = List<ArchitectBeam>.from(storey.beams);
        beams[beamIndex] = newBeam;
        return (storey.copyWith(beams: beams), targetId);
      }
    }

    // 4. Slab
    final slabIndex = storey.slabs.indexWhere((s) => s.id == elementId);
    if (slabIndex != -1) {
      final slab = storey.slabs[slabIndex];
      final newPoly = [
        for (final p in slab.polygon)
          BimTransform2D.mirror(p, origin, direction),
      ].reversed.toList();
      double? newSlope;
      if (slab.slopeDirection != null) {
        final su = Offset(
          math.cos(slab.slopeDirection!),
          math.sin(slab.slopeDirection!),
        );
        final mu = BimTransform2D.mirror(su, Offset.zero, direction);
        newSlope = math.atan2(mu.dy, mu.dx);
      }
      final newSlab = slab.copyWith(
        id: targetId,
        polygon: newPoly,
        slopeDirection: newSlope,
      );
      if (isDuplicate) {
        return (storey.copyWith(slabs: [...storey.slabs, newSlab]), targetId);
      } else {
        final slabs = List<ArchitectSlab>.from(storey.slabs);
        slabs[slabIndex] = newSlab;
        return (storey.copyWith(slabs: slabs), targetId);
      }
    }

    // 5. Roof
    final roofIndex = storey.roofs.indexWhere((r) => r.id == elementId);
    if (roofIndex != -1) {
      final roof = storey.roofs[roofIndex];
      final newPoints = [
        for (final p in roof.points)
          BimTransform2D.mirror(p, origin, direction),
      ].reversed.toList();
      final n = roof.points.length;
      final newEaves = n > 0 ? (n - 2 - roof.eavesEdgeIndex) % n : 0;
      final safeEaves = newEaves < 0 ? newEaves + n : newEaves;
      final newRoof = roof.copyWith(
        id: targetId,
        points: newPoints,
        eavesEdgeIndex: safeEaves,
      );
      if (isDuplicate) {
        return (storey.copyWith(roofs: [...storey.roofs, newRoof]), targetId);
      } else {
        final roofs = List<ArchitectRoofPlane>.from(storey.roofs);
        roofs[roofIndex] = newRoof;
        return (storey.copyWith(roofs: roofs), targetId);
      }
    }

    // 6. Zone
    final zoneIndex = storey.zones.indexWhere((z) => z.id == elementId);
    if (zoneIndex != -1) {
      final zone = storey.zones[zoneIndex];
      if (zone.isAutoBoundary) return (storey, null);
      final newPoly = [
        for (final p in zone.polygon)
          BimTransform2D.mirror(p, origin, direction),
      ].reversed.toList();
      final newZone = zone.copyWith(id: targetId, polygon: newPoly, clearScheduleOrigin: isDuplicate);
      if (isDuplicate) {
        return (storey.copyWith(zones: [...storey.zones, newZone]), targetId);
      } else {
        final zones = List<ArchitectZone>.from(storey.zones);
        zones[zoneIndex] = newZone;
        return (storey.copyWith(zones: zones), targetId);
      }
    }

    // 7. Opening
    final openingIndex = storey.openings.indexWhere((o) => o.id == elementId);
    if (openingIndex != -1) {
      final opening = storey.openings[openingIndex];
      final newBoundary = [
        for (final p in opening.boundary)
          BimTransform2D.mirror(p, origin, direction),
      ].reversed.toList();
      final newOpening = opening.copyWith(
        id: targetId,
        boundary: newBoundary,
      );
      if (isDuplicate) {
        return (
          storey.copyWith(openings: [...storey.openings, newOpening]),
          targetId,
        );
      } else {
        final openings = List<ArchitectOpening>.from(storey.openings);
        openings[openingIndex] = newOpening;
        return (storey.copyWith(openings: openings), targetId);
      }
    }

    // 8. Stair
    final stairIndex = storey.stairs.indexWhere((s) => s.id == elementId);
    if (stairIndex != -1) {
      final stair = storey.stairs[stairIndex];
      final newStair = stair.copyWith(
        id: targetId,
        startPoint: BimTransform2D.mirror(stair.startPoint, origin, direction),
        endPoint: BimTransform2D.mirror(stair.endPoint, origin, direction),
      );
      if (isDuplicate) {
        return (storey.copyWith(stairs: [...storey.stairs, newStair]), targetId);
      } else {
        final stairs = List<ArchitectStair>.from(storey.stairs);
        stairs[stairIndex] = newStair;
        return (storey.copyWith(stairs: stairs), targetId);
      }
    }

    // 9. Dimension
    final dimIndex = storey.dimensions.indexWhere((d) => d.id == elementId);
    if (dimIndex != -1) {
      final dim = storey.dimensions[dimIndex];
      final newDim = dim.copyWith(
        id: targetId,
        startPoint: BimTransform2D.mirror(dim.startPoint, origin, direction),
        endPoint: BimTransform2D.mirror(dim.endPoint, origin, direction),
        anchors: [
          for (final a in dim.anchors)
            a.at(BimTransform2D.mirror(a.point, origin, direction)),
        ],
      );
      if (isDuplicate) {
        return (
          storey.copyWith(dimensions: [...storey.dimensions, newDim]),
          targetId,
        );
      } else {
        final dims = List<ArchitectDimension>.from(storey.dimensions);
        dims[dimIndex] = newDim;
        return (storey.copyWith(dimensions: dims), targetId);
      }
    }

    // 10. Annotation
    final annIndex = storey.annotations.indexWhere((a) => a.id == elementId);
    if (annIndex != -1) {
      final ann = storey.annotations[annIndex];
      final newAnn = ann.copyWith(
        id: targetId,
        position: BimTransform2D.mirror(ann.position, origin, direction),
      );
      if (isDuplicate) {
        return (
          storey.copyWith(annotations: [...storey.annotations, newAnn]),
          targetId,
        );
      } else {
        final anns = List<ArchitectAnnotation>.from(storey.annotations);
        anns[annIndex] = newAnn;
        return (storey.copyWith(annotations: anns), targetId);
      }
    }

    // 11. Elevation Marker
    final elevIndex = storey.elevationMarkers.indexWhere(
      (e) => e.id == elementId,
    );
    if (elevIndex != -1) {
      final elev = storey.elevationMarkers[elevIndex];
      final newElev = elev.copyWith(
        id: targetId,
        position: BimTransform2D.mirror(elev.position, origin, direction),
      );
      if (isDuplicate) {
        return (
          storey.copyWith(
            elevationMarkers: [...storey.elevationMarkers, newElev],
          ),
          targetId,
        );
      } else {
        final elevs = List<ArchitectElevationMarker>.from(
          storey.elevationMarkers,
        );
        elevs[elevIndex] = newElev;
        return (storey.copyWith(elevationMarkers: elevs), targetId);
      }
    }

    // 12. CAD Primitive
    final cadIndex = storey.cadPrimitives.indexWhere((c) => c.id == elementId);
    if (cadIndex != -1) {
      final prim = storey.cadPrimitives[cadIndex];
      final newPrim = prim.copyWith(
        id: targetId,
        startPoint: BimTransform2D.mirror(prim.startPoint, origin, direction),
        endPoint: BimTransform2D.mirror(prim.endPoint, origin, direction),
        polygon: prim.polygon != null
            ? [
                for (final p in prim.polygon!)
                  BimTransform2D.mirror(p, origin, direction),
              ].reversed.toList()
            : null,
      );
      if (isDuplicate) {
        return (
          storey.copyWith(cadPrimitives: [...storey.cadPrimitives, newPrim]),
          targetId,
        );
      } else {
        final cads = List<ArchitectCadPrimitive>.from(storey.cadPrimitives);
        cads[cadIndex] = newPrim;
        return (storey.copyWith(cadPrimitives: cads), targetId);
      }
    }

    return (storey, null);
  }

  (ArchitectStorey, List<String>) mirrorElementsByIds(
    ArchitectStorey storey,
    Set<String> elementIds, {
    required Offset origin,
    required Offset direction,
    bool isDuplicate = false,
    Map<String, String>? idMap,
  }) {
    var currentStorey = storey;
    final affectedIds = <String>[];
    for (final id in elementIds) {
      final (updated, affectedId) = mirrorElementById(
        currentStorey,
        id,
        origin: origin,
        direction: direction,
        isDuplicate: isDuplicate,
        newId: idMap?[id],
      );
      if (affectedId != null) {
        currentStorey = updated;
        affectedIds.add(affectedId);
      }
    }
    return (currentStorey, affectedIds);
  }

  ArchitectStorey deleteElementsByIds(
    ArchitectStorey storey,
    Set<String> elementIds,
  ) {
    var currentStorey = storey;
    for (final id in elementIds) {
      currentStorey = deleteElementById(currentStorey, id);
    }
    return currentStorey;
  }

  Set<String> findConnectedWallChain(
    ArchitectStorey storey,
    String startWallId,
  ) {
    final startWall =
        storey.walls.where((w) => w.id == startWallId).firstOrNull;
    if (startWall == null) return {startWallId};

    final result = <String>{startWallId};
    final queue = <ArchitectWall>[startWall];

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final currEndpoints = [current.startPoint, current.endPoint];

      for (final other in storey.walls) {
        if (result.contains(other.id)) continue;

        final tolerance =
            math.max(current.thickness, other.thickness) * 1.2 + 0.05;
        final otherEndpoints = [other.startPoint, other.endPoint];

        bool connected = false;
        // Corner connection (endpoint to endpoint)
        for (final p1 in currEndpoints) {
          for (final p2 in otherEndpoints) {
            if ((p1 - p2).distance <= tolerance) {
              connected = true;
              break;
            }
          }
          if (connected) break;
        }

        // T-junction (endpoint of one to body of the other)
        if (!connected) {
          for (final p in currEndpoints) {
            if (_pointToSegmentDistance(p, other.startPoint, other.endPoint) <=
                other.thickness / 2.0 + 0.08) {
              connected = true;
              break;
            }
          }
        }
        if (!connected) {
          for (final p in otherEndpoints) {
            if (_pointToSegmentDistance(
                  p,
                  current.startPoint,
                  current.endPoint,
                ) <=
                current.thickness / 2.0 + 0.08) {
              connected = true;
              break;
            }
          }
        }

        if (connected) {
          result.add(other.id);
          queue.add(other);
        }
      }
    }
    return result;
  }

  // ===========================================================================
  // 14. HELPER GEOMETRY
  // ===========================================================================

  static double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-8) return (p - a).distance;

    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
    final proj = a + ab * t;
    return (p - proj).distance;
  }
}
