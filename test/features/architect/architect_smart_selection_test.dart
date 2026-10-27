import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final elementTool = ArchitectElementTool();

  group('ArchitectElementTool - Smart Batch & Topology', () {
    test('findConnectedWallChain returns topologically connected walls', () {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        thickness: 0.25,
      );
      final w2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(5, 0),
        endPoint: const Offset(5, 5),
        thickness: 0.25,
      );
      final w3 = ArchitectWall(
        id: 'w3',
        startPoint: const Offset(5, 5),
        endPoint: const Offset(0, 5),
        thickness: 0.25,
      );
      final wDisconnected = ArchitectWall(
        id: 'w4',
        startPoint: const Offset(20, 20),
        endPoint: const Offset(25, 20),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        walls: [w1, w2, w3, wDisconnected],
      );

      final chain = elementTool.findConnectedWallChain(storey, 'w1');
      expect(chain, containsAll({'w1', 'w2', 'w3'}));
      expect(chain.contains('w4'), isFalse);
    });

    test('duplicateElementsByIds duplicates walls and columns with offset', () {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final c1 = ArchitectColumn(
        id: 'c1',
        position: const Offset(2, 2),
        width: 0.3,
        depth: 0.3,
      );
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        walls: [w1],
        columns: [c1],
      );

      final (nextStorey, copyIds) = elementTool.duplicateElementsByIds(
        storey,
        {'w1', 'c1'},
        offset: const Offset(1, 1),
      );

      expect(copyIds.length, 2);
      expect(nextStorey.walls.length, 2);
      expect(nextStorey.columns.length, 2);

      final copyWall = nextStorey.walls.firstWhere((w) => w.id != 'w1');
      expect(copyWall.startPoint, const Offset(1, 1));
      expect(copyWall.endPoint, const Offset(5, 1));

      final copyCol = nextStorey.columns.firstWhere((c) => c.id != 'c1');
      expect(copyCol.position, const Offset(3, 3));
    });

    test('rotateElementsByIds rotates elements by 90 degrees', () {
      final c1 = ArchitectColumn(
        id: 'c1',
        position: const Offset(2, 2),
        width: 0.4,
        depth: 0.2,
        rotationDeg: 0,
      );
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        columns: [c1],
      );

      final rotatedStorey = elementTool.rotateElementsByIds(storey, {'c1'});
      expect(rotatedStorey.columns.first.rotationDeg, 90);
    });

    test('flipElementsByIds flips wall direction (reverses endpoints)', () {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        walls: [w1],
      );

      final flippedStorey = elementTool.flipElementsByIds(storey, {'w1'});
      expect(flippedStorey.walls.first.startPoint, const Offset(4, 0));
      expect(flippedStorey.walls.first.endPoint, const Offset(0, 0));
    });

    test('deleteElementsByIds deletes mixed elements in one pass', () {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final c1 = ArchitectColumn(
        id: 'c1',
        position: const Offset(2, 2),
        width: 0.3,
        depth: 0.3,
      );
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        walls: [w1],
        columns: [c1],
      );

      final cleared = elementTool.deleteElementsByIds(storey, {'w1', 'c1'});
      expect(cleared.walls, isEmpty);
      expect(cleared.columns, isEmpty);
    });
  });

  group('ArchitectSelection.summary localization', () {
    testWidgets('summarizes same-type and mixed-type selections', (tester) async {
      late AppLocalizations l10nEn;
      late AppLocalizations l10nBg;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              l10nEn = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bg'),
          home: Builder(
            builder: (context) {
              l10nBg = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's1',
        storeys: [
          ArchitectStorey(
            id: 's1',
            name: 'Floor 1',
            walls: [
              ArchitectWall(
                id: 'w1',
                startPoint: const Offset(0, 0),
                endPoint: const Offset(4, 0),
                thickness: 0.25,
              ),
              ArchitectWall(
                id: 'w2',
                startPoint: const Offset(4, 0),
                endPoint: const Offset(4, 4),
                thickness: 0.25,
              ),
            ],
            columns: [
              ArchitectColumn(
                id: 'c1',
                position: const Offset(2, 2),
                width: 0.3,
                depth: 0.3,
              ),
            ],
          ),
        ],
      );

      // Walls only summary
      final wallsSummaryEn = ArchitectSelection.summary(project, {'w1', 'w2'}, l10nEn);
      expect(wallsSummaryEn, contains('2 walls'));

      final wallsSummaryBg = ArchitectSelection.summary(project, {'w1', 'w2'}, l10nBg);
      expect(wallsSummaryBg, contains('2 стени'));

      // Mixed summary
      final mixedSummaryEn = ArchitectSelection.summary(project, {'w1', 'c1'}, l10nEn);
      expect(mixedSummaryEn, contains('2 items:'));

      final mixedSummaryBg = ArchitectSelection.summary(project, {'w1', 'c1'}, l10nBg);
      expect(mixedSummaryBg, contains('2 елемента:'));
      expect(ArchitectSelection.summary(project, {'w1', 'c1'}, l10nEn, compact: true), '2 items');
      expect(ArchitectSelection.summary(project, {'w1', 'c1'}, l10nBg, compact: true), '2 елемента');
    });
  });

  group('ArchitectWorkspaceScreen - Sequential & Smart Selection Integration', () {
    ArchitectCommandController seededController() {
      final w1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final w2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4, 0),
        endPoint: const Offset(4, 4),
        thickness: 0.25,
      );
      final c1 = ArchitectColumn(
        id: 'c1',
        position: const Offset(2, 2),
        width: 0.4,
        depth: 0.4,
      );
      return ArchitectCommandController(
        ArchitectProject(
          id: 'p',
          name: 'Workspace',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: 's',
          storeys: [
            ArchitectStorey(
              id: 's',
              name: 'Floor',
              walls: [w1, w2],
              columns: [c1],
            ),
          ],
        ),
      );
    }

    Future<void> openWorkspace(
      WidgetTester tester,
      ArchitectCommandController commands,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(
            commandController: commands,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Architect2dPainter overlay(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((e) => e.painter)
        .whereType<Architect2dPainter>()
        .firstWhere((e) => e.layer == ArchitectPaintLayer.interaction);

    BimViewportController camera(WidgetTester tester) => overlay(tester).viewport!;

    Offset screen(WidgetTester tester, Offset point) =>
        tester.getTopLeft(find.byKey(const ValueKey('architect-viewport-input'))) +
        camera(tester).toScreen(point);

    testWidgets('Explicit multi-select keeps multiple elements with a compact action bar', (tester) async {
      final commands = seededController();
      await openWorkspace(tester, commands);

      // Switch to Select tool
      await tester.tap(find.byIcon(Icons.near_me_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
      await tester.pumpAndSettle();

      // Tap w1 (at model 2, 0)
      await tester.tapAt(screen(tester, const Offset(2, 0)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('architect-selection-bar')), findsOneWidget);

      // Sequentially tap c1 (at model 2, 2) - should add to selection
      await tester.tapAt(screen(tester, const Offset(2, 2)));
      await tester.pumpAndSettle();

      // Selection actions remain available without a count.
      expect(find.byKey(const ValueKey('architect-selection-bar')), findsOneWidget);
      expect(find.text('2 items'), findsNothing);
      expect(find.byKey(const ValueKey('architect-context-menu-btn')), findsNothing);

      // Hold a selected element to open the group context menu.
      final held = await tester.startGesture(screen(tester, const Offset(1, 0)));
      await tester.pump(const Duration(milliseconds: 750));
      await held.up();
      await tester.pumpAndSettle();

      // ArchitectRadialMenu should be visible with badge
      expect(find.byType(ArchitectRadialMenu), findsOneWidget);
      expect(find.textContaining('2 items:'), findsWidgets);
    });

    testWidgets('Select connected walls expands selection to all connected walls', (tester) async {
      final commands = seededController();
      await openWorkspace(tester, commands);

      // Select w1
      await tester.tap(find.byIcon(Icons.near_me_outlined));
      await tester.pumpAndSettle();

      await tester.tapAt(screen(tester, const Offset(2, 0)));
      await tester.pumpAndSettle();

      // Tap "Connected" button in selection bar
      final connectedBtn = find.byKey(const ValueKey('architect-select-connected'));
      expect(connectedBtn, findsOneWidget);
      await tester.tap(connectedBtn);
      await tester.pumpAndSettle();

      // The connected walls are selected without a bottom count.
      expect(overlay(tester).selectedElementIds, {'w1', 'w2'});
      expect(find.textContaining('2 walls'), findsNothing);
    });

    testWidgets('Select similar elements expands selection to all of same type', (tester) async {
      final commands = seededController();
      await openWorkspace(tester, commands);

      // Select w1
      await tester.tap(find.byIcon(Icons.near_me_outlined));
      await tester.pumpAndSettle();

      await tester.tapAt(screen(tester, const Offset(2, 0)));
      await tester.pumpAndSettle();

      // Tap "Similar" button
      final similarBtn = find.byKey(const ValueKey('architect-select-similar'));
      expect(similarBtn, findsOneWidget);
      await tester.tap(similarBtn);
      await tester.pumpAndSettle();

      // Both walls are now selected
      expect(overlay(tester).selectedElementIds, {'w1', 'w2'});
      expect(find.textContaining('2 walls'), findsNothing);
    });
  });
}
