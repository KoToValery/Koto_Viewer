import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_door.dart';
import 'architect_wall_type.dart';
import 'architect_window.dart';

/// Legacy left/right retain their saved physical placement.
enum WallReferenceLine { center, inner, outer, left, right }

enum WallExteriorSide { left, right }

/// The physical line picked on a source wall, rather than its saved reference.
class ArchitectWallAttachment {
  final ArchitectWall source;
  final WallReferenceLine reference;
  const ArchitectWallAttachment(this.source, this.reference);

  WallExteriorSide sideFor(
    Offset start,
    Offset end,
    double thickness,
    double insulation,
  ) {
    final delta = end - start;
    if (delta.distance < .001) return source.exteriorSide;
    final normal = Offset(-delta.dy, delta.dx) / delta.distance;
    final aligned =
        normal.dx * source.exteriorNormal.dx +
        normal.dy * source.exteriorNormal.dy;
    if (aligned.abs() > 1e-6) {
      return aligned > 0 ? WallExteriorSide.left : WallExteriorSide.right;
    }
    // At a perpendicular corner, keep the core inside the source's end cap.
    double score(WallExteriorSide side) {
      final candidate = ArchitectWall(
        id: 'attachment',
        startPoint: start,
        endPoint: end,
        thickness: thickness,
        insulationThicknessOverride: insulation,
        referenceLine: reference,
        exteriorSide: side,
      );
      final d = candidate.coreCenterStart - source.coreCenterStart;
      final along = d.dx * source.unitVector.dx + d.dy * source.unitVector.dy;
      return math.min(along, source.length - along);
    }

    return score(WallExteriorSide.left) >= score(WallExteriorSide.right)
        ? WallExteriorSide.left
        : WallExteriorSide.right;
  }
}

/// Represents an architectural parametric wall with hosted openings (doors/windows).
class ArchitectWall {
  final String id;
  final Offset startPoint;
  final Offset endPoint;
  final double thickness; // in meters (default 0.25 m = 25 cm)
  final double height; // in meters (default 2.80 m or 1.05/1.20 m for parapets)
  final WallReferenceLine referenceLine;
  final WallExteriorSide exteriorSide;
  final double? insulationThicknessOverride;
  final bool connectStart;
  final bool connectEnd;
  final String? wallTypeId;
  final ParapetFinish? parapetFinish;
  final List<ArchitectDoor> doors;
  final List<ArchitectWindow> windows;

  const ArchitectWall({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    this.thickness = 0.25,
    this.height = 2.80,
    this.referenceLine = WallReferenceLine.center,
    this.exteriorSide = WallExteriorSide.left,
    this.insulationThicknessOverride,
    this.connectStart = true,
    this.connectEnd = true,
    this.wallTypeId,
    this.parapetFinish,
    this.doors = const [],
    this.windows = const [],
  });

  bool get isParapet =>
      height < 1.50 || (wallTypeId != null && wallTypeId!.contains('parapet'));

  double get length => (endPoint - startPoint).distance;

  static final _standardInsulation = {
    for (final type in ArchitectWallType.standardCatalog())
      type.id: type.insulationThickness,
  };
  double get insulationThickness =>
      (insulationThicknessOverride ?? _standardInsulation[wallTypeId] ?? 0)
          .clamp(0.0, math.max(0.0, thickness - .001));
  double get coreThickness => thickness - insulationThickness;
  double get exteriorSign => exteriorSide == WallExteriorSide.left ? 1 : -1;
  Offset get exteriorNormal => normalVector * exteriorSign;
  Offset get coreCenterStart =>
      centerStart - exteriorNormal * insulationThickness / 2;
  Offset get coreCenterEnd =>
      centerEnd - exteriorNormal * insulationThickness / 2;

  Offset get unitVector {
    final len = length;
    if (len < 1e-4) return const Offset(1, 0);
    return (endPoint - startPoint) / len;
  }

  Offset get normalVector {
    final u = unitVector;
    return Offset(-u.dy, u.dx);
  }

  Offset get centerOffset =>
      normalVector *
      switch (referenceLine) {
        WallReferenceLine.center => exteriorSign * insulationThickness / 2,
        WallReferenceLine.inner => exteriorSign * thickness / 2,
        WallReferenceLine.outer => -exteriorSign * thickness / 2,
        WallReferenceLine.left => -thickness / 2,
        WallReferenceLine.right => thickness / 2,
      };
  Offset get centerStart => startPoint + centerOffset;
  Offset get centerEnd => endPoint + centerOffset;

  /// 4 corner points of the 2D wall polygon.
  List<Offset> get polygonCorners {
    final n = normalVector * (thickness / 2.0);
    return [centerStart - n, centerEnd - n, centerEnd + n, centerStart + n];
  }

