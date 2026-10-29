import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_special_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';

ArchitectProject attachedLogProject() => ArchitectProject.fromJson(
  jsonDecode(
    File(
      'test/fixtures/bim_package_log_walls_2026_10_28.json',
    ).readAsStringSync(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment(
    'LOG_AUDIT_MODE',
    defaultValue: 'geometry',
  );
  Directory('build/log-wall-audit-2026-10-28').createSync(recursive: true);
  void trace(String value) {
    File(
      'build/log-wall-audit-2026-10-28/trace.log',
    ).writeAsStringSync('${DateTime.now()} $value\n', mode: FileMode.append);
    debugPrint(value);
  }

  test(
    'attached log house $mode performance',
    () async {
      final project = attachedLogProject(),
          floor = project.storeys.firstWhere((s) => s.walls.isNotEmpty);
      final watch = Stopwatch()..start();
      trace('START $mode');
      if (mode == 'stages') {
        var last = 0, gap = 0;
        final timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
          final now = watch.elapsedMilliseconds;
          if (now - last > gap) gap = now - last;
          last = now;
        });
        Future<void> report(String stage) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          trace('$stage ${watch.elapsedMilliseconds}ms max_ui_gap=${gap}ms');
          watch.reset();
          last = 0;
          gap = 0;
        }

        try {
          final solids = await ArchitectWallSolids.buildAsync(
            floor,
            project,
            prepareShell: true,
          );
          await report('PREPARE');
          final line = project.sections.single;
          await ArchitectMeshSection.prepareVertical(
            solids.map((s) => s.triangles),
            line.start,
            line.axis,
            line.length,
          );
          await report('SLICE');
          final cut = ArchitectBuildingSection.build(
            project,
            project.sections.single,
            includeProjection: false,
          );
          await report('CUT regions=${cut.regions.length}');
          final mesh = await Architect3dBuilder.buildProjectMeshAsync(
            project,
            previewGeometry: false,
          );
          await report('MESH triangles=${mesh.triangles.length}');
          final section = await ArchitectBuildingSection.buildAsync(
            project,
            project.sections.single,
          );
          await report('SECTION faces=${section.background!.faces.length}');
        } finally {
          timer.cancel();
        }
        return;
      }
      if (mode == 'geometry') {
        final parts = ArchitectSpecialWallGeometry.build(
          floor,
          project: project,
        );
        trace(
          'SPECIAL ${watch.elapsedMilliseconds}ms components=${parts.length} triangles=${parts.fold<int>(0, (n, c) => n + c.triangles.length)} max=${parts.map((c) => c.triangles.length).fold<int>(0, (a, b) => a > b ? a : b)}',
        );
        watch.reset();
        final solids = ArchitectWallSolids.build(
          floor,
          project.wallTypes,
          project: project,
        );
        trace('SOLIDS ${watch.elapsedMilliseconds}ms count=${solids.length}');
      } else if (mode == 'mesh') {
        final mesh = Architect3dBuilder.buildProjectMesh(
          project,
          previewGeometry: false,
        );
        trace(
          'MESH ${watch.elapsedMilliseconds}ms triangles=${mesh.triangles.length}',
        );
      } else if (mode == 'plan') {
        final plan = ArchitectWallLayers.forProject(
          project.copyWith(activeStoreyId: floor.id),
        );
        trace(
          'PLAN ${watch.elapsedMilliseconds}ms materials=${plan.materials.length}',
        );
      } else {
        final section = mode == 'async'
            ? await ArchitectBuildingSection.buildAsync(
                project,
                project.sections.single,
              )
            : ArchitectBuildingSection.build(
                project,
                project.sections.single,
                includeProjection: mode != 'cut',
              );
        trace(
          'SECTION ${watch.elapsedMilliseconds}ms regions=${section.regions.length} faces=${section.background?.faces.length}',
        );
        watch.reset();
        final paths = section.elementPaths;
        trace('PATHS ${watch.elapsedMilliseconds}ms count=${paths.length}');
      }
      trace('DONE $mode');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
