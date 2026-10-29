import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_loader.dart';
import 'package:kotoview/src/features/architect/widgets/architect_projection_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_projection_status.dart';
import 'architect_section_drainage_performance_test.dart' as fixture;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_workspace_views_test.dart' as views;
import 'architect_projection_test_helper.dart' as projection;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'latest projection wins, pending requests coalesce and disposal rejects results',
    () async {
      var changes = 0, calls = 0;
      final loader = ArchitectProjectionLoader<int>(() => changes++);
      final first = Completer<int>(), last = Completer<int>();
      loader.ensure(Object(), 'A', () {
        calls++;
        return first.future;
      });
      await Future<void>.delayed(Duration.zero);
      loader.ensure(Object(), 'B', () async {
        calls++;
        return 2;
      });
      loader.ensure(Object(), 'C', () {
        calls++;
        return last.future;
      });
      first.complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(loader.data, isNull);
      expect(changes, 0);
      expect(calls, 2);
      last.complete(3);
      await Future<void>.delayed(Duration.zero);
      expect(loader.data, 3);
      expect(changes, 1);
      final stale = Completer<int>();
      loader.ensure(Object(), 'D', () => stale.future);
      await Future<void>.delayed(Duration.zero);
      loader.dispose();
      stale.complete(4);
      await Future<void>.delayed(Duration.zero);
      expect(changes, 1);
    },
  );

  test(
    'failed projection can retry without swallowing the next model revision',
    () async {
      final source = Object();
      final loader = ArchitectProjectionLoader<int>(() {});
      loader.ensure(source, 'A', () async => throw StateError('bad geometry'));
      await Future<void>.delayed(Duration.zero);
      expect(loader.failed, isTrue);
      loader.invalidate();
      loader.ensure(source, 'A', () async => 7);
      await Future<void>.delayed(Duration.zero);
      expect(loader.failed, isFalse);
      expect(loader.data, 7);
      loader.dispose();
    },
  );

  testWidgets(
    'actual package sections open on a phone and reuse selection paths while panning',
    (tester) async {
      final controller = ArchitectCommandController(
        fixture.attachedDrainageProject(),
      );
      addTearDown(controller.dispose);
      await workspace.open(tester, controller);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      for (final cut in controller.project.sections) {
        await views.select(tester, 'section', cut.id);
        expect(find.byType(ArchitectProjectionStatus), findsNothing);
        final editor = tester.widget<ArchitectProjectionEditor>(
          find.byType(ArchitectProjectionEditor),
        );
        final before = editor.paths;
        expect(before, isNotEmpty);
        final rect = tester.getRect(
          find.byKey(const ValueKey('architect-workspace-projection')),
        );
        await tester.dragFrom(rect.center, const Offset(45, 15));
        await projection.settleProjection(tester);
        final after = tester
            .widget<ArchitectProjectionEditor>(
              find.byType(ArchitectProjectionEditor),
            )
            .paths;
        expect(
          identical(after, before),
          isTrue,
          reason: 'Viewport changes must reuse existing selection contours',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
