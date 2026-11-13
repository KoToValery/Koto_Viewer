import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_storeys_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_workspace_view_bar.dart';
import 'architect_opening_continuous_placement_test.dart' as workspace;

ArchitectProject _project() => ArchitectProject(
  id: 'manager',
  name: 'House 01',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's1',
  storeys: const [
    ArchitectStorey(
      id: 's1',
      name: 'Level 1',
      elevation: 0,
      height: 2.8,
      walls: [
        ArchitectWall(
          id: 'a',
          startPoint: Offset(0, 0),
          endPoint: Offset(6, 0),
        ),
        ArchitectWall(
          id: 'b',
          startPoint: Offset(6, 0),
          endPoint: Offset(6, 4),
        ),
        ArchitectWall(
          id: 'c',
          startPoint: Offset(6, 4),
          endPoint: Offset(0, 4),
        ),
        ArchitectWall(
          id: 'd',
          startPoint: Offset(0, 4),
          endPoint: Offset(0, 0),
        ),
      ],
    ),
    ArchitectStorey(id: 's2', name: 'Level 2', elevation: 2.8, height: 2.8),
    ArchitectStorey(id: 'roof', name: '', elevation: 5.6, isRoof: true),
  ],
);

Future<void> _open(
  WidgetTester tester,
  ArchitectCommandController controller, {
  Size size = const Size(1200, 900),
  String language = 'bg',
  Brightness brightness = Brightness.light,
  double textScale = 1,
  ValueChanged<String?>? onReturn,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-manager'),
            child: const Text('Drawing'),
            onPressed: () async {
              final result = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => RepaintBoundary(
                    key: const ValueKey('manager-capture'),
                    child: ArchitectStoreysScreen(controller: controller),
                  ),
                ),
              );
              onReturn?.call(result);
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-manager')));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['bg', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'manager has a visible return on a narrow $language $brightness phone',
        (tester) async {
          final model = ArchitectCommandController(_project());
          addTearDown(model.dispose);
          String? returned;
          await _open(
            tester,
            model,
            size: const Size(360, 740),
            language: language,
            brightness: brightness,
            textScale: 1.35,
            onReturn: (id) => returned = id,
          );
          expect(tester.takeException(), isNull);
          expect(
            find
                .byKey(const ValueKey('architect-storeys-return'))
                .hitTestable(),
            findsOneWidget,
          );
          await _tap(tester, 'architect-storeys-select-s2');
          await _tap(tester, 'architect-storeys-return');
          expect(find.byType(ArchitectStoreysScreen), findsNothing);
          expect(returned, 's2');
          expect(model.undoCount, 0);
        },
      );
    }
  }

  testWidgets(
    'single addition validates, returns the new floor, and undoes once',
    (tester) async {
      final model = ArchitectCommandController(_project());
      addTearDown(model.dispose);
      String? returned;
      await _open(
        tester,
        model,
        language: 'en',
        onReturn: (id) => returned = id,
      );
      await _tap(tester, 'architect-storeys-add');
      await tester.enterText(
        find.byKey(const ValueKey('architect-storeys-height')),
        'NaN',
      );
      await _tap(tester, 'architect-storeys-save');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(model.undoCount, 0);
      await tester.enterText(
        find.byKey(const ValueKey('architect-storeys-height')),
        '3,20',
      );
      await _tap(tester, 'architect-storeys-save');
      final added = model.project.storeys.singleWhere(
        (s) => s.name == 'Storey 3',
      );
      expect(added.height, 3.2);
      expect(added.elevation, 5.6);
      expect(model.project.roofStorey!.elevation, closeTo(8.8, 1e-8));
      expect(model.undoCount, 1);
      await _tap(tester, 'architect-storeys-return');
      expect(returned, added.id);
      model.undo();
      expect(model.project.storeys.length, 3);
      model.redo();
      expect(model.project.storeys.length, 4);
    },
  );

  testWidgets('height edits, batch additions and deletion use shared history', (
    tester,
  ) async {
    final model = ArchitectCommandController(_project());
    addTearDown(model.dispose);
    await _open(tester, model);
    await _tap(tester, 'architect-storeys-edit-s1');
    await tester.enterText(
      find.byKey(const ValueKey('architect-storeys-name')),
      'Ground',
    );
    await tester.enterText(
      find.byKey(const ValueKey('architect-storeys-height')),
      '3',
    );
    await _tap(tester, 'architect-storeys-save');
    expect(model.project.storeys.first.name, 'Ground');
    expect(model.project.storeys[1].elevation, 3);
    expect(model.undoCount, 1);
    await _tap(tester, 'architect-storeys-batch');
    await tester.enterText(
      find.byKey(const ValueKey('architect-storeys-batch-count')),
      '2',
    );
    await _tap(tester, 'architect-storeys-batch-submit');
    expect(model.project.storeys.where((s) => !s.isRoof).length, 4);
    expect(model.undoCount, 2);
    await _tap(tester, 'architect-storeys-undo');
    expect(model.project.storeys.where((s) => !s.isRoof).length, 2);
    await _tap(tester, 'architect-storeys-select-s2');
    await _tap(tester, 'architect-storeys-delete-s2');
    await _tap(tester, 'architect-storeys-delete-confirm');
    expect(model.project.storeys.where((s) => !s.isRoof).length, 1);
    expect(
      find.byKey(const ValueKey('architect-storeys-delete-s1')),
      findsNothing,
    );
    await _tap(tester, 'architect-storeys-back');
    expect(find.byType(ArchitectStoreysScreen), findsNothing);
  });

  testWidgets('workspace return opens the selected storey after adding it', (
    tester,
  ) async {
    final model = ArchitectCommandController(_project());
    addTearDown(model.dispose);
    await workspace.openWorkspace(tester, model);
    tester
        .widget<ArchitectWorkspaceViewBar>(
          find.byType(ArchitectWorkspaceViewBar),
        )
        .onManage(ArchitectWorkspaceView.plan);
    await tester.pumpAndSettle();
    await _tap(tester, 'architect-storeys-add');
    await _tap(tester, 'architect-storeys-save');
    final added = model.project.storeys.singleWhere(
      (s) => s.name == 'Storey 3',
    );
    await _tap(tester, 'architect-storeys-return');
    expect(model.project.activeStoreyId, added.id);
    expect(
      find.byKey(const ValueKey('architect-viewport-input')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  if (Platform.environment['UPDATE_STOREY_MANAGER_PREVIEWS'] == 'true') {
    for (final entry in {
      'desktop': const Size(1200, 900),
      'phone': const Size(390, 844),
    }.entries) {
      for (final brightness in Brightness.values) {
        testWidgets('manager preview ${entry.key} $brightness', (tester) async {
          await tester.runAsync(() async {
            await (FontLoader('Roboto')..addFont(
                  rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
                ))
                .load();
          });
          final model = ArchitectCommandController(_project());
          addTearDown(model.dispose);
          await _open(tester, model, size: entry.value, brightness: brightness);
          expect(tester.takeException(), isNull);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('manager-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'scratch/storeys_manager_${entry.key}_${brightness.name}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        });
      }
    }
  }
}
