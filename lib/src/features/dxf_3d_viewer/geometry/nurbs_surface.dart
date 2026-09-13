import 'dart:math' as math;
import '../models/mesh_3d.dart';

/// 4D Homogeneous coordinate representation for Rational B-Splines (NURBS).
class Vector4 {
  final double x;
  final double y;
  final double z;
  final double w;

  const Vector4(this.x, this.y, this.z, this.w);

  Vector4 operator +(Vector4 o) => Vector4(x + o.x, y + o.y, z + o.z, w + o.w);
  Vector4 operator *(double s) => Vector4(x * s, y * s, z * s, w * s);

  Vector3 toVector3() {
    if (w.abs() > 1e-12) {
      return Vector3(x / w, y / w, z / w);
    }
    return Vector3(x, y, z);
  }

  @override
  String toString() => 'Vector4($x, $y, $z, $w)';
}

/// Pure-Dart Tensor-Product Non-Uniform Rational B-Spline (NURBS) Surface Evaluator.
class NurbsSurface {
  final int degreeU;
  final int degreeV;
  final List<double> knotsU;
  final List<double> knotsV;
  /// Grid of control points: outer index is u, inner index is v.
  /// controlPoints[u_idx][v_idx], size: (numU) x (numV).
  final List<List<Vector3>> controlPoints;
  /// Optional grid of rational weights: weights[u_idx][v_idx].
  final List<List<double>>? weights;
  final bool isClosedU;
  final bool isClosedV;

  NurbsSurface({
    required this.degreeU,
    required this.degreeV,
    required List<double> knotsU,
    required List<double> knotsV,
    required this.controlPoints,
    this.weights,
    this.isClosedU = false,
    this.isClosedV = false,
  })  : knotsU = _validateOrFixKnots(knotsU, controlPoints.length - 1, degreeU),
        knotsV = _validateOrFixKnots(knotsV, (controlPoints.isNotEmpty ? controlPoints[0].length : 1) - 1, degreeV);

  int get numU => controlPoints.length;
  int get numV => controlPoints.isNotEmpty ? controlPoints[0].length : 0;

  double get uMin => knotsU.length > degreeU ? knotsU[degreeU] : 0.0;
  double get uMax => knotsU.length > numU ? knotsU[numU] : 1.0;
  double get vMin => knotsV.length > degreeV ? knotsV[degreeV] : 0.0;
  double get vMax => knotsV.length > numV ? knotsV[numV] : 1.0;

  /// Helper to validate or generate clamped uniform knot vector if invalid
  static List<double> _validateOrFixKnots(List<double> knots, int n, int p) {
    final expectedCount = n + p + 2;
    if (knots.length == expectedCount) {
      return List<double>.from(knots);
    }
    if (knots.length >= n + p + 1) {
      // Sometimes standard omits 1 end knot; pad it
      final list = List<double>.from(knots);
      while (list.length < expectedCount) {
        list.add(list.last);
      }
      return list;
    }
    return createClampedKnotVector(n, p);
  }

  /// Generates a clamped uniform knot vector for degree [p] with [n + 1] control points.
  static List<double> createClampedKnotVector(int n, int p) {
    final int count = n + p + 2;
    final List<double> k = List<double>.filled(count, 0.0);
    for (int i = 0; i <= p; i++) {
      k[i] = 0.0;
    }
    final int innerCount = n - p;
    for (int i = 1; i <= innerCount; i++) {
      k[p + i] = i / (innerCount + 1.0);
    }
    for (int i = n + 1; i < count; i++) {
      k[i] = 1.0;
    }
    return k;
  }

  /// Finds knot span index `s` such that `k[s] <= u < k[s+1]`.
  static int findKnotSpan(int n, int p, double u, List<double> k) {
    if (u >= k[n + 1]) {
      int s = n;
      while (s > p && (k[s] - k[s + 1]).abs() < 1e-12) {
        s--;
      }
      return s;
    }
    if (u <= k[p]) {
      return p;
    }
    int low = p;
    int high = n + 1;
    int mid = (low + high) ~/ 2;
    while (u < k[mid] || u >= k[mid + 1]) {
      if (u < k[mid]) {
        high = mid;
      } else {
        low = mid;
      }
      mid = (low + high) ~/ 2;
      if (low >= high - 1) break;
    }
    return mid;
  }

