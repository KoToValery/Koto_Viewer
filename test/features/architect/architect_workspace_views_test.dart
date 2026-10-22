import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';
import 'architect_elevation_test.dart' as fixture;
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectProject project() => fixture.elevationProject().copyWith(
  sections: const [
    ArchitectSection(id: 'cut', start: Offset(-1, 2), end: Offset(9, 2)),
  ],
);

Future<void> select(WidgetTester tester, String type, String id) async {
  await tester.tap(find.byKey(ValueKey('architect-view-$type')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is CheckedPopupMenuItem<String> && w.value == id,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await qa.loadQaFonts();
    final file = File('C:/Windows/Fonts/arial.ttf');
    if (file.existsSync()) {
      await (FontLoader('Roboto')..addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          ))
          .load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'view drafting persists separately with shared history and old-file defaults',
    () {
      final source = ArchitectCommandController(project());
      final view = ArchitectWorkspaceViewController(source);
      addTearDown(source.dispose);
      addTearDown(view.dispose);
      final floors = source.project.storeys.map((s) => s.toJson()).toList();
      view.select(ArchitectWorkspaceView.elevation, fixture.facade.id);
      view.execute(
        PlaceArchitectCadPrimitive(
          storeyId: view.project.activeStoreyId,
          primitive: const ArchitectCadPrimitive(
            id: 'line',
            type: CadPrimitiveType.line,
            startPoint: Offset(1, -1),
            endPoint: Offset(3, -1),
          ),
        ),
      );
      final count = source.undoCount;
      view.select(ArchitectWorkspaceView.section, 'cut');
      expect(view.project.activeStorey.cadPrimitives, isEmpty);
      expect(source.undoCount, count);
      view.commit(
        view.project.updateActiveStorey(
          view.project.activeStorey.copyWith(
            annotations: const [
              ArchitectAnnotation(
                id: 'text',
                position: Offset(2, -2),
                text: 'Detail',
              ),
            ],
            dimensions: const [
              ArchitectDimension(
                id: 'dim',
                startPoint: Offset(0, -1),
                endPoint: Offset(4, -1),
              ),
            ],
            elevationMarkers: const [
              ArchitectElevationMarker(
                id: 'level',
                position: Offset(2, -3),
                elevation: 3,
              ),
            ],
          ),
        ),
      );
      expect(source.project.storeys.map((s) => s.toJson()).toList(), floors);
      expect(source.project.elevations.single.drawing.annotations, isEmpty);
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(source.project.toJson())),
      );
      expect(
        restored.elevations.single.drawing.cadPrimitives.single.id,
        'line',
      );
      expect(
        restored.sections.single.drawing.annotations.single.text,
        'Detail',
      );
      expect(restored.sections.single.drawing.dimensions.single.id, 'dim');
      expect(
        restored.sections.single.drawing.elevationMarkers.single.elevation,
        3,
      );
      view.undo();
      expect(view.project.activeStorey.annotations, isEmpty);
      view.redo();
      expect(view.project.activeStorey.annotations.single.text, 'Detail');
      view.select(ArchitectWorkspaceView.plan, null);
      expect(view.project.activeStorey.annotations, isEmpty);
      final old = source.project.toJson();
      (old['elevations'] as List).cast<Map>().single.remove('drawing');
      (old['sections'] as List).cast<Map>().single.remove('drawing');
      final legacy = ArchitectProject.fromJson(old);
      expect(legacy.elevations.single.drawing.cadPrimitives, isEmpty);
      expect(legacy.sections.single.drawing.annotations, isEmpty);
    },
  );

  testWidgets('new facade selected in management returns to the main canvas', (
    tester,
  ) async {
    final source = ArchitectCommandController(
      fixture.elevationProject(markers: false),
    );
    addTearDown(source.dispose);
    await workspace.open(tester, source);
    await tester.tap(find.byKey(const ValueKey('architect-view-elevation')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('architect-building-elevations')),
    );
    await tester.pumpAndSettle();
    await qa.tapPlan(tester, source.project, const Offset(-1, -2));
    await qa.tapPlan(tester, source.project, const Offset(9, -2));
    await qa.tapPlan(tester, source.project, const Offset(4, 0));
    expect(source.project.elevations, hasLength(1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('architect-workspace-projection')),
      findsOneWidget,
    );
    await tools.choose(tester, Icons.timeline_rounded);
    await tester.pumpAndSettle();
    await workspace.wallTap(tester, const Offset(1, -1));
    await workspace.wallTap(tester, const Offset(4, -1));
    await tester.tap(find.byKey(const ValueKey('wall-end')));
    await tester.pumpAndSettle();
    expect(
      source.project.elevations.single.drawing.cadPrimitives,
      hasLength(1),
    );
    expect(source.project.activeStorey.cadPrimitives, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final type in ['elevation', 'section']) {
    for (final entry in {
      'rect': Icons.crop_square_rounded,
      'circle': Icons.radio_button_unchecked_rounded,
      'dimension': Icons.straighten_rounded,
      'measure': Icons.square_foot_rounded,
    }.entries) {
      testWidgets('${entry.key} works on the main $type canvas', (
        tester,
      ) async {
        final source = ArchitectCommandController(project());
        addTearDown(source.dispose);
        await workspace.open(tester, source);
        await select(
          tester,
          type,
          type == 'elevation' ? fixture.facade.id : 'cut',
        );
        await tools.choose(tester, entry.value);
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(1, -1));
        await workspace.wallTap(tester, const Offset(4, -2));
        if (entry.key == 'circle' || entry.key == 'rect') {
          await tester.tap(find.byKey(const ValueKey('shape-save')));
          await tester.pumpAndSettle();
        } else if (entry.key == 'dimension') {
          await tester.tap(
            find.byKey(const ValueKey('architect-dimension-confirm')),
          );
          await tester.pumpAndSettle();
        }
        final drawing = type == 'elevation'
            ? source.project.elevations.single.drawing
            : source.project.sections.single.drawing;
        if (entry.key == 'dimension') {
          expect(drawing.dimensions, hasLength(1));
        } else if (entry.key == 'measure') {
          expect(source.canUndo, isFalse);
        } else {
          expect(drawing.cadPrimitives, hasLength(1));
        }
        expect(source.project.activeStorey.dimensions, isEmpty);
        expect(source.project.activeStorey.cadPrimitives, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final locale in ['bg', 'en']) {
    testWidgets(
      'phone dropdowns, drawing, text, levels and view cameras ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = ArchitectCommandController(project());
        addTearDown(source.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            theme: ThemeData(fontFamily: 'TestReadable', useMaterial3: true),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: capture,
              child: ArchitectWorkspaceScreen(commandController: source),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await select(tester, 'plan', 's1');
        expect(source.project.activeStoreyId, 's1');
        final undo = source.undoCount;
        await select(tester, 'elevation', fixture.facade.id);
        expect(source.undoCount, undo);
        expect(
          find.byKey(const ValueKey('architect-workspace-projection')),
          findsOneWidget,
        );
        await tools.choose(tester, Icons.timeline_rounded);
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(1, -1));
        await workspace.wallTap(tester, const Offset(4, -1));
        await tester.tap(find.byKey(const ValueKey('wall-end')));
        await tester.pumpAndSettle();
        expect(
          source.project.elevations.single.drawing.cadPrimitives,
          hasLength(1),
        );
        final camera = workspace.camera(tester);
        camera.navigate(
          previousFocal: camera.size.center(Offset.zero),
          focal: camera.size.center(Offset.zero),
          scaleFactor: 1.15,
        );
        camera.panBy(const Offset(12, -18));
        await tester.pump();
        final savedScale = camera.scale, savedTranslation = camera.translation;
        await select(tester, 'section', 'cut');
        await tools.choose(tester, Icons.title_rounded);
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(2, -2));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Detail A');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();
        expect(
          source.project.sections.single.drawing.annotations.single.text,
          'Detail A',
        );
        await tools.choose(tester, Icons.change_history_rounded);
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(4, -3));
        expect(
          source
              .project
              .sections
              .single
              .drawing
              .elevationMarkers
              .single
              .elevation,
          3,
        );
        expect(source.project.activeStorey.annotations, isEmpty);
        expect(source.project.elevations.single.drawing.annotations, isEmpty);
        await tester.tap(find.byKey(const ValueKey('architect-undo')));
        await tester.pumpAndSettle();
        expect(
          source.project.sections.single.drawing.elevationMarkers,
          isEmpty,
        );
        await tester.tap(find.byKey(const ValueKey('architect-redo')));
        await tester.pumpAndSettle();
        expect(
          source.project.sections.single.drawing.elevationMarkers,
          hasLength(1),
        );
        await select(tester, 'elevation', fixture.facade.id);
        expect(camera.scale, closeTo(savedScale, 1e-8));
        expect(
          (camera.translation - savedTranslation).distance,
          lessThan(1e-8),
        );
        expect(
          workspace.overlay(tester).project.activeStorey.cadPrimitives,
          hasLength(1),
        );
        await tester.tap(find.byKey(const ValueKey('architect-tool-category')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('architect-category-build')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('architect-category-drawing')),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(10, 90));
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('WORKSPACE_VIEWS_QA_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/architect-workspace-views-qa/facade-$locale.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
