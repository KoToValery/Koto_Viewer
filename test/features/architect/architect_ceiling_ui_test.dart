import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_ceiling_drafting_bar.dart';
import 'package:kotoview/src/features/architect/widgets/architect_ceiling_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_workspace_view_bar.dart';
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
      'quick plan mode switch & Plan menu sub-plan work on phone (${locale.languageCode})',
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

        // Option 1: Quick switch pill is visible and toggles to Ceilings & MEP.
        final switchPill = find.byKey(
          const ValueKey('architect-plan-mode-switch'),
        );
        expect(switchPill, findsOneWidget);

        final l = await AppLocalizations.delegate.load(locale);
        await tester.tap(
          find.descendant(
            of: switchPill,
            matching: find.text(l.architectCeilingPlanShort),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('±0.00 · ${l.architectCeilingPlanShort}'),
          findsOneWidget,
        );

        // Option 2: Plan dropdown menu allows adding explicit ceiling sub-plan.
        await tester.tap(find.byKey(const ValueKey('architect-view-plan')));
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
}
