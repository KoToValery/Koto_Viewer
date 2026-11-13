import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_perimeter_draft.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_layout_resolver.dart';

void main() {
  ArchitectStairPerimeterDraft create() => ArchitectStairPerimeterDraft(
    const ArchitectStair(
      id: 'stair',
      startPoint: Offset.zero,
      endPoint: Offset(1, 0),
      width: 1.2,
      design: ArchitectStairDesign(
        shape: StairShape.straight,
        code: StairCode.geometryOnly,
        manualGoing: .28,
        rise: 2.8,
        followStoreys: false,
      ),
    ),
  );
  test('outside edge builds one flight and an exact first length', () {
    final d = create();
    addTearDown(d.dispose);
    d.pick(const Offset(5, 2));
    d.pick(const Offset(6.4, 2));
    d.setLength(1.4);
    expect(d.preview!.plan.nosings.first.$1, const Offset(5, 2));
    expect(d.layout.flights, isEmpty);
    expect(d.acceptPart(), isTrue);
    expect(
      d.committedPreview!.design!.layout!.flights.single.run(d.design.going),
      closeTo(1.4, 1e-8),
    );
    expect(d.complete, isTrue);
    final snap = d.snappingPreview;
    d.aim(const Offset(8, 2));
    expect(identical(d.snappingPreview, snap), isTrue);
  });
  test(
    'continuous outside trace creates a landing and a turned second flight',
    () {
      final d = create();
      addTearDown(d.dispose);
      d.pick(Offset.zero);
      d.pick(const Offset(1.4, 0));
      d.acceptPart();
      d.pick(const Offset(2.6, 0));
      d.acceptPart();
      d.pick(const Offset(2.6, 1.4));
      final live = d.preview!;
      expect(live.design!.layout!.flights, hasLength(2));
      expect(live.design!.layout!.landings, hasLength(1));
      expect(ArchitectStairLayoutResolver.check(live.design!), isEmpty);
      d.acceptPart();
      expect(d.complete, isTrue);
      d.undo();
      expect(d.complete, isFalse);
      d.redo();
      expect(d.complete, isTrue);
    },
  );
  test(
    'navigation restores the provisional endpoint without adding a segment',
    () {
      final d = create();
      addTearDown(d.dispose);
      d.pick(Offset.zero);
      d.aim(const Offset(1.4, 0));
      final previous = d.target;
      d.beginPointer();
      d.aim(const Offset(10, 0));
      d.cancelPointer();
      expect(d.target, previous);
      expect(d.segments, isEmpty);
    },
  );
}
