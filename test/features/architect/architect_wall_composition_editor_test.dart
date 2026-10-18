import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_composition_editor.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_wall_compositions_test.dart' as data;

void main() {
  for (final language in ['en', 'bg'])
    for (final dark in [false, true]) {
      testWidgets(
        'Layer editor on a 360px phone: validation, exact thin layers, save ($language $dark)',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = data
              .project([])
              .copyWith(units: ArchitectUnit.centimeters, distanceDecimals: 0);
          ArchitectWallType? saved;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => ArchitectWallCompositionEditor(
                        project: p,
                        type: data.composition,
                        plinth: const ArchitectWallPlinth(),
                        onApply: (value, _, _) {
                          saved = value;
                          return true;
                        },
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final input = find.byKey(
            const ValueKey('wall-layer-thickness-render'),
          );
          await tester.ensureVisible(input);
          await tester.enterText(input, 'NaN');
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
          await tester.pumpAndSettle();
          expect(saved, isNull);
          expect(tester.takeException(), isNull);
          await tester.enterText(input, '0,75');
          await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
          await tester.pumpAndSettle();
          expect(saved, isNotNull);
          expect(saved!.layers.first.thickness, .0075);
          expect(saved!.layers.last.thickness, .015);
          expect(tester.takeException(), isNull);
        },
      );
    }
  testWidgets(
    'Mixed plinth fields remain independent when one field is changed',
    (tester) async {
      const a = ArchitectWallPlinth(
            enabled: true,
            height: .5,
            finish: ArchitectMaterial.stone,
          ),
          b = ArchitectWallPlinth(
            enabled: true,
            height: .8,
            finish: ArchitectMaterial.tile,
          );
      ArchitectWallPlinthPatch? patch;
      bool? compositionChanged;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ArchitectWallCompositionEditor(
                    project: data.project([]),
                    type: data.composition,
                    plinth: a,
                    plinths: const [a, b],
                    onApply: (_, value, changed) {
                      patch = value;
                      compositionChanged = changed;
                      return true;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final h = find.byKey(const ValueKey('wall-plinth-height'));
      await tester.ensureVisible(h);
      await tester.enterText(h, '0.65');
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      expect(compositionChanged, isFalse);
      expect(patch!.apply(a).height, .65);
      expect(patch!.apply(b).height, .65);
      expect(patch!.apply(a).finish, ArchitectMaterial.stone);
      expect(patch!.apply(b).finish, ArchitectMaterial.tile);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Selected-wall composition and the short plinth dialog each create one Undo',
    (tester) async {
      final a = data.wall('a', Offset.zero, const Offset(4, 0)),
          b = data.wall('b', const Offset(0, 3), const Offset(4, 3));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [a, b]),
      );
      addTearDown(model.dispose);
      model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: model),
        ),
      );
      await tester.pumpAndSettle();
      await editing.contextHold(tester, const Offset(2, 0));
      await tester.tap(find.byKey(const ValueKey('architect-wall-thickness')));
      await tester.pumpAndSettle();
      final eps = find.byKey(const ValueKey('wall-layer-thickness-eps'));
      await tester.ensureVisible(eps);
      await tester.enterText(eps, '15');
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls.first.insulationThickness, .15);
      expect(model.project.activeStorey.walls.last.insulationThickness, .12);
      expect(model.undoCount, 1);
      await editing.contextHold(tester, const Offset(2, 0));
      await tester.tap(find.text('Properties'));
      await tester.pumpAndSettle();
      final plinth = find.byKey(
        const ValueKey('architect-property-wall-plinth'),
      );
      await tester.ensureVisible(plinth);
      await tester.tap(plinth);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-plinth-enabled')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('wall-plinth-height')),
        '65',
      );
      await tester.tap(find.byKey(const ValueKey('wall-plinth-save')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls.first.plinth.height, .65);
      expect(model.project.activeStorey.walls.first.plinth.enabled, isTrue);
      expect(model.project.activeStorey.walls.last.plinth.enabled, isFalse);
      expect(model.undoCount, 2);
      model.undo();
      expect(model.project.activeStorey.walls.first.plinth.enabled, isFalse);
      expect(model.project.activeStorey.walls.first.insulationThickness, .15);
      model.undo();
      expect(model.project.activeStorey.walls.first.insulationThickness, .12);
      expect(tester.takeException(), isNull);
    },
  );
}
