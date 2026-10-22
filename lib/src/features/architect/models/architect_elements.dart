import 'architect_line_style.dart';
import 'architect_hatch_pattern.dart';
// === SECTION: ARCHITECTURAL ELEMENT MODELS ===
import 'dart:ui';
import 'package:flutter/material.dart';
import 'architect_stair_design.dart';
export 'architect_stair_design.dart';

// ===========================================================================
// 0. CUT DISPLAY MODE (PLAN CUT PLANE / СРЯЗВАЩА РАВНИНА)
// ===========================================================================

/// Defines how an architectural element is displayed relative to the floor plan cut plane.
enum ArchitectCutDisplayMode {
  /// Automatically determined by whether the floor cut plane intersects the element's height range.
  /// Parapets (< 1.50m or typed as parapet) automatically display in projection (uncut).
  auto,

  /// Always displayed in projection (uncut) with a medium/thin contour line (ideal for parapets).
  projected,

  /// Always displayed as cut with heavy core border and thin insulation outline.
  cut,

  /// Displayed as overhead element (above cut plane, e.g. with dashed line).
  overhead;

  static ArchitectCutDisplayMode fromName(String? name) {
    return ArchitectCutDisplayMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ArchitectCutDisplayMode.auto,
    );
  }
}

// ===========================================================================
// 1. ARCHITECTURAL BEAM / LINTEL
// ===========================================================================

class ArchitectBeam {
  final String id;
  final Offset startPoint;
  final Offset endPoint;
  final double width; // in meters (default 0.25 m = 25 cm)
  final double depth; // in meters (default 0.50 m = 50 cm)
  final double
  baseOffset; // in meters relative to storey elevation (default 2.20 m)
  final ArchitectCutDisplayMode cutDisplayMode;
  final String label;

  const ArchitectBeam({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    this.width = 0.25,
    this.depth = 0.50,
    this.baseOffset = 2.20,
    this.cutDisplayMode = ArchitectCutDisplayMode.auto,
    this.label = 'B 25/50',
  });

  bool isCutAt(double storeyCutPlane) {
    return switch (cutDisplayMode) {
      ArchitectCutDisplayMode.cut => true,
      ArchitectCutDisplayMode.projected => false,
      ArchitectCutDisplayMode.overhead => false,
      ArchitectCutDisplayMode.auto => () {
        final zLow = baseOffset;
        final zHigh = baseOffset + depth;
        return zLow <= storeyCutPlane && storeyCutPlane <= zHigh;
      }(),
    };
  }

  bool isOverheadAt(double storeyCutPlane) {
    return switch (cutDisplayMode) {
      ArchitectCutDisplayMode.overhead => true,
      ArchitectCutDisplayMode.auto => baseOffset > storeyCutPlane,
      _ => false,
    };
  }

  double get length => (endPoint - startPoint).distance;

  Offset get unitVector {
    final len = length;
    if (len < 1e-4) return const Offset(1, 0);
    return (endPoint - startPoint) / len;
  }

  Offset get normalVector {
    final u = unitVector;
    return Offset(-u.dy, u.dx);
  }

  List<Offset> get polygonCorners {
    final n = normalVector * (width / 2.0);
    return [startPoint - n, endPoint - n, endPoint + n, startPoint + n];
  }

  ArchitectBeam copyWith({
    String? id,
    Offset? startPoint,
    Offset? endPoint,
    double? width,
    double? depth,
    double? baseOffset,
    ArchitectCutDisplayMode? cutDisplayMode,
    String? label,
  }) => ArchitectBeam(
    id: id ?? this.id,
    startPoint: startPoint ?? this.startPoint,
    endPoint: endPoint ?? this.endPoint,
    width: width ?? this.width,
    depth: depth ?? this.depth,
    baseOffset: baseOffset ?? this.baseOffset,
    cutDisplayMode: cutDisplayMode ?? this.cutDisplayMode,
    label: label ?? this.label,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startPoint': {'x': startPoint.dx, 'y': startPoint.dy},
    'endPoint': {'x': endPoint.dx, 'y': endPoint.dy},
    'width': width,
    'depth': depth,
    'baseOffset': baseOffset,
    'cutDisplayMode': cutDisplayMode.name,
    'label': label,
  };

