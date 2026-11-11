import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_path_solid.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_network.dart';
import 'package:kotoview/src/features/architect/services/architect_chamfer_fillet.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_offset.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_operation_axis.dart';

import 'architect_editing_test.dart' as editing;

ArchitectWall physicalWall(
  String id,
  Offset a,
  Offset b,
  WallReferenceLine reference, {
  double thickness = .37,
  double insulation = .12,
}) {
  final wall = ArchitectWall(
    id: id,
    startPoint: a,
    endPoint: b,
    thickness: thickness,
    insulationThicknessOverride: insulation,
    referenceLine: reference,
    exteriorSideMode: WallResolutionMode.manual,
    height: 3.6,
    followStoreyHeight: false,
    baseOffset: .15,
  );
  final shift = a - wall.coreCenterStart;
  return wall.copyWith(startPoint: a + shift, endPoint: b + shift);
}

ArchitectWall reversed(ArchitectWall w) => w.copyWith(
  startPoint: w.endPoint,
  endPoint: w.startPoint,
  referenceLine: switch (w.referenceLine) {
    WallReferenceLine.left => WallReferenceLine.right,
    WallReferenceLine.right => WallReferenceLine.left,
    _ => w.referenceLine,
  },
  exteriorSide: w.exteriorSide == WallExteriorSide.left
      ? WallExteriorSide.right
      : WallExteriorSide.left,
);

void near(Offset a, Offset b) => expect((a - b).distance, lessThan(1e-8));

