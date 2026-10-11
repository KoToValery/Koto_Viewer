import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';

/// Automatic plate membership, without extra UI or a second geometry copy.
/// A region needs a real shared edge at the same level; point contacts and gaps
/// never create a connection. Re-evaluated after edits and when loading seeds.
class SlabZoneGrouping {
  static double sharedEdgeLength(
    StructuralSlab a,
    StructuralSlab b,
    double scale,
  ) {
    final eps = 1e-8 * scale;
    double cross(Offset p, Offset q) => p.dx * q.dy - p.dy * q.dx;
    double total = 0;
    for (var i = 0; i < a.polygon.length; i++) {
      final p = a.polygon[i], v = a.polygon[(i + 1) % a.polygon.length] - p;
      final length = v.distance;
      if (length <= eps) continue;
      final u = v / length;
      for (var j = 0; j < b.polygon.length; j++) {
        final c = b.polygon[j] - p,
            d = b.polygon[(j + 1) % b.polygon.length] - p;
        if (cross(u, c).abs() > eps || cross(u, d).abs() > eps) continue;
        final x = c.dx * u.dx + c.dy * u.dy, y = d.dx * u.dx + d.dy * u.dy;
        total += math.max(
          0,
          math.min(length, math.max(x, y)) - math.max(0, math.min(x, y)),
        );
      }
    }
    return total;
  }

  static List<StructuralSlab> attach(
    List<StructuralSlab> slabs,
    double scale, {
    StoreyLevel? owner,
  }) {
    if (!scale.isFinite || scale <= 0) return slabs;
    double level(StructuralSlab s) =>
        owner?.structuralElevationFor(s) ??
        s.topElevation ??
        -(s.floorFinish ?? .05);
    final mains = slabs.where((s) => !s.isSlabZone).toList();
    return [
      for (final zone in slabs)
        if (!zone.isSlabZone)
          zone
        else
          (() {
            StructuralSlab? parent;
            var longest = 1e-8 * scale;
            for (final main in mains) {
              if (main.isFloorSlab != zone.isFloorSlab ||
                  (level(main) - level(zone)).abs() > 1e-6) {
                continue;
              }
              final contact = sharedEdgeLength(zone, main, scale);
              if (contact > longest) {
                longest = contact;
                parent = main;
              }
            }
            if (zone.parentSlabId == parent?.id) return zone;
            return zone.copyWith(
              parentSlabId: parent?.id,
              clearParentSlabId: parent == null,
            );
          })(),
    ];
  }
}
