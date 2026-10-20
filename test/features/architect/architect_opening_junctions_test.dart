import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_path_solid.dart';
import 'package:kotoview/src/features/architect/rendering/architect_solid_shell.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';

class _DoorCanvas implements Canvas {
  final paths = <Path>[];
  final arcs = <Rect>[];
  @override
  void drawPath(Path path, Paint paint) => paths.add(path);
  @override
  void drawArc(
    Rect rect,
    double start,
    double sweep,
    bool center,
    Paint paint,
  ) => arcs.add(rect);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Door leaf meets the same jamb face in plan, picking and 3D on both sides',
    () {
      for (final angle in [0.0, math.pi / 2, 2.4]) {
        final u = Offset(math.cos(angle), math.sin(angle));
        final n = Offset(-u.dy, u.dx);
        for (final inward in [false, true]) {
          for (final left in [false, true]) {
            for (final opening in [0.0, 45.0, 90.0]) {
              final door = ArchitectDoor(
                id: 'door',
                wallId: 'wall',
                uuid: 'door',
                offsetRatio: .5,
                isHingeLeft: left,
                openInward: inward,
                openAngleDeg: opening,
                frameThickness: .07,
                leafThickness: .035,
              );
              final canvas = _DoorCanvas();
              door.paint2D(
                canvas: canvas,
                wallStart: Offset.zero,
                wallEnd: u * 4,
                wallThickness: .37,
                zoomScale: 100,
              );
              final hinge =
                  u * (2 + (left ? -1 : 1) * (door.width / 2 - .07)) +
                  n * ((inward ? 1 : -1) * .37 / 2);
              if (opening > 0) {
                expect(
                  (canvas.arcs.first.center - hinge).distance,
                  lessThan(1e-8),
                );
              }
              // Mask, two jambs, then leaf: its footprint must match the 3D slab.
              final footprint = canvas.paths.last;
              final leaf = door
                  .build3D(
                    wallStart: Offset.zero,
                    wallEnd: u * 4,
                    wallThickness: .37,
                    storeyElevation: 0,
                  )
                  .where((t) => t.color == const Color(0xFF8D6E63))
                  .toList();
              expect(leaf, isNotEmpty);
              expect(
                leaf.fold(0.0, (v, t) => v + t.signedVolume),
                closeTo(
                  door.clearWidth *
                      door.leafThickness *
                      (door.height - door.frameThickness - .02),
                  1e-6,
                ),
              );
              final meshBounds = Rect.fromPoints(
                Offset(
                  leaf.expand((t) => [t.v0.x, t.v1.x, t.v2.x]).reduce(math.min),
                  leaf.expand((t) => [t.v0.y, t.v1.y, t.v2.y]).reduce(math.min),
                ),
                Offset(
                  leaf.expand((t) => [t.v0.x, t.v1.x, t.v2.x]).reduce(math.max),
                  leaf.expand((t) => [t.v0.y, t.v1.y, t.v2.y]).reduce(math.max),
                ),
              );
              final plan = footprint.getBounds();
              expect(
                (plan.topLeft - meshBounds.topLeft).distance,
                lessThan(1e-6),
              );
              expect(
                (plan.bottomRight - meshBounds.bottomRight).distance,
                lessThan(1e-6),
              );
              final rotation =
                  angle +
                  (left
                      ? (inward ? 1 : -1) * opening * math.pi / 180
                      : math.pi - (inward ? 1 : -1) * opening * math.pi / 180);
              final tip =
                  hinge +
                  Offset(math.cos(rotation), math.sin(rotation)) *
                      door.clearWidth;
              expect(
                door.containsPoint(
                  tip,
                  wallStart: Offset.zero,
                  wallEnd: u * 4,
                  wallThickness: .37,
                  tolerance: 0,
                ),
                isTrue,
              );
            }
          }
        }
      }
    },
  );

  test(
    'Wall normals face outside, including thin skins away from the origin',
    () {
      for (final origin in [Offset.zero, const Offset(100, 200)]) {
        final path = Path()
          ..addRect(Rect.fromLTWH(origin.dx, origin.dy, 4, .015));
        final mesh = ArchitectPathSolid.extrude(
          path,
          0,
          3,
          const Color(0xffaaaaaa),
        );
        for (final triangle in mesh.where((t) => t.normal.z.abs() < .5)) {
          final point = triangle.centroid;
          final out = point + triangle.normal * .001;
          final inside = point - triangle.normal * .001;
          expect(path.contains(Offset(out.x, out.y)), isFalse);
          expect(path.contains(Offset(inside.x, inside.y)), isTrue);
        }
      }
    },
  );

  test(
    'Touching material boxes retain only the exposed shell and material ownership',
    () {
      final a = ArchitectPathSolid.extrude(
        Path()..addRect(const Rect.fromLTWH(0, 0, 2, 1)),
        0,
        1,
        const Color(0xffff0000),
      );
      final b = ArchitectPathSolid.extrude(
        Path()..addRect(const Rect.fromLTWH(1, 0, 1, 1)),
        1,
        2,
        const Color(0xff0000ff),
      );
      final shell = ArchitectSolidShell.build([a, b]);
      expect(shell[0].every((t) => t.color == const Color(0xffff0000)), isTrue);
      expect(shell[1].every((t) => t.color == const Color(0xff0000ff)), isTrue);
      final faces = shell.expand((s) => s).toList();
      expect(faces.fold(0.0, (v, t) => v + t.area), closeTo(14, 1e-6));
      expect(faces.fold(0.0, (v, t) => v + t.signedVolume), closeTo(3, 1e-6));
      expect(
        faces.any(
          (t) =>
              (t.centroid.z - 1).abs() < 1e-6 &&
              t.centroid.x > 1 &&
              t.normal.z.abs() > .5,
        ),
        isFalse,
      );
    },
  );

  test(
    'Window and door levels expose reveals without internal caps or layer faces',
    () {
      for (final angle in [0.0, math.pi / 2, .5]) {
        final u = Offset(math.cos(angle), math.sin(angle));
        final wall = ArchitectWall(
          id: 'wall',
          startPoint: Offset.zero,
          endPoint: u * 6,
          thickness: .37,
          height: 2.8,
          layers: const [
            ArchitectMaterialLayer(
              id: 'eps',
              material: ArchitectMaterial.eps,
              role: ArchitectLayerRole.insulation,
              thickness: .12,
            ),
            ArchitectMaterialLayer(
              id: 'brick',
              material: ArchitectMaterial.brick,
              role: ArchitectLayerRole.core,
              thickness: .25,
            ),
          ],
          windows: const [
            ArchitectWindow(
              id: 'window',
              wallId: 'wall',
              uuid: 'window',
              offsetRatio: .3,
              width: 1.2,
              height: 1.4,
              sillHeight: .85,
            ),
          ],
          doors: const [
            ArchitectDoor(
              id: 'door',
              wallId: 'wall',
              uuid: 'door',
              offsetRatio: .8,
              width: .9,
              height: 2,
            ),
          ],
        );
        final storey = ArchitectStorey(id: 's', name: '0', walls: [wall]);
        final solids = ArchitectWallSolids.build(storey, []);
        final shell = ArchitectSolidShell.build([
          for (final s in solids) s.triangles,
        ]);
        bool occupied(Vector3 p) => solids.any(
          (s) =>
              p.z > s.bottom &&
              p.z < s.top &&
              s.path.contains(Offset(p.x, p.y)),
        );
        for (final t in shell.expand((s) => s)) {
          // Ignore micron-scale triangulation slivers at float32 boolean edges.
          if (t.area < 1e-7) continue;
          expect(
            occupied(t.centroid + t.normal * .0001),
            isFalse,
            reason:
                'Internal surface, angle $angle, area ${t.area}, normal ${t.normal}, vertices ${[t.v0, t.v1, t.v2].map((p) => [p.x, p.y, p.z]).toList()}',
          );
          expect(occupied(t.centroid - t.normal * .0001), isTrue);
        }
        double capArea(double z) => shell
            .expand((s) => s)
            .where(
              (t) => [t.v0, t.v1, t.v2].every((p) => (p.z - z).abs() < 1e-6),
            )
            .fold(0.0, (a, t) => a + t.area);
        expect(capArea(.85), closeTo(1.2 * .37, 1e-5));
        expect(capArea(2), closeTo(.9 * .37, 1e-5));
        expect(capArea(2.25), closeTo(1.2 * .37, 1e-5));

        final project = ArchitectProject(
          id: 'p',
          name: 'Test',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          storeys: [storey],
          activeStoreyId: 's',
        );
        final sources = <Triangle3D, String>{};
        final mesh = Architect3dBuilder.buildProjectMesh(
          project,
          sources: sources,
        );
        expect(sources.length, mesh.triangles.length);
        expect(sources.values.toSet(), containsAll(['wall', 'door', 'window']));
      }
    },
  );
}