  factory ArchitectBeam.fromJson(Map<String, dynamic> json) => ArchitectBeam(
    id: json['id'] as String,
    startPoint: Offset(
      (json['startPoint']['x'] as num).toDouble(),
      (json['startPoint']['y'] as num).toDouble(),
    ),
    endPoint: Offset(
      (json['endPoint']['x'] as num).toDouble(),
      (json['endPoint']['y'] as num).toDouble(),
    ),
    width: (json['width'] as num?)?.toDouble() ?? 0.25,
    depth: (json['depth'] as num?)?.toDouble() ?? 0.50,
    baseOffset: (json['baseOffset'] as num?)?.toDouble() ?? 2.20,
    cutDisplayMode: ArchitectCutDisplayMode.fromName(
      json['cutDisplayMode'] as String?,
    ),
    label: json['label'] as String? ?? 'B 25/50',
  );

  bool containsPoint(Offset pt, {double tolerance = 0.15}) {
    final len = length;
    if (len < 1e-4) return (pt - startPoint).distance <= tolerance;
    final u = unitVector;
    final v = pt - startPoint;
    final dot = v.dx * u.dx + v.dy * u.dy;
    final ratio = (dot / len).clamp(0.0, 1.0);
    final proj = startPoint + u * (ratio * len);
    return (pt - proj).distance <= (width / 2.0 + tolerance);
  }
}

// ===========================================================================
// 2. ARCHITECTURAL SLAB / FLOOR
// ===========================================================================

class ArchitectSlab {
  final String id;
  final List<Offset> polygon;
  final double thickness; // in meters (default 0.20 m = 20 cm)
  final String label;
  final String? assemblyId;
  final double coreTopOffset;
  final double? slopeDirection; // radians; arrow points downhill

  const ArchitectSlab({
    required this.id,
    required this.polygon,
    this.thickness = 0.20,
    this.label = 'Slab d=20cm',
    this.assemblyId,
    this.coreTopOffset = 0,
    this.slopeDirection,
  });

  double get area {
    if (polygon.length < 3) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      sum += (p1.dx * p2.dy - p2.dx * p1.dy);
    }
    return (sum.abs() / 2.0);
  }

  Offset get centroid {
    if (polygon.isEmpty) return Offset.zero;
    double cx = 0, cy = 0;
    for (final p in polygon) {
      cx += p.dx;
      cy += p.dy;
    }
    return Offset(cx / polygon.length, cy / polygon.length);
  }

  ArchitectSlab copyWith({
    String? id,
    List<Offset>? polygon,
    double? thickness,
    String? label,
    String? assemblyId,
    bool clearAssembly = false,
    double? coreTopOffset,
    double? slopeDirection,
  }) => ArchitectSlab(
    id: id ?? this.id,
    polygon: polygon ?? this.polygon,
    thickness: thickness ?? this.thickness,
    label: label ?? this.label,
    assemblyId: clearAssembly ? null : assemblyId ?? this.assemblyId,
    coreTopOffset: coreTopOffset ?? this.coreTopOffset,
    slopeDirection: slopeDirection ?? this.slopeDirection,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'polygon': polygon.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'thickness': thickness,
    'label': label,
    'assemblyId': assemblyId,
    'coreTopOffset': coreTopOffset,
    'slopeDirection': slopeDirection,
  };

  factory ArchitectSlab.fromJson(Map<String, dynamic> json) => ArchitectSlab(
    id: json['id'] as String,
    polygon:
        (json['polygon'] as List<dynamic>?)
            ?.map(
              (p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ),
            )
            .toList() ??
        const [],
    thickness: (json['thickness'] as num?)?.toDouble() ?? 0.20,
    label: json['label'] as String? ?? 'Slab d=20cm',
    assemblyId: json['assemblyId'] as String?,
    coreTopOffset: (json['coreTopOffset'] as num?)?.toDouble() ?? 0,
    slopeDirection: (json['slopeDirection'] as num?)?.toDouble(),
  );

  bool containsPoint(Offset pt) {
    if (polygon.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].dy > pt.dy) != (polygon[j].dy > pt.dy)) &&
          (pt.dx <
              (polygon[j].dx - polygon[i].dx) *
                      (pt.dy - polygon[i].dy) /
                      (polygon[j].dy - polygon[i].dy) +
                  polygon[i].dx)) {
        inside = !inside;
      }
    }
    return inside;
  }
}

