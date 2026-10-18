import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  for (final language in ['bg', 'en']) {
    testWidgets(
      'Three-point arc, exact R, cancel and one Undo on a phone ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = editing.seeded(const ArchitectStorey(id: 's', name: ''));
        addTearDown(model.dispose);
        model.restore(
          model.project.copyWith(
            units: ArchitectUnit.centimeters,
            distanceDecimals: 0,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();
        await editing.selectTool(tester, 'wall');
        if (language == 'bg') {
          final arc = find.byKey(const ValueKey('architect-wall-arc-mode'));
          await tester.ensureVisible(arc);
          await tester.tap(arc);
        } else {
          await tester.tap(find.byKey(const ValueKey('wall-arc-toggle')));
        }
        await tester.pumpAndSettle();
        await tester.tapAt(workspace.screen(tester, const Offset(-1.5, 0)));
        await tester.pumpAndSettle();
        await tester.tapAt(workspace.screen(tester, const Offset(1.5, 0)));
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls, isEmpty);
        await tester.tap(find.byKey(const ValueKey('wall-arc-radius')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('wall-arc-radius-input')),
          '200',
        );
        final l = AppLocalizations.of(
          tester.element(find.byKey(const ValueKey('wall-arc-radius-input'))),
        )!;
        await tester.tap(find.text(l.applyAction));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-arc-confirm')));
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls.length, 1);
        final wall = model.project.activeStorey.walls.single;
        expect(wall.isCurved, isTrue);
        expect(wall.arc!.radius, closeTo(2, .000001));
        expect(model.undoCount, 1);
        final changed = SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {wall.id},
          values: {'arcRadius': 2.5},
        ).apply(model.project);
        expect(
          changed.activeStorey.walls.single.arc!.radius,
          closeTo(2.5, .000001),
        );
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls, isEmpty);
        await tester.tapAt(workspace.screen(tester, const Offset(-1.5, 0)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-stop-drawing')));
        await tester.pumpAndSettle();
        expect(model.canUndo, isFalse);
        expect(model.project.activeStorey.walls, isEmpty);
        for (final p in [
          const Offset(-1.5, 0),
          const Offset(1.5, 0),
          const Offset(0, 1),
        ]) {
          await tester.tapAt(workspace.screen(tester, p));
          await tester.pumpAndSettle();
        }
        expect(
          model.project.activeStorey.walls.single.arc!.radius,
          closeTo(1.625, .000001),
        );
        expect(model.undoCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
