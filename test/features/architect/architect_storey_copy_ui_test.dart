import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_copy_storey_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_storeys_screen.dart';

Future<void> _showCopyDialog(
  WidgetTester tester,
  ArchitectProject project, {
  Size size = const Size(1200, 900),
  String language = 'bg',
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Set<String>? selectedElementIds,
  ValueChanged<StoreyCopyOptions>? onCopyRequested,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('storey-copy-test-boundary'),
        child: Scaffold(
          body: ArchitectCopyStoreyDialog(
            project: project,
            initialSourceStoreyId: 'storey_1',
            selectedElementIds: selectedElementIds,
            onCopyRequested: onCopyRequested ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapCopyControl(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

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
          columns: [ArchitectColumn(id: 'col_1', position: Offset(0, 0))],
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

  testWidgets('ArchitectCopyStoreyDialog renders and dispatches copy options', (
    tester,
  ) async {
    StoreyCopyOptions? capturedOptions;
    await _showCopyDialog(
      tester,
      project,
      onCopyRequested: (options) => capturedOptions = options,
    );

    expect(find.byType(ArchitectCopyStoreyDialog), findsOneWidget);
    expect(find.textContaining('Етаж 1'), findsWidgets);
    await _tapCopyControl(tester, 'architect-copy-submit');

    expect(capturedOptions, isNotNull);
    expect(capturedOptions!.sourceStoreyId, 'storey_1');
    expect(
      capturedOptions!.targetStoreyIds,
      containsAll(['storey_2', 'storey_3']),
    );
    expect(capturedOptions!.mode, StoreyCopyMode.replace);
  });

  for (final language in ['bg', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'copy dialog fits narrow phone in $language, $brightness, larger text',
        (tester) async {
          await _showCopyDialog(
            tester,
            project,
            size: const Size(360, 740),
            language: language,
            brightness: brightness,
            textScale: 1.35,
            selectedElementIds: {'wall_1'},
          );
          expect(tester.takeException(), isNull);
          final submit = find.byKey(const ValueKey('architect-copy-submit'));
          expect(submit.hitTestable(), findsOneWidget);
          await _tapCopyControl(tester, 'architect-copy-settings');
          await _tapCopyControl(tester, 'architect-copy-adjust-groups');
          expect(tester.takeException(), isNull);
          expect(submit.hitTestable(), findsOneWidget);
        },
      );
    }
  }

  testWidgets('category groups transfer each related element type together', (
    tester,
  ) async {
    StoreyCopyOptions? captured;
    await _showCopyDialog(
      tester,
      project,
      onCopyRequested: (options) => captured = options,
    );
    for (final group in ['stairs', 'dimensions', 'annotations', 'components']) {
      expect(
        find.byKey(ValueKey('architect-copy-category-$group')),
        findsOneWidget,
      );
      await _tapCopyControl(tester, 'architect-copy-category-$group');
    }
    await _tapCopyControl(tester, 'architect-copy-submit');
    expect(captured, isNotNull);
    expect(captured!.elementTypes, {
      ArchitectStoreyElementType.walls,
      ArchitectStoreyElementType.columns,
      ArchitectStoreyElementType.beams,
      ArchitectStoreyElementType.slabs,
      ArchitectStoreyElementType.zones,
    });
  });

  testWidgets('source changes do not carry selection IDs from another storey', (
    tester,
  ) async {
    final secondStorey = project.storeys[1].copyWith(
      walls: const [
        ArchitectWall(
          id: 'wall_2',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
        ),
      ],
    );
    final populatedProject = project.copyWith(
      storeys: [project.storeys[0], secondStorey, project.storeys[2]],
    );
    StoreyCopyOptions? captured;
    await _showCopyDialog(
      tester,
      populatedProject,
      selectedElementIds: {'wall_1'},
      onCopyRequested: (options) => captured = options,
    );
    await _tapCopyControl(tester, 'architect-copy-submit');
    expect(captured!.selectedElementIds, {'wall_1'});

    await _tapCopyControl(tester, 'architect-copy-scope-all');
    await _tapCopyControl(tester, 'architect-copy-submit');
    expect(captured!.selectedElementIds, isNull);

    await _tapCopyControl(tester, 'architect-copy-scope-selection');
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('architect-copy-source')),
        )
        .onChanged!('storey_2');
    await tester.pumpAndSettle();
    await _tapCopyControl(tester, 'architect-copy-submit');
    expect(captured!.sourceStoreyId, 'storey_2');
    expect(captured!.selectedElementIds, isNull);
    expect(captured!.targetStoreyIds, isNot(contains('storey_2')));
  });

  testWidgets('empty categories or targets disable copy until selected again', (
    tester,
  ) async {
    await _showCopyDialog(tester, project);
    ElevatedButton submit() => tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('architect-copy-submit')),
    );
    expect(submit().onPressed, isNotNull);
    await _tapCopyControl(tester, 'architect-copy-categories-none');
    expect(submit().onPressed, isNull);
    await _tapCopyControl(tester, 'architect-copy-categories-all');
    expect(submit().onPressed, isNotNull);
    await _tapCopyControl(tester, 'architect-copy-targets-none');
    expect(submit().onPressed, isNull);
    await _tapCopyControl(tester, 'architect-copy-targets-all');
    expect(submit().onPressed, isNotNull);
  });

  testWidgets('copy mode and adaptation controls reach the submitted options', (
    tester,
  ) async {
    StoreyCopyOptions? captured;
    await _showCopyDialog(
      tester,
      project,
      onCopyRequested: (options) => captured = options,
    );
    await _tapCopyControl(tester, 'architect-copy-settings');
    await _tapCopyControl(tester, 'architect-copy-mode-merge');
    for (final option in ['walls', 'levels', 'groups']) {
      await _tapCopyControl(tester, 'architect-copy-adjust-$option');
    }
    await _tapCopyControl(tester, 'architect-copy-submit');
    expect(captured!.mode, StoreyCopyMode.merge);
    expect(captured!.adjustWallHeights, isFalse);
    expect(captured!.adjustLevelMarkers, isFalse);
    expect(captured!.preserveGroups, isFalse);
  });

  testWidgets('new storeys validate input and stage localized copy targets', (
    tester,
  ) async {
    StoreyCopyOptions? captured;
    await _showCopyDialog(
      tester,
      project,
      onCopyRequested: (options) => captured = options,
    );
    await _tapCopyControl(tester, 'architect-copy-new-storeys');
    final count = find.byKey(const ValueKey('architect-copy-batch-count'));
    final height = find.byKey(const ValueKey('architect-copy-batch-height'));
    await tester.enterText(count, '0');
    await tester.enterText(height, '-1');
    await _tapCopyControl(tester, 'architect-copy-batch-submit');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<TextFormField>(count).validator!('0'), isNotNull);
    expect(tester.widget<TextFormField>(height).validator!('NaN'), isNotNull);
    await tester.enterText(count, '2');
    await tester.enterText(height, '3,20');
    await _tapCopyControl(tester, 'architect-copy-batch-submit');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Етаж 4'), findsOneWidget);
    expect(find.text('Етаж 5'), findsOneWidget);
    expect(project.storeys, hasLength(3));
    expect(captured, isNull);

    await _tapCopyControl(tester, 'architect-copy-submit');
    expect(captured!.additionalStoreys, hasLength(2));
    expect(captured!.additionalStoreys.map((s) => s.name), [
      'Етаж 4',
      'Етаж 5',
    ]);
    expect(captured!.additionalStoreys.every((s) => s.height == 3.2), isTrue);
    expect(
      captured!.targetStoreyIds,
      containsAll(captured!.additionalStoreys.map((s) => s.id)),
    );
    expect(project.storeys, hasLength(3));

    final lowerNewStoreyId = captured!.additionalStoreys.first.id;
    await _tapCopyControl(tester, 'architect-copy-target-$lowerNewStoreyId');
    await _tapCopyControl(tester, 'architect-copy-submit');
    expect(captured!.additionalStoreys, hasLength(2));
    expect(captured!.targetStoreyIds, isNot(contains(lowerNewStoreyId)));
    expect(
      captured!.targetStoreyIds,
      contains(captured!.additionalStoreys.last.id),
    );
  });

  testWidgets('cancelling new storeys leaves the original targets unchanged', (
    tester,
  ) async {
    StoreyCopyOptions? captured;
    await _showCopyDialog(
      tester,
      project,
      onCopyRequested: (options) => captured = options,
    );
    await _tapCopyControl(tester, 'architect-copy-new-storeys');
    await tester.enterText(
      find.byKey(const ValueKey('architect-copy-batch-count')),
      '8',
    );
    final alert = tester.element(find.byType(AlertDialog));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(
          TextButton,
          MaterialLocalizations.of(alert).cancelButtonLabel,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapCopyControl(tester, 'architect-copy-submit');
    expect(captured!.additionalStoreys, isEmpty);
    expect(captured!.targetStoreyIds, {'storey_2', 'storey_3'});
    expect(project.storeys, hasLength(3));
  });

  testWidgets('phone batch form remains usable above the on-screen keyboard', (
    tester,
  ) async {
    await _showCopyDialog(
      tester,
      project,
      size: const Size(360, 740),
      textScale: 1.35,
    );
    await _tapCopyControl(tester, 'architect-copy-new-storeys');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('architect-copy-batch-height')),
      '3,10',
    );
    await _tapCopyControl(tester, 'architect-copy-batch-submit');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('architect-copy-submit')).hitTestable(),
      findsOneWidget,
    );
  });

  if (Platform.environment['UPDATE_STOREY_COPY_PREVIEWS'] == 'true') {
    for (final entry in {
      'desktop': const Size(1200, 900),
      'phone': const Size(390, 844),
    }.entries) {
      for (final brightness in Brightness.values) {
        testWidgets('render ${entry.key} $brightness storey copy preview', (
          tester,
        ) async {
          await tester.runAsync(() async {
            final font = File('C:/Windows/Fonts/arial.ttf');
            if (await font.exists()) {
              await (FontLoader(
                'Roboto',
              )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
            }
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
          await _showCopyDialog(
            tester,
            project,
            size: entry.value,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('storey-copy-test-boundary')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'scratch/storey_copy_${entry.key}_${brightness.name}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        });
      }
    }
  }

  testWidgets(
    'ArchitectStoreysScreen renders multi-storey layout and manages levels',
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

      // The manager delegates to the shared copy dialog; opening it is read-only.
      final copyAction = find.byKey(const ValueKey('architect-storeys-copy'));
      expect(copyAction, findsOneWidget);
      await tester.tap(copyAction);
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectCopyStoreyDialog), findsOneWidget);
      expect(controller.undoCount, 0);
      await tester.tap(find.byKey(const ValueKey('architect-copy-submit')));
      await tester.pumpAndSettle();

      // Verify copy succeeded: storey_2 and storey_3 now have the walls and columns copied!
      final s2 = controller.project.storeys.firstWhere(
        (s) => s.id == 'storey_2',
      );
      final s3 = controller.project.storeys.firstWhere(
        (s) => s.id == 'storey_3',
      );

      expect(s2.walls.length, 1);
      expect(s2.columns.length, 1);
      expect(s3.walls.length, 1);
      expect(s3.columns.length, 1);
      expect(controller.undoCount, 1);
    },
  );
}
