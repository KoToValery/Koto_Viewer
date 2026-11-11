import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_plate_model.dart';

List<Offset> _square(double a, {Offset o = Offset.zero}) =>
    [o, o + Offset(a, 0), o + Offset(a, a), o + Offset(0, a)];

List<PlateSupport> _edgeWalls(List<Offset> poly) => [
  for (var i = 0; i < poly.length; i++)
    PlateSupport.line('w$i', poly[i], poly[(i + 1) % poly.length], 0.0),
];

double _maxDeflection(PlateSolution s) =>
    s.nodes.fold(0.0, (m, n) => math.max(m, n.deflectionQp));

void main() {
  const e = 30e6; // kPa
  const t = 0.2;
  const q = 10.0;

  group('ACM element', () {
    test('consistent load sums to the cell area', () {
      final el = AcmElement(0.5, 0.2);
      var sum = 0.0;
      for (var n = 0; n < 4; n++) {
        sum += el.load[n * 3];
      }
      expect(sum, closeTo(0.25, 1e-12));
    });

    test('rigid-body motion produces no forces', () {
      final el = AcmElement(0.5, 0.3);
      final h = 0.25;
      final nodes = [Offset(-h, -h), Offset(h, -h), Offset(h, h), Offset(-h, h)];
      // w = 1 + 2x + 3y  -> wx = 2, wy = 3
      final u = [
        for (final p in nodes) ...[1 + 2 * p.dx + 3 * p.dy, 2.0, 3.0],
      ];
      for (var r = 0; r < 12; r++) {
        var f = 0.0;
        for (var c = 0; c < 12; c++) {
          f += el.stiffness[r * 12 + c] * u[c];
        }
        expect(f.abs(), lessThan(1e-9));
      }
    });
  });

  group('Plate benchmarks', () {
    test('simply supported square plate matches Navier (0.00406 q a^4 / D)', () {
      const a = 6.0, nu = 0.3;
      final poly = _square(a);
      final s = SlabPlateModel.solve(
        regions: [PlateRegion(polygon: poly, thicknessM: t, loadUls: q,
            loadQuasiPermanent: q)],
        supports: _edgeWalls(poly),
        cadUnitsPerMeter: 1,
        elasticModulusKpa: e,
        poisson: nu,
      );
      expect(s.status, PlateStatus.solved);
      final d = e * t * t * t / (12 * (1 - nu * nu));
      final expected = 0.00406 * q * math.pow(a, 4) / d;
      expect(_maxDeflection(s), closeTo(expected, expected * 0.03));
      expect(s.totalReactionUls, closeTo(q * a * a, 1e-6 * q * a * a));
      // Centre moment 0.0479 q a^2; nearest cell centres are 0.25 m away.
      final centre = s.cells.reduce((x, y) =>
          (x.centerCad - const Offset(3, 3)).distance <
                  (y.centerCad - const Offset(3, 3)).distance
              ? x
              : y);
      final mExpected = 0.0479 * q * a * a;
      expect(math.max(centre.mx.abs(), centre.my.abs()),
          closeTo(mExpected, mExpected * 0.06));
    });

    test('four symmetric corner columns share the load equally', () {
      final poly = _square(6);
      final cols = [
        for (final c in [Offset.zero, const Offset(6, 0), const Offset(6, 6),
          const Offset(0, 6)])
          PlateSupport.footprint('c${c.dx}${c.dy}', _square(0.3, o: c - const Offset(.15, .15))),
      ];
      final s = SlabPlateModel.solve(
        regions: [PlateRegion(polygon: poly, thicknessM: t, loadUls: q,
            loadQuasiPermanent: q * .7)],
        supports: cols,
        cadUnitsPerMeter: 1,
        elasticModulusKpa: e,
      );
      expect(s.status, PlateStatus.solved);
      expect(s.reactionUls.length, 4);
      for (final r in s.reactionUls.values) {
        expect(r, closeTo(q * 36 / 4, 1e-6 * q * 36));
      }
      for (final r in s.reactionQp.values) {
        expect(r, closeTo(q * .7 * 36 / 4, 1e-6 * q * 36));
      }
    });

    test('point and line loads stay in equilibrium', () {
      final poly = _square(5);
      final s = SlabPlateModel.solve(
        regions: [PlateRegion(polygon: poly, thicknessM: t, loadUls: q,
            loadQuasiPermanent: q)],
        supports: _edgeWalls(poly),
        pointLoads: const [PlatePointLoad('p', Offset(2, 3), 120, 80)],
        lineLoads: const [PlateLineLoad(Offset(1, 1), Offset(4, 1), 5, 3)],
        cadUnitsPerMeter: 1,
        elasticModulusKpa: e,
      );
      expect(s.totalReactionUls, closeTo(q * 25 + 120 + 15, 1e-6 * 400));
      expect(s.lostLoadUls, 0);
    });

    test('a plate on one column is reported as unsupported, not solved', () {
      final poly = _square(4);
      final s = SlabPlateModel.solve(
        regions: [PlateRegion(polygon: poly, thicknessM: t, loadUls: q,
            loadQuasiPermanent: q)],
        supports: [PlateSupport.footprint('c', _square(.3, o: const Offset(1.85, 1.85)))],
        cadUnitsPerMeter: 1,
        elasticModulusKpa: e,
      );
      expect(s.status, PlateStatus.unstable);
      expect(s.unsupportedAreaM2, closeTo(16, 1e-6));
      expect(s.lostLoadUls, closeTo(q * 16, 1e-6));
    });

    test('result does not depend on rotation or CAD units', () {
      List<Offset> transform(List<Offset> p, double angle, double scale) => [
        for (final v in p)
          Offset(v.dx * math.cos(angle) - v.dy * math.sin(angle),
                  v.dx * math.sin(angle) + v.dy * math.cos(angle)) *
              scale + const Offset(1e5, -3e4),
      ];
      PlateSolution run(double angle, double scale) {
        final poly = transform([
          Offset.zero, const Offset(8, 0), const Offset(8, 5), const Offset(3, 5),
          const Offset(3, 7), Offset.zero + const Offset(0, 7),
        ], angle, scale);
        final cols = [
          for (final c in const [Offset(0, 0), Offset(4, 0), Offset(8, 0),
            Offset(8, 5), Offset(3, 5), Offset(0, 7), Offset(0, 3.5), Offset(3, 7)])
            PlateSupport.footprint('$c',
                transform(_square(.3, o: c - const Offset(.15, .15)), angle, scale)),
        ];
        return SlabPlateModel.solve(
          regions: [PlateRegion(polygon: poly, thicknessM: t, loadUls: q,
              loadQuasiPermanent: q)],
          supports: cols,
          cadUnitsPerMeter: scale,
          elasticModulusKpa: e,
        );
      }
      final base = run(0, 1);
      final turned = run(0.52, 100);
      expect(base.status, PlateStatus.solved);
      expect(turned.status, PlateStatus.solved);
      expect(_maxDeflection(turned),
          closeTo(_maxDeflection(base), _maxDeflection(base) * 0.01));
      for (final id in base.reactionUls.keys) {
        expect(turned.reactionUls[id],
            closeTo(base.reactionUls[id]!, base.totalReactionUls * 0.005));
      }
    });
  });
}
