import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_structural_seed_sync.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'bim_seed_lifecycle_test.dart' as f;

DxfDocument aligned({double scale = 1, Offset shift = Offset.zero}) {
  final doc = f.drawing();
  final meta = BimUnderlayMetadata.read(doc)!;
  meta['sourceToProject'] = {
    'scale': scale,
    'translation': [shift.dx, shift.dy],
  };
  meta['slabEnvelope']['version'] = SlabEnvelopeResult.version;
  meta['axes'] = [
    StructuralGridAxis(
      id: 'a',
      name: 'A',
      start: shift,
      end: const Offset(10, 0) * scale + shift,
    ).toJson(),
  ];
  doc.headerVars[BimUnderlayMetadata.key] = jsonEncode(meta);
  return doc;
}

void main() {
  for (final ratio in [1.0, 2.0]) {
    test(
      'alignment rebases edited elements, holes and shared axes exactly once: scale=$ratio',
      () {
        final source = f.project([0, 2.85]);
        var (project, model) = BimStructuralSeedSync.refresh(
          source,
          f.model(source),
          {'s0': aligned(), 's1': aligned()},
        );
        final floor = model.storeys.first;
        final edited = floor.slabs.single.copyWith(
          polygon: f.ring(9),
          thickness: .27,
          openings: [f.ring(1).map((p) => p + const Offset(2, 2)).toList()],
          openingTypes: [SlabOpeningType.staircase],
        );
        model = model.copyWith(
          storeys: [
            floor.copyWith(
              slabs: [edited],
              columns: [
                const StructuralColumn(
                  id: 'c',
                  center: Offset(3, 3),
                  width: .3,
                  height: .4,
                ),
              ],
              shearWalls: [
                const StructuralShearWall(
                  id: 'w',
                  start: Offset(1, 1),
                  end: Offset(1, 4),
                  thickness: .25,
                ),
              ],
              beams: [
                const StructuralBeam(
                  id: 'b',
                  start: Offset(1, 1),
                  end: Offset(5, 1),
                  width: .3,
                  depth: .5,
                ),
              ],
            ),
            model.storeys.last,
          ],
        );
        const shift = Offset(120, -37);
        final docs = {
          's0': aligned(scale: ratio, shift: shift),
          's1': aligned(),
        };
        final (updated, moved) = BimStructuralSeedSync.refresh(
          project,
          model,
          docs,
        );
        final next = moved.storeys.first;
        expect(next.columns.single.center, const Offset(3, 3) * ratio + shift);
        expect(next.columns.single.width, .3 * ratio);
        expect(
          next.shearWalls.single.start,
          const Offset(1, 1) * ratio + shift,
        );
        expect(next.shearWalls.single.end, const Offset(1, 4) * ratio + shift);
        expect(next.beams.single.end, const Offset(5, 1) * ratio + shift);
        expect(
          next.slabs.single.polygon,
          edited.polygon.map((p) => p * ratio + shift).toList(),
        );
        expect(
          next.slabs.single.openings.single,
          edited.openings.single.map((p) => p * ratio + shift).toList(),
        );
        expect(next.slabs.single.thickness, .27);
        expect(next.slabs.single.openingTypes, [SlabOpeningType.staircase]);
        expect(next.slabs.single.isFloorSlab, true);
        expect(
          updated.storeys.first.processing['structuralReviewRequired'],
          false,
        );
        expect(
          moved.storeys.last.slabs.single.polygon,
          model.storeys.last.slabs.single.polygon,
        );
        expect(
          moved.gridAxes.map((a) => a.name).toSet().length,
          moved.gridAxes.length,
        );
        expect(
          moved.gridAxes.any((a) => (a.start.dy - shift.dy).abs() < .001),
          true,
        );
        final again = BimStructuralSeedSync.refresh(updated, moved, docs).$2;
        expect(again.toJson(), moved.toJson());
        final (reset, returned) = BimStructuralSeedSync.refresh(
          updated,
          moved,
          {'s0': aligned(), 's1': aligned()},
        );
        expect(
          returned.storeys.first.columns.single.center,
          const Offset(3, 3),
        );
        expect(returned.storeys.first.slabs.single.polygon, edited.polygon);
        expect(
          reset.storeys.first.processing['structuralTransform']['translation'],
          [0.0, 0.0],
        );
      },
    );
  }
  test('older source frame is recovered from the saved seed key', () {
    final source = f.project([0, 2.85]);
    final (first, model) = BimStructuralSeedSync.refresh(
      source,
      f.model(source),
      {'s0': aligned(), 's1': aligned()},
    );
    final project = first.copyWith(
      storeys: first.storeys.map((s) {
        final processing = Map<String, dynamic>.from(s.processing)
          ..remove('structuralTransform');
        return s.copyWith(processing: processing);
      }).toList(),
    );
    final moved = BimStructuralSeedSync.refresh(project, model, {
      's0': aligned(shift: const Offset(100, 0)),
      's1': aligned(),
    }).$2;
    expect(
      moved.storeys.first.slabs.single.polygon.first,
      const Offset(100, 0),
    );
  });
  test('legacy automatic ceiling is migrated to its creation floor', () {
    final source = f.project([0, 2.85]);
    final legacy = f
        .model(source)
        .copyWith(
          storeys: [
            const StoreyLevel(
              id: 's0',
              name: 'ground',
              slabs: [
                StructuralSlab(
                  id: 'bim_slab_s0_main_0',
                  polygon: [
                    Offset(0, 0),
                    Offset(9, 0),
                    Offset(9, 9),
                    Offset(0, 9),
                  ],
                ),
              ],
            ),
            const StoreyLevel(id: 's1', name: 'upper', elevation: 2.85),
          ],
        );
    final model = BimStructuralSeedSync.refresh(source, legacy, {
      's0': aligned(),
      's1': aligned(),
    }).$2;
    final slab = model.storeys.first.slabs.single;
    expect(slab.isFloorSlab, true);
    expect(model.storeys.first.structuralElevationFor(slab), -.05);
    expect(model.floorSlabStoreyFor(model.storeys.last), isNull);
    expect(model.ceilingSlabStoreyFor(model.storeys.first)!.id, 's1');
    expect(
      model
          .supportedStoreyFor(model.storeys.first)
          .slabs
          .any((s) => s.id == slab.id),
      false,
    );
  });
}
