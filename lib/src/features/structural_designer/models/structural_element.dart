import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Supported geometric cross-section shapes for columns.
enum ColumnShape {
  rectangular,
  circular,
  lShape,
}

/// Mode for ArchiCAD-like ghost story / trace reference underlay.
enum GhostStoreyMode {
  none,
  below,
  above,
}

/// Represents a structural reinforced concrete column.
class StructuralColumn {
  final String id;
  final String? name;
  final Offset center;
  final ColumnShape shape;
  final double width; // in meters (or diameter if circular, or Leg 1 for L-shape)
  final double height; // in meters (or Leg 2 for L-shape)
  final double rotationRad;
  final double thickness; // in meters (flange/web thickness for L-shape, default 0.25)
  final bool isMirrored; // whether shape is mirrored horizontally

  const StructuralColumn({
    required this.id,
    this.name,
    required this.center,
    this.shape = ColumnShape.rectangular,
    this.width = 0.25,
    this.height = 0.25,
    this.rotationRad = 0.0,
    this.thickness = 0.25,
    this.isMirrored = false,
  });

  /// User-facing column display name (e.g. "К1", "К2"). Falls back to "К" if empty.
  String get displayName => (name != null && name!.trim().isNotEmpty) ? name!.trim() : 'К';

  /// Top-left corner of the column bounding box in CAD coordinates.
  Offset get topLeft => Offset(center.dx - width / 2.0, center.dy + height / 2.0);

  /// Creates a column with its top-left corner positioned at [topLeft] in CAD coordinates.
  factory StructuralColumn.fromTopLeft({
    required String id,
    String? name,
    required Offset topLeft,
    ColumnShape shape = ColumnShape.rectangular,
    double width = 0.25,
    double height = 0.25,
    double rotationRad = 0.0,
    double thickness = 0.25,
    bool isMirrored = false,
  }) {
    final center = Offset(topLeft.dx + width / 2.0, topLeft.dy - height / 2.0);
    return StructuralColumn(
      id: id,
      name: name,
      center: center,
      shape: shape,
      width: width,
      height: height,
      rotationRad: rotationRad,
      thickness: thickness,
      isMirrored: isMirrored,
    );
  }

  /// Calculates the corner vertices of the column in CAD world coordinates,
  /// starting from outer corner in clockwise/counter-clockwise order.
  List<Offset> get polygonVertices {
    if (shape == ColumnShape.circular) {
      // 12-sided polygon approximation for circular column
      const int segments = 12;
      final double r = width / 2.0;
      final List<Offset> pts = [];
      for (int i = 0; i < segments; i++) {
        final double a = 2.0 * math.pi * i / segments;
        pts.add(Offset(
          center.dx + r * math.cos(a),
          center.dy + r * math.sin(a),
        ));
      }
      return pts;
    }

    final double halfW = width / 2.0;
    final double halfH = height / 2.0;
    final cosA = math.cos(rotationRad);
    final sinA = math.sin(rotationRad);

    Offset rotate(double lx, double ly) {
      return Offset(
        center.dx + (lx * cosA - ly * sinA),
        center.dy + (lx * sinA + ly * cosA),
      );
    }

    if (shape == ColumnShape.lShape) {
      // 6-vertex L-shaped corner column: legs width x height, flange thickness
      final double t = math.min(thickness, math.min(width, height) * 0.9);
      if (!isMirrored) {
        return [
          rotate(-halfW, -halfH), // Outer corner
          rotate(halfW, -halfH), // Tip of horizontal leg
          rotate(halfW, -halfH + t),
          rotate(-halfW + t, -halfH + t), // Inner corner
          rotate(-halfW + t, halfH),
          rotate(-halfW, halfH), // Tip of vertical leg
        ];
      } else {
        return [
          rotate(halfW, -halfH), // Outer corner (mirrored)
          rotate(-halfW, -halfH), // Tip of horizontal leg
          rotate(-halfW, -halfH + t),
          rotate(halfW - t, -halfH + t), // Inner corner
          rotate(halfW - t, halfH),
          rotate(halfW, halfH), // Tip of vertical leg
        ];
      }
    }

    // Top-Left, Top-Right, Bottom-Right, Bottom-Left in CAD coordinates (Y up)
    return [
      rotate(-halfW, halfH),
      rotate(halfW, halfH),
      rotate(halfW, -halfH),
      rotate(-halfW, -halfH),
    ];
  }

