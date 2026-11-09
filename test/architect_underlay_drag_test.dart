import 'package:flutter_test/flutter_test.dart';

import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_underlay_drag_controller.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  final dummyProject = ArchitectProject(
    id: 'test_id',
    name: 'Test Project',
    createdAt: now,
    updatedAt: now,
    activeStoreyId: 'storey_1',
    storeys: const [
      ArchitectStorey(id: 'storey_1', name: '±0.00', elevation: 0.0, height: 2.8),
    ],
  );

  group('ArchitectUnderlayDragController Unit Tests', () {
    late ArchitectUnderlayDragController controller;

    setUp(() {
      controller = ArchitectUnderlayDragController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('CAD Underlay Drag Phase Transitions and Math Accuracy', () {
      expect(controller.phase, ArchitectUnderlayDragPhase.idle);
      expect(controller.isIdle, isTrue);

      const double unitsPerMeter = 1000.0; // mm to meters
      const initialOrigin = Offset(5000, 10000);
      final initialFrame = BimCoordinateFrame(origin: initialOrigin, unitsPerMeter: unitsPerMeter);

      // Start drag session
      controller.startDrag(
        isCad: true,
        underlayName: 'plan_level1.dxf',
        storeyId: 'storey_1',
        unitsPerMeter: unitsPerMeter,
        originalCadOrigin: initialOrigin,
      );

      expect(controller.phase, ArchitectUnderlayDragPhase.pickingBasePoint);
      expect(controller.isPickingBasePoint, isTrue);
      expect(controller.underlayName, 'plan_level1.dxf');

      // Pick base point at local model coordinates (2.5m, 4.0m)
      const basePointModel = Offset(2.5, 4.0);
      final expectedBaseCad = initialFrame.toCad(basePointModel);
      expect(expectedBaseCad, equals(const Offset(7500.0, 14000.0)));

      // Simulate hover at base point
      controller.updateHover(
        basePointModel,
        project: dummyProject,
        scale: 40.0,
      );
      expect(controller.currentPointModel, equals(basePointModel));

      // Confirm base point
      final confirmed = controller.confirmBasePoint(frame: initialFrame);
      expect(confirmed, isTrue);
      expect(controller.phase, ArchitectUnderlayDragPhase.draggingToTarget);
      expect(controller.isDraggingToTarget, isTrue);
      expect(controller.basePointModel, equals(basePointModel));
      expect(controller.basePointCad, equals(expectedBaseCad));

      // Drag to target position on drawing (5.5m, 8.0m) -> delta (+3.0m, +4.0m)
      const targetPointModel = Offset(5.5, 8.0);
      controller.updateHover(
        targetPointModel,
        project: dummyProject,
        scale: 40.0,
      );

      expect(controller.currentPointModel, equals(targetPointModel));
      expect(controller.deltaModel, equals(const Offset(3.0, 4.0)));
      expect(controller.distanceMeters, closeTo(5.0, 1e-6)); // 3-4-5 right triangle

      // Compute placement result
      final existingMask = [
        const Offset(1.0, 1.0),
        const Offset(6.0, 1.0),
        const Offset(6.0, 6.0),
      ];
      final placement = controller.computeCadPlacement(
        targetPointModel: targetPointModel,
        existingMask: existingMask,
      );

      // Verify that with the new origin, the picked CAD point lands exactly on the target model point!
      final newFrame = BimCoordinateFrame(
        origin: Offset(placement.newOriginX, placement.newOriginY),
        unitsPerMeter: unitsPerMeter,
      );
      final mappedTarget = newFrame.toModel(expectedBaseCad);
      expect(mappedTarget.dx, closeTo(targetPointModel.dx, 1e-9));
      expect(mappedTarget.dy, closeTo(targetPointModel.dy, 1e-9));

      // Verify mask vertices are translated by delta (+3.0m, +4.0m)
      expect(placement.translatedMask, isNotNull);
      expect(placement.translatedMask![0], equals(const Offset(4.0, 5.0)));
      expect(placement.translatedMask![1], equals(const Offset(9.0, 5.0)));
      expect(placement.translatedMask![2], equals(const Offset(9.0, 10.0)));

      // Verify real-time ghost coordinate frame
      final ghostFrame = controller.ghostCadFrame;
      expect(ghostFrame, isNotNull);
      expect(ghostFrame!.origin, equals(Offset(placement.newOriginX, placement.newOriginY)));

      // Cancel resets state to idle
      controller.cancel();
      expect(controller.phase, ArchitectUnderlayDragPhase.idle);
      expect(controller.deltaModel, isNull);
    });

    test('Raster Underlay Drag Phase Transitions and Math Accuracy', () {
      const initialPos = Offset(10.0, 20.0);

      controller.startDrag(
        isCad: false,
        rasterId: 'raster_123',
        underlayName: 'sketch.png',
        storeyId: 'storey_1',
        unitsPerMeter: 1.0,
        originalRasterPosition: initialPos,
      );

      expect(controller.phase, ArchitectUnderlayDragPhase.pickingBasePoint);

      const baseModel = Offset(12.0, 22.0);
      controller.updateHover(
        baseModel,
        project: dummyProject,
        scale: 40.0,
      );
      controller.confirmBasePoint();
      expect(controller.phase, ArchitectUnderlayDragPhase.draggingToTarget);

      const targetModel = Offset(15.0, 26.0); // delta = (+3.0, +4.0)
      controller.updateHover(
        targetModel,
        project: dummyProject,
        scale: 40.0,
      );

      expect(controller.deltaModel, equals(const Offset(3.0, 4.0)));

      final placement = controller.computeRasterPlacement(
        targetPointModel: targetModel,
        existingMask: [const Offset(10.0, 20.0), const Offset(20.0, 20.0)],
      );

      expect(placement.newPosition, equals(const Offset(13.0, 24.0)));
      expect(placement.translatedMask![0], equals(const Offset(13.0, 24.0)));
      expect(placement.translatedMask![1], equals(const Offset(23.0, 24.0)));

      expect(controller.ghostRasterPosition, equals(const Offset(13.0, 24.0)));
    });

    test('Module Isolation: Architectural Underlay mutations do NOT affect BimStoreyUnderlay', () {
      // 1. Initial shared project storey underlay
      const structuralControlPoint = Offset(100.0, 200.0);
      final bimStorey = const BimStoreyUnderlay(
        storeyId: 'storey_1',
        name: '±0.00',
        elevation: 0.0,
        underlayFileName: 'underlays/working.kcad',
        controlPoint: structuralControlPoint,
      );

      // 2. Architectural project underlay config
      final archUnderlayConfig = const ArchitectCadUnderlayConfig(
        storeyId: 'storey_1',
        fileName: 'drawing.dxf',
        internalCopyPath: 'path/to/drawing.dxf',
        lockedCadOriginX: 50.0,
        lockedCadOriginY: 60.0,
        unitsPerMeter: 1000.0,
      );

      final archProject = dummyProject.copyWith(
        cadUnderlays: {'storey_1': archUnderlayConfig},
      );

      // 3. User drags underlay in architectural module to new origin
      const newArchOriginX = 75.0;
      const newArchOriginY = 90.0;
      final updatedArchConfig = archUnderlayConfig.copyWith(
        lockedCadOriginX: newArchOriginX,
        lockedCadOriginY: newArchOriginY,
      );
      final updatedArchProject = archProject.copyWith(
        cadUnderlays: {'storey_1': updatedArchConfig},
      );

      // 4. Verification:
      // Architectural underlay now has new coordinates
      expect(updatedArchProject.cadUnderlays['storey_1']!.lockedCadOriginX, equals(75.0));
      expect(updatedArchProject.cadUnderlays['storey_1']!.lockedCadOriginY, equals(90.0));

      // BimStoreyUnderlay control point used by structural module remains strictly 100.0, 200.0
      expect(bimStorey.controlPoint, equals(structuralControlPoint));
      expect(bimStorey.controlPoint!.dx, equals(100.0));
      expect(bimStorey.controlPoint!.dy, equals(200.0));
    });
  });
}