// ===========================================================================
// 3. ARCHITECTURAL OPENING / SHAFT / VOID
// ===========================================================================

enum OpeningType { shaft, floorVoid, elevator }

class ArchitectOpening {
  final String id;
  final List<Offset> boundary;
  final String label;
  final OpeningType type;

  const ArchitectOpening({
    required this.id,
    required this.boundary,
    this.label = 'Shaft',
    this.type = OpeningType.shaft,
  });

  Offset get centroid {
    if (boundary.isEmpty) return Offset.zero;
    double cx = 0, cy = 0;
    for (final p in boundary) {
      cx += p.dx;
      cy += p.dy;
    }
    return Offset(cx / boundary.length, cy / boundary.length);
  }

  ArchitectOpening copyWith({
    String? id,
    List<Offset>? boundary,
    String? label,
    OpeningType? type,
  }) => ArchitectOpening(
    id: id ?? this.id,
    boundary: boundary ?? this.boundary,
    label: label ?? this.label,
    type: type ?? this.type,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'boundary': boundary.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'label': label,
    'type': type.name,
  };

  factory ArchitectOpening.fromJson(Map<String, dynamic> json) =>
      ArchitectOpening(
        id: json['id'] as String,
        boundary:
            (json['boundary'] as List<dynamic>?)
                ?.map(
                  (p) => Offset(
                    (p['x'] as num).toDouble(),
                    (p['y'] as num).toDouble(),
                  ),
                )
                .toList() ??
            const [],
        label: json['label'] as String? ?? 'Shaft',
        type: OpeningType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => OpeningType.shaft,
        ),
      );
}

// ===========================================================================
// 4. ARCHITECTURAL STAIR
// ===========================================================================

class ArchitectStair {
  final String id;
  final Offset startPoint;
  final Offset endPoint;
  final double width; // flight width in meters (default 1.10 m)
  final int _stepCount;
  final bool _hasLanding;
  final ArchitectStairDesign? design;
  int get stepCount => design?.risers ?? _stepCount;
  bool get hasLanding => design == null ? _hasLanding : design!.flightCount > 1;

  const ArchitectStair({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    this.width = 1.10,
    int stepCount = 16,
    bool hasLanding = false,
    this.design,
  }) : _stepCount = stepCount,
       _hasLanding = hasLanding;

  double get length => (endPoint - startPoint).distance;

  Offset get unitVector {
    final len = length;
    if (len < 1e-4) return const Offset(1, 0);
    return (endPoint - startPoint) / len;
  }

  Offset get normalVector {
    final u = unitVector;
    return Offset(-u.dy, u.dx);
  }

  List<Offset> get polygonCorners {
    if (design != null) {
      final bounds = plan.bounds;
      return [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomRight,
        bounds.bottomLeft,
      ];
    }
    final n = normalVector * (width / 2.0);
    return [startPoint - n, endPoint - n, endPoint + n, startPoint + n];
  }

  static final _plans = Expando<ArchitectStairPlan>();

  /// Includes the caption for framing/culling, without enlarging the pick area.
  Rect get displayBounds {
    final bounds = plan.bounds;
    if (design?.showLabel != true) return bounds.inflate(.08);
    final label = Rect.fromCenter(
      center: bounds.bottomCenter + const Offset(0, .4),
      width: 5,
      height: .8,
    );
    return bounds.inflate(.08).expandToInclude(label);
  }

