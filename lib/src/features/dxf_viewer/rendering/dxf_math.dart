import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/dxf_models.dart';

/// Geometric & Mathematical helper functions for DXF rendering.
class DxfMath {
  const DxfMath._();

  /// Converts a polyline segment with bulge to a list of sample points (or a Path).
  static List<Offset> generateBulgeArcPoints(
    Offset p1,
    Offset p2,
    double bulge, {
    int maxSegments = 32,
  }) {
    if (bulge.abs() < 1e-6) {
      return [p1, p2];
    }

    final double d = (p2 - p1).distance;
    if (d < 1e-7) {
      return [p1];
    }

    final double theta = 4.0 * math.atan(bulge);
    final double radius = (d / 2.0) * (1.0 + bulge * bulge) / (2.0 * bulge.abs());

    // Midpoint of chord
    final double mx = (p1.dx + p2.dx) / 2.0;
    final double my = (p1.dy + p2.dy) / 2.0;

    // Normal vector perpendicular to chord (pointing to the left of p1->p2)
    final double nx = -(p2.dy - p1.dy) / d;
    final double ny = (p2.dx - p1.dx) / d;

    // Distance from midpoint to center
    final double distToCenter = (d / 2.0) * (1.0 - bulge * bulge) / (2.0 * bulge);

    final double cx = mx + nx * distToCenter;
    final double cy = my + ny * distToCenter;

    final double startAngle = math.atan2(p1.dy - cy, p1.dx - cx);

    // Number of segments proportional to included angle
    final int segments = (maxSegments * (theta.abs() / (2 * math.pi))).clamp(4, maxSegments).toInt();
    final double step = theta / segments;

    final List<Offset> points = [p1];
    for (int i = 1; i < segments; i++) {
      final double angle = startAngle + i * step;
      final double x = cx + radius * math.cos(angle);
      final double y = cy + radius * math.sin(angle);
      points.add(Offset(x, y));
    }
    points.add(p2);
    return points;
  }

  /// Appends polyline vertices (including bulge arcs) to a Flutter Path.
  static void addPolylineToPath(
    Path path,
    List<DxfPolylineVertex> vertices, {
    bool isClosed = false,
  }) {
    if (vertices.isEmpty) return;

    path.moveTo(vertices.first.x, vertices.first.y);

    final int count = vertices.length;
    final int endIdx = isClosed ? count : count - 1;

    for (int i = 0; i < endIdx; i++) {
      final v1 = vertices[i];
      final v2 = vertices[(i + 1) % count];

      if (v1.bulge.abs() > 1e-6) {
        final arcPoints = generateBulgeArcPoints(
          v1.offset,
          v2.offset,
          v1.bulge,
        );
        for (int k = 1; k < arcPoints.length; k++) {
          path.lineTo(arcPoints[k].dx, arcPoints[k].dy);
        }
      } else {
        path.lineTo(v2.x, v2.y);
      }
    }

    if (isClosed) {
      path.close();
    }
  }

  /// Generates sample points for an Ellipse.
  static List<Offset> generateEllipsePoints(
    Offset center,
    Offset majorAxisEndOffset,
    double minorRatio, {
    double startParam = 0.0,
    double endParam = 2 * math.pi,
    int segments = 64,
  }) {
    final double a = majorAxisEndOffset.distance;
    if (a < 1e-7) return [center];

    final double b = a * minorRatio;
    final double phi = math.atan2(majorAxisEndOffset.dy, majorAxisEndOffset.dx);

    double sweep = endParam - startParam;
    if (sweep <= 0) sweep += 2 * math.pi;

    final int numPoints = (segments * (sweep / (2 * math.pi))).clamp(8, segments).toInt();
    final double step = sweep / numPoints;

    final List<Offset> points = [];
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);

