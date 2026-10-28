import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/rendering/architect_special_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_boolean.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_composition_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_type_label.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_type_picker.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_camera.dart';
import 'architect_special_wall_ui_test.dart' as qa;
import 'architect_elevation_ui_test.dart' as fonts;
import 'architect_special_wall_systems_test.dart' as fixtures;

ArchitectProject logHouse() => ArchitectProject.fromJson(
  jsonDecode(
    File('test/fixtures/architect/log_house_24.json').readAsStringSync(),
  ),
);

double firstHit(List<Triangle3D> triangles, Vector3 origin, Vector3 direction) {
  var nearest = double.infinity;
  for (final t in triangles) {
    final a = t.v1 - t.v0,
        b = t.v2 - t.v0,
        h = direction.cross(b),
        det = a.dot(h);
    if (det.abs() < 1e-10) continue;
    final s = origin - t.v0,
        u = s.dot(h) / det,
        q = s.cross(a),
        v = direction.dot(q) / det,
        d = b.dot(q) / det;
    if (u >= -1e-7 && v >= -1e-7 && u + v <= 1.0000001 && d > 1e-8) {
      nearest = math.min(nearest, d);
    }
  }
  return nearest;
}

void main() {
  setUpAll(fonts.loadQaFonts);
  test(
    'nominal log plans preserve openings and physical column/slab contacts',
    () {
      final wall = fixtures
          .special(
            'a',
            ArchitectWallSystemKind.roundLogs,
            Offset.zero,
            const Offset(4, 0),
            height: 2.8,
          )
          .copyWith(
            doors: const [
              ArchitectDoor(
                id: 'door',
                uuid: 'door',
                wallId: 'a',
                offsetRatio: .2,
                width: .8,
              ),
            ],
          );
      final p = fixtures.project([wall]);
      final floor = p.activeStorey.copyWith(
        columns: const [
          ArchitectColumn(
            id: 'column',
            position: Offset(1.6, 0),
            width: .3,
            depth: .3,
          ),
        ],
        slabs: const [
          ArchitectSlab(
            id: 'slab',
            coreTopOffset: 1.3,
            thickness: .2,
            polygon: [Offset(2, -1), Offset(3, -1), Offset(3, 1), Offset(2, 1)],
            holes: [
              [
                Offset(2.4, -.5),
                Offset(2.6, -.5),
                Offset(2.6, .5),
                Offset(2.4, .5),
              ],
            ],
          ),
        ],
      );
      final plan = ArchitectWallLayers.forProject(p.copyWith(storeys: [floor]));
      for (final x in [.2, 2.5, 3.5]) {
        expect(plan.body.contains(Offset(x, 0)), isTrue);
      }
      for (final x in [.8, 1.6, 2.2]) {
        expect(plan.body.contains(Offset(x, 0)), isFalse);
      }
    },
  );
  test('reported house keeps all four nominal 24 cm walls at every plan cut', () {
    final p = logHouse();
    for (final cut in [.216, .31, 1.2, 1.2001, 2.436]) {
      final plan = ArchitectWallLayers.build(
        p.activeStorey.walls,
        p.wallTypes,
        storey: p.activeStorey,
        project: p,
        cutPlaneHeight: cut,
      );
      for (final w in p.activeStorey.walls) {
        expect(w.thickness, .24);
        final path = plan.coreRegions[w.id]!;
        for (final station in [.15, .3, .5, .7, .85]) {
          final center = w.centerStart + w.unitVector * w.length * station;
          for (final offset in [-.119, -.06, 0.0, .06, .119]) {
            expect(
              path.contains(center + w.normalVector * offset),
              isTrue,
              reason:
                  '${w.id} disappears at cut=$cut, station=$station, offset=$offset',
            );
          }
          expect(path.contains(center + w.normalVector * .121), isFalse);
          expect(path.contains(center - w.normalVector * .121), isFalse);
        }
      }
      // Perpendicular tails remain one diameter past the outside wall face.
      expect(plan.body.contains(const Offset(6.85, 6.6)), isTrue);
      expect(plan.body.contains(const Offset(14.75, 0)), isTrue);
      expect(plan.body.contains(const Offset(14.4, 6.95)), isTrue);
      // Hatch owners never overlap at the log corner.
      final corner = const Offset(7.2, 6.6);
      expect(plan.materials.where((m) => m.path.contains(corner)).length, 1);
    }
  });

  test(
    'reported house keeps circular profiles and visible surfaces on both sides',
    () {
      final p = logHouse(), floor = p.activeStorey;
      final components = ArchitectSpecialWallGeometry.build(floor, project: p);
      final shell = ArchitectMeshBoolean.exposedSurfaces([
        for (final c in components) c.triangles,
      ]);
      final layouts = ArchitectSpecialWallGeometry.logLayouts(floor.walls);
      for (final w in floor.walls) {
        final display = [
          for (var i = 0; i < components.length; i++)
            if (components[i].wall.id == w.id) ...shell[i],
        ];
        final pitch = w.system.pitch(w.thickness), phase = layouts[w.id]!.phase;
        final mid = (w.centerStart + w.centerEnd) / 2;
        var section = Path();
        for (final c in components.where((c) => c.wall.id == w.id)) {
          section = Path.combine(
            PathOperation.union,
            section,
            ArchitectMeshSection.vertical(c.triangles, mid, w.normalVector),
          );
        }
        for (var z = .201; z < 2.85; z += .013) {
          expect(
            section.contains(Offset(0, z)),
            isTrue,
            reason: '${w.id}: section missing at $z',
          );
        }
        for (final z in [.201, .453, .903, 1.203, 1.503, 2.003, 2.503, 2.803]) {
          var halfWidth = 0.0;
          for (var row = 0; row < 16; row++) {
            final dz = z - (row + phase) * pitch;
            if (dz.abs() < .12) {
              halfWidth = math.max(halfWidth, math.sqrt(.12 * .12 - dz * dz));
            }
          }
          for (final side in [-1.0, 1.0]) {
            final mid = (w.centerStart + w.centerEnd) / 2,
                n = w.normalVector * side;
            expect(
              firstHit(
                display,
                Vector3(mid.dx + n.dx, mid.dy + n.dy, z),
                Vector3(-n.dx, -n.dy, 0),
              ),
              closeTo(1 - halfWidth, .0005),
              reason: '${w.id}: missing or flattened log at $z',
            );
          }
        }
      }
    },
  );

  for (final language in ['bg', 'en']) {
    testWidgets(
      'wall family conversion is clear and preserves drafts at 320px $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = logHouse(),
            original = ArchitectWallType.standardCatalog().first.copyWith(
              id: 'selected-wall-draft',
              name: '25+12',
            );
        ArchitectWallType? saved;
        late AppLocalizations l;
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'TestReadable', useMaterial3: true),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  l = AppLocalizations.of(context)!;
                  return ArchitectWallCompositionEditor(
                    project: p,
                    type: original,
                    allowTypeSelection: true,
                    onApply: (type, _, _) {
                      saved = type;
                      return true;
                    },
                  );
                },
              ),
            ),
          ),
        );
        Future<void> system(
          ArchitectWallSystemKind from,
          ArchitectWallSystemKind to,
        ) async {
          final field = find.byKey(ValueKey('wall-system-kind-${from.name}'));
          await tester.ensureVisible(field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(find.text(to.label(l)).last);
          await tester.pumpAndSettle();
        }

        await tester.enterText(
          find.byKey(const ValueKey('wall-layer-thickness-core')),
          '30',
        );
        await system(
          ArchitectWallSystemKind.layered,
          ArchitectWallSystemKind.roundLogs,
        );
        expect(find.text('25+12'), findsNothing);
        expect(find.byKey(const ValueKey('wall-system-overlap')), findsNothing);
        final diameter = find.byKey(const ValueKey('wall-layer-thickness-log'));
        await tester.enterText(diameter, '28');
        await tester.pump();
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('wall-active-composition')),
              )
              .data,
          contains('28'),
        );
        await system(
          ArchitectWallSystemKind.roundLogs,
          ArchitectWallSystemKind.studFrame,
        );
        await system(
          ArchitectWallSystemKind.studFrame,
          ArchitectWallSystemKind.roundLogs,
        );
        expect(tester.widget<TextFormField>(diameter).controller!.text, '28');
        await system(
          ArchitectWallSystemKind.roundLogs,
          ArchitectWallSystemKind.layered,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('wall-layer-thickness-core')),
              )
              .controller!
              .text,
          '30',
        );
        await system(
          ArchitectWallSystemKind.layered,
          ArchitectWallSystemKind.roundLogs,
        );
        if (const bool.fromEnvironment('LOG_WALL_QA')) {
          await tester.pumpAndSettle();
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          await tester.runAsync(() async {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'scratch/log_wall_editor_$language.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        // The type list is scoped to the active construction family.
        await tester.tap(find.byKey(const ValueKey('wall-composition-type')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('architect-wall-type-ext_25_12_eps')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('architect-wall-type-round_logs_240')),
          findsOneWidget,
        );
        Navigator.of(
          tester.element(find.byKey(const ValueKey('wall-catalog-list'))),
        ).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(saved!.system.isLog, isTrue);
        expect(saved!.totalThickness, .28);
        expect(saved!.name, isEmpty);
        expect(saved!.id, original.id);
        expect(saved!.labelId, 'round_logs_240');
      },
    );

    testWidgets('catalog selects construction first at 320px $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final types = ArchitectWallType.standardCatalog(includeSpecial: true);
      ArchitectWallType? selected;
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context)!;
              return Scaffold(
                body: ArchitectWallCatalogBrowser(
                  types: types,
                  activeType: types.first,
                  onSelect: (type) => selected = type,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      var kind = ArchitectWallSystemKind.layered;
      for (final next in [
        ArchitectWallSystemKind.roundLogs,
        ArchitectWallSystemKind.studFrame,
        ArchitectWallSystemKind.sandwichPanels,
      ]) {
        await tester.tap(
          find.byKey(ValueKey('wall-catalog-system-${kind.name}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(next.label(l)).last);
        await tester.pumpAndSettle();
        final id = types.firstWhere((t) => t.system.kind == next).id;
        expect(find.byKey(ValueKey('architect-wall-type-$id')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('architect-wall-type-ext_25_12_eps')),
          findsNothing,
        );
        await tester.tap(find.byKey(ValueKey('architect-wall-type-$id')));
        await tester.pumpAndSettle();
        expect(selected!.system.kind, next);
        kind = next;
      }
      expect(selected!.totalThickness, .2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reported house visual review of plan and solid log walls', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('LOG_WALL_QA')) return;
    final p = logHouse();
    final wallsOnly = p.copyWith(storeys: [p.activeStorey.copyWith(slabs: [])]);
    await tester.runAsync(() async {
      for (final entry in [('house', p), ('walls', wallsOnly)]) {
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.drawColor(Colors.white, BlendMode.src);
        final plan = ArchitectWallLayers.forProject(entry.$2);
        final bounds = plan.body.getBounds(), scale = 48.0;
        canvas.save();
        canvas.translate(220, 290);
        canvas.scale(scale, -scale);
        canvas.translate(-bounds.center.dx, -bounds.center.dy);
        canvas.drawPath(plan.body, Paint()..color = const Color(0xffefefef));
        canvas.drawPath(
          plan.body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 / scale
            ..color = Colors.black,
        );
        canvas.restore();
        canvas.save();
        canvas.translate(440, 0);
        await qa.drawMesh(
          canvas,
          Architect3dBuilder.buildProjectMesh(entry.$2),
          const Size(960, 700),
          Cad3DCamera(zoom: 1.05),
        );
        canvas.restore();
        final picture = recorder.endRecording(),
            image = await picture.toImage(1400, 700);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'scratch/log_wall_fixed_${entry.$1}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
    });
  });
}