  ArchitectWall copyWith({
    String? id,
    Offset? startPoint,
    Offset? endPoint,
    double? thickness,
    double? height,
    WallReferenceLine? referenceLine,
    WallExteriorSide? exteriorSide,
    double? insulationThicknessOverride,
    bool? connectStart,
    bool? connectEnd,
    String? wallTypeId,
    ParapetFinish? parapetFinish,
    List<ArchitectDoor>? doors,
    List<ArchitectWindow>? windows,
  }) => ArchitectWall(
    id: id ?? this.id,
    startPoint: startPoint ?? this.startPoint,
    endPoint: endPoint ?? this.endPoint,
    thickness: thickness ?? this.thickness,
    height: height ?? this.height,
    referenceLine: referenceLine ?? this.referenceLine,
    exteriorSide: exteriorSide ?? this.exteriorSide,
    insulationThicknessOverride:
        insulationThicknessOverride ?? this.insulationThicknessOverride,
    connectStart: connectStart ?? this.connectStart,
    connectEnd: connectEnd ?? this.connectEnd,
    wallTypeId: wallTypeId ?? this.wallTypeId,
    parapetFinish: parapetFinish ?? this.parapetFinish,
    doors: doors ?? this.doors,
    windows: windows ?? this.windows,
  );

  bool get isDetached => !connectStart && !connectEnd;

  bool connectsAt(Offset point) {
    if (isDetached) return false;
    final delta = point - startPoint;
    final along = delta.dx * unitVector.dx + delta.dy * unitVector.dy;
    return (along.abs() >= 1e-8 || connectStart) &&
        ((along - length).abs() >= 1e-8 || connectEnd);
  }

  List<Offset> get coreCorners {
    final n = normalVector * coreThickness / 2;
    return [
      coreCenterStart - n,
      coreCenterEnd - n,
      coreCenterEnd + n,
      coreCenterStart + n,
    ];
  }

  /// Change the material side without moving the masonry/concrete core.
  ArchitectWall mirroredAroundCore() {
    final flipped = copyWith(
      exteriorSide: exteriorSide == WallExteriorSide.left
          ? WallExteriorSide.right
          : WallExteriorSide.left,
    );
    final shift = coreCenterStart - flipped.coreCenterStart;
    return flipped.copyWith(
      startPoint: flipped.startPoint + shift,
      endPoint: flipped.endPoint + shift,
    );
  }

  ArchitectWall addDoor(ArchitectDoor door) {
    return copyWith(doors: [...doors, door]);
  }

  ArchitectWall removeDoor(String doorId) {
    return copyWith(doors: doors.where((d) => d.id != doorId).toList());
  }

  ArchitectWall addWindow(ArchitectWindow window) {
    return copyWith(windows: [...windows, window]);
  }

  ArchitectWall removeWindow(String windowId) {
    return copyWith(windows: windows.where((w) => w.id != windowId).toList());
  }

  /// Projects a click [point] onto the baseline, returning normalized ratio [0..1] and distance.
  (double ratio, double dist) projectPoint(Offset point) {
    final len = length;
    if (len < 1e-4) return (0.0, (point - startPoint).distance);
    final u = unitVector;
    final v = point - centerStart;
    final dot = v.dx * u.dx + v.dy * u.dy;
    final ratio = (dot / len).clamp(0.0, 1.0);
    final proj = centerStart + u * (ratio * len);
    final dist = (point - proj).distance;
    return (ratio, dist);
  }

  /// Tests if a screen/model point lies within the wall body.
  bool containsPoint(Offset point, {double tolerance = 0.10}) {
    final (ratio, dist) = projectPoint(point);
    return dist <= (thickness / 2.0 + tolerance) &&
        ratio >= 0.0 &&
        ratio <= 1.0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startPoint': {'x': startPoint.dx, 'y': startPoint.dy},
    'endPoint': {'x': endPoint.dx, 'y': endPoint.dy},
    'thickness': thickness,
    'height': height,
    'referenceLine': referenceLine.name,
    'exteriorSide': exteriorSide.name,
    'insulationThicknessOverride': insulationThicknessOverride,
    'connectStart': connectStart,
    'connectEnd': connectEnd,
    'wallTypeId': wallTypeId,
    'parapetFinish': parapetFinish?.name,
    'doors': doors.map((d) => d.toJson()).toList(),
    'windows': windows.map((w) => w.toJson()).toList(),
  };

