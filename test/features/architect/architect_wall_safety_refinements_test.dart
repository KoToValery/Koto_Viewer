import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_connection_policy.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_exterior_resolver.dart';
import 'package:kotoview/src/features/architect/services/architect_chamfer_fillet.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_element_group_test.dart' as groups;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_wall_operation_axis_test.dart' as geometry;
import 'architect_hatch_editing_regression_test.dart' as hatches;

void main() {
  for (final curved in [false, true]) {
    for (final reference in WallReferenceLine.values) {
      test(
        'Reference keeps physical skins and openings: $curved / $reference',
        () {
          final wall = geometry
              .physicalWall(
                'a',
                Offset.zero,
                const Offset(8, 0),
                WallReferenceLine.outer,
              )
              .copyWith(
                arcBulge: curved ? .25 : 0,
                doors: const [
                  ArchitectDoor(
                    id: 'd',
                    wallId: 'a',
                    uuid: 'd',
                    offsetRatio: .5,
                  ),
                ],
              );
          final model = editing.seeded(
            ArchitectStorey(id: 's', name: '', walls: [wall]),
          );
          addTearDown(model.dispose);
          final before = model.project;
          model.execute(
            SetArchitectElementProperties(
              storeyId: 's',
              elementIds: {'a'},
              textValues: {'referenceLine': reference.name},
            ),
          );
          final next = model.project.activeStorey.walls.single;
          for (var i = 0; i < wall.polygonCorners.length; i++) {
            geometry.near(next.polygonCorners[i], wall.polygonCorners[i]);
          }
          geometry.near(
            next.centerPointAt(next.doors.single.offsetRatio),
            wall.centerPointAt(.5),
          );
          expect(next.referenceLine, reference);
          if (reference != wall.referenceLine) {
            model.undo();
            expect(model.project, same(before));
            model.redo();
            expect(
              model.project.activeStorey.walls.single.toJson(),
              next.toJson(),
            );
          }
        },
      );
    }
  }
  test(
    'A simultaneous reference and radius edit keeps the explicitly typed radius',
    () {
      final wall = geometry
          .physicalWall(
            'a',
            Offset.zero,
            const Offset(8, 0),
            WallReferenceLine.center,
          )
          .copyWith(arcBulge: .25);
      final radius = wall.arc!.radius * 1.3;
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [wall]),
      );
      addTearDown(model.dispose);
      final next = SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'a'},
        values: {'arcRadius': radius},
        textValues: {'referenceLine': 'outer'},
      ).apply(model.project).activeStorey.walls.single;
      expect(next.referenceLine, WallReferenceLine.outer);
      expect(next.arc!.radius, closeTo(radius, 1e-8));
    },
  );
  test('Reference opt-out retains the saved line', () {
    final wall = geometry.physicalWall(
      'a',
      Offset.zero,
      const Offset(4, 0),
      WallReferenceLine.center,
    );
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: '', walls: [wall]),
    );
    addTearDown(model.dispose);
    final next = const SetArchitectElementProperties(
      storeyId: 's',
      elementIds: {'a'},
      textValues: {'referenceLine': 'outer'},
      preserveWallPosition: false,
    ).apply(model.project).activeStorey.walls.single;
    expect(next.startPoint, wall.startPoint);
    expect(
      (next.coreCenterStart - wall.coreCenterStart).distance,
      greaterThan(.01),
    );
  });
  test(
    'Core clearance ignores finishes, both references and reversed direction',
    () {
      for (final ref in WallReferenceLine.values) {
        final a = geometry.physicalWall(
          'a',
          Offset.zero,
          const Offset(4, 0),
          ref,
        );
        final b = geometry.reversed(
          geometry.physicalWall(
            'b',
            const Offset(0, 4),
            const Offset(4, 4),
            ref,
          ),
        );
        final gap = ArchitectWallClearance.nearest(a, [a, b]).single;
        expect(gap.distance, closeTo(3.75, 1e-8));
        expect(gap.start.dy, closeTo(.125, 1e-8));
        expect(gap.end.dy, closeTo(3.875, 1e-8));
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: '', walls: [a, b]),
        );
        final next = const SetArchitectWallClearance(
          storeyId: 's',
          wallId: 'a',
          neighborId: 'b',
          distance: 3,
        ).apply(model.project);
        expect(
          ArchitectWallClearance.nearest(
            next.activeStorey.walls.first,
            next.activeStorey.walls,
          ).single.distance,
          closeTo(3, 1e-8),
        );
        model.dispose();
      }
    },
  );
  test('T Attach never moves the host to its distant connected corner', () {
    final host = editing.wall('host', Offset.zero, const Offset(12, 0));
    final far = editing.wall('far', const Offset(12, 0), const Offset(12, 4));
    final stem = editing
        .wall('stem', const Offset(4, 0), const Offset(4, 3))
        .copyWith(connectStart: false, connectEnd: false);
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: '', walls: [host, far, stem]),
    );
    addTearDown(model.dispose);
    model.execute(
      const AttachArchitectWalls(storeyId: 's', wallIds: {'host', 'stem'}),
    );
    for (final old in [host, far, stem]) {
      final next = model.project.activeStorey.walls.firstWhere(
        (w) => w.id == old.id,
      );
      geometry.near(next.coreCenterStart, old.coreCenterStart);
      geometry.near(next.coreCenterEnd, old.coreCenterEnd);
    }
    expect(model.project.activeStorey.walls.last.isDetached, isFalse);
  });
  test(
    'Attach refuses gaps; curved and collinear end contacts stay finite',
    () {
      const a = ArchitectWall(
        id: 'a',
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
      );
      const b = ArchitectWall(
        id: 'b',
        startPoint: Offset(4.01, 0),
        endPoint: Offset(8, 0),
      );
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', walls: [a, b]),
      );
      addTearDown(model.dispose);
      expect(
        () => const AttachArchitectWalls(
          storeyId: 's',
          wallIds: {'a', 'b'},
        ).apply(model.project),
        throwsArgumentError,
      );
      expect(
        ArchitectWallConnectionPolicy.touches(
          a,
          b.copyWith(startPoint: const Offset(4, 0)),
        ),
        isTrue,
      );
      final arc = a.copyWith(arcBulge: .4);
      expect(
        ArchitectWallConnectionPolicy.touches(
          arc,
          b.copyWith(startPoint: const Offset(4, 0)),
        ),
        isTrue,
      );
    },
  );
  test(
    'Temporary Detach releases after move, persists and restores with Undo',
    () {
      final a = editing.wall('a', Offset.zero, const Offset(4, 0));
      final b = editing.wall('b', const Offset(4, 0), const Offset(4, 4));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [a, b]),
      );
      addTearDown(model.dispose);
      model.execute(
        const SetArchitectWallConnection(
          storeyId: 's',
          wallIds: {'a'},
          connected: false,
          temporary: true,
        ),
      );
      final detached = model.project;
      expect(
        ArchitectProject.fromJson(
          detached.toJson(),
        ).activeStorey.walls.first.autoAttachAfterMove,
        isTrue,
      );
      final zero = const MoveArchitectElements(
        storeyId: 's',
        elementIds: {'a'},
        delta: Offset.zero,
      ).apply(detached);
      expect(zero.activeStorey.walls.first.isDetached, isTrue);
      model.execute(
        const MoveArchitectElements(
          storeyId: 's',
          elementIds: {'a'},
          delta: Offset(0, 1),
        ),
      );
      final next = model.project.activeStorey.walls;
      expect(next.first.autoAttachAfterMove, isFalse);
      expect(next.first.isDetached, isFalse);
      expect(next.last.startPoint, b.startPoint);
      expect(next.last.endPoint, b.endPoint);
      model.undo();
      expect(model.project, same(detached));
      model.redo();
      expect(
        model.project.activeStorey.walls.first.autoAttachAfterMove,
        isFalse,
      );
      final permanent = const SetArchitectWallConnection(
        storeyId: 's',
        wallIds: {'a'},
        connected: false,
      ).apply(detached);
      final moved = const MoveArchitectElements(
        storeyId: 's',
        elementIds: {'a'},
        delta: Offset(0, 1),
      ).apply(permanent);
      expect(moved.activeStorey.walls.first.isDetached, isTrue);
    },
  );
  test(
    'Endpoint relocation releases temporary Detach; property edits do not',
    () {
      final a = editing
          .wall('a', Offset.zero, const Offset(4, 0))
          .copyWith(
            connectStart: false,
            connectEnd: false,
            autoAttachAfterMove: true,
          );
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: '',
          walls: [a, editing.wall('b', const Offset(5, 0), const Offset(5, 4))],
        ),
      );
      addTearDown(model.dispose);
      final property = const SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'a'},
        values: {'height': 3.2},
      ).apply(model.project).activeStorey.walls.first;
      expect(property.autoAttachAfterMove, isTrue);
      final candidate = UpdateArchitectWall(
        storeyId: 's',
        wall: a.copyWith(endPoint: const Offset(5, 0)),
      ).apply(model.project);
      expect(candidate.activeStorey.walls.first.autoAttachAfterMove, isFalse);
      expect(candidate.activeStorey.walls.first.connectEnd, isTrue);
      expect(
        model.project.activeStorey.walls.first.autoAttachAfterMove,
        isTrue,
      );
    },
  );
  test(
    'End clearance uses core faces through an insulated physical support',
    () {
      final support = geometry.physicalWall(
        'support',
        Offset.zero,
        const Offset(10, 0),
        WallReferenceLine.outer,
      );
      final a = geometry.physicalWall(
        'a',
        const Offset(2, 0),
        const Offset(2, 4),
        WallReferenceLine.inner,
      );
      final b = geometry.physicalWall(
        'b',
        const Offset(8, 0),
        const Offset(8, 4),
        WallReferenceLine.outer,
      );
      final walls = [support, a, b];
      final gap = ArchitectWallClearance.endpoints(
        a,
        walls,
        includeParallel: true,
      ).firstWhere((g) => g.neighborId == 'b');
      expect(gap.distance, closeTo(5.75, 1e-8));
      expect(gap.start.dx, closeTo(2.125, 1e-8));
      expect(gap.end.dx, closeTo(7.875, 1e-8));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: walls),
      );
      addTearDown(model.dispose);
      final next = SetArchitectWallEndpointClearance(
        storeyId: 's',
        wallId: 'a',
        neighborId: 'b',
        supportId: 'support',
        atStart: true,
        distance: 4.5,
      ).apply(model.project);
      final resized = next.activeStorey.walls.firstWhere((w) => w.id == 'a');
      final result = ArchitectWallClearance.endpoints(
        resized,
        next.activeStorey.walls,
        includeParallel: true,
      ).firstWhere((g) => g.neighborId == 'b' && g.atStart == true);
      expect(result.distance, closeTo(4.5, 1e-7));
      geometry.near(
        next.activeStorey.walls.last.coreCenterStart,
        b.coreCenterStart,
      );
    },
  );
  test(
    'Corner refuses conflicting manual exterior sides and impossible contour values',
    () {
      final a = geometry.physicalWall(
        'a',
        Offset.zero,
        const Offset(4, 0),
        WallReferenceLine.center,
      );
      final b = geometry.physicalWall(
        'b',
        const Offset(4, 0),
        const Offset(4, 4),
        WallReferenceLine.center,
      );
      expect(
        ArchitectChamferFillet.wallPairFillet(
          a,
          b.copyWith(exteriorSide: WallExteriorSide.right),
          radius: .5,
        ),
        isNull,
      );
      expect(
        ArchitectChamferFillet.polygonChamfer(hatches.outer, distance: 100),
        hatches.outer,
      );
      expect(
        ArchitectChamferFillet.polygonFillet(hatches.outer, radius: 100),
        hatches.outer,
      );
    },
  );
  test('A moved detached wall waits across a gap until finite contact', () {
    final a = editing
        .wall('a', Offset.zero, const Offset(4, 0))
        .copyWith(
          connectStart: false,
          connectEnd: false,
          autoAttachAfterMove: true,
        );
    final b = editing.wall('b', const Offset(4.01, 1), const Offset(8, 1));
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: '', walls: [a, b]),
    );
    addTearDown(model.dispose);
    final moved = const MoveArchitectElements(
      storeyId: 's',
      elementIds: {'a'},
      delta: Offset(0, 1),
    ).apply(model.project);
    expect(moved.activeStorey.walls.first.isDetached, isTrue);
    expect(moved.activeStorey.walls.first.autoAttachAfterMove, isTrue);
    final joined = const MoveArchitectElements(
      storeyId: 's',
      elementIds: {'a'},
      delta: Offset(.01, 0),
    ).apply(moved);
    expect(joined.activeStorey.walls.first.isDetached, isFalse);
    expect(joined.activeStorey.walls.first.autoAttachAfterMove, isFalse);
    expect(joined.activeStorey.walls.last.startPoint, b.startPoint);
  });
  test('Prepared corner connectors keep the resolved exterior at both ends', () {
    const points = [Offset(0, 0), Offset(6, 0), Offset(6, 5), Offset(0, 5)];
    for (final fillet in [false, true]) {
      for (final reverse in [false, true]) {
        for (final swap in [false, true]) {
          final walls = [
            for (var i = 0; i < 4; i++)
              ArchitectWall(
                id: 'w$i',
                startPoint: points[i],
                endPoint: points[(i + 1) % 4],
                thickness: .37,
                insulationThicknessOverride: .12,
              ),
          ];
          final model = editing.seeded(
            ArchitectWallExteriorResolver.resolveStorey(
              ArchitectStorey(id: 's', name: '', walls: walls),
            ),
          );
          model.commit(model.project);
          final floor = model.project.activeStorey;
          var a = floor.walls[0], b = floor.walls[1];
          if (reverse) {
            a = geometry.reversed(a);
            b = geometry.reversed(b);
          }
          if (swap) {
            final old = a;
            a = b;
            b = old;
          }
          final result = fillet
              ? ArchitectChamferFillet.wallPairFillet(a, b, radius: .7)!
              : ArchitectChamferFillet.wallPairChamfer(a, b, distance: .7)!;
          final prepared = model.prepare(
            model.project.updateActiveStorey(
              floor.copyWith(
                walls: [
                  for (final wall in floor.walls)
                    if (wall.id == a.id)
                      result.wallA
                    else if (wall.id == b.id)
                      result.wallB
                    else
                      wall,
                  result.connector,
                ],
              ),
            ),
          );
          final connector = prepared.activeStorey.walls.last;
          final first = connector.normalAt(0) * connector.exteriorSign;
          final last = connector.normalAt(1) * connector.exteriorSign;
          expect(
            first.dx * a.exteriorNormal.dx + first.dy * a.exteriorNormal.dy,
            greaterThan(.5),
            reason:
                "fillet=$fillet reverse=$reverse swap=$swap A=${a.exteriorSide} B=${b.exteriorSide} before=${result.connector.exteriorSide} after=${connector.exteriorSide}",
          );
          expect(
            last.dx * b.exteriorNormal.dx + last.dy * b.exteriorNormal.dy,
            greaterThan(.5),
            reason:
                "fillet=$fillet reverse=$reverse swap=$swap A=${a.exteriorSide} B=${b.exteriorSide} before=${result.connector.exteriorSide} after=${connector.exteriorSide}",
          );
          model.dispose();
        }
      }
    }
  });
  for (final language in ['bg', 'en']) {
    testWidgets(
      'Phone single Mirror preview toggles without copies accumulating: $language',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final wall = editing
            .wall('a', const Offset(2, -2), const Offset(2, 2))
            .copyWith(
              doors: const [
                ArchitectDoor(
                  id: 'door',
                  wallId: 'a',
                  uuid: 'door',
                  offsetRatio: .25,
                ),
              ],
            );
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: '', walls: [wall]),
        );
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();
        workspace.camera(tester).fit(const Rect.fromLTRB(-5, -4, 5, 4));
        await tester.pumpAndSettle();
        await editing.contextHold(tester, const Offset(2, 1.5));
        expect(
          find.text(
            lookupAppLocalizations(Locale(language)).architectMirrorCopy,
          ),
          findsNothing,
        );
        await groups.action(tester, BimEditAction.mirrorMove);
        await tester.tapAt(workspace.screen(tester, Offset.zero));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-mirror-vertical-btn')),
        );
        await tester.pumpAndSettle();
        expect(model.undoCount, 0);
        String? copyId, doorId;
        for (var i = 0; i < 5; i++) {
          await tester.tap(
            find.byKey(const ValueKey('architect-mirror-keep-original')),
          );
          await tester.pumpAndSettle();
          final walls = workspace.overlay(tester).project.activeStorey.walls;
          expect(walls, hasLength(i.isEven ? 2 : 1));
          if (i.isEven) {
            copyId ??= walls.last.id;
            expect(walls.last.id, copyId);
            doorId ??= walls.last.doors.single.id;
            expect(walls.last.doors.single.id, doorId);
            expect(walls.last.doors.single.wallId, copyId);
          }
          expect(model.project.activeStorey.walls, hasLength(1));
        }
        expect(
          find.byKey(const ValueKey('architect-command-apply')),
          findsOneWidget,
        );
        final rect = tester.getRect(
          find.byKey(const ValueKey('architect-command-apply')),
        );
        expect(rect.right, lessThanOrEqualTo(360));
        await editing.acceptGeometryCommand(tester);
        expect(model.project.activeStorey.walls, hasLength(2));
        expect(model.undoCount, 1);
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls, hasLength(1));
        model.redo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls.last.id, copyId);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'Phone T Attach preserves both walls and the distant corner: $language',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final host = editing.wall('host', Offset.zero, const Offset(12, 0));
        final far = editing.wall(
          'far',
          const Offset(12, 0),
          const Offset(12, 4),
        );
        final stem = editing
            .wall('stem', const Offset(4, 0), const Offset(4, 3))
            .copyWith(connectStart: false, connectEnd: false);
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: '', walls: [host, far, stem]),
        );
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();
        workspace.camera(tester).fit(const Rect.fromLTRB(-2, -2, 14, 6));
        await tester.pumpAndSettle();
        await editing.contextHold(tester, const Offset(4, 2));
        await groups.action(tester, BimEditAction.attach);
        await tester.tapAt(workspace.screen(tester, const Offset(1, 0)));
        await tester.pumpAndSettle();
        expect(model.undoCount, 0);
        await editing.acceptGeometryCommand(tester);
        expect(model.undoCount, 1);
        for (final wall in [host, far, stem]) {
          final next = model.project.activeStorey.walls.firstWhere(
            (w) => w.id == wall.id,
          );
          geometry.near(next.coreCenterStart, wall.coreCenterStart);
          geometry.near(next.coreCenterEnd, wall.coreCenterEnd);
        }
        expect(model.project.activeStorey.walls.last.isDetached, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'Phone Detach has one confirmation and Hatch starts with locked movement: $language',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: '',
            walls: [editing.wall('a', Offset.zero, const Offset(4, 0))],
          ),
        );
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();
        await editing.contextHold(tester, const Offset(2, 0));
        await groups.action(tester, BimEditAction.detach);
        await editing.acceptGeometryCommand(tester);
        expect(
          model.project.activeStorey.walls.single.autoAttachAfterMove,
          isTrue,
        );
        expect(model.undoCount, 1);
        expect(
          find.byKey(const ValueKey('architect-command-apply')),
          findsNothing,
        );
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls.single.isDetached, isFalse);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        final hatchModel = hatches.hatchModel();
        addTearDown(hatchModel.dispose);
        await workspace.open(tester, hatchModel);
        await tester.tapAt(workspace.screen(tester, const Offset(1, 1)));
        await tester.pumpAndSettle();
        final pull = find.byKey(const ValueKey('polygon-edge-pull'));
        expect(
          tester
              .widget<AppIcon>(
                find.descendant(of: pull, matching: find.byType(AppIcon)),
              )
              .id,
          AppIconId.edgePull,
        );
        final ids = [
          for (final mode in ['pull', 'move'])
            tester
                .widget<AppIcon>(
                  find.descendant(
                    of: find.byKey(ValueKey('polygon-edge-$mode')),
                    matching: find.byType(AppIcon),
                  ),
                )
                .id,
        ];
        expect(ids.toSet(), hasLength(2));
        expect(
          find.byKey(const ValueKey('polygon-edge-extendCatheti')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('architect-polygon-angle-lock')),
          findsOneWidget,
        );
        final move = find.byKey(const ValueKey('polygon-edge-move'));
        expect(
          tester
              .widget<AppIcon>(
                find.descendant(of: move, matching: find.byType(AppIcon)),
              )
              .color,
          Theme.of(tester.element(move)).colorScheme.primary,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