    for (int i = 0; i <= numPoints; i++) {
      final double t = startParam + i * step;
      final double cosT = math.cos(t);
      final double sinT = math.sin(t);

      final double x = center.dx + a * cosT * cosPhi - b * sinT * sinPhi;
      final double y = center.dy + a * cosT * sinPhi + b * sinT * cosPhi;
      points.add(Offset(x, y));
    }
    return points;
  }

  /// Evaluates a B-Spline curve using the Cox-de Boor algorithm.
  static List<Offset> evaluateSpline(
    int degree,
    List<Offset> controlPoints, {
    List<double>? knots,
    List<double>? weights,
    int sampleCount = 100,
  }) {
    final int n = controlPoints.length - 1;
    final int p = degree;

    if (n < p || controlPoints.isEmpty) {
      return controlPoints;
    }

    // Generate clamped uniform knot vector if not provided or invalid
    List<double> k = knots ?? [];
    final int expectedKnots = n + p + 2;
    if (k.length != expectedKnots) {
      k = List<double>.filled(expectedKnots, 0.0);
      for (int i = 0; i <= p; i++) {
        k[i] = 0.0;
      }
      for (int i = p + 1; i <= n; i++) {
        k[i] = (i - p) / (n - p + 1.0);
      }
      for (int i = n + 1; i < expectedKnots; i++) {
        k[i] = 1.0;
      }
    }

    final double uMin = k[p];
    final double uMax = k[n + 1];
    final double uRange = uMax - uMin;

    if (uRange <= 1e-7) {
      return controlPoints;
    }

    final List<Offset> result = [];
    final int steps = sampleCount.clamp(20, 200);

    for (int step = 0; step <= steps; step++) {
      final double u = (step == steps) ? uMax - 1e-7 : uMin + (step / steps) * uRange;

      // Find knot span index s such that k[s] <= u < k[s+1]
      int s = p;
      while (s < n && k[s + 1] <= u) {
        s++;
      }

      // De Boor's algorithm
      final List<Offset> d = List.generate(p + 1, (j) => controlPoints[s - p + j]);
      final List<double> w = (weights != null && weights.length == controlPoints.length)
          ? List.generate(p + 1, (j) => weights[s - p + j])
          : List.filled(p + 1, 1.0);

      // Homogeneous coordinates (w*x, w*y, w)
      final List<double> wx = List.generate(p + 1, (j) => d[j].dx * w[j]);
      final List<double> wy = List.generate(p + 1, (j) => d[j].dy * w[j]);
      final List<double> ww = List.from(w);

      for (int r = 1; r <= p; r++) {
        for (int j = p; j >= r; j--) {
          final int knotIdx = s - p + j;
          final double denom = k[knotIdx + p - r + 1] - k[knotIdx];
          final double alpha = (denom.abs() > 1e-9) ? (u - k[knotIdx]) / denom : 0.0;

          wx[j] = (1.0 - alpha) * wx[j - 1] + alpha * wx[j];
          wy[j] = (1.0 - alpha) * wy[j - 1] + alpha * wy[j];
          ww[j] = (1.0 - alpha) * ww[j - 1] + alpha * ww[j];
        }
      }

      final double finalW = (ww[p].abs() > 1e-9) ? ww[p] : 1.0;
      result.add(Offset(wx[p] / finalW, wy[p] / finalW));
    }

    return result;
  }

  /// Formats raw CAD coordinate/drawing-unit value without unit conversion.
  static String formatCadNumber(double value) {
    if (value.abs() < 1e-4) return '0.00';
    if (value.abs() >= 10000) {
      return value.toStringAsFixed(1);
    } else if (value.abs() >= 100) {
      return value.toStringAsFixed(2);
    } else {
      return value.toStringAsFixed(3);
    }
  }

  /// Formats real CAD distance converted from drawing units to meters (or display units).
  static String formatDistance(double distance, {DxfUnit unit = DxfUnit.meters}) {
    final double distInMeters = distance * unit.toMeters;
    if (distInMeters.abs() < 1e-4) return '0.00';
    if (distInMeters >= 10000) {
      return distInMeters.toStringAsFixed(1);
    } else if (distInMeters >= 100) {
      return distInMeters.toStringAsFixed(2);
    } else {
      return distInMeters.toStringAsFixed(2);
    }
  }

  /// Formats angle in degrees.
  static String formatAngle(double angleDeg) {
    double a = angleDeg % 360.0;
    if (a < 0) a += 360.0;
    return '${a.toStringAsFixed(1)}°';
  }

  /// Calculates polygon area using the Shoelace (Gauss) formula.
  static double calculatePolygonArea(List<Offset> points) {
    if (points.length < 3) return 0.0;
    double area = 0.0;
    final int n = points.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += points[i].dx * points[j].dy;
      area -= points[j].dx * points[i].dy;
    }
    return (area / 2.0).abs();
  }

  /// Calculates polygon perimeter.
  static double calculatePolygonPerimeter(List<Offset> points, {bool isClosed = true}) {
    if (points.length < 2) return 0.0;
    double perim = 0.0;
    final int end = isClosed ? points.length : points.length - 1;
    for (int i = 0; i < end; i++) {
      final j = (i + 1) % points.length;
      perim += (points[j] - points[i]).distance;
    }
    return perim;
  }

  /// Calculates the geometric centroid (center of mass) of a polygon.
  static Offset calculatePolygonCentroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    if (points.length == 1) return points.first;
    if (points.length == 2) {
      return Offset(
        (points[0].dx + points[1].dx) / 2.0,
        (points[0].dy + points[1].dy) / 2.0,
      );
    }

    double cx = 0.0;
    double cy = 0.0;
    double signedArea = 0.0;
    final int n = points.length;

    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final double a = points[i].dx * points[j].dy - points[j].dx * points[i].dy;
      signedArea += a;
      cx += (points[i].dx + points[j].dx) * a;
      cy += (points[i].dy + points[j].dy) * a;
    }

    signedArea *= 0.5;
    if (signedArea.abs() < 1e-7) {
      // Fallback to simple average if points are collinear or self-cancelling
      double avgX = 0.0;
      double avgY = 0.0;
      for (final p in points) {
        avgX += p.dx;
        avgY += p.dy;
      }
      return Offset(avgX / n, avgY / n);
    }

    cx /= (6.0 * signedArea);
    cy /= (6.0 * signedArea);
    return Offset(cx, cy);
  }

  /// Calculates the included angle in degrees between two rays: vertex -> p1 and vertex -> p2.
  /// Returns value in range [0.0, 180.0].
  static double calculateAngleBetweenVectors(Offset vertex, Offset p1, Offset p2) {
    final double v1x = p1.dx - vertex.dx;
    final double v1y = p1.dy - vertex.dy;
    final double v2x = p2.dx - vertex.dx;
    final double v2y = p2.dy - vertex.dy;

    final double len1 = math.sqrt(v1x * v1x + v1y * v1y);
    final double len2 = math.sqrt(v2x * v2x + v2y * v2y);

    if (len1 < 1e-9 || len2 < 1e-9) return 0.0;

    final double dot = v1x * v2x + v1y * v2y;
    final double cosTheta = (dot / (len1 * len2)).clamp(-1.0, 1.0);
    return math.acos(cosTheta) * 180.0 / math.pi;
  }

  /// Calculates center and radius of a circle passing through 3 points (circumcircle).
  /// Returns null if points are collinear or invalid.
  static ({Offset center, double radius})? circleFrom3Points(Offset p1, Offset p2, Offset p3) {
    final double d = 2.0 *
        (p1.dx * (p2.dy - p3.dy) +
            p2.dx * (p3.dy - p1.dy) +
            p3.dx * (p1.dy - p2.dy));

    if (d.abs() < 1e-7) {
      return null; // Collinear
    }

    final double p1Sq = p1.dx * p1.dx + p1.dy * p1.dy;
    final double p2Sq = p2.dx * p2.dx + p2.dy * p2.dy;
    final double p3Sq = p3.dx * p3.dx + p3.dy * p3.dy;

    final double cx = (p1Sq * (p2.dy - p3.dy) +
            p2Sq * (p3.dy - p1.dy) +
            p3Sq * (p1.dy - p2.dy)) /
        d;

    final double cy = (p1Sq * (p3.dx - p2.dx) +
            p2Sq * (p1.dx - p3.dx) +
            p3Sq * (p2.dx - p1.dx)) /
        d;

    final center = Offset(cx, cy);
    final radius = (p1 - center).distance;
    return (center: center, radius: radius);
  }

  /// Formats area for human display, converting from drawing units to square meters (m²).
  ///
  /// For instance, if drawing units are centimeters (INSUNITS=5):
  /// 1 cm² = 0.0001 m² (area / 10000.0).
  /// A closet of 69,878 cm² -> 6.99 m².
  static String formatArea(double areaCad, {DxfUnit unit = DxfUnit.meters, int? decimals}) {
    final double areaM2 = areaCad * (unit.toMeters * unit.toMeters);
    if (areaM2.abs() < 1e-4) return '0.00 m²';
    if (areaM2 >= 10000.0) {
      final double ha = areaM2 / 10000.0;
      return '${areaM2.toStringAsFixed(decimals ?? 1)} m² (${ha.toStringAsFixed(2)} ha)';
    } else if (areaM2 >= 100.0) {
      return '${areaM2.toStringAsFixed(decimals ?? 2)} m²';
    } else {
      final int d = decimals ?? (unit != DxfUnit.meters ? 2 : 3);
      return '${areaM2.toStringAsFixed(d)} m²';
    }
  }
}

