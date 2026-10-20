// === SECTION: ARCHITECT WALL OVERSHOOT DETECTOR ===

import 'dart:math' as math;
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

  /// Detects all overshoots for walls in a storey.
  static List<ArchitectWallOvershoot> detectInStorey(
    ArchitectStorey storey, {
    Set<String> ignoredIds = const {},
  }) {
    final results = <ArchitectWallOvershoot>[];
    for (final wall in storey.walls) {
      final overshoots = detectForWall(wall, storey.walls, ignoredIds: ignoredIds);
      for (final os in overshoots) {
        if (!results.any((existing) => existing.id == os.id)) {
          results.add(os);
        }
      }
    }
    return results;
  }

  /// Detects overshoots specifically for [wall] against [allWalls].
  static List<ArchitectWallOvershoot> detectForWall(
    ArchitectWall wall,
    List<ArchitectWall> allWalls, {
    Set<String> ignoredIds = const {},
  }) {
    if (wall.length < 0.20) return const [];
    final list = <ArchitectWallOvershoot>[];

    for (final other in allWalls) {
      if (other.id == wall.id || other.length < 0.20) continue;

      // Lines must not be nearly parallel.
      final cross = (wall.unitVector.dx * other.unitVector.dy -
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
      if (tOther < -other.thickness || tOther > other.length + other.thickness) {
        continue;
      }

      // Along wall, calculate physical face boundaries of other
      final denom = wall.unitVector.dx * other.normalVector.dx +
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
      final denomOther = other.unitVector.dx * wall.normalVector.dx +
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
      if (tOther < other.length) {
        final dOtherEnd = other.length - tOther;
        final protrudesOtherEnd = dOtherEnd > tMaxWall + minOvershootMeters;
        final isOtherEndOvershoot =
            wallMeetsAtAxis ? dOtherEnd >= minOvershootMeters : protrudesOtherEnd;
        if (isOtherEndOvershoot &&
            dOtherEnd <= maxOvershootMeters &&
            tOther >= math.max(0.20, dOtherEnd * 1.5)) {
          otherOvershoots = true;
          otherStart = false;
        }
      }
      if (!otherOvershoots && tOther > 0) {
        final dOtherStart = tOther;
        final remOther = other.length - tOther;
        final protrudesOtherStart = dOtherStart > -tMinWall + minOvershootMeters;
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
      if (tWall < wall.length) {
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

          if (overshootDist >= minOvershootMeters) {
            final overshoot = ArchitectWallOvershoot(
              wall: wall,
              atStart: false,
              otherWall: other,
              intersectionPoint: trimPoint,
              overshootMeters: overshootDist,
              otherAlsoOvershoots: otherOvershoots,
              otherAtStart: otherStart,
            );
            if (!ignoredIds.contains(overshoot.id)) {
              list.add(overshoot);
            }
          }
        }
      }

      // Check startPoint overshoot (tWall > 0)
      if (tWall > 0) {
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

          if (overshootDist >= minOvershootMeters) {
            final overshoot = ArchitectWallOvershoot(
              wall: wall,
              atStart: true,
              otherWall: other,
              intersectionPoint: trimPoint,
              overshootMeters: overshootDist,
              otherAlsoOvershoots: otherOvershoots,
              otherAtStart: otherStart,
            );
            if (!ignoredIds.contains(overshoot.id)) {
              list.add(overshoot);
            }
          }
        }
      }
    }

    return list;
  }

  /// Creates the batch commands to trim the wall (and paired wall if applicable) flush to intersection.
  static List<ArchitectModelCommand> createTrimCommands({
    required String storeyId,
    required ArchitectWallOvershoot overshoot,
  }) {
    final commands = <ArchitectModelCommand>[];

    // Primary wall trim
    final wall = overshoot.wall;
    final trimmedWall = overshoot.atStart
        ? wall.copyWith(startPoint: overshoot.intersectionPoint)
        : wall.copyWith(endPoint: overshoot.intersectionPoint);

    commands.add(
      UpdateArchitectWall(
        storeyId: storeyId,
        wall: trimmedWall,
        carryConnections: false,
      ),
    );

    // If other wall also overshoots at this corner (X-crossing), trim it as well
    if (overshoot.otherAlsoOvershoots && overshoot.otherAtStart != null) {
      final other = overshoot.otherWall;
      final trimmedOther = overshoot.otherAtStart!
          ? other.copyWith(startPoint: overshoot.intersectionPoint)
          : other.copyWith(endPoint: overshoot.intersectionPoint);
      commands.add(
        UpdateArchitectWall(
          storeyId: storeyId,
          wall: trimmedOther,
          carryConnections: false,
        ),
      );
    }

    return commands;
  }
}
