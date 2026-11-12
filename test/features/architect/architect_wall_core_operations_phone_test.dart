import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_element_group_test.dart' as groups;
import 'architect_wall_operation_axis_test.dart' as geometry;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  for (final language in ['bg', 'en']) {
    for (final fillet in [false, true]) {
      testWidgets(
        'Phone mixed-reference ${fillet ? 'fillet' : 'chamfer'} and axis spacing: $language',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final a = geometry.physicalWall(
            'a',
            const Offset(-2, 0),
            const Offset(1, 0),
            WallReferenceLine.inner,
          );
          final b = geometry.physicalWall(
            'b',
            const Offset(1, 0),
            const Offset(1, 3),
            WallReferenceLine.outer,
          );
          final model = editing.seeded(
            ArchitectStorey(id: 's', name: '', walls: [a, b]),
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
          final before = model.project;
          await editing.contextHold(tester, const Offset(-.5, 0));
          await groups.action(
            tester,
            fillet ? BimEditAction.fillet : BimEditAction.chamfer,
          );
          expect(find.byKey(const ValueKey('wall-end')), findsNothing);
          expect(model.undoCount, 0);
          // Cancelling the second-wall pick never edits the first wall.
          await tester.tap(
            find.byKey(const ValueKey('architect-command-cancel')),
          );
          await tester.pumpAndSettle();
          expect(model.project, same(before));
          await editing.contextHold(tester, const Offset(-.5, 0));
          await groups.action(
            tester,
            fillet ? BimEditAction.fillet : BimEditAction.chamfer,
          );
          expect(find.byKey(const ValueKey('wall-end')), findsNothing);
          await workspace.wallTap(tester, const Offset(1, 2));
          await tester.pumpAndSettle();
          expect(workspace.overlay(tester).selectedElementIds, {'a', 'b'});
          expect(find.byKey(const ValueKey('wall-end')), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('wall-end')));
          await tester.pumpAndSettle();
          expect(model.undoCount, 0);
          await editing.acceptGeometryCommand(tester);
          expect(model.project.activeStorey.walls, hasLength(3));
          final walls = model.project.activeStorey.walls;
          geometry.near(walls[0].coreCenterStart, a.coreCenterStart);
          geometry.near(walls[1].coreCenterEnd, b.coreCenterEnd);
          geometry.near(walls[2].coreCenterStart, walls[0].coreCenterEnd);
          geometry.near(walls[2].coreCenterEnd, walls[1].coreCenterStart);
          expect(walls[0].referenceLine, a.referenceLine);
          expect(walls[1].referenceLine, b.referenceLine);
          expect(model.undoCount, 1);
          await tester.tap(find.byKey(const ValueKey('architect-undo')));
          await tester.pumpAndSettle();
          expect(model.project, same(before));
          // The existing Offset dialog explains the distance, without extra menus.
          await editing.contextHold(tester, const Offset(-.5, 0));
          await groups.action(tester, BimEditAction.offset);
          final field = find.byKey(const ValueKey('architect-offset-distance'));
          expect(field, findsOneWidget);
          final l = AppLocalizations.of(tester.element(field))!;
          expect(
            tester.widget<TextField>(field).decoration!.labelText,
            l.architectWallAxisSpacing,
          );
          final rect = tester.getRect(field);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
          await tester.tap(find.text(l.cancel));
          await tester.pumpAndSettle();
          expect(model.project, same(before));
          expect(model.undoCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
