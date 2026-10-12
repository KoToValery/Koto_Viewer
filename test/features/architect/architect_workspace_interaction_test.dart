import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

class ReadCountingLine extends DxfLine {
  int reads = 0;
  ReadCountingLine()
    : super(layer: 'lines', p1: Offset.zero, p2: const Offset(8, 0));
  @override
  Offset get p1 {
    reads++;
    return super.p1;
  }
}

ArchitectCommandController commands() => ArchitectCommandController(
  ArchitectProject(
    id: 'p',
    name: 'Workspace',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    activeStoreyId: 's',
    storeys: const [ArchitectStorey(id: 's', name: 'Floor')],
  ),
);

Future<void> open(
  WidgetTester tester,
  ArchitectCommandController commands, {
  Map<String, DxfDocument>? underlays,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ArchitectWorkspaceScreen(
        commandController: commands,
        underlaysByStorey: underlays,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Architect2dPainter overlay(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((e) => e.painter)
    .whereType<Architect2dPainter>()
    .firstWhere((e) => e.layer == ArchitectPaintLayer.interaction);
BimViewportController camera(WidgetTester tester) => overlay(tester).viewport!;
Offset screen(WidgetTester tester, Offset point) =>
    tester.getTopLeft(find.byKey(const ValueKey('architect-viewport-input'))) +
    camera(tester).toScreen(point);

Future<void> wallTap(WidgetTester tester, Offset point) async {
  // BIM quick taps use their actual location; holds use the offset target.
  await tester.tapAt(screen(tester, point));
  await tester.pump();
}

void main() {
  testWidgets(
    'Releasing an old gesture after switching tools cannot place a new element',
    (tester) async {
      final model = commands();
      addTearDown(model.dispose);
      await open(tester, model);
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();
      await tester.tapAt(screen(tester, Offset.zero));
      await tester.pump();
      final held = await tester.startGesture(
        screen(tester, const Offset(3, 1)),
        pointer: 81,
      );
      await held.moveTo(screen(tester, const Offset(3, .1)));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.view_column_rounded));
      await tester.pumpAndSettle();
      await held.up();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls, isEmpty);
      expect(model.project.activeStorey.columns, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Phone workspace keeps navigation and selection controls within the screen',
    (tester) async {
      final previousWarningPolicy =
          WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal =
            previousWarningPolicy,
      );
      final model = commands();
      addTearDown(model.dispose);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = DxfDocument(
        entities: [],
        layers: {},
        blocks: {},
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
        entityStats: {},
        headerVars: {},
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArchitectWorkspaceScreen(
                      commandController: model,
                      underlaysByStorey: {'s': doc},
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byIcon(Icons.view_column_rounded));
      await tester.tap(find.byIcon(Icons.view_column_rounded));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tapAt(screen(tester, const Offset(3, 3)));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.columns.length, 1);
      await tester.ensureVisible(find.byIcon(Icons.view_column_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.view_column_rounded));
      await tester.pumpAndSettle();
      await tester.longPressAt(screen(tester, const Offset(3, 3)));
      await tester.pumpAndSettle();
      expect(
        overlay(tester).selectedElementId,
        model.project.activeStorey.columns.single.id,
      );
      expect(find.byKey(const ValueKey('architect-more')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A column inside a room can be grabbed without jumping, cancelled and moved with one Undo',
    (tester) async {
      final model = commands();
      addTearDown(model.dispose);
      const original = Offset(3, 2);
      model.executeBatch([
        CreateArchitectZone(
          storeyId: 's',
          zone: ArchitectZone(
            id: 'room',
            name: 'Room',
            category: ArchitectZoneCategory.living,
            polygon: const [
              Offset.zero,
              Offset(6, 0),
              Offset(6, 4),
              Offset(0, 4),
            ],
          ),
        ),
        const PlaceArchitectColumn(
          storeyId: 's',
          column: ArchitectColumn(id: 'col', position: original),
        ),
      ]);
      await open(tester, model);
      await tester.tap(find.byIcon(Icons.view_column_rounded));
      await tester.pumpAndSettle();
      await tester.longPressAt(screen(tester, original));
      await tester.pump();
      var commits = 0;
      model.addListener(() => commits++);
      final grab = original + const Offset(.05, .04);
      final gesture = await tester.startGesture(
        screen(tester, grab),
        pointer: 51,
      );
      await tester.pump(const Duration(milliseconds: 281));
      expect(
        overlay(tester).project.activeStorey.columns.single.position,
        original,
      );
      await gesture.moveTo(screen(tester, grab + const Offset(.3, .2)));
      await tester.pump();
      expect(
        overlay(tester).project.activeStorey.columns.single.position,
        original + const Offset(.3, .2),
      );
      expect(model.project.activeStorey.columns.single.position, original);
      final second = await tester.startGesture(
        screen(tester, const Offset(5, 3)),
        pointer: 52,
      );
      await second.up();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(commits, 0);
      expect(model.project.activeStorey.columns.single.position, original);
      final drag = await tester.startGesture(screen(tester, grab));
      await tester.pump(const Duration(milliseconds: 281));
      await drag.moveTo(screen(tester, grab + const Offset(.3, .2)));
      await drag.up();
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(
        model.project.activeStorey.columns.single.position,
        original + const Offset(.3, .2),
      );
      await tester.tap(find.byKey(const ValueKey('architect-undo')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.columns.single.position, original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wall preview equals committed snap and single-line mode starts a fresh segment',
    (tester) async {
      final model = commands();
      addTearDown(model.dispose);
      await open(tester, model);
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-dimension-mode')));
      await tester.pump();
      await wallTap(tester, Offset.zero);
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: screen(tester, const Offset(3.03, .08)));
      await mouse.moveTo(screen(tester, const Offset(3.03, .08)));
      await tester.pump();
      final preview = overlay(tester).activeDraftEnd!;
      expect(preview.dy.abs(), lessThan(1e-9));
      await wallTap(tester, const Offset(3.03, .08));
      await tester.pumpAndSettle();
      expect(
        (model.project.activeStorey.walls.single.endPoint - preview).distance,
        lessThan(1e-9),
      );
      expect(overlay(tester).activeDraftStart, isNull);
      await wallTap(tester, const Offset(-2, -2));
      await tester.pump();
      expect(overlay(tester).activeDraftStart, const Offset(-2, -2));
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Two stationary touch taps create an axis without a hover event',
    (tester) async {
      final model = commands();
      addTearDown(model.dispose);
      await open(tester, model);
      await tester.ensureVisible(find.byIcon(Icons.grid_on_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.grid_on_rounded));
      await tester.pumpAndSettle();
      await tester.tapAt(screen(tester, const Offset(-2, -2)));
      await tester.pump();
      await tester.tapAt(screen(tester, const Offset(3, -2)));
      await tester.pumpAndSettle();
      expect(model.project.gridAxes.length, 1);
      expect(model.project.gridAxes.single.length, closeTo(5, 1e-9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wall drafting allows one-finger navigation, direct release and Undo',
    (tester) async {
      final model = commands();
      addTearDown(model.dispose);
      await open(tester, model);
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-dimension-mode')));
      await tester.pump();
      await wallTap(tester, Offset.zero);
      await tester.pump();
      final translation = camera(tester).translation;
      final gesture = await tester.startGesture(
        screen(tester, const Offset(2, 1)),
      );
      await gesture.moveTo(screen(tester, const Offset(3, .05)));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(camera(tester).translation, isNot(translation));
      expect(model.project.activeStorey.walls, isEmpty);
      expect(overlay(tester).activeDraftStart, Offset.zero);
      await wallTap(tester, const Offset(3, .05));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.walls.single.endPoint.dy.abs(),
        lessThan(1e-9),
      );
      await tester.tap(find.byKey(const ValueKey('architect-undo')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls, isEmpty);
      await tester.tap(find.byKey(const ValueKey('architect-redo')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'External coordinate commands refresh the screen independently of zoom',
    (tester) async {
      final model = commands();
      addTearDown(model.dispose);
      await open(tester, model);
      camera(tester).navigate(
        previousFocal: const Offset(100, 100),
        focal: const Offset(100, 100),
        scaleFactor: 3,
      );
      model.execute(
        const CreateArchitectWall(
          storeyId: 's',
          wall: ArchitectWall(
            id: 'automated',
            startPoint: Offset(1.2345678, 2),
            endPoint: Offset(5.2345678, 2),
          ),
        ),
      );
      await tester.pump();
      expect(
        overlay(tester).project.activeStorey.walls.single.startPoint,
        const Offset(1.2345678, 2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Column preview and release use the same quantized model position',
    (tester) async {
      final model = commands();
      addTearDown(model.dispose);
      await open(tester, model);
      await tester.tap(find.byIcon(Icons.view_column_rounded));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final target = screen(tester, const Offset(2.34567, 2.22222));
      await mouse.addPointer(location: target);
      await mouse.moveTo(target);
      await tester.pump();
      final preview = overlay(tester).columnPreview!;
      await tester.tapAt(target);
      await tester.pumpAndSettle();
      final column = model.project.activeStorey.columns.single;
      expect(column.position, preview.position);
      expect(column.width, preview.width);
      expect(column.depth, preview.depth);
      expect(column.shape, preview.shape);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Zone dragging remains a preview; second finger cancels; release commits once',
    (tester) async {
      final model = commands();
      addTearDown(model.dispose);
      const polygon = [Offset(0, 0), Offset(6, 0), Offset(6, 4), Offset(0, 4)];
      model.execute(
        CreateArchitectZone(
          storeyId: 's',
          zone: ArchitectZone(
            id: 'room',
            name: 'Room',
            category: ArchitectZoneCategory.living,
            polygon: polygon,
          ),
        ),
      );
      await open(tester, model);
      await tester.tap(find.byIcon(Icons.space_dashboard_rounded));
      await tester.pumpAndSettle();
      await tester.longPressAt(screen(tester, const Offset(2, 2)));
      await tester.pump();
      var commits = 0;
      model.addListener(() => commits++);
      final first = await tester.startGesture(
        screen(tester, const Offset(2, 2)),
        pointer: 31,
      );
      await tester.pump(const Duration(milliseconds: 281));
      await first.moveTo(screen(tester, const Offset(2.3, 2.2)));
      await tester.pump();
      expect(model.project.activeStorey.zones.single.polygon, polygon);
      final second = await tester.startGesture(
        screen(tester, const Offset(4, 2)),
        pointer: 32,
      );
      await second.moveBy(const Offset(20, 0));
      await second.up();
      await first.up();
      await tester.pumpAndSettle();
      expect(commits, 0);
      expect(model.project.activeStorey.zones.single.polygon, polygon);
      final drag = await tester.startGesture(
        screen(tester, const Offset(2, 2)),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await drag.moveTo(screen(tester, const Offset(2.2, 2.1)));
      await drag.up();
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(
        (model.project.activeStorey.zones.single.polygon.first -
                const Offset(.2, .1))
            .distance,
        lessThan(1e-9),
      );
      model.undo();
      await tester.pump();
      expect(model.project.activeStorey.zones.single.polygon, polygon);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pointer previews do not repaint the CAD underlay; camera navigation does',
    (tester) async {
      final model = commands();
      addTearDown(model.dispose);
      final line = ReadCountingLine();
      final doc = DxfDocument(
        entities: [line],
        layers: {'lines': DxfLayer(name: 'lines')},
        blocks: {},
        bounds: const Rect.fromLTWH(0, 0, 8, 5),
        entityStats: {},
        headerVars: {},
      );
      await open(tester, model, underlays: {'s': doc});
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();
      await tester.tapAt(screen(tester, const Offset(1, 1)));
      await tester.pump();
      final before = line.reads;
      expect(before, greaterThan(0));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: screen(tester, const Offset(2, 1)));
      for (var i = 0; i < 10; i++) {
        await mouse.moveTo(screen(tester, Offset(2 + i * .1, 1.1)));
        await tester.pump();
      }
      expect(line.reads, before);
      camera(tester).panBy(const Offset(20, 10));
      await tester.pump();
      expect(line.reads, greaterThan(before));
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
}