  ArchitectStairPlan get plan => _plans[this] ??= design == null
      ? ArchitectStairPlan(
          [polygonCorners],
          [
            for (var i = 1; i < stepCount; i++)
              (
                startPoint +
                    unitVector * (length * i / stepCount) -
                    normalVector * width / 2,
                startPoint +
                    unitVector * (length * i / stepCount) +
                    normalVector * width / 2,
              ),
          ],
          [startPoint, endPoint],
        )
      : ArchitectStairPlan.build(
          start: startPoint,
          direction: endPoint - startPoint,
          width: width,
          design: design!,
        );

  ArchitectStair copyWith({
    String? id,
    Offset? startPoint,
    Offset? endPoint,
    double? width,
    int? stepCount,
    bool? hasLanding,
    ArchitectStairDesign? design,
  }) => ArchitectStair(
    id: id ?? this.id,
    startPoint: startPoint ?? this.startPoint,
    endPoint: endPoint ?? this.endPoint,
    width: width ?? this.width,
    stepCount: stepCount ?? this.stepCount,
    hasLanding: hasLanding ?? this.hasLanding,
    design: design ?? this.design,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startPoint': {'x': startPoint.dx, 'y': startPoint.dy},
    'endPoint': {'x': endPoint.dx, 'y': endPoint.dy},
    'width': width,
    'stepCount': stepCount,
    'hasLanding': hasLanding,
    if (design != null) 'design': design!.toJson(),
  };

  factory ArchitectStair.fromJson(Map<String, dynamic> json) => ArchitectStair(
    id: json['id'] as String,
    startPoint: Offset(
      (json['startPoint']['x'] as num).toDouble(),
      (json['startPoint']['y'] as num).toDouble(),
    ),
    endPoint: Offset(
      (json['endPoint']['x'] as num).toDouble(),
      (json['endPoint']['y'] as num).toDouble(),
    ),
    width: (json['width'] as num?)?.toDouble() ?? 1.10,
    stepCount: (json['stepCount'] as num?)?.toInt() ?? 16,
    hasLanding: json['hasLanding'] as bool? ?? false,
    design: json['design'] is Map
        ? ArchitectStairDesign.fromJson(
            Map<String, dynamic>.from(json['design'] as Map),
          )
        : null,
  );
}

// ===========================================================================
// 5. ARCHITECTURAL DIMENSION LINE (РАЗМЕРНА ЛИНИЯ)
// ===========================================================================

/// A persistent witness point. Unattached points retain their model coordinates.
/// Attached points resolve against the element on every model transaction.
class ArchitectDimensionAnchor {
  final Offset point;
  final String? elementId;
  final String feature;
  final int index;
  final double ratio;
  final double side;
  const ArchitectDimensionAnchor({
    required this.point,
    this.elementId,
    this.feature = 'point',
    this.index = 0,
    this.ratio = 0,
    this.side = 0,
  });
  ArchitectDimensionAnchor at(Offset value) => ArchitectDimensionAnchor(
    point: value,
    elementId: elementId,
    feature: feature,
    index: index,
    ratio: ratio,
    side: side,
  );
  Map<String, dynamic> toJson() => {
    'point': {'x': point.dx, 'y': point.dy},
    'elementId': elementId,
    'feature': feature,
    'index': index,
    'ratio': ratio,
    'side': side,
  };
  factory ArchitectDimensionAnchor.fromJson(Map<String, dynamic> json) =>
      ArchitectDimensionAnchor(
        point: Offset(
          (json['point']['x'] as num).toDouble(),
          (json['point']['y'] as num).toDouble(),
        ),
        elementId: json['elementId'] as String?,
        feature: json['feature'] as String? ?? 'point',
        index: json['index'] as int? ?? 0,
        ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
        side: (json['side'] as num?)?.toDouble() ?? 0,
      );
}

enum ArchitectDimensionStyle { exterior, interior, single }

class ArchitectDimension {
  final String id;
  final Offset startPoint;
  final Offset endPoint;
  final double offsetDistance; // perpendicular offset in meters
  final String? customText;
  final List<ArchitectDimensionAnchor> anchors;
  final Offset? direction;
  final bool showOverall;
  final ArchitectDimensionStyle style;

