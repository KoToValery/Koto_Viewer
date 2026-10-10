import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_structural_seed_sync.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_3d_mesh_builder.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/widgets/storey_manager_sheet.dart';
import 'features/bim_projects/bim_seed_lifecycle_test.dart' as fixtures;

// These cases intentionally exercise saved legacy ceilings. New BIM seeds are
// floor-owned now, so construct the legacy owner representation explicitly.
StructuralProject legacyCeilings(StructuralProject seeded) => seeded.copyWith(
  storeys: [
    for (var i = 0; i < seeded.storeys.length; i++)
      seeded.storeys[i].copyWith(
        slabs: [
          if (i + 1 < seeded.storeys.length)
            for (final slab in seeded.storeys[i + 1].slabs)
              slab.copyWith(
                isFloorSlab: false,
                topElevation: seeded.storeys[i + 1].structuralElevationFor(
                  slab,
                ),
              ),
        ],
      ),
  ],
);

StructuralProject twoLevels() {
  final p = fixtures.project([0, 2.8]);
  return legacyCeilings(
    BimStructuralSeedSync.refresh(p, fixtures.model(p), fixtures.docs(p)).$2,
  ).copyWith(activeStoreyIndex: 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Upper floor references its lower ceiling without changing ownership or elevation',
    () {
      final p = twoLevels();
      final before = jsonEncode(p.toJson());
      final upper = p.activeStorey;
      final floor = p.floorSlabStoreyFor(upper)!;
      expect(upper.slabs, isEmpty);
      expect(floor.id, 's0');
      expect(floor.slabs.single.id, p.storeys.first.slabs.single.id);
      expect(
        floor.structuralElevationFor(floor.slabs.single),
        closeTo(2.75, 1e-9),
      );
      final view = p.storeyPlanFor(upper);
      expect(view.slabs.length, 1);
      expect(
        view.structuralElevationFor(view.slabs.single),
        closeTo(2.75, 1e-9),
      );
      expect(p.floorSlabStoreyFor(p.storeys.first), isNull);
      expect(jsonEncode(p.toJson()), before);
    },
  );
  test(
    'Floor lookup uses nearest lower elevation and never revives a missing plate',
    () {
      final p = fixtures.project([-3.2, 0, 2.8, 5.6]);
      final (_, floorOwned) = BimStructuralSeedSync.refresh(
        p,
        fixtures.model(p),
        fixtures.docs(p),
      );
      final seeded = legacyCeilings(floorOwned);
      final unordered = seeded.copyWith(
        storeys: seeded.storeys.reversed.toList(),
      );
      expect(unordered.floorSlabStoreyFor(seeded.storeys.last)!.id, 's2');
      final withoutCeiling = seeded.copyWith(
        storeys: [
          for (final s in seeded.storeys)
            s.id == 's2' ? s.copyWith(slabs: []) : s,
        ],
      );
      expect(
        withoutCeiling.floorSlabStoreyFor(withoutCeiling.storeys.last),
        isNull,
      );
      final shifted = twoLevels();
      final source = shifted.storeys.first;
      final altered = shifted.copyWith(
        storeys: [
          source.copyWith(
            slabs: [source.slabs.single.copyWith(topElevation: 3.1)],
          ),
          shifted.storeys.last,
        ],
      );
      expect(altered.floorSlabStoreyFor(altered.activeStorey), isNull);
    },
  );
  test(
    '3D has one plate at 2.80 finished level and highlights it from the upper floor',
    () {
      final p = twoLevels();
      final all = Structural3dMeshBuilder.buildProjectMesh(
        p,
        cadUnitsPerMeter: 1000,
      );
      final highlighted = Structural3dMeshBuilder.buildProjectMesh(
        p,
        highlightStoreyIndex: 1,
        cadUnitsPerMeter: 1000,
      );
      expect(highlighted.triangleCount, all.triangleCount);
      expect(
        highlighted.groups!.singleWhere((g) => g.id == 's1').triangles,
        isEmpty,
      );
      expect(
        highlighted.triangles
            .expand((t) => [t.v0.z, t.v1.z, t.v2.z])
            .reduce(math.max),
        closeTo(2750, 1e-6),
      );
      final cap = highlighted.triangles.where(
        (t) => [t.v0.z, t.v1.z, t.v2.z].every((z) => (z - 2750).abs() < 1e-6),
      );
      expect(cap, isNotEmpty);
      expect(cap.every((t) => t.color!.a == 1), true);
    },
  );
  test(
    'Upper DXF includes floor contour and stairs at the actual concrete elevation',
    () async {
      final temp = await Directory.systemTemp.createTemp('floor_view_export_');
      addTearDown(() => temp.delete(recursive: true));
      final p = twoLevels();
      final opening = fixtures
          .ring(1)
          .map((v) => v + const Offset(2, 2))
          .toList();
      final lower = p.storeys.first.copyWith(
        slabs: [
          p.storeys.first.slabs.single.copyWith(
            openings: [opening],
            openingTypes: [SlabOpeningType.staircase],
          ),
        ],
      );
      final edited = p.copyWith(storeys: [lower, p.storeys.last]);
      final manifest = fixtures.project([0, 2.8]);
      final standalone = manifest.copyWith(
        storeys: [
          for (final s in manifest.storeys)
            BimStoreyUnderlay(
              storeyId: s.storeyId,
              name: s.name,
              elevation: s.elevation,
            ),
        ],
      );
      final file = await BimExportService.exportStoreyDxf(
        project: standalone,
        structural: edited,
        storeyId: 's1',
        outputDirectory: temp,
      );
      final drawing = await DxfParser.parseFromFile(file);
      expect(
        drawing.entities
            .where((e) => e.layer == 'S-SLAB')
            .whereType<DxfLwPolyline>(),
        hasLength(2),
      );
      expect(
        drawing.entities
            .whereType<DxfText>()
            .where((t) => t.layer == 'S-SLAB')
            .single
            .text,
        contains('T.O.C. +2.75'),
      );
      expect(edited.storeys.last.slabs, isEmpty);
    },
  );
  testWidgets(
    'Upper floor is visible with trace disabled and edits route to the existing plate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final initial = twoLevels();
      final opening = fixtures
          .ring(1)
          .map((v) => v + const Offset(2, 2))
          .toList();
      final slab = initial.storeys.first.slabs.single.copyWith(
        openings: [opening],
        openingTypes: [SlabOpeningType.staircase],
      );
      final project = initial.copyWith(
        storeys: [
          initial.storeys.first.copyWith(slabs: [slab]),
          initial.storeys.last,
        ],
      );
      final doc = DxfDocument(
        entities: [],
        layers: {},
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
        entityStats: {},
      );
      var saved = project;
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            initialProject: project,
            title: 'P',
            initialCadBounds: doc.bounds,
            bimContext: StructuralBimContext(
              underlaysByStorey: {'s0': doc, 's1': doc},
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
      expect(tester.takeException(), isNull);
      Structural2dPainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<Structural2dPainter>()
          .first;
      expect(painter().ghostStorey, isNull);
      expect(painter().currentStorey.slabs, isEmpty);
      expect(painter().floorSlabStorey!.slabs.single.id, slab.id);
      expect(painter().floorSlabStorey!.slabs.single.openings, [opening]);
      expect(
        find.byKey(const ValueKey('bim-floor-slab-reference')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('bim-edit-floor-slab')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(painter().currentStorey.id, 's0');
      expect(painter().selectedSlabId, slab.id);
      await tester.tap(find.byTooltip(l.mirrorElement));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(saved.storeys.first.slabs.single.openings, isNot([opening]));
      await tester.tap(find.widgetWithText(ElevatedButton, l.save));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(of: find.byType(AppBar), matching: find.text('±0.00')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: find.byType(StoreyManagerSheet),
          matching: find.text('+2.80'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(painter().currentStorey.id, 's1');
      expect(
        painter().floorSlabStorey!.slabs.single.openings,
        saved.storeys.first.slabs.single.openings,
      );
      expect(saved.storeys.last.slabs, isEmpty);
      expect(saved.storeys.fold<int>(0, (n, s) => n + s.slabs.length), 1);
      await tester.tap(
        find.descendant(of: find.byType(AppBar), matching: find.text('+2.80')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(StoreyManagerSheet),
          matching: find.text(l.traceRefBelow),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(StoreyManagerSheet),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(painter().ghostStorey!.id, 's0');
      expect(
        find.byKey(const ValueKey('bim-floor-slab-reference')),
        findsOneWidget,
      );
      expect(
        find.text(l.traceReferenceLayer(saved.storeys.first.name)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Floor contour is painted in the upper plan without trace mode', (
    tester,
  ) async {
    final p = twoLevels();
    final painter = Structural2dPainter(
      currentStorey: p.activeStorey.copyWith(gridAxes: []),
      floorSlabStorey: p.floorSlabStoreyFor(p.activeStorey),
      showSlabSpanOverlay: false,
      showCantileverHeatmap: false,
      cadToScene: (v) => Offset(10 + v.dx * 10, 110 - v.dy * 10),
      cadScale: 10,
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(120, 120));
    final picture = recorder.endRecording();
    late ui.Image img;
    late ByteData pixels;
    await tester.runAsync(() async {
      img = await picture.toImage(120, 120);
      pixels = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    final offset = (50 * 120 + 10) * 4;
    expect(pixels.getUint8(offset + 3), greaterThan(200));
    expect(pixels.getUint8(offset + 2), greaterThan(pixels.getUint8(offset)));
    picture.dispose();
    img.dispose();
  });
}
