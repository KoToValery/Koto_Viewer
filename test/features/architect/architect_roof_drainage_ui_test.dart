import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layers_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_component_library_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_roof_drainage_test.dart' as fixture;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUpAll(qa.loadQaFonts);
  testWidgets(
    'library placement uses the picked eaves position and one undo step',
    (tester) async {
      final model = ArchitectCommandController(
        fixture.drainageProject(bay: true),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      final l = AppLocalizations.of(
        tester.element(find.byType(ArchitectToolPalette)),
      )!;
      Future<void> begin() async {
        tester
            .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
            .onOpenComponentLibrary!();
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.architectDrainageSmart));
        await tester.pumpAndSettle();
      }

      await begin();
      expect(find.text(l.architectDrainagePrompt), findsOneWidget);
      await tester.tapAt(workspace.screen(tester, const Offset(3.5, 2)));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.roofs.single.drainage.downpipes.length,
        1,
      );
      await tester.tapAt(workspace.screen(tester, const Offset(3.5, 0)));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.roofs.single.drainage.downpipes.length,
        2,
      );
      expect(
        model.project.activeStorey.roofs.single.drainage.downpipes.last.offset,
        closeTo(3.5, .001),
      );
      expect(find.text(l.architectDrainagePrompt), findsNothing);
      model.undo();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.roofs.single.drainage.downpipes.length,
        1,
      );
      model.redo();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.roofs.single.drainage.downpipes.length,
        2,
      );
      await begin();
      await tester.tapAt(workspace.screen(tester, Offset.zero));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.roofs.single.drainage.downpipes.length,
        3,
      );
      expect(
        model.project.activeStorey.roofs.single.drainage.downpipes.last.offset,
        closeTo(.061, .001),
      );
      model.undo();
      await tester.pumpAndSettle();
      await begin();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(l.architectDrainagePrompt), findsNothing);
      expect(
        model.project.activeStorey.roofs.single.drainage.downpipes.length,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['bg', 'en']) {
    testWidgets(
      'phone drainage settings save, validate and reopen ($language)',
      (tester) async {
        await qa.phone(tester);
        final capture = GlobalKey();
        final project = fixture.drainageProject(bay: true);
        var roof = project.activeStorey.roofs.single;
        var applied = 0;
        await tester.pumpWidget(
          qa.host(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ArchitectRoofLayersDialog(
                      initialAssembly: roof.assembly,
                      initialSlopeDegrees: roof.slopeDegrees,
                      initialEavesOverhang: roof.eavesOverhang,
                      initialEavesCut: roof.eavesCut,
                      initialDrainage: roof.drainage,
                      project: project,
                      roof: roof,
                      onApply: (result) {
                        roof = roof.copyWith(drainage: result.drainage);
                        applied++;
                      },
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
            language,
            capture,
          ),
        );
        final l = AppLocalizations.of(tester.element(find.text('Open')))!;
        Future<void> open() async {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.architectDrainageTitle));
          await tester.pumpAndSettle();
        }

        await open();
        expect(find.text(l.architectDrainageGutter), findsOneWidget);
        final width = find.widgetWithText(
          TextFormField,
          l.architectDrainageWidth,
        );
        await tester.ensureVisible(width);
        await tester.enterText(width, '0');
        await tester.tap(find.byKey(const ValueKey('roof-layers-apply')));
        await tester.pumpAndSettle();
        expect(applied, 0);
        await tester.enterText(width, '18');
        await tester.pumpAndSettle();
        final pipe = find.text('${l.architectDrainagePipe} 1');
        await tester.ensureVisible(pipe);
        await tester.tap(pipe);
        await tester.pumpAndSettle();
        final offset = find.widgetWithText(
          TextFormField,
          l.architectDrainageOffset,
        );
        await tester.enterText(offset, '2,5');
        await tester.tap(find.widgetWithText(FilledButton, l.save).last);
        await tester.pumpAndSettle();
        expect(find.text(l.architectDrainageReady), findsOneWidget);
        await qa.capturePhone(tester, capture, 'drainage-$language');
        await tester.tap(find.byKey(const ValueKey('roof-layers-apply')));
        await tester.pumpAndSettle();
        expect(applied, 1);
        expect(roof.drainage.gutterWidth, closeTo(.18, 1e-8));
        expect(roof.drainage.downpipes.single.offset, 2.5);
        await open();
        expect(find.text(l.architectDrainageGutter), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('library smart downpipe invokes the same placement action', (
    tester,
  ) async {
    await qa.phone(tester);
    var placed = 0;
    await tester.pumpWidget(
      qa.host(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ArchitectComponentLibraryDialog.show(
                context,
                onSelectDownpipe: () => placed++,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        'bg',
        GlobalKey(),
      ),
    );
    final l = AppLocalizations.of(tester.element(find.text('Open')))!;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.architectDrainageSmart));
    await tester.pumpAndSettle();
    expect(placed, 1);
    expect(find.byType(ArchitectComponentLibraryDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
