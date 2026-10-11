import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';

ArchitectWall exterior(
  String id,
  Offset start,
  Offset end, {
  WallReferenceLine reference = WallReferenceLine.center,
}) => ArchitectWall(
  id: id,
  startPoint: start,
  endPoint: end,
  thickness: .37,
  wallTypeId: 'ext_25_12_eps',
  referenceLine: reference,
);

void main() {
  test(
    'Exterior layers retain 25 cm core and 12 cm insulation for every reference',
    () {
      for (final reference in WallReferenceLine.values) {
        final wall = exterior(
          'w',
          Offset.zero,
          const Offset(3, 0),
          reference: reference,
        );
        final layers = ArchitectWallLayers.build([wall], []);
        expect(layers.body.getBounds().height, closeTo(.37, 1e-7));
        expect(layers.core.getBounds().height, closeTo(.25, 1e-7));
        expect(layers.insulation.getBounds().height, closeTo(.12, 1e-7));
        final center = wall.centerStart.dy;
        expect(layers.core.contains(Offset(1, center)), isTrue);
        expect(layers.core.contains(Offset(1, center + .12)), isFalse);
        expect(layers.insulation.contains(Offset(1, center + .12)), isTrue);
      }
    },
  );

  test(
    'Layer mitres remain connected and inside the body for all references',
    () {
      for (final a in WallReferenceLine.values) {
        for (final b in WallReferenceLine.values) {
          for (final start in [const Offset(-3, 0), const Offset(3, 0)]) {
            final layers = ArchitectWallLayers.build([
              exterior('a', start, Offset.zero, reference: a),
              exterior('b', Offset.zero, const Offset(0, 3), reference: b),
            ], []);
            expect(
              layers.core.computeMetrics().length,
              1,
              reason: '$a / $b / $start',
            );
            expect(
              ui.Path.combine(
                ui.PathOperation.difference,
                layers.core,
                layers.body,
              ).computeMetrics(),
              isEmpty,
            );
            expect(
              ui.Path.combine(
                ui.PathOperation.intersect,
                layers.core,
                layers.insulation,
              ).computeMetrics(),
              isEmpty,
            );
          }
        }
      }
      for (final start in [Offset.zero, const Offset(0, -2)]) {
        final layers = ArchitectWallLayers.build([
          exterior('a', const Offset(-3, 0), const Offset(3, 0)),
          exterior('b', start, const Offset(0, 2)),
        ], []);
        expect(layers.core.computeMetrics().length, 1);
        expect(layers.core.contains(const Offset(.5, .5)), isFalse);
      }
    },
  );

  testWidgets(
    'Plan renders hatch only in brick, no fill, and thinner insulation outline',
    (tester) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 650, 200));
      canvas.translate(20, 100);
      canvas.scale(200);
      final project = ArchitectProject(
        id: 'p',
        name: 'p',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's',
        wallTypes: ArchitectWallType.standardCatalog(),
        storeys: [
          ArchitectStorey(
            id: 's',
            name: 's',
            walls: [exterior('w', Offset.zero, const Offset(3, 0))],
          ),
        ],
      );
      Architect2dPainter(
        project: project,
        activeTool: ArchitectTool.select,
        paintGrid: false,
        zoomScale: 200,
      ).paint(canvas, const Size(650, 200));
      final picture = recorder.endRecording();
      final pixels = (await tester.runAsync(() async {
        final image = await picture.toImage(650, 200);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes;
      }))!;
      int alpha(int x, int y) => pixels.getUint8((y * 650 + x) * 4 + 3);
      var hatchPixels = 0;
      var transparentCorePixels = 0;
      for (var x = 60; x < 580; x++) {
        for (var y = 132; y < 143; y++) {
          expect(
            alpha(x, y),
            0,
            reason: 'Insulation has neither hatch nor fill',
          );
        }
        for (var y = 82; y < 117; y++) {
          if (alpha(x, y) > 0) {
            hatchPixels++;
          } else {
            transparentCorePixels++;
          }
        }
      }
      expect(hatchPixels, greaterThan(100));
      expect(transparentCorePixels, greaterThan(hatchPixels));
      int rowOpacity(int top, int bottom) {
        var result = 0;
        for (var x = 60; x < 580; x++) {
          for (var y = top; y <= bottom; y++) {
            result += alpha(x, y);
          }
        }
        return result;
      }

      expect(rowOpacity(147, 151), lessThan(rowOpacity(72, 78)));
      picture.dispose();
    },
  );
}
