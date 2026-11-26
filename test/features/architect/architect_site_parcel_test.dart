import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_en.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_site_parcel.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_dxf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_site_orientation.dart';
import 'package:kotoview/src/features/architect/services/architect_site_underlay_pick.dart';
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

      Future<void> menu(String label) async {
        await tester.tap(find.byKey(const ValueKey('architect-site-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await menu('Parcel');
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
      await menu('Setback line');
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
}
