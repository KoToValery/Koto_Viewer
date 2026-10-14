import '../rendering/architect_canvas_palette.dart';
// === SECTION: ARCHITECTURAL WINDOW MODEL & RENDERING ===
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_fenestration_style.dart';
import '../rendering/fenestration_3d_builder.dart';
import '../services/fenestration_library_service.dart';

/// Represents a hosted architectural window element adhering to standard CAD/BIM conventions.
class ArchitectWindow {
  final String id;
  final String wallId;

  /// Normalized position along the host wall baseline [0.0 .. 1.0].
  final double offsetRatio;
  final double width; // in meters (default 1.20 m = 120 cm)
  final double height; // in meters (default 1.40 m = 140 cm)
  final double sillHeight; // in meters (парапет, default 0.85 m = 85 cm)
  final double frameThickness; // in meters (0.05 m = 5 cm)
  final int panesCount; // 1 = fixed, 2 = double casement, 3 = triple
  final String specId; // Specification tag, e.g. "П1"
  final String uuid; // Unique persistent identifier
  final String? styleId;
  final ArchitectFenestrationStyle? style;

  /// Effective style from direct reference, or resolved from persistent library by [styleId].
  ArchitectFenestrationStyle? get resolvedStyle =>
      style ??
      (styleId != null
          ? FenestrationLibraryService.instance.getStyleById(styleId!)
          : null);

  const ArchitectWindow({
    required this.id,
    required this.wallId,
    required this.offsetRatio,
    this.width = 1.20,
    this.height = 1.40,
    this.sillHeight = 0.85,
    this.frameThickness = 0.05,
    this.panesCount = 2,
    this.specId = 'П1',
    required this.uuid,
    this.styleId,
    this.style,
  });

  ArchitectWindow copyWith({
    String? id,
    String? wallId,
    double? offsetRatio,
    double? width,
    double? height,
    double? sillHeight,
    double? frameThickness,
    int panesCount = 2,
    String? specId,
    String? uuid,
    String? styleId,
    ArchitectFenestrationStyle? style,
  }) => ArchitectWindow(
    id: id ?? this.id,
    wallId: wallId ?? this.wallId,
    offsetRatio: offsetRatio ?? this.offsetRatio,
    width: width ?? this.width,
    height: height ?? this.height,
    sillHeight: sillHeight ?? this.sillHeight,
    frameThickness: frameThickness ?? this.frameThickness,
    panesCount: panesCount,
    specId: specId ?? this.specId,
    uuid: uuid ?? this.uuid,
    styleId: styleId ?? this.styleId,
    style: style ?? this.style,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'wallId': wallId,
    'offsetRatio': offsetRatio,
    'width': width,
    'height': height,
    'sillHeight': sillHeight,
    'frameThickness': frameThickness,
    'panesCount': panesCount,
    'specId': specId,
    'uuid': uuid,
    if (styleId != null) 'styleId': styleId,
    if (style != null) 'style': style!.toJson(),
  };

  factory ArchitectWindow.fromJson(Map<String, dynamic> json) =>
      ArchitectWindow(
        id: json['id'] as String,
        wallId: json['wallId'] as String,
        offsetRatio: (json['offsetRatio'] as num).toDouble(),
        width: (json['width'] as num?)?.toDouble() ?? 1.20,
        height: (json['height'] as num?)?.toDouble() ?? 1.40,
        sillHeight: (json['sillHeight'] as num?)?.toDouble() ?? 0.85,
        frameThickness: (json['frameThickness'] as num?)?.toDouble() ?? 0.05,
        panesCount: (json['panesCount'] as num?)?.toInt() ?? 2,
        specId: json['specId'] as String? ?? 'П1',
        uuid: json['uuid'] as String? ?? json['id'] as String,
        styleId: json['styleId'] as String?,
        style: json['style'] != null
            ? ArchitectFenestrationStyle.fromJson(
                json['style'] as Map<String, dynamic>,
              )
            : null,
      );

  // ===========================================================================
  // 2D CANVAS RENDERING
  // ===========================================================================

