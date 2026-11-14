import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_3d_viewport.dart';
import 'package:kotoview/src/features/architect/widgets/architect_workspace_view_bar.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_projection_test_helper.dart' as projection;

ArchitectCommandController _controller() => ArchitectCommandController(
  ArchitectProject(
    id: 'p1',
    name: 'Navigation House',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    activeStoreyId: 's1',
    storeys: const [
      ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        walls: [
          ArchitectWall(
            id: 'w1',
            startPoint: Offset(0, 0),
            endPoint: Offset(6, 0),
          ),
          ArchitectWall(
            id: 'w2',
            startPoint: Offset(6, 0),
            endPoint: Offset(6, 4),
          ),
        ],
      ),
    ],
    elevations: const [
      ArchitectElevation(
        id: 'e1',
        start: Offset(-1, -2),
        end: Offset(7, -2),
      ),
    ],
    sections: const [
      ArchitectSection(
        id: 'sec1',
        name: 'A-A',
        start: Offset(-1, 2),
        end: Offset(7, 2),
      ),
    ],
  ),
);

BimWorkProject _bimProject() => BimWorkProject(
  id: 'bim-p1',
  name: 'Navigation House',
  projectType: BimProjectType.architectural,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pushWorkspace(
  WidgetTester tester,
  ArchitectCommandController controller, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  BimWorkProject? bimProject,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('open-workspace'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ArchitectWorkspaceScreen(
                      commandController: controller,
                      bimProject: bimProject,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-workspace')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in const [Locale('en'), Locale('bg')]) {
    testWidgets(
      'Back, view bar 1-tap Plan return, and 3D pill work on narrow phone (${locale.languageCode})',
      (tester) async {
        final controller = _controller();
        addTearDown(controller.dispose);
        await _pushWorkspace(
          tester,
          controller,
          locale: locale,
          size: const Size(360, 640),
          bimProject: _bimProject(),
        );
        final l10n = lookupAppLocalizations(locale);
        expect(find.byType(ArchitectWorkspaceScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('architect-view-3d')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 1) Open 3D from view bar -> top-left Back returns directly to Plan.
        await tester.tap(find.byKey(const ValueKey('architect-view-3d')));
        await tester.pumpAndSettle();
        expect(find.byType(Architect3dViewport), findsOneWidget);
        expect(
          find.byKey(const ValueKey('architect-3d-back-to-plan')),
          findsOneWidget,
        );
        expect(find.text(l10n.architectView3D), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('architect-workspace-back')));
        await tester.pumpAndSettle();
        expect(find.byType(Architect3dViewport), findsNothing);
        expect(find.byType(ArchitectWorkspaceScreen), findsOneWidget);

        // 2) Open 3D -> Android/system Back returns directly to Plan.
        await tester.tap(find.byKey(const ValueKey('architect-view-3d')));
        await tester.pumpAndSettle();
        expect(find.byType(Architect3dViewport), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(Architect3dViewport), findsNothing);
        expect(find.byType(ArchitectWorkspaceScreen), findsOneWidget);

        // 3) Open 3D -> floating 2D Plan button in 3D canvas returns to Plan.
        await tester.tap(find.byKey(const ValueKey('architect-view-3d')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-3d-back-to-plan')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Architect3dViewport), findsNothing);

        // 4) Open 3D -> 1-tap Plan tab in view bar returns straight to Plan without opening popup menu.
        await tester.tap(find.byKey(const ValueKey('architect-view-3d')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('architect-view-plan')));
        await tester.pumpAndSettle();
        expect(find.byType(Architect3dViewport), findsNothing);
        expect(find.byType(CheckedPopupMenuItem<String>), findsNothing);

        // 5) Open Section -> 1-tap Plan tab & top-left Back both return to Plan.
        await tester.tap(find.byKey(const ValueKey('architect-view-section')));
        await projection.settleProjection(tester);
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is CheckedPopupMenuItem<String> && w.value == 'sec1',
          ),
        );
        await projection.settleProjection(tester);
        expect(
          tester
              .widget<ArchitectWorkspaceViewBar>(
                find.byType(ArchitectWorkspaceViewBar),
              )
              .view
              .name,
          'section',
        );

        await tester.tap(find.byKey(const ValueKey('architect-workspace-back')));
        await projection.settleProjection(tester);
        expect(
          tester
              .widget<ArchitectWorkspaceViewBar>(
                find.byType(ArchitectWorkspaceViewBar),
              )
              .view
              .name,
          'plan',
        );
        expect(find.byType(ArchitectWorkspaceScreen), findsOneWidget);

        // 6) Open Elevation -> 1-tap Plan tab returns directly to Plan.
        await tester.tap(find.byKey(const ValueKey('architect-view-elevation')));
        await projection.settleProjection(tester);
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is CheckedPopupMenuItem<String> && w.value == 'e1',
          ),
        );
        await projection.settleProjection(tester);
        await tester.tap(find.byKey(const ValueKey('architect-view-plan')));
        await projection.settleProjection(tester);
        expect(
          tester
              .widget<ArchitectWorkspaceViewBar>(
                find.byType(ArchitectWorkspaceViewBar),
              )
              .view
              .name,
          'plan',
        );

        // 7) On Plan -> Back asks Exit confirmation mentioning automatic save.
        await tester.tap(find.byKey(const ValueKey('architect-workspace-back')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('architect-exit-project-dialog')),
          findsOneWidget,
        );
        expect(find.text(l10n.architectExitProjectTitle), findsOneWidget);
        expect(find.text(l10n.architectExitProjectMessage), findsOneWidget);

        // Cancel stays in workspace.
        await tester.tap(
          find.byKey(const ValueKey('architect-exit-project-cancel')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectWorkspaceScreen), findsOneWidget);

        // System Back also prompts; Confirm pops back to launcher.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('architect-exit-project-dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-exit-project-confirm')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectWorkspaceScreen), findsNothing);
        expect(find.byKey(const ValueKey('open-workspace')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Unattached scratch workspace shows unattached exit prompt and Print Preview Back returns to Plan',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await _pushWorkspace(tester, controller);
      final l10n = lookupAppLocalizations(const Locale('en'));

      // Toggle Print Preview from compact sheets menu -> Back returns to Plan canvas.
      await tester.tap(find.byKey(const ValueKey('architect-model-sheets')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.architectPrintPreview));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ArchitectWorkspaceViewBar>(
              find.byType(ArchitectWorkspaceViewBar),
            )
            .isPrintPreview,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('architect-workspace-back')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ArchitectWorkspaceViewBar>(
              find.byType(ArchitectWorkspaceViewBar),
            )
            .isPrintPreview,
        isFalse,
      );
      expect(find.byType(ArchitectWorkspaceScreen), findsOneWidget);

      // Now Back prompts unattached exit confirmation and pops on confirm.
      await tester.tap(find.byKey(const ValueKey('architect-workspace-back')));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.architectExitProjectUnattachedMessage),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('architect-exit-project-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectWorkspaceScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
