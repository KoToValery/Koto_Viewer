import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_hatch_pattern.dart';
import 'package:kotoview/src/features/architect/models/architect_line_style.dart';
import 'package:kotoview/src/features/architect/models/architect_line_symbol.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_hatch_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_scene_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_hatch_patterns.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_hatch_picker.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

const polygon = [Offset(0, 0), Offset(6, 0), Offset(6, 4), Offset(0, 4)];
const hatch = ArchitectCadPrimitive(
  id: 'h',
  type: CadPrimitiveType.hatch,
  startPoint: Offset.zero,
  endPoint: Offset(6, 4),
  polygon: polygon,
);
const own = ArchitectHatchPattern(
  id: 'custom_hatch',
  name: 'Utility',
  layers: [
    ArchitectHatchLayer(
      angleDeg: 15,
      spacingMm: 5,
      shiftMm: 2,
      symbolsOnly: true,
      lineStyle: ArchitectLineStyle(
        id: 'custom_symbol',
        name: 'Own',
        segmentsMm: [],
        symbol: ArchitectLineSymbol(
          shape: ArchitectLineSymbolShape.custom,
          spacingMm: 8,
          sizeMm: 2,
          strokes: [
            [Offset(-.5, 0), Offset(0, -.5), Offset(.5, 0)],
            [Offset(0, -.5), Offset(0, .5)],
          ],
        ),
      ),
    ),
    ArchitectHatchLayer(angleDeg: -45, spacingMm: 6),
  ],
);
ArchitectProject fixture([
  List<ArchitectCadPrimitive> primitives = const [hatch],
]) => ArchitectProject(
  id: 'p',
  name: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [ArchitectStorey(id: 's', name: '', cadPrimitives: primitives)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Twelve localized presets retain distinct vector definitions and old projects load',
    () async {
      expect(ArchitectHatchPattern.presets, hasLength(12));
      final definitions = <String>{};
      for (final p in ArchitectHatchPattern.presets) {
        p.validate();
        expect(ArchitectHatchPattern.fromJson(p.toJson()), p);
        definitions.add(jsonEncode(p.layers.map((l) => l.toJson()).toList()));
        final path = ArchitectHatchGeometry.path(
          boundary: Path()..addRect(const Rect.fromLTWH(0, 0, 60, 40)),
          pattern: p,
          unitsPerMm: 1,
        );
        expect(path.computeMetrics(), isNotEmpty);
        for (final locale in ['bg', 'en']) {
          final l = await AppLocalizations.delegate.load(Locale(locale));
          expect(p.label(l), isNotEmpty);
        }
      }
      expect(definitions, hasLength(12));
      final old = fixture([]).toJson()..remove('hatchPatterns');
      expect(ArchitectProject.fromJson(old).hatchPatterns, isEmpty);
    },
  );
  test('Custom layered symbols and properties persist with atomic Undo', () {
    final model = ArchitectCommandController(
      fixture([hatch, hatch.copyWith(id: 'h2')]),
    );
    addTearDown(model.dispose);
    final before = model.project.toJson();
    model.execute(
      SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'h', 'h2'},
        values: const {'hatchScale': 2, 'hatchAngle': -30},
        textValues: {
          'hatchPattern': jsonEncode(own.toJson()),
          'hatchBorder': 'false',
        },
      ),
    );
    final restored = ArchitectProject.fromJson(
      jsonDecode(jsonEncode(model.project.toJson())) as Map<String, dynamic>,
    );
    expect(restored.hatchPatterns.single, own);
    for (final p in restored.activeStorey.cadPrimitives) {
      expect(p.hatchPattern, own);
      expect(p.hatchScale, 2);
      expect(p.hatchAngle, -30);
      expect(p.hatchBorder, isFalse);
    }
    model.undo();
    expect(model.project.toJson(), before);
    model.redo();
    expect(model.project.hatchPatterns.single, own);
  });
  test(
    'Placement rejects invalid contours, transforms and layers without partial mutations',
    () {
      for (final p in [
        hatch.copyWith(
          polygon: const [
            Offset.zero,
            Offset(6, 4),
            Offset(6, 0),
            Offset(0, 4),
          ],
        ),
        hatch.copyWith(hatchScale: 0),
        hatch.copyWith(hatchAngle: double.nan),
        hatch.copyWith(
          hatchPattern: const ArchitectHatchPattern(
            id: 'bad',
            name: 'Bad',
            layers: [ArchitectHatchLayer(spacingMm: 0)],
          ),
        ),
      ]) {
        expect(
          () => PlaceArchitectCadPrimitive(
            storeyId: 's',
            primitive: p,
          ).apply(fixture([])),
          throwsArgumentError,
        );
      }
      for (final values in [
        {'hatchScale': 21.0},
        {'hatchAngle': 181.0},
        {'hatchAngle': double.nan},
      ]) {
        expect(
          () => SetArchitectElementProperties(
            storeyId: 's',
            elementIds: {'h'},
            values: values,
          ).apply(fixture()),
          throwsArgumentError,
        );
      }
      final line = hatch.copyWith(type: CadPrimitiveType.line);
      expect(
        () => SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'h'},
          textValues: {'hatchPattern': jsonEncode(own.toJson())},
        ).apply(fixture([line])),
        throwsArgumentError,
      );
    },
  );
  test(
    'Catalog edits preserve placed snapshots and are reused after deleting geometry',
    () {
      final old = fixture([
        hatch.copyWith(hatchPattern: own),
      ]).copyWith(hatchPatterns: [own]);
      final changed = ArchitectHatchPattern(
        id: own.id,
        name: own.name,
        layers: const [ArchitectHatchLayer(angleDeg: 0)],
      );
      var next = SaveArchitectHatchPattern(changed).apply(old);
      expect(next.activeStorey.cadPrimitives.single.hatchPattern, own);
      next = PlaceArchitectCadPrimitive(
        storeyId: 's',
        primitive: hatch.copyWith(id: 'copy', hatchPattern: own),
      ).apply(next);
      expect(next.hatchPatterns.single, changed);
      next = next.updateActiveStorey(
        next.activeStorey.copyWith(cadPrimitives: []),
      );
      expect(
        ArchitectProject.fromJson(next.toJson()).hatchPatterns.single,
        changed,
      );
    },
  );
  test(
    'Hatches share polygon point insertion, pull, translation, mirror, bounds and snaps',
    () {
      var p = fixture([hatch.copyWith(hatchPattern: own)]);
      p = const InsertArchitectElementPoint(
        storeyId: 's',
        elementId: 'h',
        point: Offset(3, 0),
        newElementId: 'unused',
      ).apply(p);
      expect(p.activeStorey.cadPrimitives.single.polygonCorners, hasLength(5));
      p = UpdateArchitectPolygon(
        storeyId: 's',
        elementId: 'h',
        polygon: ArchitectPolygonGeometry.pullEdge(polygon, 1, 2)!,
      ).apply(p);
      p = const MoveArchitectElements(
        storeyId: 's',
        elementIds: {'h'},
        delta: Offset(2, 1),
      ).apply(p);
      expect(ArchitectSelection.bounds(p, 'h')!.right, 10);
      p = const MirrorArchitectElements(
        storeyId: 's',
        elementIds: {'h'},
        origin: Offset.zero,
        direction: Offset(0, 1),
        isDuplicate: true,
        idMap: {'h': 'copy'},
      ).apply(p);
      expect(
        p.activeStorey.cadPrimitives.every((e) => e.hatchPattern == own),
        isTrue,
      );
      expect(ArchitectSelection.bounds(p, 'copy')!.left, -10);
      expect(ArchitectSceneGeometry.projectBounds(p).left, -10);
      final geometry = ArchitectSnapGeometry.of(p);
      expect(
        geometry.alignmentPoints.any((e) => e.point == const Offset(10, 1)),
        isTrue,
      );
      expect(
        ArchitectElementTool().hitTestElementsForTool(
          p.activeStorey,
          const Offset(3, 2),
          100,
          ArchitectTool.hatch,
        ),
        contains('h'),
      );
      expect(
        ArchitectElementTool().hitTestElementsForTool(
          p.activeStorey,
          const Offset(3, 2),
          100,
          ArchitectTool.slab,
        ),
        isEmpty,
      );
    },
  );
  test('Hatches in sections retain their reusable catalog and source Undo', () {
    final model = ArchitectCommandController(
      fixture([]).copyWith(
        sections: const [
          ArchitectSection(
            id: 'section',
            start: Offset.zero,
            end: Offset(8, 0),
          ),
        ],
      ),
    );
    addTearDown(model.dispose);
    final view = ArchitectWorkspaceViewController(model);
    addTearDown(view.dispose);
    view.select(ArchitectWorkspaceView.section, 'section');
    view.execute(
      PlaceArchitectCadPrimitive(
        storeyId: view.project.activeStoreyId,
        primitive: hatch.copyWith(hatchPattern: own),
      ),
    );
    expect(model.project.hatchPatterns.single, own);
    expect(
      model.project.sections.single.drawing.cadPrimitives.single.type,
      CadPrimitiveType.hatch,
    );
    model.undo();
    expect(model.project.sections.single.drawing.cadPrimitives, isEmpty);
    expect(model.project.hatchPatterns, isEmpty);
  });
  test(
    'Paper spacing and stroke weight stay fixed at every scale and zoom, with concave clipping',
    () {
      const concave = [
        Offset.zero,
        Offset(6, 0),
        Offset(6, 2),
        Offset(2, 2),
        Offset(2, 4),
        Offset(0, 4),
      ];
      for (final scale in ArchitectDimensionScale.values) {
        for (final zoom in [25.0, 100.0, 500.0]) {
          final canvas = ArchitectVectorCanvas()
            ..scale(1000 / scale.denominator);
          ArchitectElementsPainterHelper.drawCadPrimitives(
            canvas: canvas,
            storey: fixture([
              hatch.copyWith(
                polygon: concave,
                hatchPattern: ArchitectHatchPattern.presets[2],
                hatchBorder: false,
              ),
            ]).activeStorey,
            zoomScale: zoom,
            dimensionScale: scale,
          );
          final op = canvas.operations.single as ArchitectVectorPath;
          expect(op.width, closeTo(.13, 1e-6));
          expect(op.clip, isNotNull);
          expect(op.bounds.left, greaterThanOrEqualTo(0));
          expect(
            op.bounds.right,
            lessThanOrEqualTo(6 * 1000 / scale.denominator),
          );
          expect(
            op.clip!.contains(Offset(5, 3) * (1000 / scale.denominator)),
            isFalse,
          );
          final rows = op.path.computeMetrics().toList();
          final delta =
              rows[1].getTangentForOffset(0)!.position.dy -
              rows[0].getTangentForOffset(0)!.position.dy;
          expect(delta, closeTo(3, 1e-4));
        }
      }
    },
  );
  test(
    'Publication keeps clipped hatch vectors and exports a readable PDF',
    () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      const drawing = ArchitectSavedDrawing(
        id: 'plan:s',
        sourceId: 's',
        kind: ArchitectDrawingKind.plan,
      );
      final p = fixture([
        hatch.copyWith(hatchPattern: own),
      ]).copyWith(document: const ArchitectDocument(drawings: [drawing]));
      final scene = ArchitectDrawingPublisher.build(p, drawing, 100, l);
      expect(
        scene.operations.whereType<ArchitectVectorPath>().where(
          (o) => o.sources.contains('h') && o.clip != null,
        ),
        isNotEmpty,
      );
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
  test(
    'Panning a cropped hatch keeps independent dash and symbol phases stable',
    () {
      const pattern = ArchitectHatchPattern(
        id: 'phase_test',
        name: 'Phase',
        layers: [
          ArchitectHatchLayer(
            angleDeg: 0,
            spacingMm: 5,
            shiftMm: 2,
            lineStyle: ArchitectLineStyle(
              id: 'phase_line',
              name: 'Phase',
              segmentsMm: [5, 2],
              symbol: ArchitectLineSymbol(
                shape: ArchitectLineSymbolShape.circle,
                sizeMm: 2,
                spacingMm: 12,
              ),
            ),
          ),
        ],
      );
      final boundary = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 50));
      final full = ArchitectHatchGeometry.path(
        boundary: boundary,
        pattern: pattern,
        unitsPerMm: 1,
      );
      final cropped = ArchitectHatchGeometry.path(
        boundary: boundary,
        pattern: pattern,
        unitsPerMm: 1,
        visibleBounds: const Rect.fromLTWH(30, 10, 40, 25),
      );
      const inside = Rect.fromLTRB(35, 12, 65, 28);
      Set<String> strokes(Path path) => path
          .computeMetrics()
          .map((m) {
            final b = m.extractPath(0, m.length).getBounds();
            if (!inside.contains(b.topLeft) ||
                !inside.contains(b.bottomRight)) {
              return '';
            }
            return [
              b.left,
              b.top,
              b.right,
              b.bottom,
              m.length,
            ].map((v) => v.toStringAsFixed(3)).join(',');
          })
          .where((s) => s.isNotEmpty)
          .toSet();
      expect(strokes(cropped), isNotEmpty);
      expect(strokes(cropped), strokes(full));
    },
  );
  test(
    'Optional hatch borders use the chosen line style at a fixed paper weight',
    () {
      for (final scale in [
        ArchitectDimensionScale.scale50,
        ArchitectDimensionScale.scale200,
      ]) {
        final canvas = ArchitectVectorCanvas()..scale(1000 / scale.denominator);
        ArchitectElementsPainterHelper.drawCadPrimitives(
          canvas: canvas,
          storey: fixture([
            hatch.copyWith(lineStyle: ArchitectLineStyle.presets[1]),
          ]).activeStorey,
          zoomScale: 80,
          dimensionScale: scale,
        );
        final border = canvas.operations.last as ArchitectVectorPath;
        expect(border.clip, isNull);
        expect(border.width, closeTo(.18, 1e-6));
        expect(border.path.computeMetrics().first.length, closeTo(3, 1e-4));
      }
      expect(
        ArchitectSelection.fields(fixture(), 'h'),
        isNot(contains('strokeWidth')),
      );
    },
  );
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'Phone custom editor changes layers and uses the line symbol editor ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ArchitectHatchPattern? saved;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  key: const ValueKey('open'),
                  child: const Text('Open'),
                  onPressed: () async {
                    saved = await showDialog<ArchitectHatchPattern>(
                      context: ctx,
                      builder: (_) => const ArchitectHatchEditor(
                        initial: ArchitectHatchPattern.diagonal,
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
        await tester.enterText(
          find.byKey(const ValueKey('hatch-pattern-name')),
          'Own hatch',
        );
        await tester.pump();
        final step = find.byKey(const ValueKey('hatch-layer-0-spacingMm'));
        await tester.ensureVisible(step);
        await tester.pumpAndSettle();
        await tester.tap(step);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-key-5')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('wall-end')));
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectHatchEditor), findsOneWidget);
        final line = find.byKey(const ValueKey('hatch-layer-0-style'));
        await tester.ensureVisible(line);
        await tester.pumpAndSettle();
        await tester.tap(line);
        await tester.pumpAndSettle();
        final power = find.byKey(const ValueKey('line-style-powerLine'));
        await tester.scrollUntilVisible(
          power,
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(power);
        await tester.pumpAndSettle();
        final only = find.byKey(const ValueKey('hatch-layer-0-symbols'));
        await tester.ensureVisible(only);
        await tester.pumpAndSettle();
        await tester.tap(only);
        await tester.pumpAndSettle();
        final add = find.byKey(const ValueKey('hatch-add-layer'));
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('hatch-pattern-save')));
        await tester.pumpAndSettle();
        expect(saved!.layers, hasLength(2));
        expect(saved!.layers.first.spacingMm, 5);
        expect(saved!.layers.first.symbolsOnly, isTrue);
        expect(
          saved!.layers.first.lineStyle.symbol!.shape,
          ArchitectLineSymbolShape.lightning,
        );
        saved!.validate();
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'Phone properties select a hatch and toggle the border atomically ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = ArchitectCommandController(fixture());
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
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
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-property-hatch')),
        );
        await tester.pumpAndSettle();
        final brick = find.byKey(const ValueKey('hatch-pattern-brick'));
        await tester.ensureVisible(brick);
        await tester.pumpAndSettle();
        await tester.tap(brick);
        await tester.pumpAndSettle();
        final border = find.byKey(
          const ValueKey('architect-property-hatch-border'),
        );
        await tester.ensureVisible(border);
        await tester.pumpAndSettle();
        await tester.tap(border);
        await tester.pumpAndSettle();
        final l = await AppLocalizations.delegate.load(Locale(locale));
        await tester.tap(find.widgetWithText(FilledButton, l.save));
        await tester.pumpAndSettle();
        expect(
          model.project.activeStorey.cadPrimitives.single.hatchPattern.id,
          'brick',
        );
        expect(
          model.project.activeStorey.cadPrimitives.single.hatchBorder,
          isFalse,
        );
        model.undo();
        expect(
          model.project.activeStorey.cadPrimitives.single.hatchPattern.id,
          'diagonal',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Hatch drawing closes like a slab, cancels draft and shares contour handles with Undo',
    (tester) async {
      final model = ArchitectCommandController(fixture([]));
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.texture_rounded);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, Offset.zero);
      await workspace.wallTap(tester, const Offset(6, 0));
      await tester.tap(find.byKey(const ValueKey('hatch-draft-cancel')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.cadPrimitives, isEmpty);
      for (final p in polygon) {
        await workspace.wallTap(tester, p);
      }
      expect(model.project.activeStorey.cadPrimitives, isEmpty);
      expect(workspace.overlay(tester).slabDraftPoints, hasLength(4));
      await workspace.wallTap(tester, Offset.zero);
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.single.type,
        CadPrimitiveType.hatch,
      );
      expect(model.project.activeStorey.slabs, isEmpty);
      await tools.prepare(tester, Icons.near_me_outlined);
      await tester.tap(find.byKey(const ValueKey('architect-tool-select')));
      await tester.pumpAndSettle();
      await editing.hold(tester, const Offset(3, 2));
      expect(workspace.overlay(tester).selectedElementId, isNotNull);
      final before = model.project;
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(6, 2)),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await gesture.moveTo(workspace.screen(tester, const Offset(8, 2)));
      await tester.pump();
      expect(identical(model.project, before), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.single.polygonCorners,
        hasLength(6),
      );
      model.undo();
      await tester.pump();
      expect(model.project.toJson(), before.toJson());
      model.undo();
      expect(model.project.activeStorey.cadPrimitives, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'General selection retains Select and Select similar keeps only hatches',
    (tester) async {
      final model = ArchitectCommandController(
        fixture([
          hatch,
          hatch.copyWith(
            id: 'h2',
            startPoint: const Offset(8, 0),
            endPoint: const Offset(14, 4),
            polygon: polygon.map((p) => p + const Offset(8, 0)).toList(),
          ),
          hatch.copyWith(
            id: 'rectangle',
            type: CadPrimitiveType.rect,
            startPoint: const Offset(0, 6),
            endPoint: const Offset(6, 10),
            polygon: polygon.map((p) => p + const Offset(0, 6)).toList(),
          ),
        ]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.near_me_outlined);
      await tester.pumpAndSettle();
      await editing.hold(tester, const Offset(3, 2));
      expect(
        tester
            .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
            .activeTool,
        ArchitectTool.select,
      );
      final before = model.project.toJson();
      await tester.tap(find.byKey(const ValueKey('architect-select-similar')));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'h', 'h2'});
      expect(model.project.toJson(), before);
      for (final locale in ['bg', 'en']) {
        final l = await AppLocalizations.delegate.load(Locale(locale));
        expect(
          ArchitectSelection.summary(model.project, {'h', 'h2'}, l),
          l.architectSelectionHatchesCount(2),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Render all presets for visual review', (tester) async {
    if (!const bool.fromEnvironment('UPDATE_ARCHITECT_HATCH_PREVIEW')) return;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      for (var i = 0; i < ArchitectHatchPattern.presets.length; i++) {
        final boundary = Path()
          ..addRect(
            Rect.fromLTWH(20 + (i % 5) * 150, 20 + (i ~/ 5) * 150, 130, 130),
          );
        canvas.save();
        canvas.clipPath(boundary);
        canvas.drawPath(
          ArchitectHatchGeometry.path(
            boundary: boundary,
            pattern: ArchitectHatchPattern.presets[i],
            unitsPerMm: 4,
          ),
          Paint()
            ..color = Colors.black
            ..strokeWidth = .6
            ..style = PaintingStyle.stroke,
        );
        canvas.restore();
        canvas.drawPath(
          boundary,
          Paint()
            ..color = Colors.grey
            ..strokeWidth = .7
            ..style = PaintingStyle.stroke,
        );
      }
      final image = await recorder.endRecording().toImage(770, 320);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '.dart_tool/architect_hatch_presets.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
