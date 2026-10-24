import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/core/services/ui_settings_service.dart';
import 'package:kotoview/src/core/widgets/app_settings_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'package:kotoview/src/features/bim_editing/models/bim_context_menu_settings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UiSettingsService.contextMenu.value = const BimContextMenuSettings();
  });
  tearDown(
    () => UiSettingsService.contextMenu.value = const BimContextMenuSettings(),
  );
  test(
    'Default circle, custom combinations and mode survive restart',
    () async {
      await UiSettingsService.init();
      expect(
        UiSettingsService.contextMenu.value.mode,
        BimContextMenuMode.circle,
      );
      final custom = BimContextMenuPreset(
        id: 'mine',
        name: 'Моя подредба',
        mode: BimContextMenuMode.grid,
        slots: const [
          BimEditAction.cut,
          null,
          BimEditAction.newPoint,
          BimEditAction.move,
          BimEditAction.delete,
          BimEditAction.rename,
          BimEditAction.duplicate,
          BimEditAction.cutOpening,
        ],
      );
      final settings = const BimContextMenuSettings().savePreset(custom);
      await UiSettingsService.save(settings);
      UiSettingsService.contextMenu.value = const BimContextMenuSettings();
      await UiSettingsService.init();
      final loaded = UiSettingsService.contextMenu.value;
      expect(jsonEncode(loaded.toJson()), jsonEncode(settings.toJson()));
      expect(
        loaded.pages.expand((p) => p).whereType<BimEditAction>().toSet(),
        BimEditAction.values.toSet(),
      );
      expect(
        loaded.pages.expand((p) => p).whereType<BimEditAction>(),
        hasLength(BimEditAction.values.length),
      );
      expect(loaded.select('mine').mode, BimContextMenuMode.grid);
      expect(loaded.deletePreset('mine').selectedPresetId, 'default');
      expect(loaded.deletePreset('mine').presets, isEmpty);
    },
  );
  test(
    'Damaged settings and duplicate or unknown slots recover safely',
    () async {
      SharedPreferences.setMockInitialValues({
        UiSettingsService.preferenceKey: '{bad json',
      });
      await UiSettingsService.init();
      expect(
        UiSettingsService.contextMenu.value.mode,
        BimContextMenuMode.circle,
      );
      final settings = BimContextMenuSettings.fromJson({
        'mode': 'unknown',
        'selectedPresetId': 'custom',
        'presets': [
          {
            'id': 'custom',
            'name': 'Work',
            'mode': 'grid',
            'slots': ['move', 'move', 'missing', null, 'delete'],
          },
          {'id': 'broken'},
          {'id': 'default', 'name': 'Cannot replace built-in'},
        ],
      });
      expect(settings.mode, BimContextMenuMode.circle);
      expect(settings.slots, [
        BimEditAction.move,
        null,
        null,
        null,
        BimEditAction.delete,
        null,
        null,
        null,
      ]);
      expect(
        settings.pages.expand((p) => p).whereType<BimEditAction>(),
        hasLength(BimEditAction.values.length),
      );
    },
  );
  for (final language in ['bg', 'en']) {
    testWidgets(
      'Phone UI settings create, edit, reload and delete a named combination ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  key: const ValueKey('open-settings'),
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute<void>(
                      builder: (_) => const AppSettingsScreen(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.byKey(const ValueKey('open-settings')));
          await tester.pumpAndSettle();
        }

        await open();
        expect(
          find.byKey(const ValueKey('settings-ui-category')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('context-menu-mode-circle')),
        );
        await tester.pumpAndSettle();
        final l = await AppLocalizations.delegate.load(Locale(language));
        await tester.tap(find.text(l.contextMenuGrid).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('context-menu-new')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('context-menu-preset-name')),
          'My tools',
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-radial-move')).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('context-menu-choose-rotate')),
        );
        await tester.pumpAndSettle();
        final swapped = tester
            .widget<ArchitectRadialMenu>(find.byType(ArchitectRadialMenu).last)
            .settings!
            .slots;
        expect(swapped.first, BimEditAction.rotate);
        expect(swapped[1], BimEditAction.move);
        await tester.tap(
          find.byKey(const ValueKey('architect-radial-rotate')).last,
        );
        await tester.pumpAndSettle();
        final cut = find.byKey(const ValueKey('context-menu-choose-cut'));
        await tester.ensureVisible(cut);
        await tester.pumpAndSettle();
        await tester.tap(cut);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('context-menu-preset-save')),
        );
        await tester.pumpAndSettle();
        expect(find.text('My tools'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('app-settings-save')));
        await tester.pumpAndSettle();
        await UiSettingsService.init();
        expect(
          UiSettingsService.contextMenu.value.mode,
          BimContextMenuMode.grid,
        );
        expect(
          UiSettingsService.contextMenu.value.slots.first,
          BimEditAction.cut,
        );
        await open();
        await tester.tap(find.byKey(const ValueKey('context-menu-edit')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('context-menu-preset-name')),
          'Renamed',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('context-menu-preset-save')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('app-settings-save')));
        await tester.pumpAndSettle();
        await UiSettingsService.init();
        expect(
          UiSettingsService.contextMenu.value.presets.single.name,
          'Renamed',
        );
        await open();
        await tester.tap(
          find.byKey(const ValueKey('context-menu-delete-preset')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('app-settings-save')));
        await tester.pumpAndSettle();
        await UiSettingsService.init();
        expect(UiSettingsService.contextMenu.value.presets, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
