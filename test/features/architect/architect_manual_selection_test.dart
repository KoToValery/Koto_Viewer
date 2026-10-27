import 'architect_tool_test_helper.dart' as tool_ui;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_grid_axis_properties_card.dart';
import 'package:kotoview/src/features/architect/widgets/architect_zone_properties_card.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectStorey scene() => const ArchitectStorey(
  id: 's',
  name: 'Floor',
  walls: [
    ArchitectWall(id: 'w1', startPoint: Offset.zero, endPoint: Offset(4, 0)),
    ArchitectWall(id: 'w2', startPoint: Offset(4, 0), endPoint: Offset(4, 4)),
    ArchitectWall(id: 'w3', startPoint: Offset(4, 4), endPoint: Offset(0, 4)),
    ArchitectWall(id: 'w4', startPoint: Offset(7, 0), endPoint: Offset(7, 4)),
  ],
  columns: [
    ArchitectColumn(id: 'c1', position: Offset(1, 2)),
    ArchitectColumn(id: 'c2', position: Offset(2, 2)),
    ArchitectColumn(id: 'c3', position: Offset(3, 2)),
  ],
);

Future<void> selectTool(WidgetTester tester) async {
  await tool_ui.prepare(tester, Icons.near_me_outlined);
  await tester.tap(find.byIcon(Icons.near_me_outlined));
  await tester.pumpAndSettle();
}

