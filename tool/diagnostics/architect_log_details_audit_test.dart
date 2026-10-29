import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_bg.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import '../../test/features/architect/architect_elevation_ui_test.dart' as qa;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(qa.loadQaFonts);
  test('reported log house junction audit', () async {
    final controller = ArchitectCommandController(
      ArchitectProject.fromJson(
        jsonDecode(
          File(
            'test/fixtures/bim_package_log_details_2026_10_29.json',
          ).readAsStringSync(),
        ),
      ),
    );
    addTearDown(controller.dispose);
    final project = controller.project, cut = project.sections.single;
    final section = await ArchitectBuildingSection.buildAsync(project, cut);
    const stage = String.fromEnvironment(
      'LOG_DETAILS_STAGE',
      defaultValue: 'after',
    );
    final directory = Directory('build/log-details-audit');
    await directory.create(recursive: true);
    final drawing = ArchitectSectionDrawing(
      project,
      cut,
      section,
      AppLocalizationsBg(),
      const ColorScheme.light(),
      null,
      'TestReadable',
    );
    Future<void> capture(String name, Rect bounds, Size size) async {
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      final scale =
          math.min(size.width / bounds.width, size.height / bounds.height) *
          .94;
      ArchitectBuildingSectionPainter(
        drawing,
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
        '${directory.path}/$stage-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }

    await capture(
      'section',
      section.bounds.inflate(.15),
      const Size(1800, 1250),
    );
    final wall = project.storeys.first.walls.firstWhere(
      (w) =>
          (w.startPoint.dy - 6.6).abs() < .01 &&
          (w.endPoint.dy - 6.6).abs() < .01,
    );
    final relative = (wall.centerStart + wall.centerEnd) / 2 - cut.start;
    final wallStation = relative.dx * cut.axis.dx + relative.dy * cut.axis.dy;
    await capture(
      'eaves',
      Rect.fromLTRB(wallStation - .7, 2.2, wallStation + 1.1, 3.9),
      const Size(1100, 1100),
    );
    await capture(
      'base',
      Rect.fromLTRB(wallStation - .7, -1.3, wallStation + 3.7, .65),
      const Size(1500, 750),
    );
    debugPrint(
      'bounds=${section.bounds} station=$wallStation regions=${section.regions.length} drawing=${section.drawingRegions.length}',
    );
    for (final r in section.drawingRegions) {
      debugPrint(
        '${r.sourceId} ${r.material} ${r.path.getBounds()} loops=${r.path.computeMetrics().length}',
      );
    }
  });
}
