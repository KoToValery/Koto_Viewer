import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  for (final oldReference in WallReferenceLine.values) {
    test(
      'Physical face determines reference and clean layers from $oldReference',
      () {
        final source = editing
            .wall('old', Offset.zero, const Offset(4, 0), exterior: true)
            .copyWith(referenceLine: oldReference);
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: 's', walls: [source]),
        );
        addTearDown(model.dispose);
        final midpoint = (source.centerStart + source.centerEnd) / 2;
        for (final face in [
          (
            WallReferenceLine.inner,
            midpoint - source.exteriorNormal * source.thickness / 2,
          ),
          (
            WallReferenceLine.outer,
            midpoint + source.exteriorNormal * source.thickness / 2,
          ),
          (
            WallReferenceLine.center,
            (source.coreCenterStart + source.coreCenterEnd) / 2,
          ),
        ]) {
          final snap = ArchitectWallSnap.resolve(
            raw: face.$2 + const Offset(.003, .001),
            project: model.project,
            scale: 1000,
          );
          expect(snap.wallAttachment?.reference, face.$1);
          expect(snap.wallAttachment?.source.id, source.id);
          for (final direction in [const Offset(0, -2), const Offset(0, 2)]) {
            final next = editing
                .wall('new', snap.point, snap.point + direction, exterior: true)
                .copyWith(
                  referenceLine: snap.wallAttachment!.reference,
                  exteriorSide: snap.wallAttachment!.sideFor(
                    snap.point,
                    snap.point + direction,
                    .37,
                    .12,
                  ),
                );
            final layers = ArchitectWallLayers.build([source, next], []);
            expect(layers.body.computeMetrics().length, 1);
            expect(layers.core.computeMetrics().length, 1);
            final saved = ArchitectWall.fromJson(next.toJson());
            expect(saved.referenceLine, face.$1);
          }
        }
      },
    );
  }
  test(
    'Clearance uses finished faces, overlapping length and nearest wall on each side',
    () {
      final a = editing.wall(
        'a',
        Offset.zero,
        const Offset(4, 0),
        exterior: true,
      );
      final b = editing.wall(
        'b',
        const Offset(4, 3),
        const Offset(0, 3),
        exterior: true,
      );
      final c = editing.wall('c', const Offset(0, -2), const Offset(4, -2));
      final d = editing.wall('far', const Offset(0, 6), const Offset(4, 6));
      final e = editing.wall(
        'unfaced',
        const Offset(8, 1),
        const Offset(10, 1),
      );
      final gaps = ArchitectWallClearance.nearest(a, [a, b, c, d, e]);
      expect(gaps.map((g) => g.neighborId).toSet(), {'b', 'c'});
      expect(gaps.first.distance, closeTo(1.75, 1e-9));
      expect(gaps.last.distance, closeTo(2.51, 1e-9));
      for (final gap in gaps) {
        expect((gap.end - gap.start).distance, closeTo(gap.distance, 1e-9));
      }
    },
  );
  test(
    'Setting clearance moves selected wall and openings; support stays fixed; Undo is atomic',
    () {
      final a = editing
          .wall('a', Offset.zero, const Offset(4, 0), exterior: true)
          .addDoor(
            const ArchitectDoor(
              id: 'd',
              wallId: 'a',
              offsetRatio: .5,
              uuid: 'd',
            ),
          );
      final b = editing.wall(
        'b',
        const Offset(0, 3),
        const Offset(4, 3),
        exterior: true,
      );
      final support = editing.wall(
        'support',
        const Offset(0, -4),
        const Offset(0, 6),
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [a, b, support]),
      );
      addTearDown(model.dispose);
      final old = model.project;
      model.execute(
        const SetArchitectWallClearance(
          storeyId: 's',
          wallId: 'a',
          neighborId: 'b',
          distance: 2,
        ),
      );
      final walls = model.project.activeStorey.walls;
      expect(walls[0].startPoint.dy, closeTo(.63, 1e-9));
      expect(walls[0].doors.single.offsetRatio, .5);
      expect(walls[1].toJson(), b.toJson());
      expect(walls[2].toJson(), support.toJson());
      expect(
        ArchitectWallClearance.nearest(walls[0], walls).single.distance,
        closeTo(2, 1e-9),
      );
      model.undo();
      expect(identical(model.project, old), isTrue);
      expect(
        () => model.execute(
          const SetArchitectWallClearance(
            storeyId: 's',
            wallId: 'a',
            neighborId: 'b',
            distance: -1,
          ),
        ),
        throwsArgumentError,
      );
    },
  );
  test('Rotated clearance has the same value and exact positioning', () {
    const angle = math.pi / 5;
    Offset rotate(Offset p) => Offset(
      p.dx * math.cos(angle) - p.dy * math.sin(angle),
      p.dx * math.sin(angle) + p.dy * math.cos(angle),
    );
    final a = editing.wall(
      'a',
      rotate(Offset.zero),
      rotate(const Offset(4, 0)),
    );
    final b = editing.wall(
      'b',
      rotate(const Offset(0, 3)),
      rotate(const Offset(4, 3)),
    );
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 's', walls: [a, b]),
    );
    addTearDown(model.dispose);
    expect(
      ArchitectWallClearance.nearest(a, [a, b]).single.distance,
      closeTo(2.75, 1e-9),
    );
    model.execute(
      const SetArchitectWallClearance(
        storeyId: 's',
        wallId: 'a',
        neighborId: 'b',
        distance: 1.25,
      ),
    );
    final walls = model.project.activeStorey.walls;
    expect(
      ArchitectWallClearance.nearest(walls[0], walls).single.distance,
      closeTo(1.25, 1e-9),
    );
  });
  test(
    'Trim chooses crossings, deletes only picked interval and preserves hosts',
    () {
      var a = editing
          .wall('a', Offset.zero, const Offset(6, 0), exterior: true)
          .copyWith(referenceLine: WallReferenceLine.inner);
      for (final entry in [('left', .1), ('middle', .5), ('right', .9)]) {
        a = a.addDoor(
          ArchitectDoor(
            id: entry.$1,
            wallId: 'a',
            offsetRatio: entry.$2,
            width: .8,
            uuid: entry.$1,
          ),
        );
      }
      final b = editing.wall('b', const Offset(2, -2), const Offset(2, 2));
      final c = editing.wall('c', const Offset(4, -2), const Offset(4, 2));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [a, b, c]),
      );
      addTearDown(model.dispose);
      final old = model.project;
      final span = ArchitectWallTrimSpan.at(a, [a, b, c], const Offset(3, 0));
      expect(span.from, closeTo(1 / 3, 1e-9));
      expect(span.to, closeTo(2 / 3, 1e-9));
      model.execute(
        const TrimArchitectWall(storeyId: 's', wallId: 'a', pick: Offset(3, 0)),
      );
      final walls = model.project.activeStorey.walls;
      expect(walls, hasLength(4));
      expect(walls[0].length, closeTo(2, 1e-9));
      expect(walls[1].startPoint, const Offset(4, 0));
      expect(walls[0].doors.single.id, 'left');
      expect(walls[1].doors.single.id, 'right');
      expect(walls[1].doors.single.wallId, walls[1].id);
      expect(walls[1].doors.single.offsetRatio, closeTo(.7, 1e-9));
      expect(walls[2].toJson(), b.toJson());
      model.undo();
      expect(identical(model.project, old), isTrue);
    },
  );
  test('Trim at opening boundary is rejected without changing any wall', () {
    final a = editing
        .wall('a', Offset.zero, const Offset(6, 0))
        .addDoor(
          const ArchitectDoor(
            id: 'd',
            wallId: 'a',
            offsetRatio: 1 / 3,
            width: .8,
            uuid: 'd',
          ),
        );
    final b = editing.wall('b', const Offset(2, -2), const Offset(2, 2));
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 's', walls: [a, b]),
    );
    addTearDown(model.dispose);
    final old = model.project;
    expect(
      () => model.execute(
        const TrimArchitectWall(storeyId: 's', wallId: 'a', pick: Offset(4, 0)),
      ),
      throwsArgumentError,
    );
    expect(identical(model.project, old), isTrue);
  });
  testWidgets(
    'Quick touch neither selects nor moves; swipe pans; hold enables editing',
    (tester) async {
      final a = editing.wall('a', Offset.zero, const Offset(4, 0));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [a]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.ensureVisible(find.byIcon(Icons.pan_tool_rounded));
      await tester.tap(find.byIcon(Icons.pan_tool_rounded));
      await tester.pumpAndSettle();
      final old = model.project;
      await workspace.wallTap(tester, const Offset(2, 0));
      expect(workspace.overlay(tester).selectedElementId, isNull);
      final translation = workspace.camera(tester).translation;
      final swipe = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 0)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await swipe.moveBy(const Offset(40, 0));
      await swipe.up();
      await tester.pump();
      expect(workspace.camera(tester).translation, isNot(translation));
      expect(identical(model.project, old), isTrue);
      await editing.selectTool(tester, 'wall');
      await editing.hold(tester, const Offset(2, 0));
      final jitter = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 0)),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await jitter.moveBy(const Offset(1, 1));
      await jitter.up();
      await tester.pump();
      expect(identical(model.project, old), isTrue);
      final hold = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 0)),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await hold.moveTo(workspace.screen(tester, const Offset(2, 1)));
      await tester.pump();
      expect(identical(model.project, old), isTrue);
      expect(
        workspace.overlay(tester).project.activeStorey.walls.single.startPoint,
        const Offset(0, 1),
      );
      await hold.up();
      await tester.pump();
      expect(
        model.project.activeStorey.walls.single.startPoint,
        const Offset(0, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Draft inherits an inner face; click clearance opens local keypad and repositions',
    (tester) async {
      final a = editing.wall(
        'a',
        Offset.zero,
        const Offset(4, 0),
        exterior: true,
      );
      final b = editing.wall(
        'b',
        const Offset(0, 3),
        const Offset(4, 3),
        exterior: true,
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [a, b]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(2, -.125));
      expect(
        workspace.overlay(tester).activeWallReference,
        WallReferenceLine.inner,
      );
      await workspace.wallTap(tester, const Offset(2, -2));
      expect(
        workspace.overlay(tester).activeWallReference,
        WallReferenceLine.inner,
      );
      // Cancel the draft before selecting the original wall.
      await tester.tap(find.byIcon(Icons.pan_tool_rounded));
      await tester.pumpAndSettle();
      await editing.selectTool(tester, 'wall');
      await editing.hold(tester, const Offset(1, 0));
      expect(find.byKey(const ValueKey('wall-clearance-b')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wall-clearance-b')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      for (final key in ['2', '.', '0']) {
        await tester.tap(find.byKey(ValueKey('wall-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.walls[0].startPoint.dy,
        closeTo(.63, 1e-9),
      );
      expect(model.project.activeStorey.walls[1].toJson(), b.toJson());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Phone Cut previews and removes the tapped interval with one touch',
    (tester) async {
      final a = editing.wall('a', Offset.zero, const Offset(6, 0));
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [
            a,
            editing.wall('b', const Offset(2, -2), const Offset(2, 2)),
            editing.wall('c', const Offset(4, -2), const Offset(4, 2)),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.selectTool(tester, 'wall');
      await editing.hold(tester, const Offset(3, 0));
      await tester.tap(find.byKey(const ValueKey('architect-wall-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-cut')));
      await tester.pumpAndSettle();
      final old = model.project;
      final g = await tester.startGesture(
        workspace.screen(tester, const Offset(3, 0)),
      );
      await tester.pump();
      final span = workspace.overlay(tester).wallTrimSpan!;
      expect(span.from, closeTo(1 / 3, 1e-9));
      expect(span.to, closeTo(2 / 3, 1e-9));
      expect(identical(model.project, old), isTrue);
      await g.up();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls, hasLength(4));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Control click trims directly and release cannot select or place another element',
    (tester) async {
      final a = editing.wall('a', Offset.zero, const Offset(6, 0));
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [
            a,
            editing.wall('b', const Offset(2, -2), const Offset(2, 2)),
            editing.wall('c', const Offset(4, -2), const Offset(4, 2)),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.selectTool(tester, 'wall');
      final old = model.project;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final g = await tester.startGesture(
        workspace.screen(tester, const Offset(3, 0)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(model.project.activeStorey.walls, hasLength(4));
      final trimmed = model.project;
      await g.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(identical(model.project, trimmed), isTrue);
      expect(workspace.overlay(tester).selectedElementId, isNull);
      model.undo();
      expect(identical(model.project, old), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '360 by 800: clearance, local keypad and tap trim fit and operate',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final a = editing.wall(
        'a',
        const Offset(-2, 0),
        const Offset(2, 0),
        exterior: true,
      );
      final b = editing.wall(
        'b',
        const Offset(-2, 3),
        const Offset(2, 3),
        exterior: true,
      );
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [
            a,
            b,
            editing.wall('c', const Offset(-1, -1), const Offset(-1, 1)),
            editing.wall('d', const Offset(1, -1), const Offset(1, 1)),
          ],
        ),
      );
      addTearDown(model.dispose);
      const key = ValueKey('wall-smart-phone-preview');
      if (const bool.fromEnvironment('UPDATE_ARCHITECT_SMART_PREVIEW')) {
        await tester.runAsync(() async {
          final font = FontLoader('Roboto')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
                ),
              ),
            );
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            locale: const Locale('bg'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String file) async {
        if (!const bool.fromEnvironment('UPDATE_ARCHITECT_SMART_PREVIEW')) {
          return;
        }
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File(file).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }

      await editing.selectTool(tester, 'wall');
      await editing.hold(tester, Offset.zero);
      final chip = find.byKey(const ValueKey('wall-clearance-b'));
      expect(chip, findsOneWidget);
      final rect = tester.getRect(chip);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      await capture('docs/images/architect_wall_clearance_phone.png');
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      for (final id in ['wall-key-0', 'wall-end']) {
        final rect = tester.getRect(find.byKey(ValueKey(id)));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(rect.bottom, lessThanOrEqualTo(800));
      }
      await capture('docs/images/architect_wall_clearance_keypad_phone.png');
      await tester.tap(find.byKey(const ValueKey('wall-key-2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.walls.first.startPoint.dy,
        closeTo(.63, 1e-9),
      );
      expect(model.project.activeStorey.walls[1].toJson(), b.toJson());
      await tester.tap(find.byKey(const ValueKey('architect-undo')));
      await tester.pumpAndSettle();
      await editing.hold(tester, Offset.zero);
      await tester.tap(find.byKey(const ValueKey('architect-wall-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-cut')));
      await tester.pumpAndSettle();
      final g = await tester.startGesture(
        workspace.screen(tester, Offset.zero),
      );
      await tester.pump();
      expect(workspace.overlay(tester).wallTrimSpan, isNotNull);
      await capture('docs/images/architect_wall_trim_phone.png');
      await g.up();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls, hasLength(5));
      expect(tester.takeException(), isNull);
    },
  );
}