  const ArchitectDimension({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    this.offsetDistance = 0.50,
    this.customText,
    this.anchors = const [],
    this.direction,
    this.showOverall = true,
    this.style = ArchitectDimensionStyle.exterior,
  });

  bool get isChain => anchors.isNotEmpty;
  Offset get unitVector =>
      direction ??
      (length > 1e-8 ? (endPoint - startPoint) / length : const Offset(1, 0));
  Offset get normal => Offset(-unitVector.dy, unitVector.dx);
  Offset get lineStart => startPoint + normal * offsetDistance;
  Offset get lineEnd => endPoint + normal * offsetDistance;

  /// Keep all associations, but measure only the inward faces of end walls.
  /// Both faces of intermediate partitions remain on the interior row.
  List<ArchitectDimensionAnchor> get measuredAnchors {
    if (style != ArchitectDimensionStyle.interior) return anchors;
    double position(ArchitectDimensionAnchor a) =>
        (a.point - startPoint).dx * unitVector.dx +
        (a.point - startPoint).dy * unitVector.dy;
    final faces = anchors.where((a) => a.feature == 'wallFace').toList()
      ..sort((a, b) => position(a).compareTo(position(b)));
    if (faces.map((a) => a.elementId).toSet().length < 2) return anchors;
    final firstId = faces.first.elementId;
    final lastId = faces.last.elementId;
    final lower = faces
        .where((a) => a.elementId == firstId)
        .map(position)
        .reduce((a, b) => a > b ? a : b);
    final upper = faces
        .where((a) => a.elementId == lastId)
        .map(position)
        .reduce((a, b) => a < b ? a : b);
    return anchors
        .where(
          (a) => position(a) >= lower - 1e-6 && position(a) <= upper + 1e-6,
        )
        .toList();
  }

  List<Offset> get witnessPoints => isChain
      ? measuredAnchors.map((a) => a.point).toList()
      : [startPoint, endPoint];
  List<Offset> get dimensionPoints {
    final u = unitVector;
    final values = witnessPoints.map((p) {
      final d = p - startPoint;
      return d.dx * u.dx + d.dy * u.dy;
    }).toList()..sort();
    final unique = <double>[];
    for (final value in values) {
      if (unique.isEmpty || (value - unique.last).abs() > 1e-6) {
        unique.add(value);
      }
    }
    return unique.map((t) => lineStart + u * t).toList();
  }

  double get length => (endPoint - startPoint).distance;

  String get displayText {
    if (customText != null && customText!.trim().isNotEmpty) {
      return customText!;
    }
    return length.toStringAsFixed(2);
  }

  ArchitectDimension copyWith({
    String? id,
    Offset? startPoint,
    Offset? endPoint,
    double? offsetDistance,
    String? customText,
    List<ArchitectDimensionAnchor>? anchors,
    Offset? direction,
    bool? showOverall,
    ArchitectDimensionStyle? style,
  }) => ArchitectDimension(
    id: id ?? this.id,
    startPoint: startPoint ?? this.startPoint,
    endPoint: endPoint ?? this.endPoint,
    offsetDistance: offsetDistance ?? this.offsetDistance,
    customText: customText ?? this.customText,
    anchors: anchors ?? this.anchors,
    direction: direction ?? this.direction,
    showOverall: showOverall ?? this.showOverall,
    style: style ?? this.style,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startPoint': {'x': startPoint.dx, 'y': startPoint.dy},
    'endPoint': {'x': endPoint.dx, 'y': endPoint.dy},
    'offsetDistance': offsetDistance,
    'customText': customText,
    'style': style.name,
    if (anchors.isNotEmpty) 'anchors': anchors.map((a) => a.toJson()).toList(),
    if (direction != null)
      'direction': {'x': direction!.dx, 'y': direction!.dy},
    if (anchors.isNotEmpty) 'showOverall': showOverall,
  };

