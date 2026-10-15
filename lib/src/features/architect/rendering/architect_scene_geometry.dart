import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_elements.dart';

class ArchitectSceneGeometry {
  static Rect boundsOf(Iterable<Offset> points) {
    final values = points.toList();
    if (values.isEmpty) return Rect.zero;
    var rect = Rect.fromPoints(values.first, values.first);
    for (final point in values.skip(1)) {
      rect = Rect.fromLTRB(
        math.min(rect.left, point.dx),
        math.min(rect.top, point.dy),
        math.max(rect.right, point.dx),
        math.max(rect.bottom, point.dy),
      );
    }
    return rect;
  }

  static Rect projectBounds(ArchitectProject project) => boundsOf([
    for (final a in project.gridAxes) ...[a.start, a.end],
    for (final s in project.storeys) ...[
      for (final w in s.walls) ...w.polygonCorners,
      for (final z in s.zones) ...z.polygon,
      for (final c in s.columns) ...[
        c.position - Offset(c.width, c.depth),
        c.position + Offset(c.width, c.depth),
      ],
      for (final b in s.beams) ...b.polygonCorners,
      for (final slab in s.slabs) ...slab.polygon,
      for (final opening in s.openings) ...opening.boundary,
      for (final stair in s.stairs) ...stair.polygonCorners,
      for (final dim in s.dimensions) ...[
        ...dim.witnessPoints,
        dim.lineStart,
        dim.lineEnd,
      ],
      for (final e in s.elevationMarkers) e.position,
      for (final e in s.annotations) e.position,
      for (final e in s.cadPrimitives) ...[
        if (e.type == CadPrimitiveType.circle) ...[
          e.startPoint -
              Offset(
                (e.endPoint - e.startPoint).distance,
                (e.endPoint - e.startPoint).distance,
              ),
          e.startPoint +
              Offset(
                (e.endPoint - e.startPoint).distance,
                (e.endPoint - e.startPoint).distance,
              ),
        ] else if (e.type == CadPrimitiveType.rect)
          ...e.polygonCorners
        else ...[
          e.startPoint,
          e.endPoint,
        ],
      ],
    ],
  ]);

  static ArchitectProject visible(
    ArchitectProject project,
    Rect view,
    double scale,
  ) {
    final expanded = view.inflate(80 / scale);
    bool intersects(Iterable<Offset> points, [double margin = 0]) =>
        boundsOf(points).inflate(math.max(margin, 1e-9)).overlaps(expanded);
    final s = project.activeStorey;
    final filtered = s.copyWith(
      walls: s.walls.where((e) => intersects(e.polygonCorners)).toList(),
      zones: s.zones.where((e) => intersects(e.polygon)).toList(),
      columns: s.columns
          .where((e) => intersects([e.position], math.max(e.width, e.depth)))
          .toList(),
      beams: s.beams.where((e) => intersects(e.polygonCorners)).toList(),
      slabs: s.slabs.where((e) => intersects(e.polygon)).toList(),
      openings: s.openings.where((e) => intersects(e.boundary)).toList(),
      stairs: s.stairs
          .where((e) => intersects(e.polygonCorners))
          .toList(),
      dimensions: s.dimensions
          .where(
            (e) => intersects([...e.witnessPoints, e.lineStart, e.lineEnd]),
          )
          .toList(),
      // Text can extend far beyond its anchor; leave it to canvas clipping.
      cadPrimitives: s.cadPrimitives
          .where(
            (e) => e.type == CadPrimitiveType.circle
                ? intersects([
                    e.startPoint,
                  ], (e.endPoint - e.startPoint).distance)
                : intersects(
                    e.type == CadPrimitiveType.rect
                        ? e.polygonCorners
                        : [e.startPoint, e.endPoint],
                  ),
          )
          .toList(),
    );
    return project
        .updateActiveStorey(filtered)
        .copyWithGridAxes(
          project.gridAxes.where((a) => intersects([a.start, a.end])).toList(),
        );
  }
}
