import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart'
    show ArchitectTool;
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_manual_selection_test.dart' as selection;
import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['bg', 'en']) {
    testWidgets(
      'Phone $language categories expose every tool and keep Select available',
      (tester) async {
        final model = workspace.commands();
        addTearDown(model.dispose);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();
        for (final category in ArchitectToolCategory.values) {
          await tester.tap(
            find.byKey(const ValueKey('architect-tool-category')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(ValueKey('architect-category-${category.name}')),
          );
          await tester.pumpAndSettle();
          for (final entry in tool_ui.toolsByIcon.entries) {
            expect(
              find.byIcon(entry.key),
              entry.value == ArchitectTool.select ||
                      ArchitectToolCategory.of(entry.value) == category
                  ? findsOneWidget
                  : findsNothing,
            );
          }
          final entries = tool_ui.toolsByIcon.entries.where(
            (e) =>
                e.value != ArchitectTool.select &&
                ArchitectToolCategory.of(e.value) == category,
          );
          for (final entry in entries) {
            await tool_ui.choose(tester, entry.key);
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<ArchitectToolPalette>(
                    find.byType(ArchitectToolPalette),
                  )
                  .activeTool,
              entry.value,
            );
          }
          await tester.tap(find.byKey(const ValueKey('architect-tool-select')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(ValueKey('architect-tools-${category.name}')),
            findsOneWidget,
          );
        }
        expect(model.undoCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final angle in [0.0, math.pi / 2, .7]) {
    testWidgets(
      'Zoomed clearances stay visible away from wall midpoint and avoid fan at $angle',
      (tester) async {
        Offset rotate(Offset p) => Offset(
          p.dx * math.cos(angle) - p.dy * math.sin(angle),
          p.dx * math.sin(angle) + p.dy * math.cos(angle),
        );
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: 'Floor',
            walls: [
              for (final e in [
                ('selected', 0.0),
                ('before', -15.0),
                ('after', 12.0),
              ])
                editing.wall(
                  e.$1,
                  rotate(Offset(-100, e.$2)),
                  rotate(Offset(100, e.$2)),
                ),
            ],
          ),
        );
        addTearDown(model.dispose);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture =
            Platform.environment['UPDATE_ARCHITECT_CLEARANCE_PREVIEW'] ==
            'true';
        if (capture) {
          await tester.runAsync(() async {
            await (FontLoader('Roboto')..addFont(
                  File(
                    'C:/Windows/Fonts/arial.ttf',
                  ).readAsBytes().then(ByteData.sublistView),
                ))
                .load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('bg'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: boundary,
              child: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tool_ui.choose(tester, Icons.line_weight_rounded);
        await tester.pumpAndSettle();
        final camera = workspace.camera(tester);
        camera.fit(
          Rect.fromCenter(
            center: rotate(const Offset(60, 0)),
            width: 4,
            height: 4,
          ),
        );
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, rotate(const Offset(60, 0)));
        await tester.pumpAndSettle();
        final viewport = tester.getRect(
          find.byKey(const ValueKey('architect-viewport-input')),
        );
        void checkBadges({bool fan = false}) {
          final rects = <Rect>[];
          for (final id in ['before', 'after']) {
            final rect = tester.getRect(
              find.byKey(ValueKey('wall-clearance-$id')),
            );
            expect(viewport.contains(rect.topLeft), isTrue);
            expect(viewport.contains(rect.bottomRight), isTrue);
            expect(rects.any((r) => r.overlaps(rect)), isFalse);
            final floatingActionsFinder = find.byKey(
              const ValueKey('architect-wall-floating-actions'),
            );
            if (floatingActionsFinder.evaluate().isNotEmpty) {
              expect(
                rect.overlaps(tester.getRect(floatingActionsFinder)),
                isFalse,
              );
            }
            if (fan) {
              final menu = tester.widget<ArchitectRadialMenu>(
                find.byType(ArchitectRadialMenu),
              );
              for (final item in menu.items) {
                expect(
                  rect.overlaps(
                    tester.getRect(
                      find.byKey(
                        ValueKey('architect-radial-${item.action.name}'),
                      ),
                    ),
                  ),
                  isFalse,
                );
              }
              expect(
                rect.overlaps(
                  tester.getRect(
                    find.byKey(const ValueKey('architect-radial-title')),
                  ),
                ),
                isFalse,
              );
            }
            rects.add(rect);
          }
        }

        checkBadges();
        await selection.holdMenu(tester, rotate(const Offset(60, 0)));
        checkBadges(fan: true);
        if (capture && angle == 0) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              'docs/images/architect_visible_clearances_phone.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        tester
            .widget<ArchitectRadialMenu>(find.byType(ArchitectRadialMenu))
            .onDismiss();
        camera.fit(
          Rect.fromCenter(
            center: rotate(const Offset(65, 0)),
            width: 2,
            height: 2,
          ),
        );
        await tester.pumpAndSettle();
        checkBadges();
        // In Select mode the readouts stay visible without capturing taps intended
        // to add another element to the selection.
        await selection.selectTool(tester);
        await workspace.wallTap(tester, rotate(const Offset(65, 0)));
        await tester.pumpAndSettle();
        checkBadges();
        expect(model.undoCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Floating Extend targets a wall, commits once and supports Undo',
    (tester) async {
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [
            editing.wall('selected', Offset.zero, const Offset(2, 0)),
            editing.wall('target', const Offset(5, -2), const Offset(5, 2)),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool_ui.choose(tester, Icons.line_weight_rounded);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(.5, 0));
      await tester.pumpAndSettle();
      final before = model.project;
      await tester.tap(find.byKey(const ValueKey('architect-wall-extend')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(5, 1));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.walls.first.endPoint,
        const Offset(5, 0),
      );
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project, same(before));
      expect(tester.takeException(), isNull);
    },
  );
}
