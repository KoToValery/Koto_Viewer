import 'architect_tool_test_helper.dart' as tool_ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_polygon_geometry.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

const polygon = [Offset(0, 0), Offset(8, 0), Offset(8, 6), Offset(0, 6)];
const kinds = ['wall', 'beam', 'line', 'rect', 'slab', 'zone', 'opening'];

ArchitectStorey fixture(String kind) => ArchitectStorey(
  id: 's',
  name: 's',
  walls: kind == 'wall'
      ? [
          editing
              .wall('p', Offset.zero, const Offset(8, 0))
              .addDoor(
                const ArchitectDoor(
                  id: 'd',
                  wallId: 'p',
                  uuid: 'door',
                  offsetRatio: .75,
                ),
              ),
        ]
      : [],
  beams: kind == 'beam'
      ? const [
          ArchitectBeam(
            id: 'p',
            startPoint: Offset.zero,
            endPoint: Offset(8, 0),
            width: .31,
            depth: .72,
            label: 'Beam',
          ),
        ]
      : [],
  cadPrimitives: kind == 'line' || kind == 'rect'
      ? [
          ArchitectCadPrimitive(
            id: 'p',
            type: kind == 'line'
                ? CadPrimitiveType.line
                : CadPrimitiveType.rect,
            startPoint: Offset.zero,
            endPoint: kind == 'line' ? const Offset(8, 0) : const Offset(8, 6),
            colorValue: 0xFF123456,
            strokeWidth: 3,
          ),
        ]
      : [],
  slabs: kind == 'slab'
      ? const [
          ArchitectSlab(
            id: 'p',
            polygon: polygon,
            thickness: .27,
            label: 'Floor',
          ),
        ]
      : [],
  zones: kind == 'zone'
      ? const [
          ArchitectZone(
            id: 'p',
            name: 'Room',
            category: ArchitectZoneCategory.office,
            polygon: polygon,
            targetArea: 60,
          ),
        ]
      : [],
  openings: kind == 'opening'
      ? const [
          ArchitectOpening(
            id: 'p',
            boundary: polygon,
            type: OpeningType.elevator,
            label: 'Lift',
          ),
        ]
      : [],
);

