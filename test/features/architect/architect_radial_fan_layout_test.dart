import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/core/services/ui_settings_service.dart';
import 'package:kotoview/src/features/bim_editing/models/bim_context_menu_settings.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => UiSettingsService.contextMenu.value = const BimContextMenuSettings(),
  );
  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final mode in BimContextMenuMode.values) {
    test(
      'Fixed $mode slots retain relative positions at every screen edge',
      () {
        for (final size in [
          const Size(320, 420),
          const Size(360, 640),
          const Size(640, 140),
          const Size(1000, 760),
        ]) {
          List<Offset>? reference;
          for (final point in [
            Offset.zero,
            Offset(size.width, 0),
            Offset(0, size.height),
            Offset(size.width, size.height),
            size.center(Offset.zero),
          ]) {
            final layout = ArchitectRadialLayout.compute(
              size: size,
              center: point,
              mode: mode,
              hasTitle: true,
            );
            expect(layout.targets, hasLength(8));
            expect(layout.buttonSize, 52);
            final offsets = layout.targets
                .map((p) => p - layout.moreTarget)
                .toList();
            reference ??= offsets;
            for (var i = 0; i < offsets.length; i++) {
              expect((offsets[i] - reference[i]).distance, lessThan(1e-7));
            }
            final available = Rect.fromLTWH(
              0,
              0,
              size.width,
              layout.contentHeight,
            );
            final rects = [
              for (final p in [...layout.targets, layout.moreTarget])
                Rect.fromCenter(
                  center: p,
                  width: layout.buttonSize,
                  height: layout.buttonSize,
                ),
            ];
            for (var i = 0; i < rects.length; i++) {
              expect(
                available.contains(rects[i].topLeft) &&
                    available.contains(rects[i].bottomRight),
                isTrue,
              );
              expect(rects[i].overlaps(layout.badge), isFalse);
              for (final r in rects.skip(i + 1)) {
                expect(rects[i].overlaps(r), isFalse);
              }
            }
          }
        }
      },
    );
    for (final language in ['bg', 'en']) {
      testWidgets(
        'Every action is reachable on fixed $mode pages ($language)',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final l = await AppLocalizations.delegate.load(Locale(language));
          final boundary = GlobalKey();
          BimEditAction? selected;
          final settings = BimContextMenuSettings(mode: mode);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                  body: ArchitectRadialMenu(
                    settings: settings,
                    center: const Offset(310, 620),
                    title: l.architectToolSlab,
                    items: [
                      for (final action in BimEditAction.values)
                        ArchitectRadialMenuItem(
                          action: action,
                          icon: BimEditActions.icon(action),
                          label: BimEditActions.label(action, l),
                          color: Colors.cyan,
                        ),
                    ],
                    onActionSelected: (a) => selected = a,
                    onDismiss: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var p = 0; p < settings.pages.length; p++) {
            for (final action in settings.pages[p].whereType<BimEditAction>()) {
              final button = find.byKey(
                ValueKey('architect-radial-${action.name}'),
              );
              final rect = tester.getRect(button);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(320));
              await tester.tap(button);
              await tester.pump();
              expect(selected, action);
            }
            await tester.tap(
              find.byKey(const ValueKey('architect-radial-more')),
            );
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('build/architect_fixed_menu')
              ..createSync(recursive: true);
            File(
              '${folder.path}/${mode.name}-$language.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        },
      );
    }
  }
  testWidgets(
    'Unavailable actions keep their slots and cannot execute; preferences update live',
    (tester) async {
      var hits = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArchitectRadialMenu(
              center: const Offset(250, 250),
              items: const [
                ArchitectRadialMenuItem(
                  action: BimEditAction.move,
                  icon: Icons.open_with,
                  label: 'Move',
                  color: Colors.cyan,
                ),
              ],
              onActionSelected: (_) => hits++,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final move = find.byKey(const ValueKey('architect-radial-move'));
      final rotate = find.byKey(const ValueKey('architect-radial-rotate'));
      final before = tester.getRect(move);
      await tester.tap(rotate);
      expect(hits, 0);
      await tester.tap(move);
      expect(hits, 1);
      expect(tester.getRect(move), before);
      UiSettingsService.contextMenu.value = const BimContextMenuSettings(
        mode: BimContextMenuMode.grid,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(move), isNot(before));
      expect(
        find.byKey(const ValueKey('architect-radial-rotate')),
        findsOneWidget,
      );
    },
  );
  testWidgets('Short viewports scroll a complete fixed menu', (tester) async {
    tester.view.physicalSize = const Size(320, 140);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchitectRadialMenu(
            center: const Offset(160, 70),
            items: const [],
            onActionSelected: (_) {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('architect-radial-scroll')),
      findsOneWidget,
    );
    final more = find.byKey(const ValueKey('architect-radial-more'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
