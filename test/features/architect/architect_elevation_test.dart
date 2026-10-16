import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';

const facade = ArchitectElevation(
  id: 'e',
  start: Offset(-1, -2),
  end: Offset(9, -2),
);

ArchitectProject elevationProject({bool markers = true}) {
  final storeys = <ArchitectStorey>[];
  for (var i = 0; i < 2; i++) {
    final wall = ArchitectWall(
      id: 'front$i',
      startPoint: Offset.zero,
      endPoint: const Offset(8, 0),
      height: 3,
      thickness: .3,
      windows: [
        for (var j = 0; j < (i == 0 ? 2 : 3); j++)
          ArchitectWindow(
            id: 'w$i$j',
            uuid: 'w$i$j',
            wallId: 'front$i',
            offsetRatio: .2 + j * .3,
            width: 1.3,
            height: 1.4,
            sillHeight: .9,
          ),
      ],
      doors: i == 0
          ? [
              const ArchitectDoor(
                id: 'd',
                uuid: 'd',
                wallId: 'front0',
                offsetRatio: .8,
                width: 1,
                height: 2.2,
              ),
            ]
          : [],
    );
    storeys.add(
      ArchitectStorey(
        id: 's$i',
        name: '$i',
        height: 3,
        elevation: i * 3,
        walls: [
          wall,
          ArchitectWall(
            id: 'back$i',
            startPoint: const Offset(0, 5),
            endPoint: const Offset(8, 5),
            height: 3,
          ),
          ArchitectWall(
            id: 'left$i',
            startPoint: Offset.zero,
            endPoint: const Offset(0, 5),
            height: 3,
          ),
          ArchitectWall(
            id: 'right$i',
            startPoint: const Offset(8, 0),
            endPoint: const Offset(8, 5),
            height: 3,
          ),
        ],
        slabs: [
          ArchitectSlab(
            id: 'slab$i',
            polygon: const [
              Offset(0, 0),
              Offset(8, 0),
              Offset(8, 5),
              Offset(0, 5),
            ],
            thickness: .2,
          ),
        ],
      ),
    );
  }
  return ArchitectProject(
    id: 'p',
    name: 'Test',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    activeStoreyId: 's0',
    storeys: storeys,
    elevations: markers ? [facade] : [],
    northSymbol: markers
        ? const ArchitectNorthSymbol(position: Offset(-2, -2))
        : null,
  );
}

