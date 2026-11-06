import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_copy_storey_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_storeys_screen.dart';

void main() {
  late ArchitectProject project;

  setUp(() {
    final now = DateTime.now();
    project = ArchitectProject(
      id: 'ui_test_project',
      name: 'Многоетажна сграда',
      createdAt: now,
      updatedAt: now,
      storeys: const [
        ArchitectStorey(
          id: 'storey_1',
          name: 'Етаж 1',
          elevation: 0.00,
          height: 2.80,
          walls: [
            ArchitectWall(
              id: 'wall_1',
              startPoint: Offset(0, 0),
              endPoint: Offset(8, 0),
            ),
          ],
          columns: [
            ArchitectColumn(
              id: 'col_1',
              position: Offset(0, 0),
            ),
          ],
        ),
        ArchitectStorey(
          id: 'storey_2',
          name: 'Етаж 2',
          elevation: 2.80,
          height: 2.80,
        ),
        ArchitectStorey(
          id: 'storey_3',
          name: 'Етаж 3',
          elevation: 5.60,
          height: 2.80,
        ),
      ],
      activeStoreyId: 'storey_1',
    );
  });

  testWidgets('ArchitectCopyStoreyDialog renders and dispatches copy options',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    StoreyCopyOptions? capturedOptions;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ArchitectCopyStoreyDialog(
            project: project,
            initialSourceStoreyId: 'storey_1',
            onCopyRequested: (opts) => capturedOptions = opts,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ArchitectCopyStoreyDialog), findsOneWidget);
    // Source should default to storey_1
    expect(find.textContaining('Етаж 1'), findsWidgets);

    // Tap the Copy button
    final copyBtn = find.ancestor(
      of: find.text('Копирай елементи'),
      matching: find.byType(ElevatedButton),
    );
    expect(copyBtn, findsOneWidget);
    await tester.tap(copyBtn);
    await tester.pumpAndSettle();

    expect(capturedOptions, isNotNull);
    expect(capturedOptions!.sourceStoreyId, 'storey_1');
    expect(capturedOptions!.targetStoreyIds, containsAll(['storey_2', 'storey_3']));
    expect(capturedOptions!.mode, StoreyCopyMode.replace);
  });

  testWidgets('ArchitectStoreysScreen renders multi-storey layout and manages levels',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });

    final controller = ArchitectCommandController(project);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectStoreysScreen(controller: controller),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ArchitectStoreysScreen), findsOneWidget);
    expect(find.text('Етаж 1'), findsWidgets);
    expect(find.text('Етаж 2'), findsWidgets);
    expect(find.text('Етаж 3'), findsWidgets);

    // Scroll until bottom copy button is visible and tap
    final copyAction =
        find.byKey(const ValueKey('architect-storeys-execute-copy'));
    await tester.scrollUntilVisible(
      copyAction,
      300.0,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ).last,
    );
    await tester.pumpAndSettle();

    expect(copyAction, findsOneWidget);

    await tester.tap(copyAction);
    await tester.pumpAndSettle();

    // Verify copy succeeded: storey_2 and storey_3 now have the walls and columns copied!
    final s2 = controller.project.storeys.firstWhere((s) => s.id == 'storey_2');
    final s3 = controller.project.storeys.firstWhere((s) => s.id == 'storey_3');

    expect(s2.walls.length, 1);
    expect(s2.columns.length, 1);
    expect(s3.walls.length, 1);
    expect(s3.columns.length, 1);
  });
}
