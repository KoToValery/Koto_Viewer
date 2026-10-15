import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' show ImageByteFormat;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_editor.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_dimensions.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_scene_geometry.dart';
import 'package:kotoview/src/features/architect/widgets/architect_shape_dimension_panel.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'architect_polygon_editor_test.dart' as shapes;
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  for (final reversed in [false, true]) {
    test(
      'Absolute inside/outside distances move only the chosen edge ($reversed)',
      () {
        final polygon = reversed
            ? shapes.rectangle.reversed.toList()
            : shapes.rectangle;
        final edge = ArchitectPolygonDimensions.hitEdge(
          polygon,
          const Offset(6, 2),
          .01,
        )!;
        final dimensions = ArchitectPolygonDimensions.nearest(
          elementId: 'r',
          polygon: polygon,
          edge: edge,
          storey: ArchitectStorey(
            id: 's',
            name: 's',
            walls: [
              editing.wall('wall', const Offset(10, -1), const Offset(10, 5)),
              editing.wall('far', const Offset(12, -1), const Offset(12, 5)),
              editing.wall('disjoint', const Offset(7, 8), const Offset(7, 10)),
            ],
          ),
        );
        expect(dimensions, hasLength(2));
        final internal = dimensions.firstWhere((d) => d.referenceId == 'r');
        expect(internal.distance, 6);
        final enlarged = internal.setDistance(polygon, 6.5)!;
        expect(ArchitectSceneGeometry.boundsOf(enlarged).right, 6.5);
        expect(enlarged, containsAll(polygon));
        final external = dimensions.firstWhere((d) => d.referenceId == 'wall');
        expect(external.distance, closeTo(3.875, 1e-9));
        final moved = external.setDistance(polygon, 2)!;
        expect(
          ArchitectSceneGeometry.boundsOf(moved).right,
          closeTo(7.875, 1e-9),
        );
        expect(moved, containsAll(polygon));
        expect(internal.setDistance(polygon, double.nan), isNull);
        expect(internal.setDistance(polygon, 0), isNull);
      },
    );
  }

  test(
    'Distances work in rotated contours and measure neighboring slabs/rectangles',
    () {
      Offset rotate(Offset p) => Offset(
        p.dx * math.cos(.6) - p.dy * math.sin(.6),
        p.dx * math.sin(.6) + p.dy * math.cos(.6),
      );
      final polygon = shapes.rectangle.map(rotate).toList();
      final adjacent = shapes.rectangle
          .map((p) => rotate(p + const Offset(9, 0)))
          .toList();
      final dimensions = ArchitectPolygonDimensions.nearest(
        elementId: 'r',
        polygon: polygon,
        edge: 1,
        storey: ArchitectStorey(
          id: 's',
          name: 's',
          slabs: [ArchitectSlab(id: 'other', polygon: adjacent)],
        ),
      );
      expect(dimensions, hasLength(2));
      expect(dimensions.last.referenceId, 'other');
      expect(dimensions.last.distance, closeTo(3, 1e-9));
      final moved = dimensions.first.setDistance(polygon, 8)!;
      expect(ArchitectPolygonGeometry.signedArea(moved), closeTo(32, 1e-9));
    },
  );

  for (final slab in [false, true]) {
    testWidgets(
      'Edit edge via absolute cm distance, preview, Cancel, Save and one Undo (slab=$slab)',
      (tester) async {
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: 's',
            cadPrimitives: slab ? [] : [shapes.primitive],
            slabs: slab
                ? [
                    const ArchitectSlab(
                      id: 'r',
                      polygon: shapes.rectangle,
                      thickness: .23,
                    ),
                  ]
                : [],
          ),
        );
        addTearDown(model.dispose);
        model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
        await workspace.open(tester, model);
        await shapes.tool(
          tester,
          slab ? Icons.layers_rounded : Icons.crop_square_rounded,
        );
        await editing.contextHold(tester, const Offset(3, 2));
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectRadialMenu), findsOneWidget);
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        // A quick edge tap selects it without moving it or starting a new shape.
        final before = model.project;
        await workspace.wallTap(tester, const Offset(6, 2));
        await tester.pumpAndSettle();
        final distance = find.byKey(const ValueKey('polygon-distance-r-3'));
        expect(distance, findsOneWidget);
        expect(find.text('600.00 cm'), findsOneWidget);
        await tester.tap(distance);
        await tester.pumpAndSettle();
        await shapes.enter(tester, '650.25');
        expect(identical(before, model.project), isTrue);
        final preview = workspace.overlay(tester).project;
        expect(
          ArchitectSceneGeometry.boundsOf(shapes.contour(preview, slab)).right,
          closeTo(6.5025, 1e-9),
        );
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byKey(const ValueKey('shape-cancel')));
        await tester.pumpAndSettle();
        expect(identical(before, model.project), isTrue);
        await tester.tap(distance);
        await tester.pumpAndSettle();
        await shapes.enter(tester, '650.25');
        await tester.tap(find.byKey(const ValueKey('shape-save')));
        await tester.pumpAndSettle();
        final updated = shapes.contour(model.project, slab);
        expect(
          ArchitectSceneGeometry.boundsOf(updated).right,
          closeTo(6.5025, 1e-9),
        );
        expect(updated, containsAll(shapes.rectangle));
        expect(updated, hasLength(6));
        if (slab) {
          expect(model.project.activeStorey.slabs.single.thickness, .23);
        }
        model.undo();
        await tester.pumpAndSettle();
        expect(identical(before, model.project), isTrue);
      },
    );
  }
  test('Offset handles do not add their screen clearance to the movement', () {
    final editor = ArchitectPolygonEditor();
    for (final edge in [false, true]) {
      final handle = edge
          ? ArchitectPolygonEditor.offsetEdgeHandle(shapes.rectangle, 1, 100)
          : ArchitectPolygonEditor.offsetVertexHandle(shapes.rectangle, 1, 100);
      expect(editor.start('r', shapes.rectangle, handle, 100), isTrue);
      editor.update(handle, shapes.free, .1);
      expect(editor.preview, shapes.rectangle);
      editor.update(handle + const Offset(.5, 0), shapes.free, .1);
      expect(editor.editedPoint!.dx, closeTo(6.5, 1e-9));
      expect(editor.leaderLine!.$2, handle + const Offset(.5, 0));
      editor.cancel();
    }
  });

  testWidgets(
    'Phone edge distances, neighbor distance and signed offset use the local keypad',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = bool.fromEnvironment('UPDATE_ARCHITECT_DISTANCE_PREVIEW');
      if (capture) {
        await tester.runAsync(() async {
          final font = FontLoader('Roboto')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
                ),
              ),
            );
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      Future<void> screenshot(String name) async {
        if (!capture) return;
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('distance-phone-preview')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ImageByteFormat.png);
          await File(
            'docs/images/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          cadPrimitives: [shapes.primitive],
          walls: [
            editing.wall('wall', const Offset(10, 0), const Offset(10, 4)),
          ],
        ),
      );
      model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
      addTearDown(model.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('distance-phone-preview'),
          child: MaterialApp(
            theme: ThemeData.dark(),
            locale: const Locale('bg'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await shapes.tool(tester, Icons.crop_square_rounded);
      await editing.contextHold(tester, const Offset(3, 2));
      await tester.pumpAndSettle();
      final menu = tester.widget<ArchitectRadialMenu>(
        find.byType(ArchitectRadialMenu),
      );
      await tester.tap(
        find.text(
          menu.items
              .firstWhere((item) => item.action == ArchitectRadialAction.edit)
              .label,
        ),
      );
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(6, 2));
      await tester.pumpAndSettle();
      final external = find.byKey(const ValueKey('polygon-distance-wall-2'));
      expect(external, findsOneWidget);
      await screenshot('architect_edge_distances_phone');
      final before = model.project;
      await tester.tap(external);
      await tester.pumpAndSettle();
      final panelRect = tester.getRect(
        find.byType(ArchitectShapeDimensionPanel),
      );
      expect(panelRect.left, greaterThanOrEqualTo(0));
      expect(panelRect.right, lessThanOrEqualTo(360));
      expect(panelRect.bottom, lessThanOrEqualTo(800));
      await shapes.enter(tester, '200');
      await tester.pumpAndSettle();
      await screenshot('architect_edge_distance_input_phone');
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      expect(
        ArchitectSceneGeometry.boundsOf(
          model.project.activeStorey.cadPrimitives.single.polygonCorners,
        ).right,
        closeTo(7.875, 1e-9),
      );
      expect(model.project.activeStorey.walls, before.activeStorey.walls);
      await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
      await tester.pumpAndSettle();
      await shapes.enter(tester, '50');
      await tester.tap(find.text('±'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      expect(
        ArchitectSceneGeometry.boundsOf(
          model.project.activeStorey.cadPrimitives.single.polygonCorners,
        ).right,
        closeTo(7.375, 1e-9),
      );
      expect(tester.testTextInput.isVisible, isFalse);
      // Pulling through the opposite edge cannot save an invalid contour.
      final stable = model.project;
      await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
      await tester.pumpAndSettle();
      await shapes.enter(tester, '900');
      await tester.tap(find.text('±'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('shape-save')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('shape-cancel')));
      await tester.pumpAndSettle();
      expect(model.project, same(stable));
      await tester.tap(find.byKey(const ValueKey('polygon-edge-move')));
      await tester.pumpAndSettle();
      final closeRect = tester.getRect(
        find.byKey(const ValueKey('polygon-edit-close')),
      );
      final magnetRect = tester.getRect(
        find.byKey(const ValueKey('architect-settings')),
      );
      expect(closeRect.overlaps(magnetRect), isFalse);
      final oldContour =
          model.project.activeStorey.cadPrimitives.single.polygonCorners;
      await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
      await tester.pumpAndSettle();
      await shapes.enter(tester, '50');
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      final movedContour =
          model.project.activeStorey.cadPrimitives.single.polygonCorners;
      expect(movedContour, hasLength(oldContour.length));
      expect(
        ArchitectSceneGeometry.boundsOf(movedContour).right,
        closeTo(7.875, 1e-9),
      );
      await screenshot('architect_edge_move_phone');
      expect(tester.takeException(), isNull);
    },
  );
  for (final reversed in [false, true]) {
    test(
      'Parallel move translates both ends, retains length and joins neighbors ($reversed)',
      () {
        final polygon = reversed
            ? shapes.rectangle.reversed.toList()
            : shapes.rectangle;
        final edge = ArchitectPolygonDimensions.hitEdge(
          polygon,
          const Offset(6, 2),
          .01,
        )!;
        final moved = ArchitectPolygonGeometry.moveEdge(polygon, edge, 2)!;
        expect(moved, hasLength(4));
        expect(
          moved,
          containsAll([
            const Offset(8, 0),
            const Offset(8, 4),
            const Offset(0, 0),
            const Offset(0, 4),
          ]),
        );
        expect(moved, isNot(contains(const Offset(6, 0))));
        expect(moved, isNot(contains(const Offset(6, 4))));
        final a = polygon[edge], b = polygon[(edge + 1) % polygon.length];
        expect(moved[(edge + 1) % moved.length] - moved[edge], b - a);
        expect(ArchitectPolygonGeometry.valid(moved), isTrue);
        expect(ArchitectPolygonGeometry.moveEdge(polygon, edge, -6), isNull);
        expect(ArchitectPolygonGeometry.moveEdge(polygon, edge, -7), isNull);
        expect(
          ArchitectPolygonGeometry.moveEdge(polygon, edge, double.infinity),
          isNull,
        );
        final back = ArchitectPolygonGeometry.moveEdge(moved, edge, -2)!;
        expect(back, polygon);
      },
    );
  }
  test(
    'Parallel edge movement handles rotation, concave crossings and wrapped endpoints',
    () {
      Offset rotate(Offset p) => Offset(
        p.dx * math.cos(.7) - p.dy * math.sin(.7),
        p.dx * math.sin(.7) + p.dy * math.cos(.7),
      );
      final polygon = shapes.rectangle.map(rotate).toList();
      final moved = ArchitectPolygonGeometry.moveEdge(polygon, 3, 2)!;
      expect(moved, hasLength(4));
      expect(moved[1], polygon[1]);
      expect(moved[2], polygon[2]);
      expect(
        ((moved[0] - moved[3]) - (polygon[0] - polygon[3])).distance,
        lessThan(1e-9),
      );
      expect(
        (moved[0] - polygon[0] - (moved[3] - polygon[3])).distance,
        lessThan(1e-9),
      );
      const concave = [
        Offset(0, 0),
        Offset(6, 0),
        Offset(6, 2),
        Offset(2, 2),
        Offset(2, 4),
        Offset(0, 4),
      ];
      expect(ArchitectPolygonGeometry.moveEdge(concave, 2, -3), isNull);
    },
  );
  test(
    'Parallel mode starts anywhere on an edge and keeps the last valid preview',
    () {
      final editor = ArchitectPolygonEditor();
      expect(
        editor.startEdge('r', shapes.rectangle, 1, const Offset(6, .8), 100),
        isTrue,
      );
      editor.update(const Offset(8, 3.8), shapes.free, .1);
      expect(editor.preview, hasLength(4));
      expect(
        editor.preview,
        containsAll([const Offset(8, 0), const Offset(8, 4)]),
      );
      final valid = editor.preview;
      editor.update(const Offset(-1, .8), shapes.free, .1);
      expect(editor.invalid, isTrue);
      expect(editor.preview, same(valid));
    },
  );

  for (final slab in [false, true]) {
    testWidgets(
      'Move an entire edge by dragging or by its cm distance (slab=$slab)',
      (tester) async {
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: 's',
            cadPrimitives: slab ? [] : [shapes.primitive],
            slabs: slab
                ? [
                    const ArchitectSlab(
                      id: 'r',
                      polygon: shapes.rectangle,
                      thickness: .23,
                    ),
                  ]
                : [],
          ),
        );
        model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await shapes.tool(
          tester,
          slab ? Icons.layers_rounded : Icons.crop_square_rounded,
        );
        await editing.contextHold(tester, const Offset(3, 2));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('polygon-edge-move')));
        await tester.pumpAndSettle();
        final initial = model.project;
        // Hold away from the midpoint: the complete edge moves, without a jump.
        final drag = await tester.startGesture(
          workspace.screen(tester, const Offset(6, 1)),
        );
        await tester.pump(const Duration(milliseconds: 281));
        await drag.moveTo(workspace.screen(tester, const Offset(7, 1)));
        await tester.pump();
        expect(model.project, same(initial));
        expect(
          shapes.contour(workspace.overlay(tester).project, slab),
          hasLength(4),
        );
        await drag.up();
        await tester.pumpAndSettle();
        final dragged = shapes.contour(model.project, slab);
        expect(dragged, hasLength(4));
        expect(
          dragged,
          containsAll([
            const Offset(7, 0),
            const Offset(7, 4),
            const Offset(0, 0),
            const Offset(0, 4),
          ]),
        );
        final beforeSize = model.project;
        final dimension = find.byKey(const ValueKey('polygon-distance-r-3'));
        await tester.tap(dimension);
        await tester.pumpAndSettle();
        await shapes.enter(tester, '750.25');
        expect(model.project, same(beforeSize));
        await tester.tap(find.byKey(const ValueKey('shape-save')));
        await tester.pumpAndSettle();
        final resized = shapes.contour(model.project, slab);
        expect(resized, hasLength(4));
        expect(resized[1].dx, closeTo(7.5025, 1e-9));
        expect(resized[2].dx, closeTo(7.5025, 1e-9));
        if (slab) {
          expect(model.project.activeStorey.slabs.single.thickness, .23);
        }
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project, same(beforeSize));
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project, same(initial));
        // The other operation still retains old corners.
        await tester.tap(find.byKey(const ValueKey('polygon-edge-pull')));
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(6, 2));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
        await tester.pumpAndSettle();
        await shapes.enter(tester, '50');
        await tester.tap(find.byKey(const ValueKey('shape-save')));
        await tester.pumpAndSettle();
        expect(shapes.contour(model.project, slab), hasLength(6));
        expect(
          shapes.contour(model.project, slab),
          containsAll(shapes.rectangle),
        );
        expect(tester.testTextInput.isVisible, isFalse);
      },
    );
  }
  test('A snapped endpoint corrects the complete parallel edge', () {
    final editor = ArchitectPolygonEditor();
    final handle = ArchitectPolygonEditor.offsetEdgeHandle(
      shapes.rectangle,
      1,
      100,
    );
    expect(
      editor.start(
        'r',
        shapes.rectangle,
        handle,
        100,
        mode: ArchitectPolygonEdgeMode.move,
      ),
      isTrue,
    );
    editor.update(
      handle + const Offset(1.96, 0),
      (point) => (point - const Offset(8, 0)).distance < .1
          ? const ArchitectSnapResult(
              point: Offset(8, 0),
              isSnapped: true,
              snapLabel: 'Endpoint',
            )
          : shapes.free(point),
      .1,
    );
    expect(editor.activeSnap, isNotNull);
    expect(editor.preview, hasLength(4));
    expect(
      editor.preview,
      containsAll([const Offset(8, 0), const Offset(8, 4)]),
    );
  });
}