  /// 1D Cox-de Boor algorithm in 4D homogeneous coordinates.
  static Vector4 deBoor1D(int p, List<Vector4> cp, List<double> k, double u, int s) {
    final List<Vector4> d = List.generate(p + 1, (j) => cp[s - p + j]);
    for (int r = 1; r <= p; r++) {
      for (int j = p; j >= r; j--) {
        final int knotIdx = s - p + j;
        final double denom = k[knotIdx + p - r + 1] - k[knotIdx];
        final double alpha = (denom.abs() > 1e-12) ? (u - k[knotIdx]) / denom : 0.0;
        d[j] = Vector4(
          (1.0 - alpha) * d[j - 1].x + alpha * d[j].x,
          (1.0 - alpha) * d[j - 1].y + alpha * d[j].y,
          (1.0 - alpha) * d[j - 1].z + alpha * d[j].z,
          (1.0 - alpha) * d[j - 1].w + alpha * d[j].w,
        );
      }
    }
    return d[p];
  }

  /// Evaluates 3D Cartesian point on the NURBS surface at parameter coordinates (u, v).
  Vector3 evaluate(double u, double v) {
    if (numU == 0 || numV == 0) return Vector3.zero;

    final n = numU - 1;
    final m = numV - 1;
    final p = degreeU;
    final q = degreeV;

    final clampedU = u.clamp(uMin, uMax);
    final clampedV = v.clamp(vMin, vMax);

    final spanV = findKnotSpan(m, q, clampedV, knotsV);
    final spanU = findKnotSpan(n, p, clampedU, knotsU);

    // Evaluate intermediate 4D points along u for each relevant column in v
    final List<Vector4> intermediateV = [];

    for (int j = spanV - q; j <= spanV; j++) {
      final List<Vector4> columnU = List.generate(numU, (i) {
        final pt = controlPoints[i][j];
        final w = (weights != null && i < weights!.length && j < weights![i].length)
            ? weights![i][j]
            : 1.0;
        return Vector4(pt.x * w, pt.y * w, pt.z * w, w);
      });

      final evaluatedU = deBoor1D(p, columnU, knotsU, clampedU, spanU);
      intermediateV.add(evaluatedU);
    }

    // Evaluate along v using intermediate points
    final result4D = deBoor1D(q, intermediateV, knotsV, clampedV, q);
    return result4D.toVector3();
  }

  /// Evaluates surface normal at (u, v) using central difference partial derivatives.
  Vector3 evaluateNormal(double u, double v) {
    final du = math.max((uMax - uMin) * 1e-4, 1e-6);
    final dv = math.max((vMax - vMin) * 1e-4, 1e-6);

    final pU0 = evaluate(math.max(u - du, uMin), v);
    final pU1 = evaluate(math.min(u + du, uMax), v);
    final pV0 = evaluate(u, math.max(v - dv, vMin));
    final pV1 = evaluate(u, math.min(v + dv, vMax));

    final tu = pU1 - pU0;
    final tv = pV1 - pV0;
    final norm = tu.cross(tv).normalized();
    if (norm.lengthSquared > 1e-8) {
      return norm;
    }
    return const Vector3(0, 0, 1);
  }

