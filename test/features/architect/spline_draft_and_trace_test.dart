import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_spline_contour_tracer.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

import 'architect_drawing_controls_revision_test.dart' as revision;
import 'architect_workspace_interaction_test.dart' as workspace;

DxfDocument _dxfDoc(List<DxfEntity> entities) => DxfDocument(
      entities: entities,
      blocks: const {},
      layers: {'0': DxfLayer(name: '0'), 'TOPO': DxfLayer(name: 'TOPO')},
      headerVars: const {},
      bounds: const Rect.fromLTRB(-100, -100, 100, 100),
      entityStats: const {},
    );

void main() {
  group('ArchitectSplineContourTracer — Auto-trace CAD, Underlay & Model', () {
    test('traces open DXF spline/polyline underlay contour with elevation', () {
      final project = ArchitectProject.starterWithCatalog(
        name: 'Trace Underlay',
        storeyCount: 1,
      );
      final doc = _dxfDoc([
        DxfLwPolyline(
          layer: 'TOPO',
          vertices: const [
            DxfPolylineVertex(x: 0, y: 2),
            DxfPolylineVertex(x: 5, y: 4),
            DxfPolylineVertex(x: 10, y: 3),
          ],
          elevation: 542.5,
        ),
        DxfCircle(
          layer: '0',
          center: const Offset(20, 20),
          radius: 3.0,
        ),
      ]);

      final pickedCurve = ArchitectSplineContourTracer.traceAt(
        project: project,
        modelPoint: const Offset(5, 3.9),
        hitToleranceMeters: 0.6,
        underlayDocument: doc,
        underlayFrame: const BimCoordinateFrame(),
      );
      expect(pickedCurve, isNotNull);
      expect(pickedCurve!.source, ArchitectSplineTraceSource.underlay);
      expect(pickedCurve.closed, isFalse);
      expect(pickedCurve.elevation, closeTo(542.5, 1e-4));
      expect(pickedCurve.points.length, 3);

      final pickedCircle = ArchitectSplineContourTracer.traceAt(
        project: project,
        modelPoint: const Offset(23.0, 20.0),
        hitToleranceMeters: 0.6,
        underlayDocument: doc,
        underlayFrame: const BimCoordinateFrame(),
      );
      expect(pickedCircle, isNotNull);
      expect(pickedCircle!.source, ArchitectSplineTraceSource.underlay);
      expect(pickedCircle.closed, isTrue);
      expect(pickedCircle.points.length, greaterThanOrEqualTo(12));
    });

    test('traces site-plan terrain contour (хоризонтал) on План Терен', () {
      final base = ArchitectProject.starterWithCatalog(
        name: 'Site Contour Trace',
        storeyCount: 1,
      );
      final site = base.siteStorey!;
      final project = base.copyWith(
        activeStoreyId: site.id,
        existingTerrain: const ArchitectTerrainSurface(
          state: ArchitectTerrainState.existing,
          contours: [
            ArchitectTerrainContour(
              id: 'c1',
              points: [Offset(0, 5), Offset(6, 7), Offset(12, 5)],
              elevation: 1.5,
              isSpline: true,
            ),
          ],
        ),
      );

      final traced = ArchitectSplineContourTracer.traceAt(
        project: project,
        modelPoint: const Offset(6, 7.05),
        hitToleranceMeters: 0.5,
      );
      expect(traced, isNotNull);
      expect(traced!.source, ArchitectSplineTraceSource.terrainContour);
      expect(traced.elevation, closeTo(1.5, 1e-4));
      expect(traced.closed, isFalse);
    });

    test('stitches active storey lines and detects enclosed closed contours', () {
      final base = ArchitectProject.starterWithCatalog(
        name: 'Model Contour Trace',
        storeyCount: 1,
      );
      final storey = base.activeStorey.copyWith(
        cadPrimitives: const [
          ArchitectCadPrimitive(
            id: 'l1',
            type: CadPrimitiveType.line,
            startPoint: Offset(0, 0),
            endPoint: Offset(4, 0),
          ),
          ArchitectCadPrimitive(
            id: 'l2',
            type: CadPrimitiveType.line,
            startPoint: Offset(4, 0),
            endPoint: Offset(4, 3),
          ),
          ArchitectCadPrimitive(
            id: 'l3',
            type: CadPrimitiveType.line,
            startPoint: Offset(4, 3),
            endPoint: Offset(0, 3),
          ),
          ArchitectCadPrimitive(
            id: 'l4',
            type: CadPrimitiveType.line,
            startPoint: Offset(0, 3),
            endPoint: Offset(0, 0),
          ),
        ],
      );
      final project = base.updateActiveStorey(storey);

      // Edge tap stitches all 4 lines into a closed loop
      final onEdge = ArchitectSplineContourTracer.traceAt(
        project: project,
        modelPoint: const Offset(2, 0.05),
        hitToleranceMeters: 0.4,
      );
      expect(onEdge, isNotNull);
      expect(onEdge!.source, ArchitectSplineTraceSource.modelCurve);
      expect(onEdge.closed, isTrue);
      expect(onEdge.points.length, 4);

      // Interior tap detects closed face via ArchitectClosedContour
      final inside = ArchitectSplineContourTracer.traceAt(
        project: project,
        modelPoint: const Offset(2, 1.5),
        hitToleranceMeters: 0.4,
      );
      expect(inside, isNotNull);
      expect(inside!.source, ArchitectSplineTraceSource.closedRoom);
      expect(inside.closed, isTrue);
    });
  });

  group('Workspace Confirm (X + Green Checkmark) & Spline Trace UI', () {
    testWidgets(
      'Spline drafting displays floating X + green checkmark and commits spline',
      (tester) async {
        final model = workspace.commands();
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await revision.tool(tester, ArchitectTool.spline);

        await workspace.wallTap(tester, const Offset(0, 0));
        await workspace.wallTap(tester, const Offset(3, 1.5));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('architect-draft-cancel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-draft-confirm')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('architect-draft-confirm')));
        await tester.pumpAndSettle();

        final splines = model.project.activeStorey.cadPrimitives
            .where((p) => p.type == CadPrimitiveType.spline)
            .toList();
        expect(splines, hasLength(1));
        expect(splines.single.polygon, hasLength(2));
        expect(splines.single.closed, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Mask drafting displays floating X + green checkmark and commits mask',
      (tester) async {
        final model = workspace.commands();
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await revision.tool(tester, ArchitectTool.mask);

        for (final pt in const [Offset(0, 0), Offset(4, 0), Offset(4, 3)]) {
          await workspace.wallTap(tester, pt);
        }
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('architect-draft-cancel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-draft-confirm')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('architect-draft-confirm')));
        await tester.pumpAndSettle();

        final masks = model.project.activeStorey.cadPrimitives
            .where((p) => p.type == CadPrimitiveType.mask)
            .toList();
        expect(masks, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Floor drain floating green checkmark commits floor drain (not slab)',
      (tester) async {
        final model = workspace.commands();
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await revision.tool(tester, ArchitectTool.floorDrain);

        for (final pt in const [Offset(0, 0), Offset(3, 0), Offset(3, 3)]) {
          await workspace.wallTap(tester, pt);
        }
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('architect-draft-confirm')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('architect-draft-confirm')));
        await tester.pumpAndSettle();

        expect(model.project.activeStorey.floorDrains, hasLength(1));
        expect(model.project.activeStorey.slabs, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Spline Auto-trace mode traces an existing contour into a CAD spline',
      (tester) async {
        final base = ArchitectProject.starterWithCatalog(
          name: 'Spline Trace Widget Test',
          storeyCount: 1,
        );
        final seeded = base.updateActiveStorey(
          base.activeStorey.copyWith(
            cadPrimitives: const [
              ArchitectCadPrimitive(
                id: 'rect-1',
                type: CadPrimitiveType.rect,
                startPoint: Offset(0, 0),
                endPoint: Offset(4, 3),
              ),
            ],
          ),
        );
        final model = ArchitectCommandController(seeded);
        addTearDown(model.dispose);

        await workspace.open(tester, model);
        await revision.tool(tester, ArchitectTool.spline);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('architect-spline-trace-contour')),
        );
        await tester.pumpAndSettle();

        await workspace.wallTap(tester, const Offset(2, 0));
        await tester.pumpAndSettle();

        final splines = model.project.activeStorey.cadPrimitives
            .where((p) => p.type == CadPrimitiveType.spline)
            .toList();
        expect(splines, hasLength(1));
        expect(splines.single.closed, isTrue);
        expect(splines.single.polygon, hasLength(4));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
