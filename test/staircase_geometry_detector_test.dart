import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_geometry_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_assemblies.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_opening_contours.dart';
import 'package:kotoview/src/features/structural_designer/widgets/staircase_geometry_dialog.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';

DxfDocument doc(
  List<DxfEntity> entities, {
  Map<String, DxfBlock> blocks = const {},
}) => DxfDocument(
  entities: entities,
  layers: {'0': DxfLayer(name: '0')},
  blocks: blocks,
  bounds: Rect.zero,
  entityStats: {},
  headerVars: {},
);
List<DxfEntity> run({
  double scale = 1,
  double angle = 0,
  bool mirror = false,
  double step = .28,
  int count = 6,
  bool dashed = false,
}) {
  Offset p(double x, double y) {
    if (mirror) x = -x;
    return Offset(
          x * math.cos(angle) - y * math.sin(angle),
          x * math.sin(angle) + y * math.cos(angle),
        ) *
        scale;
  }

  return [
    for (var i = 0; i < count; i++)
      DxfLine(
        p1: p(0, i * step),
        p2: p(.9, i * step),
        lineType: dashed ? 'DASHED' : null,
      ),
    DxfLine(p1: p(0, -.14), p2: p(0, (count - 1) * step + .14)),
    DxfLine(p1: p(.9, -.14), p2: p(.9, (count - 1) * step + .14)),
  ];
}

