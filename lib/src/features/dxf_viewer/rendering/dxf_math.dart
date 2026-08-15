import 'dart:math' as math;
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

  /// Formats real CAD distance for human display.
  static String formatDistance(double distance) {
    if (distance.abs() < 1e-4) return '0.00';
    if (distance >= 10000) {
      return distance.toStringAsFixed(1);
    } else if (distance >= 100) {
      return distance.toStringAsFixed(2);
    } else {
      return distance.toStringAsFixed(3);
    }
  }

  /// Formats angle in degrees.
  static String formatAngle(double angleDeg) {
    double a = angleDeg % 360.0;
    if (a < 0) a += 360.0;
    return '${a.toStringAsFixed(1)}°';
  }
}
