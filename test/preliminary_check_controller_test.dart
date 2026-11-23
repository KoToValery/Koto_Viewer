import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/element_check_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/services/preliminary_check_controller.dart';

PreliminaryCheckReport _report(int ms) => PreliminaryCheckReport(
  elements: const {},
  slabs: const [],
  unsupported: const [],
  durationMs: ms,
);

void main() {
  const project = StructuralProject();

  test('debounce merges bursts into one run', () async {
    var runs = 0;
    final c = PreliminaryCheckController(
      debounce: const Duration(milliseconds: 20),
      runner: (p, s) async {
        runs++;
        return _report(runs);
      },
    );
    for (var i = 0; i < 5; i++) {
      c.request(project, 1);
    }
    expect(c.isStale, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(runs, 1);
    expect(c.isStale, isFalse);
    expect(c.report.durationMs, 1);
    c.dispose();
  });

  test('a superseded result is dropped', () async {
    final first = Completer<PreliminaryCheckReport>();
    final second = Completer<PreliminaryCheckReport>();
    final queue = [first, second];
    final c = PreliminaryCheckController(
      debounce: Duration.zero,
      runner: (p, s) => queue.removeAt(0).future,
    );
    c.request(project, 1, immediate: true);
    c.request(project, 1, immediate: true);
    second.complete(_report(2));
    await Future<void>.delayed(Duration.zero);
    first.complete(_report(1));
    await Future<void>.delayed(Duration.zero);
    expect(c.report.durationMs, 2);
    expect(c.isStale, isFalse);
    c.dispose();
  });

  test('a failed run keeps the previous report and exposes the error', () async {
    var fail = false;
    final c = PreliminaryCheckController(
      debounce: Duration.zero,
      runner: (p, s) async {
        if (fail) throw StateError('x');
        return _report(7);
      },
    );
    c.request(project, 1, immediate: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    fail = true;
    c.request(project, 1, immediate: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.report.durationMs, 7);
    expect(c.error, isA<StateError>());
    expect(c.isStale, isTrue);
    c.dispose();
  });
}
