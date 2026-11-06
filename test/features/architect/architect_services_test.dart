import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';
import 'package:kotoview/src/features/architect/components/definitions/service_components.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_service_plan_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_junctions.dart';
import 'package:kotoview/src/features/architect/services/architect_service_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_slab_geometry.dart';
import 'package:kotoview/src/features/architect/services/component_library_service.dart';
import 'package:kotoview/src/features/architect/widgets/architect_component_library_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_component_labels.dart';
import 'package:kotoview/src/features/architect/widgets/component_dimensions_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/component_preview_painters.dart';
import 'architect_workspace_interaction_test.dart' as workspace;

List<Offset> box(double x, double y, double w, double h) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x + w, y + h),
  Offset(x, y + h),
];

ArchitectComponentInstance placed(
  ServiceComponentKind kind, {
  Offset position = const Offset(2, 2),
  Map<String, dynamic> parameters = const {},
}) {
  final definition = ServiceComponentDefinition(kind);
  return ArchitectComponentInstance(
    id: 'service',
    definitionId: definition.id,
    position: position,
    parameters: {...definition.defaultParameters, ...parameters},
  );
}

ArchitectProject projectOf(List<ArchitectStorey> floors) => ArchitectProject(
  id: 'test',
  name: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  storeys: floors,
  activeStoreyId: floors.first.id,
);

