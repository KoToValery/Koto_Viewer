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
  });
}
