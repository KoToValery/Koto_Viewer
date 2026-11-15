import 'dart:math' as math;
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_command_controller.dart';
import 'architect_stair_layout_resolver.dart';
import 'architect_stair_headroom.dart';

enum StairCheckState { pass, error, advice, review }

enum StairCheckKind {
  width,
  riser,
  going,
  slope,
  landing,
  flightRise,
  innerGoing30,
  innerGoing,
  innerDiameter,
  comfort,
  evacuation,
  capacity,
  headroom,
  handrails,
  finishes,
  accessibility,
  scope,
  version,
  upperStorey,
  groupSteps,
  layout,
}

class StairCheck {
  final StairCheckKind kind;
  final StairCheckState state;
  final double? actual, minimum, maximum;
  final String? article;
  const StairCheck(
    this.kind,
    this.state, {
    this.actual,
    this.minimum,
    this.maximum,
    this.article,
  });
}

/// Explicit, scoped geometric checks, never a whole-building certificate.
/// Informative geometric and ergonomic stair checks, never blocking edits.
class ArchitectStairRules {
  static List<StairCheck> check(
    ArchitectStair stair, {
    ArchitectProject? project,
    ArchitectStorey? storey,
  }) {
    final d = stair.design;
    if (d == null) {
      return [const StairCheck(StairCheckKind.scope, StairCheckState.review)];
    }
    final result = <StairCheck>[];
    final width = d.layout == null
        ? stair.width
        : d.layout!.flights.map((f) => f.width).reduce(math.min);
    final landingDepth = d.layout == null
        ? math.max(stair.width, d.landingDepth)
        : ArchitectStairLayoutResolver.landingDepth(d);
    final layoutIssues = ArchitectStairLayoutResolver.check(d);
    if (layoutIssues.isNotEmpty) {
      result.add(
        const StairCheck(StairCheckKind.layout, StairCheckState.error),
      );
    }
    final measuredHeadroom =
        project != null && storey != null && d.layout != null
        ? ArchitectStairHeadroom.minimum(project, storey, stair)
        : null;
    void range(
      StairCheckKind kind,
      double actual, {
      double? min,
      double? max,
      String? article,
      bool advisory = true,
    }) {
      final ok =
          (min == null || actual >= min - 1e-9) &&
          (max == null || actual <= max + 1e-9);
      result.add(
        StairCheck(
          kind,
          ok
              ? StairCheckState.pass
              : advisory
              ? StairCheckState.advice
              : StairCheckState.error,
          actual: actual,
          minimum: min,
          maximum: max,
          article: article,
        ),
      );
    }

    final walkGoing = d.walkingGoing(stair.width);
    range(
      StairCheckKind.comfort,
      2 * d.riser + walkGoing,
      min: .60,
      max: .64,
      article: '2h + b',
    );
    range(StairCheckKind.width, width, min: .90);
    range(StairCheckKind.riser, d.riser, min: .12, max: .18);
    if (!d.isSpiral) {
      range(StairCheckKind.going, walkGoing, min: .25, max: .35);
      range(StairCheckKind.slope, d.riser / walkGoing, max: 1 / 1.5);
    }
    if (d.hasWinders) {
      final winderWalk = d.winderGoingAt(stair.width, stair.width / 2);
      range(StairCheckKind.going, winderWalk, min: .25, max: .35);
      range(StairCheckKind.slope, d.riser / winderWalk, max: 1 / 1.5);
      range(
        StairCheckKind.innerGoing30,
        d.winderGoingAt(stair.width, .30),
        min: .23,
      );
      range(
        StairCheckKind.innerGoing,
        d.winderGoingAt(stair.width, 0),
        min: .05,
      );
    }
    if (d.isSpiral) {
      range(StairCheckKind.innerGoing30, d.goingAt30, min: .23);
      range(StairCheckKind.innerGoing, d.innerGoing, min: .10);
    }
    if (!d.isSpiral && d.flightCount > 1) {
      if (d.layout != null) {
        for (var i = 0; i < d.layout!.landings.length; i++) {
          range(
            StairCheckKind.landing,
            ArchitectStairLayoutResolver.landingDepth(d, landingIndex: i),
            min: math.max(
              d.layout!.flights[i].width,
              d.layout!.flights[i + 1].width,
            ),
          );
        }
      } else {
        range(StairCheckKind.landing, landingDepth, min: stair.width);
      }
    }
    range(
      StairCheckKind.flightRise,
      d.flightRisers.reduce(math.max) * d.riser,
      max: 2.5,
    );
    if (d.layout == null && d.shape == StairShape.spiralOverlap) {
      if (d.overlapHeadroom < .001) {
        range(
          StairCheckKind.headroom,
          d.overlapHeadroom,
          min: .001,
          article: '3D',
          advisory: false,
        );
      } else {
        range(
          StairCheckKind.headroom,
          d.overlapHeadroom,
          min: 2.1,
          article: '2.10 m',
        );
      }
    } else if (measuredHeadroom != null && measuredHeadroom.isFinite) {
      range(
        StairCheckKind.headroom,
        measuredHeadroom,
        min: 2.1,
        article: '2.10 m',
      );
    }
    return result;
  }

