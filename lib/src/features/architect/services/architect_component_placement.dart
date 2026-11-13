import 'dart:math' as math;
import 'dart:ui';

import '../models/architect_component.dart';
import '../models/architect_component_definition.dart';
import '../models/architect_wall.dart';

/// Optional, screen-sized attachment to the closest physical wall face.
/// Catalog order and the saved wall reference line never decide the result.
class ArchitectComponentPlacement {
  static (Offset, double) resolve({
    required Offset raw,
    required ArchitectComponentDefinition definition,
    required Iterable<ArchitectWall> walls,
    required double rotation,
    required double tolerance,
    required bool magnetic,
  }) {
    if (!magnetic ||
        definition.placementMode != ComponentPlacementMode.wallAttached) {
      return (raw, rotation);
    }
    var bestDistance = tolerance;
    var result = (raw, rotation);
    for (final wall in walls) {
      if (wall.length < .001) continue;
      final (ratio, _) = wall.projectPoint(raw);
      if (ratio < 0 || ratio > 1) continue;
      final normal = wall.normalAt(ratio);
      final center =
          wall.referencePointAt(ratio) + normal * wall.centerLineOffset;
      final offset = raw - center;
      final side = offset.dx * normal.dx + offset.dy * normal.dy >= 0 ? 1 : -1;
      final faceNormal = normal * side.toDouble();
      final face = center + faceNormal * (wall.thickness / 2);
      final distance = (raw - face).distance;
      if (distance >= bestDistance) continue;
      bestDistance = distance;
      result = (face, math.atan2(faceNormal.dy, faceNormal.dx) - math.pi / 2);
    }
    return result;
  }
}
