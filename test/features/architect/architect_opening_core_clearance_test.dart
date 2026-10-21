import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_opening_continuous_placement_test.dart' as openings;
import 'architect_manual_selection_test.dart' as selection;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  test(
    'End junctions use core faces for bare, insulated and layered walls',
    () {
      for (final angle in [0.0, math.pi / 2, .6]) {
        Offset turn(Offset p) => Offset(
          p.dx * math.cos(angle) - p.dy * math.sin(angle),
          p.dx * math.sin(angle) + p.dy * math.cos(angle),
        );
        for (final layered in [false, true]) {
          for (final insulation in [0.0, .12, .20]) {
            for (final side in WallExteriorSide.values) {
              final host = ArchitectWall(
                id: 'host',
                startPoint: turn(Offset.zero),
                endPoint: turn(const Offset(8, 0)),
                thickness: .37,
                insulationThicknessOverride: .12,
              );
              final crossing = ArchitectWall(
                id: 'cross',
                startPoint: turn(Offset.zero),
                endPoint: turn(const Offset(0, 4)),
                thickness: .25 + insulation,
                insulationThicknessOverride: insulation,
                exteriorSide: side,
                layers: layered
                    ? [
                        if (insulation > 0)
                          ArchitectMaterialLayer(
                            id: 'eps',
                            material: ArchitectMaterial.eps,
                            role: ArchitectLayerRole.insulation,
                            thickness: insulation,
                          ),
                        const ArchitectMaterialLayer(
                          id: 'brick',
                          material: ArchitectMaterial.brick,
                          role: ArchitectLayerRole.core,
                          thickness: .25,
                        ),
                      ]
                    : const [],
              );
              final end = crossing.copyWith(
                id: 'end',
                startPoint: turn(const Offset(8, 0)),
                endPoint: turn(const Offset(8, 4)),
              );
              final gaps = ArchitectOpeningClearance.forOpening(
                wall: host,
                walls: [host, crossing, end],
                openingId: 'opening',
                offsetRatio: .5,
                openingWidth: 1,
              );
              for (final gap in gaps) {
                expect(gap.distance, closeTo(3.375, 1e-6));
                expect(
                  gap.boundaryKind,
                  ArchitectOpeningBoundaryKind.intersectingWall,
                );
                expect(gap.referenceElementId, gap.isLeft ? 'cross' : 'end');
              }
            }
          }
        }
      }
    },
  );

  test('Angled insulated core reference is on the actual masonry face', () {
    const host = ArchitectWall(
      id: 'host',
      startPoint: Offset.zero,
      endPoint: Offset(8, 0),
      thickness: .37,
      insulationThicknessOverride: .12,
    );
    final cross = ArchitectWall(
      id: 'cross',
      startPoint: const Offset(4, 0),
      endPoint: const Offset(7, 3),
      thickness: .45,
      insulationThicknessOverride: .20,
    );
    final gap = ArchitectOpeningClearance.forOpening(
      wall: host,
      walls: [host, cross],
      openingId: 'opening',
      offsetRatio: .2,
      openingWidth: 1,
    ).last;
    expect(gap.distance, closeTo(4 - .125 * math.sqrt2 - 2.1, 1e-6));
    final delta = gap.referencePoint - cross.coreCenterStart;
    expect(
      (delta.dx * cross.normalVector.dx + delta.dy * cross.normalVector.dy)
          .abs(),
      closeTo(.125, 1e-6),
    );
  });

  test(
    'Editing a clearance from an insulated corner preserves neighboring openings and Undo',
    () {
      const window = ArchitectWindow(
        id: 'window',
        wallId: 'host',
        uuid: 'window',
        offsetRatio: .25,
        width: 1,
      );
      const neighbor = ArchitectDoor(
        id: 'door',
        wallId: 'host',
        uuid: 'door',
        offsetRatio: .75,
        width: 1,
      );
      final host = ArchitectWall(
        id: 'host',
        startPoint: Offset.zero,
        endPoint: const Offset(8, 0),
        windows: const [window],
        doors: const [neighbor],
      );
      const cross = ArchitectWall(
        id: 'cross',
        startPoint: Offset.zero,
        endPoint: Offset(0, 4),
        thickness: .37,
        insulationThicknessOverride: .12,
      );
      final model = openings.seededController(walls: [host, cross]);
      addTearDown(model.dispose);
      final before = model.project;
      model.execute(
        const SetArchitectOpeningClearance(
          storeyId: 's',
          wallId: 'host',
          openingId: 'window',
          isLeft: true,
          distance: .75,
        ),
      );
      final after = model.project.activeStorey.walls.first;
      expect(
        after.windows.single.offsetRatio * 8 - .5,
        closeTo(.125 + .75, 1e-6),
      );
      final gaps = ArchitectOpeningClearance.forOpening(
        wall: after,
        walls: model.project.activeStorey.walls,
        openingId: 'window',
        offsetRatio: after.windows.single.offsetRatio,
        openingWidth: 1,
      );
      expect(gaps.first.distance, closeTo(.75, 1e-6));
      expect(
        gaps.last.boundaryKind,
        ArchitectOpeningBoundaryKind.neighborOpening,
      );
      expect(after.doors.single, same(neighbor));
      model.undo();
      expect(model.project, same(before));
    },
  );

  for (final door in [false, true]) {
    testWidgets(
      'Selected ${door ? 'door' : 'window'} clearance shrinks with zoom and stays editable',
      (tester) async {
        final host = ArchitectWall(
          id: 'host',
          startPoint: Offset.zero,
          endPoint: const Offset(8, 0),
          windows: door
              ? const []
              : const [
                  ArchitectWindow(
                    id: 'opening',
                    wallId: 'host',
                    uuid: 'opening',
                    offsetRatio: .5,
                    width: 1,
                  ),
                ],
          doors: door
              ? const [
                  ArchitectDoor(
                    id: 'opening',
                    wallId: 'host',
                    uuid: 'opening',
                    offsetRatio: .5,
                    width: 1,
                  ),
                ]
              : const [],
        );
        const cross = ArchitectWall(
          id: 'cross',
          startPoint: Offset.zero,
          endPoint: Offset(0, 4),
          thickness: .37,
          insulationThicknessOverride: .12,
        );
        final model = openings.seededController(walls: [host, cross]);
        addTearDown(model.dispose);
        await openings.openWorkspace(tester, model);
        await selection.selectTool(tester);
        final camera = workspace.camera(tester);
        camera.fit(const Rect.fromLTWH(-1, -2, 10, 6));
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(4, 0));
        await tester.pumpAndSettle();
        final badge = find.byKey(
          const ValueKey('opening-clearance-opening-left'),
        );
        expect(badge, findsOneWidget);
        expect(
          find.descendant(
            of: badge,
            matching: find.text(model.project.formatLength(3.375)),
          ),
          findsOneWidget,
        );
        for (final scale in [100.0, 50.0, 20.0]) {
          final focal = camera.size.center(Offset.zero);
          camera.navigate(
            previousFocal: focal,
            focal: focal,
            scaleFactor: scale / camera.scale,
          );
          await tester.pumpAndSettle();
          final size = tester.getSize(badge);
          expect(size.width / camera.scale, closeTo(.88, 1e-6));
          expect(size.height / camera.scale, closeTo(.36, 1e-6));
        }
        final focal = camera.size.center(Offset.zero);
        camera.navigate(
          previousFocal: focal,
          focal: focal,
          scaleFactor: 100 / camera.scale,
        );
        await tester.pumpAndSettle();
        await tester.tap(badge);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
