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
      expect(
        live.design!.layout!.flights[0].footprint(live.design!.going).map((p) => p.dy).every((y) => y >= -1e-6),
        isTrue,
      );
      expect(
        live.design!.layout!.flights[1].footprint(live.design!.going).map((p) => p.dx).every((x) => x <= 2.6 + 1e-6),
        isTrue,
      );
      d.acceptPart();
      expect(d.complete, isTrue);
      d.undo();
      expect(d.complete, isFalse);
      d.redo();
      expect(d.complete, isTrue);
    },
  );
  test('keystroke edits on first flight fit whole steps without shrinking going', () {
    final d = create();
    addTearDown(d.dispose);
    d.pick(Offset.zero);
    d.pick(const Offset(1.0, 0));
    d.setLength(.02);
    d.setLength(.25);
    d.setLength(2.50);
    expect(d.acceptPart(), isTrue);
    final flight = d.committedPreview!.design!.layout!.flights.single;
    expect(flight.risers, 10);
    expect(d.design.going, closeTo(.278, 1e-8));
    expect(flight.run(d.design.going), closeTo(2.502, 1e-8));
  });
  test('second flight exact non-multiple length does not break layout checks', () {
    final d = create();
    addTearDown(d.dispose);
    d.pick(Offset.zero);
    d.pick(const Offset(2.50, 0));
    d.setLength(2.50);
    expect(d.acceptPart(), isTrue);
    d.pick(Offset(d.anchor!.dx + 1.20, 0));
    expect(d.acceptPart(), isTrue);
    d.pick(Offset(d.anchor!.dx, 2.00));
    d.setLength(2.00);
    final live = d.preview!;
    expect(ArchitectStairLayoutResolver.check(live.design!), isEmpty);
    expect(d.acceptPart(), isTrue);
    expect(d.complete, isTrue);
  });
  test(
    'turning landing stays inside perimeter and trims adjoining flights dynamically',
    () {
      for (final turnY in [2.6, -2.6]) {
        final d = create();
        addTearDown(d.dispose);
        d.pick(Offset.zero);
        d.pick(const Offset(2.6, 0));
        d.setLength(2.6);
        expect(d.committedPreview, isNull);
        expect(d.preview!.design!.layout!.flights.single.risers, 10);
        expect(d.acceptPart(), isTrue);
        final flightEndX = d.anchor!.dx;

        d.pick(Offset(flightEndX, turnY));
        final quads = d.pendingLandingQuads;
        expect(quads, hasLength(1));
        expect(
          quads.single.every(
            (p) => p.dx <= flightEndX + 1e-6 && p.dx >= flightEndX - 1.2 - 1e-6,
          ),
          isTrue,
        );
        final trimmedFirst = d.preview!.design!.layout!.flights.single;
        expect(trimmedFirst.risers, 6);
        expect(trimmedFirst.run(d.design.going), closeTo(1.4, 1e-6));
        expect(trimmedFirst.end(d.design.going).dx, closeTo(1.4, 1e-6));
        expect(d.acceptPart(), isTrue);

        d.pick(Offset(0, turnY));
        d.setLength(2.6);
        final live = d.preview!;
        final flights = live.design!.layout!.flights;
        expect(flights, hasLength(2));
        expect(live.design!.layout!.landings, hasLength(1));
        expect(flights[0].end(live.design!.going).dx, closeTo(1.4, 1e-6));
        expect(flights[1].origin.dx, closeTo(flightEndX - 1.2, 1e-6));
        expect(
          flights[1].end(live.design!.going).dx,
          closeTo(flightEndX - 2.6, 1e-6),
        );
        expect(ArchitectStairLayoutResolver.check(live.design!), isEmpty);
      }
    },
  );
  test(
    'asymmetric U-turn fits trimmed first flight going and advances second flight',
    () {
      final d = ArchitectStairPerimeterDraft(
        const ArchitectStair(
          id: 'stair',
          startPoint: Offset.zero,
          endPoint: Offset(1, 0),
          width: 1.1,
          design: ArchitectStairDesign(
            shape: StairShape.straight,
            code: StairCode.geometryOnly,
            manualGoing: .28,
            rise: 2.8,
            followStoreys: false,
          ),
        ),
      );
      addTearDown(d.dispose);
      d.pick(Offset.zero);
      d.pick(const Offset(0, 3.8));
      d.setLength(3.8);
      expect(d.acceptPart(), isTrue);
      final flightEndY = d.anchor!.dy;
      d.pick(Offset(2.5, flightEndY));
      expect(d.acceptPart(), isTrue);
      // Rounded 0.1 cm going on trimmed clear run stays inside turning landing.
      expect(d.design.going, closeTo(.269, 1e-8));

      d.pick(const Offset(2.5, 0));
      d.setLength(3.576);
      final live = d.preview!;
      final flights = live.design!.layout!.flights;
      expect(flights, hasLength(2));
      expect(flights[0].end(live.design!.going).dy, closeTo(2.69, 1e-6));
      expect(flights[1].origin.dy, closeTo(flightEndY - 1.1, 1e-6));
      expect(live.design!.layout!.landings.single.polygon.every((p) => p.dy <= flightEndY + 1e-6), isTrue);
      expect(ArchitectStairLayoutResolver.check(live.design!), isEmpty);

      // Undoing the turn restores the full untrimmed first flight.
      d.undo();
      d.undo();
      expect(d.design.going, closeTo(.271, 1e-8));
    },
  );
  test('turning L-stair landing trims first flight cleanly at corner', () {
    final d = create();
    addTearDown(d.dispose);
    d.pick(Offset.zero);
    d.pick(const Offset(0, 3.8));
    d.setLength(3.8);
    expect(d.acceptPart(), isTrue);
    final flightEndY = d.anchor!.dy;
    d.pick(Offset(1.2, flightEndY));
    expect(d.acceptPart(), isTrue);
    d.pick(Offset(3.8, flightEndY));
    d.setLength(2.6);
    final live = d.preview!;
    final flights = live.design!.layout!.flights;
    expect(flights, hasLength(2));
    expect(flights[0].run(live.design!.going), closeTo(2.592, 1e-6));
    expect(flights[1].origin.dx, closeTo(1.2, 1e-6));
    expect(flights[1].run(live.design!.going), closeTo(2.592, 1e-6));
    expect(ArchitectStairLayoutResolver.check(live.design!), isEmpty);
  });
  test('outer three-edge U-turn advances second flight past the landing', () {
    final d = create();
    addTearDown(d.dispose);
    d.pick(Offset.zero);
    d.pick(const Offset(1.4, 0));
    expect(d.acceptPart(), isTrue);
    d.pick(const Offset(2.6, 0));
    expect(d.acceptPart(), isTrue);
    d.choose(StairPerimeterPart.landing);
    d.pick(const Offset(2.6, 2.6));
    expect(d.acceptPart(), isTrue);
    d.pick(const Offset(1.2, 2.6));
    final live = d.preview!;
    expect(live.design!.layout!.flights, hasLength(2));
    expect(live.design!.layout!.landings, hasLength(1));
    expect(ArchitectStairLayoutResolver.check(live.design!), isEmpty);
    expect(
      live.design!.layout!.flights[1].origin.dx,
      closeTo(1.4, 1e-6),
    );
  });
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
