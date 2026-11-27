import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_en.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart'
    show ArchitectTool;
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_chamfer_fillet.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_dxf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_rotation.dart';
import 'package:kotoview/src/features/architect/services/architect_site_orientation.dart';
import 'package:kotoview/src/features/architect/services/architect_site_underlay_pick.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_pointer_interaction.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;

import 'architect_workspace_interaction_test.dart' as workspace;

const _rectangle = [Offset.zero, Offset(10, 0), Offset(10, 8), Offset(0, 8)];

ArchitectProject _project({
  ArchitectSiteParcel? parcel,
  bool building = false,
}) {
  final project = ArchitectProject.starterWithCatalog(
    name: 'Parcel',
    storeyCount: 1,
  );
  final site = project.siteStorey!;
  return project.copyWith(
    activeStoreyId: site.id,
    storeys: [
      for (final storey in project.storeys)
        if (storey.isSite)
          storey.copyWith(siteParcel: parcel)
        else if (building)
          storey.copyWith(
            walls: const [
              ArchitectWall(
                id: 'a',
                startPoint: Offset(3, 2),
                endPoint: Offset(7, 2),
              ),
              ArchitectWall(
                id: 'b',
                startPoint: Offset(7, 2),
                endPoint: Offset(7, 6),
              ),
              ArchitectWall(
                id: 'c',
                startPoint: Offset(7, 6),
                endPoint: Offset(3, 6),
              ),
              ArchitectWall(
                id: 'd',
                startPoint: Offset(3, 6),
                endPoint: Offset(3, 2),
              ),
            ],
          )
        else
          storey,
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  bool hasSegment(List<ArchitectSiteSegment> segments, Offset a, Offset b) =>
      segments.any(
        (line) =>
            ((line.$1 - a).distance < 1e-6 && (line.$2 - b).distance < 1e-6) ||
            ((line.$1 - b).distance < 1e-6 && (line.$2 - a).distance < 1e-6),
      );

  test(
    'intersecting setbacks form a closed contour and trim to the parcel otherwise',
    () {
      final partial = ArchitectSiteParcel(_rectangle, setbacks: {0: 1, 1: 2});
      expect(partial.trimmedSetbacks, hasLength(2));
      expect(
        hasSegment(
          partial.trimmedSetbacks,
          const Offset(0, 1),
          const Offset(8, 1),
        ),
        isTrue,
      );
      expect(
        hasSegment(
          partial.trimmedSetbacks,
          const Offset(8, 1),
          const Offset(8, 8),
        ),
        isTrue,
      );
      final closed = partial.withSetback(2, 1.5).withSetback(3, 3);
      expect(closed.trimmedSetbacks, hasLength(4));
      const corners = [
        Offset(3, 1),
        Offset(8, 1),
        Offset(8, 6.5),
        Offset(3, 6.5),
      ];
      for (var i = 0; i < corners.length; i++) {
        expect(
          hasSegment(
            closed.trimmedSetbacks,
            corners[i],
            corners[(i + 1) % corners.length],
          ),
          isTrue,
        );
      }
      expect(closed.withSetback(3, 9).trimmedSetbacks, isEmpty);
    },
  );

  test(
    'setback offsets meet at a concave corner without cutting the other wing',
    () {
      final parcel = ArchitectSiteParcel(
        const [
          Offset.zero,
          Offset(10, 0),
          Offset(10, 4),
          Offset(4, 4),
          Offset(4, 10),
          Offset(0, 10),
        ],
        setbacks: {2: 1, 3: 1},
      );
      expect(parcel.trimmedSetbacks, hasLength(2));
      expect(
        hasSegment(
          parcel.trimmedSetbacks,
          const Offset(10, 3),
          const Offset(3, 3),
        ),
        isTrue,
      );
      expect(
        hasSegment(
          parcel.trimmedSetbacks,
          const Offset(3, 3),
          const Offset(3, 10),
        ),
        isTrue,
      );
    },
  );

  test(
    'clips exact interior setbacks on concave parcels in either winding',
    () {
      const outline = [
        Offset.zero,
        Offset(10, 0),
        Offset(10, 10),
        Offset(7, 10),
        Offset(7, 3),
        Offset(3, 3),
        Offset(3, 10),
        Offset(0, 10),
      ];
      final parcel = ArchitectSiteParcel(outline);
      expect(parcel.area, 72);
      expect(parcel.setbackSegments(0, 4), [
        (const Offset(0, 4), const Offset(3, 4)),
        (const Offset(7, 4), const Offset(10, 4)),
      ]);
      expect(parcel.setbackSegments(0, 11), isEmpty);
      expect(parcel.setbackSegments(0, 0), isEmpty);
      expect(
        ArchitectSiteParcel(outline.reversed.toList()).setbackSegments(6, 4),
        [
          (const Offset(10, 4), const Offset(7, 4)),
          (const Offset(3, 4), const Offset(0, 4)),
        ],
      );
      expect(
        ArchitectSiteParcel.fromJson({
          'vertices': [
            [0, 0],
            [4, 4],
            [0, 4],
            [4, 0],
          ],
        }),
        isNull,
      );
    },
  );

  test(
    'measures finite edges and identifies crossing, touching and outside outlines',
    () {
      final parcel = ArchitectSiteParcel(_rectangle);
      const inside = [
        [Offset(2, 3), Offset(7, 3), Offset(7, 5), Offset(2, 5)],
      ];
      expect(parcel.clearances(inside).map((p) => (p.$2 - p.$1).distance), [
        3,
        3,
        3,
        2,
      ]);
      expect(parcel.buildingOutside(inside), isFalse);
      const touching = [
        [Offset(2, 0), Offset(7, 0), Offset(7, 5), Offset(2, 5)],
      ];
      expect(
        parcel.clearances(touching).first.$1,
        parcel.clearances(touching).first.$2,
      );
      expect(parcel.buildingOutside(touching), isFalse);
      const crossing = [
        [Offset(2, -1), Offset(7, -1), Offset(7, 5), Offset(2, 5)],
      ];
      expect(
        parcel.clearances(crossing).first.$1,
        parcel.clearances(crossing).first.$2,
      );
      expect(parcel.buildingOutside(crossing), isTrue);
      const outside = [
        [Offset(-2, -2), Offset(-1, -2), Offset(-1, -1), Offset(-2, -1)],
      ];
      final (a, b) = parcel.clearances(outside).first;
      expect((b - a).distance, closeTo(math.sqrt2, 1e-9));
      expect(parcel.buildingOutside(outside), isTrue);
    },
  );

  test(
    'picks only finite visible CAD geometry and returns both crossing candidates',
    () {
      final doc = DxfDocument(
        entities: [
          DxfLine(layer: '0', p1: const Offset(0, 1), p2: const Offset(10, 1)),
          DxfLine(layer: '0', p1: const Offset(5, 0), p2: const Offset(5, 3)),
          DxfLine(
            layer: 'Guide',
            p1: const Offset(3, 0),
            p2: const Offset(3, 8),
          ),
        ],
        layers: {
          '0': DxfLayer(name: '0'),
          'Guide': DxfLayer(name: 'Guide'),
        },
        blocks: const {},
        bounds: const Rect.fromLTWH(0, 0, 10, 8),
        entityStats: const {},
        headerVars: const {},
      );
      const frame = BimCoordinateFrame();
      List<ArchitectSiteSegment> pick(Offset cadPoint, {List<Offset>? mask}) =>
          ArchitectSiteUnderlayPick.nearby(
            document: doc,
            frame: frame,
            point: frame.toModel(cadPoint),
            tolerance: .15,
            visibility: const {'Guide': false},
            mask: mask,
          );
      expect(pick(const Offset(5, 1)), hasLength(2));
      expect(pick(const Offset(3, 1)), hasLength(1));
      expect(pick(const Offset(5, 5)), isEmpty);
      final clipped = pick(
        const Offset(2, 1),
        mask: [
          for (final p in const [
            Offset.zero,
            Offset(4, 0),
            Offset(4, 2),
            Offset(0, 2),
          ])
            frame.toModel(p),
        ],
      ).single;
      expect((clipped.$2 - clipped.$1).distance, closeTo(4, 1e-9));
    },
  );

  test(
    'persists site-only geometry and rotates it through command history',
    () {
      final parcel = ArchitectSiteParcel(_rectangle, setbacks: {0: 2});
      final project = _project(parcel: parcel);
      expect(
        ArchitectProject.fromJson(_project().toJson()).siteStorey!.siteParcel,
        isNull,
      );
      final restored = ArchitectProject.fromJson(
        project.toJson(),
      ).siteStorey!.siteParcel!;
      expect(restored.vertices, parcel.vertices);
      expect(restored.setbacks, parcel.setbacks);
      final controller = ArchitectCommandController(project);
      addTearDown(controller.dispose);
      final aligned = ArchitectSiteOrientation.align(
        project: project,
        pivot: Offset.zero,
        deltaRad: math.pi / 2,
      );
      controller.execute(AlignArchitectSiteOrientation(aligned));
      final rotated = controller.project.siteStorey!.siteParcel!;
      expect(rotated.vertices[1].dy, closeTo(10, 1e-9));
      expect(rotated.area, closeTo(parcel.area, 1e-9));
      expect(rotated.setbacks, parcel.setbacks);
      controller.undo();
      expect(
        controller.project.siteStorey!.siteParcel!.vertices,
        parcel.vertices,
      );
      controller.redo();
      expect(
        controller.project.siteStorey!.siteParcel!.vertices,
        rotated.vertices,
      );
    },
  );

  test(
    'shares parcel, segmented setback and dimensions in vector, PDF and DXF',
    () async {
      final project = _project(
        parcel: ArchitectSiteParcel(_rectangle, setbacks: {0: 1, 1: 2}),
        building: true,
      );
      final l = AppLocalizationsEn();
      const drawing = ArchitectSavedDrawing(
        id: 'plan:storey_site',
        sourceId: 'storey_site',
        kind: ArchitectDrawingKind.plan,
        sitePlan: true,
      );
      const sheet = ArchitectSheet(
        id: 'site',
        placements: [
          ArchitectDrawingPlacement(
            id: 'parcel',
            drawingId: 'plan:storey_site',
            frame: Rect.fromLTWH(25, 30, 170, 145),
            anchor: Offset(5, 4),
            scale: 100,
          ),
        ],
      );
      final published = project.copyWith(
        document: const ArchitectDocument(drawings: [drawing], sheets: [sheet]),
      );
      final scene = ArchitectDrawingPublisher.build(published, drawing, 100, l);
      final parcel = scene.operations
          .whereType<ArchitectVectorPath>()
          .singleWhere((op) => op.role == 'siteParcelBoundary');
      final dashes = scene.operations
          .whereType<ArchitectVectorPath>()
          .where((op) => op.role == 'siteSetback')
          .toList();
      expect(dashes.length, greaterThan(2));
      expect(
        dashes.every((op) {
          final bounds = op.path.getBounds();
          return bounds.right <= 80.0001 && bounds.top >= 9.9999;
        }),
        isTrue,
      );
      expect(
        dashes.every(
          (op) => op.width < parcel.width && op.color.r > op.color.g,
        ),
        isTrue,
      );
      expect(
        scene.operations.whereType<ArchitectVectorText>().where(
          (op) => op.sources.contains('siteClearance'),
        ),
        hasLength(4),
      );
      final dxf = utf8.decode(
        (await ArchitectDxfExport.exportViews(published, [
          drawing,
        ], l)).values.single,
      );
      expect(dxf, contains('A-SITESETBACK'));
      expect(dxf, contains('Area 80.00'));
      final document = pdf.PdfDocument(
        inputBytes: await ArchitectPdfExport.export(published, [sheet], l),
      );
      addTearDown(document.dispose);
      expect(
        pdf.PdfTextExtractor(document).extractText(),
        contains('Area 80.00'),
      );
    },
  );

  testWidgets(
    'phone menu traces through the held aim point and edits a setback',
    (tester) async {
      final controller = ArchitectCommandController(_project());
      addTearDown(controller.dispose);
      await workspace.open(tester, controller);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-2, -2, 14, 12), padding: 62);
      await tester.pumpAndSettle();

      Future<void> siteAction(String name) async {
        final button = find.byKey(ValueKey('architect-site-action-$name'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await siteAction('parcel');
      final aim = workspace.screen(tester, Offset.zero);
      final hold = await tester.startGesture(
        aim + const Offset(0, BimPointerInteraction.touchClearancePx),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await hold.up();
      await tester.pump();
      for (final p in _rectangle.skip(1)) {
        await tester.tapAt(workspace.screen(tester, p));
        await tester.pump();
      }
      await tester.tap(
        find.byKey(const ValueKey('architect-site-parcel-apply')),
      );
      await tester.pumpAndSettle();
      expect(
        controller.project.siteStorey!.siteParcel!.area,
        closeTo(80, 1e-7),
      );
      await siteAction('setback');
      await tester.tapAt(workspace.screen(tester, const Offset(5, 0)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-site-setback-key-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply').last);
      await tester.pumpAndSettle();
      expect(controller.project.siteStorey!.siteParcel!.setbacks, {0: 2});
      await tester.tapAt(workspace.screen(tester, const Offset(10, 4)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-site-setback-key-1')),
      );
      await tester.pumpAndSettle();
      final preview = workspace.overlay(tester).siteSetbackPreview!;
      expect(
        hasSegment(preview, const Offset(0, 2), const Offset(9, 2)),
        isTrue,
      );
      expect(
        hasSegment(preview, const Offset(9, 2), const Offset(9, 8)),
        isTrue,
      );
      expect(controller.project.siteStorey!.siteParcel!.setbacks, {0: 2});
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).siteSetbackPreview, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'drawn site parcel supports standard move, polygon edit, point insertion, rotation, mirror, and deletion',
    () {
      final parcel = ArchitectSiteParcel(
        _rectangle,
        setbacks: const {1: 2.0, 3: 3.0},
      );
      final initial = _project(parcel: parcel);
      final siteId = initial.siteStorey!.id;
      final controller = ArchitectCommandController(initial);
      addTearDown(controller.dispose);

      // 1. Move
      controller.commit(
        MoveArchitectElement(
          storeyId: siteId,
          elementId: ArchitectSiteParcel.elementId,
          delta: const Offset(2, 1),
        ).apply(controller.project),
      );
      expect(
        controller.project.siteStorey!.siteParcel!.vertices.first,
        const Offset(2, 1),
      );

      // 2. Insert point on edge 0 -> setbacks >= 1 shift by +1
      final locate = InsertArchitectElementPoint.locate(
        controller.project.siteStorey!,
        ArchitectSiteParcel.elementId,
        const Offset(7, 1),
      )!;
      expect(locate.edge, 0);
      controller.commit(
        InsertArchitectElementPoint(
          storeyId: siteId,
          elementId: ArchitectSiteParcel.elementId,
          point: locate.point,
          newElementId: 'unused',
        ).apply(controller.project),
      );
      expect(controller.project.siteStorey!.siteParcel!.vertices.length, 5);
      expect(
        controller.project.siteStorey!.siteParcel!.setbacks,
        const {2: 2.0, 4: 3.0},
      );

      // 3. Update polygon directly
      const resized = [
        Offset.zero,
        Offset(12, 0),
        Offset(12, 8),
        Offset(0, 8),
      ];
      controller.commit(
        UpdateArchitectPolygon(
          storeyId: siteId,
          elementId: ArchitectSiteParcel.elementId,
          polygon: resized,
        ).apply(controller.project),
      );
      expect(controller.project.siteStorey!.siteParcel!.area, closeTo(96, 1e-7));

      // 4. Rotation & Mirror & Delete
      final rotated = ArchitectRotation.apply(
        controller.project.siteStorey!,
        {ArchitectSiteParcel.elementId},
        Offset.zero,
        math.pi / 2,
      );
      expect(rotated.siteParcel!.vertices[1].dy, closeTo(12, 1e-7));

      final tool = ArchitectElementTool();
      final (mirrored, mirroredId) = tool.mirrorElementById(
        controller.project.siteStorey!,
        ArchitectSiteParcel.elementId,
        origin: Offset.zero,
        direction: const Offset(0, 1),
      );
      expect(mirroredId, ArchitectSiteParcel.elementId);
      expect(mirrored.siteParcel!.vertices[1].dx, closeTo(-12, 1e-7));

      final cleared = tool.deleteElementById(
        controller.project.siteStorey!,
        ArchitectSiteParcel.elementId,
      );
      expect(cleared.siteParcel, isNull);
    },
  );

  testWidgets(
    'site plan bottom quick bar exposes all commands and tapping drawn parcel selects it for standard editing and properties',
    (tester) async {
      final parcel = ArchitectSiteParcel(_rectangle);
      final controller = ArchitectCommandController(_project(parcel: parcel));
      addTearDown(controller.dispose);
      await workspace.open(tester, controller);
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-2, -2, 14, 12), padding: 62);
      await tester.pumpAndSettle();

      // Quick bar exposes all 7 site plan commands directly at the bottom.
      expect(
        find.byKey(const ValueKey('architect-site-quick-bar')),
        findsOneWidget,
      );
      for (final action in [
        'underlay',
        'align',
        'cadVisibility',
        'parcel',
        'setback',
        'terrain',
        'contours',
      ]) {
        expect(
          find.byKey(ValueKey('architect-site-action-$action')),
          findsOneWidget,
        );
      }

      // Tapping the drawn parcel boundary selects site_parcel and opens standard editing controls.
      await tester.tapAt(workspace.screen(tester, const Offset(5, 0)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('architect-selection-delete')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-selection-new-point')),
        findsOneWidget,
      );

      // Standard deletion removes siteParcel and undo restores it.
      await tester.tap(
        find.byKey(const ValueKey('architect-selection-delete')),
      );
      await tester.pumpAndSettle();
      expect(controller.project.siteStorey!.siteParcel, isNull);

      controller.undo();
      await tester.pumpAndSettle();
      expect(controller.project.siteStorey!.siteParcel, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'editing parcel vertices, chamfer/fillet, or collapsing vertices updates connected setbacks cleanly',
    () {
      // 1. Moving edge outward recalculates setback segment to follow the moved side.
      final parcel = ArchitectSiteParcel(_rectangle, setbacks: const {0: 2.0});
      final expanded = parcel.withVertices(const [
        Offset.zero,
        Offset(10, 0),
        Offset(10, 10),
        Offset(0, 10),
      ]);
      expect(expanded.setbacks, const {0: 2.0});
      expect(
        hasSegment(
          expanded.trimmedSetbacks,
          const Offset(0, 2),
          const Offset(10, 2),
        ),
        isTrue,
      );

      // Moving top edge down to y=2 shifts its connected setback from y=2 to y=4.
      final slopedOrShifted = parcel.withVertices(const [
        Offset(0, 2),
        Offset(10, 2),
        Offset(10, 8),
        Offset(0, 8),
      ]);
      expect(
        hasSegment(
          slopedOrShifted.trimmedSetbacks,
          const Offset(0, 4),
          const Offset(10, 4),
        ),
        isTrue,
      );

      // 2. Chamfer corner 1 keeps setbacks on original surviving edges 0 -> 0, 1 -> 2, 2 -> 3.
      final withThree = ArchitectSiteParcel(
        _rectangle,
        setbacks: const {0: 2.0, 1: 2.0, 2: 3.0},
      );
      final chamfered = ArchitectChamferFillet.polygonChamfer(
        withThree.vertices,
        vertexIndex: 1,
        distance: 1.0,
        isClosed: true,
      );
      final afterChamfer = withThree.withVertices(chamfered);
      expect(afterChamfer.vertices, hasLength(5));
      expect(afterChamfer.setbacks, const {0: 2.0, 2: 2.0, 3: 3.0});
      expect(afterChamfer.trimmedSetbacks, isNotEmpty);

      // 3. Fillet corner 1 with 4 segments keeps setbacks on surviving edges.
      final filleted = ArchitectChamferFillet.polygonFillet(
        withThree.vertices,
        vertexIndex: 1,
        radius: 1.0,
        segments: 4,
        isClosed: true,
      );
      final afterFillet = withThree.withVertices(filleted);
      expect(afterFillet.setbacks[0], 2.0);
      expect(afterFillet.setbacks[afterFillet.vertices.length - 3], 2.0);
      expect(afterFillet.setbacks[afterFillet.vertices.length - 2], 3.0);
      expect(afterFillet.trimmedSetbacks, isNotEmpty);

      // 4. Collapsing a vertex in a 5-gon preserves setbacks on remaining sides.
      const pentagon = [
        Offset.zero,
        Offset(5, 0),
        Offset(10, 0),
        Offset(10, 8),
        Offset(0, 8),
      ];
      final pentaParcel = ArchitectSiteParcel(
        pentagon,
        setbacks: const {0: 2.0, 3: 1.5, 4: 1.0},
      );
      final collapsed = pentaParcel.withVertices(_rectangle);
      expect(collapsed.setbacks, const {0: 2.0, 2: 1.5, 3: 1.0});
    },
  );

  testWidgets(
    'moving CAD or raster underlay on site plan moves parcel and setback lines together with undo',
    (tester) async {
      final starter = ArchitectProject.starterWithCatalog(
        name: 'UnderlaySync',
        storeyCount: 1,
      );
      final site = starter.siteStorey!.id;
      final initialParcel = ArchitectSiteParcel(
        _rectangle,
        setbacks: const {0: 2.0, 1: 1.5},
      );
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: const {},
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(10, 0)),
          DxfLine(p1: Offset(10, 0), p2: Offset(10, 8)),
          DxfLine(p1: Offset(10, 8), p2: Offset(0, 8)),
          DxfLine(p1: Offset(0, 8), p2: Offset(0, 0)),
        ],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 10, 8),
        entityStats: const {},
      );
      final raster = ArchitectRasterUnderlay(
        id: 'raster-site',
        storeyId: site,
        fileName: 'scan.png',
        internalImagePath: '',
        position: Offset.zero,
        metersPerPixel: 0.01,
        imageWidthPx: 1000,
        imageHeightPx: 800,
      );
      var project = starter
          .copyWith(activeStoreyId: site, rasterUnderlays: [raster])
          .withCadUnderlayAdded(
            ArchitectCadUnderlayConfig(
              id: 'cad-site',
              storeyId: site,
              fileName: 'survey.dxf',
              internalCopyPath: '',
              unitsPerMeter: 1.0,
              lockedCadOriginX: 0,
              lockedCadOriginY: 0,
              lockOrigin: true,
            ),
          );
      project = project.updateStorey(
        project.siteStorey!.copyWith(siteParcel: initialParcel),
      );
      final controller = ArchitectCommandController(project);
      addTearDown(controller.dispose);

      await workspace.open(tester, controller, underlays: {site: doc});
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-2, -2, 16, 14), padding: 62);
      await tester.pumpAndSettle();

      // 1. Select CAD underlay (tap inside its bounds) and drag its central handle by (2, 1).
      tester
          .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
          .onToolChanged(ArchitectTool.cadUnderlay);
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(5, 4)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('architect-underlay-crop')),
        findsOneWidget,
      );

      final cadDrag = await tester.startGesture(
        workspace.screen(tester, const Offset(5, 4)),
      );
      await cadDrag.moveTo(workspace.screen(tester, const Offset(7, 5)));
      await tester.pump();
      await cadDrag.up();
      await tester.pumpAndSettle();

      final movedAfterCad = controller.project.siteStorey!.siteParcel!;
      expect(movedAfterCad.vertices.first.dx, closeTo(2, 0.15));
      expect(movedAfterCad.vertices.first.dy, closeTo(1, 0.15));
      expect(
        movedAfterCad.trimmedSetbacks.any(
          (seg) =>
              (seg.$1.dy - (movedAfterCad.vertices.first.dy + 2)).abs() < 0.05 &&
              (seg.$2.dy - (movedAfterCad.vertices.first.dy + 2)).abs() < 0.05,
        ),
        isTrue,
      );

      // Undo restores both CAD underlay and parcel + setbacks atomically.
      controller.undo();
      await tester.pumpAndSettle();
      expect(
        controller.project.siteStorey!.siteParcel!.vertices.first,
        Offset.zero,
      );

      // 2. Select Raster underlay (tap inside its bounds) and drag it by (3, 2).
      tester
          .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
          .onToolChanged(ArchitectTool.rasterUnderlay);
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(5, 4)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('architect-underlay-crop')),
        findsOneWidget,
      );
      final rasterDrag = await tester.startGesture(
        workspace.screen(tester, const Offset(5, 4)),
      );
      await rasterDrag.moveTo(workspace.screen(tester, const Offset(8, 6)));
      await tester.pump();
      await rasterDrag.up();
      await tester.pumpAndSettle();

      final movedRaster = controller.project.rasterUnderlays.single;
      expect(movedRaster.position.dx, closeTo(3, 0.15));
      expect(movedRaster.position.dy, closeTo(2, 0.15));
      final movedAfterRaster = controller.project.siteStorey!.siteParcel!;
      expect(
        movedAfterRaster.vertices.first.dx,
        closeTo(movedRaster.position.dx, 1e-6),
      );
      expect(
        movedAfterRaster.vertices.first.dy,
        closeTo(movedRaster.position.dy, 1e-6),
      );
      expect(
        movedAfterRaster.trimmedSetbacks.any(
          (seg) =>
              (seg.$1.dy - (movedAfterRaster.vertices.first.dy + 2)).abs() <
              1e-6,
        ),
        isTrue,
      );

      controller.undo();
      await tester.pumpAndSettle();
      expect(
        controller.project.siteStorey!.siteParcel!.vertices.first,
        Offset.zero,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'perpendicularClearances measures from setback when configured or boundary otherwise and computes rigid translation',
    () {
      const building = [
        [
          Offset(3, 2.5),
          Offset(7, 2.5),
          Offset(7, 5.5),
          Offset(3, 5.5),
        ],
      ];
      final parcel = ArchitectSiteParcel(
        _rectangle,
        setbacks: const {0: 1.0, 1: 2.0},
      );
      final clearances = parcel.perpendicularClearances(building);
      expect(clearances, hasLength(4));

      // Side 0: measured from setback y=1.0 to building y=2.5 => 1.5 m.
      expect(clearances[0].sideIndex, 0);
      expect(clearances[0].fromSetback, isTrue);
      expect(clearances[0].distance, closeTo(1.5, 1e-7));
      expect(clearances[0].linePoint, const Offset(5, 1));
      expect(clearances[0].buildingPoint, const Offset(5, 2.5));

      // Side 1: measured from setback x=8.0 to building x=7.0 => 1.0 m.
      expect(clearances[1].sideIndex, 1);
      expect(clearances[1].fromSetback, isTrue);
      expect(clearances[1].distance, closeTo(1.0, 1e-7));

      // Side 2: no setback -> measured from boundary y=8.0 to building y=5.5 => 2.5 m.
      expect(clearances[2].sideIndex, 2);
      expect(clearances[2].fromSetback, isFalse);
      expect(clearances[2].distance, closeTo(2.5, 1e-7));

      // Rigid translation adjusts boundary/setback distance to exact 3.00 m.
      final deltaSide2 = clearances[2].translationForDistance(3.0);
      expect(deltaSide2.dx, closeTo(0, 1e-7));
      expect(deltaSide2.dy, closeTo(0.5, 1e-7));
      final shifted = parcel.transformed((p) => p + deltaSide2);
      expect(
        shifted.perpendicularClearances(building)[2].distance,
        closeTo(3.0, 1e-7),
      );
      expect(shifted.setbacks, parcel.setbacks);

      // Non-orthogonal diagonals beyond segment span are excluded.
      const offsetBuilding = [
        [
          Offset(12, 2),
          Offset(15, 2),
          Offset(15, 5),
          Offset(12, 5),
        ],
      ];
      final perp = parcel.perpendicularClearances(offsetBuilding);
      expect(perp.where((c) => c.sideIndex == 0), isEmpty);
      expect(perp.where((c) => c.sideIndex == 2), isEmpty);
    },
  );

  testWidgets(
    'clicking site clearance badge opens modal and shifts parcel, setback, and underlays rigidly to exact distance',
    (tester) async {
      final starter = ArchitectProject.starterWithCatalog(
        name: 'ClearanceModal',
        storeyCount: 1,
      );
      final site = starter.siteStorey!.id;
      final ground = starter.storeys.firstWhere((s) => !s.isSite);
      final parcel = ArchitectSiteParcel(
        _rectangle,
        setbacks: const {0: 1.0},
      );
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: const {},
        entities: const [DxfLine(p1: Offset.zero, p2: Offset(10, 0))],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 10, 8),
        entityStats: const {},
      );
      final raster = ArchitectRasterUnderlay(
        id: 'raster-clearance',
        storeyId: site,
        fileName: 'scan.png',
        internalImagePath: '',
        position: Offset.zero,
        metersPerPixel: 0.01,
        imageWidthPx: 1000,
        imageHeightPx: 800,
      );
      final project = starter
          .copyWith(
            activeStoreyId: site,
            rasterUnderlays: [raster],
            storeys: [
              for (final s in starter.storeys)
                if (s.isSite)
                  s.copyWith(siteParcel: parcel)
                else if (s.id == ground.id)
                  s.copyWith(
                    walls: const [
                      ArchitectWall(
                        id: 'bw1',
                        startPoint: Offset(3.125, 3.625),
                        endPoint: Offset(6.875, 3.625),
                      ),
                      ArchitectWall(
                        id: 'bw2',
                        startPoint: Offset(6.875, 3.625),
                        endPoint: Offset(6.875, 5.375),
                      ),
                      ArchitectWall(
                        id: 'bw3',
                        startPoint: Offset(6.875, 5.375),
                        endPoint: Offset(3.125, 5.375),
                      ),
                      ArchitectWall(
                        id: 'bw4',
                        startPoint: Offset(3.125, 5.375),
                        endPoint: Offset(3.125, 3.625),
                      ),
                    ],
                  )
                else
                  s,
            ],
          )
          .withCadUnderlayAdded(
            ArchitectCadUnderlayConfig(
              id: 'cad-clearance',
              storeyId: site,
              fileName: 'survey.dxf',
              internalCopyPath: '',
              unitsPerMeter: 1.0,
              lockedCadOriginX: 0,
              lockedCadOriginY: 0,
              cadOrientation: true,
              lockOrigin: true,
            ),
          );
      final controller = ArchitectCommandController(project);
      addTearDown(controller.dispose);

      await workspace.open(tester, controller, underlays: {site: doc});
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-2, -2, 14, 12), padding: 62);
      await tester.pumpAndSettle();

      // Side 0: ZOOL at y=1.0 -> building y=3.5 => 2.50 m.
      final setbackBadge = find.byKey(const ValueKey('site-clearance-0'));
      expect(setbackBadge, findsOneWidget);
      await tester.tap(setbackBadge);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('site-clearance-keypad')),
        findsOneWidget,
      );

      for (final k in ['3', '.', '0', '0']) {
        await tester.tap(find.byKey(ValueKey('shape-key-$k')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();

      // Parcel + ZOOL + CAD + Raster shifted rigidly by (0, -0.50).
      final after1 = controller.project;
      expect(
        after1.siteStorey!.siteParcel!.vertices.first.dy,
        closeTo(-0.5, 1e-6),
      );
      expect(after1.siteStorey!.siteParcel!.setbacks, const {0: 1.0});
      expect(after1.rasterUnderlays.single.position.dy, closeTo(-0.5, 1e-6));
      expect(
        after1.cadUnderlays[site]!
            .frame(const BimCoordinateFrame())
            .toModel(Offset.zero)
            .dy,
        closeTo(-0.5, 1e-6),
      );

      // Undo reverts parcel, ZOOL, and both underlays in a single step.
      controller.undo();
      await tester.pumpAndSettle();
      expect(
        controller.project.siteStorey!.siteParcel!.vertices.first.dy,
        closeTo(0, 1e-6),
      );
      expect(
        controller.project.rasterUnderlays.single.position.dy,
        closeTo(0, 1e-6),
      );

      // Side 2: boundary at y=8.0 -> building y=5.5 => 2.50 m -> edit to 3.00 m.
      final boundaryBadge = find.byKey(const ValueKey('site-clearance-2'));
      expect(boundaryBadge, findsOneWidget);
      await tester.tap(boundaryBadge);
      await tester.pumpAndSettle();
      for (final k in ['3', '.', '0', '0']) {
        await tester.tap(find.byKey(ValueKey('shape-key-$k')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();

      final after2 = controller.project;
      expect(
        after2.siteStorey!.siteParcel!.vertices.first.dy,
        closeTo(0.5, 1e-6),
      );
      expect(after2.rasterUnderlays.single.position.dy, closeTo(0.5, 1e-6));
      expect(
        after2.cadUnderlays[site]!
            .frame(const BimCoordinateFrame())
            .toModel(Offset.zero)
            .dy,
        closeTo(0.5, 1e-6),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
