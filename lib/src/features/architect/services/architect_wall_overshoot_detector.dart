// === SECTION: ARCHITECT WALL OVERSHOOT DETECTOR ===

import 'dart:math' as math;
import 'architect_wall_connection_policy.dart';
import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_wall_network.dart';
import 'architect_command_controller.dart';

/// Represents a detected wall overshoot (a small protruding stub past an intersecting wall).
class ArchitectWallOvershoot {
  /// The wall that has the protruding end.
  final ArchitectWall wall;

  /// True if startPoint overshoots, false if endPoint overshoots.
  final bool atStart;

  /// The other wall that was intersected.
  final ArchitectWall otherWall;

  /// The intersection point where the wall should be trimmed to.
  final Offset intersectionPoint;

  /// The overshoot distance (length of protruding stub) in meters.
  final double overshootMeters;

  /// True if the other wall also overshoots at the same intersection (an X-crossing).
  final bool otherAlsoOvershoots;

  /// If other wall also overshoots, whether its startPoint overshoots.
  final bool? otherAtStart;

  const ArchitectWallOvershoot({
    required this.wall,
    required this.atStart,
    required this.otherWall,
    required this.intersectionPoint,
    required this.overshootMeters,
    this.otherAlsoOvershoots = false,
    this.otherAtStart,
  });

  /// Overshoot distance rounded to centimeters.
  int get overshootCm => math.max(1, (overshootMeters * 100).round());

  /// Unique identifier for this overshoot occurrence.
  String get id => '${wall.id}-${atStart ? 'start' : 'end'}-${otherWall.id}';

  /// The coordinates of the protruding tip.
  Offset get stubPoint => atStart ? wall.startPoint : wall.endPoint;

  /// Midpoint of the stub segment for visual markers.
  Offset get stubMidpoint => (stubPoint + intersectionPoint) / 2;
}

class ArchitectWallOvershootDetector {
  /// Minimum overshoot distance to trigger detection (1.5 cm).
  static const double minOvershootMeters = 0.015;

  /// Maximum overshoot distance to consider an unintentional drafting error (50 cm).
  static const double maxOvershootMeters = 0.50;

  static final _cache = Expando<List<ArchitectWallOvershoot>>();

  /// Detects all overshoots for walls in a storey.
  static List<ArchitectWallOvershoot> detectInStorey(
    ArchitectStorey storey, {
    Set<String> ignoredIds = const {},
  }) {
    final results = _cache[storey.walls] ??= List.unmodifiable([
      for (final wall in storey.walls) ...detectForWall(wall, storey.walls),
    ]);
    return ignoredIds.isEmpty
        ? results
        : results.where((os) => !ignoredIds.contains(os.id)).toList();
  }

