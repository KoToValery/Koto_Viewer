import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_exterior_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_exterior_resolver.dart';

ArchitectWall openWall({
  required String id,
  required Offset start,
  required Offset end,
  String? wallTypeId,
  ArchitectWallLocation? location,
  bool? parapet,
  double thickness = 0.25,
  double height = 2.80,
  WallExteriorSide exteriorSide = WallExteriorSide.left,
}) {
  return ArchitectWall(
    id: id,
    startPoint: start,
    endPoint: end,
    wallTypeId: wallTypeId,
    location: location,
    parapet: parapet,
    thickness: thickness,
    height: height,
    exteriorSide: exteriorSide,
  );
}

void main() {
  group('ArchitectWallExteriorResolver - Interior, 25cm Exterior and Parapets', () {
    test('Interior walls are always exteriorResolved = true and never unresolved', () {
      final interiorWall = openWall(
        id: 'w_int',
        start: Offset.zero,
        end: const Offset(4, 0),
        wallTypeId: 'int_12_partition',
        location: ArchitectWallLocation.interior,
        thickness: 0.12,
      );

      expect(interiorWall.isInterior, isTrue);
      expect(interiorWall.isExterior, isFalse);

      final storey = ArchitectStorey(id: 's', name: 's', walls: [interiorWall]);
      final resolvedStorey = ArchitectWallExteriorResolver.resolveStorey(storey);
      final resolved = resolvedStorey.walls.first;

      expect(resolved.exteriorResolved, isTrue);
      expect(resolved.location, ArchitectWallLocation.interior);
      expect(ArchitectWallExteriorPainter.hitTest(resolved, const Offset(2, 0.5), 1.0), isFalse);
    });

    test('25 cm exterior walls without insulation (ext_25_brick) are isExterior = true', () {
      final ext25Wall = openWall(
        id: 'w_ext25',
        start: Offset.zero,
        end: const Offset(5, 0),
        wallTypeId: 'ext_25_brick',
        thickness: 0.25,
        location: ArchitectWallLocation.exterior,
      );

      expect(ext25Wall.isExterior, isTrue);
      expect(ext25Wall.hasInsulation, isFalse);

      // In open / single mode before loop closure
      final storey = ArchitectStorey(id: 's', name: 's', walls: [ext25Wall]);
      final resolvedStorey = ArchitectWallExteriorResolver.resolveStorey(storey);
      final resolved = resolvedStorey.walls.first;

      expect(resolved.isExterior, isTrue);

      // Arrow position is on normal * exteriorSign
      final n = ext25Wall.normalAt(0.5) * ext25Wall.exteriorSign;
      final face = ext25Wall.centerPointAt(0.5) + n * (ext25Wall.thickness / 2);
      const scale = 50.0;
      final arrowCenter = face + n * (11.5 / scale);

      // Hit test directly on arrow
      expect(ArchitectWallExteriorPainter.hitTest(resolved, arrowCenter, scale), isTrue);

      // Hit test away from arrow
      expect(ArchitectWallExteriorPainter.hitTest(resolved, face + n * 2.0, scale), isFalse);
    });

    test('25 cm uninsulated walls resolve correctly in closed rectangular loop', () {
      final p = [
        Offset.zero,
        const Offset(6, 0),
        const Offset(6, 4),
        const Offset(0, 4),
      ];
      final walls = [
        for (var i = 0; i < 4; i++)
          openWall(
            id: 'w_$i',
            start: p[i],
            end: p[(i + 1) % 4],
            wallTypeId: 'ext_25_brick',
            thickness: 0.25,
            location: ArchitectWallLocation.exterior,
          ),
      ];

      final storey = ArchitectStorey(id: 's', name: 's', walls: walls);
      final resolvedStorey = ArchitectWallExteriorResolver.resolveStorey(storey);

      for (final w in resolvedStorey.walls) {
        expect(w.isExterior, isTrue);
        expect(w.exteriorResolved, isTrue);
        expect(w.exteriorSide, WallExteriorSide.right);
      }
    });

    test('Parapets have isParapet = true, isExterior = true, and support hitTest and mirror', () {
      final parapet = openWall(
        id: 'p_1',
        start: Offset.zero,
        end: const Offset(3, 0),
        wallTypeId: 'parapet_12',
        thickness: 0.12,
        height: 1.05,
        parapet: true,
        location: ArchitectWallLocation.exterior,
        exteriorSide: WallExteriorSide.left,
      );

      expect(parapet.isParapet, isTrue);
      expect(parapet.isExterior, isTrue);

      // Verify hitTest works for parapets now
      final n = parapet.normalAt(0.5) * parapet.exteriorSign;
      final face = parapet.centerPointAt(0.5) + n * (parapet.thickness / 2);
      const scale = 50.0;
      final arrowCenter = face + n * (11.5 / scale);
      expect(ArchitectWallExteriorPainter.hitTest(parapet, arrowCenter, scale), isTrue);
      expect(ArchitectWallExteriorPainter.hitTest(parapet, face + n * 2.0, scale), isFalse);

      // Parapets stay excluded from room analysis
      final analysis = ArchitectWallExteriorResolver.analyze([parapet]);
      expect(analysis.containsKey('p_1'), isFalse);
    });

    test('MirrorArchitectWalls flips exteriorSide and marks exteriorResolved = true', () {
      final initialWall = openWall(
        id: 'flip_wall',
        start: Offset.zero,
        end: const Offset(4, 0),
        wallTypeId: 'ext_25_brick',
        thickness: 0.25,
        location: ArchitectWallLocation.exterior,
        exteriorSide: WallExteriorSide.left,
      );

      final project = ArchitectProject.starterWithCatalog(name: 'test', storeyCount: 1).copyWith(
        activeStoreyId: 's',
        storeys: [ArchitectStorey(id: 's', name: 's', walls: [initialWall])],
      );

      final controller = ArchitectCommandController(project);
      addTearDown(controller.dispose);

      controller.execute(
        const MirrorArchitectWalls(storeyId: 's', wallIds: {'flip_wall'}),
      );

      final updated = controller.project.activeStorey.walls.first;
      expect(updated.exteriorSide, WallExteriorSide.right);
      expect(updated.exteriorSideMode, WallResolutionMode.manual);
      expect(updated.exteriorResolved, isTrue);
    });

    test('Multi-wall chain flip flips all selected walls simultaneously', () {
      final chain = [
        openWall(id: 'c1', start: Offset.zero, end: const Offset(4, 0), exteriorSide: WallExteriorSide.left),
        openWall(id: 'c2', start: const Offset(4, 0), end: const Offset(4, 4), exteriorSide: WallExteriorSide.left),
        openWall(id: 'c3', start: const Offset(4, 4), end: const Offset(0, 4), exteriorSide: WallExteriorSide.left),
      ];

      final project = ArchitectProject.starterWithCatalog(name: 'test', storeyCount: 1).copyWith(
        activeStoreyId: 's',
        storeys: [ArchitectStorey(id: 's', name: 's', walls: chain)],
      );

      final controller = ArchitectCommandController(project);
      addTearDown(controller.dispose);

      controller.execute(
        const MirrorArchitectWalls(storeyId: 's', wallIds: {'c1', 'c2', 'c3'}),
      );

      for (final w in controller.project.activeStorey.walls) {
        expect(w.exteriorSide, WallExteriorSide.right);
        expect(w.exteriorSideMode, WallResolutionMode.manual);
        expect(w.exteriorResolved, isTrue);
      }
    });
  });
}
