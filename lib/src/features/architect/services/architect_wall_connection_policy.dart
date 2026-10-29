import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_wall.dart';
import '../models/architect_project.dart';

/// Construction intent is shared by automatic detection and command execution.
class ArchitectWallConnectionPolicy {
  /// Largest physical distance from the core axis to either finish face.
  static double coreJunctionReach(ArchitectWall wall) =>
      wall.coreThickness / 2 +
      math.max(wall.exteriorBuildUp, wall.interiorBuildUp);

  /// Stable across a flip that moves the leading line but keeps the core fixed.
  static Offset? coreJunction(ArchitectWall a, ArchitectWall b) {
    if (a.isCurved || b.isCurved || a.isDetached || b.isDetached) return null;
    final u = a.unitVector, v = b.unitVector;
    final cross = u.dx * v.dy - u.dy * v.dx;
    if (cross.abs() < 1e-7) return null;
    final d = b.coreCenterStart - a.coreCenterStart;
    final s = (d.dx * v.dy - d.dy * v.dx) / cross;
    final t = (d.dx * u.dy - d.dy * u.dx) / cross;
    bool accepts(ArchitectWall w, double along, double reach) =>
        along >= -reach - .0001 &&
        along <= w.length + reach + .0001 &&
        (along > reach + .0001 || w.connectStart) &&
        (along < w.length - reach - .0001 || w.connectEnd);
    if (!accepts(a, s, coreJunctionReach(b)) ||
        !accepts(b, t, coreJunctionReach(a))) {
      return null;
    }
    return a.coreCenterStart + u * s;
  }

  static bool compatibleLogs(ArchitectWall a, ArchitectWall b) =>
      a.system.isLog &&
      b.system.isLog &&
      (a.thickness - b.thickness).abs() < 1e-6 &&
      (a.system.pitch(a.thickness) - b.system.pitch(b.thickness)).abs() <
          1e-6 &&
      (a.baseOffset - b.baseOffset).abs() < 1e-6;
  static Offset? joint(ArchitectWall a, ArchitectWall b) {
    if (a.isCurved || b.isCurved || a.isDetached || b.isDetached) return null;
    final u = a.unitVector, v = b.unitVector, cross = u.dx * v.dy - u.dy * v.dx;
    if (cross.abs() < 1e-7) return null;
    final d = b.centerStart - a.centerStart,
        s = (d.dx * v.dy - d.dy * v.dx) / cross,
        t = (d.dx * u.dy - d.dy * u.dx) / cross;
    final allowance = math.max(a.thickness, b.thickness) + .001;
    if (s < -allowance ||
        s > a.length + allowance ||
        t < -allowance ||
        t > b.length + allowance ||
        (s.abs() < allowance && !a.connectStart) ||
        ((s - a.length).abs() < allowance && !a.connectEnd) ||
        (t.abs() < allowance && !b.connectStart) ||
        ((t - b.length).abs() < allowance && !b.connectEnd)) {
      return null;
    }
    return a.centerStart + u * s;
  }

  static ArchitectStorey validateStorey(ArchitectStorey floor) {
    for (final wall in floor.walls.where((w) => w.system.isSpecial)) {
      wall.validateGeometry();
    }
    final logs = floor.walls.where((w) => w.system.isLog).toList();
    for (var i = 0; i < logs.length; i++) {
      for (final other in logs.skip(i + 1)) {
        final wall = logs[i];
        if (joint(wall, other) == null) continue;
        if (!compatibleLogs(wall, other) ||
            (wall.unitVector.dx * other.unitVector.dx +
                        wall.unitVector.dy * other.unitVector.dy)
                    .abs() >
                1e-5) {
          throw ArgumentError(
            'Connected log walls require matching diameter, course pitch and perpendicular axes',
          );
        }
      }
    }
    return floor;
  }

  static ArchitectProject validateProject(ArchitectProject project) {
    for (final floor in project.storeys) {
      validateStorey(floor);
    }
    return project;
  }

  static bool protectsLogTail(
    ArchitectWall wall,
    ArchitectWall other,
    bool atStart,
    Offset intersection,
  ) {
    if (!wall.system.isLog ||
        !other.system.isLog ||
        (wall.thickness - other.thickness).abs() > 1e-6 ||
        (wall.unitVector.dx * other.unitVector.dx +
                    wall.unitVector.dy * other.unitVector.dy)
                .abs() >
            1e-5) {
      return false;
    }
    if (!(atStart ? wall.connectStart : wall.connectEnd)) return false;
    final configured = atStart
        ? wall.systemPlacement.startTail
        : wall.systemPlacement.endTail;
    final expected =
        other.thickness / 2 +
        (configured ?? wall.thickness * wall.system.tailFactor);
    final tip = atStart ? wall.coreCenterStart : wall.coreCenterEnd;
    final along =
        (tip - intersection).dx * wall.unitVector.dx +
        (tip - intersection).dy * wall.unitVector.dy;
    return (along.abs() - expected).abs() < math.max(.001, expected * 1e-5);
  }
}
