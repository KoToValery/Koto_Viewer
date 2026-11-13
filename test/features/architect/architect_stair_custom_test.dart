import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/adapters/architect_element_adapters.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_section.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_draft_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_headroom.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_layout_resolver.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_landing_path.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_railings.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_rules.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_storey_copy_service.dart';
import 'package:kotoview/src/features/architect/models/architect_storey_copy_types.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_perimeter_overlay.dart';
import 'architect_stair_design_test.dart' as fixture;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tools;

ArchitectStair customStair() => fixture.stair(
  design: ArchitectStairDesign(
    shape: StairShape.straight,
    code: StairCode.geometryOnly,
    followStoreys: false,
    rise: 3.06,
    manualGoing: .3,
    showRailing: false,
    layout: ArchitectStairLayout(
      flights: const [
        ArchitectStairFlightSpec(
          id: 'f1',
          origin: Offset.zero,
          axis: Offset(1, 0),
          width: 1,
          risers: 5,
        ),
        ArchitectStairFlightSpec(
          id: 'f2',
          origin: Offset(2.4, 0),
          axis: Offset(1, 0),
          width: 1.2,
          risers: 6,
        ),
        ArchitectStairFlightSpec(
          id: 'f3',
          origin: Offset(5.2, 0),
          axis: Offset(1, 0),
          width: .9,
          risers: 7,
        ),
      ],
      landings: [
        ArchitectStairLandingSpec(
          id: 'l1',
          polygon: const [
            Offset(1.2, -.5),
            Offset(2.4, -.6),
            Offset(2.4, .6),
            Offset(1.2, .5),
          ],
        ),
        ArchitectStairLandingSpec(
          id: 'l2',
          polygon: const [
            Offset(3.9, -.6),
            Offset(5.2, -.45),
            Offset(5.2, .45),
            Offset(3.9, .6),
          ],
        ),
      ],
      cell: const [
        Offset(-.2, -1),
        Offset(7.3, -.8),
        Offset(7.5, 1.3),
        Offset(-.2, 1.1),
      ],
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a custom layout is authoritative over every retained preset shape', () {
    final source = customStair();
    for (final shape in StairShape.values) {
      final stair = source.copyWith(
        design: source.design!.copyWith(shape: shape),
      );
      expect(stair.design!.isSpiral, isFalse);
      expect(stair.design!.hasWinders, isFalse);
      expect(stair.plan.nosings, source.plan.nosings);
      expect(
        ArchitectStairRules.check(
          stair,
        ).where((c) => c.state == StairCheckState.error),
        isEmpty,
      );
    }
  });
  test(
    'landing walking lines stay inside concave contours and reject narrow internal necks',
    () {
      const u = [
        Offset(0, 0),
        Offset(4, 0),
        Offset(4, 4),
        Offset(3, 4),
        Offset(3, 1),
        Offset(1, 1),
        Offset(1, 4),
        Offset(0, 4),
      ];
      final route = ArchitectStairLandingPath.route(
        u,
        const Offset(.5, 4),
        const Offset(3.5, 4),
        width: .5,
        incoming: const Offset(0, -1),
        outgoing: const Offset(0, 1),
      );
      expect(route, isNotEmpty);
      for (var i = 1; i < route.length; i++) {
        for (final t in [.25, .5, .75]) {
          expect(
            ArchitectStairLandingPath.contains(
              u,
              route[i - 1] + (route[i] - route[i - 1]) * t,
            ),
            isTrue,
          );
        }
      }
      const neck = [
        Offset(0, -.6),
        Offset(1, -.6),
        Offset(1, -.15),
        Offset(3, -.15),
        Offset(3, -.6),
        Offset(4, -.6),
        Offset(4, .6),
        Offset(3, .6),
        Offset(3, .15),
        Offset(1, .15),
        Offset(1, .6),
        Offset(0, .6),
      ];
      final d = customStair().design!.copyWith(
        layout: ArchitectStairLayout(
          flights: const [
            ArchitectStairFlightSpec(
              id: 'in',
              origin: Offset(-1.2, 0),
              axis: Offset(1, 0),
              width: 1,
              risers: 5,
            ),
            ArchitectStairFlightSpec(
              id: 'out',
              origin: Offset(4, 0),
              axis: Offset(1, 0),
              width: 1,
              risers: 5,
            ),
          ],
          landings: [ArchitectStairLandingSpec(id: 'neck', polygon: neck)],
        ),
      );
      expect(
        ArchitectStairLayoutResolver.check(
          d,
        ).any((i) => i.problem == StairLayoutProblem.clearance),
        isTrue,
      );
    },
  );
  test(
    'open-riser upper flights have no imaginary waist across their clear centre',
    () {
      for (final construction in [
        StairConstruction.steel,
        StairConstruction.timber,
      ]) {
        final stair = fixture.stair(
          design: ArchitectStairDesign(
            shape: StairShape.straight,
            code: StairCode.geometryOnly,
            rise: 6.3,
            followStoreys: false,
            manualGoing: .3,
            construction: construction,
            layout: ArchitectStairLayout(
              flights: const [
                ArchitectStairFlightSpec(
                  id: 'lower',
                  origin: Offset.zero,
                  axis: Offset(1, 0),
                  width: .5,
                  risers: 9,
                ),
                ArchitectStairFlightSpec(
                  id: 'return',
                  origin: Offset(2.4, 1.2),
                  axis: Offset(-1, 0),
                  width: 1.2,
                  risers: 9,
                ),
                ArchitectStairFlightSpec(
                  id: 'upper',
                  origin: Offset.zero,
                  axis: Offset(1, 0),
                  width: 1.2,
                  risers: 9,
                ),
              ],
              landings: [
                ArchitectStairLandingSpec(
                  id: 'right',
                  polygon: const [
                    Offset(2.4, -.25),
                    Offset(3.6, -.25),
                    Offset(3.6, 1.8),
                    Offset(2.4, 1.8),
                  ],
                ),
                ArchitectStairLandingSpec(
                  id: 'left',
                  polygon: const [
                    Offset(0, -.6),
                    Offset(0, 1.8),
                    Offset(-1.2, 1.8),
                    Offset(-1.2, -.6),
                  ],
                ),
              ],
            ),
          ),
        );
        final project = fixture.project(stairs: [stair]);
        expect(ArchitectStairLayoutResolver.check(stair.design!), isEmpty);
        expect(
          ArchitectStairHeadroom.minimum(project, project.activeStorey, stair),
          closeTo(4.16, 1e-6),
        );
      }
    },
  );
  test(
    'duplicate, rotate and storey copy preserve the complete custom layout',
    () {
      final stair = customStair();
      final tool = ArchitectElementTool();
      addTearDown(tool.dispose);
      final floor = fixture.project(stairs: [stair]).activeStorey;
      final copy = tool.duplicateElementById(
        floor,
        stair.id,
        offset: const Offset(2, 1),
      );
      expect(copy.$1.stairs, hasLength(2));
      expect(
        copy.$1.stairs.last.design!.layout!.toJson(),
        stair.design!.layout!.toJson(),
      );
      final rotated = tool.rotateElementById(floor, stair.id).stairs.single;
      expect(
        rotated.plan.bounds.width,
        closeTo(stair.plan.bounds.height, 1e-8),
      );
      final linked = stair.copyWith(
        design: stair.design!.copyWith(
          followStoreys: true,
          upperStoreyId: 'upper',
        ),
      );
      final base = fixture.project(stairs: [linked]);
      final project = base.copyWith(
        storeys: [
          ...base.storeys,
          const ArchitectStorey(id: 'third', name: '3', elevation: 6.3),
        ],
      );
      final result = ArchitectStoreyCopyService.copyElements(
        project,
        const StoreyCopyOptions(
          sourceStoreyId: 's',
          targetStoreyIds: {'upper'},
          elementTypes: {ArchitectStoreyElementType.stairs},
        ),
      );
      final resolved = ArchitectStairRules.resolve(result.$1);
      final copied = resolved.storeys
          .firstWhere((s) => s.id == 'upper')
          .stairs
          .single;
      expect(copied.design!.upperStoreyId, 'third');
      expect(copied.design!.rise, closeTo(3.3, 1e-8));
      expect(copied.design!.layout!.toJson(), linked.design!.layout!.toJson());
    },
  );
  test(
    'three unequal flights share rise and going and survive project JSON',
    () {
      final s = customStair(), d = s.design!;
      d.validate();
      expect(d.flightRisers, [5, 6, 7]);
      expect(d.risers, 18);
      expect(d.riser, closeTo(.17, 1e-9));
      expect(ArchitectStairLayoutResolver.check(d), isEmpty);
      final g = ArchitectStairGeometry.of(s);
      expect(g.flights.map((f) => f.width), [1, 1.2, .9]);
      expect(g.landings.map((l) => l.elevation), [
        closeTo(.85, 1e-9),
        closeTo(1.87, 1e-9),
      ]);
      expect(g.flights.last.top, closeTo(3.06, 1e-9));
      expect(s.plan.nosings, hasLength(18));
      final p = fixture.project(stairs: [s]);
      final restored = ArchitectProject.fromJson(
        p.toJson(),
      ).activeStorey.stairs.single;
      expect(restored.toJson(), s.toJson());
      expect(restored.plan.nosings, s.plan.nosings);
    },
  );
  test('preset conversion preserves exact footprints and handedness', () {
    for (final shape in [
      StairShape.straight,
      StairShape.quarterTurn,
      StairShape.halfTurn,
    ]) {
      for (final left in [false, true]) {
        final s = fixture.stair(
          design: ArchitectStairDesign(shape: shape, turnLeft: left),
        );
        final layout = ArchitectStairLayoutResolver.fromStair(s);
        final converted = s.copyWith(
          design: s.design!.copyWith(
            layout: layout,
            manualGoing: s.design!.going,
          ),
        );
        expect(converted.plan.nosings, s.plan.nosings);
        expect(ArchitectStairLayoutResolver.check(converted.design!), isEmpty);
      }
    }
  });
  test('local layout follows translation, rotation, reflection and undo', () {
    final s = customStair();
    final translated = const ArchitectStairEditingAdapter().translate(
      s,
      const Offset(4, -3),
    );
    expect(
      translated.plan.nosings.first.$1,
      s.plan.nosings.first.$1 + const Offset(4, -3),
    );
    final rotated = s.copyWith(endPoint: const Offset(0, 1));
    expect(
      rotated.plan.nosings.last.$1.dx,
      closeTo(-s.plan.nosings.last.$1.dy, 1e-8),
    );
    final floor = fixture.project(stairs: [s]).activeStorey;
    final tool = ArchitectElementTool();
    addTearDown(tool.dispose);
    final mirrored = tool.mirrorElementById(
      floor,
      s.id,
      origin: Offset.zero,
      direction: const Offset(1, 0),
    );
    final m = mirrored.$1.stairs.single;
    expect(
      m.plan.nosings.last.$1.dy,
      closeTo(-s.plan.nosings.last.$1.dy, 1e-8),
    );
    final commands = ArchitectCommandController(fixture.project());
    addTearDown(commands.dispose);
    commands.execute(PutArchitectStair(storeyId: 's', stair: s, create: true));
    commands.undo();
    expect(commands.project.activeStorey.stairs, isEmpty);
    commands.redo();
    expect(commands.project.activeStorey.stairs.single.toJson(), s.toJson());
  });
  test(
    'concave cell rejects an edge crossing a notch, not just outside vertices',
    () {
      final s = customStair(), d = s.design!;
      final l = d.layout!.copyWith(
        cell: const [
          Offset(-1, -1),
          Offset(8, -1),
          Offset(8, 1),
          Offset(3, 1),
          Offset(3, -.1),
          Offset(2.8, -.1),
          Offset(2.8, 1),
          Offset(-1, 1),
        ],
      );
      expect(
        ArchitectStairLayoutResolver.check(
          d.copyWith(layout: l),
        ).any((e) => e.problem == StairLayoutProblem.cell),
        isTrue,
      );
    },
  );
  test(
    'self crossing contours and unsupported versions fail without preset fallback',
    () {
      final d = customStair().design!, l = d.layout!;
      expect(
        () => d
            .copyWith(
              layout: l.copyWith(
                cell: const [
                  Offset.zero,
                  Offset(2, 2),
                  Offset(0, 2),
                  Offset(2, 0),
                ],
              ),
            )
            .validate(),
        throwsArgumentError,
      );
      expect(
        () => ArchitectStairLayout.fromJson({...l.toJson(), 'version': 50}),
        throwsArgumentError,
      );
    },
  );
  test('fixed incompatible dimensions remain unchanged after failed fit', () {
    final d = customStair().design!, l = d.layout!;
    final locked = l.copyWith(
      goingLocked: true,
      flights: [
        l.flights.first.copyWith(fixedRun: 1.25, countLocked: true),
        ...l.flights.skip(1),
      ],
    );
    final next = d.copyWith(layout: locked);
    final before = next.toJson();
    expect(ArchitectStairLayoutResolver.fit(next), isNull);
    expect(next.toJson(), before);
    expect(
      ArchitectStairLayoutResolver.check(next).first.suggestedRun,
      closeTo(1.2, 1e-9),
    );
  });
  test(
    'fit proposes a common going and balances an explicit total without changing locked counts',
    () {
      final original = customStair().design!;
      final only = original.copyWith(
        layout: ArchitectStairLayout(
          flights: [
            original.layout!.flights.first.copyWith(
              fixedRun: 1.25,
              countLocked: true,
            ),
          ],
        ),
      );
      final fit = ArchitectStairLayoutResolver.fit(only)!;
      expect(fit.going, closeTo(.3125, 1e-9));
      expect(only.going, .3);
      final l = original.layout!.copyWith(
        cell: [],
        flights: [
          original.layout!.flights.first.copyWith(countLocked: true),
          ...original.layout!.flights.skip(1),
        ],
      );
      final balanced = ArchitectStairLayoutResolver.fit(
        original.copyWith(layout: l, manualRisers: 20),
      )!;
      expect(balanced.risers, 20);
      expect(balanced.layout!.flights.first.risers, 5);
      expect(ArchitectStairLayoutResolver.check(balanced), isEmpty);
    },
  );
  test(
    'oblique flights connect to concave landings with either polygon winding',
    () {
      const polygon = [
        Offset(1.2, -.5),
        Offset(3.1, -.5),
        Offset(3.1, 0),
        Offset(2.6, .5),
        Offset(2.1, .5),
        Offset(2.1, .8),
        Offset(1.8, .8),
        Offset(1.8, .5),
        Offset(1.2, .5),
      ];
      for (final p in [polygon, polygon.reversed.toList()]) {
        final s = customStair();
        final d = s.design!.copyWith(
          layout: ArchitectStairLayout(
            flights: [
              s.design!.layout!.flights.first,
              ArchitectStairFlightSpec(
                id: 'oblique',
                origin: const Offset(2.85, .25),
                axis: Offset(1 / math.sqrt(2), 1 / math.sqrt(2)),
                width: 1 / math.sqrt(2),
                risers: 6,
              ),
            ],
            landings: [ArchitectStairLandingSpec(id: 'concave', polygon: p)],
          ),
        );
        final stair = s.copyWith(design: d);
        expect(ArchitectStairLayoutResolver.check(d), isEmpty);
        expect(ArchitectStairMesh.body(stair), isNotEmpty);
        expect(
          ArchitectStairSection.build(
            ArchitectStairMesh.body(stair),
            const Offset(1.9, 0),
            const Offset(0, 1),
          ).isEmpty,
          isFalse,
        );
      }
    },
  );
  test(
    'placement normalization preserves rotated geometry and linked levels update all flights',
    () {
      final source = customStair();
      final rotated = source.copyWith(
        startPoint: const Offset(2, 4),
        endPoint: const Offset(2, 5),
      );
      final normalized = ArchitectStairLayoutResolver.normalizePlacement(
        rotated,
      );
      for (var i = 0; i < rotated.plan.nosings.length; i++) {
        expect(
          (normalized.plan.nosings[i].$1 - rotated.plan.nosings[i].$1).distance,
          lessThan(1e-8),
        );
      }
      final linked = source.copyWith(
        design: source.design!.copyWith(
          followStoreys: true,
          upperStoreyId: 'upper',
          startOffset: .2,
        ),
      );
      final p = fixture.project(stairs: [linked]);
      final resolved = ArchitectStairRules.resolve(p);
      final s = resolved.activeStorey.stairs.single;
      expect(s.design!.rise, closeTo(2.8, 1e-9));
      expect(
        ArchitectStairGeometry.of(s).flights.last.top + .2,
        closeTo(3, 1e-9),
      );
    },
  );
  test(
    'manual slab openings and narrow side obstructions affect full tread clearance',
    () {
      final s = customStair();
      final p = fixture.project(stairs: [s]);
      const slab = ArchitectSlab(
        id: 'slab',
        polygon: [Offset(-1, -1), Offset(8, -1), Offset(8, 1), Offset(-1, 1)],
        thickness: .2,
        coreTopOffset: 3.06,
      );
      final floor = p.activeStorey.copyWith(slabs: [slab]);
      final solid = p.updateActiveStorey(floor);
      expect(ArchitectStairHeadroom.minimum(solid, floor, s), 0);
      final opened = floor.copyWith(
        openings: const [
          ArchitectOpening(
            id: 'opening',
            boundary: [
              Offset(-.5, -.8),
              Offset(7.5, -.8),
              Offset(7.5, .8),
              Offset(-.5, .8),
            ],
          ),
        ],
      );
      expect(
        ArchitectStairHeadroom.minimum(p.updateActiveStorey(opened), opened, s),
        double.infinity,
      );
      final strip = floor.copyWith(
        slabs: [
          slab.copyWith(
            polygon: const [
              Offset(6.8, .44),
              Offset(7, .44),
              Offset(7, .45),
              Offset(6.8, .45),
            ],
          ),
        ],
      );
      expect(
        ArchitectStairHeadroom.minimum(p.updateActiveStorey(strip), strip, s),
        0,
      );
    },
  );
  test(
    'closed unioned solids produce continuous real sections for every construction',
    () {
      for (final construction in StairConstruction.values) {
        final original = customStair();
        final s = original.copyWith(
          design: original.design!.copyWith(construction: construction),
        );
        final solids = ArchitectStairMesh.body(s);
        expect(solids, isNotEmpty);
        final vertices = solids
            .expand((s) => s.triangles)
            .expand((t) => [t.v0, t.v1, t.v2]);
        expect(
          vertices.every((v) => v.x.isFinite && v.y.isFinite && v.z.isFinite),
          isTrue,
        );
        // Framed stairs have open risers: the separate upper floor supplies
        // the final bearing surface. The concrete waist has a terminal tie.
        expect(
          vertices.map((v) => v.z).reduce(math.max),
          closeTo(
            construction == StairConstruction.concrete ? 3.06 : 2.89,
            1e-8,
          ),
        );
        final section = ArchitectStairSection.build(
          solids,
          Offset.zero,
          const Offset(1, 0),
        );
        expect(section.isEmpty, isFalse);
        if (construction == StairConstruction.concrete) {
          final p = section.regions[StairSolidMaterial.concrete]!;
          expect(p.contains(const Offset(1.5, .80)), isTrue);
          expect(p.contains(const Offset(2.41, .9)), isTrue);
          expect(p.contains(const Offset(4.5, 1.8)), isTrue);
        }
      }
    },
  );
  test('custom railings follow real flight widths and landing levels', () {
    final original = customStair();
    final s = original.copyWith(
      design: original.design!.copyWith(showRailing: true),
    );
    final paths = ArchitectStairRailings.build(
      s,
      storey: fixture.project().activeStorey,
    );
    expect(paths, isNotEmpty);
    final points = paths.expand((p) => p.base).toList();
    expect(points.map((p) => p.z).reduce(math.max), closeTo(3.06, 1e-8));
    expect(
      points.any((p) => (p.y.abs() - .45).abs() < 1e-6 && p.x > 5.2),
      isTrue,
    );
    expect(
      ArchitectStairMesh.railings(s, storey: fixture.project().activeStorey)
          .expand((s) => s.triangles)
          .expand((t) => [t.v0, t.v1, t.v2])
          .every((v) => v.x.isFinite && v.y.isFinite && v.z.isFinite),
      isTrue,
    );
  });
  test(
    'controller draws connected flights, supports local undo and preserves failed edits',
    () {
      final seed = fixture.stair(
        design: const ArchitectStairDesign(
          shape: StairShape.straight,
          code: StairCode.geometryOnly,
          manualGoing: .3,
        ),
      );
      final draft = ArchitectStairDraftController(seed, create: true);
      addTearDown(draft.dispose);
      draft.pick(const Offset(10, 4));
      draft.pick(const Offset(11.2, 4));
      expect(draft.layout.flights.single.risers, 5);
      draft.addLanding();
      draft.beginFlight();
      draft.pick(const Offset(12.4, 4));
      draft.pick(const Offset(13.9, 4));
      expect(draft.layout.flights.map((f) => f.risers), [5, 6]);
      expect(draft.complete, isTrue);
      expect(draft.issues, isEmpty);
      draft.undo();
      expect(draft.complete, isFalse);
      expect(draft.layout.flights, hasLength(1));
      draft.removeLastPart();
      expect(draft.complete, isTrue);
    },
  );
  testWidgets(
    'workspace stages, pans and commits a free stair as one undoable edit',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.stairs_rounded);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stair-tool-freeform')));
      await tester.pumpAndSettle();
      final draft = tester
          .widget<ArchitectStairPerimeterOverlay>(
            find.byType(ArchitectStairPerimeterOverlay),
          )
          .draft;
      draft.replaceDesign(draft.design.copyWith(code: StairCode.geometryOnly));
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, Offset.zero));
      await tester.pump();
      await tester.tapAt(workspace.screen(tester, const Offset(2, 0)));
      await tester.pumpAndSettle();
      expect(draft.preview!.design!.layout!.flights, hasLength(1));
      draft.acceptPart();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.stairs, isEmpty);
      final before = workspace.camera(tester).translation;
      final g = await tester.startGesture(
        workspace.screen(tester, const Offset(-1, 2)),
      );
      await g.moveBy(const Offset(45, 30));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(workspace.camera(tester).translation, isNot(before));
      expect(draft.layout.flights, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('stair-draft-apply')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.stairs.single.design!.layout,
        isNotNull,
      );
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.stairs, isEmpty);
      model.redo();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.stairs, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
