import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_layout.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_chain_preview.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'architect_dimension_chain_test.dart' as dimensions;
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectDimension dimension() => ArchitectDimensionChain.build(
  id: 'dim',
  direction: const Offset(1, 0),
  offset: -2,
  anchors: const [
    ArchitectDimensionAnchor(point: Offset(0, 0)),
    ArchitectDimensionAnchor(point: Offset(5, 0)),
    ArchitectDimensionAnchor(point: Offset(10, 0)),
    ArchitectDimensionAnchor(point: Offset(3, 0), feature: 'opening'),
    ArchitectDimensionAnchor(point: Offset(4, 0), feature: 'opening'),
  ],
);
ArchitectProject project({
  ArchitectDocument document = const ArchitectDocument(),
}) => ArchitectProject(
  id: 'p',
  name: 'Scale test',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  document: document,
  storeys: [
    ArchitectStorey(
      id: 's',
      name: 'Floor',
      dimensions: [dimension()],
      walls: const [
        ArchitectWall(
          id: 'wall',
          startPoint: Offset(0, 0),
          endPoint: Offset(10, 0),
          windows: [
            ArchitectWindow(
              id: 'window',
              wallId: 'wall',
              offsetRatio: .35,
              width: 1,
              uuid: 'window',
            ),
          ],
          doors: [
            ArchitectDoor(
              id: 'door',
              wallId: 'wall',
              offsetRatio: .7,
              width: 1,
              uuid: 'door',
            ),
          ],
        ),
      ],
      columns: const [
        ArchitectColumn(
          id: 'col',
          position: Offset(9, 4),
          label: 'C1234',
          width: .3,
          depth: .3,
        ),
      ],
      zones: const [
        ArchitectZone(
          id: 'zone',
          number: '1',
          name: 'Living',
          category: ArchitectZoneCategory.living,
          polygon: [Offset(1, 1), Offset(8, 1), Offset(8, 5), Offset(1, 5)],
        ),
      ],
      zoneScheduleOrigin: const Offset(12, 0),
      slabs: const [
        ArchitectSlab(
          id: 'slab',
          label: 'Slab',
          polygon: [Offset(20, 0), Offset(25, 0), Offset(25, 5), Offset(20, 5)],
        ),
      ],
    ),
  ],
  gridAxes: const [
    StructuralGridAxis(
      id: 'axis',
      name: 'A',
      start: Offset(-1, -2),
      end: Offset(-1, 8),
    ),
  ],
);
const drawing = ArchitectSavedDrawing(
  id: 'plan:s',
  sourceId: 's',
  kind: ArchitectDrawingKind.plan,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
    final font = FontLoader('ArchitectNoto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await font.load();
  });

  test('Render scale examples for visual review', () async {
    if (Platform.environment['UPDATE_ARCHITECT_SCALE_PREVIEW'] != 'true') {
      return;
    }
    for (final denominator in [50, 100, 500]) {
      var p = project(
        document: ArchitectDocument(viewScales: {'plan:s': denominator}),
      );
      if (denominator == 500) {
        // A situation drawing uses a site-sized subject, rather than forcing
        // detailed room and opening annotations into a 20 mm building plan.
        p = p.copyWith(
          storeys: [
            ArchitectStorey(
              id: 's',
              name: 'Site',
              walls: const [
                ArchitectWall(
                  id: 'w1',
                  startPoint: Offset(20, 20),
                  endPoint: Offset(45, 20),
                ),
                ArchitectWall(
                  id: 'w2',
                  startPoint: Offset(45, 20),
                  endPoint: Offset(45, 32),
                ),
                ArchitectWall(
                  id: 'w3',
                  startPoint: Offset(45, 32),
                  endPoint: Offset(20, 32),
                ),
                ArchitectWall(
                  id: 'w4',
                  startPoint: Offset(20, 32),
                  endPoint: Offset(20, 20),
                ),
              ],
              zones: const [
                ArchitectZone(
                  id: 'site',
                  name: 'Site',
                  number: '1',
                  category: ArchitectZoneCategory.living,
                  polygon: [
                    Offset(0, 0),
                    Offset(100, 0),
                    Offset(100, 60),
                    Offset(0, 60),
                  ],
                ),
              ],
              dimensions: [
                ArchitectDimensionChain.build(
                  id: 'site-dim',
                  direction: const Offset(1, 0),
                  offset: -7,
                  anchors: const [
                    ArchitectDimensionAnchor(point: Offset(0, 0)),
                    ArchitectDimensionAnchor(point: Offset(20, 0)),
                    ArchitectDimensionAnchor(point: Offset(45, 0)),
                    ArchitectDimensionAnchor(point: Offset(100, 0)),
                  ],
                ),
              ],
            ),
          ],
          gridAxes: const [],
        );
      }
      final scene = ArchitectDrawingPublisher.build(p, drawing, denominator, l);
      final bounds = scene.bounds.inflate(3);
      final scale = math.min(1120 / bounds.width, 650 / bounds.height);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      final title = TextPainter(
        text: TextSpan(
          text: '1:$denominator',
          style: const TextStyle(
            fontFamily: 'ArchitectNoto',
            fontSize: 28,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      title.paint(canvas, const Offset(24, 12));
      canvas.translate(40 - bounds.left * scale, 60 - bounds.top * scale);
      canvas.scale(scale);
      scene.paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1200, 740);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'scratch/architect_annotation_scale_$denominator.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });

  test(
    'Roof and stair symbols retain their publication layout at distant zoom',
    () {
      final source = project();
      final p = source.updateActiveStorey(
        source.activeStorey.copyWith(
          walls: [],
          zones: [],
          columns: [],
          dimensions: [],
          slabs: [],
          clearZoneScheduleOrigin: true,
          roofs: [
            ArchitectRoofPlane(
              id: 'roof',
              storeyId: 's',
              points: const [
                Offset(20, 0),
                Offset(25, 0),
                Offset(25, 5),
                Offset(20, 5),
              ],
            ),
          ],
          stairs: const [
            ArchitectStair(
              id: 'stair',
              startPoint: Offset(0, 0),
              endPoint: Offset(1, 0),
              design: ArchitectStairDesign(showRailing: false),
            ),
          ],
        ),
      );
      for (final denominator in [50, 100, 500]) {
        final published = ArchitectDrawingPublisher.build(
          p,
          drawing,
          denominator,
          l,
        ).operations.whereType<ArchitectVectorText>().toList();
        expect(published.any((t) => t.sources.contains('roof')), isTrue);
        expect(published.any((t) => t.sources.contains('stair')), isTrue);
        for (final zoom in [5.0, 80.0, 320.0]) {
          final canvas = ArchitectVectorCanvas()..scale(zoom);
          ArchitectTextScope(p.document, 'plan:s', denominator, zoom).run(() {
            Architect2dPainter(
              project: p,
              activeTool: ArchitectTool.select,
              zoomScale: zoom,
              l10n: l,
              layer: ArchitectPaintLayer.model,
              paintGrid: false,
            ).paint(canvas, const Size(2000, 2000));
          });
          final texts = canvas.operations
              .whereType<ArchitectVectorText>()
              .toList();
          expect(texts.length, published.length);
          for (var i = 0; i < texts.length; i++) {
            expect(texts[i].text, published[i].text);
            expect(
              texts[i].size / zoom,
              closeTo(published[i].size * denominator / 1000, 1e-7),
            );
            expect(
              (texts[i].position / zoom -
                      published[i].position * (denominator / 1000))
                  .distance,
              lessThan(ArchitectDrawingScale(denominator).paperToModel(.1)),
              reason: texts[i].text,
            );
          }
        }
      }
    },
  );

  test(
    'Default exterior row gaps follow drawing scale, independently of zoom',
    () {
      for (final (scale, gap) in [
        (ArchitectDimensionScale.scale50, .3),
        (ArchitectDimensionScale.scale100, .4),
        (ArchitectDimensionScale.scale500, 3.0),
      ]) {
        for (final zoom in [10.0, 80.0, 320.0]) {
          final tiers = ArchitectDimensionLayout.layoutTiers(
            dimension: dimension(),
            scale: zoom,
            dimensionScale: scale,
          );
          expect(tiers, hasLength(3));
          for (var i = 1; i < tiers.length; i++) {
            expect(
              (tiers[i].line.$1.dy - tiers[i - 1].line.$1.dy).abs(),
              closeTo(gap, 1e-9),
            );
          }
        }
      }
    },
  );

  test(
    'Profiles, per-element overrides and saved view scales control the actual row gap',
    () {
      const document = ArchitectDocument(
        viewScales: {'plan:s': 50},
        profileMm: {'100/dimension': 3.3},
        overrideMm: {
          'plan:s/dim/dimension/100': 4.4,
          'plan:s/dim/dimension/50': 3,
        },
      );
      expect(
        ArchitectDimensionLayout.rowSpacingFor(
          dimension(),
          document: document,
          viewKey: 'plan:s',
          dimensionScale: ArchitectDimensionScale.scale100,
        ),
        closeTo(.6, 1e-9),
      );
      final noViewScale = document.copyWith(viewScales: {});
      expect(
        ArchitectDimensionLayout.rowSpacingFor(
          dimension(),
          document: noViewScale,
          viewKey: 'plan:s',
        ),
        closeTo(.8, 1e-9),
      );
      expect(
        ArchitectDimensionLayout.rowSpacingFor(
          dimension().copyWith(id: 'other'),
          document: noViewScale,
          viewKey: 'plan:s',
        ),
        closeTo(.6, 1e-9),
      );
      // A sheet placement can use another scale from the saved working view.
      ArchitectTextScope(document, 'plan:s', 100, 30, publication: true).run(
        () {
          expect(
            ArchitectDimensionLayout.rowSpacingFor(dimension()),
            closeTo(.8, 1e-9),
          );
        },
      );
    },
  );

  test(
    '1:500 uses modest paper lettering while retaining special symbol sizes',
    () {
      const document = ArchitectDocument();
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.dimension, 500),
        2.5,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.ordinary, 500),
        2.5,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.roomName, 500),
        3,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.title, 500),
        3.75,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.symbol, 500),
        2.2,
      );
      expect(
        ArchitectDimensionScale.scale500.textHeightMm,
        const ArchitectDrawingScale(500).defaultTextMm,
      );
    },
  );

  for (final denominator in [50, 100, 500]) {
    test(
      '1:$denominator working text, zones, symbols and dimensions match publication through zoom',
      () {
        final p = project(
          document: ArchitectDocument(viewScales: {'plan:s': denominator}),
        );
        final published = ArchitectDrawingPublisher.build(
          p,
          drawing,
          denominator,
          l,
        ).operations.whereType<ArchitectVectorText>().toList();
        expect(published, isNotEmpty);
        for (final zoom in [5.0, 20.0, 80.0, 320.0]) {
          final canvas = ArchitectVectorCanvas()..scale(zoom);
          Architect2dPainter(
            activeTool: ArchitectTool.select,
            project: p,
            zoomScale: zoom,
            l10n: l,
            layer: ArchitectPaintLayer.model,
            paintGrid: false,
          ).paint(canvas, const Size(2000, 2000));
          final texts = canvas.operations
              .whereType<ArchitectVectorText>()
              .toList();
          expect(texts.length, published.length);
          for (var i = 0; i < texts.length; i++) {
            final actual = texts[i], expected = published[i];
            expect(actual.text, expected.text);
            expect(actual.role, expected.role);
            expect(actual.sources, expected.sources);
            expect(
              actual.size / zoom,
              closeTo(expected.size * denominator / 1000, 1e-7),
            );
            expect(
              (actual.position / zoom -
                      expected.position * (denominator / 1000))
                  .distance,
              lessThan(.001),
              reason: '${actual.role}: ${actual.text}',
            );
          }
        }
      },
    );
  }

  test(
    'Large dimension overrides move the text and separate the painted rows',
    () {
      const doc = ArchitectDocument(
        overrideMm: {'plan:s/dim/dimension/100': 4.4},
      );
      final canvas = ArchitectVectorCanvas();
      ArchitectTextScope(doc, 'plan:s', 100, 20).run(() {
        ArchitectElementsPainterHelper.drawDimensions(
          canvas: canvas,
          storey: project().activeStorey,
          zoomScale: 20,
        );
      });
      final text = canvas.operations.whereType<ArchitectVectorText>().toList();
      expect(text, isNotEmpty);
      expect(
        text.every(
          (t) =>
              (t.size * ArchitectDrawingScale.fontCapRatio - .44).abs() < 1e-8,
        ),
        isTrue,
      );
      final rows = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension(),
        scale: 20,
        document: doc,
        viewKey: 'plan:s',
      );
      final lines = canvas.operations
          .whereType<ArchitectVectorPath>()
          .where(
            (p) =>
                p.sources.contains('dim') &&
                (p.bounds.width - 10.0125).abs() < 1e-5,
          )
          .toList();
      expect(lines.length, greaterThanOrEqualTo(3));
      expect(
        (rows[1].line.$1.dy - rows[0].line.$1.dy).abs(),
        closeTo(.8, 1e-9),
      );
    },
  );

  test(
    'Picking and preview use the same saved profile as the model and print',
    () {
      const document = ArchitectDocument(
        viewScales: {'plan:s': 50},
        overrideMm: {'plan:s/dim/dimension/50': 3},
      );
      final p = project(document: document);
      final tool = ArchitectElementTool();
      addTearDown(tool.dispose);
      final rows = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension(),
        scale: 200,
        document: document,
        viewKey: 'plan:s',
      );
      final target = (rows.last.line.$1 + rows.last.line.$2) / 2;
      expect(
        tool.hitTestForTool(
          p.activeStorey,
          target,
          200,
          ArchitectTool.dimension,
          annotationProject: p,
          drawingViewKey: 'plan:s',
        ),
        'dim',
      );
      final viewport = BimViewportController();
      addTearDown(viewport.dispose);
      final canvas = ArchitectVectorCanvas();
      ArchitectDimensionChainPreview(
        dimension: dimension(),
        viewport: viewport,
        units: p.units,
        palette: const ArchitectCanvasPalette.light(),
        storey: p.activeStorey,
        document: document,
        viewKey: 'plan:s',
      ).paint(canvas, const Size(1000, 1000));
      final labels = canvas.operations
          .whereType<ArchitectVectorText>()
          .toList();
      expect(labels, isNotEmpty);
      expect(
        labels.first.size / viewport.scale * ArchitectDrawingScale.fontCapRatio,
        closeTo(.15, 1e-8),
      );
    },
  );

  testWidgets(
    'Editing a placed dimension retains its individual text profile in the draft',
    (tester) async {
      const document = ArchitectDocument(
        overrideMm: {'plan:s/dim/dimension/100': 4.4},
      );
      final model = editing.seeded(project().activeStorey);
      addTearDown(model.dispose);
      model.replaceView(model.project.copyWith(document: document));
      await workspace.open(tester, model);
      await tool_ui.choose(tester, Icons.pan_tool_rounded);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(5, -2));
      await tester.tap(
        find.byKey(const ValueKey('architect-dimension-add-walls')),
      );
      await tester.pump();
      expect(dimensions.preview(tester)!.id, 'dim');
      final preview =
          tester
                  .widget<CustomPaint>(
                    find.byKey(
                      const ValueKey('architect-dimension-chain-preview'),
                    ),
                  )
                  .painter!
              as ArchitectDimensionChainPreview;
      expect(preview.document, same(document));
      expect(preview.viewKey, 'plan:s');
      expect(
        ArchitectDimensionLayout.rowSpacingFor(
          preview.dimension!,
          document: preview.document,
          viewKey: preview.viewKey,
        ),
        closeTo(.8, 1e-9),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
