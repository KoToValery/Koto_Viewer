import 'dart:math' as math;
import 'dart:ui';

/// Integrals in metres about a nearby origin, independent of ring orientation.
class PolygonMassIntegrals {
  final double area, firstX, firstY, polar;
  const PolygonMassIntegrals(this.area, this.firstX, this.firstY, this.polar);
  static PolygonMassIntegrals integrate(
    List<Offset> ring,
    Offset origin,
    double scale,
  ) {
    double a = 0, x = 0, y = 0, j = 0;
    for (var i = 0; i < ring.length; i++) {
      final p = (ring[i] - origin) / scale;
      final q = (ring[(i + 1) % ring.length] - origin) / scale;
      final cross = p.dx * q.dy - q.dx * p.dy;
      a += cross;
      x += (p.dx + q.dx) * cross;
      y += (p.dy + q.dy) * cross;
      j +=
          (p.dx * p.dx +
              p.dx * q.dx +
              q.dx * q.dx +
              p.dy * p.dy +
              p.dy * q.dy +
              q.dy * q.dy) *
          cross;
    }
    final sign = a < 0 ? -1.0 : 1.0;
    return PolygonMassIntegrals(
      sign * a / 2,
      sign * x / 6,
      sign * y / 6,
      sign * j / 12,
    );
  }
}

/// Elastic layout proxy under equal material, height and end-restraint factors.
/// These m^4 indices are not physical element stiffnesses or a 3D solution.
/// Local Saint-Venant/warping torsion and wall/core coupling are not included.
class LayoutSupport {
  final Offset position;
  final double kx, ky, kxy;
  const LayoutSupport(this.position, this.kx, this.ky, this.kxy);
  factory LayoutSupport.rotated(
    Offset position,
    double x,
    double y,
    double angle,
  ) {
    final c = math.cos(angle), s = math.sin(angle);
    return LayoutSupport(
      position,
      x * c * c + y * s * s,
      x * s * s + y * c * c,
      (x - y) * s * c,
    );
  }
}

class LayoutRigidity {
  final Offset center;
  final double kx, ky, torsion;
  const LayoutRigidity(this.center, this.kx, this.ky, this.torsion);
  static LayoutRigidity? calculate(List<LayoutSupport> supports) {
    if (supports.isEmpty) return null;
    // Work relative to a support to preserve precision at large CAD coordinates.
    final origin = supports.first.position;
    double x = 0, y = 0, xy = 0, bx = 0, by = 0;
    for (final e in supports) {
      if (!e.kx.isFinite ||
          !e.ky.isFinite ||
          !e.kxy.isFinite ||
          e.kx <= 0 ||
          e.ky <= 0 ||
          !e.position.dx.isFinite ||
          !e.position.dy.isFinite) {
        return null;
      }
      final p = e.position - origin;
      x += e.kx;
      y += e.ky;
      xy += e.kxy;
      bx += e.kx * p.dy - e.kxy * p.dx;
      by += e.ky * p.dx - e.kxy * p.dy;
    }
    final determinant = x * y - xy * xy;
    if (!determinant.isFinite || determinant <= 1e-12 * (x + y) * (x + y)) {
      return null;
    }
    final local = Offset(
      (x * by + xy * bx) / determinant,
      (xy * by + y * bx) / determinant,
    );
    double torsion = 0;
    for (final e in supports) {
      final p = e.position - origin - local;
      torsion +=
          e.kx * p.dy * p.dy + e.ky * p.dx * p.dx - 2 * e.kxy * p.dx * p.dy;
    }
    return LayoutRigidity(origin + local, x, y, math.max(0, torsion));
  }
}
