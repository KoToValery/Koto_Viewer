import 'dart:math' as math;
import 'dart:ui';

import 'dicom_parser.dart';

/// 3D Vector for DICOM Patient-Based Coordinate System (RCS) calculations.
class DicomVector3 {
  final double x;
  final double y;
  final double z;

  const DicomVector3(this.x, this.y, this.z);

  static const DicomVector3 zero = DicomVector3(0, 0, 0);

  DicomVector3 operator +(DicomVector3 o) =>
      DicomVector3(x + o.x, y + o.y, z + o.z);

  DicomVector3 operator -(DicomVector3 o) =>
      DicomVector3(x - o.x, y - o.y, z - o.z);

  DicomVector3 operator *(double s) =>
      DicomVector3(x * s, y * s, z * s);

  DicomVector3 operator /(double s) =>
      DicomVector3(x / s, y / s, z / s);

  double dot(DicomVector3 o) => x * o.x + y * o.y + z * o.z;

  DicomVector3 cross(DicomVector3 o) => DicomVector3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get lengthSquared => x * x + y * y + z * z;

  double get length => math.sqrt(lengthSquared);

  DicomVector3 normalized() {
    final l = length;
    if (l < 1e-9) return DicomVector3.zero;
    return this / l;
  }

  @override
  String toString() => 'DicomVector3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// Represents an on-screen cross-reference line projected from another slice.
class DicomReferenceLine {
  /// Start point in target slice's pixel coordinates.
  final Offset start;

  /// End point in target slice's pixel coordinates.
  final Offset end;

  /// Physical start point in target slice (extent of source slice)
  final Offset? physicalStart;

  /// Physical end point in target slice (extent of source slice)
  final Offset? physicalEnd;

  /// Source series description (e.g. "pd/spir/COR", "Axial")
  final String? sourceSeriesDescription;

  /// 0-indexed slice number of the source slice
  final int sourceSliceIndex;

  /// Total slices in the source series
  final int sourceTotalSlices;

  const DicomReferenceLine({
    required this.start,
    required this.end,
    this.physicalStart,
    this.physicalEnd,
    this.sourceSeriesDescription,
    required this.sourceSliceIndex,
    required this.sourceTotalSlices,
  });
}

/// Geometry engine implementing DICOM PS3.3 C.7.6.2 (Image Plane Module)
/// for calculating 3D plane intersections, scout lines, and spatial localizers.
class DicomGeometry {
  const DicomGeometry._();

  /// Extract plane normal vector (u x v) from DICOM header.
  static DicomVector3? getNormal(DicomHeader header) {
    final orientation = header.imageOrientationPatient;
    if (orientation == null || orientation.length < 6) {
      return null;
    }
    final u = DicomVector3(orientation[0], orientation[1], orientation[2]);
    final v = DicomVector3(orientation[3], orientation[4], orientation[5]);
    final n = u.cross(v);
    if (n.lengthSquared < 1e-6) return null;
    return n.normalized();
  }

  /// Returns true if two slices have parallel image planes (angle < ~1 degree).
  static bool arePlanesParallel(DicomHeader h1, DicomHeader h2) {
    final n1 = getNormal(h1);
    final n2 = getNormal(h2);
    if (n1 == null || n2 == null) return false;
    final dot = (n1.dot(n2)).abs();
    return (1.0 - dot) < 1e-4;
  }

