import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';


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
    this.openAngleDeg = 45.0,
    this.specId = '1',
    required this.uuid,
  });

  /// Clear passage width between jamb frames in meters.
  double get clearWidth => math.max(0.20, width - 2 * frameThickness);

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
        openAngleDeg: (json['openAngleDeg'] as num?)?.toDouble() ?? 45.0,
        specId: json['specId'] as String? ?? '1',
        uuid: json['uuid'] as String? ?? json['id'] as String,
      );

  // ===========================================================================
  // 2D ARCHITECTURAL CANVAS RENDERING (DIRECT FROM element_vrata.dxf STANDARD)
  // ===========================================================================

  /// Renders the 2D architectural door symbol with jamb frames, leaf, swing arc,
  /// dimension label (W/H), sill height, and specification badge.
  void paint2D({
    required Canvas canvas,
    required Offset wallStart,
    required Offset wallEnd,
    required double wallThickness,
    required double zoomScale,
    bool isSelected = false,
  }) {
    final wallVec = wallEnd - wallStart;
    final wallLen = wallVec.distance;
    if (wallLen < 1e-4) return;

    final u = wallVec / wallLen; // Unit vector along wall baseline
    final n = Offset(-u.dy, u.dx); // Unit normal vector across wall thickness

    // Center of door opening on baseline
    final centerPos = wallStart + u * (offsetRatio * wallLen);
    final halfW = width / 2.0;
    final pLeftBase = centerPos - u * halfW;
    final pRightBase = centerPos + u * halfW;

    final halfThick = wallThickness / 2.0;

    // Paints
    final framePaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = isSelected ? const Color(0xFF00E5FF) : Colors.black
      ..strokeWidth = (isSelected ? 2.0 : 1.2) / zoomScale
      ..style = PaintingStyle.stroke;

    final leafPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.fill;

    final swingArcPaint = Paint()
      ..color = (isSelected ? const Color(0xFF00E5FF) : Colors.black87)
          .withValues(alpha: 0.6)
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;

    // 1. Draw 2 Door Frame Jambs (Каси: 4 cm x wallThickness)
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

      canvas.drawPath(path, framePaint);
      canvas.drawPath(path, strokePaint);
    }

    drawJamb(pLeftBase, true);
    drawJamb(pRightBase, false);

    // 2. Clear Opening & Hinge Positioning
    final hingeJambBase = isHingeLeft
        ? pLeftBase + u * frameThickness
        : pRightBase - u * frameThickness;

    final swingSign = openInward ? 1.0 : -1.0;
    final hingePos = hingeJambBase + n * (swingSign * halfThick);
    final leafLen = clearWidth;

    // 3. Door Leaf (4 cm thickness, rotated by openAngleDeg)
    final angleRad = openAngleDeg * math.pi / 180.0;
    final swingDir = isHingeLeft ? 1.0 : -1.0;

    // Compute rotated direction of the door leaf
    // Baseline angle
    final baseAngle = math.atan2(u.dy, u.dx);
    final rotAngle = baseAngle +
        (isHingeLeft ? (openInward ? angleRad : -angleRad) : (openInward ? math.pi - angleRad : math.pi + angleRad));

    final leafU = Offset(math.cos(rotAngle), math.sin(rotAngle));
    final leafN = Offset(-leafU.dy, leafU.dx) * (swingSign * swingDir);

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

    canvas.drawPath(leafPath, leafPaint);
    canvas.drawPath(leafPath, strokePaint);

    // 4. Swing Arc (Дъга на отваряемост)
    final arcRect = Rect.fromCircle(center: hingePos, radius: leafLen);
    final startAngle = isHingeLeft ? baseAngle : baseAngle + math.pi;
    final sweepAngle = (isHingeLeft ? 1.0 : -1.0) * (openInward ? angleRad : -angleRad);

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, swingArcPaint);

    // 5. Central Dimension Line & Text Tag (90/200, h=15)
    final lineStart = centerPos - n * halfThick;
    final lineEnd = centerPos + n * halfThick;
    final centerLinePaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(lineStart, lineEnd, centerLinePaint);

    // Dimension string in cm (e.g. "90 / 200")
    final wCm = (width * 100).round();
    final hCm = (height * 100).round();
    final sillCm = (sillHeight * 100).round();

    final label = sillCm > 0 ? '$wCm / $hCm\nh=$sillCm' : '$wCm / $hCm';

    canvas.save();
    canvas.translate(centerPos.dx, centerPos.dy);
    canvas.rotate(baseAngle);
    canvas.scale(1.0 / zoomScale);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(-textPainter.width / 2.0, -textPainter.height / 2.0);
    // Draw clean background pill
    final bgRect = Rect.fromLTWH(
      textOffset.dx - 3,
      textOffset.dy - 2,
      textPainter.width + 6,
      textPainter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(3.0)),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    textPainter.paint(canvas, textOffset);

    // 6. Specification Badge (Кръгче/бадж с ID "1")
    const badgeR = 8.0;
    final badgeCenter = Offset(0.0, halfThick * zoomScale + 14.0);
    canvas.drawCircle(badgeCenter, badgeR, Paint()..color = const Color(0xFFE0F7FA));
    canvas.drawCircle(
      badgeCenter,
      badgeR,
      Paint()
        ..color = const Color(0xFF00838F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final idPainter = TextPainter(
      text: TextSpan(
        text: specId,
        style: const TextStyle(
          color: Color(0xFF006064),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    idPainter.paint(
      canvas,
      badgeCenter - Offset(idPainter.width / 2.0, idPainter.height / 2.0),
    );

    canvas.restore();
  }

  // ===========================================================================
  // 3D SOLID MESH GENERATION (TRIANGLES)
  // ===========================================================================

  /// Generates 3D mesh triangles for jamb frames, lintel, and door leaf.
  List<Triangle3D> build3D({
    required Offset wallStart,
    required Offset wallEnd,
    required double wallThickness,
    required double storeyElevation,
  }) {
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

    const frameColor = Color(0xFF4E342E);
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

    // 4. 3D Door Leaf (4cm thick, half-open)
    final swingSign = openInward ? 1.0 : -1.0;
    final hingePos = (isHingeLeft
            ? pLeft + u * frameThickness
            : pRight - u * frameThickness) +
        n * (swingSign * halfThick);

    final angleRad = openAngleDeg * math.pi / 180.0;
    final baseAngle = math.atan2(u.dy, u.dx);
    final rotAngle = baseAngle +
        (isHingeLeft ? (openInward ? angleRad : -angleRad) : (openInward ? math.pi - angleRad : math.pi + angleRad));

    final leafU = Offset(math.cos(rotAngle), math.sin(rotAngle));
    final leafStart = hingePos;
    final leafEnd = hingePos + leafU * clearWidth;

    addPrism(leafStart, leafEnd, zBottom + 0.01, zTop - frameThickness - 0.01, leafColor);

    // 5. Sill Block (if sill > 0)
    if (sillHeight > 0) {
      addPrism(pLeft, pRight, storeyElevation, zBottom, const Color(0xFF78909C));
    }

    return tris;
  }
}
