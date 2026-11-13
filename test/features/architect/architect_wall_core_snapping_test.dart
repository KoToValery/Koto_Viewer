import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_endpoint_snap.dart';
import 'package:kotoview/src/features/architect/services/architect_drag_controller.dart';

const layers = [
  ArchitectMaterialLayer(
    id: 'eps',
    material: ArchitectMaterial.eps,
    role: ArchitectLayerRole.insulation,
    thickness: .12,
  ),
  ArchitectMaterialLayer(
    id: 'brick',
    material: ArchitectMaterial.brick,
    role: ArchitectLayerRole.core,
    thickness: .25,
  ),
  ArchitectMaterialLayer(
    id: 'plaster',
    material: ArchitectMaterial.plaster,
    role: ArchitectLayerRole.finish,
    thickness: .015,
  ),
];

ArchitectProject project(List<ArchitectWall> walls) =>
    ArchitectProject.starterWithCatalog(name: '', storeyCount: 1).copyWith(
      gridAxes: const [],
      activeStoreyId: 's',
      storeys: [ArchitectStorey(id: 's', name: '', walls: walls)],
    );

void main() {
  for (final reference in WallReferenceLine.values) {
    for (final bulge in [0.0, .3]) {
      test(
        'Wall snapping exposes only core faces: $reference, bulge $bulge',
        () {
          final wall = ArchitectWall(
            id: 'w',
            startPoint: Offset.zero,
            endPoint: const Offset(4, 0),
            thickness: .385,
            layers: layers,
            referenceLine: reference,
            arcBulge: bulge,
          );
          final model = project([wall]);
          final n = wall.normalAt(.5) * wall.exteriorSign;
          final coreCenter =
              wall.centerPointAt(.5) - n * wall.coreAsymmetry / 2;
          for (final sign in [-1, 1]) {
            final finish =
                wall.centerPointAt(.5) + n * (sign * wall.thickness / 2);
            final core = coreCenter + n * (sign * wall.coreThickness / 2);
            final rejected = ArchitectWallSnap.resolve(
              raw: finish,
              project: model,
              scale: 10000,
              coreOnly: true,
            );
            expect(
              (rejected.point - finish).distance > .001 || !rejected.isSnapped,
              isTrue,
            );
            final snap = ArchitectWallSnap.resolve(
              raw: core,
              project: model,
              scale: 10000,
              coreOnly: true,
            );
            expect(snap.isSnapped, isTrue);
            expect((snap.point - core).distance, lessThan(.0001));
            expect(snap.wallAttachment?.source, same(wall));
            expect(
              snap.wallAttachment?.reference,
              sign == 1 ? WallReferenceLine.outer : WallReferenceLine.inner,
            );
          }
          final proxies = ArchitectWallGeometry.coreWalls([wall]);
          final proxy = proxies.single;
          expect(proxy.thickness, closeTo(.25, 1e-9));
          expect(
            (proxy.centerPointAt(.5) - coreCenter).distance,
            lessThan(1e-9),
          );
          expect(
            ArchitectSnapGeometry.of(model, wallCoresOnly: true),
            same(ArchitectSnapGeometry.of(model, wallCoresOnly: true)),
          );
        },
      );
    }
  }

  test('Continuation preserves handedness at either turn and any rotation', () {
    for (final reference in [
      WallReferenceLine.inner,
      WallReferenceLine.outer,
      WallReferenceLine.center,
    ]) {
      for (final side in WallExteriorSide.values) {
        for (final angle in [0.0, .37, math.pi / 2]) {
          final u = Offset(math.cos(angle), math.sin(angle));
          final source = ArchitectWall(
            id: 'w',
            startPoint: Offset.zero,
            endPoint: u * 3,
            thickness: .385,
            layers: layers,
            referenceLine: reference,
            exteriorSide: side,
          );
          for (final turn in [-1, 1]) {
            final nextDirection = Offset(-u.dy, u.dx) * turn.toDouble();
            final attachment = ArchitectWallAttachment(
              source,
              reference,
              continuation: true,
            );
            expect(
              attachment.sideFor(
                source.endPoint,
                source.endPoint + nextDirection * 3,
                .385,
                .12,
              ),
              side,
            );
          }
        }
      }
    }
  });

  test('Translation aligns cores despite different finish build-ups', () {
    const target = ArchitectWall(
      id: 'target',
      startPoint: Offset.zero,
      endPoint: Offset(4, 0),
      thickness: .385,
      layers: layers,
    );
    const moving = ArchitectWall(
      id: 'moving',
      startPoint: Offset(0, 2),
      endPoint: Offset(4, 2),
      thickness: .25,
    );
    final model = project([target, moving]);
    final snap = ArchitectSnapHelper.snapTranslation(
      project: model,
      elementIds: {'moving'},
      delta: const Offset(0, -1.998),
      tolerance: .01,
      wallCoresOnly: true,
    );
    expect(snap.isSnapped, isTrue);
    expect(snap.point.dy, closeTo(-2, 1e-9));
    final alignment = ArchitectWallAlignment.move(
      [target, moving],
      {'moving'},
      const Offset(0, -1.998),
      1000,
      coreOnly: true,
    );
    expect(alignment.$1.dy, closeTo(-2, 1e-9));
  });

  test('Two-point Drag uses core geometry for both picks', () {
    const host = ArchitectWall(
      id: 'host',
      startPoint: Offset.zero,
      endPoint: Offset(4, 0),
      thickness: .385,
      layers: layers,
    );
    const moving = ArchitectWall(
      id: 'moving',
      startPoint: Offset(0, 2),
      endPoint: Offset(4, 2),
      thickness: .385,
      layers: layers,
    );
    final model = project([host, moving]);
    final drag = ArchitectDragController();
    addTearDown(drag.dispose);
    drag.startDrag(elementIds: {'moving'}, storeyId: 's');
    final coreFace =
        moving.coreCenterStart +
        moving.unitVector * 2 +
        moving.exteriorNormal * moving.coreThickness / 2;
    drag.updateBaseHover(
      coreFace,
      project: model,
      scale: 1000,
      snapToDefaultGrip: false,
    );
    expect((drag.currentPointModel! - coreFace).distance, lessThan(1e-9));
    drag.grabBasePoint(drag.currentPointModel!);
    final target =
        host.coreCenterStart +
        host.unitVector * 2 +
        host.exteriorNormal * host.coreThickness / 2;
    drag.updateTargetHover(
      target + const Offset(0, .003),
      project: model,
      scale: 1000,
    );
    expect((drag.currentPointModel! - target).distance, lessThan(1e-9));
    expect(drag.deltaModel!.dy, closeTo(-2, 1e-9));
  });

  for (final locked in [true, false]) {
    test(
      'Endpoint ${locked ? 'locked' : 'unlocked'} ignores insulation and plaster',
      () {
        const host = ArchitectWall(
          id: 'host',
          startPoint: Offset(4, -2),
          endPoint: Offset(4, 2),
          thickness: .385,
          layers: layers,
        );
        const wall = ArchitectWall(
          id: 'draft',
          startPoint: Offset.zero,
          endPoint: Offset(2, 0),
          thickness: .25,
        );
        final model = project([host]);
        final finish =
            host.centerPointAt(.5) + host.exteriorNormal * host.thickness / 2;
        final rejected = ArchitectWallEndpointSnap.resolve(
          wall: wall,
          atStart: false,
          raw: finish,
          snapProject: model,
          scale: 10000,
          angleLocked: locked,
        );
        expect(
          rejected.snapLabel,
          isNot(anyOf('Endpoint', 'Intersection', 'Edge', 'Midpoint')),
        );
        final core =
            host.coreCenterStart +
            host.unitVector * 2 +
            host.exteriorNormal * host.coreThickness / 2;
        final snap = ArchitectWallEndpointSnap.resolve(
          wall: wall,
          atStart: false,
          raw: core + const Offset(.0001, 0),
          snapProject: model,
          scale: 10000,
          angleLocked: locked,
        );
        expect((snap.point - core).distance, lessThan(.0001));
      },
    );
  }
}
