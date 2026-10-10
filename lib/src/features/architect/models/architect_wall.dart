import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_door.dart';

/// Represents an architectural parametric wall with hosted openings (doors/windows).
class ArchitectWall {
  final String id;
  final Offset startPoint;
  final Offset endPoint;
  final double thickness; // in meters (default 0.25 m = 25 cm)
  final double height; // in meters (default 2.80 m)
  final List<ArchitectDoor> doors;

  const ArchitectWall({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    this.thickness = 0.25,
    this.height = 2.80,
    this.doors = const [],
  });

  double get length => (endPoint - startPoint).distance;

  Offset get unitVector {
    final len = length;
    if (len < 1e-4) return const Offset(1, 0);
    return (endPoint - startPoint) / len;
  }

  Offset get normalVector {
    final u = unitVector;
    return Offset(-u.dy, u.dx);
  }

  /// 4 corner points of the 2D wall polygon.
  List<Offset> get polygonCorners {
    final n = normalVector * (thickness / 2.0);
    return [
      startPoint - n,
      endPoint - n,
      endPoint + n,
      startPoint + n,
    ];
  }

  ArchitectWall copyWith({
    String? id,
    Offset? startPoint,
    Offset? endPoint,
    double? thickness,
    double? height,
    List<ArchitectDoor>? doors,
  }) =>
      ArchitectWall(
        id: id ?? this.id,
        startPoint: startPoint ?? this.startPoint,
        endPoint: endPoint ?? this.endPoint,
        thickness: thickness ?? this.thickness,
        height: height ?? this.height,
        doors: doors ?? this.doors,
      );

  ArchitectWall addDoor(ArchitectDoor door) {
    return copyWith(doors: [...doors, door]);
  }

  ArchitectWall removeDoor(String doorId) {
    return copyWith(doors: doors.where((d) => d.id != doorId).toList());
  }

  /// Projects a click [point] onto the baseline, returning normalized ratio [0..1] and distance.
  (double ratio, double dist) projectPoint(Offset point) {
    final len = length;
    if (len < 1e-4) return (0.0, (point - startPoint).distance);
    final u = unitVector;
    final v = point - startPoint;
    final dot = v.dx * u.dx + v.dy * u.dy;
    final ratio = (dot / len).clamp(0.0, 1.0);
    final proj = startPoint + u * (ratio * len);
    final dist = (point - proj).distance;
    return (ratio, dist);
  }

  /// Tests if a screen/model point lies within the wall body.
  bool containsPoint(Offset point, {double tolerance = 0.10}) {
    final (ratio, dist) = projectPoint(point);
    return dist <= (thickness / 2.0 + tolerance) && ratio >= 0.0 && ratio <= 1.0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startPoint': {'x': startPoint.dx, 'y': startPoint.dy},
        'endPoint': {'x': endPoint.dx, 'y': endPoint.dy},
        'thickness': thickness,
        'height': height,
        'doors': doors.map((d) => d.toJson()).toList(),
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
        doors: (json['doors'] as List<dynamic>?)
                ?.map((d) => ArchitectDoor.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  // ===========================================================================
  // 3D SOLID WALL EXTRUSION WITH BOOLEAN CUTOUTS
  // ===========================================================================

  /// Builds solid 3D mesh triangles for the wall, splitting it around hosted doors.
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
    void addWallPrism(double startAlong, double endAlong, double zMin, double zMax) {
      if (endAlong <= startAlong + 1e-4 || zMax <= zMin + 1e-4) return;
      final a = startPoint + u * startAlong;
      final b = startPoint + u * endAlong;

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

    if (doors.isEmpty) {
      // Solid wall without any cutouts
      addWallPrism(0.0, len, zBottom, zTop);
      return tris;
    }

    // Sort doors along wall baseline
    final sortedDoors = List<ArchitectDoor>.from(doors)
      ..sort((a, b) => a.offsetRatio.compareTo(b.offsetRatio));

    double currentX = 0.0;
    for (final door in sortedDoors) {
      final doorCenter = door.offsetRatio * len;
      final doorStart = math.max(0.0, doorCenter - door.width / 2.0);
      final doorEnd = math.min(len, doorCenter + door.width / 2.0);

      // 1. Left pier (full height)
      if (doorStart > currentX) {
        addWallPrism(currentX, doorStart, zBottom, zTop);
      }

      // 2. Sill block below door (if sill > 0)
      if (door.sillHeight > 0) {
        addWallPrism(doorStart, doorEnd, zBottom, zBottom + door.sillHeight);
      }

      // 3. Lintel wall segment above door
      final doorHeadZ = zBottom + door.sillHeight + door.height;
      if (doorHeadZ < zTop) {
        addWallPrism(doorStart, doorEnd, doorHeadZ, zTop);
      }

      // 4. Add 3D elements of the door itself
      tris.addAll(door.build3D(
        wallStart: startPoint,
        wallEnd: endPoint,
        wallThickness: thickness,
        storeyElevation: storeyElevation,
      ));

      currentX = math.max(currentX, doorEnd);
    }

    // 5. Right pier (full height)
    if (currentX < len) {
      addWallPrism(currentX, len, zBottom, zTop);
    }

    return tris;
  }
}
