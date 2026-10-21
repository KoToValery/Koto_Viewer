// === SECTION: ARCHITECTURAL COMPONENT DEFINITION & PARAMETRIC BUILDER ===
// Table of Contents:
// 1. PARAMETRIC SCHEMA & FIELD DEFINITIONS
// 2. CACHED COMPONENT GEOMETRY CONTAINER
// 3. PARAMETRIC SOLID & BLOCK BUILDER (ParametricSolidBuilder)
// 4. ABSTRACT COMPONENT DEFINITION (ArchitectComponentDefinition)

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../cad_3d/models/mesh_3d.dart';
import 'architect_component.dart';

// ===========================================================================
// 1. PARAMETRIC SCHEMA & FIELD DEFINITIONS
// ===========================================================================

/// Data type of a component parameter field.
enum ParametricFieldType { number, integer, boolean, choice }

/// Metadata describing a configurable property of a parametric component.
class ParametricFieldSchema {
  final String key;
  final String label;
  final ParametricFieldType type;
  final double defaultValue;
  final double min;
  final double max;
  final double step;
  final String unit;
  final List<String> options;

  const ParametricFieldSchema({
    required this.key,
    required this.label,
    this.type = ParametricFieldType.number,
    required this.defaultValue,
    this.min = 0.05,
    this.max = 10.0,
    this.step = 0.01,
    this.unit = 'm',
    this.options = const [],
  });
}

// ===========================================================================
// 2. CACHED COMPONENT GEOMETRY CONTAINER
// ===========================================================================

/// Container pairing the 3D solid mesh and 2D CAD block derived synchronously
/// from identical parameter values.
class CachedComponentGeometry {
  /// Watertight 3D mesh in Z-up architectural coordinates.
  final Mesh3D mesh3d;

  /// Clean 2D architectural block for plan rendering.
  final ArchitectComponentBlock2D block2d;

  const CachedComponentGeometry({
    required this.mesh3d,
    required this.block2d,
  });
}

// ===========================================================================
// 3. PARAMETRIC SOLID & BLOCK BUILDER (ParametricSolidBuilder)
// ===========================================================================

/// Fluent procedural geometry constructor.
///
/// Origin Convention:
/// - X axis: Centered [-width / 2, +width / 2]
/// - Y axis: Back at 0, front at +depth [0, depth]
/// - Z axis: Bottom at 0, top at +height [0, height]
class ParametricSolidBuilder {
  final double width;
  final double depth;
  final double height;

  final List<Triangle3D> _triangles = [];
  final List<Path> _detailPaths = [];
  Path? _customOutline;
  Path? _customMask;

  ParametricSolidBuilder({
    required this.width,
    required this.depth,
    required this.height,
  });

  List<Triangle3D> get triangles => List.unmodifiable(_triangles);

  /// Adds an axis-aligned box solid in Z-up coordinates.
  ///
  /// [origin]: (x, y) bottom-corner offset. If null, x defaults to -boxWidth/2 and y to 0.
  void addBox({
    Offset? origin,
    required double boxWidth,
    required double boxDepth,
    required double boxHeight,
    double zBottom = 0.0,
    Color color = const Color(0xFFEEEEEE),
    MeshMaterial? material,
  }) {
    final x0 = origin?.dx ?? (-boxWidth / 2.0);
    final y0 = origin?.dy ?? 0.0;
    final x1 = x0 + boxWidth;
    final y1 = y0 + boxDepth;
    final z0 = zBottom;
    final z1 = z0 + boxHeight;

    final p000 = Vector3(x0, y0, z0);
    final p100 = Vector3(x1, y0, z0);
    final p110 = Vector3(x1, y1, z0);
    final p010 = Vector3(x0, y1, z0);

    final p001 = Vector3(x0, y0, z1);
    final p101 = Vector3(x1, y0, z1);
    final p111 = Vector3(x1, y1, z1);
    final p011 = Vector3(x0, y1, z1);

    void quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d) {
      _triangles.add(Triangle3D(v0: a, v1: b, v2: c, color: color, material: material));
      _triangles.add(Triangle3D(v0: a, v1: c, v2: d, color: color, material: material));
    }

