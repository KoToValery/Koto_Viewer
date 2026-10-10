import 'dart:convert';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_structural_seed_sync.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

List<Offset> ring(double size) => [
  Offset.zero,
  Offset(size, 0),
  Offset(size, size),
  Offset(0, size),
];
DxfDocument drawing({double size = 10, double axisY = 0, bool empty = false}) =>
    DxfDocument(
      bounds: Rect.fromLTWH(0, 0, size, size),
      layers: {},
      blocks: {},
      entities: [],
      entityStats: {},
      headerVars: {
        BimUnderlayMetadata.key: jsonEncode({
          'version': BimUnderlayMetadata.version,
          'complete': true,
          'hasResults': !empty,
          'axes': empty
              ? []
              : [
                  StructuralGridAxis(
                    id: 'a',
                    name: 'A',
                    start: Offset(0, axisY),
                    end: Offset(size, axisY),
                  ).toJson(),
                ],
          'slabEnvelope': {
            'contours': empty
                ? []
                : [
                    ring(size).map((p) => [p.dx, p.dy]).toList(),
                  ],
          },
          'slabProjections': [],
        }),
      },
    );
BimWorkProject project(List<double> levels) => BimWorkProject(
  id: 'p',
  name: 'P',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  structuralUnitsPerMeter: 1,
  storeys: [
    for (var i = 0; i < levels.length; i++)
      BimStoreyUnderlay(
        storeyId: 's$i',
        name: 'S$i',
        elevation: levels[i],
        underlayFileName: 's$i.kcad',
      ),
  ],
);
StructuralProject model(BimWorkProject p) => StructuralProject(
  title: 'P',
  storeys: [
    for (final s in p.storeys)
      StoreyLevel(id: s.storeyId, name: s.name, elevation: s.elevation),
  ],
);
Map<String, DxfDocument> docs(BimWorkProject p) => {
  for (final s in p.storeys) s.storeyId: drawing(),
};
void main() {
  test('Automatic slabs belong to every loaded creation floor', () {
    final p = project([0, 2.85, 5.6]);
    final (_, s) = BimStructuralSeedSync.refresh(p, model(p), docs(p));
    expect(s.storeys.map((s) => s.slabs.length), [1, 1, 1]);
    for (final floor in s.storeys) {
      expect(floor.slabs.single.isFloorSlab, true);
      expect(
        floor.structuralElevationFor(floor.slabs.single),
        floor.elevation - .05,
      );
    }
    expect(s.ceilingSlabStoreyFor(s.storeys.first)!.id, 's1');
    final single = project([0]);
    expect(
      BimStructuralSeedSync.refresh(
        single,
        model(single),
        docs(single),
      ).$2.activeStorey.slabs,
      hasLength(1),
    );
    expect(
      BimStructuralSeedSync.refresh(p, model(p), {
        's0': drawing(),
      }).$2.storeys.map((s) => s.slabs.length),
      [1, 0, 0],
    );
  });
  test(
    'An unloaded intermediate floor does not own or borrow another slab',
    () {
      final p = project([0, 2.8, 5.6]);
      final (_, s) = BimStructuralSeedSync.refresh(p, model(p), {
        's0': drawing(),
        's2': drawing(),
      });
      expect(s.storeys.map((s) => s.slabs.length), [1, 0, 1]);
      expect(s.ceilingSlabStoreyFor(s.storeys.first), isNull);
    },
  );
  test('Adding or removing another floor does not move floor-owned slabs', () {
    var p = project([0]);
    var (updated, s) = BimStructuralSeedSync.refresh(p, model(p), docs(p));
    final original = s.storeys.first.slabs.single;
    p = updated.copyWith(
      storeys: [
        ...updated.storeys,
        const BimStoreyUnderlay(
          storeyId: 's1',
          name: 'S1',
          elevation: 3.2,
          underlayFileName: 's1.kcad',
        ),
      ],
    );
    (updated, s) = BimStructuralSeedSync.refresh(p, s, docs(p));
    expect(s.storeys.map((s) => s.slabs.length), [1, 1]);
    p = updated.copyWith(storeys: [updated.storeys.first]);
    (updated, s) = BimStructuralSeedSync.refresh(p, s, docs(p));
    expect(s.storeys.length, 1);
    expect(s.activeStorey.slabs.single.toJson(), original.toJson());
  });
  test(
    'Underlay revision updates outline and keeps thickness, stairs and supports',
    () {
      final p = project([0, 2.8]);
      var (updated, s) = BimStructuralSeedSync.refresh(p, model(p), docs(p));
      final floor = s.storeys.first;
      final slab = floor.slabs.single.copyWith(
        thickness: .26,
        openings: [ring(1).map((v) => v + const Offset(2, 2)).toList()],
        openingTypes: [SlabOpeningType.staircase],
      );
      s = s.copyWith(
        storeys: [
          floor.copyWith(
            slabs: [slab],
            columns: [const StructuralColumn(id: 'c', center: Offset(3, 3))],
            shearWalls: [
              const StructuralShearWall(
                id: 'w',
                start: Offset(0, 0),
                end: Offset(0, 3),
              ),
            ],
          ),
          s.storeys.last,
        ],
      );
      (updated, s) = BimStructuralSeedSync.refresh(updated, s, {
        's0': drawing(size: 12, axisY: 2),
        's1': drawing(),
      });
      final changed = s.storeys.first;
      expect(changed.slabs.single.polygon, ring(12));
      expect(changed.slabs.single.thickness, .26);
      expect(changed.slabs.single.openings, slab.openings);
      expect(changed.slabs.single.getOpeningType(0), SlabOpeningType.staircase);
      expect(changed.columns.single.id, 'c');
      expect(changed.shearWalls.single.id, 'w');
      expect(
        updated.storeys.first.processing['structuralReviewRequired'],
        true,
      );
      expect(s.effectiveGridAxes.any((a) => a.start.dy == 2), true);
      // A smaller outline cannot silently erase an opening outside the new contour.
      (_, s) = BimStructuralSeedSync.refresh(updated, s, {
        's0': drawing(size: 2),
        's1': drawing(),
      });
      expect(s.storeys.first.slabs.single.polygon, ring(12));
      expect(s.storeys.first.slabs.single.openings, slab.openings);
    },
  );
  test(
    'Deleted automatic slabs and axes stay deleted across multiple revisions',
    () {
      final p = project([0, 2.8]);
      var (updated, s) = BimStructuralSeedSync.refresh(p, model(p), docs(p));
      s = s
          .copyWith(
            storeys: [
              s.storeys.first.copyWith(slabs: []),
              s.storeys.last,
            ],
          )
          .copyWithGridAxes([]);
      for (final size in [11.0, 12.0, 13.0]) {
        (updated, s) = BimStructuralSeedSync.refresh(updated, s, {
          's0': drawing(size: size),
          's1': drawing(size: size),
        });
        expect(s.storeys.first.slabs, isEmpty);
        expect(s.effectiveGridAxes, isEmpty);
      }
    },
  );
  test('Manual outline and roof slab survive removal and source revision', () {
    final p = project([0, 2.8]);
    var (updated, s) = BimStructuralSeedSync.refresh(p, model(p), docs(p));
    final manual = s.storeys.first.slabs.single.copyWith(polygon: ring(9));
    s = s.copyWith(
      storeys: [
        s.storeys.first.copyWith(slabs: [manual]),
        s.storeys.last,
      ],
    );
    updated = updated.copyWith(storeys: [updated.storeys.first]);
    (updated, s) = BimStructuralSeedSync.refresh(updated, s, {
      's0': drawing(size: 12),
    });
    expect(s.activeStorey.slabs.single.toJson(), manual.toJson());
    expect(updated.storeys.first.processing['structuralReviewRequired'], true);
  });
  test(
    'Removed floor axes can be replaced by coincident axes of remaining floor',
    () {
      final p = project([0, 2.8]);
      var (updated, s) = BimStructuralSeedSync.refresh(p, model(p), docs(p));
      expect(s.effectiveGridAxes.single.id, startsWith('bim_axis_s0_'));
      updated = updated.copyWith(storeys: [updated.storeys.last]);
      (_, s) = BimStructuralSeedSync.refresh(updated, s, {'s1': drawing()});
      expect(s.effectiveGridAxes.single.id, startsWith('bim_axis_s1_'));
    },
  );
  test('Empty new analysis removes obsolete automatic geometry', () {
    final p = project([0, 2.8]);
    final (updated, s) = BimStructuralSeedSync.refresh(p, model(p), docs(p));
    final (_, refreshed) = BimStructuralSeedSync.refresh(updated, s, {
      's0': drawing(empty: true),
      's1': drawing(empty: true),
    });
    expect(refreshed.effectiveGridAxes, isEmpty);
    expect(refreshed.storeys.first.slabs, isEmpty);
  });
}
