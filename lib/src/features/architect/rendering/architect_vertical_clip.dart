import 'dart:ui';

typedef ArchitectHeightPlane = double Function(Offset);

class ArchitectVerticalPart {
  final Path path;
  final ArchitectHeightPlane bottom, top;
  const ArchitectVerticalPart(this.path, this.bottom, this.top);
}

/// Clips vertical material prisms against actual planar slab/roof surfaces.
/// Each resulting footprint has a single linear bottom and top surface.
class ArchitectVerticalClip {
  static Path positive(Path path, ArchitectHeightPlane value) {
    if (path.getBounds().isEmpty) return Path();
    final bounds = path.getBounds().inflate(1);
    final input = [
          bounds.topLeft,
          bounds.topRight,
          bounds.bottomRight,
          bounds.bottomLeft,
        ],
        polygon = <Offset>[];
    for (var i = 0; i < input.length; i++) {
      final a = input[i],
          b = input[(i + 1) % input.length],
          da = value(a),
          db = value(b);
      if (da >= 0) polygon.add(a);
      if ((da >= 0) != (db >= 0)) polygon.add(a + (b - a) * (da / (da - db)));
    }
    return polygon.length < 3
        ? Path()
        : Path.combine(
            PathOperation.intersect,
            path,
            Path()..addPolygon(polygon, true),
          );
  }

  static List<ArchitectVerticalPart> _nonempty(
    Path path,
    ArchitectHeightPlane bottom,
    ArchitectHeightPlane top,
  ) {
    final valid = positive(path, (p) => top(p) - bottom(p) - .0000001);
    return [
      if (!valid.getBounds().isEmpty) ArchitectVerticalPart(valid, bottom, top),
    ];
  }

  static List<ArchitectVerticalPart> cap(
    ArchitectVerticalPart part,
    ArchitectHeightPlane ceiling,
  ) {
    final lower = positive(part.path, (p) => part.top(p) - ceiling(p));
    final unchanged = Path.combine(PathOperation.difference, part.path, lower);
    return [
      ..._nonempty(lower, part.bottom, ceiling),
      ..._nonempty(unchanged, part.bottom, part.top),
    ];
  }

  static List<ArchitectVerticalPart> subtract(
    List<ArchitectVerticalPart> parts,
    Path footprint,
    ArchitectHeightPlane bottom,
    ArchitectHeightPlane top, {
    bool removeAbove = false,
  }) {
    final result = <ArchitectVerticalPart>[];
    for (final part in parts) {
      if (!part.path.getBounds().overlaps(footprint.getBounds())) {
        result.add(part);
        continue;
      }
      final overlap = Path.combine(
        PathOperation.intersect,
        part.path,
        footprint,
      );
      final outside = Path.combine(
        PathOperation.difference,
        part.path,
        footprint,
      );
      if (!outside.getBounds().isEmpty)
        result.add(ArchitectVerticalPart(outside, part.bottom, part.top));
      if (overlap.getBounds().isEmpty) continue;
      result.addAll(
        cap(ArchitectVerticalPart(overlap, part.bottom, part.top), bottom),
      );
      if (!removeAbove) {
        final upper = positive(overlap, (p) => top(p) - part.bottom(p));
        final lower = Path.combine(PathOperation.difference, overlap, upper);
        result.addAll([
          ..._nonempty(upper, top, part.top),
          ..._nonempty(lower, part.bottom, part.top),
        ]);
      }
    }
    return result;
  }
}
