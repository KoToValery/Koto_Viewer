// === SECTION: ARCHITECTURAL COMPONENT DEFINITION & PARAMETRIC BUILDER ===
// Table of Contents:
// 1. PARAMETRIC SCHEMA & FIELD DEFINITIONS
// 2. CACHED COMPONENT GEOMETRY CONTAINER
// 3. PARAMETRIC SOLID & BLOCK BUILDER (ParametricSolidBuilder)
// 4. ABSTRACT COMPONENT DEFINITION (ArchitectComponentDefinition)

import 'dart:math' as math;
import 'dart:typed_data';
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

  const CachedComponentGeometry({required this.mesh3d, required this.block2d});
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
  Path? _footprint;
  Path? _customOutline;
  Path? _customMask;

  ParametricSolidBuilder({
    required this.width,
    required this.depth,
    required this.height,
  });

  List<Triangle3D> get triangles => List.unmodifiable(_triangles);

  void _includeFootprint(Path path) {
    _footprint = _footprint == null
        ? path
        : Path.combine(PathOperation.union, _footprint!, path);
  }

  void _validateSize(Iterable<double> values) {
    if (values.any((v) => !v.isFinite || v <= 0)) {
      throw const FormatException(
        'Solid dimensions must be positive and finite',
      );
    }
  }

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
    _validateSize([boxWidth, boxDepth, boxHeight]);
    final x0 = origin?.dx ?? (-boxWidth / 2.0);
    final y0 = origin?.dy ?? 0.0;
    final x1 = x0 + boxWidth;
    final y1 = y0 + boxDepth;
    final z0 = zBottom;
    final z1 = z0 + boxHeight;
    _includeFootprint(Path()..addRect(Rect.fromLTRB(x0, y0, x1, y1)));

    final p000 = Vector3(x0, y0, z0);
    final p100 = Vector3(x1, y0, z0);
    final p110 = Vector3(x1, y1, z0);
    final p010 = Vector3(x0, y1, z0);

    final p001 = Vector3(x0, y0, z1);
    final p101 = Vector3(x1, y0, z1);
    final p111 = Vector3(x1, y1, z1);
    final p011 = Vector3(x0, y1, z1);

    void quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d) {
      _triangles.add(
        Triangle3D(v0: a, v1: b, v2: c, color: color, material: material),
      );
      _triangles.add(
        Triangle3D(v0: a, v1: c, v2: d, color: color, material: material),
      );
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
    int segments = 48,
    Color color = const Color(0xFFFFFFFF),
    MeshMaterial? material,
  }) {
    _validateSize([radius, cylinderHeight]);
    if (segments < 3 || segments > 256) {
      throw const FormatException(
        'Cylinder segments must be between 3 and 256',
      );
    }
    _includeFootprint(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
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
      _triangles.add(
        Triangle3D(
          v0: circle0[i],
          v1: circle0[next],
          v2: circle1[next],
          color: color,
          material: material,
        ),
      );
      _triangles.add(
        Triangle3D(
          v0: circle0[i],
          v1: circle1[next],
          v2: circle1[i],
          color: color,
          material: material,
        ),
      );

      // Top cap
      _triangles.add(
        Triangle3D(
          v0: topCenter,
          v1: circle1[i],
          v2: circle1[next],
          color: color,
          material: material,
        ),
      );

      // Bottom cap
      _triangles.add(
        Triangle3D(
          v0: botCenter,
          v1: circle0[next],
          v2: circle0[i],
          color: color,
          material: material,
        ),
      );
    }
  }

  /// Elliptical vessel with an actual cavity, tapered inner walls and closed base.
  /// Each ring connects to the next; no intersecting substitute solids are used.
  void addBasin({
    required Offset center,
    required double basinWidth,
    required double basinDepth,
    required double basinHeight,
    double wall = 0.025,
    double base = 0.04,
    double zBottom = 0,
    int segments = 64,
    bool rectangular = false,
    bool roundedBody = false,
    Color color = const Color(0xFFFAFAFA),
  }) {
    _validateSize([basinWidth, basinDepth, basinHeight, wall, base]);
    if (wall * 2 >= math.min(basinWidth, basinDepth) ||
        base >= basinHeight ||
        segments < 8 ||
        segments > 256) {
      throw const FormatException('Invalid basin wall, base or segment count');
    }
    final rx = basinWidth / 2;
    final ry = basinDepth / 2;
    final footprint = Rect.fromCenter(
      center: center,
      width: basinWidth,
      height: basinDepth,
    );
    _includeFootprint(
      rectangular ? (Path()..addRect(footprint)) : (Path()..addOval(footprint)),
    );
    List<Vector3> ring(double x, double y, double z) => [
      for (var i = 0; i < segments; i++)
        Vector3(
          center.dx + x * math.cos(i * 2 * math.pi / segments),
          center.dy + y * math.sin(i * 2 * math.pi / segments),
          z,
        ),
    ];
    List<Vector3> outerRing(double z) {
      if (!rectangular) return ring(rx, ry, z);
      final corners = [
        Offset(rx, 0),
        Offset(rx, ry),
        Offset(0, ry),
        Offset(-rx, ry),
        Offset(-rx, 0),
        Offset(-rx, -ry),
        Offset(0, -ry),
        Offset(rx, -ry),
        Offset(rx, 0),
      ];
      return [
        for (var i = 0; i < segments; i++)
          () {
            final t = i * 8 / segments;
            final point = Offset.lerp(
              corners[t.floor()],
              corners[t.floor() + 1],
              t - t.floor(),
            )!;
            return Vector3(center.dx + point.dx, center.dy + point.dy, z);
          }(),
      ];
    }

    final outerBottom = rectangular
        ? outerRing(zBottom)
        : ring(
            rx * (roundedBody ? .45 : .82),
            ry * (roundedBody ? .45 : .82),
            zBottom,
          );
    final outerTop = outerRing(zBottom + basinHeight);
    final innerTop = ring(rx - wall, ry - wall, zBottom + basinHeight);
    final innerBottom = ring(
      (rx - wall) * .65,
      (ry - wall) * .65,
      zBottom + base,
    );
    void triangle(Vector3 a, Vector3 b, Vector3 c) {
      _triangles.add(Triangle3D(v0: a, v1: b, v2: c, color: color));
    }

    void join(List<Vector3> a, List<Vector3> b) {
      for (var i = 0; i < segments; i++) {
        final j = (i + 1) % segments;
        triangle(a[i], a[j], b[j]);
        triangle(a[i], b[j], b[i]);
      }
    }

    if (roundedBody && !rectangular) {
      final lower = ring(rx * .75, ry * .75, zBottom + basinHeight * .25);
      final upper = ring(rx * .96, ry * .96, zBottom + basinHeight * .70);
      join(outerBottom, lower);
      join(lower, upper);
      join(upper, outerTop);
    } else {
      join(outerBottom, outerTop);
    }
    join(outerTop, innerTop);
    join(innerTop, innerBottom);
    for (var i = 0; i < segments; i++) {
      final j = (i + 1) % segments;
      triangle(
        Vector3(center.dx, center.dy, zBottom),
        outerBottom[j],
        outerBottom[i],
      );
      triangle(
        Vector3(center.dx, center.dy, zBottom + base),
        innerBottom[i],
        innerBottom[j],
      );
    }
    add2DDetailPath(
      Path()..addOval(
        Rect.fromCenter(
          center: center,
          width: basinWidth - wall * 2,
          height: basinDepth - wall * 2,
        ),
      ),
    );
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
    final defaultPath =
        _footprint ??
        (Path()..addRect(Rect.fromLTRB(-width / 2.0, 0.0, width / 2.0, depth)));
    final outline = _customOutline ?? defaultPath;
    var rect = outline.getBounds();
    for (final detail in _detailPaths) {
      rect = rect.expandToInclude(detail.getBounds());
    }

    final block = ArchitectComponentBlock2D(
      boundsMask: _customMask ?? defaultPath,
      outline: outline,
      detailPaths: List.unmodifiable(_detailPaths),
      bounds: rect,
    );

    final mesh = Mesh3D(name: name, triangles: List.unmodifiable(_triangles));

    return CachedComponentGeometry(mesh3d: mesh, block2d: block);
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

  /// Whether instances of this component are visible in building sections by default.
  /// Furniture and general sanitary items default to false; floor drains default to true.
  bool get defaultVisibleInSection => false;

  /// Schema of configurable dimensions and properties.
  List<ParametricFieldSchema> get schema;

  /// Default parameter values.
  Map<String, dynamic> get defaultParameters {
    return {for (final f in schema) f.key: f.defaultValue};
  }

  /// Synchronously generates 3D mesh and 2D CAD block from parameters.
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params);

  /// Placement resizing scales the authored object, including every detail.
  /// The native parameter values are retained for repeated edits and JSON export.
  /// This keeps a locked XYZ ratio from changing mattress/leg/wall proportions.
  CachedComponentGeometry resolveGeometry(Map<String, dynamic> params) {
    const axes = ['width', 'depth', 'height'];
    final native = {...defaultParameters, ...params};
    if (!axes.every((key) => params['_base_$key'] is num)) {
      return generateGeometry(native);
    }
    final scales = <double>[];
    for (final key in axes) {
      final original = (params['_base_$key'] as num).toDouble();
      final target = (native[key] as num).toDouble();
      if (!original.isFinite ||
          original <= 0 ||
          !target.isFinite ||
          target <= 0) {
        throw const FormatException('Invalid component scale');
      }
      native[key] = original;
      native.remove('_base_$key');
      scales.add(target / original);
    }
    final geometry = generateGeometry(native);
    final sx = scales[0], sy = scales[1], sz = scales[2];
    Vector3 point(Vector3 p) => Vector3(p.x * sx, p.y * sy, p.z * sz);
    Vector3 normal(Vector3 n) =>
        Vector3(n.x / sx, n.y / sy, n.z / sz).normalized();
    final matrix = Float64List.fromList([
      sx,
      0,
      0,
      0,
      0,
      sy,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]);
    final block = geometry.block2d;
    return CachedComponentGeometry(
      mesh3d: Mesh3D(
        name: geometry.mesh3d.name,
        triangles: [
          for (final t in geometry.mesh3d.triangles)
            Triangle3D(
              v0: point(t.v0),
              v1: point(t.v1),
              v2: point(t.v2),
              normal: normal(t.normal),
              color: t.color,
              material: t.material,
              isDoubleSided: t.isDoubleSided,
              textureCoordinates: t.textureCoordinates,
              vertexNormals: t.vertexNormals?.map(normal).toList(),
              vertexColors: t.vertexColors,
              linearVertexColors: t.linearVertexColors,
            ),
        ],
      ),
      block2d: ArchitectComponentBlock2D(
        boundsMask: block.boundsMask.transform(matrix),
        outline: block.outline.transform(matrix),
        detailPaths: [
          for (final path in block.detailPaths) path.transform(matrix),
        ],
        bounds: Rect.fromLTRB(
          block.bounds.left * sx,
          block.bounds.top * sy,
          block.bounds.right * sx,
          block.bounds.bottom * sy,
        ),
      ),
    );
  }
}