  Rect get bounds {
    final pts = polygonVertices;
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  StructuralColumn copyWith({
    String? id,
    String? name,
    Offset? center,
    ColumnShape? shape,
    double? width,
    double? height,
    double? rotationRad,
    double? thickness,
    bool? isMirrored,
  }) {
    return StructuralColumn(
      id: id ?? this.id,
      name: name ?? this.name,
      center: center ?? this.center,
      shape: shape ?? this.shape,
      width: width ?? this.width,
      height: height ?? this.height,
      rotationRad: rotationRad ?? this.rotationRad,
      thickness: thickness ?? this.thickness,
      isMirrored: isMirrored ?? this.isMirrored,
    );
  }
}

/// Represents a structural reinforced concrete shear wall (шайба).
/// The line from [start] to [end] is the LEADING REFERENCE LINE (default on the LEFT of the wall).
class StructuralShearWall {
  final String id;
  final Offset start;
  final Offset end;
  final double thickness; // in meters (default 0.25)
  final bool isFlipped; // whether the wall body is flipped to the left side of the line

  const StructuralShearWall({
    required this.id,
    required this.start,
    required this.end,
    this.thickness = 0.25,
    this.isFlipped = false,
  });

  double get length {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get angleRad => math.atan2(end.dy - start.dy, end.dx - start.dx);

  /// 4 corner vertices forming the thick wall box in CAD coordinates.
  /// The line from [start] to [end] is the leading line on the LEFT (or right if flipped).
  List<Offset> get polygonVertices {
    final double l = length;
    if (l < 1e-6) {
      return [start, start, start, start];
    }
    // In CAD coordinates (Y up):
    // Direction vector is (dx/l, dy/l)
    // Left normal is (-dy/l, dx/l)
    // Right normal is (dy/l, -dx/l)
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final normal = isFlipped ? Offset(-dy / l, dx / l) : Offset(dy / l, -dx / l);
    final ox = normal.dx * thickness;
    final oy = normal.dy * thickness;

    return [
      start,
      end,
      Offset(end.dx + ox, end.dy + oy),
      Offset(start.dx + ox, start.dy + oy),
    ];
  }

  StructuralShearWall copyWith({
    String? id,
    Offset? start,
    Offset? end,
    double? thickness,
    bool? isFlipped,
  }) {
    return StructuralShearWall(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      thickness: thickness ?? this.thickness,
      isFlipped: isFlipped ?? this.isFlipped,
    );
  }
}

/// Represents a structural reinforced concrete beam (греда).
class StructuralBeam {
  final String id;
  final Offset start;
  final Offset end;
  final double width; // in meters (b, e.g. 0.25)
  final double depth; // in meters (h, e.g. 0.50)
  final bool isSecondary;

  const StructuralBeam({
    required this.id,
    required this.start,
    required this.end,
    this.width = 0.25,
    this.depth = 0.50,
    this.isSecondary = false,
  });

