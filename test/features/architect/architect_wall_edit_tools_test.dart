import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_network.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  for (final reference in WallReferenceLine.values) {
    test('Mirror preserves core, openings and connections: $reference', () {
      final wall = editing
          .wall('w', const Offset(1, 2), const Offset(4, 6), exterior: true)
          .copyWith(referenceLine: reference)
          .addDoor(
            const ArchitectDoor(
              id: 'd',
              wallId: 'w',
              offsetRatio: .5,
              uuid: 'd',
            ),
          );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [wall]),
      );
      addTearDown(model.dispose);
      final old = model.project;
      model.execute(const MirrorArchitectWalls(storeyId: 's', wallIds: {'w'}));
      final next = model.project.activeStorey.walls.single;
      expect(
        (next.coreCenterStart - wall.coreCenterStart).distance,
        lessThan(1e-9),
      );
      expect(
        (next.coreCenterEnd - wall.coreCenterEnd).distance,
        lessThan(1e-9),
      );
      expect(next.exteriorSide, WallExteriorSide.right);
      expect(next.doors.single.toJson(), wall.doors.single.toJson());
      expect(next.connectStart, isTrue);
      model.undo();
      expect(identical(model.project, old), isTrue);
      model.execute(
        SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'w'},
          textValues: const {'exteriorSide': 'right'},
        ),
      );
      expect(
        (model.project.activeStorey.walls.single.coreCenterStart -
                wall.coreCenterStart)
            .distance,
        lessThan(1e-9),
      );
    });
    test('Snap every body and core corner with $reference reference', () {
      final wall = editing
          .wall('w', const Offset(1, 2), const Offset(4, 6), exterior: true)
          .copyWith(referenceLine: reference);
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [wall]),
      );
      addTearDown(model.dispose);
      for (final point in [...wall.polygonCorners, ...wall.coreCorners]) {
        final snap = ArchitectWallSnap.resolve(
          raw: point + const Offset(.002, .003),
          project: model.project,
          scale: 1000,
        );
        expect((snap.point - point).distance, lessThan(1e-9));
        expect(snap.isSnapped, isTrue);
      }
    });
  }
  test(
    'Joined outside mitre corner is magnetic independently of the core axis',
    () {
      final a = editing.wall(
        'a',
        Offset.zero,
        const Offset(4, 0),
        exterior: true,
      );
      final b = editing.wall(
        'b',
        const Offset(4, 0),
        const Offset(4, 4),
        exterior: true,
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [a, b]),
      );
      addTearDown(model.dispose);
      final corner = const Offset(4.125, -.125);
      expect(ArchitectWallGeometry.of([a, b]).corners, contains(corner));
      final snap = ArchitectWallSnap.resolve(
        raw: corner + const Offset(.006, -.004),
        project: model.project,
        scale: 1000,
      );
      expect(snap.point, corner);
      final off = ArchitectWallSnap.resolve(
        raw: corner + const Offset(.006, -.004),
        project: model.project,
        scale: 1000,
        magnetic: false,
      );
      expect(off.isSnapped, isFalse);
    },
  );
  test(
    'Pulling a connected branch slides along a stationary base; detach frees it',
    () {
      final base = editing.wall('a', Offset.zero, const Offset(6, 0));
      final branch = editing
          .wall('b', const Offset(2, 0), const Offset(2, 3))
          .addDoor(
            const ArchitectDoor(
              id: 'd',
              wallId: 'b',
              offsetRatio: .5,
              uuid: 'd',
            ),
          );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [base, branch]),
      );
      addTearDown(model.dispose);
      model.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'b',
          delta: Offset(1, .5),
        ),
      );
      var next = model.project.activeStorey.walls;
      expect(identical(next[0], base), isTrue);
      expect(next[1].startPoint, const Offset(3, 0));
      expect(next[1].endPoint, const Offset(3, 3.5));
      expect(
        next[1].doors.single.offsetRatio * next[1].length,
        closeTo(2, 1e-9),
      );
      model.undo();
      model.execute(
        const SetArchitectWallConnection(
          storeyId: 's',
          wallIds: {'b'},
          connected: false,
        ),
      );
      final saved = ArchitectWall.fromJson(
        model.project.activeStorey.walls[1].toJson(),
      );
      expect(saved.isDetached, isTrue);
      model.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'b',
          delta: Offset(1, .5),
        ),
      );
      next = model.project.activeStorey.walls;
      expect(next[0].toJson(), base.toJson());
      expect(next[1].startPoint, const Offset(3, .5));
      expect(next[1].endPoint, const Offset(3, 3.5));
    },
  );
  test('Detached ends omit mitres and Join restores their connection', () {
    final a = editing.wall('a', Offset.zero, const Offset(4, 0));
    final b = editing.wall('b', const Offset(4, 0), const Offset(4, 3));
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 's', walls: [a, b]),
    );
    addTearDown(model.dispose);
    expect(
      ArchitectWallNetwork.junctions(model.project.activeStorey.walls),
      hasLength(1),
    );
    model.execute(
      const SetArchitectWallConnection(
        storeyId: 's',
        wallIds: {'b'},
        connected: false,
      ),
    );
    expect(
      ArchitectWallNetwork.junctions(model.project.activeStorey.walls),
      isEmpty,
    );
    model.execute(const JoinArchitectWalls(storeyId: 's', wallIds: {'a', 'b'}));
    expect(
      ArchitectWallNetwork.junctions(model.project.activeStorey.walls),
      hasLength(1),
    );
  });
  test(
    'Cut splits only crossed walls, preserves openings/outer joins and undoes once',
    () {
      final a = editing
          .wall('a', Offset.zero, const Offset(6, 0))
          .addDoor(
            const ArchitectDoor(
              id: 'd',
              wallId: 'a',
              offsetRatio: .75,
              uuid: 'd',
            ),
          );
      final b = editing.wall('b', const Offset(0, 2), const Offset(6, 2));
      final c = editing.wall('c', const Offset(0, 4), const Offset(6, 4));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [a, b, c]),
      );
      addTearDown(model.dispose);
      final old = model.project;
      model.execute(
        const CutArchitectWalls(
          storeyId: 's',
          wallIds: {'a', 'b', 'c'},
          start: Offset(3, -1),
          end: Offset(3, 3),
        ),
      );
      final walls = model.project.activeStorey.walls;
      expect(walls, hasLength(5));
      expect(walls[0].connectStart, isTrue);
      expect(walls[0].connectEnd, isFalse);
      expect(walls[1].connectStart, isFalse);
      expect(walls[1].connectEnd, isTrue);
      expect(walls[1].doors.single.wallId, walls[1].id);
      expect(walls[1].doors.single.offsetRatio, .5);
      expect(walls.last.toJson(), c.toJson());
      model.undo();
      expect(identical(model.project, old), isTrue);
      model.redo();
      expect(model.project.activeStorey.walls, hasLength(5));
    },
  );
  test('Cut through an opening rejects the entire multi-wall transaction', () {
    final a = editing.wall('a', Offset.zero, const Offset(6, 0));
    final b = editing
        .wall('b', const Offset(0, 2), const Offset(6, 2))
        .addDoor(
          const ArchitectDoor(id: 'd', wallId: 'b', offsetRatio: .5, uuid: 'd'),
        );
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 's', walls: [a, b]),
    );
    addTearDown(model.dispose);
    final old = model.project;
    expect(
      () => model.execute(
        const CutArchitectWalls(
          storeyId: 's',
          wallIds: {'a', 'b'},
          start: Offset(3, -1),
          end: Offset(3, 3),
        ),
      ),
      throwsArgumentError,
    );
    expect(identical(model.project, old), isTrue);
  });
  test(
    'Magnetic body guides align rotated parallel and perpendicular neighbors',
    () {
      for (final angle in [0.0, math.pi / 5]) {
        Offset rotate(Offset p) => Offset(
          p.dx * math.cos(angle) - p.dy * math.sin(angle),
          p.dx * math.sin(angle) + p.dy * math.cos(angle),
        );
        final a = editing.wall(
          'a',
          rotate(const Offset(0, 0)),
          rotate(const Offset(4, 0)),
        );
        final b = editing.wall(
          'b',
          rotate(const Offset(0, 3)),
          rotate(const Offset(4, 3)),
        );
        final aligned = ArchitectWallAlignment.move(
          [a, b],
          {'a'},
          rotate(const Offset(1, 2.97)),
          100,
          parallelOnly: true,
        );
        expect(
          (aligned.$1 - rotate(const Offset(1, 3))).distance,
          lessThan(1e-9),
        );
        expect(aligned.$2, isNotEmpty);
      }
    },
  );
  test(
    'Magnetic guides capture perpendicular faces and a rotated relative direction',
    () {
      final a = editing.wall('a', Offset.zero, const Offset(4, 0));
      final b = editing.wall('b', const Offset(4, 3), const Offset(4, 6));
      final aligned = ArchitectWallAlignment.move(
        [a, b],
        {'a'},
        const Offset(1, 2.85),
        100,
        parallelOnly: true,
      );
      expect(aligned.$1.dy, closeTo(2.875, 1e-9));
      expect(aligned.$2, isNotEmpty);
      const angle = math.pi / 5;
      Offset rotate(Offset p) => Offset(
        p.dx * math.cos(angle) - p.dy * math.sin(angle),
        p.dx * math.sin(angle) + p.dy * math.cos(angle),
      );
      final neighbor = editing.wall(
        'w',
        rotate(const Offset(0, 3)),
        rotate(const Offset(4, 3)),
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [neighbor]),
      );
      addTearDown(model.dispose);
      final raw = Offset(
        2 * math.cos(angle + .007),
        2 * math.sin(angle + .007),
      );
      final snap = ArchitectWallSnap.resolve(
        raw: raw,
        anchor: Offset.zero,
        project: model.project,
        scale: 100,
      );
      expect(snap.angleDeg, closeTo(36, 1e-9));
      expect(snap.magneticGuides, isNotEmpty);
    },
  );
  testWidgets(
    'Quick detach, in-place mirror and two-point cutting operate from selection',
    (tester) async {
      final w = editing
          .wall('w', Offset.zero, const Offset(6, 0), exterior: true)
          .copyWith(referenceLine: WallReferenceLine.inner);
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [w]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.hold(tester, const Offset(2, .2));
      await tester.tap(find.byKey(const ValueKey('wall-detach')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls.single.isDetached, isTrue);
      await tester.tap(find.byKey(const ValueKey('architect-wall-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-mirror')));
      await tester.pumpAndSettle();
      expect(
        (model.project.activeStorey.walls.single.coreCenterStart -
                w.coreCenterStart)
            .distance,
        lessThan(1e-9),
      );
      await tester.tap(find.byKey(const ValueKey('architect-wall-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-cut')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(3, -1));
      final g = await tester.startGesture(
        workspace.screen(tester, const Offset(3, 1)),
      );
      await g.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(workspace.overlay(tester).wallCutLine, isNotNull);
      await g.up();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Branch body preview and commit preserve support and translated openings',
    (tester) async {
      final base = editing.wall('a', Offset.zero, const Offset(6, 0));
      final branch = editing
          .wall('b', const Offset(2, 0), const Offset(2, 3))
          .addDoor(
            const ArchitectDoor(
              id: 'd',
              wallId: 'b',
              offsetRatio: .5,
              uuid: 'd',
            ),
          );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [base, branch]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.hold(tester, const Offset(2, 2.5));
      final old = model.project;
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 2.5)),
      );
      await gesture.moveTo(workspace.screen(tester, const Offset(3, 3)));
      await tester.pump();
      final preview = workspace.overlay(tester).project;
      expect(preview.activeStorey.walls[0].toJson(), base.toJson());
      expect(preview.activeStorey.walls[1].startPoint, const Offset(3, 0));
      expect(preview.activeStorey.walls[1].endPoint, const Offset(3, 3.5));
      expect(identical(model.project, old), isTrue);
      await gesture.up();
      await tester.pump();
      expect(model.project.toJson(), preview.toJson());
      final next = model.project.activeStorey.walls[1];
      expect(next.doors.single.offsetRatio * next.length, closeTo(2, 1e-9));
      await tester.tap(find.byKey(const ValueKey('architect-undo')));
      await tester.pump();
      expect(identical(model.project, old), isTrue);
    },
  );
  testWidgets('Phone selection and cut preview remain visible at 360 by 800', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = editing.seeded(
      ArchitectStorey(
        id: 's',
        name: 's',
        walls: [
          editing.wall(
            'a',
            const Offset(-2, -1),
            const Offset(2, -1),
            exterior: true,
          ),
          editing.wall(
            'b',
            const Offset(-2, 1),
            const Offset(2, 1),
            exterior: true,
          ),
        ],
      ),
    );
    addTearDown(model.dispose);
    const key = ValueKey('wall-cut-phone-preview');
    if (const bool.fromEnvironment('UPDATE_ARCHITECT_EDIT_PREVIEW')) {
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
    await editing.hold(tester, const Offset(0, -1));
    await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
    await tester.pumpAndSettle();
    await workspace.wallTap(tester, const Offset(0, 1));
    await tester.pumpAndSettle();
    for (final id in [
      'wall-detach',
      'architect-wall-actions',
      'architect-selection-properties',
      'architect-selection-move',
      'architect-clear-selection',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(id)));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
    }
    await tester.tap(find.byKey(const ValueKey('architect-wall-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wall-cut')));
    await tester.pumpAndSettle();
    await workspace.wallTap(tester, const Offset(0, -1.8));
    final gesture = await tester.startGesture(
      workspace.screen(tester, const Offset(0, 1.8)),
    );
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(workspace.overlay(tester).wallCutLine, isNotNull);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('UPDATE_ARCHITECT_EDIT_PREVIEW')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          'docs/images/architect_wall_cut_phone.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.walls, hasLength(4));
  });
}
