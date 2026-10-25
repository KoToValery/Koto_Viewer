// === SECTION: ARCHITECTURAL COMPONENT INSTANCE & 2D BLOCK MODELS ===
// Table of Contents:
// 1. ENUMS (Category, Placement Mode, Snap Point Type)
// 2. 2D CAD BLOCK PRIMITIVES & CONTAINER (ArchitectComponentBlock2D)
// 3. COMPONENT INSTANCE ENTITY (ArchitectComponentInstance)

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

// ===========================================================================
// 1. ENUMS
// ===========================================================================

/// High-level architectural classification for components and library items.
enum ArchitectComponentCategory {
  sanitary,
  furniture,
  kitchen,
  storage,
  equipment,
  lighting,
  office,
  outdoor,
  doors,
  windows;

  static ArchitectComponentCategory fromName(String? name) {
    return ArchitectComponentCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => ArchitectComponentCategory.furniture,
    );
  }
}

/// Placement rule for an architectural component.
enum ComponentPlacementMode {
  /// The object naturally attaches to a wall (toilets, vanities, radiators, wardrobes).
  /// The back face (Y = 0) aligns to the wall surface, and +Y faces into the room.
  wallAttached,

  /// Freestanding object (tables, chairs, sofas, kitchen islands).
  freeStanding;

  static ComponentPlacementMode fromName(String? name) {
    return ComponentPlacementMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ComponentPlacementMode.freeStanding,
    );
  }
}

// ===========================================================================
// 2. 2D CAD BLOCK CONTAINER (ArchitectComponentBlock2D)
// ===========================================================================

/// Represents a compiled 2D CAD/BIM block symbol.
///
/// Origin Convention:
/// - X is centered: [-width / 2, +width / 2]
/// - Y starts at back = 0, facing forward into positive Y: [0, depth]
class ArchitectComponentBlock2D {
  /// Solid mask polygon used to clear/whiteout floor hatches and slab lines underneath.
  final Path boundsMask;

  /// Perimeter cut/profile line of the object.
  final Path outline;

  /// Internal detail linework (e.g. pillow seams, sanitary bowls, sink drains, cabinet lines).
  final List<Path> detailPaths;

  /// Bounding box in local coordinates.
  final Rect bounds;

  const ArchitectComponentBlock2D({
    required this.boundsMask,
    required this.outline,
    this.detailPaths = const [],
    required this.bounds,
  });

  /// Creates a simple rectangular block.
  factory ArchitectComponentBlock2D.rect({
    required double width,
    required double depth,
    List<Path> details = const [],
  }) {
    final rect = Rect.fromLTRB(-width / 2.0, 0.0, width / 2.0, depth);
    final p = Path()..addRect(rect);
    return ArchitectComponentBlock2D(
      boundsMask: p,
      outline: p,
      detailPaths: details,
      bounds: rect,
    );
  }
}

// ===========================================================================
// 3. COMPONENT INSTANCE ENTITY
// ===========================================================================

/// An instance of a parametric 3D/2D component placed on an architectural storey.
class ArchitectComponentInstance {
  final String id;
  final String definitionId;

  /// Plan position in metres on the storey coordinate plane (X, Y).
  final Offset position;

  /// Vertical offset in metres relative to storey finished floor elevation (Z).
  /// e.g. 0.0 for floor objects, +0.15 for wall-hung toilets, +1.45 for upper cabinets.
  final double elevationOffset;

  /// Rotation angle in radians around the local Z axis.
  final double rotation;

  /// Parametric dimensions and customization properties.
  /// Standard keys include: 'width', 'depth', 'height'.
  final Map<String, dynamic> parameters;

  /// Optional custom label or schedule tag.
  final String label;

  /// Whether the component is temporarily hidden or locked.
  final bool isVisible;
  final bool isLocked;

  /// Explicit override for whether this component appears in building sections.
  /// When null, inherits [ArchitectComponentDefinition.defaultVisibleInSection]
  /// (which is false for furniture/sanitary and true for floor drains).
  final bool? visibleInSection;

  const ArchitectComponentInstance({
    required this.id,
    required this.definitionId,
    required this.position,
    this.elevationOffset = 0.0,
    this.rotation = 0.0,
    this.parameters = const {},
    this.label = '',
    this.isVisible = true,
    this.isLocked = false,
    this.visibleInSection,
  });

