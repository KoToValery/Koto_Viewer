import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/load_rundown.dart';
import 'package:kotoview/src/features/structural_designer/models/element_check_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

StructuralColumn _col(String id, Offset c) =>
    StructuralColumn(id: id, center: c, width: .3, height: .3);

StructuralSlab _slab(String id) => StructuralSlab(
  id: id,
  polygon: const [Offset(-.15, -.15), Offset(6.15, -.15), Offset(6.15, 6.15), Offset(-.15, 6.15)],
);

const _corners = [Offset(0, 0), Offset(6, 0), Offset(6, 6), Offset(0, 6)];

StructuralProject _project({bool floating = false, double facade = 3.5}) => StructuralProject(
  facadeWallLoad: facade,
  storeys: [
    StoreyLevel(
      id: 'g',
      name: 'g',
      elevation: 0,
      height: 3,
      columns: [for (var i = 0; i < 4; i++) _col('g$i', _corners[i])],
      slabs: [_slab('sg')],
    ),
    StoreyLevel(
      id: 'u',
      name: 'u',
      elevation: 3,
      height: 3,
      columns: [
        for (var i = 0; i < 4; i++) _col('u$i', _corners[i]),
        if (floating) _col('uf', const Offset(3, 3)),
      ],
      slabs: [_slab('su')],
    ),
  ],
);

double _sum(PreliminaryCheckReport r, String storey) => r.elements.values
    .where((e) => e.storeyId == storey)
    .fold(0.0, (s, e) => s + e.axialUls);

void main() {
  const slabArea = 6.3 * 6.3;
  const qUls = 1.35 * (25 * .2 + 1.5) + 1.5 * 2.0;
  const colSelf = 1.35 * 25 * .09 * 3;

  test('aligned columns accumulate the storey above', () {
    final r = LoadRundown.analyze(_project(facade: 0), cadUnitsPerMeter: 1);
    final upper = r.element('u', 'u0')!;
    final lower = r.element('g', 'g0')!;
    expect(upper.axialUls, closeTo(qUls * slabArea / 4 + colSelf, 1e-3));
    expect(lower.axialUls, closeTo(upper.axialUls + qUls * slabArea / 4 + colSelf, 1e-3));
    expect(lower.check(CheckKind.punching)?.isDetermined, isTrue);
    expect(lower.check(CheckKind.columnSeismicAxial)?.isDetermined, isTrue);
  });

  test('a floating column loads the slab below instead of disappearing', () {
    final r = LoadRundown.analyze(_project(floating: true, facade: 0), cadUnitsPerMeter: 1);
    final upperTotal = _sum(r, 'u');
    final lowerTotal = _sum(r, 'g');
    expect(lowerTotal, closeTo(upperTotal + qUls * slabArea + 4 * colSelf, 1e-2));
    // The floating column's load makes the lower slab work harder.
    final plain = LoadRundown.analyze(_project(facade: 0), cadUnitsPerMeter: 1);
    final loaded = r.slabsFor('g').single.deflection.demand;
    final unloaded = plain.slabsFor('g').single.deflection.demand;
    expect(loaded, greaterThan(unloaded * 1.2));
  });

  test('facade load goes on non-roof ceilings only', () {
    final r = LoadRundown.analyze(_project(), cadUnitsPerMeter: 1);
    final noFacade = LoadRundown.analyze(_project(facade: 0), cadUnitsPerMeter: 1);
    expect(_sum(r, 'u'), closeTo(_sum(noFacade, 'u'), 1e-6));
    expect(_sum(r, 'g') - _sum(noFacade, 'g'), closeTo(1.35 * 3.5 * 4 * 6.3, 1e-2));
  });

  test('same result in centimetres', () {
    StructuralProject toCm(StructuralProject p) => p.copyWith(storeys: [
      for (final s in p.storeys)
        s.copyWith(
          columns: [
            for (final c in s.columns)
              c.copyWith(center: c.center * 100, width: 30, height: 30),
          ],
          slabs: [
            for (final sl in s.slabs)
              sl.copyWith(polygon: [for (final v in sl.polygon) v * 100]),
          ],
        ),
    ]);
    final m = LoadRundown.analyze(_project(floating: true), cadUnitsPerMeter: 1);
    final cm = LoadRundown.analyze(toCm(_project(floating: true)), cadUnitsPerMeter: 100);
    for (final e in m.elements.entries) {
      expect(cm.elements[e.key]!.axialUls, closeTo(e.value.axialUls, 1e-3));
      expect(cm.elements[e.key]!.utilization, closeTo(e.value.utilization, 1e-6));
    }
  });
}
