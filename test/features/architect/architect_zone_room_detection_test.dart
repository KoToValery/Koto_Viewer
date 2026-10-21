import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_room_detector.dart';
import 'package:kotoview/src/features/architect/services/architect_zone_tool.dart';
import 'package:kotoview/src/features/architect/rendering/architect_zone_painter_helper.dart';

void main() {
  group('ArchitectZone Model & Properties Tests', () {
    test('ArchitectZone defaults and custom properties are correctly populated', () {
      const poly = [
        Offset(0, 0),
        Offset(4, 0),
        Offset(4, 3),
        Offset(0, 3),
      ];

      final zone = ArchitectZone(
        id: 'zone_101',
        number: '1',
        name: 'Спалня',
        category: ArchitectZoneCategory.bedroom,
        polygon: poly,
        floorFinish: 'Ламинат 8мм',
        wallFinish: 'Латекс светъл',
        ceilingFinish: 'Гипсокартон с латекс',
        clearHeight: 2.70,
        isAutoBoundary: true,
        seedPoint: const Offset(2, 1.5),
      );

      expect(zone.id, 'zone_101');
      expect(zone.number, '1');
      expect(zone.name, 'Спалня');
      expect(zone.category, ArchitectZoneCategory.bedroom);
      expect(zone.floorFinish, 'Ламинат 8мм');
      expect(zone.wallFinish, 'Латекс светъл');
      expect(zone.ceilingFinish, 'Гипсокартон с латекс');
      expect(zone.clearHeight, 2.70);
      expect(zone.isAutoBoundary, isTrue);
      expect(zone.seedPoint, const Offset(2, 1.5));
      expect(zone.area, closeTo(12.0, 0.01));
      expect(zone.perimeter, closeTo(14.0, 0.01));
    });

    test('ArchitectZone toJson and fromJson preserve all properties', () {
      const poly = [
        Offset(1, 1),
        Offset(5, 1),
        Offset(5, 4),
        Offset(1, 4),
      ];

      final original = ArchitectZone(
        id: 'zone_202',
        number: '2',
        name: 'Дневна',
        category: ArchitectZoneCategory.living,
        polygon: poly,
        floorFinish: 'Гранитогрес 60x60',
        wallFinish: 'Миеща се боя',
        ceilingFinish: 'Окачен таван',
        clearHeight: 2.80,
        isAutoBoundary: false,
        seedPoint: const Offset(3, 2.5),
      );

      final json = original.toJson();
      final restored = ArchitectZone.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.number, '2');
      expect(restored.name, 'Дневна');
      expect(restored.category, ArchitectZoneCategory.living);
      expect(restored.floorFinish, 'Гранитогрес 60x60');
      expect(restored.wallFinish, 'Миеща се боя');
      expect(restored.ceilingFinish, 'Окачен таван');
      expect(restored.clearHeight, 2.80);
      expect(restored.isAutoBoundary, isFalse);
      expect(restored.seedPoint, const Offset(3, 2.5));
      expect(restored.polygon.length, 4);
    });

    test('Standard catalogs for room finishes contain expected presets', () {
      final l10n = lookupAppLocalizations(const Locale('bg'));
      expect(ArchitectZone.standardFloorFinishes(l10n), isNotEmpty);
      expect(ArchitectZone.standardWallFinishes(l10n), isNotEmpty);
      expect(ArchitectZone.standardCeilingFinishes(l10n), isNotEmpty);

      expect(
        ArchitectZone.standardFloorFinishes(l10n)
            .contains(l10n.architectZoneFloorLaminate),
        isTrue,
      );
      expect(
        ArchitectZone.standardWallFinishes(l10n)
            .contains(l10n.architectZoneWallLatex),
        isTrue,
      );
      expect(
        ArchitectZone.standardCeilingFinishes(l10n)
            .contains(l10n.architectZoneCeilingLatex),
        isTrue,
      );
    });

    test('ArchitectStorey serializes and restores zoneScheduleOrigin', () {
      final storey = ArchitectStorey(
        id: 'storey_1',
        name: 'Партер',
        elevation: 0.0,
        height: 3.0,
        zoneScheduleOrigin: const Offset(12.5, 8.0),
      );

      final json = storey.toJson();
      final restored = ArchitectStorey.fromJson(json);

      expect(restored.zoneScheduleOrigin, const Offset(12.5, 8.0));

      final cleared = restored.copyWith(clearZoneScheduleOrigin: true);
      expect(cleared.zoneScheduleOrigin, isNull);
    });
  });

  group('ArchitectRoomDetector Tests', () {
    // Construct a standard 4m x 3m enclosed room made of 4 walls (0.25m thickness)
    List<ArchitectWall> createEnclosedRoom({
      double x = 0,
      double y = 0,
      double w = 4.0,
      double h = 3.0,
      double thickness = 0.25,
    }) {
      return [
        // Bottom wall
        ArchitectWall(
          id: 'w_bottom',
          startPoint: Offset(x, y),
          endPoint: Offset(x + w, y),
          thickness: thickness,
        ),
        // Right wall
        ArchitectWall(
          id: 'w_right',
          startPoint: Offset(x + w, y),
          endPoint: Offset(x + w, y + h),
          thickness: thickness,
        ),
        // Top wall
        ArchitectWall(
          id: 'w_top',
          startPoint: Offset(x + w, y + h),
          endPoint: Offset(x, y + h),
          thickness: thickness,
        ),
        // Left wall
        ArchitectWall(
          id: 'w_left',
          startPoint: Offset(x, y + h),
          endPoint: Offset(x, y),
          thickness: thickness,
        ),
      ];
    }

    test('detectRoomPolygon finds boundary of enclosed rectangular room', () {
      final walls = createEnclosedRoom(x: 0, y: 0, w: 4, h: 3);
      final seed = const Offset(2.0, 1.5);

      final polygon = ArchitectRoomDetector.detectRoomPolygon(
        seedPoint: seed,
        walls: walls,
      );

      expect(polygon, isNotNull);
      expect(polygon!.length, greaterThanOrEqualTo(4));

      // Check that the seed point is strictly inside the detected polygon
      final zone = ArchitectZone(
        id: 'z_test',
        name: 'Test Room',
        category: ArchitectZoneCategory.bedroom,
        polygon: polygon,
      );
      expect(zone.containsPoint(seed), isTrue);

      // Room area should be reasonably close to clear inner area:
      // ~ (4 - 0.25) * (3 - 0.25) = 3.75 * 2.75 = 10.31 m²
      final area = ArchitectZoneGeometry.calculateArea(polygon);
      expect(area, greaterThan(8.0));
      expect(area, lessThan(12.5));
    });

    test('detectRoomPolygon returns null when space is wide open / leaks outside', () {
      // 3 walls with one missing side (open room)
      final openWalls = [
        const ArchitectWall(
          id: 'w1',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
          thickness: 0.25,
        ),
        const ArchitectWall(
          id: 'w2',
          startPoint: Offset(4, 0),
          endPoint: Offset(4, 3),
          thickness: 0.25,
        ),
        const ArchitectWall(
          id: 'w3',
          startPoint: Offset(4, 3),
          endPoint: Offset(0, 3),
          thickness: 0.25,
        ),
        // Missing w4 (left wall)
      ];

      final polygon = ArchitectRoomDetector.detectRoomPolygon(
        seedPoint: const Offset(2, 1.5),
        walls: openWalls,
      );

      // Leak detection must prevent filling entire canvas and return null
      expect(polygon, isNull);
    });

    test('detectMergedZones discovers rooms that become continuous when dividing wall is deleted', () {
      // Create two adjacent rooms: Room A (0..4, 0..3) and Room B (4..8, 0..3)
      // Dividing wall is at x = 4.
      // If we remove the dividing wall at x = 4, they form one single large room (0..8, 0..3).
      final perimeterWalls = [
        const ArchitectWall(
          id: 'w_bottom',
          startPoint: Offset(0, 0),
          endPoint: Offset(8, 0),
          thickness: 0.25,
        ),
        const ArchitectWall(
          id: 'w_right',
          startPoint: Offset(8, 0),
          endPoint: Offset(8, 3),
          thickness: 0.25,
        ),
        const ArchitectWall(
          id: 'w_top',
          startPoint: Offset(8, 3),
          endPoint: Offset(0, 3),
          thickness: 0.25,
        ),
        const ArchitectWall(
          id: 'w_left',
          startPoint: Offset(0, 3),
          endPoint: Offset(0, 0),
          thickness: 0.25,
        ),
      ];

      final zoneA = ArchitectZone(
        id: 'zone_a',
        number: '1',
        name: 'Стая 1',
        category: ArchitectZoneCategory.bedroom,
        polygon: const [
          Offset(0.2, 0.2),
          Offset(3.8, 0.2),
          Offset(3.8, 2.8),
          Offset(0.2, 2.8),
        ],
        seedPoint: const Offset(2.0, 1.5),
        isAutoBoundary: true,
      );

      final zoneB = ArchitectZone(
        id: 'zone_b',
        number: '2',
        name: 'Стая 2',
        category: ArchitectZoneCategory.bedroom,
        polygon: const [
          Offset(4.2, 0.2),
          Offset(7.8, 0.2),
          Offset(7.8, 2.8),
          Offset(4.2, 2.8),
        ],
        seedPoint: const Offset(6.0, 1.5),
        isAutoBoundary: true,
      );

      final mergeCandidate = ArchitectRoomDetector.detectMergedZones(
        existingZones: [zoneA, zoneB],
        remainingWalls: perimeterWalls,
      );

      expect(mergeCandidate, isNotNull);
      expect(mergeCandidate!.zoneA.id, 'zone_a');
      expect(mergeCandidate.zoneB.id, 'zone_b');
      expect(mergeCandidate.mergedPolygon.length, greaterThanOrEqualTo(4));

      // Merged area should span both rooms (~ 8 * 3 = ~24 m²)
      final mergedArea = ArchitectZoneGeometry.calculateArea(
        mergeCandidate.mergedPolygon,
      );
      expect(mergedArea, greaterThan(18.0));
      expect(mergedArea, lessThan(26.0));
    });
  });

  group('ArchitectZoneTool Integration Tests', () {
    test('createAutoZone factory builds compliant zone with custom finishes and auto boundary', () {
      final tool = ArchitectZoneTool();

      final zone = tool.createAutoZone(
        polygon: const [
          Offset(0, 0),
          Offset(5, 0),
          Offset(5, 4),
          Offset(0, 4),
        ],
        seedPoint: const Offset(2.5, 2.0),
        category: ArchitectZoneCategory.kitchen,
        name: 'Кухня с трапезария',
        number: '3',
        floorFinish: 'Теракота',
        wallFinish: 'Латекс',
        ceilingFinish: 'Гипсокартон',
        clearHeight: 2.65,
      );

      expect(zone.id.startsWith('zone_'), isTrue);
      expect(zone.number, '3');
      expect(zone.name, 'Кухня с трапезария');
      expect(zone.category, ArchitectZoneCategory.kitchen);
      expect(zone.isAutoBoundary, isTrue);
      expect(zone.seedPoint, const Offset(2.5, 2.0));
      expect(zone.floorFinish, 'Теракота');
      expect(zone.wallFinish, 'Латекс');
      expect(zone.ceilingFinish, 'Гипсокартон');
      expect(zone.clearHeight, 2.65);
    });

    test('commitDrafting supports custom number and auto boundary flag', () {
      final tool = ArchitectZoneTool();
      tool.placementMode = ArchitectZonePlacementMode.manualPoints;

      tool.startDrafting(const Offset(0, 0));
      tool.addDraftingPoint(const Offset(4, 0));
      tool.addDraftingPoint(const Offset(4, 3));
      tool.addDraftingPoint(const Offset(0, 3));

      final committed = tool.commitDrafting(
        category: ArchitectZoneCategory.living,
        defaultName: 'Дневна',
        number: '4',
      );

      expect(committed, isNotNull);
      expect(committed!.number, '4');
      expect(committed.name, 'Дневна');
      expect(committed.category, ArchitectZoneCategory.living);
      expect(committed.polygon.length, 4);
      expect(tool.isDrafting, isFalse);
    });

    test('toggling placementMode between autoClick and manualPoints', () {
      final tool = ArchitectZoneTool();
      expect(tool.placementMode, ArchitectZonePlacementMode.autoClick);

      tool.placementMode = ArchitectZonePlacementMode.manualPoints;
      expect(tool.placementMode, ArchitectZonePlacementMode.manualPoints);

      tool.placementMode = ArchitectZonePlacementMode.autoClick;
      expect(tool.placementMode, ArchitectZonePlacementMode.autoClick);
    });
  });

  group('ArchitectZoneScheduleTable Tests', () {
    test('getZoneTableTotalHeight calculates exact sum of title, header, rows and footer', () {
      final height1 = ArchitectZonePainterHelper.getZoneTableTotalHeight(1);
      expect(
        height1,
        ArchitectZonePainterHelper.zoneTableTitleHeight +
            ArchitectZonePainterHelper.zoneTableHeaderHeight +
            ArchitectZonePainterHelper.zoneTableRowHeight +
            ArchitectZonePainterHelper.zoneTableFooterHeight,
      );

      final height3 = ArchitectZonePainterHelper.getZoneTableTotalHeight(3);
      expect(
        height3,
        height1 + 2 * ArchitectZonePainterHelper.zoneTableRowHeight,
      );
    });

    test('zone table bounds and hit testing stay fixed across camera zooms', () {
      final zone1 = ArchitectZone(
        id: 'z1',
        number: '1',
        name: 'Антре',
        category: ArchitectZoneCategory.corridor,
        polygon: const [Offset(0, 0), Offset(2, 0), Offset(2, 3), Offset(0, 3)],
        floorFinish: 'Теракота',
        wallFinish: 'Латекс',
        ceilingFinish: 'Латекс',
      );
      final zone2 = ArchitectZone(
        id: 'z2',
        number: '2',
        name: 'Спалня',
        category: ArchitectZoneCategory.bedroom,
        polygon: const [Offset(2, 0), Offset(6, 0), Offset(6, 4), Offset(2, 4)],
        floorFinish: 'Ламинат',
        wallFinish: 'Латекс',
        ceilingFinish: 'Латекс',
      );

      final storey = ArchitectStorey(
        id: 'st_1',
        name: 'Етаж 1',
        zones: [zone1, zone2],
        zoneScheduleOrigin: const Offset(10.0, 15.0),
      );

      const zoom = 50.0;
      const drawingScale = ArchitectZonePainterHelper.zoneTableDrawingScale;
      final bounds = ArchitectZonePainterHelper.getZoneTableBounds(
        storey: storey,
        origin: storey.zoneScheduleOrigin!,
        zoomScale: zoom,
      );

      expect(bounds.left, 10.0);
      expect(bounds.top, 15.0);
      expect(
        bounds.width,
        closeTo(
          ArchitectZonePainterHelper.zoneTableTotalWidth / drawingScale,
          1e-4,
        ),
      );
      final expectedHeight =
          ArchitectZonePainterHelper.getZoneTableTotalHeight(2) / drawingScale;
      expect(bounds.height, closeTo(expectedHeight, 1e-4));

      // Hit testing inside bounds
      expect(bounds.contains(const Offset(10.1, 15.1)), isTrue);
      expect(bounds.contains(bounds.center), isTrue);

      // Zooming changes the screen footprint, never the model-space hit area.
      for (final cameraZoom in [5.0, 20.0, 80.0, 200.0]) {
        final zoomedBounds = ArchitectZonePainterHelper.getZoneTableBounds(
          storey: storey,
          origin: storey.zoneScheduleOrigin!,
          zoomScale: cameraZoom,
        );
        expect(zoomedBounds, bounds);
        expect(zoomedBounds.contains(bounds.center), isTrue);
        expect(
          zoomedBounds.contains(Offset(bounds.right + .01, bounds.center.dy)),
          isFalse,
        );
      }

      // Hit testing outside bounds
      expect(bounds.contains(const Offset(9.9, 15.0)), isFalse);
      expect(bounds.contains(const Offset(10.0, 14.9)), isFalse);
      expect(bounds.contains(const Offset(50.0, 50.0)), isFalse);
    });
  });
}
