import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_arc_editing.dart';
import 'architect_wall_compositions_test.dart' as data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Rise and midpoint match the circular arc in either direction at any angle',
    () {
      for (final angle in [0.0, .73, 2.6]) {
        final start = const Offset(9, -6);
        final end = start + Offset(math.cos(angle), math.sin(angle)) * 4;
        for (final b in [.001, .4, 1.0, 2.4, -.001, -.4, -1.0, -2.4]) {
          final arc = ArchitectWallArc(start, end, b);
          expect((arc.midpoint - arc.pointAt(.5)).distance, lessThan(1e-8));
          expect(
            (arc.midpoint - arc.chordMidpoint).distance,
            closeTo(arc.sagitta, 1e-9),
          );
          final rise = arc.midpoint - arc.chordMidpoint;
          final chord = end - start;
          expect(rise.dx * chord.dx + rise.dy * chord.dy, closeTo(0, 1e-9));
          final next = arc.withSagitta(.7);
          expect(next.start, start);
          expect(next.end, end);
          expect(next.bulge.sign, b.sign);
          expect(next.sagitta, closeTo(.7, 1e-12));
        }
      }
    },
  );

  test(
    'Known 3-4-5 circle retains minor/major branch and reverses cleanly',
    () {
      for (final b in [.5, 2.0, -.5, -2.0]) {
        final arc = ArchitectWallArc(Offset.zero, const Offset(8, 0), b);
        expect(arc.radius, 5);
        final next = arc.withRadius(7);
        expect(next.radius, closeTo(7, 1e-10));
        expect(next.bulge.abs() > 1, b.abs() > 1);
        expect(next.bulge.sign, b.sign);
        final halfCircle = next.withRadius(4);
        expect(halfCircle.bulge.abs(), 1);
        final reversed = ArchitectWallArc(arc.end, arc.start, -arc.bulge);
        expect((reversed.midpoint - arc.midpoint).distance, lessThan(1e-10));
        expect(reversed.sagitta, arc.sagitta);
      }
      final shallow = const ArchitectWallArc(
        Offset.zero,
        Offset(4, 0),
        .1,
      ).withRadius(1e9);
      expect(shallow.radius, closeTo(1e9, .001));
      expect(shallow.sagitta, greaterThan(0));
    },
  );

  test('Non-finite, zero, negative and impossible dimensions are rejected', () {
    const arc = ArchitectWallArc(Offset.zero, Offset(4, 0), -.5);
    for (final value in [double.nan, double.infinity, -1.0, 0.0]) {
      expect(() => arc.withSagitta(value), throwsArgumentError);
      expect(() => arc.withRadius(value), throwsArgumentError);
    }
    expect(() => arc.withRadius(1.99), throwsArgumentError);
    expect(
      () => const ArchitectWallArc(Offset.zero, Offset.zero, 1).withSagitta(1),
      throwsArgumentError,
    );
    final thick = data.wall('arc', Offset.zero, const Offset(.4, 0));
    expect(
      () => ArchitectWallArcEditing.withDimension(
        thick,
        ArchitectArcDimension.radius,
        .2,
      ),
      throwsArgumentError,
    );
  });

  test(
    'Changing curvature retains references, materials, openings and saved shape',
    () {
      final original = data
          .wall('arc', Offset.zero, const Offset(4, 0))
          .copyWith(
            arcBulge: -.5,
            referenceLine: WallReferenceLine.outer,
            windows: const [
              ArchitectWindow(
                id: 'window',
                uuid: 'window',
                wallId: 'arc',
                offsetRatio: .5,
                width: .8,
              ),
            ],
          );
      final changed = ArchitectWallArcEditing.withDimension(
        original,
        ArchitectArcDimension.sagitta,
        1.2,
      );
      expect(changed.arc!.sagitta, closeTo(1.2, 1e-10));
      final before = original.toJson()..remove('arcBulge');
      final after = changed.toJson()..remove('arcBulge');
      expect(after, before);
      expect(
        ArchitectWall.fromJson(changed.toJson()).arc!.sagitta,
        closeTo(1.2, 1e-10),
      );
      final radius = SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'arc'},
        values: {'arcRadius': 3},
      ).apply(data.project([original]));
      final wall = radius.activeStorey.walls.single;
      expect(wall.arc!.radius, closeTo(3, 1e-10));
      expect(wall.startPoint, original.startPoint);
      expect(wall.endPoint, original.endPoint);
    },
  );

  test(
    'Flattening an arc rejects overlapping openings but permits vertically separate windows',
    () {
      final original = ArchitectWall(
        id: 'arc',
        startPoint: Offset.zero,
        endPoint: const Offset(4, 0),
        thickness: .2,
        arcBulge: .5,
        windows: const [
          ArchitectWindow(
            id: 'a',
            uuid: 'a',
            wallId: 'arc',
            offsetRatio: .4,
            width: .85,
          ),
          ArchitectWindow(
            id: 'b',
            uuid: 'b',
            wallId: 'arc',
            offsetRatio: .6,
            width: .85,
          ),
        ],
      );
      ArchitectWallArcEditing.validateOpenings(original);
      expect(
        () => ArchitectWallArcEditing.withDimension(
          original,
          ArchitectArcDimension.sagitta,
          .05,
        ),
        throwsArgumentError,
      );
      expect(
        () => SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'arc'},
          values: {'arcRadius': 100},
        ).apply(data.project([original])),
        throwsArgumentError,
      );
      final stacked = original.copyWith(
        windows: [
          original.windows.first,
          original.windows.last.copyWith(sillHeight: 2.3, height: .4),
        ],
      );
      final next = ArchitectWallArcEditing.withDimension(
        stacked,
        ArchitectArcDimension.sagitta,
        .05,
      );
      expect(next.windows.map((w) => w.offsetRatio), [.4, .6]);
    },
  );
}
