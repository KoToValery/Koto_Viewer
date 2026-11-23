import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/models/element_check_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/widgets/element_check_panel.dart';

ElementUtilization _element(String id, double percent) => ElementUtilization(
  elementId: id,
  storeyId: 's',
  type: CheckedElementType.column,
  checks: [
    ElementCheck(CheckKind.columnAxial, percent * 4, 400),
    ElementCheck(CheckKind.punching, percent * 0.008, 1.0),
    const ElementCheck(CheckKind.columnSeismicAxial, double.nan, 0.65),
  ],
  axialUls: percent * 4,
  axialQuasiPermanent: percent * 3,
  slabReactionUls: percent * 2,
);

Widget _host(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
);

void main() {
  group('utilization scale', () {
    test('levels and text', () {
      expect(UtilizationLevel.of(0.5), UtilizationLevel.ok);
      expect(UtilizationLevel.of(0.85), UtilizationLevel.ok);
      expect(UtilizationLevel.of(0.86), UtilizationLevel.near);
      expect(UtilizationLevel.of(1.0), UtilizationLevel.near);
      expect(UtilizationLevel.of(1.01), UtilizationLevel.over);
      expect(UtilizationLevel.of(double.nan), UtilizationLevel.unknown);
      expect(utilizationText(0.943), '94 %');
      expect(utilizationText(12), '>999 %');
      expect(utilizationText(double.nan), '—');
    });

    test('governing check is the highest determined one', () {
      final e = _element('c', 80);
      expect(e.governing!.kind, CheckKind.columnAxial);
      expect(e.level, UtilizationLevel.ok);
      expect(_element('c', 120).level, UtilizationLevel.over);
    });
  });

  for (final locale in const [Locale('en'), Locale('bg')]) {
    testWidgets('check panel and details fit a 320 px phone (${locale.languageCode})', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(locale, ElementCheckPanel(utilization: _element('c', 94))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Only determined checks are shown; the undetermined seismic one is not.
      expect(find.textContaining('94 %'), findsOneWidget);
      expect(find.textContaining('ν_d'), findsNothing);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(find.text(l10n.checkPreliminary), findsOneWidget);
      expect(find.textContaining('kN'), findsWidgets);
    });
  }

  testWidgets('panel without result explains itself', (tester) async {
    await tester.pumpWidget(
      _host(const Locale('en'), const ElementCheckPanel(utilization: null)),
    );
    expect(find.text('Not available for this element'), findsOneWidget);
    await tester.pumpWidget(
      _host(
        const Locale('en'),
        const ElementCheckPanel(utilization: null, running: true),
      ),
    );
    expect(find.text('Checking…'), findsOneWidget);
  });

  group('plan painter', () {
    Future<List<int>> paint(PreliminaryCheckReport? report, {bool stale = false}) async {
      const column = StructuralColumn(
        id: 'c',
        center: Offset(5, 5),
        width: 0.5,
        height: 0.5,
      );
      const floor = StoreyLevel(id: 's', name: 's', columns: [column]);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFF161B22), BlendMode.src);
      Structural2dPainter(
        currentStorey: floor,
        cadUnitsPerMeter: 1,
        cadScale: 40,
        checkReport: report,
        checkStale: stale,
        showCantileverHeatmap: false,
        cadToScene: (p) => Offset(p.dx * 40, p.dy * 40),
      ).paint(canvas, const Size(400, 400));
      final image = await recorder.endRecording().toImage(400, 400);
      final data = await image.toByteData(format: ImageByteFormat.rawRgba);
      return data!.buffer.asUint8List();
    }

    ({int r, int g, int b}) centre(List<int> px) {
      // Column centre is (200, 200); sample just inside its fill.
      final i = (206 * 400 + 206) * 4;
      return (r: px[i], g: px[i + 1], b: px[i + 2]);
    }

    PreliminaryCheckReport report(double percent) => PreliminaryCheckReport(
      elements: {'s/c': _element('c', percent)},
      slabs: const [],
      unsupported: const [],
    );

    testWidgets('over-limit column is drawn red, near-limit orange', (tester) async {
      await tester.runAsync(() async {
        final over = centre(await paint(report(130)));
        final near = centre(await paint(report(95)));
        final plain = centre(await paint(null));
        expect(over.r, greaterThan(over.b + 60));
        expect(over.g, lessThan(80));
        expect(near.r, greaterThan(near.b + 100));
        expect(near.g, greaterThan(over.g + 40));
        expect(plain.b, greaterThan(plain.r + 60));
      });
    });

    testWidgets('slab badge and unsupported wash are drawn', (tester) async {
      await tester.runAsync(() async {
        final withSlab = PreliminaryCheckReport(
          elements: const {},
          slabs: [
            SlabCheckResult(
              storeyId: 's',
              component: 0,
              deflection: const ElementCheck(CheckKind.slabDeflection, 20, 10),
              deflectionPointCad: const Offset(2, 2),
              bending: const ElementCheck(CheckKind.slabBending, 5, 50),
              bendingPointCad: const Offset(3, 3),
            ),
          ],
          unsupported: const [
            UnsupportedSlabArea('s', [
              [Offset(6, 6), Offset(8, 6), Offset(8, 8), Offset(6, 8)],
            ], 4),
          ],
        );
        final px = await paint(withSlab);
        // Wash over (7, 7) metres -> pixel (280, 280): red tint over the dark ground.
        final i = (280 * 400 + 280) * 4;
        expect(px[i], greaterThan(px[i + 2] + 15));
        // The badge sits at the deflection point (2, 2) -> (80, 80).
        var lit = 0;
        for (var y = 70; y < 92; y++) {
          for (var x = 60; x < 140; x++) {
            final k = (y * 400 + x) * 4;
            if (px[k] > 180 && px[k + 1] < 120) lit++;
          }
        }
        expect(lit, greaterThan(10));
      });
    });
  });
}
