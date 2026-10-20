import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_snap.dart';

ArchitectProject roofSnapProject({String? group}) => ArchitectProject(
  id: 'p',
  name: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [
    ArchitectStorey(
      id: 's',
      name: '',
      height: 3,
      roofs: [
        ArchitectRoofPlane(
          id: 'left',
          storeyId: 's',
          roofGroupId: group,
          points: const [
            Offset(0, 0),
            Offset(4, 0),
            Offset(4, 4),
            Offset(0, 4),
          ],
          eavesEdgeIndex: 3,
          slopeDegrees: 25,
          baseElevationOffset: 3,
          attachToWalls: false,
          placementResolved: true,
          eavesOverhang: 0,
        ),
        ArchitectRoofPlane(
          id: 'right',
          storeyId: 's',
          roofGroupId: group,
          points: const [
            Offset(4, 0),
            Offset(8, 0),
            Offset(8, 4),
            Offset(4, 4),
          ],
          eavesEdgeIndex: 1,
          slopeDegrees: 25,
          baseElevationOffset: 3.25,
          attachToWalls: false,
          placementResolved: true,
          eavesOverhang: 0,
        ),
      ],
    ),
  ],
);

const roofSnapCut = ArchitectSection(
  id: 'cut',
  start: Offset(-1, 2),
  end: Offset(9, 2),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'independent roof slopes snap their real ridge edges and persist one move',
    () {
      final controller = ArchitectCommandController(roofSnapProject());
      addTearDown(controller.dispose);
      final p = controller.project;
      final data = ArchitectBuildingSection.build(p, roofSnapCut);
      final snap = ArchitectProjectionSnap(
        p,
        data.elementPaths,
        'right',
        roofProfiles: data.roofProfiles,
      );
      final result = snap.resolve(
        const Offset(0, -.22),
        .05,
        horizontal: false,
      );
      expect(result.contact, isNotNull);
      expect(result.delta.dx, 0);
      expect(result.delta.dy, closeTo(-.25, 1e-5));
      controller.commit(
        ArchitectProjectionEditing.move(
          p,
          'right',
          result.delta,
          roofSnapCut.axis,
          elevation: false,
        ),
      );
      expect(controller.undoCount, 1);
      final roof = controller.project.activeStorey.roofs.last;
      expect(roof.baseElevationOffset, closeTo(3, 1e-5));
      expect(roof.points, p.activeStorey.roofs.last.points);
      expect(roof.slopeDegrees, 25);
      controller.undo();
      expect(
        controller.project.activeStorey.roofs.last.baseElevationOffset,
        3.25,
      );
      controller.redo();
      expect(
        controller.project.activeStorey.roofs.last.baseElevationOffset,
        closeTo(3, 1e-5),
      );
      final reopened = ArchitectProject.fromJson(controller.project.toJson());
      expect(
        reopened.activeStorey.roofs.last.baseElevationOffset,
        closeTo(3, 1e-5),
      );
      expect(
        snap.resolve(const Offset(0, .8), .001, horizontal: false).contact,
        isNull,
      );
    },
  );

  test('roof group members cannot attract one another during a group move', () {
    final p = roofSnapProject(group: 'gable');
    final data = ArchitectBuildingSection.build(p, roofSnapCut);
    final snap = ArchitectProjectionSnap(
      p,
      data.elementPaths,
      'right',
      roofProfiles: data.roofProfiles,
    );
    final result = snap.resolve(const Offset(0, -.22), .05, horizontal: false);
    expect(snap.movingIds, {'left', 'right'});
    expect(result.delta, const Offset(0, -.22));
    expect(result.contact, isNull);
  });

  test(
    'section snaps a sloping underside to a wall cap without shifting the plan',
    () {
      final p = roofSnapProject().copyWith(
        storeys: [
          roofSnapProject().activeStorey.copyWith(
            walls: const [
              ArchitectWall(
                id: 'wall',
                startPoint: Offset(2, 0),
                endPoint: Offset(2, 4),
              ),
            ],
          ),
        ],
      );
      // The support contact lies inside the roof edge, away from its corners.
      final paths = {
        'left': Path()
          ..addPolygon(const [
            Offset(0, 3.2),
            Offset(4, 4.2),
            Offset(4, 4.4),
            Offset(0, 3.4),
          ], true),
        'wall': Path()..addRect(const Rect.fromLTRB(1.9, 0, 2.1, 3)),
      };
      final snap = ArchitectProjectionSnap(p, paths, 'left');
      final result = snap.resolve(
        const Offset(0, -.65),
        .04,
        horizontal: false,
      );
      expect(result.contact, isNotNull);
      expect(result.delta.dx, 0);
      // First contact at the higher wall corner, with no penetration.
      expect(result.delta.dy, closeTo(-.675, 1e-6));
    },
  );
}
