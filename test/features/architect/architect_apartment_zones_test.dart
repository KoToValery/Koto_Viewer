import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_material_layer.dart';
import 'package:kotoview/src/features/architect/services/architect_apartment_zones.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/rendering/architect_zone_painter_helper.dart';
import 'package:kotoview/src/features/architect/widgets/architect_zone_properties_card.dart';
import 'package:kotoview/src/features/architect/widgets/architect_zone_schedule_dialog.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tool_ui;

ArchitectZone rectangle(
  String id,
  double x, {
  bool apartment = false,
  String? owner,
  Offset? origin,
}) => ArchitectZone(
  id: id,
  number: id,
  name: id,
  category: ArchitectZoneCategory.living,
  kind: apartment ? ArchitectZoneKind.apartment : ArchitectZoneKind.room,
  apartmentId: owner,
  scheduleOrigin: origin,
  polygon: [
    Offset(x, 0),
    Offset(x + (apartment ? 5 : 2), 0),
    Offset(x + (apartment ? 5 : 2), apartment ? 5 : 2),
    Offset(x, apartment ? 5 : 2),
  ],
);

ArchitectStorey scene() => ArchitectStorey(
  id: 's',
  name: 'Floor',
  zoneScheduleOrigin: const Offset(12, -4),
  zones: [
    rectangle('a', 0, apartment: true, origin: const Offset(12, 0)),
    rectangle('b', 6, apartment: true, origin: const Offset(12, 5)),
    rectangle('r1', 1),
    rectangle('r2', 7),
    rectangle('free', 15),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Apartment contours are manual and survive serialization with room ownership and table origins',
    () {
      final original = scene();
      final restored = ArchitectStorey.fromJson(original.toJson());
      expect(restored.zones.first.isApartment, isTrue);
      expect(restored.zones.first.isAutoBoundary, isFalse);
      expect(restored.zones.first.scheduleOrigin, const Offset(12, 0));
      expect(restored.zones.where((z) => z.id == 'r1').single.apartmentId, 'a');
      final old = rectangle('old', 0).toJson()..remove('kind');
      expect(ArchitectZone.fromJson(old).kind, ArchitectZoneKind.room);
      final deleted = original.toJson();
      (deleted['zones'] as List).removeWhere((z) => z['id'] == 'a');
      expect(
        ArchitectStorey.fromJson(
          deleted,
        ).zones.where((z) => z.id == 'r1').single.apartmentId,
        isNull,
      );
    },
  );

  test(
    'Rooms are assigned automatically once; deleting or demoting the owner releases rooms',
    () {
      final zones = scene().zones;
      final groups = ArchitectApartmentZones.groups(
        scene().copyWith(zones: zones),
      );
      expect(groups.where((g) => g.id == 'a').single.netArea, 4);
      expect(groups.where((g) => g.id == 'b').single.netArea, 4);
      expect(groups.fold<double>(0, (sum, g) => sum + g.netArea), 12);
      final deleted = scene().copyWith(
        zones: zones.where((z) => z.id != 'a').toList(),
      );
      expect(deleted.zones.where((z) => z.apartmentId == 'a'), isEmpty);
      final demoted = scene().copyWith(
        zones: [
          for (final z in zones)
            z.id == 'a' ? z.copyWith(kind: ArchitectZoneKind.room) : z,
        ],
      );
      expect(demoted.zones.where((z) => z.apartmentId == 'a'), isEmpty);
    },
  );

  test(
    'Actual overlap handles a concave notch instead of using the room centre or bounds',
    () {
      final apartment = rectangle('a', 0, apartment: true).copyWith(
        polygon: const [
          Offset.zero,
          Offset(6, 0),
          Offset(6, 6),
          Offset(4, 6),
          Offset(4, 2),
          Offset(2, 2),
          Offset(2, 6),
          Offset(0, 6),
        ],
      );
      final acrossNotch = rectangle('across', 1).copyWith(
        polygon: const [Offset(1, 3), Offset(5, 3), Offset(5, 4), Offset(1, 4)],
      );
      final notch = rectangle('b', 0, apartment: true).copyWith(
        polygon: const [
          Offset(2, 2),
          Offset(3.5, 2),
          Offset(3.5, 6),
          Offset(2, 6),
        ],
      );
      // The room centre lies in B, but its two ends overlap A by 2 m²,
      // versus 1.5 m² in B. Its entire 4 m² belongs to A, only once.
      final storey = scene().copyWith(zones: [notch, apartment, acrossNotch]);
      expect(storey.zones.last.apartmentId, 'a');
      expect(
        ArchitectApartmentZones.groups(
          storey,
        ).firstWhere((g) => g.id == 'a').netArea,
        4,
      );
    },
  );

  test(
    'Largest overlap wins across multiple apartments, even below half the room',
    () {
      final storey = scene().copyWith(
        zones: [
          rectangle('a', 0, apartment: true),
          rectangle('b', 5, apartment: true),
          rectangle('c', 10, apartment: true),
          rectangle('split', 4.5, owner: 'a'),
          rectangle('partial', 9.9).copyWith(
            polygon: const [
              Offset(9.9, 4),
              Offset(11.9, 4),
              Offset(11.9, 8),
              Offset(9.9, 8),
            ],
          ),
        ],
      );
      expect(storey.zones[3].apartmentId, 'b');
      expect(storey.zones[4].apartmentId, 'c');
      final groups = ArchitectApartmentZones.groups(storey);
      expect(groups.firstWhere((g) => g.id == 'b').netArea, 4);
      expect(groups.firstWhere((g) => g.id == 'c').netArea, 8);
      expect(groups.expand((g) => g.rooms).map((r) => r.id).toSet().length, 2);
    },
  );

  test('Equal overlaps retain the owner; unowned ties use a stable ID', () {
    final a = rectangle('a', 0, apartment: true);
    final b = rectangle('b', 5, apartment: true);
    final unowned = rectangle('tie', 4);
    final owned = unowned.copyWith(id: 'owned', apartmentId: 'b');
    for (final apartments in [
      [b, a],
      [a, b],
    ]) {
      final storey = scene().copyWith(zones: [...apartments, unowned, owned]);
      expect(storey.zones[2].apartmentId, 'a');
      expect(storey.zones[3].apartmentId, 'b');
    }
  });

  test(
    'Edge and corner contact and stale links do not attach an outside room',
    () {
      final storey = scene().copyWith(
        zones: [
          rectangle('a', 0, apartment: true),
          rectangle('edge', 5, owner: 'a'),
          rectangle('corner', 5, owner: 'a').copyWith(
            polygon: const [
              Offset(5, 5),
              Offset(7, 5),
              Offset(7, 7),
              Offset(5, 7),
            ],
          ),
          rectangle('outside', 15, owner: 'missing'),
        ],
      );
      expect(storey.zones.skip(1).every((r) => r.apartmentId == null), isTrue);
    },
  );

  test(
    'Room and apartment edits, removal, undo and loading recalculate ownership',
    () {
      final a = rectangle('a', 0, apartment: true);
      final b = rectangle('b', 5, apartment: true);
      final room = rectangle('r', 4.5);
      final model = editing.seeded(scene().copyWith(zones: [a, b, room]));
      addTearDown(model.dispose);
      expect(model.project.activeStorey.zones.last.apartmentId, 'b');
      model.commit(
        model.project.updateActiveStorey(
          model.project.activeStorey.copyWith(
            zones: [
              a,
              b,
              room.copyWith(polygon: rectangle('r', 3.5).polygon),
            ],
          ),
        ),
      );
      expect(model.project.activeStorey.zones.last.apartmentId, 'a');
      model.undo();
      expect(model.project.activeStorey.zones.last.apartmentId, 'b');
      model.redo();
      expect(model.project.activeStorey.zones.last.apartmentId, 'a');
      final expanded = a.copyWith(
        polygon: const [Offset(0, 0), Offset(7, 0), Offset(7, 5), Offset(0, 5)],
      );
      final moved = scene().copyWith(zones: [expanded, b, room]);
      expect(moved.zones.last.apartmentId, 'a');
      final removed = moved.copyWith(
        zones: moved.zones.where((z) => z.id != 'a').toList(),
      );
      expect(removed.zones.last.apartmentId, 'b');
      final stale = moved.toJson();
      (stale['zones'] as List).last['apartmentId'] = 'b';
      expect(ArchitectStorey.fromJson(stale).zones.last.apartmentId, 'a');
    },
  );

  test(
    'Boundary snapping uses interior axes and exterior faces including their corner',
    () {
      const internal = ArchitectWall(
        id: 'i',
        startPoint: Offset.zero,
        endPoint: Offset(5, 0),
        location: ArchitectWallLocation.interior,
      );
      const outer = ArchitectWall(
        id: 'e',
        startPoint: Offset.zero,
        endPoint: Offset(5, 0),
        location: ArchitectWallLocation.exterior,
      );
      expect(
        ArchitectApartmentZones.snapBoundary(const Offset(2, .08), [
          internal,
        ], .2),
        const Offset(2, 0),
      );
      expect(
        ArchitectApartmentZones.snapBoundary(const Offset(2, .08), [outer], .2),
        const Offset(2, .125),
      );
      const vertical = ArchitectWall(
        id: 'v',
        startPoint: Offset.zero,
        endPoint: Offset(0, 5),
        location: ArchitectWallLocation.exterior,
      );
      expect(
        ArchitectApartmentZones.snapBoundary(const Offset(-.1, .1), [
          outer,
          vertical,
        ], .2),
        const Offset(-.125, .125),
      );
    },
  );

  test(
    'Separate schedules exclude apartment contours from net totals and have independently saved positions',
    () {
      final tables = ArchitectZonePainterHelper.scheduleTables(
        storey: scene(),
        zoomScale: 80,
      );
      expect(tables.length, 3);
      expect(
        tables.map((t) => t.group.id),
        containsAll(['a', 'b', 'unassigned']),
      );
      expect(
        tables.firstWhere((t) => t.group.id == 'a').group.apartment!.area,
        25,
      );
      expect(tables.firstWhere((t) => t.group.id == 'a').group.netArea, 4);
      expect(
        tables.firstWhere((t) => t.group.id == 'b').origin,
        const Offset(12, 5),
      );
      expect(
        tables.firstWhere((t) => t.group.id == 'a').storey.zones.single.id,
        'r1',
      );
    },
  );

  test('Room stamps have no opaque background or unselected fill', () {
    final model = editing.seeded(scene().copyWith(zones: [rectangle('r', 0)]));
    addTearDown(model.dispose);
    final canvas = ArchitectVectorCanvas();
    ArchitectTextScope(
      model.project.document,
      'plan:s',
      100,
      80,
      publication: true,
    ).run(() {
      ArchitectZonePainterHelper.drawZones(
        canvas: canvas,
        project: model.project,
        zoomScale: 80,
      );
    });
    expect(
      canvas.operations.whereType<ArchitectVectorPath>().where((p) => p.fill),
      isEmpty,
    );
    expect(canvas.operations.whereType<ArchitectVectorText>(), isNotEmpty);
  });

  test('Apartment stamps stay above their room labels on the plan', () {
    final model = editing.seeded(scene());
    addTearDown(model.dispose);
    final canvas = ArchitectVectorCanvas();
    ArchitectTextScope(
      model.project.document,
      'plan:s',
      100,
      80,
      publication: true,
    ).run(() {
      ArchitectZonePainterHelper.drawZones(
        canvas: canvas,
        project: model.project,
        zoomScale: 80,
      );
    });
    final labels = canvas.operations.whereType<ArchitectVectorText>().where(
      (t) => t.sources.contains('a'),
    );
    expect(labels, isNotEmpty);
    expect(labels.every((t) => t.bounds.bottom < 0), isTrue);
  });

  test(
    'Centimeter drawings publish square metres in every apartment table',
    () {
      final model = editing.seeded(scene());
      addTearDown(model.dispose);
      final l = lookupAppLocalizations(const Locale('bg'));
      final canvas = ArchitectVectorCanvas();
      ArchitectTextScope(
        model.project.document,
        'plan:s',
        100,
        80,
        units: ArchitectUnit.centimeters,
        publication: true,
      ).run(() {
        ArchitectZonePainterHelper.drawZoneSchedule(
          canvas: canvas,
          storey: scene(),
          zoomScale: 80,
          l10n: l,
        );
      });
      final text = canvas.operations
          .whereType<ArchitectVectorText>()
          .map((t) => t.text)
          .join('\n');
      expect(text, contains('m²'));
      expect(text, isNot(contains('cm²')));
      expect(text, contains(l.architectApartmentGross));
      expect(text, contains(l.architectApartmentNet));
      expect(text, contains('25 m²'));
      expect(text, contains('4 m²'));
    },
  );

  for (final locale in ['bg', 'en']) {
    testWidgets('Apartment properties and schedule fit a phone in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArchitectZonePropertiesCard(
              zone: scene().zones.first,
              zones: scene().zones,
              onZoneUpdated: (_) {},
              onDeleteZone: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArchitectZoneScheduleDialog(
              storey: scene(),
              initialApartmentId: 'b',
              units: ArchitectUnit.centimeters,
              onZoneUpdated: (_) {},
              onTableOriginChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('r2'), findsWidgets);
      expect(find.text('r1'), findsNothing);
    });
  }

  testWidgets(
    'Drawing an apartment assigns its rooms immediately and undo restores the previous drawing',
    (tester) async {
      final room = rectangle('room', 1);
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', zones: [room]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool_ui.choose(tester, Icons.space_dashboard_rounded);
      await tester.pumpAndSettle();
      await tool_ui.setMagnetic(tester, false);
      await tester.tap(find.byKey(const ValueKey('zone-draft-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apartment').last);
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-2, -2, 9, 9), padding: 180);
      await tester.pumpAndSettle();
      for (final point in const [
        Offset(-1, -1),
        Offset(5, -1),
        Offset(5, 5),
        Offset(-1, 5),
        Offset(-1, -1),
      ]) {
        await workspace.wallTap(tester, point);
      }
      await tester.pumpAndSettle();
      final apartment = model.project.activeStorey.zones
          .where((z) => z.isApartment)
          .single;
      expect(apartment.isAutoBoundary, isFalse);
      expect(model.project.activeStorey.zones.first.apartmentId, apartment.id);
      await tester.tap(find.byKey(const ValueKey('apartment-rooms')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('apartment-room-room')), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.zones.first.apartmentId, apartment.id);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.zones.first.apartmentId, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Dragging one apartment schedule leaves its sibling and the unassigned schedule in place',
    (tester) async {
      final model = editing.seeded(scene());
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool_ui.choose(tester, Icons.space_dashboard_rounded);
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(0, -8, 35, 25), padding: 180);
      await tester.pumpAndSettle();
      final before = model.project.activeStorey;
      final tables = ArchitectZonePainterHelper.scheduleTables(
        storey: before,
        project: model.project,
        zoomScale: workspace.camera(tester).scale,
        l10n: lookupAppLocalizations(const Locale('en')),
      );
      final target = tables.firstWhere((t) => t.group.id == 'b');
      final drag = await tester.startGesture(
        workspace.screen(tester, target.bounds.center),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await drag.moveBy(const Offset(40, 20));
      await drag.up();
      await tester.pumpAndSettle();
      final after = model.project.activeStorey;
      expect(after.zoneScheduleOrigin, before.zoneScheduleOrigin);
      expect(
        after.zones.first.scheduleOrigin,
        before.zones.first.scheduleOrigin,
      );
      expect(
        after.zones[1].scheduleOrigin,
        isNot(before.zones[1].scheduleOrigin),
      );
      model.undo();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.zones[1].scheduleOrigin,
        before.zones[1].scheduleOrigin,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