  /// Detects overshoots specifically for [wall] against [allWalls].
  static List<ArchitectWallOvershoot> detectForWall(
    ArchitectWall wall,
    List<ArchitectWall> allWalls, {
    Set<String> ignoredIds = const {},
  }) {
    if (wall.isCurved || wall.isDetached || wall.length < 0.20) return const [];
    final list = <ArchitectWallOvershoot>[];

    for (final other in allWalls) {
      if (other.id == wall.id ||
          other.isCurved ||
          other.isDetached ||
          other.length < 0.20) {
        continue;
      }

      // Lines must not be nearly parallel.
      final cross =
          (wall.unitVector.dx * other.unitVector.dy -
                  wall.unitVector.dy * other.unitVector.dx)
              .abs();
      if (cross < 0.20) continue; // angle < ~11.5 deg

      final pInt = ArchitectWallNetwork.intersection(
        wall.startPoint,
        wall.endPoint,
        other.startPoint,
        other.endPoint,
      );
      if (pInt == null) continue;

      // Check whether pInt lies along otherWall (allowing for wall thickness tolerance).
      final dOther = pInt - other.startPoint;
      final tOther =
          dOther.dx * other.unitVector.dx + dOther.dy * other.unitVector.dy;
      if (tOther < -other.thickness ||
          tOther > other.length + other.thickness) {
        continue;
      }

      // Along wall, calculate physical face boundaries of other
      final denom =
          wall.unitVector.dx * other.normalVector.dx +
          wall.unitVector.dy * other.normalVector.dy;
      if (denom.abs() < 1e-4) continue;

      final lowOther = other.centerLineOffset - other.thickness / 2;
      final highOther = other.centerLineOffset + other.thickness / 2;
      final t1 = lowOther / denom;
      final t2 = highOther / denom;
      final tMinOther = math.min(t1, t2);
      final tMaxOther = math.max(t1, t2);

      // Check whether other terminates at axis (corner vertex) or crosses/stops short
      final distToOtherEnd = math.min(
        (other.startPoint - pInt).distance,
        (other.endPoint - pInt).distance,
      );
      final otherMeetsAtAxis = distToOtherEnd < 0.02;

      // Along other, calculate physical face boundaries of wall
      final denomOther =
          other.unitVector.dx * wall.normalVector.dx +
          other.unitVector.dy * wall.normalVector.dy;
      double tMinWall = 0, tMaxWall = 0;
      if (denomOther.abs() >= 1e-4) {
        final lowWall = wall.centerLineOffset - wall.thickness / 2;
        final highWall = wall.centerLineOffset + wall.thickness / 2;
        final tw1 = lowWall / denomOther;
        final tw2 = highWall / denomOther;
        tMinWall = math.min(tw1, tw2);
        tMaxWall = math.max(tw1, tw2);
      }
      final distToWallEnd = math.min(
        (wall.startPoint - pInt).distance,
        (wall.endPoint - pInt).distance,
      );
      final wallMeetsAtAxis = distToWallEnd < 0.02;

      // Check if other wall also overshoots at this intersection
      bool otherOvershoots = false;
      bool? otherStart;
      if (other.connectEnd && tOther < other.length) {
        final dOtherEnd = other.length - tOther;
        final protrudesOtherEnd = dOtherEnd > tMaxWall + minOvershootMeters;
        final isOtherEndOvershoot = wallMeetsAtAxis
            ? dOtherEnd >= minOvershootMeters
            : protrudesOtherEnd;
        if (isOtherEndOvershoot &&
            dOtherEnd <= maxOvershootMeters &&
            tOther >= math.max(0.20, dOtherEnd * 1.5)) {
          otherOvershoots = true;
          otherStart = false;
        }
      }
      if (!otherOvershoots && other.connectStart && tOther > 0) {
        final dOtherStart = tOther;
        final remOther = other.length - tOther;
        final protrudesOtherStart =
            dOtherStart > -tMinWall + minOvershootMeters;
        final isOtherStartOvershoot = wallMeetsAtAxis
            ? dOtherStart >= minOvershootMeters
            : protrudesOtherStart;
        if (isOtherStartOvershoot &&
            dOtherStart <= maxOvershootMeters &&
            remOther >= math.max(0.20, dOtherStart * 1.5)) {
          otherOvershoots = true;
          otherStart = true;
        }
      }

      // Check along this wall.
      final dWall = pInt - wall.startPoint;
      final tWall =
          dWall.dx * wall.unitVector.dx + dWall.dy * wall.unitVector.dy;

      // Check endPoint overshoot (tWall < wall.length)
      if (wall.connectEnd && tWall < wall.length) {
        final deltaEnd = wall.length - tWall;
        final protrudesPastFace = deltaEnd > tMaxOther + minOvershootMeters;
        final isOvershoot = (otherMeetsAtAxis || otherOvershoots)
            ? deltaEnd >= minOvershootMeters
            : protrudesPastFace;

        if (isOvershoot &&
            deltaEnd <= maxOvershootMeters &&
            tWall >= math.max(0.20, deltaEnd * 1.5)) {
          final trimPoint = (otherMeetsAtAxis || otherOvershoots)
              ? pInt
              : pInt + wall.unitVector * tMaxOther;
          final overshootDist = (otherMeetsAtAxis || otherOvershoots)
              ? deltaEnd
              : (deltaEnd - tMaxOther);

          if (overshootDist >= minOvershootMeters &&
              !ArchitectWallConnectionPolicy.protectsLogTail(
                wall,
                other,
                false,
                pInt,
              )) {
            final overshoot = ArchitectWallOvershoot(
              wall: wall,
              atStart: false,
              otherWall: other,
              intersectionPoint: trimPoint,
              overshootMeters: overshootDist,
              otherAlsoOvershoots: otherOvershoots,
              otherAtStart: otherStart,
            );
            if (!ignoredIds.contains(overshoot.id) &&
                isSafe(overshoot, allWalls)) {
              list.add(overshoot);
            }
          }
        }
      }

      // Check startPoint overshoot (tWall > 0)
      if (wall.connectStart && tWall > 0) {
        final deltaStart = tWall;
        final faceDist = -tMinOther;
        final protrudesPastFace = deltaStart > faceDist + minOvershootMeters;
        final isOvershoot = (otherMeetsAtAxis || otherOvershoots)
            ? deltaStart >= minOvershootMeters
            : protrudesPastFace;

        final remaining = wall.length - deltaStart;
        if (isOvershoot &&
            deltaStart <= maxOvershootMeters &&
            remaining >= math.max(0.20, deltaStart * 1.5)) {
          final trimPoint = (otherMeetsAtAxis || otherOvershoots)
              ? pInt
              : pInt + wall.unitVector * tMinOther;
          final overshootDist = (otherMeetsAtAxis || otherOvershoots)
              ? deltaStart
              : (deltaStart - faceDist);

          if (overshootDist >= minOvershootMeters &&
              !ArchitectWallConnectionPolicy.protectsLogTail(
                wall,
                other,
                true,
                pInt,
              )) {
            final overshoot = ArchitectWallOvershoot(
              wall: wall,
              atStart: true,
              otherWall: other,
              intersectionPoint: trimPoint,
              overshootMeters: overshootDist,
              otherAlsoOvershoots: otherOvershoots,
              otherAtStart: otherStart,
            );
            if (!ignoredIds.contains(overshoot.id) &&
                isSafe(overshoot, allWalls)) {
              list.add(overshoot);
            }
          }
        }
      }
    }

    return list;
  }