  factory ArchitectDimension.fromJson(Map<String, dynamic> json) =>
      ArchitectDimension(
        id: json['id'] as String,
        startPoint: Offset(
          (json['startPoint']['x'] as num).toDouble(),
          (json['startPoint']['y'] as num).toDouble(),
        ),
        endPoint: Offset(
          (json['endPoint']['x'] as num).toDouble(),
          (json['endPoint']['y'] as num).toDouble(),
        ),
        offsetDistance: (json['offsetDistance'] as num?)?.toDouble() ?? 0.50,
        customText: json['customText'] as String?,
        showOverall: json['showOverall'] as bool? ?? true,
        style:
            ArchitectDimensionStyle.values
                .where((style) => style.name == json['style'])
                .firstOrNull ??
            ArchitectDimensionStyle.exterior,
        anchors: (json['anchors'] as List? ?? [])
            .map(
              (a) =>
                  ArchitectDimensionAnchor.fromJson(a as Map<String, dynamic>),
            )
            .toList(),
        direction: json['direction'] == null
            ? null
            : Offset(
                (json['direction']['x'] as num).toDouble(),
                (json['direction']['y'] as num).toDouble(),
              ),
      );
}

// ===========================================================================
// 6. ARCHITECTURAL ELEVATION MARKER (НИВОВА КОТА ±0.00)
// ===========================================================================

class ArchitectElevationMarker {
  final String id;
  final Offset position;
  final double elevation; // in meters
  final String? label; // optional note, e.g. "ГП" or "КК"

  const ArchitectElevationMarker({
    required this.id,
    required this.position,
    required this.elevation,
    this.label,
  });

  String get formattedElevation {
    if (elevation.abs() < 1e-4) return '±0.00';
    final sign = elevation > 0 ? '+' : '';
    return '$sign${elevation.toStringAsFixed(2)}';
  }

  ArchitectElevationMarker copyWith({
    String? id,
    Offset? position,
    double? elevation,
    String? label,
  }) => ArchitectElevationMarker(
    id: id ?? this.id,
    position: position ?? this.position,
    elevation: elevation ?? this.elevation,
    label: label ?? this.label,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': {'x': position.dx, 'y': position.dy},
    'elevation': elevation,
    'label': label,
  };

  factory ArchitectElevationMarker.fromJson(Map<String, dynamic> json) =>
      ArchitectElevationMarker(
        id: json['id'] as String,
        position: Offset(
          (json['position']['x'] as num).toDouble(),
          (json['position']['y'] as num).toDouble(),
        ),
        elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
        label: json['label'] as String?,
      );
}

// ===========================================================================
// 7. ARCHITECTURAL TEXT ANNOTATION
// ===========================================================================

class ArchitectAnnotation {
  final String id;
  final Offset position;
  final String text;
  final double fontSize; // in meters (default 0.30 m)

  const ArchitectAnnotation({
    required this.id,
    required this.position,
    required this.text,
    this.fontSize = 0.30,
  });

  ArchitectAnnotation copyWith({
    String? id,
    Offset? position,
    String? text,
    double? fontSize,
  }) => ArchitectAnnotation(
    id: id ?? this.id,
    position: position ?? this.position,
    text: text ?? this.text,
    fontSize: fontSize ?? this.fontSize,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': {'x': position.dx, 'y': position.dy},
    'text': text,
    'fontSize': fontSize,
  };

  factory ArchitectAnnotation.fromJson(Map<String, dynamic> json) =>
      ArchitectAnnotation(
        id: json['id'] as String,
        position: Offset(
          (json['position']['x'] as num).toDouble(),
          (json['position']['y'] as num).toDouble(),
        ),
        text: json['text'] as String? ?? '',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 0.30,
      );
}

// ===========================================================================
// 8. 2D CAD PRIMITIVES (LINE, RECT, CIRCLE)
// ===========================================================================

enum CadPrimitiveType { line, rect, circle, hatch }

class ArchitectCadPrimitive {
  final String id;
  final CadPrimitiveType type;
  final Offset startPoint;
  final Offset endPoint;
  final int colorValue; // ARGB
  final List<Offset>? polygon;
  final double strokeWidth;
  final ArchitectLineStyle lineStyle;
  final ArchitectHatchPattern hatchPattern;
  final double hatchScale, hatchAngle;
  final bool hatchBorder;

