import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_component.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';

void main() {
  group('ArchitectElementTool - Multi-Delete and Quick Menu Deletion', () {
    late ArchitectElementTool tool;
    late ArchitectStorey baseStorey;

    setUp(() {
      tool = ArchitectElementTool();
      const wall1 = ArchitectWall(
        id: 'w1',
        startPoint: Offset(0, 0),
        endPoint: Offset(5, 0),
        thickness: 0.25,
      );
      const wall2 = ArchitectWall(
        id: 'w2',
        startPoint: Offset(5, 0),
        endPoint: Offset(5, 5),
        thickness: 0.25,
      );
      const comp1 = ArchitectComponentInstance(
        id: 'comp1',
        definitionId: 'service_chimney',
        position: Offset(2, 0.5),
      );
      const zone1 = ArchitectZone(
        id: 'z1',
        name: 'Living Room',
        category: ArchitectZoneCategory.living,
        polygon: [
          Offset(0, 0),
          Offset(5, 0),
          Offset(5, 5),
          Offset(0, 5),
        ],
      );

      baseStorey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        walls: [wall1, wall2],
        components: [comp1],
        zones: [zone1],
      );
    });

    test('deleteElementById deletes component instance cleanly', () {
      final updated = tool.deleteElementById(baseStorey, 'comp1');
      expect(updated.components.any((c) => c.id == 'comp1'), isFalse);
      expect(updated.walls.length, 2);
      expect(updated.zones.length, 1);
    });

    test('deleteElementById deletes zone cleanly', () {
      final updated = tool.deleteElementById(baseStorey, 'z1');
      expect(updated.zones.any((z) => z.id == 'z1'), isFalse);
      expect(updated.walls.length, 2);
      expect(updated.components.length, 1);
    });

    test('deleteElementsByIds deletes mixed elements (walls, components, zones) in one pass', () {
      final updated = tool.deleteElementsByIds(baseStorey, {'w1', 'comp1', 'z1'});
      expect(updated.walls.map((w) => w.id), ['w2']);
      expect(updated.components, isEmpty);
      expect(updated.zones, isEmpty);
    });

    test('deleteElementsByIds handles empty set without modifying storey', () {
      final updated = tool.deleteElementsByIds(baseStorey, {});
      expect(updated, equals(baseStorey));
    });
  });
}
