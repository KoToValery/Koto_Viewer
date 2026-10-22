import 'architect_view_drawing.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'architect_section.dart';

enum ArchitectCompassDirection {
  north,
  northEast,
  east,
  southEast,
  south,
  southWest,
  west,
  northWest,
}

/// Clockwise radians from plan-up (-Y). The building coordinates never rotate.
class ArchitectNorthSymbol {
  final Offset position;
  final double angle;
  const ArchitectNorthSymbol({required this.position, this.angle = 0});
  Offset get direction => Offset(math.sin(angle), -math.cos(angle));
  Map<String, dynamic> toJson() => {
    'position': sectionPointJson(position),
    'angle': angle,
  };
  factory ArchitectNorthSymbol.fromJson(Map<String, dynamic> json) =>
      ArchitectNorthSymbol(
        position: sectionPoint(json['position'] as Map),
        angle: (json['angle'] as num?)?.toDouble() ?? 0,
      );
}

/// A finite horizontal viewing span. Positive side looks to the left of its axis
/// in model coordinates; the compass name describes the outward-facing normal.
class ArchitectElevation {
  final String id;
  final Offset start, end;
  final int viewSide;
  final double? viewDepth;
  final ArchitectViewDrawing drawing;
  const ArchitectElevation({
    required this.id,
    required this.start,
    required this.end,
    this.viewSide = 1,
    this.viewDepth,
    this.drawing = const ArchitectViewDrawing(),
  });
  double get length => (end - start).distance;
  Offset get axis =>
      length > 1e-9 ? (end - start) / length : const Offset(1, 0);
  Offset get centre => (start + end) / 2;
  Offset get viewDirection => Offset(-axis.dy, axis.dx) * viewSide.toDouble();
  Offset get right => axis * viewSide.toDouble();
  ArchitectCompassDirection compassDirection(double northAngle) {
    final outward = -viewDirection;
    final bearing = math.atan2(outward.dx, -outward.dy) - northAngle;
    final sector = (bearing / (math.pi / 4)).round();
    return ArchitectCompassDirection.values[sector % 8];
  }

  ArchitectElevation copyWith({
    Offset? start,
    Offset? end,
    int? viewSide,
    ArchitectViewDrawing? drawing,
    double? viewDepth,
    bool clearViewDepth = false,
  }) => ArchitectElevation(
    id: id,
    start: start ?? this.start,
    end: end ?? this.end,
    viewSide: viewSide ?? this.viewSide,
    drawing: drawing ?? this.drawing,
    viewDepth: clearViewDepth ? null : viewDepth ?? this.viewDepth,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'start': sectionPointJson(start),
    'end': sectionPointJson(end),
    'viewSide': viewSide,
    'viewDepth': viewDepth,
    'drawing': drawing.toJson(),
  };
  factory ArchitectElevation.fromJson(Map<String, dynamic> json) =>
      ArchitectElevation(
        id: json['id'] as String,
        start: sectionPoint(json['start'] as Map),
        end: sectionPoint(json['end'] as Map),
        viewSide: json['viewSide'] == -1 ? -1 : 1,
        viewDepth: viewDepthFromJson(json['viewDepth']),
        drawing: ArchitectViewDrawing.fromJson(
          Map<String, dynamic>.from(json['drawing'] as Map? ?? {}),
        ),
      );
}