/// Fast 2D Affine Transformation Matrix for CAD entities and blocks.
/// Represents the transformation:
///   [ cx ]   [ m00  m01  m02 ] [ lx ]
///   [ cy ] = [ m10  m11  m12 ] [ ly ]
///   [  1 ]   [  0    0    1  ] [  1 ]
class DxfAffineMatrix {
  final double m00, m01, m02;
  final double m10, m11, m12;

  const DxfAffineMatrix({
    required this.m00,
    required this.m01,
    required this.m02,
    required this.m10,
    required this.m11,
    required this.m12,
  });

  /// Identity matrix.
  static const DxfAffineMatrix identity = DxfAffineMatrix(
    m00: 1.0, m01: 0.0, m02: 0.0,
    m10: 0.0, m11: 1.0, m12: 0.0,
  );

  /// Creates a matrix mapping block local coordinates (relative to block basePoint)
  /// directly to Canvas screen pixels:
  factory DxfAffineMatrix.forInsert({
    required double scaleX,
    required double scaleY,
    required double rotationDeg,
    required Offset canvasOrigin, // toCanvas(insertPoint)
    required double fitScale,
  }) {
    final rad = rotationDeg * math.pi / 180.0;
    final c = math.cos(rad);
    final s = math.sin(rad);

    return DxfAffineMatrix(
      m00: scaleX * c * fitScale,
      m01: -scaleY * s * fitScale,
      m02: canvasOrigin.dx,
      m10: -scaleX * s * fitScale,
      m11: -scaleY * c * fitScale,
      m12: canvasOrigin.dy,
    );
  }

