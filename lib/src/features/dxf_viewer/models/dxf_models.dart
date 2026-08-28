import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../rendering/dxf_math.dart';
import '../rendering/dxf_quadtree.dart';

/// Vertex in lightweight polyline or 2D polyline.
class DxfPolylineVertex {
  final double x;
  final double y;
  final double bulge;
  final double startWidth;
  final double endWidth;

  const DxfPolylineVertex({
    required this.x,
    required this.y,
    this.bulge = 0.0,
    this.startWidth = 0.0,
    this.endWidth = 0.0,
  });

  Offset get offset => Offset(x, y);
}

/// Representation of a CAD Layer.
class DxfLayer {
  final String name;
  final int colorIndex;
  final int? trueColor;
  bool isVisible;
  final bool isFrozen;
  final double? lineweight;
  double? customLineweight; // null = Original (from DXF), or 0.12, 0.25, 0.35, 0.70 mm override
  final String? lineType;

  bool get isThick =>
      (customLineweight != null && customLineweight! >= 0.35) ||
      (customLineweight == null && (lineweight != null && lineweight! >= 0.35));

  set isThick(bool val) {
    customLineweight = val ? 0.70 : 0.12;
  }

  DxfLayer({
    required this.name,
    this.colorIndex = 7,
    this.trueColor,
    this.isVisible = true,
    this.isFrozen = false,
    this.lineweight,
    this.customLineweight,
    this.lineType,
    bool isThick = false,
  }) {
    if (isThick && customLineweight == null) {
      customLineweight = 0.70;
    }
  }

  DxfLayer copyWith({
    String? name,
    int? colorIndex,
    int? trueColor,
    bool? isVisible,
    bool? isFrozen,
    double? lineweight,
    double? customLineweight,
    String? lineType,
    bool? isThick,
  }) {
    final layer = DxfLayer(
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      trueColor: trueColor ?? this.trueColor,
      isVisible: isVisible ?? this.isVisible,
      isFrozen: isFrozen ?? this.isFrozen,
      lineweight: lineweight ?? this.lineweight,
      customLineweight: customLineweight ?? this.customLineweight,
      lineType: lineType ?? this.lineType,
    );
    if (isThick != null && customLineweight == null) {
      layer.isThick = isThick;
    }
    return layer;
  }
}

/// Representation of a CAD Block definition (reusable group of entities).
class DxfBlock {
  final String name;
  final Offset basePoint;
  final List<DxfEntity> entities;

  const DxfBlock({
    required this.name,
    this.basePoint = Offset.zero,
    this.entities = const [],
  });
}

/// Abstract base class for all DXF Entities.
abstract class DxfEntity {
  final String layer;
  final int? colorIndex;
  final int? trueColor;
  final String? lineType;
  final double? lineWeight;

  const DxfEntity({
    this.layer = '0',
    this.colorIndex,
    this.trueColor,
    this.lineType,
    this.lineWeight,
  });

  /// Compute axis-aligned bounding box of this entity in CAD coordinate space.
  Rect? getBoundingBox(Map<String, DxfBlock> blocks);

  /// Entity type label for statistics & inspection.
  String get typeName;
}

/// LINE Entity.
class DxfLine extends DxfEntity {
  final Offset p1;
  final Offset p2;

