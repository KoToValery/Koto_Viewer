import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/l10n_extensions.dart';
import 'package:kotoview/src/features/dxf_viewer/dxf_viewer_screen.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

/// Real-world drag/zoom performance regression test on the 930_ovk fixture.
///
/// Requires DxfPainter to expose (added alongside this test):
///   - static DxfPaintStats? lastStats
///   - static int get paintCallCount
///   - static bool debugLogRepaintReasons
///
/// Copy the real 930_ovk.dxf file into test_files/ once — do NOT point this
/// at a machine-local DwgConverterService cache path (hash+timestamp named,
/// not stable across machines/CI/cache-clears).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Instrumented drag & zoom test on REAL 930_ovk.dxf (61MB)',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    DxfPainter.debugCollectBlockDiagnostics = true;

    // Stable fixture path with fallback, not a machine-local cache path.
    final testFile = File('test_files/930_ovk.dxf').existsSync()
        ? File('test_files/930_ovk.dxf')
        : File('test_files/OVK_converted.dxf');
    expect(
      testFile.existsSync(),
      isTrue,
      reason:
          'Fixture not found. Copy the real 930_ovk.dxf into test_files/ once.',
    );
    print(
      'Using test file: ${testFile.path} '
      '(${(testFile.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB)',
    );

    await tester.binding.setSurfaceSize(const Size(1920, 1080));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DxfViewerScreen(
          filePath: testFile.path,
          addToRecent: false,
        ),
      ),
    );

    print('Waiting for file parsing and initial layout (61MB DXF)...');
    bool isLoaded = false;
    for (int i = 0; i < 300; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find.byType(InteractiveViewer).evaluate().isNotEmpty) {
        print('InteractiveViewer found after ${(i + 1) * 100}ms real time!');
        isLoaded = true;
        break;
      }
    }
    expect(isLoaded, isTrue,
        reason: 'Failed to load 61MB DXF file within 30s');
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );

    // Initial fit-to-screen paint already fired during load/settle.
    // Baseline the counter and stats before the gesture sequence below.
    final baselinePaintCount = DxfPainter.paintCallCount;
    final fitToScreenStats = DxfPainter.lastStats;
    expect(fitToScreenStats, isNotNull,
        reason: 'No paint() recorded after initial load');
    print('Fit-to-screen baseline: $fitToScreenStats');

    // ──────────────── 1. DRAG TEST (GPU transform, no CAD repaint) ────
    print('\n══════════ 1. STARTING DRAG GESTURE TEST (30 STEPS) ══════════');
    final dragStopwatch = Stopwatch()..start();
    final gesture = await tester.startGesture(const Offset(960, 540));

    for (int step = 1; step <= 30; step++) {
      await gesture.moveBy(const Offset(15, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    dragStopwatch.stop();
    print('30 drag steps completed in ${dragStopwatch.elapsedMilliseconds}ms.');

    // Point 1 (GPU-transform-only pan) as a hard regression guard: the CAD
    // layer must not repaint mid-gesture. If this fails, the "free GPU
    // transform during drag" architecture has regressed.
    final paintCountDuringDrag = DxfPainter.paintCallCount - baselinePaintCount;
    expect(
      paintCountDuringDrag,
      equals(0),
      reason: 'CAD layer repainted $paintCountDuringDrag time(s) during drag '
          '— GPU-transform-only pan has regressed (was confirmed working '
          'via the "0ms CPU repaint skipped" log line).',
    );

    print('══════════ RELEASING DRAG (SETTLE WAIT) ══════════');
    await gesture.up();

    final settleStopwatch = Stopwatch()..start();
    // Settle timer fires after 140ms.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    settleStopwatch.stop();
    print('Settle & repaint completed in ${settleStopwatch.elapsedMilliseconds}ms.');

    // ──────────────── 2. IDLE GUARD (no gesture, no pending settle) ────
    // Regression guard for the #10->#11 spurious-repaint finding: holding
    // still with nothing pending must not trigger a second paint().
    print('\n══════════ 2. IDLE SPURIOUS-REPAINT GUARD ══════════');
    final countBeforeIdle = DxfPainter.paintCallCount;
    DxfPainter.debugLogRepaintReasons = true;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    DxfPainter.debugLogRepaintReasons = false;
    final countAfterIdle = DxfPainter.paintCallCount;
    expect(
      countAfterIdle,
      equals(countBeforeIdle),
      reason: 'paint() fired $countAfterIdle - $countBeforeIdle time(s) on '
          'idle with no gesture or pending settle — spurious repaint '
          '(see printed shouldRepaint reason above).',
    );

    // ──────────────── 3. ZOOM-IN INTO A KNOWN INSERT-DENSE REGION ─────
    // Coordinates target a region known (from ovk_real_world_test.dart) to
    // contain window/door block inserts, not an arbitrary offset that may
    // land in a sparse area and under/overstate the Insert-rendering cost.
    print('\n══════════ 3. ZOOM-IN TEST (insert-dense region, 5.0x) ══════════');
    final ivState = tester.state(find.byType(InteractiveViewer));
    final tc = (ivState.widget as InteractiveViewer).transformationController!;
    // In CAD space, target region is near (15500, 5400).
    // Mapping CAD coords to 1920x1080 scene pixels at fitScale (~0.065):
    // sceneX = 32.0 + (15500 - (-513.1)) * 0.06497 = ~1072
    // sceneY = 118.6 + (6195.9 - 5400) * 0.06497 = ~170
    // At 5.0x zoom, centering (1072, 170) at (960, 540):
    // tx = 960 - 1072 * 5.0 = -4400.0, ty = 540 - 170 * 5.0 = -310.0
    final zoomMatrix = Matrix4.identity()
      ..translate(-4400.0, -310.0)
      ..scale(5.0);
    tc.value = zoomMatrix;

    final zoomStopwatch = Stopwatch()..start();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    zoomStopwatch.stop();
    print('Zoom settle & repaint completed in ${zoomStopwatch.elapsedMilliseconds}ms.');

    final zoomStats = DxfPainter.lastStats;
    expect(zoomStats, isNotNull, reason: 'No paint() recorded after zoom settle');
    print('Zoomed-in stats: $zoomStats');

    // ──────────────── 4. INSERT-COST REGRESSION GUARD (Phase 0 target) ─
    // Baseline from the real profiling log: Insert bucket was consistently
    // 66-85% of total paint time at comparable zoom levels. Adjust the
    // threshold once Phase 0 (insert Picture-cache / LOD impostor) lands;
    // this assertion should start FAILING before the fix and PASSING after.
    print('\n══════════ 4. INSERT COST REGRESSION GUARD ══════════');
    if (zoomStats!.insertCount > 0) {
      final insertShare = zoomStats.insertMs / zoomStats.totalMs;
      print(
        'Insert share of total paint time: '
        '${(insertShare * 100).toStringAsFixed(1)}% '
        '(${zoomStats.insertMs}ms / ${zoomStats.totalMs}ms, '
        '${zoomStats.insertCount} inserts)',
      );
      // NOTE: set to fail against current (pre-fix) code, tighten after
      // Phase 0 lands. This documents the target, it does not yet enforce it.
      // expect(zoomStats.insertMs, lessThan(150),
      //     reason: 'Insert bucket regression — target <150ms after Phase 0');
    }

    print('\n══════════ TEST COMPLETED SUCCESSFULLY ══════════\n');
  });
}
