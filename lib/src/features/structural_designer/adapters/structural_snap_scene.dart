import 'dart:ui';
import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../bim_editing/scene/bim_point_index.dart';
import '../../bim_editing/snapping/bim_snap_resolver.dart';
import '../models/structural_element.dart';

typedef StructuralSnapFeature = ({
  Offset point,
  BimSnapKind kind,
  String owner,
  String storeyId,
});

/// Native feature policy; storage, capture bounds and ranking are shared.
class StructuralSnapScene {
  static final _cache = Expando<Map<double, StructuralSnapScene>>();
  static StructuralSnapScene of(
    StructuralProject project,
    double unitsPerMeter,
  ) {
    final frames = _cache[project] ??= {};
    return frames[unitsPerMeter] ??= StructuralSnapScene._(
      project,
      BimCoordinateFrame(unitsPerMeter: unitsPerMeter),
    );
  }

  final _index = BimPointIndex<StructuralSnapFeature>();
  StructuralSnapScene._(StructuralProject project, BimCoordinateFrame frame) {
    for (final floor in [
      project.activeStorey,
      ?project.ghostStorey,
    ]) {
      void point(Offset native, BimSnapKind kind, String owner) {
        final metres = frame.toModel(native);
        _index.add(metres, (
          point: metres,
          kind: kind,
          owner: owner,
          storeyId: floor.id,
        ));
      }

      void polygon(List<Offset> vertices, String owner) {
        for (var i = 0; i < vertices.length; i++) {
          point(vertices[i], BimSnapKind.endpoint, owner);
          point(
            (vertices[i] + vertices[(i + 1) % vertices.length]) / 2,
            BimSnapKind.midpoint,
            owner,
          );
        }
      }

      for (var i = 0; i < floor.gridAxes.length; i++) {
        final axis = floor.gridAxes[i];
        point(axis.start, BimSnapKind.endpoint, axis.id);
        point(axis.end, BimSnapKind.endpoint, axis.id);
        for (final other in floor.gridAxes.skip(i + 1)) {
          if (axis.intersectionWith(other) case final intersection?) {
            point(intersection, BimSnapKind.intersection, '@axes');
          }
        }
      }
      // Construction deliberately snaps columns only at their corners.
      for (final column in floor.columns) {
        for (final vertex in column.polygonVertices) {
          point(vertex, BimSnapKind.endpoint, column.id);
        }
      }
      for (final wall in floor.shearWalls) {
        point(wall.start, BimSnapKind.endpoint, wall.id);
        point(wall.end, BimSnapKind.endpoint, wall.id);
        for (final vertex in wall.polygonVertices) {
          point(vertex, BimSnapKind.endpoint, wall.id);
        }
      }
      for (final beam in floor.beams) {
        point(beam.start, BimSnapKind.endpoint, beam.id);
        point(beam.end, BimSnapKind.endpoint, beam.id);
        point((beam.start + beam.end) / 2, BimSnapKind.midpoint, beam.id);
      }
      for (final slab in floor.slabs) {
        polygon(slab.polygon, slab.id);
        for (final hole in slab.openings) {
          polygon(hole, slab.id);
        }
      }
    }
    _index.seal();
  }
  Iterable<StructuralSnapFeature> query(Offset model, double radius) =>
      _index.query(model, radius);
}
