import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/widgets/architect_projection_status.dart';

/// Widget tests use a fake clock, while compute() workers use real isolate
/// messages. Let those messages arrive before settling UI animations.
Future<void> settleProjection(WidgetTester tester, {int attempts = 250}) async {
  await tester.pump(const Duration(milliseconds: 1));
  for (var i = 0; i < attempts; i++) {
    final busy = tester
        .widgetList<ArchitectProjectionStatus>(
          find.byType(ArchitectProjectionStatus),
        )
        .any((status) => !status.failed);
    if (!busy) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }
  throw TestFailure('Architectural projection worker did not complete');
}
