import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';

void main() {
  group('ArchitectLineWeights', () {
    test('Standard lineweights define clear geometric hierarchy', () {
      expect(ArchitectLineWeights.cutHeavy, greaterThan(ArchitectLineWeights.projection));
      expect(ArchitectLineWeights.projection, greaterThan(ArchitectLineWeights.cutThin));
      expect(ArchitectLineWeights.cutThin, greaterThan(ArchitectLineWeights.hairline));
      expect(ArchitectLineWeights.overhead, greaterThan(ArchitectLineWeights.hairline));

      expect(ArchitectLineWeights.cutHeavy, 2.2);
      expect(ArchitectLineWeights.projection, 1.2);
      expect(ArchitectLineWeights.cutThin, 0.8);
      expect(ArchitectLineWeights.hairline, 0.5);
      expect(ArchitectLineWeights.overhead, 1.0);
    });
  });

  group('Horizontal Cut Plane & Display Mode', () {
    test('Standard bearing wall is cut at default 1.20m cut plane', () {
      const wall = ArchitectWall(
        id: 'w1',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        height: 2.80,
        baseOffset: 0.0,
      );
      expect(wall.isCutAt(1.20), isTrue);
      expect(wall.isOverheadAt(1.20), isFalse);
    });

    test('Parapet (< 1.50m) defaults to uncut projection in auto mode', () {
      const parapet = ArchitectWall(
        id: 'p1',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        height: 1.05,
        wallTypeId: 'parapet_12',
      );
      expect(parapet.isParapet, isTrue);
      expect(parapet.isCutAt(1.20), isFalse);

      // User override: forced cut
      final forcedCut = parapet.copyWith(cutDisplayMode: ArchitectCutDisplayMode.cut);
      expect(forcedCut.isCutAt(1.20), isTrue);
    });

    test('Wall elevated above cut plane is overhead', () {
      const highWall = ArchitectWall(
        id: 'w2',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        height: 0.60,
        baseOffset: 2.20,
      );
      expect(highWall.isCutAt(1.20), isFalse);
      expect(highWall.isOverheadAt(1.20), isTrue);
    });

    test('Forced projected mode renders normal wall as uncut', () {
      const wall = ArchitectWall(
        id: 'w3',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        height: 2.80,
        cutDisplayMode: ArchitectCutDisplayMode.projected,
      );
      expect(wall.isCutAt(1.20), isFalse);
    });

    test('ArchitectColumn evaluates cut status correctly', () {
      const col = ArchitectColumn(
        id: 'c1',
        position: Offset(1, 1),
        height: 2.80,
        baseOffset: 0.0,
      );
      expect(col.isCutAt(1.20), isTrue);

      const highCol = ArchitectColumn(
        id: 'c2',
        position: Offset(1, 1),
        height: 1.00,
        baseOffset: 2.00,
      );
      expect(highCol.isCutAt(1.20), isFalse);
      expect(highCol.isOverheadAt(1.20), isTrue);

      final forcedUncut = col.copyWith(cutDisplayMode: ArchitectCutDisplayMode.projected);
      expect(forcedUncut.isCutAt(1.20), isFalse);
    });

    test('ArchitectBeam defaults to overhead above 1.20m cut plane', () {
      const beam = ArchitectBeam(
        id: 'b1',
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        baseOffset: 2.20,
        depth: 0.50,
      );
      expect(beam.isOverheadAt(1.20), isTrue);
      expect(beam.isCutAt(1.20), isFalse);

      // Beam cut if cut plane is at 2.40m
      expect(beam.isCutAt(2.40), isTrue);
    });
  });

  group('Wall Layers Separation for Cut and Uncut Elements', () {
    test('Cut walls go into core/body, parapets go into uncutBody', () {
      const cutWall = ArchitectWall(
        id: 'cut',
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        thickness: 0.25,
        height: 2.80,
      );
      const parapet = ArchitectWall(
        id: 'para',
        startPoint: Offset(0, 2),
        endPoint: Offset(4, 2),
        thickness: 0.15,
        height: 1.05,
        wallTypeId: 'parapet_12',
      );

      final layers = ArchitectWallLayers.build([cutWall, parapet], [], cutPlaneHeight: 1.20);
      expect(layers.walls.length, 1);
      expect(layers.walls.first.id, 'cut');
      expect(layers.body.computeMetrics().isNotEmpty, isTrue);
      expect(layers.core.computeMetrics().isNotEmpty, isTrue);
      expect(layers.uncutBody.computeMetrics().isNotEmpty, isTrue);
    });
  });

  group('Base Offset in 3D Mesh Generation', () {
    test('3D wall elevation offsets by baseOffset', () {
      const wall = ArchitectWall(
        id: 'w1',
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        height: 1.50,
        baseOffset: 0.50,
        followStoreyHeight: false,
      );
      const storeyElevation = 3.00;
      final wallTris = wall.build3D(storeyElevation: storeyElevation);
      final zCoords = wallTris.expand((t) => [t.v0.z, t.v1.z, t.v2.z]).toList();
      final minZ = zCoords.reduce(math.min);
      final maxZ = zCoords.reduce(math.max);

      // Storey elevation (3.00) + baseOffset (0.50) = 3.50
      expect(minZ, closeTo(3.50, 1e-6));
      // 3.50 + height (1.50) = 5.00
      expect(maxZ, closeTo(5.00, 1e-6));

      // Also check project mesh maxZ reaches 5.00
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test Project',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's1',
        storeys: const [
          ArchitectStorey(
            id: 's1',
            name: 'First Floor',
            elevation: storeyElevation,
            height: 2.80,
            walls: [wall],
          ),
        ],
      );
      final mesh = Architect3dBuilder.buildProjectMesh(project);
      final meshMaxZ = mesh.triangles.expand((t) => [t.v0.z, t.v1.z, t.v2.z]).reduce(math.max);
      expect(meshMaxZ, closeTo(5.00, 1e-6));
    });
  });

  group('Properties Command & Serialization', () {
    test('SetArchitectElementProperties applies baseOffset and cutDisplayMode', () {
      final project = ArchitectProject(
        id: 'p1',
        name: 'P1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's1',
        storeys: const [
          ArchitectStorey(
            id: 's1',
            name: 'Storey 1',
            walls: [
              ArchitectWall(
                id: 'w1',
                startPoint: Offset.zero,
                endPoint: Offset(3, 0),
                thickness: 0.25,
                height: 2.80,
              ),
            ],
          ),
        ],
      );

      final cmd = SetArchitectElementProperties(
        storeyId: 's1',
        elementIds: {'w1'},
        values: {'baseOffset': 0.45},
        textValues: {'cutDisplayMode': 'projected'},
      );

      final updated = cmd.apply(project);
      final wall = updated.activeStorey.walls.firstWhere((w) => w.id == 'w1');
      expect(wall.baseOffset, 0.45);
      expect(wall.cutDisplayMode, ArchitectCutDisplayMode.projected);

      // Verify JSON roundtrip
      final json = updated.toJson();
      final restored = ArchitectProject.fromJson(json);
      final restoredWall = restored.activeStorey.walls.firstWhere((w) => w.id == 'w1');
      expect(restoredWall.baseOffset, 0.45);
      expect(restoredWall.cutDisplayMode, ArchitectCutDisplayMode.projected);
    });
  });
}
