import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'seismic_slab_load.dart';

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
  final String? generatedBy; // Optional provenance; edits retain normal object identity.
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
    this.generatedBy,
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
    String? generatedBy,
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
      generatedBy: generatedBy,
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
    String? generatedBy,
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
      generatedBy: generatedBy ?? this.generatedBy,
      center: center ?? this.center,
      shape: shape ?? this.shape,
      width: width ?? this.width,
      height: height ?? this.height,
      rotationRad: rotationRad ?? this.rotationRad,
      thickness: thickness ?? this.thickness,
      isMirrored: isMirrored ?? this.isMirrored,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (generatedBy != null) 'generatedBy': generatedBy,
    'center': {'dx': center.dx, 'dy': center.dy},
    'shape': shape.name,
    'width': width,
    'height': height,
    'rotationRad': rotationRad,
    'thickness': thickness,
    'isMirrored': isMirrored,
  };

  factory StructuralColumn.fromJson(Map<String, dynamic> json) {
    return StructuralColumn(
      id: json['id'] as String,
      name: json['name'] as String?,
      generatedBy: json['generatedBy'] as String?,
      center: Offset(
        (json['center']['dx'] as num).toDouble(),
        (json['center']['dy'] as num).toDouble(),
      ),
      shape: ColumnShape.values.firstWhere(
        (s) => s.name == json['shape'],
        orElse: () => ColumnShape.rectangular,
      ),
      width: (json['width'] as num?)?.toDouble() ?? 0.25,
      height: (json['height'] as num?)?.toDouble() ?? 0.25,
      rotationRad: (json['rotationRad'] as num?)?.toDouble() ?? 0.0,
      thickness: (json['thickness'] as num?)?.toDouble() ?? 0.25,
      isMirrored: json['isMirrored'] as bool? ?? false,
    );
  }
}

/// Reference baseline position for shear walls.
enum ShearWallReferenceLine {
  center,
  leftFace,
  rightFace,
}

/// Represents a structural reinforced concrete shear wall (шайба).
/// The line from [start] to [end] is the LEADING REFERENCE LINE.
class StructuralShearWall {
  final String id;
  final String? name;
  final String? generatedBy; // Optional provenance; edits retain normal object identity.
  final Offset start;
  final Offset end;
  final double thickness; // in meters (default 0.25)
  final bool isFlipped; // whether the wall body is flipped to the opposite side of the line
  final ShearWallReferenceLine referenceLine;

  const StructuralShearWall({
    required this.id,
    this.name,
    this.generatedBy,
    required this.start,
    required this.end,
    this.thickness = 0.25,
    this.isFlipped = false,
    this.referenceLine = ShearWallReferenceLine.center,
  });

  /// User-facing shear wall display name (e.g. "Ш1", "Ш2" or "W1", "W2"). Falls back to "Ш" if empty.
  String get displayName => (name != null && name!.trim().isNotEmpty) ? name!.trim() : 'Ш';

  double get length {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get angleRad => math.atan2(end.dy - start.dy, end.dx - start.dx);

  /// Rotation angle in radians (synonym for [angleRad]).
  double get rotationRad => angleRad;

  /// Geometric center of the shear wall body.
  Offset get center {
    final baseCenter = Offset((start.dx + end.dx) / 2.0, (start.dy + end.dy) / 2.0);
    if (referenceLine == ShearWallReferenceLine.center) return baseCenter;
    final double l = length;
    if (l < 1e-6) return baseCenter;
    final normal = Offset((end.dy - start.dy) / l, -(end.dx - start.dx) / l);
    final halfT = thickness / 2.0;
    final double shift = referenceLine == ShearWallReferenceLine.leftFace
        ? (isFlipped ? -halfT : halfT)
        : (isFlipped ? halfT : -halfT);
    return baseCenter + normal * shift;
  }

  /// 4 corner vertices forming the thick wall box in CAD coordinates.
  List<Offset> get polygonVertices {
    final double l = length;
    if (l < 1e-6) {
      return [start, start, start, start];
    }
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final normal = Offset(dy / l, -dx / l);
    final halfT = thickness / 2.0;

    final double o1;
    final double o2;
    switch (referenceLine) {
      case ShearWallReferenceLine.center:
        o1 = -halfT;
        o2 = halfT;
        break;
      case ShearWallReferenceLine.leftFace:
        o1 = isFlipped ? -thickness : 0.0;
        o2 = isFlipped ? 0.0 : thickness;
        break;
      case ShearWallReferenceLine.rightFace:
        o1 = isFlipped ? 0.0 : -thickness;
        o2 = isFlipped ? thickness : 0.0;
        break;
    }

    return [
      Offset(start.dx + normal.dx * o1, start.dy + normal.dy * o1),
      Offset(end.dx + normal.dx * o1, end.dy + normal.dy * o1),
      Offset(end.dx + normal.dx * o2, end.dy + normal.dy * o2),
      Offset(start.dx + normal.dx * o2, start.dy + normal.dy * o2),
    ];
  }

  StructuralShearWall copyWith({
    String? id,
    String? name,
    String? generatedBy,
    Offset? start,
    Offset? end,
    double? thickness,
    bool? isFlipped,
    ShearWallReferenceLine? referenceLine,
  }) {
    return StructuralShearWall(
      id: id ?? this.id,
      name: name ?? this.name,
      generatedBy: generatedBy ?? this.generatedBy,
      start: start ?? this.start,
      end: end ?? this.end,
      thickness: thickness ?? this.thickness,
      isFlipped: isFlipped ?? this.isFlipped,
      referenceLine: referenceLine ?? this.referenceLine,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (generatedBy != null) 'generatedBy': generatedBy,
    'start': {'dx': start.dx, 'dy': start.dy},
    'end': {'dx': end.dx, 'dy': end.dy},
    'thickness': thickness,
    'isFlipped': isFlipped,
    'referenceLine': referenceLine.name,
  };

  factory StructuralShearWall.fromJson(Map<String, dynamic> json) {
    return StructuralShearWall(
      id: json['id'] as String,
      name: json['name'] as String?,
      generatedBy: json['generatedBy'] as String?,
      start: Offset(
        (json['start']['dx'] as num).toDouble(),
        (json['start']['dy'] as num).toDouble(),
      ),
      end: Offset(
        (json['end']['dx'] as num).toDouble(),
        (json['end']['dy'] as num).toDouble(),
      ),
      thickness: (json['thickness'] as num?)?.toDouble() ?? 0.25,
      isFlipped: json['isFlipped'] as bool? ?? false,
      referenceLine: ShearWallReferenceLine.values.firstWhere(
        (s) => s.name == json['referenceLine'],
        orElse: () => ShearWallReferenceLine.center,
      ),
    );
  }
}

/// Represents a structural reinforced concrete beam (греда).
class StructuralBeam {
  final String id;
  final String? name; // e.g. "Г1", "B1"
  final Offset start;
  final Offset end;
  final double width; // in CAD units (b, e.g. 0.25 * cadUnitsPerMeter)
  final double depth; // in CAD units (h, e.g. 0.50 * cadUnitsPerMeter)
  final bool isSecondary;

  const StructuralBeam({
    required this.id,
    this.name,
    required this.start,
    required this.end,
    this.width = 0.25,
    this.depth = 0.50,
    this.isSecondary = false,
  });

  /// User-facing beam display name (e.g. "Г1", "B1"). Falls back to "Г" if empty.
  String get displayName => (name != null && name!.trim().isNotEmpty) ? name!.trim() : 'Г';

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
    String? name,
    Offset? start,
    Offset? end,
    double? width,
    double? depth,
    bool? isSecondary,
  }) {
    return StructuralBeam(
      id: id ?? this.id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      width: width ?? this.width,
      depth: depth ?? this.depth,
      isSecondary: isSecondary ?? this.isSecondary,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name != null) 'name': name,
    'start': {'dx': start.dx, 'dy': start.dy},
    'end': {'dx': end.dx, 'dy': end.dy},
    'width': width,
    'depth': depth,
    'isSecondary': isSecondary,
  };

