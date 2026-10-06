import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_contact_geometry.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

List<Offset> box(double x, double y, double w, double h) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x + w, y + h),
  Offset(x, y + h),
];
StructuralSlab slab(List<Offset> ring, {List<List<Offset>> holes = const []}) =>
    StructuralSlab(id: 's', polygon: ring, openings: holes);

void main() {
  test(
    'nearby and touching columns do not acquire a false slab connection',
    () {
      final slabs = [slab(box(0, 0, 10, 10))];
      for (final x in [-.21, -.2]) {
        final col = StructuralColumn(
          id: 'c',
          center: Offset(x, 5),
          width: .4,
          height: .4,
        );
        expect(
          SeismicAnalysisCalculator.isColumnConnectedToSlab(col, slabs, 1),
          isFalse,
        );
      }
      const partial = StructuralColumn(
        id: 'c',
        center: Offset(-.19, 5),
        width: .4,
        height: .4,
      );
      expect(
        SlabContactGeometry.columnContact(partial, slabs, 1)!.areaM2,
        closeTo(.004, 1e-12),
      );
    },
  );

  test('column inside an opening remains disconnected near its edge', () {
    final slabs = [
      slab(box(0, 0, 10, 10), holes: [box(2, 2, 4, 4)]),
    ];
    const col = StructuralColumn(
      id: 'c',
      center: Offset(2.21, 3),
      width: .4,
      height: .4,
    );
    expect(
      SeismicAnalysisCalculator.isColumnConnectedToSlab(col, slabs, 1),
      isFalse,
    );
  });

  test(
    'crossing footprints connect even when none of their corners overlap',
    () {
      final m = SlabContactGeometry.measure(box(-2, -.2, 4, .4), [
        slab(box(-.1, -2, .2, 4)),
      ], 1)!;
      expect(m.areaM2, closeTo(.08, 1e-12));
      expect(m.projectedLengthM, closeTo(.2, 1e-12));
      expect(m.centroidCad.distance, lessThan(1e-12));
    },
  );

  test('slab union and overlapping openings count each area only once', () {
    final m = SlabContactGeometry.measure(box(0, 0, 4, 4), [
      slab(box(0, 0, 3, 4), holes: [box(1, 1, 1, 2), box(1, 2, 1, 1)]),
      slab(box(2, 0, 2, 4)),
    ], 1)!;
    expect(m.areaM2, closeTo(14, 1e-12));
    expect(m.centroidCad.dx, closeTo(29 / 14, 1e-12));
    expect(m.centroidCad.dy, closeTo(2, 1e-12));
  });

  test(
    'concave footprint, rotation, units and large translations preserve contact',
    () {
      final ring = [
        const Offset(0, 0),
        const Offset(2, 0),
        const Offset(2, 1),
        const Offset(1, 1),
        const Offset(1, 2),
        const Offset(0, 2),
      ];
      final outer = box(-1, -1, 4, 4);
      for (final scale in [1.0, 1000.0]) {
        Offset transform(Offset p) =>
            const Offset(1e7, -2e7) +
            Offset(
                  p.dx * math.cos(.7) - p.dy * math.sin(.7),
                  p.dx * math.sin(.7) + p.dy * math.cos(.7),
                ) *
                scale;
        final m = SlabContactGeometry.measure(
          ring.map(transform).toList(),
          [slab(outer.map(transform).toList())],
          scale,
          direction: Offset(math.cos(.7), math.sin(.7)),
        )!;
        expect(m.areaM2, closeTo(3, 1e-7));
        expect(m.projectedLengthM, closeTo(2, 1e-7));
        expect(
          (m.centroidCad - transform(const Offset(5 / 6, 5 / 6))).distance /
              scale,
          lessThan(1e-7),
        );
      }
    },
  );

  test('narrow wall contact missed by discrete samples is measured', () {
    const wall = StructuralShearWall(
      id: 'w',
      start: Offset(0, 0),
      end: Offset(10, 0),
      thickness: .2,
    );
    final c = SeismicAnalysisCalculator.getWallDiaphragmConnection(wall, [
      slab(box(.21, -1, .03, 2)),
    ], 1);
    expect(c.isConnected, isTrue);
    expect(c.connectedFraction, closeTo(.003, 1e-12));
    expect(c.effectiveLengthM, 10);
    expect(c.requiresReview, isTrue);
  });

  test(
    'wall uses actual reference face and flip rather than its input axis',
    () {
      const wall = StructuralShearWall(
        id: 'w',
        start: Offset(0, 0),
        end: Offset(4, 0),
        thickness: .2,
        referenceLine: ShearWallReferenceLine.leftFace,
      );
      // CAD wall normal for an eastward segment points toward negative Y.
      final slabs = [slab(box(-1, -2.05, 6, 2))];
      final contact = SeismicAnalysisCalculator.getWallDiaphragmConnection(
        wall,
        slabs,
        1,
      );
      expect(contact.isConnected, isTrue);
      expect(contact.connectedFraction, closeTo(1, 1e-12));
      expect(contact.requiresReview, isFalse);
      expect(
        SeismicAnalysisCalculator.getWallDiaphragmConnection(
          wall.copyWith(isFlipped: true),
          slabs,
          1,
        ).isConnected,
        isFalse,
      );
    },
  );

  test('wall spanning opening withholds stiffness and eccentricity', () async {
    const wall = StructuralShearWall(
      id: 'w',
      start: Offset(1, 5),
      end: Offset(9, 5),
      thickness: .2,
    );
    final slabs = [
      slab(box(0, 0, 10, 10), holes: [box(4, 4, 2, 2)]),
    ];
    final c = SeismicAnalysisCalculator.getWallDiaphragmConnection(
      wall,
      slabs,
      1,
    );
    expect(c.connectedFraction, closeTo(.75, 1e-12));
    expect(c.effectiveLengthM, 8);
    final report = SeismicAnalysisCalculator.analyzeProject(
      StructuralProject(
        storeys: [
          StoreyLevel(id: 'f', name: 'f', slabs: slabs, shearWalls: [wall]),
        ],
      ),
    );
    final check = report.storeyChecks.single;
    expect(check.hasLateralStiffness, isFalse);
    expect(check.centerOfRigidityCad, isNull);
    expect(check.eccentricityM, isNull);
    expect(check.connectionReviewNames, [wall.displayName]);
    for (final locale in ['bg', 'en']) {
      final strings = await AppLocalizations.delegate.load(Locale(locale));
      expect(
        check.localizedRecommendation(strings),
        strings.seismicConnectionReview(wall.displayName),
      );
    }
  });

  test('self-crossing, degenerate and excessive contours are unevaluated', () {
    final floor = [slab(box(-10, -10, 20, 20))];
    expect(
      SlabContactGeometry.measure(
        [
          const Offset(0, 0),
          const Offset(3, 2),
          const Offset(0, 2),
          const Offset(2, 0),
        ],
        floor,
        1,
      ),
      isNull,
    );
    expect(SlabContactGeometry.measure(box(0, 0, 0, 2), floor, 1), isNull);
    expect(SlabContactGeometry.measure(box(0, 0, 2, 2), floor, 0), isNull);
    final ring = [
      for (var i = 0; i < 2500; i++)
        Offset(
          math.cos(i * 2 * math.pi / 2500),
          math.sin(i * 2 * math.pi / 2500),
        ),
    ];
    expect(SlabContactGeometry.measure(ring, floor, 1), isNull);
  });

  test('circular contact is bracketed at ambiguous boundaries', () {
    const col = StructuralColumn(
      id: 'c',
      center: Offset.zero,
      width: 2,
      height: 2,
      shape: ColumnShape.circular,
    );
    expect(
      SlabContactGeometry.columnContact(col, [
        slab(box(-2, -2, 4, 4)),
      ], 1)!.areaM2,
      closeTo(math.pi, .0004),
    );
    expect(
      SlabContactGeometry.columnContact(col, [
        slab(box(1.01, -2, 2, 4)),
      ], 1)!.areaM2,
      0,
    );
    expect(
      SlabContactGeometry.columnContact(col, [slab(box(1.00001, -2, 2, 4))], 1),
      isNull,
    );
  });
}
