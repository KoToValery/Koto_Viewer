import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_handles.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_layout_resolver.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_railings.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart'
    show Vector3;
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_opening_continuous_placement_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tool_ui;

Future<void> _enterStairDimension(
  WidgetTester tester,
  String chipKey,
  String digits,
) async {
  final chip = find.descendant(
    of: find.byType(ArchitectToolPalette),
    matching: find.byKey(ValueKey(chipKey)),
  );
  expect(chip, findsOneWidget);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
  for (final ch in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('bim-number-key-$ch')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Stair defaults & quick menu', () {
    test('default flight width is 100 cm and halfTurn totalWidth is 240 cm', () {
      final tool = ArchitectElementTool();
      expect(tool.stairWidth, closeTo(1.00, 1e-6));
      expect(tool.stairDesign.totalWidth, closeTo(2.40, 1e-6));
      expect(tool.stairDesign.effectiveTotalWidth(tool.stairWidth), closeTo(2.40, 1e-6));
      expect(tool.stairDesign.wellGap(tool.stairWidth), closeTo(0.40, 1e-6));
    });

    testWidgets(
      'quick bar shows 100cm/240cm defaults, well gap remainder, height H, and landing offset (bg)',
      (tester) async {
        tester.view.physicalSize = const Size(420, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final commands = workspace.seededController();
        addTearDown(commands.dispose);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('bg'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: commands),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('architect-tool-category')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('architect-category-stairs')));
        await tester.pumpAndSettle();
        final halfTurnBtn = find.byKey(const ValueKey('stair-shape-halfTurn'));
        await tester.ensureVisible(halfTurnBtn);
        await tester.pumpAndSettle();
        await tester.tap(halfTurnBtn);
        await tester.pumpAndSettle();

        var palette = tester.widget<ArchitectToolPalette>(
          find.byType(ArchitectToolPalette),
        );
        expect(palette.stairWidth, closeTo(1.00, 1e-6));
        expect(palette.stairDesign.totalWidth, closeTo(2.40, 1e-6));
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('stair-well-gap'))).data,
          'Око: 40 cm',
        );

        // Changing total width updates remaining well gap live.
        await _enterStairDimension(tester, 'stair-total-width-input', '220');
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('stair-well-gap'))).data,
          'Око: 20 cm',
        );

        // Landing offset and total stair height H are editable directly in the quick bar.
        await _enterStairDimension(tester, 'stair-landing-offset-input', '5');
        await _enterStairDimension(tester, 'stair-rise-input', '300');

        palette = tester.widget<ArchitectToolPalette>(
          find.byType(ArchitectToolPalette),
        );
        expect(palette.stairDesign.landingStepOffset, closeTo(0.05, 1e-6));
        expect(palette.stairDesign.followStoreys, isFalse);
        expect(palette.stairDesign.rise, closeTo(3.00, 1e-6));
      },
    );

    testWidgets(
      'handle-edited stair keeps flight width, height H, going and step h visible in quick bar',
      (tester) async {
        const preset = ArchitectStair(
          id: 'st_dragged',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
          width: 1.0,
          design: ArchitectStairDesign(
            shape: StairShape.halfTurn,
            rise: 2.8,
            followStoreys: false,
            totalWidth: 2.4,
            landingDepth: 1.2,
          ),
        );
        final handles = ArchitectStairHandles.handles(preset, 0.25);
        final landingFlightHandle = handles.firstWhere(
          (h) => h.landingIndex == null && h.flightIndex == 0 && !h.atStart,
        );
        final dragged = ArchitectStairHandles.applyDrag(
          preset,
          landingFlightHandle,
          landingFlightHandle.anchor - const Offset(0.30, 0),
        );
        expect(dragged.design!.layout, isNotNull);

        final commands = ArchitectCommandController(
          ArchitectProject(
            id: 'p_custom_bar',
            name: 'Custom Bar',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            activeStoreyId: 's',
            storeys: [
              ArchitectStorey(
                id: 's',
                name: 'Floor 1',
                stairs: [dragged],
              ),
            ],
          ),
        );
        addTearDown(commands.dispose);

        await workspace.openWorkspace(tester, commands);
        workspace
            .camera(tester)
            .fit(const Rect.fromLTRB(-1, -1, 5, 4), padding: 64);
        await tester.pumpAndSettle();

        await tool_ui.choose(tester, Icons.near_me_outlined);
        await tester.pumpAndSettle();
        await tester.tapAt(workspace.screen(tester, const Offset(0.9, 0)));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('stair-width-input')), findsOneWidget);
        expect(find.byKey(const ValueKey('stair-rise-input')), findsOneWidget);
        expect(find.byKey(const ValueKey('stair-going-input')), findsOneWidget);
        expect(find.byKey(const ValueKey('stair-riser-input')), findsOneWidget);

        await _enterStairDimension(tester, 'stair-width-input', '110');
        await _enterStairDimension(tester, 'stair-rise-input', '300');

        final edited = commands.project.activeStorey.stairs.single;
        expect(edited.width, closeTo(1.10, 1e-6));
        expect(
          edited.design!.layout!.flights.every((f) => (f.width - 1.10).abs() < 1e-6),
          isTrue,
        );
        expect(ArchitectStairLayoutResolver.check(edited.design!), isEmpty);
        expect(edited.design!.rise, closeTo(3.00, 1e-6));
        await _enterStairDimension(tester, 'stair-riser-input', '15');
        final fitted = commands.project.activeStorey.stairs.single;
        expect(fitted.design!.risers, 20);
        expect(fitted.design!.riser, closeTo(.15, 1e-9));
        expect(ArchitectStairLayoutResolver.check(fitted.design!), isEmpty);
        commands.undo();
        await tester.pumpAndSettle();
        expect(commands.project.activeStorey.stairs.single.design!.risers,
            edited.design!.risers);
      },
    );
  });

  group('Landing handle editing', () {
    test('lateral flight handle preserves risers and reconnects landing', () {
      for (final (shape, turnLeft) in [
        (StairShape.halfTurn, false),
        (StairShape.halfTurn, true),
        (StairShape.quarterTurn, false),
        (StairShape.quarterTurn, true),
      ]) {
        final stair = ArchitectStair(
          id: 'lateral',
          startPoint: Offset.zero,
          endPoint: const Offset(1, 0),
          width: 1,
          design: ArchitectStairDesign(
            shape: shape,
            rise: 2.8,
            followStoreys: false,
            turnLeft: turnLeft,
            totalWidth: 2.4,
            landingDepth: 1.2,
          ),
        );
        final handle = ArchitectStairHandles.handles(
          stair,
          .25,
        ).firstWhere((h) => h.lateral);
        final direction = (handle.handle - handle.anchor) / .25;
        final flights = ArchitectStairGeometry.of(stair).flights;
        final otherPort = flights.first.point(flights.first.run, 0);
        expect(
          ArchitectStairGeometry.dot(direction, flights.last.origin - otherPort),
          greaterThan(0),
        );
        expect(
          ArchitectStairHandles.hitTest(stair, handle.handle, 100, 25)!.lateral,
          isTrue,
        );
        final moved = ArchitectStairHandles.applyDrag(
          stair,
          handle,
          handle.anchor + direction * .2,
        );
        expect(moved.design!.risers, stair.design!.risers);
        expect(moved.design!.riser, closeTo(stair.design!.riser, 1e-9));
        expect(moved.width, stair.width);
        expect(ArchitectStairLayoutResolver.check(moved.design!), isEmpty);
        expect(
          (ArchitectStairHandles.anchorFor(moved, handle) - handle.anchor)
              .distance,
          closeTo(.2, 1e-6),
        );
      }
    });
    test('halfTurn landing flight handles and outer landing back edge adjust cleanly in both directions', () {
      const stair = ArchitectStair(
        id: 'u_stair',
        startPoint: Offset.zero,
        endPoint: Offset(1, 0),
        width: 1.0,
        design: ArchitectStairDesign(
          shape: StairShape.halfTurn,
          rise: 2.8,
          followStoreys: false,
          totalWidth: 2.4,
          landingDepth: 1.2,
        ),
      );

      final handles = ArchitectStairHandles.handles(stair, 0.25);
      final f0End = handles.firstWhere(
        (h) => h.landingIndex == null && h.flightIndex == 0 && !h.atStart,
      );
      final f1Start = handles.firstWhere(
        (h) => h.landingIndex == null && h.flightIndex == 1 && h.atStart,
      );
      final landingBack = handles.firstWhere((h) => h.landingIndex == 0);

      // Shift a landing connection by less than one tread in either direction.
      final f0Back = ArchitectStairHandles.applyDrag(
        stair,
        f0End,
        f0End.anchor - const Offset(0.05, 0),
      );
      expect(ArchitectStairLayoutResolver.check(f0Back.design!), isEmpty);
      expect(
        f0Back.design!.layout!.flights[0].risers,
        stair.design!.flightRisers[0],
      );

      expect(f0Back.design!.risers, stair.design!.risers);
      expect(f0Back.design!.riser, closeTo(stair.design!.riser, 1e-9));
      expect(f0Back.design!.going, stair.design!.going);
      expect(
        ArchitectStairHandles.anchorFor(f0Back, f0End).dx,
        closeTo(f0End.anchor.dx - .05, 1e-8),
      );

      final f0Forward = ArchitectStairHandles.applyDrag(
        stair,
        f0End,
        f0End.anchor + const Offset(0.05, 0),
      );
      expect(ArchitectStairLayoutResolver.check(f0Forward.design!), isEmpty);
      expect(
        f0Forward.design!.layout!.flights[0].risers,
        stair.design!.flightRisers[0],
      );
      expect(
        ArchitectStairLayoutResolver.landingDepth(f0Forward.design!),
        greaterThanOrEqualTo(1.0 - 1e-6),
      );

      final f1Back = ArchitectStairHandles.applyDrag(
        stair,
        f1Start,
        f1Start.anchor - const Offset(0.05, 0),
      );
      expect(ArchitectStairLayoutResolver.check(f1Back.design!), isEmpty);
      expect(
        f1Back.design!.layout!.flights[1].risers,
        stair.design!.flightRisers[1],
      );
      expect(
        ArchitectStairLayoutResolver.returnStagger(f1Back.design!, 0),
        closeTo(.05, 1e-8),
      );

      final f1Forward = ArchitectStairHandles.applyDrag(
        stair,
        f1Start,
        f1Start.anchor + const Offset(0.05, 0),
      );
      expect(ArchitectStairLayoutResolver.check(f1Forward.design!), isEmpty);
      expect(
        f1Forward.design!.layout!.flights[1].risers,
        stair.design!.flightRisers[1],
      );
      expect(
        ArchitectStairLayoutResolver.returnStagger(f1Forward.design!, 0),
        closeTo(-.05, 1e-8),
      );
      var exact = f1Back;
      for (final offset in [0.0, -.035, .05]) {
        exact = ArchitectStairLayoutResolver.setReturnStagger(exact, 0, offset);
        final restored = ArchitectStair.fromJson(exact.toJson());
        expect(ArchitectStairLayoutResolver.check(restored.design!), isEmpty);
        expect(restored.design!.flightRisers, stair.design!.flightRisers);
        expect(
          ArchitectStairLayoutResolver.returnStagger(restored.design!, 0),
          closeTo(offset, 1e-8),
        );
      }

      // 4. Outer landing back handle adjusts landingDepth on preset without converting layout.
      final stretchedPreset = ArchitectStairHandles.applyDrag(
        stair,
        landingBack,
        landingBack.anchor + const Offset(0.45, 0),
      );
      expect(stretchedPreset.design!.layout, isNull);
      expect(stretchedPreset.design!.landingDepth, closeTo(1.65, 1e-2));

      // And works on custom-layout landing back handle too.
      final customHandles = ArchitectStairHandles.handles(f0Back, 0.25);
      final customLandingBack = customHandles.firstWhere(
        (h) => h.landingIndex == 0,
      );
      final stretchedCustom = ArchitectStairHandles.applyDrag(
        f0Back,
        customLandingBack,
        customLandingBack.anchor + const Offset(0.50, 0),
      );
      expect(ArchitectStairLayoutResolver.check(stretchedCustom.design!), isEmpty);
      expect(
        ArchitectStairLayoutResolver.landingDepth(stretchedCustom.design!),
        greaterThan(1.4),
      );
    });

    test('quarterTurn landing flight handles adjust flights & back wall cleanly', () {
      const lStair = ArchitectStair(
        id: 'l_stair',
        startPoint: Offset.zero,
        endPoint: Offset(1, 0),
        width: 1.0,
        design: ArchitectStairDesign(
          shape: StairShape.quarterTurn,
          rise: 2.8,
          followStoreys: false,
          landingDepth: 1.2,
        ),
      );

      final handles = ArchitectStairHandles.handles(lStair, 0.25);
      final f0End = handles.firstWhere(
        (h) => h.landingIndex == null && h.flightIndex == 0 && !h.atStart,
      );
      final f1Start = handles.firstWhere(
        (h) => h.landingIndex == null && h.flightIndex == 1 && h.atStart,
      );

      final f0Short = ArchitectStairHandles.applyDrag(
        lStair,
        f0End,
        f0End.anchor - const Offset(0.30, 0),
      );
      expect(ArchitectStairLayoutResolver.check(f0Short.design!), isEmpty);

      final f1Short = ArchitectStairHandles.applyDrag(
        lStair,
        f1Start,
        f1Start.anchor + const Offset(0, 0.30),
      );
      expect(ArchitectStairLayoutResolver.check(f1Short.design!), isEmpty);

      // With generous landing depth (1.50m), advancing flight 0 forward stays valid.
      final deepLStair = lStair.copyWith(
        design: lStair.design!.copyWith(landingDepth: 1.5),
      );
      final deepHandles = ArchitectStairHandles.handles(deepLStair, 0.25);
      final deepF0End = deepHandles.firstWhere(
        (h) => h.landingIndex == null && h.flightIndex == 0 && !h.atStart,
      );
      final f0Long = ArchitectStairHandles.applyDrag(
        deepLStair,
        deepF0End,
        deepF0End.anchor + const Offset(0.30, 0),
      );
      expect(ArchitectStairLayoutResolver.check(f0Long.design!), isEmpty);
    });
  });

  group('Inner stair railing plan width', () {
    test('planOffset keeps uniform ±2.4 cm railing width across vertical riser transitions', () {
      const stair = ArchitectStair(
        id: 'u_rail',
        startPoint: Offset.zero,
        endPoint: Offset(1, 0),
        width: 1.0,
        design: ArchitectStairDesign(
          shape: StairShape.halfTurn,
          rise: 2.8,
          followStoreys: false,
          totalWidth: 2.4,
          landingDepth: 1.2,
        ),
      );
      final paths = ArchitectStairRailings.build(
        stair,
        storey: const ArchitectStorey(id: 's', name: '0.00'),
      );
      expect(paths, isNotEmpty);

      for (final path in paths) {
        final base = ArchitectStairMesh.simplify(path.base);
        if (base.length < 2) continue;
        final left = ArchitectStairRailings.planOffset(base, -0.024);
        final right = ArchitectStairRailings.planOffset(base, 0.024);
        for (var i = 0; i < base.length - 1; i++) {
          final lDist = (left[i] - right[i]).distance;
          final a2d = Offset(base[i].x, base[i].y);
          final b2d = Offset(base[i + 1].x, base[i + 1].y);
          final seg2d = b2d - a2d;
          // Every 2D offset vertex must stay strictly <= 2*sqrt(2)*0.024 (no 2x widening to 0.096).
          expect(lDist, lessThanOrEqualTo(0.048 * math.sqrt(2) + 1e-4));
          if (seg2d.distance > 0.25) {
            final normal = Offset(-seg2d.dy, seg2d.dx) / seg2d.distance;
            final midL = (left[i] + left[i + 1]) / 2;
            final midR = (right[i] + right[i + 1]) / 2;
            final perpWidth =
                ((midL - midR).dx * normal.dx + (midL - midR).dy * normal.dy)
                    .abs();
            // Perpendicular railing thickness along straight flights stays exact 4.8 cm.
            expect(perpWidth, closeTo(0.048, 1e-4));
          }
        }
      }

      // Direct regression check for vertical XY-coincident step entering a flight.
      final synthetic = [
        Vector3(0, 0, 1.4),
        Vector3(0, 0.4, 1.4),
        Vector3(0, 0.4, 1.575),
        Vector3(-2.0, 0.4, 2.8),
      ];
      final offL = ArchitectStairRailings.planOffset(synthetic, -0.024);
      final offR = ArchitectStairRailings.planOffset(synthetic, 0.024);
      expect(
        (offL[2] - offR[2]).distance,
        closeTo(0.048 * math.sqrt(2), 1e-4),
      );
      final flightMidWidth =
          (((offL[2] + offL[3]) / 2 - (offR[2] + offR[3]) / 2).dy).abs();
      expect(flightMidWidth, closeTo(0.048, 1e-4));
    });
  });
}