  factory StructuralBeam.fromJson(Map<String, dynamic> json) {
    return StructuralBeam(
      id: json['id'] as String,
      name: json['name'] as String?,
      start: Offset(
        (json['start']['dx'] as num).toDouble(),
        (json['start']['dy'] as num).toDouble(),
      ),
      end: Offset(
        (json['end']['dx'] as num).toDouble(),
        (json['end']['dy'] as num).toDouble(),
      ),
      width: (json['width'] as num?)?.toDouble() ?? 0.25,
      depth: (json['depth'] as num?)?.toDouble() ?? 0.50,
      isSecondary: json['isSecondary'] as bool? ?? false,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': {'dx': start.dx, 'dy': start.dy},
    'end': {'dx': end.dx, 'dy': end.dy},
    'bubbleAtStart': bubbleAtStart,
    'bubbleAtEnd': bubbleAtEnd,
  };

  factory StructuralGridAxis.fromJson(Map<String, dynamic> json) {
    return StructuralGridAxis(
      id: json['id'] as String,
      name: json['name'] as String? ?? '1',
      start: Offset(
        (json['start']['dx'] as num).toDouble(),
        (json['start']['dy'] as num).toDouble(),
      ),
      end: Offset(
        (json['end']['dx'] as num).toDouble(),
        (json['end']['dy'] as num).toDouble(),
      ),
      bubbleAtStart: json['bubbleAtStart'] as bool? ?? true,
      bubbleAtEnd: json['bubbleAtEnd'] as bool? ?? true,
    );
  }
}

/// Represents the engineering / architectural type of a slab opening cutout.
enum SlabOpeningType {
  /// MEP Installation shaft (Инсталационен щранг - ВиК, ОВК, Електро).
  shaft,

  /// Staircase void / flight cut (Стълбищен отвор / стълбищна клетка).
  staircase,

  /// Elevator shaft core void (Асансьорна шахта).
  elevator,

  /// General / custom architectural slab opening (Свободен / общ отвор).
  custom,
}

/// Represents a typed opening in a structural slab.
class SlabOpening {
  final String id;
  final int index;
  final SlabOpeningType type;
  final List<Offset> polygon;
  final String? name;

  const SlabOpening({
    required this.id,
    required this.index,
    this.type = SlabOpeningType.shaft,
    required this.polygon,
    this.name,
  });

  /// Short display code (e.g. "Щ", "СТ", "АС", "ОТ").
  String get defaultCode {
    switch (type) {
      case SlabOpeningType.shaft:
        return 'Щ';
      case SlabOpeningType.staircase:
        return 'СТ';
      case SlabOpeningType.elevator:
        return 'АС';
      case SlabOpeningType.custom:
        return 'ОТ';
    }
  }

  double get area => StructuralSlab.calculateArea(polygon);

  Offset get centroid {
    if (polygon.isEmpty) return Offset.zero;
    double cx = 0, cy = 0;
    for (final p in polygon) {
      cx += p.dx;
      cy += p.dy;
    }
    return Offset(cx / polygon.length, cy / polygon.length);
  }
}

/// Represents a reinforced concrete slab (плоча).
class StructuralSlab {
  final String id;
  final List<Offset> polygon; // Outer perimeter boundary
  final List<List<Offset>> openings; // Staircase, elevator, shaft cutouts
  final List<SlabOpeningType>? openingTypes; // Typed categorization of openings
  final double thickness; // in meters (default 0.20)
  /// Absolute top-of-concrete elevation in metres; null derives the ceiling.
  final double? topElevation;
  final SeismicSlabLoad? seismicLoad;

  SeismicSlabLoad effectiveSeismicLoad(StructuralProject project) => seismicLoad ??
      SeismicSlabLoad(permanentKnM2: project.deadLoadSuperimposed,
        variableKnM2: project.liveLoad, participation: 0.3);
  final double? floorFinish; // in meters (flooring/screed finish thickness, default 0.05)
  final int? colorValue; // ARGB hex integer for distinct custom color

  const StructuralSlab({
    required this.id,
    required this.polygon,
    this.openings = const [],
    this.openingTypes,
    this.thickness = 0.20,
    this.topElevation,
    this.seismicLoad,
    this.floorFinish,
    this.colorValue,
  });

  /// Retrieves the engineering opening type for opening at [index].
  SlabOpeningType getOpeningType(int index) {
    if (openingTypes != null && index >= 0 && index < openingTypes!.length) {
      return openingTypes![index];
    }
    return SlabOpeningType.shaft;
  }

  /// Returns typed opening objects for all openings in this slab.
  List<SlabOpening> get typedOpenings {
    final list = <SlabOpening>[];
    for (int i = 0; i < openings.length; i++) {
      list.add(SlabOpening(
        id: '${id}_op_$i',
        index: i,
        type: getOpeningType(i),
        polygon: openings[i],
      ));
    }
    return list;
  }

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
  StructuralSlab addOpening(List<Offset> opening, {SlabOpeningType type = SlabOpeningType.shaft}) {
    if (opening.length < 3) return this;
    final updatedOpenings = List<List<Offset>>.from(openings)..add(opening);
    final updatedTypes = List<SlabOpeningType>.generate(
      updatedOpenings.length,
      (i) => i < (openingTypes?.length ?? 0)
          ? openingTypes![i]
          : (i == updatedOpenings.length - 1 ? type : SlabOpeningType.shaft),
    );
    return copyWith(openings: updatedOpenings, openingTypes: updatedTypes);
  }

  /// Removes opening at [index].
  StructuralSlab removeOpening(int index) {
    if (index < 0 || index >= openings.length) return this;
    final updatedOpenings = List<List<Offset>>.from(openings)..removeAt(index);
    List<SlabOpeningType>? updatedTypes;
    if (openingTypes != null && index < openingTypes!.length) {
      updatedTypes = List<SlabOpeningType>.from(openingTypes!)..removeAt(index);
    }
    return copyWith(openings: updatedOpenings, openingTypes: updatedTypes);
  }

  /// Updates opening at [index].
  StructuralSlab updateOpening(int index, List<Offset> newOpening, {SlabOpeningType? type}) {
    if (index < 0 || index >= openings.length || newOpening.length < 3) return this;
    final updatedOpenings = List<List<Offset>>.from(openings);
    updatedOpenings[index] = newOpening;
    List<SlabOpeningType>? updatedTypes;
    if (openingTypes != null || type != null) {
      updatedTypes = List<SlabOpeningType>.generate(
        openings.length,
        (i) => (i == index && type != null) ? type : getOpeningType(i),
      );
    }
    return copyWith(openings: updatedOpenings, openingTypes: updatedTypes);
  }

