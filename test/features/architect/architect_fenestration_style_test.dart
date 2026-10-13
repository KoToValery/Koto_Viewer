import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_fenestration_style.dart';
import 'package:kotoview/src/features/architect/rendering/fenestration_3d_builder.dart';

void main() {
  group('ArchitectFenestrationStyle & Subdivision Tests', () {
    test('Default catalog presets initialize with valid geometry and panes', () {
      final catalog = ArchitectFenestrationStyle.standardCatalog();
      expect(catalog.isNotEmpty, isTrue);

      for (final style in catalog) {
        expect(style.defaultWidth, greaterThan(0.40));
        expect(style.defaultHeight, greaterThan(0.40));
        final panes = style.rootSubdivision.collectPanes();
        expect(panes.isNotEmpty, isTrue);
      }
    });

    test('FenestrationPane operability and infill properties', () {
      const fixedPane = FenestrationPane(
        id: 'p1',
        paneType: PaneType.fixedGlazing,
      );
      expect(fixedPane.isOpenable, isFalse);
      expect(fixedPane.isGlazed, isTrue);
      expect(fixedPane.isSolidPanel, isFalse);

      const turnPane = FenestrationPane(
        id: 'p2',
        paneType: PaneType.casementLeft,
        sashProfileWidth: 0.065,
      );
      expect(turnPane.isOpenable, isTrue);
      expect(turnPane.isGlazed, isTrue);
      expect(turnPane.sashProfileWidth, closeTo(0.065, 1e-4));

      const solidPane = FenestrationPane(
        id: 'p3',
        paneType: PaneType.solidPanel,
      );
      expect(solidPane.isOpenable, isFalse);
      expect(solidPane.isGlazed, isFalse);
      expect(solidPane.isSolidPanel, isTrue);
    });

    test('FenestrationPane muntins (шпроси) configuration', () {
      const pane = FenestrationPane(
        id: 'p_muntin',
        paneType: PaneType.fixedGlazing,
        muntinCols: 2,
        muntinRows: 3,
        muntinWidth: 0.024,
      );
      expect(pane.hasMuntins, isTrue);
      expect(pane.muntinCols, equals(2));
      expect(pane.muntinRows, equals(3));
      expect(pane.muntinWidth, closeTo(0.024, 1e-4));

      final json = pane.toJson();
      final restored = FenestrationPane.fromJson(json);
      expect(restored.muntinCols, equals(2));
      expect(restored.muntinRows, equals(3));
      expect(restored.muntinWidth, closeTo(0.024, 1e-4));
      expect(restored.hasMuntins, isTrue);
    });

    test('Splitting a leaf pane vertically divides space into two children', () {
      var style = ArchitectFenestrationStyle(
        id: 'test_win',
        name: 'Test Window',
        kind: FenestrationKind.window,
        defaultWidth: 1.40,
        defaultHeight: 1.40,
        rootSubdivision: const FenestrationSubdivision(
          id: 'root',
          pane: FenestrationPane(id: 'main_pane', paneType: PaneType.fixedGlazing),
        ),
      );

      expect(style.rootSubdivision.isSplit, isFalse);
      expect(style.rootSubdivision.collectPanes().length, equals(1));

      // Split vertical
      style = style.splitPane('main_pane', vertical: true, count: 2);
      expect(style.rootSubdivision.isSplit, isTrue);
      expect(style.rootSubdivision.isVertical, isTrue);
      final panes = style.rootSubdivision.collectPanes();
      expect(panes.length, equals(2));

      // Check metric rects
      final rects = style.rootSubdivision.collectPaneRects(
        Rect.fromLTWH(0, 0, style.defaultWidth, style.defaultHeight),
      );
      expect(rects.length, equals(2));
      final leftRect = rects[panes[0].id]!;
      final rightRect = rects[panes[1].id]!;
      expect(leftRect.width, closeTo(0.70, 1e-3));
      expect(rightRect.width, closeTo(0.70, 1e-3));
      expect(leftRect.height, closeTo(1.40, 1e-3));
    });

    test('Setting exact metric dimension on a leaf pane scales ratios correctly', () {
      var style = ArchitectFenestrationStyle(
        id: 'test_win',
        name: 'Test Window',
        kind: FenestrationKind.window,
        defaultWidth: 1.40,
        defaultHeight: 1.40,
        rootSubdivision: const FenestrationSubdivision(
          id: 'root',
          pane: FenestrationPane(id: 'main_pane', paneType: PaneType.fixedGlazing),
        ),
      );

      style = style.splitPane('main_pane', vertical: true, count: 2);
      final panes = style.rootSubdivision.collectPanes();
      final leftPaneId = panes[0].id;
      final rightPaneId = panes[1].id;

      // Set left leaf to exactly 0.50 m (50 cm)
      style = style.setPaneMetricDimension(leftPaneId, 0.50, true);

      final rects = style.rootSubdivision.collectPaneRects(
        Rect.fromLTWH(0, 0, style.defaultWidth, style.defaultHeight),
      );
      final leftRect = rects[leftPaneId]!;
      final rightRect = rects[rightPaneId]!;

      expect(leftRect.width, closeTo(0.50, 1e-3));
      expect(rightRect.width, closeTo(0.90, 1e-3));
      expect(leftRect.width + rightRect.width, closeTo(1.40, 1e-3));
    });

    test('Collapsing a division merges leaves back into single pane', () {
      var style = ArchitectFenestrationStyle(
        id: 'test_win',
        name: 'Test Window',
        kind: FenestrationKind.window,
        defaultWidth: 1.40,
        defaultHeight: 1.40,
        rootSubdivision: const FenestrationSubdivision(
          id: 'root',
          pane: FenestrationPane(id: 'main_pane', paneType: PaneType.fixedGlazing),
        ),
      );

      style = style.splitPane('main_pane', vertical: true, count: 2);
      final panes = style.rootSubdivision.collectPanes();
      expect(panes.length, equals(2));

      style = style.collapsePane(panes[0].id);
      expect(style.rootSubdivision.isSplit, isFalse);
      expect(style.rootSubdivision.collectPanes().length, equals(1));
    });

    test('Hit testing finds the clicked leaf pane in metric and canvas coordinates', () {
      var style = ArchitectFenestrationStyle(
        id: 'test_win',
        name: 'Test Window',
        kind: FenestrationKind.window,
        defaultWidth: 1.40,
        defaultHeight: 1.40,
        rootSubdivision: const FenestrationSubdivision(
          id: 'root',
          pane: FenestrationPane(id: 'main_pane', paneType: PaneType.fixedGlazing),
        ),
      );

      style = style.splitPane('main_pane', vertical: true, count: 2);
      final panes = style.rootSubdivision.collectPanes();
      final leftId = panes[0].id;
      final rightId = panes[1].id;

      // Metric hit test: (0.30, 0.70) should hit left pane
      final hitLeft = style.hitTest(const Offset(0.30, 0.70));
      expect(hitLeft, isNotNull);
      expect(hitLeft!.$1.id, equals(leftId));

      // Metric hit test: (1.10, 0.70) should hit right pane
      final hitRight = style.hitTest(const Offset(1.10, 0.70));
      expect(hitRight, isNotNull);
      expect(hitRight!.$1.id, equals(rightId));

      // Canvas hit test with standard canvas size 800x600
      const canvasSize = Size(800, 600);
      final margin = 0.25;
      final totalW = style.defaultWidth + margin * 2;
      final totalH = style.defaultHeight + margin * 2;
      final scale = (600 / totalH) * 0.90;
      final origin = Offset(
        canvasSize.width / 2 - (style.defaultWidth / 2) * scale,
        canvasSize.height / 2 + (style.defaultHeight / 2) * scale,
      );

      // Point in left pane on canvas
      final canvasLeftPoint = Offset(
        origin.dx + 0.35 * scale,
        origin.dy - 0.70 * scale,
      );
      final canvasHit = style.hitTestFromCanvas(canvasLeftPoint, canvasSize);
      expect(canvasHit, isNotNull);
      expect(canvasHit!.$1.id, equals(leftId));
    });

    test('2D Elevation rendering executes cleanly with operable sash and muntins', () {
      final style = ArchitectFenestrationStyle(
        id: 'test_muntin_win',
        name: 'Muntin Casement',
        kind: FenestrationKind.window,
        defaultWidth: 1.20,
        defaultHeight: 1.50,
        hasCasing: true,
        casingWidth: 0.08,
        rootSubdivision: const FenestrationSubdivision(
          id: 'root',
          pane: FenestrationPane(
            id: 'p_tilt',
            paneType: PaneType.tiltAndTurn,
            sashProfileWidth: 0.065,
            muntinCols: 2,
            muntinRows: 2,
            muntinWidth: 0.022,
          ),
        ),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => style.paintElevation2D(
          canvas: canvas,
          size: const Size(600, 500),
          selectedPaneId: 'p_tilt',
        ),
        returnsNormally,
      );
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('3D opening mesh generates solid double glazing and 3D muntin bars', () {
      final style = ArchitectFenestrationStyle(
        id: 'test_3d_win',
        name: '3D Test Window',
        kind: FenestrationKind.window,
        defaultWidth: 1.00,
        defaultHeight: 1.20,
        defaultSillHeight: 0.85,
        hasCasing: true,
        casingWidth: 0.08,
        casingProjection: 0.03,
        rootSubdivision: const FenestrationSubdivision(
          id: 'root',
          pane: FenestrationPane(
            id: 'p1',
            paneType: PaneType.tiltAndTurn,
            muntinCols: 1,
            muntinRows: 1,
            muntinWidth: 0.025,
          ),
        ),
      );

      final triangles = Fenestration3dBuilder.buildOpening3D(
        style: style,
        wallStart: const Offset(-1.0, 0),
        wallEnd: const Offset(1.0, 0),
        wallThickness: 0.37,
        coreThickness: 0.25,
        insulationThickness: 0.12,
        exteriorSign: 1.0,
        offsetRatio: 0.5,
        width: 1.00,
        height: 1.20,
        sillHeight: 0.85,
        storeyElevation: 0.0,
      );

      expect(triangles.isNotEmpty, isTrue);
      // Verify casing, frame, double glazing, and 3D muntin triangles were emitted
      expect(triangles.length, greaterThan(40));
    });
  });
}
