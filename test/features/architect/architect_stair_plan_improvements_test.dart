import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_plan_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_railings.dart';
import 'architect_stair_detail_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations bg;
  setUpAll(() async {
    bg = await AppLocalizations.delegate.load(const Locale('bg'));
    final font = rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    await (FontLoader('Roboto')..addFont(font)).load();
    await (FontLoader('ArchitectNoto')..addFont(font)).load();
  });

  ArchitectVectorCanvas plan(
    ArchitectStair stair, {
    bool labels = true,
    ArchitectStorey? floor,
    ArchitectProject? project,
  }) {
    final canvas = ArchitectVectorCanvas();
    ArchitectStairPlanPainter.draw(
      canvas: canvas,
      stair: stair,
      scale: 100,
      color: Colors.black,
      l10n: bg,
      labels: labels,
      storey: floor,
      project: project,
    );
    return canvas;
  }

  test(
    'corner stays fixed for all shapes, both turns, widths and rotations',
    () {
      const anchor = Offset(3, -2);
      for (final shape in StairShape.values) {
        for (final left in [false, true]) {
          for (final angle in [0.0, .7, math.pi / 2, 2.8]) {
            for (final width in [.9, 1.8]) {
              for (final winders in [
                false,
                if (shape == StairShape.quarterTurn ||
                    shape == StairShape.halfTurn)
                  true,
              ]) {
                final stair = ArchitectStair.fromCorner(
                  id: 'st',
                  corner: anchor,
                  directionPoint:
                      anchor + Offset(math.cos(angle), math.sin(angle)) * 2,
                  width: width,
                  design: fixture.design.copyWith(
                    shape: shape,
                    turnLeft: left,
                    winderSteps: winders,
                  ),
                );
                expect(
                  (stair.placementCorner - anchor).distance,
                  lessThan(1e-8),
                );
                final first = stair.plan.nosings.first;
                expect(
                  math.min(
                    (first.$1 - anchor).distance,
                    (first.$2 - anchor).distance,
                  ),
                  lessThan(1e-8),
                );
                expect(
                  (stair.startPoint - anchor).distance,
                  closeTo(width / 2, 1e-8),
                );
                final restored = ArchitectStair.fromJson(stair.toJson());
                expect(restored.plan.nosings, stair.plan.nosings);
              }
            }
          }
        }
      }
    },
  );

  test(
    'plan has no hatch and enabling the caption preserves every tread line',
    () {
      for (final material in StairConstruction.values) {
        final stair = fixture.stair(
          fixture.design.copyWith(construction: material, showRailing: false),
        );
        final withText = plan(stair), withoutText = plan(stair, labels: false);
        final paths = withText.operations
            .whereType<ArchitectVectorPath>()
            .toList();
        final other = withoutText.operations
            .whereType<ArchitectVectorPath>()
            .toList();
        expect(paths, hasLength(other.length));
        expect(
          paths.every((p) => p.clip == null && p.color.a == 1 && !p.fill),
          isTrue,
        );
        for (var i = 0; i < paths.length; i++) {
          expect(paths[i].bounds, other[i].bounds);
          expect(
            paths[i].path.computeMetrics().map((m) => m.length).toList(),
            other[i].path.computeMetrics().map((m) => m.length).toList(),
          );
        }
        expect(
          withText.operations.whereType<ArchitectVectorText>(),
          hasLength(2),
        );
        for (final (a, b) in stair.plan.nosings) {
          final bounds = Rect.fromPoints(a, b);
          expect(
            paths.any((p) {
              final actual = p.path.getBounds();
              return (actual.topLeft - bounds.topLeft).distance < 1e-6 &&
                  (actual.bottomRight - bounds.bottomRight).distance < 1e-6;
            }),
            isTrue,
          );
        }
      }
    },
  );

  test(
    'landing levels include storey and start offsets and follow geometry changes',
    () {
      for (final shape in [StairShape.quarterTurn, StairShape.halfTurn]) {
        for (final rise in [2.8, 3.4]) {
          final stair = fixture.stair(
            fixture.design.copyWith(
              shape: shape,
              rise: rise,
              startOffset: -.2,
              showLabel: false,
            ),
          );
          final floor = fixture.floor().copyWith(elevation: 4, stairs: [stair]);
          final project = fixture.project().copyWith(
            storeys: [floor],
            levelUnits: ArchitectUnit.centimeters,
            levelDecimals: 1,
          );
          final level =
              4 - .2 + stair.design!.flightRisers.first * stair.design!.riser;
          final ops = plan(
            stair,
            floor: floor,
            project: project,
          ).operations.whereType<ArchitectVectorText>();
          expect(ops.map((o) => o.text), [project.formatLevel(level)]);
          expect(ops.single.sources, {stair.id});
          expect(floor.elevationMarkers, isEmpty);
          final landing = ArchitectStairGeometry.of(stair).landings.single;
          expect(
            ArchitectStairGeometry.inside(
              ops.single.bounds.center,
              landing.polygon,
            ),
            isTrue,
          );
          final canvas = ArchitectTextScope(
            const ArchitectDocument(),
            'plan:s',
            100,
            100,
            levelUnits: ArchitectUnit.meters,
            levelDecimals: 3,
          ).run(() => plan(stair, floor: floor, project: project));
          expect(
            canvas.operations.whereType<ArchitectVectorText>().single.text,
            formatArchitectLevel(level, decimals: 3),
          );
        }
      }
      final winder = fixture.stair(
        fixture.design.copyWith(
          shape: StairShape.quarterTurn,
          winderSteps: true,
          showLabel: false,
        ),
      );
      expect(plan(winder).operations.whereType<ArchitectVectorText>(), isEmpty);
    },
  );

  test(
    'guards use even bays, corner posts and slender infill with no duplicate end posts',
    () {
      for (final shape in StairShape.values) {
        final stair = fixture.stair(fixture.design.copyWith(shape: shape));
        for (final path in ArchitectStairRailings.build(
          stair,
          storey: fixture.floor(),
        )) {
          final members = ArchitectStairRailings.members(path);
          final posts = members.where((m) => m.post).toList();
          expect(posts.first.point.distanceTo(path.base.first), lessThan(1e-8));
          expect(posts.last.point.distanceTo(path.base.last), lessThan(1e-8));
          for (var i = 1; i < posts.length; i++) {
            final a = posts[i - 1].point, b = posts[i].point;
            expect(
              Offset(a.x - b.x, a.y - b.y).distance,
              lessThanOrEqualTo(1.000001),
            );
          }
          for (var i = 1; i < members.length; i++) {
            expect(
              members[i].point.distanceTo(members[i - 1].point),
              greaterThan(1e-7),
            );
          }
        }
        for (final solid in ArchitectStairMesh.railings(
          stair,
          storey: fixture.floor(),
        )) {
          expect(
            solid.triangles.every((t) => t.area.isFinite && t.area > 1e-12),
            isTrue,
            reason: shape.name,
          );
        }
      }
    },
  );

  test('render stair plan and railing review sheet', () async {
    if (!const bool.fromEnvironment('STAIR_LAYOUT_PREVIEW')) return;
    const width = 1800, height = 1300;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
    final shapes = [
      StairShape.straight,
      StairShape.quarterTurn,
      StairShape.halfTurn,
    ];
    for (var col = 0; col < shapes.length; col++) {
      final stair = fixture.stair(
        fixture.design.copyWith(shape: shapes[col], rise: 3, manualRisers: 18),
      );
      final floor = fixture.floor().copyWith(stairs: [stair]);
      final bounds = stair.plan.bounds;
      canvas.save();
      canvas.translate(col * 600 + 75 - bounds.left * 70, 55 - bounds.top * 70);
      canvas.scale(70.0);
      ArchitectStairPlanPainter.draw(
        canvas: canvas,
        stair: stair,
        scale: 70,
        color: Colors.black,
        l10n: bg,
        storey: floor,
        project: fixture.project(),
      );
      canvas.restore();
      final solids = [
        ...ArchitectStairMesh.body(stair),
        ...ArchitectStairMesh.railings(stair, storey: floor),
      ];
      final triangles = solids.expand((s) => s.triangles).toList()
        ..sort(
          (a, b) => (a.centroid.x + a.centroid.y + a.centroid.z * .3).compareTo(
            b.centroid.x + b.centroid.y + b.centroid.z * .3,
          ),
        );
      Offset projectPoint(dynamic p) =>
          Offset((p.x - p.y) * .8, (p.x + p.y) * .35 - p.z);
      final projected = triangles
          .expand(
            (t) => [projectPoint(t.v0), projectPoint(t.v1), projectPoint(t.v2)],
          )
          .toList();
      final box = (Path()..addPolygon(projected, false)).getBounds();
      final zoom = math.min(470 / box.width, 550 / box.height);
      canvas.save();
      canvas.translate(col * 600 + 65 - box.left * zoom, 710 - box.top * zoom);
      canvas.scale(zoom);
      for (final t in triangles) {
        final light = (.55 + t.normal.z.abs() * .35).clamp(0.0, 1.0);
        final color = t.color ?? Colors.grey;
        canvas.drawPath(
          Path()..addPolygon([
            projectPoint(t.v0),
            projectPoint(t.v1),
            projectPoint(t.v2),
          ], true),
          Paint()
            ..color = Color.fromRGBO(
              (color.r * light * 255).round(),
              (color.g * light * 255).round(),
              (color.b * light * 255).round(),
              1,
            ),
        );
      }
      canvas.restore();
    }
    final picture = recorder.endRecording(),
        image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      'build/architect_stair_plan_improvements.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
