import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'architect_roof_drainage_test.dart' as fixture;
import 'architect_elevation_ui_test.dart' as qa;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(qa.loadQaFonts);
  test('section keeps the downpipe bore and gutter outlet open', () async {
    final project = fixture.drainageProject(bay: true);
    final section = ArchitectBuildingSection.build(
      project,
      const ArchitectSection(
        id: 'cut',
        start: Offset(2, -1),
        end: Offset(2, 5),
      ),
    );
    final drainage = section.regions
        .where((r) => r.customFillColor?.toARGB32() == 0xffeeeeee)
        .single
        .path;
    expect(drainage.contains(const Offset(1.75, 1)), isFalse);
    expect(drainage.contains(const Offset(1.7005, 1)), isTrue);
    // The gutter floor is perforated at the pipe center, including in section.
    expect(drainage.contains(const Offset(.95, 6.8705)), isFalse);
    if (!const bool.fromEnvironment('ELEVATION_QA_CAPTURE')) return;
    final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    void text(String value, Offset position, double size) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'TestReadable',
            color: const Color(0xff20272b),
            fontSize: size,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 700);
      painter.paint(canvas, position);
    }

    void panel(Rect destination, Rect world, {bool onlyDrainage = false}) {
      final scale = math.min(
        destination.width / world.width,
        destination.height / world.height,
      );
      canvas.save();
      canvas.clipRect(destination);
      canvas.translate(
        destination.center.dx - world.center.dx * scale,
        destination.center.dy + world.center.dy * scale,
      );
      canvas.scale(scale, -scale);
      for (final region in section.regions) {
        if (onlyDrainage && region.customFillColor?.toARGB32() != 0xffeeeeee) {
          continue;
        }
        canvas.drawPath(
          region.path,
          Paint()
            ..color = region.customFillColor != null
                ? const Color(0xff8a969c)
                : const Color(0xfff0f1f2),
        );
        canvas.drawPath(
          region.path,
          Paint()
            ..color = const Color(0xff30383c)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .75 / scale,
        );
      }
      canvas.restore();
    }

    text('ВТ — автоматично трасе около еркер', const Offset(38, 26), 27);
    text('Разрез през тръбата', const Offset(38, 74), 18);
    panel(
      const Rect.fromLTWH(35, 110, 620, 800),
      const Rect.fromLTWH(.55, 0, 4.6, 9.3),
    );
    text('Връзка с улука — кух профил', const Offset(710, 104), 20);
    panel(
      const Rect.fromLTWH(710, 160, 640, 390),
      const Rect.fromLTWH(.84, 6.73, .24, .29),
      onlyDrainage: true,
    );
    text('Отместване под еркера', const Offset(710, 590), 20);
    panel(
      const Rect.fromLTWH(710, 635, 640, 275),
      const Rect.fromLTWH(.9, 1.9, 1.0, 1.2),
      onlyDrainage: true,
    );
    final picture = recorder.endRecording(),
        image = await picture.toImage(1400, 960);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/architect-elevation-qa/drainage-section.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