  /// Updates the type of opening at [index].
  StructuralSlab updateOpeningType(int index, SlabOpeningType type) {
    if (index < 0 || index >= openings.length) return this;
    final updatedTypes = List<SlabOpeningType>.generate(
      openings.length,
      (i) => i == index ? type : getOpeningType(i),
    );
    return copyWith(openingTypes: updatedTypes);
  }

  /// Moves opening vertex at [vertexIndex] of opening [openingIndex] to [newPos].
  StructuralSlab moveOpeningVertex(int openingIndex, int vertexIndex, Offset newPos) {
    if (openingIndex < 0 || openingIndex >= openings.length) return this;
    final op = openings[openingIndex];
    if (vertexIndex < 0 || vertexIndex >= op.length) return this;
    final updatedOp = List<Offset>.from(op);
    updatedOp[vertexIndex] = newPos;
    return updateOpening(openingIndex, updatedOp);
  }

  /// Inserts a new vertex at the midpoint of edge [edgeIndex] of opening [openingIndex].
  StructuralSlab insertOpeningMidpointVertex(int openingIndex, int edgeIndex) {
    if (openingIndex < 0 || openingIndex >= openings.length) return this;
    final op = openings[openingIndex];
    if (edgeIndex < 0 || edgeIndex >= op.length) return this;
    final p1 = op[edgeIndex];
    final p2 = op[(edgeIndex + 1) % op.length];
    final mid = Offset((p1.dx + p2.dx) / 2.0, (p1.dy + p2.dy) / 2.0);
    final updatedOp = List<Offset>.from(op);
    updatedOp.insert(edgeIndex + 1, mid);
    return updateOpening(openingIndex, updatedOp);
  }

  /// Removes opening vertex at [vertexIndex] of opening [openingIndex] if at least 4 vertices remain.
  StructuralSlab? removeOpeningVertex(int openingIndex, int vertexIndex) {
    if (openingIndex < 0 || openingIndex >= openings.length) return null;
    final op = openings[openingIndex];
    if (op.length <= 3 || vertexIndex < 0 || vertexIndex >= op.length) return null;
    final updatedOp = List<Offset>.from(op)..removeAt(vertexIndex);
    return updateOpening(openingIndex, updatedOp);
  }

