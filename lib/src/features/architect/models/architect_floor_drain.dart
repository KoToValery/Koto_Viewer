// === SECTION: FLOOR DRAIN MODEL ===
// Table of Contents:
// 1. DRAIN SHAPE & DEFAULT DIMENSIONS
// 2. FLOOR DRAIN ELEMENT (floor area + drain + fall)

import 'dart:math' as math;
import 'dart:ui';
import 'architect_contour.dart';

// ===========================================================================
// 1. DRAIN SHAPE & DEFAULT DIMENSIONS
// ===========================================================================

enum ArchitectDrainShape { round, linear }

/// Realistic catalogue dimensions in metres.
class ArchitectDrainDefaults {
  ArchitectDrainDefaults._();

  /// Round grate diameter (outlet DN50 with a 100-150 mm grate).
  static const roundDiameter = 0.15;
  static const roundMin = 0.10;
  static const roundMax = 0.25;

  /// Linear channel: grate length and visible grate width (70-100 mm channel).
  static const linearLength = 0.80;
  static const linearMin = 0.40;
  static const linearMax = 1.50;
  static const linearWidth = 0.08;
  static const linearWidthMin = 0.06;
  static const linearWidthMax = 0.12;

  /// Wet-room fall, percent (EN 1253 / common practice 1-2 %, max 3 %).
  static const slopePercent = 1.5;
  static const slopeMin = 0.5;
  static const slopeMax = 3.0;
}

// ===========================================================================
// 2. FLOOR DRAIN ELEMENT
// ===========================================================================

/// A wet-area floor (bathroom, WC, balcony) with a round or linear drain.
/// The polygon is the finished-floor outline; the fall is derived from the
/// drain position, never stored, so editing the drain updates every slope.
class ArchitectFloorDrain {
  final String id;
  final List<Offset> polygon;
  final List<List<Offset>> holes;
  final ArchitectDrainShape shape;

  /// Centre of the grate in model metres.
  final Offset position;

  /// Axis direction of a linear channel, radians. Unused by round drains.
  final double angle;

  /// Round: grate diameter. Linear: grate length.
  final double size;

  /// Linear grate width. Unused by round drains.
  final double width;

  /// Fall of the finished floor towards the drain, in percent.
  final double slopePercent;

  const ArchitectFloorDrain({
    required this.id,
    required this.polygon,
    this.holes = const [],
    this.shape = ArchitectDrainShape.round,
    required this.position,
    this.angle = 0,
    this.size = ArchitectDrainDefaults.roundDiameter,
    this.width = ArchitectDrainDefaults.linearWidth,
    this.slopePercent = ArchitectDrainDefaults.slopePercent,
  });

  bool get isLinear => shape == ArchitectDrainShape.linear;

  /// Half of the grate footprint across the fall direction.
  double get halfWidth => isLinear ? width / 2 : size / 2;

  Offset get axisDirection => Offset(math.cos(angle), math.sin(angle));

  /// End points of the drain axis (identical for a round drain).
  (Offset, Offset) get axis {
    if (!isLinear) return (position, position);
    final half = axisDirection * (size / 2);
    return (position - half, position + half);
  }

  Offset get centroid {
    if (polygon.isEmpty) return Offset.zero;
    var x = 0.0, y = 0.0;
    for (final p in polygon) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / polygon.length, y / polygon.length);
  }

  double get area {
    if (polygon.length < 3) return 0;
    var sum = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2 - ArchitectContour.area(holes);
  }

  bool containsPoint(Offset point) =>
      ArchitectContour.path(polygon, holes).contains(point);

  ArchitectFloorDrain translate(Offset delta) => copyWith(
    polygon: [for (final p in polygon) p + delta],
    holes: ArchitectContour.transform(holes, (p) => p + delta),
    position: position + delta,
  );

  ArchitectFloorDrain copyWith({
    String? id,
    List<Offset>? polygon,
    List<List<Offset>>? holes,
    ArchitectDrainShape? shape,
    Offset? position,
    double? angle,
    double? size,
    double? width,
    double? slopePercent,
  }) => ArchitectFloorDrain(
    id: id ?? this.id,
    polygon: polygon ?? this.polygon,
    holes: holes ?? this.holes,
    shape: shape ?? this.shape,
    position: position ?? this.position,
    angle: angle ?? this.angle,
    size: size ?? this.size,
    width: width ?? this.width,
    slopePercent: slopePercent ?? this.slopePercent,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'polygon': [
      for (final p in polygon) {'x': p.dx, 'y': p.dy},
    ],
    if (holes.isNotEmpty) 'holes': ArchitectContour.write(holes),
    'shape': shape.name,
    'position': {'x': position.dx, 'y': position.dy},
    'angle': angle,
    'size': size,
    'width': width,
    'slopePercent': slopePercent,
  };

  factory ArchitectFloorDrain.fromJson(Map<String, dynamic> json) {
    Offset point(dynamic p) =>
        Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble());
    return ArchitectFloorDrain(
      id: json['id'] as String,
      polygon: [for (final p in json['polygon'] as List? ?? const []) point(p)],
      holes: ArchitectContour.read(json['holes']),
      shape: ArchitectDrainShape.values.firstWhere(
        (s) => s.name == json['shape'],
        orElse: () => ArchitectDrainShape.round,
      ),
      position: point(json['position']),
      angle: (json['angle'] as num?)?.toDouble() ?? 0,
      size:
          (json['size'] as num?)?.toDouble() ??
          ArchitectDrainDefaults.roundDiameter,
      width:
          (json['width'] as num?)?.toDouble() ??
          ArchitectDrainDefaults.linearWidth,
      slopePercent:
          (json['slopePercent'] as num?)?.toDouble() ??
          ArchitectDrainDefaults.slopePercent,
    );
  }
}
