import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/initial_scheme_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_layout_evaluator.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'initial_scheme_generator_test.dart' as f;

void main() {
  const enabled = bool.fromEnvironment('BIM_LAYOUT_BENCHMARK');
  test('measure before and after layouts with the same evaluator', () async {
    final rows =
        jsonDecode(
              await File(
                'test/fixtures/initial_scheme_before_optimization.json',
              ).readAsString(),
            )
            as List;
    final results = <Map<String, Object?>>[];
    for (final row in rows) {
      final project = StructuralProject.fromJson(
        Map<String, dynamic>.from(row['project']),
      );
      final oldFloor = StoreyLevel.fromJson(
        Map<String, dynamic>.from(row['layout']),
      );
      final (_, standard) = f.fixture(
        angle: row['name'] == 'rotated' ? .43 : 0,
      );
      final core = [
        f.pair(const Offset(6.7, 5.5), const Offset(6.7, 10.5), 1),
        f.pair(const Offset(9.3, 5.5), const Offset(9.3, 10.5), 1),
        f.pair(const Offset(6.5, 5.7), const Offset(9.5, 5.7), 1),
        f.pair(const Offset(6.5, 10.3), const Offset(9.5, 10.3), 1),
      ];
      final before = SupportLayoutEvaluator.evaluate(project, oldFloor, 1);
      final clock = Stopwatch()..start();
      final generated = InitialSchemeGenerator.generate(
        project: project,
        wallPairs: row['name'] == 'core-only' ? core : standard,
        scale: 1,
      );
      clock.stop();
      final after = generated.assessment!;
      results.add({
        'name': row['name'],
        'source': 'synthetic regression geometry',
        'before': before.toMetrics(),
        'after': after.toMetrics(),
        'generationMs': clock.elapsedMilliseconds,
        'seedLayouts': generated.searchedLayouts,
        'localEvaluations': generated.optimizationEvaluations,
        'acceptedChanges': generated.optimizationChanges,
        'limits': generated.limitReasons.toList(),
        'comparedToOldLayout': after.compareTo(before),
      });
      expect(
        after.compareTo(generated.initialAssessment!),
        lessThanOrEqualTo(0),
      );
      // Frozen pre-change output is evaluated with the new evaluator too.
      // Regression protection is separate from an optimizer's own seed score.
      expect(
        after.compareTo(before),
        lessThanOrEqualTo(0),
        reason: row['name'],
      );
      expect(
        after.unavailableChecks,
        lessThanOrEqualTo(before.unavailableChecks),
      );
      expect(
        after.topology.unresolvedAreaM2,
        lessThanOrEqualTo(before.topology.unresolvedAreaM2 + 1e-6),
      );
    }
    await File('docs/bim_support_optimization_benchmark.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'scope':
            'Preliminary geometric/elastic screening; synthetic cases, not an actual building verification',
        'cases': results,
      }),
    );
  }, skip: !enabled);
}