  /// A real contact, respecting detached ends and the physical finished faces.
  static bool hasContact(ArchitectWall a, ArchitectWall b) {
    if (a.isDetached || b.isDetached) return false;
    bool accepts(ArchitectWall w, Offset p) {
      final (ratio, distance) = w.projectPoint(p);
      final along = ratio * w.length;
      return distance <= w.thickness / 2 + .0001 &&
          along >= -.0001 &&
          along <= w.length + .0001 &&
          (along > .0001 || w.connectStart) &&
          (w.length - along > .0001 || w.connectEnd);
    }

    for (final node in a.intersections(b)) {
      if (accepts(a, node) && accepts(b, node)) return true;
    }
    for (final (host, other) in [(a, b), (b, a)]) {
      for (final (enabled, points) in [
        (
          host.connectStart,
          [host.startPoint, host.centerStart, host.coreCenterStart],
        ),
        (host.connectEnd, [host.endPoint, host.centerEnd, host.coreCenterEnd]),
      ]) {
        if (enabled && points.any((p) => accepts(other, p))) return true;
      }
    }
    return false;
  }

  static Map<String, ArchitectWall>? _trimmed(ArchitectWallOvershoot os) {
    final result = <String, ArchitectWall>{};
    bool trim(ArchitectWall w, bool atStart) {
      if (!(atStart ? w.connectStart : w.connectEnd) ||
          ArchitectWallConnectionPolicy.protectsLogTail(
            w,
            w.id == os.wall.id ? os.otherWall : os.wall,
            atStart,
            os.intersectionPoint,
          )) {
        return false;
      }
      final point = os.intersectionPoint;
      final shift = atStart ? (point - w.startPoint).distance : 0.0;
      final next = atStart
          ? w.copyWith(startPoint: point)
          : w.copyWith(endPoint: point);
      if (next.length < .001 || next.length >= w.length) return false;
      double? ratio(double old, double width) {
        final along = old * w.length - shift;
        final half = w.openingArcSpan(width) / 2;
        if (along - half < -.0001 || along + half > next.length + .0001) {
          return null;
        }
        return along / next.length;
      }

      for (final opening in [
        ...w.doors.map((o) => (o.offsetRatio, o.width)),
        ...w.windows.map((o) => (o.offsetRatio, o.width)),
      ]) {
        if (ratio(opening.$1, opening.$2) == null) return false;
      }
      result[w.id] = next.copyWith(
        doors: [
          for (final d in w.doors)
            d.copyWith(offsetRatio: ratio(d.offsetRatio, d.width)!),
        ],
        windows: [
          for (final o in w.windows)
            o.copyWith(offsetRatio: ratio(o.offsetRatio, o.width)!),
        ],
      );
      return true;
    }

    if (!trim(os.wall, os.atStart)) return null;
    if (os.otherAlsoOvershoots &&
        os.otherAtStart != null &&
        !trim(os.otherWall, os.otherAtStart!)) {
      return null;
    }
    return result;
  }

