import '../rendering/architect_vector_scene.dart';
import '../rendering/architect_opening_plan_painter.dart';
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
    this.specId = 'W1',
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
    int? panesCount,
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
    panesCount: panesCount ?? this.panesCount,
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
        specId: json['specId'] as String? ?? 'W1',
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
    bool wallGeometryProvided = false,
    double coreThickness = 0.25,
    double insulationThickness = 0.0,
    double? coreCenterShift,
    double exteriorSign = 1.0,
  }) {
    architectDrawingSources(canvas, {id}, 'opening');
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

    final effectiveStyle = resolvedStyle;
    if (effectiveStyle != null) {
      effectiveStyle.paintPlan2D(
        palette: palette,
        canvas: canvas,
        wallGeometryProvided: wallGeometryProvided,
        wallStart: wallStart,
        wallEnd: wallEnd,
        wallThickness: wallThickness,
        coreThickness: coreThickness,
        insulationThickness: insulationThickness,
        coreCenterShift: coreCenterShift,
        exteriorSign: exteriorSign,
        offsetRatio: offsetRatio,
        elementWidth: width,
        elementHeight: height,
        elementSillHeight: sillHeight,
        zoomScale: zoomScale,
        isSelected: isSelected,
        showDimensions: false,
      );
      ArchitectOpeningPlanPainter.paint(
        canvas: canvas,
        centerPos: centerPos,
        normal: n * exteriorSign,
        wallThickness: wallThickness,
        width: width,
        height: height,
        sillHeight: sillHeight,
        specId: specId,
        outsideWall: true,
        zoomScale: zoomScale,
        palette: palette,
        isSelected: isSelected,
      );
      return;
    }

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

    // 1. Cut wall opening rectangle (fill with white to mask wall fill)
    final maskHalfThick = halfThick + 1.5 / zoomScale;
    final openingPath = Path()
      ..moveTo(pLeftBase.dx - n.dx * maskHalfThick, pLeftBase.dy - n.dy * maskHalfThick)
      ..lineTo(
        pRightBase.dx - n.dx * maskHalfThick,
        pRightBase.dy - n.dy * maskHalfThick,
      )
      ..lineTo(
        pRightBase.dx + n.dx * maskHalfThick,
        pRightBase.dy + n.dy * maskHalfThick,
      )
      ..lineTo(pLeftBase.dx + n.dx * maskHalfThick, pLeftBase.dy + n.dy * maskHalfThick)
      ..close();
    if (!wallGeometryProvided) canvas.drawPath(openingPath, openingCutPaint);

    // 2. Window jamb lines
    if (!wallGeometryProvided) {
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
    }
    ArchitectOpeningPlanPainter.paintWindowSill(
      canvas: canvas,
      center: centerPos,
      direction: u,
      exteriorNormal: n * exteriorSign,
      sillHeight: sillHeight,
      width: width,
      wallThickness: wallThickness,
      zoomScale: zoomScale,
      palette: palette,
      isSelected: isSelected,
    );

    // A compact frame sits in the masonry core; its profiles do not span
    // the entire wall depth. Each closed sash has its own glazing and end caps.
    final frameDepth = math.min(.07, wallThickness);
    final shift =
        coreCenterShift ?? -(wallThickness - coreThickness) / 2 * exteriorSign;
    final frameCenter = centerPos + n * shift;
    void profile(double station, double faceWidth) {
      final point = frameCenter + u * station;
      final a = point - n * (frameDepth / 2);
      final b = point + n * (frameDepth / 2);
      final across = u * faceWidth;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo((b + across).dx, (b + across).dy)
          ..lineTo((a + across).dx, (a + across).dy)
          ..close(),
        framePaint,
      );
    }

    final face = frameThickness.clamp(.005, width / 4);
    profile(-halfW, face);
    profile(halfW - face, face);
    final count = math.max(1, panesCount);
    for (var i = 1; i < count; i++) {
      profile(-halfW + width * i / count - face / 2, face);
    }
    for (var i = 0; i < count; i++) {
      final left = -halfW + width * i / count + (i == 0 ? face : face / 2);
      final right =
          -halfW + width * (i + 1) / count - (i == count - 1 ? face : face / 2);
      if (right <= left) continue;
      ArchitectOpeningPlanPainter.paintWindowPane(
        canvas: canvas,
        left: frameCenter + u * left,
        right: frameCenter + u * right,
        direction: u,
        normal: n,
        frameDepth: frameDepth,
        glazingThickness: .024,
        openable: count > 1,
        zoomScale: zoomScale,
        palette: palette,
        isSelected: isSelected,
      );
    }

    ArchitectOpeningPlanPainter.paint(
      canvas: canvas,
      centerPos: centerPos,
      normal: n * exteriorSign,
      wallThickness: wallThickness,
      width: width,
      height: height,
      sillHeight: sillHeight,
      specId: specId,
      outsideWall: true,
      zoomScale: zoomScale,
      palette: palette,
      isSelected: isSelected,
    );
  }

  /// Returns whether [point] hits any part of this window's 2D representation:
  /// opening corridor, dimension line, or specification badge.
  bool containsPoint(
    Offset point, {
    required Offset wallStart,
    required Offset wallEnd,
    required double wallThickness,
    double tolerance = 0.15,
    double exteriorSign = 1.0,
  }) {
    final wallDelta = wallEnd - wallStart;
    final wallLen = wallDelta.distance;
    if (wallLen < 1e-4) return false;

    final centerPos = wallStart + wallDelta * offsetRatio;
    final u = wallDelta / wallLen;
    final pLeftBase = centerPos - u * (width / 2.0);
    final pRightBase = centerPos + u * (width / 2.0);

    final dOpening = _distToSegment(point, pLeftBase, pRightBase);
    if (dOpening <= (wallThickness / 2.0) + tolerance) return true;

    final n = Offset(-u.dy, u.dx) * exteriorSign;
    return ArchitectOpeningPlanPainter.containsPoint(
      point,
      center: centerPos,
      normal: n,
      wallThickness: wallThickness,
      tolerance: tolerance,
      width: width,
      height: height,
      outsideWall: true,
      sillHeight: sillHeight,
    );
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-8) return (p - a).distance;
    final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    final clampedT = t.clamp(0.0, 1.0);
    final proj = a + ab * clampedT;
    return (p - proj).distance;
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
    double? coreCenterShift,
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
        coreCenterShift: coreCenterShift,
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

    // Complete the legacy frame in elevation, including its pane divisions.
    _addBox3D(tris, lp2, rp1, rp4, lp3, zBottom, zBottom + jWidth, frameColor);
    _addBox3D(tris, lp2, rp1, rp4, lp3, zTop - jWidth, zTop, frameColor);
    for (var i = 1; i < panesCount; i++) {
      final centre = centerPos + u * (width * (i / panesCount - .5));
      final left = centre - u * (jWidth / 2), right = centre + u * (jWidth / 2);
      _addBox3D(
        tris,
        left - n * halfThick,
        right - n * halfThick,
        right + n * halfThick,
        left + n * halfThick,
        zBottom + jWidth,
        zTop - jWidth,
        frameColor,
      );
    }

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
      zBottom + jWidth,
      zTop - jWidth,
      glassColor,
    );

    // Black Rubber Glazing Gasket (черно гумено уплътнение за стъклопакета)
    const gasketColor = Color(0xFF1B1B1B);
    const gasketW = 0.008;
    const halfGasket = 0.012;
    final gLeft = centerPos - u * (halfW - jWidth);
    final gRight = centerPos + u * (halfW - jWidth);
    final gzMin = zBottom + jWidth;
    final gzMax = zTop - jWidth;

    void addGasketBox(Offset pA, Offset pB, double z1, double z2) {
      if (z2 <= z1 + 1e-4) return;
      final b1 = pA - n * halfGasket;
      final b2 = pB - n * halfGasket;
      final b3 = pB + n * halfGasket;
      final b4 = pA + n * halfGasket;
      _addBox3D(tris, b1, b2, b3, b4, z1, z2, gasketColor);
    }

    addGasketBox(gLeft, gLeft + u * gasketW, gzMin, gzMax);
    addGasketBox(gRight - u * gasketW, gRight, gzMin, gzMax);
    addGasketBox(
      gLeft + u * gasketW,
      gRight - u * gasketW,
      gzMin,
      gzMin + gasketW,
    );
    addGasketBox(
      gLeft + u * gasketW,
      gRight - u * gasketW,
      gzMax - gasketW,
      gzMax,
    );

    // Interior-facing window hinges
    final interiorDir = -exteriorSign;
    final hingePos =
        (centerPos - u * (halfW - jWidth * 0.7)) +
        n * (interiorDir * halfThick + interiorDir * 0.009);

    void addHinge(double zC) {
      const hingeR = 0.009;
      const halfH = 0.025;
      final zHMin = zC - halfH;
      final zHMax = zC + halfH;
      const segs = 8;
      final pts = List.generate(segs, (i) {
        final a = i * 2 * math.pi / segs;
        return hingePos + Offset(math.cos(a), math.sin(a)) * hingeR;
      });

      const barrelCol = Color(0xFF263238);
      const capCol = Color(0xFF37474F);

      for (var i = 0; i < segs; i++) {
        final pA = pts[i];
        final pB = pts[(i + 1) % segs];
        final vAB = Vector3(pA.dx, pA.dy, zHMin);
        final vBB = Vector3(pB.dx, pB.dy, zHMin);
        final vAT = Vector3(pA.dx, pA.dy, zHMax);
        final vBT = Vector3(pB.dx, pB.dy, zHMax);

        tris.add(Triangle3D(v0: vAB, v1: vBB, v2: vBT, color: barrelCol));
        tris.add(Triangle3D(v0: vAB, v1: vBT, v2: vAT, color: barrelCol));
      }

      final cT = Vector3(hingePos.dx, hingePos.dy, zHMax);
      final cB = Vector3(hingePos.dx, hingePos.dy, zHMin);
      for (var i = 0; i < segs; i++) {
        final pA = pts[i];
        final pB = pts[(i + 1) % segs];
        tris.add(
          Triangle3D(
            v0: cT,
            v1: Vector3(pA.dx, pA.dy, zHMax),
            v2: Vector3(pB.dx, pB.dy, zHMax),
            color: capCol,
          ),
        );
        tris.add(
          Triangle3D(
            v0: cB,
            v1: Vector3(pB.dx, pB.dy, zHMin),
            v2: Vector3(pA.dx, pA.dy, zHMin),
            color: capCol,
          ),
        );
      }
    }

    addHinge(zTop - jWidth - 0.06);
    addHinge(zBottom + jWidth + 0.06);

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
    // Close the solid so section-plane intersections form complete loops.
    tris.add(Triangle3D(v0: v1B, v1: v3B, v2: v2B, color: color));
    tris.add(Triangle3D(v0: v1B, v1: v4B, v2: v3B, color: color));
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
