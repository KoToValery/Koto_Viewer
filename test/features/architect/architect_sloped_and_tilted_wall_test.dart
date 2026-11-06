import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/architect/models/architect_roof.dart';
import 'package:kotoview/src/features/architect/models/architect_roof_settings.dart';

void main() {
  group('ArchitectWall Sloped Top (Gable / Калкан)', () {
    test('Calculates slope and height interpolation along wall', () {
      final wall = ArchitectWall(
        id: 'gable_wall_1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.25,
        height: 2.80,
        endHeight: 5.80,
        clipToRoof: false,
      );

      expect(wall.isSlopedTop, isTrue);
      expect(wall.heightAtRatio(0.0), closeTo(2.80, 1e-4));
      expect(wall.heightAtRatio(1.0), closeTo(5.80, 1e-4));
      expect(wall.heightAtRatio(0.5), closeTo(4.30, 1e-4));

      // Delta H = 3.0m, Length = 6.0m -> atan(3/6) = atan(0.5) ~ 26.565 deg, 50%
      expect(wall.topSlopeDegrees, closeTo(26.565, 0.01));
      expect(wall.topSlopePercent, closeTo(50.0, 0.01));

      // heightAtPoint
      expect(wall.heightAtPoint(const Offset(3, 0)), closeTo(4.30, 1e-4));
      expect(wall.heightAtPoint(const Offset(0, 0)), closeTo(2.80, 1e-4));
      expect(wall.heightAtPoint(const Offset(6, 0)), closeTo(5.80, 1e-4));
    });

    test('toJson and fromJson preserves sloped and tilted wall parameters', () {
      final original = ArchitectWall(
        id: 'gable_wall_json',
        startPoint: const Offset(1, 2),
        endPoint: const Offset(7, 2),
        thickness: 0.30,
        height: 3.00,
        endHeight: 4.80,
        tiltAngle: 15.0,
        clipToRoof: false,
      );

      final json = original.toJson();
      expect(json['endHeight'], 4.80);
      expect(json['tiltAngle'], 15.0);
      expect(json['clipToRoof'], false);

      final restored = ArchitectWall.fromJson(json);
      expect(restored.id, 'gable_wall_json');
      expect(restored.height, 3.00);
      expect(restored.endHeight, 4.80);
      expect(restored.tiltAngle, 15.0);
      expect(restored.clipToRoof, false);
      expect(restored.isSlopedTop, isTrue);
      expect(restored.isTilted, isTrue);
    });

    test('3D mesh generation creates trapezoidal solid with sloped top', () {
      final wall = ArchitectWall(
        id: 'gable_3d',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.20,
        height: 2.00,
        endHeight: 4.00,
        baseOffset: 0.0,
      );

      final triangles = wall.build3D(
        storeyElevation: 10.0,
        resolveComposition: false,
      );
      expect(triangles, isNotEmpty);

      // Find top vertices at start (x ~ 0) and end (x ~ 4)
      final allVertices = triangles.expand((t) => [t.v0, t.v1, t.v2]).toList();

      final verticesAtStart = allVertices.where((v) => v.x.abs() < 1e-3);
      final verticesAtEnd = allVertices.where((v) => (v.x - 4.0).abs() < 1e-3);

      final maxZStart = verticesAtStart.map((v) => v.z).reduce(math.max);
      final maxZEnd = verticesAtEnd.map((v) => v.z).reduce(math.max);

      // At start (x=0), Z top should be storeyElevation (10.0) + height (2.0) = 12.0
      expect(maxZStart, closeTo(12.00, 1e-3));
      // At end (x=4), Z top should be storeyElevation (10.0) + endHeight (4.0) = 14.0
      expect(maxZEnd, closeTo(14.00, 1e-3));
    });

    test('3D mesh generation handles tilted walls (transverse lean)', () {
      // Wall along X-axis, normal along +Y
      final wall = ArchitectWall(
        id: 'tilted_wall',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.20,
        height: 3.00,
        tiltAngle: 10.0, // leans along normal (+Y) by 3 * tan(10 deg) ~ 0.5289 m
      );

      expect(wall.isTilted, isTrue);

      final triangles = wall.build3D(
        storeyElevation: 0.0,
        resolveComposition: false,
      );
      expect(triangles, isNotEmpty);

      final allVertices = triangles.expand((t) => [t.v0, t.v1, t.v2]).toList();
      final topVertices = allVertices.where((v) => (v.z - 3.0).abs() < 1e-3);
      final bottomVertices = allVertices.where((v) => v.z.abs() < 1e-3);

      final topMeanY = topVertices.map((v) => v.y).reduce((a, b) => a + b) / topVertices.length;
      final bottomMeanY = bottomVertices.map((v) => v.y).reduce((a, b) => a + b) / bottomVertices.length;

      final expectedShift = 3.0 * math.tan(10.0 * math.pi / 180.0);
      expect(topMeanY - bottomMeanY, closeTo(expectedShift, 1e-3));
    });

    test('SplitArchitectWall cleanly splits sloped wall preserving slope', () {
      final wall = ArchitectWall(
        id: 'wall_to_split',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        thickness: 0.25,
        height: 2.00,
        endHeight: 4.00,
        clipToRoof: false,
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        elevation: 0,
        height: 3.0,
        walls: [wall],
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project',
        activeStoreyId: 's1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
      );

      // Split in the middle (ratio = 0.5 -> x = 5.0)
      final splitCmd = SplitArchitectWall(
        storeyId: 's1',
        wallId: 'wall_to_split',
        newWallId: 'wall_split_2',
        ratio: 0.5,
      );

      final updatedProject = splitCmd.apply(project);
      final walls = updatedProject.storeys.first.walls;
      expect(walls.length, 2);

      final first = walls.firstWhere((w) => w.id == 'wall_to_split');
      final second = walls.firstWhere((w) => w.id == 'wall_split_2');

      // First segment: [0, 0] to [5, 0], height 2.00 to 3.00
      expect(first.startPoint, const Offset(0, 0));
      expect(first.endPoint, const Offset(5, 0));
      expect(first.height, closeTo(2.00, 1e-4));
      expect(first.endHeight, closeTo(3.00, 1e-4));
      expect(first.topSlopeDegrees, closeTo(wall.topSlopeDegrees, 1e-4));

      // Second segment: [5, 0] to [10, 0], height 3.00 to 4.00
      expect(second.startPoint, const Offset(5, 0));
      expect(second.endPoint, const Offset(10, 0));
      expect(second.height, closeTo(3.00, 1e-4));
      expect(second.endHeight, closeTo(4.00, 1e-4));
      expect(second.topSlopeDegrees, closeTo(wall.topSlopeDegrees, 1e-4));
    });

    test('ArchitectWallSolids respects clipToRoof = false for gable walls', () {
      final gableWall = ArchitectWall(
        id: 'gable_wall_solid',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.25,
        height: 3.00,
        endHeight: 5.00,
        clipToRoof: false,
      );

      final roof = ArchitectRoofPlane(
        id: 'test_roof',
        storeyId: 'storey_top',
        points: const [Offset(0, -1), Offset(6, -1), Offset(6, 4), Offset(0, 4)],
        slopeDegrees: 25.0,
      );

      final storey = ArchitectStorey(
        id: 'storey_top',
        name: 'Top Floor',
        elevation: 0,
        height: 3.0,
        walls: [gableWall],
        roofs: [roof],
      );

      final project = ArchitectProject(
        id: 'proj_solids',
        name: 'Solids Project',
        activeStoreyId: 'storey_top',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
      );

      final solids = ArchitectWallSolids.build(
        storey,
        project.wallTypes,
        project: project,
      );

      expect(solids, isNotEmpty);
      final gableSolid = solids.firstWhere((s) => s.wall.id == 'gable_wall_solid');
      // The solid's top at endPoint should reach 5.0m without being cut off by the roof
      expect(gableSolid.top, closeTo(5.00, 1e-3));
    });

    test('SetArchitectElementProperties can update and clear endHeight and tiltAngle', () {
      final wall = ArchitectWall(
        id: 'prop_wall',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        thickness: 0.25,
        height: 2.80,
      );

      final project = ArchitectProject(
        id: 'proj_props',
        name: 'Props Project',
        activeStoreyId: 'storey_props',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [
          ArchitectStorey(
            id: 'storey_props',
            name: 'Props Floor',
            elevation: 0,
            height: 2.80,
            walls: [wall],
          ),
        ],
      );

      // 1. Set endHeight and tiltAngle and clipToRoof: false
      final setCmd = SetArchitectElementProperties(
        storeyId: 'storey_props',
        elementIds: {'prop_wall'},
        values: {'endHeight': 4.50, 'tiltAngle': -12.0},
        textValues: {'clipToRoof': 'false'},
      );

      final updated = setCmd.apply(project);
      final updatedWall = updated.storeys.first.walls.first;
      expect(updatedWall.endHeight, 4.50);
      expect(updatedWall.tiltAngle, -12.0);
      expect(updatedWall.clipToRoof, false);
      expect(updatedWall.isSlopedTop, isTrue);
      expect(updatedWall.isTilted, isTrue);

      // 2. Clear endHeight and tiltAngle
      final clearCmd = SetArchitectElementProperties(
        storeyId: 'storey_props',
        elementIds: {'prop_wall'},
        clearValues: {'endHeight', 'tiltAngle'},
        textValues: {'clipToRoof': 'true'},
      );

      final restored = clearCmd.apply(updated);
      final restoredWall = restored.storeys.first.walls.first;
      expect(restoredWall.endHeight, isNull);
      expect(restoredWall.tiltAngle, isNull);
      expect(restoredWall.clipToRoof, true);
      expect(restoredWall.isSlopedTop, isFalse);
      expect(restoredWall.isTilted, isFalse);
    });
  });
}
