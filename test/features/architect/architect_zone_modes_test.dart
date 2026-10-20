import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/adapters/architect_element_adapters.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/models/architect_zone_presets.dart';
import 'package:kotoview/src/features/architect/rendering/architect_zone_painter_helper.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_editor.dart';
import 'package:kotoview/src/features/architect/services/architect_room_detector.dart';
import 'package:kotoview/src/features/architect/services/architect_zone_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_zone_properties_card.dart';
import 'package:kotoview/src/features/architect/widgets/architect_zone_drafting_bar.dart';
import 'package:kotoview/src/features/architect/widgets/architect_workspace_settings_dialog.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tool_ui;

const zone = ArchitectZone(
  id: 'z',
  number: '101',
  name: 'Room',
  category: ArchitectZoneCategory.living,
  polygon: [Offset(1, 1), Offset(3, 1), Offset(3, 3), Offset(1, 3)],
);
const walls = [
  ArchitectWall(id: 'a', startPoint: Offset.zero, endPoint: Offset(6, 0)),
  ArchitectWall(id: 'b', startPoint: Offset(6, 0), endPoint: Offset(6, 5)),
  ArchitectWall(id: 'c', startPoint: Offset(6, 5), endPoint: Offset(0, 5)),
  ArchitectWall(id: 'd', startPoint: Offset(0, 5), endPoint: Offset.zero),
];