void main() {
  test('Detached endpoints do not acquire an offset junction', () {
    final a = physicalWall(
      'a',
      Offset.zero,
      const Offset(4, 0),
      WallReferenceLine.outer,
    ).copyWith(connectEnd: false);
    final b = physicalWall(
      'b',
      const Offset(4, 0),
      const Offset(4, 4),
      WallReferenceLine.inner,
    ).copyWith(connectStart: false);
    final next = ArchitectOffset.apply(
      ArchitectStorey(id: 's', name: '', walls: [a, b]),
      {'a', 'b'},
      distance: .5,
      side: const Offset(5, -1),
    );
    near(next.walls[0].coreCenterEnd, const Offset(4, -.5));
    near(next.walls[1].coreCenterStart, const Offset(4.5, 0));
    expect(next.walls[0].connectEnd, isFalse);
    expect(next.walls[1].connectStart, isFalse);
  });
  test(
    'Line-arc offset normalizes a physical corner with mixed leading lines',
    () {
      const a = ArchitectWall(
        id: 'a',
        startPoint: Offset(-4, 0),
        endPoint: Offset.zero,
        thickness: .25,
        referenceLine: WallReferenceLine.outer,
      );
      const b = ArchitectWall(
        id: 'b',
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        thickness: .25,
        arcBulge: .5,
        referenceLine: WallReferenceLine.inner,
      );
      final next = ArchitectOffset.apply(
        const ArchitectStorey(id: 's', name: '', walls: [a, b]),
        {'a', 'b'},
        distance: .2,
        side: const Offset(-2, -2),
      );
      near(next.walls[0].coreCenterEnd, next.walls[1].coreCenterStart);
      near(
        ArchitectWallOperationAxis.core(next.walls[1]).arc!.center,
        ArchitectWallOperationAxis.core(b).arc!.center,
      );
      expect(
        next.walls[0].coreCenterStart.dy,
        closeTo(a.coreCenterStart.dy - .2, 1e-8),
      );
      expect(next.walls[1].referenceLine, b.referenceLine);
    },
  );
  test(
    'Rotated fillet keeps the physical side when source directions are reversed',
    () {
      const angle = .47;
      Offset rotate(Offset p) => Offset(
        p.dx * math.cos(angle) - p.dy * math.sin(angle),
        p.dx * math.sin(angle) + p.dy * math.cos(angle),
      );
      final a = reversed(
        physicalWall(
          'a',
          rotate(Offset.zero),
          rotate(const Offset(4, 0)),
          WallReferenceLine.outer,
        ),
      );
      final b = reversed(
        physicalWall(
          'b',
          rotate(const Offset(4, 0)),
          rotate(const Offset(4, 4)),
          WallReferenceLine.inner,
        ),
      );
      final result = ArchitectChamferFillet.wallPairFillet(a, b, radius: .7)!;
      near(result.wallA.coreCenterStart, rotate(const Offset(3.3, 0)));
      near(result.wallB.coreCenterEnd, rotate(const Offset(4, .7)));
      near(result.connector.tangentAt(0), rotate(const Offset(1, 0)));
      near(
        result.connector.normalAt(0) * result.connector.exteriorSign,
        rotate(const Offset(0, 1)),
      );
      expect(result.connector.height, a.height);
      expect(result.wallA.referenceLine, a.referenceLine);
      expect(result.wallB.referenceLine, b.referenceLine);
    },
  );

  test(
    'Offset copy follows the core axes and preserves opening stations through persistence and Undo',
    () {
      final a =
          physicalWall(
            'a',
            Offset.zero,
            const Offset(4, 0),
            WallReferenceLine.outer,
          ).addDoor(
            const ArchitectDoor(
              id: 'd',
              uuid: 'd',
              wallId: 'a',
              offsetRatio: .4,
              width: .8,
            ),
          );
      final b = physicalWall(
        'b',
        const Offset(4, 0),
        const Offset(4, 4),
        WallReferenceLine.inner,
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [a, b]),
      );
      addTearDown(model.dispose);
      final before = model.project;
      model.execute(
        const OffsetArchitectElements(
          storeyId: 's',
          elementIds: {'a', 'b'},
          distance: .5,
          side: Offset(5, -1),
          idMap: {'a': 'copyA', 'b': 'copyB'},
        ),
      );
      final saved = ArchitectProject.fromJson(model.project.toJson());
      final copied = saved.activeStorey.walls.firstWhere(
        (w) => w.id == 'copyA',
      );
      final copiedB = saved.activeStorey.walls.firstWhere(
        (w) => w.id == 'copyB',
      );
      near(copied.coreCenterEnd, copiedB.coreCenterStart);
      near(
        copied.centerPointAt(copied.doors.single.offsetRatio),
        a.centerPointAt(.4) + const Offset(0, -.5),
      );
      expect(copied.referenceLine, a.referenceLine);
      expect(copied.doors.single.wallId, 'copyA');
      expect(copied.doors.single.id, isNot('d'));
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project, same(before));
    },
  );

  for (final ra in WallReferenceLine.values) {
    for (final rb in WallReferenceLine.values) {
      for (final fillet in [false, true]) {
        test('${fillet ? 'Fillet' : 'Chamfer'} uses core: $ra / $rb', () {
          final a = physicalWall('a', Offset.zero, const Offset(4, 0), ra);
          final b = physicalWall(
            'b',
            const Offset(4, 0),
            const Offset(4, 4),
            rb,
            thickness: .3,
            insulation: 0,
          );
          final result = fillet
              ? ArchitectChamferFillet.wallPairFillet(a, b, radius: .7)
              : ArchitectChamferFillet.wallPairChamfer(a, b, distance: .7);
          expect(result, isNotNull);
          final r = result!;
          near(r.wallA.coreCenterStart, a.coreCenterStart);
          near(r.wallB.coreCenterEnd, b.coreCenterEnd);
          near(r.wallA.coreCenterEnd, const Offset(3.3, 0));
          near(r.wallB.coreCenterStart, const Offset(4, .7));
          near(r.connector.coreCenterStart, r.wallA.coreCenterEnd);
          near(r.connector.coreCenterEnd, r.wallB.coreCenterStart);
          expect(r.wallA.referenceLine, ra);
          expect(r.wallB.referenceLine, rb);
          expect(r.connector.height, a.height);
          expect(r.connector.baseOffset, a.baseOffset);
          expect(r.connector.insulationThickness, a.insulationThickness);
          if (fillet) {
            expect(r.connector.arc!.radius, closeTo(.7, 1e-8));
            near(r.connector.tangentAt(0), const Offset(1, 0));
            near(r.connector.tangentAt(1), const Offset(0, 1));
          }
          final body = ArchitectWallNetwork.body([
            r.wallA,
            r.connector,
            r.wallB,
          ]);
          expect(ArchitectPathSolid.contours(body), hasLength(1));
          expect(body.contains(r.wallA.coreCenterEnd), isTrue);
          expect(body.contains(r.wallB.coreCenterStart), isTrue);
        });
      }
      test(
        'Offset mixed-reference chain $ra / $rb preserves physical placement',
        () {
          final a = physicalWall('a', Offset.zero, const Offset(4, 0), ra);
          final b = reversed(
            physicalWall('b', const Offset(4, 0), const Offset(4, 4), rb),
          );
          final storey = ArchitectStorey(id: 's', name: '', walls: [a, b]);
          final next = ArchitectOffset.apply(
            storey,
            {'a', 'b'},
            distance: .5,
            side: const Offset(5, -1),
          );
          final aa = next.walls[0], bb = next.walls[1];
          near(aa.coreCenterStart, const Offset(0, -.5));
          near(aa.coreCenterEnd, const Offset(4.5, -.5));
          near(bb.coreCenterStart, const Offset(4.5, 4));
          near(bb.coreCenterEnd, aa.coreCenterEnd);
          expect(aa.referenceLine, a.referenceLine);
          expect(bb.referenceLine, b.referenceLine);
          expect(aa.exteriorSide, a.exteriorSide);
          expect(bb.exteriorSide, b.exteriorSide);
          // Each finished face follows the same half-metre translation.
          near(
            aa.polygonCorners[0] - a.polygonCorners[0],
            const Offset(0, -.5),
          );
        },
      );
    }
  }

  test(
    'Physical corner with different reference endpoints forms one offset chain',
    () {
      const a = ArchitectWall(
        id: 'a',
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        thickness: .25,
        referenceLine: WallReferenceLine.outer,
      );
      const b = ArchitectWall(
        id: 'b',
        startPoint: Offset(4, 0),
        endPoint: Offset(4, 4),
        thickness: .25,
        referenceLine: WallReferenceLine.inner,
      );
      final next = ArchitectOffset.apply(
        const ArchitectStorey(id: 's', name: '', walls: [a, b]),
        {'a', 'b'},
        distance: .5,
        side: const Offset(5, -1),
      );
      near(next.walls[0].coreCenterEnd, next.walls[1].coreCenterStart);
      expect(
        next.walls[0].coreCenterStart.dy,
        closeTo(a.coreCenterStart.dy - .5, 1e-8),
      );
      expect(
        next.walls[1].coreCenterEnd.dx,
        closeTo(b.coreCenterEnd.dx + .5, 1e-8),
      );
    },
  );

  test(
    'Trimming a mixed-reference corner keeps hosted openings and undoes once',
    () {
      final a =
          physicalWall(
            'a',
            Offset.zero,
            const Offset(4, 0),
            WallReferenceLine.inner,
          ).addDoor(
            const ArchitectDoor(
              id: 'd',
              uuid: 'd',
              wallId: 'a',
              offsetRatio: .4,
              width: .8,
            ),
          );
      final b =
          physicalWall(
            'b',
            const Offset(4, 0),
            const Offset(4, 4),
            WallReferenceLine.outer,
          ).addDoor(
            const ArchitectDoor(
              id: 'e',
              uuid: 'e',
              wallId: 'b',
              offsetRatio: .6,
              width: .8,
            ),
          );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [a, b]),
      );
      addTearDown(model.dispose);
      final before = model.project;
      final r = ArchitectChamferFillet.wallPairFillet(a, b, radius: .7)!;
      near(
        r.wallA.centerPointAt(r.wallA.doors.single.offsetRatio),
        a.centerPointAt(.4),
      );
      near(
        r.wallB.centerPointAt(r.wallB.doors.single.offsetRatio),
        b.centerPointAt(.6),
      );
      model.commit(
        before.updateActiveStorey(
          before.activeStorey.copyWith(walls: [r.wallA, r.wallB, r.connector]),
        ),
      );
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project, same(before));
      model.redo();
      expect(model.project.activeStorey.walls, hasLength(3));
    },
  );

  test(
    'Cutting through an opening or requesting an impossible radius is refused',
    () {
      final a =
          physicalWall(
            'a',
            Offset.zero,
            const Offset(4, 0),
            WallReferenceLine.outer,
          ).addDoor(
            const ArchitectDoor(
              id: 'd',
              uuid: 'd',
              wallId: 'a',
              offsetRatio: .8,
              width: 1,
            ),
          );
      final b = physicalWall(
        'b',
        const Offset(4, 0),
        const Offset(4, 4),
        WallReferenceLine.inner,
      );
      expect(ArchitectChamferFillet.wallPairFillet(a, b, radius: 1), isNull);
      expect(ArchitectChamferFillet.wallPairChamfer(a, b, distance: 1), isNull);
      expect(
        ArchitectChamferFillet.wallPairFillet(
          a.copyWith(doors: []),
          b,
          radius: 5,
        ),
        isNull,
      );
      expect(a.doors.single.offsetRatio, .8);
    },
  );

  for (final ref in WallReferenceLine.values) {
    test(
      'Curved offset and reference round trip retain physical core: $ref',
      () {
        final axis = ArchitectWall(
          id: 'w',
          startPoint: Offset.zero,
          endPoint: const Offset(4, 0),
          arcBulge: math.tan(math.pi / 8),
          thickness: .001,
        );
        final source = ArchitectWallOperationAxis.restore(
          ArchitectWall(
            id: 'w',
            startPoint: axis.startPoint,
            endPoint: axis.endPoint,
            arcBulge: axis.arcBulge,
            referenceLine: ref,
            thickness: .37,
            insulationThicknessOverride: .12,
          ),
          axis,
        );
        final core = ArchitectWallOperationAxis.core(source);
        near(core.arc!.center, axis.arc!.center);
        expect(core.arc!.radius, closeTo(axis.arc!.radius, 1e-8));
        final next = ArchitectOffset.apply(
          ArchitectStorey(id: 's', name: '', walls: [source]),
          {'w'},
          distance: .2,
          side: axis.arc!.center,
        ).walls.single;
        final nextCore = ArchitectWallOperationAxis.core(next);
        expect(nextCore.arc!.radius, closeTo(core.arc!.radius - .2, 1e-8));
        near(nextCore.arc!.center, core.arc!.center);
        expect(next.referenceLine, ref);
      },
    );
  }
}
