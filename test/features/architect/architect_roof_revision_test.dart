import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_hatch_pattern.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_drainage_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_downpipe_handle.dart';
import 'package:kotoview/src/features/architect/widgets/architect_projection_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'architect_roof_drainage_test.dart' as fixture;
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_workspace_interaction_test.dart' as workspace;

Widget host(Widget child, String language) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

ArchitectDownpipeHandlePainter pipePainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('downpipe-handle-paint')),
            )
            .painter!
        as ArchitectDownpipeHandlePainter;

RoofSnapGuideResult? guide(ArchitectStorey floor, Offset raw) =>
    ArchitectRoofGeometry.resolveRoofGuideSnap(
      raw: raw,
      anchor: Offset.zero,
      draftPoints: const [Offset.zero, Offset(10, 0)],
      activeStorey: floor,
      currentSlopeDegrees: 30,
      snapTolerance: .15,
      hip45Label: () => '45',
      hipAngleLabel: (v) => v,
      hipIntersectionLabel: () => 'apex',
      cornerHipIntersectionLabel: () => 'corner',
      ridgeAlignmentLabel: () => 'ridge',
      perpToCornerLabel: () => 'perpendicular',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(qa.loadQaFonts);
  test('opposite slopes and far facade corners never emit drafting guides', () {
    final opposite = ArchitectRoofPlane(
      id: 'opposite',
      storeyId: 's',
      points: const [Offset(2, 4), Offset(3, 4), Offset(3, 7)],
      slopeDegrees: 30,
    );
    final floor = ArchitectStorey(
      id: 's',
      name: '',
      walls: const [
        ArchitectWall(
          id: 'base',
          startPoint: Offset.zero,
          endPoint: Offset(10, 0),
        ),
        ArchitectWall(
          id: 'far',
          startPoint: Offset(2, 4),
          endPoint: Offset(2, 8),
        ),
      ],
      roofs: [opposite],
    );
    final result = guide(floor, const Offset(3.02, 2.98))!;
    expect(result.isIntersectionSnap, isFalse);
    expect(result.magneticGuides.every((g) => g.$1 == Offset.zero), isTrue);
    final empty = guide(floor.copyWith(walls: []), const Offset(3.02, 2.98))!;
    expect(empty.isIntersectionSnap, isFalse);
  });

  test(
    'overhead roof edges are thin dashed strokes with shared edges drawn once',
    () {
      final p = fixture.drainageProject();
      final roofFloor = p.activeStorey.copyWith(
        elevation: 3,
        walls: [],
        isRoof: true,
      );
      final project = p.copyWith(
        storeys: [
          const ArchitectStorey(id: 'below', name: ''),
          roofFloor,
        ],
        activeStoreyId: 'below',
      );
      final canvas = ArchitectVectorCanvas();
      ArchitectRoofPainterHelper.paintOverhead(
        canvas: canvas,
        project: project,
        scale: 100,
        color: Colors.black,
      );
      final edges = canvas.operations.whereType<ArchitectVectorPath>().toList();
      expect(edges, isNotEmpty);
      expect(edges.every((e) => !e.fill && e.role == 'roofOverhead'), isTrue);
      expect(
        edges
            .expand((e) => e.path.computeMetrics())
            .every((m) => m.length <= .06001),
        isTrue,
      );
      expect(
        edges.fold<double>(
          0,
          (sum, e) =>
              sum +
              e.path.computeMetrics().fold<double>(0, (a, b) => a + b.length),
        ),
        lessThan(20),
      );
    },
  );

  test(
    'section hatch spacing and phase stay fixed in model coordinates at every zoom',
    () {
      final p = fixture.drainageProject();
      const cut = ArchitectSection(
        id: 'cut',
        start: Offset.zero,
        end: Offset(4, 0),
      );
      final data = ArchitectBuildingSection([
        ArchitectSectionRegion(
          'material',
          SlabMaterial.concrete,
          Path()..addRect(const Rect.fromLTWH(0, 0, 4, 3)),
          hatchPattern: const ArchitectHatchPattern(
            id: 'horizontal',
            layers: [ArchitectHatchLayer(angleDeg: 0)],
          ),
        ),
      ], const Rect.fromLTWH(0, 0, 4, 3));
      final drawing = ArchitectSectionDrawing(
        p,
        cut,
        data,
        lookupAppLocalizations(const Locale('en')),
        const ColorScheme.light(),
        null,
        null,
      );
      List<double> stations(double scale, Offset centre) {
        final canvas = ArchitectVectorCanvas();
        ArchitectBuildingSectionPainter(
          drawing,
          centre,
          scale,
        ).paint(canvas, const Size(800, 600));
        final hatch = canvas.operations
            .whereType<ArchitectVectorPath>()
            .firstWhere((e) => e.role == 'sectionHatch');
        return [
          for (final line in hatch.path.computeMetrics())
            centre.dy -
                (line.getTangentForOffset(0)!.position.dy - 300) / scale,
        ];
      }

      final a = stations(40, const Offset(2, 1.5));
      final b = stations(80, const Offset(1.5, 1));
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i], closeTo(b[i], 1e-6));
      }
    },
  );

  for (final language in ['bg', 'en']) {
    testWidgets(
      'downpipe leader moves along gutter with one undo ($language)',
      (tester) async {
        await qa.phone(tester);
        final controller = ArchitectCommandController(
          fixture.drainageProject(),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          host(
            AnimatedBuilder(
              animation: controller,
              builder: (_, _) => ArchitectDownpipeHandle(
                controller: controller,
                toScreen: (p, z) => Offset(50 + p.dx * 50, 300 + p.dy * 50),
              ),
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final at = pipePainter(tester).views.single.points.first;
        await tester.tapAt(at);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('downpipe-offset')), findsOneWidget);
        final handle = pipePainter(tester).handle!;
        expect((handle - at).distance, greaterThan(40));
        final drag = await tester.startGesture(handle);
        await drag.moveBy(const Offset(40, 20));
        await tester.pump();
        expect(controller.canUndo, isFalse);
        await drag.up();
        await tester.pumpAndSettle();
        expect(controller.undoCount, 1);
        expect(
          controller
              .project
              .activeStorey
              .roofs
              .single
              .drainage
              .downpipes
              .single
              .offset,
          closeTo(2.8, 1e-7),
        );
        controller.undo();
        await tester.pumpAndSettle();
        expect(
          controller
              .project
              .activeStorey
              .roofs
              .single
              .drainage
              .downpipes
              .single
              .offset,
          2,
        );
        final cancel = await tester.startGesture(pipePainter(tester).handle!);
        await cancel.moveBy(const Offset(30, 0));
        await tester.pump();
        await cancel.cancel();
        await tester.pumpAndSettle();
        expect(controller.canUndo, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('roof wall and slab expose section context menus ($language)', (
      tester,
    ) async {
      final base = fixture.drainageProject();
      final controller = ArchitectCommandController(
        base.updateActiveStorey(
          base.activeStorey.copyWith(
            slabs: [
              ArchitectSlab(
                id: 'slab',
                polygon: const [Offset.zero, Offset(4, 0), Offset(4, 4)],
                thickness: .2,
              ),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      final paths = {
        for (final (id, x) in [('roof', 1.0), ('facade', 4.0), ('slab', 7.0)])
          id: Path()..addRect(Rect.fromLTWH(x, 2, 2, 1)),
      };
      await tester.pumpWidget(
        host(
          ArchitectProjectionEditor(
            controller: controller,
            paths: paths,
            origin: Offset.zero,
            right: const Offset(1, 0),
            elevation: false,
            scale: 50,
            toView: (p) => p / 50,
            toScreen: (p) => p * 50,
          ),
          language,
        ),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(language));
      for (final x in [2.0, 5.0, 8.0]) {
        final mouse = await tester.startGesture(
          Offset(x * 50, 125),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await mouse.up();
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(PopupMenuItem<String>, l.architectProperties),
          findsOneWidget,
        );
        if (x == 2) expect(find.text(l.architectRoofPitchEdit), findsOneWidget);
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
      }
      await tester.longPressAt(const Offset(250, 125));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(PopupMenuItem<String>, l.architectProperties),
        findsOneWidget,
      );
      expect(controller.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'plan downpipe handle bypasses drawing input and retains its position',
    (tester) async {
      final controller = ArchitectCommandController(fixture.drainageProject());
      addTearDown(controller.dispose);
      await workspace.open(tester, controller);
      final at = pipePainter(tester).views.single.points.first;
      final panel = tester.getTopLeft(find.byType(ArchitectDownpipeHandle));
      await tester.tapAt(panel + at);
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(
        panel + pipePainter(tester).handle!,
      );
      final pixels = workspace.camera(tester).scale;
      await drag.moveBy(Offset(.75 * pixels, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(controller.undoCount, 1);
      expect(
        controller
            .project
            .activeStorey
            .roofs
            .single
            .drainage
            .downpipes
            .single
            .offset,
        closeTo(2.75, .001),
      );
      expect(tester.takeException(), isNull);
    },
  );
  test('new downpipe starts in the middle of the exposed facade', () {
    final p = fixture.drainageProject();
    expect(
      ArchitectRoofDrainageGeometry.initialOffset(
        p,
        p.activeStorey.roofs.single,
      ),
      3,
    );
  });
  test(
    'new downpipe uses a wall midpoint rather than a joint between facade walls',
    () {
      final source = fixture.drainageProject();
      final p = source.updateActiveStorey(
        source.activeStorey.copyWith(
          walls: const [
            ArchitectWall(
              id: 'a',
              startPoint: Offset(0, 1),
              endPoint: Offset(3, 1),
            ),
            ArchitectWall(
              id: 'b',
              startPoint: Offset(3, 1),
              endPoint: Offset(6, 1),
            ),
          ],
        ),
      );
      expect(
        ArchitectRoofDrainageGeometry.initialOffset(
          p,
          p.activeStorey.roofs.single,
        ),
        anyOf(1.5, 4.5),
      );
    },
  );
  testWidgets(
    'roof corner object snap takes precedence over a nearby 45 degree guide',
    (tester) async {
      final source = fixture.drainageProject();
      final roof = source.activeStorey.roofs.single.copyWith(
        points: const [Offset(3, 2.96), Offset(4, 2.96), Offset(4, 4)],
        drainage: const ArchitectRoofDrainage(),
      );
      final controller = ArchitectCommandController(
        source.updateActiveStorey(
          source.activeStorey.copyWith(roofs: [roof], walls: []),
        ),
      );
      addTearDown(controller.dispose);
      await workspace.open(tester, controller);
      tester
          .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
          .onToolChanged(ArchitectTool.roof);
      await tester.pumpAndSettle();
      final tool = workspace.overlay(tester).roofTool!;
      tool.setDrawMode(RoofDrawMode.polygon);
      tool.addDraftPoint(Offset.zero, storey: controller.project.activeStorey);
      tool.addDraftPoint(
        const Offset(6, 0),
        storey: controller.project.activeStorey,
      );
      workspace.camera(tester).fit(const Rect.fromLTRB(-1, -1, 7, 6));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(3, 2.99)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(3, 2.99)));
      await tester.pump();
      expect(
        (tool.candidatePoint! - const Offset(3, 2.96)).distance,
        lessThan(1e-6),
      );
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'section downpipe can be selected and moved separately from its roof',
    (tester) async {
      final controller = ArchitectCommandController(fixture.drainageProject());
      addTearDown(controller.dispose);
      const cut = ArchitectSection(
        id: 'cut',
        start: Offset(-1, -1),
        end: Offset(7, -1),
      );
      await tester.pumpWidget(
        host(
          AnimatedBuilder(
            animation: controller,
            builder: (_, _) {
              final data = ArchitectBuildingSection.build(
                controller.project,
                cut,
              ).forView(cut);
              return ArchitectProjectionEditor(
                controller: controller,
                paths: data.elementPaths,
                roofProfiles: data.roofProfiles,
                origin: cut.drawingOrigin,
                right: cut.drawingRight,
                elevation: false,
                scale: 40,
                toView: (p) => Offset((p.dx - 50) / 40, (500 - p.dy) / 40),
                toScreen: (p) => Offset(50 + p.dx * 40, 500 - p.dy * 40),
              );
            },
          ),
          'bg',
        ),
      );
      await tester.pumpAndSettle();
      expect(pipePainter(tester).views, hasLength(1));
      final points = pipePainter(tester).views.single.points;
      await tester.tapAt((points[points.length - 2] + points.last) / 2);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('projection-properties')), findsNothing);
      final handle = pipePainter(tester).handle!;
      final drag = await tester.startGesture(handle);
      await drag.moveBy(const Offset(-30, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        controller
            .project
            .activeStorey
            .roofs
            .single
            .drainage
            .downpipes
            .single
            .offset,
        closeTo(2.75, 1e-7),
      );
      expect(controller.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'full building sections with gutters and downpipes finish promptly',
    () {
      final p = ArchitectProject.fromJson(
        jsonDecode(
          File(
            'test/fixtures/bim_package_roof_drainage_corners.json',
          ).readAsStringSync(),
        ),
      );
      final roof = p.storeys.last.roofs.first;
      final pipe = ArchitectRoofDrainageGeometry.build(
        p,
        p.storeys.last,
        roof,
      ).routes.first;
      final x = pipe.points.first.x, y = pipe.points.first.y;
      for (final cut in [
        ArchitectSection(
          id: 'across',
          start: Offset(x, y - 1),
          end: Offset(x, y + 25),
        ),
        ArchitectSection(
          id: 'along',
          start: Offset(x - 20, y + .001),
          end: Offset(x + 20, y + .001),
        ),
      ]) {
        final timer = Stopwatch()..start();
        final data = ArchitectBuildingSection.build(p, cut);
        // Include contour merging and ownership paths used on the first frame.
        expect(data.drawingRegions, isNotEmpty);
        expect(data.elementPaths, isNotEmpty);
        expect(
          timer.elapsedMilliseconds,
          lessThan(5000),
          reason: '${cut.id}: ${timer.elapsedMilliseconds} ms',
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