void main() {
  for (final kind in kinds) {
    test('New point preserves native $kind data and geometry; one Undo', () {
      final model = editing.seeded(fixture(kind));
      addTearDown(model.dispose);
      final original = model.project;
      final beforePath = InsertArchitectElementPoint.pathOf(
        original.activeStorey,
        'p',
      )!;
      model.execute(
        const InsertArchitectElementPoint(
          storeyId: 's',
          elementId: 'p',
          point: Offset(3, .02),
          newElementId: 'next',
        ),
      );
      final storey = model.project.activeStorey;
      final after = InsertArchitectElementPoint.pathOf(storey, 'p')!;
      if (beforePath.closed) {
        expect(after.points, [
          polygon.first,
          const Offset(3, 0),
          ...polygon.skip(1),
        ]);
        expect(BimPolygonGeometry.signedArea(after.points), 48);
        expect(after.points, isNot(same(beforePath.points)));
        if (kind == 'slab') expect(storey.slabs.single.thickness, .27);
        if (kind == 'zone') expect(storey.zones.single.targetArea, 60);
        if (kind == 'opening') {
          expect(storey.openings.single.type, OpeningType.elevator);
        }
        if (kind == 'rect') expect(storey.cadPrimitives.single.strokeWidth, 3);
      } else {
        expect(after.points, [Offset.zero, const Offset(3, 0)]);
        final second = InsertArchitectElementPoint.pathOf(storey, 'next')!;
        expect(second.points, [const Offset(3, 0), const Offset(8, 0)]);
        if (kind == 'wall') {
          expect(storey.walls.first.connectEnd, isTrue);
          expect(storey.walls.last.connectStart, isTrue);
          expect(storey.walls.last.doors.single.wallId, 'next');
          expect(storey.walls.last.doors.single.uuid, 'door');
          expect(storey.walls.last.doors.single.offsetRatio, .6);
        }
        if (kind == 'beam') {
          expect(storey.beams.last.depth, .72);
          expect(storey.beams.last.width, .31);
        }
        if (kind == 'line') {
          expect(storey.cadPrimitives.last.colorValue, 0xFF123456);
        }
      }
      model.undo();
      expect(identical(model.project, original), isTrue);
      expect(model.canUndo, isFalse);
    });
  }

  for (final kind in kinds) {
    test(
      'Midpoint insertion identifies the $kind segment from an off-center pick',
      () {
        final model = editing.seeded(fixture(kind));
        addTearDown(model.dispose);
        final original = model.project;
        model.execute(
          const InsertArchitectElementPoint(
            storeyId: 's',
            elementId: 'p',
            point: Offset(1, .02),
            newElementId: 'next',
            atMidpoint: true,
          ),
        );
        final path = InsertArchitectElementPoint.pathOf(
          model.project.activeStorey,
          'p',
        )!;
        expect(path.points, contains(const Offset(4, 0)));
        if (path.closed) expect(BimPolygonGeometry.signedArea(path.points), 48);
        model.undo();
        expect(model.project, same(original));
        expect(model.canUndo, isFalse);
        model.redo();
        expect(
          InsertArchitectElementPoint.pathOf(
            model.project.activeStorey,
            'p',
          )!.points,
          contains(const Offset(4, 0)),
        );
      },
    );
  }

  test('Midpoint insertion includes a polygon closing edge', () {
    final model = editing.seeded(fixture('slab'));
    addTearDown(model.dispose);
    model.execute(
      const InsertArchitectElementPoint(
        storeyId: 's',
        elementId: 'p',
        point: Offset(.02, 4.7),
        newElementId: 'next',
        atMidpoint: true,
      ),
    );
    expect(model.project.activeStorey.slabs.single.polygon, [
      ...polygon,
      const Offset(0, 3),
    ]);
  });

  test('Midpoint insertion preserves an oblique native line', () {
    final model = editing.seeded(
      fixture('line').copyWith(
        cadPrimitives: const [
          ArchitectCadPrimitive(
            id: 'p',
            type: CadPrimitiveType.line,
            startPoint: Offset(2, 1),
            endPoint: Offset(10, 9),
            strokeWidth: 3,
          ),
        ],
      ),
    );
    addTearDown(model.dispose);
    model.execute(
      const InsertArchitectElementPoint(
        storeyId: 's',
        elementId: 'p',
        point: Offset(3, 2.1),
        newElementId: 'next',
        atMidpoint: true,
      ),
    );
    expect(
      model.project.activeStorey.cadPrimitives.first.endPoint,
      const Offset(6, 5),
    );
    expect(
      model.project.activeStorey.cadPrimitives.last.startPoint,
      const Offset(6, 5),
    );
    expect(
      model.project.activeStorey.cadPrimitives.last.endPoint,
      const Offset(10, 9),
    );
    expect(model.project.activeStorey.cadPrimitives.last.strokeWidth, 3);
  });

  test(
    'New point and Split have different connection semantics; invalid points are atomic',
    () {
      final model = editing.seeded(fixture('wall'));
      addTearDown(model.dispose);
      final original = model.project;
      for (final point in [
        Offset.zero,
        const Offset(6, 0),
        const Offset(double.nan, 0),
      ]) {
        expect(
          () => model.execute(
            InsertArchitectElementPoint(
              storeyId: 's',
              elementId: 'p',
              point: point,
              newElementId: 'next',
            ),
          ),
          throwsArgumentError,
        );
        expect(identical(model.project, original), isTrue);
        expect(model.canUndo, isFalse);
      }
      model.execute(
        const CutArchitectWalls(
          storeyId: 's',
          wallIds: {'p'},
          start: Offset(3, -1),
          end: Offset(3, 1),
        ),
      );
      expect(model.project.activeStorey.walls.first.connectEnd, isFalse);
      expect(model.project.activeStorey.walls.last.connectStart, isFalse);
    },
  );

  for (final kind in kinds) {
    testWidgets(
      'context New point inserts at the indicated midpoint on $kind immediately',
      (tester) async {
        final model = editing.seeded(fixture(kind));
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await editing.selectTool(
          tester,
          kind == 'line' || kind == 'rect' ? 'CAD' : kind,
        );
        if (kind == 'rect') {
          await tool_ui.prepare(tester, Icons.crop_square_rounded);
          await tool_ui.choose(tester, Icons.crop_square_rounded);
          await tester.pumpAndSettle();
        }
        // For polygons select inside; for native lines select the body.
        final select = ['rect', 'slab', 'opening'].contains(kind)
            ? const Offset(3, .1)
            : kind == 'zone'
                ? const Offset(3, 2)
                : const Offset(1, 0);
        final original = model.project;
        await editing.contextHold(tester, select);
        final action = find.byKey(const ValueKey('architect-radial-newPoint'));
        expect(action, findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('architect-new-point-banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-new-point-cancel')),
          findsOneWidget,
        );
        workspace.camera(tester).fit(const Rect.fromLTWH(-1, -1, 10, 8));
        await tester.pumpAndSettle();
        await tester.tapAt(workspace.screen(tester, const Offset(4, 0)));
        await tester.pumpAndSettle();
        final path = InsertArchitectElementPoint.pathOf(
          model.project.activeStorey,
          'p',
        )!;
        expect(path.points, contains(const Offset(4, 0)));
        expect(model.canUndo, isTrue);
        expect(
          find.byKey(const ValueKey('architect-new-point-cancel')),
          findsNothing,
        );
        model.undo();
        await tester.pump();
        expect(identical(model.project, original), isTrue);
        if (kind == 'zone') {
          expect(workspace.overlay(tester).zoneEditingPolygon, polygon);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('New point labels are localized', () async {
    final bg = await AppLocalizations.delegate.load(const Locale('bg'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(bg.bimNewPoint, 'Нова точка');
    expect(en.bimNewPoint, 'New point');
  });

  testWidgets(
    'Bulgarian phone wall context has eight separate actions and inserts a connected point',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = editing.seeded(fixture('wall'));
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: model),
        ),
      );
      await tester.pumpAndSettle();
      await editing.selectTool(tester, 'wall');
      await editing.contextHold(tester, const Offset(3, 0));
      expect(find.text('Нова точка'), findsOneWidget);
      expect(find.text('Срежи'), findsOneWidget);
      final buttons = find.byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('architect-radial-'),
      );
      expect(buttons, findsNWidgets(10));
      final rects = tester.getRect(buttons.at(0));
      expect(rects.left, greaterThanOrEqualTo(0));
      for (var i = 0; i < 10; i++) {
        final a = tester.getRect(buttons.at(i));
        expect(a.right, lessThanOrEqualTo(360));
        for (var j = i + 1; j < 10; j++) {
          expect(
            (a.center - tester.getRect(buttons.at(j)).center).distance,
            greaterThanOrEqualTo(50 - 1e-8),
          );
        }
      }
      await tester.tap(find.byKey(const ValueKey('architect-radial-newPoint')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('architect-new-point-banner')), findsOneWidget);
      await tester.tapAt(workspace.screen(tester, const Offset(4, 0)));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls, hasLength(2));
      expect(model.project.activeStorey.walls.first.connectEnd, isTrue);
      expect(
        model.project.activeStorey.walls.first.endPoint,
        const Offset(4, 0),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
