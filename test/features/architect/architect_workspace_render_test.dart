import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_underlay_painter.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_grid_axis_painter_helper.dart';

class CountingCanvas implements Canvas {
  int lines = 0;
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DxfDocument document(List<DxfEntity> entities, Rect bounds) => DxfDocument(
  entities: entities,
  layers: {'lines': DxfLayer(name: 'lines')},
  blocks: {},
  bounds: bounds,
  entityStats: {},
  headerVars: {},
);

void main() {
  test('Axis bubbles and labels retain print proportions at every zoom', () {
    final project = ArchitectProject(
      id: 'axes',
      name: 'Axes',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      storeys: const [ArchitectStorey(id: 's', name: 'Storey')],
      gridAxes: const [
        StructuralGridAxis(
          id: 'axis',
          name: 'A',
          start: Offset.zero,
          end: Offset(6, 0),
        ),
      ],
    );
    for (final denominator in [50, 100, 500]) {
      final widths = <double>[];
      for (final publication in [false, true]) {
        for (final zoom in [20.0, 80.0, 320.0]) {
          final canvas = ArchitectVectorCanvas()..scale(zoom);
          const document = ArchitectDocument();
          final capMm = document.textMm(
            'plan:s',
            'axis',
            ArchitectAnnotationRole.symbol,
            denominator,
          );
          ArchitectTextScope(
            document,
            'plan:s',
            denominator,
            zoom,
            publication: publication,
          ).run(() {
            ArchitectGridAxisPainterHelper.drawAxes(
              canvas: canvas,
              project: project,
              zoomScale: zoom,
            );
          });
          final labels = canvas.operations
              .whereType<ArchitectVectorText>()
              .toList();
          expect(labels, hasLength(2));
          expect(labels.every((t) => t.sources.contains('axis')), isTrue);
          expect(
            ArchitectDrawingScale(
                  denominator,
                ).modelToPaper(labels.first.size / zoom) *
                ArchitectDrawingScale.fontCapRatio,
            closeTo(capMm, 1e-8),
          );
          widths.add(labels.first.bounds.width / zoom);
          final bubbleWidth =
              ArchitectDrawingScale(denominator).paperToModel(capMm) /
              11 *
              24 *
              zoom;
          expect(
            canvas.operations.whereType<ArchitectVectorPath>().any(
              (p) =>
                  p.fill &&
                  (p.bounds.width - bubbleWidth).abs() < 1e-4 &&
                  (p.bounds.height - bubbleWidth).abs() < 1e-4,
            ),
            isTrue,
          );
        }
      }
      expect(
        widths.every((w) => (w - widths.first).abs() < 1e-4),
        isTrue,
        reason: '$denominator: $widths',
      );
    }
  });
  test('Column text follows model geometry rather than camera pixels', () {
    final widths = <double>[];
    for (final zoom in [40.0, 160.0]) {
      final canvas = ArchitectVectorCanvas()..scale(zoom);
      const column = ArchitectColumn(
        id: 'col',
        position: Offset.zero,
        width: .4,
        depth: .4,
      );
      ArchitectTextScope(
        const ArchitectDocument(),
        'plan:s',
        50,
        zoom,
      ).run(() => column.paint2D(canvas: canvas, zoomScale: zoom));
      final label = canvas.operations
          .whereType<ArchitectVectorText>()
          .firstWhere((e) => e.role == 'dimension');
      widths.add(label.bounds.width);
      expect(
        label.size / zoom * 20 * ArchitectDrawingScale.fontCapRatio,
        closeTo(1.5, 1e-8),
      );
    }
    expect(widths[1] / widths[0], closeTo(4, 1e-5));
  });

  test(
    '10,000-entity underlay renders only geometry intersecting the camera',
    () {
      final doc = document([
        for (var x = 0; x < 100; x++)
          for (var y = 0; y < 100; y++)
            DxfLine(
              layer: 'lines',
              p1: Offset(x * 10, y * 10),
              p2: Offset(x * 10 + 1, y * 10 + 1),
            ),
      ], const Rect.fromLTWH(0, 0, 1000, 1000));
      final canvas = CountingCanvas();
      ArchitectElementsPainterHelper.drawUnderlay(
        canvas: canvas,
        underlayDoc: doc,
        zoomScale: 40,
        layerVisibility: {},
        visibleRect: const Rect.fromLTWH(20, 20, 50, 50),
      );
      expect(canvas.lines, greaterThan(0));
      expect(canvas.lines, lessThan(100));
    },
  );

  test(
    'Millimetre underlay is rendered at its metre position after origin rebasing',
    () async {
      final viewport = BimViewportController();
      addTearDown(viewport.dispose);
      viewport.resize(const Size(400, 400));
      viewport.fit(const Rect.fromLTWH(0, 0, 10, 10), padding: 40);
      final doc = document([
        DxfLine(
          layer: 'lines',
          p1: const Offset(11000, 22000),
          p2: const Offset(13000, 22000),
        ),
      ], const Rect.fromLTWH(10000, 20000, 10000, 10000));
      final painter = ArchitectUnderlayPainter(
        document: doc,
        viewport: viewport,
        frame: const BimCoordinateFrame(
          origin: Offset(10000, 20000),
          unitsPerMeter: 1000,
        ),
        visibility: {},
      );
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), const Size(400, 400));
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 400);
      final pixels = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
      final screen = viewport.toScreen(const Offset(2, 2));
      var alpha = 0;
      for (var y = screen.dy.floor() - 1; y <= screen.dy.ceil() + 1; y++) {
        alpha += pixels.getUint8((y * 400 + screen.dx.round()) * 4 + 3);
      }
      expect(alpha, greaterThan(0));
      image.dispose();
      picture.dispose();
    },
  );
}
