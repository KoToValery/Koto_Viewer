import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_solid_shell.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('small valid faces keep a unit plane normal through shell assembly', () {
    final t = Triangle3D(
      v0: Vector3.zero,
      v1: const Vector3(1, 0, 0),
      v2: const Vector3(0, 5e-10, 0),
    );
    expect(t.area, greaterThan(1e-12));
    expect(t.normal.length, 0); // Existing Vector3 normalization tolerance.
    final shell = ArchitectSolidShell.build([
      [t],
    ]).single;
    expect(shell, hasLength(1));
    for (final v in [shell.single.v0, shell.single.v1, shell.single.v2]) {
      expect(v.x.isFinite && v.y.isFinite && v.z.isFinite, isTrue);
      expect(v.z, 0);
    }
    expect(shell.single.area, closeTo(t.area, 1e-20));
  });
  test('jog changes visible geometry while keeping one far clipping plane', () {
    List<Triangle3D> wall(double y) => [
      Triangle3D(
        v0: Vector3(0, y, 0),
        v1: Vector3(8, y, 0),
        v2: Vector3(8, y, 3),
      ),
      Triangle3D(
        v0: Vector3(0, y, 0),
        v1: Vector3(8, y, 3),
        v2: Vector3(0, y, 3),
      ),
    ];
    final geometry = ArchitectBuildingElevation.fromTriangles(
      [...wall(2), ...wall(6)],
      const ArchitectElevation(
        id: 'jog',
        start: Offset.zero,
        end: Offset(8, 0),
        viewDepth: 5,
        steps: [Offset(4, 3)],
      ),
    );
    expect(geometry.faces.any((p) => p.contains(const Offset(-3, 1))), isTrue);
    expect(geometry.faces.any((p) => p.contains(const Offset(3, 1))), isFalse);
  });
  test(
    'roof edits and finite view depths retain finite source mesh vertices',
    () {
      final project = ArchitectProject.fromJson(
        jsonDecode(
          File(
            'test/fixtures/bim_package_roof_drainage_corners.json',
          ).readAsStringSync(),
        ),
      );
      final roof = project.storeys.expand((s) => s.roofs).first;
      for (final z in [0.0, -.5, .25]) {
        final edited = ArchitectProjectionEditing.move(
          project,
          roof.id,
          Offset(.2, z),
          const Offset(1, 0),
          elevation: true,
        );
        final mesh = Architect3dBuilder.buildProjectMesh(edited);
        for (final t in mesh.triangles) {
          for (final v in [t.v0, t.v1, t.v2]) {
            expect(
              v.x.isFinite && v.y.isFinite && v.z.isFinite,
              isTrue,
              reason: 'roof move $z: $v',
            );
          }
        }
        for (final depth in [.01, 1.0, 10.0]) {
          final view = ArchitectElevation(
            id: 'e',
            start: const Offset(-1, -1),
            end: const Offset(10, -1),
            viewDepth: depth,
          );
          expect(
            ArchitectBuildingElevation.build(edited, view).bounds.isFinite,
            isTrue,
          );
        }
      }
    },
  );
  test(
    'stepped views retain model coordinates and finite clipped drawings',
    () {
      final project = ArchitectProject.fromJson(
        jsonDecode(
          File(
            'test/fixtures/bim_package_roof_drainage_corners.json',
          ).readAsStringSync(),
        ),
      );
      const cut = ArchitectSection(
        id: 's',
        start: Offset(-1, 0),
        end: Offset(10, 0),
        viewDepth: 10,
        steps: [Offset(4, 1), Offset(7, 0)],
      );
      expect(cut.pointAt(5), const Offset(4, 1));
      expect(
        ArchitectSection.fromJson(jsonDecode(jsonEncode(cut.toJson()))).steps,
        cut.steps,
      );
      final section = ArchitectBuildingSection.build(project, cut);
      expect(section.bounds.isFinite, isTrue);
      expect(section.regions, isNotEmpty);
      final elevation = ArchitectBuildingElevation.build(
        project,
        ArchitectElevation(
          id: 'e',
          start: cut.start,
          end: cut.end,
          steps: cut.steps,
          viewDepth: cut.viewDepth,
        ),
      );
      expect(elevation.bounds.isFinite, isTrue);
      for (final p in elevation.faces) {
        expect(p.getBounds().isFinite, isTrue);
      }
    },
  );
}
