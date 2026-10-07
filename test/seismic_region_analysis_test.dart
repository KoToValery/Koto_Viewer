import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/seismic_analysis_models.dart';

List<Offset> box(double x, double y, double w, double h) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x + w, y + h),
  Offset(x, y + h),
];
StoreySeismicCheck evaluate(StoreyLevel storey, {double scale = 1}) =>
    SeismicAnalysisCalculator.analyzeProject(
      StructuralProject(storeys: [storey]),
      cadUnitsPerMeter: scale,
    ).storeyChecks.single;

void main() {
  test(
    'separate regions reproduce isolated models and retain unique assignments',
    () {
      final a = StructuralSlab(
        id: 'a',
        polygon: box(0, 0, 4, 4),
        thickness: .2,
      );
      final b = StructuralSlab(
        id: 'b',
        polygon: box(10, 0, 6, 6),
        thickness: .3,
        openings: [box(12, 2, 1, 1)],
      );
      const ca = StructuralColumn(
        id: 'ca',
        center: Offset(1, 1),
        width: .4,
        height: .4,
      );
      const cb = StructuralColumn(
        id: 'cb',
        center: Offset(15, 5),
        width: .5,
        height: .5,
      );
      const outside = StructuralColumn(
        id: 'outside',
        center: Offset(30, 30),
        width: .4,
        height: .4,
      );
      final storey = StoreyLevel(
        id: 'f',
        name: 'f',
        slabs: [a, b],
        columns: [ca, cb, outside],
      );
      final result = evaluate(storey);
      expect(result.eccentricityM, isNull);
      expect(result.disconnectedColumnIds, ['outside']);
      expect(result.diaphragmRegions.length, 2);
      for (var i = 0; i < 2; i++) {
        final region = result.diaphragmRegions[i];
        final alone = evaluate(
          storey.copyWith(slabs: [i == 0 ? a : b], columns: [i == 0 ? ca : cb]),
        );
        expect(region.slabIndices, [i]);
        expect(region.columnIds, [i == 0 ? 'ca' : 'cb']);
        expect(region.check!.floorAreaM2, alone.floorAreaM2);
        expect(region.check!.centerOfMassCad, alone.centerOfMassCad);
        expect(region.check!.centerOfRigidityCad, alone.centerOfRigidityCad);
        expect(region.check!.eccentricityM, alone.eccentricityM);
        expect(region.check!.stiffnessRatioToAbove, isNull);
      }
    },
  );
  test(
    'shared column withholds both affected regions without duplicating mass',
    () {
      final result = evaluate(
        StoreyLevel(
          id: 'f',
          name: 'f',
          slabs: [
            StructuralSlab(id: 'a', polygon: box(0, 0, 4, 4)),
            StructuralSlab(id: 'b', polygon: box(4.1, 0, 4, 4)),
            StructuralSlab(id: 'c', polygon: box(20, 0, 4, 4)),
          ],
          columns: const [
            StructuralColumn(
              id: 'shared',
              name: 'C1',
              center: Offset(4.05, 2),
              width: .4,
              height: .4,
            ),
          ],
        ),
      );
      for (final region in result.diaphragmRegions.take(2)) {
        expect(region.check, isNull);
        expect(region.columnIds, isEmpty);
        expect(region.ambiguousSupportNames, ['C1']);
      }
      expect(result.diaphragmRegions.last.check, isNotNull);
      expect(result.diaphragmRegions.last.ambiguousSupportNames, isEmpty);
    },
  );
  test('wall bridging regions requires a coupled model', () {
    final result = evaluate(
      StoreyLevel(
        id: 'f',
        name: 'f',
        slabs: [
          StructuralSlab(id: 'a', polygon: box(0, 0, 4, 4)),
          StructuralSlab(id: 'b', polygon: box(6, 0, 4, 4)),
        ],
        shearWalls: const [
          StructuralShearWall(
            id: 'w',
            name: 'W1',
            start: Offset(2, 2),
            end: Offset(8, 2),
            thickness: .2,
          ),
        ],
      ),
    );
    expect(
      result.diaphragmRegions.every(
        (r) => r.check == null && r.ambiguousSupportNames.contains('W1'),
      ),
      isTrue,
    );
  });
  test(
    'connected slabs retain their own thickness and openings in regional mass',
    () {
      final result = evaluate(
        StoreyLevel(
          id: 'f',
          name: 'f',
          slabs: [
            StructuralSlab(id: 'a', polygon: box(0, 0, 2, 2), thickness: .2),
            StructuralSlab(id: 'b', polygon: box(2, 0, 2, 2), thickness: .4),
            StructuralSlab(id: 'remote', polygon: box(10, 0, 2, 2)),
          ],
        ),
      );
      final region = result.diaphragmRegions.first;
      expect(region.slabIndices, [0, 1]);
      // Project defaults: 1.5 + 0.3*2 = 2.1 kN/m2 superimposed weight.
      final expected = (4 * 7.1 * 1 + 4 * 12.1 * 3) / (4 * 7.1 + 4 * 12.1);
      expect(region.check!.floorAreaM2, 8);
      expect(region.check!.centerOfMassCad!.dx, closeTo(expected, 1e-10));
    },
  );
  test('millimetre coordinates preserve exclusive support assignment', () {
    final result = evaluate(
      StoreyLevel(
        id: 'f',
        name: 'f',
        slabs: [
          StructuralSlab(id: 'a', polygon: box(0, 0, 4000, 4000)),
          StructuralSlab(id: 'b', polygon: box(10000, 0, 4000, 4000)),
        ],
        columns: const [
          StructuralColumn(
            id: 'c',
            center: Offset(2000, 2000),
            width: 400,
            height: 400,
          ),
        ],
      ),
      scale: 1000,
    );
    expect(result.diaphragmRegions.first.columnIds, ['c']);
    expect(result.diaphragmRegions.last.columnIds, isEmpty);
    expect(result.diaphragmRegions.first.check!.floorAreaM2, 16);
    expect(
      result.diaphragmRegions.first.check!.eccentricityM!.distance,
      closeTo(0, 1e-10),
    );
  });
}
