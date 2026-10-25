import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_section_visibility.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/rendering/architect_section_hatch.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_drainage_geometry.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import 'architect_elevation_ui_test.dart' as qa;

ArchitectProject ccProject({bool both = false}) => ArchitectProject.fromJson(
  jsonDecode(
    File(
      both
          ? 'test/fixtures/bim_package_sections_bb_cc_2026_10_25.json'
          : 'test/fixtures/bim_package_section_cc_2026_10_25.json',
    ).readAsStringSync(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(qa.loadQaFonts);

  test('actual B-B and C-C keep arrows and show south eaves on the right', () {
    final project = ccProject(both: true);
    expect(project.sections, hasLength(2));
    final floor = project.storeys.last, roof = floor.roofs.last;
    final route = ArchitectRoofDrainageGeometry.build(
      project,
      floor,
      roof,
    ).routes.single;
    expect(route.status, ArchitectDownpipeStatus.ready);
    final p = route.points.last;
    for (final cut in project.sections) {
      final data = ArchitectBuildingSection.build(project, cut).forView(cut);
      expect(cut.viewDirection.dx, closeTo(1, 1e-8));
      expect(cut.drawingRight.dy, closeTo(1, 1e-8));
      final delta = Offset(p.x, p.y) - cut.drawingOrigin;
      final x = delta.dx * cut.drawingRight.dx + delta.dy * cut.drawingRight.dy;
      expect(x, greaterThan(cut.length / 2));
      expect(
        data.background!.elementPaths[roof.id]!.contains(Offset(x, 1)),
        isTrue,
      );
      expect(
        data.regions.where((r) => r.customFillColor?.toARGB32() == 0xffeeeeee),
        hasLength(2),
      );
      expect(identical(data.forView(cut), data), isTrue);
      for (final plane in floor.roofs) {
        final rawStation =
            (plane.centroid - cut.start).dx * cut.axis.dx +
            (plane.centroid - cut.start).dy * cut.axis.dy;
        final world = cut.pointAt(rawStation);
        final point = Offset(
          cut.drawingStation(rawStation),
          floor.elevation + plane.topElevationAt(world) - .01,
        );
        expect(data.pickRoof(point, .002), plane.id);
        expect(data.roofProfiles[plane.id]!.contains(point), isTrue);
      }
    }
  });

  test('C-C and a new B-B show the actual pipe behind the cut by default', () {
    final project = ccProject(), cut = project.sections.single;
    final floor = project.storeys.last;
    final roof = floor.roofs.last;
    final route = ArchitectRoofDrainageGeometry.build(
      project,
      floor,
      roof,
    ).routes.single;
    expect(route.status, ArchitectDownpipeStatus.ready);
    for (final section in [
      cut,
      const ArchitectSection(
        id: 'new-bb',
        name: 'B-B',
        start: Offset(8, 15.5),
        end: Offset(-1, 15.5),
      ),
    ]) {
      final full = ArchitectBuildingSection.build(project, section);
      final cutOnly = ArchitectBuildingSection.build(
        project,
        section.copyWith(
          visibility: const ArchitectSectionVisibility(
            categories: {
              ArchitectSectionCategory.gutters: ArchitectSectionDisplay.cutOnly,
              ArchitectSectionCategory.downpipes:
                  ArchitectSectionDisplay.cutOnly,
            },
          ),
        ),
      );
      final visible = full.background!.elementPaths[roof.id]!;
      expect(visible.getBounds().top, closeTo(route.points.last.z, .002));
      final noPipe = cutOnly.background!.elementPaths[roof.id];
      expect(noPipe == null || noPipe.getBounds().top > 2, isTrue);
    }
  });

  test('C-C uses real hollow gutter dimensions and material hatches', () {
    final project = ccProject();
    final section = ArchitectBuildingSection.build(
      project,
      project.sections.single,
    );
    final gutters = section.regions
        .where((r) => r.customFillColor?.toARGB32() == 0xffeeeeee)
        .toList();
    expect(gutters, hasLength(2));
    for (final gutter in gutters) {
      final box = gutter.path.getBounds();
      expect(box.width, closeTo(.15, 1e-5));
      expect(box.height, closeTo(.09, 1e-5));
      expect(gutter.path.contains(box.center), isFalse);
      expect(ArchitectSectionHatch.slab(gutter.material), isNull);
      final fascia = section.regions
          .where(
            (r) =>
                r.sourceId == gutter.sourceId &&
                r.timberCrossSectionPolygon != null &&
                r.path.getBounds().width < .05 &&
                r.path.getBounds().height > .2,
          )
          .single;
      expect(
        Path.combine(
          PathOperation.intersect,
          fascia.path,
          gutter.path,
        ).getBounds().isEmpty,
        isTrue,
        reason: 'The gutter must sit outside the fascia',
      );
      final flashing = section.regions
          .where(
            (r) =>
                r.sourceId == gutter.sourceId &&
                r.roof &&
                r.customFillColor?.toARGB32() == 0xff37474f,
          )
          .single;
      expect(
        Path.combine(
          PathOperation.intersect,
          flashing.path,
          gutter.path,
        ).getBounds().isEmpty,
        isTrue,
        reason: 'The drip edge must not penetrate the channel',
      );
    }
    final wood = section.regions.where(
      (r) => r.roof && r.material == SlabMaterial.parquet,
    );
    final concrete = section.regions.where(
      (r) => r.material == SlabMaterial.concrete,
    );
    expect(wood, isNotEmpty);
    expect(concrete, isNotEmpty);
    expect(
      wood.map((r) => ArchitectSectionHatch.slab(r.material)!.id).toSet(),
      {'wood'},
    );
    expect(
      concrete.map((r) => ArchitectSectionHatch.slab(r.material)!.id).toSet(),
      {'concrete'},
    );
    expect(section.regions.any((r) => r.hatchPattern?.id == 'brick'), isTrue);
  });

  test('capture real C-C and eaves drawing for visual inspection', () async {
    if (!const bool.fromEnvironment('SECTION_CC_QA')) return;
    final project = ccProject(both: true), cut = project.sections.first;
    final data = ArchitectBuildingSection.build(project, cut).forView(cut);
    final drawing = ArchitectSectionDrawing(
      project,
      cut,
      data,
      lookupAppLocalizations(const Locale('bg')),
      const ColorScheme.light(),
      null,
      'TestReadable',
    );
    Future<void> capture(
      String name,
      Rect bounds,
      Size size, {
      ArchitectSectionDrawing? other,
    }) async {
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      final scale =
          math.min(size.width / bounds.width, size.height / bounds.height) * .9;
      ArchitectBuildingSectionPainter(
        other ?? drawing,
        bounds.center,
        scale,
      ).paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'docs/images/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }

    await capture(
      'architect_section_cc_corrected',
      data.bounds.inflate(.3),
      const Size(1500, 950),
    );
    final gutter = data.regions
        .firstWhere((r) => r.customFillColor?.toARGB32() == 0xffeeeeee)
        .path
        .getBounds();
    await capture(
      'architect_section_cc_eaves_detail',
      gutter.inflate(.35),
      const Size(1000, 800),
    );
    final bb = project.sections.last;
    final bbData = ArchitectBuildingSection.build(project, bb).forView(bb);
    await capture(
      'architect_section_bb_corrected',
      bbData.bounds.inflate(.3),
      const Size(1500, 950),
      other: ArchitectSectionDrawing(
        project,
        bb,
        bbData,
        lookupAppLocalizations(const Locale('bg')),
        const ColorScheme.light(),
        null,
        'TestReadable',
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
