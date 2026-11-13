import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';

ArchitectProject _project(List<ArchitectWall> walls) => ArchitectProject(
  id: 'opening-properties',
  name: 'Opening properties',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [ArchitectStorey(id: 's', name: 'Floor', walls: walls)],
);

ArchitectWall _placedAtJamb({required bool magnetic}) {
  const wall = ArchitectWall(
    id: 'host',
    startPoint: Offset.zero,
    endPoint: Offset(3, 0),
  );
  final placement = ArchitectOpeningPlacement.resolve(
    walls: [wall],
    rawPoint: const Offset(.45, 0),
    openingWidth: .9,
    magnetic: magnetic,
    defaultHingeLeft: true,
  )!;
  expect(placement.offsetRatio, closeTo(.15, 1e-12));
  // A legal placement loses a fraction of a floating-point unit on reread.
  if (magnetic) {
    expect(placement.offsetRatio * wall.length, lessThan(.9 / 2));
  }
  return wall.copyWith(
    doors: [
      ArchitectDoor(
        id: 'door',
        wallId: wall.id,
        offsetRatio: placement.offsetRatio,
        width: .9,
        isHingeLeft: placement.isHingeLeft,
        openInward: placement.openInward,
        uuid: 'door-uuid',
      ),
    ],
  );
}

void main() {
  for (final magnetic in [false, true]) {
    test('accepted jamb placement stays editable, magnetic=$magnetic', () {
      final wall = _placedAtJamb(magnetic: magnetic);
      final model = ArchitectCommandController(_project([wall]));
      addTearDown(model.dispose);
      final before = jsonEncode(model.project.toJson());
      model.execute(
        const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'door'},
          values: {'height': 2.1},
          textValues: {
            'isHingeLeft': 'false',
            'openInward': 'false',
            'hasCasing': 'true',
          },
        ),
      );
      final door = model.project.activeStorey.walls.single.doors.single;
      expect(door.isHingeLeft, isFalse);
      expect(door.openInward, isFalse);
      expect(door.hasCasing, isTrue);
      expect(door.height, 2.1);
      expect(door.offsetRatio, wall.doors.single.offsetRatio);
      expect(door.uuid, 'door-uuid');
      expect(model.undoCount, 1);
      final after = jsonEncode(model.project.toJson());
      final restored = ArchitectProject.fromJson(jsonDecode(after));
      expect(
        restored.activeStorey.walls.single.doors.single.toJson(),
        door.toJson(),
      );
      model.undo();
      expect(jsonEncode(model.project.toJson()), before);
      model.redo();
      expect(jsonEncode(model.project.toJson()), after);
    });
  }

  test('resizing to a jamb uses the same tolerance as placement', () {
    final wall = _placedAtJamb(magnetic: true);
    for (final window in [false, true]) {
      final host = wall.copyWith(
        doors: window ? [] : [wall.doors.single.copyWith(width: .8)],
        windows: window
            ? [
                const ArchitectWindow(
                  id: 'window',
                  wallId: 'host',
                  offsetRatio: .15,
                  width: .8,
                  uuid: 'window-uuid',
                ),
              ]
            : [],
      );
      final next = SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {window ? 'window' : 'door'},
        values: const {'width': .9},
      ).apply(_project([host]));
      final updated = next.activeStorey.walls.single;
      expect(
        window ? updated.windows.single.width : updated.doors.single.width,
        .9,
      );
      expect(
        window
            ? updated.windows.single.offsetRatio
            : updated.doors.single.offsetRatio,
        .15,
      );
    }
  });

  test('unmodified openings do not block edits elsewhere on the floor', () {
    final boundary = _placedAtJamb(magnetic: false);
    final editedHost = boundary.copyWith(
      id: 'other-host',
      startPoint: const Offset(0, 4),
      endPoint: const Offset(3, 4),
      doors: [
        boundary.doors.single.copyWith(
          id: 'other-door',
          wallId: 'other-host',
          offsetRatio: .5,
        ),
      ],
    );
    // Old project data may also contain an opening that genuinely crosses its
    // host. An unrelated edit must leave that opening exactly as it was.
    final legacy = boundary.copyWith(
      id: 'legacy-host',
      startPoint: const Offset(0, 8),
      endPoint: const Offset(1, 8),
      doors: [
        boundary.doors.single.copyWith(
          id: 'legacy-door',
          wallId: 'legacy-host',
          offsetRatio: .1,
        ),
      ],
    );
    final next = const SetArchitectElementProperties(
      storeyId: 's',
      elementIds: {'other-door'},
      values: {'width': 1.2},
    ).apply(_project([boundary, editedHost, legacy]));
    expect(next.activeStorey.walls[1].doors.single.width, 1.2);
    expect(next.activeStorey.walls.first.toJson(), boundary.toJson());
    expect(next.activeStorey.walls.last.toJson(), legacy.toJson());
  });

  test('real width overflow still rejects atomically', () {
    final model = ArchitectCommandController(
      _project([_placedAtJamb(magnetic: false)]),
    );
    addTearDown(model.dispose);
    final before = jsonEncode(model.project.toJson());
    expect(
      () => model.execute(
        const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'door'},
          values: {'width': 1},
        ),
      ),
      throwsArgumentError,
    );
    expect(jsonEncode(model.project.toJson()), before);
    expect(model.undoCount, 0);
  });

  test('curved hosts retain their physical chord-width constraints', () {
    const arc = ArchitectWall(
      id: 'arc',
      startPoint: Offset.zero,
      endPoint: Offset(4, 0),
      arcBulge: .5,
    );
    final wall = arc.copyWith(
      doors: [
        ArchitectDoor(
          id: 'door',
          wallId: 'arc',
          offsetRatio: .45 / arc.length,
          width: .7,
          uuid: 'arc-door',
        ),
      ],
    );
    wall.validateGeometry();
    final project = _project([wall]);
    final fitting = const SetArchitectElementProperties(
      storeyId: 's',
      elementIds: {'door'},
      values: {'width': .8},
    ).apply(project);
    fitting.activeStorey.walls.single.validateGeometry();
    expect(
      () => const SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'door'},
        values: {'width': .9},
      ).apply(project),
      throwsArgumentError,
    );
  });
}
