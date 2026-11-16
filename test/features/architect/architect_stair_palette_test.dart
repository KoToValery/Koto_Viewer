import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart'
    show ArchitectTool;
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_rules.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_opening_continuous_placement_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tool_ui;

Future<void> _enterStairDimension(
  WidgetTester tester,
  String chipKey,
  String digits,
) async {
  final chip = find.descendant(
    of: find.byType(ArchitectToolPalette),
    matching: find.byKey(ValueKey(chipKey)),
  );
  expect(chip, findsOneWidget);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
  for (final ch in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('bim-number-key-$ch')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
  await tester.pumpAndSettle();
}

ArchitectProject _persisted(ArchitectCommandController commands) =>
    ArchitectProject.fromJson(
      jsonDecode(jsonEncode(commands.project.toJson())) as Map<String, dynamic>,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ArchitectToolCategory places stairs in its own category', () {
    expect(
      ArchitectToolCategory.of(ArchitectTool.stair),
      ArchitectToolCategory.stairs,
    );
    expect(ArchitectToolCategory.stairs.tools, [ArchitectTool.stair]);
    expect(
      ArchitectToolCategory.build.tools.contains(ArchitectTool.stair),
      isFalse,
    );
    expect(
      ArchitectStairRules.risersForTargetHeight(
        const ArchitectStairDesign(rise: 3.0, shape: StairShape.straight),
        0.15,
      ),
      20,
    );
  });

  testWidgets(
    'stairs category exposes stair shape buttons and direct numeric inputs on phone (bg)',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final commands = workspace.seededController();
      addTearDown(commands.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: commands),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('architect-tool-category')));
      await tester.pumpAndSettle();
      final stairsCat = find.byKey(const ValueKey('architect-category-stairs'));
      expect(stairsCat, findsOneWidget);
      await tester.tap(stairsCat);
      await tester.pumpAndSettle();

      // Category shows all 5 stair shape buttons + freeform directly.
      for (final shape in StairShape.values) {
        expect(find.byKey(ValueKey('stair-shape-${shape.name}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('stair-tool-freeform')), findsOneWidget);

      // Select halfTurn shape -> activates Stair tool and opens quick-edit bar.
      final halfTurnBtn = find.byKey(const ValueKey('stair-shape-halfTurn'));
      await tester.ensureVisible(halfTurnBtn);
      await tester.pumpAndSettle();
      await tester.tap(halfTurnBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stair-tool-shape')), findsNothing);

      var palette = tester.widget<ArchitectToolPalette>(
        find.byType(ArchitectToolPalette),
      );
      expect(palette.activeTool, ArchitectTool.stair);
      expect(palette.stairDesign.shape, StairShape.halfTurn);

      await _enterStairDimension(tester, 'stair-width-input', '100');
      await _enterStairDimension(tester, 'stair-total-width-input', '250');
      await _enterStairDimension(tester, 'stair-landing-depth-input', '130');
      await _enterStairDimension(tester, 'stair-going-input', '30');
      await _enterStairDimension(tester, 'stair-riser-input', '14');

      palette = tester.widget<ArchitectToolPalette>(
        find.byType(ArchitectToolPalette),
      );
      expect(palette.stairWidth, closeTo(1.0, 1e-6));
      expect(palette.stairDesign.totalWidth, closeTo(2.5, 1e-6));
      expect(palette.stairDesign.landingDepth, closeTo(1.3, 1e-6));
      expect(palette.stairDesign.going, closeTo(0.30, 1e-6));
      expect(palette.stairDesign.risers, 20);
      expect(palette.stairDesign.riser, closeTo(0.14, 1e-6));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('stair-riser-input')),
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsOneWidget,
      );

      // Switch to spiral and edit outer diameter -> updates innerRadius cleanly.
      final spiralBtn = find.byKey(const ValueKey('stair-shape-spiral'));
      await tester.ensureVisible(spiralBtn);
      await tester.tap(spiralBtn);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('stair-outer-diameter-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('stair-total-width-input')),
        findsNothing,
      );
      await _enterStairDimension(tester, 'stair-outer-diameter-input', '240');

      palette = tester.widget<ArchitectToolPalette>(
        find.byType(ArchitectToolPalette),
      );
      expect(palette.stairDesign.shape, StairShape.spiral);
      expect(palette.stairDesign.innerRadius, closeTo(0.20, 1e-6));

      // Switch to straight -> shows overall footprint readout + going + riser.
      final straightBtn = find.byKey(const ValueKey('stair-shape-straight'));
      await tester.ensureVisible(straightBtn);
      await tester.tap(straightBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('stair-overall-size')), findsOneWidget);
      expect(find.byKey(const ValueKey('stair-going-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('stair-riser-input')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting a placed stair opens quick dimension inputs with undo/redo and persistence',
    (tester) async {
      const stair = ArchitectStair(
        id: 'stair_1',
        startPoint: Offset(0, 0),
        endPoint: Offset(4, 0),
        width: 1.2,
        design: ArchitectStairDesign(
          shape: StairShape.halfTurn,
          rise: 3.0,
          followStoreys: false,
          landingDepth: 1.2,
        ),
      );
      final commands = ArchitectCommandController(
        ArchitectProject(
          id: 'p_stairs',
          name: 'Stairs Workspace',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: 's',
          storeys: [
            ArchitectStorey(
              id: 's',
              name: 'Floor 1',
              stairs: const [stair],
            ),
          ],
        ),
      );
      addTearDown(commands.dispose);

      await workspace.openWorkspace(tester, commands);
      workspace
          .camera(tester)
          .fit(const Rect.fromLTRB(-1, -1, 5, 4), padding: 64);
      await tester.pumpAndSettle();

      await tool_ui.choose(tester, Icons.near_me_outlined);
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(1.0, 0)));
      await tester.pumpAndSettle();

      final palette = tester.widget<ArchitectToolPalette>(
        find.byType(ArchitectToolPalette),
      );
      expect(palette.selectedStair?.id, 'stair_1');

      await _enterStairDimension(tester, 'stair-width-input', '105');
      await _enterStairDimension(tester, 'stair-total-width-input', '260');
      await _enterStairDimension(tester, 'stair-going-input', '31');
      await _enterStairDimension(tester, 'stair-riser-input', '15');

      final edited = commands.project.activeStorey.stairs.single;
      expect(edited.width, closeTo(1.05, 1e-6));
      expect(edited.design!.totalWidth, closeTo(2.60, 1e-6));
      expect(edited.design!.going, closeTo(0.31, 1e-6));
      expect(edited.design!.risers, 20);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('stair-riser-input')),
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsNothing,
      );
      expect(commands.undoCount, 4);

      final persisted = _persisted(commands).activeStorey.stairs.single;
      expect(persisted.width, closeTo(1.05, 1e-6));
      expect(persisted.design!.totalWidth, closeTo(2.60, 1e-6));

      commands.undo();
      commands.undo();
      commands.undo();
      commands.undo();
      await tester.pumpAndSettle();
      final undone = commands.project.activeStorey.stairs.single;
      expect(undone.width, closeTo(1.2, 1e-6));
      expect(undone.design!.totalWidth, isNull);

      commands.redo();
      commands.redo();
      commands.redo();
      commands.redo();
      await tester.pumpAndSettle();
      final redone = commands.project.activeStorey.stairs.single;
      expect(redone.width, closeTo(1.05, 1e-6));
      expect(redone.design!.totalWidth, closeTo(2.60, 1e-6));
      expect(tester.takeException(), isNull);
    },
  );
}
