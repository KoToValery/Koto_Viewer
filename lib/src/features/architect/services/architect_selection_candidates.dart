import 'dart:math' as math;
import 'dart:ui';

import '../models/architect_project.dart';
import '../models/architect_elements.dart';
import '../models/architect_wall.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../rendering/architect_2d_painter.dart' show ArchitectTool;
import '../rendering/architect_scene_geometry.dart';
import 'architect_element_tool.dart';
import 'architect_selection.dart';

/// A transient snapshot: changing the picked tool must not reorder its hits.
class ArchitectSelectionCandidates {
  final List<String> ids;
  final Offset point;
  final int index;
  ArchitectSelectionCandidates(
    Iterable<String> ids,
    this.point, {
    this.index = 0,
  }) : ids = List.unmodifiable(ids.toSet());

  String get current => ids[index];
  ArchitectSelectionCandidates at(int next) =>
      ArchitectSelectionCandidates(ids, point, index: next % ids.length);

  static const touchPixels = 22.0;

  static Map<String, ArchitectTool> tools(ArchitectProject project) {
    final s = project.activeStorey;
    return {
      for (final e in s.columns) e.id: ArchitectTool.column,
      for (final w in s.walls) ...{
        for (final e in w.windows) e.id: ArchitectTool.window,
        for (final e in w.doors) e.id: ArchitectTool.door,
      },
      for (final e in s.beams) e.id: ArchitectTool.beam,
      for (final e in s.stairs) e.id: ArchitectTool.stair,
      for (final e in s.openings) e.id: ArchitectTool.opening,
      for (final e in s.dimensions) e.id: ArchitectTool.dimension,
      for (final e in s.elevationMarkers) e.id: ArchitectTool.level,
      for (final e in s.annotations) e.id: ArchitectTool.text,
      for (final e in s.cadPrimitives)
        e.id: switch (e.type) {
          CadPrimitiveType.circle => ArchitectTool.cadCircle,
          CadPrimitiveType.rect => ArchitectTool.cadRect,
          CadPrimitiveType.hatch => ArchitectTool.hatch,
          _ => ArchitectTool.cadLine,
        },
      for (final e in s.walls) e.id: ArchitectTool.wall,
      for (final e in s.roofs) e.id: ArchitectTool.roof,
      for (final e in s.floorDrains) e.id: ArchitectTool.floorDrain,
      for (final e in s.slabs) e.id: ArchitectTool.slab,
      for (final e in s.components.reversed)
        if (e.isVisible) e.id: e.isServiceComponent
            ? ArchitectTool.services : ArchitectTool.component,
      for (final e in s.zones) e.id: ArchitectTool.zone,
      for (final e in s.pathways) e.id: ArchitectTool.pathway,
      for (final e in s.streets) e.id: ArchitectTool.street,
      for (final e in s.vegetation) e.id: ArchitectTool.vegetation,
      for (final e in s.siteFences) e.id: ArchitectTool.siteFence,
      for (final surface in [project.existingTerrain, project.proposedTerrain]) ...{
        surface.id: ArchitectTool.terrain,
        for (final b in surface.boundaries) b.id: ArchitectTool.terrain,
        for (final c in surface.contours) c.id: ArchitectTool.terrain,
        for (final sp in surface.spots) sp.id: ArchitectTool.terrain,
      },
      for (final e in project.gridAxes) e.id: ArchitectTool.axis,
      for (final e in project.sections) e.id: ArchitectTool.section,
      for (final e in project.elevations) e.id: ArchitectTool.elevation,
    };
  }

