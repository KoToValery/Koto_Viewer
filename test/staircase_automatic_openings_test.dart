import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_automatic_openings.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_inventory.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_placement_rules.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'staircase_opening_contours_test.dart' as contours;
import 'staircase_geometry_detector_test.dart' as geometry;

const plate = [Offset(-2, -2), Offset(8, -2), Offset(8, 8), Offset(-2, 8)];
StructuralProject building({bool manual = false}) => StructuralProject(
  storeys: [
    const StoreyLevel(
      id: 'g',
      name: 'Ground',
      slabs: [StructuralSlab(id: 'sg', polygon: plate, isFloorSlab: true)],
    ),
    StoreyLevel(
      id: 'f',
      name: 'First',
      elevation: 2.8,
      slabs: [
        StructuralSlab(
          id: 'sf',
          polygon: plate,
          isFloorSlab: true,
          openings: manual ? [contours.outline] : [],
          openingTypes: manual ? [SlabOpeningType.staircase] : [],
        ),
      ],
    ),
    const StoreyLevel(
      id: 'r',
      name: 'Roof',
      elevation: 5.6,
      slabs: [StructuralSlab(id: 'sr', polygon: plate, isFloorSlab: true)],
    ),
  ],
);
Map<String, DxfDocument> drawings() => {
  'g': geometry.doc(geometry.run()),
  'f': geometry.doc([
    for (var i = 0; i < contours.outline.length; i++)
      DxfLine(
        p1: contours.outline[i],
        p2: contours.outline[(i + 1) % contours.outline.length],
      ),
  ]),
  'r': geometry.doc([]),
};
void main() {
  test(
    'one operation cuts an observed arrival polygon, leaves the first floor and roof solid',
    () {
      final p = building();
      final targets = StaircaseAutomaticOpenings.detect(p, drawings(), 1);
      expect(targets, hasLength(1));
      expect(targets.single.storeyId, 'f');
      expect(StaircaseAutomaticOpenings.missing(p, targets, 1), {'f'});
      final result = StaircaseAutomaticOpenings.apply(p, targets, 1);
      expect(result.added, 1);
      expect(
        result.project.storeys[1].slabs.single.openings.single.toSet(),
        contours.outline.toSet(),
      );
      expect(
        result.project.storeys[1].slabs.single.getOpeningType(0),
        SlabOpeningType.staircase,
      );
      expect(result.project.storeys.first.slabs.single.openings, isEmpty);
      expect(result.project.storeys.last.slabs.single.openings, isEmpty);
      expect(result.project.staircases, isEmpty);
      expect(
        result.project.storeys.every((s) => s.staircaseZones.isEmpty),
        isTrue,
      );
      expect(
        StaircaseAutomaticOpenings.missing(result.project, targets, 1),
        isEmpty,
      );
      expect(
        StaircaseAutomaticOpenings.apply(result.project, targets, 1).added,
        0,
      );
      final arrival = result.project.supportedStoreyFor(
        result.project.storeys[1],
      );
      expect(
        SupportPlacementRules.circulationFits(
          [
            const Offset(.4, .4),
            const Offset(.6, .4),
            const Offset(.6, .6),
            const Offset(.4, .6),
          ],
          arrival,
          1,
        ),
        isFalse,
      );
    },
  );
  test(
    'manual typed cuts satisfy column checks without scope, review or circulation drawing',
    () {
      final p = building(manual: true);
      final targets = StaircaseAutomaticOpenings.detect(p, drawings(), 1);
      expect(StaircaseAutomaticOpenings.missing(p, targets, 1), isEmpty);
      expect(StaircaseInventory.evaluateOpenings(p, 1).ready, isTrue);
      final result = StaircaseAutomaticOpenings.apply(p, targets, 1);
      expect(result.added, 0);
      expect(identical(result.project, p), isTrue);
    },
  );
  test(
    'first floor is exempt even when supplied an explicit cut candidate',
    () {
      final p = building();
      final result = StaircaseAutomaticOpenings.apply(p, [
        DetectedStairOpening('g', contours.outline, [contours.outline]),
      ], 1);
      expect(result.added, 0);
      expect(p.storeys.first.slabs.single.openings, isEmpty);
    },
  );
  test('straight treads alone cannot be turned into a rectangular cut', () {
    final p = building();
    final docs = {
      'g': geometry.doc(geometry.run()),
      'f': geometry.doc(geometry.run()),
    };
    final targets = StaircaseAutomaticOpenings.detect(p, docs, 1);
    expect(targets.single.contours, isEmpty);
    expect(StaircaseAutomaticOpenings.apply(p, targets, 1).added, 0);
    expect(StaircaseAutomaticOpenings.missing(p, targets, 1), {'f'});
  });
  test(
    'a contour on the wrong level and an out-of-plate contour are not applied',
    () {
      final p = building();
      final wrong = p.copyWith(
        storeys: [
          p.storeys.first,
          p.storeys[1].copyWith(
            slabs: [p.storeys[1].slabs.single.copyWith(topElevation: 8)],
          ),
          p.storeys.last,
        ],
      );
      final targets = StaircaseAutomaticOpenings.detect(p, drawings(), 1);
      expect(StaircaseAutomaticOpenings.apply(wrong, targets, 1).added, 0);
      expect(
        StaircaseAutomaticOpenings.apply(p, [
          DetectedStairOpening('f', contours.outline, [
            contours.outline.map((v) => v + const Offset(20, 0)).toList(),
          ]),
        ], 1).added,
        0,
      );
    },
  );
  test(
    'two independent staircases cut two holes with no duplicate on a repeat',
    () {
      final p = building();
      final docs = drawings();
      docs['g'] = geometry.doc([
        ...geometry.run(),
        for (final entity in geometry.run().cast<DxfLine>())
          DxfLine(
            p1: entity.p1 + const Offset(4, 0),
            p2: entity.p2 + const Offset(4, 0),
          ),
      ]);
      docs['f'] = geometry.doc([
        for (final shift in [Offset.zero, const Offset(4, 0)])
          for (var i = 0; i < contours.outline.length; i++)
            DxfLine(
              p1: contours.outline[i] + shift,
              p2: contours.outline[(i + 1) % contours.outline.length] + shift,
            ),
      ]);
      final targets = StaircaseAutomaticOpenings.detect(p, docs, 1);
      expect(targets, hasLength(2));
      final cut = StaircaseAutomaticOpenings.apply(p, targets, 1);
      expect(cut.added, 2);
      expect(cut.project.storeys[1].slabs.single.openings, hasLength(2));
      expect(
        StaircaseAutomaticOpenings.missing(cut.project, targets, 1),
        isEmpty,
      );
      expect(
        StaircaseAutomaticOpenings.apply(cut.project, targets, 1).added,
        0,
      );
    },
  );
  test(
    'existing scopes need only arrival cuts; neither ground nor review flags block columns',
    () {
      final p = building(manual: true).copyWith(
        staircases: [
          const StaircaseCore(
            id: 'old',
            name: 'old',
            startStoreyId: 'g',
            endStoreyId: 'f',
          ),
        ],
      );
      expect(StaircaseInventory.evaluateOpenings(p, 1).ready, isTrue);
      expect(
        StaircaseInventory.evaluateOpenings(
          building().copyWith(staircases: p.staircases),
          1,
        ).gaps.single.storeyId,
        'f',
      );
    },
  );
  test(
    'real BIM stair lines cut the upper physical owner using lower flight evidence',
    () {
      final raw =
          jsonDecode(
                File(
                  'test/fixtures/bim_staircase_local_strokes.json',
                ).readAsStringSync(),
              )
              as Map;
      DxfDocument source(String key) => geometry.doc([
        for (final row in raw[key] as List)
          DxfLine(
            p1: Offset((row[0] as num).toDouble(), (row[1] as num).toDouble()),
            p2: Offset((row[2] as num).toDouble(), (row[3] as num).toDouble()),
            lineType: row[4] as String,
          ),
      ]);
      final big = [
        const Offset(-1200, -500),
        const Offset(0, -500),
        const Offset(0, 700),
        const Offset(-1200, 700),
      ];
      final p = building().copyWith(
        storeys: [
          for (final s in building().storeys)
            s.copyWith(slabs: [s.slabs.single.copyWith(polygon: big)]),
        ],
      );
      final targets = StaircaseAutomaticOpenings.detect(p, {
        'g': source('revision_VNIEJI'),
        'f': source('revision_ZTRFQO'),
        'r': geometry.doc([]),
      }, 100);
      expect(targets, hasLength(1));
      final result = StaircaseAutomaticOpenings.apply(p, targets, 100);
      expect(result.added, 1);
      expect(
        result.project.storeys[1].slabs.single.openings.single.length,
        greaterThan(4),
      );
      expect(result.project.storeys.first.slabs.single.openings, isEmpty);
      expect(result.project.storeys.last.slabs.single.openings, isEmpty);
    },
  );
}
