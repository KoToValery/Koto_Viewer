import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_drawing_color.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_hatch_pattern.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_drawing_color_picker.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_hatch_picker.dart';
import 'architect_hatch_test.dart' as hatches;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectDrawingColor preset(String id) {
  final p = ArchitectDrawingColors.find(id)!;
  return ArchitectDrawingColor(p.argb, presetId: p.id);
}

ArchitectCadPrimitive fill([
  ArchitectDrawingColor color = ArchitectDrawingColor.ink,
]) => hatches.hatch.copyWith(
  hatchPattern: ArchitectHatchPattern.solid,
  colorValue: color.argb,
  colorPresetId: color.presetId,
  holes: const [
    [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)],
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  });
  test(
    'Planning palettes separate OUP/PUP references, tone variants and PlanZV groups',
    () async {
      expect(
        ArchitectDrawingColors.presets.map((p) => p.id).toSet().length,
        ArchitectDrawingColors.presets.length,
      );
      expect(
        ArchitectDrawingColors.presets.where(
          (p) => p.palette == ArchitectColorPalette.bgOup,
        ),
        hasLength(13),
      );
      expect(
        ArchitectDrawingColors.presets.where(
          (p) => p.palette == ArchitectColorPalette.bgPup,
        ),
        hasLength(21),
      );
      expect(
        ArchitectDrawingColors.presets.where(
          (p) => p.palette == ArchitectColorPalette.dePlanZV,
        ),
        hasLength(12),
      );
      expect(preset('bgOupResidential').preset!.code, 'RAL 8023');
      expect(preset('bgPupHousingLowHigh').preset!.code, 'RAL 1019');
      expect(preset('bgPupHousingMediumComplex').preset!.code, 'RAL 1019+');
      expect(preset('bgPupIndustrial').preset!.code, 'RAL 4008+');
      expect(preset('bgPupServingRoad').preset!.code, 'RAL 4005++');
      expect(preset('bgPupHousingExisting').preset!.code, 'RAL 8004');
      expect(
        ArchitectDrawingColors.presets
            .where((p) => p.palette == ArchitectColorPalette.dePlanZV)
            .every((p) => !p.code.contains('RAL')),
        isTrue,
      );
      for (final p in ArchitectDrawingColors.presets) {
        ArchitectDrawingColor(p.argb, presetId: p.id).validate();
        for (final locale in ['bg', 'en']) {
          final l = await AppLocalizations.delegate.load(Locale(locale));
          expect(p.role.label(l), isNotEmpty);
          expect(p.palette.label(l), isNotEmpty);
        }
      }
    },
  );
  test(
    'Solid fill and referenced colors persist and batch properties have one Undo',
    () {
      ArchitectHatchPattern.solid.validate();
      expect(
        ArchitectHatchPattern.fromJson(ArchitectHatchPattern.solid.toJson()),
        ArchitectHatchPattern.solid,
      );
      final model = ArchitectCommandController(
        hatches.fixture([hatches.hatch, hatches.hatch.copyWith(id: 'h2')]),
      );
      addTearDown(model.dispose);
      final before = model.project.toJson();
      final color = preset('bgPupHousingLowHigh').withOpacity(65);
      model.execute(
        SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'h', 'h2'},
          textValues: {
            'hatchPattern': jsonEncode(ArchitectHatchPattern.solid.toJson()),
            'drawingColor': jsonEncode(color.toJson()),
          },
        ),
      );
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(model.project.toJson())) as Map<String, dynamic>,
      );
      for (final p in restored.activeStorey.cadPrimitives) {
        expect(p.hatchPattern.isSolid, isTrue);
        expect(p.drawingColor, color);
      }
      model.undo();
      expect(model.project.toJson(), before);
      model.redo();
      expect(
        model.project.activeStorey.cadPrimitives.first.drawingColor,
        color,
      );
    },
  );
  test(
    'Malformed color references are rejected atomically and custom RGB clears the reference',
    () {
      for (final data in [
        {'argb': -1},
        {'argb': 0x100000000},
        {'argb': 'red'},
        {'argb': 0xFF112233, 'presetId': 'missing'},
        {'argb': 0xFF112233, 'presetId': 'bgOupResidential'},
      ]) {
        expect(
          () => SetArchitectElementProperties(
            storeyId: 's',
            elementIds: {'h'},
            textValues: {'drawingColor': jsonEncode(data)},
          ).apply(hatches.fixture()),
          throwsArgumentError,
        );
      }
      final p = fill(preset('bgOupResidential'));
      expect(p.copyWith(colorValue: 0xFF112233).colorPresetId, isNull);
      expect(
        p
            .copyWith(colorValue: (p.colorValue & 0xFFFFFF) | 0x80000000)
            .colorPresetId,
        p.colorPresetId,
      );
      final old = hatches.hatch.toJson()..remove('colorPresetId');
      expect(
        ArchitectCadPrimitive.fromJson(old).drawingColor,
        ArchitectDrawingColor.ink,
      );
      expect(
        () => PlaceArchitectCadPrimitive(
          storeyId: 's',
          primitive: fill().copyWith(colorPresetId: 'bad'),
        ).apply(hatches.fixture([])),
        throwsArgumentError,
      );
    },
  );
  test(
    'Geometry edits and section-local drawings preserve RAL references and openings',
    () {
      var p = hatches.fixture([fill(preset('bgOupWater'))]);
      p = const MoveArchitectElements(
        storeyId: 's',
        elementIds: {'h'},
        delta: Offset(1, 2),
      ).apply(p);
      p = const MirrorArchitectElements(
        storeyId: 's',
        elementIds: {'h'},
        origin: Offset.zero,
        direction: Offset(0, 1),
        isDuplicate: true,
        idMap: {'h': 'copy'},
      ).apply(p);
      expect(
        p.activeStorey.cadPrimitives.every(
          (p) => p.colorPresetId == 'bgOupWater' && p.holes.length == 1,
        ),
        isTrue,
      );
      final source = ArchitectCommandController(
        hatches
            .fixture([])
            .copyWith(
              sections: const [
                ArchitectSection(
                  id: 'cut',
                  start: Offset.zero,
                  end: Offset(8, 0),
                ),
              ],
            ),
      );
      addTearDown(source.dispose);
      final view = ArchitectWorkspaceViewController(source);
      addTearDown(view.dispose);
      view.select(ArchitectWorkspaceView.section, 'cut');
      view.execute(
        PlaceArchitectCadPrimitive(
          storeyId: view.project.activeStoreyId,
          primitive: fill(preset('deTransport')),
        ),
      );
      expect(
        source
            .project
            .sections
            .single
            .drawing
            .cadPrimitives
            .single
            .colorPresetId,
        'deTransport',
      );
      source.undo();
      expect(source.project.sections.single.drawing.cadPrimitives, isEmpty);
    },
  );
  test(
    'Solid fills preserve exact color/alpha on light and dark canvases and leave holes open',
    () {
      for (final color in [
        const ArchitectDrawingColor(0xFF101010),
        const ArchitectDrawingColor(0xFFFFFFFF),
        const ArchitectDrawingColor(0x80EEDD22),
        preset('bgOupResidential'),
      ]) {
        for (final palette in [
          const ArchitectCanvasPalette.light(),
          const ArchitectCanvasPalette.dark(),
        ]) {
          final canvas = ArchitectVectorCanvas();
          ArchitectElementsPainterHelper.drawCadPrimitives(
            canvas: canvas,
            storey: hatches.fixture([fill(color)]).activeStorey,
            zoomScale: 80,
            palette: palette,
          );
          final op = canvas.operations
              .whereType<ArchitectVectorPath>()
              .firstWhere((p) => p.role == 'cadFill');
          expect(op.color.toARGB32(), color.argb);
          expect(op.fill, isTrue);
          expect(op.path.contains(const Offset(3, 2)), isTrue);
          expect(op.path.contains(const Offset(1.5, 1.5)), isFalse);
          expect(op.clip!.contains(const Offset(1.5, 1.5)), isFalse);
        }
      }
      final existing = ArchitectVectorCanvas()
        ..drawRect(
          const Rect.fromLTWH(0, 0, 10, 10),
          Paint()..color = Colors.black,
        );
      expect(
        (existing.operations.single as ArchitectVectorPath).color.a,
        lessThan(.1),
      );
    },
  );
  test(
    'Colored hatch strokes also retain their chosen color without palette remapping',
    () {
      final color = preset('bgPupWater');
      final canvas = ArchitectVectorCanvas();
      ArchitectElementsPainterHelper.drawCadPrimitives(
        canvas: canvas,
        palette: const ArchitectCanvasPalette.dark(),
        storey: hatches.fixture([
          hatches.hatch.copyWith(
            colorValue: color.argb,
            colorPresetId: color.presetId,
          ),
        ]).activeStorey,
        zoomScale: 100,
      );
      expect(
        (canvas.operations.first as ArchitectVectorPath).color.toARGB32(),
        color.argb,
      );
    },
  );
  test(
    'Selecting a translucent fill draws it once, below walls, and only overlays its outline',
    () {
      final p = hatches.fixture([
        fill(const ArchitectDrawingColor(0x80778899)),
      ]);
      final withWall = p.updateActiveStorey(
        p.activeStorey.copyWith(
          slabs: const [
            ArchitectSlab(id: 'slab', polygon: hatches.polygon, label: 'Slab'),
          ],
          zones: const [
            ArchitectZone(
              id: 'zone',
              name: 'Room',
              category: ArchitectZoneCategory.custom,
              polygon: hatches.polygon,
              isAutoBoundary: false,
            ),
          ],
          walls: const [
            ArchitectWall(
              id: 'wall',
              startPoint: Offset(0, 3),
              endPoint: Offset(6, 3),
            ),
          ],
        ),
      );
      final canvas = ArchitectVectorCanvas();
      for (final layer in [
        ArchitectPaintLayer.model,
        ArchitectPaintLayer.interaction,
      ]) {
        Architect2dPainter(
          project: withWall,
          activeTool: ArchitectTool.select,
          layer: layer,
          selectedElementId: 'h',
          paintGrid: false,
          zoomScale: 80,
        ).paint(canvas, const Size(1000, 1000));
      }
      final fills = canvas.operations
          .whereType<ArchitectVectorPath>()
          .where((o) => o.role == 'cadFill')
          .toList();
      expect(fills, hasLength(1));
      expect(fills.single.color.toARGB32(), 0x80778899);
      expect(
        canvas.operations.indexOf(fills.single),
        lessThan(
          canvas.operations.indexWhere((o) => o.sources.contains('wall')),
        ),
      );
      for (final id in ['slab', 'zone']) {
        final index = canvas.operations.indexWhere(
          (o) => o.sources.contains(id),
        );
        expect(index, greaterThan(canvas.operations.indexOf(fills.single)));
      }
    },
  );
  test(
    'Publication retains opaque fill colors and produces vector PDF pages',
    () async {
      final l = await AppLocalizations.delegate.load(const Locale('bg'));
      const drawing = ArchitectSavedDrawing(
        id: 'plan:s',
        sourceId: 's',
        kind: ArchitectDrawingKind.plan,
      );
      final color = preset('bgPupHousingLowHigh');
      final p = hatches
          .fixture([fill(color)])
          .copyWith(document: const ArchitectDocument(drawings: [drawing]));
      final scene = ArchitectDrawingPublisher.build(p, drawing, 100, l);
      final op = scene.operations.whereType<ArchitectVectorPath>().singleWhere(
        (o) => o.role == 'cadFill',
      );
      expect(op.color.toARGB32(), color.argb);
      expect(op.color.a, 1);
      expect(op.fill, isTrue);
      expect(op.path.contains(const Offset(15, 15)), isFalse);
      const sheet = ArchitectSheet(
        id: 'sheet',
        placements: [
          ArchitectDrawingPlacement(
            id: 'place',
            drawingId: 'plan:s',
            frame: Rect.fromLTWH(20, 20, 200, 120),
            anchor: Offset(50, 50),
            scale: 100,
          ),
        ],
      );
      final bytes = await ArchitectPdfExport.export(p, [sheet], l);
      final pdf = PdfDocument(inputBytes: bytes);
      expect(pdf.pages.count, 1);
      pdf.dispose();
    },
  );
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'Phone properties choose solid fill and a PUP RAL color in one Undo ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const capture = bool.fromEnvironment('UPDATE_ARCHITECT_COLOR_PREVIEW');
        if (capture) {
          await tester.runAsync(() async {
            final loader = FontLoader('ReviewArial')
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
                  ),
                ),
              );
            await loader.load();
            final icons = FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
            await icons.load();
          });
        }
        final model = ArchitectCommandController(hatches.fixture());
        addTearDown(model.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('color-phone'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(locale),
              theme: capture ? ThemeData(fontFamily: 'ReviewArial') : null,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ArchitectElementPropertiesDialog(
                  project: model.project,
                  elementIds: const {'h'},
                  onApply: (values, texts) {
                    model.execute(
                      SetArchitectElementProperties(
                        storeyId: 's',
                        elementIds: {'h'},
                        values: values,
                        textValues: texts,
                      ),
                    );
                    return true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-property-hatch')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('hatch-pattern-solidFill')));
        await tester.pumpAndSettle();
        final control = find.byKey(
          const ValueKey('architect-property-hatch-color'),
        );
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        await tester.tap(control);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('drawing-color-palette')));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .text(
                ArchitectColorPalette.bgPup.label(
                  await AppLocalizations.delegate.load(Locale(locale)),
                ),
              )
              .hitTestable()
              .last,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('drawing-color-search')),
          '1019',
        );
        await tester.pumpAndSettle();
        if (capture) {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const ValueKey('color-phone')),
                )
                .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '.dart_tool/planning_colors/phone_$locale.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(
          find.byKey(const ValueKey('drawing-color-bgPupHousingLowHigh')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('drawing-color-save')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-properties-save')),
        );
        await tester.pumpAndSettle();
        final placed = model.project.activeStorey.cadPrimitives.single;
        expect(placed.hatchPattern.isSolid, isTrue);
        expect(placed.drawingColor, preset('bgPupHousingLowHigh'));
        model.undo();
        expect(
          model.project.activeStorey.cadPrimitives.single.hatchPattern.isSolid,
          isFalse,
        );
        expect(
          model.project.activeStorey.cadPrimitives.single.colorPresetId,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Custom HEX/RGB clears preset metadata and validates input; cancellation makes no changes',
    (tester) async {
      ArchitectDrawingColor? saved;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                key: const ValueKey('open'),
                child: const Text('Open'),
                onPressed: () async {
                  saved = await showDialog<ArchitectDrawingColor>(
                    context: ctx,
                    builder: (_) => ArchitectDrawingColorDialog(
                      initial: preset('bgOupResidential'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawing-color-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('drawing-color-hex')),
        'BAD',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('drawing-color-custom-save')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('drawing-color-hex')),
        '123456',
      );
      await tester.pump();
      tester
          .widget<Slider>(find.byKey(const ValueKey('drawing-color-channel-R')))
          .onChanged!(171);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('drawing-color-custom-save')));
      await tester.pumpAndSettle();
      tester
          .widget<Slider>(find.byKey(const ValueKey('drawing-color-opacity')))
          .onChanged!(60);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('drawing-color-save')));
      await tester.pumpAndSettle();
      expect(saved!.hex, '#AB3456');
      expect(saved!.presetId, isNull);
      expect(saved!.opacityPercent, 60);
      saved = null;
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('drawing-color-search')),
        '5015',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawing-color-bgOupWater')));
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.widgetWithText(TextButton, l.cancel));
      await tester.pumpAndSettle();
      expect(saved, isNull);
    },
  );
  testWidgets(
    'Phone hatch bar fits color, draw modes and three drafting actions in 300 pixels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: ArchitectHatchDraftBar(
                  pattern: ArchitectHatchPattern.solid,
                  customPatterns: const [],
                  lineStyles: const [],
                  pointCount: 3,
                  onChanged: (_) {},
                  onUndo: () {},
                  onFinish: () {},
                  onCancel: () {},
                  onAutomaticChanged: (_) {},
                  onColorChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(ArchitectHatchDraftBar)).width,
        lessThanOrEqualTo(300),
      );
      for (final key in [
        'hatch-mode-auto',
        'hatch-mode-manual',
        'architect-draft-hatch-color',
        'hatch-draft-undo',
        'hatch-draft-finish',
        'hatch-draft-cancel',
      ]) {
        expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Draft controls choose solid and German color before automatic filling',
    (tester) async {
      final host = hatches.hatch.copyWith(
        type: CadPrimitiveType.rect,
        id: 'rectangle',
      );
      final model = ArchitectCommandController(hatches.fixture([host]));
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.texture_rounded);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-draft-hatch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hatch-pattern-solidFill')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-draft-hatch-color')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawing-color-palette')));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .text(
              ArchitectColorPalette.dePlanZV.label(
                await AppLocalizations.delegate.load(const Locale('en')),
              ),
            )
            .hitTestable()
            .last,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('drawing-color-search')),
        '6.1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawing-color-deTransport')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawing-color-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hatch-mode-auto')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(3, 2));
      await tester.pumpAndSettle();
      final placed = model.project.activeStorey.cadPrimitives.last;
      expect(placed.type, CadPrimitiveType.hatch);
      expect(placed.hatchPattern.isSolid, isTrue);
      expect(placed.drawingColor, preset('deTransport'));
      model.undo();
      expect(model.project.activeStorey.cadPrimitives, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
