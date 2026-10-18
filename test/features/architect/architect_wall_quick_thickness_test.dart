import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_type_label.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';
import 'architect_editing_test.dart' as editing;

void main() {
  for (final language in ['en', 'bg']) {
    testWidgets(
      'Quick thickness saves only the selected wall and supports cancel/undo ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final a = editing.wall(
          'a',
          Offset.zero,
          const Offset(4, 0),
          exterior: true,
        );
        final b = editing.wall(
          'b',
          const Offset(0, 4),
          const Offset(4, 4),
          exterior: true,
        );
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: '', walls: [a, b]),
        );
        model.restore(
          model.project.copyWith(
            units: ArchitectUnit.centimeters,
            distanceDecimals: 0,
          ),
        );
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();
        await editing.contextHold(tester, const Offset(2, 0));
        final action = find.byKey(const ValueKey('architect-wall-thickness'));
        expect(action, findsOneWidget);
        expect(find.text('d=37 cm'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('architect-wall-straighten')),
          findsNothing,
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        final core = find.byKey(const ValueKey('architect-wall-core-input'));
        final insulation = find.byKey(
          const ValueKey('architect-wall-insulation-input'),
        );
        await tester.enterText(core, '30');
        await tester.enterText(insulation, '15,5');
        final l = AppLocalizations.of(tester.element(core))!;
        await tester.tap(find.text(l.cancel));
        await tester.pumpAndSettle();
        expect(model.canUndo, isFalse);
        expect(model.project.activeStorey.walls.first.thickness, .37);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.enterText(core, '0');
        await tester.tap(
          find.byKey(const ValueKey('architect-wall-thickness-save')),
        );
        await tester.pumpAndSettle();
        expect(model.canUndo, isFalse);
        expect(find.text(l.architectWallInvalidThickness), findsOneWidget);
        await tester.enterText(core, '30');
        await tester.enterText(insulation, '15,5');
        await tester.tap(
          find.byKey(const ValueKey('architect-wall-thickness-save')),
        );
        await tester.pumpAndSettle();
        expect(
          model.project.activeStorey.walls.first.thickness,
          closeTo(.455, 1e-9),
        );
        expect(
          model.project.activeStorey.walls.first.coreThickness,
          closeTo(.30, 1e-9),
        );
        expect(model.project.activeStorey.walls.last.thickness, .37);
        expect(model.undoCount, 1);
        model.undo();
        expect(model.project.activeStorey.walls.first.thickness, .37);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'Preset picker labels are short and retain material distinctions',
    () async {
      for (final language in ['en', 'bg']) {
        final l = await AppLocalizations.delegate.load(Locale(language));
        final types = ArchitectWallType.standardCatalog();
        expect(types[0].compactLabel(l), '25+12');
        expect(types[1].compactLabel(l), '12');
        expect(types[2].compactLabel(l), '25');
        expect(types[3].compactLabel(l), isNot('25'));
        expect(
          types[0].copyWith(brickThickness: .255).compactLabel(l),
          '25.5+12',
        );
        expect(
          types[0]
              .copyWith(id: 'custom', name: 'My named wall')
              .compactLabel(l),
          'My named wall',
        );
        expect(
          BimEditActions.icon(BimEditAction.newPoint),
          isNot(Icons.add_location_alt_outlined),
        );
      }
    },
  );
}