  /// Test the whole proposed result; a short tail may support an existing return.
  static bool isSafe(ArchitectWallOvershoot os, List<ArchitectWall> walls) {
    final next = _trimmed(os);
    if (next == null ||
        !hasContact(next[os.wall.id]!, next[os.otherWall.id] ?? os.otherWall)) {
      return false;
    }
    for (final old in [
      os.wall,
      if (next.containsKey(os.otherWall.id)) os.otherWall,
    ]) {
      for (final other in walls) {
        if (other.id == old.id) continue;
        if (hasContact(old, other) &&
            !hasContact(next[old.id]!, next[other.id] ?? other)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Kept as a list for existing callers; the complete trim is one atomic command.
  static List<ArchitectModelCommand> createTrimCommands({
    required String storeyId,
    required ArchitectWallOvershoot overshoot,
  }) => _trimmed(overshoot) == null
      ? const []
      : [TrimArchitectWallOvershoot(storeyId: storeyId, overshoot: overshoot)];
}

/// Re-resolves the suggestion against the current storey before changing anything.
class TrimArchitectWallOvershoot extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectWallOvershoot overshoot;
  const TrimArchitectWallOvershoot({
    required this.storeyId,
    required this.overshoot,
  });

  @override
  ArchitectProject apply(ArchitectProject project) {
    final storey = ArchitectModelCommand.storey(project, storeyId);
    final wall = storey.walls
        .where((w) => w.id == overshoot.wall.id)
        .firstOrNull;
    if (wall == null) return project;
    final current =
        ArchitectWallOvershootDetector.detectForWall(wall, storey.walls)
            .where(
              (os) =>
                  os.id == overshoot.id &&
                  (os.stubPoint - overshoot.stubPoint).distance < .000001 &&
                  (os.intersectionPoint - overshoot.intersectionPoint)
                          .distance <
                      .000001,
            )
            .firstOrNull;
    if (current == null) return project;
    final next = ArchitectWallOvershootDetector._trimmed(current)!;
    for (final w in next.values) {
      w.validateGeometry();
    }
    return ArchitectModelCommand.replace(
      project,
      storey.copyWith(walls: [for (final w in storey.walls) next[w.id] ?? w]),
    );
  }
}
