// === SECTION: ARCHITECTURAL COLUMN MODEL & RENDERING ===
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';

enum ColumnShape { rectangular, circular }

/// Represents an architectural/structural column element.
class ArchitectColumn {
  final String id;
  final Offset position;
  final ColumnShape shape;
  final double width; // in meters (default 0.25 m = 25 cm)
  final double depth; // in meters (default 0.25 m = 25 cm)
  final double rotationDeg;
  final String label;

  const ArchitectColumn({
    required this.id,
    required this.position,
    this.shape = ColumnShape.rectangular,
    this.width = 0.25,
    this.depth = 0.25,
    this.rotationDeg = 0.0,
    this.label = 'К1',
  });

  ArchitectColumn copyWith({
    String? id,
    Offset? position,
    ColumnShape? shape,
    double? width,
    double? depth,
    double? rotationDeg,
    String? label,
  }) =>
      ArchitectColumn(
        id: id ?? this.id,
        position: position ?? this.position,
        shape: shape ?? this.shape,
        width: width ?? this.width,
        depth: depth ?? this.depth,
        rotationDeg: rotationDeg ?? this.rotationDeg,
        label: label ?? this.label,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': {'x': position.dx, 'y': position.dy},
    'shape': shape.name,
    'width': width,
    'depth': depth,
    'rotationDeg': rotationDeg,
    'label': label,
  };

  factory ArchitectColumn.fromJson(Map<String, dynamic> json) => ArchitectColumn(
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
    label: json['label'] as String? ?? 'К1',
  );

  bool containsPoint(Offset pt, {double tolerance = 0.10}) {
    if (shape == ColumnShape.circular) {
      final r = (width / 2.0) + tolerance;
      return (pt - position).distance <= r;
    }
    final halfW = (width / 2.0) + tolerance;
    final halfD = (depth / 2.0) + tolerance;
    final delta = pt - position;
    return delta.dx.abs() <= halfW && delta.dy.abs() <= halfD;
  }

  void paint2D({
    required Canvas canvas,
    required double zoomScale,
    bool isSelected = false,
  }) {
    final borderPaint = Paint()
      ..color = isSelected ? const Color(0xFF00E5FF) : const Color(0xFF212121)
      ..strokeWidth = (isSelected ? 2.5 : 1.5) / zoomScale
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF757575)
      ..style = PaintingStyle.fill;

    final crossPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 0.8 / zoomScale
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (rotationDeg.abs() > 1e-4) {
      canvas.rotate(rotationDeg * math.pi / 180.0);
    }

    if (shape == ColumnShape.circular) {
      final r = width / 2.0;
      canvas.drawCircle(Offset.zero, r, fillPaint);
      canvas.drawCircle(Offset.zero, r, borderPaint);

      // Center crosshair
      final crossLen = r * 0.7;
      canvas.drawLine(Offset(-crossLen, 0), Offset(crossLen, 0), crossPaint);
      canvas.drawLine(Offset(0, -crossLen), Offset(0, crossLen), crossPaint);
    } else {
      final halfW = width / 2.0;
      final halfD = depth / 2.0;
      final rect = Rect.fromLTRB(-halfW, -halfD, halfW, halfD);

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);

      // Center X diagonals or crosshair
      canvas.drawLine(Offset(-halfW, -halfD), Offset(halfW, halfD), crossPaint);
      canvas.drawLine(Offset(halfW, -halfD), Offset(-halfW, halfD), crossPaint);
    }

    // Dimension / Name label if zoomed in
    if (zoomScale > 15.0) {
      final wCm = (width * 100).round();
      final dCm = (depth * 100).round();
      final text = shape == ColumnShape.circular ? 'd=$wCm' : '$wCm/$dCm';

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
            fontSize: 7.0 / zoomScale * 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    }

    canvas.restore();
  }

  List<Triangle3D> build3D({
    required double storeyElevation,
    required double storeyHeight,
  }) {
    final List<Triangle3D> tris = [];
    final zMin = storeyElevation;
    final zMax = storeyElevation + storeyHeight;
    const colColor = Color(0xFFB0BEC5);

    if (shape == ColumnShape.circular) {
      final r = width / 2.0;
      const segments = 12;
      final topCenter = Vector3(position.dx, position.dy, zMax);
      final botCenter = Vector3(position.dx, position.dy, zMin);

      for (int i = 0; i < segments; i++) {
        final a1 = (i / segments) * 2 * math.pi;
        final a2 = ((i + 1) / segments) * 2 * math.pi;

        final p1 = Offset(position.dx + r * math.cos(a1), position.dy + r * math.sin(a1));
        final p2 = Offset(position.dx + r * math.cos(a2), position.dy + r * math.sin(a2));

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
      final p1 = position + Offset(-halfW, -halfD);
      final p2 = position + Offset(halfW, -halfD);
      final p3 = position + Offset(halfW, halfD);
      final p4 = position + Offset(-halfW, halfD);

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
