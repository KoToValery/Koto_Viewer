import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_wall_compositions_test.dart' as data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curved = data
      .wall('arc', Offset.zero, const Offset(4, 0))
      .copyWith(arcBulge: 1);
  test(
    'Three points define an exact circle, with true arc length and hit test',
    () {
      final b = ArchitectWallArc.through(
        Offset.zero,
        const Offset(4, 0),
        const Offset(2, 1),
      );
      expect(b, closeTo(-.5, 1e-10));
      final arc = ArchitectWallArc(Offset.zero, const Offset(4, 0), b);
      expect(arc.pointAt(.5).dx, closeTo(2, 1e-10));
      expect(arc.pointAt(.5).dy, closeTo(1, 1e-10));
      expect(curved.length, closeTo(2 * math.pi, 1e-10));
      expect(curved.containsPoint(curved.centerPointAt(.5)), isTrue);
      expect(curved.containsPoint(const Offset(2, 0)), isFalse);
      expect(
        curved.projectPoint(curved.centerPointAt(.7)).$1,
        closeTo(.7, 1e-10),
      );
    },
  );
  test('Concentric layers form one body in plan and 3D', () {
    final layers = ArchitectWallLayers.build([curved], [data.composition]);
    final expected =
        curved.length * curved.thickness -
        math.pi * curved.centerLineOffset * curved.thickness;
    expect(data.area(layers.body), closeTo(expected, .002));
    expect(
      layers.materials.fold(0.0, (v, r) => v + data.area(r.path)),
      closeTo(data.area(layers.body), .0001),
    );
    final solids = ArchitectWallSolids.build(
      data.project([curved]).activeStorey,
      [data.composition],
    );
    expect(
      solids.fold(0.0, (v, r) => v + data.area(r.path) * (r.top - r.bottom)),
      closeTo(data.area(layers.body) * 2.8, .001),
    );
  });
  test(
    'Splitting and reopening preserve both exact arcs and the material side',
    () {
      final p = SplitArchitectWall(
        storeyId: 's',
        wallId: 'arc',
        newWallId: 'second',
        ratio: .4,
      ).apply(data.project([curved]));
      final a = p.activeStorey.walls[0], b = p.activeStorey.walls[1];
      expect(a.endPoint, b.startPoint);
      expect(a.arcBulge, closeTo(math.tan(math.pi * .1), 1e-10));
      expect(a.length + b.length, closeTo(curved.length, 1e-9));
      expect((a.arc!.center - curved.arc!.center).distance, lessThan(1e-8));
      final reloaded = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(reloaded.activeStorey.walls.first.arcBulge, a.arcBulge);
      final flipped = curved.mirroredAroundCore();
      expect(
        (flipped.coreCenterStart - curved.coreCenterStart).distance,
        lessThan(.000001),
      );
      expect(
        (flipped.coreCenterEnd - curved.coreCenterEnd).distance,
        lessThan(.000001),
      );
    },
  );
  test('A finite cutting stroke uses the arc rather than its chord', () {
    final p = CutArchitectWalls(
      storeyId: 's',
      wallIds: {'arc'},
      start: const Offset(2, -3),
      end: const Offset(2, -1),
    ).apply(data.project([curved]));
    expect(p.activeStorey.walls.length, 2);
    expect(p.activeStorey.walls.first.length, closeTo(math.pi, 1e-9));
  });
  test('An impossible inner radius is rejected', () {
    expect(
      () => curved.copyWith(endPoint: const Offset(.1, 0)).validateGeometry(),
      throwsArgumentError,
    );
  });
  test('A straight window cuts all concentric skins at its tangent', () {
    final host = curved.copyWith(
      windows: [
        const ArchitectWindow(
          id: 'win',
          uuid: 'win',
          wallId: 'arc',
          offsetRatio: .5,
          width: 1,
          height: 1.2,
          sillHeight: .8,
        ),
      ],
    );
    host.validateGeometry();
    final outline = Path()..addPolygon(host.polygonCorners, true);
    final hole = Path.combine(
      PathOperation.intersect,
      outline,
      host.openingCutoutAt(1),
    );
    final plan = ArchitectWallLayers.build([host], [data.composition]);
    expect(plan.body.contains(host.centerPointAt(.5)), isFalse);
    final solids = ArchitectWallSolids.build(
      data.project([host]).activeStorey,
      [data.composition],
    );
    expect(
      solids.fold(0.0, (v, s) => v + data.area(s.path) * (s.top - s.bottom)),
      closeTo(data.area(outline) * 2.8 - data.area(hole) * 1.2, .0002),
    );
    for (final solid in solids.where((s) => s.bottom >= .8 && s.top <= 2)) {
      expect(
        data.area(Path.combine(PathOperation.intersect, solid.path, hole)),
        lessThan(.000001),
      );
    }
  });
  test('Oversize frames and frames crossing an arc end are rejected', () {
    const wide = ArchitectWindow(
      id: 'win',
      uuid: 'win',
      wallId: 'arc',
      offsetRatio: .5,
      width: 3.9,
    );
    expect(
      () => curved.copyWith(windows: [wide]).validateGeometry(),
      throwsArgumentError,
    );
    expect(
      () => curved
          .copyWith(windows: [wide.copyWith(width: 1, offsetRatio: .03)])
          .validateGeometry(),
      throwsArgumentError,
    );
  });
  test(
    'Straight to curved material junctions have neither holes nor overlap',
    () {
      final straight = data.wall('straight', const Offset(-3, 0), Offset.zero);
      final layers = ArchitectWallLayers.build(
        [curved, straight],
        [data.composition],
      );
      var all = Path();
      for (final r in layers.materials) {
        expect(
          data.area(Path.combine(PathOperation.intersect, all, r.path)),
          lessThan(.00001),
        );
        all = Path.combine(PathOperation.union, all, r.path);
      }
      expect(
        data.area(Path.combine(PathOperation.difference, layers.body, all)),
        lessThan(.00001),
      );
    },
  );
}
