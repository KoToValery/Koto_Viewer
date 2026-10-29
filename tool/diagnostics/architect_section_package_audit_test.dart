// Manual diagnostic for the attached 2026-10-28 BIM package.
// `robust` is an experiment; it does not change the application implementation.
// `raw` traces the application's elementPaths union sequence and can block
// for tens of seconds per drainage contour. Run it in a separate process.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section_visibility.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_drainage_mesh.dart';
import 'package:kotoview/src/features/architect/rendering/architect_path_solid.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_drainage_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import '../../test/features/architect/architect_elevation_ui_test.dart' as qa;

void main() {
  const outputDirectory = String.fromEnvironment(
    'AUDIT_OUTPUT',
    defaultValue: 'build/section-audit-2026-10-28',
  );
  Directory(outputDirectory).createSync(recursive: true);
  void trace(String value) {
    File(
      '$outputDirectory/trace.log',
    ).writeAsStringSync('${DateTime.now()} $value\n', mode: FileMode.append);
    debugPrint(value);
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(qa.loadQaFonts);
  const requestedMode = String.fromEnvironment(
    'AUDIT_MODE',
    defaultValue: 'all',
  );
  const requestedIndex = int.fromEnvironment('AUDIT_SECTION', defaultValue: 0);
  const pathMode = String.fromEnvironment(
    'AUDIT_PATH_MODE',
    defaultValue: 'skip',
  );
  const captureImages = bool.fromEnvironment('AUDIT_CAPTURE');
  const allSections = bool.fromEnvironment('AUDIT_ALL_SECTIONS');
  for (final mode
      in requestedMode == 'all'
          ? ['none', 'gutters', 'cutOnly', 'full']
          : [requestedMode]) {
    for (final sectionIndex
        in requestedMode == 'all' || allSections
            ? [0, 1, 2]
            : [requestedIndex]) {
      test(
        'current attached package section audit $mode $sectionIndex',
        () async {
          var project = ArchitectProject.fromJson(
            jsonDecode(
              File(
                'test/fixtures/bim_package_sections_2026_10_28.json',
              ).readAsStringSync(),
            ),
          );
          if (mode == 'none' || mode == 'gutters') {
            project = project.copyWith(
              storeys: [
                for (final floor in project.storeys)
                  floor.copyWith(
                    roofs: [
                      for (final roof in floor.roofs)
                        roof.copyWith(
                          drainage: roof.drainage.copyWith(
                            showGutter: mode == 'none'
                                ? false
                                : roof.drainage.showGutter,
                            downpipes: [],
                          ),
                        ),
                    ],
                  ),
              ],
            );
          }
          var cut = project.sections[sectionIndex];
          if (mode == 'cutOnly') {
            cut = cut.copyWith(
              visibility: const ArchitectSectionVisibility(
                categories: {
                  ArchitectSectionCategory.gutters:
                      ArchitectSectionDisplay.cutOnly,
                  ArchitectSectionCategory.downpipes:
                      ArchitectSectionDisplay.cutOnly,
                },
              ),
            );
          }
          final sw = Stopwatch()..start();
          for (final floor in project.storeys) {
            for (final roof in floor.roofs) {
              final triangles = ArchitectRoofDrainageMesh.build(
                project,
                floor,
                roof,
                details: false,
              );
              final geometry = ArchitectRoofDrainageGeometry.build(
                project,
                floor,
                roof,
              );
              trace(
                'DRAIN ${roof.id}: ${triangles.length} triangles, ${geometry.gutters.length} gutters, routes=${geometry.routes.map((r) => '${r.status}:${r.points}').toList()}, elapsed=${sw.elapsedMilliseconds}ms',
              );
            }
          }
          final mesh = Architect3dBuilder.buildProjectMesh(
            project,
            cleanDrainage: true,
          );
          trace(
            'MESH mode=$mode triangles=${mesh.triangles.length} elapsed=${sw.elapsedMilliseconds}ms',
          );
          sw.reset();
          trace('SECTION START ${cut.name} mode=$mode');
          final data = ArchitectBuildingSection.build(
            project,
            cut,
          ).forView(cut);
          expect(data.regions, isNotEmpty);
          trace(
            'SECTION DONE ${cut.name} mode=$mode ms=${sw.elapsedMilliseconds}, regions=${data.regions.length}, faces=${data.background?.faces.length}, bounds=${data.bounds}',
          );
          final buildMs = sw.elapsedMilliseconds;
          sw.reset();
          trace('ELEMENT PATHS START');
          final elementPaths = pathMode == 'production'
              ? data.elementPaths
              : <String, Path>{...?data.background?.elementPaths};
          for (
            var i = 0;
            pathMode != 'skip' &&
                pathMode != 'production' &&
                i < data.regions.length;
            i++
          ) {
            final region = data.regions[i];
            if (pathMode == 'raw') {
              trace('UNION START $i ${region.sourceId} ${region.material}');
            }
            elementPaths[region.sourceId] =
                elementPaths.containsKey(region.sourceId)
                ? (pathMode == 'robust'
                      ? ArchitectMeshSection.combine
                      : Path.combine)(
                    PathOperation.union,
                    elementPaths[region.sourceId]!,
                    region.path,
                  )
                : region.path;
            if (pathMode == 'raw') {
              trace('UNION DONE $i');
            }
          }
          trace(
            pathMode == 'skip'
                ? 'ELEMENT PATHS SKIPPED'
                : 'ELEMENT PATHS DONE ms=${sw.elapsedMilliseconds} count=${elementPaths.length}',
          );
          final elementPathsMs = sw.elapsedMilliseconds;
          final overlaps = <Map<String, Object?>>[];
          double area(Path path) {
            var total = 0.0;
            for (final contour in ArchitectPathSolid.contours(
              path,
              tolerance: .00001,
            )) {
              for (var i = 0; i < contour.length; i++) {
                final a = contour[i], b = contour[(i + 1) % contour.length];
                total += (a.dx * b.dy - b.dx * a.dy) / 2;
              }
            }
            return total.abs();
          }

          for (var i = 0; i < data.regions.length; i++) {
            final a = data.regions[i];
            for (var j = i + 1; j < data.regions.length; j++) {
              final b = data.regions[j];
              if (!a.path.getBounds().overlaps(b.path.getBounds())) continue;
              final intersection = Path.combine(
                PathOperation.intersect,
                a.path,
                b.path,
              );
              final overlapArea = area(intersection);
              if (overlapArea < 1e-6) continue;
              overlaps.add({
                'a': i,
                'b': j,
                'areaM2': overlapArea,
                'bounds': intersection.getBounds().toString(),
              });
            }
          }
          trace('OVERLAPS ${cut.name}: ${overlaps.length} region pairs');
          final report = <String, Object?>{
            'mode': mode,
            'section': cut.name,
            'milliseconds': buildMs,
            'elementPathsMs': pathMode == 'skip' ? null : elementPathsMs,
            'pathMode': pathMode,
            'roofMembers': [
              for (final floor in project.storeys)
                for (final slice in ArchitectRoofGeometry.buildSectionSlices(
                  storey: floor,
                  sectionLine: cut,
                  project: project,
                  lowerStorey: ArchitectRoofGeometry.supportingWallStorey(
                    project,
                    floor,
                  ),
                ))
                  for (final member in slice.members)
                    {
                      'id': member.roofId,
                      'kind': member.kind.name,
                      'material': member.material?.name,
                      'bounds': [
                        member.path.getBounds().left,
                        member.path.getBounds().top,
                        member.path.getBounds().right,
                        member.path.getBounds().bottom,
                      ],
                    },
            ],
            'overlaps': overlaps,
            'regions': data.regions
                .map(
                  (r) => {
                    'id': r.sourceId,
                    'material': r.material.name,
                    'roof': r.roof,
                    'slab': r.slab,
                    'timber': r.timberCrossSectionPolygon != null,
                    'color': r.customFillColor?.toARGB32(),
                    'bounds': r.path.getBounds().toString(),
                    'boundsM': [
                      r.path.getBounds().left,
                      r.path.getBounds().top,
                      r.path.getBounds().right,
                      r.path.getBounds().bottom,
                    ],
                  },
                )
                .toList(),
          };
          await File(
            '$outputDirectory/report-$mode-$sectionIndex.json',
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
          if (!captureImages) return;
          final drawing = ArchitectSectionDrawing(
            project,
            cut,
            data,
            lookupAppLocalizations(const Locale('bg')),
            const ColorScheme.light(),
            null,
            'TestReadable',
          );
          Future<void> capture(String name, Rect bounds, Size size) async {
            final rec = ui.PictureRecorder();
            final actualCanvas = Canvas(rec)
              ..drawColor(Colors.white, BlendMode.src);
            final scale =
                math.min(
                  size.width / bounds.width,
                  size.height / bounds.height,
                ) *
                .94;
            ArchitectBuildingSectionPainter(
              drawing,
              bounds.center,
              scale,
            ).paint(actualCanvas, size);
            final picture = rec.endRecording();
            final image = await picture.toImage(
              size.width.toInt(),
              size.height.toInt(),
            );
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$outputDirectory/$name.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
            picture.dispose();
          }

          await capture(
            'section-$mode-$sectionIndex',
            data.bounds.inflate(.15),
            const Size(1800, 1150),
          );
          final roofBounds = data.roofProfiles.values
              .map((p) => p.getBounds())
              .reduce((a, b) => a.expandToInclude(b));
          for (final (suffix, bounds) in [
            (
              'left-eaves',
              Rect.fromLTWH(roofBounds.left - .25, 2.55, 1.8, 1.45),
            ),
            (
              'right-eaves',
              Rect.fromLTWH(roofBounds.right - 1.55, 2.55, 1.8, 1.45),
            ),
            (
              'ridge',
              Rect.fromCenter(
                center: Offset(roofBounds.center.dx, roofBounds.bottom - .25),
                width: 1.5,
                height: 1.1,
              ),
            ),
            ('base', Rect.fromLTWH(roofBounds.left + .4, -1.1, 2.2, 1.5)),
          ]) {
            await capture(
              '$suffix-$mode-$sectionIndex',
              bounds,
              const Size(1250, 1000),
            );
          }
        },
        timeout: const Timeout(Duration(seconds: 90)),
      );
    }
  }
}
