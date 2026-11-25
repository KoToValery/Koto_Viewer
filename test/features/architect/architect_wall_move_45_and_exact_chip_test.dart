import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

Future<void> _tapKeypad(WidgetTester tester, String digits) async {
  final panel = find.byKey(const ValueKey('wall-move-exact-keypad'));
  for (final ch in digits.split('')) {
    await tester.tap(
      find.descendant(of: panel, matching: find.text(ch)).first,
    );
    await tester.pump();
  }
}

void main() {
  group('ArchitectSnapHelper.snapDirection', () {
    test('snaps near 45° diagonal to exact 45° and provides guide line', () {
      final result = ArchitectSnapHelper.snapDirection(
        anchor: const Offset(1, 2),
        delta: const Offset(1.94, 2.04),
        radius: 0.25,
        scale: 80,
      );
      expect(result.isSnapped, isTrue);
      expect(result.snapLabel, '45°');
      expect(result.angleDeg, closeTo(45.0, 1e-6));
      expect(result.point.dx, closeTo(result.point.dy, 1e-6));
      expect(result.point.dx, closeTo(1.99, 1e-6));
      expect(result.magneticGuides, hasLength(1));
      final guide = result.magneticGuides.single;
      // Guide passes through anchor along 45° direction and extends past endpoint.
      expect((guide.$2 - guide.$1).dx, closeTo((guide.$2 - guide.$1).dy, 1e-6));
      expect((guide.$2 - const Offset(1, 2)).distance, greaterThan(result.point.distance));
    });

    test('snaps near 135°, 225°, 315° and leaves 25° unsnapped', () {
      final d135 = ArchitectSnapHelper.snapDirection(
        anchor: Offset.zero,
        delta: const Offset(-1.52, 1.48),
      );
      expect(d135.isSnapped, isTrue);
      expect(d135.snapLabel, '135°');
      expect(d135.point.dx, closeTo(-d135.point.dy, 1e-6));

      final d225 = ArchitectSnapHelper.snapDirection(
        anchor: Offset.zero,
        delta: const Offset(-1.52, -1.48),
      );
      expect(d225.isSnapped, isTrue);
      expect(d225.snapLabel, '225°');
      expect(d225.point.dx, closeTo(d225.point.dy, 1e-6));

      final d315 = ArchitectSnapHelper.snapDirection(
        anchor: Offset.zero,
        delta: const Offset(1.52, -1.48),
      );
      expect(d315.isSnapped, isTrue);
      expect(d315.snapLabel, '315°');
      expect(d315.point.dx, closeTo(-d315.point.dy, 1e-6));

      final offAngle = ArchitectSnapHelper.snapDirection(
        anchor: Offset.zero,
        delta: Offset(math.cos(25 * math.pi / 180) * 2, math.sin(25 * math.pi / 180) * 2),
      );
      expect(offAngle.isSnapped, isFalse);
      expect(offAngle.magneticGuides, isEmpty);
    });
  });

  for (final language in ['en', 'bg']) {
    testWidgets(
      'Wall midpoint drag snaps to 45°, shows non-blocking chip, and refines exact distance in one Undo ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(420, 840);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final wall = editing.wall('w1', const Offset(-2, 0), const Offset(2, 0));
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: '', walls: [wall]),
        );
        addTearDown(model.dispose);
        model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
        final original = model.project;

        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();

        // Select the wall first, then drag its midpoint (0, 0) diagonally ~45°.
        await workspace.wallTap(tester, Offset.zero);
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementId, 'w1');

        final gesture = await tester.startGesture(
          workspace.screen(tester, Offset.zero),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(workspace.screen(tester, const Offset(1.40, 1.46)));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        // Snapped to exact 45° (dx == dy) and committed as 1 undo step.
        final afterDrag = model.project.activeStorey.walls.single;
        final dragDelta = afterDrag.startPoint - wall.startPoint;
        expect(dragDelta.dx, closeTo(dragDelta.dy, 1e-4));
        expect(dragDelta.distance, greaterThan(1.5));
        expect(model.undoCount, 1);

        // Non-blocking floating chip appears with distance and 45° indicator.
        final chipFinder = find.byKey(
          const ValueKey('architect-wall-move-exact-chip'),
        );
        expect(chipFinder, findsOneWidget);
        expect(
          find.descendant(of: chipFinder, matching: find.textContaining('45°')),
          findsOneWidget,
        );

        // Tap chip to open exact distance modal, enter 200 cm (= 2.00 m), and save.
        await tester.tap(
          find.byKey(const ValueKey('architect-wall-move-exact-edit')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('wall-move-exact-keypad')),
          findsOneWidget,
        );

        await _tapKeypad(tester, '200');
        await tester.tap(find.byKey(const ValueKey('shape-save')));
        await tester.pumpAndSettle();

        // Exact 2.00 m along 45° from original pre-drag wall position.
        final refined = model.project.activeStorey.walls.single;
        final refinedDelta = refined.startPoint - wall.startPoint;
        final expectedComp = 2.0 / math.sqrt2;
        expect(refinedDelta.dx, closeTo(expectedComp, 1e-4));
        expect(refinedDelta.dy, closeTo(expectedComp, 1e-4));
        expect(refinedDelta.distance, closeTo(2.0, 1e-4));

        // Still only 1 undo step back to the pre-drag project.
        expect(model.undoCount, 1);
        model.undo();
        expect(model.project.activeStorey, same(original.activeStorey));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Floating chip can be dismissed without modifying the wall', (
    tester,
  ) async {
    final wall = editing.wall('w1', const Offset(-2, 0), const Offset(2, 0));
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: '', walls: [wall]),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);

    await workspace.wallTap(tester, Offset.zero);
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      workspace.screen(tester, Offset.zero),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(workspace.screen(tester, const Offset(1.0, 1.02)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final movedBeforeDismiss = model.project.activeStorey.walls.single;
    expect(
      find.byKey(const ValueKey('architect-wall-move-exact-chip')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('architect-wall-move-exact-dismiss')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('architect-wall-move-exact-chip')),
      findsNothing,
    );
    expect(
      model.project.activeStorey.walls.single.startPoint,
      movedBeforeDismiss.startPoint,
    );
    expect(tester.takeException(), isNull);
  });
}
