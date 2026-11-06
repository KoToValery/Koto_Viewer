import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_composer.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_layout.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheets_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheet_viewport.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_catalog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_workspace_settings_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_types_manager.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_composition_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_slab_layers_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layers_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_component_library_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_project_wizard_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_zone_presets_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_view_properties_dialog.dart';
import 'package:kotoview/src/features/architect/models/architect_zone_presets.dart';
import 'package:kotoview/src/features/architect/widgets/architect_properties_shell.dart';
import 'package:kotoview/src/features/architect/widgets/architect_zone_schedule_dialog.dart';
import 'architect_publication_test.dart' as publication;
import 'architect_elevation_ui_test.dart' as qa;

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('ARCHITECT_MOBILE_QA')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/architect_mobile_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await qa.loadQaFonts();
    await (FontLoader('ArchitectNoto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'fit retains rotation and refuses a frame too small for fixed paper text',
    () async {
      final l = await AppLocalizations.delegate.load(const Locale('bg'));
      final p = publication.fixture();
      const place = ArchitectDrawingPlacement(
        id: 'v',
        drawingId: 'plan:s',
        frame: Rect.zero,
        anchor: Offset.zero,
        scale: 20,
        rotation: 90,
      );
      final result = ArchitectSheetLayout.fit(
        place,
        const Rect.fromLTWH(10, 10, 260, 150),
        (scale) =>
            ArchitectDrawingPublisher.build(p, publication.drawing, scale, l),
        title: (scale) => '1  План  1:$scale',
      );
      expect(result.rotation, 90);
      expect(result.anchor.dx.isFinite && result.anchor.dy.isFinite, isTrue);
      expect(
        () => ArchitectSheetLayout.fit(
          place,
          const Rect.fromLTWH(0, 0, 5, 5),
          (scale) =>
              ArchitectDrawingPublisher.build(p, publication.drawing, scale, l),
          title: (scale) => '1  План  1:$scale',
        ),
        throwsA(isA<ArchitectSheetFitException>()),
      );
    },
  );

  for (final language in ['bg', 'en']) {
    test(
      'layout protects margins, titles and the title block ($language)',
      () async {
        final l = await AppLocalizations.delegate.load(Locale(language));
        final p = publication.fixture().copyWith(
          document: const ArchitectDocument(drawings: [publication.drawing]),
        );
        const sheet = ArchitectSheet(id: 's', widthMm: 297, heightMm: 210);
        final area = ArchitectSheetLayout.drawingArea(p, sheet);
        final fitted = ArchitectSheetLayout.fit(
          const ArchitectDrawingPlacement(
            id: 'v',
            drawingId: 'plan:s',
            frame: Rect.zero,
            anchor: Offset.zero,
            scale: 20,
          ),
          area,
          (scale) =>
              ArchitectDrawingPublisher.build(p, publication.drawing, scale, l),
          title: (scale) => '1  ${l.architectSheetPlan}  1:$scale',
        );
        final placed = sheet.copyWith(placements: [fitted]);
        expect(fitted.scale, greaterThan(20));
        expect(ArchitectSheetComposer.issues(p, placed, l), isEmpty);
        final scene = ArchitectDrawingPublisher.build(
          p,
          publication.drawing,
          fitted.scale,
          l,
        );
        expect(
          scene.bounds.width + 4,
          lessThanOrEqualTo(fitted.frame.width + .01),
        );
        expect(
          scene.bounds.height + 4,
          lessThanOrEqualTo(fitted.frame.height + .01),
        );
        expect(
          ArchitectSheetComposer.issues(
            p,
            sheet.copyWith(
              placements: [
                fitted.copyWith(
                  frame: fitted.frame.shift(const Offset(-20, 0)),
                ),
              ],
            ),
            l,
          ),
          contains(l.architectSheetOutside),
        );
        expect(
          ArchitectSheetComposer.issues(
            p,
            sheet.copyWith(
              placements: [
                fitted,
                fitted.copyWith(number: '2'),
              ],
            ),
            l,
          ),
          contains(l.architectSheetOverlap),
        );
        final overlapped = sheet.copyWith(
          placements: [fitted.copyWith(frame: Rect.fromLTWH(20, 160, 150, 30))],
        );
        expect(
          ArchitectSheetComposer.issues(p, overlapped, l),
          contains(l.architectSheetTitleOverlap),
        );
        await expectLater(
          ArchitectPdfExport.export(p, [overlapped], l),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'reason',
              contains(l.architectSheetTitleOverlap),
            ),
          ),
        );
        final remaining = ArchitectSheetLayout.freeArea(p, placed, l);
        if (remaining != null) {
          expect(remaining.overlaps(fitted.frame), isFalse);
        }
      },
    );
  }

  test(
    'empty title cells and line rules remain valid printable vectors',
    () async {
      final l = await AppLocalizations.delegate.load(const Locale('bg'));
      final p = publication.fixture().copyWith(
        document: const ArchitectDocument(
          templates: [
            ArchitectSheetTemplate(
              id: 'rules',
              items: [
                ArchitectTitleItem(
                  id: 'line',
                  rect: Rect.fromLTWH(0, 0, 180, 0),
                ),
                ArchitectTitleItem(
                  id: 'vertical',
                  rect: Rect.fromLTWH(0, 0, 0, 20),
                ),
                ArchitectTitleItem(
                  id: 'blank',
                  rect: Rect.fromLTWH(0, 0, 30, 5),
                ),
              ],
            ),
          ],
        ),
      );
      const sheet = ArchitectSheet(id: 's', templateId: 'rules');
      expect(ArchitectSheetComposer.issues(p, sheet, l), isEmpty);
      final bytes = await ArchitectPdfExport.export(p, [sheet], l);
      expect(bytes.length, greaterThan(100));
    },
  );

  for (final language in ['bg', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'phone tool search selects directly and respects theme ($language/$dark)',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final c = ArchitectCommandController(publication.fixture());
          addTearDown(c.dispose);
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                  fontFamily: 'TestReadable',
                ),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: ArchitectWorkspaceScreen(commandController: c),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('architect-tool-category')),
          );
          await tester.pumpAndSettle();
          await capture(tester, key, 'tools-$language-$dark');
          final l = AppLocalizations.of(
            tester.element(find.byType(ArchitectToolBrowser)),
          )!;
          await tester.enterText(
            find.byKey(const ValueKey('architect-tool-search')),
            l.architectToolRoof,
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('architect-catalog-tool-roof')),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
                .activeTool,
            ArchitectTool.roof,
          );
          expect(
            Theme.of(
              tester.element(find.byKey(const ValueKey('architect-tool-roof'))),
            ).brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          expect(
            find.byKey(const ValueKey('architect-tool-pan')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'architect dialogs remain readable on 320px with large text ($language/$dark)',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = publication.fixture().copyWith(
            sections: [
              const ArchitectSection(
                id: 'section',
                start: Offset(0, 2),
                end: Offset(6, 2),
              ),
            ],
          );
          final c = ArchitectCommandController(p);
          addTearDown(c.dispose);
          final dialogs = <String, Widget Function()>{
            'settings': () => ArchitectWorkspaceSettingsDialog(
              settings: const ArchitectWorkspaceSettings(
                units: ArchitectUnit.centimeters,
                ghostStoreys: false,
                grid: true,
                magnetic: true,
                underlay: false,
                darkCanvas: false,
                axisCoreThickness: .25,
              ),
              hasUnderlay: false,
            ),
            'walls': () =>
                ArchitectWallTypesManager(project: p, onApply: (_) => true),
            'wall-composition': () => ArchitectWallCompositionEditor(
              project: p,
              type: ArchitectWallType.standardCatalog().first,
              onApply: (_, _, _) => true,
            ),
            'slab': () => ArchitectSlabLayersDialog(
              project: p,
              slab: const ArchitectSlab(
                id: 'slab',
                polygon: [
                  Offset.zero,
                  Offset(6, 0),
                  Offset(6, 5),
                  Offset(0, 5),
                ],
              ),
              onApply: (_) => true,
            ),
            'roof': () => ArchitectRoofLayersDialog(
              initialAssembly: ArchitectRoofAssembly.fromPreset(
                ArchitectRoofPreset.values.first,
              ),
              initialSlopeDegrees: 30,
              initialEavesOverhang: .5,
              initialEavesCut: ArchitectRoofEavesCut.values.first,
              onApply: (_) {},
            ),
            'stair': () => ArchitectStairPropertiesDialog(
              project: p,
              stair: const ArchitectStair(
                id: 'stair',
                startPoint: Offset.zero,
                endPoint: Offset(4, 0),
              ),
              onApply: (_) => true,
            ),
            'library': () => const ArchitectComponentLibraryDialog(),
            'wizard': () => const ArchitectProjectWizardDialog(),
            'zones': () => ArchitectZonePresetsDialog(
              presets: const ArchitectZonePresets(),
              onSave: (_) {},
            ),
            'schedule': () => ArchitectZoneScheduleDialog(
              storey: p.activeStorey,
              onZoneUpdated: (_) {},
              onTableOriginChanged: (_) {},
            ),
            'section': () => ArchitectViewPropertiesDialog(
              project: p,
              viewId: 'section',
              controller: c,
            ),
          };
          for (final entry in dialogs.entries) {
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp(
                  key: ValueKey(entry.key),
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light,
                    fontFamily: 'TestReadable',
                  ),
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(1.4)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        key: const ValueKey('open'),
                        onPressed: () {
                          if ([
                            'wall-composition',
                            'slab',
                            'roof',
                            'stair',
                            'section',
                          ].contains(entry.key)) {
                            showArchitectProperties<void>(
                              context: context,
                              builder: (_) => entry.value(),
                            );
                          } else {
                            showDialog<void>(
                              context: context,
                              builder: (_) => entry.value(),
                            );
                          }
                        },
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('open')));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key}/$language/$dark',
            );
            await capture(tester, key, '${entry.key}-$language-$dark');
            final fields = find.byType(TextField);
            if (fields.evaluate().isNotEmpty) {
              await tester.ensureVisible(fields.first);
              await tester.tap(fields.first);
              tester.view.viewInsets = const FakeViewPadding(bottom: 260);
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${entry.key}/keyboard/$language/$dark',
              );
              await capture(
                tester,
                key,
                '${entry.key}-keyboard-$language-$dark',
              );
              tester.view.resetViewInsets();
              FocusManager.instance.primaryFocus?.unfocus();
              await tester.pumpAndSettle();
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          }
        },
      );

      testWidgets('phone sheet workflow and dialogs ($language/$dark)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = ArchitectCommandController(
          publication.fixture().copyWith(
            document: const ArchitectDocument(
              sheets: [ArchitectSheet(id: 'sheet')],
            ),
          ),
        );
        addTearDown(c.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                fontFamily: 'TestReadable',
              ),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.4)),
                child: child!,
              ),
              home: ArchitectSheetsScreen(controller: c),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectSheetsScreen)),
        )!;
        await tester.tap(find.byTooltip(l.architectSheetPlace));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Етаж 1').last);
        await tester.pumpAndSettle();
        expect(c.project.document.sheets.single.placements, isEmpty);
        final viewportState = tester.state<ArchitectSheetViewportState>(
          find.byType(ArchitectSheetViewport),
        );
        final input = find.byKey(
          const ValueKey('architect-sheet-viewport-input'),
        );
        await tester.tapAt(
          tester.getTopLeft(input) +
              viewportState.paperToScreen(const Offset(10, 10)),
        );
        await tester.pumpAndSettle();
        expect(c.project.document.sheets.single.placements, hasLength(1));
        // Fitting is now an explicit action, after freely placing the source.
        await tester.tap(find.byTooltip(l.architectSheetFitView));
        await tester.pumpAndSettle();
        expect(
          ArchitectSheetComposer.issues(
            c.project,
            c.project.document.sheets.single,
            l,
          ),
          isEmpty,
        );
        await capture(tester, key, 'sheet-$language-$dark');
        final viewport = tester.getRect(input);
        final topLeft =
            viewport.topLeft + viewportState.paperToScreen(Offset.zero);
        final bottomRight =
            viewport.topLeft +
            viewportState.paperToScreen(
              Offset(
                c.project.document.sheets.single.widthMm,
                c.project.document.sheets.single.heightMm,
              ),
            );
        expect(viewport.contains(topLeft), isTrue);
        expect(viewport.contains(bottomRight), isTrue);
        await tester.tap(find.byTooltip(l.architectSheetEdit));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'placement-$language-$dark');
        final beforeProperties = c
            .project
            .document
            .sheets
            .single
            .placements
            .single
            .toJson();
        for (final field in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          expect(field.controller!.text.length, lessThan(13));
        }
        await tester.tap(find.text(l.architectSheetSave));
        await tester.pumpAndSettle();
        expect(
          c.project.document.sheets.single.placements.single.toJson(),
          beforeProperties,
        );
        await tester.tap(find.byKey(const ValueKey('architect-sheet-crop')));
        await tester.pumpAndSettle();
        await capture(tester, key, 'crop-rectangle-$language-$dark');
        await tester.tap(
          find.byKey(const ValueKey('architect-sheet-crop-polygon')),
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-sheet-crop-add-point')),
        );
        await tester.pumpAndSettle();
        await capture(tester, key, 'crop-polygon-$language-$dark');
        final saveButton = find.byKey(
          const ValueKey('architect-sheet-crop-save'),
        );
        expect(
          tester.getRect(input).overlaps(tester.getRect(saveButton)),
          isTrue,
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-sheet-crop-cancel')),
        );
        await tester.pumpAndSettle();
        expect(
          c.project.document.sheets.single.placements.single.toJson(),
          beforeProperties,
        );
        await tester.tap(find.byTooltip(l.architectSheetVisibility));
        await tester.pumpAndSettle();
        await capture(tester, key, 'visibility-$language-$dark');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l.architectSheetCancel));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('architect-sheet-export')));
        await tester.pumpAndSettle();
        await capture(tester, key, 'export-$language-$dark');
        expect(find.text(l.architectSheetExportOrder), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l.architectSheetCancel));
        await tester.pumpAndSettle();
      });
    }
  }
}
