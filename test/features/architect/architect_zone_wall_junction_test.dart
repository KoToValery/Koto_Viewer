import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_network.dart';
import 'package:kotoview/src/features/architect/services/architect_room_detector.dart';

void main() {
  // Three edge-referenced walls meet at (4, 3). Their separate rectangular
  // bodies only touch at a corner; the joined plan fills the missing mitre.
  List<ArchitectWall> walls({bool open = false}) => [
    for (final (id, start, end) in [
      ('top', const Offset(0, 0), const Offset(8, 0)),
      ('right', const Offset(8, 0), const Offset(8, 6)),
      ('bottom', const Offset(8, 6), const Offset(0, 6)),
      ('left', const Offset(0, 6), const Offset(0, 0)),
    ])
      ArchitectWall(id: id, startPoint: start, endPoint: end, thickness: .25),
    ArchitectWall(
      id: 'upper',
      startPoint: const Offset(4, 0),
      endPoint: open ? const Offset(4, 2.5) : const Offset(4, 3),
      thickness: .12,
      referenceLine: WallReferenceLine.right,
    ),
    const ArchitectWall(
      id: 'lower',
      startPoint: Offset(4, 3),
      endPoint: Offset(4, 6),
      thickness: .25,
      referenceLine: WallReferenceLine.left,
    ),
    const ArchitectWall(
      id: 'branch',
      startPoint: Offset(4, 3),
      endPoint: Offset(8, 3),
      thickness: .25,
      referenceLine: WallReferenceLine.right,
    ),
  ];

  ArchitectZone zone(List<Offset> polygon, Offset seed, String id) =>
      ArchitectZone(
        id: id,
        name: id,
        category: ArchitectZoneCategory.custom,
        polygon: polygon,
        seedPoint: seed,
        isAutoBoundary: true,
      );

  for (final degrees in [0, 15, 37, 90]) {
    for (final cellSize in [.05, .025]) {
      test(
        'three-wall junction separates rooms at $degrees degrees / $cellSize',
        () {
          final angle = degrees * math.pi / 180;
          Offset transform(Offset p) => Offset(
            p.dx * math.cos(angle) - p.dy * math.sin(angle) + .013,
            p.dx * math.sin(angle) + p.dy * math.cos(angle) + .027,
          );
          final network = [
            for (final wall in walls())
              wall.copyWith(
                startPoint: transform(wall.startPoint),
                endPoint: transform(wall.endPoint),
              ),
          ];
          // This is a closed junction in the actual plan geometry.
          expect(
            ArchitectWallNetwork.body(
              network,
            ).contains(transform(const Offset(3.95, 3.1))),
            isTrue,
          );
          final seeds = [
            transform(const Offset(2, 3)),
            transform(const Offset(6, 1.5)),
            transform(const Offset(6, 4.5)),
          ];
          final zones = <ArchitectZone>[];
          for (var i = 0; i < seeds.length; i++) {
            final polygon = ArchitectRoomDetector.detectRoomPolygon(
              seedPoint: seeds[i],
              walls: network,
              targetCellSize: cellSize,
            );
            expect(polygon, isNotNull);
            final detected = zone(polygon!, seeds[i], 'room$i');
            expect(detected.containsPoint(seeds[i]), isTrue);
            for (var j = 0; j < seeds.length; j++) {
              if (i != j) expect(detected.containsPoint(seeds[j]), isFalse);
            }
            expect(
              detected.containsPoint(transform(const Offset(3.95, 3.1))),
              isFalse,
              reason:
                  'The room must not include the solid closing the junction',
            );
            expect(
              detected.area,
              inInclusiveRange(i == 0 ? 19 : 8, i == 0 ? 24 : 12),
            );
            zones.add(detected);
          }
          expect(
            ArchitectRoomDetector.detectMergedZones(
              existingZones: zones,
              remainingWalls: network,
            ),
            isNull,
          );
        },
      );
    }
  }

  test('a real opening at the junction still connects the adjoining rooms', () {
    final network = walls(open: true);
    const leftSeed = Offset(2, 3), rightSeed = Offset(6, 1.5);
    final polygon = ArchitectRoomDetector.detectRoomPolygon(
      seedPoint: leftSeed,
      walls: network,
    );
    expect(polygon, isNotNull);
    final detected = zone(polygon!, leftSeed, 'left');
    expect(detected.containsPoint(rightSeed), isTrue);
    expect(detected.containsPoint(const Offset(6, 4.5)), isFalse);
    expect(
      ArchitectRoomDetector.detectMergedZones(
        existingZones: [detected, zone(polygon, rightSeed, 'right')],
        remainingWalls: network,
      ),
      isNotNull,
    );
  });
}