  bool get isFloorDrainComponent =>
      definitionId == 'sanitary_floor_drain' ||
      definitionId == 'sanitary_linear_drain';

  bool effectiveVisibleInSection({bool defaultFromDefinition = false}) {
    if (visibleInSection != null) return visibleInSection!;
    if (parameters['visibleInSection'] is bool) {
      return parameters['visibleInSection'] as bool;
    }
    if (isFloorDrainComponent) return true;
    return defaultFromDefinition;
  }

  double get width => (parameters['width'] as num?)?.toDouble() ?? 0.60;
  double get depth => (parameters['depth'] as num?)?.toDouble() ?? 0.60;
  double get height => (parameters['height'] as num?)?.toDouble() ?? 0.85;

  /// Local bounds in metres: X centered, Y from 0 to depth.
  Rect get localBounds => Rect.fromLTRB(-width / 2.0, 0.0, width / 2.0, depth);

  /// 4 World-space polygon corners of the component footprint.
  List<Offset> get worldPolygonCorners {
    final wHalf = width / 2.0;
    final d = depth;
    final cosR = math.cos(rotation);
    final sinR = math.sin(rotation);

    Offset transform(double lx, double ly) {
      final rx = lx * cosR - ly * sinR;
      final ry = lx * sinR + ly * cosR;
      return Offset(position.dx + rx, position.dy + ry);
    }

    return [
      transform(-wHalf, 0.0), // Back-left
      transform(wHalf, 0.0),  // Back-right
      transform(wHalf, d),    // Front-right
      transform(-wHalf, d),   // Front-left
    ];
  }

  /// Axis-aligned bounding box in world coordinates.
  Rect get worldBoundingRect {
    final corners = worldPolygonCorners;
    var minX = corners[0].dx, maxX = corners[0].dx;
    var minY = corners[0].dy, maxY = corners[0].dy;
    for (var i = 1; i < corners.length; i++) {
      final p = corners[i];
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Hit testing for 2D floor plan interactions.
  bool containsPoint(Offset point) {
    final corners = worldPolygonCorners;
    // Standard point-in-polygon ray-casting test
    var inside = false;
    for (int i = 0, j = corners.length - 1; i < corners.length; j = i++) {
      final xi = corners[i].dx, yi = corners[i].dy;
      final xj = corners[j].dx, yj = corners[j].dy;
      final intersect =
          ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / (yj - yi + 1e-12) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  ArchitectComponentInstance copyWith({
    String? id,
    String? definitionId,
    Offset? position,
    double? elevationOffset,
    double? rotation,
    Map<String, dynamic>? parameters,
    String? label,
    bool? isVisible,
    bool? isLocked,
    bool? visibleInSection,
  }) {
    return ArchitectComponentInstance(
      id: id ?? this.id,
      definitionId: definitionId ?? this.definitionId,
      position: position ?? this.position,
      elevationOffset: elevationOffset ?? this.elevationOffset,
      rotation: rotation ?? this.rotation,
      parameters: parameters ?? this.parameters,
      label: label ?? this.label,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      visibleInSection: visibleInSection ?? this.visibleInSection,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'definitionId': definitionId,
    'x': position.dx,
    'y': position.dy,
    'elevationOffset': elevationOffset,
    'rotation': rotation,
    'parameters': parameters,
    if (label.isNotEmpty) 'label': label,
    if (!isVisible) 'isVisible': isVisible,
    if (isLocked) 'isLocked': isLocked,
    if (visibleInSection != null) 'visibleInSection': visibleInSection,
  };

  factory ArchitectComponentInstance.fromJson(Map<String, dynamic> json) {
    return ArchitectComponentInstance(
      id: json['id'] as String,
      definitionId: json['definitionId'] as String,
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
      ),
      elevationOffset: (json['elevationOffset'] as num?)?.toDouble() ?? 0.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      parameters: json['parameters'] != null
          ? Map<String, dynamic>.from(json['parameters'] as Map)
          : const {},
      label: json['label'] as String? ?? '',
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      visibleInSection: json['visibleInSection'] as bool?,
    );
  }
}