class OpeningCanvas implements Canvas {
  int paragraphs = 0, lines = 0;
  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => paragraphs++;
  @override
  void drawLine(Offset a, Offset b, Paint p) => lines++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    await (FontLoader(
      'ArchitectNoto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'Opening symbols have no text even for legacy labels at publication zoom',
    () {
      final canvas = OpeningCanvas();
      ArchitectElementsPainterHelper.drawOpenings(
        canvas: canvas,
        zoomScale: 200,
        storey: ArchitectStorey(
          id: 's',
          name: '',
          openings: [
            ArchitectOpening(
              id: 'o',
              boundary: box(0, 0, .5, .5),
              label: 'Shaft 1',
            ),
          ],
        ),
      );
      expect(canvas.paragraphs, 0);
      expect(canvas.lines, 2);
    },
  );

  test(
    'Small round openings remain circular and persist without a default label',
    () {
      final tool = ArchitectElementTool()..setOpeningType(OpeningType.circular);
      const floor = ArchitectStorey(id: 's', name: '');
      final opening = tool
          .placeOpening(
            storey: floor,
            p1: Offset.zero,
            p2: const Offset(.11, .2),
          )!
          .$2;
      expect(opening.boundary.length, 48);
      expect(opening.label, isEmpty);
      for (final point in opening.boundary) {
        expect((point - opening.centroid).distance, closeTo(.055, 1e-7));
      }
      expect(
        ArchitectOpening.fromJson(opening.toJson()).type,
        OpeningType.circular,
      );
    },
  );

  for (final kind in ServiceComponentKind.values) {
    test(
      '${kind.name} builds finite hollow geometry with a true footprint',
      () {
        final definition = ServiceComponentDefinition(kind);
        final geometry = definition.resolveGeometry(
          definition.defaultParameters,
        );
        expect(geometry.mesh3d.triangles, isNotEmpty);
        for (final face in geometry.mesh3d.triangles) {
          for (final v in [face.v0, face.v1, face.v2]) {
            expect(v.x.isFinite && v.y.isFinite && v.z.isFinite, isTrue);
          }
        }
        final slice = ArchitectMeshSection.slice(
          geometry.mesh3d.triangles,
          Vector3(0, 0, kind == ServiceComponentKind.fireplace ? 1 : .1),
          const Vector3(0, 0, 1),
          (p) => Offset(p.x, p.y),
        );
        final d = definition.nominalSize.$2;
        final bore = switch (kind) {
          ServiceComponentKind.ventDouble ||
          ServiceComponentKind.ventTransition => Offset(
            -definition.nominalSize.$1 / 4,
            d / 2,
          ),
          ServiceComponentKind.compactVent ||
          ServiceComponentKind.compactTransition => Offset(-.06, d / 2),
          _ => Offset(0, d / 2),
        };
        expect(
          slice.contains(bore),
          isFalse,
          reason: 'The bore must remain open',
        );
      },
    );
  }

  test(
    'Chimney follows an upper storey roof and all cap variants keep the flue open',
    () {
      final c = placed(ServiceComponentKind.chimney);
      final roof = ArchitectRoofPlane(
        id: 'r',
        storeyId: 'upper',
        points: box(0, 0, 6, 6),
        slopeDegrees: 28,
        baseElevationOffset: 0,
        eavesOverhang: 0,
      );
      final ground = ArchitectStorey(id: 's', name: '', components: [c]);
      final upper = ArchitectStorey(
        id: 'upper',
        name: '',
        elevation: 5.6,
        roofs: [roof],
      );
      final project = projectOf([ground, upper]);
      final params = ArchitectServiceGeometry.parameters(project, ground, c);
      final highest = c.worldPolygonCorners
          .map((p) => 5.6 + roof.topElevationAt(p))
          .reduce(math.max);
      expect(params['height'], closeTo(highest + .8, 1e-5));
      final footprint = ArchitectRoofJunctions.of(
        upper,
        project: project,
      ).footprint(roof);
      expect(footprint.contains(c.worldBoundingRect.center), isFalse);
      expect(footprint.contains(const Offset(1, 1)), isTrue);
      final definition = ServiceComponentDefinition(
        ServiceComponentKind.chimney,
      );
      final tops = <double>{};
      for (var cap = 0; cap < 4; cap++) {
        final geo = definition.resolveGeometry({...params, 'capType': cap});
        tops.add(geo.mesh3d.bounds.max.z);
        final slice = ArchitectMeshSection.slice(
          geo.mesh3d.triangles,
          const Vector3(0, 0, 1),
          const Vector3(0, 0, 1),
          (p) => Offset(p.x, p.y),
        );
        expect(slice.contains(const Offset(0, .18)), isFalse);
        expect(slice.contains(const Offset(.17, .18)), isTrue);
      }
      expect(tops.length, 4);
      final sources = <Triangle3D, String>{};
      final mesh = Architect3dBuilder.buildProjectMesh(
        project,
        previewGeometry: false,
        sources: sources,
      );
      expect(mesh.triangles.where((t) => sources[t] == c.id), isNotEmpty);
      expect(ArchitectServiceGeometry.flashing(project, ground, c), isNotEmpty);
      final section = ArchitectBuildingSection.build(
        project,
        ArchitectSection(
          id: 'section',
          start: const Offset(0, 2.18),
          end: const Offset(6, 2.18),
        ),
        includeProjection: false,
      );
      final regions = section.regions.where((r) => r.sourceId == c.id).toList();
      expect(regions, isNotEmpty);
      expect(regions.any((r) => r.path.contains(const Offset(2, 1))), isFalse);
      expect(
        regions.any((r) => r.path.contains(const Offset(2.17, 1))),
        isTrue,
        reason: regions.map((r) => r.path.getBounds()).join(', '),
      );
    },
  );

  test(
    'Slab and section holes follow service height, move and delete across storeys',
    () {
      final c = placed(
        ServiceComponentKind.sewer,
        parameters: {'height': 3.0, 'autoHeight': false},
      );
      final slab = ArchitectSlab(id: 'slab', polygon: box(0, 0, 6, 6));
      final ground = ArchitectStorey(id: 's', name: '', components: [c]);
      final floor = ArchitectStorey(
        id: 'upper',
        name: '',
        elevation: 2.8,
        slabs: [slab],
      );
      final project = projectOf([ground, floor]);
      final center = c.worldBoundingRect.center;
      expect(
        ArchitectSlabGeometry.contains(floor, slab, center, project: project),
        isFalse,
      );
      final cut = ArchitectSection(
        id: 'cut',
        name: '',
        start: Offset(0, center.dy),
        end: Offset(6, center.dy),
      );
      expect(
        ArchitectSlabGeometry.intervals(
          floor,
          slab,
          cut,
          project: project,
        ).length,
        2,
      );
      final moved = project.copyWith(
        storeys: [
          ground.copyWith(
            components: [c.copyWith(position: const Offset(4, 4))],
          ),
          floor,
        ],
      );
      expect(
        ArchitectSlabGeometry.contains(floor, slab, center, project: moved),
        isTrue,
      );
      final removed = project.copyWith(
        storeys: [
          ground.copyWith(components: []),
          floor,
        ],
      );
      expect(
        ArchitectSlabGeometry.contains(floor, slab, center, project: removed),
        isTrue,
      );
      final above = floor.copyWith(elevation: 5.6);
      expect(
        ArchitectSlabGeometry.contains(
          above,
          slab,
          center,
          project: projectOf([ground, above]),
        ),
        isTrue,
      );
    },
  );

  test('Services have one tool home independent of furniture visibility', () {
    expect(
      ArchitectToolCategory.of(ArchitectTool.opening),
      ArchitectToolCategory.services,
    );
    expect(
      ArchitectToolCategory.of(ArchitectTool.services),
      ArchitectToolCategory.services,
    );
    expect(
      ComponentLibraryService.instance
          .getByCategory(ArchitectComponentCategory.services)
          .length,
      ServiceComponentKind.values.length,
    );
  });

  testWidgets('Services place through the workspace and participate in Undo', (
    tester,
  ) async {
    final commands = workspace.commands();
    addTearDown(commands.dispose);
    await workspace.open(tester, commands);
    tester
        .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
        .onToolChanged(ArchitectTool.services);
    await tester.pumpAndSettle();
    final definition = ServiceComponentDefinition(
      ServiceComponentKind.combinedRiser,
    );
    ComponentLibraryService.instance.setActiveDefinition(definition);
    await tester.pumpAndSettle();
    await workspace.wallTap(tester, const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(
      commands.project.activeStorey.components.single.definitionId,
      definition.id,
    );
    expect(commands.undoCount, 1);
    commands.undo();
    await tester.pumpAndSettle();
    expect(commands.project.activeStorey.components, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['bg', 'en']) {
    testWidgets('$locale service library and cap controls fit a 320px phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final definition = ServiceComponentDefinition(
        ServiceComponentKind.chimney,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'ArchitectNoto'),
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => ArchitectComponentLibraryDialog.show(
                    context,
                    initialCategory: ArchitectComponentCategory.services,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text(locale == 'bg' ? 'Единично вент. тяло' : 'Single vent block'),
        findsOneWidget,
      );
      Navigator.of(
        tester.element(find.byType(ArchitectComponentLibraryDialog)),
      ).pop();
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Open'));
      ComponentDimensionsDialog.show(
        context,
        definition,
        definition.defaultParameters,
      );
      await tester.pumpAndSettle();
      final cap = find.byKey(const ValueKey('service-chimney-cap'));
      await tester.ensureVisible(cap);
      await tester.tap(cap);
      await tester.pumpAndSettle();
      await tester.tap(find.text(locale == 'bg' ? 'Конусна' : 'Conical').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (Platform.environment['SERVICE_REVIEW_IMAGES'] == '1') {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/services_review').createSync(recursive: true);
          File(
            'build/services_review/controls_$locale.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets('Service plan and cap review sheet', (tester) async {
    if (Platform.environment['SERVICE_REVIEW_IMAGES'] != '1') return;
    tester.view.physicalSize = const Size(1200, 1020);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final definitions = ServiceComponentDefinition.catalog();
    final chimney = ServiceComponentDefinition(ServiceComponentKind.chimney);
    final l = await AppLocalizations.delegate.load(const Locale('bg'));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'ArchitectNoto'),
          home: Scaffold(
            backgroundColor: Colors.white,
            body: GridView.count(
              crossAxisCount: 5,
              children: [
                for (final d in definitions)
                  Column(
                    children: [
                      Text(componentLabel(l, d)),
                      Expanded(
                        child: CustomPaint(
                          size: const Size(230, 180),
                          painter: ComponentPlanPreviewPainter(
                            d.resolveGeometry(d.defaultParameters).block2d,
                            d.nominalSize.$1,
                            d.nominalSize.$2,
                          ),
                        ),
                      ),
                    ],
                  ),
                for (var cap = 0; cap < 4; cap++)
                  Column(
                    children: [
                      Text(
                        [
                          l.architectServiceCapNone,
                          l.architectServiceCapFlat,
                          l.architectServiceCapPitched,
                          l.architectServiceCapConical,
                        ][cap],
                      ),
                      Expanded(
                        child: CustomPaint(
                          size: const Size(230, 180),
                          painter: ComponentMeshPreviewPainter(
                            chimney.resolveGeometry({
                              ...chimney.defaultParameters,
                              'height': .7,
                              'capType': cap,
                            }).mesh3d,
                            .65,
                            .65,
                          ),
                        ),
                      ),
                    ],
                  ),
                Column(
                  children: [
                    Text(l.architectServiceFireplace),
                    Expanded(
                      child: CustomPaint(
                        size: const Size(230, 180),
                        painter: ComponentMeshPreviewPainter(
                          ServiceComponentDefinition(
                            ServiceComponentKind.fireplace,
                          ).resolveGeometry({}).mesh3d,
                          .55,
                          .65 + math.pi,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/services_review').createSync(recursive: true);
      File(
        'build/services_review/catalog.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('Continuous services plans, roof and fireplace review', (
    tester,
  ) async {
    if (Platform.environment['SERVICE_REVIEW_IMAGES'] != '1') return;
    tester.view.physicalSize = const Size(1200, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final components = [
      placed(
        ServiceComponentKind.ventDouble,
        position: const Offset(1.2, 1.2),
      ).copyWith(id: 'duct'),
      placed(
        ServiceComponentKind.sewer,
        position: const Offset(3, 1.2),
      ).copyWith(id: 'sewer'),
      placed(
        ServiceComponentKind.chimney,
        position: const Offset(1.2, 3),
      ).copyWith(id: 'chimney'),
      placed(
        ServiceComponentKind.fireplace,
        position: const Offset(3, 3),
      ).copyWith(id: 'fireplace'),
    ];
    final roof = ArchitectRoofPlane(
      id: 'roof',
      storeyId: 'roof',
      points: box(0, 0, 5, 5),
      slopeDegrees: 18,
      baseElevationOffset: 0,
      eavesOverhang: 0,
    );
    final project = projectOf([
      ArchitectStorey(id: 'ground', name: '', components: components),
      const ArchitectStorey(id: 'upper', name: '', elevation: 2.8),
      ArchitectStorey(
        id: 'roof',
        name: '',
        elevation: 5.6,
        isRoof: true,
        roofs: [roof],
      ),
    ]);
    final section = ArchitectBuildingSection.build(
      project,
      const ArchitectSection(
        id: 'review',
        start: Offset(0, 3.18),
        end: Offset(5, 3.18),
      ),
      includeProjection: false,
    );
    final l = await AppLocalizations.delegate.load(const Locale('bg'));
    final fireplace = ServiceComponentDefinition(
      ServiceComponentKind.fireplace,
    );
    final key = GlobalKey();
    Widget tile(String title, CustomPainter painter) => Column(
      children: [
        Padding(padding: const EdgeInsets.all(12), child: Text(title)),
        Expanded(
          child: CustomPaint(size: const Size(380, 350), painter: painter),
        ),
      ],
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'ArchitectNoto'),
          home: Scaffold(
            backgroundColor: Colors.white,
            body: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 400 / 410,
              children: [
                tile(
                  l.architectStoreyGround,
                  _ServiceReviewPlan(project, project.storeys[0]),
                ),
                tile(
                  l.architectStoreyFloor,
                  _ServiceReviewPlan(project, project.storeys[1]),
                ),
                tile(
                  l.architectToolRoof,
                  _ServiceReviewPlan(project, project.storeys[2]),
                ),
                tile(l.architectToolSection, _ServiceReviewSection(section)),
                tile(
                  l.architectServiceFireplace,
                  ComponentMeshPreviewPainter(
                    fireplace.resolveGeometry({}).mesh3d,
                    .55,
                    .65 + math.pi,
                  ),
                ),
                tile(
                  '3D',
                  ComponentMeshPreviewPainter(
                    Architect3dBuilder.buildProjectMesh(
                      project,
                      previewGeometry: false,
                    ),
                    .6,
                    .65,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/services_review').createSync(recursive: true);
      File(
        'build/services_review/continuity.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}

class _ServiceReviewPlan extends CustomPainter {
  final ArchitectProject project;
  final ArchitectStorey floor;
  _ServiceReviewPlan(this.project, this.floor);
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 3.4;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-2.1, -2.25);
    if (floor.isRoof) {
      ArchitectTextScope(project.document, 'plan:${floor.id}', 100, scale).run(
        () => ArchitectRoofPainterHelper.paintRoofs(
          canvas: canvas,
          storey: floor,
          project: project,
          scale: scale,
          selectedIds: {},
        ),
      );
      ArchitectServicePlanPainter.roofOpenings(
        canvas: canvas,
        storey: floor,
        project: project,
        scale: scale,
        palette: const ArchitectCanvasPalette.light(),
      );
    }
    ArchitectElementsPainterHelper.drawComponents(
      canvas: canvas,
      storey: floor,
      project: project,
      zoomScale: scale,
      layerVisible: false,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ServiceReviewSection extends CustomPainter {
  final ArchitectBuildingSection section;
  _ServiceReviewSection(this.section);
  @override
  void paint(Canvas canvas, Size size) {
    final b = section.bounds;
    final scale = math.min(
      size.width / (b.width + .4),
      size.height / (b.height + .6),
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, -scale);
    canvas.translate(-b.center.dx, -b.center.dy);
    for (final r in section.regions) {
      canvas.drawPath(r.path, Paint()..color = const Color(0xfff5f5f5));
      canvas.drawPath(
        r.path,
        Paint()
          ..color = const Color(0xff333333)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8 / scale,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
