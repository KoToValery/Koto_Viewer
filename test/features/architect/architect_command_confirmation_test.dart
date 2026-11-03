import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_room_detector.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_command_preview.dart';
import 'package:kotoview/src/features/architect/services/architect_drafting_seed.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_element_group_test.dart' as groups;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';

const interior = ArchitectWall(
  id: 'interior',
  startPoint: Offset(2, -2),
  endPoint: Offset(2, 2),
  thickness: .3,
  height: 3.2,
  followStoreyHeight: false,
  parapet: false,
);
const parapet = ArchitectWall(
  id: 'parapet',
  startPoint: Offset(-3, -2),
  endPoint: Offset(-3, 2),
  thickness: .12,
  height: 1.05,
  followStoreyHeight: false,
  parapet: true,
);

Future<void> confirm(WidgetTester tester) async {
  final apply = find.byKey(const ValueKey('architect-command-apply'));
  expect(tester.widget<IconButton>(apply).onPressed, isNotNull);
  await tester.tap(apply);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Mirror previews keep hosted copy identities and source wall properties',
    () {
      final wall = interior.addDoor(
        const ArchitectDoor(
          id: 'door',
          wallId: 'interior',
          uuid: 'door-uuid',
          offsetRatio: .5,
        ),
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [wall]),
      );
      addTearDown(model.dispose);
      const command = MirrorArchitectElements(
        storeyId: 's',
        elementIds: {'interior'},
        origin: Offset.zero,
        direction: Offset(0, 1),
        isDuplicate: true,
        idMap: {'interior': 'copy'},
      );
      final first = command.apply(model.project).activeStorey.walls.last;
      final second = command.apply(model.project).activeStorey.walls.last;
      expect(first.doors.single.id, second.doors.single.id);
      expect(first.doors.single.uuid, second.doors.single.uuid);
      expect(first.doors.single.wallId, first.id);
      expect(first.doors.single.id, isNot(wall.doors.single.id));
      expect(first.height, wall.height);
      expect(first.baseOffset, wall.baseOffset);
      expect(first.followStoreyHeight, wall.followStoreyHeight);
      expect(first.wallTypeId, wall.wallTypeId);
    },
  );

  test(
    'Copy bypasses drafting defaults; only explicit new drawing inherits them',
    () {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', walls: [interior, parapet]),
      );
      addTearDown(model.dispose);
      final seed = ArchitectDraftingSeed.fromSelection(
        model.project,
        'parapet',
      )!;
      final view = ArchitectWorkspaceViewController(model)
        ..prepareCreation = seed.apply;
      addTearDown(view.dispose);
      view.execute(
        const MirrorArchitectElements(
          storeyId: 's',
          elementIds: {'interior'},
          origin: Offset.zero,
          direction: Offset(0, 1),
          isDuplicate: true,
          idMap: {'interior': 'copy'},
        ),
      );
      final copy = model.project.activeStorey.walls.last;
      expect(copy.height, interior.height);
      expect(copy.thickness, interior.thickness);
      expect(copy.followStoreyHeight, interior.followStoreyHeight);
      expect(copy.isParapet, isFalse);
      view.execute(
        const CreateArchitectWall(
          storeyId: 's',
          wall: ArchitectWall(
            id: 'drawn',
            startPoint: Offset(0, 4),
            endPoint: Offset(4, 4),
          ),
        ),
        applyDraftingDefaults: true,
      );
      expect(model.project.activeStorey.walls.last.height, parapet.height);
      expect(model.project.activeStorey.walls.last.isParapet, isTrue);
      final restored = ArchitectProject.fromJson(model.project.toJson());
      expect(
        restored.activeStorey.walls.firstWhere((w) => w.id == 'copy').height,
        3.2,
      );
    },
  );

  test(
    'Command preview rejects stale contexts and makes no history before acceptance',
    () {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', walls: [interior]),
      );
      addTearDown(model.dispose);
      final source = model.project;
      final next = const MoveArchitectElements(
        storeyId: 's',
        elementIds: {'interior'},
        delta: Offset(1, 0),
      ).apply(source);
      final session = ArchitectCommandPreview(
        action: 'move',
        document: source,
        context: 'original',
        original: source,
      );
      expect(session.stage('original', source), isTrue);
      expect(session.ready, isFalse);
      expect(session.stage('original', next), isTrue);
      expect(model.project, same(source));
      expect(model.undoCount, 0);
      expect(session.confirm('different-view'), isNull);
      expect(model.project, same(source));
      expect(model.undoCount, 0);
    },
  );

  for (final language in ['bg', 'en']) {
    for (final width in [360.0, 390.0]) {
      testWidgets(
        'Parapet seed cannot alter mirror copy; X and ✓ fit $language $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final model = editing.seeded(
            const ArchitectStorey(
              id: 's',
              name: '',
              walls: [interior, parapet],
            ),
          );
          addTearDown(model.dispose);
          final source = model.project;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ArchitectWorkspaceScreen(commandController: model),
            ),
          );
          await tester.pumpAndSettle();
          workspace
              .camera(tester)
              .fit(const Rect.fromLTRB(-5, -4, 5, 4), padding: 40);
          await tester.pumpAndSettle();
          await editing.ensureSelectionTool(tester);
          await workspace.wallTap(tester, const Offset(-3, -1));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('architect-draw-selection')),
          );
          await tester.pumpAndSettle();
          await workspace.wallTap(tester, const Offset(2, -1));
          await tester.pumpAndSettle();
          Future<void> mirror() async {
            await tester.tap(
              find.byKey(const ValueKey('architect-selection-mirror-copy')),
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<IconButton>(
                    find.byKey(const ValueKey('architect-command-apply')),
                  )
                  .onPressed,
              isNull,
            );
            await tester.tapAt(workspace.screen(tester, Offset.zero));
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('architect-mirror-vertical-btn')),
            );
            await tester.pumpAndSettle();
          }

          await mirror();
          expect(model.project, same(source));
          expect(model.undoCount, 0);
          final preview = workspace
              .overlay(tester)
              .project
              .activeStorey
              .walls
              .last;
          expect(preview.height, 3.2);
          expect(preview.thickness, .3);
          expect(preview.isParapet, isFalse);
          for (final key in [
            'architect-command-cancel',
            'architect-command-apply',
          ]) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            expect(rect.top, greaterThanOrEqualTo(0));
          }
          await tester.tap(
            find.byKey(const ValueKey('architect-command-cancel')),
          );
          await tester.pumpAndSettle();
          expect(model.project, same(source));
          expect(model.undoCount, 0);
          expect(workspace.overlay(tester).selectedElementId, 'interior');
          await mirror();
          final pendingId = workspace
              .overlay(tester)
              .project
              .activeStorey
              .walls
              .last
              .id;
          await confirm(tester);
          final copy = model.project.activeStorey.walls.last;
          expect(copy.id, pendingId);
          expect(copy.height, interior.height);
          expect(copy.thickness, interior.thickness);
          expect(copy.isParapet, isFalse);
          expect(model.undoCount, 1);
          model.undo();
          await tester.pumpAndSettle();
          expect(model.project.activeStorey.walls, hasLength(2));
          model.redo();
          await tester.pumpAndSettle();
          expect(model.project.activeStorey.walls.last.height, 3.2);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Rotate preset stages once and requires the shared green check', (
    tester,
  ) async {
    final model = editing.seeded(
      const ArchitectStorey(id: 's', name: '', walls: [interior]),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await editing.contextHold(tester, const Offset(2, -1));
    await groups.action(tester, BimEditAction.rotate);
    await tester.tap(
      find.byKey(const ValueKey('architect-rotation-preset-90')),
    );
    await tester.pumpAndSettle();
    expect(
      model.project.activeStorey.walls.single.startPoint,
      interior.startPoint,
    );
    expect(model.undoCount, 0);
    await confirm(tester);
    expect(
      model.project.activeStorey.walls.single.startPoint,
      isNot(interior.startPoint),
    );
    expect(model.project.activeStorey.walls.single.height, interior.height);
    expect(model.undoCount, 1);
  });

  testWidgets(
    'Command Move freezes after release and ignores hover until acceptance',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', walls: [interior]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.hold(tester, const Offset(2, -1));
      await tester.tap(find.byKey(const ValueKey('architect-selection-move')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-move-free')));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(2, -1)),
      );
      await tester.pump(const Duration(milliseconds: 451));
      await gesture.moveTo(workspace.screen(tester, const Offset(3, -1)));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(model.undoCount, 0);
      final frozen = workspace
          .overlay(tester)
          .project
          .activeStorey
          .walls
          .single
          .startPoint;
      expect(frozen, isNot(interior.startPoint));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(4, 1)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(-1, 1)));
      await tester.pumpAndSettle();
      expect(
        workspace.overlay(tester).project.activeStorey.walls.single.startPoint,
        frozen,
      );
      await mouse.removePointer();
      await confirm(tester);
      expect(model.project.activeStorey.walls.single.startPoint, frozen);
      expect(model.undoCount, 1);
    },
  );

  testWidgets(
    'Direct endpoint dragging keeps release-to-save without a command',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', walls: [interior]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.hold(tester, const Offset(2, -1));
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 2)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 451));
      await gesture.moveTo(workspace.screen(tester, const Offset(3, 2)));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.walls.single.endPoint,
        isNot(interior.endPoint),
      );
      expect(model.undoCount, 1);
      expect(find.byKey(const ValueKey('architect-command-bar')), findsNothing);
    },
  );

  testWidgets('Moving a wall and its automatic room is one confirmed Undo', (
    tester,
  ) async {
    final walls = [
      editing.wall('bottom', const Offset(-2, 0), const Offset(2, 0)),
      editing.wall('right', const Offset(2, 0), const Offset(2, 3)),
      editing.wall('top', const Offset(2, 3), const Offset(-2, 3)),
      editing.wall('left', const Offset(-2, 3), const Offset(-2, 0)),
    ];
    const seed = ArchitectZone(
      id: 'room',
      name: '',
      category: ArchitectZoneCategory.living,
      polygon: [Offset(-2, 0), Offset(2, 0), Offset(2, 3), Offset(-2, 3)],
      isAutoBoundary: true,
    );
    final zone = ArchitectRoomDetector.automaticZone(seed, walls)!;
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: '', walls: walls, zones: [zone]),
    );
    addTearDown(model.dispose);
    final before = model.project;
    await workspace.open(tester, model);
    await editing.selectTool(tester, 'wall');
    await workspace.wallTap(tester, const Offset(0, 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-selection-move')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-move-offset')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('architect-axis-value')),
      '-0.5',
    );
    await tester.tap(find.byKey(const ValueKey('architect-axis-value-save')));
    await tester.pumpAndSettle();
    expect(model.project, same(before));
    expect(
      workspace.overlay(tester).project.activeStorey.zones.single.area,
      greaterThan(zone.area),
    );
    await confirm(tester);
    expect(model.undoCount, 1);
    expect(
      model.project.activeStorey.zones.single.area,
      greaterThan(zone.area),
    );
    model.undo();
    expect(model.project, same(before));
  });

  testWidgets(
    'Opening cut uses one shared green check after its input points',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: '',
          slabs: [
            ArchitectSlab(
              id: 'slab',
              polygon: [Offset(0, 0), Offset(8, 0), Offset(8, 6), Offset(0, 6)],
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.contextHold(tester, const Offset(2, 2));
      await groups.action(tester, BimEditAction.cutOpening);
      for (final point in [
        const Offset(1, 1),
        const Offset(3, 1),
        const Offset(3, 3),
        const Offset(1, 3),
      ]) {
        await tester.tapAt(workspace.screen(tester, point));
        await tester.pumpAndSettle();
      }
      expect(model.project.activeStorey.slabs.single.holes, isEmpty);
      expect(model.undoCount, 0);
      await confirm(tester);
      expect(model.project.activeStorey.slabs.single.holes, hasLength(1));
      expect(model.undoCount, 1);
      expect(find.byKey(const ValueKey('architect-command-bar')), findsNothing);
    },
  );
}