  double get length {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get angleRad => math.atan2(end.dy - start.dy, end.dx - start.dx);

  /// 4 corner vertices forming the thick beam box centered along the axis.
  List<Offset> get polygonVertices {
    final double l = length;
    if (l < 1e-6) {
      return [start, start, start, start];
    }
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final normal = Offset(dy / l, -dx / l);
    final halfW = width / 2.0;
    final ox = normal.dx * halfW;
    final oy = normal.dy * halfW;

    return [
      Offset(start.dx - ox, start.dy - oy),
      Offset(end.dx - ox, end.dy - oy),
      Offset(end.dx + ox, end.dy + oy),
      Offset(start.dx + ox, start.dy + oy),
    ];
  }

  Rect get bounds {
    final pts = polygonVertices;
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  StructuralBeam copyWith({
    String? id,
    Offset? start,
    Offset? end,
    double? width,
    double? depth,
    bool? isSecondary,
  }) {
    return StructuralBeam(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      width: width ?? this.width,
      depth: depth ?? this.depth,
      isSecondary: isSecondary ?? this.isSecondary,
    );
  }
}

/// Represents a structural grid / axis line (осова линия).
/// Rendered with an architectural dash-dot pattern and an end circular bubble with label.
class StructuralGridAxis {
  final String id;
  final String name; // e.g. "1", "2", "A", "B"
  final Offset start;
  final Offset end;
  final bool bubbleAtStart;
  final bool bubbleAtEnd;

  const StructuralGridAxis({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    this.bubbleAtStart = true,
    this.bubbleAtEnd = true,
  });

  double get length {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get angleRad => math.atan2(end.dy - start.dy, end.dx - start.dx);

  Offset get direction {
    final len = length;
    if (len < 1e-6) return const Offset(1, 0);
    return Offset((end.dx - start.dx) / len, (end.dy - start.dy) / len);
  }

  Offset get normal {
    final dir = direction;
    return Offset(-dir.dy, dir.dx);
  }

  Rect get bounds {
    final minX = math.min(start.dx, end.dx);
    final maxX = math.max(start.dx, end.dx);
    final minY = math.min(start.dy, end.dy);
    final maxY = math.max(start.dy, end.dy);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Calculates orthogonal projection of [pt] onto the infinite axis line.
  Offset projectPoint(Offset pt) {
    final dir = direction;
    final v = pt - start;
    final dot = v.dx * dir.dx + v.dy * dir.dy;
    return start + dir * dot;
  }

  /// Shortest distance from [pt] to the finite axis segment.
  double distanceToSegment(Offset pt) {
    final dir = direction;
    final v = pt - start;
    final dot = v.dx * dir.dx + v.dy * dir.dy;
    final clampedDot = dot.clamp(0.0, length);
    final proj = start + dir * clampedDot;
    return (pt - proj).distance;
  }

  /// Calculates intersection point with another axis line, or null if parallel.
  Offset? intersectionWith(StructuralGridAxis other) {
    final p1 = start;
    final p2 = end;
    final p3 = other.start;
    final p4 = other.end;

    final d = (p1.dx - p2.dx) * (p3.dy - p4.dy) - (p1.dy - p2.dy) * (p3.dx - p4.dx);
    if (d.abs() < 1e-6) return null; // Parallel

    final t = ((p1.dx - p3.dx) * (p3.dy - p4.dy) - (p1.dy - p3.dy) * (p3.dx - p4.dx)) / d;
    return Offset(
      p1.dx + t * (p2.dx - p1.dx),
      p1.dy + t * (p2.dy - p1.dy),
    );
  }

  /// Checks whether this axis is parallel to [other] within an angular tolerance (~2.8 degrees).
  bool isParallelTo(StructuralGridAxis other, {double toleranceRad = 0.05}) {
    final d1 = direction;
    final d2 = other.direction;
    // Cross product of 2D unit vectors equals sin(theta)
    final cross = (d1.dx * d2.dy - d1.dy * d2.dx).abs();
    return cross < math.sin(toleranceRad);
  }

  /// Aligns this axis's start and end extents with [reference] along their common direction,
  /// preserving this axis's line position and orientation.
  StructuralGridAxis alignWith(StructuralGridAxis reference) {
    final refStart = reference.start;
    final refEnd = reference.end;
    final refDir = reference.direction;
    final refNormal = reference.normal;

    // Perpendicular offset of this axis's midpoint from reference's start
    final mid = (start + end) / 2.0;
    final dPerp = (mid - refStart).dx * refNormal.dx + (mid - refStart).dy * refNormal.dy;

    // Preserve orientation (whether this axis points in same or opposite direction as reference)
    final dot = direction.dx * refDir.dx + direction.dy * refDir.dy;

    final Offset newStart;
    final Offset newEnd;
    if (dot >= 0) {
      newStart = refStart + refNormal * dPerp;
      newEnd = refEnd + refNormal * dPerp;
    } else {
      newStart = refEnd + refNormal * dPerp;
      newEnd = refStart + refNormal * dPerp;
    }

    return copyWith(start: newStart, end: newEnd);
  }

  /// Computes the centerline bisector between two line segments (wall faces).
  static StructuralGridAxis? fromTwoSegments({
    required String id,
    required String name,
    required Offset a1,
    required Offset a2,
    required Offset b1,
    required Offset b2,
    double extensionLength = 1.5,
  }) {
    final vA = a2 - a1;
    final vB = b2 - b1;
    final lenA = vA.distance;
    final lenB = vB.distance;
    if (lenA < 1e-4 || lenB < 1e-4) return null;

    final uA = vA / lenA;
    var uB = vB / lenB;
    if (uA.dx * uB.dx + uA.dy * uB.dy < 0) {
      uB = -uB;
    }

    final avgDir = uA + uB;
    final avgLen = avgDir.distance;
    if (avgLen < 1e-4) return null;
    final dir = avgDir / avgLen;

    final midA = (a1 + a2) / 2.0;
    final midB = (b1 + b2) / 2.0;
    final center = (midA + midB) / 2.0;

    final projs = [a1, a2, b1, b2]
        .map((p) => (p - center).dx * dir.dx + (p - center).dy * dir.dy)
        .toList();
    final minProj = projs.reduce(math.min) - extensionLength;
    final maxProj = projs.reduce(math.max) + extensionLength;

    return StructuralGridAxis(
      id: id,
      name: name,
      start: center + dir * minProj,
      end: center + dir * maxProj,
      bubbleAtStart: true,
      bubbleAtEnd: true,
    );
  }

  StructuralGridAxis copyWith({
    String? id,
    String? name,
    Offset? start,
    Offset? end,
    bool? bubbleAtStart,
    bool? bubbleAtEnd,
  }) {
    return StructuralGridAxis(
      id: id ?? this.id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      bubbleAtStart: bubbleAtStart ?? this.bubbleAtStart,
      bubbleAtEnd: bubbleAtEnd ?? this.bubbleAtEnd,
    );
  }
}

/// Represents a reinforced concrete slab (плоча).
class StructuralSlab {
  final String id;
  final List<Offset> polygon; // Outer perimeter boundary
  final List<List<Offset>> openings; // Staircase, elevator, shaft cutouts
  final double thickness; // in meters (default 0.20)
  final double? floorFinish; // in meters (flooring/screed finish thickness, default 0.05)

  const StructuralSlab({
    required this.id,
    required this.polygon,
    this.openings = const [],
    this.thickness = 0.20,
    this.floorFinish,
  });

  /// Signed area of polygon using shoelace formula.
  static double calculateArea(List<Offset> pts) {
    if (pts.length < 3) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < pts.length; i++) {
      final p1 = pts[i];
      final p2 = pts[(i + 1) % pts.length];
      sum += (p1.dx * p2.dy - p2.dx * p1.dy);
    }
    return (sum / 2.0).abs();
  }

  double get netArea {
    double gross = calculateArea(polygon);
    for (final op in openings) {
      gross -= calculateArea(op);
    }
    return math.max(0.0, gross);
  }

  Rect get bounds {
    if (polygon.isEmpty) return Rect.zero;
    double minX = polygon.first.dx, maxX = polygon.first.dx;
    double minY = polygon.first.dy, maxY = polygon.first.dy;
    for (final p in polygon) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Centroid of the polygon vertices.
  Offset get centroid {
    if (polygon.isEmpty) return Offset.zero;
    double cx = 0.0, cy = 0.0;
    for (final p in polygon) {
      cx += p.dx;
      cy += p.dy;
    }
    return Offset(cx / polygon.length, cy / polygon.length);
  }

  /// Total perimeter of the slab in CAD units.
  double get perimeter {
    if (polygon.length < 2) return 0.0;
    double p = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      p += (polygon[(i + 1) % polygon.length] - polygon[i]).distance;
    }
    return p;
  }

  /// Inserts a new vertex at the midpoint of edge [edgeIndex].
  StructuralSlab insertMidpointVertex(int edgeIndex) {
    if (edgeIndex < 0 || edgeIndex >= polygon.length) return this;
    final p1 = polygon[edgeIndex];
    final p2 = polygon[(edgeIndex + 1) % polygon.length];
    final mid = Offset((p1.dx + p2.dx) / 2.0, (p1.dy + p2.dy) / 2.0);
    final updated = List<Offset>.from(polygon);
    updated.insert(edgeIndex + 1, mid);
    return copyWith(polygon: updated);
  }

  /// Moves vertex at [index] to [newPos].
  StructuralSlab moveVertex(int index, Offset newPos) {
    if (index < 0 || index >= polygon.length) return this;
    final updated = List<Offset>.from(polygon);
    updated[index] = newPos;
    return copyWith(polygon: updated);
  }

  /// Removes vertex at [index] if at least 4 vertices remain.
  StructuralSlab? removeVertex(int index) {
    if (polygon.length <= 3 || index < 0 || index >= polygon.length) return null;
    final updated = List<Offset>.from(polygon)..removeAt(index);
    return copyWith(polygon: updated);
  }

  /// Adds an opening polygon (cutout) to the slab.
  StructuralSlab addOpening(List<Offset> opening) {
    if (opening.length < 3) return this;
    final updated = List<List<Offset>>.from(openings)..add(opening);
    return copyWith(openings: updated);
  }

  /// Removes opening at [index].
  StructuralSlab removeOpening(int index) {
    if (index < 0 || index >= openings.length) return this;
    final updated = List<List<Offset>>.from(openings)..removeAt(index);
    return copyWith(openings: updated);
  }

  /// Updates opening at [index].
  StructuralSlab updateOpening(int index, List<Offset> newOpening) {
    if (index < 0 || index >= openings.length || newOpening.length < 3) return this;
    final updated = List<List<Offset>>.from(openings);
    updated[index] = newOpening;
    return copyWith(openings: updated);
  }

  /// Checks whether two 2D line segments strictly cross/intersect.
  static bool doSegmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    double ccw(Offset a, Offset b, Offset c) {
      return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    }
    final d1 = ccw(p3, p4, p1);
    final d2 = ccw(p3, p4, p2);
    final d3 = ccw(p1, p2, p3);
    final d4 = ccw(p1, p2, p4);

    if (((d1 > 1e-6 && d2 < -1e-6) || (d1 < -1e-6 && d2 > 1e-6)) &&
        ((d3 > 1e-6 && d4 < -1e-6) || (d3 < -1e-6 && d4 > 1e-6))) {
      return true;
    }
    return false;
  }

  /// Checks whether polygon edges self-intersect (X-shaped crossing / bowtie).
  static bool hasSelfIntersections(List<Offset> pts) {
    final n = pts.length;
    if (n < 4) return false;
    for (int i = 0; i < n; i++) {
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      for (int j = i + 2; j < n; j++) {
        if (i == 0 && j == n - 1) continue;
        final p3 = pts[j];
        final p4 = pts[(j + 1) % n];
        if (doSegmentsIntersect(p1, p2, p3, p4)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Cleans a polygon by removing orphan (0,0) / NaN points, collapsing overlapping vertices,
  /// and eliminating redundant collinear vertices.
  static List<Offset> cleanPolygon(List<Offset> rawPts, {double minDistance = 0.05}) {
    if (rawPts.length < 3) return List.from(rawPts);

    // 1. Filter out NaN and Infinite points
    final nonNanPts = <Offset>[];
    for (final p in rawPts) {
      if (!p.dx.isNaN && !p.dy.isNaN && !p.dx.isInfinite && !p.dy.isInfinite) {
        nonNanPts.add(p);
      }
    }
    if (nonNanPts.length < 3) return nonNanPts;

    // Check for orphan (0, 0): only drop (0, 0) if the non-zero points form a coherent
    // contour (>= 3 points) and (0, 0) is well outside their bounding box (isolated stray point).
    final nonZeroPts = nonNanPts.where((p) => p.dx.abs() > 1e-4 || p.dy.abs() > 1e-4).toList();
    bool dropZero = false;
    if (nonZeroPts.length >= 3) {
      double minX = nonZeroPts[0].dx, maxX = nonZeroPts[0].dx;
      double minY = nonZeroPts[0].dy, maxY = nonZeroPts[0].dy;
      for (final p in nonZeroPts) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      final bbox = Rect.fromLTRB(minX, minY, maxX, maxY);
      final margin = math.max(0.5, math.min(bbox.width, bbox.height) * 0.1);
      if (!bbox.inflate(margin).contains(Offset.zero)) {
        dropZero = true;
      }
    }

    final validPts = <Offset>[];
    for (final p in nonNanPts) {
      if (dropZero && p.dx.abs() < 1e-4 && p.dy.abs() < 1e-4) {
        continue;
      }
      validPts.add(p);
    }

    if (validPts.length < 3) return validPts;

    // 2. Collapse overlapping / duplicate adjacent points
    bool changed = true;
    while (changed && validPts.length > 3) {
      changed = false;
      for (int i = 0; i < validPts.length; i++) {
        final next = (i + 1) % validPts.length;
        if ((validPts[i] - validPts[next]).distance < minDistance) {
          validPts.removeAt(next);
          changed = true;
          break;
        }
      }
    }

    // 3. Remove collinear points
    changed = true;
    while (changed && validPts.length > 3) {
      changed = false;
      for (int i = 0; i < validPts.length; i++) {
        final prev = (i - 1 + validPts.length) % validPts.length;
        final next = (i + 1) % validPts.length;
        final v1 = validPts[i] - validPts[prev];
        final v2 = validPts[next] - validPts[i];
        final l1 = v1.distance;
        final l2 = v2.distance;
        if (l1 > 1e-4 && l2 > 1e-4) {
          final cross = (v1.dx * v2.dy - v1.dy * v2.dx) / (l1 * l2);
          final dot = (v1.dx * v2.dx + v1.dy * v2.dy) / (l1 * l2);
          if (cross.abs() < 0.015 && dot > 0.99) {
            validPts.removeAt(i);
            changed = true;
            break;
          }
        }
      }
    }

    return validPts;
  }

  /// Uniform parallel offset of all edges by [distance] in CAD units.
  /// Positive distance expands outward, negative distance shrinks inward.
  StructuralSlab offsetContour(double distance) {
    if (polygon.length < 3 || distance.abs() < 1e-6) return this;
    final count = polygon.length;
    double sum = 0.0;
    for (int i = 0; i < count; i++) {
      final pA = polygon[i];
      final pB = polygon[(i + 1) % count];
      sum += (pA.dx * pB.dy - pB.dx * pA.dy);
    }
    final isCCW = sum > 0;
    final List<Offset> normals = [];
    for (int i = 0; i < count; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % count];
      final edge = p2 - p1;
      final len = edge.distance;
      if (len < 1e-6) {
        normals.add(Offset.zero);
      } else {
        final u = edge / len;
        normals.add(isCCW ? Offset(u.dy, -u.dx) : Offset(-u.dy, u.dx));
      }
    }
    final List<Offset> newPts = [];
    for (int i = 0; i < count; i++) {
      final prevIdx = (i - 1 + count) % count;
      final n1 = normals[prevIdx];
      final n2 = normals[i];
      final bisector = n1 + n2;
      final bisLen = bisector.distance;
      if (bisLen < 1e-4) {
        newPts.add(polygon[i] + n2 * distance);
      } else {
        final uBis = bisector / bisLen;
        final cosHalf = (n1.dx * uBis.dx + n1.dy * uBis.dy).clamp(0.25, 1.0);
        final d = (distance / cosHalf).clamp(-distance.abs() * 2.5, distance.abs() * 2.5);
        newPts.add(polygon[i] + uBis * d);
      }
    }
    return copyWith(polygon: newPts);
  }

  /// Rotates the slab polygon by [angleDegrees] around its centroid.
  StructuralSlab rotate(double angleDegrees) {
    if (polygon.isEmpty || angleDegrees == 0.0) return this;
    final center = centroid;
    final rad = angleDegrees * math.pi / 180.0;
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);
    final newPts = polygon.map((p) {
      final dx = p.dx - center.dx;
      final dy = p.dy - center.dy;
      return Offset(
        center.dx + (dx * cosA - dy * sinA),
        center.dy + (dx * sinA + dy * cosA),
      );
    }).toList();
    return copyWith(polygon: newPts);
  }

  /// Ray-casting point-in-polygon check.
  bool containsPoint(Offset pt) {
    if (!bounds.contains(pt)) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;
      final intersect = ((yi > pt.dy) != (yj > pt.dy)) &&
          (pt.dx < (xj - xi) * (pt.dy - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    if (!inside) return false;

    // Check if inside any opening
    for (final op in openings) {
      bool insideOpening = false;
      for (int i = 0, j = op.length - 1; i < op.length; j = i++) {
        final xi = op[i].dx, yi = op[i].dy;
        final xj = op[j].dx, yj = op[j].dy;
        final intersect = ((yi > pt.dy) != (yj > pt.dy)) &&
            (pt.dx < (xj - xi) * (pt.dy - yi) / (yj - yi) + xi);
        if (intersect) insideOpening = !insideOpening;
      }
      if (insideOpening) return false;
    }

    return true;
  }

  /// Calculates the midpoints and outward normal vectors for all edges of the slab perimeter.
  List<SlabEdgeGripInfo> get edgeGrips {
    if (polygon.length < 3) return const [];

    double sum = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final pA = polygon[i];
      final pB = polygon[(i + 1) % polygon.length];
      sum += (pA.dx * pB.dy - pB.dx * pA.dy);
    }
    final isCCW = sum > 0;

    final List<SlabEdgeGripInfo> grips = [];
    for (int i = 0; i < polygon.length; i++) {
      final v1 = polygon[i];
      final v2 = polygon[(i + 1) % polygon.length];
      final edge = v2 - v1;
      final len = edge.distance;
      if (len < 1e-6) continue;
      final u = edge / len;
      final normal = isCCW ? Offset(u.dy, -u.dx) : Offset(-u.dy, u.dx);
      final mid = Offset((v1.dx + v2.dx) / 2.0, (v1.dy + v2.dy) / 2.0);

      grips.add(SlabEdgeGripInfo(
        edgeIndex: i,
        midpoint: mid,
        normal: normal,
        v1: v1,
        v2: v2,
        length: len,
      ));
    }
    return grips;
  }

  /// Extrudes the polygon edge from vertex [edgeIndex] to [(edgeIndex + 1) % len]
  /// parallel to itself by [distance] in the outward normal direction,
  /// while keeping all existing vertices strictly in place.
  StructuralSlab extrudeEdgeParallel({
    required int edgeIndex,
    required double distance,
  }) {
    if (polygon.length < 3 || edgeIndex < 0 || edgeIndex >= polygon.length) {
      return this;
    }
    if (distance.abs() < 1e-4) {
      return this;
    }

    final v1 = polygon[edgeIndex];
    final v2 = polygon[(edgeIndex + 1) % polygon.length];
    final edge = v2 - v1;
    final len = edge.distance;
    if (len < 1e-6) return this;

    final u = edge / len;

    // Determine outward normal using signed Shoelace formula
    double sum = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final pA = polygon[i];
      final pB = polygon[(i + 1) % polygon.length];
      sum += (pA.dx * pB.dy - pB.dx * pA.dy);
    }
    final isCCW = sum > 0;
    final normal = isCCW ? Offset(u.dy, -u.dx) : Offset(-u.dy, u.dx);

    final vNew1 = v1 + normal * distance;
    final vNew2 = v2 + normal * distance;

    final newPolygon = List<Offset>.from(polygon);
    newPolygon.insertAll(edgeIndex + 1, [vNew1, vNew2]);

    return copyWith(polygon: newPolygon);
  }

  StructuralSlab copyWith({
    String? id,
    List<Offset>? polygon,
    List<List<Offset>>? openings,
    double? thickness,
    double? floorFinish,
  }) {
    return StructuralSlab(
      id: id ?? this.id,
      polygon: polygon ?? this.polygon,
      openings: openings ?? this.openings,
      thickness: thickness ?? this.thickness,
      floorFinish: floorFinish ?? this.floorFinish,
    );
  }
}

/// Represents a midpoint grip along an edge of a slab polygon.
class SlabEdgeGripInfo {
  final int edgeIndex;
  final Offset midpoint;
  final Offset normal; // Outward unit normal
  final Offset v1;
  final Offset v2;
  final double length;

  const SlabEdgeGripInfo({
    required this.edgeIndex,
    required this.midpoint,
    required this.normal,
    required this.v1,
    required this.v2,
    required this.length,
  });
}

/// Represents a building storey / level (Етаж).
class StoreyLevel {
  final String id;
  final String name;
  final double elevation; // Architectural Z height above ground (m)
  final double floorFinishThickness; // in meters (flooring screed/finish thickness, default 0.05 m / 5 cm)
  final double height; // Clear floor-to-floor height (m)
  final List<StructuralColumn> columns;
  final List<StructuralShearWall> shearWalls;
  final List<StructuralBeam> beams;
  final List<StructuralSlab> slabs;
  final List<StructuralGridAxis> gridAxes;

  const StoreyLevel({
    required this.id,
    required this.name,
    this.elevation = 0.0,
    this.floorFinishThickness = 0.05,
    this.height = 2.80,
    this.columns = const [],
    this.shearWalls = const [],
    this.beams = const [],
    this.slabs = const [],
    this.gridAxes = const [],
  });

  /// Computes the structural elevation (Конструктивна кота) for [slab].
  /// Calculated as architectural elevation minus flooring finish thickness.
  double structuralElevationFor(StructuralSlab slab) {
    final finish = slab.floorFinish ?? floorFinishThickness;
    return elevation - finish;
  }

  /// Duplicates current storey elements to a new level above.
  StoreyLevel cloneToNextLevel({
    required String newId,
    required String newName,
    required double newElevation,
  }) {
    return StoreyLevel(
      id: newId,
      name: newName,
      elevation: newElevation,
      floorFinishThickness: floorFinishThickness,
      height: height,
      columns: columns
          .map((c) => c.copyWith(id: '${c.id}_lvl_${newElevation.toInt()}'))
          .toList(),
      shearWalls: shearWalls
          .map((w) => w.copyWith(id: '${w.id}_lvl_${newElevation.toInt()}'))
          .toList(),
      beams: beams
          .map((b) => b.copyWith(id: '${b.id}_lvl_${newElevation.toInt()}'))
          .toList(),
      slabs: slabs
          .map((s) => s.copyWith(id: '${s.id}_lvl_${newElevation.toInt()}'))
          .toList(),
      gridAxes: gridAxes
          .map((a) => a.copyWith(id: '${a.id}_lvl_${newElevation.toInt()}'))
          .toList(),
    );
  }

  StoreyLevel copyWith({
    String? id,
    String? name,
    double? elevation,
    double? floorFinishThickness,
    double? height,
    List<StructuralColumn>? columns,
    List<StructuralShearWall>? shearWalls,
    List<StructuralBeam>? beams,
    List<StructuralSlab>? slabs,
    List<StructuralGridAxis>? gridAxes,
  }) {
    return StoreyLevel(
      id: id ?? this.id,
      name: name ?? this.name,
      elevation: elevation ?? this.elevation,
      floorFinishThickness: floorFinishThickness ?? this.floorFinishThickness,
      height: height ?? this.height,
      columns: columns ?? this.columns,
      shearWalls: shearWalls ?? this.shearWalls,
      beams: beams ?? this.beams,
      slabs: slabs ?? this.slabs,
      gridAxes: gridAxes ?? this.gridAxes,
    );
  }
}

/// Master project holding all storeys and analysis settings.
class StructuralProject {
  final String title;
  final List<StoreyLevel> storeys;
  final int activeStoreyIndex;
  final GhostStoreyMode ghostMode;
  final String concreteGrade; // e.g. 'C25/30'
  final double concreteE; // Elastic modulus in MPa (e.g. 31000)
  final double deadLoadSuperimposed; // kN/m² (finishes, screed, ceilings)
  final double liveLoad; // kN/m² (residential: 2.0)
  final double facadeWallLoad; // kN/m along perimeter (e.g. 3.5 kN/m)

  const StructuralProject({
    this.title = 'Конструктивен Модел',
    this.storeys = const [
      StoreyLevel(
        id: 'storey_1',
        name: 'Етаж 1 (Кота ±0.00)',
        elevation: 0.0,
        height: 2.80,
      ),
    ],
    this.activeStoreyIndex = 0,
    this.ghostMode = GhostStoreyMode.none,
    this.concreteGrade = 'C25/30',
    this.concreteE = 31000.0,
    this.deadLoadSuperimposed = 1.5,
    this.liveLoad = 2.0,
    this.facadeWallLoad = 3.5,
  });

  StoreyLevel get activeStorey =>
      (activeStoreyIndex >= 0 && activeStoreyIndex < storeys.length)
          ? storeys[activeStoreyIndex]
          : storeys.first;

  StoreyLevel? get ghostStorey {
    switch (ghostMode) {
      case GhostStoreyMode.below:
        return activeStoreyIndex > 0 ? storeys[activeStoreyIndex - 1] : null;
      case GhostStoreyMode.above:
        return activeStoreyIndex < storeys.length - 1
            ? storeys[activeStoreyIndex + 1]
            : null;
      case GhostStoreyMode.none:
        return null;
    }
  }

  StructuralProject copyWith({
    String? title,
    List<StoreyLevel>? storeys,
    int? activeStoreyIndex,
    GhostStoreyMode? ghostMode,
    String? concreteGrade,
    double? concreteE,
    double? deadLoadSuperimposed,
    double? liveLoad,
    double? facadeWallLoad,
  }) {
    return StructuralProject(
      title: title ?? this.title,
      storeys: storeys ?? this.storeys,
      activeStoreyIndex: activeStoreyIndex ?? this.activeStoreyIndex,
      ghostMode: ghostMode ?? this.ghostMode,
      concreteGrade: concreteGrade ?? this.concreteGrade,
      concreteE: concreteE ?? this.concreteE,
      deadLoadSuperimposed: deadLoadSuperimposed ?? this.deadLoadSuperimposed,
      liveLoad: liveLoad ?? this.liveLoad,
      facadeWallLoad: facadeWallLoad ?? this.facadeWallLoad,
    );
  }
}
