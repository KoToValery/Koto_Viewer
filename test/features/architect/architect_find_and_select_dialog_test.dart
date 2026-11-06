// === SECTION: ARCHITECTURAL FIND & SELECT DIALOG WIDGET TESTS ===
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/services/fenestration_library_service.dart';
import 'package:kotoview/src/features/architect/services/architect_filter_selection_service.dart';
import 'package:kotoview/src/features/architect/widgets/architect_find_and_select_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await FenestrationLibraryService.instance.init();
  });

  ArchitectProject createTestProject() {
    final wall = ArchitectWall(
      id: 'w1',
      startPoint: const Offset(0, 0),
      endPoint: const Offset(10, 0),
      thickness: 0.25,
      height: 2.80,
      windows: const [
        ArchitectWindow(
          id: 'win_1',
          wallId: 'w1',
          offsetRatio: 0.3,
          width: 1.20,
          height: 1.40,
          sillHeight: 0.85,
          specId: 'W1',
          uuid: 'u_win_1',
          styleId: 'win_fixed',
        ),
      ],
    );

    return ArchitectProject(
      id: 'proj_test',
      name: 'Test Project',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      storeys: [
        ArchitectStorey(
          id: 'storey_1',
          name: 'Floor 1',
          walls: [wall],
        ),
      ],
      activeStoreyId: 'storey_1',
    );
  }

  Widget createWidgetUnderTest(ArchitectProject project, {
    void Function(BatchModifyArchitectElementsCommand)? onApply,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: ArchitectFindAndSelectDialog(
          project: project,
          selectedIds: const {'win_1'},
          onSelect: (_) {},
          onSwitchStorey: (_) {},
          onApplyCommand: (cmd) {
            if (cmd is BatchModifyArchitectElementsCommand && onApply != null) {
              onApply(cmd);
            }
          },
        ),
      ),
    );
  }

  testWidgets('ArchitectFindAndSelectDialog renders and shows matching elements', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final project = createTestProject();

    await tester.pumpWidget(createWidgetUnderTest(project));
    await tester.pumpAndSettle();

    // Verify Title and Tabs
    expect(find.text('Find & Select'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Select'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Batch Modify'), findsOneWidget);

    // Verify matches banner
    expect(find.textContaining('1 element'), findsOneWidget);

    // Switch to Batch Modify Tab
    await tester.tap(find.text('Batch Modify'));
    await tester.pumpAndSettle();

    // Verify Skin Only toggle is present and defaulted to true
    expect(find.text('Keep current dimensions (Skin only)'), findsOneWidget);
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    // Apply batch modification
    BatchModifyArchitectElementsCommand? appliedCommand;
    await tester.pumpWidget(createWidgetUnderTest(project, onApply: (cmd) {
      appliedCommand = cmd;
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batch Modify'));
    await tester.pumpAndSettle();

    // Tap Apply changes button
    final applyButtonFinder = find.textContaining('Apply changes');
    expect(applyButtonFinder, findsOneWidget);
    await tester.tap(applyButtonFinder);
    await tester.pump();

    expect(appliedCommand, isNotNull);
    expect(appliedCommand!.skinOnly, isTrue);
  });
}
