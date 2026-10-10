import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import 'slab_contact_geometry.dart';
import 'structural_polygon_distance.dart';
import 'wall_placement_domain.dart';

/// Common geometric policy for generation, resizing and local search.
/// Centre spacing is a layout preference, not a capacity check.
class SupportPlacementRules {
  static List<Offset> columnFootprint(StructuralColumn c) =>
      c.shape == ColumnShape.circular
      ? SlabContactGeometry.columnFootprint(
          c.copyWith(width: c.width / math.cos(math.pi / 256)),
        )
      : c.polygonVertices;
  static String? separationReason({
    required List<Offset> polygon,
    required Offset center,
    required bool isWall,
    required Iterable<StructuralColumn> columns,
    required Iterable<StructuralShearWall> walls,
    required double scale,
    required double columnSpacingM,
    required double wallSpacingM,
    String? skipId,
    Offset? wallDirection,
  }) {
    for (final c in columns) {
      if (c.id == skipId) continue;
      final gap = c.shape == ColumnShape.circular
          ? StructuralPolygonDistance.toCircle(polygon, c.center, c.width / 2)
          : StructuralPolygonDistance.between(polygon, c.polygonVertices);
      if (gap < (.05 - 1e-8) * scale) return 'collision';
      if (!isWall &&
          (c.center - center).distance < (columnSpacingM - 1e-8) * scale) {
        return 'column-spacing';
      }
    }
    for (final w in walls) {
      if (w.id == skipId) continue;
      if (StructuralPolygonDistance.between(polygon, w.polygonVertices) <
          (.05 - 1e-8) * scale) {
        return 'collision';
      }
      if (isWall && wallDirection != null && w.length > 0) {
        final u = (w.end - w.start) / w.length;
        if ((u.dx * wallDirection.dx + u.dy * wallDirection.dy).abs() >=
                .9239 &&
            (w.center - center).distance < (wallSpacingM - 1e-8) * scale) {
          return 'wall-spacing';
        }
      }
    }
    return null;
  }

  static bool slabFits(
    List<Offset> polygon,
    List<StructuralSlab> slabs,
    double scale,
  ) {
    final area = StructuralSlab.calculateArea(polygon) / (scale * scale);
    if (!area.isFinite || area <= 1e-10) return false;
    final contact = SlabContactGeometry.measure(polygon, slabs, scale);
    return contact != null &&
        (contact.areaM2 - area).abs() <= math.max(1e-10, area * 1e-7) &&
        !slabs.any(
          (s) => s.openings.any(
            (h) =>
                StructuralPolygonDistance.between(polygon, h) <= 1e-7 * scale,
          ),
        );
  }

  static String? reason({
    required List<Offset> polygon,
    required Offset center,
    required bool isWall,
    required StoreyLevel floor,
    required WallPlacementDomain domain,
    required double scale,
    required double columnSpacingM,
    required double wallSpacingM,
    bool includeOpenings = false,
    String? skipId,
    Offset? wallDirection,
  }) {
    if (!domain.contains(polygon, includeOpenings: includeOpenings)) {
      return 'wall';
    }
    if (!slabFits(polygon, floor.slabs, scale)) return 'slab';
    return separationReason(
      polygon: polygon,
      center: center,
      isWall: isWall,
      columns: floor.columns,
      walls: floor.shearWalls,
      scale: scale,
      columnSpacingM: columnSpacingM,
      wallSpacingM: wallSpacingM,
      skipId: skipId,
      wallDirection: wallDirection,
    );
  }
}
