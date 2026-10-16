import '../../../core/l10n/l10n_extensions.dart';
import 'package:intl/intl.dart';
import '../models/architect_elements.dart';
import '../services/architect_stair_rules.dart';

String stairPlanLabel(AppLocalizations l, ArchitectStair stair) {
  final d = stair.design;
  if (d == null) return '';
  final cm = NumberFormat('0.##', l.localeName);
  return '${l.stairPlanStepsLabel(d.risers, cm.format(d.walkingGoing(stair.width) * 100), cm.format(d.riser * 100))}\n'
      '${l.stairPlanRiseLabel(NumberFormat('0.00', l.localeName).format(d.rise))}';
}

String stairShapeLabel(AppLocalizations l, StairShape shape) => switch (shape) {
  StairShape.straight => l.stairStraight,
  StairShape.quarterTurn => l.stairQuarterTurn,
  StairShape.halfTurn => l.stairHalfTurn,
  StairShape.spiral => l.stairSpiral,
};
String stairUseLabel(AppLocalizations l, StairUse use) => switch (use) {
  StairUse.private => l.stairUsePrivate,
  StairUse.common => l.stairUseCommon,
  StairUse.public => l.stairUsePublic,
  StairUse.assembly => l.stairUseAssembly,
  StairUse.outdoorRoute => l.stairUseOutdoor,
};
String stairEvacuationLabel(AppLocalizations l, StairEvacuation e) =>
    switch (e) {
      StairEvacuation.unspecified => l.stairUnspecified,
      StairEvacuation.none => l.stairNoEvacuation,
      StairEvacuation.upTo15 => l.stairUpTo15,
      StairEvacuation.from16To50 => l.stair16To50,
      StairEvacuation.over50 => l.stairOver50,
    };
String stairCheckLabel(AppLocalizations l, StairCheckKind kind) =>
    switch (kind) {
      StairCheckKind.width => l.stairClearWidth,
      StairCheckKind.riser => l.stairRiser,
      StairCheckKind.going => l.stairGoing,
      StairCheckKind.slope => l.stairCheckSlope,
      StairCheckKind.landing => l.stairLanding,
      StairCheckKind.flightRise => l.stairCheckFlightRise,
      StairCheckKind.innerGoing30 => l.stairCheckInner30,
      StairCheckKind.innerGoing => l.stairCheckInner,
      StairCheckKind.innerDiameter => l.stairCheckDiameter,
      StairCheckKind.comfort => l.stairCheckComfort,
      StairCheckKind.evacuation => l.stairEvacuation,
      StairCheckKind.capacity => l.stairCheckCapacity,
      StairCheckKind.headroom => l.stairCheckHeadroom,
      StairCheckKind.handrails => l.stairCheckHandrails,
      StairCheckKind.finishes => l.stairCheckFinishes,
      StairCheckKind.accessibility => l.stairCheckAccessibility,
      StairCheckKind.scope => l.stairCheckScope,
      StairCheckKind.version => l.stairCheckVersion,
      StairCheckKind.upperStorey => l.stairCheckUpperStorey,
      StairCheckKind.groupSteps => l.stairCheckGroupSteps,
    };
String stairStateLabel(AppLocalizations l, StairCheckState state) =>
    switch (state) {
      StairCheckState.pass => l.stairCheckPass,
      StairCheckState.error => l.stairCheckError,
      StairCheckState.advice => l.stairCheckAdvice,
      StairCheckState.review => l.stairCheckReview,
    };