List<Triangle3D> panel(double x0, double x1, double y, double z0, double z1) {
  final a = Vector3(x0, y, z0),
      b = Vector3(x1, y, z0),
      c = Vector3(x1, y, z1),
      d = Vector3(x0, y, z1);
  return [Triangle3D(v0: a, v1: b, v2: c), Triangle3D(v0: a, v1: c, v2: d)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const view = ArchitectElevation(
    id: 'view',
    start: Offset(-5, -2),
    end: Offset(5, -2),
  );
  test(
    'all compass directions, reversed view and full rotations use the outward normal',
    () {
      expect(view.compassDirection(0), ArchitectCompassDirection.north);
      expect(
        view.compassDirection(math.pi / 2),
        ArchitectCompassDirection.west,
      );
      expect(
        view.copyWith(viewSide: -1).compassDirection(0),
        ArchitectCompassDirection.south,
      );
      for (var i = -16; i < 16; i++) {
        expect(
          view.compassDirection(-i * math.pi / 4),
          ArchitectCompassDirection.values[i % 8],
        );
      }
      final diagonal = view.copyWith(end: const Offset(5, 8));
      expect(diagonal.compassDirection(0), ArchitectCompassDirection.northEast);
    },
  );
  test(
    'project JSON and history preserve markers and north without changing building coordinates',
    () {
      final original = elevationProject();
      final controller = ArchitectCommandController(original);
      addTearDown(controller.dispose);
      final before = jsonEncode(
        controller.project.storeys.map((s) => s.toJson()).toList(),
      );
      controller.commit(
        controller.project.copyWith(
          northSymbol: const ArchitectNorthSymbol(
            position: Offset(12, 3),
            angle: math.pi / 2,
          ),
        ),
      );
      expect(
        controller.project.elevations.single.compassDirection(
          controller.project.northSymbol!.angle,
        ),
        ArchitectCompassDirection.west,
      );
      expect(
        jsonEncode(controller.project.storeys.map((s) => s.toJson()).toList()),
        before,
      );
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(controller.project.toJson()))
            as Map<String, dynamic>,
      );
      expect(restored.elevations.single.toJson(), facade.toJson());
      expect(
        restored.northSymbol!.toJson(),
        controller.project.northSymbol!.toJson(),
      );
      controller.undo();
      expect(controller.project.northSymbol!.angle, 0);
      controller.redo();
      expect(controller.project.northSymbol!.angle, math.pi / 2);
      final legacy = original.toJson()
        ..remove('elevations')
        ..remove('northSymbol');
      expect(ArchitectProject.fromJson(legacy).elevations, isEmpty);
      expect(ArchitectProject.fromJson(legacy).northSymbol, isNull);
    },
  );
  test(
    'coplanar triangles, T junctions and storey seams unite into one outline',
    () {
      final drawing = ArchitectBuildingElevation.fromTriangles([
        ...panel(-3, 0, 0, 0, 4),
        ...panel(0, 3, 0, 0, 2),
        ...panel(0, 3, 0, 2, 4),
      ], view);
      expect(drawing.faces, hasLength(1));
      final contours = drawing.faces.single.computeMetrics().toList();
      expect(contours, hasLength(1));
      expect(contours.single.length, closeTo(20, 1e-5));
      expect(drawing.bounds, const Rect.fromLTRB(-3, 0, 3, 4));
    },
  );
  test('rear faces are removed exactly; exposed rear portions survive', () {
    final hidden = ArchitectBuildingElevation.fromTriangles([
      ...panel(-3, 3, 0, 0, 4),
      ...panel(-2, 2, 2, 1, 3),
    ], view);
    expect(hidden.faces, hasLength(1));
    final partial = ArchitectBuildingElevation.fromTriangles([
      ...panel(-1, 1, 0, 0, 4),
      ...panel(-3, 3, 2, 0, 4),
    ], view);
    expect(partial.faces, hasLength(2));
    expect(
      partial.faces.where((p) => p.contains(const Offset(0, 2))),
      hasLength(1),
    );
    expect(
      partial.faces.where((p) => p.contains(const Offset(2, 2))),
      hasLength(1),
    );
    expect(partial.bounds, const Rect.fromLTRB(-3, 0, 3, 4));
  });
  test(
    'flush material boundaries and window frame divisions remain visible',
    () {
      final surface = panel(-3, 0, 0, 0, 4);
      final trim = panel(0, 3, 0, 0, 4).map(
        (t) => Triangle3D(
          v0: t.v0,
          v1: t.v1,
          v2: t.v2,
          color: const Color(0xff444444),
        ),
      );
      final drawing = ArchitectBuildingElevation.fromTriangles([
        ...surface,
        ...trim,
      ], view);
      expect(drawing.faces, hasLength(2));
      final project = elevationProject().copyWith(
        storeys: [
          const ArchitectStorey(
            id: 's0',
            name: '',
            walls: [
              ArchitectWall(
                id: 'w',
                startPoint: Offset(-3, 0),
                endPoint: Offset(3, 0),
                thickness: .3,
                windows: [
                  ArchitectWindow(
                    id: 'win',
                    wallId: 'w',
                    uuid: 'win',
                    offsetRatio: .5,
                    sillHeight: .9,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final facade = ArchitectBuildingElevation.build(project, view);
      // The recessed glass is clipped by the mullion into two visible panes.
      expect(
        facade.faces.any(
          (p) =>
              (p.getBounds().width - 1.1).abs() < 1e-4 &&
              p.computeMetrics().length == 2,
        ),
        isTrue,
      );
    },
  );
  test(
    'marker span and near plane clip actual geometry without a preview slab',
    () {
      final clipped = ArchitectBuildingElevation.fromTriangles([
        ...panel(-10, 10, 0, 0, 3),
        ...panel(-10, 10, -4, 0, 10),
      ], view);
      expect(clipped.bounds, const Rect.fromLTRB(-5, 0, 5, 3));
      final empty = elevationProject(markers: false).copyWith(storeys: []);
      expect(ArchitectBuildingElevation.build(empty, view).faces, isEmpty);
      final wallOnly = empty.copyWith(
        storeys: [
          const ArchitectStorey(
            id: 'wall',
            name: '',
            walls: [
              ArchitectWall(
                id: 'w',
                startPoint: Offset(-3, 0),
                endPoint: Offset(3, 0),
                thickness: .3,
              ),
            ],
          ),
        ],
      );
      final actual = ArchitectBuildingElevation.build(wallOnly, view);
      expect(actual.bounds.left, -3);
      expect(actual.bounds.right, 3);
      expect(actual.bounds.top, 0);
      expect(actual.faces, hasLength(1));
    },
  );
  test('intersecting sloped planes split at their depth crossing', () {
    final slope = [
      Triangle3D(
        v0: const Vector3(-3, -1, 0),
        v1: const Vector3(3, 1, 0),
        v2: const Vector3(3, 1, 4),
      ),
      Triangle3D(
        v0: const Vector3(-3, -1, 0),
        v1: const Vector3(3, 1, 4),
        v2: const Vector3(-3, -1, 4),
      ),
    ];
    final drawing = ArchitectBuildingElevation.fromTriangles([
      ...panel(-3, 3, 0, 0, 4),
      ...slope,
    ], view);
    expect(drawing.faces, hasLength(2));
    for (final x in [-2.0, 2.0]) {
      expect(
        drawing.faces.where((p) => p.contains(Offset(x, 2))),
        hasLength(1),
      );
    }
  });
  test(
    'rotated facade is an orthogonal projection along its own viewing direction',
    () {
      const rotated = ArchitectElevation(
        id: 'r',
        start: Offset(-3, -3),
        end: Offset(3, 3),
      );
      final shifted = rotated.copyWith(
        start: rotated.start - rotated.viewDirection * 2,
        end: rotated.end - rotated.viewDirection * 2,
      );
      final drawing = ArchitectBuildingElevation.fromTriangles([
        Triangle3D(
          v0: const Vector3(-2, -2, 0),
          v1: const Vector3(2, 2, 0),
          v2: const Vector3(2, 2, 3),
        ),
        Triangle3D(
          v0: const Vector3(-2, -2, 0),
          v1: const Vector3(2, 2, 3),
          v2: const Vector3(-2, -2, 3),
        ),
      ], shifted);
      expect(drawing.faces, hasLength(1));
      expect(drawing.bounds.width, closeTo(4 * math.sqrt(2), 1e-6));
      expect(drawing.bounds.height, 3);
    },
  );
}
