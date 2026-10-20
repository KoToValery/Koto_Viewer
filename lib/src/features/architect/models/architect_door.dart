import '../rendering/architect_path_solid.dart';
import '../rendering/architect_opening_plan_painter.dart';
import '../rendering/architect_canvas_palette.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_fenestration_style.dart';
import '../services/fenestration_library_service.dart';
import '../rendering/fenestration_3d_builder.dart';

/// Represents a hosted architectural door element adhering to the DXF standard.
class ArchitectDoor {
  final String id;
  final String wallId;
  /// Normalized position along the host wall baseline [0.0 .. 1.0].
  final double offsetRatio;
  final double width; // in meters (default 0.90 m = 90 cm)
  final double height; // in meters (default 2.00 m = 200 cm)
  final double sillHeight; // in meters (default 0.0 m; if >0 shows h=15 cm)
  final double frameThickness; // in meters (0.04 m = 4 cm)
  final double leafThickness; // in meters (0.04 m = 4 cm)
  final bool isHingeLeft; // true = hinge on left side of opening
  final bool openInward; // true = swing towards interior face
  final double openAngleDeg; // default 45.0° (half-open) or 90.0°
  final String specId; // Mark for schedule/table, e.g. "1" or "В1"
  final String uuid; // Unique persistent classifier identifier
  final String? styleId;
  final ArchitectFenestrationStyle? style;

  /// Effective style from direct reference, or resolved from persistent library by [styleId].
  ArchitectFenestrationStyle? get resolvedStyle =>
      style ??
      (styleId != null
          ? FenestrationLibraryService.instance.getStyleById(styleId!)
          : null);

  const ArchitectDoor({
    required this.id,
    required this.wallId,
    required this.offsetRatio,
    this.width = 0.90,
    this.height = 2.00,
    this.sillHeight = 0.0,
    this.frameThickness = 0.04,
    this.leafThickness = 0.04,
    this.isHingeLeft = true,
    this.openInward = true,
    this.openAngleDeg = 90.0,
    this.specId = '1',
    required this.uuid,
    this.styleId,
    this.style,
  });

  /// Clear passage width between jamb frames in meters.
  double get clearWidth => math.max(0.20, width - 2 * frameThickness);

  /// One hinge and leaf basis shared by the plan, picking, and solid model.
  /// Mirroring the opening side also mirrors the leaf thickness into the jamb.
  ({Offset hinge, Offset direction, Offset normal}) _leafGeometry(
    Offset left,
    Offset right,
    Offset u,
    Offset n,
    double halfWallThickness,
  ) {
    final sign = openInward ? 1.0 : -1.0;
    final hinge = (isHingeLeft
            ? left + u * frameThickness
            : right - u * frameThickness) +
        n * (sign * halfWallThickness);
    final angle = openAngleDeg * math.pi / 180;
    final rotation = math.atan2(u.dy, u.dx) +
        (isHingeLeft
            ? sign * angle
            : math.pi - sign * angle);
    final direction = Offset(math.cos(rotation), math.sin(rotation));
    final normal = Offset(-direction.dy, direction.dx) *
        (sign * (isHingeLeft ? -1 : 1));
    return (hinge: hinge, direction: direction, normal: normal);
  }

  /// Formats the parametric spec ID based on base number and hinge orientation.
  /// Left-hinged doors append a prime (') symbol to distinguish from right-hinged doors.
  static String formatSpecId({
    required int baseNumber,
    required bool isHingeLeft,
  }) {
    return isHingeLeft ? "$baseNumber'" : '$baseNumber';
  }

  /// Size key matching width, height, and sill height within millimeter precision.
  static String sizeKey({
    required double width,
    required double height,
    required double sillHeight,
  }) {
    final w = (width * 100).round();
    final h = (height * 100).round();
    final s = (sillHeight * 100).round();
    return '${w}_${h}_$s';
  }

