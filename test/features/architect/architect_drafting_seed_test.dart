import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drafting_seed.dart';
import 'package:kotoview/src/features/architect/services/architect_workspace_view_controller.dart';

import 'architect_editing_test.dart' as editing;

void main() {
  test(
    'Inherited defaults share the placement transaction and preserve source, geometry, and editable controls',
    () {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: '',
          walls: [
            ArchitectWall(
              id: 'source',
              startPoint: Offset.zero,
              endPoint: Offset(3, 0),
              thickness: .2,
              height: 3.4,
              baseOffset: .2,
              followStoreyHeight: false,
              doors: [
                ArchitectDoor(
                  id: 'source-door',
                  wallId: 'source',
                  offsetRatio: .5,
                  uuid: 'source-door',
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      final original = model.project;
      final seed = ArchitectDraftingSeed.fromSelection(original, 'source')!;
      final view = ArchitectWorkspaceViewController(model)
        ..prepareCreation = seed.apply;
      addTearDown(view.dispose);
      view.execute(
        const CreateArchitectWall(
          storeyId: 's',
          wall: ArchitectWall(
            id: 'new',
            startPoint: Offset(0, 4),
            endPoint: Offset(5, 4),
            thickness: .3,
          ),
        ),
      );
      final placed = model.project.activeStorey.walls.last;
      expect(placed.startPoint, const Offset(0, 4));
      expect(placed.endPoint, const Offset(5, 4));
      expect(
        placed.thickness,
        .3,
      ); // A live tool edit supersedes its initial seed.
      expect(placed.height, 3.4);
      expect(placed.baseOffset, .2);
      expect(placed.followStoreyHeight, isFalse);
      expect(placed.doors, isEmpty);
      expect(
        model.project.activeStorey.walls.first.toJson(),
        original.activeStorey.walls.first.toJson(),
      );
      model.undo();
      expect(model.project.toJson(), original.toJson());
      expect(model.canUndo, isFalse);
      model.redo();
      expect(model.project.activeStorey.walls.last.height, 3.4);
    },
  );

  test(
    'Hosted defaults preserve new host, placement, identity and dimensions',
    () {
      final original = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: '',
          walls: [
            ArchitectWall(
              id: 'source',
              startPoint: Offset.zero,
              endPoint: Offset(6, 0),
              doors: [
                ArchitectDoor(
                  id: 'old',
                  wallId: 'source',
                  offsetRatio: .2,
                  uuid: 'old',
                  frameThickness: .08,
                ),
              ],
            ),
            ArchitectWall(
              id: 'target',
              startPoint: Offset(0, 3),
              endPoint: Offset(6, 3),
            ),
          ],
        ),
      );
      addTearDown(original.dispose);
      final seed = ArchitectDraftingSeed.fromSelection(
        original.project,
        'old',
      )!;
      final target = original.project.activeStorey.walls.last.addDoor(
        const ArchitectDoor(
          id: 'new',
          wallId: 'target',
          offsetRatio: .7,
          uuid: 'new',
          width: 1.2,
        ),
      );
      final next = original.project.updateActiveStorey(
        original.project.activeStorey.copyWith(
          walls: [original.project.activeStorey.walls.first, target],
        ),
      );
      final result = seed
          .apply(original.project, next)
          .activeStorey
          .walls
          .last
          .doors
          .single;
      expect(result.wallId, 'target');
      expect(result.id, 'new');
      expect(result.uuid, 'new');
      expect(result.offsetRatio, .7);
      expect(result.width, 1.2);
      expect(result.frameThickness, .08);
    },
  );

  test(
    'Hatch defaults carry print style without copying the source polygon or holes',
    () {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: '',
          cadPrimitives: [
            ArchitectCadPrimitive(
              id: 'old',
              type: CadPrimitiveType.hatch,
              startPoint: Offset.zero,
              endPoint: Offset(4, 4),
              polygon: [Offset.zero, Offset(4, 0), Offset(4, 4), Offset(0, 4)],
              holes: [
                [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)],
              ],
              hatchScale: 2,
              hatchAngle: 32,
              hatchBorder: false,
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      final seed = ArchitectDraftingSeed.fromSelection(model.project, 'old')!;
      final old = model.project.activeStorey;
      const fresh = ArchitectCadPrimitive(
        id: 'new',
        type: CadPrimitiveType.hatch,
        startPoint: Offset(5, 0),
        endPoint: Offset(7, 2),
        polygon: [Offset(5, 0), Offset(7, 0), Offset(7, 2), Offset(5, 2)],
      );
      final result = seed
          .apply(
            model.project,
            model.project.updateActiveStorey(
              old.copyWith(cadPrimitives: [...old.cadPrimitives, fresh]),
            ),
          )
          .activeStorey
          .cadPrimitives
          .last;
      expect(result.polygon, fresh.polygon);
      expect(result.holes, isEmpty);
      expect(result.hatchScale, 2);
      expect(result.hatchAngle, 32);
      expect(result.hatchBorder, isFalse);
      expect(
        ArchitectDraftingSeed.toolFor(model.project, 'old'),
        ArchitectTool.hatch,
      );
      expect(ArchitectDraftingSeed.toolFor(model.project, 'missing'), isNull);
    },
  );
}
