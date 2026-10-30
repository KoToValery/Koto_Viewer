import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_line_style.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_view_drawing.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_scene_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_marquee_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_offset.dart';
import 'package:kotoview/src/features/architect/services/architect_polyline_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/widgets/architect_line_style_picker.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

const vertices = [Offset.zero, Offset(4, 0), Offset(4, 3)];
const polyline = ArchitectCadPrimitive(
  id: 'path',
  type: CadPrimitiveType.polyline,
  startPoint: Offset.zero,
  endPoint: Offset(4, 3),
  polygon: vertices,
  colorValue: 0xFF234567,
  strokeWidth: 2.5,
);

ArchitectCommandController seeded() {
  final model = editing.seeded(
    const ArchitectStorey(id: 's', name: 's', cadPrimitives: [polyline]),
  );
  addTearDown(model.dispose);
  return model;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'Mirroring and section reflection preserve ordered endpoints and all vertices',
    () {
      final model = seeded();
      final mirrored = ArchitectElementTool()
          .mirrorElementById(
            model.project.activeStorey,
            'path',
            origin: Offset.zero,
            direction: const Offset(0, 1),
          )
          .$1
          .cadPrimitives
          .single;
      expect(mirrored.linePoints, [
        Offset.zero,
        const Offset(-4, 0),
        const Offset(-4, 3),
      ]);
      expect(mirrored.startPoint, mirrored.linePoints.first);
      expect(mirrored.endPoint, mirrored.linePoints.last);
      const drawing = ArchitectViewDrawing(cadPrimitives: [polyline]);
      final reflected = drawing.reflectedHorizontally(10).cadPrimitives.single;
      expect(reflected.linePoints, [
        const Offset(10, 0),
        const Offset(6, 0),
        const Offset(6, 3),
      ]);
      expect(reflected.startPoint, reflected.linePoints.first);
      expect(reflected.endPoint, reflected.linePoints.last);
      expect(
        drawing
            .reflectedHorizontally(10)
            .reflectedHorizontally(10)
            .cadPrimitives
            .single
            .linePoints,
        vertices,
      );
    },
  );

  test(
    'Serialization, vertex edit, insertion and Undo preserve one native object',
    () {
      final model = seeded();
      final before = model.project.toJson();
      expect(
        ArchitectProject.fromJson(
          before,
        ).activeStorey.cadPrimitives.single.linePoints,
        vertices,
      );
      model.execute(
        UpdateArchitectPolyline(
          storeyId: 's',
          elementId: 'path',
          points: ArchitectPolylineEditing.moveVertex(
            vertices,
            1,
            const Offset(5, 1),
          ),
        ),
      );
      var result = model.project.activeStorey.cadPrimitives.single;
      expect(result.linePoints, [
        Offset.zero,
        const Offset(5, 1),
        const Offset(4, 3),
      ]);
      expect(result.colorValue, polyline.colorValue);
      expect(result.strokeWidth, polyline.strokeWidth);
      model.undo();
      expect(model.project.toJson(), before);
      model.redo();
      expect(
        model.project.activeStorey.cadPrimitives.single.linePoints[1],
        const Offset(5, 1),
      );
      model.undo();
      model.execute(
        const InsertArchitectElementPoint(
          storeyId: 's',
          elementId: 'path',
          newElementId: 'unused',
          point: Offset(2, 0),
        ),
      );
      result = model.project.activeStorey.cadPrimitives.single;
      expect(result.id, 'path');
      expect(result.linePoints, [
        Offset.zero,
        const Offset(2, 0),
        const Offset(4, 0),
        const Offset(4, 3),
      ]);
    },
  );

  test('Collapsed and nonfinite segments cannot mutate the project', () {
    final model = seeded();
    final before = model.project.toJson();
    for (final points in [
      [Offset.zero],
      [Offset.zero, Offset.zero],
      [Offset.zero, const Offset(double.nan, 0)],
    ]) {
      expect(
        () => model.execute(
          UpdateArchitectPolyline(
            storeyId: 's',
            elementId: 'path',
            points: points,
          ),
        ),
        throwsArgumentError,
      );
      expect(model.project.toJson(), before);
    }
  });

  test(
    'Print paths, picking and snapping contain only the actual open segments',
    () {
      final model = seeded();
      final floor = model.project.activeStorey;
      final canvas = ArchitectVectorCanvas(sourceIds: {'path'});
      ArchitectElementsPainterHelper.drawCadPrimitives(
        canvas: canvas,
        storey: floor,
        zoomScale: 100,
      );
      final path = (canvas.operations.single as ArchitectVectorPath).path;
      expect(path.computeMetrics().single.length, closeTo(7, 1e-6));
      expect(
        ArchitectSelection.outline(
          model.project,
          'path',
        ).computeMetrics().single.length,
        closeTo(7, 1e-6),
      );
      final edges = ArchitectSnapGeometry.of(
        model.project,
      ).edges.where((e) => e.owner == 'path');
      expect(edges, hasLength(2));
      final tool = ArchitectElementTool();
      expect(tool.hitTestElement(floor, const Offset(4, 2), 100), 'path');
      expect(tool.hitTestElement(floor, const Offset(2, 1.5), 100), isNull);
      final marquee = const [
        Offset(3.8, 1),
        Offset(4.2, 1),
        Offset(4.2, 2),
        Offset(3.8, 2),
      ];
      expect(
        ArchitectMarqueeTool.evaluateSelection(
          storey: floor,
          project: model.project,
          polygon: marquee,
        ),
        {'path'},
      );
      expect(
        ArchitectMarqueeTool.evaluateSelection(
          storey: floor,
          project: model.project,
          polygon: marquee,
          relation: ArchitectSelectionRelation.contained,
        ),
        isEmpty,
      );
    },
  );

  test(
    'Intermediate vertices survive viewport culling and copying translates the entire path',
    () {
      final model = seeded();
      final floor = model.project.activeStorey.copyWith(
        cadPrimitives: [
          polyline.copyWith(
            endPoint: const Offset(0, 1),
            polygon: const [
              Offset.zero,
              Offset(20, 0),
              Offset(20, 1),
              Offset(0, 1),
            ],
          ),
        ],
      );
      final project = model.project.updateActiveStorey(floor);
      expect(
        ArchitectSceneGeometry.visible(
          project,
          const Rect.fromLTWH(19, -.5, 2, 2),
          100,
        ).activeStorey.cadPrimitives,
        hasLength(1),
      );
      final copied = ArchitectElementTool().duplicateElementById(
        floor,
        'path',
        offset: const Offset(2, 3),
      );
      final result = copied.$1.cadPrimitives.last;
      expect(
        result.linePoints,
        floor.cadPrimitives.single.linePoints
            .map((p) => p + const Offset(2, 3))
            .toList(),
      );
      expect(result.id, isNot('path'));
    },
  );

  test(
    'Offset keeps an open path connected and preserves its native identity',
    () {
      final model = seeded();
      final shifted = ArchitectOffset.apply(
        model.project.activeStorey,
        {'path'},
        distance: 1,
        side: const Offset(2, -2),
      ).cadPrimitives.single;
      expect(shifted.id, 'path');
      expect(shifted.type, CadPrimitiveType.polyline);
      expect(shifted.linePoints, [
        const Offset(0, -1),
        const Offset(5, -1),
        const Offset(5, 3),
      ]);
      expect(shifted.strokeWidth, polyline.strokeWidth);
    },
  );

  test(
    'Leader grips remain usable at straight joints and shared closed endpoints',
    () {
      const straight = [Offset.zero, Offset(4, 0), Offset(8, 0)];
      final handle = ArchitectPolylineEditing.handle(straight, 1, 100, 50);
      expect(handle, const Offset(4, -.5));
      expect(ArchitectPolylineEditing.hit(straight, handle, 100, 50), (
        1,
        true,
      ));
      expect(ArchitectPolylineEditing.hit(straight, straight[1], 100, 0), (
        1,
        false,
      ));
      final closed = [...vertices, Offset.zero];
      final result = ArchitectPolylineEditing.moveVertex(
        closed,
        3,
        const Offset(-1, 1),
      );
      expect(result.first, result.last);
      ArchitectCadPrimitive.validatePolyline(result);
    },
  );

  testWidgets(
    'Phone polyline mode draws one path, ends it and starts a separate path',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      await tools.choose(tester, Icons.timeline_rounded);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-line-mode-polyline')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall-dimension-mode')));
      await tester.pump();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTRB(-3, -3, 7, 6), padding: 50);
      await tester.pump();
      final modeRect = tester.getRect(
        find.byKey(const ValueKey('architect-line-mode-polyline')),
      );
      expect(modeRect.right, lessThanOrEqualTo(360));
      await workspace.wallTap(tester, Offset.zero);
      await workspace.wallTap(tester, const Offset(4, 0));
      await workspace.wallTap(tester, const Offset(4, 3));
      expect(
        model.project.activeStorey.cadPrimitives.single.linePoints,
        vertices,
      );
      await tester.tap(find.byKey(const ValueKey('wall-stop-drawing')));
      await tester.pump();
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      await workspace.wallTap(tester, const Offset(0, 1));
      await workspace.wallTap(tester, const Offset(2, 1));
      expect(model.project.activeStorey.cadPrimitives, hasLength(2));
      model.undo();
      expect(
        model.project.activeStorey.cadPrimitives.single.linePoints,
        vertices,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Precision Continue and End append to one path and style changes apply to the whole path',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.timeline_rounded);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-line-mode-polyline')),
      );
      await tester.pump();
      await workspace.wallTap(tester, Offset.zero);
      await workspace.wallTap(tester, const Offset(4, 0));
      await tester.tap(find.byKey(const ValueKey('wall-continue')));
      await tester.pumpAndSettle();
      tester
          .widget<ArchitectLineStylePicker>(
            find.byKey(const ValueKey('architect-draft-line-style')),
          )
          .onChanged(ArchitectLineStyle.presets[1]);
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.single.lineStyle,
        ArchitectLineStyle.presets[1],
      );
      final first = model.project.activeStorey.cadPrimitives.single.linePoints;
      await workspace.wallTap(tester, const Offset(4, 3));
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      final points = model.project.activeStorey.cadPrimitives.single.linePoints;
      expect(points, hasLength(3));
      for (var i = 0; i < points.length; i++) {
        expect((points[i] - vertices[i]).distance, lessThan(1e-9));
      }
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      model.undo();
      expect(model.project.activeStorey.cadPrimitives.single.linePoints, first);
      model.redo();
      expect(
        model.project.activeStorey.cadPrimitives.single.linePoints,
        points,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['bg', 'en']) {
    testWidgets('Phone polyline controls and vertex grips fit in $language', (
      tester,
    ) async {
      final model = seeded();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = ValueKey('polyline-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        ),
      );
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTRB(-1, -1, 6, 5), padding: 40);
      await tools.choose(tester, Icons.timeline_rounded);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-line-mode-polyline')),
      );
      await tester.pumpAndSettle();
      final chip = tester.getRect(
        find.byKey(const ValueKey('architect-line-mode-polyline')),
      );
      expect(chip.left, greaterThanOrEqualTo(0));
      expect(chip.right, lessThanOrEqualTo(360));
      expect(
        find.text(language == 'bg' ? 'Полилиния' : 'Polyline'),
        findsOneWidget,
      );
      Future<void> snapshot(String stage) async {
        if (!const bool.fromEnvironment('POLYLINE_QA')) return;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('scratch').create(recursive: true);
          await File(
            'scratch/architect_polyline_${stage}_$language.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await snapshot('mode');
      await editing.hold(tester, const Offset(2, 0));
      expect(workspace.overlay(tester).selectedElementId, 'path');
      await snapshot('edit');
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets(
      'Dragging a shared vertex using its leader grip supports $kind and Undo',
      (tester) async {
        final model = seeded();
        await workspace.open(tester, model);
        await tools.choose(tester, Icons.timeline_rounded);
        await editing.hold(tester, const Offset(2, 0));
        expect(workspace.overlay(tester).selectedElementId, 'path');
        final painter = workspace.overlay(tester);
        final handle = ArchitectPolylineEditing.handle(
          vertices,
          1,
          workspace.camera(tester).scale,
          painter.handleOffsetLength,
        );
        const delta = Offset(1, 1);
        final drag = await tester.startGesture(
          workspace.screen(tester, handle),
          kind: kind,
        );
        await drag.moveTo(workspace.screen(tester, handle + delta));
        await tester.pump();
        expect(workspace.overlay(tester).wallEndpointLeaderLine, isNotNull);
        await drag.up();
        await tester.pumpAndSettle();
        final result = model.project.activeStorey.cadPrimitives.single;
        expect(result.linePoints, [
          Offset.zero,
          const Offset(5, 1),
          const Offset(4, 3),
        ]);
        expect(result.colorValue, polyline.colorValue);
        model.undo();
        expect(
          model.project.activeStorey.cadPrimitives.single.linePoints,
          vertices,
        );
        model.redo();
        expect(
          model.project.activeStorey.cadPrimitives.single.linePoints[1],
          const Offset(5, 1),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