  const ArchitectCadPrimitive({
    required this.id,
    required this.type,
    required this.startPoint,
    required this.endPoint,
    this.colorValue = 0xFF424242,
    this.strokeWidth = 1.0,
    this.lineStyle = ArchitectLineStyle.solid,
    this.hatchPattern = ArchitectHatchPattern.diagonal,
    this.hatchScale = 1,
    this.hatchAngle = 0,
    this.hatchBorder = true,
    this.polygon,
  });

  List<Offset> get polygonCorners {
    if (polygon != null) return polygon!;
    final rect = Rect.fromPoints(startPoint, endPoint);
    return [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
  }

  bool get isPolygon => type == CadPrimitiveType.rect || type == CadPrimitiveType.hatch;

  ArchitectCadPrimitive copyWith({
    String? id,
    CadPrimitiveType? type,
    Offset? startPoint,
    Offset? endPoint,
    int? colorValue,
    double? strokeWidth,
    ArchitectLineStyle? lineStyle,
    ArchitectHatchPattern? hatchPattern,
    double? hatchScale,
    double? hatchAngle,
    bool? hatchBorder,
    List<Offset>? polygon,
  }) => ArchitectCadPrimitive(
    id: id ?? this.id,
    type: type ?? this.type,
    startPoint: startPoint ?? this.startPoint,
    endPoint: endPoint ?? this.endPoint,
    colorValue: colorValue ?? this.colorValue,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    lineStyle: lineStyle ?? this.lineStyle,
    hatchPattern: hatchPattern ?? this.hatchPattern,
    hatchScale: hatchScale ?? this.hatchScale,
    hatchAngle: hatchAngle ?? this.hatchAngle,
    hatchBorder: hatchBorder ?? this.hatchBorder,
    polygon: polygon ?? this.polygon,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'startPoint': {'x': startPoint.dx, 'y': startPoint.dy},
    'endPoint': {'x': endPoint.dx, 'y': endPoint.dy},
    'colorValue': colorValue,
    'strokeWidth': strokeWidth,
    if (type != CadPrimitiveType.circle) 'lineStyle': lineStyle.toJson(),
    if (type == CadPrimitiveType.hatch) ...{
      'hatchPattern': hatchPattern.toJson(), 'hatchScale': hatchScale,
      'hatchAngle': hatchAngle, 'hatchBorder': hatchBorder,
    },
    if (polygon != null)
      'polygon': [
        for (final p in polygon!) {'x': p.dx, 'y': p.dy},
      ],
  };

  factory ArchitectCadPrimitive.fromJson(Map<String, dynamic> json) =>
      ArchitectCadPrimitive(
        id: json['id'] as String,
        type: CadPrimitiveType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => CadPrimitiveType.line,
        ),
        startPoint: Offset(
          (json['startPoint']['x'] as num).toDouble(),
          (json['startPoint']['y'] as num).toDouble(),
        ),
        endPoint: Offset(
          (json['endPoint']['x'] as num).toDouble(),
          (json['endPoint']['y'] as num).toDouble(),
        ),
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF424242,
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1.0,
        hatchPattern: json['hatchPattern'] is Map ? ArchitectHatchPattern.fromJson(
          Map<String, dynamic>.from(json['hatchPattern'] as Map)) : ArchitectHatchPattern.diagonal,
        hatchScale: (json['hatchScale'] as num?)?.toDouble() ?? 1,
        hatchAngle: (json['hatchAngle'] as num?)?.toDouble() ?? 0,
        hatchBorder: json['hatchBorder'] as bool? ?? true,
        lineStyle: json['lineStyle'] is Map
            ? ArchitectLineStyle.fromJson(
                Map<String, dynamic>.from(json['lineStyle'] as Map),
              )
            : ArchitectLineStyle.solid,
        polygon: (json['polygon'] as List?)
            ?.map(
              (p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ),
            )
            .toList(),
      );
}
