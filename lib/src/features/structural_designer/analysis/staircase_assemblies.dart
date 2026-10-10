import 'dart:ui';
import '../models/structural_element.dart' show compute2DConvexHull;
import 'staircase_geometry_detector.dart';
import 'structural_polygon_distance.dart';

class StaircaseAssembly {
  final List<StairFlightCandidate> flights;
  const StaircaseAssembly(this.flights);

  /// Conservative circulation reserve, never an opening contour.
  List<Offset> get circulation =>
      compute2DConvexHull(flights.expand((f) => f.polygon).toList());
  static List<StaircaseAssembly> group(
    List<StairFlightCandidate> flights,
    double scale,
  ) {
    final visited = <int>{}, result = <StaircaseAssembly>[];
    for (var i = 0; i < flights.length; i++) {
      if (!visited.add(i)) continue;
      final queue = [i];
      for (var at = 0; at < queue.length; at++) {
        for (var j = 0; j < flights.length; j++) {
          if (visited.contains(j)) continue;
          if (StructuralPolygonDistance.between(
                flights[queue[at]].polygon,
                flights[j].polygon,
              ) <=
              .65 * scale) {
            visited.add(j);
            queue.add(j);
          }
        }
      }
      result.add(StaircaseAssembly([for (final j in queue) flights[j]]));
    }
    return result;
  }
}