  /// Calculates the 2D intersection line (in pixel coordinates of [targetHeader])
  /// formed by the intersection of [sourceHeader]'s plane with [targetHeader]'s plane.
  ///
  /// Returns `null` if the planes do not intersect, are parallel, or if required
  /// spatial tags are missing.
  static DicomReferenceLine? calculateIntersection({
    required DicomHeader targetHeader,
    required DicomHeader sourceHeader,
    required int sourceSliceIndex,
    required int sourceTotalSlices,
    String? sourceSeriesDescription,
  }) {
    // 1. Validate Target Header geometry
    final targetPosList = targetHeader.imagePositionPatient;
    final targetOrientList = targetHeader.imageOrientationPatient;
    if (targetPosList == null || targetPosList.length < 3 ||
        targetOrientList == null || targetOrientList.length < 6) {
      return null;
    }

    // 2. Validate Source Header geometry
    final sourcePosList = sourceHeader.imagePositionPatient;
    final sourceOrientList = sourceHeader.imageOrientationPatient;
    if (sourcePosList == null || sourcePosList.length < 3 ||
        sourceOrientList == null || sourceOrientList.length < 6) {
      return null;
    }

    final targetP = DicomVector3(targetPosList[0], targetPosList[1], targetPosList[2]);
    final targetU = DicomVector3(targetOrientList[0], targetOrientList[1], targetOrientList[2]).normalized();
    final targetV = DicomVector3(targetOrientList[3], targetOrientList[4], targetOrientList[5]).normalized();
    final targetN = targetU.cross(targetV).normalized();

    final sourceP = DicomVector3(sourcePosList[0], sourcePosList[1], sourcePosList[2]);
    final sourceU = DicomVector3(sourceOrientList[0], sourceOrientList[1], sourceOrientList[2]).normalized();
    final sourceV = DicomVector3(sourceOrientList[3], sourceOrientList[4], sourceOrientList[5]).normalized();
    final sourceN = sourceU.cross(sourceV).normalized();

    // Check if planes are parallel
    final dotNormals = (targetN.dot(sourceN)).abs();
    if ((1.0 - dotNormals) < 1e-4) {
      // Parallel planes don't intersect across the image
      return null;
    }

    // Target pixel spacing in mm
    final targetDx = targetHeader.pixelSpacingCol ?? 1.0;
    final targetDy = targetHeader.pixelSpacingRow ?? 1.0;
    final targetCols = targetHeader.columns.toDouble();
    final targetRows = targetHeader.rows.toDouble();

    // Source dimensions and pixel spacing in mm
    final sourceDx = sourceHeader.pixelSpacingCol ?? 1.0;
    final sourceDy = sourceHeader.pixelSpacingRow ?? 1.0;
    final sourceW = sourceHeader.columns * sourceDx;
    final sourceH = sourceHeader.rows * sourceDy;

    // 3. Compute 4 corners of Source Slice in 3D Patient Coordinates (RCS)
    final c0 = sourceP;
    final c1 = sourceP + (sourceU * sourceW);
    final c2 = sourceP + (sourceU * sourceW) + (sourceV * sourceH);
    final c3 = sourceP + (sourceV * sourceH);

    final corners = [c0, c1, c2, c3];

    // Compute signed distance from each source corner to the target plane:
    // d = (C - targetP) . targetN
    final distances = List<double>.generate(4, (i) => (corners[i] - targetP).dot(targetN));

    // Find intersection points of the source quad edges with the target plane
    final physicalIntersections = <Offset>[];

    for (int i = 0; i < 4; i++) {
      final j = (i + 1) % 4;
      final d1 = distances[i];
      final d2 = distances[j];

      // Check if edge crosses the target plane (opposite signs)
      if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) {
        final t = -d1 / (d2 - d1);
        final q = corners[i] + ((corners[j] - corners[i]) * t);

        // Map 3D point Q to target slice 2D pixel coordinates (c, r)
        final diff = q - targetP;
        final col = diff.dot(targetU) / targetDx;
        final row = diff.dot(targetV) / targetDy;
        physicalIntersections.add(Offset(col, row));
      } else if (d1.abs() < 1e-5) {
        // Vertex lies on target plane
        final diff = corners[i] - targetP;
        final col = diff.dot(targetU) / targetDx;
        final row = diff.dot(targetV) / targetDy;
        final pt = Offset(col, row);
        if (!physicalIntersections.any((p) => (p - pt).distanceSquared < 1e-4)) {
          physicalIntersections.add(pt);
        }
      }
    }

    // 4. Line equation on target image:
    // Any point on target image is X(c, r) = targetP + c*targetDx*targetU + r*targetDy*targetV
    // Plane of source is: (X - sourceP) . sourceN = 0
    // => a*c + b*r + k = 0
    final a = targetDx * targetU.dot(sourceN);
    final b = targetDy * targetV.dot(sourceN);
    final k = (targetP - sourceP).dot(sourceN);

    // Find intersection of line a*c + b*r + k = 0 with target image bounding box:
    // col in [0, targetCols], row in [0, targetRows]
    final edgePoints = _intersectLineWithRect(a, b, k, targetCols, targetRows);

    if (edgePoints.length < 2 && physicalIntersections.length < 2) {
      return null;
    }

    Offset pStart;
    Offset pEnd;

    if (edgePoints.length >= 2) {
      pStart = edgePoints[0];
      pEnd = edgePoints[1];
    } else {
      pStart = physicalIntersections[0];
      pEnd = physicalIntersections[1];
    }

    Offset? physStart;
    Offset? physEnd;
    if (physicalIntersections.length >= 2) {
      physStart = physicalIntersections[0];
      physEnd = physicalIntersections[1];
    }

    return DicomReferenceLine(
      start: pStart,
      end: pEnd,
      physicalStart: physStart,
      physicalEnd: physEnd,
      sourceSeriesDescription: sourceSeriesDescription ?? sourceHeader.seriesDescription,
      sourceSliceIndex: sourceSliceIndex,
      sourceTotalSlices: sourceTotalSlices,
    );
  }

  /// Intersects the line a*x + b*y + c = 0 with the rectangle [0, w] x [0, h].
  static List<Offset> _intersectLineWithRect(
    double a,
    double b,
    double c,
    double w,
    double h,
  ) {
    final points = <Offset>[];

    void tryAddPoint(double x, double y) {
      if (x >= -0.01 && x <= w + 0.01 && y >= -0.01 && y <= h + 0.01) {
        final clamped = Offset(x.clamp(0.0, w), y.clamp(0.0, h));
        if (!points.any((p) => (p - clamped).distanceSquared < 1e-4)) {
          points.add(clamped);
        }
      }
    }

    // Left edge: x = 0 => b*y + c = 0 => y = -c / b
    if (b.abs() > 1e-7) {
      tryAddPoint(0.0, -c / b);
      // Right edge: x = w => a*w + b*y + c = 0 => y = -(c + a*w) / b
      tryAddPoint(w, -(c + a * w) / b);
    }

    // Top edge: y = 0 => a*x + c = 0 => x = -c / a
    if (a.abs() > 1e-7) {
      tryAddPoint(-c / a, 0.0);
      // Bottom edge: y = h => a*x + b*h + c = 0 => x = -(c + b*h) / a
      tryAddPoint(-(c + b * h) / a, h);
    }

    return points;
  }
}
