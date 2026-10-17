import 'architect_elements.dart';

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