  /// Calculates the midpoints and outward normal vectors for all edges of opening [openingIndex].
  List<SlabEdgeGripInfo> getOpeningEdgeGrips(int openingIndex) {
    if (openingIndex < 0 || openingIndex >= openings.length) return const [];
    final op = openings[openingIndex];
    if (op.length < 3) return const [];

    double sum = 0.0;
    for (int i = 0; i < op.length; i++) {
      final pA = op[i];
      final pB = op[(i + 1) % op.length];
      sum += (pA.dx * pB.dy - pB.dx * pA.dy);
    }
    final isCCW = sum > 0;

    final List<SlabEdgeGripInfo> grips = [];
    for (int i = 0; i < op.length; i++) {
      final v1 = op[i];
      final v2 = op[(i + 1) % op.length];
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

  /// Extrudes the opening polygon edge from vertex [edgeIndex] to [(edgeIndex + 1) % len]
  /// parallel to itself by [distance] in the outward normal direction,
  /// inserting two new vertices to create the stepped extrusion (identical to slab extrudeEdgeParallel).
  StructuralSlab extrudeOpeningEdgeParallel({
    required int openingIndex,
    required int edgeIndex,
    required double distance,
  }) {
    if (openingIndex < 0 || openingIndex >= openings.length) return this;
    final op = openings[openingIndex];
    if (op.length < 3 || edgeIndex < 0 || edgeIndex >= op.length) return this;
    if (distance.abs() < 1e-4) return this;

    final v1 = op[edgeIndex];
    final v2 = op[(edgeIndex + 1) % op.length];
    final edge = v2 - v1;
    final len = edge.distance;
    if (len < 1e-6) return this;

    final u = edge / len;
    double sum = 0.0;
    for (int i = 0; i < op.length; i++) {
      final pA = op[i];
      final pB = op[(i + 1) % op.length];
      sum += (pA.dx * pB.dy - pB.dx * pA.dy);
    }
    final isCCW = sum > 0;
    final normal = isCCW ? Offset(u.dy, -u.dx) : Offset(-u.dy, u.dx);

    final vNew1 = v1 + normal * distance;
    final vNew2 = v2 + normal * distance;

    final newOp = List<Offset>.from(op);
    newOp.insertAll(edgeIndex + 1, [vNew1, vNew2]);

    return updateOpening(openingIndex, newOp);
  }

  /// Pulls the opening edge at [edgeIndex] of opening [openingIndex] by [distance] in the outward normal direction,
  /// extending/trimming adjacent edges and cleaning collinear orphan points and artifacts.
  StructuralSlab dynamicPullOpeningEdge({
    required int openingIndex,
    required int edgeIndex,
    required double distance,
    double minDistanceCad = 0.05,
  }) {
    if (openingIndex < 0 || openingIndex >= openings.length) return this;
    final op = openings[openingIndex];
    if (op.length < 3 || edgeIndex < 0 || edgeIndex >= op.length || distance.abs() < 1e-4) {
      return this;
    }

    final n = op.length;
    final v1 = op[edgeIndex];
    final v2 = op[(edgeIndex + 1) % n];
    final edge = v2 - v1;
    final len = edge.distance;
    if (len < 1e-6) return this;

    final u = edge / len;
    double sum = 0.0;
    for (int i = 0; i < n; i++) {
      final pA = op[i];
      final pB = op[(i + 1) % n];
      sum += (pA.dx * pB.dy - pB.dx * pA.dy);
    }
    final isCCW = sum > 0;
    final normal = isCCW ? Offset(u.dy, -u.dx) : Offset(-u.dy, u.dx);

    final vPrev = op[(edgeIndex - 1 + n) % n];
    final vNext = op[(edgeIndex + 2) % n];

    final d1 = v1 - vPrev;
    final d2 = vNext - v2;
    final len1 = d1.distance;
    final len2 = d2.distance;

    final double normProj1 = len1 > 1e-6 ? (d1.dx * normal.dx + d1.dy * normal.dy) / len1 : 0.0;
    final double normProj2 = len2 > 1e-6 ? (d2.dx * (-normal.dx) + d2.dy * (-normal.dy)) / len2 : 0.0;

    final bool isD1Collinear = normProj1.abs() <= 0.08;
    final bool isD2Collinear = normProj2.abs() <= 0.08;

    Offset vNew1;
    if (isD1Collinear) {
      vNew1 = v1 + normal * distance;
    } else {
      if (normProj1.abs() >= 0.20) {
        final t1 = distance / (normProj1 * len1);
        vNew1 = v1 + d1 * t1;
      } else {
        vNew1 = v1 + normal * distance;
      }
    }

    Offset vNew2;
    if (isD2Collinear) {
      vNew2 = v2 + normal * distance;
    } else {
      final proj2 = (d2.dx * normal.dx + d2.dy * normal.dy) / (len2 > 1e-6 ? len2 : 1.0);
      if (proj2.abs() >= 0.20) {
        final t2 = distance / (proj2 * len2);
        vNew2 = v2 + d2 * t2;
      } else {
        vNew2 = v2 + normal * distance;
      }
    }

    final newPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      if (i == edgeIndex) {
        if (isD1Collinear) newPts.add(v1);
        newPts.add(vNew1);
        newPts.add(vNew2);
        if (isD2Collinear) newPts.add(v2);
      } else if (i == (edgeIndex + 1) % n) {
        continue;
      } else {
        newPts.add(op[i]);
      }
    }

    final cleanedPts = cleanPolygon(newPts, minDistance: minDistanceCad);
    if (cleanedPts.length >= 3 && !hasSelfIntersections(cleanedPts)) {
      final newArea = calculateArea(cleanedPts);
      if (newArea > 1e-4) {
        return updateOpening(openingIndex, cleanedPts);
      }
    }

    // Fallback parallel
    final fbPts = <Offset>[];
    final fb1 = v1 + normal * distance;
    final fb2 = v2 + normal * distance;
    for (int i = 0; i < n; i++) {
      if (i == edgeIndex) {
        if (isD1Collinear) fbPts.add(v1);
        fbPts.add(fb1);
        fbPts.add(fb2);
        if (isD2Collinear) fbPts.add(v2);
      } else if (i == (edgeIndex + 1) % n) {
        continue;
      } else {
        fbPts.add(op[i]);
      }
    }
    final cleanedFb = cleanPolygon(fbPts, minDistance: minDistanceCad);
    if (cleanedFb.length >= 3 && !hasSelfIntersections(cleanedFb)) {
      return updateOpening(openingIndex, cleanedFb);
    }

    return this;
  }

  /// Merges opening vertex at [fromIndex] into vertex at [toIndex] of opening [openingIndex].
  StructuralSlab? mergeOpeningVertices({
    required int openingIndex,
    required int fromIndex,
    required int toIndex,
    double minDistanceCad = 0.05,
  }) {
    if (openingIndex < 0 || openingIndex >= openings.length) return null;
    final op = openings[openingIndex];
    if (op.length <= 3) return null;
    if (fromIndex < 0 || fromIndex >= op.length) return null;
    if (toIndex < 0 || toIndex >= op.length || fromIndex == toIndex) return null;

    final n = op.length;
    final bool isAdjacent = (fromIndex + 1) % n == toIndex || (toIndex + 1) % n == fromIndex;

    List<Offset> candidate;
    if (isAdjacent) {
      candidate = List<Offset>.from(op)..removeAt(fromIndex);
    } else {
      candidate = List<Offset>.from(op);
      candidate[fromIndex] = candidate[toIndex];
    }

    final cleaned = cleanPolygon(candidate, minDistance: minDistanceCad);
    if (cleaned.length >= 3 && !hasSelfIntersections(cleaned)) {
      return updateOpening(openingIndex, cleaned);
    }

    final fallback = List<Offset>.from(op)..removeAt(fromIndex);
    final cleanedFb = cleanPolygon(fallback, minDistance: minDistanceCad);
    if (cleanedFb.length >= 3 && !hasSelfIntersections(cleanedFb)) {
      return updateOpening(openingIndex, cleanedFb);
    }

    return null;
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
  /// eliminating redundant collinear vertices, and pruning degenerate needle fold-backs or pinch flaps.
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

    // Iterative multi-pass reduction until polygon is completely clean
    bool outerChanged = true;
    int maxPasses = 15;
    while (outerChanged && validPts.length > 3 && maxPasses-- > 0) {
      outerChanged = false;

      // 2. Collapse adjacent duplicate points
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        final next = (i + 1) % validPts.length;
        if ((validPts[i] - validPts[next]).distance < minDistance) {
          validPts.removeAt(next);
          outerChanged = true;
          break;
        }
      }
      if (outerChanged) continue;

      // 3. Remove collinear points, acute needle fold-backs, and slits
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        final prev = (i - 1 + validPts.length) % validPts.length;
        final next = (i + 1) % validPts.length;
        final v1 = validPts[i] - validPts[prev];
        final v2 = validPts[next] - validPts[i];
        final l1 = v1.distance;
        final l2 = v2.distance;
        if (l1 > 1e-4 && l2 > 1e-4) {
          final cross = (v1.dx * v2.dy - v1.dy * v2.dx) / (l1 * l2);
          final dot = (v1.dx * v2.dx + v1.dy * v2.dy) / (l1 * l2);

          // Distance from vertex i to chord between prev and next
          final chord = validPts[next] - validPts[prev];
          final chordLen = chord.distance;
          final double distToChord;
          if (chordLen > 1e-4) {
            final t = (((validPts[i].dx - validPts[prev].dx) * chord.dx +
                        (validPts[i].dy - validPts[prev].dy) * chord.dy) /
                    (chordLen * chordLen))
                .clamp(0.0, 1.0);
            final proj = validPts[prev] + chord * t;
            distToChord = (validPts[i] - proj).distance;
          } else {
            distToChord = (validPts[i] - validPts[prev]).distance;
          }

          // A. Collinear redundant vertex (orphan point sitting on straight line)
          if ((cross.abs() < 0.04 && dot > 0.96) ||
              (distToChord < math.max(minDistance * 0.4, 0.015) && dot > 0.5)) {
            validPts.removeAt(i);
            outerChanged = true;
            break;
          }

          // B. Acute needle fold-back / spike (израстък/остър вглъбнат участък)
          if (cross.abs() < 0.08 && dot < -0.85) {
            validPts.removeAt(i);
            if (chordLen < minDistance * 1.5 && validPts.length > 3) {
              final newNext = next > i ? next - 1 : next;
              validPts.removeAt(newNext);
            }
            outerChanged = true;
            break;
          }

          // C. Degenerate narrow slit where chord between prev and next is almost closed
          if (chordLen < minDistance * 1.5 && dot < -0.5) {
            validPts.removeAt(i);
            outerChanged = true;
            break;
          }
        }
      }
      if (outerChanged) continue;

      // 4. Non-adjacent pinch duplicate collapse (merging or touching points)
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        for (int j = i + 2; j < validPts.length; j++) {
          if (i == 0 && j == validPts.length - 1) continue;
          if ((validPts[i] - validPts[j]).distance < minDistance) {
            // Find smaller sub-loop between i and j
            final loop1Len = j - i;
            final loop2Len = validPts.length - loop1Len;
            if (loop1Len <= loop2Len) {
              // Subloop is from i+1 to j
              validPts.removeRange(i + 1, j + 1);
            } else {
              // Subloop wraps around 0: from j+1 to end and 0 to i-1
              validPts.removeRange(j + 1, validPts.length);
              validPts.removeRange(0, i);
            }
            outerChanged = true;
            break;
          }
        }
        if (outerChanged) break;
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

  /// Moves the polygon edge at [edgeIndex] parallel to itself by [distance]
  /// in the outward normal direction (positive = outward, negative = inward),
  /// extending or trimming adjacent edges in ArchiCAD fashion, and cleaning
  /// any redundant collinear points, spikes, acute notches, or overlapping segments.
  StructuralSlab offsetEdge({
    required int edgeIndex,
    required double distance,
    double minDistanceCad = 0.05,
  }) {
    if (polygon.length < 3 || edgeIndex < 0 || edgeIndex >= polygon.length) {
      return this;
    }
    if (distance.abs() < 1e-4) {
      return this;
    }

    final n = polygon.length;
    final v1 = polygon[edgeIndex];
    final v2 = polygon[(edgeIndex + 1) % n];
    final edge = v2 - v1;
    final len = edge.distance;
    if (len < 1e-6) return this;

    final u = edge / len;

    // Outward normal via Shoelace orientation
    double sum = 0.0;
    for (int i = 0; i < n; i++) {
      final pA = polygon[i];
      final pB = polygon[(i + 1) % n];
      sum += (pA.dx * pB.dy - pB.dx * pA.dy);
    }
    final isCCW = sum > 0;
    final normal = isCCW ? Offset(u.dy, -u.dx) : Offset(-u.dy, u.dx);

    final vPrev = polygon[(edgeIndex - 1 + n) % n];
    final vNext = polygon[(edgeIndex + 2) % n];

    final d1 = v1 - vPrev;
    final d2 = vNext - v2;

    final denom1 = d1.dx * normal.dx + d1.dy * normal.dy;
    final denom2 = d2.dx * normal.dx + d2.dy * normal.dy;

    final bool isD1Collinear = denom1.abs() <= 0.05;
    final bool isD2Collinear = denom2.abs() <= 0.05;

    Offset vNew1;
    if (!isD1Collinear) {
      final t1 = (distance / denom1).clamp(-4.0 * distance.abs(), 4.0 * distance.abs());
      vNew1 = v1 + d1 * t1;
    } else {
      vNew1 = v1 + normal * distance;
    }

    Offset vNew2;
    if (!isD2Collinear) {
      final t2 = (distance / denom2).clamp(-4.0 * distance.abs(), 4.0 * distance.abs());
      vNew2 = v2 + d2 * t2;
    } else {
      vNew2 = v2 + normal * distance;
    }

    final newPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      if (i == edgeIndex) {
        if (isD1Collinear) {
          newPts.add(v1);
        }
        newPts.add(vNew1);
        newPts.add(vNew2);
        if (isD2Collinear) {
          newPts.add(v2);
        }
      } else if (i == (edgeIndex + 1) % n) {
        continue;
      } else {
        newPts.add(polygon[i]);
      }
    }

    final cleanedPts = cleanPolygon(newPts, minDistance: minDistanceCad);
    if (cleanedPts.length >= 3 && !hasSelfIntersections(cleanedPts)) {
      return copyWith(polygon: cleanedPts);
    }

    return this;
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

  /// Pulls the polygon edge at [edgeIndex] by [distance] in the outward normal direction,
  /// intelligently extending or trimming adjacent edges (moving corners when connected at angles
  /// to eliminate orphan points, or creating clean steps when pulling a sub-segment of a straight wall),
  /// while strictly preventing self-intersections, fold-backs, holes, and bowtie artifacts.
  StructuralSlab dynamicPullEdge({
    required int edgeIndex,
    required double distance,
    double minDistanceCad = 0.05,
  }) {
    if (polygon.length < 3 || edgeIndex < 0 || edgeIndex >= polygon.length) {
      return this;
    }
    if (distance.abs() < 1e-4) {
      return this;
    }

    final n = polygon.length;
    final v1 = polygon[edgeIndex];
    final v2 = polygon[(edgeIndex + 1) % n];
    final edge = v2 - v1;
    final len = edge.distance;
    if (len < 1e-6) return this;

    final u = edge / len;

    // Outward normal via Shoelace signed area
    double sum = 0.0;
    for (int i = 0; i < n; i++) {
      final pA = polygon[i];
      final pB = polygon[(i + 1) % n];
      sum += (pA.dx * pB.dy - pB.dx * pA.dy);
    }
    final isCCW = sum > 0;
    final normal = isCCW ? Offset(u.dy, -u.dx) : Offset(-u.dy, u.dx);

    final vPrev = polygon[(edgeIndex - 1 + n) % n];
    final vNext = polygon[(edgeIndex + 2) % n];

    final d1 = v1 - vPrev;
    final d2 = vNext - v2;
    final len1 = d1.distance;
    final len2 = d2.distance;

    // Projections of adjacent edge unit directions along the outward normal
    final double normProj1 = len1 > 1e-6 ? (d1.dx * normal.dx + d1.dy * normal.dy) / len1 : 0.0;
    final double normProj2 = len2 > 1e-6 ? (d2.dx * (-normal.dx) + d2.dy * (-normal.dy)) / len2 : 0.0;

    // Collinear checks: an adjacent edge is collinear with the moved edge if its direction is
    // perpendicular to the outward normal (|normProj| <= 0.08)
    final bool isD1Collinear = normProj1.abs() <= 0.08;
    final bool isD2Collinear = normProj2.abs() <= 0.08;

    Offset vNew1;
    if (isD1Collinear) {
      // Wall continues along the same straight line: keep v1 as step anchor, insert new corner
      vNew1 = v1 + normal * distance;
    } else {
      // Adjacent edge is at an angle or perpendicular: intersect the extended adjacent ray
      // with the offset edge line.
      if (normProj1.abs() >= 0.20) {
        final t1 = distance / (normProj1 * len1);
        vNew1 = v1 + d1 * t1;
      } else {
        // Very shallow angle: fallback to perpendicular offset to avoid extreme runaway spike
        vNew1 = v1 + normal * distance;
      }
    }

    Offset vNew2;
    if (isD2Collinear) {
      // Wall continues along the same straight line: keep v2 as step anchor, insert new corner
      vNew2 = v2 + normal * distance;
    } else {
      // Adjacent edge is at an angle or perpendicular: intersect with offset edge line
      final proj2 = (d2.dx * normal.dx + d2.dy * normal.dy) / (len2 > 1e-6 ? len2 : 1.0);
      if (proj2.abs() >= 0.20) {
        final t2 = distance / (proj2 * len2);
        vNew2 = v2 + d2 * t2;
      } else {
        vNew2 = v2 + normal * distance;
      }
    }

    final newPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      if (i == edgeIndex) {
        if (isD1Collinear) {
          newPts.add(v1);
        }
        newPts.add(vNew1);
        newPts.add(vNew2);
        if (isD2Collinear) {
          newPts.add(v2);
        }
      } else if (i == (edgeIndex + 1) % n) {
        continue;
      } else {
        newPts.add(polygon[i]);
      }
    }

    final cleanedPts = cleanPolygon(newPts, minDistance: minDistanceCad);
    if (cleanedPts.length >= 3 && !hasSelfIntersections(cleanedPts)) {
      final newArea = calculateArea(cleanedPts);
      if (newArea > 1e-4) {
        return copyWith(polygon: cleanedPts);
      }
    }

    // Fallback: parallel offset without runaway miters
    final fallbackPts = <Offset>[];
    final fbNew1 = v1 + normal * distance;
    final fbNew2 = v2 + normal * distance;
    for (int i = 0; i < n; i++) {
      if (i == edgeIndex) {
        if (isD1Collinear) fallbackPts.add(v1);
        fallbackPts.add(fbNew1);
        fallbackPts.add(fbNew2);
        if (isD2Collinear) fallbackPts.add(v2);
      } else if (i == (edgeIndex + 1) % n) {
        continue;
      } else {
        fallbackPts.add(polygon[i]);
      }
    }
    final cleanedFallback = cleanPolygon(fallbackPts, minDistance: minDistanceCad);
    if (cleanedFallback.length >= 3 && !hasSelfIntersections(cleanedFallback)) {
      return copyWith(polygon: cleanedFallback);
    }

    return this;
  }