  factory ArchitectWall.fromJson(Map<String, dynamic> json) => ArchitectWall(
    id: json['id'] as String,
    startPoint: Offset(
      (json['startPoint']['x'] as num).toDouble(),
      (json['startPoint']['y'] as num).toDouble(),
    ),
    endPoint: Offset(
      (json['endPoint']['x'] as num).toDouble(),
      (json['endPoint']['y'] as num).toDouble(),
    ),
    thickness: (json['thickness'] as num?)?.toDouble() ?? 0.25,
    height: (json['height'] as num?)?.toDouble() ?? 2.80,
    referenceLine: WallReferenceLine.values.firstWhere(
      (value) => value.name == json['referenceLine'],
      orElse: () => WallReferenceLine.center,
    ),
    exteriorSide: WallExteriorSide.values.firstWhere(
      (value) => value.name == json['exteriorSide'],
      orElse: () => WallExteriorSide.left,
    ),
    insulationThicknessOverride: (json['insulationThicknessOverride'] as num?)
        ?.toDouble(),
    connectStart: json['connectStart'] as bool? ?? true,
    connectEnd: json['connectEnd'] as bool? ?? true,
    wallTypeId: json['wallTypeId'] as String?,
    parapetFinish: json['parapetFinish'] != null
        ? ParapetFinish.values.firstWhere(
            (p) => p.name == json['parapetFinish'],
            orElse: () => ParapetFinish.cap,
          )
        : null,
    doors:
        (json['doors'] as List<dynamic>?)
            ?.map((d) => ArchitectDoor.fromJson(d as Map<String, dynamic>))
            .toList() ??
        const [],
    windows:
        (json['windows'] as List<dynamic>?)
            ?.map((w) => ArchitectWindow.fromJson(w as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  // ===========================================================================
  // 3D SOLID WALL EXTRUSION WITH BOOLEAN CUTOUTS
  // ===========================================================================

  /// Builds solid 3D mesh triangles for the wall, splitting it around hosted doors and windows.
  List<Triangle3D> build3D({required double storeyElevation}) {
    final List<Triangle3D> tris = [];
    final len = length;
    if (len < 1e-4) return tris;

    final u = unitVector;
    final n = normalVector;
    final halfThick = thickness / 2.0;

    const wallColor = Color(0xFFECEFF1);
    final zBottom = storeyElevation;
    final zTop = storeyElevation + height;

    // Extrude a solid rectangular prism segment between two offsets along the baseline
    void addWallPrism(
      double startAlong,
      double endAlong,
      double zMin,
      double zMax,
    ) {
      if (endAlong <= startAlong + 1e-4 || zMax <= zMin + 1e-4) return;
      final a = centerStart + u * startAlong;
      final b = centerStart + u * endAlong;

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

      // 4 Vertical sides
      tris.add(Triangle3D(v0: v1B, v1: v2B, v2: v2T, color: wallColor));
      tris.add(Triangle3D(v0: v1B, v1: v2T, v2: v1T, color: wallColor));

      tris.add(Triangle3D(v0: v2B, v1: v3B, v2: v3T, color: wallColor));
      tris.add(Triangle3D(v0: v2B, v1: v3T, v2: v2T, color: wallColor));

      tris.add(Triangle3D(v0: v3B, v1: v4B, v2: v4T, color: wallColor));
      tris.add(Triangle3D(v0: v3B, v1: v4T, v2: v3T, color: wallColor));

      tris.add(Triangle3D(v0: v4B, v1: v1B, v2: v1T, color: wallColor));
      tris.add(Triangle3D(v0: v4B, v1: v1T, v2: v4T, color: wallColor));

      // Top & Bottom caps
      tris.add(Triangle3D(v0: v1T, v1: v2T, v2: v3T, color: wallColor));
      tris.add(Triangle3D(v0: v1T, v1: v3T, v2: v4T, color: wallColor));
    }

    if (doors.isEmpty && windows.isEmpty) {
      // Solid wall without any cutouts
      addWallPrism(0.0, len, zBottom, zTop);
      return tris;
    }

    // Unified list of hosted openings (doors + windows)
    final openings =
        <
          ({
            double offsetRatio,
            double width,
            double height,
            double sillHeight,
            List<Triangle3D> Function() build3DTris,
          })
        >[];

    for (final d in doors) {
      openings.add((
        offsetRatio: d.offsetRatio,
        width: d.width,
        height: d.height,
        sillHeight: d.sillHeight,
        build3DTris: () => d.build3D(
          wallStart: centerStart,
          wallEnd: centerEnd,
          wallThickness: thickness,
          storeyElevation: storeyElevation,
        ),
      ));
    }

    for (final w in windows) {
      openings.add((
        offsetRatio: w.offsetRatio,
        width: w.width,
        height: w.height,
        sillHeight: w.sillHeight,
        build3DTris: () => w.build3D(
          wallStart: centerStart,
          wallEnd: centerEnd,
          wallThickness: thickness,
          storeyElevation: storeyElevation,
        ),
      ));
    }

    openings.sort((a, b) => a.offsetRatio.compareTo(b.offsetRatio));

    double currentX = 0.0;
    for (final op in openings) {
      final center = op.offsetRatio * len;
      final opStart = math.max(0.0, center - op.width / 2.0);
      final opEnd = math.min(len, center + op.width / 2.0);

      // 1. Left pier before opening
      if (opStart > currentX) {
        addWallPrism(currentX, opStart, zBottom, zTop);
      }

      // 2. Sill section below opening
      if (op.sillHeight > 0) {
        addWallPrism(opStart, opEnd, zBottom, zBottom + op.sillHeight);
      }

      // 3. Lintel section above opening
      final headZ = zBottom + op.sillHeight + op.height;
      if (headZ < zTop) {
        addWallPrism(opStart, opEnd, headZ, zTop);
      }

      // 4. Opening mesh elements
      tris.addAll(op.build3DTris());

      currentX = math.max(currentX, opEnd);
    }

    // 5. Right pier after last opening
    if (currentX < len) {
      addWallPrism(currentX, len, zBottom, zTop);
    }

    return tris;
  }
}
