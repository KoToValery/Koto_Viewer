import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_geometry_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_opening_contours.dart';
import 'package:kotoview/src/features/structural_designer/widgets/staircase_geometry_dialog.dart';
import 'staircase_geometry_detector_test.dart' as geometry;

const outline = [
  Offset(-.15, -.2),
  Offset(1.1, -.2),
  Offset(1.1, .7),
  Offset(1.7, .7),
  Offset(1.7, 1.65),
  Offset(-.15, 1.65),
];
StairGeometryResult evidence({
  bool closed = true,
  bool dashedOutline = false,
}) => StaircaseGeometryDetector.detect(
  geometry.doc([
    ...geometry.run(),
    for (var i = 0; i < outline.length - (closed ? 0 : 1); i++)
      DxfLine(
        p1: outline[i],
        p2: outline[(i + 1) % outline.length],
        lineType: dashedOutline ? 'DASHED' : null,
      ),
    const DxfLine(
      p1: Offset(.5, -.2),
      p2: Offset(.5, -.5),
    ), // Dangling detail does not close a face.
  ]),
  1,
);
void main() {
  test(
    'observed concave contour remains a polygon, including a landing extension',
    () {
      final e = evidence();
      expect(e.flights, hasLength(1));
      final contours = StaircaseOpeningContours.find(e, e.flights.single, 1);
      expect(contours, hasLength(1));
      expect(contours.single.toSet(), outline.toSet());
    },
  );
  test(
    'missing edges, dashed projections and oversized enclosing frames do not invent cuts',
    () {
      for (final e in [
        evidence(closed: false),
        evidence(dashedOutline: true),
      ]) {
        expect(StaircaseOpeningContours.find(e, e.flights.single, 1), isEmpty);
      }
      final e = StaircaseGeometryDetector.detect(
        geometry.doc([
          ...geometry.run(),
          const DxfLine(p1: Offset(-10, -10), p2: Offset(10, -10)),
          const DxfLine(p1: Offset(10, -10), p2: Offset(10, 10)),
          const DxfLine(p1: Offset(10, 10), p2: Offset(-10, 10)),
          const DxfLine(p1: Offset(-10, 10), p2: Offset(-10, -10)),
        ]),
        1,
      );
      expect(StaircaseOpeningContours.find(e, e.flights.single, 1), isEmpty);
    },
  );
  test('lower flight evidence uses only arrival-level boundaries', () {
    final lower = evidence();
    final target = StairGeometryResult(lower.flights, [
      for (var i = 0; i < outline.length; i++)
        (outline[i], outline[(i + 1) % outline.length]),
    ]);
    expect(
      StaircaseOpeningContours.find(
        target,
        target.flights.single,
        1,
      ).single.toSet(),
      outline.toSet(),
    );
  });
  testWidgets(
    'observed opening is offered only on arrival floors and remains a draft',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      StaircaseGeometrySelection? chosen;
      Future<void> open(bool allow) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('open'),
                  onPressed: () async {
                    chosen = await showDialog<StaircaseGeometrySelection>(
                      context: context,
                      builder: (_) => StaircaseGeometryDialog(
                        result: evidence(),
                        allowOpening: allow,
                        referenceLevel: '±0.00',
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      await open(false);
      expect(find.text(l.staircaseUseOpening), findsNothing);
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      await open(true);
      expect(find.text(l.staircaseEvidenceFromLevel('±0.00')), findsOneWidget);
      await tester.tap(find.text(l.staircaseUseOpening));
      await tester.pumpAndSettle();
      expect(chosen!.isOpening, isTrue);
      expect(chosen!.polygon.toSet(), outline.toSet());
      expect(tester.takeException(), isNull);
    },
  );
}
