import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_editing/commands/bim_edit_history.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_edit_session.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';

void main() {
  test('batch publishes once; failure and no-op publish nothing', () {
    final controller = BimTransactionController<int>(
      0,
      equivalent: (a, b) => a == b,
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    expect(
      () => controller.applyBatch([
        (v) => v + 1,
        (_) => throw StateError('invalid'),
      ]),
      throwsStateError,
    );
    expect(controller.value, 0);
    expect(controller.canUndo, isFalse);
    controller.applyBatch([(v) => v + 1, (v) => v - 1]);
    expect(notifications, 0);
    controller.applyBatch([(v) => v + 1, (v) => v + 1]);
    expect(notifications, 1);
    controller.undo();
    expect(controller.value, 0);
    expect(controller.canUndo, isFalse);
    controller.redo();
    expect(controller.value, 2);
    controller.undo();
    controller.commit(3);
    expect(controller.canRedo, isFalse);
  });

  test('bounded native checkpoints skip duplicate and unused snapshots', () {
    final history = BimEditHistory<int>(limit: 2, equivalent: (a, b) => a == b);
    history.checkpoint(0);
    history.checkpoint(0);
    history.checkpoint(1);
    history.checkpoint(2);
    expect(history.undo(2), 1);
    expect(history.undo(1), 1);
    expect(history.canUndo, isFalse);
    expect(history.redo(1), 2);
    history.clear();
    expect(history.canRedo, isFalse);
  });

  test('preview is derived from original and finishes at most once', () {
    final session = BimEditSession(context: ('doc', 'floor', 1), original: 10);
    expect(session.update(('doc', 'floor', 1), (v) => v + 2), isTrue);
    expect(session.update(('doc', 'floor', 1), (v) => v + 3), isTrue);
    expect(session.original, 10);
    expect(session.preview, 13);
    expect(session.finish(('doc', 'floor', 1), changed: true), 13);
    expect(session.finish(('doc', 'floor', 1), changed: true), isNull);
    expect(session.update(('doc', 'floor', 1), (v) => v + 100), isFalse);
  });

  for (final context in [
    ('other', 'floor', 1),
    ('doc', 'other', 1),
    ('doc', 'floor', 2),
  ]) {
    test(
      'changed document, floor or revision invalidates preview: $context',
      () {
        final session = BimEditSession(
          context: ('doc', 'floor', 1),
          original: 10,
        );
        session.update(('doc', 'floor', 1), (v) => v + 1);
        expect(session.update(context, (v) => v + 2), isFalse);
        expect(session.preview, session.original);
        expect(session.finish(context, changed: true), isNull);
      },
    );
  }

  test('cancel and zero movement cannot commit', () {
    final session = BimEditSession(context: 1, original: 10);
    expect(session.finish(1, changed: false), isNull);
    final cancelled = BimEditSession(context: 1, original: 10);
    cancelled.update(1, (v) => v + 1);
    cancelled.cancel();
    expect(cancelled.finish(1, changed: true), isNull);
  });

  test('Architect copies and timestamps do not create phantom Undo steps', () {
    final original = ArchitectProject(
      id: 'p',
      name: 'Test',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      storeys: const [ArchitectStorey(id: 's', name: 'Floor')],
    );
    final commands = ArchitectCommandController(original);
    addTearDown(commands.dispose);
    commands.commit(original.copyWith(updatedAt: DateTime(2027)));
    expect(commands.canUndo, isFalse);
    expect(identical(commands.project, original), isTrue);
    commands.commit(original.copyWith(name: 'Changed'));
    expect(commands.canUndo, isTrue);
    commands.undo();
    expect(commands.project.name, 'Test');
  });

  test('semantic comparison distinguishes absent and null map entries', () {
    expect(bimValuesEqual({'x': null}, {'y': null}), isFalse);
    expect(
      bimValuesEqual(
        [
          {'x': 2},
        ],
        [
          {'x': 2.0},
        ],
      ),
      isTrue,
    );
  });
}