void main() {
  for (final scale in [1.0, 100.0, 1000.0]) {
    for (final angle in [0.0, .61, 2.4]) {
      test('unlabelled 2D flights: scale=$scale angle=$angle mirrored', () {
        final result = StaircaseGeometryDetector.detect(
          doc(run(scale: scale, angle: angle, mirror: true)),
          scale,
        );
        expect(result.limited, isFalse);
        expect(result.flights, hasLength(1));
        expect(result.flights.single.treads, hasLength(6));
        expect(result.flights.single.spacingM, closeTo(.28, 1e-8));
        expect(result.flights.single.boundarySides, 2);
      });
    }
  }
  test('projects dashed flights and transformed nested block children', () {
    final d = doc(
      [
        const DxfInsert(
          blockName: 'outer',
          insertPoint: Offset(200, 300),
          scaleX: 100,
          scaleY: 100,
          rotationDeg: 37,
        ),
      ],
      blocks: {
        'outer': DxfBlock(
          name: 'outer',
          entities: [
            const DxfInsert(
              blockName: 'flight',
              insertPoint: Offset.zero,
              scaleX: -1,
            ),
          ],
        ),
        'flight': DxfBlock(name: 'flight', entities: run(dashed: true)),
      },
    );
    final result = StaircaseGeometryDetector.detect(d, 100);
    expect(result.flights, hasLength(1));
    expect(result.flights.single.treads, hasLength(6));
  });
  test('multiple unequal L/U arms remain separate geometry proposals', () {
    final entities = [
      ...run(count: 5),
      ...run(count: 8, angle: math.pi / 2).map(
        (e) => DxfLine(
          p1: (e as DxfLine).p1 + const Offset(3, 3),
          p2: e.p2 + const Offset(3, 3),
        ),
      ),
    ];
    final result = StaircaseGeometryDetector.detect(doc(entities), 1);
    expect(result.flights.map((f) => f.treads.length).toSet(), {5, 8});
  });
  test('winder pattern is recognized without parallel tread lines', () {
    final result = StaircaseGeometryDetector.detect(
      doc([
        for (var i = 0; i < 6; i++)
          DxfLine(
            p1: const Offset(2, 2),
            p2: Offset(
              2 + 1.1 * math.cos(i * .26),
              2 + 1.1 * math.sin(i * .26),
            ),
          ),
      ]),
      1,
    );
    expect(result.flights.where((f) => f.isWinder), hasLength(1));
    expect(result.flights.single.polygon.length, greaterThan(3));
  });
  test(
    'three-step quarter-turn winder does not require small angular spacing',
    () {
      final result = StaircaseGeometryDetector.detect(
        doc([
          for (var i = 0; i < 4; i++)
            DxfLine(
              p1: Offset.zero,
              p2: Offset(
                1.2 * math.cos(i * math.pi / 6),
                1.2 * math.sin(i * math.pi / 6),
              ),
            ),
        ]),
        1,
      );
      expect(result.flights.where((f) => f.isWinder), hasLength(1));
    },
  );
  test(
    'thin rail profiles, small furniture lines and irregular spacing do not form flights',
    () {
      expect(
        StaircaseGeometryDetector.detect(doc(run(step: .025)), 1).flights,
        isEmpty,
      );
      expect(
        StaircaseGeometryDetector.detect(
          doc([
            for (var i = 0; i < 8; i++)
              DxfLine(p1: Offset(0, i * .28), p2: Offset(.3, i * .28)),
          ]),
          1,
        ).flights,
        isEmpty,
      );
      expect(
        StaircaseGeometryDetector.detect(
          doc([
            for (final y in [0.0, .2, .55, .8, 1.18, 1.4])
              DxfLine(p1: Offset(0, y), p2: Offset(.9, y)),
          ]),
          1,
        ).flights,
        isEmpty,
      );
    },
  );
  test(
    'hidden layers and paper space are excluded, large drawings fail closed',
    () {
      final d = doc(run());
      d.layers['0'] = d.layers['0']!.copyWith(isVisible: false);
      expect(StaircaseGeometryDetector.detect(d, 1).flights, isEmpty);
      expect(
        StaircaseGeometryDetector.detect(
          doc([
            for (var i = 0; i < 2001; i++)
              DxfLine(p1: Offset(i * 2.0, 0), p2: Offset(i * 2.0, .9)),
          ]),
          1,
        ).limited,
        isTrue,
      );
      expect(StaircaseGeometryDetector.detect(doc(run()), 0).flights, isEmpty);
    },
  );
  test(
    'real BIM strokes find both ground flights but do not invent an upper opening',
    () {
      final raw =
          jsonDecode(
                File(
                  'test/fixtures/bim_staircase_local_strokes.json',
                ).readAsStringSync(),
              )
              as Map;
      StairGeometryResult detect(String rev) =>
          StaircaseGeometryDetector.detect(
            doc([
              for (final row in raw[rev] as List)
                DxfLine(
                  p1: Offset(
                    (row[0] as num).toDouble(),
                    (row[1] as num).toDouble(),
                  ),
                  p2: Offset(
                    (row[2] as num).toDouble(),
                    (row[3] as num).toDouble(),
                  ),
                  lineType: row[4] as String,
                ),
            ]),
            100,
          );
      final ground = detect('revision_VNIEJI');
      expect(
        ground.flights
            .where((f) => !f.isWinder)
            .map((f) => f.treads.length)
            .toSet(),
        {5, 6},
      );
      expect(
        ground.flights
            .where((f) => !f.isWinder)
            .every((f) => (f.spacingM - .28).abs() < 1e-8),
        isTrue,
      );
      expect(ground.flights.where((f) => f.isWinder).length, 2);
      final groups = StaircaseAssembly.group(ground.flights, 100);
      expect(groups, hasLength(1));
      expect(groups.single.flights.where((f) => !f.isWinder), hasLength(2));
      final upper = detect('revision_ZTRFQO');
      expect(upper.flights, isEmpty);
      final linked = StairGeometryResult(
        ground.flights,
        upper.strokes,
        boundaryStrokes: upper.boundaryStrokes,
      );
      expect(
        StaircaseOpeningContours.findAssembly(
          linked,
          groups.single.flights,
          100,
        ),
        hasLength(1),
      );
      expect(
        StaircaseOpeningContours.find(
          linked,
          linked.flights.firstWhere((f) => !f.isWinder),
          100,
        ),
        isNotEmpty,
      );
    },
  );
  testWidgets('proposal confirmation is a zone, never a slab cut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final l = await AppLocalizations.delegate.load(const Locale('bg'));
    StaircaseGeometrySelection? chosen;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('open'),
              onPressed: () async {
                chosen = await showDialog<StaircaseGeometrySelection>(
                  context: context,
                  builder: (_) => StaircaseGeometryDialog(
                    result: StaircaseGeometryDetector.detect(doc(run()), 1),
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
    expect(find.text(l.staircaseDetectionPartial), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l.staircaseUseZone));
    await tester.pumpAndSettle();
    expect(chosen!.polygon, hasLength(4));
    expect(chosen!.isOpening, isFalse);
  });
}
