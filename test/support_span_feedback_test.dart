import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/vertical_capacity_calculator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_span_feedback_cache.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/vertical_capacity_models.dart';
import 'package:kotoview/src/features/structural_designer/rendering/support_span_overlay_layout.dart';

StoreyLevel bay({double h = .25, double scale = 1}) => StoreyLevel(
  id: 'f',
  name: 'f',
  columns: [
    for (final (id, p) in [
      ('a', const Offset(0, 0)),
      ('b', const Offset(6, 0)),
      ('c', const Offset(0, 3)),
      ('d', const Offset(6, 3)),
    ])
      StructuralColumn(
        id: id,
        center: p * scale,
        width: .25 * scale,
        height: .3 * scale,
      ),
  ],
  slabs: [
    StructuralSlab(
      id: 's',
      thickness: h,
      polygon: [
        Offset(-1, -1) * scale,
        Offset(7, -1) * scale,
        Offset(7, 4) * scale,
        Offset(-1, 4) * scale,
      ],
    ),
  ],
);
bool samePair(SupportSpanCheck check, Offset a, Offset b) =>
    (check.segment.$1 == a && check.segment.$2 == b) ||
    (check.segment.$1 == b && check.segment.$2 == a);

void main() {
  test(
    'all problem bays are available simultaneously and respond to assigned thickness',
    () {
      final checks = VerticalCapacityCalculator.evaluateSupportSpans(bay(), 1);
      expect(checks.where((s) => s.isProblematic), hasLength(2));
      expect(
        checks.where((s) => s.isProblematic).map((s) => s.allowableSpanM),
        everyElement(closeTo(4.84, 1e-9)),
      );
      expect(
        VerticalCapacityCalculator.evaluateSupportSpans(
          bay(h: .32),
          1,
        ).where((s) => s.isProblematic),
        isEmpty,
      );
      final report = VerticalCapacityCalculator.evaluateSlabSpan(bay(), 1);
      expect(report.supportSpans, hasLength(checks.length));
      expect(report.isDeflectionSafe, isFalse);
    },
  );
  for (final scale in [1.0, 1000.0]) {
    test(
      'preview insertion splits one bay without hiding the other: $scale',
      () {
        final floor = bay(scale: scale);
        final project = StructuralProject(storeys: [floor]);
        final cache = SupportSpanFeedbackCache();
        final initial = cache.evaluate(project, scale);
        final preview = StructuralColumn(
          id: 'preview',
          center: Offset(3, 0) * scale,
          width: .25 * scale,
          height: .3 * scale,
        );
        final live = cache.evaluate(project, scale, previewColumn: preview);
        expect(initial.where((s) => s.isProblematic), hasLength(2));
        expect(live.where((s) => s.isProblematic), hasLength(1));
        expect(
          live.any(
            (s) => samePair(s, Offset(0, 0) * scale, Offset(6, 0) * scale),
          ),
          isFalse,
        );
        expect(
          live.any(
            (s) =>
                samePair(s, Offset(0, 3) * scale, Offset(6, 3) * scale) &&
                s.isProblematic,
          ),
          isTrue,
        );
        expect(
          identical(
            live,
            cache.evaluate(project, scale, previewColumn: preview),
          ),
          isTrue,
        );
        final committed = cache.evaluate(
          project.copyWith(
            storeys: [
              floor.copyWith(columns: [...floor.columns, preview]),
            ],
          ),
          scale,
        );
        expect(
          committed.map((s) => (s.segment, s.isProblematic)),
          live.map((s) => (s.segment, s.isProblematic)),
        );
        expect(project.activeStorey.columns, hasLength(4));
      },
    );
  }
  test(
    'moving preview replaces its old support and cancellation restores all original problems',
    () {
      final floor = bay();
      final project = StructuralProject(storeys: [floor]);
      final cache = SupportSpanFeedbackCache();
      final original = cache.evaluate(project, 1);
      final col = floor.columns[1].copyWith(center: const Offset(3, 0));
      final live = cache.evaluate(project, 1, previewColumn: col);
      expect(
        live.any(
          (s) =>
              s.segment.$1 == const Offset(6, 0) ||
              s.segment.$2 == const Offset(6, 0),
        ),
        isFalse,
      );
      final restored = cache.evaluate(project, 1);
      expect(restored.map((s) => s.segment), original.map((s) => s.segment));
      expect(
        cache
            .evaluate(
              project.copyWith(
                storeys: [
                  floor.copyWith(
                    slabs: [floor.slabs.single.copyWith(thickness: .4)],
                  ),
                ],
              ),
              1,
            )
            .where((s) => s.isProblematic),
        isEmpty,
      );
    },
  );
  test(
    'separate slab zones use their own thickness; crossing uses the thinner section',
    () {
      final floor = bay().copyWith(
        columns: [
          for (final (id, p) in [
            ('a', const Offset(0, 0)),
            ('b', const Offset(3, 0)),
            ('c', const Offset(6, 0)),
            ('d', const Offset(0, 3)),
            ('e', const Offset(6, 3)),
          ])
            StructuralColumn(id: id, center: p, width: .25, height: .3),
        ],
        slabs: [
          const StructuralSlab(
            id: 'thin',
            thickness: .15,
            polygon: [
              Offset(-1, -1),
              Offset(3, -1),
              Offset(3, 4),
              Offset(-1, 4),
            ],
          ),
          const StructuralSlab(
            id: 'thick',
            thickness: .3,
            polygon: [Offset(3, -1), Offset(7, -1), Offset(7, 4), Offset(3, 4)],
          ),
        ],
      );
      final checks = VerticalCapacityCalculator.evaluateSupportSpans(floor, 1);
      final thin = checks.singleWhere(
        (s) => samePair(s, const Offset(0, 0), const Offset(3, 0)),
      );
      final thick = checks.singleWhere(
        (s) => samePair(s, const Offset(3, 0), const Offset(6, 0)),
      );
      expect(thin.thicknessM, .15);
      expect(thin.isProblematic, isTrue);
      expect(thick.thicknessM, .3);
      expect(thick.isProblematic, isFalse);
      final crossing = checks.singleWhere(
        (s) => samePair(s, const Offset(0, 3), const Offset(6, 3)),
      );
      expect(crossing.thicknessM, .15);
      expect(crossing.slabIds, containsAll(['thin', 'thick']));
      final report = VerticalCapacityCalculator.evaluateSlabSpan(floor, 1);
      expect(report.currentThicknessM, .15);
    },
  );
  test('reversing axes cannot duplicate a problem line', () {
    final floor = bay().copyWith(
      gridAxes: [
        const StructuralGridAxis(
          id: 'a1',
          name: 'A',
          start: Offset(-1, 0),
          end: Offset(7, 0),
        ),
        const StructuralGridAxis(
          id: 'a2',
          name: 'B',
          start: Offset(7, 0),
          end: Offset(-1, 0),
        ),
      ],
    );
    final checks = VerticalCapacityCalculator.evaluateSupportSpans(floor, 1);
    expect(
      checks.where((s) => samePair(s, const Offset(0, 0), const Offset(6, 0))),
      hasLength(1),
    );
  });
  test(
    'a beam elsewhere cannot improve a bay and supported beams split at the live column',
    () {
      final floor = bay(h: .25).copyWith(
        beams: [
          const StructuralBeam(
            id: 'beam',
            start: Offset(0, 0),
            end: Offset(6, 0),
            width: .25,
            depth: .5,
          ),
        ],
      );
      final checks = VerticalCapacityCalculator.evaluateSupportSpans(floor, 1);
      final bottom = checks.singleWhere(
        (s) => samePair(s, const Offset(0, 0), const Offset(6, 0)),
      );
      final top = checks.singleWhere(
        (s) => samePair(s, const Offset(0, 3), const Offset(6, 3)),
      );
      expect(bottom.hasBeams, isTrue);
      expect(bottom.isProblematic, isFalse);
      expect(top.hasBeams, isFalse);
      expect(top.isProblematic, isTrue);
      final live = SupportSpanFeedbackCache().evaluate(
        StructuralProject(storeys: [floor]),
        1,
        previewColumn: const StructuralColumn(
          id: 'preview',
          center: Offset(3, 0),
          width: .25,
          height: .3,
        ),
      );
      expect(
        live.any((s) => samePair(s, const Offset(0, 0), const Offset(6, 0))),
        isFalse,
      );
    },
  );
  test(
    'holes and disconnected slabs never create feedback links over a void',
    () {
      final floor = bay();
      final perforated = floor.copyWith(
        slabs: [
          floor.slabs.single.addOpening([
            const Offset(2, -.5),
            const Offset(4, -.5),
            const Offset(4, .5),
            const Offset(2, .5),
          ]),
        ],
      );
      final checks = VerticalCapacityCalculator.evaluateSupportSpans(
        perforated,
        1,
      );
      expect(
        checks.any((s) => samePair(s, const Offset(0, 0), const Offset(6, 0))),
        isFalse,
      );
      final disconnected = floor.copyWith(
        slabs: [
          const StructuralSlab(
            id: 'left',
            polygon: [
              Offset(-1, -1),
              Offset(2, -1),
              Offset(2, 4),
              Offset(-1, 4),
            ],
          ),
          const StructuralSlab(
            id: 'right',
            polygon: [Offset(4, -1), Offset(7, -1), Offset(7, 4), Offset(4, 4)],
          ),
        ],
      );
      expect(
        VerticalCapacityCalculator.evaluateSupportSpans(
          disconnected,
          1,
        ).any((s) => s.spanM == 6),
        isFalse,
      );
    },
  );
  test(
    'unknown thickness is not silently replaced with 20cm or shown as safe',
    () {
      final invalid = VerticalCapacityCalculator.evaluateSupportSpans(
        bay(h: 0),
        1,
      );
      expect(invalid.every((s) => !s.isDetermined), isTrue);
      expect(
        VerticalCapacityCalculator.evaluateSlabSpan(
          bay(h: 0),
          1,
        ).isSpanDetermined,
        isFalse,
      );
      expect(
        VerticalCapacityCalculator.evaluateSupportSpans(
          bay().copyWith(slabs: []),
          1,
        ),
        isEmpty,
      );
    },
  );
  test(
    'exact screening limit does not add a hidden centimetre to the user thickness',
    () {
      expect(
        VerticalCapacityCalculator.evaluateSupportSpans(
          bay(h: .2),
          1,
        ).first.allowableSpanM,
        closeTo(3.74, 1e-9),
      );
    },
  );
  test(
    'all visible lines remain while badges stay bounded, separated and inside viewport',
    () {
      final checks = [
        for (var i = 0; i < 30; i++)
          SupportSpanCheck(
            segment: (Offset(20, 20 + i * 9), Offset(450, 20 + i * 9)),
            spanM: 6,
            thicknessM: .2,
            allowableSpanM: 3.74,
          ),
      ];
      const viewport = Rect.fromLTWH(0, 0, 480, 320);
      final layout = SupportSpanOverlayLayout.build(
        checks: checks,
        toPixel: (p) => p,
        viewport: viewport,
        labelSize: (_) => const Size(140, 22),
        reserved: [const Rect.fromLTWH(10, 10, 220, 42)],
      );
      expect(layout.lines, hasLength(30));
      expect(layout.labels.length, inInclusiveRange(1, 6));
      for (var i = 0; i < layout.labels.length; i++) {
        expect(viewport.contains(layout.labels[i].rect.topLeft), isTrue);
        expect(viewport.contains(layout.labels[i].rect.bottomRight), isTrue);
        for (var j = i + 1; j < layout.labels.length; j++) {
          expect(
            layout.labels[i].rect.overlaps(layout.labels[j].rect),
            isFalse,
          );
        }
      }
    },
  );
  test(
    'focus label has priority and offscreen links are clipped without changing global counts',
    () {
      const check = SupportSpanCheck(
        segment: (Offset(-100, 100), Offset(400, 100)),
        spanM: 6,
        thicknessM: .25,
        allowableSpanM: 4.84,
      );
      const other = SupportSpanCheck(
        segment: (Offset(0, 200), Offset(400, 200)),
        spanM: 10,
        thicknessM: .2,
        allowableSpanM: 3.74,
      );
      const hidden = SupportSpanCheck(
        segment: (Offset(0, 500), Offset(400, 500)),
        spanM: 10,
        thicknessM: .2,
        allowableSpanM: 3.74,
      );
      final layout = SupportSpanOverlayLayout.build(
        checks: [other, hidden, check],
        toPixel: (p) => p,
        viewport: const Rect.fromLTWH(0, 0, 450, 300),
        focusCad: const Offset(400, 100),
        labelSize: (_) => const Size(100, 20),
        maxLabels: 1,
      );
      expect(layout.lines, hasLength(2));
      expect(layout.labels.single.line.check, same(check));
      expect(layout.lines.first.start, const Offset(0, 100));
    },
  );
  for (final mouse in [false, true]) {
    testWidgets(
      'actual placement previews all bays, commits the preview and Undo restores them: mouse=$mouse',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final floor = bay();
        final document = DxfDocument(
          entities: [],
          layers: {},
          blocks: {},
          headerVars: {},
          bounds: const Rect.fromLTWH(-1, -1, 8, 5),
          entityStats: {},
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StructuralDesignerScreen(
              document: document,
              initialProject: StructuralProject(storeys: [floor]),
              initialCadBounds: document.bounds,
              title: 'spacing-test',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = await AppLocalizations.delegate.load(const Locale('en'));
        Structural2dPainter model() => tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<Structural2dPainter>()
            .first;
        expect(
          model().supportSpanChecks!.where((s) => s.isProblematic),
          hasLength(2),
        );
        await tester.tap(find.text(l.toolColumn));
        await tester.pumpAndSettle();
        final origin = tester.getTopLeft(find.byType(InteractiveViewer).first);
        final position = model().cadToScene(const Offset(3, 0));
        final gesture = await tester.startGesture(
          origin + position + Offset(0, mouse ? 0 : 64),
          kind: mouse ? PointerDeviceKind.mouse : PointerDeviceKind.touch,
        );
        await tester.pump(const Duration(milliseconds: 650));
        expect(model().previewColumnPos!.dx, closeTo(3, .05));
        expect(model().previewColumnPos!.dy, closeTo(0, .05));
        final preview = model().supportSpanChecks!;
        expect(preview.where((s) => s.isProblematic), hasLength(1));
        expect(model().currentStorey.columns, hasLength(4));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(model().currentStorey.columns, hasLength(5));
        expect(
          model().supportSpanChecks!.map((s) => (s.segment, s.isProblematic)),
          preview.map((s) => (s.segment, s.isProblematic)),
        );
        await tester.tap(find.byTooltip(l.undoAction).first);
        await tester.pumpAndSettle();
        expect(model().currentStorey.columns, hasLength(4));
        expect(
          model().supportSpanChecks!.where((s) => s.isProblematic),
          hasLength(2),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'feedback painter renders a compact overview and dense labels without exceptions',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final floor = bay();
      final checks = VerticalCapacityCalculator.evaluateSupportSpans(floor, 1);
      final strings = await AppLocalizations.delegate.load(const Locale('bg'));
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFF10151C), BlendMode.src);
      final painter = Structural2dPainter(
        currentStorey: floor,
        supportSpanChecks: checks,
        spanFocusCad: const Offset(0, 0),
        spanVisibleCadRect: const Rect.fromLTWH(-1, -1, 8, 5),
        cadToScene: (p) => Offset((p.dx + 1) * 80, (4 - p.dy) * 80),
        cadScale: 80,
        showCantileverHeatmap: false,
        l10n: strings,
      );
      painter.paint(canvas, const Size(640, 400));
      final picture = recorder.endRecording();
      final image = await picture.toImage(640, 400);
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      await File(
        '.dart_tool/support_span_feedback_preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    },
  );
}
