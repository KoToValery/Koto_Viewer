import '../models/architect_wall.dart';

/// Derived dimensions change curvature only; reference endpoints and all host
/// properties remain in the wall's existing coordinate system.
class ArchitectWallArcEditing {
  static ArchitectWall withDimension(
    ArchitectWall wall,
    ArchitectArcDimension dimension,
    double value,
  ) {
    final arc = ArchitectWallArc(wall.startPoint, wall.endPoint, wall.arcBulge);
    final next = dimension == ArchitectArcDimension.sagitta
        ? arc.withSagitta(value)
        : arc.withRadius(value);
    final result = wall.copyWith(arcBulge: next.bulge);
    result.validateGeometry();
    if (!result.isCurved) throw ArgumentError('Arc is too shallow');
    validateOpenings(result);
    return result;
  }

  static void validateOpenings(ArchitectWall wall) {
    if (!wall.isCurved) return;
    final openings = [
      for (final d in wall.doors)
        (d.offsetRatio, d.width, d.sillHeight, d.sillHeight + d.height),
      for (final w in wall.windows)
        (w.offsetRatio, w.width, w.sillHeight, w.sillHeight + w.height),
    ];
    for (var i = 0; i < openings.length; i++) {
      final a = openings[i], halfA = wall.openingArcSpan(a.$2) / 2;
      for (final b in openings.skip(i + 1)) {
        if (a.$4 <= b.$3 + 1e-8 || b.$4 <= a.$3 + 1e-8) continue;
        final halfB = wall.openingArcSpan(b.$2) / 2;
        if ((a.$1 - b.$1).abs() * wall.length < halfA + halfB - 1e-8) {
          throw ArgumentError('Openings overlap on the curved host');
        }
      }
    }
  }
}