  /// Creates a local 2D affine matrix for a nested insert inside a parent block:
  factory DxfAffineMatrix.forNestedInsert({
    required Offset insertPoint,
    required Offset parentBasePoint,
    required double scaleX,
    required double scaleY,
    required double rotationDeg,
  }) {
    final rad = rotationDeg * math.pi / 180.0;
    final c = math.cos(rad);
    final s = math.sin(rad);

    return DxfAffineMatrix(
      m00: scaleX * c,
      m01: -scaleY * s,
      m02: insertPoint.dx - parentBasePoint.dx,
      m10: scaleX * s,
      m11: scaleY * c,
      m12: insertPoint.dy - parentBasePoint.dy,
    );
  }

  /// Evaluates transformed position on Canvas for block-relative point (lx, ly).
  @pragma('vm:prefer-inline')
  Offset transform(double lx, double ly) {
    return Offset(
      m00 * lx + m01 * ly + m02,
      m10 * lx + m11 * ly + m12,
    );
  }

  /// Composes this matrix (parent) with a child matrix: M_composed = this * child
  DxfAffineMatrix multiply(DxfAffineMatrix child) {
    return DxfAffineMatrix(
      m00: m00 * child.m00 + m01 * child.m10,
      m01: m00 * child.m01 + m01 * child.m11,
      m02: m00 * child.m02 + m01 * child.m12 + m02,
      m10: m10 * child.m00 + m11 * child.m10,
      m11: m10 * child.m01 + m11 * child.m11,
      m12: m10 * child.m02 + m11 * child.m12 + m12,
    );
  }

  /// Static 16-element Float64List reused to avoid heap allocation during Path.transform.
  static final Float64List _storage = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  /// Returns 4x4 matrix in column-major order for Skia Path.transform() or Canvas.transform().
  Float64List toFloat64List() {
    _storage[0] = m00;
    _storage[1] = m10;
    _storage[4] = m01;
    _storage[5] = m11;
    _storage[12] = m02;
    _storage[13] = m12;
    return _storage;
  }
}

/// Represents an Object Coordinate System (OCS) transformation to World Coordinate System (WCS).
/// Implements the official Autodesk DXF Arbitrary Axis Algorithm.
class OcsTransform {
  final double nx;
  final double ny;
  final double nz;

  // Unit vector of OCS X-axis in WCS
  final double xx;
  final double xy;
  final double xz;

  // Unit vector of OCS Y-axis in WCS
  final double yx;
  final double yy;
  final double yz;

  final bool isIdentity;

  const OcsTransform._({
    required this.nx,
    required this.ny,
    required this.nz,
    required this.xx,
    required this.xy,
    required this.xz,
    required this.yx,
    required this.yy,
    required this.yz,
    required this.isIdentity,
  });

  /// Identity OCS transformation where OCS matches WCS (normal is 0, 0, 1).
  static const OcsTransform identity = OcsTransform._(
    nx: 0.0,
    ny: 0.0,
    nz: 1.0,
    xx: 1.0,
    xy: 0.0,
    xz: 0.0,
    yx: 0.0,
    yy: 1.0,
    yz: 0.0,
    isIdentity: true,
  );