  const DxfLine({
    required this.p1,
    required this.p2,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'LINE';

  @override
  Rect getBoundingBox(Map<String, DxfBlock> blocks) {
    return Rect.fromPoints(p1, p2);
  }

  double get length => (p2 - p1).distance;
}

/// POINT Entity.
class DxfPoint extends DxfEntity {
  final Offset point;

  const DxfPoint({
    required this.point,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'POINT';

  @override
  Rect getBoundingBox(Map<String, DxfBlock> blocks) {
    return Rect.fromCircle(center: point, radius: 0.1);
  }
}

/// CIRCLE Entity.
class DxfCircle extends DxfEntity {
  final Offset center;
  final double radius;

  const DxfCircle({
    required this.center,
    required this.radius,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'CIRCLE';

  @override
  Rect getBoundingBox(Map<String, DxfBlock> blocks) {
    return Rect.fromCircle(center: center, radius: radius);
  }
}

/// ARC Entity.
class DxfArc extends DxfEntity {
  final Offset center;
  final double radius;
  final double startAngleDeg;
  final double endAngleDeg;

  const DxfArc({
    required this.center,
    required this.radius,
    required this.startAngleDeg,
    required this.endAngleDeg,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'ARC';

  @override
  Rect getBoundingBox(Map<String, DxfBlock> blocks) {
    // Exact bounding box factoring start & end angles + quadrant extremes
    double sweep = endAngleDeg - startAngleDeg;
    if (sweep <= 0) sweep += 360.0;

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    void testAngle(double deg) {
      final rad = deg * math.pi / 180.0;
      final x = center.dx + radius * math.cos(rad);
      final y = center.dy + radius * math.sin(rad);
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    testAngle(startAngleDeg);
    testAngle(endAngleDeg);

    // Check 0, 90, 180, 270 degrees if within arc sweep
    for (double testDeg = 0; testDeg < 360; testDeg += 90) {
      double diff = testDeg - startAngleDeg;
      while (diff < 0) {
        diff += 360.0;
      }
      while (diff >= 360.0) {
        diff -= 360.0;
      }
      if (diff <= sweep) {
        testAngle(testDeg);
      }
    }

    if (minX == double.infinity) {
      return Rect.fromCircle(center: center, radius: radius);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// ELLIPSE Entity.
class DxfEllipse extends DxfEntity {
  final Offset center;
  final Offset majorAxisEndOffset;
  final double minorRatio;
  final double startParam;
  final double endParam;

  const DxfEllipse({
    required this.center,
    required this.majorAxisEndOffset,
    required this.minorRatio,
    this.startParam = 0.0,
    this.endParam = 2 * math.pi,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'ELLIPSE';

  @override
  Rect getBoundingBox(Map<String, DxfBlock> blocks) {
    final double majorRadius = majorAxisEndOffset.distance;
    final double minorRadius = majorRadius * minorRatio;
    final double maxR = math.max(majorRadius, minorRadius);
    return Rect.fromCircle(center: center, radius: maxR);
  }
}

/// LWPOLYLINE (Lightweight Polyline) Entity.
class DxfLwPolyline extends DxfEntity {
  final List<DxfPolylineVertex> vertices;
  final bool isClosed;
  final double elevation;

  const DxfLwPolyline({
    required this.vertices,
    this.isClosed = false,
    this.elevation = 0.0,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'LWPOLYLINE';

  @override
  Rect? getBoundingBox(Map<String, DxfBlock> blocks) {
    if (vertices.isEmpty) return null;
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final v in vertices) {
      minX = math.min(minX, v.x);
      maxX = math.max(maxX, v.x);
      minY = math.min(minY, v.y);
      maxY = math.max(maxY, v.y);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// POLYLINE (2D or 3D Polyline) Entity.
class DxfPolyline extends DxfEntity {
  final List<DxfPolylineVertex> vertices;
  final bool isClosed;
  final bool is3D;
  final int flags;

  const DxfPolyline({
    required this.vertices,
    this.isClosed = false,
    this.is3D = false,
    this.flags = 0,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'POLYLINE';

  @override
  Rect? getBoundingBox(Map<String, DxfBlock> blocks) {
    if (vertices.isEmpty) return null;
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final v in vertices) {
      minX = math.min(minX, v.x);
      maxX = math.max(maxX, v.x);
      minY = math.min(minY, v.y);
      maxY = math.max(maxY, v.y);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// SPLINE (NURBS / B-Spline) Entity.
class DxfSpline extends DxfEntity {
  final int degree;
  final List<Offset> controlPoints;
  final List<Offset> fitPoints;
  final List<double> knots;
  final List<double> weights;
  final bool isClosed;
  final bool isRational;

  const DxfSpline({
    required this.degree,
    required this.controlPoints,
    this.fitPoints = const [],
    this.knots = const [],
    this.weights = const [],
    this.isClosed = false,
    this.isRational = false,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'SPLINE';

  @override
  Rect? getBoundingBox(Map<String, DxfBlock> blocks) {
    final points = controlPoints.isNotEmpty ? controlPoints : fitPoints;
    if (points.isEmpty) return null;
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// TEXT (Single-line Text) Entity.
class DxfText extends DxfEntity {
  final String text;
  final Offset insertPoint;
  final Offset? alignPoint;
  final double height;
  final double rotationDeg;
  final int hAlign; // 0=Left, 1=Center, 2=Right, 3=Aligned, 4=Middle, 5=Fit
  final int vAlign; // 0=Baseline, 1=Bottom, 2=Middle, 3=Top
  final String? style;

  const DxfText({
    required this.text,
    required this.insertPoint,
    this.alignPoint,
    this.height = 2.5,
    this.rotationDeg = 0.0,
    this.hAlign = 0,
    this.vAlign = 0,
    this.style,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'TEXT';

  @override
  Rect getBoundingBox(Map<String, DxfBlock> blocks) {
    final approxWidth = (text.length * height * 0.65).clamp(height, double.infinity);
    final pos = ((hAlign != 0 || vAlign != 0) && alignPoint != null) ? alignPoint! : insertPoint;
    return Rect.fromLTWH(pos.dx, pos.dy, approxWidth, height);
  }
}

/// MTEXT (Multi-line Text) Entity.
class DxfMText extends DxfEntity {
  final String rawText;
  final String cleanText;
  final Offset insertPoint;
  final double height;
  final double? refWidth;
  final double rotationDeg;
  final int attachmentPoint; // 1=TL, 2=TC, 3=TR, 4=ML, 5=MC, 6=MR, 7=BL, 8=BC, 9=BR
  final Offset? directionVector;

  const DxfMText({
    required this.rawText,
    required this.cleanText,
    required this.insertPoint,
    this.height = 2.5,
    this.refWidth,
    this.rotationDeg = 0.0,
    this.attachmentPoint = 1,
    this.directionVector,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'MTEXT';

  @override
  Rect getBoundingBox(Map<String, DxfBlock> blocks) {
    final double width = refWidth != null && refWidth! > 0
        ? refWidth!
        : (cleanText.length * height * 0.6).clamp(height * 2, double.infinity);
    final lines = cleanText.split('\n').length;
    final totalHeight = height * lines * 1.35;
    return Rect.fromLTWH(insertPoint.dx, insertPoint.dy, width, totalHeight);
  }
}

/// SOLID or TRACE (Filled triangle or quad) Entity.
class DxfSolid extends DxfEntity {
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final Offset p3;

  const DxfSolid({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.p3,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'SOLID';

  @override
  Rect getBoundingBox(Map<String, DxfBlock> blocks) {
    final minX = math.min(math.min(p0.dx, p1.dx), math.min(p2.dx, p3.dx));
    final maxX = math.max(math.max(p0.dx, p1.dx), math.max(p2.dx, p3.dx));
    final minY = math.min(math.min(p0.dy, p1.dy), math.min(p2.dy, p3.dy));
    final maxY = math.max(math.max(p0.dy, p1.dy), math.max(p2.dy, p3.dy));
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// HATCH Entity.
class DxfHatch extends DxfEntity {
  final List<List<Offset>> boundaryPaths;
  final String patternName;
  final bool isSolid;
  final double patternAngle;
  final double patternScale;
  final double? transparency; // 0.0 (transparent) to 1.0 (opaque), e.g. 0.10 for ArchiCAD 10% shadow fills

  const DxfHatch({
    required this.boundaryPaths,
    this.patternName = 'SOLID',
    this.isSolid = true,
    this.patternAngle = 0.0,
    this.patternScale = 1.0,
    this.transparency,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'HATCH';

  @override
  Rect? getBoundingBox(Map<String, DxfBlock> blocks) {
    if (boundaryPaths.isEmpty) return null;
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final loop in boundaryPaths) {
      for (final p in loop) {
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
    }
    if (minX == double.infinity) return null;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// INSERT (Block Reference) Entity.
class DxfInsert extends DxfEntity {
  final String blockName;
  final Offset insertPoint;
  final double scaleX;
  final double scaleY;
  final double scaleZ;
  final double rotationDeg;
  final int rowCount;
  final int colCount;
  final double rowSpacing;
  final double colSpacing;

  const DxfInsert({
    required this.blockName,
    required this.insertPoint,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.scaleZ = 1.0,
    this.rotationDeg = 0.0,
    this.rowCount = 1,
    this.colCount = 1,
    this.rowSpacing = 0.0,
    this.colSpacing = 0.0,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'INSERT';

  @override
  Rect? getBoundingBox(Map<String, DxfBlock> blocks) {
    final block = blocks[blockName];
    if (block == null || block.entities.isEmpty) {
      return Rect.fromCircle(center: insertPoint, radius: 1.0);
    }

    Rect? blockBounds;
    for (final child in block.entities) {
      final childBounds = child.getBoundingBox(blocks);
      if (childBounds != null) {
        blockBounds = blockBounds == null ? childBounds : blockBounds.expandToInclude(childBounds);
      }
    }

    if (blockBounds == null) {
      return Rect.fromCircle(center: insertPoint, radius: 1.0);
    }

    // Transform child bounds
    final sx = scaleX;
    final sy = scaleY;
    final left = insertPoint.dx + (blockBounds.left - block.basePoint.dx) * sx;
    final right = insertPoint.dx + (blockBounds.right - block.basePoint.dx) * sx;
    final top = insertPoint.dy + (blockBounds.top - block.basePoint.dy) * sy;
    final bottom = insertPoint.dy + (blockBounds.bottom - block.basePoint.dy) * sy;

    return Rect.fromLTRB(
      math.min(left, right),
      math.min(top, bottom),
      math.max(left, right),
      math.max(top, bottom),
    );
  }
}

/// DIMENSION Entity.
class DxfDimension extends DxfEntity {
  final int dimType;
  final Offset defPoint1;
  final Offset? defPoint2;
  final Offset textPoint;
  final String? textOverride;
  final String? blockName;

  const DxfDimension({
    required this.dimType,
    required this.defPoint1,
    this.defPoint2,
    required this.textPoint,
    this.textOverride,
    this.blockName,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'DIMENSION';

  @override
  Rect getBoundingBox(Map<String, DxfBlock> blocks) {
    if (blockName != null && blocks.containsKey(blockName)) {
      final b = blocks[blockName]!;
      Rect? bBounds;
      for (final e in b.entities) {
        final eb = e.getBoundingBox(blocks);
        if (eb != null) bBounds = bBounds == null ? eb : bBounds.expandToInclude(eb);
      }
      if (bBounds != null) return bBounds;
    }

    double minX = math.min(defPoint1.dx, textPoint.dx);
    double maxX = math.max(defPoint1.dx, textPoint.dx);
    double minY = math.min(defPoint1.dy, textPoint.dy);
    double maxY = math.max(defPoint1.dy, textPoint.dy);

    if (defPoint2 != null) {
      minX = math.min(minX, defPoint2!.dx);
      maxX = math.max(maxX, defPoint2!.dx);
      minY = math.min(minY, defPoint2!.dy);
      maxY = math.max(maxY, defPoint2!.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// LEADER Entity.
class DxfLeader extends DxfEntity {
  final List<Offset> vertices;
  final bool hasArrowhead;

  const DxfLeader({
    required this.vertices,
    this.hasArrowhead = true,
    super.layer,
    super.colorIndex,
    super.trueColor,
    super.lineType,
    super.lineWeight,
  });

  @override
  String get typeName => 'LEADER';

  @override
  Rect? getBoundingBox(Map<String, DxfBlock> blocks) {
    if (vertices.isEmpty) return null;
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final p in vertices) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// Full parsed DXF Document.
class DxfDocument {
  final Map<String, DxfLayer> layers;
  final Map<String, DxfBlock> blocks;
  final List<DxfEntity> entities;
  final Map<String, String> headerVars;
  final Rect bounds;
  final Map<String, int> entityStats;
  final Map<String, List<double>> lineTypes;
  DxfQuadTree? spatialIndex;

  DxfDocument({
    required this.layers,
    required this.blocks,
    required this.entities,
    required this.headerVars,
    required this.bounds,
    required this.entityStats,
    this.lineTypes = const {},
    this.spatialIndex,
  });

  /// Returns existing spatial index or builds a Quadtree on demand.
  DxfQuadTree get orBuildSpatialIndex =>
      spatialIndex ??= DxfQuadTree.build(entities, blocks, bounds);

  int get totalEntities => entities.length;
  int get totalLayers => layers.length;
  int get totalBlocks => blocks.length;

  double get width => bounds.width.abs();
  double get height => bounds.height.abs();
}

/// CAD Measurement and Markup tool types.
enum DxfMeasureTool {
  distance(label: 'Distance', icon: Icons.straighten),
  area(label: 'Area', icon: Icons.polyline),
  angle(label: 'Angle', icon: Icons.architecture),
  radius(label: 'Radius / Ø', icon: Icons.radio_button_unchecked),
  annotation(label: 'Leader Note', icon: Icons.arrow_outward);

  final String label;
  final IconData icon;
  const DxfMeasureTool({required this.label, required this.icon});
}

/// Represents a user-drawn CAD Annotation (Leader arrow pointing to a feature with an attached text note).
class DxfAnnotation {
  final String id;
  final Offset arrowTipCad;
  final Offset textPosCad;
  final String text;
  final int colorValue;
  final double? textHeight;
  final DateTime createdAt;

  const DxfAnnotation({
    required this.id,
    required this.arrowTipCad,
    required this.textPosCad,
    required this.text,
    this.colorValue = 0xFFFF5252,
    this.textHeight,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipX': arrowTipCad.dx,
    'tipY': arrowTipCad.dy,
    'textX': textPosCad.dx,
    'textY': textPosCad.dy,
    'text': text,
    'color': colorValue,
    'textHeight': textHeight,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DxfAnnotation.fromJson(Map<String, dynamic> json) => DxfAnnotation(
    id: json['id'] as String,
    arrowTipCad: Offset((json['tipX'] as num).toDouble(), (json['tipY'] as num).toDouble()),
    textPosCad: Offset((json['textX'] as num).toDouble(), (json['textY'] as num).toDouble()),
    text: json['text'] as String,
    colorValue: json['color'] as int? ?? 0xFFFF5252,
    textHeight: (json['textHeight'] as num?)?.toDouble(),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  DxfAnnotation copyWith({
    String? id,
    Offset? arrowTipCad,
    Offset? textPosCad,
    String? text,
    int? colorValue,
    double? textHeight,
    DateTime? createdAt,
  }) => DxfAnnotation(
    id: id ?? this.id,
    arrowTipCad: arrowTipCad ?? this.arrowTipCad,
    textPosCad: textPosCad ?? this.textPosCad,
    text: text ?? this.text,
    colorValue: colorValue ?? this.colorValue,
    textHeight: textHeight ?? this.textHeight,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// Rich measurement and annotation state model.
class DxfMeasurement {
  final DxfMeasureTool tool;

  // 1. Distance Tool
  final Offset? p1Cad;
  final Offset? p2Cad;

  // 2. Area Tool
  final List<Offset> areaPoints;
  final bool isAreaClosed;

  // 3. Angle Tool
  final Offset? angleVertex;
  final Offset? angleP1;
  final Offset? angleP2;

  // 4. Radius / Diameter Tool
  final Offset? circleCenter;
  final double? radius;
  final bool isArc;
  final double? arcLength;
  final List<Offset> circlePoints;

  // 5. Annotation / Leader Tool
  final Offset? annotationTip;
  final Offset? annotationTextPos;
  final String? annotationText;

  const DxfMeasurement({
    this.tool = DxfMeasureTool.distance,
    this.p1Cad,
    this.p2Cad,
    this.areaPoints = const [],
    this.isAreaClosed = false,
    this.angleVertex,
    this.angleP1,
    this.angleP2,
    this.circleCenter,
    this.radius,
    this.isArc = false,
    this.arcLength,
    this.circlePoints = const [],
    this.annotationTip,
    this.annotationTextPos,
    this.annotationText,
  });

  // Distance Helpers (backward compatible)
  double? get distance => (p1Cad != null && p2Cad != null) ? (p2Cad! - p1Cad!).distance : null;
  double? get deltaX => (p1Cad != null && p2Cad != null) ? (p2Cad!.dx - p1Cad!.dx).abs() : null;
  double? get deltaY => (p1Cad != null && p2Cad != null) ? (p2Cad!.dy - p1Cad!.dy).abs() : null;

  // Area Helpers
  double get area => DxfMath.calculatePolygonArea(areaPoints);
  double get perimeter => DxfMath.calculatePolygonPerimeter(areaPoints, isClosed: isAreaClosed || areaPoints.length >= 3);
  Offset get centroid => DxfMath.calculatePolygonCentroid(areaPoints);

  // Angle Helpers
  double? get angleDegrees {
    if (angleVertex != null && angleP1 != null && angleP2 != null) {
      return DxfMath.calculateAngleBetweenVectors(angleVertex!, angleP1!, angleP2!);
    }
    return null;
  }

  // Radius Helpers
  double? get diameter => radius != null ? radius! * 2.0 : null;

  DxfMeasurement copyWith({
    DxfMeasureTool? tool,
    Offset? p1Cad,
    Offset? p2Cad,
    List<Offset>? areaPoints,
    bool? isAreaClosed,
    Offset? angleVertex,
    Offset? angleP1,
    Offset? angleP2,
    Offset? circleCenter,
    double? radius,
    bool? isArc,
    double? arcLength,
    List<Offset>? circlePoints,
    Offset? annotationTip,
    Offset? annotationTextPos,
    String? annotationText,
  }) {
    return DxfMeasurement(
      tool: tool ?? this.tool,
      p1Cad: p1Cad ?? this.p1Cad,
      p2Cad: p2Cad ?? this.p2Cad,
      areaPoints: areaPoints ?? this.areaPoints,
      isAreaClosed: isAreaClosed ?? this.isAreaClosed,
      angleVertex: angleVertex ?? this.angleVertex,
      angleP1: angleP1 ?? this.angleP1,
      angleP2: angleP2 ?? this.angleP2,
      circleCenter: circleCenter ?? this.circleCenter,
      radius: radius ?? this.radius,
      isArc: isArc ?? this.isArc,
      arcLength: arcLength ?? this.arcLength,
      circlePoints: circlePoints ?? this.circlePoints,
      annotationTip: annotationTip ?? this.annotationTip,
      annotationTextPos: annotationTextPos ?? this.annotationTextPos,
      annotationText: annotationText ?? this.annotationText,
    );
  }
}
