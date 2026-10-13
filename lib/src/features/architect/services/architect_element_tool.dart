// === SECTION: ARCHITECTURAL ELEMENT TOOL ===
import 'package:flutter/material.dart';
import 'architect_element_id.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_door.dart';
import '../models/architect_wall.dart';
import '../models/architect_window.dart';
import '../models/architect_fenestration_style.dart';
import '../rendering/architect_2d_painter.dart' show ArchitectTool;

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
  double stairWidth = 1.00;
  int stairSteps = 16;

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

  void setStairParams({double? width, int? steps}) {
    if (width != null) stairWidth = width;
    if (steps != null) stairSteps = steps;
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
  }) {
    ArchitectWall? targetWall;
    double bestDist = double.infinity;

    for (final wall in storey.walls) {
      final (_, dist) = wall.projectPoint(point);
      if (dist <= wall.thickness / 2.0 + 0.30 && dist < bestDist) {
        bestDist = dist;
        targetWall = wall;
      }
    }

    if (targetWall == null) return null;

    final (ratio, _) = targetWall.projectPoint(point);
    final now = ArchitectElementId.next('element');

    final newWindow = ArchitectWindow(
      id: 'win_$now',
      wallId: targetWall.id,
      offsetRatio: ratio,
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
  }) {
    final now = ArchitectElementId.next('element');
    final newColumn = ArchitectColumn(
      id: 'col_$now',
      position: point,
      shape: columnShape,
      width: columnWidth,
      depth: columnDepth,
    );

    return (
      storey.copyWith(columns: [...storey.columns, newColumn]),
      newColumn,
    );
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
    if ((end - start).distance < (type == CadPrimitiveType.line ? .05 : .001)) {
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
  String? hitTestForTool(
    ArchitectStorey storey,
    Offset point,
    double scale,
    ArchitectTool tool,
  ) {
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
      openings: tool == ArchitectTool.opening ? storey.openings : [],
      stairs: tool == ArchitectTool.stair ? storey.stairs : [],
      dimensions: tool == ArchitectTool.dimension ? storey.dimensions : [],
      annotations: tool == ArchitectTool.text ? storey.annotations : [],
      elevationMarkers: tool == ArchitectTool.level
          ? storey.elevationMarkers
          : [],
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
    final id = hitTestElement(scoped, point, scale);
    if (tool != ArchitectTool.wall && scoped.walls.any((w) => w.id == id)) {
      return null;
    }
    return id;
  }

  String? hitTestElement(ArchitectStorey storey, Offset point, double scale) {
    final tolerance = 14.0 / scale;

    // Check Columns
    for (final col in storey.columns) {
      if (col.containsPoint(point, tolerance: tolerance)) {
        return col.id;
      }
    }

    // Check Hosted Windows
    for (final wall in storey.walls) {
      for (final win in wall.windows) {
        final winCenter =
            wall.centerStart +
            (wall.centerEnd - wall.centerStart) * win.offsetRatio;
        if ((point - winCenter).distance <= win.width / 2.0 + tolerance) {
          return win.id;
        }
      }
      for (final door in wall.doors) {
        final doorCenter =
            wall.centerStart +
            (wall.centerEnd - wall.centerStart) * door.offsetRatio;
        if ((point - doorCenter).distance <= door.width / 2.0 + tolerance) {
          return door.id;
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
        return beam.id;
      }
    }

    // Check Stairs
    for (final stair in storey.stairs) {
      final dist = _pointToSegmentDistance(
        point,
        stair.startPoint,
        stair.endPoint,
      );
      if (dist <= stair.width / 2.0 + tolerance) {
        return stair.id;
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
          return op.id;
        }
      }
    }

    // Check Dimensions
    for (final dim in storey.dimensions) {
      final dist = _pointToSegmentDistance(point, dim.startPoint, dim.endPoint);
      if (dist <= tolerance) {
        return dim.id;
      }
    }

    // Check Elevation Markers
    for (final el in storey.elevationMarkers) {
      if ((point - el.position).distance <= 0.40 + tolerance) {
        return el.id;
      }
    }

    // Check Annotations
    for (final ann in storey.annotations) {
      if ((point - ann.position).distance <= 0.60 + tolerance) {
        return ann.id;
      }
    }

    // Check CAD Primitives
    for (final prim in storey.cadPrimitives) {
      if (prim.type == CadPrimitiveType.line) {
        if (_pointToSegmentDistance(point, prim.startPoint, prim.endPoint) <=
            tolerance) {
          return prim.id;
        }
      } else if (prim.type == CadPrimitiveType.rect) {
        final points = prim.polygonCorners;
        final path = Path()..addPolygon(points, true);
        if (path.contains(point)) return prim.id;
        for (var i = 0; i < points.length; i++) {
          if (_pointToSegmentDistance(
                point,
                points[i],
                points[(i + 1) % points.length],
              ) <=
              tolerance) {
            return prim.id;
          }
        }
      } else if (prim.type == CadPrimitiveType.circle) {
        final rad = (prim.endPoint - prim.startPoint).distance;
        final d = (point - prim.startPoint).distance;
        if ((d - rad).abs() <= tolerance) return prim.id;
      }
    }

    // Check Walls
    for (final wall in storey.walls) {
      if (wall.containsPoint(point)) {
        return wall.id;
      }
    }

    // Check Slabs
    for (final slab in storey.slabs) {
      if (slab.containsPoint(point)) {
        return slab.id;
      }
    }

    return null;
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
    final timestamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    final newId = '${elementId}_c$timestamp';

    // 1. Column
    final colIndex = storey.columns.indexWhere((c) => c.id == elementId);
    if (colIndex != -1) {
      final col = storey.columns[colIndex];
      final newCol = col.copyWith(id: newId, position: col.position + offset);
      return (storey.copyWith(columns: [...storey.columns, newCol]), newId);
    }

    // 2. Wall
    final wallIndex = storey.walls.indexWhere((w) => w.id == elementId);
    if (wallIndex != -1) {
      final wall = storey.walls[wallIndex];
      final newWall = wall.copyWith(
        id: newId,
        startPoint: wall.startPoint + offset,
        endPoint: wall.endPoint + offset,
        doors: [],
        windows: [],
      );
      return (storey.copyWith(walls: [...storey.walls, newWall]), newId);
    }

    // 3. Slab
    final slabIndex = storey.slabs.indexWhere((s) => s.id == elementId);
    if (slabIndex != -1) {
      final slab = storey.slabs[slabIndex];
      final newSlab = slab.copyWith(
        id: newId,
        polygon: slab.polygon.map((p) => p + offset).toList(),
      );
      return (storey.copyWith(slabs: [...storey.slabs, newSlab]), newId);
    }

    // 4. CAD Primitive
    final cadIndex = storey.cadPrimitives.indexWhere((c) => c.id == elementId);
    if (cadIndex != -1) {
      final prim = storey.cadPrimitives[cadIndex];
      final newPrim = prim.copyWith(
        id: newId,
        startPoint: prim.startPoint + offset,
        endPoint: prim.endPoint + offset,
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
      final newZone = zone.copyWith(
        id: newId,
        polygon: zone.polygon.map((p) => p + offset).toList(),
      );
      return (storey.copyWith(zones: [...storey.zones, newZone]), newId);
    }

    // 6. Beam
    final beamIndex = storey.beams.indexWhere((b) => b.id == elementId);
    if (beamIndex != -1) {
      final beam = storey.beams[beamIndex];
      final newBeam = beam.copyWith(
        id: newId,
        startPoint: beam.startPoint + offset,
        endPoint: beam.endPoint + offset,
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
      newCols[colIndex] = col.copyWith(
        width: col.depth,
        depth: col.width,
        rotationDeg: (col.rotationDeg + 90) % 360,
      );
      return storey.copyWith(columns: newCols);
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
        newSlabs[slabIndex] = slab.copyWith(polygon: rotatedPoly);
        return storey.copyWith(slabs: newSlabs);
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
      );
      return storey.copyWith(walls: newWalls);
    }

    return storey;
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
