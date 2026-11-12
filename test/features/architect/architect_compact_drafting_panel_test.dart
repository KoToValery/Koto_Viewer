import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_distance_drafting_panel.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

const captureKey = ValueKey('compact-drafting-capture');
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_COMPACT_DRAFTING')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File(
      '.dart_tool/compact-drafting-$name.png',
    ).writeAsBytes(data.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
  });
  for (final language in ['bg', 'en']) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 360.0]) {
        testWidgets(
          'Compact value and actions stay usable $language $brightness $width',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            double value = 3.25;
            var next = 0;
            var end = 0;
            var cancel = 0;
            await tester.pumpWidget(
              RepaintBoundary(
                key: captureKey,
                child: MaterialApp(
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: ThemeData(
                    brightness: brightness,
                    fontFamily: 'Roboto',
                  ),
                  home: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: width - 16,
                        child: BimDistanceDraftingPanel(
                          length: 3.25,
                          unit: 'm',
                          onLength: (v) => value = v,
                          onContinue: () => next++,
                          onEnd: () => end++,
                          onCancel: () => cancel++,
                          onUnlock: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final panel = find.byKey(const ValueKey('bim-distance-panel'));
            expect(tester.getSize(panel).height, lessThanOrEqualTo(64));
            expect(find.byKey(const ValueKey('wall-key-0')), findsNothing);
            for (final key in [
              'wall-length-input',
              'wall-continue',
              'wall-end',
              'wall-cancel',
              'wall-direction-unlock',
            ]) {
              final finder = find.byKey(ValueKey(key));
              final rect = tester.getRect(finder);
              expect(rect.height, greaterThanOrEqualTo(44));
              expect(rect.width, greaterThanOrEqualTo(44));
              expect(finder.hitTestable(), findsOneWidget);
              expect(rect.right, lessThanOrEqualTo(width));
            }
            await capture(
              tester,
              'row-$language-${brightness.name}-${width.toInt()}',
            );
            await tester.tap(find.byKey(const ValueKey('wall-length-input')));
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('wall-key-0')), findsOneWidget);
            expect(find.byType(EditableText), findsNothing);
            for (final key in ['4', '.', '2']) {
              await tester.tap(find.byKey(ValueKey('wall-key-$key')));
              await tester.pump();
            }
            expect(value, 4.2);
            await capture(
              tester,
              'keypad-$language-${brightness.name}-${width.toInt()}',
            );
            await tester.tap(find.byKey(const ValueKey('wall-continue')));
            expect(next, 1);
            await tester.tap(find.byKey(const ValueKey('wall-end')));
            expect(end, 1);
            for (var i = 0; i < 3; i++) {
              await tester.tap(find.byKey(const ValueKey('wall-key-⌫')));
              await tester.pump();
            }
            expect(
              tester
                  .widget<IconButton>(
                    find.byKey(const ValueKey('wall-continue')),
                  )
                  .onPressed,
              isNull,
            );
            expect(
              tester
                  .widget<FilledButton>(find.byKey(const ValueKey('wall-end')))
                  .onPressed,
              isNull,
            );
            await tester.tap(find.byKey(const ValueKey('wall-cancel')));
            expect(cancel, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    for (final target in [
      const Offset(.63, 1.37),
      const Offset(1, 0),
      const Offset(3, -2),
    ]) {
      testWidgets(
        'One wall checkpoint remains editable for every snap $language $target',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final source = editing.wall(
            'source',
            const Offset(3, -2),
            const Offset(3, 2),
          );
          final model = editing.seeded(
            ArchitectStorey(id: 's', name: '', walls: [source]),
          );
          addTearDown(model.dispose);
          await tester.pumpWidget(
            RepaintBoundary(
              key: captureKey,
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: ArchitectWorkspaceScreen(commandController: model),
              ),
            ),
          );
          await tester.pumpAndSettle();
          workspace
              .camera(tester)
              .fit(const Rect.fromLTRB(-5, -5, 5, 5), padding: 40);
          await tester.pumpAndSettle();
          await editing.selectTool(tester, 'wall');
          await workspace.wallTap(tester, const Offset(-2, 0));
          await workspace.wallTap(tester, target);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('wall-length-input')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('wall-continue')), findsOneWidget);
          expect(find.byKey(const ValueKey('wall-end')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('architect-draft-cancel')),
            findsNothing,
          );
          expect(model.undoCount, 0);
          await capture(tester, 'wall-$language-${target.dx}-${target.dy}');
          await tester.tap(find.byKey(const ValueKey('wall-length-input')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('wall-key-4')));
          await tester.pumpAndSettle();
          final preview = workspace.overlay(tester);
          expect(
            (preview.activeDraftEnd! - preview.activeDraftStart!).distance,
            closeTo(4, 1e-8),
          );
          await tester.tap(find.byKey(const ValueKey('wall-end')));
          await tester.pumpAndSettle();
          expect(model.project.activeStorey.walls, hasLength(2));
          expect(model.undoCount, 1);
          model.undo();
          await tester.pumpAndSettle();
          expect(model.project.activeStorey.walls, hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final kind in ['wall', 'line', 'hatch']) {
      testWidgets('Exactly one corner command per menu $language $kind', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: '',
            walls: kind == 'wall'
                ? [editing.wall('a', const Offset(-2, 0), const Offset(2, 0))]
                : [],
            cadPrimitives: kind == 'wall'
                ? []
                : [
                    ArchitectCadPrimitive(
                      id: 'a',
                      type: kind == 'line'
                          ? CadPrimitiveType.line
                          : CadPrimitiveType.hatch,
                      startPoint: const Offset(-2, -1),
                      endPoint: const Offset(2, 1),
                    ),
                  ],
          ),
        );
        addTearDown(model.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        workspace
            .camera(tester)
            .fit(const Rect.fromLTRB(-4, -4, 4, 4), padding: 40);
        await tester.pumpAndSettle();
        await editing.ensureSelectionTool(tester);
        await workspace.wallTap(tester, Offset.zero);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-selection-more')),
        );
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(Locale(language));
        expect(find.text(l.architectChamfer), findsOneWidget);
        expect(find.text(l.architectFillet), findsOneWidget);
        await capture(tester, 'menu-$kind-$language');
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'Small exact dialogs and physical keyboard keep validation and shortcuts',
    (tester) async {
      tester.view.physicalSize = const Size(360, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      double value = 1;
      var applied = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: BimDistanceDraftingPanel(
                  length: 1,
                  unit: 'm',
                  keypadInitiallyOpen: true,
                  showContinue: false,
                  showDirection: false,
                  onLength: (v) => value = v,
                  onEnd: () => applied++,
                  onContinue: () {},
                  onUnlock: () {},
                  onCancel: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.pump();
      expect(value, 2.5);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      expect(applied, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
