import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/initial_scheme_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_placement_domain.dart';
import 'package:kotoview/src/features/structural_designer/analysis/geometric_window_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/vertical_capacity_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';
import 'initial_scheme_generator_test.dart' as fixtures;
import 'package:kotoview/src/features/structural_designer/analysis/wall_placement_network.dart';
import 'package:kotoview/src/features/structural_designer/widgets/initial_scheme_dialog.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';

void main() {
  test(
    'support intervals cannot cross slab openings or disconnected wings',
    () {
      final floor = StoreyLevel(
        id: 'floor',
        name: 'floor',
        columns: const [
          StructuralColumn(id: 'a', center: Offset(1, 2)),
          StructuralColumn(id: 'b', center: Offset(9, 2)),
        ],
        slabs: [
          StructuralSlab(
            id: 'slab',
            polygon: const [
              Offset(0, 0),
              Offset(10, 0),
              Offset(10, 4),
              Offset(0, 4),
            ],
            openings: const [
              [Offset(4, 1), Offset(6, 1), Offset(6, 3), Offset(4, 3)],
            ],
          ),
        ],
      );
      expect(
        VerticalCapacityCalculator.calculateClearSpan(floor, 1).maxSpanM.isNaN,
        isTrue,
      );
      final split = floor.copyWith(
        slabs: [
          StructuralSlab(
            id: 'left',
            polygon: const [
              Offset(0, 0),
              Offset(3, 0),
              Offset(3, 4),
              Offset(0, 4),
            ],
          ),
          StructuralSlab(
            id: 'right',
            polygon: const [
              Offset(7, 0),
              Offset(10, 0),
              Offset(10, 4),
              Offset(7, 4),
            ],
          ),
        ],
      );
      expect(
        VerticalCapacityCalculator.calculateClearSpan(split, 1).maxSpanM.isNaN,
        isTrue,
      );
    },
  );
  test(
    'core traversal reaches connected segments then starts a disconnected wing',
    () {
      final distances = WallPlacementNetwork.distances(
        const [
          PlacementWallSegment(Offset(0, 0), Offset(4, 0), .25),
          PlacementWallSegment(Offset(4, 0), Offset(8, 0), .25),
          PlacementWallSegment(Offset(8, 0), Offset(8, 4), .25),
          PlacementWallSegment(Offset(20, 0), Offset(24, 0), .25),
        ],
        const [
          [Offset(0, 1), Offset(1, 1), Offset(1, 2), Offset(0, 2)],
        ],
        [],
        1,
      );
      expect(distances.every((d) => d.isFinite), isTrue);
      expect(distances[0], lessThan(distances[1]));
      expect(distances[1], lessThan(distances[2]));
      expect(distances[2], lessThan(distances[3]));
    },
  );
  testWidgets('fallback warning and undefined-span display fit the preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (project, _) = fixtures.fixture();
    final runs = [
      fixtures.pair(const Offset(1, 2), const Offset(1.15, 2), 1),
      fixtures.pair(const Offset(5.15, 2), const Offset(5.3, 2), 1),
    ];
    final opening = GeometricWindowOpening(
      start: const Offset(1.15, 2),
      end: const Offset(5.15, 2),
      thickness: .25,
      length: 4,
      barrierPolygon: const [],
    );
    final l = await AppLocalizations.delegate.load(const Locale('bg'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InitialSchemeDialog(
          project: project,
          pairs: runs,
          wallOpenings: [opening],
          scale: 1,
          options: const InitialSchemeOptions(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(l.schemeOpeningFallback), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'all generated sections fit actual walls at rotated plans and CAD scales',
    () {
      for (final scale in [1.0, 100.0, 1000.0]) {
        for (final angle in [0.0, .37]) {
          final (project, runs) = fixtures.fixture(scale: scale, angle: angle);
          final domain = WallPlacementDomain.build(runs, [], scale);
          final proposal = InitialSchemeGenerator.generate(
            project: project,
            wallPairs: runs,
            scale: scale,
          );
          expect(proposal.columns, isNotEmpty);
          for (final c in proposal.columns) {
            expect(domain.contains(c.polygonVertices), isTrue, reason: c.id);
          }
          for (final w in proposal.walls) {
            expect(domain.contains(w.polygonVertices), isTrue, reason: w.id);
          }
        }
      }
    },
  );
  test('wall thinner than both column dimensions cannot host a column', () {
    final (project, _) = fixtures.fixture();
    final runs = [
      fixtures.pair(const Offset(1, 2), const Offset(19, 2), 1, width: .12),
    ];
    final proposal = InitialSchemeGenerator.generate(
      project: project,
      wallPairs: runs,
      scale: 1,
    );
    expect(proposal.isEmpty, isTrue);
  });
  test(
    'quarter turn fits a 25 by 30 section in a 25 cm wall without resizing',
    () {
      final (project, _) = fixtures.fixture();
      final runs = [fixtures.pair(const Offset(1, 2), const Offset(19, 2), 1)];
      final proposal = InitialSchemeGenerator.generate(
        project: project,
        wallPairs: runs,
        scale: 1,
      );
      expect(proposal.columns, isNotEmpty);
      for (final c in proposal.columns) {
        expect(c.width, .25);
        expect(c.height, .3);
        expect(c.rotationRad, closeTo(math.pi / 2, 1e-8));
      }
    },
  );
  test(
    'opening is a marked last resort, never an inferred bridge across a room',
    () {
      for (final scale in [1.0, 1000.0]) {
        final (project, _) = fixtures.fixture(scale: scale);
        Offset p(double x, double y) => Offset(x, y) * scale;
        final runs = [
          fixtures.pair(p(1, 2), p(1.15, 2), scale),
          fixtures.pair(p(5.15, 2), p(5.3, 2), scale),
        ];
        final opening = GeometricWindowOpening(
          start: p(1.15, 2),
          end: p(5.15, 2),
          thickness: .25 * scale,
          length: 4 * scale,
          barrierPolygon: WallPlacementDomain.strip(
            p(1.15, 2),
            p(5.15, 2),
            .25 * scale,
          ),
        );
        final noEvidence = InitialSchemeGenerator.generate(
          project: project,
          wallPairs: runs,
          scale: scale,
        );
        expect(noEvidence.columns, isEmpty);
        final result = InitialSchemeGenerator.generate(
          project: project,
          wallPairs: runs,
          wallOpenings: [opening],
          scale: scale,
        );
        expect(result.columns, isNotEmpty);
        expect(result.openingColumnIds.length, result.columns.length);
        final domain = WallPlacementDomain.build(runs, [opening], scale);
        for (final c in result.columns) {
          expect(
            domain.contains(c.polygonVertices, includeOpenings: true),
            isTrue,
          );
          expect(c.generatedBy, 'initial-scheme-v2-opening-review');
        }
        expect(result.walls, isEmpty);
        final restored = StructuralProject.fromJson(
          project
              .copyWith(storeys: [result.apply(project.activeStorey)])
              .toJson(),
        );
        expect(
          restored.activeStorey.columns.first.generatedBy,
          'initial-scheme-v2-opening-review',
        );
      }
    },
  );
  test('opening without two real jambs is not a placement corridor', () {
    final (project, runs) = fixtures.fixture();
    final fake = GeometricWindowOpening(
      start: const Offset(4, 4),
      end: const Offset(6, 4),
      thickness: .3,
      length: 2,
      barrierPolygon: const [],
    );
    final domain = WallPlacementDomain.build(runs, [fake], 1);
    expect(domain.openings, isEmpty);
    final result = InitialSchemeGenerator.generate(
      project: project,
      wallPairs: runs,
      wallOpenings: [fake],
      scale: 1,
    );
    expect(result.openingColumnIds, isEmpty);
  });
  test(
    'solid alternatives prevent opening fallback and slab holes stay forbidden',
    () {
      final (project, _) = fixtures.fixture();
      final runs = [
        fixtures.pair(const Offset(1, 2), const Offset(1.15, 2), 1),
        fixtures.pair(const Offset(5.15, 2), const Offset(5.3, 2), 1),
        fixtures.pair(const Offset(1, 2.5), const Offset(6, 2.5), 1),
      ];
      final opening = GeometricWindowOpening(
        start: const Offset(1.15, 2),
        end: const Offset(5.15, 2),
        thickness: .25,
        length: 4,
        barrierPolygon: const [],
      );
      final result = InitialSchemeGenerator.generate(
        project: project,
        wallPairs: runs,
        wallOpenings: [opening],
        scale: 1,
      );
      expect(result.columns.length + result.walls.length, greaterThan(0));
      expect(result.openingColumnIds, isEmpty);
      final holeProject = project.copyWith(
        storeys: [
          project.activeStorey.copyWith(
            slabs: [
              project.activeStorey.slabs.single.copyWith(
                openings: [
                  ...project.activeStorey.slabs.single.openings,
                  const [
                    Offset(.8, 1.8),
                    Offset(5.5, 1.8),
                    Offset(5.5, 2.2),
                    Offset(.8, 2.2),
                  ],
                ],
              ),
            ],
          ),
        ],
      );
      final blocked = InitialSchemeGenerator.generate(
        project: holeProject,
        wallPairs: runs.take(2).toList(),
        wallOpenings: [opening],
        scale: 1,
      );
      expect(blocked.openingColumnIds, isEmpty);
    },
  );
  test('preview and manual analysis share the exact same support interval', () {
    final (project, runs) = fixtures.fixture();
    final result = InitialSchemeGenerator.generate(
      project: project,
      wallPairs: runs,
      scale: 1,
    );
    final floor = result
        .apply(project.activeStorey)
        .copyWith(gridAxes: project.effectiveGridAxes);
    final manual = VerticalCapacityCalculator.calculateClearSpan(floor, 1);
    expect(result.maxSupportSpanM, manual.maxSpanM);
    expect(result.criticalSupportSpan, manual.criticalSpanSegment);
    final assessment = VerticalCapacityCalculator.evaluateSlabSpan(floor, 1);
    expect(result.spanCheck!.isDeflectionSafe, assessment.isDeflectionSafe);
    expect(
      result.spanCheck!.recommendedMinThicknessM,
      assessment.recommendedMinThicknessM,
    );
  });
  test(
    'missing supports stay undetermined and intervals over ten metres are retained',
    () {
      const floor = StoreyLevel(id: 'floor', name: 'floor');
      expect(
        VerticalCapacityCalculator.calculateClearSpan(floor, 1).maxSpanM.isNaN,
        isTrue,
      );
      final report = VerticalCapacityCalculator.analyzeProject(
        StructuralProject(storeys: [floor]),
      );
      expect(report.slabChecks.first.isDeflectionSafe, isFalse);
      expect(report.slabChecks.first.isSpanDetermined, isFalse);
      final supported = floor.copyWith(
        columns: const [
          StructuralColumn(id: 'a', center: Offset(0, 0)),
          StructuralColumn(id: 'b', center: Offset(14, 0)),
        ],
      );
      expect(
        VerticalCapacityCalculator.calculateClearSpan(supported, 1).maxSpanM,
        14,
      );
    },
  );
  test(
    'core at right does not exhaust wall count before looking at left side',
    () {
      final (base, _) = fixtures.fixture();
      final floor = base.activeStorey.copyWith(
        slabs: [
          base.activeStorey.slabs.single.copyWith(
            openings: [
              const [
                Offset(15, 6),
                Offset(17, 6),
                Offset(17, 10),
                Offset(15, 10),
              ],
            ],
          ),
        ],
      );
      final runs = <WallPairCandidate>[
        for (final x in [2.0, 14.5, 17.5])
          fixtures.pair(Offset(x, 1), Offset(x, 15), 1),
        for (final y in [2.0, 14.0])
          fixtures.pair(Offset(1, y), Offset(19, y), 1),
      ];
      final result = InitialSchemeGenerator.generate(
        project: base.copyWith(storeys: [floor]),
        wallPairs: runs,
        scale: 1,
      );
      expect(result.walls.any((w) => w.center.dx < 5), isTrue);
      expect(result.walls.any((w) => w.center.dx > 14), isTrue);
    },
  );
}
