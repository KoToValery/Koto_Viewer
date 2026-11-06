import 'package:kotoview/src/core/icons/app_icon.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/core/services/ui_settings_service.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'package:kotoview/src/features/architect/widgets/architect_grid_axis_properties_card.dart';
import 'package:kotoview/src/features/bim_editing/models/bim_context_menu_settings.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_line_geometry.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  for (final language in ['bg', 'en']) {
    for (final mode in BimContextMenuMode.values) {
      testWidgets('Phone axis context stays visible: $language ${mode.name}', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final settings = UiSettingsService.contextMenu.value;
        UiSettingsService.contextMenu.value = BimContextMenuSettings(
          mode: mode,
        );
        addTearDown(() => UiSettingsService.contextMenu.value = settings);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = editing.seeded(
          const ArchitectStorey(id: 's', name: ''),
          axes: const [
            StructuralGridAxis(
              id: 'axis',
              name: 'A',
              start: Offset(-3, 0),
              end: Offset(3, 0),
            ),
          ],
        );
        addTearDown(model.dispose);
        await tester.runAsync(() async {
          await (FontLoader('Roboto')
                ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
              .load();
        });
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('context-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(language),
              theme: ThemeData(
                brightness: mode == BimContextMenuMode.circle
                    ? Brightness.light
                    : Brightness.dark,
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        workspace.camera(tester).fit(const Rect.fromLTWH(-4, -3, 8, 6));
        await tester.pumpAndSettle();
        final canvas = find.byKey(const ValueKey('architect-viewport-input'));
        final size = tester.getSize(canvas);
        final pick = workspace.screen(tester, Offset.zero);
        final gesture = await tester.startGesture(pick);
        await tester.pump(const Duration(milliseconds: 281));
        expect(find.byType(ArchitectGridAxisPropertiesCard), findsOneWidget);
        expect(tester.getSize(canvas), size);
        expect(workspace.screen(tester, Offset.zero), pick);
        await tester.pump(const Duration(milliseconds: 420));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectRadialMenu), findsOneWidget);
        expect(find.byType(ArchitectGridAxisPropertiesCard), findsNothing);
        final target = find.byKey(
          const ValueKey('architect-radial-properties'),
        );
        expect(
          tester.getRect(canvas).contains(tester.getCenter(target)),
          isTrue,
        );
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('context-capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/context_menu/axis_${language}_${mode.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectRadialMenu), findsNothing);
        expect(find.byType(ArchitectGridAxisPropertiesCard), findsOneWidget);
        expect(model.canUndo, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final angle in [0.0, math.pi / 2, math.pi * 3 / 8]) {
    testWidgets(
      'short hold selects, long hold opens context; visible gap at $angle',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Offset rotate(Offset p) => Offset(
          p.dx * math.cos(angle) - p.dy * math.sin(angle),
          p.dx * math.sin(angle) + p.dy * math.cos(angle),
        );
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: 's',
            walls: [
              editing.wall(
                'a',
                rotate(const Offset(-1, 0)),
                rotate(const Offset(1, 0)),
              ),
              editing.wall(
                'b',
                rotate(const Offset(-1, -12)),
                rotate(const Offset(1, -12)),
              ),
            ],
          ),
        );
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();
        await editing.selectTool(tester, 'wall');
        workspace.camera(tester).fit(const Rect.fromLTWH(-2, -2, 4, 4));
        await tester.pumpAndSettle();
        final before = model.project;
        final gesture = await tester.startGesture(
          workspace.screen(tester, Offset.zero),
        );
        await tester.pump(const Duration(milliseconds: 281));
        expect(workspace.overlay(tester).selectedElementId, 'a');
        expect(find.byType(ArchitectRadialMenu), findsNothing);
        final badge = find.byKey(const ValueKey('wall-clearance-b'));
        expect(badge, findsOneWidget);
        expect(
          find.descendant(
            of: badge,
            matching: find.text(model.project.formatLength(11.75)),
          ),
          findsOneWidget,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(identical(model.project, before), isTrue);
        final longer = await tester.startGesture(
          workspace.screen(tester, Offset.zero),
        );
        await tester.pump(const Duration(milliseconds: 281));
        expect(find.byType(ArchitectRadialMenu), findsNothing);
        await tester.pump(const Duration(milliseconds: 420));
        expect(find.byType(ArchitectRadialMenu), findsOneWidget);
        await longer.up();
        await tester.pumpAndSettle();
        expect(identical(model.project, before), isTrue);
        expect(model.canUndo, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final center in [
    const Offset(20, 60),
    const Offset(340, 60),
    const Offset(20, 540),
    const Offset(340, 540),
    const Offset(180, 540),
  ]) {
    testWidgets(
      'eight context targets stay separate inside canvas at $center',
      (tester) async {
        tester.view.physicalSize = const Size(360, 620);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = const BimContextMenuSettings().slots
            .whereType<ArchitectRadialAction>()
            .toList();
        ArchitectRadialAction? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArchitectRadialMenu(
                center: center,
                items: [
                  for (final action in actions)
                    ArchitectRadialMenuItem(
                      action: action,
                      icon: AppIconId.edit,
                      label: action.name,
                      color: Colors.cyan,
                    ),
                ],
                onActionSelected: (action) => selected = action,
                onDismiss: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rects = [
          for (final action in actions)
            tester.getRect(
              find.byKey(ValueKey('architect-radial-${action.name}')),
            ),
        ];
        for (var i = 0; i < rects.length; i++) {
          expect(rects[i].left, greaterThanOrEqualTo(12 - 1e-8));
          expect(rects[i].right, lessThanOrEqualTo(348 + 1e-8));
          expect(rects[i].top, greaterThanOrEqualTo(12 - 1e-8));
          expect(rects[i].bottom, lessThanOrEqualTo(608 + 1e-8));
          for (var j = i + 1; j < rects.length; j++) {
            expect(
              (rects[i].center - rects[j].center).distance,
              greaterThanOrEqualTo(60 - 1e-8),
            );
          }
          await tester.tapAt(rects[i].center);
          expect(selected, actions[i]);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'visible segment preserves orientation and handles reversed and offscreen lines',
    () {
      const view = Rect.fromLTWH(0, 0, 10, 10);
      expect(
        BimLineGeometry.visibleSegment(
          const Offset(5, -20),
          const Offset(5, 6),
          view,
        ),
        (const Offset(5, 0), const Offset(5, 6)),
      );
      expect(
        BimLineGeometry.visibleSegment(
          const Offset(20, 5),
          const Offset(6, 5),
          view,
        ),
        (const Offset(10, 5), const Offset(6, 5)),
      );
      expect(
        BimLineGeometry.visibleSegment(
          const Offset(-2, -2),
          const Offset(-1, -1),
          view,
        ),
        isNull,
      );
    },
  );
}