  /// Merges vertex at [fromIndex] into vertex at [toIndex], collapsing adjacent edges
  /// or eliminating degenerate loops, and cleaning redundant collinear vertices.
  StructuralSlab? mergeVertices({
    required int fromIndex,
    required int toIndex,
    double minDistanceCad = 0.05,
  }) {
    if (polygon.length <= 3) return null;
    if (fromIndex < 0 || fromIndex >= polygon.length) return null;
    if (toIndex < 0 || toIndex >= polygon.length || fromIndex == toIndex) return null;

    final n = polygon.length;
    final bool isAdjacent = (fromIndex + 1) % n == toIndex || (toIndex + 1) % n == fromIndex;

    List<Offset> candidate;
    if (isAdjacent) {
      candidate = List<Offset>.from(polygon)..removeAt(fromIndex);
    } else {
      candidate = List<Offset>.from(polygon);
      candidate[fromIndex] = candidate[toIndex];
    }

    final cleaned = cleanPolygon(candidate, minDistance: minDistanceCad);
    if (cleaned.length >= 3 && !hasSelfIntersections(cleaned)) {
      return copyWith(polygon: cleaned);
    }

    // Fallback: direct removal
    final fallback = List<Offset>.from(polygon)..removeAt(fromIndex);
    final cleanedFb = cleanPolygon(fallback, minDistance: minDistanceCad);
    if (cleanedFb.length >= 3 && !hasSelfIntersections(cleanedFb)) {
      return copyWith(polygon: cleanedFb);
    }

    return null;
  }

