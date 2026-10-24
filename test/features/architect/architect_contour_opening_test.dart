import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_contour.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_closed_contour.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_junctions.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_slab_geometry.dart';
import 'package:kotoview/src/features/architect/widgets/architect_hatch_picker.dart';
import 'architect_tool_test_helper.dart' as tools;
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

const outer = [Offset.zero, Offset(8, 0), Offset(8, 6), Offset(0, 6)];
const hole = [Offset(2, 2), Offset(4, 2), Offset(4, 4), Offset(2, 4)];
const hatch = ArchitectCadPrimitive(
  id: 'hatch',
  type: CadPrimitiveType.hatch,
  startPoint: Offset.zero,
  endPoint: Offset(8, 6),
  polygon: outer,
);
ArchitectProject project() => ArchitectProject(
  id: 'p',
  name: 'Test',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [
    ArchitectStorey(
      id: 's',
      name: 'Floor',
      slabs: const [
        ArchitectSlab(id: 'slab', polygon: outer),
        ArchitectSlab(id: 'neighbor', polygon: outer),
      ],
      roofs: [
        ArchitectRoofPlane(
          id: 'roof',
          storeyId: 's',
          points: outer,
          slopeDegrees: 0,
          eavesOverhang: 0,
          attachToWalls: false,
        ),
      ],
      cadPrimitives: const [hatch],
    ),
  ],
);
List<ArchitectCadPrimitive> lines(List<Offset> p) => [
  for (var i = 0; i < p.length; i++)
    ArchitectCadPrimitive(
      id: 'line$i',
      type: CadPrimitiveType.line,
      startPoint: p[i],
      endPoint: p[(i + 1) % p.length],
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Openings belong to one host, persist, and undo/redo atomically', () {
    for (final id in ['slab', 'roof', 'hatch']) {
      final model = ArchitectCommandController(project());
      addTearDown(model.dispose);
      final before = jsonEncode(model.project.toJson());
      model.execute(
        CutArchitectContourOpening(storeyId: 's', elementId: id, polygon: hole),
      );
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(model.project.toJson())),
      );
      expect(CutArchitectContourOpening.target(restored.activeStorey, id)!.$2, [
        hole,
      ]);
      expect(restored.activeStorey.slabs.last.holes, isEmpty);
      expect(
        ArchitectSelection.outline(restored, id).contains(const Offset(3, 3)),
        isFalse,
      );
      if (id == 'slab') expect(restored.activeStorey.slabs.first.area, 44);
      if (id == 'roof') expect(restored.activeStorey.roofs.single.planArea, 44);
      model.undo();
      expect(jsonEncode(model.project.toJson()), before);
      model.redo();
      expect(
        CutArchitectContourOpening.target(model.project.activeStorey, id)!.$2,
        [hole],
      );
    }
  });
  test(
    'Invalid, touching, overlapping and concavity-crossing cuts are rejected',
    () {
      final model = ArchitectCommandController(project());
      addTearDown(model.dispose);
      model.execute(
        const CutArchitectContourOpening(
          storeyId: 's',
          elementId: 'hatch',
          polygon: hole,
        ),
      );
      final before = jsonEncode(model.project.toJson());
      for (final p in [
        hole,
        outer,
        [const Offset(7, 2), const Offset(9, 2), const Offset(9, 4)],
        [
          const Offset(1, 1),
          const Offset(5, 5),
          const Offset(5, 1),
          const Offset(1, 5),
        ],
      ]) {
        expect(
          () => model.execute(
            CutArchitectContourOpening(
              storeyId: 's',
              elementId: 'hatch',
              polygon: p,
            ),
          ),
          throwsArgumentError,
        );
        expect(jsonEncode(model.project.toJson()), before);
      }
      const concave = [
        Offset.zero,
        Offset(8, 0),
        Offset(8, 6),
        Offset(5, 6),
        Offset(5, 2),
        Offset(3, 2),
        Offset(3, 6),
        Offset(0, 6),
      ];
      expect(
        ArchitectContour.canAdd(concave, [], const [
          Offset(1, 3),
          Offset(7, 3),
          Offset(4, 1),
        ]),
        isFalse,
      );
      expect(
        () => model.execute(
          const UpdateArchitectPolygon(
            storeyId: 's',
            elementId: 'hatch',
            polygon: [Offset.zero, Offset(3, 0), Offset(3, 6), Offset(0, 6)],
          ),
        ),
        throwsArgumentError,
      );
    },
  );
  test('Slab section and roof 3D have an actual void through all layers', () {
    var p = project();
    for (final id in ['slab', 'roof']) {
      p = CutArchitectContourOpening(
        storeyId: 's',
        elementId: id,
        polygon: hole,
      ).apply(p);
    }
    final floor = p.activeStorey;
    final slab = floor.slabs.first;
    expect(
      ArchitectSlabGeometry.intervals(
        floor,
        slab,
        const ArchitectSection(
          id: 'cut',
          start: Offset(0, 3),
          end: Offset(8, 3),
        ),
      ),
      [(0.0, 2.0), (4.0, 8.0)],
    );
    expect(
      ArchitectSlabGeometry.footprint(floor, slab).fold(
        0.0,
        (sum, ring) => sum + ArchitectPolygonGeometry.signedArea(ring).abs(),
      ),
      closeTo(44, 1e-6),
    );
    expect(
      ArchitectRoofJunctions.of(
        floor,
      ).footprint(floor.roofs.single).contains(const Offset(3, 3)),
      isFalse,
    );
    final slices = ArchitectRoofGeometry.buildSectionSlices(
      storey: floor,
      sectionLine: const ArchitectSection(
        id: 'roof-cut',
        start: Offset(0, 3),
        end: Offset(8, 3),
      ),
    );
    expect(slices, isNotEmpty);
    expect(slices.any((s) => s.fromS < 3 && s.toS > 3), isFalse);
    // Isolate the roof so unrelated slabs cannot hide a filled opening.
    final mesh = Architect3dBuilder.buildProjectMesh(
      p.copyWith(storeys: [floor.copyWith(slabs: [])]),
    );
    expect(mesh.triangles, isNotEmpty);
    for (final t in mesh.triangles) {
      final xy = [
        Offset(t.v0.x, t.v0.y),
        Offset(t.v1.x, t.v1.y),
        Offset(t.v2.x, t.v2.y),
      ];
      if (ArchitectPolygonGeometry.signedArea(xy).abs() > 1e-9) {
        expect(
          ArchitectPolygonGeometry.contains(xy, const Offset(3.1, 3.2)),
          isFalse,
        );
      }
    }
  });
  test('Move and mirror transform inner rings with their host', () {
    var p = project();
    for (final id in ['slab', 'roof', 'hatch']) {
      p = CutArchitectContourOpening(
        storeyId: 's',
        elementId: id,
        polygon: hole,
      ).apply(p);
    }
    p = const MoveArchitectElements(
      storeyId: 's',
      elementIds: {'slab', 'roof', 'hatch'},
      delta: Offset(10, 0),
    ).apply(p);
    p = const MirrorArchitectElements(
      storeyId: 's',
      elementIds: {'slab', 'roof', 'hatch'},
      origin: Offset.zero,
      direction: Offset(0, 1),
      isDuplicate: false,
    ).apply(p);
    for (final id in ['slab', 'roof', 'hatch']) {
      final target = CutArchitectContourOpening.target(p.activeStorey, id)!;
      expect(ArchitectContour.valid(target.$1, target.$2), isTrue);
      expect(
        ArchitectSelection.outline(p, id).contains(const Offset(-13, 3)),
        isFalse,
      );
      expect(target.$2.single, contains(const Offset(-12, 2)));
    }
  });
  test(
    'Auto fill detects CAD faces, dividers and islands; open contours fail',
    () {
      ArchitectStorey floor(List<ArchitectCadPrimitive> p) =>
          ArchitectStorey(id: 's', name: '', cadPrimitives: p);
      final boundary = lines(outer);
      final result = ArchitectClosedContour.detect(
        floor(boundary),
        const Offset(1, 1),
      )!;
      expect(ArchitectPolygonGeometry.signedArea(result.polygon).abs(), 48);
      expect(
        ArchitectClosedContour.detect(
          floor(boundary.take(3).toList()),
          const Offset(1, 1),
        ),
        isNull,
      );
      final divided = ArchitectClosedContour.detect(
        floor([
          ...boundary,
          const ArchitectCadPrimitive(
            id: 'divider',
            type: CadPrimitiveType.line,
            startPoint: Offset(5, -1),
            endPoint: Offset(5, 7),
          ),
        ]),
        const Offset(1, 1),
      )!;
      expect(ArchitectPolygonGeometry.signedArea(divided.polygon).abs(), 30);
      final island = ArchitectClosedContour.detect(
        floor([...boundary, ...lines(hole)]),
        const Offset(1, 1),
      )!;
      expect(island.holes, hasLength(1));
      expect(
        ArchitectContour.path(
          island.polygon,
          island.holes,
        ).contains(const Offset(3, 3)),
        isFalse,
      );
    },
  );
  testWidgets('Auto hatch places from an interior tap and remains undoable', (
    tester,
  ) async {
    final model = ArchitectCommandController(
      project().copyWith(
        storeys: [
          ArchitectStorey(id: 's', name: '', cadPrimitives: lines(outer)),
        ],
      ),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await tools.choose(tester, Icons.texture_rounded);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hatch-mode-auto')));
    await tester.pumpAndSettle();
    await tester.tapAt(workspace.screen(tester, const Offset(1, 1)));
    await tester.pumpAndSettle();
    expect(
      model.project.activeStorey.cadPrimitives.where(
        (p) => p.type == CadPrimitiveType.hatch,
      ),
      hasLength(1),
    );
    model.undo();
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.cadPrimitives, hasLength(4));
    expect(tester.takeException(), isNull);
  });
  test(
    'Printed hatch vectors clip out holes and retain both boundary rings',
    () {
      final canvas = ArchitectVectorCanvas();
      ArchitectElementsPainterHelper.drawCadPrimitives(
        canvas: canvas,
        storey: ArchitectStorey(
          id: 's',
          name: '',
          cadPrimitives: [
            hatch.copyWith(holes: [hole]),
          ],
        ),
        zoomScale: 100,
      );
      final paths = canvas.operations.whereType<ArchitectVectorPath>().toList();
      final fill = paths.firstWhere((p) => p.clip != null);
      expect(fill.clip!.contains(const Offset(3, 3)), isFalse);
      expect(fill.clip!.contains(const Offset(1, 1)), isTrue);
      expect(paths.last.path.computeMetrics(), hasLength(2));
    },
  );
  test('Auto hatch follows room wall faces and a CAD divider', () {
    final room = ArchitectStorey(
      id: 's',
      name: '',
      walls: [
        for (var i = 0; i < outer.length; i++)
          editing.wall('w$i', outer[i], outer[(i + 1) % outer.length]),
      ],
      cadPrimitives: const [
        ArchitectCadPrimitive(
          id: 'divider',
          type: CadPrimitiveType.line,
          startPoint: Offset(5, -1),
          endPoint: Offset(5, 7),
        ),
      ],
    );
    final result = ArchitectClosedContour.detect(room, const Offset(1, 1))!;
    expect(ArchitectPolygonGeometry.valid(result.polygon), isTrue);
    expect(result.polygon.every((p) => p.dx <= 5 + 1e-6), isTrue);
    expect(
      ArchitectPolygonGeometry.signedArea(result.polygon).abs(),
      greaterThan(20),
    );
  });
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'Hatch modes and drafting controls fit a 320 px phone in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        bool? selected;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: ArchitectHatchDraftBar(
                  pattern: hatch.hatchPattern,
                  customPatterns: const [],
                  lineStyles: const [],
                  pointCount: 3,
                  onChanged: (_) {},
                  onUndo: () {},
                  onFinish: () {},
                  onCancel: () {},
                  onAutomaticChanged: (v) => selected = v,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in [
          'hatch-mode-auto',
          'hatch-mode-manual',
          'hatch-draft-finish',
          'hatch-draft-cancel',
        ]) {
          final button = find.byKey(ValueKey(key));
          final bounds = tester.getRect(button);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(320));
        }
        await tester.tap(find.byKey(const ValueKey('hatch-mode-auto')));
        expect(selected, isTrue);
        await tester.tap(find.byKey(const ValueKey('hatch-mode-manual')));
        expect(selected, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final id in ['slab', 'roof', 'hatch']) {
    testWidgets(
      'Context opening can be drawn, cancelled and committed on $id',
      (tester) async {
        final floor = project().activeStorey;
        final model = ArchitectCommandController(
          project().copyWith(
            storeys: [
              floor.copyWith(
                slabs: id == 'slab' ? [floor.slabs.first] : [],
                roofs: id == 'roof' ? floor.roofs : [],
                cadPrimitives: id == 'hatch' ? [hatch] : [],
              ),
            ],
          ),
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await editing.contextHold(tester, const Offset(1, 1));
        final cut = find.byKey(const ValueKey('architect-radial-cutOpening'));
        expect(cut, findsOneWidget);
        await tester.tap(cut);
        await tester.pumpAndSettle();
        await tester.tapAt(workspace.screen(tester, hole.first));
        await tester.pumpAndSettle();
        expect(model.canUndo, isFalse);
        await tester.tap(find.byKey(const ValueKey('opening-draft-cancel')));
        await tester.pumpAndSettle();
        expect(model.canUndo, isFalse);
        await editing.contextHold(tester, const Offset(1, 1));
        await tester.tap(cut);
        await tester.pumpAndSettle();
        for (final point in hole) {
          await tester.tapAt(workspace.screen(tester, point));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('opening-draft-finish')));
        await tester.pumpAndSettle();
        expect(
          CutArchitectContourOpening.target(model.project.activeStorey, id)!.$2,
          hasLength(1),
        );
        model.undo();
        await tester.pumpAndSettle();
        expect(
          CutArchitectContourOpening.target(model.project.activeStorey, id)!.$2,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