  /// Extracts the base integer number from a specId (e.g. "1" -> 1, "1'" -> 1, "2" -> 2).
  /// Returns null if specId does not contain digits.
  static int? extractBaseNumber(String specId) {
    final match = RegExp(r'\d+').firstMatch(specId);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  /// Resolves the parametric door ID for a door specification against existing doors.
  /// Doors of identical dimensions (width, height, sillHeight) share the same base number.
  /// Left-hinged doors append a prime (') symbol to the base number.
  static String resolveSpecId({
    required Iterable<ArchitectDoor> existingDoors,
    required double width,
    required double height,
    required double sillHeight,
    required bool isHingeLeft,
  }) {
    final targetKey = sizeKey(width: width, height: height, sillHeight: sillHeight);
    int? matchedBase;
    int maxBase = 0;

    for (final door in existingDoors) {
      final base = extractBaseNumber(door.specId);
      if (base != null) {
        if (base > maxBase) {
          maxBase = base;
        }
        final dKey = sizeKey(
          width: door.width,
          height: door.height,
          sillHeight: door.sillHeight,
        );
        if (dKey == targetKey && matchedBase == null) {
          matchedBase = base;
        }
      }
    }

    final effectiveBase = matchedBase ?? (maxBase + 1);
    return formatSpecId(baseNumber: effectiveBase, isHingeLeft: isHingeLeft);
  }

  ArchitectDoor copyWith({
    String? id,
    String? wallId,
    double? offsetRatio,
    double? width,
    double? height,
    double? sillHeight,
    double? frameThickness,
    double? leafThickness,
    bool? isHingeLeft,
    bool? openInward,
    double? openAngleDeg,
    String? specId,
    String? uuid,
    String? styleId,
    ArchitectFenestrationStyle? style,
  }) =>
      ArchitectDoor(
        id: id ?? this.id,
        wallId: wallId ?? this.wallId,
        offsetRatio: offsetRatio ?? this.offsetRatio,
        width: width ?? this.width,
        height: height ?? this.height,
        sillHeight: sillHeight ?? this.sillHeight,
        frameThickness: frameThickness ?? this.frameThickness,
        leafThickness: leafThickness ?? this.leafThickness,
        isHingeLeft: isHingeLeft ?? this.isHingeLeft,
        openInward: openInward ?? this.openInward,
        openAngleDeg: openAngleDeg ?? this.openAngleDeg,
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
        'leafThickness': leafThickness,
        'isHingeLeft': isHingeLeft,
        'openInward': openInward,
        'openAngleDeg': openAngleDeg,
        'specId': specId,
        'uuid': uuid,
        if (styleId != null) 'styleId': styleId,
        if (style != null) 'style': style!.toJson(),
      };

  factory ArchitectDoor.fromJson(Map<String, dynamic> json) => ArchitectDoor(
        id: json['id'] as String,
        wallId: json['wallId'] as String,
        offsetRatio: (json['offsetRatio'] as num).toDouble(),
        width: (json['width'] as num?)?.toDouble() ?? 0.90,
        height: (json['height'] as num?)?.toDouble() ?? 2.00,
        sillHeight: (json['sillHeight'] as num?)?.toDouble() ?? 0.0,
        frameThickness: (json['frameThickness'] as num?)?.toDouble() ?? 0.04,
        leafThickness: (json['leafThickness'] as num?)?.toDouble() ?? 0.04,
        isHingeLeft: json['isHingeLeft'] as bool? ?? true,
        openInward: json['openInward'] as bool? ?? true,
        openAngleDeg: (json['openAngleDeg'] as num?)?.toDouble() ?? 90.0,
        specId: json['specId'] as String? ?? '1',
        uuid: json['uuid'] as String? ?? json['id'] as String,
        styleId: json['styleId'] as String?,
        style: json['style'] != null
            ? ArchitectFenestrationStyle.fromJson(
                json['style'] as Map<String, dynamic>)
            : null,
      );

  // ===========================================================================
  // 2D ARCHITECTURAL CANVAS RENDERING (DIRECT FROM door.dxf STANDARD)
  // ===========================================================================

  /// Renders the 2D architectural door symbol with jamb frames, 90° open leaf,
  /// dashed swing arc, central fraction dimension line (W/H, sill), and specification
  /// mark circle badge, matching door.dxf standard.
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
    final wallVec = wallEnd - wallStart;
    final wallLen = wallVec.distance;
    if (wallLen < 1e-4) return;

    final u = wallVec / wallLen; // Vector along wall baseline
    final n = Offset(-u.dy, u.dx); // Vector normal across wall thickness
    final halfThick = wallThickness / 2.0;

    // Center of door opening on baseline
    final centerPos = wallStart + u * (offsetRatio * wallLen);
    final halfW = width / 2.0;
    final pLeftBase = centerPos - u * halfW;
    final pRightBase = centerPos + u * halfW;

    // Paints
    final cutMaskPaint = Paint()
      ..color = palette.background
      ..style = PaintingStyle.fill;

    final frameStrokePaint = Paint()
      ..color = isSelected ? const Color(0xFF00E5FF) : palette.foreground(const Color(0xFF263238))
      ..strokeWidth = (isSelected ? 1.6 : 1.0) / zoomScale
      ..style = PaintingStyle.stroke;

    final wallCutEdgePaint = Paint()
      ..color = isSelected ? const Color(0xFF00E5FF) : palette.foreground(Colors.black87)
      ..strokeWidth = (isSelected ? 1.6 : 1.0) / zoomScale
      ..style = PaintingStyle.stroke;

    final leafStrokePaint = Paint()
      ..color = isSelected ? const Color(0xFF00E5FF) : palette.foreground(const Color(0xFF37474F))
      ..strokeWidth = (isSelected ? 1.6 : 1.0) / zoomScale
      ..style = PaintingStyle.stroke;

    final swingArcPaint = Paint()
      ..color = isSelected ? const Color(0xFF00E5FF) : palette.foreground(Colors.black87)
      ..strokeWidth = (isSelected ? 1.2 : 0.8) / zoomScale
      ..style = PaintingStyle.stroke;

    // 1. Cut rough wall opening through wall body (mask background)
    final openingPath = Path()
      ..moveTo(pLeftBase.dx - n.dx * (halfThick + 0.002), pLeftBase.dy - n.dy * (halfThick + 0.002))
      ..lineTo(pRightBase.dx - n.dx * (halfThick + 0.002), pRightBase.dy - n.dy * (halfThick + 0.002))
      ..lineTo(pRightBase.dx + n.dx * (halfThick + 0.002), pRightBase.dy + n.dy * (halfThick + 0.002))
      ..lineTo(pLeftBase.dx + n.dx * (halfThick + 0.002), pLeftBase.dy + n.dy * (halfThick + 0.002))
      ..close();
    if(!wallGeometryProvided)canvas.drawPath(openingPath, cutMaskPaint);

    // 2. Wall jamb cut lines (Линии на зида при светлия отвор)
    if(!wallGeometryProvided) {
    canvas.drawLine(pLeftBase - n * halfThick, pLeftBase + n * halfThick, wallCutEdgePaint);
    canvas.drawLine(pRightBase - n * halfThick, pRightBase + n * halfThick, wallCutEdgePaint);

    }
    // 3. Draw 2 Door Frame Jambs (Каси: frameThickness x wallThickness, matching door.dxf New_ramka)
    // Transparent interior, thin stroke outline only (no solid hatch)
    void drawJamb(Offset baseCorner, bool isLeft) {
      final p1 = baseCorner - n * halfThick;
      final p2 = baseCorner + n * halfThick;
      final dir = isLeft ? 1.0 : -1.0;
      final p3 = p2 + u * (dir * frameThickness);
      final p4 = p1 + u * (dir * frameThickness);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      canvas.drawPath(path, frameStrokePaint);
    }

    drawJamb(pLeftBase, true);
    drawJamb(pRightBase, false);

    // The hinge follows the selected opening face of the frame.
    final leaf = _leafGeometry(pLeftBase, pRightBase, u, n, halfThick);
    final hingePos = leaf.hinge;
    final leafLen = clearWidth;
    final leafU = leaf.direction;
    final leafN = leaf.normal;
    final angleRad = openAngleDeg * math.pi / 180.0;
    final baseAngle = math.atan2(u.dy, u.dx);

    final leafP1 = hingePos;
    final leafP2 = hingePos + leafU * leafLen;
    final leafP3 = leafP2 + leafN * leafThickness;
    final leafP4 = leafP1 + leafN * leafThickness;

    final leafPath = Path()
      ..moveTo(leafP1.dx, leafP1.dy)
      ..lineTo(leafP2.dx, leafP2.dy)
      ..lineTo(leafP3.dx, leafP3.dy)
      ..lineTo(leafP4.dx, leafP4.dy)
      ..close();

    canvas.drawPath(leafPath, leafStrokePaint);

    // 6. Dashed Swing Arc (matching door.dxf New_otvarqemost)
    final startAngle = isHingeLeft ? baseAngle : baseAngle + math.pi;
    final sweepAngle = (isHingeLeft ? 1.0 : -1.0) * (openInward ? angleRad : -angleRad);
    final totalSweep = sweepAngle.abs();
    if (totalSweep > 1e-4) {
      const stepAngle = 0.08; // ~4.5 degrees
      const dashRatio = 0.65; // 65% dash, 35% gap
      var curA = 0.0;
      final sign = sweepAngle.sign;
      while (curA < totalSweep) {
        final curSweep = math.min(stepAngle * dashRatio, totalSweep - curA);
        canvas.drawArc(
          Rect.fromCircle(center: hingePos, radius: leafLen),
          startAngle + sign * curA,
          sign * curSweep,
          false,
          swingArcPaint,
        );
        curA += stepAngle;
      }
    }

    ArchitectOpeningPlanPainter.paint(
      canvas: canvas,
      centerPos: centerPos,
      normal: n,
      wallThickness: wallThickness,
      width: width,
      height: height,
      sillHeight: sillHeight,
      specId: specId,
      zoomScale: zoomScale,
      palette: palette,
      isSelected: isSelected,
    );
  }