  StructuralSlab copyWith({
    String? id,
    List<Offset>? polygon,
    List<List<Offset>>? openings,
    List<SlabOpeningType>? openingTypes,
    double? thickness,
    double? floorFinish,
    int? colorValue,
    SeismicSlabLoad? seismicLoad,
    bool clearSeismicLoad = false,
    double? topElevation,
    bool clearTopElevation = false,
  }) {
    return StructuralSlab(
      id: id ?? this.id,
      polygon: polygon ?? this.polygon,
      openings: openings ?? this.openings,
      openingTypes: openingTypes ?? this.openingTypes,
      thickness: thickness ?? this.thickness,
      topElevation: clearTopElevation ? null : topElevation ?? this.topElevation,
      floorFinish: floorFinish ?? this.floorFinish,
      colorValue: colorValue ?? this.colorValue,
      seismicLoad: clearSeismicLoad ? null : seismicLoad ?? this.seismicLoad,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'polygon': polygon.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
    'openings': openings.map((op) => op.map((p) => {'dx': p.dx, 'dy': p.dy}).toList()).toList(),
    if (openingTypes != null) 'openingTypes': openingTypes!.map((t) => t.name).toList(),
    'thickness': thickness,
    if (topElevation != null) 'topElevation': topElevation,
    'floorFinish': floorFinish,
    if (seismicLoad != null) 'seismicLoad': seismicLoad!.toJson(),
    'colorValue': colorValue,
  };

  factory StructuralSlab.fromJson(Map<String, dynamic> json) {
    return StructuralSlab(
      id: json['id'] as String,
      polygon: (json['polygon'] as List<dynamic>?)
              ?.map((p) => Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble()))
              .toList() ??
          [],
      openings: (json['openings'] as List<dynamic>?)
              ?.map((op) => (op as List<dynamic>)
                  .map((p) => Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble()))
                  .toList())
              .toList() ??
          [],
      openingTypes: (json['openingTypes'] as List<dynamic>?)
          ?.map((t) => SlabOpeningType.values.firstWhere(
                (v) => v.name == t,
                orElse: () => SlabOpeningType.shaft,
              ))
          .toList(),
      thickness: (json['thickness'] as num?)?.toDouble() ?? 0.20,
      topElevation: (json['topElevation'] as num?)?.toDouble(),
      floorFinish: (json['floorFinish'] as num?)?.toDouble(),
      seismicLoad: json['seismicLoad'] is Map
          ? SeismicSlabLoad.fromJson(Map<String, dynamic>.from(json['seismicLoad'] as Map)) : null,
      colorValue: json['colorValue'] as int?,
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

  /// Formatted elevation string (e.g. ±0.00, +2.80, -2.80) to save space without long floor text labels.
  String get elevationLabel {
    if (elevation.abs() < 1e-4) return '±0.00';
    final sign = elevation > 0 ? '+' : '';
    return '$sign${elevation.toStringAsFixed(2)}';
  }

  /// Whether any structural BIM elements exist on this storey.
  bool get hasAnyElements =>
      columns.isNotEmpty ||
      shearWalls.isNotEmpty ||
      beams.isNotEmpty ||
      slabs.isNotEmpty ||
      gridAxes.isNotEmpty;

  /// Computes the structural elevation (Конструктивна кота) for [slab].
  /// Calculated as explicit top elevation, or storey floor level (base elevation - finish).
  double structuralElevationFor(StructuralSlab slab) {
    return slab.topElevation ??
        (elevation - (slab.floorFinish ?? floorFinishThickness));
  }

  /// Absolute elevation of the underside of [slab] concrete in metres.
  double slabSoffitElevationFor(StructuralSlab slab) =>
      structuralElevationFor(slab) - slab.thickness;

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
          .map((s) => s.copyWith(
                id: '${s.id}_lvl_${newElevation.toInt()}',
                topElevation: s.topElevation != null
                    ? s.topElevation! + (newElevation - elevation)
                    : null,
              ))
          .toList(),
      gridAxes: List.from(gridAxes),
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'elevation': elevation,
    'floorFinishThickness': floorFinishThickness,
    'height': height,
    'columns': columns.map((c) => c.toJson()).toList(),
    'shearWalls': shearWalls.map((w) => w.toJson()).toList(),
    'beams': beams.map((b) => b.toJson()).toList(),
    'slabs': slabs.map((s) => s.toJson()).toList(),
    'gridAxes': gridAxes.map((a) => a.toJson()).toList(),
  };

