import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';

void main() {
  group('ArchitectDoor & Window 2D Hit Testing Tests', () {
    const wallStart = Offset(0, 0);
    const wallEnd = Offset(10, 0);
    const wallThickness = 0.25;

    final door = ArchitectDoor(
      id: 'd1',
      wallId: 'w1',
      offsetRatio: 0.5, // at (5, 0)
      width: 0.9,
      height: 2.0,
      sillHeight: 0.0,
      isHingeLeft: true,
      openInward: true, // leaf swings toward +Y
      specId: '1',
      uuid: 'UUID-D1',
    );

    final window = ArchitectWindow(
      id: 'win1',
      wallId: 'w1',
      offsetRatio: 0.2, // at (2, 0)
      width: 1.2,
      height: 1.4,
      sillHeight: 0.85,
      specId: 'W1',
      uuid: 'UUID-WIN1',
    );

    test('ArchitectDoor containsPoint hits corridor, leaf, and ID badge accurately', () {
      // 1. Center of opening on the wall
      expect(
        door.containsPoint(
          const Offset(5.0, 0.0),
          wallStart: wallStart,
          wallEnd: wallEnd,
          wallThickness: wallThickness,
        ),
        isTrue,
      );

      // 2. Door leaf swinging into the room (around (5.45, 0.5))
      expect(
        door.containsPoint(
          const Offset(5.45, 0.40),
          wallStart: wallStart,
          wallEnd: wallEnd,
          wallThickness: wallThickness,
        ),
        isTrue,
      );

      // 3. ID circle badge outside the wall face (at Y = 0.25/2 + 0.22 + 0.16 = 0.505m)
      expect(
        door.containsPoint(
          const Offset(5.0, 0.50),
          wallStart: wallStart,
          wallEnd: wallEnd,
          wallThickness: wallThickness,
        ),
        isTrue,
      );

      // 4. Far away point (miss)
      expect(
        door.containsPoint(
          const Offset(5.0, 2.5),
          wallStart: wallStart,
          wallEnd: wallEnd,
          wallThickness: wallThickness,
        ),
        isFalse,
      );
    });

    test('ArchitectElementTool hitTestElements picks door when tapping leaf or badge', () {
      final wall = ArchitectWall(
        id: 'w1',
        startPoint: wallStart,
        endPoint: wallEnd,
        thickness: wallThickness,
        doors: [door],
        windows: [window],
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        walls: [wall],
      );

      final elementTool = ArchitectElementTool();

      // Tap on leaf in the room
      final hitOnLeaf = elementTool.hitTestElement(storey, const Offset(5.45, 0.40), 20.0);
      expect(hitOnLeaf, equals('d1'));

      // Tap on ID badge
      final hitOnBadge = elementTool.hitTestElement(storey, const Offset(5.0, 0.50), 20.0);
      expect(hitOnBadge, equals('d1'));

      // Tap on window opening
      final hitOnWin = elementTool.hitTestElement(storey, const Offset(2.0, 0.0), 20.0);
      expect(hitOnWin, equals('win1'));
    });
  });
}
