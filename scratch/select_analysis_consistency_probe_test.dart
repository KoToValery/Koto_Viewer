import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_marquee_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import '../test/features/architect/architect_editing_test.dart' as editing;
import '../test/features/architect/architect_manual_selection_test.dart' as manual;
import '../test/features/architect/architect_workspace_interaction_test.dart' as workspace;

// Analysis-only regression probes. Product code is intentionally unchanged.
void main() {
  testWidgets('Analysis rotation of selected columns uses the shared confirm', (
    tester,
  ) async {
    final model = editing.seeded(manual.scene());
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await manual.selectTool(tester);
    await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
    await tester.pumpAndSettle();
    await workspace.wallTap(tester, const Offset(1, 2));
    await workspace.wallTap(tester, const Offset(2, 2));
    final menu = await manual.holdMenu(tester, const Offset(1, 2));
    menu.onActionSelected(ArchitectRadialAction.rotate);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-rotation-preset-90')));
    await tester.pumpAndSettle();
    expect(model.undoCount, 0);
    await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.columns.map((c) => c.rotationDeg), [
      90,
      90,
      0,
    ]);
    expect(model.undoCount, 1);
    model.undo();
    expect(model.project.activeStorey.columns.every((c) => c.rotationDeg == 0),
        isTrue);
  });

  for (final relation in ArchitectSelectionRelation.values) {
    test('Area ${relation.name} includes selectable notes and level markers', () {
      const storey = ArchitectStorey(
        id: 's',
        name: '',
        annotations: [
          ArchitectAnnotation(
            id: 'note',
            position: Offset(-1, 0),
            text: 'A',
          ),
        ],
        elevationMarkers: [
          ArchitectElevationMarker(
            id: 'level',
            position: Offset(1, 0),
            elevation: 0,
          ),
        ],
      );
      final project = ArchitectProject(
        id: 'p',
        name: '',
        createdAt: DateTime(2026, 11, 4),
        updatedAt: DateTime(2026, 11, 4),
        storeys: const [storey],
        activeStoreyId: storey.id,
      );
      final tool = ArchitectElementTool();
      final tapped = {
        ...tool.hitTestElements(storey, const Offset(-1, 0), 100),
        ...tool.hitTestElements(storey, const Offset(1, 0), 100),
      };
      expect(tapped, containsAll(['note', 'level']));
      final framed = ArchitectMarqueeTool.evaluateSelection(
        storey: storey,
        project: project,
        polygon: const [
          Offset(-5, -5),
          Offset(5, -5),
          Offset(5, 5),
          Offset(-5, 5),
        ],
        relation: relation,
      );
      expect(framed, containsAll(['note', 'level']));
    });
  }
}
