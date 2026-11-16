import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_slab_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_draft_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_handles.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_headroom.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_layout_resolver.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_railings.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_rules.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_draft_overlay.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_labels.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_properties_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations bg;

  setUpAll(() async {
    bg = await AppLocalizations.delegate.load(const Locale('bg'));
    final font = rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    await (FontLoader('Roboto')..addFont(font)).load();
    await (FontLoader('ArchitectNoto')..addFont(font)).load();
  });

  ArchitectProject wrapStorey(
    ArchitectStorey storey, {
    List<ArchitectStorey>? extra,
  }) => ArchitectProject(
    id: 'p',
    name: 'Test',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    activeStoreyId: storey.id,
    storeys: [storey, ...?extra],
  );

  group('Stair enhancements & bug fixes', () {
    test('roundGoing rounds to 0.1 cm and labels avoid long repeating decimals', () {
      expect(ArchitectStairDesign.roundGoing(.3044444), closeTo(.304, 1e-9));
      expect(ArchitectStairDesign.roundGoing(2.5 / 9), closeTo(.278, 1e-9));
      const stair = ArchitectStair(
        id: 's1',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        width: 1.2,
        design: ArchitectStairDesign(
          shape: StairShape.straight,
          rise: 2.8,
          followStoreys: false,
          manualRisers: 16,
          manualGoing: .3044444,
        ),
      );
      final label = stairPlanLabel(bg, stair);
      expect(label, contains('30,4'));
      expect(label, isNot(contains('30,44')));
    });

    test('applyGoingInverse adjusts risers inversely for presets, winders, and custom layouts', () {
      // Preset straight: ~2.80 m run (10 treads @ 28 cm) -> changing going to 35 cm -> 8 treads (9 risers).
      const straight = ArchitectStairDesign(
        shape: StairShape.straight,
        rise: 2.8,
        followStoreys: false,
        manualRisers: 11,
        manualGoing: .28,
      );
      final updatedStraight = ArchitectStairRules.applyGoingInverse(
        straight,
        .35,
      );
      expect(updatedStraight.going, closeTo(.35, 1e-6));
      expect(updatedStraight.risers, 9);

      // Preset halfTurn: 2 flights -> preserves overall run inversely.
      const halfTurn = ArchitectStairDesign(
        shape: StairShape.halfTurn,
        rise: 3.0,
        followStoreys: false,
        manualRisers: 18,
        manualGoing: .28,
      );
      final updatedHalf = ArchitectStairRules.applyGoingInverse(halfTurn, .32);
      expect(updatedHalf.going, closeTo(.32, 1e-6));
      expect(updatedHalf.risers, 16);

      // Winders: changing going preserves straight run and clamps >= turnCount + 3.
      const winder = ArchitectStairDesign(
        shape: StairShape.quarterTurn,
        winderSteps: true,
        rise: 2.8,
        followStoreys: false,
        manualRisers: 14,
        manualGoing: .28,
      );
      final updatedWinder = ArchitectStairRules.applyGoingInverse(
        winder,
        .35,
        width: 1.0,
      );
      expect(updatedWinder.going, closeTo(.35, 1e-6));
      expect(updatedWinder.risers, lessThan(winder.risers));

      // Custom layout: preserves total run of each flight and keeps landing connected.
      const baseStair = ArchitectStair(
        id: 'q1',
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        width: 1.2,
        design: ArchitectStairDesign(
          shape: StairShape.quarterTurn,
          rise: 3.0,
          followStoreys: false,
          manualRisers: 18,
          manualGoing: .28,
        ),
      );
      final customDesign = baseStair.design!.copyWith(
        shape: StairShape.straight,
        layout: ArchitectStairLayoutResolver.fromStair(baseStair),
      );
      final updatedCustom = ArchitectStairRules.applyGoingInverse(
        customDesign,
        .35,
      );
      expect(updatedCustom.going, closeTo(.35, 1e-6));
      expect(updatedCustom.layout!.goingLocked, isTrue);
      expect(updatedCustom.risers, lessThan(customDesign.risers));
      expect(ArchitectStairLayoutResolver.check(updatedCustom), isEmpty);
    });

    test('halfTurn preset with wellGap 0 generates inner well guardrails', () {
      const stair = ArchitectStair(
        id: 'u0',
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        width: 1.2,
        design: ArchitectStairDesign(
          shape: StairShape.halfTurn,
          rise: 3.0,
          followStoreys: false,
          totalWidth: 2.4,
        ),
      );
      final storey = ArchitectStorey(
        id: 's0',
        name: '0.00',
        height: 3.0,
        stairs: [stair],
      );
      final paths = ArchitectStairRailings.build(stair, storey: storey);
      final innerPaths = paths
          .where(
            (p) =>
                !p.wallMounted &&
                p.base.every((pt) => (pt.y - 0.6).abs() < 0.08),
          )
          .toList();
      expect(innerPaths, isNotEmpty);
      expect(innerPaths.single.base.length, greaterThanOrEqualTo(4));
    });

    test('ground slab below stair is not counted as overhead obstacle and upper slabs are not auto-cut', () {
      const groundSlab = ArchitectSlab(
        id: 'slab0',
        polygon: [
          Offset(-1, -1),
          Offset(6, -1),
          Offset(6, 4),
          Offset(-1, 4),
        ],
      );
      const upperSlab = ArchitectSlab(
        id: 'slab1',
        polygon: [
          Offset(-1, -1),
          Offset(6, -1),
          Offset(6, 4),
          Offset(-1, 4),
        ],
      );
      const stair = ArchitectStair(
        id: 'st1',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        width: 1.2,
        design: ArchitectStairDesign(
          shape: StairShape.straight,
          rise: 3.0,
          followStoreys: false,
          manualRisers: 17,
          manualGoing: .28,
        ),
      );
      const groundFloor = ArchitectStorey(
        id: 's0',
        name: '0.00',
        height: 3.0,
        elevation: 0.0,
        slabs: [groundSlab],
        stairs: [stair],
      );
      const upperFloor = ArchitectStorey(
        id: 's1',
        name: '+3.00',
        height: 3.0,
        elevation: 3.0,
        slabs: [upperSlab],
      );
      final singleFloorProject = wrapStorey(groundFloor);
      expect(
        ArchitectStairHeadroom.minimum(singleFloorProject, groundFloor, stair),
        isNull,
      );
      final twoFloorProject = wrapStorey(groundFloor, extra: [upperFloor]);
      expect(
        ArchitectSlabGeometry.holes(
          upperFloor,
          upperSlab,
          project: twoFloorProject,
        ),
        isEmpty,
      );
      expect(
        ArchitectStairHeadroom.minimum(twoFloorProject, groundFloor, stair),
        lessThan(3.0),
      );
    });

    test('landingStepOffset staggers outgoing flight cleanly for quarterTurn and halfTurn', () {
      for (final shape in [StairShape.quarterTurn, StairShape.halfTurn]) {
        for (final turnLeft in [false, true]) {
          final stair = ArchitectStair(
            id: 'st_${shape.name}_$turnLeft',
            startPoint: Offset.zero,
            endPoint: const Offset(4, 0),
            width: 1.1,
            design: ArchitectStairDesign(
              shape: shape,
              rise: 3.0,
              followStoreys: false,
              turnLeft: turnLeft,
              landingDepth: 1.2,
              landingStepOffset: .30,
            ),
          );
          final baseline = ArchitectStair(
            id: 'base_${shape.name}_$turnLeft',
            startPoint: Offset.zero,
            endPoint: const Offset(4, 0),
            width: 1.1,
            design: stair.design!.copyWith(landingStepOffset: 0.0),
          );
          final baseGeom = ArchitectStairGeometry.of(baseline);
          final geom = ArchitectStairGeometry.of(stair);
          expect(geom.flights, hasLength(2));
          expect(geom.landings, hasLength(1));
          expect(
            (geom.flights[1].origin - baseGeom.flights[1].origin).distance,
            closeTo(.30, 1e-6),
          );
          final plan = stair.plan;
          expect(plan.nosings, isNotEmpty);
          final mesh = ArchitectStairMesh.body(stair);
          expect(mesh, isNotEmpty);
          final roundtrip = ArchitectStairDesign.fromJson(
            stair.design!.toJson(),
          );
          expect(roundtrip.landingStepOffset, closeTo(.30, 1e-9));
        }
      }
    });

    test('selected stair paints without dropping wall-mounted rails, exposes handles, drags, and flips', () {
      const wall = ArchitectWall(
        id: 'w1',
        startPoint: Offset(-.2, -.725),
        endPoint: Offset(4.5, -.725),
        thickness: .25,
        height: 4.0,
      );
      const stair = ArchitectStair(
        id: 'st_drag',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        width: 1.2,
        design: ArchitectStairDesign(
          shape: StairShape.straight,
          use: StairUse.private,
          rise: 3.0,
          followStoreys: false,
          manualRisers: 11,
          manualGoing: .30,
        ),
      );
      const storey = ArchitectStorey(
        id: 's0',
        name: '0.00',
        height: 4.0,
        walls: [wall],
        stairs: [stair],
      );
      final project = wrapStorey(storey);

      // Rendering selected stair on active storey with active wall must succeed and draw handles.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = Architect2dPainter(
        project: project,
        palette: const ArchitectCanvasPalette.light(),
        activeTool: ArchitectTool.select,
        selectedElementId: stair.id,
        zoomScale: 100,
        handleOffsetLength: 28,
        paintGrid: false,
        l10n: bg,
      );
      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      // Handles hit-test & applyDrag on straight flight end (3.00 m -> ~3.60 m = 12 treads -> 13 risers).
      final hit = ArchitectStairHandles.hitTest(
        stair,
        const Offset(3.0 + .28, 0),
        100,
        28,
      );
      expect(hit, isNotNull);
      expect(hit!.atStart, isFalse);
      expect(hit.isOffset, isTrue);

      final dragged = ArchitectStairHandles.applyDrag(
        stair,
        hit,
        const Offset(3.6, 0),
      );
      expect(dragged.design!.risers, 13);
      expect(dragged.endPoint.dx, closeTo(3.6, 1e-6));

      // Flip turns on a quarterTurn stair via ArchitectElementTool.flipElementById.
      const turnStair = ArchitectStair(
        id: 'st_turn',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        width: 1.2,
        design: ArchitectStairDesign(
          shape: StairShape.quarterTurn,
          rise: 3.0,
          followStoreys: false,
        ),
      );
      final flippedStorey = ArchitectElementTool().flipElementById(
        storey.copyWith(stairs: [turnStair]),
        turnStair.id,
      );
      expect(flippedStorey.stairs.single.design!.turnLeft, isTrue);
    });

    testWidgets('editing legacy stair or landing offset in properties dialog unlocks Save', (tester) async {
      const legacyStair = ArchitectStair(
        id: 'legacy_1',
        startPoint: Offset.zero,
        endPoint: Offset(3.2, 0),
        width: 1.2,
        stepCount: 14,
      );
      final project = ArchitectProject(
        id: 'p',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        units: ArchitectUnit.centimeters,
        activeStoreyId: 's0',
        storeys: const [
          ArchitectStorey(
            id: 's0',
            name: '0.00',
            height: 3.0,
            stairs: [legacyStair],
          ),
          ArchitectStorey(
            id: 's1',
            name: '+3.00',
            height: 3.0,
            elevation: 3.0,
          ),
        ],
      );
      ArchitectStair? saved;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bg'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ArchitectStairPropertiesDialog(
                    project: project,
                    stair: legacyStair,
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

      // Expand advanced dimensions section before editing tread going (default cm unit -> 32).
      final dims = find.byKey(const ValueKey('stair-dimensions'));
      await tester.ensureVisible(dims);
      await tester.tap(dims);
      await tester.pumpAndSettle();

      final goingField = find.byKey(const ValueKey('stair-going'));
      await tester.ensureVisible(goingField);
      await tester.tap(goingField);
      await tester.pumpAndSettle();
      for (final ch in ['3', '2', '.', '4']) {
        await tester.tap(find.byKey(ValueKey('bim-number-key-$ch')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('stair-save')));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.design, isNotNull);
      expect(saved!.design!.going, closeTo(.324, 1e-6));
      expect(tester.takeException(), isNull);
    });

    test('riser out-of-range check uses 15-18 cm bounds non-blockingly', () {
      expect(ArchitectStairRules.minRiser, closeTo(.15, 1e-9));
      expect(ArchitectStairRules.maxRiser, closeTo(.18, 1e-9));
      expect(ArchitectStairRules.isRiserOutOfRange(.149), isTrue);
      expect(ArchitectStairRules.isRiserOutOfRange(.15), isFalse);
      expect(ArchitectStairRules.isRiserOutOfRange(.168), isFalse);
      expect(ArchitectStairRules.isRiserOutOfRange(.18), isFalse);
      expect(ArchitectStairRules.isRiserOutOfRange(.181), isTrue);

      for (final risers in [16, 22]) {
        final stair = ArchitectStair(
          id: 'r_$risers',
          startPoint: Offset.zero,
          endPoint: const Offset(3, 0),
          width: 1.2,
          design: ArchitectStairDesign(
            shape: StairShape.straight,
            rise: 3.0,
            followStoreys: false,
            manualRisers: risers,
          ),
        );
        final checks = ArchitectStairRules.check(stair);
        final riserCheck = checks.singleWhere(
          (c) => c.kind == StairCheckKind.riser,
        );
        expect(riserCheck.state, StairCheckState.advice);
        expect(checks.any((c) => c.state == StairCheckState.error), isFalse);
      }
    });

    testWidgets(
      'properties dialog and freeform draft overlay show non-blocking red riser warning outside 15-18 cm',
      (tester) async {
        const steepStair = ArchitectStair(
          id: 'steep_1',
          startPoint: Offset.zero,
          endPoint: Offset(3.2, 0),
          width: 1.2,
          design: ArchitectStairDesign(
            shape: StairShape.straight,
            rise: 3.0,
            followStoreys: false,
            manualRisers: 16,
            manualGoing: .28,
          ),
        );
        final project = wrapStorey(
          const ArchitectStorey(
            id: 's0',
            name: '0.00',
            height: 3.0,
            stairs: [steepStair],
          ),
        );
        ArchitectStair? saved;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('bg'),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ArchitectStairPropertiesDialog(
                      project: project,
                      stair: steepStair,
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

        expect(
          find.byKey(const ValueKey('stair-riser-warning')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('stair-save')));
        await tester.pumpAndSettle();
        expect(saved, isNotNull);

        // Verify red warning cue in custom draft overlay when riser < 15 cm.
        final shallowCustom = ArchitectStair(
          id: 'shallow_custom',
          startPoint: Offset.zero,
          endPoint: Offset(1, 0),
          width: 1.2,
          design: ArchitectStairDesign(
            shape: StairShape.straight,
            rise: 2.8,
            followStoreys: false,
            manualGoing: .28,
            layout: ArchitectStairLayout(
              flights: [
                ArchitectStairFlightSpec(
                  id: 'f1',
                  origin: Offset.zero,
                  axis: Offset(1, 0),
                  width: 1.2,
                  risers: 20,
                ),
              ],
            ),
          ),
        );
        final draft = ArchitectStairDraftController(shallowCustom, create: false);
        addTearDown(draft.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('bg'),
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: ArchitectStairDraftOverlay(
                  draft: draft,
                  project: project,
                  toScreen: (p) => Offset(p.dx * 100 + 50, p.dy * 100 + 300),
                  toModel: (s) => Offset((s.dx - 50) / 100, (s.dy - 300) / 100),
                  scale: 100,
                  onApply: () {},
                  onCancel: () {},
                  onProperties: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('stair-draft-riser-warning')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('stair-draft-riser-warning')),
            matching: find.byIcon(Icons.warning_amber_rounded),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