  /// Returns whether [point] hits any part of this door's 2D representation:
  /// opening corridor in wall, door leaf, swing arc, or ID circle badge.
  bool containsPoint(
    Offset point, {
    required Offset wallStart,
    required Offset wallEnd,
    required double wallThickness,
    double tolerance = 0.15,
  }) {
    final wallDelta = wallEnd - wallStart;
    final wallLen = wallDelta.distance;
    if (wallLen < 1e-4) return false;

    final u = wallDelta / wallLen;
    final n = Offset(-u.dy, u.dx);
    final halfThick = wallThickness / 2.0;

    final centerPos = wallStart + wallDelta * offsetRatio;
    final pLeftBase = centerPos - u * (width / 2.0);
    final pRightBase = centerPos + u * (width / 2.0);

    // 1. Opening corridor in wall
    final dOpening = _distToSegment(point, pLeftBase, pRightBase);
    if (dOpening <= halfThick + tolerance) return true;

    // Use the exact leaf and jamb dimensions that are drawn.
    final leaf = _leafGeometry(pLeftBase, pRightBase, u, n, halfThick);
    final hingePos = leaf.hinge;
    final leafEnd = hingePos + leaf.direction * clearWidth;
    if (_distToSegment(point, hingePos, leafEnd) <= tolerance + 0.06) {
      return true;
    }

    // 3. ID circle badge & dimension line
    const badgeR = 0.16;
    final extDist = halfThick + 0.22;
    final badgeCenter = centerPos + n * (extDist + badgeR);
    if ((point - badgeCenter).distance <= badgeR + tolerance) {
      return true;
    }
    final dimStart = centerPos - n * (halfThick + 0.08);
    final dimEnd = centerPos + n * extDist;
    if (_distToSegment(point, dimStart, dimEnd) <= tolerance + 0.05) {
      return true;
    }

    // 4. Swing arc bounding
    final distHinge = (point - hingePos).distance;
    if ((distHinge - clearWidth).abs() <= tolerance + 0.05) {
      return true;
    }

    return false;
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
  // 3D SOLID MESH GENERATION (TRIANGLES)
  // ===========================================================================

  /// Generates 3D mesh triangles for jamb frames, lintel, 3D door leaf,
  /// 3D door handle, and interior-facing visible 3D barrel hinges.
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
        isHingeLeft: isHingeLeft,
      );
    }

    final List<Triangle3D> tris = [];
    final wallVec = wallEnd - wallStart;
    final wallLen = wallVec.distance;
    if (wallLen < 1e-4) return tris;

    final u = wallVec / wallLen;
    final n = Offset(-u.dy, u.dx);
    final halfThick = wallThickness / 2.0;

    final centerPos = wallStart + u * (offsetRatio * wallLen);
    final halfW = width / 2.0;
    final pLeft = centerPos - u * halfW;
    final pRight = centerPos + u * halfW;

    final zBottom = storeyElevation + sillHeight;
    final zTop = zBottom + height;

    const frameColor = Color(0xFF37474F);
    const leafColor = Color(0xFF8D6E63);

    // Helper to extrude 2D box into 3D prism
    void addPrism(Offset a, Offset b, double zMin, double zMax, Color col) {
      final p1 = a - n * halfThick;
      final p2 = b - n * halfThick;
      final p3 = b + n * halfThick;
      final p4 = a + n * halfThick;

      final v1B = Vector3(p1.dx, p1.dy, zMin);
      final v2B = Vector3(p2.dx, p2.dy, zMin);
      final v3B = Vector3(p3.dx, p3.dy, zMin);
      final v4B = Vector3(p4.dx, p4.dy, zMin);

      final v1T = Vector3(p1.dx, p1.dy, zMax);
      final v2T = Vector3(p2.dx, p2.dy, zMax);
      final v3T = Vector3(p3.dx, p3.dy, zMax);
      final v4T = Vector3(p4.dx, p4.dy, zMax);

      // Sides
      tris.add(Triangle3D(v0: v1B, v1: v2B, v2: v2T, color: col));
      tris.add(Triangle3D(v0: v1B, v1: v2T, v2: v1T, color: col));

      tris.add(Triangle3D(v0: v2B, v1: v3B, v2: v3T, color: col));
      tris.add(Triangle3D(v0: v2B, v1: v3T, v2: v2T, color: col));

      tris.add(Triangle3D(v0: v3B, v1: v4B, v2: v4T, color: col));
      tris.add(Triangle3D(v0: v3B, v1: v4T, v2: v3T, color: col));

      tris.add(Triangle3D(v0: v4B, v1: v1B, v2: v1T, color: col));
      tris.add(Triangle3D(v0: v4B, v1: v1T, v2: v4T, color: col));

      // Caps
      tris.add(Triangle3D(v0: v1T, v1: v2T, v2: v3T, color: col));
      tris.add(Triangle3D(v0: v1T, v1: v3T, v2: v4T, color: col));
    }

    // 1. Left Frame Jamb (Колона 4cm)
    addPrism(pLeft, pLeft + u * frameThickness, zBottom, zTop, frameColor);

    // 2. Right Frame Jamb (Колона 4cm)
    addPrism(pRight - u * frameThickness, pRight, zBottom, zTop, frameColor);

    // 3. Top Head Jamb / Lintel (4cm)
    addPrism(pLeft + u * frameThickness, pRight - u * frameThickness,
        zTop - frameThickness, zTop, frameColor);

    // 4. 3D Door Leaf (4cm thick, swung open)
    final swingSign = openInward ? 1.0 : -1.0;
    final leaf = _leafGeometry(pLeft, pRight, u, n, halfThick);
    final hingePos = leaf.hinge;
    final leafU = leaf.direction;
    final leafN = leaf.normal;

    final leafStart = hingePos;
    final leafEnd = hingePos + leafU * clearWidth;

    // Extrude door leaf prism
    final lp1 = leafStart;
    final lp2 = leafEnd;
    final lp3 = leafEnd + leafN * leafThickness;
    final lp4 = leafStart + leafN * leafThickness;

    final lzMin = zBottom + 0.01;
    final lzMax = zTop - frameThickness - 0.01;

    tris.addAll(ArchitectPathSolid.extrude(
      Path()..addPolygon([lp1, lp2, lp3, lp4], true),
      lzMin,
      lzMax,
      leafColor,
    ));

    // 5. 3D Lever Handle on Door Leaf
    final handleStation = leafStart + leafU * (clearWidth - 0.08);
    final handleRoot = handleStation + leafN * leafThickness;
    final zHandle = zBottom + math.min(1.00, height - 0.20);
    final hp1 = handleRoot + leafN * (swingSign * 0.06);
    final hp2 = hp1 - leafU * 0.10;
    const handleColor = Color(0xFFCFD8DC);

    final hv1 = Vector3(handleRoot.dx, handleRoot.dy, zHandle - 0.012);
    final hv2 = Vector3(hp1.dx, hp1.dy, zHandle - 0.012);
    final hv3 = Vector3(hp1.dx, hp1.dy, zHandle + 0.012);
    final hv4 = Vector3(handleRoot.dx, handleRoot.dy, zHandle + 0.012);
    tris.add(Triangle3D(v0: hv1, v1: hv2, v2: hv3, color: handleColor, isDoubleSided: true));
    tris.add(Triangle3D(v0: hv1, v1: hv3, v2: hv4, color: handleColor, isDoubleSided: true));

    final hlv1 = Vector3(hp1.dx, hp1.dy, zHandle - 0.012);
    final hlv2 = Vector3(hp2.dx, hp2.dy, zHandle - 0.012);
    final hlv3 = Vector3(hp2.dx, hp2.dy, zHandle + 0.012);
    final hlv4 = Vector3(hp1.dx, hp1.dy, zHandle + 0.012);
    tris.add(Triangle3D(v0: hlv1, v1: hlv2, v2: hlv3, color: handleColor, isDoubleSided: true));
    tris.add(Triangle3D(v0: hlv1, v1: hlv3, v2: hlv4, color: handleColor, isDoubleSided: true));

    // 6. 3D Barrel Hinges visible from the interior side
    final hingeCenter = hingePos + n * (swingSign * 0.012);
    void addHingeBarrel(double zC) {
      const hingeR = 0.013;
      const halfH = 0.045;
      final zHMin = zC - halfH;
      final zHMax = zC + halfH;
      const segs = 8;
      final pts = List.generate(segs, (i) {
        final a = i * 2 * math.pi / segs;
        return hingeCenter + Offset(math.cos(a), math.sin(a)) * hingeR;
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

      final cT = Vector3(hingeCenter.dx, hingeCenter.dy, zHMax);
      final cB = Vector3(hingeCenter.dx, hingeCenter.dy, zHMin);
      for (var i = 0; i < segs; i++) {
        final pA = pts[i];
        final pB = pts[(i + 1) % segs];
        tris.add(Triangle3D(
          v0: cT,
          v1: Vector3(pA.dx, pA.dy, zHMax),
          v2: Vector3(pB.dx, pB.dy, zHMax),
          color: capCol,
        ));
        tris.add(Triangle3D(
          v0: cB,
          v1: Vector3(pB.dx, pB.dy, zHMin),
          v2: Vector3(pA.dx, pA.dy, zHMin),
          color: capCol,
        ));
      }

      // Mounting leaf plates
      final plateDir = isHingeLeft ? -u : u;
      final mp1 = hingeCenter - n * (swingSign * 0.003);
      final mp2 = hingeCenter + plateDir * 0.025;
      final mv1 = Vector3(mp1.dx, mp1.dy, zHMin + 0.01);
      final mv2 = Vector3(mp2.dx, mp2.dy, zHMin + 0.01);
      final mv3 = Vector3(mp2.dx, mp2.dy, zHMax - 0.01);
      final mv4 = Vector3(mp1.dx, mp1.dy, zHMax - 0.01);
      tris.add(Triangle3D(v0: mv1, v1: mv2, v2: mv3, color: barrelCol, isDoubleSided: true));
      tris.add(Triangle3D(v0: mv1, v1: mv3, v2: mv4, color: barrelCol, isDoubleSided: true));
    }

    addHingeBarrel(zTop - 0.22);
    addHingeBarrel(zBottom + height * 0.55);
    addHingeBarrel(zBottom + 0.25);

    // 7. Sill Block (if sill > 0)
    if (sillHeight > 0) {
      addPrism(pLeft, pRight, storeyElevation, zBottom, const Color(0xFF78909C));
    }

    return tris;
  }
}
