import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_railings.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_rules.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_section.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_labels.dart';

const design = ArchitectStairDesign(
  shape: StairShape.quarterTurn,
  winderSteps: true,
  rise: 3.2,
  use: StairUse.private,
  evacuation: StairEvacuation.from16To50,
  followStoreys: false,
  manualRisers: 20,
  manualGoing: .30,
);
ArchitectStair stair([ArchitectStairDesign d = design]) => ArchitectStair(
  id: 'st',
  startPoint: Offset.zero,
  endPoint: const Offset(1, 0),
  width: 1.2,
  design: d,
);
ArchitectProject project(ArchitectStair s) => ArchitectProject(
  id: 'p',
  name: 'Test',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 'floor',
  storeys: [
    ArchitectStorey(id: 'floor', name: 'Level', stairs: [s]),
  ],
);

double area(List<Offset> p) =>
    [
      for (var i = 0; i < p.length; i++)
        p[i].dx * p[(i + 1) % p.length].dy - p[i].dy * p[(i + 1) % p.length].dx,
    ].reduce((a, b) => a + b).abs() /
    2;

void main() {
  test(
    'legacy plans retain landings; winder and overlap settings round trip',
    () {
      final old = design.toJson()
        ..remove('winderSteps')
        ..remove('cornerRiser')
        ..remove('manualWinderRadius')
        ..remove('manualWinderSteps');
      expect(ArchitectStairDesign.fromJson(old).hasWinders, isFalse);
      final d = design.copyWith(
        cornerRiser: true,
        manualWinderSteps: 4,
        manualWinderRadius: .4,
      );
      expect(ArchitectStairDesign.fromJson(d.toJson()).toJson(), d.toJson());
      final overlap = design.copyWith(shape: StairShape.spiralOverlap);
      expect(overlap.sweepDegrees, 375);
      overlap.validate();
      expect(
        ArchitectStairDesign.fromJson(overlap.toJson()).shape,
        StairShape.spiralOverlap,
      );
      expect(overlap.copyWith(shape: StairShape.spiral).sweepDegrees, 270);
      expect(
        () => overlap.copyWith(sweepDegrees: 360).validate(),
        throwsArgumentError,
      );
      expect(
        () => design
            .copyWith(shape: StairShape.spiral, sweepDegrees: 450)
            .validate(),
        throwsArgumentError,
      );
    },
  );
  for (final shape in [StairShape.quarterTurn, StairShape.halfTurn]) {
    for (final cornerRiser in [false, true]) {
      test(
        '${shape.name} ${cornerRiser ? 'riser' : 'tread'} at corner has actual safe winders and a continuous waist',
        () {
          final d = design.copyWith(shape: shape, cornerRiser: cornerRiser);
          final s = stair(d), plan = s.plan, layout = d.winderLayout(s.width);
          expect(layout.perQuarter % 2, cornerRiser ? 0 : 1);
          expect(plan.nosings, hasLength(d.risers));
          final turnCount = layout.perQuarter * d.turnQuarters;
          final lead = (d.risers - 1 - turnCount) ~/ 2;
          // Measure the 30 cm line from the actual inner/outer nosing endpoints.
          Offset point(int i) {
            final (inner, outer) = plan.nosings[lead + i];
            return inner + (outer - inner) / (outer - inner).distance * .30;
          }

          for (var i = 0; i < turnCount; i++) {
            expect(
              (point(i + 1) - point(i)).distance,
              greaterThanOrEqualTo(.23 - 1e-8),
            );
          }
          final center = Offset(lead * d.going, layout.radius + s.width / 2);
          final corner =
              center +
              Offset(layout.radius + s.width, -layout.radius - s.width);
          final hits = plan.nosings.where(
            (n) => (n.$2 - corner).distance < 1e-7,
          );
          expect(hits.length, cornerRiser ? 1 : 0);
          expect(plan.contains(center, .001), isFalse);
          final footprintArea = plan.footprints
              .map(area)
              .reduce((a, b) => a + b);
          final surfaceArea = plan.surfaces
              .map((s) => area(s.polygon))
              .reduce((a, b) => a + b);
          expect(surfaceArea, closeTo(footprintArea, .00001));
          expect(ArchitectStairGeometry.of(s).landings, isEmpty);
          expect(d.flightCount, 1);
          final body = ArchitectStairMesh.body(s);
          for (final solid in body) {
            for (final triangle in solid.triangles) {
              expect(triangle.area, greaterThan(1e-12));
              expect(
                [
                  triangle.v0.z,
                  triangle.v1.z,
                  triangle.v2.z,
                ].every((z) => z.isFinite),
                isTrue,
              );
            }
          }
          final paths = ArchitectStairRailings.build(
            s,
            storey: project(s).activeStorey,
          );
          expect(paths, isNotEmpty);
          final z = paths.expand((p) => p.base.map((p) => p.z));
          expect(z.reduce(math.min), closeTo(d.riser, 1e-6));
          expect(z.reduce(math.max), closeTo(d.rise, 1e-6));
          final end = plan.nosings.last,
              previous = plan.nosings[plan.nosings.length - 2];
          final section = ArchitectStairSection.build(
            body,
            (end.$1 + end.$2) / 2,
            end.$1 + end.$2 - previous.$1 - previous.$2,
          );
          expect(
            section.regions[StairSolidMaterial.concrete]!.computeMetrics(),
            isNotEmpty,
          );
          expect(
            section.regions[StairSolidMaterial.finish]!.computeMetrics(),
            isNotEmpty,
          );
          expect(section.bounds.bottom, closeTo(d.rise, 1e-5));
          final firstTurn = plan.nosings[lead + 1];
          final cut = ArchitectStairGeometry.of(s).cut((lead + 1.5) * d.riser);
          expect(cut.crossing, firstTurn);
        },
      );
    }
  }
  test(
    'winders mirror and rotate together with railings and finished elevations',
    () {
      final a = stair(), d = design.copyWith(turnLeft: true, startOffset: .25);
      final b = stair(
        d,
      ).copyWith(startPoint: const Offset(4, 6), endPoint: const Offset(4, 7));
      for (var i = 0; i < a.plan.nosings.length; i++) {
        final p = a.plan.nosings[i].$1, q = b.plan.nosings[i].$1;
        expect((q - Offset(4 + p.dy, 6 + p.dx)).distance, lessThan(1e-8));
      }
      final heights = ArchitectStairMesh.body(
        b,
      ).expand((s) => s.triangles).expand((t) => [t.v0.z, t.v1.z, t.v2.z]);
      expect(heights.reduce(math.max), closeTo(d.rise + .25, 1e-8));
    },
  );
  test(
    'Article 52(4) checks actual winders, with the correct evacuation scope',
    () {
      final small = design.copyWith(
        manualWinderSteps: 5,
        manualWinderRadius: .05,
      );
      for (final evacuation in [
        StairEvacuation.from16To50,
        StairEvacuation.upTo15,
        StairEvacuation.over50,
      ]) {
        final checks = ArchitectStairRules.check(
          stair(small.copyWith(evacuation: evacuation)),
        );
        final check = checks.singleWhere(
          (c) => c.kind == StairCheckKind.innerGoing30,
        );
        expect(check.actual, lessThan(.23));
        expect(
          check.state,
          evacuation == StairEvacuation.from16To50
              ? StairCheckState.error
              : StairCheckState.advice,
        );
        if (evacuation == StairEvacuation.from16To50) {
          expect(check.article, '52(4)1');
        }
        if (evacuation == StairEvacuation.over50) {
          expect(
            checks.any(
              (c) =>
                  c.kind == StairCheckKind.scope &&
                  c.state == StairCheckState.review,
            ),
            isTrue,
          );
        }
      }
      final s = stair(small),
          p = project(
            s,
          ).copyWith(storeys: [project(s).activeStorey.copyWith(stairs: [])]);
      expect(
        () => PutArchitectStair(
          storeyId: 'floor',
          stair: s,
          create: true,
        ).apply(p),
        throwsArgumentError,
      );
    },
  );
  test('manual winders check their own walking-line going and slope', () {
    final s = stair(
      design.copyWith(manualWinderRadius: .05, manualWinderSteps: 5),
    );
    final errors = ArchitectStairRules.check(
      s,
    ).where((c) => c.state == StairCheckState.error);
    expect(
      errors.any((c) => c.kind == StairCheckKind.going && c.actual! < .25),
      isTrue,
    );
    expect(
      errors.any((c) => c.kind == StairCheckKind.slope && c.actual! > 1 / 1.5),
      isTrue,
    );
  });
  test(
    'overlap headroom keeps indoor, private and outdoor code scopes distinct',
    () {
      final d = design.copyWith(
        shape: StairShape.spiralOverlap,
        sweepDegrees: 450,
        rise: 2.5,
        manualRisers: 20,
      );
      for (final use in [
        StairUse.private,
        StairUse.common,
        StairUse.outdoorRoute,
      ]) {
        final checks = ArchitectStairRules.check(stair(d.copyWith(use: use)));
        final measured = checks.singleWhere(
          (c) => c.kind == StairCheckKind.headroom && c.actual != null,
        );
        expect(measured.actual, lessThan(2.1));
        expect(
          measured.state,
          use == StairUse.common
              ? StairCheckState.error
              : StairCheckState.advice,
        );
        expect(measured.article, use == StairUse.common ? '55(1)5' : '2.10 m');
      }
    },
  );
  test('winders cannot replace the landing required by flight rise', () {
    for (final shape in [StairShape.quarterTurn, StairShape.halfTurn]) {
      final s = stair(
        design.copyWith(shape: shape, use: StairUse.common, rise: 2.8),
      );
      expect(
        ArchitectStairRules.check(s).any(
          (c) =>
              c.kind == StairCheckKind.flightRise &&
              c.state == StairCheckState.error,
        ),
        isTrue,
      );
    }
  });
  test(
    'overlapping spiral retains its well and two distinct vertical levels',
    () {
      final s = stair(
        design.copyWith(
          shape: StairShape.spiralOverlap,
          sweepDegrees: 720,
          rise: 6,
          manualRisers: 40,
          code: StairCode.geometryOnly,
        ),
      );
      final d = s.design!, center = Offset(0, d.innerRadius + s.width / 2);
      expect(s.plan.contains(center, .001), isFalse);
      expect(s.plan.contains(const Offset(.1, 0), .001), isTrue);
      final body = ArchitectStairMesh.body(s);
      final heights = body
          .expand((s) => s.triangles)
          .expand((t) => [t.v0.z, t.v1.z, t.v2.z]);
      expect(heights.reduce(math.max), closeTo(6, 1e-8));
      final lower = ArchitectStairGeometry.of(s).cut(1);
      expect(lower.above.computeMetrics(), isNotEmpty);
      final upper = ArchitectStairGeometry.of(s).cut(4);
      expect(upper.above.computeMetrics(), isEmpty);
      final rails = ArchitectStairRailings.build(
        s,
        storey: project(s).activeStorey,
      );
      final top = rails.expand((p) => p.base.map((p) => p.z)).reduce(math.max);
      expect(top, closeTo(6, 1e-8));
    },
  );
  test(
    'overlap headroom uses the concrete soffit and detects physical intersections',
    () {
      final d = design.copyWith(
        shape: StairShape.spiralOverlap,
        sweepDegrees: 450,
        manualRisers: 30,
        rise: 4.5,
        code: StairCode.geometryOnly,
      );
      expect(
        d.overlapHeadroom,
        closeTo(((360 / 450 * 29 * 8).floor() / 8 - 1) * .15 - .17, 1e-8),
      );
      final thinner = d.copyWith(concreteThickness: .1, finishThickness: .01);
      expect(thinner.overlapHeadroom - d.overlapHeadroom, closeTo(.06, 1e-8));
      final collision = d.copyWith(rise: .2, sweepDegrees: 900);
      expect(
        ArchitectStairRules.check(stair(collision)).any(
          (c) =>
              c.kind == StairCheckKind.headroom &&
              c.state == StairCheckState.error,
        ),
        isTrue,
      );
    },
  );
  test('winder caption reports both straight and curved going sizes', () async {
    final l = await AppLocalizations.delegate.load(const Locale('bg'));
    final caption = stairPlanLabel(l, stair());
    expect(caption, contains('30–'));
    expect(caption, contains('H=3,20'));
  });
  test(
    'automatic winders remain buildable across widths, rises and corner choices',
    () {
      for (final width in [.7, 1.0, 1.2, 1.6, 2.0]) {
        for (final height in [.5, 1.6, 2.8, 4.9]) {
          for (final shape in [StairShape.quarterTurn, StairShape.halfTurn]) {
            for (final corner in [false, true]) {
              final d = design.copyWith(
                shape: shape,
                rise: height,
                cornerRiser: corner,
                code: StairCode.geometryOnly,
                autoRisers: true,
                autoGoing: true,
              );
              d.validate();
              final s = stair(d).copyWith(width: width);
              expect(s.plan.nosings.length, d.risers);
              expect(
                d.winderGoingAt(width, .3),
                greaterThanOrEqualTo(.23 - 1e-9),
              );
              expect(
                d.winderGoingAt(width, 0),
                greaterThanOrEqualTo(.05 - 1e-9),
              );
              expect(ArchitectStairMesh.body(s), isNotEmpty);
            }
          }
        }
      }
    },
  );
  test(
    'computed overlap clearance agrees with the actual upper concrete mesh',
    () {
      final d = design.copyWith(
        shape: StairShape.spiralOverlap,
        sweepDegrees: 450,
        rise: 4.5,
        manualRisers: 30,
        code: StairCode.geometryOnly,
      );
      final s = stair(d), center = Offset(0, d.innerRadius + s.width / 2);
      final concrete = ArchitectStairMesh.body(s)
          .where((s) => s.material == StairSolidMaterial.concrete)
          .expand((s) => s.triangles)
          .toList();
      var minimum = double.infinity;
      for (var i = 0; i < 100; i++) {
        final angle = (math.pi / 2) * (i + .0001) / 100;
        final point =
            center +
            Offset(math.sin(angle), -math.cos(angle)) *
                (d.innerRadius + s.width / 2);
        final treadTop = ((angle / d.anglePerGoing).floor() + 1) * d.riser;
        var underside = double.infinity;
        for (final t in concrete) {
          final a = Offset(t.v0.x, t.v0.y),
              b = Offset(t.v1.x, t.v1.y),
              c = Offset(t.v2.x, t.v2.y);
          final denominator = ArchitectStairGeometry.cross(b - a, c - a);
          if (denominator.abs() < 1e-10) continue;
          final v =
              ArchitectStairGeometry.cross(point - a, c - a) / denominator;
          final w =
              ArchitectStairGeometry.cross(b - a, point - a) / denominator;
          if (v < -1e-8 || w < -1e-8 || v + w > 1 + 1e-8) continue;
          final z = t.v0.z * (1 - v - w) + t.v1.z * v + t.v2.z * w;
          if (z > treadTop + .01) underside = math.min(underside, z);
        }
        minimum = math.min(minimum, underside - treadTop);
      }
      expect(minimum, greaterThanOrEqualTo(d.overlapHeadroom - 1e-8));
      expect(
        minimum - d.overlapHeadroom,
        lessThanOrEqualTo(
          d.riser / ArchitectStairDesign.spiralSlicesPerGoing + .001,
        ),
      );
    },
  );
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'phone $locale toggles winders and saves the selected corner treatment',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ArchitectStair? saved;
        final s = stair(design.copyWith(winderSteps: false));
        final l = await AppLocalizations.delegate.load(Locale(locale));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('open'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ArchitectStairPropertiesDialog(
                      project: project(s),
                      stair: s,
                      onApply: (s) {
                        saved = s;
                        return true;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('stair-winders')));
        await tester.tap(find.byKey(const ValueKey('stair-winders')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('stair-dimensions')),
        );
        await tester.tap(find.text(l.stairAdvanced));
        await tester.pumpAndSettle();
        final corner = find.byKey(const ValueKey('stair-corner-false'));
        await tester.ensureVisible(corner);
        await tester.tap(corner);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.stairWinderCornerRiser).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('stair-save')));
        await tester.pumpAndSettle();
        expect(saved!.design!.hasWinders, isTrue);
        expect(saved!.design!.cornerRiser, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
