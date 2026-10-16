import 'dart:math' as math;
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_command_controller.dart';

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
/// Sources / rule matrix: docs/architect_stairs_bulgaria.md.
class ArchitectStairRules {
  static const fireSource =
      'https://mvr.bg/upload/286736/Naredba%20Iz-1971_2025_1.pdf';
  static const accessibilitySource =
      'https://dv.parliament.bg/DVWeb/showMaterialDV.jsp?idMat=155689';
  static List<StairCheck> check(ArchitectStair stair) {
    final d = stair.design;
    if (d == null) {
      return [const StairCheck(StairCheckKind.scope, StairCheckState.review)];
    }
    final result = <StairCheck>[];
    void range(
      StairCheckKind kind,
      double actual, {
      double? min,
      double? max,
      required String article,
      bool advisory = false,
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

    range(
      StairCheckKind.comfort,
      2 * d.riser + d.walkingGoing(stair.width),
      min: .60,
      max: .64,
      article: '2h + b',
      advisory: true,
    );
    if (d.code == StairCode.geometryOnly) {
      result.add(
        const StairCheck(StairCheckKind.scope, StairCheckState.review),
      );
      return result;
    }
    if (d.rulesVersion != ArchitectStairDesign.currentRules) {
      result.add(
        const StairCheck(StairCheckKind.version, StairCheckState.review),
      );
      return result;
    }
    if (d.accessible) {
      final outdoor = d.use == StairUse.outdoorRoute;
      final article = outdoor ? '18(1)' : '55(1)';
      range(
        StairCheckKind.width,
        stair.width,
        min: d.use == StairUse.assembly ? 1.6 : 1.2,
        article: article,
      );
      range(
        StairCheckKind.riser,
        d.riser,
        max: outdoor ? .15 : .17,
        article: article,
      );
      range(
        StairCheckKind.flightRise,
        d.flightRisers.reduce(math.max) * d.riser,
        max: outdoor ? 1.2 : 2.5,
        article: article,
      );
      if (d.shape != StairShape.spiral) {
        range(
          StairCheckKind.going,
          d.going,
          min: outdoor ? .32 : .28,
          max: outdoor ? null : .35,
          article: article,
        );
        if (d.flightCount > 1) {
          range(
            StairCheckKind.landing,
            math.max(stair.width, d.landingDepth),
            min: outdoor ? 1.5 : 1.2,
            article: article,
          );
        }
      } else {
        result.add(
          const StairCheck(
            StairCheckKind.accessibility,
            StairCheckState.review,
            article: '55',
          ),
        );
      }
      result.addAll([
        StairCheck(
          StairCheckKind.headroom,
          StairCheckState.review,
          minimum: outdoor ? null : 2.1,
          article: outdoor ? '18' : '55(1)5',
        ),
        StairCheck(
          StairCheckKind.handrails,
          StairCheckState.review,
          article: outdoor ? '18' : '55(2)',
        ),
        StairCheck(
          StairCheckKind.finishes,
          StairCheckState.review,
          article: outdoor ? '18' : '55(3)',
        ),
      ]);
    } else {
      result.add(
        const StairCheck(StairCheckKind.scope, StairCheckState.review),
      );
    }
    if (d.evacuation == StairEvacuation.unspecified) {
      result.add(
        const StairCheck(StairCheckKind.evacuation, StairCheckState.review),
      );
    } else if (d.isEvacuation) {
      range(
        StairCheckKind.groupSteps,
        d.flightRisers.reduce(math.min).toDouble(),
        min: 3,
        article: '54(3)',
      );
      // Occupant bands suffice for Art. 52, but cannot size the complete
      // evacuation route under Art. 45 or check functional fire subclasses.
      result.add(
        const StairCheck(
          StairCheckKind.capacity,
          StairCheckState.review,
          article: '45',
        ),
      );
      if (d.use == StairUse.outdoorRoute) {
        // Art. 18 urban routes are not the same scope as external escape
        // stairs under Art. 51; do not silently apply one to the other.
        result.add(
          const StairCheck(
            StairCheckKind.scope,
            StairCheckState.review,
            article: '51',
          ),
        );
      } else {
        range(StairCheckKind.riser, d.riser, max: .22, article: '47(4)');
        if (d.shape != StairShape.spiral) {
          range(StairCheckKind.going, d.going, min: .25, article: '47(4)');
          range(
            StairCheckKind.slope,
            d.riser / d.going,
            max: 1 / 1.5,
            article: '47(4)',
          );
          if (d.flightCount > 1) {
            range(
              StairCheckKind.landing,
              math.max(stair.width, d.landingDepth),
              min: stair.width,
              article: '45(8)',
            );
          }
        }
      }
      if (d.shape == StairShape.spiral) {
        if (d.evacuation == StairEvacuation.from16To50) {
          range(
            StairCheckKind.innerGoing30,
            d.goingAt30,
            min: .23,
            article: '52(1)1',
          );
          range(StairCheckKind.width, stair.width, min: 1.2, article: '52(1)2');
        } else if (d.evacuation == StairEvacuation.over50) {
          range(
            StairCheckKind.innerDiameter,
            2 * d.innerRadius,
            min: .9,
            article: '52(2)1',
          );
          range(
            StairCheckKind.innerGoing,
            d.innerGoing,
            min: .23,
            article: '52(2)1',
          );
          range(StairCheckKind.width, stair.width, min: 1.5, article: '52(2)2');
        }
        result.add(
          const StairCheck(
            StairCheckKind.handrails,
            StairCheckState.review,
            article: '52',
          ),
        );
        result.add(
          const StairCheck(StairCheckKind.headroom, StairCheckState.review),
        );
      }
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
    return design.copyWith(
      rise: target == null ? floor.height : target.elevation - floor.elevation,
      upperStoreyId: target?.id,
    );
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
                    next.upperStoreyId != null &&
                    !project.storeys.any(
                      (s) =>
                          s.id == next.upperStoreyId &&
                          s.elevation > floor.elevation,
                    );
                if (!next.isDraft &&
                    (missingTarget ||
                        check(
                          stair.copyWith(design: next),
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
    if (d != null &&
        !d.isDraft &&
        d.followStoreys &&
        d.upperStoreyId != null &&
        !project.storeys.any(
          (s) => s.id == d.upperStoreyId && s.elevation > floor.elevation,
        )) {
      throw ArgumentError('Upper floor is missing or below the start');
    }
    if (resolved.design != null &&
        !resolved.design!.isDraft &&
        ArchitectStairRules.check(
          resolved,
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
