import 'architect_projection_test_helper.dart' as projection;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_ceiling_drafting_bar.dart';
import 'package:kotoview/src/features/architect/widgets/architect_ceiling_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_workspace_view_bar.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_viewport_controller.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_editing_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

ArchitectProject _ceilingProject({bool hasCeilingPlan = false}) => ArchitectProject(
  id: 'p_ceil',
  name: 'Ceiling House',
  createdAt: DateTime(2026, 11, 20),
  updatedAt: DateTime(2026, 11, 20),
  activeStoreyId: 's0',
  storeys: [
    ArchitectStorey(
      id: 's0',
      name: '±0.00',
      elevation: 0.0,
      height: 3.0,
      hasCeilingPlan: hasCeilingPlan,
      ceilings: const [
        ArchitectSuspendedCeiling(
          id: 'c1',
          type: SuspendedCeilingType.armstrong,
          polygon: [Offset(0, 0), Offset(4, 0), Offset(4, 3), Offset(0, 3)],
          dropFromUpperSlab: 0.25,
        ),
      ],
    ),
    const ArchitectStorey(
      id: 's1',
      name: '+3.00',
      elevation: 3.0,
      height: 2.8,
      slabs: [
        ArchitectSlab(
          id: 'slab_upper',
          polygon: [Offset(-1, -1), Offset(6, -1), Offset(6, 5), Offset(-1, 5)],
          thickness: 0.20,
        ),
      ],
    ),
  ],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final locale in const [Locale('bg'), Locale('en')]) {
    testWidgets(
      'Plan menu switches floor and ceiling on phone (${locale.languageCode})',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final controller = ArchitectCommandController(_ceilingProject());
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: controller),
          ),
        );
        await tester.pumpAndSettle();

        final l = await AppLocalizations.delegate.load(locale);
        final plan = find.byKey(const ValueKey('architect-view-plan'));
        Finder entry(String id) => find.byWidgetPredicate(
          (widget) => widget is CheckedPopupMenuItem<String> && widget.value == id,
        );
        expect(
          find.byKey(const ValueKey('architect-plan-mode-switch')),
          findsNothing,
        );
        await tester.tap(plan);
        await tester.pumpAndSettle();
        await tester.tap(entry('ceiling:s0'));
        await tester.pumpAndSettle();

        expect(
          find.text('±0.00 · ${l.architectCeilingPlanShort}'),
          findsOneWidget,
        );
        expect(controller.project.activeStorey.hasCeilingPlan, isFalse);

        await tester.tap(plan);
        await tester.pumpAndSettle();
        await tester.tap(entry('s0'));
        await tester.pumpAndSettle();
        expect(find.text('±0.00 · ${l.architectCeilingPlanShort}'), findsNothing);

        await tester.tap(plan);
        await tester.pumpAndSettle();
        expect(find.text(l.architectAddCeilingPlan), findsOneWidget);
        await tester.tap(find.text(l.architectAddCeilingPlan));
        await tester.pumpAndSettle();

        expect(controller.project.storeys.first.hasCeilingPlan, isTrue);

        // Re-opening Plan menu shows the nested Ceilings & MEP sub-plan entry.
        await tester.tap(find.byKey(const ValueKey('architect-view-plan')));
        await tester.pumpAndSettle();
        expect(find.text(l.architectCeilingPlan), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ArchitectCeilingDraftingBar and PropertiesDialog work on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final project = _ceilingProject(hasCeilingPlan: true);
    var ceiling = project.storeys.first.ceilings.first;
    ArchitectSuspendedCeiling? applied;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ArchitectCeilingDraftingBar(
                  type: ceiling.type,
                  fromRoom: true,
                  dropFromUpperSlab: ceiling.dropFromUpperSlab,
                  selected: ceiling,
                  onTypeChanged: (t) => ceiling = ceiling.copyWith(type: t),
                  onFromRoomChanged: (_) {},
                  onDropChanged: (d) =>
                      ceiling = ceiling.copyWith(dropFromUpperSlab: d),
                  onProperties: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => ArchitectCeilingPropertiesDialog(
                        project: project,
                        ceiling: ceiling,
                        onApply: (next) {
                          applied = next;
                          return true;
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final propsBtn = find.byKey(const ValueKey('ceiling-draft-properties'));
    await tester.ensureVisible(propsBtn);
    await tester.pumpAndSettle();
    await tester.tap(propsBtn);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('architect-ceiling-properties-dialog')),
      findsOneWidget,
    );
    final tile60x120 = find.text('60×120');
    expect(tile60x120, findsOneWidget);
    await tester.ensureVisible(tile60x120);
    await tester.pumpAndSettle();
    await tester.tap(tile60x120);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ceiling-prop-apply')));
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
    expect(applied!.tileLength, closeTo(1.20, 1e-6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Architect2dPainter renders ceilingServices and floor modes cleanly', (
    tester,
  ) async {
    final project = _ceilingProject(hasCeilingPlan: true);
    for (final mode in ArchitectPlanMode.values) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CustomPaint(
                painter: Architect2dPainter(
                  project: project,
                  activeTool: ArchitectTool.ceiling,
                  planMode: mode,
                  zoomScale: 30.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(ArchitectWorkspaceViewBar), findsNothing);
  });

  testWidgets(
    'Editing selected ceiling vertex locks viewport pan while panning empty space moves camera',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = ArchitectCommandController(
        _ceilingProject(hasCeilingPlan: true),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Ceilings & MEP mode so the suspended ceiling is selectable/editable.
      await tester.tap(find.byKey(const ValueKey('architect-view-plan')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckedPopupMenuItem<String> &&
              widget.value == 'ceiling:s0',
        ),
      );
      await tester.pumpAndSettle();

      final viewportFinder = find.descendant(
        of: find.byType(ArchitectWorkspaceScreen),
        matching: find.byWidgetPredicate(
          (w) =>
              w is BimEditingViewport &&
              w.inputKey == const ValueKey('architect-viewport-input'),
        ),
      );
      final viewportBox = tester.renderObject<RenderBox>(viewportFinder);
      BimViewportController cameraOf() =>
          tester.widget<BimEditingViewport>(viewportFinder).controller
              as BimViewportController;
      Offset toGlobalScreen(Offset model) =>
          viewportBox.localToGlobal(cameraOf().toScreen(model));

      // Tap inside ceiling c1 to select it and enter polygon editing.
      await tester.tapAt(toGlobalScreen(const Offset(2.0, 1.5)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('polygon-edit-close')), findsOneWidget);

      final initialCameraOffset = cameraOf().translation;
      final originalCorner =
          controller.project.storeys.first.ceilings.first.polygon[2];

      // Drag ceiling vertex (4, 3) using touch input; must move vertex without panning screen.
      final vertexGesture = await tester.startGesture(
        toGlobalScreen(originalCorner),
        kind: PointerDeviceKind.touch,
      );
      await vertexGesture.moveBy(const Offset(45, 0));
      await tester.pump();
      await vertexGesture.up();
      await tester.pumpAndSettle();

      expect(cameraOf().translation, initialCameraOffset);
      final updatedCorner =
          controller.project.storeys.first.ceilings.first.polygon[2];
      expect(updatedCorner.dx, greaterThan(originalCorner.dx + 0.1));

      // Drag empty canvas outside ceiling & handles; viewport camera must pan cleanly.
      final panStart = viewportBox.localToGlobal(
        Offset(24, viewportBox.size.height - 40),
      );
      final panGesture = await tester.startGesture(
        panStart,
        kind: PointerDeviceKind.touch,
      );
      await panGesture.moveBy(const Offset(60, -40));
      await tester.pump();
      await panGesture.up();
      await tester.pumpAndSettle();

      expect(
        (cameraOf().translation - initialCameraOffset).distance,
        greaterThan(20.0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Ceiling drafting stepper toggles Δh / H on phone and section view shows editable upper/lower dimensions',
    (tester) async {
      tester.view.physicalSize = const Size(420, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var anchor = CeilingElevationAnchor.fromUpperSlab;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setLocalState) => ArchitectCeilingDraftingBar(
                type: SuspendedCeilingType.armstrong,
                fromRoom: true,
                elevationAnchor: anchor,
                dropFromUpperSlab: 0.25,
                clearHeight: 2.55,
                onTypeChanged: (_) {},
                onFromRoomChanged: (_) {},
                onAnchorChanged: (next) => setLocalState(() => anchor = next),
                onDropChanged: (_) {},
                onClearHeightChanged: (_) {},
                onProperties: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Δh'), findsOneWidget);
      final anchorToggle = find.byKey(const ValueKey('ceiling-anchor-toggle'));
      await tester.ensureVisible(anchorToggle);
      await tester.pumpAndSettle();
      await tester.tap(anchorToggle);
      await tester.pumpAndSettle();
      expect(find.text('H'), findsOneWidget);

      // Now test Section view selection & interactive upper/lower dynamic dimensions.
      final sectionProject = _ceilingProject(hasCeilingPlan: true).copyWith(
        sections: const [
          ArchitectSection(
            id: 'sec_a',
            name: 'A-A',
            start: Offset(-1, 1.5),
            end: Offset(5, 1.5),
          ),
        ],
      );
      final controller = ArchitectCommandController(sectionProject);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Switch workspace view to section A-A via UI menu.
      await tester.tap(find.byKey(const ValueKey('architect-view-section')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is CheckedPopupMenuItem<String> && w.value == 'sec_a',
        ),
      );
      await projection.settleProjection(tester);

      final viewportFinder = find.descendant(
        of: find.byType(ArchitectWorkspaceScreen),
        matching: find.byWidgetPredicate(
          (w) =>
              w is BimEditingViewport &&
              w.inputKey == const ValueKey('architect-viewport-input'),
        ),
      );
      final viewportBox = tester.renderObject<RenderBox>(viewportFinder);
      BimViewportController cameraOf() =>
          tester.widget<BimEditingViewport>(viewportFinder).controller
              as BimViewportController;

      // Tap the ceiling plate in section (upper slab bottom = 2.80, drop = 0.25 => z = 2.55, view x = 2.5).
      final hitScreen = viewportBox.localToGlobal(
        cameraOf().toScreen(const Offset(2.5, -2.56)),
      );
      await tester.tapAt(hitScreen);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('projection-distance-head')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('projection-distance-sill')),
        findsOneWidget,
      );

      // Tap lower dimension button ("До готов под") -> keypad opens -> enter 2.20 m -> save.
      await tester.tap(
        find.byKey(const ValueKey('projection-distance-sill')),
      );
      await tester.pumpAndSettle();

      final dialog = find.byType(Dialog).last;
      for (final ch in ['2', '.', '2']) {
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.byKey(ValueKey('wall-key-$ch')),
          ),
        );
        await tester.pump();
      }
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.byKey(const ValueKey('wall-end')),
        ),
      );
      await projection.settleProjection(tester);

      final updated = controller.project.storeys.first.ceilings.first;
      expect(updated.clearHeight, closeTo(2.20, 1e-4));
      // Upper slab underside is at 2.80 -> new drop must auto-recalculate to 0.60 m!
      expect(updated.dropFromUpperSlab, closeTo(0.60, 1e-4));
      expect(tester.takeException(), isNull);
    },
  );
}