  /// Computes OCS -> WCS transformation using the Autodesk Arbitrary Axis Algorithm.
  factory OcsTransform.fromExtrusion(double nx, double ny, double nz) {
    final double lenSq = nx * nx + ny * ny + nz * nz;
    if (lenSq < 1e-12) {
      return identity;
    }

    final double len = math.sqrt(lenSq);
    final double unx = nx / len;
    final double uny = ny / len;
    final double unz = nz / len;

    // Check if close to identity (0, 0, 1)
    if (unx.abs() < 1e-6 && uny.abs() < 1e-6 && (unz - 1.0).abs() < 1e-6) {
      return identity;
    }

    // Arbitrary Axis Algorithm:
    // If (|nx| < 1/64) and (|ny| < 1/64), Ax = (0, 1, 0) x N
    // Otherwise, Ax = (0, 0, 1) x N
    final double axX;
    final double axY;
    final double axZ;

    const double kThreshold = 1.0 / 64.0; // 0.015625
    if (unx.abs() < kThreshold && uny.abs() < kThreshold) {
      // (0, 1, 0) x (unx, uny, unz) = (unz, 0, -unx)
      axX = unz;
      axY = 0.0;
      axZ = -unx;
    } else {
      // (0, 0, 1) x (unx, uny, unz) = (-uny, unx, 0)
      axX = -uny;
      axY = unx;
      axZ = 0.0;
    }

    // Normalize Ax to get X_ocs
    final double axLen = math.sqrt(axX * axX + axY * axY + axZ * axZ);
    if (axLen < 1e-12) {
      return identity;
    }
    final double uxx = axX / axLen;
    final double uxy = axY / axLen;
    final double uxz = axZ / axLen;

    // Y_ocs = N x X_ocs
    final double uyx = uny * uxz - unz * uxy;
    final double uyy = unz * uxx - unx * uxz;
    final double uyz = unx * uxy - uny * uxx;

    return OcsTransform._(
      nx: unx,
      ny: uny,
      nz: unz,
      xx: uxx,
      xy: uxy,
      xz: uxz,
      yx: uyx,
      yy: uyy,
      yz: uyz,
      isIdentity: false,
    );
  }

  /// Transforms an OCS point (x, y, elevation) to 2D WCS projection (Offset).
  @pragma('vm:prefer-inline')
  Offset toWcs2D(double ocsX, double ocsY, [double elevation = 0.0]) {
    if (isIdentity) {
      return Offset(ocsX, ocsY);
    }
    final double wx = ocsX * xx + ocsY * yx + elevation * nx;
    final double wy = ocsX * xy + ocsY * yy + elevation * ny;
    return Offset(wx, wy);
  }

  /// Transforms an OCS angle in degrees to WCS 2D angle in degrees [0, 360).
  double angleToWcs(double angleDeg) {
    if (isIdentity) {
      double a = angleDeg % 360.0;
      if (a < 0) a += 360.0;
      return a;
    }
    final double rad = angleDeg * math.pi / 180.0;
    final double cosA = math.cos(rad);
    final double sinA = math.sin(rad);
    final double vx = cosA * xx + sinA * yx;
    final double vy = cosA * xy + sinA * yy;
    double a = math.atan2(vy, vx) * 180.0 / math.pi;
    if (a < 0) a += 360.0;
    return a;
  }

  /// Transforms an arc's start and end angles from OCS to 2D WCS.
  /// If nz < 0 (pointing in -Z direction), the arc sweep direction in XY projection
  /// is reversed from CCW to CW, so start and end angles are swapped to keep
  /// the CCW representation consistent with standard 2D canvas drawing.
  ({double startAngleDeg, double endAngleDeg}) transformArcAngles(
    double startA,
    double endA,
  ) {
    if (isIdentity) {
      return (startAngleDeg: startA, endAngleDeg: endA);
    }

    final double a1 = angleToWcs(startA);
    final double a2 = angleToWcs(endA);

    if (nz < 0) {
      return (startAngleDeg: a2, endAngleDeg: a1);
    } else {
      return (startAngleDeg: a1, endAngleDeg: a2);
    }
  }

  /// Transforms a polyline bulge factor.
  /// If nz < 0, the orientation of curvature is inverted.
  double transformBulge(double bulge) {
    if (isIdentity || nz >= 0) {
      return bulge;
    }
    return -bulge;
  }
}

