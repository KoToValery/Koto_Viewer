import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_drag_controller.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

void main() {
  group('ArchitectDragController Unit Tests', () {
    late ArchitectDragController controller;
    late ArchitectProject project;

    setUp(() {
      controller = ArchitectDragController();
      final wall = ArchitectWall(
        id: 'wall_1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.25,
      );
      final storey = ArchitectStorey(
        id: 'storey_1',
        name: 'Floor 1',
        walls: [wall],
      );
      final now = DateTime(2026, 1, 1);
      project = ArchitectProject(
        id: 'proj_1',
        name: 'Test Project',
        createdAt: now,
        updatedAt: now,
        storeys: [storey],
        activeStoreyId: 'storey_1',
      );
    });

    tearDown(() => controller.dispose());

    test('base snaps outside the selection and remains an uncommitted aim', () {
      controller.startDrag(elementIds: {'elsewhere'});
      controller.updateBaseHover(
        const Offset(.03, .02),
        project: project,
        scale: 100,
      );
      expect(controller.currentPointModel, Offset.zero);
      expect(controller.isPickingBasePoint, isTrue);
      expect(controller.basePointModel, isNull);
      expect(controller.deltaModel, isNull);
    });

    test('rotated raster uses its real corners, edge midpoints and leader', () {
      const raster = ArchitectRasterUnderlay(
        id: 'raster',
        storeyId: 'storey_1',
        fileName: 'plan.png',
        internalImagePath: '',
        imageWidthPx: 400,
        imageHeightPx: 200,
        metersPerPixel: .01,
        position: Offset(20, 30),
        rotationRad: math.pi / 2,
      );
      controller.startDrag(
        isUnderlay: true,
        rasterId: raster.id,
        originalRasterPosition: raster.position,
        defaultAnchor: raster.localBounds.center,
        zoomScale: 100,
      );
      controller.updateBaseHover(
        controller.defaultHandleGrip!,
        project: project,
        raster: raster,
        scale: 100,
      );
      expect(controller.currentPointModel, raster.localBounds.center);
      expect(controller.currentSnapLabel, 'Grip');
      for (final corner in raster.localCorners) {
        controller.updateBaseHover(
          corner + const Offset(.02, .01),
          project: project,
          raster: raster,
          scale: 100,
          snapToDefaultGrip: false,
        );
        expect(
          (controller.currentPointModel! - corner).distance,
          lessThan(1e-9),
        );
      }
      final midpoint = (raster.localCorners[0] + raster.localCorners[1]) / 2;
      controller.updateBaseHover(
        midpoint + const Offset(.02, .01),
        project: project,
        raster: raster,
        scale: 100,
        snapToDefaultGrip: false,
      );
      expect(
        (controller.currentPointModel! - midpoint).distance,
        lessThan(1e-9),
      );
      expect(controller.currentSnapLabel, 'Midpoint');
    });

    test(
      'CAD reference endpoint lands exactly on the snapped drawing target',
      () {
        const frame = BimCoordinateFrame(
          origin: Offset(5000, 10000),
          unitsPerMeter: 1000,
        );
        final document = DxfDocument(
          layers: {},
          blocks: {},
          headerVars: {},
          entityStats: {},
          bounds: const Rect.fromLTRB(7000, 13000, 11000, 15000),
          entities: [
            const DxfLine(p1: Offset(7000, 13000), p2: Offset(11000, 15000)),
          ],
        );
        controller.startDrag(
          isUnderlay: true,
          isCadUnderlay: true,
          unitsPerMeter: 1000,
          originalCadOrigin: frame.origin,
        );
        controller.updateBaseHover(
          const Offset(2.03, 3.02),
          project: project,
          dxfDoc: document,
          frame: frame,
          scale: 100,
        );
        expect(controller.currentPointModel, const Offset(2, 3));
        expect(controller.currentSnapLabel, 'Endpoint');
        controller.grabBasePoint(controller.currentPointModel!, frame: frame);
        controller.updateTargetHover(
          const Offset(.02, .03),
          project: project,
          scale: 100,
          dxfDoc: document,
          frame: frame,
        );
        expect(controller.currentPointModel, Offset.zero);
        final placement = controller.computeCadPlacement(
          targetPointModel: controller.currentPointModel!,
          existingMask: [const Offset(1, 2), const Offset(3, 4)],
        );
        final movedFrame = BimCoordinateFrame(
          origin: Offset(placement.newOriginX, placement.newOriginY),
          unitsPerMeter: 1000,
        );
        expect(movedFrame.toModel(const Offset(7000, 13000)), Offset.zero);
        expect(placement.translatedMask, [
          const Offset(-1, -1),
          const Offset(1, 1),
        ]);
      },
    );

    test('Initial state is idle', () {
      expect(controller.phase, ArchitectDragPhase.idle);
      expect(controller.isIdle, isTrue);
      expect(controller.isActive, isFalse);
      expect(controller.isPickingBasePoint, isFalse);
      expect(controller.isDraggingToTarget, isFalse);
    });

    test(
      'startDrag transitions to pickingBasePoint and sets default handle',
      () {
        controller.startDrag(
          elementIds: {'wall_1'},
          defaultAnchor: const Offset(5, 0),
          handleOffsetLength: 48.0,
          zoomScale: 1.0,
        );

        expect(controller.phase, ArchitectDragPhase.pickingBasePoint);
        expect(controller.isPickingBasePoint, isTrue);
        expect(controller.isActive, isTrue);
        expect(controller.elementIds, contains('wall_1'));
        expect(controller.defaultHandleAnchor, const Offset(5, 0));
        expect(controller.defaultHandleGrip, isNotNull);
      },
    );

    test(
      'updateBaseHover snaps to wall endpoint and grabBasePoint transitions to draggingToTarget',
      () {
        controller.startDrag(
          elementIds: {'wall_1'},
          defaultAnchor: const Offset(5, 0),
        );

        // Hover near (0, 0) - start point of wall
        controller.updateBaseHover(
          const Offset(0.05, 0.05),
          project: project,
          scale: 100.0,
        );

        expect(controller.isSnapped, isTrue);
        expect(controller.currentPointModel, const Offset(0, 0));

        // Grab the base point
        controller.grabBasePoint(controller.currentPointModel!);

        expect(controller.phase, ArchitectDragPhase.draggingToTarget);
        expect(controller.isDraggingToTarget, isTrue);
        expect(controller.basePointModel, const Offset(0, 0));
      },
    );

    test(
      'updateTargetHover computes delta, distance, and angle accurately',
      () {
        controller.startDrag(
          elementIds: {'wall_1'},
          defaultAnchor: const Offset(5, 0),
        );

        controller.grabBasePoint(const Offset(0, 0));

        controller.updateTargetHover(
          const Offset(3, 4),
          project: project,
          scale: 100.0,
        );

        expect(controller.deltaModel, const Offset(3, 4));
        expect(controller.distanceMeters, closeTo(5.0, 1e-4));
        expect(controller.angleDeg, closeTo(53.13, 0.1));
      },
    );

    test('CAD underlay placement math accuracy', () {
      controller.startDrag(
        isUnderlay: true,
        isCadUnderlay: true,
        unitsPerMeter: 1000.0, // 1m = 1000 CAD mm
        originalCadOrigin: const Offset(1000, 2000),
        defaultAnchor: const Offset(1, 2),
      );

      controller.grabBasePoint(const Offset(1, 2));

      final placement = controller.computeCadPlacement(
        targetPointModel: const Offset(3, 5),
        existingMask: [const Offset(0, 0), const Offset(2, 2)],
      );

      // Delta in model = (2, 3)
      // New origin = baseCad - targetModel * unitsPerMeter
      expect(placement.translatedMask, isNotNull);
      expect(placement.translatedMask!.first, const Offset(2, 3));
      expect(placement.translatedMask!.last, const Offset(4, 5));
    });

    test('cancel resets state back to idle', () {
      controller.startDrag(
        elementIds: {'wall_1'},
        defaultAnchor: const Offset(5, 0),
      );
      controller.grabBasePoint(const Offset(5, 0));

      controller.cancel();

      expect(controller.phase, ArchitectDragPhase.idle);
      expect(controller.isActive, isFalse);
      expect(controller.elementIds, isEmpty);
      expect(controller.basePointModel, isNull);
      expect(controller.currentPointModel, isNull);
    });
  });
}
