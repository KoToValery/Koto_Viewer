import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_line_geometry.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/adapters/architect_element_adapters.dart';

void main() {
  test(
    'common projections/intersections retain finite versus reference-line rules',
    () {
      expect(
        BimLineGeometry.closest(
          const Offset(3, 2),
          Offset.zero,
          const Offset(2, 0),
        ),
        const Offset(2, 0),
      );
      expect(
        BimLineGeometry.intersection(
          Offset.zero,
          const Offset(1, 0),
          const Offset(2, -1),
          const Offset(2, 1),
        ),
        const Offset(2, 0),
      );
      expect(
        BimLineGeometry.intersection(
          Offset.zero,
          const Offset(1, 0),
          const Offset(2, -1),
          const Offset(2, 1),
          firstFinite: true,
        ),
        isNull,
      );
      expect(
        BimLineGeometry.intersection(
          Offset.zero,
          Offset.zero,
          const Offset(2, -1),
          const Offset(2, 1),
        ),
        isNull,
      );
      expect(
        BimLineGeometry.hostedFits(length: 6, width: 1, ratio: .5),
        isTrue,
      );
      expect(
        BimLineGeometry.hostedFits(length: 6, width: 1, ratio: .01),
        isFalse,
      );
    },
  );
  test(
    'wall Drag+ clone rebinds independent hosted identities and carries their properties',
    () {
      const wall = ArchitectWall(
        id: 'wall',
        startPoint: Offset.zero,
        endPoint: Offset(6, 0),
        thickness: .4,
        insulationThicknessOverride: .12,
        referenceLine: WallReferenceLine.outer,
        exteriorSide: WallExteriorSide.right,
        doors: [
          ArchitectDoor(
            id: 'door',
            wallId: 'wall',
            offsetRatio: .3,
            width: .9,
            height: 2.2,
            uuid: 'door-uuid',
            styleId: 'custom-door',
            isHingeLeft: false,
          ),
        ],
        windows: [
          ArchitectWindow(
            id: 'window',
            wallId: 'wall',
            offsetRatio: .7,
            uuid: 'window-uuid',
            styleId: 'custom-window',
            sillHeight: .92,
          ),
        ],
      );
      final tool = ArchitectElementTool();
      addTearDown(tool.dispose);
      final (floor, copyId) = tool.duplicateElementById(
        const ArchitectStorey(id: 'f', name: 'Floor', walls: [wall]),
        'wall',
        offset: Offset.zero,
      );
      final clone = floor.walls.last;
      expect(clone.id, copyId);
      expect(clone.doors.single.wallId, clone.id);
      expect(clone.windows.single.wallId, clone.id);
      expect(clone.doors.single.id, isNot(wall.doors.single.id));
      expect(clone.doors.single.uuid, isNot(wall.doors.single.uuid));
      expect(clone.windows.single.uuid, isNot(wall.windows.single.uuid));
      expect(clone.doors.single.styleId, 'custom-door');
      expect(clone.doors.single.isHingeLeft, isFalse);
      expect(clone.windows.single.sillHeight, .92);
      final project = ArchitectProject(
        id: 'p',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 'f',
        storeys: [floor],
      );
      final moved = MoveArchitectElement(
        storeyId: 'f',
        elementId: copyId!,
        delta: const Offset(3, 2),
        carryConnections: false,
      ).apply(project);
      expect(moved.activeStorey.walls.first.toJson(), wall.toJson());
      expect(moved.activeStorey.walls.last.startPoint, const Offset(3, 2));
      expect(moved.activeStorey.walls.last.endPoint, const Offset(9, 2));
      expect(
        moved.activeStorey.walls.last.doors.single.toJson(),
        clone.doors.single.toJson(),
      );
      expect(moved.activeStorey.walls.last.insulationThickness, .12);
      expect(moved.activeStorey.walls.last.referenceLine, wall.referenceLine);
    },
  );
  test(
    'special-element translations preserve arbitrary contour and metadata fields',
    () {
      const source = ArchitectCadPrimitive(
        id: 'rect',
        type: CadPrimitiveType.rect,
        startPoint: Offset.zero,
        endPoint: Offset(4, 3),
        polygon: [Offset.zero, Offset(3, 1), Offset(4, 3), Offset(1, 2)],
      );
      final moved = const ArchitectCadEditingAdapter().translate(
        source,
        const Offset(2, -1),
      );
      expect(moved.polygon!.first, const Offset(2, -1));
      expect(moved.polygon!.last, const Offset(3, 1));
      expect(moved.type, source.type);
      const stair = ArchitectStair(
        id: 'stair',
        startPoint: Offset.zero,
        endPoint: Offset(3, 4),
        width: 1.3,
        hasLanding: true,
        stepCount: 19,
      );
      final stairMoved = const ArchitectStairEditingAdapter().translate(
        stair,
        const Offset(1, 1),
      );
      expect(stairMoved.startPoint, const Offset(1, 1));
      expect(stairMoved.stepCount, 19);
      expect(stairMoved.hasLanding, isTrue);
    },
  );
}
