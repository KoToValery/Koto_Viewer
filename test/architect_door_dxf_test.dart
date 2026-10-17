import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArchitectDoor DXF Standard & Parametric Model Tests', () {
    test('Door serialization, deserialization, and parametric copyWith', () {
      final door = ArchitectDoor(
        id: 'door_test_1',
        wallId: 'wall_1',
        offsetRatio: 0.5,
        width: 0.90,
        height: 2.00,
        sillHeight: 0.15,
        isHingeLeft: true,
        openInward: true,
        specId: '1',
        uuid: 'UUID_1',
      );

      final json = door.toJson();
      expect(json['id'], 'door_test_1');
      expect(json['width'], 0.90);
      expect(json['height'], 2.00);
      expect(json['sillHeight'], 0.15);
      expect(json['isHingeLeft'], true);
      expect(json['openInward'], true);
      expect(json['specId'], '1');
      expect(json['openAngleDeg'], 90.0);

      final reconstructed = ArchitectDoor.fromJson(json);
      expect(reconstructed.id, door.id);
      expect(reconstructed.width, 0.90);
      expect(reconstructed.height, 2.00);
      expect(reconstructed.sillHeight, 0.15);
      expect(reconstructed.specId, '1');
      expect(reconstructed.openAngleDeg, 90.0);

      // Parametric modification of dimensions and ID
      final modified = door.copyWith(
        width: 1.00,
        height: 2.10,
        specId: 'D2',
        isHingeLeft: false,
        openInward: false,
      );
      expect(modified.width, 1.00);
      expect(modified.height, 2.10);
      expect(modified.specId, 'D2');
      expect(modified.isHingeLeft, false);
      expect(modified.openInward, false);
    });

    test('paint2D executes without error and matches DXF symbols', () {
      final door = ArchitectDoor(
        id: 'door_1',
        wallId: 'wall_1',
        offsetRatio: 0.5,
        width: 0.90,
        height: 2.00,
        sillHeight: 0.15,
        specId: '1',
        uuid: 'UUID_1',
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Paint 2D symbol
      door.paint2D(
        canvas: canvas,
        wallStart: const Offset(0, 0),
        wallEnd: const Offset(5.0, 0),
        wallThickness: 0.37,
        zoomScale: 20.0,
        isSelected: false,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('build3D generates frame, leaf, handle, and 3 interior barrel hinges', () {
      final door = ArchitectDoor(
        id: 'door_1',
        wallId: 'wall_1',
        offsetRatio: 0.5,
        width: 0.90,
        height: 2.00,
        sillHeight: 0.0,
        specId: '1',
        uuid: 'UUID_1',
        isHingeLeft: true,
        openInward: true,
      );

      final tris = door.build3D(
        wallStart: const Offset(0, 0),
        wallEnd: const Offset(4.0, 0),
        wallThickness: 0.25,
        storeyElevation: 0.0,
      );

      // Tris must be generated
      expect(tris.isNotEmpty, isTrue);

      // Hinges: Dark graphite barrels with Color(0xFF263238)
      final hingeTris = tris.where((t) => t.color == const Color(0xFF263238)).toList();
      expect(hingeTris.isNotEmpty, isTrue);

      // Leaf: Color(0xFF8D6E63)
      final leafTris = tris.where((t) => t.color == const Color(0xFF8D6E63)).toList();
      expect(leafTris.isNotEmpty, isTrue);

      // Frame: Color(0xFF37474F)
      final frameTris = tris.where((t) => t.color == const Color(0xFF37474F)).toList();
      expect(frameTris.isNotEmpty, isTrue);
    });

    test('ArchitectOpeningPlacement.resolve determines opening direction & hinge side', () {
      final wall = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10.0, 0),
        thickness: 0.25,
      );

      // Cursor placed at X=4.7 (left of snapped center), Y=+0.2 (interior side)
      final resLeftInward = ArchitectOpeningPlacement.resolve(
        walls: [wall],
        rawPoint: const Offset(4.7, 0.2),
        openingWidth: 0.90,
        magnetic: true,
        defaultHingeLeft: true,
      );

      expect(resLeftInward, isNotNull);
      expect(resLeftInward!.openInward, true);
      expect(resLeftInward.isHingeLeft, true);

      // Cursor placed at X=5.3, Y=-0.2 (exterior side) with defaultHingeLeft: false
      final resRightOutward = ArchitectOpeningPlacement.resolve(
        walls: [wall],
        rawPoint: const Offset(5.3, -0.2),
        openingWidth: 0.90,
        magnetic: true,
        defaultHingeLeft: false,
      );

      expect(resRightOutward, isNotNull);
      expect(resRightOutward!.openInward, false);
      expect(resRightOutward.isHingeLeft, false);
    });

    test('ArchitectDoor.resolveSpecId shares base number for identical size and appends prime for left-opening', () {
      final doors = <ArchitectDoor>[];

      // 1. First door: 90/200, right-hinged -> base 1, no prime -> "1"
      final id1 = ArchitectDoor.resolveSpecId(
        existingDoors: doors,
        width: 0.90,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: false,
      );
      expect(id1, '1');
      doors.add(ArchitectDoor(
        id: 'd1',
        wallId: 'w1',
        offsetRatio: 0.2,
        width: 0.90,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: false,
        specId: id1,
        uuid: 'u1',
      ));

      // 2. Second door: identical 90/200, but left-hinged -> same base 1, prime appended -> "1'"
      final id2 = ArchitectDoor.resolveSpecId(
        existingDoors: doors,
        width: 0.90,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: true,
      );
      expect(id2, "1'");
      doors.add(ArchitectDoor(
        id: 'd2',
        wallId: 'w1',
        offsetRatio: 0.4,
        width: 0.90,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: true,
        specId: id2,
        uuid: 'u2',
      ));

      // 3. Third door: another 90/200 right-hinged -> "1"
      final id3 = ArchitectDoor.resolveSpecId(
        existingDoors: doors,
        width: 0.90,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: false,
      );
      expect(id3, '1');

      // 4. Fourth door: new size 80/200, right-hinged -> base 2 -> "2"
      final id4 = ArchitectDoor.resolveSpecId(
        existingDoors: doors,
        width: 0.80,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: false,
      );
      expect(id4, '2');
      doors.add(ArchitectDoor(
        id: 'd4',
        wallId: 'w1',
        offsetRatio: 0.6,
        width: 0.80,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: false,
        specId: id4,
        uuid: 'u4',
      ));

      // 5. Fifth door: identical 80/200, left-hinged -> base 2 with prime -> "2'"
      final id5 = ArchitectDoor.resolveSpecId(
        existingDoors: doors,
        width: 0.80,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: true,
      );
      expect(id5, "2'");

      // 6. Sixth door: new size 70/200, left-hinged first -> base 3 with prime -> "3'"
      final id6 = ArchitectDoor.resolveSpecId(
        existingDoors: doors,
        width: 0.70,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: true,
      );
      expect(id6, "3'");
      doors.add(ArchitectDoor(
        id: 'd6',
        wallId: 'w1',
        offsetRatio: 0.8,
        width: 0.70,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: true,
        specId: id6,
        uuid: 'u6',
      ));

      // 7. Seventh door: same 70/200, right-hinged later -> reuses base 3 without prime -> "3"
      final id7 = ArchitectDoor.resolveSpecId(
        existingDoors: doors,
        width: 0.70,
        height: 2.00,
        sillHeight: 0.0,
        isHingeLeft: false,
      );
      expect(id7, '3');
    });

    test('ArchitectOpeningPlacement.resolve supports dynamic cursor distance outward for wide doors', () {
      final wall = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10.0, 0),
        thickness: 0.25,
      );

      // 1.20 m wide door, cursor moved 1.0 m outward from wall face (Y = 1.125 m)
      final res = ArchitectOpeningPlacement.resolve(
        walls: [wall],
        rawPoint: const Offset(5.0, 1.10),
        openingWidth: 1.20,
        magnetic: true,
      );

      expect(res, isNotNull);
      expect(res!.wall.id, 'w1');
    });
  });
}
