import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  for (final angle in [0.0, math.pi / 2, .7]) {
    test(
      'outward wall pull stretches returns and T ends, preserving hosts at $angle',
      () {
        Offset rotate(Offset p) => Offset(
          p.dx * math.cos(angle) - p.dy * math.sin(angle),
          p.dx * math.sin(angle) + p.dy * math.cos(angle),
        );
        final a = editing
            .wall('a', rotate(Offset.zero), rotate(const Offset(4, 0)))
            .addDoor(
              const ArchitectDoor(
                id: 'moving',
                wallId: 'a',
                uuid: 'moving',
                offsetRatio: .5,
              ),
            );
        final left = editing
            .wall('left', rotate(Offset.zero), rotate(const Offset(0, 2)))
            .addDoor(
              const ArchitectDoor(
                id: 'fixed',
                wallId: 'left',
                uuid: 'fixed',
                offsetRatio: .5,
              ),
            );
        final right = editing.wall(
          'right',
          rotate(const Offset(4, 0)),
          rotate(const Offset(4, 2)),
        );
        final branch = editing.wall(
          'T',
          rotate(const Offset(2, 0)),
          rotate(const Offset(2, 2)),
        );
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: 's', walls: [a, left, right, branch]),
        );
        addTearDown(model.dispose);
        final before = model.project;
        model.execute(
          MoveArchitectElement(
            storeyId: 's',
            elementId: 'a',
            delta: rotate(const Offset(0, -3)),
          ),
        );
        final next = model.project.activeStorey.walls;
        for (final wall in next.skip(1)) {
          final x = wall.id == 'left'
              ? 0.0
              : wall.id == 'right'
              ? 4.0
              : 2.0;
          expect(
            (wall.startPoint - rotate(Offset(x, -3))).distance,
            lessThan(1e-8),
          );
          expect(
            (wall.endPoint - rotate(Offset(x, 2))).distance,
            lessThan(1e-8),
          );
          expect(wall.connectStart, isTrue);
        }
        expect(next.first.doors.single.offsetRatio, .5);
        expect(next[1].doors.single.offsetRatio, closeTo(.8, 1e-8));
        expect(next[1].doors.single.uuid, 'fixed');
        expect(next[1].doors.single.wallId, 'left');
        model.undo();
        expect(identical(model.project, before), isTrue);
        expect(model.canUndo, isFalse);
        model.redo();
        expect(
          (model.project.activeStorey.walls.first.startPoint -
                  rotate(const Offset(0, -3)))
              .distance,
          lessThan(1e-8),
        );
      },
    );
  }

  test(
    'detached walls stay independent; invalid host shortening is atomic',
    () {
      final a = editing.wall('a', Offset.zero, const Offset(4, 0));
      final support = editing
          .wall('support', Offset.zero, const Offset(0, 2))
          .addDoor(
            const ArchitectDoor(
              id: 'd',
              wallId: 'support',
              uuid: 'd',
              offsetRatio: .5,
            ),
          );
      final detached = editing
          .wall('detached', const Offset(2, 0), const Offset(2, 2))
          .copyWith(connectStart: false, connectEnd: false);
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [a, support, detached]),
      );
      addTearDown(model.dispose);
      final before = model.project;
      expect(
        () => model.execute(
          const MoveArchitectElement(
            storeyId: 's',
            elementId: 'a',
            delta: Offset(0, 3),
          ),
        ),
        throwsArgumentError,
      );
      expect(identical(model.project, before), isTrue);
      expect(model.canUndo, isFalse);
      model.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'a',
          delta: Offset(0, -3),
        ),
      );
      expect(model.project.activeStorey.walls.last.toJson(), detached.toJson());
    },
  );

  testWidgets('connected outward drag previews, cancels and commits once', (
    tester,
  ) async {
    final model = editing.seeded(
      ArchitectStorey(
        id: 's',
        name: 's',
        walls: [
          editing.wall('a', Offset.zero, const Offset(4, 0)),
          editing.wall('left', Offset.zero, const Offset(0, 2)),
          editing.wall('right', const Offset(4, 0), const Offset(4, 2)),
        ],
      ),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await editing.selectTool(tester, 'wall');
    workspace.camera(tester).fit(const Rect.fromLTWH(-2, -4, 8, 8));
    await tester.pumpAndSettle();
    await editing.hold(tester, const Offset(2, 0));
    final before = model.project;
    final cancel = await tester.startGesture(
      workspace.screen(tester, const Offset(2, 0)),
      kind: PointerDeviceKind.mouse,
    );
    await cancel.moveTo(workspace.screen(tester, const Offset(2, -3)));
    await tester.pump();
    expect(identical(model.project, before), isTrue);
    expect(
      workspace.overlay(tester).project.activeStorey.walls[1].startPoint,
      const Offset(0, -3),
    );
    await cancel.cancel();
    await tester.pump();
    expect(identical(model.project, before), isTrue);
    final drag = await tester.startGesture(
      workspace.screen(tester, const Offset(2, 0)),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveTo(workspace.screen(tester, const Offset(2, -3)));
    await drag.up();
    await tester.pump();
    expect(model.project.activeStorey.walls[2].startPoint, const Offset(4, -3));
    model.undo();
    expect(identical(model.project, before), isTrue);
    expect(model.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });
}