  static List<String> planHits(
    ArchitectProject project,
    ArchitectElementTool elementTool,
    Offset point,
    double scale, {
    required bool Function(String) allowed,
    bool includeComponents = true,
    String? drawingViewKey,
  }) {
    final tolerance = touchPixels / scale;
    // Cull before constructing detailed outlines, especially roof junctions.
    final nearby = ArchitectSceneGeometry.visible(
      project,
      Rect.fromCircle(center: point, radius: tolerance),
      scale,
    );
    final kinds = tools(nearby);
    final curvedWalls = {
      for (final wall in nearby.activeStorey.walls)
        if (wall.isCurved) wall.id: wall,
    };
    const symbols = {
      ArchitectTool.door,
      ArchitectTool.window,
      ArchitectTool.dimension,
      ArchitectTool.level,
      ArchitectTool.text,
      ArchitectTool.floorDrain,
    };
    Set<String> native(double pixels) => elementTool
        .hitTestElements(
          nearby.activeStorey,
          point,
          scale,
          gridAxes: project.gridAxes,
          annotationProject: project,
          drawingViewKey: drawingViewKey,
          tolerancePixels: pixels,
        )
        .toSet();
    final nativeHits = native(touchPixels);
    final nativeExact = native(0);
    final exact = <String>[], near = <String>[];
    for (final id in {...nativeHits, ...kinds.keys}) {
      final kind = kinds[id];
      if (kind == null ||
          !allowed(id) ||
          (!includeComponents && kind == ArchitectTool.component)) {
        continue;
      }
      final curvedWall = curvedWalls[id];
      if (curvedWall != null) {
        if (wallHit(curvedWall, point, 1e-7)) {
          exact.add(id);
        } else if (wallHit(curvedWall, point, tolerance)) {
          near.add(id);
        }
        continue;
      }
      final path = ArchitectSelection.outline(project, id);
      final symbolic = symbols.contains(kind);
      final filled = !{
        ArchitectTool.cadLine,
        ArchitectTool.cadCircle,
        ArchitectTool.axis,
        ArchitectTool.dimension,
        ArchitectTool.section,
        ArchitectTool.elevation,
        ArchitectTool.floorDrain,
      }.contains(kind);
      final direct =
          pathHit(path, point, 1e-7, filled: filled) ||
          (symbolic && nativeExact.contains(id));
      if (direct) {
        exact.add(id);
      } else if (pathHit(path, point, tolerance, filled: filled) ||
          (symbolic && nativeHits.contains(id))) {
        near.add(id);
      }
    }
    return [...exact, ...near];
  }

  /// Exact annular-sector/cap distance, independent of drawing tessellation.
  static bool wallHit(ArchitectWall wall, Offset point, double tolerance) {
    if (!ArchitectSceneGeometry.wallBounds(
      wall,
    ).inflate(tolerance + .0001).contains(point)) {
      return false;
    }
    final (ratio, distance) = wall.projectPoint(point);
    if (ratio >= 0 && ratio <= 1) {
      return distance <= wall.thickness / 2 + tolerance;
    }
    final end = ratio < 0 ? 0.0 : 1.0;
    final center = wall.centerPointAt(end);
    final half = wall.normalAt(end) * (wall.thickness / 2);
    return (point -
                BimLineGeometry.closest(point, center - half, center + half))
            .distance <=
        tolerance;
  }

  /// Tests contours, including open paths and hole boundaries. Recursive bounds
  /// rejection avoids sampling an entire long line at the touch resolution.
  static bool pathHit(
    Path path,
    Offset point,
    double tolerance, {
    bool filled = true,
  }) {
    if (!path.getBounds().inflate(tolerance + 1e-9).contains(point)) {
      return false;
    }
    if (filled && path.contains(point)) return true;
    final epsilon = math.max(math.min(tolerance / 64, .001), 1e-8);
    for (final metric in path.computeMetrics()) {
      bool intersects(double from, double to, int depth) {
        if (!metric
            .extractPath(from, to)
            .getBounds()
            .inflate(tolerance + epsilon)
            .contains(point)) {
          return false;
        }
        final a = metric.getTangentForOffset(from)?.position;
        final b = metric.getTangentForOffset(to)?.position;
        if (a == null || b == null) return false;
        if (to - from <= epsilon || depth >= 28) {
          final edge = b - a;
          final t = edge.distanceSquared == 0
              ? 0.0
              : (((point - a).dx * edge.dx + (point - a).dy * edge.dy) /
                        edge.distanceSquared)
                    .clamp(0.0, 1.0);
          return (point - (a + edge * t)).distance <= tolerance + epsilon;
        }
        final middle = (from + to) / 2;
        return intersects(from, middle, depth + 1) ||
            intersects(middle, to, depth + 1);
      }

      if (intersects(0, metric.length, 0)) return true;
    }
    return false;
  }
}
