import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_element_group_test.dart' as groups;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  for (final fillet in [false, true]) {
    for (final preselectedPair in [false, true]) {
      testWidgets(
        '${fillet ? 'Fillet' : 'Chamfer'} asks for value after both CAD lines are selected: pair=$preselectedPair',
        (tester) async {
          final model = editing.seeded(
            const ArchitectStorey(
              id: 's',
              name: '',
              cadPrimitives: [
                ArchitectCadPrimitive(
                  id: 'a',
                  type: CadPrimitiveType.line,
                  startPoint: Offset(-2, 0),
                  endPoint: Offset(1, 0),
                ),
                ArchitectCadPrimitive(
                  id: 'b',
                  type: CadPrimitiveType.line,
                  startPoint: Offset(1, 0),
                  endPoint: Offset(1, 3),
                ),
              ],
            ),
          );
          addTearDown(model.dispose);
          await workspace.open(tester, model);
          final before = model.project;
          if (preselectedPair) {
            await tester.tap(
              find.byKey(const ValueKey('architect-multi-select')),
            );
            await tester.pumpAndSettle();
            await workspace.wallTap(tester, const Offset(-.5, 0));
            await workspace.wallTap(tester, const Offset(1, 2));
            await tester.pumpAndSettle();
          }
          await editing.contextHold(tester, const Offset(-.5, 0));
          await groups.action(
            tester,
            fillet ? BimEditAction.fillet : BimEditAction.chamfer,
          );
          final applyValue = find.byKey(const ValueKey('wall-end'));
          if (!preselectedPair) {
            expect(applyValue, findsNothing);
            expect(model.project, same(before));
            expect(workspace.overlay(tester).selectedElementIds, {'a'});
            // Empty space and the source do not advance the second-line pick.
            await workspace.wallTap(tester, const Offset(-1, 2));
            await workspace.wallTap(tester, const Offset(-.5, 0));
            await tester.pumpAndSettle();
            expect(applyValue, findsNothing);
            await workspace.wallTap(tester, const Offset(1, 2));
            await tester.pumpAndSettle();
          }
          expect(applyValue, findsOneWidget);
          expect(workspace.overlay(tester).selectedElementIds, {'a', 'b'});
          expect(model.project, same(before));
          expect(model.undoCount, 0);
          if (!preselectedPair) {
            await tester.tap(find.byKey(const ValueKey('wall-cancel')));
            await tester.pumpAndSettle();
            expect(applyValue, findsNothing);
            expect(model.project, same(before));
            await workspace.wallTap(tester, const Offset(1, 2));
            await tester.pumpAndSettle();
            expect(applyValue, findsOneWidget);
          }
          await tester.tap(applyValue);
          await tester.pumpAndSettle();
          expect(model.project, same(before));
          expect(model.undoCount, 0);
          await editing.acceptGeometryCommand(tester);
          expect(model.project.activeStorey.cadPrimitives, hasLength(3));
          expect(model.undoCount, 1);
          await tester.tap(find.byKey(const ValueKey('architect-undo')));
          await tester.pumpAndSettle();
          expect(model.project, same(before));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
