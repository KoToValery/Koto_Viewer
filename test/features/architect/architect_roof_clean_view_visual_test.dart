import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_elevations_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layers_dialog.dart';
import 'architect_section_cc_package_test.dart' as cases;
import 'architect_elevation_ui_test.dart' as qa;

void main() {
  setUpAll(qa.loadQaFonts);
  testWidgets('clean views and live construction visual QA', (tester) async {
    if (!const bool.fromEnvironment('CLEAN_ROOF_QA')) return;
    final p = cases.ccProject(both: true),
        floor = p.storeys.last,
        roof = floor.roofs.last;
    final l = lookupAppLocalizations(const Locale('bg'));
    Future<void> save(String name, ui.Image image) async {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'docs/images/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    }

    await tester.runAsync(() async {
      for (final cut in p.sections) {
        final data = ArchitectBuildingSection.build(p, cut).forView(cut);
        final bounds = data.bounds.inflate(.3), recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
        final scale = math.min(1500 / bounds.width, 900 / bounds.height) * .9;
        ArchitectBuildingSectionPainter(
          ArchitectSectionDrawing(
            p,
            cut,
            data,
            l,
            const ColorScheme.light(),
            null,
            'TestReadable',
          ),
          bounds.center,
          scale,
        ).paint(canvas, const Size(1500, 900));
        final picture = recorder.endRecording();
        await save(
          cut == p.sections.first
              ? 'architect_section_cc_clean'
              : 'architect_section_bb_clean',
          await picture.toImage(1500, 900),
        );
        picture.dispose();
      }
      const view = ArchitectElevation(
        id: 'facade',
        start: Offset(-2, 4),
        end: Offset(9, 4),
      );
      final facade = ArchitectBuildingElevation.build(p, view);
      final recorder = ui.PictureRecorder(),
          canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
      final scale =
          math.min(1500 / facade.bounds.width, 900 / facade.bounds.height) * .9;
      ArchitectFacadePainter(
        facade,
        facade.bounds.center,
        scale,
        fill: Colors.white,
        fontFamily: 'TestReadable',
      ).paint(canvas, const Size(1500, 900));
      final picture = recorder.endRecording();
      await save(
        'architect_facade_downpipes_clean',
        await picture.toImage(1500, 900),
      );
      picture.dispose();
    });
    await qa.phone(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      qa.host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ArchitectRoofLayersDialog(
                  project: p,
                  roof: roof,
                  initialAssembly: roof.assembly,
                  initialSlopeDegrees: roof.slopeDegrees,
                  initialEavesOverhang: roof.eavesOverhang,
                  initialEavesCut: roof.eavesCut,
                  initialDrainage: roof.drainage,
                  initialTab: 2,
                  onApply: (_) {},
                ),
              ),
            ),
          ),
        ),
        'bg',
        key,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(l.architectRoofRaftersLabel));
    await tester.tap(find.text(l.architectRoofRaftersLabel));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await save(
        'architect_roof_dynamic_preview_phone',
        await boundary.toImage(pixelRatio: 2),
      );
    });
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
