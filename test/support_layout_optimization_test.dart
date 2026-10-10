import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/initial_scheme_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_boundary_geometry.dart';
import 'package:kotoview/src/features/structural_designer/analysis/column_vertical_continuity.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_support_topology.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_layout_evaluator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_layout_optimizer.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_placement_rules.dart';
import 'package:kotoview/src/features/structural_designer/analysis/vertical_capacity_calculator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_placement_domain.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_placement_network.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'initial_scheme_generator_test.dart' as f;
import 'package:kotoview/src/features/structural_designer/models/vertical_capacity_models.dart';

List<Offset> rect(double x, double y, double w, double h) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x + w, y + h),
  Offset(x, y + h),
];

void main() {
  test('mixed supports have collision checks and distinct spacing rules', () {
    const wall = StructuralShearWall(
      id: 'wall',
      start: Offset(0, 0),
      end: Offset(1.5, 0),
    );
    const column = StructuralColumn(id: 'column', center: Offset(2, 0));
    String? reason(
      bool isWall, {
      List<StructuralColumn> columns = const [],
      List<StructuralShearWall> walls = const [],
      Offset? direction,
    }) => SupportPlacementRules.separationReason(
      polygon: column.polygonVertices,
      center: column.center,
      isWall: isWall,
      columns: columns,
      walls: walls,
      scale: 1,
      columnSpacingM: 2,
      wallSpacingM: 2,
      wallDirection: direction,
    );
    expect(reason(false, walls: [wall]), isNull);
    expect(
      reason(
        false,
        columns: [const StructuralColumn(id: 'close', center: Offset(1, 0))],
      ),
      'column-spacing',
    );
    final overlap = column.copyWith(center: const Offset(1.4, 0));
    expect(
      SupportPlacementRules.separationReason(
        polygon: overlap.polygonVertices,
        center: overlap.center,
        isWall: false,
        columns: [],
        walls: [wall],
        scale: 1,
        columnSpacingM: 2,
        wallSpacingM: 2,
      ),
      'collision',
    );
    expect(
      reason(true, walls: [wall], direction: const Offset(1, 0)),
      'wall-spacing',
    );
    expect(reason(true, walls: [wall], direction: const Offset(0, 1)), isNull);
  });

  test(
    'long edge and corner classification survives rotation and CAD units',
    () {
      for (final scale in [1.0, 100.0, 1000.0]) {
        for (final angle in [0.0, .43]) {
          Offset p(double x, double y) =>
              Offset(
                x * math.cos(angle) - y * math.sin(angle),
                x * math.sin(angle) + y * math.cos(angle),
              ) *
              scale;
          final slab = StructuralSlab(
            id: 'slab',
            polygon: [p(0, 0), p(100, 0), p(100, 20), p(0, 20)],
          );
          PunchingPositionCheck check(double x, double y) =>
              SlabBoundaryGeometry.classify(
                StructuralColumn(
                  id: 'c',
                  center: p(x, y),
                  width: .3 * scale,
                  height: .3 * scale,
                  rotationRad: angle,
                ),
                [slab],
                scale,
                .17,
              );
          expect(check(10, .2).position, PunchingSupportPosition.edge);
          expect(check(.2, .2).position, PunchingSupportPosition.corner);
          expect(check(10, 10).position, PunchingSupportPosition.interior);
        }
      }
    },
  );

  test('shared slab seams do not classify an interior column as an edge', () {
    final slabs = [
      StructuralSlab(id: 'left', polygon: rect(0, 0, 10, 10)),
      StructuralSlab(id: 'right', polygon: rect(10, 0, 10, 10)),
    ];
    final check = SlabBoundaryGeometry.classify(
      const StructuralColumn(id: 'c', center: Offset(10, 5)),
      slabs,
      1,
      .17,
    );
    expect(check.position, PunchingSupportPosition.interior);
    final partial = [
      slabs.first,
      StructuralSlab(id: 'right', polygon: rect(10, 2, 10, 8)),
    ];
    expect(
      SlabBoundaryGeometry.classify(
        const StructuralColumn(id: 'c', center: Offset(9.8, 1)),
        partial,
        1,
        .17,
      ).position,
      PunchingSupportPosition.edge,
    );
  });

  test('opening proximity requests control-perimeter review beyond 2d', () {
    final slab = StructuralSlab(
      id: 's',
      polygon: rect(0, 0, 10, 10),
      openings: [rect(5, 4, 1, 2)],
    );
    final check = SlabBoundaryGeometry.classify(
      const StructuralColumn(id: 'c', center: Offset(4.2, 5)),
      [slab],
      1,
      .17,
    );
    expect(check.position, PunchingSupportPosition.interior);
    expect(check.nearOpening, isTrue);
    final report = VerticalCapacityCalculator.analyzeProject(
      StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'f',
            name: 'f',
            columns: const [StructuralColumn(id: 'c', center: Offset(4.2, 5))],
            slabs: [slab],
          ),
        ],
      ),
    );
    expect(report.columnChecks.single.punchingRequiresReview, isTrue);
  });

  test(
    'punching uses the local plate thickness and circular interior perimeter',
    () {
      final floor = StoreyLevel(
        id: 'f',
        name: 'f',
        columns: const [
          StructuralColumn(id: 'thin', center: Offset(2, 2)),
          StructuralColumn(id: 'thick', center: Offset(12, 2)),
          StructuralColumn(
            id: 'circle',
            center: Offset(5, 5),
            shape: ColumnShape.circular,
            width: .3,
          ),
        ],
        slabs: [
          StructuralSlab(id: 'thin', polygon: rect(0, 0, 8, 8), thickness: .15),
          StructuralSlab(
            id: 'thick',
            polygon: rect(10, 0, 8, 8),
            thickness: .35,
          ),
        ],
      );
      final project = StructuralProject(storeys: [floor]);
      final a = VerticalCapacityCalculator.analyzeProject(project);
      final b = VerticalCapacityCalculator.analyzeProject(
        project.copyWith(
          storeys: [floor.copyWith(slabs: floor.slabs.reversed.toList())],
        ),
      );
      for (final check in a.columnChecks) {
        expect(
          b.columnChecks
              .firstWhere((c) => c.columnId == check.columnId)
              .punchingUtilization,
          closeTo(check.punchingUtilization, 1e-9),
        );
      }
      expect(
        a.columnChecks
            .firstWhere((c) => c.columnId == 'circle')
            .punchingRequiresReview,
        isTrue,
      );
    },
  );

  test('wall traversal measures proximity to a whole long opening edge', () {
    final distance = WallPlacementNetwork.distances(
      const [
        PlacementWallSegment(Offset(5, 1), Offset(7, 1), .25),
        PlacementWallSegment(Offset(0, 0), Offset(2, 0), .25),
      ],
      [rect(0, 2, 12, 2)],
      [],
      1,
    );
    expect(distance.first, lessThan(distance.last));
  });

  test('closed orthogonal support graph yields two actual fields', () {
    final floor = StoreyLevel(
      id: 'f',
      name: 'f',
      columns: [
        for (final x in [0.0, 4.0])
          for (final y in [0.0, 3.0, 6.0])
            StructuralColumn(id: '$x:$y', center: Offset(x, y)),
      ],
      slabs: [
        StructuralSlab(id: 's', polygon: rect(0, 0, 4, 6), thickness: .25),
      ],
    );
    final topology = SlabSupportTopology.analyze(floor, 1);
    expect(topology.fields, hasLength(2));
    expect(topology.fields.every((f) => !f.requiresReview), isTrue);
    expect(
      topology.fields.map((f) => [f.lxM, f.lyM]..sort()),
      everyElement([3.0, 4.0]),
    );
    expect(topology.unresolvedAreaM2, closeTo(0, 1e-8));
    final opened = floor.copyWith(
      slabs: [
        floor.slabs.single.copyWith(openings: [rect(1, 1, 1, 1)]),
      ],
    );
    final cut = SlabSupportTopology.analyze(opened, 1);
    expect(cut.unresolvedAreaM2, greaterThan(0));
    final empty = SlabSupportTopology.analyze(floor.copyWith(columns: []), 1);
    expect(empty.fields, isEmpty);
    expect(empty.unresolvedAreaM2, 24);
  });

  test('unconnected plates cannot borrow an opening support', () {
    final floor = StoreyLevel(
      id: 'f',
      name: 'f',
      columns: const [StructuralColumn(id: 'c', center: Offset(5.3, 2))],
      slabs: [
        StructuralSlab(
          id: 'left',
          polygon: rect(0, 0, 5, 4),
          openings: [rect(3.5, 1.5, .5, 1)],
        ),
        StructuralSlab(id: 'right', polygon: rect(5.1, 0, 3, 4)),
      ],
    );
    final result = SupportLayoutEvaluator.evaluate(
      StructuralProject(storeys: [floor]),
      floor,
      1,
    );
    expect(result.openings.every((p) => p.distanceM.isInfinite), isTrue);
  });

  test('a dead-end support line cannot erase a closed plate field', () {
    final pts = rect(0, 0, 4, 4);
    final floor = StoreyLevel(
      id: 'f',
      name: 'f',
      slabs: [StructuralSlab(id: 's', polygon: pts)],
      columns: [
        for (var i = 0; i < pts.length; i++)
          StructuralColumn(id: 'c$i', center: pts[i]),
      ],
      shearWalls: const [
        StructuralShearWall(id: 'spur', start: Offset(0, 0), end: Offset(1, 1)),
      ],
    );
    final intervals = [
      for (var i = 0; i < 4; i++)
        SupportSpanCheck(
          segment: (pts[i], pts[(i + 1) % 4]),
          spanM: 4,
          thicknessM: .2,
          allowableSpanM: 3.74,
        ),
    ];
    final graph = SlabSupportTopology.analyze(floor, 1, intervals: intervals);
    expect(graph.fields, hasLength(1));
    expect(graph.unresolvedAreaM2, closeTo(0, 1e-8));
  });

  test('losing a known boundary root cannot buy a better layout score', () {
    final floor = StoreyLevel(
      id: 'f',
      name: 'f',
      slabs: [
        StructuralSlab(id: 's', polygon: rect(0, 0, 4, 4), thickness: .5),
      ],
      columns: const [StructuralColumn(id: 'c', center: Offset(2, 2))],
      shearWalls: const [
        StructuralShearWall(id: 'root', start: Offset(0, 2), end: Offset(4, 2)),
      ],
    );
    final project = StructuralProject(storeys: [floor]);
    final known = SupportLayoutEvaluator.evaluate(project, floor, 1);
    final lost = SupportLayoutEvaluator.evaluate(
      project,
      floor.copyWith(shearWalls: []),
      1,
    );
    expect(known.boundaries.where((b) => b.hasSupportLine), isNotEmpty);
    expect(lost.unavailableChecks, greaterThan(known.unavailableChecks));
    expect(lost.compareTo(known), greaterThan(0));
    // A close column is still not evidence of a continuous support line.
    expect(
      const BoundarySupportCheck(Offset.zero, .1, false, .5).requiresReview,
      isTrue,
    );
  });

  test(
    'joint search preserves fixed supports and improves its common score',
    () {
      final (base, runs) = f.fixture();
      const fixed = StructuralColumn(
        id: 'manual',
        name: 'Keep',
        center: Offset(18, 14),
        width: .25,
        height: .5,
      );
      final floor = base.activeStorey.copyWith(columns: [fixed]);
      final project = base.copyWith(storeys: [floor]);
      final result = InitialSchemeGenerator.generate(
        project: project,
        wallPairs: runs,
        scale: 1,
      );
      expect(
        result.assessment!.compareTo(result.initialAssessment!),
        lessThanOrEqualTo(0),
      );
      expect(result.searchedLayouts, 3);
      expect(result.optimizationEvaluations, lessThanOrEqualTo(64));
      expect(result.optimizationOperations['move-wall'], greaterThan(0));
      expect(result.optimizationOperations['paired-walls'], greaterThan(0));
      expect(result.apply(floor).columns.first, same(fixed));
      final manual = SupportLayoutEvaluator.evaluate(
        project,
        result.apply(floor).copyWith(gridAxes: project.effectiveGridAxes),
        1,
      );
      expect(
        manual.structuralPenalty,
        closeTo(result.assessment!.structuralPenalty, 1e-8),
      );
      expect(
        manual.balancePenalty,
        closeTo(result.assessment!.balancePenalty, 1e-8),
      );
    },
  );

  test('local search can prune a redundant automatic support', () {
    final floor = StoreyLevel(
      id: 'f',
      name: 'f',
      slabs: [
        StructuralSlab(id: 's', polygon: rect(0, 0, 4, 1), thickness: .5),
      ],
    );
    final seed = floor.copyWith(
      columns: [
        for (final x in [0.5, 2.0, 3.5])
          StructuralColumn(
            id: 'auto$x',
            center: Offset(x, .5),
            width: .8,
            height: .8,
            generatedBy: 'initial-scheme-v1',
          ),
      ],
    );
    final project = StructuralProject(storeys: [floor]);
    final result = SupportLayoutOptimizer.optimize(
      project: project,
      fixedFloor: floor,
      seeds: [seed],
      wallPairs: [],
      domain: WallPlacementDomain.build([], [], 1),
      scale: 1,
      minSpacingM: 2,
      maxWallLengthM: 2.5,
      maxEvaluations: 30,
      pairedWalls: false,
    );
    expect(result.floor.columns.length, lessThan(seed.columns.length));
    expect(
      result.assessment.compareTo(
        SupportLayoutEvaluator.evaluate(project, seed, 1),
      ),
      lessThan(0),
    );
  });

  test('placement stage limits are separate and explicitly identified', () {
    final (project, runs) = f.fixture();
    final result = InitialSchemeGenerator.generate(
      project: project,
      wallPairs: runs,
      scale: 1,
      options: const InitialSchemeOptions(
        placementAttemptsPerStage: 1,
        optimizeLayout: false,
      ),
    );
    expect(result.limited, isTrue);
    expect(result.limitReasons.any((s) => s.startsWith('placement:')), isTrue);
    expect(result.attemptsByStage.values, everyElement(lessThanOrEqualTo(1)));
    expect(
      result.attemptsByStage.keys,
      containsAll(['core', 'walls', 'columns']),
    );
    final axesOnly = InitialSchemeGenerator.generate(
      project: project,
      wallPairs: [],
      scale: 1,
      options: const InitialSchemeOptions(optimizeLayout: false),
    );
    expect(axesOnly.rejectionReasons['no-wall'], greaterThan(0));
  });

  test('upper floors retain inherited supports without local optimization', () {
    final (base, runs) = f.fixture();
    final generated = InitialSchemeGenerator.generate(
      project: base,
      wallPairs: runs,
      scale: 1,
    );
    final lower = generated.apply(base.activeStorey);
    final upper = base.activeStorey.copyWith(id: 'upper', elevation: 3);
    final result = InitialSchemeGenerator.generate(
      project: base.copyWith(storeys: [lower, upper], activeStoreyIndex: 1),
      wallPairs: runs,
      scale: 1,
    );
    expect(result.continuationSource, isNotNull);
    expect(result.optimizationEvaluations, 0);
    for (final c in result.columns) {
      expect(
        lower.columns.any((old) => (old.center - c.center).distance < 1e-8),
        isTrue,
      );
    }
  });
  test('nearby centres do not hide a partly unsupported upper section', () {
    final lower = StoreyLevel(
      id: 'lower',
      name: 'lower',
      columns: const [StructuralColumn(id: 'lower-c', center: Offset(2, 2))],
      slabs: [StructuralSlab(id: 's', polygon: rect(0, 0, 4, 4))],
    );
    const upperColumn = StructuralColumn(id: 'upper-c', center: Offset(2.2, 2));
    final check = ColumnVerticalContinuity.evaluate(upperColumn, lower, 1);
    expect(check.isContinuous, isFalse);
    expect(check.coverage, lessThan(.5));
    final upper = lower.copyWith(
      id: 'upper',
      elevation: 3,
      columns: [upperColumn],
    );
    final assessment = SupportLayoutEvaluator.evaluate(
      StructuralProject(storeys: [lower, upper]),
      upper,
      1,
    );
    expect(assessment.continuityIssues, 1);
    expect(
      ColumnVerticalContinuity.evaluate(
        upperColumn.copyWith(center: const Offset(2, 2)),
        lower,
        1,
      ).isContinuous,
      isTrue,
    );
  });
  test('unavailable input never receives a finite successful field check', () {
    final floor = StoreyLevel(
      id: 'f',
      name: 'f',
      slabs: [StructuralSlab(id: 's', polygon: rect(0, 0, 4, 4))],
    );
    final assessment = SupportLayoutEvaluator.evaluate(
      StructuralProject(storeys: [floor]),
      floor,
      0,
    );
    expect(assessment.unavailableChecks, greaterThan(0));
    expect(assessment.topology.invalidGeometry, isTrue);
  });
}
