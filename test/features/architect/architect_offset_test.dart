import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_offset.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_offset_geometry.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_polygon_geometry.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_offset_dialog.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_element_group_test.dart' as groups;
import 'architect_workspace_interaction_test.dart' as workspace;

const square = [Offset(0, 0), Offset(6, 0), Offset(6, 6), Offset(0, 6)];
const hole = [Offset(2, 2), Offset(3, 2), Offset(3, 3), Offset(2, 3)];
ArchitectCadPrimitive line(String id, Offset a, Offset b) =>
    ArchitectCadPrimitive(
      id: id,
      type: CadPrimitiveType.line,
      startPoint: a,
      endPoint: b,
    );
ArchitectStorey chain({bool walls = false, bool closed = false}) {
  final points = closed
      ? square
      : [Offset.zero, const Offset(4, 0), const Offset(4, 4)];
  final pairs = [
    for (var i = 0; i < (closed ? points.length : points.length - 1); i++)
      (points[i], points[(i + 1) % points.length]),
  ];
  return ArchitectStorey(
    id: 's',
    name: '',
    walls: !walls
        ? []
        : [
            for (var i = 0; i < pairs.length; i++)
              ArchitectWall(
                id: 'e$i',
                startPoint: i.isEven ? pairs[i].$1 : pairs[i].$2,
                endPoint: i.isEven ? pairs[i].$2 : pairs[i].$1,
              ),
          ],
    cadPrimitives: walls
        ? []
        : [
            for (var i = 0; i < pairs.length; i++)
              line(
                'e$i',
                i.isEven ? pairs[i].$1 : pairs[i].$2,
                i.isEven ? pairs[i].$2 : pairs[i].$1,
              ),
          ],
  );
}

OffsetArchitectElements offset(
  Set<String> ids, {
  Offset side = const Offset(8, -2),
  double distance = 1,
  Map<String, String> copies = const {},
  Map<String, String> groupCopies = const {},
  String? scope,
}) => OffsetArchitectElements(
  storeyId: 's',
  elementIds: ids,
  distance: distance,
  side: side,
  idMap: copies,
  groupIdMap: groupCopies,
  editingGroupId: scope,
);

