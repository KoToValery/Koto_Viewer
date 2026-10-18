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

      canvas.save();
      canvas.scale(1.0 / zoomScale);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
            fontFamily: 'Roboto',
            fontSize: 11.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    canvas.restore();

    // Column designation / number label next to the column (not scaled up when zoomed out)
    if (label.isNotEmpty && zoomScale >= 8.0) {
      final double halfExtentX;
      final double halfExtentY;
      if (shape == ColumnShape.circular) {
        halfExtentX = width / 2.0;
        halfExtentY = width / 2.0;
      } else {
        final rad = rotationDeg * math.pi / 180.0;
        final cosA = math.cos(rad).abs();
        final sinA = math.sin(rad).abs();
        final halfW = width / 2.0;
        final halfD = depth / 2.0;
        halfExtentX = halfW * cosA + halfD * sinA;
        halfExtentY = halfW * sinA + halfD * cosA;
      }

      final labelPos = Offset(
        position.dx + halfExtentX + 0.04,
        position.dy - halfExtentY - 0.02,
      );

      final tpLabel = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF00E5FF)
                : palette.foreground(const Color(0xFF1A237E)),
            fontFamily: 'Roboto',
            fontSize: 11.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Bounded model height: stays crisp at close zoom, never balloons above ~0.12m upon zoom-out
      final scaleFactor = (1.0 / zoomScale).clamp(0.0, 0.12 / tpLabel.height);

      const padX = 2.5;
      const padY = 1.0;
      final bgRect = Rect.fromLTWH(
        -padX,
        -padY,
        tpLabel.width + padX * 2,
        tpLabel.height + padY * 2,
      );
      final bgRRect = RRect.fromRectAndRadius(bgRect, const Radius.circular(2.5));
      final bgPaint = Paint()
        ..color = palette.background.withValues(alpha: 0.88)
        ..style = PaintingStyle.fill;
      final tagBorderPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : palette.foreground(Colors.black38).withValues(alpha: 0.5)
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke;

      canvas.save();
      canvas.translate(labelPos.dx, labelPos.dy);
      canvas.scale(scaleFactor);
      canvas.drawRRect(bgRRect, bgPaint);
      canvas.drawRRect(bgRRect, tagBorderPaint);
      tpLabel.paint(canvas, Offset.zero);
      canvas.restore();
    }
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
