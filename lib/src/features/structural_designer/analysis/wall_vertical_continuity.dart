import '../models/structural_element.dart';
import 'slab_contact_geometry.dart';

class WallVerticalContinuity {
  final String wallId, wallName;

  /// Upper footprint fraction over parallel lower walls. Null means unknown.
  final double? coverage;
  const WallVerticalContinuity(this.wallId, this.wallName, this.coverage);
  bool get isContinuous => coverage != null && coverage! >= 1 - 1e-7;

  static WallVerticalContinuity evaluate(
    StructuralShearWall upper,
    List<StructuralShearWall> lower,
    double scale,
  ) {
    WallVerticalContinuity result(double? value) =>
        WallVerticalContinuity(upper.id, upper.displayName, value);
    if (!scale.isFinite ||
        scale <= 0 ||
        !upper.length.isFinite ||
        upper.length <= 0 ||
        !upper.thickness.isFinite ||
        upper.thickness <= 0) {
      return result(null);
    }
    final u = (upper.end - upper.start) / upper.length;
    final footprints = <StructuralSlab>[];
    for (final wall in lower) {
      if (!wall.length.isFinite ||
          wall.length <= 0 ||
          !wall.thickness.isFinite ||
          wall.thickness <= 0) {
        return result(null);
      }
      final v = (wall.end - wall.start) / wall.length;
      // Numerical direction tolerance (~0.08 degrees), not a code allowance.
      if ((u.dx * v.dx + u.dy * v.dy).abs() < 1 - 1e-6) continue;
      footprints.add(
        StructuralSlab(id: wall.id, polygon: wall.polygonVertices),
      );
    }
    final contact = SlabContactGeometry.measure(
      upper.polygonVertices,
      footprints,
      scale,
      direction: upper.end - upper.start,
    );
    if (contact == null) return result(null);
    final area = (upper.length / scale) * (upper.thickness / scale);
    return result((contact.areaM2 / area).clamp(0.0, 1.0));
  }
}
