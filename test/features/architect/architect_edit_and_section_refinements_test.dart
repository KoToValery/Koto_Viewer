import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_stair_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_floor_contact.dart';
import 'package:kotoview/src/features/architect/services/architect_stair_section.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_stair_detail_test.dart' as stairs;
import 'architect_elevation_ui_test.dart' as qa;

const slab = ArchitectSlab(
  id: 'slab',
  thickness: .2,
  assemblyId: 'finish',
  polygon: [Offset(-2, -2), Offset(6, -2), Offset(6, 2), Offset(-2, 2)],
);
const assembly = ArchitectSlabAssembly(
  id: 'finish',
  usage: SlabUsage.intermediate,
  above: [
    ArchitectSlabLayer(
      id: 'finish-layer',
      material: SlabMaterial.tile,
      role: SlabLayerRole.finish,
      thickness: .08,
    ),
  ],
);

ArchitectProject stairProject(ArchitectStair stair) =>
    stairs.project().copyWith(
      storeys: [
        ArchitectStorey(id: 's', name: '', stairs: [stair], slabs: [slab]),
      ],
      slabAssemblies: [assembly],
    );

ArchitectProject windowProject({
  WallExteriorSide side = WallExteriorSide.left,
}) {
  const window = ArchitectWindow(
    id: 'window',
    wallId: 'wall',
    uuid: 'window',
    offsetRatio: .5,
  );
  return stairs.project().copyWith(
    storeys: [
      ArchitectStorey(
        id: 's',
        name: '',
        walls: [
          ArchitectWall(
            id: 'wall',
            startPoint: Offset.zero,
            endPoint: const Offset(4, 0),
            thickness: .42,
            height: 2.8,
            exteriorSide: side,
            insulationThicknessOverride: .17,
            windows: const [window],
          ),
        ],
      ),
    ],
  );
}

