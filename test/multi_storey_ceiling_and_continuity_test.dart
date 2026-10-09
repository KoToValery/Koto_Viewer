import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/widgets/initial_scheme_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/initial_scheme_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_contact_geometry.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_scheme_readiness.dart';
import 'package:kotoview/src/features/structural_designer/analysis/vertical_capacity_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_3d_mesh_builder.dart';
import 'package:kotoview/src/features/structural_designer/services/slab_opening_placement.dart';
import 'initial_scheme_generator_test.dart' show fixture, pair;

void main() {
  test(
    'opening owner remains the working storey; its ceiling follows the next actual elevation',
    () {
      final (p, _) = fixture();
      final base = p.activeStorey.copyWith(height: 2.8);
      final upper = base.copyWith(
        id: 'upper',
        elevation: 3.2,
        height: 2.8,
        slabs: [
          base.slabs.single.copyWith(
            id: 'upper-slab',
            openings: [],
            openingTypes: [],
          ),
        ],
      );
      final roof = upper.copyWith(
        id: 'roof',
        elevation: 6.5,
        height: 3.1,
        slabs: [upper.slabs.single.copyWith(id: 'roof-slab')],
      );
      var project = p.copyWith(storeys: [base, roof, upper]);
      final opening = [
        const Offset(12, 4),
        const Offset(14, 4),
        const Offset(14, 6),
        const Offset(12, 6),
      ];
      final result = SlabOpeningPlacement.apply(
        slabs: project.activeStorey.slabs,
        polygon: opening,
        scale: 1,
        type: SlabOpeningType.staircase,
      );
      expect(result.accepted, isTrue);
      project = project.copyWith(
        storeys: [
          base.copyWith(slabs: result.slabs),
          roof,
          upper,
        ],
      );
      project = StructuralProject.fromJson(
        jsonDecode(jsonEncode(project.toJson())),
      );
      expect(project.storeys.first.slabs.single.openings, hasLength(2));
      expect(project.storeys[2].slabs.single.openings, isEmpty);
      for (final (index, expected) in [(0, 3.15), (2, 6.45), (1, 9.55)]) {
        final floor = project.copyWith(activeStoreyIndex: index).activeStorey;
        expect(
          floor.structuralElevationFor(floor.slabs.single),
          closeTo(expected, 1e-9),
        );
        final mesh = Structural3dMeshBuilder.buildProjectMesh(
          project,
          cadUnitsPerMeter: 1000,
        );
        final group = mesh.groups!.singleWhere((g) => g.id == floor.id);
        expect(
          group.triangles
              .expand((t) => [t.v0.z, t.v1.z, t.v2.z])
              .reduce(math.max),
          closeTo(expected * 1000, 1e-6),
        );
      }
      expect(
        StructuralSchemeReadiness.evaluate(
          project,
          1,
        ).openings.last.concreteTop,
        closeTo(3.15, 1e-9),
      );
    },
  );

  test(
    'each report uses its own ceiling thickness and loads; lower columns accumulate ceilings above',
    () {
      final (p, _) = fixture();
      final slab = p.activeStorey.slabs.single;
      const col = StructuralColumn(
        id: 'base-c',
        center: Offset(10, 8),
        width: .5,
        height: .5,
      );
      final base = p.activeStorey.copyWith(
        columns: [col],
        slabs: [slab.copyWith(thickness: .18)],
      );
      final upper = base.copyWith(
        id: 'upper',
        elevation: 3,
        columns: [col.copyWith(id: 'upper-c')],
        slabs: [
          slab.copyWith(
            id: 'upper-s',
            thickness: .31,
            openings: [],
            openingTypes: [],
          ),
        ],
      );
      final project = p.copyWith(storeys: [upper, base], activeStoreyIndex: 1);
      final report = VerticalCapacityCalculator.analyzeProject(project);
      final a = report.columnChecks.singleWhere((c) => c.columnId == 'base-c');
      final b = report.columnChecks.singleWhere((c) => c.columnId == 'upper-c');
      expect(a.storeyIndex, 1);
      expect(b.storeyIndex, 0);
      expect(
        a.floorShearForceVedKn / a.tributaryAreaM2,
        closeTo(1.35 * (25 * .18 + 1.5) + 1.5 * 2, 1e-9),
      );
      expect(
        b.floorShearForceVedKn / b.tributaryAreaM2,
        closeTo(1.35 * (25 * .31 + 1.5) + 1.5 * 2, 1e-9),
      );
      expect(
        report.slabChecks
            .singleWhere((s) => s.storeyId == base.id)
            .currentThicknessM,
        .18,
      );
      expect(
        report.slabChecks
            .singleWhere((s) => s.storeyId == upper.id)
            .currentThicknessM,
        .31,
      );
      expect(
        a.accumulatedLoadNedKn,
        closeTo(
          a.floorShearForceVedKn + 25 * .25 * 3 * 1.35 + b.accumulatedLoadNedKn,
          1e-9,
        ),
      );
      final seismic = SeismicAnalysisCalculator.analyzeProject(project);
      expect(
        seismic.storeyChecks
            .singleWhere((s) => s.storeyId == base.id)
            .floorAreaM2,
        312,
      );
      expect(
        seismic.storeyChecks
            .singleWhere((s) => s.storeyId == upper.id)
            .floorAreaM2,
        320,
      );
    },
  );

  for (final scale in [1.0, 1000.0]) {
    for (final angle in [0.0, .41]) {
      test(
        '3D subtracts multiple holes in concave plate: scale=$scale angle=$angle',
        () {
          Offset tr(double x, double y) =>
              Offset(
                x * math.cos(angle) - y * math.sin(angle),
                x * math.sin(angle) + y * math.cos(angle),
              ) *
              scale;
          final slab = StructuralSlab(
            id: 'slab',
            polygon: [
              tr(0, 0),
              tr(8, 0),
              tr(8, 3),
              tr(5, 3),
              tr(5, 8),
              tr(0, 8),
            ],
            openings: [
              [tr(1, 1), tr(2, 1), tr(2, 2), tr(1, 2)],
              [tr(1, 4), tr(1, 6), tr(3, 6), tr(3, 4)],
            ],
          );
          final mesh = Structural3dMeshBuilder.buildProjectMesh(
            StructuralProject(
              storeys: [
                StoreyLevel(
                  id: 'f',
                  name: 'f',
                  elevation: 3,
                  height: 3,
                  slabs: [slab],
                ),
              ],
            ),
            cadUnitsPerMeter: scale,
          );
          for (final elevation in [5.95, 5.75]) {
            final caps = mesh.triangles.where(
              (t) => [
                t.v0.z,
                t.v1.z,
                t.v2.z,
              ].every((z) => (z - elevation * scale).abs() < 1e-7),
            );
            var area = 0.0;
            for (final t in caps) {
              final poly = [
                Offset(t.v0.x, t.v0.y),
                Offset(t.v1.x, t.v1.y),
                Offset(t.v2.x, t.v2.y),
              ];
              area += StructuralSlab.calculateArea(poly) / (scale * scale);
              for (final hole in slab.openings) {
                expect(
                  SlabContactGeometry.measure(poly, [
                    StructuralSlab(id: 'hole', polygon: hole),
                  ], scale)!.areaM2,
                  closeTo(0, 1e-8),
                );
              }
            }
            expect(area, closeTo(slab.netArea / (scale * scale), 1e-8));
          }
        },
      );
    }
  }

  for (final scale in [1.0, 1000.0]) {
    test(
      'upper scheme preserves exact geometry through all variants: $scale',
      () {
        final (p, _) = fixture(scale: scale);
        final c = StructuralColumn(
          id: 'c',
          name: 'C7',
          center: Offset(2, 2) * scale,
          width: .3 * scale,
          height: .4 * scale,
          rotationRad: .2,
        );
        final w = StructuralShearWall(
          id: 'w',
          name: 'W4',
          start: Offset(10, 2) * scale,
          end: Offset(10, 5.8) * scale,
          thickness: .3 * scale,
          referenceLine: ShearWallReferenceLine.leftFace,
          isFlipped: true,
        );
        final base = p.activeStorey.copyWith(columns: [c], shearWalls: [w]);
        final upper = base.copyWith(
          id: 'upper',
          elevation: 3,
          columns: [],
          shearWalls: [],
          slabs: [base.slabs.single.copyWith(openings: [], openingTypes: [])],
        );
        final runs = [
          pair(Offset(2, 1) * scale, Offset(2, 15) * scale, scale, width: .8),
          pair(Offset(10, 1) * scale, Offset(10, 15) * scale, scale, width: .8),
          pair(Offset(18, 1) * scale, Offset(18, 15) * scale, scale, width: .8),
        ];
        final project = p.copyWith(
          storeys: [base, upper],
          activeStoreyIndex: 1,
        );
        for (final variant in [0, 1, 8, 50]) {
          final proposal = InitialSchemeGenerator.generate(
            project: project,
            wallPairs: runs,
            scale: scale,
            variant: variant,
          );
          expect(proposal.columns, hasLength(1));
          expect(proposal.walls, hasLength(1));
          expect(proposal.columns.single.polygonVertices, c.polygonVertices);
          expect(proposal.columns.single.displayName, 'C7');
          expect(proposal.walls.single.polygonVertices, w.polygonVertices);
          expect(proposal.walls.single.length, closeTo(3.8 * scale, 1e-8));
          final applied = proposal.apply(upper);
          final repeated = InitialSchemeGenerator.generate(
            project: project.copyWith(storeys: [base, applied]),
            wallPairs: runs,
            scale: scale,
            variant: 99,
          );
          expect(repeated.apply(applied).columns, hasLength(1));
          expect(repeated.apply(applied).shearWalls, hasLength(1));
        }
      },
    );
  }

  test(
    'blocked continuation and an empty immediate lower floor never trigger new positions',
    () {
      final (p, runs) = fixture();
      const c = StructuralColumn(
        id: 'c',
        center: Offset(2, 2),
        width: .25,
        height: .3,
      );
      final base = p.activeStorey.copyWith(columns: [c]);
      final upper = base.copyWith(
        id: 'upper',
        elevation: 3,
        columns: [],
        slabs: [
          base.slabs.single.addOpening([
            const Offset(1, 1),
            const Offset(3, 1),
            const Offset(3, 3),
            const Offset(1, 3),
          ]),
        ],
      );
      final project = p.copyWith(storeys: [base, upper], activeStoreyIndex: 1);
      final rejected = InitialSchemeGenerator.generate(
        project: project,
        wallPairs: runs,
        scale: 1,
      );
      expect(rejected.columns, isEmpty);
      expect(rejected.walls, isEmpty);
      expect(rejected.rejectionReasons['slab'], 1);
      final middle = base.copyWith(
        id: 'middle',
        elevation: 1.5,
        columns: [],
        shearWalls: [],
      );
      final empty = InitialSchemeGenerator.generate(
        project: project.copyWith(
          storeys: [base, middle, upper],
          activeStoreyIndex: 2,
        ),
        wallPairs: runs,
        scale: 1,
      );
      expect(empty.columns, isEmpty);
      expect(empty.walls, isEmpty);
      expect(empty.continuationSource, '+1.50');
    },
  );

  test(
    'regeneration replaces stale automatic supports but preserves and flags manual mismatches',
    () {
      final (p, runs) = fixture();
      const c = StructuralColumn(
        id: 'c',
        center: Offset(2, 2),
        width: .25,
        height: .3,
      );
      final base = p.activeStorey.copyWith(columns: [c]);
      final upper = base.copyWith(
        id: 'upper',
        elevation: 3,
        columns: [
          c.copyWith(
            id: 'stale',
            center: const Offset(10, 8),
            generatedBy: 'initial-scheme-v1',
          ),
          c.copyWith(id: 'manual', center: const Offset(18, 14)),
        ],
      );
      final proposal = InitialSchemeGenerator.generate(
        project: p.copyWith(storeys: [base, upper], activeStoreyIndex: 1),
        wallPairs: runs,
        scale: 1,
      );
      final applied = proposal.apply(upper);
      expect(
        applied.columns.map((c) => c.center),
        containsAll([c.center, const Offset(18, 14)]),
      );
      expect(applied.columns.any((c) => c.id == 'stale'), isFalse);
      expect(proposal.rejectionReasons['continuity'], 1);
    },
  );
  for (final language in ['bg', 'en']) {
    testWidgets(
      'upper preview offers continuation without independent variant controls: $language',
      (tester) async {
        final (p, runs) = fixture();
        const col = StructuralColumn(
          id: 'c',
          center: Offset(2, 2),
          width: .25,
          height: .3,
        );
        final base = p.activeStorey.copyWith(columns: [col]);
        final upper = base.copyWith(id: 'upper', elevation: 3, columns: []);
        final strings = await AppLocalizations.delegate.load(Locale(language));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: InitialSchemeDialog(
                project: p.copyWith(
                  storeys: [base, upper],
                  activeStoreyIndex: 1,
                ),
                pairs: runs,
                scale: 1,
                options: const InitialSchemeOptions(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(strings.schemeContinueLower('±0.00')), findsOneWidget);
        expect(find.byKey(const ValueKey('next-scheme')), findsNothing);
        expect(
          find.byKey(const ValueKey('adaptive-scheme-sizes')),
          findsNothing,
        );
        expect(find.textContaining(strings.schemeCoverage), findsNothing);
        expect(find.text('1 C · 0 W'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
