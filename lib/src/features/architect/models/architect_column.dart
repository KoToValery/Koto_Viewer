import 'architect_document.dart';
import '../rendering/architect_vector_scene.dart';
import '../rendering/architect_canvas_palette.dart';
// === SECTION: ARCHITECTURAL COLUMN MODEL & RENDERING ===
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_elements.dart' show ArchitectCutDisplayMode;

enum ColumnShape { rectangular, circular }

/// Represents an architectural/structural column element.
class ArchitectColumn {
  final String id;
  final Offset position;
  final ColumnShape shape;
  final double width; // in meters (default 0.25 m = 25 cm)
  final double depth; // in meters (default 0.25 m = 25 cm)
  final double rotationDeg;
  final double? height;
  final double
  baseOffset; // in meters relative to storey elevation (default 0.0 m)
  final ArchitectCutDisplayMode cutDisplayMode;
  final String label;

  const ArchitectColumn({
    required this.id,
    required this.position,
    this.shape = ColumnShape.rectangular,
    this.width = 0.25,
    this.depth = 0.25,
    this.rotationDeg = 0.0,
    this.height,
    this.baseOffset = 0.0,
    this.cutDisplayMode = ArchitectCutDisplayMode.auto,
    this.label = 'C1',
  });

  bool isCutAt(double storeyCutPlane, [double defaultHeight = 2.80]) {
    return switch (cutDisplayMode) {
      ArchitectCutDisplayMode.cut => true,
      ArchitectCutDisplayMode.projected => false,
      ArchitectCutDisplayMode.overhead => false,
      ArchitectCutDisplayMode.auto => () {
        final colHeight = height ?? defaultHeight;
        final zLow = baseOffset;
        final zHigh = baseOffset + colHeight;
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

  ArchitectColumn copyWith({
    String? id,
    Offset? position,
    ColumnShape? shape,
    double? width,
    double? depth,
    double? rotationDeg,
    double? height,
    double? baseOffset,
    ArchitectCutDisplayMode? cutDisplayMode,
    String? label,
  }) => ArchitectColumn(
    id: id ?? this.id,
    position: position ?? this.position,
    shape: shape ?? this.shape,
    width: width ?? this.width,
    depth: depth ?? this.depth,
    rotationDeg: rotationDeg ?? this.rotationDeg,
    height: height ?? this.height,
    baseOffset: baseOffset ?? this.baseOffset,
    cutDisplayMode: cutDisplayMode ?? this.cutDisplayMode,
    label: label ?? this.label,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': {'x': position.dx, 'y': position.dy},
    'shape': shape.name,
    'width': width,
    'depth': depth,
    'rotationDeg': rotationDeg,
    'height': height,
    'baseOffset': baseOffset,
    'cutDisplayMode': cutDisplayMode.name,
    'label': label,
  };

  factory ArchitectColumn.fromJson(Map<String, dynamic> json) =>
      ArchitectColumn(
        id: json['id'] as String,
        position: Offset(
          (json['position']['x'] as num).toDouble(),
          (json['position']['y'] as num).toDouble(),
        ),
        shape: ColumnShape.values.firstWhere(
          (s) => s.name == json['shape'],
          orElse: () => ColumnShape.rectangular,
        ),
        width: (json['width'] as num?)?.toDouble() ?? 0.25,
        depth: (json['depth'] as num?)?.toDouble() ?? 0.25,
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0.0,
        height: (json['height'] as num?)?.toDouble(),
        baseOffset: (json['baseOffset'] as num?)?.toDouble() ?? 0.0,
        cutDisplayMode: ArchitectCutDisplayMode.fromName(
          json['cutDisplayMode'] as String?,
        ),
        label: json['label'] as String? ?? 'C1',
      );

  bool containsPoint(Offset pt, {double tolerance = 0.10}) {
    if (shape == ColumnShape.circular) {
      final r = (width / 2.0) + tolerance;
      return (pt - position).distance <= r;
    }
    final halfW = (width / 2.0) + tolerance;
    final halfD = (depth / 2.0) + tolerance;
    final v = pt - position;
    final angle = rotationDeg * math.pi / 180;
    final delta = Offset(
      v.dx * math.cos(angle) + v.dy * math.sin(angle),
      -v.dx * math.sin(angle) + v.dy * math.cos(angle),
    );
    return delta.dx.abs() <= halfW && delta.dy.abs() <= halfD;
  }

  void paint2D({
    required Canvas canvas,
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required double zoomScale,
    bool isSelected = false,
    double cutPlaneHeight = 1.20,
    double defaultStoreyHeight = 2.80,
  }) {
    architectDrawingSources(canvas, {id}, 'column');
    final isCut = isCutAt(cutPlaneHeight, defaultStoreyHeight);
    final strokeWidth = isSelected
        ? 2.5
        : (isCut
              ? ArchitectLineWeights.cutHeavy
              : ArchitectLineWeights.projection);

    final borderPaint = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFF212121))
      ..strokeWidth = strokeWidth / zoomScale
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (rotationDeg.abs() > 1e-4) {
      canvas.rotate(rotationDeg * math.pi / 180.0);
    }

    final columnDepth = shape == ColumnShape.circular ? width : depth;
    if (shape == ColumnShape.circular) {
      canvas.drawCircle(Offset.zero, width / 2, borderPaint);
    } else {
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: width,
        height: depth,
      );
      canvas.drawRect(rect, borderPaint);
    }

    // Measure in model metres. Both texts zoom with the drawing, while the
    // designation shrinks to fit even narrow columns and long custom names.
    final scope = ArchitectTextScope.current;
    final fontSize =
        scope?.fontSize(id, ArchitectAnnotationRole.ordinary) ??
        11 * ArchitectPaperStyle.annotationScale;
    ArchitectTextPainter lettering(String text, ArchitectAnnotationRole role) =>
        ArchitectTextPainter(
          elementId: id,
          role: role,
          modelScale: scope == null ? 1 : scope.fontSize(id, role) / fontSize,
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: palette.foreground(ArchitectPaperStyle.ink),
              fontFamily: 'Roboto',
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    final designation = lettering(label, ArchitectAnnotationRole.ordinary);
    // An inscribed rectangle keeps every text corner inside circular columns.
    final inset = shape == ColumnShape.circular ? .64 : .80;
    final fit = math.min(
      1.0,
      math.min(
        width * inset / math.max(designation.width, .0001),
        columnDepth * inset / math.max(designation.height, .0001),
      ),
    );
    if (label.isNotEmpty) {
      canvas.save();
      canvas.scale(fit);
      designation.paint(
        canvas,
        Offset(-designation.width / 2, -designation.height / 2),
      );
      canvas.restore();
    }

    final w = scope?.number(width) ?? (width * 100).round().toString();
    final d = scope?.number(depth) ?? (depth * 100).round().toString();
    final dimension = lettering(
      shape == ColumnShape.circular ? 'd=$w' : '$w/$d',
      ArchitectAnnotationRole.dimension,
    );
    canvas.save();
    canvas.translate(width / 2 + fontSize * fit * .4, 0);
    canvas.scale(fit);
    final dimensionOffset = Offset(0, -dimension.height / 2);
    dimension.paint(canvas, dimensionOffset);
    canvas.restore();
    canvas.restore();
  }

  List<Triangle3D> build3D({
    required double storeyElevation,
    required double storeyHeight,
  }) {
    final List<Triangle3D> tris = [];
    final zMin = storeyElevation + baseOffset;
    final zMax = zMin + (height ?? storeyHeight);
    const colColor = Color(0xFFB0BEC5);

    if (shape == ColumnShape.circular) {
      final r = width / 2.0;
      const segments = 12;
      final topCenter = Vector3(position.dx, position.dy, zMax);
      final botCenter = Vector3(position.dx, position.dy, zMin);

      for (int i = 0; i < segments; i++) {
        final a1 = (i / segments) * 2 * math.pi;
        final a2 = ((i + 1) / segments) * 2 * math.pi;

        final p1 = Offset(
          position.dx + r * math.cos(a1),
          position.dy + r * math.sin(a1),
        );
        final p2 = Offset(
          position.dx + r * math.cos(a2),
          position.dy + r * math.sin(a2),
        );

        final v1B = Vector3(p1.dx, p1.dy, zMin);
        final v2B = Vector3(p2.dx, p2.dy, zMin);
        final v1T = Vector3(p1.dx, p1.dy, zMax);
        final v2T = Vector3(p2.dx, p2.dy, zMax);

        // Sides
        tris.add(Triangle3D(v0: v1B, v1: v2B, v2: v2T, color: colColor));
        tris.add(Triangle3D(v0: v1B, v1: v2T, v2: v1T, color: colColor));
        // Top & Bottom caps
        tris.add(Triangle3D(v0: topCenter, v1: v1T, v2: v2T, color: colColor));
        tris.add(Triangle3D(v0: botCenter, v1: v2B, v2: v1B, color: colColor));
      }
    } else {
      final halfW = width / 2.0;
      final halfD = depth / 2.0;
      final angle = rotationDeg * math.pi / 180;
      Offset corner(double x, double y) =>
          position +
          Offset(
            x * math.cos(angle) - y * math.sin(angle),
            x * math.sin(angle) + y * math.cos(angle),
          );
      final p1 = corner(-halfW, -halfD);
      final p2 = corner(halfW, -halfD);
      final p3 = corner(halfW, halfD);
      final p4 = corner(-halfW, halfD);

      final v1B = Vector3(p1.dx, p1.dy, zMin);
      final v2B = Vector3(p2.dx, p2.dy, zMin);
      final v3B = Vector3(p3.dx, p3.dy, zMin);
      final v4B = Vector3(p4.dx, p4.dy, zMin);

      final v1T = Vector3(p1.dx, p1.dy, zMax);
      final v2T = Vector3(p2.dx, p2.dy, zMax);
      final v3T = Vector3(p3.dx, p3.dy, zMax);
      final v4T = Vector3(p4.dx, p4.dy, zMax);

      // Sides
      tris.add(Triangle3D(v0: v1B, v1: v2B, v2: v2T, color: colColor));
      tris.add(Triangle3D(v0: v1B, v1: v2T, v2: v1T, color: colColor));
      tris.add(Triangle3D(v0: v2B, v1: v3B, v2: v3T, color: colColor));
      tris.add(Triangle3D(v0: v2B, v1: v3T, v2: v2T, color: colColor));
      tris.add(Triangle3D(v0: v3B, v1: v4B, v2: v4T, color: colColor));
      tris.add(Triangle3D(v0: v3B, v1: v4T, v2: v3T, color: colColor));
      tris.add(Triangle3D(v0: v4B, v1: v1B, v2: v1T, color: colColor));
      tris.add(Triangle3D(v0: v4B, v1: v1T, v2: v4T, color: colColor));

      // Caps
      tris.add(Triangle3D(v0: v1T, v1: v2T, v2: v3T, color: colColor));
      tris.add(Triangle3D(v0: v1T, v1: v3T, v2: v4T, color: colColor));
      tris.add(Triangle3D(v0: v1B, v1: v3B, v2: v2B, color: colColor));
      tris.add(Triangle3D(v0: v1B, v1: v4B, v2: v3B, color: colColor));
    }

    return tris;
  }
}