  /// Nearest higher finished-floor level; only fall back to floor height if
  /// no higher floor has been modelled. Explicit targets never change silently.
  static ArchitectStairDesign resolveDesign(
    ArchitectProject project,
    ArchitectStorey floor,
    ArchitectStairDesign design,
  ) {
    if (!design.followStoreys) return design;
    final rise = linkedRise(project, floor, design);
    // Keep valid preview geometry while an invalid target is corrected or
    // explicitly saved as a draft. Never generate a zero/negative stair.
    if (rise == null) return design;
    final higher =
        project.storeys
            .where((s) => s.elevation > floor.elevation + 1e-6)
            .toList()
          ..sort((a, b) => a.elevation.compareTo(b.elevation));
    final target = design.upperStoreyId == null
        ? higher.firstOrNull
        : project.storeys
              .where(
                (s) =>
                    s.id == design.upperStoreyId &&
                    s.elevation > floor.elevation + 1e-6,
              )
              .firstOrNull;
    if (design.upperStoreyId != null && target == null) return design;
    return design.copyWith(rise: rise, upperStoreyId: target?.id);
  }

  /// Null means the selected landing is missing, at/below the start or beyond
  /// the supported rise. Resolve against the owning floor, without silently
  /// switching to a different upper floor when the starting level changes.
  static double? linkedRise(
    ArchitectProject project,
    ArchitectStorey floor,
    ArchitectStairDesign design,
  ) {
    final higher =
        project.storeys
            .where((s) => s.elevation > floor.elevation + 1e-6)
            .toList()
          ..sort((a, b) => a.elevation.compareTo(b.elevation));
    final target = design.upperStoreyId == null
        ? higher.firstOrNull
        : higher.where((s) => s.id == design.upperStoreyId).firstOrNull;
    if (design.upperStoreyId != null && target == null) return null;
    final rise =
        (target?.elevation ?? floor.elevation + floor.height) -
        floor.elevation -
        design.startOffset;
    return rise.isFinite && rise > 1e-6 && rise <= 30 ? rise : null;
  }

  static ArchitectProject resolve(ArchitectProject project) {
    var changed = false;
    final floors = [
      for (final floor in project.storeys)
        floor.copyWith(
          stairs: [
            for (final stair in floor.stairs)
              () {
                if (stair.design == null) return stair;
                var next = resolveDesign(project, floor, stair.design!);
                final missingTarget =
                    next.followStoreys &&
                    linkedRise(project, floor, next) == null;
                if (!next.isDraft &&
                    (missingTarget ||
                        check(
                          stair.copyWith(design: next),
                          project: next.layout == null ? null : project,
                          storey: floor,
                        ).any((c) => c.state == StairCheckState.error))) {
                  next = next.copyWith(isDraft: true);
                }
                if (next.rise == stair.design!.rise &&
                    next.upperStoreyId == stair.design!.upperStoreyId &&
                    next.isDraft == stair.design!.isDraft) {
                  return stair;
                }
                changed = true;
                return stair.copyWith(design: next);
              }(),
          ],
        ),
    ];
    return changed ? project.copyWith(storeys: floors) : project;
  }
}

class PutArchitectStair extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectStair stair;
  final bool create;
  const PutArchitectStair({
    required this.storeyId,
    required this.stair,
    this.create = false,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(stair.startPoint);
    ArchitectModelCommand.point(stair.endPoint);
    ArchitectModelCommand.positive(stair.width);
    if (stair.length < .001) throw ArgumentError('Stair direction is missing');
    stair.design?.validate();
    final floor = ArchitectModelCommand.storey(project, storeyId);
    if (create) {
      ArchitectModelCommand.newId(project, stair.id);
    } else if (!floor.stairs.any((s) => s.id == stair.id)) {
      throw ArgumentError('Unknown stair');
    }
    final resolved = stair.design == null
        ? stair
        : stair.copyWith(
            design: ArchitectStairRules.resolveDesign(
              project,
              floor,
              stair.design!,
            ),
          );
    final d = resolved.design;
    d?.validate();
    if (d?.layout != null &&
        ArchitectStairLayoutResolver.check(d!).isNotEmpty) {
      throw ArgumentError('Invalid stair layout constraints');
    }
    if (d != null &&
        !d.isDraft &&
        d.followStoreys &&
        ArchitectStairRules.linkedRise(project, floor, d) == null) {
      throw ArgumentError('Upper floor is missing or below the start');
    }
    if (resolved.design != null &&
        !resolved.design!.isDraft &&
        ArchitectStairRules.check(
          resolved,
          project: project,
          storey: floor,
        ).any((c) => c.state == StairCheckState.error)) {
      throw ArgumentError('Stair violates the selected geometric rules');
    }
    return ArchitectModelCommand.replace(
      project,
      floor.copyWith(
        stairs: [
          for (final s in floor.stairs) s.id == stair.id ? resolved : s,
          if (create) resolved,
        ],
      ),
    );
  }
}
