import '../models/architect_contour.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';
import '../rendering/architect_path_solid.dart';
import '../rendering/architect_vertical_clip.dart';

/// Derived roof envelopes. Original polygons and their eaves references remain
/// editable; cutting a footprint must never change its slope or datum plane.
class ArchitectRoofJunctions {
  static final _cache = Expando<(int, ArchitectRoofJunctions)>();
  final Map<String, Path> footprints;
  final Set<String> trimmed;
  const ArchitectRoofJunctions._(this.footprints, this.trimmed);

  static ArchitectRoofJunctions of(
    ArchitectStorey storey, {
    ArchitectProject? project,
  }) {
    final floors = project?.storeys ?? [storey];
    final overrides = {for (final roof in storey.roofs) roof.id: roof};
    final planes = <(ArchitectRoofPlane, double)>[
      for (final floor in floors) ...[
        for (final roof in floor.roofs)
          (
            floor.id == storey.id ? overrides[roof.id] ?? roof : roof,
            project == null ? 0 : floor.elevation,
          ),
        if (floor.id == storey.id)
          for (final roof in storey.roofs)
            if (!floor.roofs.any((r) => r.id == roof.id))
              (roof, project == null ? 0 : floor.elevation),
      ],
    ];
    final signature = Object.hashAll([
      for (final (roof, elevation) in planes)
        Object.hash(
          roof.id,
          roof.roofGroupId,
          Object.hashAll(roof.points),
          Object.hashAll(roof.holes.map(Object.hashAll)),
          roof.eavesEdgeIndex,
          roof.reverseSlope,
          roof.slopeDegrees,
          roof.baseElevationOffset + elevation,
          roof.eavesOverhang,
          roof.assembly.totalThickness,
        ),
    ]);
    final cacheKey = project?.storeys ?? storey.roofs;
    final cached = _cache[cacheKey];
    if (cached != null && cached.$1 == signature) return cached.$2;
    final result = resolve([
      for (final (roof, elevation) in planes)
        elevation == 0
            ? roof
            : roof.copyWith(
                baseElevationOffset: roof.baseElevationOffset + elevation,
              ),
    ]);
    _cache[cacheKey] = (signature, result);
    return result;
  }

  static ArchitectRoofJunctions resolve(List<ArchitectRoofPlane> roofs) {
    final original = {
      for (final roof in roofs) roof.id: ArchitectContour.path(roof.points, roof.holes),
    };
    String group(ArchitectRoofPlane roof) => roof.roofGroupId == null
        ? 'plane:${roof.id}'
        : 'group:${roof.roofGroupId}';
    final parent = {for (final roof in roofs) group(roof): group(roof)};
    String root(String key) {
      var current = key;
      final visited = <String>{};
      while (parent.containsKey(current) && parent[current] != current) {
        if (!visited.add(current)) break;
        current = parent[current]!;
      }
      return current;
    }

    final overlaps = <(String, String), Path>{};
    for (var i = 0; i < roofs.length; i++) {
      final a = roofs[i];
      for (final b in roofs.skip(i + 1)) {
        if (!a.bounds.overlaps(b.bounds)) continue;
        final overlap = Path.combine(
          PathOperation.intersect,
          original[a.id]!,
          original[b.id]!,
        );
        if (overlap.getBounds().isEmpty) continue;
        overlaps[(a.id, b.id)] = overlap;
        // A distant roof above a lower roof is not a junction. Join systems
        // whose surfaces cross or whose actual assembly volumes intersect.
        final differences = ArchitectPathSolid.contours(overlap)
            .expand((c) => c)
            .map((p) => a.topElevationAt(p) - b.topElevationAt(p))
            .toList();
        final surfacesMeet =
            differences.isNotEmpty &&
            differences.reduce(math.min) <= 1e-6 &&
            differences.reduce(math.max) >= -1e-6;
        var solidOverlap = ArchitectVerticalClip.positive(
          overlap,
          (p) => a.topElevationAt(p) - b.undersideElevationAt(p),
        );
        solidOverlap = ArchitectVerticalClip.positive(
          solidOverlap,
          (p) => b.topElevationAt(p) - a.undersideElevationAt(p),
        );
        if (surfacesMeet || !solidOverlap.getBounds().isEmpty) {
          parent[root(group(b))] = root(group(a));
        }
      }
    }
    final result = {
      for (final entry in original.entries) entry.key: Path.from(entry.value),
    };
    for (var i = 0; i < roofs.length; i++) {
      final a = roofs[i];
      for (final b in roofs.skip(i + 1)) {
        if (root(group(a)) != root(group(b))) continue;
        final overlap = overlaps[(a.id, b.id)];
        if (overlap == null) continue;
        double difference(Offset p) =>
            b.topElevationAt(p) - a.topElevationAt(p);
        final probes = [Offset.zero, const Offset(1, 0), const Offset(0, 1)];
        if (probes.every((p) => difference(p).abs() < 1e-7)) {
          // Stable ownership for duplicate coplanar surfaces, independent of
          // creation order; otherwise both would disappear or be drawn twice.
          final loser = a.id.compareTo(b.id) < 0 ? b.id : a.id;
          result[loser] = Path.combine(
            PathOperation.difference,
            result[loser]!,
            overlap,
          );
          continue;
        }
        final aboveA = ArchitectVerticalClip.positive(overlap, difference);
        final aboveB = ArchitectVerticalClip.positive(
          overlap,
          (p) => -difference(p),
        );
        result[a.id] = Path.combine(
          PathOperation.difference,
          result[a.id]!,
          aboveA,
        );
        result[b.id] = Path.combine(
          PathOperation.difference,
          result[b.id]!,
          aboveB,
        );
      }
    }
    return ArchitectRoofJunctions._(result, {
      for (final roof in roofs)
        if (roof.holes.isNotEmpty || !Path.combine(
          PathOperation.xor,
          original[roof.id]!,
          result[roof.id]!,
        ).getBounds().isEmpty)
          roof.id,
    });
  }

  Path footprint(ArchitectRoofPlane roof) =>
      footprints[roof.id] ?? (ArchitectContour.path(roof.points, roof.holes));

  /// The datum remains tied to the original eaves, while a label follows the
  /// remaining visible part when the old polygon centroid has been cut away.
  Offset labelPoint(ArchitectRoofPlane roof) {
    final path = footprint(roof);
    if (path.contains(roof.centroid)) return roof.centroid;
    final bounds = path.getBounds();
    if (path.contains(bounds.center)) return bounds.center;
    for (final x in [.5, .25, .75, .1, .9]) {
      for (final y in [.5, .25, .75, .1, .9]) {
        final point = Offset(
          bounds.left + bounds.width * x,
          bounds.top + bounds.height * y,
        );
        if (path.contains(point)) return point;
      }
    }
    return roof.centroid;
  }

  static int? originalEdge(ArchitectRoofPlane roof, Offset a, Offset b) {
    for (var i = 0; i < roof.points.length; i++) {
      final start = roof.points[i],
          delta = roof.points[(i + 1) % roof.points.length] - start;
      if (delta.distance < 1e-8) continue;
      bool on(Offset p) {
        final v = p - start;
        final t = (v.dx * delta.dx + v.dy * delta.dy) / delta.distanceSquared;
        return t >= -1e-5 &&
            t <= 1 + 1e-5 &&
            (v.dx * delta.dy - v.dy * delta.dx).abs() / delta.distance < 1e-5;
      }

      if (on(a) && on(b)) return i;
    }
    return null;
  }
}