Future<ArchitectRadialMenu> holdMenu(
  WidgetTester tester,
  Offset modelPoint,
) async {
  final gesture = await tester.startGesture(
    workspace.screen(tester, modelPoint),
  );
  await tester.pump(const Duration(milliseconds: 750));
  await gesture.up();
  await tester.pumpAndSettle();
  return tester.widget<ArchitectRadialMenu>(find.byType(ArchitectRadialMenu));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Explicit multi-selection taps toggle only their targets, including selected wall handles',
    (tester) async {
      final model = editing.seeded(scene());
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await selectTool(tester);
      await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(2, 0));
      expect(workspace.overlay(tester).selectedElementIds, {'w1'});
      await workspace.wallTap(tester, const Offset(2, 0));
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      await workspace.wallTap(tester, const Offset(1, 2));
      await workspace.wallTap(tester, const Offset(1, 2));
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      await workspace.wallTap(tester, const Offset(1, 2));
      await workspace.wallTap(tester, const Offset(2, 2));
      await workspace.wallTap(tester, const Offset(1, 0));
      expect(workspace.overlay(tester).selectedElementIds, {'c1', 'c2', 'w1'});
      await workspace.wallTap(tester, const Offset(2, 2));
      expect(workspace.overlay(tester).selectedElementIds, {'c1', 'w1'});
      await workspace.wallTap(tester, const Offset(5, 2));
      expect(workspace.overlay(tester).selectedElementIds, {'c1', 'w1'});
      await tester.tap(find.byKey(const ValueKey('architect-select-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-selection-control-clear')),
      );
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Overlap traversal adds and removes each hit without discarding other selections',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [
            ArchitectWall(
              id: 'wall',
              startPoint: Offset(-3, 0),
              endPoint: Offset(3, 0),
            ),
          ],
          columns: [
            ArchitectColumn(id: 'overlap', position: Offset.zero),
            ArchitectColumn(id: 'other', position: Offset(2, 2)),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await selectTool(tester);
      await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(2, 2));
      for (final expected in [
        {'other', 'overlap'},
        {'other', 'overlap', 'wall'},
        {'other', 'wall'},
        {'other'},
      ]) {
        await workspace.wallTap(tester, Offset.zero);
        expect(workspace.overlay(tester).selectedElementIds, expected);
      }
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Holding a manual group keeps it and adapts wall versus mixed context actions',
    (tester) async {
      final model = editing.seeded(scene());
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await selectTool(tester);
      await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(1, 0));
      await workspace.wallTap(tester, const Offset(7, 1));
      var menu = await holdMenu(tester, const Offset(1, 0));
      expect(workspace.overlay(tester).selectedElementIds, {'w1', 'w4'});
      expect(
        menu.items.map((i) => i.action),
        containsAll([
          ArchitectRadialAction.duplicate,
          ArchitectRadialAction.move,
          ArchitectRadialAction.flip,
          ArchitectRadialAction.properties,
          ArchitectRadialAction.delete,
        ]),
      );
      expect(
        menu.items.map((i) => i.action),
        isNot(contains(ArchitectRadialAction.split)),
      );
      menu.onDismiss();
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(1, 2));
      menu = await holdMenu(tester, const Offset(1, 0));
      expect(workspace.overlay(tester).selectedElementIds, {'w1', 'w4', 'c1'});
      expect(
        menu.items.map((i) => i.action),
        containsAll([
          ArchitectRadialAction.move,
          ArchitectRadialAction.mirrorMove,
          ArchitectRadialAction.mirrorCopy,
          ArchitectRadialAction.properties,
          ArchitectRadialAction.delete,
        ]),
      );
      menu.onActionSelected(ArchitectRadialAction.properties);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ArchitectElementPropertiesDialog>(
              find.byType(ArchitectElementPropertiesDialog),
            )
            .elementIds,
        {'w1', 'w4', 'c1'},
      );
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Homogeneous manual selection rotates only chosen columns and undoes once',
    (tester) async {
      final model = editing.seeded(scene());
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await selectTool(tester);
      await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(1, 2));
      await workspace.wallTap(tester, const Offset(2, 2));
      final menu = await holdMenu(tester, const Offset(1, 2));
      expect(workspace.overlay(tester).selectedElementIds, {'c1', 'c2'});
      expect(
        menu.items.map((i) => i.action),
        contains(ArchitectRadialAction.rotate),
      );
      menu.onActionSelected(ArchitectRadialAction.rotate);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-rotation-preset-90')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-rotation-apply')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.columns.map((c) => c.rotationDeg), [
        90,
        90,
        0,
      ]);
      expect(model.undoCount, 1);
      model.undo();
      expect(
        model.project.activeStorey.columns.every((c) => c.rotationDeg == 0),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Adding a zone or axis to a manual group does not open its single element inspector',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          columns: [ArchitectColumn(id: 'c', position: Offset(4, 1))],
          zones: [
            ArchitectZone(
              id: 'z',
              name: 'Room',
              category: ArchitectZoneCategory.living,
              polygon: [Offset.zero, Offset(2, 0), Offset(2, 2), Offset(0, 2)],
            ),
          ],
        ),
        axes: [
          const StructuralGridAxis(
            id: 'axis',
            name: 'A',
            start: Offset(-1, 3),
            end: Offset(5, 3),
          ),
        ],
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await selectTool(tester);
      await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(4, 1));
      await workspace.wallTap(tester, const Offset(1, 1));
      expect(workspace.overlay(tester).selectedElementIds, {'c', 'z'});
      expect(find.byType(ArchitectZonePropertiesCard), findsNothing);
      await workspace.wallTap(tester, const Offset(0, 3));
      expect(workspace.overlay(tester).selectedElementIds, {'c', 'z', 'axis'});
      expect(find.byType(ArchitectGridAxisPropertiesCard), findsNothing);
      final menu = await holdMenu(tester, const Offset(0, 3));
      // The group contains an automatic zone: only metadata and deletion apply.
      expect(menu.items.map((i) => i.action), [
        ArchitectRadialAction.properties,
        ArchitectRadialAction.delete,
      ]);
      expect(workspace.overlay(tester).selectedElementIds, {'c', 'z', 'axis'});
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['bg', 'en']) {
    testWidgets(
      'Phone $language manual mixed group has an in-bounds context badge at the edge',
      (tester) async {
        final model = editing.seeded(scene());
        addTearDown(model.dispose);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        final capture =
            Platform.environment['UPDATE_ARCHITECT_SELECTION_PREVIEW'] ==
            'true';
        if (capture) {
          await tester.runAsync(() async {
            await (FontLoader('Roboto')..addFont(
                  File(
                    'C:/Windows/Fonts/arial.ttf',
                  ).readAsBytes().then((b) => ByteData.sublistView(b)),
                ))
                .load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: boundaryKey,
              child: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await selectTool(tester);
        await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
        await tester.pumpAndSettle();
        for (final point in [
          const Offset(1, 0),
          const Offset(1, 2),
          const Offset(7, 1),
        ]) {
          await workspace.wallTap(tester, point);
          await tester.pumpAndSettle();
        }
        final menu = await holdMenu(tester, const Offset(7, 1));
        expect(workspace.overlay(tester).selectedElementIds, {
          'w1',
          'c1',
          'w4',
        });
        final badge = tester.getRect(
          find.byKey(const ValueKey('architect-radial-title')),
        );
        expect(badge.left, greaterThanOrEqualTo(0));
        expect(badge.right, lessThanOrEqualTo(360));
        expect(badge.top, greaterThanOrEqualTo(0));
        expect(badge.bottom, lessThanOrEqualTo(800));
        for (final item in menu.items) {
          final finder = find.byKey(
            ValueKey('architect-radial-${item.action.name}'),
          );
          if (finder.evaluate().isEmpty) continue; // other fixed menu pages
          final button = tester.getRect(finder);
          expect(badge.overlaps(button), isFalse);
        }
        if (capture && language == 'bg') {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              'docs/images/architect_manual_selection_phone.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        menu.onActionSelected(ArchitectRadialAction.delete);
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls.map((w) => w.id).toSet(), {
          'w2',
          'w3',
        });
        expect(model.project.activeStorey.columns.map((c) => c.id).toSet(), {
          'c2',
          'c3',
        });
        expect(model.undoCount, 1);
        model.undo();
        expect(model.project.activeStorey.walls, hasLength(4));
        expect(model.project.activeStorey.columns, hasLength(3));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
