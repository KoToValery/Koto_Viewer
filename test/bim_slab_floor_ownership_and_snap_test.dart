import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/widgets/storey_manager_sheet.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_vertex_snap.dart';
import 'package:kotoview/src/features/structural_designer/analysis/drawing_frame_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_underlay_filter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_3d_mesh_builder.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'features/bim_projects/bim_underlay_conversion_test.dart' show drawing;

const ring = [Offset(0, 0), Offset(4, 0), Offset(4, 4), Offset(0, 4)];
StructuralProject floors() => StructuralProject(
  storeys: [
    const StoreyLevel(
      id: 'roof',
      name: 'Roof',
      elevation: 5.60,
      slabs: [StructuralSlab(id: 'r', polygon: ring, isFloorSlab: true)],
    ),
    const StoreyLevel(id: 'ground', name: 'Ground'),
    StoreyLevel(
      id: 'first',
      name: 'First',
      elevation: 2.85,
      slabs: [
        const StructuralSlab(id: 'a', polygon: ring, isFloorSlab: true),
        StructuralSlab(
          id: 'b',
          isFloorSlab: true,
          thickness: .3,
          polygon: ring.map((p) => p + const Offset(5, 0)).toList(),
          openings: const [
            [Offset(6, 1), Offset(7, 1), Offset(7, 2), Offset(6, 2)],
          ],
          openingTypes: const [SlabOpeningType.staircase],
        ),
      ],
    ),
  ],
  activeStoreyIndex: 2,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all manually owned floors display below, retain their editor owner and openings after JSON',
    () {
      final p = StructuralProject.fromJson(
        jsonDecode(jsonEncode(floors().toJson())),
      );
      final original = jsonEncode(p.toJson());
      final below = p.ceilingSlabStoreyFor(p.storeys[1])!;
      expect(below.id, 'first');
      expect(below.slabs.map((s) => s.id), ['a', 'b']);
      expect(
        below.structuralElevationFor(below.slabs.first),
        closeTo(2.80, 1e-9),
      );
      expect(below.slabs.last.getOpeningType(0), SlabOpeningType.staircase);
      expect(p.ceilingSlabStoreyFor(p.activeStorey)!.id, 'roof');
      expect(p.ceilingSlabStoreyFor(p.storeys.first), isNull);
      final plans = p.ceilingStoreys;
      expect(plans[1].slabs.map((s) => s.id), ['a', 'b']);
      expect(plans[2].slabs.single.id, 'r');
      expect(plans[0].slabs, isEmpty);
      expect(p.storeyPlanFor(p.storeys[1]).slabs.length, 2);
      expect(p.activeStorey.slabs.map((s) => s.id), ['a', 'b']);
      expect(jsonEncode(p.toJson()), original);
    },
  );
  test(
    'floor level follows owner, explicit concrete level survives, never skips empty adjacent level',
    () {
      final p = floors();
      final s = p.activeStorey;
      expect(
        s.structuralElevationFor(s.slabs.first.copyWith(topElevation: 3.10)),
        3.10,
      );
      final moved = s.copyWith(elevation: 3.20);
      expect(moved.structuralElevationFor(s.slabs.first), closeTo(3.15, 1e-9));
      final withEmpty = p.copyWith(
        storeys: [
          ...p.storeys,
          const StoreyLevel(id: 'empty', name: 'Empty', elevation: 1.5),
        ],
      );
      expect(withEmpty.ceilingSlabStoreyFor(p.storeys[1]), isNull);
      final cleared = p.copyWith(
        storeys: [
          for (final level in p.storeys)
            level.id == 'first' ? level.copyWith(slabs: []) : level,
        ],
      );
      expect(cleared.ceilingSlabStoreyFor(p.storeys[1]), isNull);
    },
  );
  test('3D emits a floor slab once at its actual owner elevation', () {
    final p = floors().copyWith(
      storeys: [
        const StoreyLevel(id: 'g', name: 'G', elevation: -1),
        const StoreyLevel(
          id: 'f',
          name: 'F',
          elevation: 2.85,
          slabs: [StructuralSlab(id: 'a', polygon: ring, isFloorSlab: true)],
        ),
      ],
    );
    final mesh = Structural3dMeshBuilder.buildProjectMesh(
      p,
      highlightStoreyIndex: 0,
    );
    expect(mesh.groups!.first.triangles, isEmpty);
    final caps = mesh.triangles.where(
      (t) => [t.v0.z, t.v1.z, t.v2.z].every((z) => (z - 2.8).abs() < 1e-6),
    );
    expect(caps, isNotEmpty);
    expect(caps.every((t) => t.color!.a == 1), isTrue);
    expect(
      mesh.triangles.expand((t) => [t.v0.z, t.v1.z, t.v2.z]).reduce(math.max),
      closeTo(2.8, 1e-6),
    );
  });
  for (final units in [1.0, 100.0, 1000.0]) {
    for (final mouse in [true, false]) {
      test(
        'snap and merge are bounded at distant zoom in $units units, mouse=$mouse',
        () {
          final tolerance = SlabVertexSnap.tolerance(
            .5 / units,
            units,
            isMouse: mouse,
            merge: true,
          );
          expect(tolerance / units, lessThanOrEqualTo(.05));
          final poly = ring.map((p) => p * units).toList();
          expect(
            SlabVertexSnap.mergeCandidate(
              Offset(2.5, 0) * units,
              poly,
              0,
              tolerance,
            ),
            isNull,
          );
          expect(
            SlabVertexSnap.mergeCandidate(
              Offset(3.97, 0) * units,
              poly,
              0,
              tolerance,
            ),
            1,
          );
          final closeZoom = SlabVertexSnap.tolerance(
            1000 / units,
            units,
            isMouse: mouse,
            merge: true,
          );
          expect(
            SlabVertexSnap.mergeCandidate(
              Offset(3.97, 0) * units,
              poly,
              0,
              closeZoom,
            ),
            isNull,
          );
        },
      );
    }
  }
  test(
    'perpendicular foot and preceding-point guide on a rotated slab edge',
    () {
      final result = SlabVertexSnap.align(
        raw: const Offset(2.04, 2.02),
        previous: const Offset(4, 0),
        edges: [(const Offset(0, 0), const Offset(4, 4))],
        tolerance: .1,
      );
      expect(result.snap!.point, const Offset(2, 2));
      expect(result.guides, [
        (const Offset(0, 0), const Offset(4, 4)),
        (const Offset(4, 0), const Offset(2, 2)),
      ]);
      final far = SlabVertexSnap.align(
        raw: const Offset(3, 2),
        previous: const Offset(4, 0),
        edges: [(const Offset(0, 0), const Offset(4, 4))],
        tolerance: .1,
      );
      expect(far.snap, isNull);
    },
  );
  test(
    'previous point tracking preserves right angles with rotated incoming edges',
    () {
      final result = SlabVertexSnap.align(
        raw: const Offset(2.03, 1.98),
        previous: const Offset(4, 0),
        incomingDirection: const Offset(1, 1),
        edges: [],
        tolerance: .1,
      );
      expect(result.snap!.point.dx, closeTo(2.025, 1e-9));
      expect(result.snap!.point.dy, closeTo(1.975, 1e-9));
      expect(result.guides.single.$1, const Offset(4, 0));
    },
  );
  for (final useLines in [false, true]) {
    test(
      'anonymous drawing border excluded before walls/slabs, lines=$useLines',
      () {
        final doc = DxfParser.parseString(drawing());
        final vertices = [
          const Offset(-2000, -2000),
          const Offset(12000, -2000),
          const Offset(12000, 10000),
          const Offset(-2000, 10000),
        ];
        final border = useLines
            ? <DxfEntity>[
                for (var i = 0; i < 4; i++)
                  DxfLine(
                    p1: vertices[i],
                    p2: vertices[(i + 1) % 4],
                    layer: '0',
                  ),
              ]
            : <DxfEntity>[
                DxfLwPolyline(
                  layer: '0',
                  isClosed: true,
                  vertices: vertices
                      .map((p) => DxfPolylineVertex(x: p.dx, y: p.dy))
                      .toList(),
                ),
              ];
        doc.entities.addAll(border);
        doc.layers['0'] = DxfLayer(name: '0');
        expect(DrawingFrameDetector.documentFrames(doc), containsAll(border));
        expect(
          StructuralUnderlayFilter.detectSlabLayers(doc).detectedLayers,
          isNot(contains('0')),
        );
        final filtered = DrawingFrameDetector.withoutFrames(doc);
        expect(filtered.entities.any(border.contains), isFalse);
        final detected = WallAxisDetector.detect(doc, forceScaleFactor: 1);
        expect(detected.selectedWallPairs, isNotEmpty);
        expect(
          SlabEnvelopeDetector.detect(detected, document: filtered).contours,
          isNotEmpty,
        );
        expect(doc.entities.any(border.contains), isTrue);
      },
    );
  }
  test(
    'rotated rectangle frame on the same layer as walls is excluded without deleting the building',
    () {
      Offset tr(Offset p) => Offset(
        p.dx * math.cos(.6) - p.dy * math.sin(.6) + 400000,
        p.dx * math.sin(.6) + p.dy * math.cos(.6) + 600000,
      );
      final original = DxfParser.parseString(drawing());
      final entities = original.entities
          .whereType<DxfLine>()
          .map((e) => DxfLine(p1: tr(e.p1), p2: tr(e.p2), layer: '0'))
          .toList();
      final corners = [
        const Offset(-2000, -2000),
        const Offset(12000, -2000),
        const Offset(12000, 10000),
        const Offset(-2000, 10000),
      ].map(tr).toList();
      final border = DxfLwPolyline(
        layer: '0',
        isClosed: true,
        vertices: corners
            .map((p) => DxfPolylineVertex(x: p.dx, y: p.dy))
            .toList(),
      );
      final doc = DxfDocument(
        entities: [...entities, border],
        layers: {'0': DxfLayer(name: '0')},
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 1000000, 1000000),
        entityStats: {},
      );
      expect(DrawingFrameDetector.documentFrames(doc), {border});
      expect(
        DrawingFrameDetector.withoutFrames(doc).entities,
        hasLength(entities.length),
      );
    },
  );
  test('real rectangular building outline is retained', () {
    final doc = DxfParser.parseString(drawing());
    final slab = DxfLwPolyline(
      layer: 'real',
      isClosed: true,
      vertices: const [
        DxfPolylineVertex(x: 0, y: 0),
        DxfPolylineVertex(x: 10000, y: 0),
        DxfPolylineVertex(x: 10000, y: 8000),
        DxfPolylineVertex(x: 0, y: 8000),
      ],
    );
    doc.entities.add(slab);
    doc.layers['real'] = DxfLayer(name: 'real');
    expect(DrawingFrameDetector.documentFrames(doc), isNot(contains(slab)));
    expect(
      StructuralUnderlayFilter.detectSlabLayers(doc).detectedLayers,
      contains('real'),
    );
  });
  test(
    'conversion retains original frame and produces actual slab envelope without BIM frame copy',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'bim_frame_regression_',
      );
      addTearDown(() => temp.delete(recursive: true));
      const border =
          '0\nLWPOLYLINE\n8\n0\n90\n4\n70\n1\n10\n-2000\n20\n-2000\n10\n12000\n20\n-2000\n10\n12000\n20\n10000\n10\n-2000\n20\n10000\n';
      final source = await File('${temp.path}/frame.dxf').writeAsString(
        drawing().replaceFirst(
          '0\nENDSEC\n0\nEOF',
          '${border}0\nENDSEC\n0\nEOF',
        ),
      );
      final converted = await BimUnderlayConversionService.convert(source);
      addTearDown(converted.dispose);
      final baked = await KcadService.loadKcadFile(converted.kcadFile);
      expect(
        BimUnderlayMetadata.read(baked)!['slabEnvelope']['contours'],
        isNotEmpty,
      );
      expect(
        baked.entities.whereType<DxfLwPolyline>().where((e) => e.layer == '0'),
        hasLength(1),
      );
      expect(
        baked.entities.whereType<DxfLwPolyline>().where(
          (e) => e.layer == 'BIM_Slabs',
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'draw on upper plan, show below and edit on its original owner level',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = DxfDocument(
        entities: [],
        layers: {},
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
        entityStats: {},
      );
      var saved = const StructuralProject(
        storeys: [
          StoreyLevel(id: 'g', name: 'Ground', elevation: 0),
          StoreyLevel(id: 'f', name: 'First', elevation: 2.85),
          StoreyLevel(id: 'r', name: 'Roof', elevation: 5.6),
        ],
        activeStoreyIndex: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            initialProject: saved,
            title: 'Floor ownership',
            bimContext: StructuralBimContext(
              underlaysByStorey: {'g': doc, 'f': doc, 'r': doc},
              projectBounds: doc.bounds,
              cadUnitsPerMeter: 1,
              onProjectChanged: (p) => saved = p,
              onLayerVisibilityChanged: (_, _) {},
              onWallsDetected: (_) {},
              onExport: (_, _, _) async {},
              onManageStoreys: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder paintFinder() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is Structural2dPainter,
      );
      Structural2dPainter painter() =>
          tester.widget<CustomPaint>(paintFinder()).painter
              as Structural2dPainter;
      Offset screen(Offset p) => tester
          .renderObject<RenderBox>(paintFinder())
          .localToGlobal(painter().cadToScene(p));
      await tester.tap(find.text('Slab'));
      await tester.pumpAndSettle();
      for (final p in [
        const Offset(1, 1),
        const Offset(4, 1),
        const Offset(4, 4),
        const Offset(1, 4),
        const Offset(1, 1),
      ]) {
        await tester.tapAt(screen(p));
        await tester.pumpAndSettle();
      }
      expect(saved.storeys[1].slabs, hasLength(1));
      final slab = saved.storeys[1].slabs.single;
      expect(slab.isFloorSlab, isTrue);
      expect(
        saved.activeStorey.structuralElevationFor(slab),
        closeTo(2.80, 1e-8),
      );
      expect(saved.storeys[0].slabs, isEmpty);
      await tester.tap(
        find.descendant(of: find.byType(AppBar), matching: find.text('+2.85')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(StoreyManagerSheet),
          matching: find.text('±0.00'),
        ),
      );
      await tester.pumpAndSettle();
      expect(painter().currentStorey.id, 'g');
      expect(painter().ceilingSlabStorey!.id, 'f');
      expect(painter().ceilingSlabStorey!.slabs.single.id, slab.id);
      expect(painter().ghostStorey, isNull);
      await tester.tap(find.byKey(const ValueKey('bim-edit-floor-slab')));
      await tester.pumpAndSettle();
      expect(painter().currentStorey.id, 'f');
      expect(painter().selectedSlabId, slab.id);
      // A point still 1.5 m away from its neighbour must never collapse.
      final gesture = await tester.startGesture(
        screen(const Offset(1, 1)),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(screen(const Offset(2.5, 1)));
      await tester.pump();
      expect(painter().mergeCandidateVertexIndex, isNull);
      expect(painter().draggingSlabVertexPos!.dx, closeTo(2.5, 1e-8));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(saved.storeys[1].slabs.single.polygon, hasLength(4));
      // An endpoint within the general snap band but beyond merge band cannot delete a vertex.
      final near = await tester.startGesture(
        screen(const Offset(2.5, 1)),
        kind: PointerDeviceKind.mouse,
      );
      await near.moveTo(screen(const Offset(3.92, 1)));
      await tester.pump();
      expect(painter().mergeCandidateVertexIndex, isNull);
      await near.up();
      await tester.pumpAndSettle();
      expect(saved.storeys[1].slabs.single.polygon, hasLength(4));
      expect(
        saved.storeys[1].slabs.single.polygon.first.dx,
        closeTo(3.92, 1e-8),
      );
      expect(saved.storeys.fold<int>(0, (n, s) => n + s.slabs.length), 1);
      expect(tester.takeException(), isNull);
    },
  );
}