  void paint2D({
    required Canvas canvas,
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Offset wallStart,
    required Offset wallEnd,
    required double wallThickness,
    required double zoomScale,
    bool isSelected = false,
    double coreThickness = 0.25,
    double insulationThickness = 0.0,
    double exteriorSign = 1.0,
  }) {
    final effectiveStyle = resolvedStyle;
    if (effectiveStyle != null) {
      effectiveStyle.paintPlan2D(
        palette: palette,
        canvas: canvas,
        wallStart: wallStart,
        wallEnd: wallEnd,
        wallThickness: wallThickness,
        coreThickness: coreThickness,
        insulationThickness: insulationThickness,
        exteriorSign: exteriorSign,
        offsetRatio: offsetRatio,
        elementWidth: width,
        elementHeight: height,
        elementSillHeight: sillHeight,
        zoomScale: zoomScale,
        isSelected: isSelected,
      );
      return;
    }

    final wallVec = wallEnd - wallStart;
    final wallLen = wallVec.distance;
    if (wallLen < 1e-4) return;

    final u = wallVec / wallLen;
    final n = Offset(-u.dy, u.dx);

    final centerPos = wallStart + u * (offsetRatio * wallLen);
    final halfW = width / 2.0;
    final halfThick = wallThickness / 2.0;

    final pLeftBase = centerPos - u * halfW;
    final pRightBase = centerPos + u * halfW;

    // Paints
    final openingCutPaint = Paint()
      ..color = palette.background
      ..style = PaintingStyle.fill;

    final framePaint = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFF37474F))
      ..strokeWidth = (isSelected ? 2.5 : 1.5) / zoomScale
      ..style = PaintingStyle.stroke;

    final glassPaint = Paint()
      ..color = palette.foreground(const Color(0xFF0288D1))
      ..strokeWidth = 1.2 / zoomScale
      ..style = PaintingStyle.stroke;

    final sillPaint = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFF78909C))
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;

    // 1. Cut wall opening rectangle (fill with white to mask wall fill)
    final openingPath = Path()
      ..moveTo(pLeftBase.dx - n.dx * halfThick, pLeftBase.dy - n.dy * halfThick)
      ..lineTo(
        pRightBase.dx - n.dx * halfThick,
        pRightBase.dy - n.dy * halfThick,
      )
      ..lineTo(
        pRightBase.dx + n.dx * halfThick,
        pRightBase.dy + n.dy * halfThick,
      )
      ..lineTo(pLeftBase.dx + n.dx * halfThick, pLeftBase.dy + n.dy * halfThick)
      ..close();
    canvas.drawPath(openingPath, openingCutPaint);

    // 2. Window jamb lines
    canvas.drawLine(
      pLeftBase - n * halfThick,
      pLeftBase + n * halfThick,
      framePaint,
    );
    canvas.drawLine(
      pRightBase - n * halfThick,
      pRightBase + n * halfThick,
      framePaint,
    );

    // 3. Exterior Sill Line (extended 5cm past jambs)
    const sillOverhang = 0.05;
    final sillExt = halfThick + 0.03;
    final sillP1 = (pLeftBase - u * sillOverhang) + n * sillExt;
    final sillP2 = (pRightBase + u * sillOverhang) + n * sillExt;
    canvas.drawLine(sillP1, sillP2, sillPaint);

    // 4. Interior & Exterior Frame Edges
    canvas.drawLine(
      pLeftBase - n * (halfThick * 0.7),
      pRightBase - n * (halfThick * 0.7),
      framePaint,
    );
    canvas.drawLine(
      pLeftBase + n * (halfThick * 0.7),
      pRightBase + n * (halfThick * 0.7),
      framePaint,
    );

    // 5. Center Glass Lines (Glazing)
    final glassOffset = 0.02;
    canvas.drawLine(
      pLeftBase - n * glassOffset,
      pRightBase - n * glassOffset,
      glassPaint,
    );
    canvas.drawLine(
      pLeftBase + n * glassOffset,
      pRightBase + n * glassOffset,
      glassPaint,
    );

    // If multiple panes, draw mullion dividers
    if (panesCount >= 2) {
      for (int i = 1; i < panesCount; i++) {
        final ratio = i / panesCount;
        final mullionP = pLeftBase + u * (width * ratio);
        canvas.drawLine(
          mullionP - n * (halfThick * 0.7),
          mullionP + n * (halfThick * 0.7),
          framePaint,
        );
      }
    }

    // 6. Dimension Label (Width/Height) & Sill notation
    if (zoomScale > 15.0) {
      final wCm = (width * 100).round();
      final hCm = (height * 100).round();
      final sillCm = (sillHeight * 100).round();
      final text = '$wCm/$hCm\nh=$sillCm';

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF00E5FF)
                : palette.foreground(const Color(0xFF0277BD)),
            fontFamily: 'Roboto',
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      final labelPos = centerPos + n * (halfThick + 0.22);
      canvas.translate(labelPos.dx, labelPos.dy);
      // Align text orientation with wall baseline
      double angle = math.atan2(u.dy, u.dx);
      if (angle > math.pi / 2 || angle < -math.pi / 2) {
        angle += math.pi;
      }
      canvas.rotate(angle);
      canvas.scale(1.0 / zoomScale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  // ===========================================================================
  // 3D SOLID MESH
  // ===========================================================================

  List<Triangle3D> build3D({
    required Offset wallStart,
    required Offset wallEnd,
    required double wallThickness,
    required double storeyElevation,
    double coreThickness = 0.25,
    double insulationThickness = 0.0,
    double exteriorSign = 1.0,
  }) {
    final effectiveStyle = resolvedStyle;
    if (effectiveStyle != null) {
      return Fenestration3dBuilder.buildOpening3D(
        style: effectiveStyle,
        wallStart: wallStart,
        wallEnd: wallEnd,
        wallThickness: wallThickness,
        coreThickness: coreThickness,
        insulationThickness: insulationThickness,
        exteriorSign: exteriorSign,
        offsetRatio: offsetRatio,
        width: width,
        height: height,
        sillHeight: sillHeight,
        storeyElevation: storeyElevation,
      );
    }

    final List<Triangle3D> tris = [];
    final wallVec = wallEnd - wallStart;
    final wallLen = wallVec.distance;
    if (wallLen < 1e-4) return tris;

    final u = wallVec / wallLen;
    final n = Offset(-u.dy, u.dx);

    final centerPos = wallStart + u * (offsetRatio * wallLen);
    final halfW = width / 2.0;
    final halfThick = wallThickness / 2.0;

    final p1 = (centerPos - u * halfW) - n * halfThick;
    final p2 = (centerPos + u * halfW) - n * halfThick;
    final p3 = (centerPos + u * halfW) + n * halfThick;
    final p4 = (centerPos - u * halfW) + n * halfThick;

    final zBottom = storeyElevation + sillHeight;
    final zTop = zBottom + height;

    const frameColor = Color(0xFF455A64);
    const glassColor = Color(0x994FC3F7);

    // Frame Prisms (left and right jambs)
    final jWidth = frameThickness;
    final lp2 = (centerPos - u * (halfW - jWidth)) - n * halfThick;
    final lp3 = (centerPos - u * (halfW - jWidth)) + n * halfThick;

    _addBox3D(tris, p1, lp2, lp3, p4, zBottom, zTop, frameColor);

    final rp1 = (centerPos + u * (halfW - jWidth)) - n * halfThick;
    final rp4 = (centerPos + u * (halfW - jWidth)) + n * halfThick;
    _addBox3D(tris, rp1, p2, p3, rp4, zBottom, zTop, frameColor);

    // Glass pane in the center
    final gp1 = (centerPos - u * (halfW - jWidth)) - n * 0.01;
    final gp2 = (centerPos + u * (halfW - jWidth)) - n * 0.01;
    final gp3 = (centerPos + u * (halfW - jWidth)) + n * 0.01;
    final gp4 = (centerPos - u * (halfW - jWidth)) + n * 0.01;
    _addBox3D(
      tris,
      gp1,
      gp2,
      gp3,
      gp4,
      zBottom + 0.04,
      zTop - 0.04,
      glassColor,
    );

    return tris;
  }

  void _addBox3D(
    List<Triangle3D> tris,
    Offset b1,
    Offset b2,
    Offset b3,
    Offset b4,
    double zMin,
    double zMax,
    Color color,
  ) {
    final v1B = Vector3(b1.dx, b1.dy, zMin);
    final v2B = Vector3(b2.dx, b2.dy, zMin);
    final v3B = Vector3(b3.dx, b3.dy, zMin);
    final v4B = Vector3(b4.dx, b4.dy, zMin);

    final v1T = Vector3(b1.dx, b1.dy, zMax);
    final v2T = Vector3(b2.dx, b2.dy, zMax);
    final v3T = Vector3(b3.dx, b3.dy, zMax);
    final v4T = Vector3(b4.dx, b4.dy, zMax);

    // Top
    tris.add(Triangle3D(v0: v1T, v1: v2T, v2: v3T, color: color));
    tris.add(Triangle3D(v0: v1T, v1: v3T, v2: v4T, color: color));
    // Front
    tris.add(Triangle3D(v0: v1B, v1: v2B, v2: v2T, color: color));
    tris.add(Triangle3D(v0: v1B, v1: v2T, v2: v1T, color: color));
    // Back
    tris.add(Triangle3D(v0: v3B, v1: v4B, v2: v4T, color: color));
    tris.add(Triangle3D(v0: v3B, v1: v4T, v2: v3T, color: color));
    // Left
    tris.add(Triangle3D(v0: v4B, v1: v1B, v2: v1T, color: color));
    tris.add(Triangle3D(v0: v4B, v1: v1T, v2: v4T, color: color));
    // Right
    tris.add(Triangle3D(v0: v2B, v1: v3B, v2: v3T, color: color));
    tris.add(Triangle3D(v0: v2B, v1: v3T, v2: v2T, color: color));
  }
}
