import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_floor_drain.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_view_drawing.dart';
import 'package:kotoview/src/features/architect/rendering/architect_annotation_layout.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_floor_drain_mesh.dart';
import 'package:kotoview/src/features/architect/rendering/architect_floor_drain_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_column_clearance.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drain_surface.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_polyline_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_rotation.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_drafting_panel.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'package:kotoview/src/features/architect/widgets/architect_property_number_field.dart';
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_workspace_interaction_test.dart' as workspace;

const square = [Offset.zero, Offset(4, 0), Offset(4, 4), Offset(0, 4)];
const text = ArchitectAnnotation(
  id: 'text',
  position: Offset(1, 1),
  text: 'Текст\nText',
  rotationDeg: 30,
  italic: true,
  underline: true,
);
ArchitectProject project(ArchitectStorey storey) => ArchitectProject(
  id: 'p',
  name: 'Test',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  storeys: [storey],
  activeStoreyId: storey.id,
);

void main() {
  setUpAll(() async {
    await qa.loadQaFonts();
    await (FontLoader('ArchitectNoto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Level units are independent, preserve signs and precision, and round zero',
    () {
      final p = project(
        const ArchitectStorey(id: 's', name: 's'),
      ).copyWith(units: ArchitectUnit.millimeters);
      expect(p.formatLevel(2.8), '+2.80');
      expect(p.formatLevel(-.15), '−0.15');
      expect(p.formatLevel(-.0001), '±0.00');
      final q = ArchitectProject.fromJson(
        p
            .copyWith(levelUnits: ArchitectUnit.centimeters, levelDecimals: 3)
            .toJson(),
      );
      expect(q.formatLevel(2.8), '+280.000');
      const m = ArchitectElevationMarker(
        id: 'm',
        position: Offset.zero,
        elevation: 2.8,
      );
      final custom = m.copyWith(
        units: ArchitectUnit.millimeters,
        decimals: 0,
        symbol: ArchitectLevelSymbol.plan,
      );
      expect(
        ArchitectElevationMarker.fromJson(custom.toJson()).formattedElevation,
        '+2800',
      );
      final next =
          SetArchitectElementProperties(
            storeyId: 's',
            elementIds: const {'m'},
            textValues: const {
              'levelUnits': 'inherit',
              'levelDecimals': 'inherit',
            },
          ).apply(
            project(
              ArchitectStorey(id: 's', name: 's', elevationMarkers: [custom]),
            ),
          );
      expect(next.activeStorey.elevationMarkers.single.units, isNull);
      expect(next.activeStorey.elevationMarkers.single.decimals, isNull);
    },
  );

  test(
    'Legacy and explicit polyline closure survives edits, opening and Undo',
    () {
      const points = [
        Offset.zero,
        Offset(4, 0),
        Offset(4, 3),
        Offset(0, 3),
        Offset.zero,
      ];
      const line = ArchitectCadPrimitive(
        id: 'path',
        type: CadPrimitiveType.polyline,
        startPoint: Offset.zero,
        endPoint: Offset.zero,
        polygon: points,
      );
      final c = ArchitectCommandController(
        project(
          const ArchitectStorey(id: 's', name: 's', cadPrimitives: [line]),
        ),
      );
      addTearDown(c.dispose);
      expect(line.isClosedPolyline, isTrue);
      c.execute(
        const UpdateArchitectPolygon(
          storeyId: 's',
          elementId: 'path',
          polygon: [Offset.zero, Offset(5, 0), Offset(5, 3), Offset(0, 3)],
        ),
      );
      final edited = c.project.activeStorey.cadPrimitives.single;
      expect(edited.linePoints.first, edited.linePoints.last);
      expect(edited.startPoint, edited.linePoints.first);
      expect(edited.endPoint, edited.linePoints.last);
      c.execute(
        UpdateArchitectPolyline(
          storeyId: 's',
          elementId: 'path',
          points: edited.linePoints,
          closed: false,
        ),
      );
      expect(
        c.project.activeStorey.cadPrimitives.single.isClosedPolyline,
        isFalse,
      );
      expect(c.project.activeStorey.cadPrimitives.single.linePoints.length, 4);
      c.undo();
      expect(
        c.project.activeStorey.cadPrimitives.single.isClosedPolyline,
        isTrue,
      );
      expect(
        ArchitectProject.fromJson(
          c.project.toJson(),
        ).activeStorey.cadPrimitives.single.isClosedPolyline,
        isTrue,
      );
    },
  );

  test('Moving an open side retains shared vertices and one native object', () {
    const points = [Offset.zero, Offset(4, 0), Offset(4, 3), Offset(7, 3)];
    final moved = ArchitectPolylineEditing.moveEdge(
      points,
      1,
      const Offset(1, 0),
    );
    expect(moved, [
      Offset.zero,
      const Offset(5, 0),
      const Offset(5, 3),
      const Offset(7, 3),
    ]);
    expect(
      ArchitectPolylineEditing.hitEdge(points, const Offset(4, 1.5), 100, 0),
      (1, false),
    );
  });

  test(
    'Polyline closure in Properties shares the validated contour command',
    () {
      const line = ArchitectCadPrimitive(
        id: 'line',
        type: CadPrimitiveType.polyline,
        startPoint: Offset.zero,
        endPoint: Offset(4, 3),
        polygon: [Offset.zero, Offset(4, 0), Offset(4, 3)],
      );
      final p = project(
        const ArchitectStorey(id: 's', name: 's', cadPrimitives: [line]),
      );
      final closed = const SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'line'},
        textValues: {'closed': 'true'},
      ).apply(p);
      expect(closed.activeStorey.cadPrimitives.single.isClosedPolyline, isTrue);
      final opened = const SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'line'},
        textValues: {'closed': 'false'},
      ).apply(closed);
      expect(
        opened.activeStorey.cadPrimitives.single.linePoints,
        line.linePoints,
      );
    },
  );

  test(
    'Column face clearances move only the selected column and support round and rotated sections',
    () {
      const a = ArchitectColumn(
        id: 'a',
        position: Offset(2, 0),
        width: .4,
        depth: .4,
      );
      const b = ArchitectColumn(
        id: 'b',
        position: Offset(5, 0),
        width: .6,
        depth: .4,
      );
      const wall = ArchitectWall(
        id: 'w',
        startPoint: Offset.zero,
        endPoint: Offset(8, 0),
        thickness: .2,
      );
      final c = ArchitectCommandController(
        project(
          const ArchitectStorey(
            id: 's',
            name: 's',
            columns: [a, b],
            walls: [wall],
          ),
        ),
      );
      addTearDown(c.dispose);
      final gaps = ArchitectColumnClearance.forColumn(c.project, 'a');
      final neighbor = gaps.singleWhere((g) => g.key.contains('neighbor:b:'));
      expect(neighbor.distance, closeTo(2.5, 1e-9));
      expect(gaps.where((g) => g.key.contains('wall:w:')).length, 2);
      c.execute(
        SetArchitectColumnClearance(
          storeyId: 's',
          columnId: 'a',
          key: neighbor.key,
          distance: 1.5,
        ),
      );
      expect(c.project.activeStorey.columns.first.position, const Offset(3, 0));
      expect(c.project.activeStorey.columns.last.position, b.position);
      c.undo();
      expect(c.project.activeStorey.columns.first.position, a.position);
      expect(
        ArchitectColumnClearance.extent(
          a.copyWith(rotationDeg: 45),
          const Offset(1, 0),
        ),
        closeTo(.4 / math.sqrt(2), 1e-9),
      );
      expect(
        ArchitectColumnClearance.extent(
          a.copyWith(shape: ColumnShape.circular),
          const Offset(1, 0),
        ),
        .2,
      );
    },
  );

  for (final shape in ArchitectDrainShape.values) {
    test(
      '$shape surface covers the actual floor, excludes openings and agrees with mesh and cut heights',
      () {
        final d = ArchitectFloorDrain(
          id: 'd',
          polygon: square,
          position: const Offset(1.5, 1),
          shape: shape,
          size: shape == ArchitectDrainShape.round ? .15 : 1,
          holes: const [
            [Offset(3, 2), Offset(3.5, 2), Offset(3.5, 3), Offset(3, 3)],
          ],
        );
        final surface = ArchitectDrainSurface.of(d);
        expect(surface.triangles, isNotEmpty);
        final grate = ArchitectDrainSurface.grate(d);
        double area(List<Offset> points) {
          var result = 0.0;
          for (var i = 0; i < points.length; i++) {
            final a = points[i], b = points[(i + 1) % points.length];
            result += a.dx * b.dy - a.dy * b.dx;
          }
          return result.abs() / 2;
        }

        expect(
          surface.triangles.fold(0.0, (v, t) => v + t.area),
          closeTo(d.area - area(grate), 1e-5),
        );
        for (final t in surface.triangles) {
          expect(d.containsPoint(t.centre), isTrue);
          expect(
            surface.heightAt(t.centre),
            closeTo((t.za + t.zb + t.zc) / 3, 1e-6),
          );
        }
        final floor = ArchitectStorey(id: 's', name: 's', floorDrains: [d]);
        final mesh = ArchitectFloorDrainMesh.build(project(floor), floor, d);
        for (var i = 0; i < surface.triangles.length; i++) {
          final t = surface.triangles[i], m = mesh[i * 2];
          expect(m.v0.z, closeTo(floor.floorFinishThickness + t.za, 1e-7));
        }
        for (final (a, b, za, zb) in surface.section(
          const Offset(0, .5),
          const Offset(4, .5),
        )) {
          expect(surface.heightAt(a), closeTo(za, 1e-6));
          expect(surface.heightAt(b), closeTo(zb, 1e-6));
        }
        final canvas = ArchitectVectorCanvas();
        ArchitectFloorDrainPainterHelper.drawOne(
          canvas: canvas,
          drain: d,
          walls: [],
          zoomScale: 100,
          palette: const ArchitectCanvasPalette.light(),
        );
        expect(canvas.operations.whereType<ArchitectVectorText>(), isEmpty);
      },
    );
  }

  test(
    'Text rotation, readable section reflection and copied paper sizes survive serialization',
    () {
      final p =
          project(
            const ArchitectStorey(id: 's', name: 's', annotations: [text]),
          ).copyWith(
            document: const ArchitectDocument(
              overrideMm: {
                'plan:s/text/ordinary/100': 3.5,
                'plan:s/text/ordinary/50': 2.5,
              },
            ),
          );
      final turn = ArchitectRotation.apply(
        p.activeStorey,
        {'text'},
        text.position,
        math.pi / 2,
      ).annotations.single;
      expect(turn.rotationDeg, closeTo(120, 1e-8));
      final twice = const ArchitectViewDrawing(
        annotations: [text],
      ).reflectedHorizontally(10).reflectedHorizontally(10);
      expect(twice.annotations.single.toJson(), text.toJson());
      final (floor, id) = ArchitectElementTool().duplicateElementById(
        p.activeStorey,
        'text',
        offset: const Offset(1, 0),
      );
      final copied = p.copyWith(
        document: p.document.copyElementOverrides({'text': id!}),
        storeys: [floor],
      );
      expect(
        copied.document.textMm(
          'plan:s',
          id,
          ArchitectAnnotationRole.ordinary,
          100,
        ),
        3.5,
      );
      expect(
        copied.document.textMm(
          'plan:s',
          id,
          ArchitectAnnotationRole.ordinary,
          50,
        ),
        2.5,
      );
      expect(
        ArchitectProject.fromJson(
          copied.toJson(),
        ).activeStorey.annotations.last.italic,
        isTrue,
      );
      final outline = ArchitectAnnotationLayout.outline(text, project: p);
      expect(outline.getBounds().width, greaterThan(.2));
      final canvas = ArchitectVectorCanvas();
      ArchitectTextScope(p.document, 'plan:s', 100, 100).run(
        () => ArchitectElementsPainterHelper.drawAnnotations(
          canvas: canvas,
          storey: p.activeStorey,
          zoomScale: 100,
        ),
      );
      final words = canvas.operations.whereType<ArchitectVectorText>().toList();
      expect(words.length, 2);
      expect(words.first.rotation, closeTo(math.pi / 6, 1e-7));
      expect(words.first.fontStyle, FontStyle.italic);
      expect(words.first.decoration, TextDecoration.underline);
    },
  );

  for (final locale in ['bg', 'en']) {
    testWidgets(
      '$locale text properties save paper height and preserve formatting on a phone',
      (tester) async {
        await qa.phone(tester);
        final p = project(
          const ArchitectStorey(id: 's', name: 's', annotations: [text]),
        );
        ArchitectProject? result;
        await tester.pumpWidget(
          qa.host(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ArchitectElementPropertiesDialog(
                      project: p,
                      elementIds: const {'text'},
                      onApply: (_, _) => false,
                      onApplyProject: (next) {
                        result = next;
                        return true;
                      },
                      viewKey: 'plan:s',
                      drawingScale: 100,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
            locale,
            GlobalKey(),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final field = find.byKey(
          const ValueKey('architect-property-paper-text-false'),
        );
        expect(field, findsOneWidget);
        await tester.enterText(field, '3,50');
        await tester.pump(const Duration(milliseconds: 250));
        final save = find.byKey(const ValueKey('properties-save'));
        if (save.evaluate().isNotEmpty) {
          await tester.tap(save);
        } else {
          await tester.tap(find.text(locale == 'bg' ? 'Запази' : 'Save').last);
        }
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        expect(
          result!.document.textMm(
            'plan:s',
            'text',
            ArchitectAnnotationRole.ordinary,
            100,
          ),
          3.5,
        );
        expect(result!.activeStorey.annotations.single.italic, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets(
      '$kind dragging a polyline side keeps adjacent sides connected',
      (tester) async {
        await qa.phone(tester);
        const points = [Offset.zero, Offset(4, 0), Offset(4, 3), Offset(7, 3)];
        final c = ArchitectCommandController(
          project(
            const ArchitectStorey(
              id: 's',
              name: 's',
              cadPrimitives: [
                ArchitectCadPrimitive(
                  id: 'path',
                  type: CadPrimitiveType.polyline,
                  startPoint: Offset.zero,
                  endPoint: Offset(7, 3),
                  polygon: points,
                ),
              ],
            ),
          ),
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          qa.host(
            ArchitectWorkspaceScreen(
              initialProject: c.project,
              commandController: c,
            ),
            'bg',
            GlobalKey(),
          ),
        );
        await tester.pumpAndSettle();
        workspace
            .camera(tester)
            .fit(const Rect.fromLTRB(-1, -2, 9, 5), padding: 40);
        await tester.pump();
        await tester.tapAt(
          workspace.screen(tester, const Offset(2, 0)),
          kind: kind,
        );
        await tester.pumpAndSettle();
        final from = workspace.screen(tester, const Offset(4, 1.5));
        final gesture = await tester.startGesture(from, kind: kind);
        await gesture.moveBy(Offset(workspace.camera(tester).scale, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        final moved = c.project.activeStorey.cadPrimitives.single;
        expect(moved.linePoints[1].dx, closeTo(5, .05));
        expect(moved.linePoints[2].dx, closeTo(5, .05));
        expect(moved.linePoints.first, Offset.zero);
        expect(moved.linePoints.last, const Offset(7, 3));
        c.undo();
        await tester.pumpAndSettle();
        expect(c.project.activeStorey.cadPrimitives.single.linePoints, points);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('Column clearances include the projected upper erker edge', () {
    const wall = ArchitectWall(
      id: 'w',
      startPoint: Offset.zero,
      endPoint: Offset(8, 0),
      thickness: .2,
    );
    final lower = ArchitectStorey(
      id: 's',
      name: 's',
      walls: const [wall],
      columns: const [
        ArchitectColumn(id: 'a', position: Offset(2, 0), width: .4, depth: .4),
      ],
      slabs: const [
        ArchitectSlab(
          id: 'lower',
          polygon: [Offset.zero, Offset(8, 0), Offset(8, 4), Offset(0, 4)],
        ),
      ],
    );
    const upper = ArchitectStorey(
      id: 'upper',
      name: 'upper',
      elevation: 3,
      slabs: [
        ArchitectSlab(
          id: 'upper-slab',
          polygon: [Offset(0, -1), Offset(8, -1), Offset(8, 4), Offset(0, 4)],
        ),
      ],
    );
    final p = project(lower).copyWith(storeys: [lower, upper]);
    final erkers = ArchitectColumnClearance.forColumn(
      p,
      'a',
    ).where((g) => g.key.contains(':erker:'));
    expect(erkers, isNotEmpty);
    expect(erkers.first.distance, closeTo(.8, .001));
  });

  testWidgets('Selected column uses the wall dimension keypad and one Undo', (
    tester,
  ) async {
    await qa.phone(tester);
    const floor = ArchitectStorey(
      id: 's',
      name: 's',
      walls: [
        ArchitectWall(
          id: 'w',
          startPoint: Offset.zero,
          endPoint: Offset(8, 0),
          thickness: .2,
        ),
      ],
      columns: [
        ArchitectColumn(id: 'a', position: Offset(2, 0), width: .4, depth: .4),
        ArchitectColumn(id: 'b', position: Offset(5, 0), width: .6, depth: .4),
      ],
    );
    final c = ArchitectCommandController(project(floor));
    addTearDown(c.dispose);
    await tester.pumpWidget(
      qa.host(
        ArchitectWorkspaceScreen(
          initialProject: c.project,
          commandController: c,
        ),
        'bg',
        GlobalKey(),
      ),
    );
    await tester.pumpAndSettle();
    workspace
        .camera(tester)
        .fit(const Rect.fromLTRB(-1, -2, 9, 4), padding: 40);
    await tester.pump();
    await tester.tapAt(workspace.screen(tester, const Offset(2, 0)));
    await tester.pumpAndSettle();
    final gap = ArchitectColumnClearance.forColumn(
      c.project,
      'a',
    ).singleWhere((g) => g.key.contains('neighbor:b:'));
    await tester.tap(find.byKey(ValueKey('wall-clearance-${gap.key}')));
    await tester.pumpAndSettle();
    final keypad = tester.widget<ArchitectWallDraftingPanel>(
      find.byType(ArchitectWallDraftingPanel),
    );
    keypad.onLength(1.5);
    keypad.onEnd();
    await tester.pumpAndSettle();
    expect(c.project.activeStorey.columns.first.position, const Offset(3, 0));
    c.undo();
    await tester.pumpAndSettle();
    expect(c.project.activeStorey.columns.first.position, const Offset(2, 0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Changing a level unit reformats its input without changing elevation',
    (tester) async {
      await qa.phone(tester);
      final p = project(
        const ArchitectStorey(
          id: 's',
          name: 's',
          elevationMarkers: [
            ArchitectElevationMarker(
              id: 'm',
              position: Offset.zero,
              elevation: 2.8,
            ),
          ],
        ),
      );
      ArchitectProject? saved;
      await tester.pumpWidget(
        qa.host(
          Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => ArchitectElementPropertiesDialog(
                    project: p,
                    elementIds: const {'m'},
                    onApply: (_, _) => false,
                    onApplyProject: (next) {
                      saved = next;
                      return true;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
          'en',
          GlobalKey(),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-property-levelUnits')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('cm').last);
      await tester.pumpAndSettle();
      final field = find
          .descendant(
            of: find.byType(ArchitectPropertyNumberField),
            matching: find.byType(TextFormField),
          )
          .last;
      final entry = tester.widget<TextFormField>(field);
      expect(entry.controller!.text, '280');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(saved!.activeStorey.elevationMarkers.single.elevation, 2.8);
      expect(
        saved!.activeStorey.elevationMarkers.single.units,
        ArchitectUnit.centimeters,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Text context menu offers editing, copying, rotation and properties',
    (tester) async {
      await qa.phone(tester);
      final c = ArchitectCommandController(
        project(const ArchitectStorey(id: 's', name: 's', annotations: [text])),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        qa.host(
          ArchitectWorkspaceScreen(
            initialProject: c.project,
            commandController: c,
          ),
          'en',
          GlobalKey(),
        ),
      );
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTRB(-1, -1, 5, 5), padding: 40);
      await tester.pump();
      final centre = ArchitectAnnotationLayout.outline(
        text,
        project: c.project,
      ).getBounds().center;
      final point = workspace.screen(tester, centre);
      final click = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await click.up();
      await tester.pumpAndSettle();
      final menu = tester.widget<ArchitectRadialMenu>(
        find.byType(ArchitectRadialMenu),
      );
      expect(
        menu.items.map((i) => i.action),
        containsAll([
          ArchitectRadialAction.edit,
          ArchitectRadialAction.duplicate,
          ArchitectRadialAction.rotate,
          ArchitectRadialAction.properties,
        ]),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Styled rotated text and independent levels remain real text in PDF',
    () async {
      final l = await AppLocalizations.delegate.load(const Locale('bg'));
      const drawing = ArchitectSavedDrawing(
        id: 'plan:s',
        sourceId: 's',
        kind: ArchitectDrawingKind.plan,
      );
      const sheet = ArchitectSheet(
        id: 'sheet',
        placements: [
          ArchitectDrawingPlacement(
            id: 'place',
            drawingId: 'plan:s',
            frame: Rect.fromLTWH(10, 10, 180, 220),
            anchor: Offset.zero,
            showTitle: false,
          ),
        ],
      );
      final p =
          project(
            const ArchitectStorey(
              id: 's',
              name: 's',
              annotations: [text],
              elevationMarkers: [
                ArchitectElevationMarker(
                  id: 'm',
                  position: Offset(1, 3),
                  elevation: 2.8,
                ),
              ],
            ),
          ).copyWith(
            units: ArchitectUnit.millimeters,
            document: const ArchitectDocument(
              drawings: [drawing],
              sheets: [sheet],
            ),
          );
      final scene = ArchitectDrawingPublisher.build(p, drawing, 100, l);
      final words = scene.operations.whereType<ArchitectVectorText>().where(
        (t) => t.sources.contains('text'),
      );
      expect(words.first.fontStyle, FontStyle.italic);
      expect(words.first.decoration, TextDecoration.underline);
      final bytes = await ArchitectPdfExport.export(p, [sheet], l);
      final document = pdf.PdfDocument(inputBytes: bytes);
      final extracted = pdf.PdfTextExtractor(document).extractText();
      expect(extracted, contains('Текст'));
      expect(extracted, contains('Text'));
      expect(extracted, contains('+2.80'));
      document.dispose();
    },
  );

  test('Render the drawing symbols for visual review', () async {
    if (!const bool.fromEnvironment('CAPTURE_DRAFTING_QA')) return;
    final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    canvas.translate(30, 40);
    canvas.scale(80);
    final p = project(
      ArchitectStorey(
        id: 's',
        name: 's',
        annotations: const [text],
        elevationMarkers: const [
          ArchitectElevationMarker(
            id: 'l',
            position: Offset(5, 1),
            elevation: 2.8,
          ),
          ArchitectElevationMarker(
            id: 'f',
            position: Offset(5, 2.5),
            elevation: 0,
            symbol: ArchitectLevelSymbol.elevation,
          ),
        ],
        floorDrains: const [
          ArchitectFloorDrain(
            id: 'd',
            polygon: [Offset(0, 4), Offset(4, 4), Offset(4, 8), Offset(0, 8)],
            position: Offset(2, 6),
          ),
        ],
      ),
    );
    expect(
      ArchitectDrainSurface.of(p.activeStorey.floorDrains.single).folds,
      isNotEmpty,
    );
    expect(
      ArchitectDrainSurface.of(
        p.activeStorey.floorDrains.single,
      ).drainsContinuously,
      isTrue,
    );
    ArchitectTextScope(p.document, 'plan:s', 100, 80).run(() {
      ArchitectElementsPainterHelper.drawAnnotations(
        canvas: canvas,
        storey: p.activeStorey,
        zoomScale: 80,
      );
      ArchitectElementsPainterHelper.drawElevationMarkers(
        canvas: canvas,
        storey: p.activeStorey,
        zoomScale: 80,
      );
      ArchitectFloorDrainPainterHelper.draw(
        canvas: canvas,
        storey: p.activeStorey,
        zoomScale: 80,
      );
    });
    final picture = recorder.endRecording(),
        image = await picture.toImage(800, 800);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/architect-drafting-qa/symbols.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
