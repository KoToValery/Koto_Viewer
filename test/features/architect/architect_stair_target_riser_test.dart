import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_layout_resolver.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_rules.dart';

void main() {
  test('target riser fits a custom stair without changing floor height', () {
    const stair = ArchitectStair(
      id: 'target',
      startPoint: Offset.zero,
      endPoint: Offset(1, 0),
      width: 1,
      design: ArchitectStairDesign(
        shape: StairShape.halfTurn,
        rise: 2.8,
        followStoreys: false,
        totalWidth: 2.4,
        landingDepth: 1.2,
      ),
    );
    final original = stair.design!;
    final custom = original.copyWith(
      layout: ArchitectStairLayoutResolver.fromStair(stair),
    );
    final desiredCount = custom.risers + 1;
    final fitted = ArchitectStairRules.applyTargetRiser(
      custom,
      custom.rise / desiredCount,
    );
    expect(fitted, isNotNull);
    expect(fitted!.risers, desiredCount);
    expect(fitted.rise, custom.rise);
    expect(ArchitectStairLayoutResolver.check(fitted), isEmpty);
  });

  test('locked counts reject an impossible target', () {
    final layout = ArchitectStairLayout(
      flights: [
        const ArchitectStairFlightSpec(
          id: 'f',
          origin: Offset.zero,
          axis: Offset(1, 0),
          width: 1,
          risers: 10,
          countLocked: true,
        ),
      ],
      goingLocked: true,
    );
    final design = ArchitectStairDesign(
      rise: 2.8,
      followStoreys: false,
      manualGoing: .28,
      layout: layout,
    );
    expect(ArchitectStairRules.applyTargetRiser(design, .2), isNull);
    expect(design.risers, 10);
  });
}