Future<void> enterOffset(WidgetTester tester, String value) async {
  final field = tester.widget<TextField>(
    find.byKey(const ValueKey('architect-offset-distance')),
  );
  expect(field.readOnly, isTrue);
  expect(field.keyboardType, TextInputType.none);
  while (field.controller!.text.isNotEmpty) {
    await tester.tap(find.byKey(const ValueKey('architect-offset-key-⌫')));
    await tester.pump();
  }
  for (final key in value.split('')) {
    await tester.tap(find.byKey(ValueKey('architect-offset-key-$key')));
    await tester.pump();
  }
  expect(tester.testTextInput.isVisible, isFalse);
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final walls in [false, true]) {
    for (final closed in [false, true]) {
      test(
        'Offset ${walls ? 'wall' : 'line'} ${closed ? 'loop' : 'chain'} joins reversed segments, copies group and undoes once',
        () {
          final model = editing.seeded(chain(walls: walls, closed: closed));
          addTearDown(model.dispose);
          final ids = model.project.activeStorey.groupableIds;
          model.execute(
            GroupArchitectElements(
              storeyId: 's',
              groupId: 'g',
              elementIds: ids,
            ),
          );
          final before = model.project.toJson();
          final map = {for (final id in ids) id: 'copy_$id'};
          model.execute(offset(ids, copies: map, groupCopies: {'g': 'copy_g'}));
          final s = model.project.activeStorey;
          expect(s.groups, hasLength(2));
          expect(s.groups.last.elementIds, map.values.toSet());
          final p0 = walls
              ? s.walls.firstWhere((e) => e.id == 'copy_e0').startPoint
              : s.cadPrimitives.firstWhere((e) => e.id == 'copy_e0').startPoint;
          final p1 = walls
              ? s.walls.firstWhere((e) => e.id == 'copy_e0').endPoint
              : s.cadPrimitives.firstWhere((e) => e.id == 'copy_e0').endPoint;
          final p2 = walls
              ? s.walls.firstWhere((e) => e.id == 'copy_e1').endPoint
              : s.cadPrimitives.firstWhere((e) => e.id == 'copy_e1').endPoint;
          expect(p0, closed ? const Offset(-1, -1) : const Offset(0, -1));
          expect(p1, closed ? const Offset(7, -1) : const Offset(5, -1));
          expect(p2, p1);
          final restored = ArchitectProject.fromJson(
            jsonDecode(jsonEncode(model.project.toJson())),
          );
          expect(
            restored.activeStorey.groups.last.elementIds,
            map.values.toSet(),
          );
          model.undo();
          expect(model.project.toJson(), before);
          model.redo();
          expect(model.project.activeStorey.groups, hasLength(2));
        },
      );
    }
  }
  test(
    'Clockwise and counterclockwise contours expand and contract at exact distances',
    () {
      for (final p in [square, square.reversed.toList()]) {
        final expanded = BimOffsetGeometry.ring(p, 1);
        expect(expanded.toSet(), {
          const Offset(-1, -1),
          const Offset(7, -1),
          const Offset(7, 7),
          const Offset(-1, 7),
        });
        final inner = BimOffsetGeometry.ring(p, -1);
        expect(inner.toSet(), {
          const Offset(1, 1),
          const Offset(5, 1),
          const Offset(5, 5),
          const Offset(1, 5),
        });
        expect(() => BimOffsetGeometry.ring(p, -4), throwsArgumentError);
      }
      final concave = [
        const Offset(0, 0),
        const Offset(5, 0),
        const Offset(5, 2),
        const Offset(2, 2),
        const Offset(2, 5),
        const Offset(0, 5),
      ];
      expect(
        BimPolygonGeometry.valid(BimOffsetGeometry.ring(concave, .2)),
        isTrue,
      );
      expect(() => BimOffsetGeometry.ring(concave, -1.1), throwsArgumentError);
      final translated = square
          .map((p) => p + const Offset(1000000, -1000000))
          .toList();
      expect(
        BimOffsetGeometry.ring(translated, 1).first,
        const Offset(999999, -1000001),
      );
    },
  );
  test(
    'Slabs, roofs, hatches, rectangles, circles, beams, stairs, voids and manual zones preserve native properties',
    () {
      final roof = ArchitectRoofPlane(
        id: 'roof',
        storeyId: 's',
        points: square,
        holes: [hole],
        attachToWalls: false,
        baseElevationOffset: 4,
        slopeDegrees: 30,
        reverseSlope: true,
        eavesEdgeIndex: 2,
      );
      final s = ArchitectStorey(
        id: 's',
        name: '',
        slabs: [
          const ArchitectSlab(
            id: 'slab',
            polygon: square,
            holes: [hole],
            thickness: .33,
            assemblyId: 'assembly',
            coreTopOffset: .4,
          ),
        ],
        roofs: [roof],
        cadPrimitives: [
          const ArchitectCadPrimitive(
            id: 'hatch',
            type: CadPrimitiveType.hatch,
            startPoint: Offset.zero,
            endPoint: Offset(6, 6),
            holes: [hole],
            hatchAngle: 35,
            hatchScale: 2,
          ),
          const ArchitectCadPrimitive(
            id: 'rect',
            type: CadPrimitiveType.rect,
            startPoint: Offset.zero,
            endPoint: Offset(6, 6),
          ),
          const ArchitectCadPrimitive(
            id: 'circle',
            type: CadPrimitiveType.circle,
            startPoint: Offset(2, 2),
            endPoint: Offset(4, 2),
          ),
        ],
        beams: [
          const ArchitectBeam(
            id: 'beam',
            startPoint: Offset.zero,
            endPoint: Offset(6, 0),
            width: .4,
            depth: .7,
          ),
        ],
        stairs: [
          const ArchitectStair(
            id: 'stair',
            startPoint: Offset.zero,
            endPoint: Offset(6, 0),
          ),
        ],
        openings: [
          const ArchitectOpening(
            id: 'void',
            boundary: square,
            type: OpeningType.floorVoid,
          ),
        ],
        zones: [
          const ArchitectZone(
            id: 'zone',
            name: 'Custom',
            category: ArchitectZoneCategory.custom,
            polygon: square,
            isAutoBoundary: false,
          ),
        ],
      );
      final next = ArchitectOffset.apply(
        s,
        s.groupableIds,
        distance: .5,
        side: const Offset(9, -3),
      );
      expect(next.slabs.single.polygon.first, const Offset(-.5, -.5));
      expect(next.slabs.single.holes, [hole]);
      expect(next.slabs.single.thickness, .33);
      expect(next.slabs.single.assemblyId, 'assembly');
      expect(next.cadPrimitives.first.hatchAngle, 35);
      expect(next.cadPrimitives.first.holes, [hole]);
      expect(
        (next.cadPrimitives.last.endPoint - next.cadPrimitives.last.startPoint)
            .distance,
        2.5,
      );
      expect(next.beams.single.startPoint, const Offset(0, -.5));
      expect(next.beams.single.width, .4);
      expect(next.stairs.single.startPoint, const Offset(0, -.5));
      expect(next.openings.single.boundary.first, const Offset(-.5, -.5));
      expect(next.zones.single.polygon.first, const Offset(-.5, -.5));
      for (final p in square) {
        expect(
          next.roofs.single.undersideElevationAt(p),
          closeTo(roof.undersideElevationAt(p), 1e-9),
        );
      }
      expect(next.roofs.single.holes, [hole]);
      expect(next.roofs.single.eavesEdgeIndex, 2);
    },
  );
  test(
    'Concentric curved wall offsets preserve bulge, center and hosted identities',
    () {
      final wall = ArchitectWall(
        id: 'wall',
        startPoint: Offset.zero,
        endPoint: const Offset(8, 0),
        arcBulge: .5,
        doors: [
          ArchitectDoor(
            id: 'door',
            uuid: 'door_uuid',
            wallId: 'wall',
            offsetRatio: .5,
            width: .9,
          ),
        ],
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [wall]),
      );
      addTearDown(model.dispose);
      final side = wall.arc!.center;
      model.execute(
        offset({'wall'}, side: side, copies: {'wall': 'copy_wall'}),
      );
      final next = model.project.activeStorey.walls.last;
      expect(next.arc!.radius, closeTo(wall.arc!.radius - 1, 1e-8));
      expect((next.arc!.center - wall.arc!.center).distance, lessThan(1e-8));
      expect(next.arcBulge, wall.arcBulge);
      expect(next.doors.single.id, isNot('door'));
      expect(next.doors.single.wallId, 'copy_wall');
      expect(next.doors.single.offsetRatio, closeTo(.5, 1e-8));
      expect(model.project.activeStorey.walls.first.toJson(), wall.toJson());
    },
  );
  test(
    'Copy inside group adds members; changing a member keeps its identity and group',
    () {
      final model = editing.seeded(chain());
      addTearDown(model.dispose);
      model.execute(
        const GroupArchitectElements(
          storeyId: 's',
          groupId: 'g',
          elementIds: {'e0', 'e1'},
        ),
      );
      model.execute(offset({'e0'}, copies: {'e0': 'c'}, scope: 'g'));
      expect(model.project.activeStorey.groups.single.elementIds, {
        'e0',
        'e1',
        'c',
      });
      model.undo();
      expect(model.project.activeStorey.groups.single.elementIds, {'e0', 'e1'});
      model.execute(offset({'e0'}));
      expect(model.project.activeStorey.groups.single.elementIds, {'e0', 'e1'});
      expect(
        model.project.activeStorey.cadPrimitives
            .firstWhere((e) => e.id == 'e1')
            .startPoint,
        const Offset(4, 4),
      );
      expect(
        model.project.activeStorey.cadPrimitives
            .firstWhere((e) => e.id == 'e0')
            .startPoint,
        const Offset(0, -1),
      );
    },
  );
  test(
    'Invalid operations are atomic: holes, branching, self-intersection, unsupported members and ID collisions',
    () {
      final s = ArchitectStorey(
        id: 's',
        name: '',
        slabs: [
          const ArchitectSlab(id: 'slab', polygon: square, holes: [hole]),
        ],
        columns: [const ArchitectColumn(id: 'col', position: Offset(9, 9))],
        cadPrimitives: [
          line('a', Offset.zero, const Offset(3, 0)),
          line('b', const Offset(3, 0), const Offset(3, 3)),
          line('c', const Offset(3, 0), const Offset(5, 0)),
        ],
      );
      final model = editing.seeded(s);
      addTearDown(model.dispose);
      final before = model.project.toJson();
      for (final cmd in [
        offset({'slab'}, side: const Offset(1, 1), distance: 2.5),
        offset({'a', 'b', 'c'}),
        offset({'a', 'col'}),
        offset({'missing'}),
        offset({'a'}, copies: {'a': 'col'}),
        offset({'a'}, copies: {'a': 'b'}),
        offset({'a'}, distance: double.nan),
        offset({'a'}, distance: 0),
        offset({'a'}, side: const Offset(double.infinity, 0)),
      ]) {
        expect(() => model.execute(cmd), throwsArgumentError);
        expect(model.project.toJson(), before);
      }
      expect(ArchitectOffset.supports(s, {'a', 'col'}), isFalse);
      expect(ArchitectOffset.supports(s, {'slab', 'a'}), isTrue);
      expect(model.canUndo, isFalse);
    },
  );
  test(
    'A line-arc wall junction offsets with an exact circular intersection',
    () {
      final arc = ArchitectWall(
        id: 'arc',
        startPoint: const Offset(4, 0),
        endPoint: const Offset(8, 0),
        arcBulge: .5,
      );
      final s = ArchitectStorey(
        id: 's',
        name: '',
        walls: [
          const ArchitectWall(
            id: 'straight',
            startPoint: Offset.zero,
            endPoint: Offset(4, 0),
          ),
          arc,
        ],
      );
      final result = ArchitectOffset.apply(
        s,
        {'straight', 'arc'},
        distance: .5,
        side: const Offset(1, -2),
      );
      final a = result.walls.first, b = result.walls.last;
      expect((a.endPoint - b.startPoint).distance, lessThan(1e-8));
      expect(a.startPoint, const Offset(0, -.5));
      expect((b.arc!.center - arc.arc!.center).distance, lessThan(1e-8));
      expect(b.arc!.radius, closeTo(arc.arc!.radius + .5, 1e-8));
    },
  );
  test(
    'A closed chain of many arcs stays circular without a tessellation limit',
    () {
      const count = 40;
      Offset point(int i) =>
          Offset(
            math.cos(i * 2 * math.pi / count),
            math.sin(i * 2 * math.pi / count),
          ) *
          10;
      final s = ArchitectStorey(
        id: 's',
        name: '',
        walls: [
          for (var i = 0; i < count; i++)
            ArchitectWall(
              id: 'arc$i',
              startPoint: point(i),
              endPoint: point((i + 1) % count),
              arcBulge: math.tan(math.pi / (2 * count)),
            ),
        ],
      );
      final result = ArchitectOffset.apply(
        s,
        s.groupableIds,
        distance: 1,
        side: const Offset(20, 0),
      );
      for (final e in result.walls) {
        expect(e.arc!.radius, closeTo(11, 1e-7));
        expect(e.arc!.center.distance, lessThan(1e-7));
      }
    },
  );
  test(
    'Automatic room boundaries follow a changed wall loop in the same Undo step',
    () {
      final s = chain(walls: true, closed: true).copyWith(
        zones: [
          const ArchitectZone(
            id: 'zone',
            name: 'Room',
            category: ArchitectZoneCategory.living,
            polygon: square,
            seedPoint: Offset(3, 3),
          ),
        ],
      );
      final model = editing.seeded(s);
      addTearDown(model.dispose);
      final before = model.project.toJson();
      model.execute(
        offset({'e0', 'e1', 'e2', 'e3'}, side: const Offset(3, 3), distance: 1),
      );
      final zone = model.project.activeStorey.zones.single;
      expect(zone.isAutoBoundary, isTrue);
      expect(zone.area, closeTo(3.75 * 3.75, .02));
      model.undo();
      expect(model.project.toJson(), before);
    },
  );
  test('Offset copies use an independent roof assembly group', () {
    final s = ArchitectStorey(
      id: 's',
      name: '',
      roofs: [
        ArchitectRoofPlane(
          id: 'r1',
          storeyId: 's',
          points: square,
          roofGroupId: 'roof_group',
          attachToWalls: false,
        ),
        ArchitectRoofPlane(
          id: 'r2',
          storeyId: 's',
          points: square,
          roofGroupId: 'roof_group',
          attachToWalls: false,
        ),
      ],
    );
    final result = ArchitectOffset.apply(
      s,
      {'r1', 'r2'},
      distance: .2,
      side: const Offset(8, -2),
      idMap: {'r1': 'c1', 'r2': 'c2'},
    );
    expect(result.roofs.take(2).map((r) => r.roofGroupId), [
      'roof_group',
      'roof_group',
    ]);
    expect(result.roofs[2].roofGroupId, result.roofs[3].roofGroupId);
    expect(result.roofs[2].roofGroupId, isNot('roof_group'));
  });
  testWidgets(
    'Group offset previews, creates a new group and cancels without a model change',
    (tester) async {
      final model = editing.seeded(chain());
      addTearDown(model.dispose);
      model.execute(
        const GroupArchitectElements(
          storeyId: 's',
          groupId: 'g',
          elementIds: {'e0', 'e1'},
        ),
      );
      await workspace.open(tester, model);
      workspace.camera(tester).fit(const Rect.fromLTRB(-4, -4, 9, 8));
      await tester.pumpAndSettle();
      await editing.contextHold(tester, const Offset(2, 0));
      await groups.action(tester, BimEditAction.offset);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('architect-offset-copy')),
            )
            .value,
        isTrue,
      );
      await enterOffset(tester, '1');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('architect-offset-start')));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(2, -2)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(2, -1.5)));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.cadPrimitives, hasLength(2));
      expect(
        workspace.overlay(tester).project.activeStorey.cadPrimitives,
        hasLength(4),
      );
      await tester.tap(find.byKey(const ValueKey('architect-offset-cancel')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.cadPrimitives, hasLength(2));
      await mouse.removePointer();
      await editing.contextHold(tester, const Offset(2, 0));
      await groups.action(tester, BimEditAction.offset);
      await enterOffset(tester, '1');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('architect-offset-start')));
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(2, -2)));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.cadPrimitives, hasLength(4));
      expect(model.project.activeStorey.groups, hasLength(2));
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.cadPrimitives, hasLength(2));
      expect(model.project.activeStorey.groups, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'Phone $locale dialog validates input and converts millimetres; offset changes single member inside group',
      (tester) async {
        final model = editing.seeded(chain());
        addTearDown(model.dispose);
        model.setUnits(ArchitectUnit.millimeters);
        model.execute(
          const GroupArchitectElements(
            storeyId: 's',
            groupId: 'g',
            elementIds: {'e0', 'e1'},
          ),
        );
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        Future<void> capture(String name) async {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('build/architect_offset')
              ..createSync(recursive: true);
            File(
              '${folder.path}/$name-$locale.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        workspace.camera(tester).fit(const Rect.fromLTRB(-2, -3, 7, 7));
        await tester.pumpAndSettle();
        await editing.contextHold(tester, const Offset(2, 0));
        await groups.action(tester, BimEditAction.editGroup);
        await editing.contextHold(tester, const Offset(2, 0));
        await groups.action(tester, BimEditAction.offset);
        final submit = find.byKey(const ValueKey('architect-offset-start'));
        expect(tester.widget<TextButton>(submit).onPressed, isNull);
        await enterOffset(tester, '0');
        expect(tester.widget<TextButton>(submit).onPressed, isNull);
        await enterOffset(tester, '250.5');
        await capture('dialog');
        await tester.tap(find.byKey(const ValueKey('architect-offset-copy')));
        await tester.pump();
        await tester.tap(submit);
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: workspace.screen(tester, const Offset(2, -1)),
        );
        await mouse.moveTo(workspace.screen(tester, const Offset(2, -.5)));
        await tester.pumpAndSettle();
        await capture('preview');
        await mouse.removePointer();
        await tester.tapAt(workspace.screen(tester, const Offset(2, -1)));
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.cadPrimitives, hasLength(2));
        expect(
          model.project.activeStorey.cadPrimitives
              .firstWhere((e) => e.id == 'e0')
              .startPoint
              .dy,
          closeTo(-.2505, 1e-8),
        );
        expect(model.project.activeStorey.groups.single.elementIds, {
          'e0',
          'e1',
        });
        expect(
          find.byKey(const ValueKey('architect-group-done')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Offset dialog cancellation does not start a canvas operation', (
    tester,
  ) async {
    BimElementOffsetOptions? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showBimElementOffsetDialog(
                context,
                unitToMeters: 1,
                unitSymbol: 'm',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
