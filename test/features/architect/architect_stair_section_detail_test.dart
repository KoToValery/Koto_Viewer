import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_section_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_section.dart';

import 'architect_stair_detail_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final construction in [
    StairConstruction.steel,
    StairConstruction.timber,
  ]) {
    final material = construction == StairConstruction.steel
        ? StairSolidMaterial.metal
        : StairSolidMaterial.timber;
    test(
      '${construction.name} treads have real nosings and retain open risers',
      () {
        final s = fixture.stair(
          fixture.design.copyWith(construction: construction),
        );
        final cut = ArchitectStairSection.build(
          ArchitectStairMesh.body(s),
          Offset.zero,
          const Offset(1, 0),
        );
        final region = cut.regions[material]!;
        expect(region.contains(const Offset(-.02, .14)), isTrue);
        expect(region.contains(const Offset(.15, .08)), isFalse);
        expect(region.getBounds().left, closeTo(-.03, 1e-6));
        expect(region.getBounds().bottom, closeTo(1.44, 1e-6));
        expect(cut.projection, isEmpty);

        final noNosing = ArchitectStairSection.build(
          ArchitectStairMesh.body(
            fixture.stair(s.design!.copyWith(nosingProjection: 0)),
          ),
          Offset.zero,
          const Offset(1, 0),
        );
        expect(noNosing.bounds.left, closeTo(0, 1e-6));
      },
    );

    test(
      '${construction.name} centre section includes unhatched side structure and guard',
      () {
        final s = fixture.stair(
          fixture.design.copyWith(construction: construction),
        );
        final solids = [
          ...ArchitectStairMesh.body(s),
          ...ArchitectStairMesh.railings(s, storey: fixture.floor()),
        ];
        final cut = ArchitectStairSection.build(
          solids,
          Offset.zero,
          const Offset(1, 0),
          includeProjection: true,
        );
        expect(cut.projection, isNotEmpty);
        expect(
          cut.regions[material]!.contains(const Offset(1.35, .65)),
          isFalse,
        );
        expect(
          cut.projection.any((p) => p.contains(const Offset(1.35, .65))),
          isTrue,
        );
        expect(cut.bounds.bottom, greaterThan(2.5));
        final hidden = fixture.stair(s.design!.copyWith(showRailing: false));
        final withoutGuard = ArchitectStairSection.build(
          [
            ...ArchitectStairMesh.body(hidden),
            ...ArchitectStairMesh.railings(hidden, storey: fixture.floor()),
          ],
          Offset.zero,
          const Offset(1, 0),
          includeProjection: true,
        );
        expect(withoutGuard.bounds.bottom, closeTo(1.44, 1e-6));
      },
    );

    test(
      '${construction.name} all shapes, winders and mirrors produce closed finite solids',
      () {
        for (final shape in StairShape.values) {
          for (final left in [false, true]) {
            for (final winders in [
              false,
              if (shape == StairShape.quarterTurn ||
                  shape == StairShape.halfTurn)
                true,
            ]) {
              final s = fixture.stair(
                fixture.design.copyWith(
                  construction: construction,
                  shape: shape,
                  turnLeft: left,
                  winderSteps: winders,
                  startOffset: .35,
                ),
              );
              final solids = ArchitectStairMesh.body(s);
              for (final solid in solids) {
                for (final triangle in solid.triangles) {
                  expect(
                    triangle.area,
                    greaterThan(1e-12),
                    reason: '$shape, $left, $winders',
                  );
                  expect(
                    [triangle.v0, triangle.v1, triangle.v2].every(
                      (p) => p.x.isFinite && p.y.isFinite && p.z.isFinite,
                    ),
                    isTrue,
                  );
                }
                // Every undirected mesh edge occurs twice, including seat caps.
                final edges = <String, int>{};
                for (final t in solid.triangles) {
                  final points = [t.v0, t.v1, t.v2];
                  for (var i = 0; i < 3; i++) {
                    String key(int n) {
                      final p = points[n];
                      return '${(p.x * 1e7).round()},${(p.y * 1e7).round()},${(p.z * 1e7).round()}';
                    }

                    final pair = [key(i), key((i + 1) % 3)]..sort();
                    edges.update(
                      pair.join(':'),
                      (count) => count + 1,
                      ifAbsent: () => 1,
                    );
                  }
                }
                expect(edges.values.every((count) => count == 2), isTrue);
              }
              for (final axis in [
                const Offset(1, 0),
                const Offset(0, 1),
                const Offset(1, .3),
              ]) {
                final cut = ArchitectStairSection.build(
                  solids,
                  const Offset(.1, 0),
                  axis,
                );
                expect(
                  cut.isEmpty,
                  isFalse,
                  reason: '$shape, $left, $winders, $axis',
                );
              }
            }
          }
        }
      },
    );
  }

  test(
    'steel seats are narrower than beams; timber has continuous notched bearing',
    () {
      Path cut(StairConstruction construction, double across) =>
          ArchitectStairSection.build(
            ArchitectStairMesh.body(
              fixture.stair(
                fixture.design.copyWith(construction: construction),
              ),
            ),
            Offset(0, across),
            const Offset(1, 0),
          ).regions[construction == StairConstruction.steel
              ? StairSolidMaterial.metal
              : StairSolidMaterial.timber]!;
      expect(
        cut(StairConstruction.steel, .57).contains(const Offset(.1, .07)),
        isTrue,
      );
      expect(
        cut(StairConstruction.steel, .55).contains(const Offset(.1, .07)),
        isFalse,
      );
      expect(
        cut(StairConstruction.timber, .55).contains(const Offset(.1, .07)),
        isTrue,
      );
      expect(
        cut(StairConstruction.steel, .55).contains(const Offset(.1, -.05)),
        isTrue,
      );
    },
  );

  test('landing frame stays within its finished perimeter', () {
    for (final construction in [
      StairConstruction.steel,
      StairConstruction.timber,
    ]) {
      final s = fixture.stair(
        fixture.design.copyWith(
          shape: StairShape.halfTurn,
          construction: construction,
          nosingProjection: 0,
        ),
      );
      final bounds = s.plan.bounds;
      for (final p in ArchitectStairMesh.body(
        s,
      ).expand((s) => s.triangles).expand((t) => [t.v0, t.v1, t.v2])) {
        expect(bounds.inflate(1e-7).contains(Offset(p.x, p.y)), isTrue);
      }
    }
  });

  test(
    'building section uses the same exclusive material regions at the storey elevation',
    () {
      final s = fixture.stair(fixture.design.copyWith(startOffset: .3));
      final floor = fixture.floor().copyWith(elevation: 4, stairs: [s]);
      final project = fixture.project().copyWith(storeys: [floor]);
      const plane = ArchitectSection(
        id: 'cut',
        start: Offset(-.5, 0),
        end: Offset(3.5, 0),
      );
      final building = ArchitectBuildingSection.build(project, plane);
      final direct = ArchitectStairSection.build(
        ArchitectStairMesh.body(s),
        plane.start,
        plane.axis,
      );
      final regions = building.regions
          .where((r) => r.sourceId == s.id)
          .toList();
      expect(regions, hasLength(2));
      for (final region in regions) {
        final material = region.hatchPattern!.id == 'concrete'
            ? StairSolidMaterial.concrete
            : StairSolidMaterial.finish;
        final a = region.path.getBounds(),
            b = direct.regions[material]!.getBounds().shift(const Offset(0, 4));
        expect(a.left, closeTo(b.left, 1e-5));
        expect(a.top, closeTo(b.top, 1e-5));
        expect(a.right, closeTo(b.right, 1e-5));
        expect(a.bottom, closeTo(b.bottom, 1e-5));
      }
      expect(
        Path.combine(
          PathOperation.intersect,
          regions[0].path,
          regions[1].path,
        ).getBounds().isEmpty,
        isTrue,
      );
    },
  );

  test(
    'timber and metal meeting in the cut never receive overlapping hatches',
    () {
      final wood = ArchitectStairMesh.verticalPrism(
        const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)],
        0,
        .2,
        StairSolidMaterial.timber,
      );
      final metal = ArchitectStairMesh.verticalPrism(
        const [Offset(.4, 0), Offset(.6, 0), Offset(.6, 1), Offset(.4, 1)],
        .1,
        .8,
        StairSolidMaterial.metal,
      );
      final section = ArchitectStairSection.build(
        [wood, metal],
        const Offset(0, .5),
        const Offset(1, 0),
      );
      expect(
        section.regions[StairSolidMaterial.timber]!.contains(
          const Offset(.5, .15),
        ),
        isTrue,
      );
      expect(
        section.regions[StairSolidMaterial.metal]!.contains(
          const Offset(.5, .15),
        ),
        isFalse,
      );
      expect(
        section.regions[StairSolidMaterial.metal]!.contains(
          const Offset(.5, .3),
        ),
        isTrue,
      );
    },
  );

  test(
    'guard posts bear on level treads for all shapes, mirrors and start offsets',
    () {
      for (final shape in StairShape.values) {
        for (final left in [false, true]) {
          for (final winders in [
            false,
            if (shape == StairShape.quarterTurn || shape == StairShape.halfTurn)
              true,
          ]) {
            final s = fixture.stair(
              fixture.design.copyWith(
                shape: shape,
                turnLeft: left,
                winderSteps: winders,
                startOffset: .3,
              ),
            );
            var posts = 0;
            for (final solid in ArchitectStairMesh.railings(
              s,
              storey: fixture.floor(),
            )) {
              final points = solid.triangles
                  .expand((t) => [t.v0, t.v1, t.v2])
                  .toList();
              final bottom = points.map((p) => p.z).reduce(math.min);
              final top = points.map((p) => p.z).reduce(math.max);
              final width =
                  points.map((p) => p.x).reduce(math.max) -
                  points.map((p) => p.x).reduce(math.min);
              final depth =
                  points.map((p) => p.y).reduce(math.max) -
                  points.map((p) => p.y).reduce(math.min);
              if (top - bottom < .5 || width > .1 || depth > .1) continue;
              posts++;
              final step = (bottom - .3) / s.design!.riser;
              expect(
                step,
                closeTo(step.round(), 1e-5),
                reason:
                    '$shape, $left, $winders, ${points.firstWhere((p) => p.z == bottom)}',
              );
            }
            expect(posts, greaterThan(2));
          }
        }
      }
    },
  );

  test('render section detail review sheet', () async {
    if (!const bool.fromEnvironment('STAIR_SECTION_PREVIEW')) return;
    const width = 1800, height = 1500;
    final recorder = PictureRecorder();
    // Use one recorder for all cells so the sheet remains a single artifact.
    final sheet = Canvas(recorder)
      ..drawColor(const Color(0xffffffff), BlendMode.src);
    for (var col = 0; col < StairConstruction.values.length; col++) {
      final construction = StairConstruction.values[col];
      for (var row = 0; row < 3; row++) {
        final s = fixture.stair(
          fixture.design.copyWith(
            construction: construction,
            shape: row == 2 ? StairShape.halfTurn : StairShape.straight,
            showRailing: row == 0,
          ),
        );
        final section = ArchitectStairSection.build(
          [
            ...ArchitectStairMesh.body(s),
            ...ArchitectStairMesh.railings(s, storey: fixture.floor()),
          ],
          Offset(0, row == 1 ? .57 : 0),
          const Offset(1, 0),
          includeProjection: true,
        );
        sheet.save();
        sheet.translate(col * 600.0, row * 500.0);
        ArchitectStairSectionPainter(
          section,
          cutHeight: 1,
        ).paint(sheet, const Size(600, 500));
        sheet.restore();
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    await File(
      'build/architect_stair_sections.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
