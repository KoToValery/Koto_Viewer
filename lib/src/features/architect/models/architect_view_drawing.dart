import 'architect_elements.dart';
import 'dart:ui';

/// User drafting in view coordinates: horizontal metres and negative elevation.
/// Kept outside storeys so annotations never enter the building's 3D geometry.
class ArchitectViewDrawing {
  final List<ArchitectDimension> dimensions;
  final List<ArchitectElevationMarker> elevationMarkers;
  final List<ArchitectAnnotation> annotations;
  final List<ArchitectCadPrimitive> cadPrimitives;

  const ArchitectViewDrawing({
    this.dimensions = const [],
    this.elevationMarkers = const [],
    this.annotations = const [],
    this.cadPrimitives = const [],
  });

  /// Converts ordered-cut stations to screen-right coordinates, and back.
  /// Text stays readable; this mirrors positions rather than painted glyphs.
  ArchitectViewDrawing reflectedHorizontally(double span) {
    Offset point(Offset p) => Offset(span - p.dx, p.dy);
    return ArchitectViewDrawing(
      dimensions: [
        for (final d in dimensions)
          d.copyWith(
            startPoint: point(d.startPoint),
            endPoint: point(d.endPoint),
            offsetDistance: -d.offsetDistance,
            direction: d.direction == null
                ? null
                : Offset(-d.direction!.dx, d.direction!.dy),
            anchors: [for (final a in d.anchors) a.at(point(a.point))],
          ),
      ],
      annotations: [
        for (final a in annotations) a.copyWith(position: point(a.position)),
      ],
      elevationMarkers: [
        for (final m in elevationMarkers)
          m.copyWith(position: point(m.position)),
      ],
      cadPrimitives: [
        for (final p in cadPrimitives)
          p.copyWith(
            startPoint: point(p.startPoint),
            endPoint: point(p.endPoint),
            polygon: p.type == CadPrimitiveType.polyline
                ? p.linePoints.map(point).toList()
                : p.polygon?.map(point).toList().reversed.toList(),
            holes: [
              for (final hole in p.holes)
                hole.map(point).toList().reversed.toList(),
            ],
            hatchAngle: p.hatchAngle < 0
                ? -180 - p.hatchAngle
                : 180 - p.hatchAngle,
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'dimensions': dimensions.map((e) => e.toJson()).toList(),
    'elevationMarkers': elevationMarkers.map((e) => e.toJson()).toList(),
    'annotations': annotations.map((e) => e.toJson()).toList(),
    'cadPrimitives': cadPrimitives.map((e) => e.toJson()).toList(),
  };

  factory ArchitectViewDrawing.fromJson(
    Map<String, dynamic> json,
  ) => ArchitectViewDrawing(
    dimensions: (json['dimensions'] as List? ?? [])
        .map(
          (e) =>
              ArchitectDimension.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    elevationMarkers: (json['elevationMarkers'] as List? ?? [])
        .map(
          (e) => ArchitectElevationMarker.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(),
    annotations: (json['annotations'] as List? ?? [])
        .map(
          (e) =>
              ArchitectAnnotation.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    cadPrimitives: (json['cadPrimitives'] as List? ?? [])
        .map(
          (e) => ArchitectCadPrimitive.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(),
  );
}
