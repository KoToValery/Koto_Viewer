import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_slab_layers_dialog.dart';
import 'architect_slab_assembly_test.dart' as fixture;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tools;

Widget host(Widget child, String locale, {GlobalKey? capture}) =>
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'TestReadable', useMaterial3: true),
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

Future<void> capturePhone(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  if (!const bool.fromEnvironment('SLAB_QA_CAPTURE')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/architect-slab-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    // Real glyphs for inspectable screenshots, without network font downloads.
    final file = File('C:/Windows/Fonts/arial.ttf');
    if (!Platform.isWindows || !file.existsSync()) return;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('TestReadable')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('workspace opens slab layers through properties and saves to shared history', (tester) async {
    final controller = ArchitectCommandController(fixture.slabProject());
    addTearDown(controller.dispose);
    await workspace.open(tester, controller);
    await tools.choose(tester, Icons.layers_rounded);
    final gesture = await tester.startGesture(workspace.screen(tester, const Offset(2, 2)));
    await tester.pump(const Duration(milliseconds: 451)); await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-selection-properties')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-property-slab-layers')));
    await tester.pumpAndSettle();
    expect(find.byType(ArchitectSlabLayersDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('slab-layers-save')));
    await tester.pumpAndSettle();
    expect(controller.project.activeStorey.slabs.single.assemblyId, isNotNull);
    expect(controller.project.activeStorey.slabs.single.thickness, .2);
    controller.undo(); await tester.pumpAndSettle();
    expect(controller.project.activeStorey.slabs.single.assemblyId, isNull);
    await tester.tap(find.byKey(const ValueKey('architect-building-sections')));
    await tester.pumpAndSettle();
    expect(find.byType(ArchitectBuildingSectionsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['bg', 'en']) {
    testWidgets('slab editor fits phone and edits a lower layer ($locale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final a = ArchitectSlabCatalog.preset(SlabUsage.basement);
      final p = fixture.slabProject(assembly: a);
      final key = GlobalKey();
      await tester.pumpWidget(
        host(
          Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => ArchitectSlabLayersDialog(
                      project: p,
                      slab: p.activeStorey.slabs.single,
                      onApply: (_) => true,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
          locale,
          capture: key,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final lower = find.widgetWithText(
        ChoiceChip,
        locale == 'bg' ? 'Под бетона' : 'Below concrete',
      );
      await tester.ensureVisible(lower);
      await tester.tap(lower);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final xps = find.widgetWithText(ListTile, 'XPS');
      await tester.ensureVisible(xps);
      await tester.tap(xps);
      await tester.pumpAndSettle();
      expect(
        find.text(locale == 'bg' ? 'Дебелина (mm)' : 'Thickness (mm)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(locale == 'bg' ? 'Отказ' : 'Cancel').last);
      await tester.pumpAndSettle();
      await capturePhone(tester, key, 'layers-$locale');
    });

    testWidgets(
      'section detail rendering, history and lost link fit phone ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final a = ArchitectSlabCatalog.preset(SlabUsage.invertedRoof);
        final p = fixture
            .slabProject(
              assembly: a,
              plate: fixture.slab.copyWith(slopeDirection: 0),
            )
            .copyWith(
              sections: [
                fixture.cut.copyWith(
                  details: [
                    const ArchitectSlabDetail(
                      id: 'd',
                      slabId: 'slab',
                      station: 5,
                      textOffset: Offset(1, 2),
                    ),
                  ],
                ),
              ],
            );
        final controller = ArchitectCommandController(p);
        addTearDown(controller.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          host(
            ArchitectBuildingSectionsScreen(controller: controller),
            locale,
            capture: key,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capturePhone(tester, key, 'section-$locale');
        controller.commit(
          controller.project.updateActiveStorey(
            controller.project.activeStorey.copyWith(slabs: []),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        controller.undo();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('cut line and viewing side save a section and undo removes it', (
    tester,
  ) async {
    final controller = ArchitectCommandController(fixture.slabProject());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(ArchitectBuildingSectionsScreen(controller: controller), 'en'),
    );
    await tester.pumpAndSettle();
    final bounds = tester.getRect(
      find.byKey(const ValueKey('building-section-plan')),
    );
    await tester.tapAt(bounds.centerLeft + const Offset(30, 0));
    await tester.pump();
    await tester.tapAt(bounds.centerRight - const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(controller.project.sections, isEmpty);
    await tester.tapAt(bounds.center + const Offset(0, 30));
    await tester.pumpAndSettle();
    expect(controller.project.sections, hasLength(1));
    expect(
      find.byKey(const ValueKey('section-add-slab-detail')),
      findsOneWidget,
    );
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.project.sections, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'two detail taps associate the actual slab and undo preserves its identity',
    (tester) async {
      final a = ArchitectSlabCatalog.preset(SlabUsage.intermediate);
      final controller = ArchitectCommandController(
        fixture.slabProject(assembly: a).copyWith(sections: [fixture.cut]),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(ArchitectBuildingSectionsScreen(controller: controller), 'en'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-add-slab-detail')));
      await tester.pumpAndSettle();
      Offset screen(Offset model) {
        final rect = tester.getRect(
          find.byKey(const ValueKey('building-section-view')),
        );
        final bounds = ArchitectBuildingSection.build(
          controller.project,
          fixture.cut,
        ).bounds.inflate(.8);
        final sx = rect.width / bounds.width, sy = rect.height / bounds.height;
        final scale = sx < sy ? sx : sy;
        return rect.center +
            Offset(
              (model.dx - bounds.center.dx) * scale,
              -(model.dy - bounds.center.dy) * scale,
            );
      }

      await tester.tapAt(screen(const Offset(4, -.1)));
      await tester.pumpAndSettle();
      await tester.tapAt(screen(const Offset(7, .5)));
      await tester.pumpAndSettle();
      final detail = controller.project.sections.single.details.single;
      expect(detail.slabId, fixture.slab.id);
      expect(detail.station, closeTo(4, 1e-8));
      controller.undo();
      await tester.pumpAndSettle();
      expect(controller.project.sections.single.details, isEmpty);
      controller.redo();
      await tester.pumpAndSettle();
      expect(controller.project.sections.single.details.single.id, detail.id);
      expect(tester.takeException(), isNull);
    },
  );
}