  /// Tessellates the NURBS surface into a mesh of [Triangle3D]s.
  List<Triangle3D> tessellate({
    int? samplesU,
    int? samplesV,
    double? domainUMin,
    double? domainUMax,
    double? domainVMin,
    double? domainVMax,
  }) {
    if (numU == 0 || numV == 0) return [];

    final minU = domainUMin ?? uMin;
    final maxU = domainUMax ?? uMax;
    final minV = domainVMin ?? vMin;
    final maxV = domainVMax ?? vMax;

    if (maxU <= minU || maxV <= minV) return [];

    // Adaptive sampling based on degrees and control points count
    final nStepsU = samplesU ?? (numU * 4).clamp(12, 32);
    final nStepsV = samplesV ?? (numV * 4).clamp(12, 32);

    final List<List<Vector3>> grid = [];

    final stepU = (maxU - minU) / nStepsU;
    final stepV = (maxV - minV) / nStepsV;

    for (int i = 0; i <= nStepsU; i++) {
      final uVal = (i == nStepsU) ? maxU : minU + i * stepU;
      final List<Vector3> row = [];
      for (int j = 0; j <= nStepsV; j++) {
        final vVal = (j == nStepsV) ? maxV : minV + j * stepV;
        row.add(evaluate(uVal, vVal));
      }
      grid.add(row);
    }

    final List<Triangle3D> triangles = [];

    for (int i = 0; i < nStepsU; i++) {
      for (int j = 0; j < nStepsV; j++) {
        final p00 = grid[i][j];
        final p10 = grid[i + 1][j];
        final p11 = grid[i + 1][j + 1];
        final p01 = grid[i][j + 1];

        // Check for degenerate edges (e.g. pole at sphere/cone cap)
        final d00_01 = p00.distanceTo(p01) < 1e-8;
        final d10_11 = p10.distanceTo(p11) < 1e-8;
        final d00_10 = p00.distanceTo(p10) < 1e-8;
        final d01_11 = p01.distanceTo(p11) < 1e-8;

        if (d00_01) {
          // Degenerates into a single triangle p00, p10, p11
          final t = Triangle3D(v0: p00, v1: p10, v2: p11, isDoubleSided: true);
          if (t.area > 1e-10) triangles.add(t);
        } else if (d10_11) {
          // Degenerates into a single triangle p00, p10, p01
          final t = Triangle3D(v0: p00, v1: p10, v2: p01, isDoubleSided: true);
          if (t.area > 1e-10) triangles.add(t);
        } else if (d00_10) {
          final t = Triangle3D(v0: p00, v1: p11, v2: p01, isDoubleSided: true);
          if (t.area > 1e-10) triangles.add(t);
        } else if (d01_11) {
          final t = Triangle3D(v0: p00, v1: p10, v2: p01, isDoubleSided: true);
          if (t.area > 1e-10) triangles.add(t);
        } else {
          // Standard Quad -> Two Triangles
          final t1 = Triangle3D(v0: p00, v1: p10, v2: p11, isDoubleSided: true);
          final t2 = Triangle3D(v0: p00, v1: p11, v2: p01, isDoubleSided: true);
          if (t1.area > 1e-10) triangles.add(t1);
          if (t2.area > 1e-10) triangles.add(t2);
        }
      }
    }

    return triangles;
  }
}

/// 3D NURBS Curve Evaluator for IGES Entity 126 and STEP B_SPLINE_CURVE.
class NurbsCurve3D {
  final int degree;
  final List<double> knots;
  final List<Vector3> controlPoints;
  final List<double>? weights;

  NurbsCurve3D({
    required this.degree,
    required List<double> knots,
    required this.controlPoints,
    this.weights,
  }) : knots = NurbsSurface._validateOrFixKnots(knots, controlPoints.length - 1, degree);

  int get n => controlPoints.length - 1;
  double get uMin => knots.length > degree ? knots[degree] : 0.0;
  double get uMax => knots.length > n + 1 ? knots[n + 1] : 1.0;

  Vector3 evaluate(double u) {
    if (controlPoints.isEmpty) return Vector3.zero;
    final clampedU = u.clamp(uMin, uMax);
    final s = NurbsSurface.findKnotSpan(n, degree, clampedU, knots);

    final List<Vector4> cp4d = List.generate(controlPoints.length, (i) {
      final pt = controlPoints[i];
      final w = (weights != null && i < weights!.length) ? weights![i] : 1.0;
      return Vector4(pt.x * w, pt.y * w, pt.z * w, w);
    });

    final res4d = NurbsSurface.deBoor1D(degree, cp4d, knots, clampedU, s);
    return res4d.toVector3();
  }

  List<Vector3> samplePoints({int samples = 32, double? startU, double? endU}) {
    if (controlPoints.isEmpty) return [];
    final minU = startU ?? uMin;
    final maxU = endU ?? uMax;
    if (maxU <= minU) return controlPoints;

    final List<Vector3> pts = [];
    final steps = samples.clamp(8, 128);
    for (int i = 0; i <= steps; i++) {
      final u = (i == steps) ? maxU : minU + (i / steps) * (maxU - minU);
      pts.add(evaluate(u));
    }
    return pts;
  }
}
