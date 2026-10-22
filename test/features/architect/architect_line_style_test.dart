import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_line_style.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_line_pattern.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_line_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_line_styles.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

const custom = ArchitectLineStyle(
  id: 'custom_test',
  name: 'My pattern',
  segmentsMm: [8, 2, .25, 2],
);
ArchitectProject fixture() => ArchitectProject(
  id: 'p',
  name: 'p',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [
    ArchitectStorey(
      id: 's',
      name: 's',
      cadPrimitives: [
        const ArchitectCadPrimitive(
          id: 'l',
          type: CadPrimitiveType.line,
          startPoint: Offset.zero,
          endPoint: Offset(6, 0),
        ),
        ArchitectCadPrimitive(
          id: 'r',
          type: CadPrimitiveType.rect,
          startPoint: const Offset(1, 1),
          endPoint: const Offset(4, 3),
          lineStyle: ArchitectLineStyle.presets[1],
        ),
        const ArchitectCadPrimitive(
          id: 'c',
          type: CadPrimitiveType.circle,
          startPoint: Offset(8, 1),
          endPoint: Offset(9, 1),
        ),
      ],
      walls: const [
        ArchitectWall(
          id: 'w',
          startPoint: Offset(0, 5),
          endPoint: Offset(6, 5),
        ),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Ten distinct broken styles plus continuous; old projects remain continuous',
    () {
      expect(ArchitectLineStyle.presets, hasLength(11));
      expect(
        ArchitectLineStyle.presets.map((s) => s.segmentsMm.join(',')).toSet(),
        hasLength(11),
      );
      for (final style in ArchitectLineStyle.presets) {
        style.validate();
        expect(ArchitectLineStyle.fromJson(style.toJson()), style);
      }
      final json = fixture().toJson()..remove('lineStyles');
      final floor = (json['storeys'] as List).first as Map;
      for (final p in floor['cadPrimitives'] as List) {
        (p as Map).remove('lineStyle');
      }
      final restored = ArchitectProject.fromJson(json);
      expect(restored.lineStyles, isEmpty);
      expect(
        restored.activeStorey.cadPrimitives.every((p) => p.lineStyle.isSolid),
        isTrue,
      );
    },
  );
  test(
    'Custom pattern batch properties round-trip and Undo in one transaction',
    () {
      final model = ArchitectCommandController(fixture());
      addTearDown(model.dispose);
      final before = model.project.toJson();
      model.execute(
        SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'l', 'r'},
          textValues: {'lineStyle': jsonEncode(custom.toJson())},
        ),
      );
      expect(model.project.lineStyles.single, custom);
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(model.project.toJson())) as Map<String, dynamic>,
      );
      expect(
        restored.activeStorey.cadPrimitives
            .take(2)
            .every((p) => p.lineStyle == custom),
        isTrue,
      );
      expect(
        restored.activeStorey.cadPrimitives.last.lineStyle.isSolid,
        isTrue,
      );
      model.undo();
      expect(model.project.toJson(), before);
      model.redo();
      expect(model.project.lineStyles.single, custom);
    },
  );
  test('Wall, circle and mixed-type edits are rejected atomically', () {
    for (final ids in [
      {'w'},
      {'c'},
      {'l', 'w'},
      {'l', 'c'},
    ]) {
      final p = fixture();
      expect(
        () => SetArchitectElementProperties(
          storeyId: 's',
          elementIds: ids,
          textValues: {'lineStyle': jsonEncode(custom.toJson())},
        ).apply(p),
        throwsArgumentError,
      );
      expect(p.lineStyles, isEmpty);
      expect(p.activeStorey.cadPrimitives.first.lineStyle.isSolid, isTrue);
    }
  });
  test(
    'Reusable styles survive deleted geometry; editing a definition preserves placed snapshots',
    () {
      final styled = fixture().activeStorey.cadPrimitives.first.copyWith(
        lineStyle: custom,
      );
      final original = fixture().copyWith(
        lineStyles: [custom],
        storeys: [
          ArchitectStorey(id: 's', name: '', cadPrimitives: [styled]),
        ],
      );
      const edited = ArchitectLineStyle(
        id: 'custom_test',
        name: 'My pattern',
        segmentsMm: [2, 1],
      );
      var next = const SaveArchitectLineStyle(edited).apply(original);
      expect(next.lineStyles, [edited]);
      expect(next.activeStorey.cadPrimitives.single.lineStyle, custom);
      // A cached drawing default may still be an older snapshot.
      next = PlaceArchitectCadPrimitive(
        storeyId: 's',
        primitive: styled.copyWith(id: 'copy'),
      ).apply(next);
      expect(next.lineStyles, [edited]);
      next = next.updateActiveStorey(
        next.activeStorey.copyWith(cadPrimitives: []),
      );
      expect(ArchitectProject.fromJson(next.toJson()).lineStyles, [edited]);
    },
  );
  test(
    'Pattern validation rejects zero, odd, non-finite and excessive sequences',
    () {
      for (final lengths in [
        [0.0, 2.0],
        [1.0],
        [double.nan, 2.0],
        [101.0, 2.0],
        List.filled(18, 1.0),
      ]) {
        expect(
          () => ArchitectLineStyle(
            id: 'custom',
            name: 'n',
            segmentsMm: lengths,
          ).validate(),
          throwsArgumentError,
        );
      }
    },
  );
  test(
    'Split, duplicate, mirror and rectangle contour edits keep the custom pattern',
    () {
      var p = fixture();
      p = SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'l', 'r'},
        textValues: {'lineStyle': jsonEncode(custom.toJson())},
      ).apply(p);
      p = ArchitectLineEditing.adapt(
        p,
        const CutArchitectWalls(
          storeyId: 's',
          wallIds: {'l'},
          start: Offset(3, -1),
          end: Offset(3, 1),
        ),
      ).apply(p);
      expect(
        p.activeStorey.cadPrimitives
            .where((p) => p.type == CadPrimitiveType.line)
            .every((p) => p.lineStyle == custom),
        isTrue,
      );
      p = const UpdateArchitectPolygon(
        storeyId: 's',
        elementId: 'r',
        polygon: [Offset(1, 1), Offset(5, 1), Offset(4, 3), Offset(1, 3)],
      ).apply(p);
      p = const MirrorArchitectElements(
        storeyId: 's',
        elementIds: {'r'},
        origin: Offset.zero,
        direction: Offset(0, 1),
        isDuplicate: true,
        idMap: {'r': 'copy'},
      ).apply(p);
      expect(
        p.activeStorey.cadPrimitives
            .firstWhere((p) => p.id == 'copy')
            .lineStyle,
        custom,
      );
    },
  );
  test(
    'Section-local custom styles persist in the source project and shared Undo',
    () {
      final model = ArchitectCommandController(
        fixture().copyWith(
          sections: const [
            ArchitectSection(
              id: 'section',
              start: Offset(0, 0),
              end: Offset(5, 0),
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
          primitive: fixture().activeStorey.cadPrimitives.first.copyWith(
            lineStyle: custom,
          ),
        ),
      );
      expect(model.project.lineStyles.single, custom);
      expect(
        model.project.sections.single.drawing.cadPrimitives.single.lineStyle,
        custom,
      );
      model.undo();
      expect(model.project.lineStyles, isEmpty);
      expect(model.project.sections.single.drawing.cadPrimitives, isEmpty);
    },
  );
  test(
    'Printed dash lengths stay 3 mm at every scale, zoom and input unit',
    () {
      final l = fixture().activeStorey.cadPrimitives.first.copyWith(
        lineStyle: ArchitectLineStyle.presets[1],
      );
      for (final scale in ArchitectDimensionScale.values) {
        for (final zoom in [25.0, 100.0, 500.0]) {
          final canvas = ArchitectVectorCanvas(sourceIds: {'l'})
            ..scale(1000 / scale.denominator);
          ArchitectElementsPainterHelper.drawCadPrimitives(
            canvas: canvas,
            storey: ArchitectStorey(id: 's', name: '', cadPrimitives: [l]),
            zoomScale: zoom,
            dimensionScale: scale,
          );
          final path = (canvas.operations.single as ArchitectVectorPath).path;
          expect(path.computeMetrics().first.length, closeTo(3, 1e-5));
          final pieces = path.computeMetrics().toList();
          expect(
            (pieces[1].getTangentForOffset(0)!.position -
                    pieces[0].getTangentForOffset(pieces[0].length)!.position)
                .distance,
            closeTo(1.5, 1e-5),
          );
        }
      }
    },
  );
  test(
    'Rectangle pattern phase continues across corners and closes without a solid duplicate',
    () {
      final pattern = ArchitectLinePattern.path(
        Path()..addRect(const Rect.fromLTWH(0, 0, 4, 2)),
        ArchitectLineStyle.presets[1],
        1,
      );
      final strokes = pattern.computeMetrics().toList();
      expect(
        strokes.map((s) => s.length).toList(),
        everyElement(closeTo(3, 1e-6)),
      );
      // Stroke two starts half a millimetre along the right side, retaining phase.
      expect(strokes[1].getTangentForOffset(0)!.position, const Offset(4, .5));
    },
  );
  test(
    'Publication retains vector gaps in plan scenes and a readable PDF',
    () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final p = fixture().copyWith(
        storeys: [
          ArchitectStorey(
            id: 's',
            name: '',
            cadPrimitives: [
              fixture().activeStorey.cadPrimitives.first.copyWith(
                lineStyle: custom,
              ),
            ],
          ),
        ],
      );
      const drawing = ArchitectSavedDrawing(
        id: 'plan:s',
        sourceId: 's',
        kind: ArchitectDrawingKind.plan,
      );
      for (final scale in [50, 100]) {
        final scene = ArchitectDrawingPublisher.build(p, drawing, scale, l);
        final op = scene.operations
            .whereType<ArchitectVectorPath>()
            .where((o) => o.sources.contains('l'))
            .single;
        expect(op.path.computeMetrics().first.length, closeTo(8, 1e-4));
        expect(op.path.computeMetrics().length, greaterThan(2));
      }
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
      // The normal sheet composer resolves saved drawings from the document.
      final withDrawing = p.copyWith(
        document: const ArchitectDocument(drawings: [drawing]),
      );
      final bytes = await ArchitectPdfExport.export(withDrawing, [sheet], l);
      final pdf = PdfDocument(inputBytes: bytes);
      expect(pdf.pages.count, 1);
      pdf.dispose();
    },
  );

  Future<void> properties(
    WidgetTester tester,
    ArchitectCommandController model,
    String locale,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ArchitectElementPropertiesDialog(
                  project: model.project,
                  elementIds: {'l', 'r'},
                  onApply: (values, texts) {
                    model.execute(
                      SetArchitectElementProperties(
                        storeyId: 's',
                        elementIds: {'l', 'r'},
                        values: values,
                        textValues: texts,
                      ),
                    );
                    return true;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  for (final locale in ['bg', 'en']) {
    testWidgets(
      'Phone properties select a pattern for mixed line/rectangle and Undo ($locale)',
      (tester) async {
        final model = ArchitectCommandController(fixture());
        addTearDown(model.dispose);
        await properties(tester, model, locale);
        await tester.tap(
          find.byKey(const ValueKey('architect-property-line-style')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('line-style-dashDot')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-properties-save')),
        );
        await tester.pumpAndSettle();
        expect(
          model.project.activeStorey.cadPrimitives
              .take(2)
              .every((p) => p.lineStyle.id == 'dashDot'),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        model.undo();
        expect(
          model.project.activeStorey.cadPrimitives.first.lineStyle.isSolid,
          isTrue,
        );
      },
    );
    testWidgets(
      'Phone custom pattern edits dash/gap by local keypad and saves with properties ($locale)',
      (tester) async {
        final model = ArchitectCommandController(fixture());
        addTearDown(model.dispose);
        await properties(tester, model, locale);
        await tester.tap(
          find.byKey(const ValueKey('architect-property-line-style')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('line-style-custom')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('line-pattern-name')),
          'My line',
        );
        await tester.tap(find.byKey(const ValueKey('line-pattern-add')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('line-pattern-length-1')));
        await tester.pumpAndSettle();
        for (final key in ['2', '.', '5']) {
          await tester.tap(find.byKey(ValueKey('wall-key-$key')));
          await tester.pump();
        }
        await tester.tap(find.byKey(const ValueKey('wall-end')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('line-pattern-save')));
        await tester.pumpAndSettle();
        expect(model.project.lineStyles, isEmpty);
        await tester.tap(
          find.byKey(const ValueKey('architect-properties-save')),
        );
        await tester.pumpAndSettle();
        expect(model.project.lineStyles.single.name, 'My line');
        expect(model.project.lineStyles.single.segmentsMm, [3, 2.5, 3, 1.5]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Cancel properties discards an unsaved custom pattern and leaves history untouched',
    (tester) async {
      final model = ArchitectCommandController(fixture());
      addTearDown(model.dispose);
      await properties(tester, model, 'en');
      await tester.tap(
        find.byKey(const ValueKey('architect-property-line-style')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('line-style-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('line-pattern-name')),
        'Discard me',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('line-pattern-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(model.project.lineStyles, isEmpty);
      expect(model.canUndo, isFalse);
      expect(
        model.project.activeStorey.cadPrimitives.first.lineStyle.isSolid,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Compact drafting style applies to a line and rectangle with matching previews',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.timeline_rounded);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-draft-line-style')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('line-style-dashed')));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, Offset.zero);
      await workspace.wallTap(tester, const Offset(3, 0));
      expect(workspace.overlay(tester).activeCadLineStyle.id, 'dashed');
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      await tools.choose(tester, Icons.crop_square_rounded);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(-2, -2));
      await workspace.wallTap(tester, const Offset(-1, -1));
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.every(
          (p) => p.lineStyle.id == 'dashed',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
