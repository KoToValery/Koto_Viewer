
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/diaphragm_storey_links.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

StructuralSlab slab(
  double x,
  double w, {
  List<List<Offset>> holes = const [],
}) => StructuralSlab(
  id: 's$x',
  polygon: [Offset(x, 0), Offset(x + w, 0), Offset(x + w, 10), Offset(x, 10)],
  openings: holes,
);
StoreyLevel floor(String id, double z, {bool rotate = false}) => StoreyLevel(
  id: id,
  name: id,
  elevation: z,
  height: 3,
  slabs: [slab(0, 10)],
  columns: [
    for (final x in [2.0, 8.0])
      for (final y in [2.0, 8.0])
        StructuralColumn(
          id: '$id$x$y',
          center: Offset(x, y),
          width: rotate ? .8 : .2,
          height: rotate ? .2 : .8,
        ),
  ],
);
void main() {
  test(
    'sort by elevation on a copy; floating check uses actual lower level',
    () {
      final lower = floor('lower', 0), upper = floor('upper', 3);
      final input = StructuralProject(storeys: [upper, lower]);
      final report = SeismicAnalysisCalculator.analyzeProject(input);
      expect(input.storeys.first.id, 'upper');
      expect(report.storeyChecks.map((s) => s.storeyId), ['lower', 'upper']);
      expect(report.totalFloatingColumnsCount, 0);
      expect(
        report.storeyChecks.last.regionLinksBelow.single.lowerStoreyName,
        'lower',
      );
      expect(
        report.storeyChecks.first.stiffnessRatioXToAbove,
        closeTo(1, 1e-10),
      );
    },
  );
  test('directional weakening cannot hide behind unchanged stiffness sum', () {
    final report = SeismicAnalysisCalculator.analyzeProject(
      StructuralProject(
        storeys: [floor('lower', 0), floor('upper', 3, rotate: true)],
      ),
    );
    final lower = report.storeyChecks.first;
    expect(lower.stiffnessRatioToAbove, closeTo(1, 1e-10));
    expect(lower.stiffnessRatioXToAbove, closeTo(1 / 16, 1e-10));
    expect(lower.stiffnessRatioYToAbove, closeTo(16, 1e-10));
    expect(lower.isSoftStorey, isTrue);
  });
  test('duplicate and nonfinite elevations withhold vertical comparisons', () {
    for (final elevation in [0.0, double.nan, double.infinity]) {
      final report = SeismicAnalysisCalculator.analyzeProject(
        StructuralProject(storeys: [floor('a', 0), floor('b', elevation)]),
      );
      expect(report.storeyChecks.every((s) => !s.verticalOrderValid), isTrue);
      expect(
        report.storeyChecks.every(
          (s) => s.stiffnessRatioXToAbove == null && s.regionLinksBelow.isEmpty,
        ),
        isTrue,
      );
      expect(report.totalFloatingColumnsCount, 0);
    }
  });
  test(
    'region matcher detects splits and merges rather than nearest-centre pairs',
    () {
      final full = StoreyLevel(id: 'full', name: 'full', slabs: [slab(0, 10)]);
      final split = StoreyLevel(
        id: 'split',
        name: 'split',
        slabs: [slab(0, 4), slab(6, 4)],
      );
      final splitLinks = DiaphragmStoreyLink.between(split, full, 1);
      expect(splitLinks.length, 2);
      expect(
        splitLinks.every(
          (l) => l.kind == RegionLinkKind.branching && l.coverage == 1,
        ),
        isTrue,
      );
      final merge = DiaphragmStoreyLink.between(full, split, 1).single;
      expect(merge.lowerRegions, [0, 1]);
      expect(merge.kind, RegionLinkKind.branching);
      expect(merge.coverage, closeTo(.8, 1e-10));
    },
  );
  test(
    'region matcher excludes openings and does not bridge a horizontal gap',
    () {
      final lower = StoreyLevel(
        id: 'lower',
        name: 'lower',
        slabs: [
          slab(
            0,
            10,
            holes: [
              [
                const Offset(2, 2),
                const Offset(8, 2),
                const Offset(8, 8),
                const Offset(2, 8),
              ],
            ],
          ),
        ],
      );
      final upper = StoreyLevel(
        id: 'upper',
        name: 'upper',
        slabs: [
          StructuralSlab(
            id: 'island',
            polygon: [
              const Offset(3, 3),
              const Offset(7, 3),
              const Offset(7, 7),
              const Offset(3, 7),
            ],
          ),
        ],
      );
      expect(
        DiaphragmStoreyLink.between(upper, lower, 1).single.kind,
        RegionLinkKind.unmatched,
      );
      final remote = StoreyLevel(id: 'r', name: 'r', slabs: [slab(20, 10)]);
      expect(DiaphragmStoreyLink.between(remote, lower, 1).single.coverage, 0);
    },
  );
  test('unmatched regions do not receive stiffness ratios', () {
    final upper = floor('upper', 3).copyWith(
      slabs: [slab(20, 10)],
      columns: const [
        StructuralColumn(id: 'c', center: Offset(25, 5), width: .4, height: .4),
      ],
    );
    final report = SeismicAnalysisCalculator.analyzeProject(
      StructuralProject(storeys: [floor('lower', 0), upper]),
    );
    expect(report.storeyChecks.first.stiffnessRatioXToAbove, isNull);
  });
}
