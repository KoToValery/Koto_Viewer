import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_layer_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_layers_dialog.dart';

const _layers = [
  ArchitectLayer(
    id: ArchitectLayer.wallLayerId,
    name: 'A-WALL',
    isStandard: true,
  ),
  ArchitectLayer(id: 'z', name: 'Zulu', visible: false),
  ArchitectLayer(
    id: ArchitectLayer.doorLayerId,
    name: 'A-DOOR',
    isStandard: true,
  ),
  ArchitectLayer(id: 'a', name: 'Alpha'),
  ArchitectLayer(
    id: ArchitectLayer.beamLayerId,
    name: 'S-BEAM',
    isStandard: true,
  ),
];

List<String> _rowIds(WidgetTester tester) => tester
    .widgetList<ListTile>(
      find.descendant(
        of: find.byType(ArchitectLayersDialog),
        matching: find.byType(ListTile),
      ),
    )
    .map((row) => (row.key! as ValueKey<String>).value)
    .toList();

AppIconId _visibilityIcon(WidgetTester tester, String id) => tester
    .widgetList<AppIcon>(
      find.descendant(
        of: find.byKey(ValueKey(id)),
        matching: find.byType(AppIcon),
      ),
    )
    .single
    .id;

Future<void> _toggle(WidgetTester tester, String id) async {
  await tester.tap(
    find
        .descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byType(IconButton),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final type in [
    ArchitectWorkspaceView.elevation,
    ArchitectWorkspaceView.section,
  ]) {
    test(
      'Layer changes in $type reach the model, shared history and storage',
      () {
        final source = ArchitectCommandController(
          ArchitectProject.starter(name: 'Layers').copyWith(
            layers: _layers,
            elevations: const [
              ArchitectElevation(
                id: 'view',
                start: Offset.zero,
                end: Offset(5, 0),
              ),
            ],
            sections: const [
              ArchitectSection(
                id: 'view',
                start: Offset.zero,
                end: Offset(5, 0),
              ),
            ],
          ),
        );
        final view = ArchitectWorkspaceViewController(source);
        addTearDown(source.dispose);
        addTearDown(view.dispose);
        final originalFloors = source.project.storeys;
        view.select(type, 'view');
        view.commit(
          view.project.copyWith(
            layers: [
              for (final layer in view.project.effectiveLayers)
                layer.id == 'a' ? layer.copyWith(visible: false) : layer,
            ],
            elementLayers: const {'annotation': 'a'},
          ),
        );
        expect(
          source.project.effectiveLayers
              .firstWhere((layer) => layer.id == 'a')
              .visible,
          isFalse,
        );
        expect(source.project.elementLayers['annotation'], 'a');
        expect(source.project.storeys, originalFloors);
        expect(source.undoCount, 1);
        view.undo();
        expect(
          view.project.effectiveLayers
              .firstWhere((layer) => layer.id == 'a')
              .visible,
          isTrue,
        );
        expect(source.project.elementLayers, isEmpty);
        view.redo();
        final restored = ArchitectProject.fromJson(source.project.toJson());
        expect(
          restored.effectiveLayers
              .firstWhere((layer) => layer.id == 'a')
              .visible,
          isFalse,
        );
        expect(restored.elementLayers['annotation'], 'a');
      },
    );
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final l = lookupAppLocalizations(locale);
    final visibleOrder = locale.languageCode == 'bg'
        ? [
            'a',
            ArchitectLayer.doorLayerId,
            ArchitectLayer.beamLayerId,
            ArchitectLayer.wallLayerId,
          ]
        : [
            'a',
            ArchitectLayer.beamLayerId,
            ArchitectLayer.doorLayerId,
            ArchitectLayer.wallLayerId,
          ];

    test(
      'Layer order uses displayed names in $locale without changing storage',
      () {
        final sorted = ArchitectLayer.sortedForDisplay(_layers, l);
        expect(sorted.map((layer) => layer.id), ['z', ...visibleOrder]);
        expect(_layers.first.id, ArchitectLayer.wallLayerId);
        final hidden = _layers.map((layer) => layer.copyWith(visible: false));
        expect(
          ArchitectLayer.sortedForDisplay(hidden, l).map((layer) => layer.id),
          locale.languageCode == 'bg'
              ? [
                  'a',
                  'z',
                  ArchitectLayer.doorLayerId,
                  ArchitectLayer.beamLayerId,
                  ArchitectLayer.wallLayerId,
                ]
              : [
                  'a',
                  ArchitectLayer.beamLayerId,
                  ArchitectLayer.doorLayerId,
                  ArchitectLayer.wallLayerId,
                  'z',
                ],
        );
      },
    );

    testWidgets(
      'Phone layer menu updates every operation immediately in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final commands = ArchitectCommandController(
          ArchitectProject.starter(name: 'Layers').copyWith(layers: _layers),
        );
        addTearDown(commands.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: commands),
          ),
        );
        await tester.pumpAndSettle();

        final symbols = <AppIconId>[];
        for (final key in [
          'architect-layers',
          'architect-model-sheets',
          'architect-ghost-storeys',
        ]) {
          symbols.add(
            tester
                .widget<AppIcon>(
                  find.descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(AppIcon),
                  ),
                )
                .id,
          );
        }
        expect(symbols, [
          AppIconId.layers,
          AppIconId.sheets,
          AppIconId.ghostStoreys,
        ]);

        await tester.tap(find.byKey(const ValueKey('architect-layers')));
        await tester.pumpAndSettle();
        expect(_rowIds(tester).take(2), ['z', 'a']);
        expect(_visibilityIcon(tester, 'a'), AppIconId.visible);

        await _toggle(tester, 'a');
        expect(_visibilityIcon(tester, 'a'), AppIconId.hidden);
        expect(_rowIds(tester).take(2).toSet(), {'z', 'a'});
        expect(
          commands.project.effectiveLayers
              .firstWhere((layer) => layer.id == 'a')
              .visible,
          isFalse,
        );
        commands.undo();
        await tester.pumpAndSettle();
        expect(_visibilityIcon(tester, 'a'), AppIconId.visible);
        expect(_rowIds(tester).take(2), ['z', 'a']);
        commands.redo();
        await tester.pumpAndSettle();
        expect(_visibilityIcon(tester, 'a'), AppIconId.hidden);

        await tester.tap(find.byTooltip(l.architectAllLayersVisible));
        await tester.pumpAndSettle();
        expect(
          commands.project.effectiveLayers.every((layer) => layer.visible),
          isTrue,
        );
        expect(_visibilityIcon(tester, 'a'), AppIconId.visible);
        await _toggle(tester, 'a');
        expect(_rowIds(tester).first, 'a');
        await _toggle(tester, 'a');
        expect(_visibilityIcon(tester, 'a'), AppIconId.visible);

        await tester.tap(find.text(l.architectNewLayer));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Beta');
        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();
        expect(find.text('Beta'), findsOneWidget);
        final created = commands.project.effectiveLayers.firstWhere(
          (layer) => layer.name == 'Beta',
        );
        expect(
          _rowIds(tester).indexOf(created.id),
          greaterThan(_rowIds(tester).indexOf('a')),
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(ValueKey(created.id)),
            matching: find.byTooltip(l.architectDeleteLayer),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Beta'), findsNothing);
        commands.undo();
        await tester.pumpAndSettle();
        expect(find.text('Beta'), findsOneWidget);
        expect(
          ArchitectProject.fromJson(
            commands.project.toJson(),
          ).effectiveLayers.any((layer) => layer.id == created.id),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l.close));
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectLayersDialog), findsNothing);
      },
    );

    testWidgets(
      'Element layer picker shares the localized hidden-first order in $locale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showArchitectElementLayerPicker(
                    context,
                    project: ArchitectProject.starter(
                      name: 'Layers',
                    ).copyWith(layers: _layers),
                    currentLayerId: ArchitectLayer.wallLayerId,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final names = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((tile) => (tile.title! as Text).data);
        final expected = ArchitectLayer.sortedForDisplay(
          ArchitectProject.starter(
            name: 'Layers',
          ).copyWith(layers: _layers).effectiveLayers,
          l,
        ).map((layer) => layer.localizedName(l));
        expect(names, expected.take(names.length));
        expect(names.first, 'Zulu');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
