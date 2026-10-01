import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Supported geometric cross-section shapes for columns.
enum ColumnShape {
  rectangular,
  circular,
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
  final Offset center;
  final ColumnShape shape;
  final double width; // in meters (or diameter if circular)
  final double height; // in meters
  final double rotationRad;

  const StructuralColumn({
    required this.id,
    required this.center,
    this.shape = ColumnShape.rectangular,
    this.width = 0.25,
    this.height = 0.50,
    this.rotationRad = 0.0,
  });

  /// Top-left corner of the column in CAD coordinates.
  Offset get topLeft => Offset(center.dx - width / 2.0, center.dy + height / 2.0);

  /// Creates a column with its top-left corner positioned at [topLeft] in CAD coordinates.
  factory StructuralColumn.fromTopLeft({
    required String id,
    required Offset topLeft,
    ColumnShape shape = ColumnShape.rectangular,
    double width = 0.25,
    double height = 0.50,
    double rotationRad = 0.0,
  }) {
    final center = Offset(topLeft.dx + width / 2.0, topLeft.dy - height / 2.0);
    return StructuralColumn(
      id: id,
      center: center,
      shape: shape,
      width: width,
      height: height,
      rotationRad: rotationRad,
    );
  }

  /// Calculates the 4 corner vertices of the column in CAD world coordinates,
  /// starting from Top-Left in clockwise/counter-clockwise order.
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
    Offset? center,
    ColumnShape? shape,
    double? width,
    double? height,
    double? rotationRad,
  }) {
    return StructuralColumn(
      id: id ?? this.id,
      center: center ?? this.center,
      shape: shape ?? this.shape,
      width: width ?? this.width,
      height: height ?? this.height,
      rotationRad: rotationRad ?? this.rotationRad,
    );
  }
}

/// Represents a structural reinforced concrete shear wall (шайба).
class StructuralShearWall {
  final String id;
  final Offset start;
  final Offset end;
  final double thickness; // in meters (default 0.25)

  const StructuralShearWall({
    required this.id,
    required this.start,
    required this.end,
    this.thickness = 0.25,
  });

  double get length {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get angleRad => math.atan2(end.dy - start.dy, end.dx - start.dx);

  /// 4 corner vertices forming the thick wall box in CAD coordinates.
  List<Offset> get polygonVertices {
    final double l = length;
    if (l < 1e-6) {
      return [start, start, start, start];
    }
    final double halfT = thickness / 2.0;
    final double nx = -(end.dy - start.dy) / l * halfT;
    final double ny = (end.dx - start.dx) / l * halfT;

    return [
      Offset(start.dx + nx, start.dy + ny),
      Offset(end.dx + nx, end.dy + ny),
      Offset(end.dx - nx, end.dy - ny),
      Offset(start.dx - nx, start.dy - ny),
    ];
  }

  StructuralShearWall copyWith({
    String? id,
    Offset? start,
    Offset? end,
    double? thickness,
  }) {
    return StructuralShearWall(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      thickness: thickness ?? this.thickness,
    );
  }
}

/// Represents a reinforced concrete slab (плоча).
class StructuralSlab {
  final String id;
  final List<Offset> polygon; // Outer perimeter boundary
  final List<List<Offset>> openings; // Staircase, elevator, shaft cutouts
  final double thickness; // in meters (default 0.20)

  const StructuralSlab({
    required this.id,
    required this.polygon,
    this.openings = const [],
    this.thickness = 0.20,
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
  }) {
    return StructuralSlab(
      id: id ?? this.id,
      polygon: polygon ?? this.polygon,
      openings: openings ?? this.openings,
      thickness: thickness ?? this.thickness,
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
  final double elevation; // Z height above ground (m)
  final double height; // Clear floor-to-floor height (m)
  final List<StructuralColumn> columns;
  final List<StructuralShearWall> shearWalls;
  final List<StructuralSlab> slabs;

  const StoreyLevel({
    required this.id,
    required this.name,
    this.elevation = 0.0,
    this.height = 2.80,
    this.columns = const [],
    this.shearWalls = const [],
    this.slabs = const [],
  });

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
      height: height,
      columns: columns
          .map((c) => c.copyWith(id: '${c.id}_lvl_${newElevation.toInt()}'))
          .toList(),
      shearWalls: shearWalls
          .map((w) => w.copyWith(id: '${w.id}_lvl_${newElevation.toInt()}'))
          .toList(),
      slabs: slabs
          .map((s) => s.copyWith(id: '${s.id}_lvl_${newElevation.toInt()}'))
          .toList(),
    );
  }

  StoreyLevel copyWith({
    String? id,
    String? name,
    double? elevation,
    double? height,
    List<StructuralColumn>? columns,
    List<StructuralShearWall>? shearWalls,
    List<StructuralSlab>? slabs,
  }) {
    return StoreyLevel(
      id: id ?? this.id,
      name: name ?? this.name,
      elevation: elevation ?? this.elevation,
      height: height ?? this.height,
      columns: columns ?? this.columns,
      shearWalls: shearWalls ?? this.shearWalls,
      slabs: slabs ?? this.slabs,
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
