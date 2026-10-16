import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_railings.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_rules.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_section.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_properties_dialog.dart';

const design = ArchitectStairDesign(
  shape: StairShape.straight,
  code: StairCode.geometryOnly,
  rise: 1.6,
  followStoreys: false,
  manualRisers: 10,
  manualGoing: .3,
);
ArchitectStair stair(ArchitectStairDesign d) => ArchitectStair(
  id: 'st',
  startPoint: Offset.zero,
  endPoint: const Offset(1, 0),
  width: 1.2,
  design: d,
);
ArchitectProject project({List<ArchitectStair> stairs = const []}) =>
    ArchitectProject(
      id: 'p',
      name: 'Test',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      storeys: [
        ArchitectStorey(
          id: 's',
          name: 'Level',
          elevation: 5,
          height: 3,
          stairs: stairs,
        ),
        const ArchitectStorey(id: 'u', name: 'Upper', elevation: 8),
      ],
    );

void main() {
  test('start offset is backward compatible, validated and persisted', () {
    expect(
      ArchitectStairDesign.fromJson(
        design.toJson()..remove('startOffset'),
      ).startOffset,
      0,
    );
    for (final offset in [-.3, 0.0, .45]) {
      final p = project(stairs: [stair(design.copyWith(startOffset: offset))]);
      final loaded = ArchitectProject.fromJson(p.toJson());
      expect(loaded.activeStorey.stairs.single.design!.startOffset, offset);
    }
    for (final offset in [double.nan, double.infinity, -101.0, 101.0]) {
      expect(
        () => design.copyWith(startOffset: offset).validate(),
        throwsArgumentError,
      );
    }
  });
  test(
    'automatic rise reaches upper floor from offset start, including fallback',
    () {
      final p = project();
      for (final offset in [-.3, .45]) {
        final d = design.copyWith(followStoreys: true, startOffset: offset);
        final resolved = ArchitectStairRules.resolveDesign(
          p,
          p.activeStorey,
          d,
        );
        expect(5 + offset + resolved.rise, closeTo(8, 1e-8));
        expect(resolved.upperStoreyId, 'u');
        final fallback = p.copyWith(storeys: [p.activeStorey]);
        final single = ArchitectStairRules.resolveDesign(
          fallback,
          fallback.activeStorey,
          d,
        );
        expect(offset + single.rise, closeTo(3, 1e-8));
        expect(single.upperStoreyId, isNull);
      }
    },
  );
  for (final automatic in [false, true]) {
    test(
      'floor edits and undo preserve offset in ${automatic ? 'automatic' : 'manual'} mode',
      () {
        final commands = ArchitectCommandController(project());
        addTearDown(commands.dispose);
        commands.execute(
          PutArchitectStair(
            storeyId: 's',
            create: true,
            stair: stair(
              design.copyWith(followStoreys: automatic, startOffset: .4),
            ),
          ),
        );
        final before = commands.project.activeStorey.stairs.single;
        commands.commit(
          commands.project.copyWith(
            storeys: [
              commands.project.activeStorey.copyWith(elevation: 5.5),
              commands.project.storeys.last.copyWith(elevation: 8.2),
            ],
          ),
        );
        final d = commands.project.activeStorey.stairs.single.design!;
        expect(d.startOffset, .4);
        expect(d.rise, closeTo(automatic ? 2.3 : 1.6, 1e-8));
        commands.undo();
        expect(
          commands.project.activeStorey.stairs.single.toJson(),
          before.toJson(),
        );
        commands.redo();
        expect(
          commands.project.activeStorey.stairs.single.design!.rise,
          d.rise,
        );
      },
    );
  }
  test(
    'start at or above upper floor cannot create inverted geometry or skip the target',
    () {
      for (final withTarget in [false, true]) {
        var p = project();
        if (!withTarget) p = p.copyWith(storeys: [p.activeStorey]);
        final invalid = design.copyWith(
          followStoreys: true,
          startOffset: 3,
          upperStoreyId: withTarget ? 'u' : null,
        );
        final s = stair(invalid);
        expect(
          ArchitectStairRules.linkedRise(p, p.activeStorey, invalid),
          isNull,
        );
        expect(
          () =>
              PutArchitectStair(storeyId: 's', stair: s, create: true).apply(p),
          throwsArgumentError,
        );
        final draft = ArchitectStairRules.resolve(
          p.copyWith(
            storeys: [
              p.activeStorey.copyWith(stairs: [s]),
              ...p.storeys.skip(1),
            ],
          ),
        ).activeStorey.stairs.single.design!;
        expect(draft.isDraft, isTrue);
        expect(draft.rise, 1.6);
      }
    },
  );
  for (final shape in StairShape.values) {
    test(
      '${shape.name} offset moves body, railings, section and horizontal cut together',
      () {
        final original = stair(design.copyWith(shape: shape));
        final p = project();
        final oldBody = ArchitectStairMesh.body(original);
        final oldRails = ArchitectStairRailings.build(
          original,
          storey: p.activeStorey,
        );
        final oldSection = ArchitectStairSection.build(
          oldBody,
          Offset.zero,
          const Offset(1, 0),
        );
        final oldCut = ArchitectStairGeometry.of(original).cut(.8);
        for (final offset in [-.3, .45]) {
          final shifted = stair(original.design!.copyWith(startOffset: offset));
          final newBody = ArchitectStairMesh.body(shifted);
          expect(newBody.length, oldBody.length);
          for (var i = 0; i < oldBody.length; i++) {
            expect(newBody[i].material, oldBody[i].material);
            for (var j = 0; j < oldBody[i].triangles.length; j++) {
              final a = oldBody[i].triangles[j], b = newBody[i].triangles[j];
              final before = [a.v0, a.v1, a.v2], after = [b.v0, b.v1, b.v2];
              for (var k = 0; k < 3; k++) {
                expect(after[k].x, before[k].x);
                expect(after[k].y, before[k].y);
                expect(after[k].z, closeTo(before[k].z + offset, 1e-8));
              }
            }
          }
          final rails = ArchitectStairRailings.build(
            shifted,
            storey: p.activeStorey,
          );
          expect(rails.length, oldRails.length);
          for (var i = 0; i < rails.length; i++) {
            expect(rails[i].base.length, oldRails[i].base.length);
            for (var j = 0; j < rails[i].base.length; j++) {
              expect(
                rails[i].base[j].z,
                closeTo(oldRails[i].base[j].z + offset, 1e-8),
              );
            }
          }
          final section = ArchitectStairSection.build(
            newBody,
            Offset.zero,
            const Offset(1, 0),
          );
          expect(
            section.bounds.top,
            closeTo(oldSection.bounds.top + offset, 1e-5),
          );
          expect(
            section.bounds.bottom,
            closeTo(oldSection.bounds.bottom + offset, 1e-5),
          );
          final cut = ArchitectStairGeometry.of(shifted).cut(.8 + offset);
          expect(cut.crossing, oldCut.crossing);
          expect(cut.below.getBounds(), oldCut.below.getBounds());
          expect(cut.above.getBounds(), oldCut.above.getBounds());
          expect(
            ArchitectStairGeometry.of(
              shifted,
            ).cut(offset - .1).below.computeMetrics(),
            isEmpty,
          );
          expect(
            ArchitectStairGeometry.of(
              shifted,
            ).cut(offset + 1.7).above.computeMetrics(),
            isEmpty,
          );
        }
      },
    );
  }
  test('3D adds owning floor elevation once, above the start offset', () {
    final s = stair(design.copyWith(startOffset: -.3, showRailing: false));
    final mesh = Architect3dBuilder.buildProjectMesh(project(stairs: [s]));
    final highest = mesh.triangles
        .expand((t) => [t.v0.z, t.v1.z, t.v2.z])
        .reduce(math.max);
    expect(highest, closeTo(5 - .3 + 1.6, 1e-8));
  });
  test('smart railing evaluates wall coverage at the shifted height', () {
    final f = project().activeStorey.copyWith(
      walls: [
        const ArchitectWall(
          id: 'w',
          startPoint: Offset(-.2, -.725),
          endPoint: Offset(3, -.725),
          thickness: .25,
          height: 5,
          followStoreyHeight: false,
        ),
      ],
    );
    final touching = ArchitectStairRailings.build(stair(design), storey: f);
    expect(touching.any((p) => p.wallMounted), isTrue);
    final above = ArchitectStairRailings.build(
      stair(design.copyWith(startOffset: 6)),
      storey: f,
    );
    expect(above.every((p) => !p.wallMounted), isTrue);
  });
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'phone $locale selects manual rise and enters a signed start offset',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ArchitectStair? saved;
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
                      project: project(),
                      stair: stair(design.copyWith(followStoreys: true)),
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
        final mode = find.byKey(const ValueKey('stair-height-mode-true'));
        await tester.ensureVisible(mode);
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.stairHeightManual).last);
        await tester.pumpAndSettle();
        Future<void> enter(String field, List<String> keys) async {
          final tile = find.byKey(ValueKey('stair-$field'));
          await tester.ensureVisible(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          for (final key in keys) {
            await tester.tap(
              key == '±'
                  ? find.text('±')
                  : find.byKey(ValueKey('wall-key-$key')),
            );
            await tester.pump();
          }
          await tester.tap(find.byKey(const ValueKey('wall-end')));
          await tester.pumpAndSettle();
        }

        await enter('rise', ['1', '.', '6']);
        await enter('start-offset', ['0', '.', '3', '±']);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('stair-save')));
        await tester.pumpAndSettle();
        expect(saved!.design!.followStoreys, isFalse);
        expect(saved!.design!.rise, 1.6);
        expect(saved!.design!.startOffset, -.3);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