Future<void> captureDetails(
  ArchitectBuildingSection window,
  ArchitectStairSection stair,
) async {
  if (!const bool.fromEnvironment('CAPTURE_EDIT_DETAILS')) return;
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  void draw(Path path, bool hatch) {
    canvas.drawPath(path, Paint()..color = Colors.white);
    if (hatch) {
      canvas.save();
      canvas.clipPath(path);
      final box = path.getBounds();
      for (var x = box.left - box.height; x < box.right; x += .045) {
        canvas.drawLine(
          Offset(x, box.top),
          Offset(x + box.height, box.bottom),
          Paint()
            ..color = const Color(0xffbbbbbb)
            ..strokeWidth = .0018,
        );
      }
      canvas.restore();
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = .003,
    );
  }

  canvas.save();
  canvas.translate(40, 790);
  canvas.scale(260, -260);
  for (final region in window.regions) {
    draw(region.path, region.drawHatch);
  }
  canvas.restore();
  canvas.save();
  canvas.translate(790, 730);
  canvas.scale(180, -180);
  draw(Path()..addRect(const Rect.fromLTRB(-1, -.2, 3, 0)), true);
  draw(Path()..addRect(const Rect.fromLTRB(-1, 0, 0, .08)), false);
  for (final entry in stair.regions.entries) {
    draw(entry.value, entry.key == StairSolidMaterial.concrete);
  }
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(1500, 850);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(
    '.dart_tool/architect-window-stair-details.png',
  ).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['bg', 'en']) {
    testWidgets(
      'Edit Select all works directly from a picked wall ($language)',
      (tester) async {
        final source = editing.seeded(
          const ArchitectStorey(
            id: 's',
            name: '',
            walls: [
              ArchitectWall(
                id: 'w1',
                startPoint: Offset(-3, 0),
                endPoint: Offset(3, 0),
              ),
              ArchitectWall(
                id: 'w2',
                startPoint: Offset(-3, 2),
                endPoint: Offset(3, 2),
              ),
            ],
          ),
        );
        addTearDown(source.dispose);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: source),
          ),
        );
        await tester.pumpAndSettle();
        workspace.camera(tester).fit(const Rect.fromLTWH(-5, -4, 10, 8));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('architect-select-all')),
          findsNothing,
        );
        await workspace.wallTap(tester, Offset.zero);
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementIds, {'w1'});
        final all = find.byKey(const ValueKey('architect-select-all'));
        await tester.ensureVisible(all);
        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementIds, {'w1', 'w2'});
        expect(source.undoCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Select all windows keeps host walls and other storeys unselected',
    (tester) async {
      final source = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: '',
          walls: [
            ArchitectWall(
              id: 'host',
              startPoint: Offset.zero,
              endPoint: Offset(4, 0),
              windows: [
                ArchitectWindow(
                  id: 'a',
                  uuid: 'a',
                  wallId: 'host',
                  offsetRatio: .25,
                ),
                ArchitectWindow(
                  id: 'b',
                  uuid: 'b',
                  wallId: 'host',
                  offsetRatio: .75,
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(source.dispose);
      source.restore(
        source.project.copyWith(
          storeys: [
            source.project.activeStorey,
            const ArchitectStorey(
              id: 'upper',
              name: '',
              elevation: 3,
              walls: [
                ArchitectWall(
                  id: 'upper-host',
                  startPoint: Offset.zero,
                  endPoint: Offset(4, 0),
                  windows: [
                    ArchitectWindow(
                      id: 'upper-window',
                      uuid: 'upper-window',
                      wallId: 'upper-host',
                      offsetRatio: .5,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      await workspace.open(tester, source);
      workspace.camera(tester).fit(const Rect.fromLTWH(-2, -3, 8, 6));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(1, 0));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'a'});
      final all = find.byKey(const ValueKey('architect-select-all'));
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'a', 'b'});
      expect(source.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final shape in StairShape.values) {
    test(
      '$shape first riser finish starts at floor; concrete and tread levels stay fixed',
      () {
        final stair = stairs.stair(
          stairs.design.copyWith(shape: shape, showRailing: false),
        );
        final project = stairProject(stair), floor = project.activeStorey;
        final bottom = ArchitectStairFloorContact.firstRiserBottom(
          project,
          floor,
          stair,
        );
        expect(bottom, closeTo(.08, 1e-9));
        final bare = ArchitectStairMesh.body(stair);
        final body = ArchitectStairMesh.body(stair, firstRiserBottom: bottom);
        final concrete = body
            .where((s) => s.material == StairSolidMaterial.concrete)
            .toList();
        final oldConcrete = bare
            .where((s) => s.material == StairSolidMaterial.concrete)
            .toList();
        for (var i = 0; i < concrete.length; i++) {
          List<double> coordinates(StairSolid solid) => [
            for (final t in solid.triangles)
              for (final p in [t.v0, t.v1, t.v2]) ...[p.x, p.y, p.z],
          ];
          expect(
            coordinates(concrete[i]),
            orderedEquals(coordinates(oldConcrete[i])),
          );
        }
        final finish = body
            .where((s) => s.material == StairSolidMaterial.finish)
            .expand((s) => s.triangles)
            .expand((t) => [t.v0.z, t.v1.z, t.v2.z]);
        expect(finish.reduce(math.min), closeTo(.08, 1e-9));
        expect(finish.reduce(math.max), closeTo(stair.design!.rise, 1e-9));
      },
    );
  }

  test(
    'stair contact respects openings, slab offsets and explicit starting offsets',
    () {
      final stair = stairs.stair();
      final project = stairProject(stair);
      final noSlab = project.activeStorey.copyWith(slabs: []);
      expect(
        ArchitectStairFloorContact.firstRiserBottom(project, noSlab, stair),
        0,
      );
      final voidFloor = project.activeStorey.copyWith(
        slabs: [
          slab.copyWith(
            holes: const [
              [
                Offset(-.2, -.2),
                Offset(.2, -.2),
                Offset(.2, .2),
                Offset(-.2, .2),
              ],
            ],
          ),
        ],
      );
      expect(
        ArchitectStairFloorContact.firstRiserBottom(project, voidFloor, stair),
        0,
      );
      final elevated = stairs.stair(stairs.design.copyWith(startOffset: .3));
      expect(
        ArchitectStairFloorContact.firstRiserBottom(
          project,
          project.activeStorey,
          elevated,
        ),
        .3,
      );
      final shifted = project.activeStorey.copyWith(
        slabs: [slab.copyWith(coreTopOffset: -.04)],
      );
      expect(
        ArchitectStairFloorContact.firstRiserBottom(project, shifted, stair),
        closeTo(.04, 1e-9),
      );
    },
  );

  test(
    'floor finish stops at the first riser without overlapping its concrete',
    () {
      final project = stairProject(stairs.stair());
      final section = ArchitectBuildingSection.build(
        project,
        const ArchitectSection(
          id: 'cut',
          start: Offset(-1, 0),
          end: Offset(4, 0),
        ),
        includeProjection: false,
      );
      final finish = section.regions
          .where((r) => r.sourceId == 'slab' && r.material == SlabMaterial.tile)
          .map((r) => r.path)
          .reduce((a, b) => Path.combine(PathOperation.union, a, b));
      final concrete = section.regions
          .where(
            (r) => r.sourceId == 'st' && r.material == SlabMaterial.concrete,
          )
          .map((r) => r.path)
          .reduce((a, b) => Path.combine(PathOperation.union, a, b));
      expect(finish.contains(const Offset(.98, .04)), isTrue);
      expect(finish.contains(const Offset(1.1, .04)), isFalse);
      expect(concrete.contains(const Offset(1.1, .04)), isTrue);
      expect(
        Path.combine(
          PathOperation.intersect,
          finish,
          concrete,
        ).getBounds().isEmpty,
        isTrue,
      );
    },
  );

  for (final side in WallExteriorSide.values) {
    for (final reverse in [false, true]) {
      test(
        'window detail is unhatched, disjoint, and overhangs insulation: $side/$reverse',
        () async {
          final project = windowProject(side: side),
              wall = project.activeStorey.walls.single;
          final cut = ArchitectSection(
            id: 'cut',
            start: Offset(2, reverse ? 1 : -1),
            end: Offset(2, reverse ? -1 : 1),
          );
          final section = ArchitectBuildingSection.build(
            project,
            cut,
            includeProjection: false,
          );
          final windows = section.regions
              .where((r) => r.sourceId == 'window')
              .toList();
          expect(windows, isNotEmpty);
          expect(windows.every((r) => !r.drawHatch), isTrue);
          final path = windows
              .map((r) => r.path)
              .reduce((a, b) => Path.combine(PathOperation.union, a, b));
          final outside =
              wall.centerStart + wall.exteriorNormal * wall.thickness / 2;
          final delta = outside - cut.start;
          final station = delta.dx * cut.axis.dx + delta.dy * cut.axis.dy;
          final direction =
              wall.exteriorNormal.dx * cut.axis.dx +
              wall.exteriorNormal.dy * cut.axis.dy;
          expect(
            direction > 0 ? path.getBounds().right : -path.getBounds().left,
            greaterThan((direction > 0 ? station : -station) + .044),
          );
          final overlap = Path.combine(
            PathOperation.intersect,
            path,
            section.regions
                .where((r) => r.sourceId == 'wall')
                .map((r) => r.path)
                .reduce((a, b) => Path.combine(PathOperation.union, a, b)),
          );
          expect(overlap.getBounds().isEmpty, isTrue);
          final centre = wall.coreCenterStart - cut.start;
          final frame = centre.dx * cut.axis.dx + centre.dy * cut.axis.dy;
          expect(path.contains(Offset(frame, 1.5)), isFalse);
          expect(path.contains(Offset(frame - .010, 1.5)), isTrue);
          expect(path.contains(Offset(frame + .010, 1.5)), isTrue);
          if (!reverse && side == WallExteriorSide.left) {
            final stair = stairs.stair();
            await captureDetails(
              section,
              ArchitectStairSection.build(
                ArchitectStairMesh.body(stair, firstRiserBottom: .08),
                Offset.zero,
                const Offset(1, 0),
              ),
            );
          }
        },
      );
    }
  }
}
