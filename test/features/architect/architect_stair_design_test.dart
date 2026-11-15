import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_scene_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_rules.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_properties_dialog.dart';

ArchitectStair stair({
  ArchitectStairDesign design = const ArchitectStairDesign(),
  double width = 1.2,
  Offset start = Offset.zero,
  Offset end = const Offset(1, 0),
}) => ArchitectStair(
  id: 'st',
  startPoint: start,
  endPoint: end,
  width: width,
  design: design,
);

ArchitectProject project({List<ArchitectStair> stairs = const []}) =>
    ArchitectProject(
      id: 'p',
      name: 'Test',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      storeys: [
        ArchitectStorey(id: 's', name: '0.00', stairs: stairs),
        const ArchitectStorey(id: 'upper', name: '+3.00', elevation: 3),
      ],
    );

List<StairCheck> errors(ArchitectStair s) => ArchitectStairRules.check(
  s,
).where((c) => c.state == StairCheckState.error).toList();

void main() {
  testWidgets('two taps place the real preview in the chosen direction', (
    tester,
  ) async {
    final model = workspace.commands();
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await tool_ui.choose(tester, Icons.stairs_rounded);
    await tester.pumpAndSettle();
    await tester.tapAt(workspace.screen(tester, Offset.zero));
    await tester.pumpAndSettle();
    expect(workspace.overlay(tester).stairPreview, isNotNull);
    expect(
      workspace.overlay(tester).stairPreview!.placementCorner.distance,
      lessThan(1e-6),
    );
    await tester.tapAt(workspace.screen(tester, const Offset(0, 2)));
    await tester.pumpAndSettle();
    final placed = model.project.activeStorey.stairs.single;
    expect(placed.design!.shape, StairShape.halfTurn);
    expect(placed.unitVector.dx, closeTo(0, 1e-6));
    expect(placed.unitVector.dy, closeTo(1, 1e-6));
    expect(placed.stepCount, 17);
    expect(placed.placementCorner.distance, lessThan(1e-6));
    final first = placed.plan.nosings.first;
    expect(math.min(first.$1.distance, first.$2.distance), lessThan(1e-6));
    model.undo();
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.stairs, isEmpty);
    expect(tester.takeException(), isNull);
  });
  test('3D risers reach the exact upper finished-floor elevation', () {
    for (final shape in StairShape.values) {
      final s = stair(
        design: ArchitectStairDesign(shape: shape, rise: 3, showRailing: false),
      );
      final p = project(stairs: [s]).copyWith(
        storeys: [
          project(stairs: [s]).activeStorey,
        ],
      );
      final mesh = Architect3dBuilder.buildProjectMesh(p);
      final vertices = mesh.triangles.expand((t) => [t.v0, t.v1, t.v2]);
      expect(vertices.map((v) => v.z).reduce(math.max), closeTo(3, 1e-9));
      expect(
        vertices.every((v) => v.x.isFinite && v.y.isFinite && v.z.isFinite),
        isTrue,
      );
    }
  });
  test('element properties allow adjusted widths while rejecting invalid values', () {
    final p = project(stairs: [stair()]);
    final narrow = const SetArchitectElementProperties(
      storeyId: 's',
      elementIds: {'st'},
      values: {'width': .7},
    ).apply(p);
    expect(narrow.activeStorey.stairs.single.width, .7);
    expect(
      () => const SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'st'},
        values: {'width': 0},
      ).apply(p),
      throwsArgumentError,
    );
    final next = const SetArchitectElementProperties(
      storeyId: 's',
      elementIds: {'st'},
      values: {'stepCount': 20},
    ).apply(p);
    expect(next.activeStorey.stairs.single.stepCount, 20);
  });

  test('automatic counts close the exact finished-floor height', () {
    for (final height in [1.2, 2.8, 3.0, 3.3, 4.9]) {
      final d = ArchitectStairDesign(rise: height, shape: StairShape.straight);
      expect(d.risers * d.riser, closeTo(height, 1e-10));
      expect(d.riser, lessThanOrEqualTo(.17 + 1e-9));
      expect(d.flightRisers.reduce((a, b) => a + b), d.risers);
      expect(d.flightRisers.reduce(math.max) * d.riser, lessThanOrEqualTo(2.5));
      expect(errors(stair(design: d)), isEmpty);
    }
  });
  test(
    'straight stair inserts enough landings using integer flight counts',
    () {
      const d = ArchitectStairDesign(shape: StairShape.straight, rise: 4.9);
      expect(d.risers, 30); // 29 would make one flight 2.534 m high.
      expect(d.flightCount, 2);
      expect(d.flightRisers.reduce(math.max) * d.riser, lessThanOrEqualTo(2.5));
      expect(errors(stair(design: d)), isEmpty);
      expect(stair(design: d).plan.footprints.length, 3);
    },
  );
  test(
    'automatic U stair balances the upper limit without unnecessary landings',
    () {
      const d = ArchitectStairDesign(rise: 4.9);
      expect(d.risers, 30);
      expect(errors(stair(design: d)), isEmpty);
      expect(
        ArchitectStairRules.check(
          stair(design: d.copyWith(manualRisers: 29)),
        ).any(
          (c) =>
              c.kind == StairCheckKind.flightRise &&
              c.state == StairCheckState.advice,
        ),
        isTrue,
      );
    },
  );
  test(
    'spiral flags tall single-flight rise as informative ratio advice',
    () {
      expect(
        ArchitectStairRules.check(
          stair(design: const ArchitectStairDesign(shape: StairShape.spiral)),
        ).any(
          (c) =>
              c.kind == StairCheckKind.flightRise &&
              c.state == StairCheckState.advice,
        ),
        isTrue,
      );
    },
  );
  test(
    'removing an explicitly connected floor preserves geometry as a draft',
    () {
      final commands = ArchitectCommandController(project());
      addTearDown(commands.dispose);
      commands.execute(
        PutArchitectStair(storeyId: 's', stair: stair(), create: true),
      );
      final original = commands.project.activeStorey.stairs.single;
      commands.commit(
        commands.project.copyWith(storeys: [commands.project.activeStorey]),
      );
      expect(
        commands.project.activeStorey.stairs.single.design!.isDraft,
        isTrue,
      );
      expect(
        commands.project.activeStorey.stairs.single.design!.rise,
        original.design!.rise,
      );
      commands.undo();
      expect(
        commands.project.activeStorey.stairs.single.toJson(),
        original.toJson(),
      );
    },
  );
  test(
    'N risers have N-1 goings in each flight, without counting landings',
    () {
      const d = ArchitectStairDesign(
        shape: StairShape.straight,
        rise: 1.6,
        manualRisers: 10,
        manualGoing: .30,
      );
      final plan = stair(design: d).plan;
      expect(plan.bounds.width, closeTo(2.7, 1e-9));
      expect(plan.nosings.length, 10);
    },
  );
  test('spiral inner goings are reported informatively without regulatory errors', () {
    const d = ArchitectStairDesign(
      shape: StairShape.spiral,
      rise: 2.88,
      manualRisers: 18,
      innerRadius: .05,
    );
    final checks = ArchitectStairRules.check(stair(design: d));
    expect(errors(stair(design: d)), isEmpty);
    expect(
      checks.singleWhere((c) => c.kind == StairCheckKind.innerGoing30).state,
      StairCheckState.advice,
    );
    expect(
      checks.singleWhere((c) => c.kind == StairCheckKind.innerGoing).state,
      StairCheckState.advice,
    );
  });
  test('spiral chord is conservative and accounts for inner clear radius', () {
    const d = ArchitectStairDesign(shape: StairShape.spiral, manualRisers: 18);
    expect(d.goingAt30, closeTo(2 * .9 * math.sin(d.anglePerGoing / 2), 1e-12));
    expect(d.goingAt30, lessThan(.9 * d.anglePerGoing));
  });
  test('checks report informative comfort, riser, going and slope ratios', () {
    final checks = ArchitectStairRules.check(
      stair(design: const ArchitectStairDesign(manualGoing: .35)),
    );
    expect(
      checks.singleWhere((c) => c.kind == StairCheckKind.comfort).state,
      StairCheckState.advice,
    );
    expect(
      checks.singleWhere((c) => c.kind == StairCheckKind.comfort).article,
      '2h + b',
    );
    expect(
      checks.singleWhere((c) => c.kind == StairCheckKind.riser).state,
      StairCheckState.pass,
    );
    expect(
      checks.singleWhere((c) => c.kind == StairCheckKind.going).state,
      StairCheckState.pass,
    );
    expect(
      checks.singleWhere((c) => c.kind == StairCheckKind.slope).state,
      StairCheckState.pass,
    );
    expect(
      checks.every((c) => c.state != StairCheckState.error),
      isTrue,
    );
  });
  test('legacy JSON keeps its original schematic dimensions and risers', () {
    final old = ArchitectStair(
      id: 'old',
      startPoint: Offset.zero,
      endPoint: const Offset(4, 0),
      stepCount: 16,
    );
    final loaded = ArchitectStair.fromJson(old.toJson());
    expect(loaded.design, isNull);
    expect(loaded.stepCount, 16);
    expect(loaded.plan.bounds.width, 4);
    expect(loaded.toJson().containsKey('design'), isFalse);
  });
  test('all design settings persist through the project file', () {
    const d = ArchitectStairDesign(
      shape: StairShape.spiral,
      turnLeft: true,
      upperStoreyId: 'upper',
      manualRisers: 20,
      manualGoing: .31,
      evacuation: StairEvacuation.over50,
      innerRadius: .9,
      isDraft: true,
    );
    final original = project(stairs: [stair(design: d)]);
    final restored = ArchitectProject.fromJson(original.toJson());
    expect(
      restored.activeStorey.stairs.single.toJson(),
      original.activeStorey.stairs.single.toJson(),
    );
  });
  test('L and U picking follows both flights and excludes empty space', () {
    for (final shape in [StairShape.quarterTurn, StairShape.halfTurn]) {
      final s = stair(design: ArchitectStairDesign(shape: shape));
      final p = project(stairs: [s]);
      final plan = s.plan;
      final upperFlight = plan.footprints.last;
      final point =
          upperFlight.reduce((a, b) => a + b) / upperFlight.length.toDouble();
      expect(
        ArchitectElementTool().hitTestElements(p.activeStorey, point, 100),
        contains('st'),
      );
      expect(ArchitectSelection.outline(p, 'st').contains(point), isTrue);
      expect(ArchitectSelection.bounds(p, 'st')!.contains(point), isTrue);
      expect(plan.contains(const Offset(-1, -1), .01), isFalse);
    }
  });
  test('spiral well remains empty for drawing and picking', () {
    final s = stair(
      design: const ArchitectStairDesign(shape: StairShape.spiral),
    );
    final centre = Offset(0, s.design!.innerRadius + s.width / 2);
    expect(s.plan.path.contains(centre), isFalse);
    expect(s.plan.contains(centre, .01), isFalse);
    expect(s.plan.contains(s.startPoint + const Offset(.1, 0), .01), isTrue);
  });
  test('rotating and mirroring keep geometry and metrics consistent', () {
    final a = stair();
    final b = stair(start: const Offset(12, -8), end: const Offset(12, -7));
    for (var i = 0; i < a.plan.nosings.length; i++) {
      final p = a.plan.nosings[i].$1;
      expect(
        (b.plan.nosings[i].$1 - Offset(12 - p.dy, -8 + p.dx)).distance,
        lessThan(1e-9),
      );
    }
    final left = stair(design: const ArchitectStairDesign(turnLeft: true));
    expect(left.plan.bounds.height, closeTo(a.plan.bounds.height, 1e-9));
    expect(left.plan.bounds.bottom, closeTo(-a.plan.bounds.top, 1e-9));
  });
  test('viewport includes a return flight far from the direction handle', () {
    final s = stair();
    final upper = s.plan.footprints.last;
    final point = upper.reduce((a, b) => a + b) / upper.length.toDouble();
    final visible = ArchitectSceneGeometry.visible(
      project(stairs: [s]),
      Rect.fromCenter(center: point, width: .1, height: .1),
      1000,
    );
    expect(visible.activeStorey.stairs, hasLength(1));
  });
  test('create, move and undo preserve parametric data', () {
    final commands = ArchitectCommandController(project());
    addTearDown(commands.dispose);
    commands.execute(
      PutArchitectStair(storeyId: 's', stair: stair(), create: true),
    );
    final original = commands.project.activeStorey.stairs.single;
    expect(original.design!.rise, 3);
    commands.execute(
      const MoveArchitectElement(
        storeyId: 's',
        elementId: 'st',
        delta: Offset(2, 3),
      ),
    );
    expect(
      commands.project.activeStorey.stairs.single.startPoint,
      const Offset(2, 3),
    );
    expect(
      commands.project.activeStorey.stairs.single.design!.toJson(),
      original.design!.toJson(),
    );
    commands.undo();
    expect(
      commands.project.activeStorey.stairs.single.toJson(),
      original.toJson(),
    );
    commands.undo();
    expect(commands.project.activeStorey.stairs, isEmpty);
    commands.redo();
    expect(
      commands.project.activeStorey.stairs.single.toJson(),
      original.toJson(),
    );
  });
  test(
    'floor elevation edits recalculate the connected rise in one undo step',
    () {
      final commands = ArchitectCommandController(project());
      addTearDown(commands.dispose);
      commands.execute(
        PutArchitectStair(storeyId: 's', stair: stair(), create: true),
      );
      commands.commit(
        commands.project.copyWith(
          storeys: [
            commands.project.activeStorey,
            const ArchitectStorey(id: 'upper', name: '+3.3', elevation: 3.3),
          ],
        ),
      );
      expect(commands.project.activeStorey.stairs.single.design!.rise, 3.3);
      commands.undo();
      expect(commands.project.activeStorey.stairs.single.design!.rise, 3);
    },
  );
  test('custom dimensions save cleanly and invalid storey rejection is atomic', () {
    final commands = ArchitectCommandController(project());
    addTearDown(commands.dispose);
    commands.execute(
      PutArchitectStair(storeyId: 's', stair: stair(width: .7), create: true),
    );
    expect(commands.project.activeStorey.stairs.single.width, .7);
    expect(commands.project.activeStorey.stairs.single.design!.isDraft, isFalse);
    expect(
      () => commands.execute(
        PutArchitectStair(
          storeyId: 's',
          stair: stair(
            design: const ArchitectStairDesign(upperStoreyId: 'missing'),
          ),
          create: true,
        ),
      ),
      throwsArgumentError,
    );
    expect(commands.project.activeStorey.stairs, hasLength(1));
  });
  testWidgets(
    'stair properties fit a phone, hide BG regulations and save narrow width cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ArchitectStair? saved;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => ArchitectStairPropertiesDialog(
                      project: project(),
                      stair: stair(width: .7),
                      onApply: (s) {
                        saved = s;
                        return true;
                      },
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('България · BG-2025.1'), findsNothing);
      expect(find.text('Нормативна база'), findsNothing);
      expect(find.text('Нормативни източници'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('stair-save')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('stair-save')));
      await tester.pumpAndSettle();
      expect(saved!.width, .7);
      expect(saved!.design!.isDraft, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
