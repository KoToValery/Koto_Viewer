import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/geometry/bim_transform_2d.dart';
import '../models/architect_contour.dart';
import '../models/architect_project.dart';

/// Rigid plan rotation: all selected elements share one pivot, including holes
/// and directional metadata. Source order and hosted opening identities survive.
class ArchitectRotation {
  static bool supports(ArchitectStorey storey, Set<String> ids) =>
      ids.isNotEmpty && storey.groupableIds.containsAll(ids);

  static double snapAngle(double radians, {double tolerance = math.pi / 60}) {
    final nearest = (radians / (math.pi / 4)).round() * math.pi / 4;
    return (nearest - radians).abs() <= tolerance ? nearest : radians;
  }

  static ArchitectStorey apply(
    ArchitectStorey s,
    Set<String> ids,
    Offset pivot,
    double radians,
  ) {
    if (!supports(s, ids) ||
        !radians.isFinite ||
        !pivot.dx.isFinite ||
        !pivot.dy.isFinite) {
      throw ArgumentError('Invalid rotation');
    }
    if (radians.abs() < 1e-12) return s;
    Offset turn(Offset p) => BimTransform2D.rotate(p, pivot, radians);
    List<Offset> ring(List<Offset> p) => p.map(turn).toList();
    List<List<Offset>> holes(List<List<Offset>> p) =>
        ArchitectContour.transform(p, turn);
    return s.copyWith(
      walls: [
        for (final e in s.walls)
          if (ids.contains(e.id))
            e.copyWith(
              startPoint: turn(e.startPoint),
              endPoint: turn(e.endPoint),
            )
          else
            e,
      ],
      columns: [
        for (final e in s.columns)
          if (ids.contains(e.id))
            e.copyWith(
              position: turn(e.position),
              rotationDeg: (e.rotationDeg + radians * 180 / math.pi) % 360,
            )
          else
            e,
      ],
      beams: [
        for (final e in s.beams)
          if (ids.contains(e.id))
            e.copyWith(
              startPoint: turn(e.startPoint),
              endPoint: turn(e.endPoint),
            )
          else
            e,
      ],
      slabs: [
        for (final e in s.slabs)
          if (ids.contains(e.id))
            e.copyWith(
              polygon: ring(e.polygon),
              holes: holes(e.holes),
              slopeDirection: e.slopeDirection == null
                  ? null
                  : e.slopeDirection! + radians,
            )
          else
            e,
      ],
      roofs: [
        for (final e in s.roofs)
          if (ids.contains(e.id))
            e.copyWith(points: ring(e.points), holes: holes(e.holes))
          else
            e,
      ],
      zones: [
        for (final e in s.zones)
          if (ids.contains(e.id))
            e.copyWith(
              polygon: ring(e.polygon),
              seedPoint: e.seedPoint == null ? null : turn(e.seedPoint!),
            )
          else
            e,
      ],
      openings: [
        for (final e in s.openings)
          if (ids.contains(e.id)) e.copyWith(boundary: ring(e.boundary)) else e,
      ],
      stairs: [
        for (final e in s.stairs)
          if (ids.contains(e.id))
            e.copyWith(
              startPoint: turn(e.startPoint),
              endPoint: turn(e.endPoint),
            )
          else
            e,
      ],
      dimensions: [
        for (final e in s.dimensions)
          if (ids.contains(e.id))
            e.copyWith(
              startPoint: turn(e.startPoint),
              endPoint: turn(e.endPoint),
              anchors: [for (final a in e.anchors) a.at(turn(a.point))],
              direction: e.direction == null
                  ? null
                  : BimTransform2D.rotate(e.direction!, Offset.zero, radians),
            )
          else
            e,
      ],
      annotations: [
        for (final e in s.annotations)
          if (ids.contains(e.id)) e.copyWith(position: turn(e.position)) else e,
      ],
      elevationMarkers: [
        for (final e in s.elevationMarkers)
          if (ids.contains(e.id)) e.copyWith(position: turn(e.position)) else e,
      ],
      cadPrimitives: [
        for (final e in s.cadPrimitives)
          if (ids.contains(e.id))
            e.copyWith(
              startPoint: turn(e.startPoint),
              endPoint: turn(e.endPoint),
              polygon: e.isPolygon
                  ? ring(e.polygonCorners)
                  : e.polygon?.map(turn).toList(),
              holes: holes(e.holes),
              hatchAngle: e.hatchAngle + radians * 180 / math.pi,
            )
          else
            e,
      ],
      components: [
        for (final e in s.components)
          if (ids.contains(e.id))
            e.copyWith(
              position: turn(e.position),
              rotation: e.rotation + radians,
            )
          else
            e,
      ],
      floorDrains: [
        for (final e in s.floorDrains)
          if (ids.contains(e.id))
            e.copyWith(
              position: turn(e.position),
              polygon: ring(e.polygon),
              holes: holes(e.holes),
              angle: e.angle + radians,
            )
          else
            e,
      ],
    );
  }
}