    // Bottom (normal -Z)
    quad(p000, p010, p110, p100);
    // Top (normal +Z)
    quad(p001, p101, p111, p011);
    // Back (Y = y0, normal -Y)
    quad(p000, p100, p101, p001);
    // Front (Y = y1, normal +Y)
    quad(p010, p011, p111, p110);
    // Left (X = x0, normal -X)
    quad(p000, p001, p011, p010);
    // Right (X = x1, normal +X)
    quad(p100, p110, p111, p101);
  }

  /// Adds a vertical cylinder aligned with the Z axis.
  void addCylinder({
    required Offset center,
    required double radius,
    required double cylinderHeight,
    double zBottom = 0.0,
    int segments = 16,
    Color color = const Color(0xFFFFFFFF),
    MeshMaterial? material,
  }) {
    if (segments < 3 || radius <= 1e-4) return;
    final z0 = zBottom;
    final z1 = z0 + cylinderHeight;

    final circle0 = <Vector3>[];
    final circle1 = <Vector3>[];

    for (var i = 0; i < segments; i++) {
      final angle = (i / segments) * 2.0 * math.pi;
      final px = center.dx + math.cos(angle) * radius;
      final py = center.dy + math.sin(angle) * radius;
      circle0.add(Vector3(px, py, z0));
      circle1.add(Vector3(px, py, z1));
    }

    final topCenter = Vector3(center.dx, center.dy, z1);
    final botCenter = Vector3(center.dx, center.dy, z0);

    for (var i = 0; i < segments; i++) {
      final next = (i + 1) % segments;
      // Side quads
      _triangles.add(Triangle3D(v0: circle0[i], v1: circle1[i], v2: circle1[next], color: color, material: material));
      _triangles.add(Triangle3D(v0: circle0[i], v1: circle1[next], v2: circle0[next], color: color, material: material));

      // Top cap
      _triangles.add(Triangle3D(v0: topCenter, v1: circle1[i], v2: circle1[next], color: color, material: material));

      // Bottom cap
      _triangles.add(Triangle3D(v0: botCenter, v1: circle0[next], v2: circle0[i], color: color, material: material));
    }
  }

  /// Adds 2D plan detail line.
  void add2DDetailLine(Offset from, Offset to) {
    final p = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(to.dx, to.dy);
    _detailPaths.add(p);
  }

  /// Adds 2D plan detail path.
  void add2DDetailPath(Path path) {
    _detailPaths.add(path);
  }

  /// Sets a custom 2D plan outline instead of the default bounding rectangle.
  void set2DOutline(Path outline, {Path? mask}) {
    _customOutline = outline;
    _customMask = mask ?? outline;
  }

  /// Compiles both the 3D mesh and 2D block.
  CachedComponentGeometry build(String name) {
    final rect = Rect.fromLTRB(-width / 2.0, 0.0, width / 2.0, depth);
    final defaultPath = Path()..addRect(rect);

    final block = ArchitectComponentBlock2D(
      boundsMask: _customMask ?? defaultPath,
      outline: _customOutline ?? defaultPath,
      detailPaths: List.unmodifiable(_detailPaths),
      bounds: rect,
    );

    final mesh = Mesh3D(
      name: name,
      triangles: List.unmodifiable(_triangles),
    );

    return CachedComponentGeometry(
      mesh3d: mesh,
      block2d: block,
    );
  }
}

// ===========================================================================
// 4. ABSTRACT COMPONENT DEFINITION (ArchitectComponentDefinition)
// ===========================================================================

/// Abstract contract for any architectural 3D/2D parametric component.
abstract class ArchitectComponentDefinition {
  /// Unique identifier (e.g. 'sanitary_toilet_wall_hung').
  String get id;

  /// User-friendly display name key / default English name.
  String get defaultName;

  /// Functional category.
  ArchitectComponentCategory get category;

  /// Attachment rule.
  ComponentPlacementMode get placementMode;

  /// Schema of configurable dimensions and properties.
  List<ParametricFieldSchema> get schema;

  /// Default parameter values.
  Map<String, dynamic> get defaultParameters {
    return {for (final f in schema) f.key: f.defaultValue};
  }

  /// Synchronously generates 3D mesh and 2D CAD block from parameters.
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params);
}
