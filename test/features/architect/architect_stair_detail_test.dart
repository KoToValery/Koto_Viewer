import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/rendering/architect_scene_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_railings.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_section.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_labels.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_properties_dialog.dart';

const design = ArchitectStairDesign(
  shape: StairShape.straight,
  use: StairUse.private,
  rise: 1.6,
  followStoreys: false,
  manualRisers: 10,
  manualGoing: .3,
);
ArchitectStair stair([ArchitectStairDesign d = design]) => ArchitectStair(
  id: 'st',
  startPoint: Offset.zero,
  endPoint: const Offset(1, 0),
  width: 1.2,
  design: d,
);
ArchitectStorey floor({List<ArchitectWall> walls = const []}) =>
    ArchitectStorey(
      id: 's',
      name: '0.00',
      height: 4,
      walls: walls,
      stairs: [stair()],
    );
ArchitectProject project({List<ArchitectWall> walls = const []}) =>
    ArchitectProject(
      id: 'p',
      name: 'Test',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      storeys: [floor(walls: walls)],
    );
const wall = ArchitectWall(
  id: 'w',
  startPoint: Offset(-.2, -.725),
  endPoint: Offset(3, -.725),
  thickness: .25,
  height: 5,
  followStoreyHeight: false,
);

void main() {
  test(
    'old parametric stairs get smart railing and label defaults without changing their dimensions',
    () {
      final json = design.toJson()
        ..remove('showRailing')
        ..remove('showLabel')
        ..remove('guardHeight')
        ..remove('finishThickness')
        ..remove('nosingProjection');
      final restored = ArchitectStairDesign.fromJson(json);
      expect(restored.showRailing, isTrue);
      expect(restored.showLabel, isTrue);
      expect(restored.risers, 10);
      expect(restored.going, .3);
      final hidden = design.copyWith(
        showRailing: false,
        showLabel: false,
        concreteThickness: .18,
        finishThickness: .015,
        nosingProjection: .025,
      );
      expect(
        ArchitectStairDesign.fromJson(hidden.toJson()).toJson(),
        hidden.toJson(),
      );
    },
  );
  test(
    'open straight stair has two guards and no guard across either entrance',
    () {
      final paths = ArchitectStairRailings.build(stair(), storey: floor());
      expect(paths, hasLength(2));
      expect(paths.every((p) => !p.wallMounted), isTrue);
      for (final path in paths) {
        expect(path.base.every((p) => (p.y.abs() - .6).abs() < 1e-8), isTrue);
        expect(path.base.map((p) => p.z).reduce(math.max), closeTo(1.6, 1e-8));
      }
    },
  );
  test(
    'full wall changes only its adjacent side to a wall-mounted handrail',
    () {
      final f = floor(walls: [wall]);
      final paths = ArchitectStairRailings.build(stair(), storey: f);
      expect(paths.where((p) => p.wallMounted), hasLength(1));
      expect(paths.where((p) => !p.wallMounted), hasLength(1));
      expect(
        paths
            .singleWhere((p) => p.wallMounted)
            .base
            .every((p) => p.y > -.6 && p.y < -.5),
        isTrue,
      );
      final open = ArchitectStairRailings.build(
        stair(),
        storey: f.copyWith(walls: []),
      );
      expect(open.every((p) => !p.wallMounted), isTrue);
    },
  );
  test('partial wall does not remove the guard from the remaining flight', () {
    final paths = ArchitectStairRailings.build(
      stair(),
      storey: floor(walls: [wall.copyWith(endPoint: const Offset(1.3, -.725))]),
    );
    expect(paths.any((p) => p.wallMounted), isTrue);
    expect(
      paths.any(
        (p) => !p.wallMounted && p.base.any((v) => v.y < 0 && v.x > 1.6),
      ),
      isTrue,
    );
  });
  test('a window and a low wall retain a protective guard', () {
    final withWindow = wall.copyWith(
      windows: const [
        ArchitectWindow(
          id: 'win',
          wallId: 'w',
          uuid: 'window',
          offsetRatio: .5,
          width: .8,
          height: 1.2,
          sillHeight: .8,
        ),
      ],
    );
    final paths = ArchitectStairRailings.build(
      stair(),
      storey: floor(walls: [withWindow]),
    );
    expect(
      paths.any(
        (p) =>
            !p.wallMounted &&
            p.base.any((v) => v.y < 0 && v.x > 1.2 && v.x < 1.6),
      ),
      isTrue,
    );
    final low = ArchitectStairRailings.build(
      stair(),
      storey: floor(walls: [wall.copyWith(height: 1.1)]),
    );
    expect(low.every((p) => !p.wallMounted), isTrue);
  });
  test('railing visibility removes both handrail and guard mesh', () {
    final s = stair(design.copyWith(showRailing: false));
    expect(ArchitectStairRailings.build(s, storey: floor()), isEmpty);
    expect(ArchitectStairMesh.railings(s, storey: floor()), isEmpty);
    expect(ArchitectStairMesh.railings(stair(), storey: floor()), isNotEmpty);
  });
  test(
    '360 degree guards retain separate lower and upper ends at the same XY',
    () {
      final s = stair(
        design.copyWith(shape: StairShape.spiral, sweepDegrees: 360),
      );
      final paths = ArchitectStairRailings.build(s, storey: floor());
      expect(paths, hasLength(2));
      for (final path in paths) {
        expect(
          path.base.map((p) => p.z).reduce(math.min),
          closeTo(design.riser, 1e-8),
        );
        expect(
          path.base.map((p) => p.z).reduce(math.max),
          closeTo(design.rise, 1e-8),
        );
      }
    },
  );
  test(
    'plan cut follows the actual riser height and handles cuts outside the stair',
    () {
      final geometry = ArchitectStairGeometry.of(stair());
      final cut = geometry.cut(.8);
      expect(cut.below.contains(const Offset(.3, 0)), isTrue);
      expect(cut.below.contains(const Offset(2, 0)), isFalse);
      expect(cut.above.contains(const Offset(2, 0)), isTrue);
      expect(cut.crossing!.$1.dx, closeTo(1.5, 1e-9));
      expect(geometry.cut(-.1).below.getBounds().isEmpty, isTrue);
      expect(geometry.cut(2).above.getBounds().isEmpty, isTrue);
      expect(geometry.cut(2).crossing, isNull);
    },
  );
  test(
    'finish and nosing change 3D geometry without changing the tidy plan footprint',
    () {
      final a = stair(),
          b = stair(
            design.copyWith(nosingProjection: .06, finishThickness: .03),
          );
      expect(a.plan.nosings, b.plan.nosings);
      expect(a.plan.bounds, b.plan.bounds);
      final finish = ArchitectStairMesh.body(b)
          .where((s) => s.material == StairSolidMaterial.finish)
          .expand((s) => s.triangles)
          .expand((t) => [t.v0, t.v1, t.v2]);
      expect(finish.map((p) => p.x).reduce(math.min), closeTo(-.06, 1e-9));
    },
  );
  test(
    'actual longitudinal section has concrete waist and separate projecting finish',
    () {
      final section = ArchitectStairSection.build(
        ArchitectStairMesh.body(stair()),
        Offset.zero,
        const Offset(1, 0),
      );
      expect(section.isEmpty, isFalse);
      expect(
        section.regions[StairSolidMaterial.concrete]!.contains(
          const Offset(1.35, .60),
        ),
        isTrue,
      );
      expect(
        section.regions[StairSolidMaterial.finish]!.contains(
          const Offset(-.02, .15),
        ),
        isTrue,
      );
      expect(
        section.regions[StairSolidMaterial.concrete]!.contains(
          const Offset(1.35, 1.4),
        ),
        isFalse,
      );
      expect(section.bounds.bottom, closeTo(1.6, 1e-6));
      expect(section.bounds.top, closeTo(-.17, 1e-6));
    },
  );
  test('transverse, oblique and missed sections use the actual plane', () {
    final solids = ArchitectStairMesh.body(stair());
    final transverse = ArchitectStairSection.build(
      solids,
      const Offset(.61, 0),
      const Offset(0, 1),
    );
    expect(transverse.bounds.width, closeTo(1.2, 1e-6));
    expect(transverse.bounds.bottom, closeTo(.48, 1e-6));
    expect(
      ArchitectStairSection.build(
        solids,
        const Offset(.1, 0),
        const Offset(1, .3),
      ).isEmpty,
      isFalse,
    );
    expect(
      ArchitectStairSection.build(
        solids,
        const Offset(0, 20),
        const Offset(1, 0),
      ).isEmpty,
      isTrue,
    );
  });
  test(
    'all shapes and mirrors have finite material meshes and valid sections',
    () {
      for (final shape in StairShape.values) {
        for (final left in [false, true]) {
          final s = stair(design.copyWith(shape: shape, turnLeft: left));
          final solids = ArchitectStairMesh.body(s);
          expect(
            solids.where((s) => s.material == StairSolidMaterial.concrete),
            isNotEmpty,
          );
          expect(
            solids.where((s) => s.material == StairSolidMaterial.finish),
            isNotEmpty,
          );
          for (final solid in solids) {
            expect(
              solid.triangles.every((t) => t.area > 1e-12),
              isTrue,
              reason:
                  '${shape.name}, left=$left, ${solid.material}, ${solid.triangles.where((t) => t.area <= 1e-12).map((t) => [t.v0, t.v1, t.v2]).toList()}',
            );
            expect(
              solid.triangles
                  .expand((t) => [t.v0, t.v1, t.v2])
                  .every((p) => p.x.isFinite && p.y.isFinite && p.z.isFinite),
              isTrue,
            );
          }
          final section = ArchitectStairSection.build(
            solids,
            Offset.zero,
            const Offset(1, 0),
          );
          expect(section.isEmpty, isFalse);
        }
      }
    },
  );
  test(
    'Bulgarian plan notation is localized, concise, and on two lines',
    () async {
      final bg = await AppLocalizations.delegate.load(const Locale('bg'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(stairPlanLabel(bg, stair()), '10 ст. 30/16 см\nH=1,60 м');
      expect(stairPlanLabel(en, stair()), '10R 30/16 cm\nH=1.60 m');
    },
  );
  test(
    'caption remains visible near viewport edges without enlarging the stair pick area',
    () {
      final p = project(), s = p.activeStorey.stairs.single;
      final point = s.plan.bounds.bottomCenter + const Offset(0, .4);
      final visible = ArchitectSceneGeometry.visible(
        p,
        Rect.fromCenter(center: point, width: .1, height: .1),
        1000,
      );
      expect(visible.activeStorey.stairs, hasLength(1));
      expect(ArchitectSelection.bounds(p, s.id)!.contains(point), isFalse);
    },
  );
  test('zero finish retains a complete concrete body without phantom trim', () {
    final solids = ArchitectStairMesh.body(
      stair(design.copyWith(finishThickness: 0, nosingProjection: 0)),
    );
    expect(
      solids.every((s) => s.material == StairSolidMaterial.concrete),
      isTrue,
    );
    final section = ArchitectStairSection.build(
      solids,
      Offset.zero,
      const Offset(1, 0),
    );
    expect(section.bounds.bottom, closeTo(1.6, 1e-6));
  });
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'phone $locale controls persist visibility and open an interactive section',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ArchitectStair? saved;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ArchitectStairPropertiesDialog(
                      project: project(),
                      stair: stair(),
                      onApply: (s) {
                        saved = s;
                        return true;
                      },
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('stair-open-section')),
        );
        await tester.tap(find.byKey(const ValueKey('stair-open-section')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('stair-section-detail')),
          findsOneWidget,
        );
        final rect = tester.getRect(
          find.byKey(const ValueKey('stair-section-plan')),
        );
        await tester.tapAt(rect.center - const Offset(20, 0));
        await tester.pumpAndSettle();
        await tester.tapAt(rect.center + const Offset(20, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('stair-section-reset')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('stair-show-railing')),
        );
        await tester.tap(find.byKey(const ValueKey('stair-show-railing')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('stair-show-label')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('stair-save')));
        await tester.pumpAndSettle();
        expect(saved!.design!.showRailing, isFalse);
        expect(saved!.design!.showLabel, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
