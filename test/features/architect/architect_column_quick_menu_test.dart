import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drafting_seed.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectCommandController _projectCommands({
  ArchitectStructuralScheme scheme = ArchitectStructuralScheme.flatSlab,
  double storeyHeight = 3.0,
  List<ArchitectColumn> columns = const [],
}) => ArchitectCommandController(
  ArchitectProject(
    id: 'p-col',
    name: 'Columns',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    structuralScheme: scheme,
    activeStoreyId: 's',
    storeys: [
      ArchitectStorey(
        id: 's',
        name: 'Ground',
        height: storeyHeight,
        columns: columns,
      ),
    ],
  ),
);

Future<void> _enterKeypadNumber(
  WidgetTester tester,
  Finder chip,
  List<String> keys,
) async {
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
  for (final k in keys) {
    if (k == '±') {
      await tester.tap(find.text('±'));
    } else {
      await tester.tap(find.byKey(ValueKey('bim-number-key-$k')));
    }
    await tester.pump();
  }
  await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Structural scheme column defaults & commands', () {
    test('columnDefaultsForScheme returns researched structural defaults', () {
      expect(
        ArchitectElementTool.columnDefaultsForScheme(
          ArchitectStructuralScheme.flatSlab,
        ),
        (shape: ColumnShape.rectangular, width: 0.25, depth: 0.40),
      );
      expect(
        ArchitectElementTool.columnDefaultsForScheme(
          ArchitectStructuralScheme.beamAndSlab,
        ),
        (shape: ColumnShape.rectangular, width: 0.25, depth: 0.25),
      );
      expect(
        ArchitectElementTool.columnDefaultsForScheme(
          ArchitectStructuralScheme.sandwichPanels,
        ),
        (shape: ColumnShape.rectangular, width: 0.20, depth: 0.20),
      );
      expect(
        ArchitectElementTool.columnDefaultsForScheme(
          ArchitectStructuralScheme.roundLogs,
        ),
        (shape: ColumnShape.circular, width: 0.24, depth: 0.24),
      );
      expect(
        ArchitectElementTool.columnDefaultsForScheme(
          ArchitectStructuralScheme.studFrame,
        ),
        (shape: ColumnShape.rectangular, width: 0.15, depth: 0.15),
      );
    });

    test(
      'applyColumnSchemeDefaults and resetVertical propagate to placeColumn',
      () {
        final tool = ArchitectElementTool()
          ..setColumnParams(height: 2.7, baseOffset: -0.25)
          ..applyColumnSchemeDefaults(
            ArchitectStructuralScheme.roundLogs,
            resetVertical: true,
          );
        expect(tool.columnShape, ColumnShape.circular);
        expect(tool.columnWidth, 0.24);
        expect(tool.columnDepth, 0.24);
        expect(tool.columnHeight, isNull);
        expect(tool.columnBaseOffset, 0.0);

        const storey = ArchitectStorey(id: 's', name: 'Floor');
        final (_, placed) = tool.placeColumn(
          storey: storey,
          point: const Offset(2, 3),
        );
        expect(placed.shape, ColumnShape.circular);
        expect(placed.width, 0.24);
        expect(placed.depth, 0.24);
        expect(placed.height, isNull);
        expect(placed.baseOffset, 0.0);
      },
    );

    test(
      'ArchitectDraftingSeed does not override column size, shape, height, or baseOffset',
      () {
        final source = ArchitectProject(
          id: 'p1',
          name: 'Seed',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: 's',
          storeys: const [
            ArchitectStorey(
              id: 's',
              name: 'Ground',
              columns: [
                ArchitectColumn(
                  id: 'c1',
                  position: Offset.zero,
                  shape: ColumnShape.circular,
                  width: 0.35,
                  depth: 0.50,
                  height: 4.2,
                  baseOffset: 0.4,
                  cutDisplayMode: ArchitectCutDisplayMode.projected,
                ),
              ],
            ),
          ],
        );
        final seed = ArchitectDraftingSeed.fromSelection(source, 'c1')!;
        final next = source.updateActiveStorey(
          source.activeStorey.copyWith(
            columns: const [
              ArchitectColumn(
                id: 'c1',
                position: Offset.zero,
                shape: ColumnShape.circular,
                width: 0.35,
                depth: 0.50,
                height: 4.2,
                baseOffset: 0.4,
                cutDisplayMode: ArchitectCutDisplayMode.projected,
              ),
              ArchitectColumn(
                id: 'c2',
                position: Offset(4, 0),
                shape: ColumnShape.rectangular,
                width: 0.25,
                depth: 0.40,
                height: 2.8,
                baseOffset: -0.15,
              ),
            ],
          ),
        );
        final seeded = seed.apply(source, next);
        final placed = seeded.activeStorey.columns.last;
        expect(placed.shape, ColumnShape.rectangular);
        expect(placed.width, 0.25);
        expect(placed.depth, 0.40);
        expect(placed.height, 2.8);
        expect(placed.baseOffset, -0.15);
        expect(placed.cutDisplayMode, ArchitectCutDisplayMode.projected);
      },
    );

    test('SetArchitectElementProperties mutates column shape, W, D, H, and baseOffset', () {
      final controller = _projectCommands(
        columns: const [ArchitectColumn(id: 'c1', position: Offset.zero)],
      );
      addTearDown(controller.dispose);

      controller.execute(
        SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'c1'},
          values: const {
            'width': 0.35,
            'depth': 0.50,
            'height': 2.75,
            'baseOffset': -0.25,
          },
          textValues: {'shape': ColumnShape.circular.name},
        ),
      );
      final updated = controller.project.activeStorey.columns.single;
      expect(updated.shape, ColumnShape.circular);
      expect(updated.width, 0.35);
      expect(updated.depth, 0.50);
      expect(updated.height, 2.75);
      expect(updated.baseOffset, -0.25);

      controller.undo();
      final undone = controller.project.activeStorey.columns.single;
      expect(undone.shape, ColumnShape.rectangular);
      expect(undone.width, 0.25);
      expect(undone.height, isNull);
      expect(undone.baseOffset, 0.0);
    });
  });

  group('Column quick-edit & placement sub-bar', () {
    testWidgets(
      'Placement sub-bar uses scheme defaults, keypad W/D/H/offset, and no preset chips',
      (tester) async {
        final model = _projectCommands(
          scheme: ArchitectStructuralScheme.flatSlab,
          storeyHeight: 3.1,
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tool_ui.choose(tester, Icons.view_column_rounded);
        await tester.pumpAndSettle();

        expect(find.text('30 cm'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-width-input')),
            matching: find.text('25 cm'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-depth-input')),
            matching: find.text('40 cm'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-height-input')),
            matching: find.text('310 cm'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-base-offset-input')),
            matching: find.text('0 cm'),
          ),
          findsOneWidget,
        );

        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('column-width-input')),
          ['3', '5'],
        );
        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('column-depth-input')),
          ['5', '0'],
        );
        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('column-height-input')),
          ['2', '6', '0'],
        );
        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('column-base-offset-input')),
          ['2', '0', '±'],
        );

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-width-input')),
            matching: find.text('35 cm'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-depth-input')),
            matching: find.text('50 cm'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-height-input')),
            matching: find.text('260 cm'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-base-offset-input')),
            matching: find.text('-20 cm'),
          ),
          findsOneWidget,
        );

        final held = await tester.startGesture(
          workspace.screen(tester, const Offset(2.0, 1.5)),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 281));
        await held.up();
        await tester.pumpAndSettle();

        final confirm = find.byKey(const ValueKey('architect-command-apply'));
        expect(confirm, findsOneWidget);
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        expect(model.project.activeStorey.columns, hasLength(1));
        final placed = model.project.activeStorey.columns.single;
        expect(placed.width, closeTo(0.35, 1e-6));
        expect(placed.depth, closeTo(0.50, 1e-6));
        expect(placed.height, closeTo(2.60, 1e-6));
        expect(placed.baseOffset, closeTo(-0.20, 1e-6));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Round logs scheme initializes Circular Ø24 and hides depth chip',
      (tester) async {
        final model = _projectCommands(
          scheme: ArchitectStructuralScheme.roundLogs,
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tool_ui.choose(tester, Icons.view_column_rounded);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('column-width-input')), findsOneWidget);
        expect(find.byKey(const ValueKey('column-depth-input')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-width-input')),
            matching: find.text('24 cm'),
          ),
          findsOneWidget,
        );
        expect(find.text('Diameter'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Selecting an existing column opens quick-edit menu with W/D/H/h offset, shape switch & Undo',
      (tester) async {
        final model = _projectCommands(
          storeyHeight: 3.0,
          columns: const [
            ArchitectColumn(
              id: 'c1',
              position: Offset.zero,
              width: 0.25,
              depth: 0.40,
            ),
          ],
        );
        addTearDown(model.dispose);

        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('bg'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();
        workspace.camera(tester).fit(const Rect.fromLTRB(-5, -5, 5, 5));
        await tester.pumpAndSettle();

        // Tap column while in navigation mode.
        await tester.tapAt(workspace.screen(tester, Offset.zero));
        await tester.pumpAndSettle();

        expect(find.text('Шир.'), findsOneWidget);
        expect(find.text('Дълб.'), findsOneWidget);
        expect(find.text('Вис.'), findsOneWidget);
        expect(find.text('h от котата'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-width-input')),
            matching: find.text('25 cm'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('column-height-input')),
            matching: find.text('300 cm'),
          ),
          findsOneWidget,
        );

        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('column-width-input')),
          ['3', '0'],
        );
        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('column-height-input')),
          ['2', '8', '0'],
        );
        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('column-base-offset-input')),
          ['1', '5', '±'],
        );

        var col = model.project.activeStorey.columns.single;
        expect(col.width, closeTo(0.30, 1e-6));
        expect(col.height, closeTo(2.80, 1e-6));
        expect(col.baseOffset, closeTo(-0.15, 1e-6));

        // Switch shape to Circular; Depth chip hides and Diameter label appears.
        await tester.tap(find.byKey(const ValueKey('column-shape-circle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('column-depth-input')), findsNothing);
        expect(find.text('Диаметър'), findsOneWidget);
        col = model.project.activeStorey.columns.single;
        expect(col.shape, ColumnShape.circular);

        model.undo();
        await tester.pumpAndSettle();
        col = model.project.activeStorey.columns.single;
        expect(col.shape, ColumnShape.rectangular);
        expect(find.byKey(const ValueKey('column-depth-input')), findsOneWidget);

        // Tapping empty space clears selection and hides quick menu.
        final empty =
            workspace.screen(tester, Offset.zero) + const Offset(150, 120);
        await tester.tapAt(empty);
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementId, isNull);
        expect(find.byKey(const ValueKey('column-width-input')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
