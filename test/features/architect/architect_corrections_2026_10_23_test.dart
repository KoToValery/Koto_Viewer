import 'package:flutter/services.dart';
import 'architect_elevation_ui_test.dart' as qa;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_plan_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_section_painter.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_pitch_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_terrain_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_drafting_panel.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_hatch_pattern.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_pitch_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_section.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_hatch_picker.dart';
import 'package:kotoview/src/features/architect/widgets/architect_line_symbol_sketch.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_layout.dart';
import 'architect_elevation_test.dart' as elevations;
import 'architect_hatch_test.dart' as hatches;
import 'architect_stair_detail_test.dart' as stairs;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

Widget app(Widget child) => RepaintBoundary(
  key: const ValueKey('corrections-preview'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: 'TestReadable', useMaterial3: true),
    locale: const Locale('bg'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['UPDATE_ARCHITECT_CORRECTION_PREVIEW'] != 'true') {
    return;
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('corrections-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      'build/architect-correction-$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await qa.loadQaFonts();
    final roboto = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await roboto.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Beam designations fit within physical beam width at all drawing scales',
    () {
      for (final denominator in [50, 100, 500]) {
        const beam = ArchitectBeam(
          id: 'b',
          startPoint: Offset.zero,
          endPoint: Offset(4, 0),
          width: .2,
          label: 'B 20/40',
        );
        final canvas = ArchitectVectorCanvas();
        ArchitectTextScope(
          const ArchitectDocument(),
          'plan:s',
          denominator,
          40,
        ).run(() {
          ArchitectElementsPainterHelper.drawBeams(
            canvas: canvas,
            storey: const ArchitectStorey(id: 's', name: '', beams: [beam]),
            zoomScale: 40,
          );
        });
        final text = canvas.operations.whereType<ArchitectVectorText>().single;
        expect(text.size, lessThan(.2));
        expect(
          canvas.operations.whereType<ArchitectVectorPath>().where(
            (op) => op.fill,
          ),
          isEmpty,
        );
      }
    },
  );

  test(
    'Single-line selection traces the segment instead of a rectangular box',
    () {
      const line = ArchitectCadPrimitive(
        id: 'l',
        type: CadPrimitiveType.line,
        startPoint: Offset(1, 1),
        endPoint: Offset(4, 3),
      );
      final path = ArchitectSelection.outline(hatches.fixture([line]), 'l');
      final metric = path.computeMetrics().single;
      expect(metric.isClosed, isFalse);
      expect(metric.length, closeTo(math.sqrt(13), 1e-5));
    },
  );

  test(
    'Terrain clips faces, picking and aperture operations and survives Undo/JSON',
    () {
      final original = elevations.elevationProject();
      final view = elevations.facade.copyWith(
        terrain: const [Offset(-5, 1), Offset(5, 2)],
      );
      final model = ArchitectCommandController(
        original.copyWith(elevations: [elevations.facade]),
      );
      addTearDown(model.dispose);
      model.commit(model.project.copyWith(elevations: [view]));
      final geometry = ArchitectBuildingElevation.build(model.project, view);
      expect(geometry.terrain.length, 4);
      for (final p in geometry.faces) {
        expect(p.contains(const Offset(0, .5)), isFalse);
      }
      for (final p in geometry.elementPaths.values) {
        expect(p.contains(const Offset(0, .5)), isFalse);
      }
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(model.project.toJson())) as Map<String, dynamic>,
      );
      expect(restored.elevations.single.terrain, view.terrain);
      model.undo();
      expect(model.project.elevations.single.terrain, isEmpty);
      model.redo();
      expect(model.project.elevations.single.terrain, view.terrain);
      expect(
        () => ArchitectBuildingElevation.validateTerrain(const [
          Offset(1, 0),
          Offset(0, 1),
        ]),
        throwsArgumentError,
      );
      // Another elevation still displays its original underground geometry.
      expect(
        ArchitectBuildingElevation.build(original, elevations.facade).terrain,
        isEmpty,
      );
    },
  );

  test(
    'Roof pitch preserves the chosen exterior axis with real layer thickness',
    () {
      final roof = ArchitectRoofPlane(
        id: 'r',
        storeyId: 's',
        points: const [Offset(0, 0), Offset(4, 0), Offset(4, 5), Offset(0, 5)],
        slopeDegrees: 20,
      );
      final eave = (roof.eavesEdge.$1 + roof.eavesEdge.$2) / 2;
      for (final run in [0.0, 2.0, 4.0]) {
        final pivot = eave + roof.slopeDirection * run;
        final control = eave + roof.slopeDirection * (run < 3 ? 5 : 0);
        final target =
            roof.topElevationAt(pivot) +
            (roof.signedDistanceFromEaves(control) - run) *
                math.tan(math.pi / 6);
        final next = ArchitectRoofPitchEditing.rotate(
          roof,
          pivot: pivot,
          control: control,
          targetTopElevation: target,
        );
        expect(next.slopeDegrees, closeTo(30, 1e-8));
        expect(
          next.topElevationAt(pivot),
          closeTo(roof.topElevationAt(pivot), 1e-8),
        );
        expect(next.topElevationAt(control), closeTo(target, 1e-8));
        expect(next.points, roof.points);
        expect(next.attachToWalls, isFalse);
        expect(roof.slopeDegrees, 20);
      }
      expect(
        () => ArchitectRoofPitchEditing.rotate(
          roof,
          pivot: eave,
          control: eave,
          targetTopElevation: 3,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'Steel and timber stairs have separate treads/stringers for every shape',
    () {
      for (final material in [
        StairConstruction.steel,
        StairConstruction.timber,
      ]) {
        for (final shape in StairShape.values) {
          final design = stairs.design.copyWith(
            construction: material,
            shape: shape,
            startOffset: .3,
          );
          final stair = stairs.stair(design);
          final solids = ArchitectStairMesh.body(stair);
          expect(solids.length, greaterThan(4));
          expect(
            solids.every(
              (s) =>
                  s.material ==
                  (material == StairConstruction.steel
                      ? StairSolidMaterial.metal
                      : StairSolidMaterial.timber),
            ),
            isTrue,
          );
          for (final solid in solids) {
            expect(solid.triangles, isNotEmpty);
            for (final t in solid.triangles) {
              for (final v in [t.v0, t.v1, t.v2]) {
                expect(v.x.isFinite && v.y.isFinite && v.z.isFinite, isTrue);
              }
            }
          }
          final restored = ArchitectStairDesign.fromJson(design.toJson());
          expect(restored.construction, material);
          expect(restored.treadThickness, design.treadThickness);
          expect(restored.stringerDepth, design.stringerDepth);
          if (shape == StairShape.straight) {
            final cut = ArchitectStairSection.build(
              solids,
              const Offset(0, 0),
              const Offset(1, 0),
            );
            expect(
              cut.regions.containsKey(StairSolidMaterial.concrete),
              isFalse,
            );
          }
        }
      }
      final old = stairs.design.toJson()..remove('construction');
      expect(
        ArchitectStairDesign.fromJson(old).construction,
        StairConstruction.concrete,
      );
    },
  );

  test('Fixed circle stays centered around the clicked point', () {
    const anchor = Offset(500, 400);
    final layout = ArchitectRadialLayout.compute(
      size: const Size(1000, 800),
      center: anchor,
    );
    final radii = layout.targets
        .map((p) => (p - anchor).distance.round())
        .toSet();
    expect(radii, {84});
  });

  testWidgets(
    'Line weight is a graphic value even when project units are centimetres',
    (tester) async {
      final p = hatches.fixture([
        const ArchitectCadPrimitive(
          id: 'l',
          type: CadPrimitiveType.line,
          startPoint: Offset.zero,
          endPoint: Offset(3, 2),
        ),
      ]);
      await tester.pumpWidget(
        app(
          ArchitectElementPropertiesDialog(
            project: p,
            elementIds: const {'l'},
            onApply: (_, _) => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(
        const ValueKey('architect-property-strokeWidth'),
      );
      await tester.ensureVisible(field);
      expect(
        find.descendant(of: field, matching: find.text('0.125 mm')),
        findsOneWidget,
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      final panel = tester.widget<ArchitectWallDraftingPanel>(
        find.byType(ArchitectWallDraftingPanel).last,
      );
      expect(panel.unit, 'mm');
      expect(panel.length, .125);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Green contour control closes a hatch without touching its first point',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.texture_rounded);
      await tester.pump();
      for (final point in [
        const Offset(0, 0),
        const Offset(3, 0),
        const Offset(3, 3),
      ]) {
        await workspace.wallTap(tester, point);
      }
      final finish = find.byKey(const ValueKey('architect-draft-confirm'));
      expect(finish, findsOneWidget);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.single.type,
        CadPrimitiveType.hatch,
      );
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.cadPrimitives, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Pattern generator builds a reusable hatch from line-drawn motif',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(
          const ArchitectHatchGenerator(
            initial: ArchitectHatchPattern.diagonal,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('hatch-generator-name')),
        'Motif',
      );
      await tester.tap(find.byKey(const ValueKey('hatch-generator-draw')));
      await tester.pumpAndSettle();
      final sketch = find.byKey(const ValueKey('line-symbol-canvas'));
      await tester.ensureVisible(sketch);
      final center = tester.getCenter(sketch);
      for (final p in [
        const Offset(-35, 0),
        const Offset(0, -30),
        const Offset(35, 0),
      ]) {
        await tester.tapAt(center + p);
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('line-symbol-shape-save')));
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectLineSymbolSketch), findsNothing);
      final sample = tester.widget<ArchitectHatchSample>(
        find.byType(ArchitectHatchSample),
      );
      sample.pattern.validate();
      expect(sample.pattern.layers.single.symbolsOnly, isTrue);
      expect(
        sample.pattern.layers.single.lineStyle.symbol!.strokes.single,
        hasLength(3),
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'hatch-generator');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Roof pitch drag previews the slope before one confirmed edit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final roof = ArchitectRoofPlane(
      id: 'r',
      storeyId: 's',
      points: const [Offset(0, 0), Offset(4, 0), Offset(4, 5), Offset(0, 5)],
      slopeDegrees: 20,
    );
    ArchitectRoofPlane? saved;
    Offset screen(Offset p) => Offset(40 + p.dx * 45, 600 - p.dy * 45);
    Offset view(Offset p) => Offset((p.dx - 40) / 45, (600 - p.dy) / 45);
    await tester.pumpWidget(
      app(
        ArchitectRoofPitchEditor(
          roof: roof,
          elevation: 0,
          origin: Offset.zero,
          right: const Offset(0, 1),
          toView: view,
          toScreen: screen,
          onApply: (r) => saved = r,
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final handle = screen(Offset(5, roof.topElevationAt(const Offset(4, 5))));
    final gesture = await tester.startGesture(handle);
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(roof.slopeDegrees, 20);
    await capture(tester, 'roof-pitch');
    await tester.tap(find.byKey(const ValueKey('roof-pitch-confirm')));
    await tester.pump();
    expect(saved!.slopeDegrees, greaterThan(20));
    expect(
      saved!.topElevationAt(const Offset(2, 0)),
      closeTo(roof.topElevationAt(const Offset(2, 0)), 1e-8),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Terrain draft edits points and saves only on confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<Offset>? saved;
    await tester.pumpWidget(
      app(
        ArchitectTerrainEditor(
          initial: const [],
          toView: (p) => Offset((p.dx - 180) / 30, (600 - p.dy) / 30),
          toScreen: (p) => Offset(180 + p.dx * 30, 600 - p.dy * 30),
          onApply: (p) => saved = p,
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(60, 600));
    await tester.pump();
    await tester.tapAt(const Offset(300, 540));
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(60, 600));
    await gesture.moveBy(const Offset(0, -25));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -5));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await capture(tester, 'terrain-editor');
    await tester.tap(find.byKey(const ValueKey('terrain-confirm')));
    await tester.pump();
    expect(saved, hasLength(2));
    expect(saved!.first.dy, closeTo(1, 1e-5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Construction materials produce transparent plan and cut drawings',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final l = await AppLocalizations.delegate.load(const Locale('bg'));
      await tester.pumpWidget(
        app(CustomPaint(size: const Size(1000, 700), painter: _StairBoard(l))),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'stair-constructions');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _StairBoard extends CustomPainter {
  final AppLocalizations l;
  _StairBoard(this.l);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final labels = [
      l.architectMaterialConcrete,
      l.stairSteel,
      l.architectMaterialTimber,
    ];
    for (var i = 0; i < StairConstruction.values.length; i++) {
      final stair = stairs.stair(
        stairs.design.copyWith(construction: StairConstruction.values[i]),
      );
      final text = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            fontFamily: 'TestReadable',
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(40 + i * 325, 30));
      canvas.save();
      canvas.translate(40 + i * 325, 170);
      canvas.scale(80);
      ArchitectStairPlanPainter.draw(
        canvas: canvas,
        stair: stair,
        scale: 80,
        color: Colors.black,
        l10n: l,
      );
      canvas.restore();
      final cut = ArchitectStairSection.build(
        ArchitectStairMesh.body(stair),
        const Offset(0, 0),
        const Offset(1, 0),
      );
      expect(cut.isEmpty, isFalse);
      canvas.save();
      canvas.translate(20 + i * 325, 330);
      ArchitectStairSectionPainter(
        cut,
        cutHeight: .8,
      ).paint(canvas, const Size(300, 300));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StairBoard old) => false;
}
