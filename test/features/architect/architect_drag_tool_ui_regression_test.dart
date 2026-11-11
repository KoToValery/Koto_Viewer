import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_tool_test_helper.dart' as toolUi;
import 'architect_workspace_interaction_test.dart' as workspace;

const _columnId = 'drag-column';
const _columnPosition = Offset(3, 5);

ArchitectCommandController _dragModel() {
  final source = workspace.commands();
  final model = ArchitectCommandController(
    source.project.copyWith(
      storeys: const [
        ArchitectStorey(
          id: 's',
          name: 'Floor',
          columns: [
            ArchitectColumn(id: _columnId, position: _columnPosition),
            ArchitectColumn(id: 'reference-column', position: Offset(-1, -1)),
          ],
        ),
      ],
    ),
  );
  source.dispose();
  return model;
}

Future<void> _openPhone(
  WidgetTester tester,
  ArchitectCommandController model,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ArchitectWorkspaceScreen(commandController: model),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectCompactInBounds(WidgetTester tester) {
  final overlay = find.byKey(
    const ValueKey('architect-floating-command-overlay'),
  );
  expect(overlay, findsOneWidget);
  final rect = tester.getRect(overlay);
  expect(rect.width, lessThanOrEqualTo(128));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(360));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(800));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'phone Drag uses one compact command surface, cancels cleanly, and commits once',
    (tester) async {
      // Regression path from the reference map:
      // selection action -> _startDragSession -> pointer down/move/up ->
      // ArchitectDragController -> _confirmDragPlacement -> undo.
      final model = _dragModel();
      addTearDown(model.dispose);
      await _openPhone(tester, model);
      await toolUi.choose(tester, Icons.near_me_outlined);
      await tester.pumpAndSettle();
      await tester.longPressAt(workspace.screen(tester, _columnPosition));
      await tester.pumpAndSettle();

      await toolUi.selectionAction(tester, 'architect-selection-move');
      await tester.pump();
      _expectCompactInBounds(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.byKey(const ValueKey('architect-command-apply')),
        findsNothing,
      );

      // Picking a base point exposes the same one compact surface with Apply.
      await tester.tapAt(workspace.screen(tester, _columnPosition));
      await tester.pump();
      _expectCompactInBounds(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.byKey(const ValueKey('architect-command-apply')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('architect-command-cancel')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.columns
            .firstWhere((column) => column.id == _columnId)
            .position,
        _columnPosition,
      );
      expect(model.undoCount, 0);
      expect(
        find.byKey(const ValueKey('architect-floating-command-overlay')),
        findsNothing,
      );

      await toolUi.selectionAction(tester, 'architect-selection-move');
      await tester.pump();
      var commits = 0;
      model.addListener(() => commits++);
      final drag = await tester.startGesture(
        workspace.screen(tester, _columnPosition),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('architect-selection-bar')),
        findsNothing,
        reason:
            'The inactive selection HUD must not compete with Drag controls.',
      );
      await drag.moveTo(const Offset(180, 720));
      await tester.pump();
      _expectCompactInBounds(tester);
      expect(find.byType(SnackBar), findsNothing);

      await drag.up();
      await tester.pumpAndSettle();
      final moved = model.project.activeStorey.columns
          .firstWhere((column) => column.id == _columnId)
          .position;
      expect(moved, isNot(_columnPosition));
      expect(commits, 1);
      expect(model.undoCount, 1);
      expect(find.byType(SnackBar), findsNothing);

      model.undo();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.columns
            .firstWhere((column) => column.id == _columnId)
            .position,
        _columnPosition,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