  factory StoreyLevel.fromJson(Map<String, dynamic> json) {
    return StoreyLevel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Storey',
      elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
      floorFinishThickness: (json['floorFinishThickness'] as num?)?.toDouble() ?? 0.05,
      height: (json['height'] as num?)?.toDouble() ?? 2.80,
      columns: (json['columns'] as List<dynamic>?)
              ?.map((c) => StructuralColumn.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      shearWalls: (json['shearWalls'] as List<dynamic>?)
              ?.map((w) => StructuralShearWall.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
      beams: (json['beams'] as List<dynamic>?)
              ?.map((b) => StructuralBeam.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      slabs: (json['slabs'] as List<dynamic>?)
              ?.map((s) => StructuralSlab.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      gridAxes: (json['gridAxes'] as List<dynamic>?)
              ?.map((a) => StructuralGridAxis.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Supported building foundation types.
enum FoundationType {
  stripFooting,
  matFoundation,
}

/// Computes 2D Convex Hull of a set of 2D points using Andrew's Monotone Chain algorithm.
List<Offset> compute2DConvexHull(List<Offset> points) {
  if (points.length <= 3) return List.from(points);
  final pts = List<Offset>.from(points)
    ..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
  final unique = <Offset>[];
  for (final p in pts) {
    if (unique.isEmpty || (unique.last - p).distance > 1e-4) {
      unique.add(p);
    }
  }
  if (unique.length <= 3) return unique;

  double cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

  final lower = <Offset>[];
  for (final p in unique) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }

  final upper = <Offset>[];
  for (int i = unique.length - 1; i >= 0; i--) {
    final p = unique[i];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }

  lower.removeLast();
  upper.removeLast();
  return [...lower, ...upper];
}

/// Master project holding all storeys and analysis settings.
class StructuralProject {
  final String title;
  final List<StoreyLevel> storeys;
  final int activeStoreyIndex;
  final GhostStoreyMode ghostMode;
  final List<StructuralGridAxis> gridAxes; // Master project-level grid axes instances
  final FoundationType foundationType; // Default strip footings (ивични основи)
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
    this.gridAxes = const [],
    this.foundationType = FoundationType.stripFooting,
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

  /// Effective grid axes instances shared across the entire project.
  List<StructuralGridAxis> get effectiveGridAxes {
    if (gridAxes.isNotEmpty) return gridAxes;
    for (final s in storeys) {
      if (s.gridAxes.isNotEmpty) return s.gridAxes;
    }
    return const [];
  }

  /// Whether the project contains any basement storey (elevation below 0.00).
  bool get hasBasement => storeys.any((s) => s.elevation < -0.01);

  /// Synchronizes project-level grid axes instances across all storeys.
  StructuralProject copyWithGridAxes(List<StructuralGridAxis> newAxes) {
    return copyWith(
      gridAxes: newAxes,
      storeys: storeys.map((s) => s.copyWith(gridAxes: newAxes)).toList(),
    );
  }

  /// Computes default strip footing polygons (ивични основи) at ground level (±0.00).
  /// Generates continuous strip footings under shear walls, column pads, and connecting strip beams.
  List<List<Offset>> computeDefaultStripFoundations(
    StoreyLevel storey, {
    double stripWidthMeters = 0.60,
    double cadUnitsPerMeter = 1.0,
  }) {
    if (storey.columns.isEmpty && storey.shearWalls.isEmpty) return const [];
    final double wCad = stripWidthMeters * cadUnitsPerMeter;
    final List<List<Offset>> strips = [];

    // 1. Strip footings under all shear walls (ивични основи под шайби)
    for (final wall in storey.shearWalls) {
      final double l = wall.length;
      if (l < 1e-4) continue;
      final dir = (wall.end - wall.start) / l;
      final normal = Offset(-dir.dy, dir.dx);
      final double halfW = math.max(wall.thickness / 2.0 + 0.15 * cadUnitsPerMeter, wCad / 2.0);
      final double endExt = 0.20 * cadUnitsPerMeter;
      final p1 = wall.start - dir * endExt;
      final p2 = wall.end + dir * endExt;
      strips.add([
        p1 - normal * halfW,
        p2 - normal * halfW,
        p2 + normal * halfW,
        p1 + normal * halfW,
      ]);
    }

    // 2. Footing pads under columns (единични фундаменти/стъпки под колони)
    final double colPadExt = 0.25 * cadUnitsPerMeter;
    for (final col in storey.columns) {
      final halfW = col.width / 2.0 + colPadExt;
      final halfH = col.height / 2.0 + colPadExt;
      final c = col.center;
      final cosA = math.cos(col.rotationRad);
      final sinA = math.sin(col.rotationRad);
      Offset rot(double lx, double ly) => Offset(
        c.dx + (lx * cosA - ly * sinA),
        c.dy + (lx * sinA + ly * cosA),
      );
      strips.add([
        rot(-halfW, -halfH),
        rot(halfW, -halfH),
        rot(halfW, halfH),
        rot(-halfW, halfH),
      ]);
    }

    // 3. Connecting strip beams between adjacent columns along axes / bays (ивични фундаментни греди)
    final cols = storey.columns;
    final double maxBayCad = 8.0 * cadUnitsPerMeter;
    for (int i = 0; i < cols.length; i++) {
      for (int j = i + 1; j < cols.length; j++) {
        final c1 = cols[i].center;
        final c2 = cols[j].center;
        final delta = c2 - c1;
        final dist = delta.distance;
        if (dist > 1e-4 && dist <= maxBayCad) {
          // Check if orthogonal (aligned along X or Y within 20cm)
          final bool isOrthogonal = delta.dx.abs() <= 0.20 * cadUnitsPerMeter || delta.dy.abs() <= 0.20 * cadUnitsPerMeter;
          if (isOrthogonal) {
            final dir = delta / dist;
            // Check if there is an intermediate column between c1 and c2 along this span
            bool hasIntermediate = false;
            for (int k = 0; k < cols.length; k++) {
              if (k == i || k == j) continue;
              final ck = cols[k].center;
              final proj = (ck - c1).dx * dir.dx + (ck - c1).dy * dir.dy;
              if (proj > 0.30 * cadUnitsPerMeter && proj < dist - 0.30 * cadUnitsPerMeter) {
                final perpDist = ((ck - c1) - dir * proj).distance;
                if (perpDist <= 0.20 * cadUnitsPerMeter) {
                  hasIntermediate = true;
                  break;
                }
              }
            }
            if (!hasIntermediate) {
              final normal = Offset(-dir.dy, dir.dx);
              final halfW = wCad / 2.0;
              strips.add([
                c1 - normal * halfW,
                c2 - normal * halfW,
                c2 + normal * halfW,
                c1 + normal * halfW,
              ]);
            }
          }
        }
      }
    }

    // 4. Strip footings along any structural beams on the ground level
    for (final beam in storey.beams) {
      final double l = beam.length;
      if (l < 1e-4) continue;
      final dir = (beam.end - beam.start) / l;
      final normal = Offset(-dir.dy, dir.dx);
      final double halfW = math.max(beam.width / 2.0, wCad / 2.0);
      strips.add([
        beam.start - normal * halfW,
        beam.end - normal * halfW,
        beam.end + normal * halfW,
        beam.start + normal * halfW,
      ]);
    }

    return strips;
  }

  /// Computes default mat foundation base (фундаментна плоча) enclosing all columns and shear walls.
  StructuralSlab? computeDefaultMatFoundation(
    StoreyLevel storey, {
    double marginMeters = 0.50,
    double cadUnitsPerMeter = 1.0,
  }) {
    final allPts = <Offset>[];
    for (final col in storey.columns) {
      allPts.addAll(col.polygonVertices);
    }
    for (final wall in storey.shearWalls) {
      allPts.addAll(wall.polygonVertices);
    }
    if (allPts.length < 3) return null;

    final hull = compute2DConvexHull(allPts);
    if (hull.length < 3) return null;

    final tempSlab = StructuralSlab(id: 'foundation_mat_base', polygon: hull);
    final offsetPoly = tempSlab.offsetContour(marginMeters * cadUnitsPerMeter).polygon;

    return StructuralSlab(
      id: 'foundation_mat_base',
      polygon: offsetPoly,
      thickness: 0.50,
      colorValue: const Color(0xFF546E7A).toARGB32(),
    );
  }

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
    List<StructuralGridAxis>? gridAxes,
    FoundationType? foundationType,
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
      gridAxes: gridAxes ?? this.gridAxes,
      foundationType: foundationType ?? this.foundationType,
      concreteGrade: concreteGrade ?? this.concreteGrade,
      concreteE: concreteE ?? this.concreteE,
      deadLoadSuperimposed: deadLoadSuperimposed ?? this.deadLoadSuperimposed,
      liveLoad: liveLoad ?? this.liveLoad,
      facadeWallLoad: facadeWallLoad ?? this.facadeWallLoad,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'storeys': storeys.map((s) => s.toJson()).toList(),
    'activeStoreyIndex': activeStoreyIndex,
    'ghostMode': ghostMode.name,
    'gridAxes': gridAxes.map((a) => a.toJson()).toList(),
    'foundationType': foundationType.name,
    'concreteGrade': concreteGrade,
    'concreteE': concreteE,
    'deadLoadSuperimposed': deadLoadSuperimposed,
    'liveLoad': liveLoad,
    'facadeWallLoad': facadeWallLoad,
  };

  factory StructuralProject.fromJson(Map<String, dynamic> json) {
    return StructuralProject(
      title: json['title'] as String? ?? 'Конструктивен Модел',
      storeys: (json['storeys'] as List<dynamic>?)
              ?.map((s) => StoreyLevel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [
            StoreyLevel(
              id: 'storey_1',
              name: 'Етаж 1 (Кота ±0.00)',
              elevation: 0.0,
              height: 2.80,
            ),
          ],
      activeStoreyIndex: (json['activeStoreyIndex'] as num?)?.toInt() ?? 0,
      ghostMode: GhostStoreyMode.values.firstWhere(
        (g) => g.name == json['ghostMode'],
        orElse: () => GhostStoreyMode.none,
      ),
      gridAxes: (json['gridAxes'] as List<dynamic>?)
              ?.map((a) => StructuralGridAxis.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [],
      foundationType: FoundationType.values.firstWhere(
        (f) => f.name == json['foundationType'],
        orElse: () => FoundationType.stripFooting,
      ),
      concreteGrade: json['concreteGrade'] as String? ?? 'C25/30',
      concreteE: (json['concreteE'] as num?)?.toDouble() ?? 31000.0,
      deadLoadSuperimposed: (json['deadLoadSuperimposed'] as num?)?.toDouble() ?? 1.5,
      liveLoad: (json['liveLoad'] as num?)?.toDouble() ?? 2.0,
      facadeWallLoad: (json['facadeWallLoad'] as num?)?.toDouble() ?? 3.5,
    );
  }
}

/// Helper to extract numeric suffix from a name (e.g. "К3" -> 3, "W12" -> 12).
int? extractElementNumber(String name) {
  final match = RegExp(r'\d+').firstMatch(name);
  if (match == null) return null;
  return int.tryParse(match.group(0)!);
}

/// Helper to extract element prefix letters (e.g. "К3" -> "К", "W12" -> "W").
String? extractElementPrefix(String name) {
  final match = RegExp(r'^[^\d]+').firstMatch(name.trim());
  return match?.group(0);
}

/// Renumbers columns after a column has been deleted, ensuring no gaps in indices.
List<StructuralColumn> renumberColumnsAfterDeletion(
  List<StructuralColumn> remainingColumns,
  StructuralColumn deletedColumn, {
  String defaultPrefix = 'К',
}) {
  final deletedNum = extractElementNumber(deletedColumn.displayName);
  if (deletedNum == null) return remainingColumns;

  return remainingColumns.map((col) {
    final curNum = extractElementNumber(col.displayName);
    if (curNum != null && curNum > deletedNum) {
      final pfx = extractElementPrefix(col.displayName) ?? defaultPrefix;
      return col.copyWith(name: '$pfx${curNum - 1}');
    }
    return col;
  }).toList();
}

/// Renumbers shear walls after a shear wall has been deleted, ensuring no gaps in indices.
List<StructuralShearWall> renumberShearWallsAfterDeletion(
  List<StructuralShearWall> remainingWalls,
  StructuralShearWall deletedWall, {
  String defaultPrefix = 'Ш',
}) {
  final deletedNum = extractElementNumber(deletedWall.displayName);
  if (deletedNum == null) return remainingWalls;

  return remainingWalls.map((wall) {
    final curNum = extractElementNumber(wall.displayName);
    if (curNum != null && curNum > deletedNum) {
      final pfx = extractElementPrefix(wall.displayName) ?? defaultPrefix;
      return wall.copyWith(name: '$pfx${curNum - 1}');
    }
    return wall;
  }).toList();
}

/// Renumbers beams after a beam has been deleted, ensuring no gaps in indices.
List<StructuralBeam> renumberBeamsAfterDeletion(
  List<StructuralBeam> remainingBeams,
  StructuralBeam deletedBeam, {
  String defaultPrefix = 'Г',
}) {
  final deletedNum = extractElementNumber(deletedBeam.displayName);
  if (deletedNum == null) return remainingBeams;

  return remainingBeams.map((beam) {
    final curNum = extractElementNumber(beam.displayName);
    if (curNum != null && curNum > deletedNum) {
      final pfx = extractElementPrefix(beam.displayName) ?? defaultPrefix;
      return beam.copyWith(name: '$pfx${curNum - 1}');
    }
    return beam;
  }).toList();
}

/// Automatically re-sequences grid axes spatially:
/// Sorts parallel axes along their normal direction and renames them.
/// Axes closer to vertical -> Numbers (1, 2, 3...)
/// Axes closer to horizontal -> Letters (А, Б, В... in BG, A, B, C... in EN).
List<StructuralGridAxis> resequenceGridAxes(
  List<StructuralGridAxis> axes, {
  required bool isBulgarian,
}) {
  if (axes.isEmpty) return axes;

  const bgLetters = ['А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж', 'З', 'И', 'К', 'Л', 'М', 'Н', 'О', 'П', 'Р', 'С', 'Т', 'У', 'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Щ'];
  const enLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
  final letters = isBulgarian ? bgLetters : enLetters;

  // Group axes into parallel sets
  final groups = <List<StructuralGridAxis>>[];
  for (final axis in axes) {
    bool foundGroup = false;
    for (final group in groups) {
      if (group.first.isParallelTo(axis, toleranceRad: 0.15)) {
        group.add(axis);
        foundGroup = true;
        break;
      }
    }
    if (!foundGroup) {
      groups.add([axis]);
    }
  }

  final result = <StructuralGridAxis>[];

  for (int gIdx = 0; gIdx < groups.length; gIdx++) {
    final group = groups[gIdx];
    final refAxis = group.first;
    var normal = refAxis.normal;
    // Standardize normal direction to point in positive direction (left-to-right / bottom-to-top)
    if (normal.dx.abs() >= normal.dy.abs()) {
      if (normal.dx < 0) normal = -normal;
    } else {
      if (normal.dy < 0) normal = -normal;
    }

    // Sort axes in this group by position along the normal
    group.sort((a, b) {
      final midA = (a.start + a.end) / 2.0;
      final midB = (b.start + b.end) / 2.0;
      final coordA = midA.dx * normal.dx + midA.dy * normal.dy;
      final coordB = midB.dx * normal.dx + midB.dy * normal.dy;
      return coordA.compareTo(coordB);
    });

    final refAngle = refAxis.angleRad;
    final isVertical = (math.cos(refAngle).abs() <= math.sin(refAngle).abs());

    final bool useNumbers;
    if (groups.length == 1) {
      useNumbers = int.tryParse(refAxis.name) != null || isVertical;
    } else {
      useNumbers = isVertical;
    }

    for (int i = 0; i < group.length; i++) {
      final newName = useNumbers
          ? '${i + 1}'
          : (i < letters.length ? letters[i] : '${letters[i % letters.length]}${(i ~/ letters.length) + 1}');
      result.add(group[i].copyWith(name: newName));
    }
  }

  return result;
}