Widget localized(Widget child, String locale) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Automatic contours resist moves and polygon edits; manual contours move',
    () {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: 'Floor', zones: [zone]),
      );
      addTearDown(model.dispose);
      const adapter = ArchitectZoneEditingAdapter();
      expect(adapter.translate(zone, const Offset(3, 2)), same(zone));
      model.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'z',
          delta: Offset(3, 2),
        ),
      );
      expect(model.project.activeStorey.zones.single.polygon, zone.polygon);
      expect(
        () => const UpdateArchitectPolygon(
          storeyId: 's',
          elementId: 'z',
          polygon: [Offset.zero, Offset(4, 0), Offset(4, 4), Offset(0, 4)],
        ).apply(model.project),
        throwsArgumentError,
      );
      final manual = zone.copyWith(isAutoBoundary: false);
      expect(
        adapter.translate(manual, const Offset(3, 2)).polygon.first,
        const Offset(4, 3),
      );
      final tool = ArchitectZoneTool();
      addTearDown(tool.dispose);
      tool.startEditingZone(zone);
      expect(tool.isEditingZone, isFalse);
      expect(
        tool.startExtrude(
          zone: zone,
          edgeIndex: 0,
          pointerModel: const Offset(2, 1),
        ),
        isFalse,
      );
    },
  );

  test(
    'Returning to auto expands a manual subset to the full room, rejects leaks',
    () {
      final restored = ArchitectRoomDetector.automaticZone(
        zone.copyWith(isAutoBoundary: false),
        walls,
      );
      expect(restored, isNotNull);
      expect(restored!.isAutoBoundary, isTrue);
      expect(restored.area, greaterThan(24));
      expect(restored.containsPoint(restored.seedPoint!), isTrue);
      // A 10 cm opening in a wall must leak to the exterior.
      final leaking = [
        ...walls.take(3),
        const ArchitectWall(
          id: 'd1',
          startPoint: Offset(0, 5),
          endPoint: Offset(0, 2.55),
        ),
        const ArchitectWall(
          id: 'd2',
          startPoint: Offset(0, 2.45),
          endPoint: Offset.zero,
        ),
      ];
      expect(ArchitectRoomDetector.automaticZone(zone, leaking), isNull);
    },
  );

  test(
    'Concave rooms have an internal seed even when their centroid is outside',
    () {
      final concave = zone.copyWith(
        polygon: const [
          Offset.zero,
          Offset(6, 0),
          Offset(6, 1),
          Offset(1, 1),
          Offset(1, 6),
          Offset(0, 6),
        ],
      );
      expect(concave.containsPoint(concave.centroid), isFalse);
      expect(concave.interiorPoint, isNotNull);
      expect(concave.containsPoint(concave.interiorPoint!), isTrue);
    },
  );

  for (final locale in ['bg', 'en']) {
    testWidgets('Zone dropdowns fit a narrow phone in $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tool = ArchitectZoneTool();
      addTearDown(tool.dispose);
      await tester.pumpWidget(
        localized(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ArchitectZoneDraftingBar(
                tool: tool,
                category: ArchitectZoneCategory.storage,
                onClose: () {},
                onUndo: () {},
                onCancel: () {},
                onOpenScheduleTable: () {},
                onPlaceTable: () {},
              ),
              ArchitectZonePropertiesCard(
                zone: zone.copyWith(category: ArchitectZoneCategory.storage),
                onZoneUpdated: (_) {},
                onDeleteZone: () {},
                onClose: () {},
                onOpenScheduleTable: () {},
              ),
            ],
          ),
          locale,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButton<ArchitectZoneCategory>).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final l = lookupAppLocalizations(Locale(locale));
      expect(find.text(l.architectZoneCatBedroom), findsOneWidget);
    });
  }

  testWidgets('Mode checkbox restores full room and supports Undo', (
    tester,
  ) async {
    final model = editing.seeded(
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        zones: [zone],
        walls: walls,
      ),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await tool_ui.choose(tester, Icons.space_dashboard_rounded);
    await tester.pumpAndSettle();
    await workspace.wallTap(tester, const Offset(2, 2));
    await tester.pumpAndSettle();
    final checkbox = find.byKey(const ValueKey('zone-manual-mode'));
    expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.zones.single.isAutoBoundary, isFalse);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.zones.single.isAutoBoundary, isTrue);
    expect(model.project.activeStorey.zones.single.area, greaterThan(24));
    model.undo();
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.zones.single.isAutoBoundary, isFalse);
    expect(model.project.activeStorey.zones.single.area, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Manual zone offset vertex and edge grips edit the actual contour',
    (tester) async {
      final manual = zone.copyWith(
        isAutoBoundary: false,
        polygon: const [Offset.zero, Offset(6, 0), Offset(6, 5), Offset(0, 5)],
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', zones: [manual]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool_ui.choose(tester, Icons.space_dashboard_rounded);
      await tester.pumpAndSettle();
      await tool_ui.setMagnetic(tester, false);
      await workspace.wallTap(tester, const Offset(3, 2));
      await tester.pumpAndSettle();
      workspace.camera(tester).fit(manual.bounds, padding: 200);
      await tester.pumpAndSettle();
      final scale = workspace.camera(tester).scale;
      final grip = ArchitectPolygonEditor.offsetVertexHandle(
        manual.polygon,
        0,
        scale,
      );
      final gesture = await tester.startGesture(workspace.screen(tester, grip));
      await tester.pump(const Duration(milliseconds: 281));
      await gesture.moveBy(Offset(-scale, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.zones.single.polygon.first.dx,
        closeTo(-1, .03),
      );
      final before = model.project.activeStorey.zones.single;
      final edge = ArchitectPolygonEditor.offsetEdgeHandle(
        before.polygon,
        1,
        scale,
      );
      final edgeGesture = await tester.startGesture(
        workspace.screen(tester, edge),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await edgeGesture.moveBy(Offset(scale, 0));
      await tester.pump();
      await edgeGesture.up();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.zones.single.bounds.right,
        closeTo(7, .03),
      );
      expect(model.project.activeStorey.zones.single.isAutoBoundary, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Open boundaries retain manual mode and display a localized explanation',
    (tester) async {
      final manual = zone.copyWith(isAutoBoundary: false);
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 'Floor',
          zones: [manual],
          walls: walls.take(3).toList(),
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tool_ui.choose(tester, Icons.space_dashboard_rounded);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(2, 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zone-manual-mode')));
      await tester.pump();
      expect(model.project.activeStorey.zones.single.isAutoBoundary, isFalse);
      expect(
        find.text(
          lookupAppLocalizations(const Locale('en')).architectZoneBoundaryOpen,
        ),
        findsOneWidget,
      );
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Automatic zones offer no contour or movement actions', (
    tester,
  ) async {
    final model = editing.seeded(
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        zones: [zone],
        walls: walls,
      ),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await tool_ui.choose(tester, Icons.space_dashboard_rounded);
    await tester.pumpAndSettle();
    await workspace.wallTap(tester, const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('architect-selection-move')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('architect-selection-new-point')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('architect-selection-mirror-move')),
      findsNothing,
    );
    final drag = await tester.startGesture(
      workspace.screen(tester, const Offset(2, 2)),
    );
    await tester.pump(const Duration(milliseconds: 281));
    await drag.moveBy(const Offset(30, 10));
    await drag.up();
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.zones.single.polygon, zone.polygon);
    expect(model.undoCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Renamed presets persist, and untouched defaults follow the locale',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: 'Floor', walls: walls),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.tap(find.byKey(const ValueKey('architect-settings')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-settings-zone-presets')),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('zone-preset-category.living'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Studio');
      final floorSection = find.text(
        lookupAppLocalizations(const Locale('en')).architectZoneFloorFinish,
      );
      await tester.ensureVisible(floorSection);
      await tester.tap(floorSection);
      await tester.pumpAndSettle();
      final floorField = find.byKey(const ValueKey('zone-preset-floor.0'));
      await tester.ensureVisible(floorField);
      await tester.enterText(floorField, 'Bamboo');
      await tester.tap(find.byKey(const ValueKey('architect-settings-save')));
      await tester.pumpAndSettle();
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString('architect_zone_presets'),
        contains('Studio'),
      );
      await tester.pumpWidget(const SizedBox());
      await workspace.open(tester, model);
      await tester.tap(find.byKey(const ValueKey('architect-settings')));
      await tester.pumpAndSettle();
      final dialog = tester.widget<ArchitectWorkspaceSettingsDialog>(
        find.byType(ArchitectWorkspaceSettingsDialog),
      );
      expect(
        dialog.settings.zonePresets.overrides['category.living'],
        'Studio',
      );
      expect(dialog.settings.zonePresets.overrides['floor.0'], 'Bamboo');
      await tester.tap(find.byKey(const ValueKey('architect-settings-save')));
      await tester.pumpAndSettle();
      await tool_ui.choose(tester, Icons.space_dashboard_rounded);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.zones.single.name, 'Studio');
      expect(model.project.activeStorey.zones.single.floorFinish, 'Bamboo');
      final bg = lookupAppLocalizations(const Locale('bg'));
      final en = lookupAppLocalizations(const Locale('en'));
      const defaults = ArchitectZonePresets();
      expect(
        defaults.categoryName(ArchitectZoneCategory.bedroom, bg),
        bg.architectZoneCatBedroom,
      );
      expect(
        defaults.categoryName(ArchitectZoneCategory.bedroom, en),
        en.architectZoneCatBedroom,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('Room stamp shrinks with the drawing when zooming out', () async {
    Future<int> badgeWidth(double scale) async {
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', zones: [zone]),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..translate(100, 100)
        ..scale(scale)
        ..translate(-2, -2);
      ArchitectZonePainterHelper.drawZones(
        canvas: canvas,
        project: model.project,
        zoomScale: scale,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var left = 200, right = -1;
      for (var x = 0; x < 200; x++) {
        for (var y = 80; y < 120; y++) {
          final i = (y * 200 + x) * 4;
          if (bytes.getUint8(i + 3) > 200 &&
              bytes.getUint8(i) < 40 &&
              bytes.getUint8(i + 1) < 40 &&
              bytes.getUint8(i + 2) < 50) {
            if (x < left) left = x;
            if (x > right) right = x;
          }
        }
      }
      image.dispose();
      picture.dispose();
      model.dispose();
      return right - left + 1;
    }

    final normal = await badgeWidth(80);
    final distant = await badgeWidth(40);
    expect(normal, greaterThan(20));
    expect(distant / normal, closeTo(.5, .1));
  });
}
