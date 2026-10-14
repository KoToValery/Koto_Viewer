import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_network.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectWall wall(
  String id,
  Offset start,
  Offset end, {
  double thickness = .4,
  WallReferenceLine reference = WallReferenceLine.center,
}) => ArchitectWall(
  id: id,
  startPoint: start,
  endPoint: end,
  thickness: thickness,
  referenceLine: reference,
);

void main() {
  testWidgets(
    'BIM hold aims above the finger, drag moves the tip, release commits directly',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall-dimension-mode')));
      await tester.pump();
      final translation = workspace.camera(tester).translation;
      final first = await tester.startGesture(
        workspace.screen(tester, const Offset(-1, 1)) + const Offset(0, 64),
      );
      await tester.pump(const Duration(milliseconds: 279));
      expect(find.byKey(const ValueKey('wall-offset-pointer')), findsNothing);
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byKey(const ValueKey('wall-offset-pointer')), findsOneWidget);
      await first.up();
      await tester.pump();
      expect(workspace.overlay(tester).activeDraftStart, const Offset(-1, 1));
      expect(model.project.activeStorey.walls, isEmpty);
      final second = await tester.startGesture(
        workspace.screen(tester, const Offset(1, 1)) + const Offset(0, 64),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await second.moveTo(
        workspace.screen(tester, const Offset(3, 1.04)) + const Offset(0, 64),
      );
      await tester.pump();
      final preview = workspace.overlay(tester).activeDraftEnd!;
      expect(preview.dy, closeTo(1, 1e-9));
      expect(workspace.camera(tester).translation, translation);
      final pointer =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('wall-offset-pointer')),
                  )
                  .painter!
              as StructuralPointerPainter;
      expect(
        pointer.effectivePlacementPosition,
        workspace.camera(tester).toScreen(preview),
      );
      await second.up();
      await tester.pump();
      expect(model.project.activeStorey.walls.single.endPoint, preview);
      expect(find.byKey(const ValueKey('wall-length-input')), findsNothing);
      expect(find.byKey(const ValueKey('wall-offset-pointer')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A second finger cancels held placement and keeps the wall start through pinch',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall-dimension-mode')));
      await tester.pump();
      await workspace.wallTap(tester, Offset.zero);
      final first = await tester.startGesture(
        workspace.screen(tester, const Offset(1, 1)) + const Offset(0, 64),
        pointer: 21,
      );
      await tester.pump(const Duration(milliseconds: 281));
      await first.moveBy(const Offset(10, 0));
      await tester.pump();
      expect(find.byKey(const ValueKey('wall-offset-pointer')), findsOneWidget);
      final second = await tester.startGesture(
        workspace.screen(tester, const Offset(3, 2)),
        pointer: 22,
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('wall-offset-pointer')), findsNothing);
      final scale = workspace.camera(tester).scale;
      await second.moveBy(const Offset(60, 20));
      await second.up();
      await first.up();
      await tester.pump();
      expect(workspace.camera(tester).scale, isNot(scale));
      expect(workspace.overlay(tester).activeDraftStart, Offset.zero);
      expect(model.project.activeStorey.walls, isEmpty);
      await workspace.wallTap(tester, const Offset(4, 0));
      expect(model.project.activeStorey.walls.single.length, closeTo(4, 1e-9));
    },
  );

  testWidgets(
    'Mouse primary drag places a wall without panning; connected mode continues on release',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall-dimension-mode')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall-chain-toggle')));
      await tester.pump();
      final translation = workspace.camera(tester).translation;
      final first = await tester.startGesture(
        workspace.screen(tester, Offset.zero),
        kind: PointerDeviceKind.mouse,
      );
      await first.up();
      await tester.pump();
      final second = await tester.startGesture(
        workspace.screen(tester, const Offset(1, 1)),
        kind: PointerDeviceKind.mouse,
      );
      await second.moveTo(workspace.screen(tester, const Offset(4, .05)));
      await second.up();
      await tester.pump();
      expect(workspace.camera(tester).translation, translation);
      final end = model.project.activeStorey.walls.single.endPoint;
      expect(workspace.overlay(tester).activeDraftStart, end);
      await workspace.wallTap(tester, end + const Offset(0, 2));
      expect(model.project.activeStorey.walls.last.startPoint, end);
      await tester.tap(find.byKey(const ValueKey('wall-stop-drawing')));
      await tester.pump();
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  test('Translation stretches attached T ends while keeping their far ends', () {
    final model = workspace.commands();
    addTearDown(model.dispose);
    model.execute(
      CreateArchitectWall(
        storeyId: 's',
        wall: wall('a', Offset.zero, const Offset(4, 0)),
      ),
    );
    model.execute(
      CreateArchitectWall(
        storeyId: 's',
        wall: wall('b', const Offset(2, 0), const Offset(2, 3)),
      ),
    );
    model.execute(
      CreateArchitectWall(
        storeyId: 's',
        wall: wall('c', const Offset(3, -.2), const Offset(3, -3)),
      ),
    );
    model.execute(
      const MoveArchitectElement(
        storeyId: 's',
        elementId: 'a',
        delta: Offset(0, 1),
      ),
    );
    expect(model.project.activeStorey.walls[1].startPoint, const Offset(2, 1));
    expect(model.project.activeStorey.walls[1].endPoint, const Offset(2, 3));
    expect(
      model.project.activeStorey.walls[2].startPoint,
      const Offset(3, .8),
    );
    model.undo();
    expect(
      model.project.activeStorey.walls[2].startPoint,
      const Offset(3, -.2),
    );
  });

  test(
    'Acute joins use a bounded bevel without disconnected contours or spikes',
    () {
      final walls = [
        wall('a', const Offset(-3, 0), Offset.zero),
        wall('b', Offset.zero, const Offset(-3, .1)),
      ];
      final body = ArchitectWallNetwork.body(walls);
      expect(body.computeMetrics().length, 1);
      expect(body.getBounds().right, lessThan(1.6));
      expect(ArchitectWallNetwork.junctions(walls), isNotEmpty);
    },
  );
  test(
    'L mitres are closed for every combination of reference lines and unequal thickness',
    () {
      for (final a in WallReferenceLine.values) {
        for (final b in WallReferenceLine.values) {
          final walls = [
            wall('a', const Offset(-3, 0), Offset.zero, reference: a),
            wall(
              'b',
              Offset.zero,
              const Offset(0, 3),
              thickness: .2,
              reference: b,
            ),
          ];
          final body = ArchitectWallNetwork.body(walls);
          expect(body.computeMetrics().length, 1, reason: '$a / $b');
          // Every face intersection belongs to the connected solid.
          final joint = ArchitectWallNetwork.junctions(walls).single.$1;
          final center =
              joint.reduce((a, b) => a + b) / joint.length.toDouble();
          expect(body.contains(center), isTrue);
          expect(body.contains(const Offset(1, 1)), isFalse);
        }
      }
      final body = ArchitectWallNetwork.body([
        wall('a', const Offset(-3, 0), Offset.zero),
        wall('b', Offset.zero, const Offset(0, 3)),
      ]);
      expect(
        body.contains(const Offset(.15, -.15)),
        isTrue,
        reason: 'Outer mitre is filled',
      );
      expect(
        body.contains(const Offset(-.3, .3)),
        isFalse,
        reason: 'Inner corner remains empty',
      );
    },
  );

  test(
    'T and X connections have one contour and retain their open quadrants',
    () {
      for (final start in [Offset.zero, const Offset(0, -2)]) {
        final body = ArchitectWallNetwork.body([
          wall('a', const Offset(-3, 0), const Offset(3, 0)),
          wall('b', start, const Offset(0, 2)),
        ]);
        expect(body.computeMetrics().length, 1);
        expect(body.contains(const Offset(.1, .1)), isTrue);
        expect(body.contains(const Offset(.5, .5)), isFalse);
      }
    },
  );

  test(
    'Wall reference is persisted, physical hit tests and 3D use the same faces',
    () {
      final value = wall(
        'w',
        Offset.zero,
        const Offset(3, 0),
        reference: WallReferenceLine.left,
      );
      final restored = ArchitectWall.fromJson(value.toJson());
      expect(restored.referenceLine, WallReferenceLine.left);
      expect(restored.centerStart.dy, -.2);
      expect(
        restored.containsPoint(const Offset(1, -.3), tolerance: 0),
        isTrue,
      );
      expect(
        restored.containsPoint(const Offset(1, .1), tolerance: 0),
        isFalse,
      );
      expect(restored.build3D(storeyElevation: 0), isNotEmpty);
      final oldJson = value.toJson()..remove('referenceLine');
      expect(
        ArchitectWall.fromJson(oldJson).referenceLine,
        WallReferenceLine.center,
      );
    },
  );

  test(
    'Endpoint edits carry connected walls; splitting preserves door positions and Undo',
    () {
      final model = workspace.commands();
      addTearDown(model.dispose);
      final first = wall('a', Offset.zero, const Offset(4, 0)).addDoor(
        const ArchitectDoor(
          id: 'd',
          uuid: 'door',
          wallId: 'a',
          offsetRatio: .75,
          width: .8,
        ),
      );
      model.execute(CreateArchitectWall(storeyId: 's', wall: first));
      model.execute(
        CreateArchitectWall(
          storeyId: 's',
          wall: wall('b', const Offset(4, 0), const Offset(4, 3)),
        ),
      );
      model.execute(
        UpdateArchitectWall(
          storeyId: 's',
          wall: first.copyWith(endPoint: const Offset(5, 0)),
        ),
      );
      expect(
        model.project.activeStorey.walls.last.startPoint,
        const Offset(5, 0),
      );
      expect(
        model.project.activeStorey.walls.first.doors.single.offsetRatio,
        closeTo(.6, 1e-9),
      );
      model.undo();
      expect(
        model.project.activeStorey.walls.last.startPoint,
        const Offset(4, 0),
      );
      model.execute(
        const SplitArchitectWall(
          storeyId: 's',
          wallId: 'a',
          newWallId: 'a2',
          ratio: .5,
        ),
      );
      final second = model.project.activeStorey.walls[1];
      expect(second.doors.single.wallId, 'a2');
      expect(
        second.startPoint.dx + second.length * second.doors.single.offsetRatio,
        3,
      );
      model.undo();
      expect(model.project.activeStorey.walls.length, 2);
      expect(
        () => const SplitArchitectWall(
          storeyId: 's',
          wallId: 'a',
          newWallId: 'bad',
          ratio: .75,
        ).apply(model.project),
        throwsArgumentError,
      );
    },
  );

  test(
    'Wall snap prioritizes endpoints and captures visible rebased CAD edges',
    () {
      final model = workspace.commands();
      addTearDown(model.dispose);
      final project = model.project.updateActiveStorey(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [
            ArchitectWall(
              id: 'w',
              startPoint: Offset.zero,
              endPoint: Offset(3, 0),
            ),
          ],
        ),
      );
      final end = ArchitectWallSnap.resolve(
        raw: const Offset(2.95, .02),
        project: project,
        scale: 100,
      );
      expect(end.point, const Offset(3, 0));
      final doc = DxfDocument(
        entities: [
          DxfLine(
            layer: 'base',
            p1: const Offset(11000, 22000),
            p2: const Offset(15000, 22000),
          ),
        ],
        layers: {'base': DxfLayer(name: 'base')},
        blocks: {},
        bounds: const Rect.fromLTWH(10000, 20000, 10000, 10000),
        entityStats: {},
        headerVars: {},
      );
      const frame = BimCoordinateFrame(
        origin: Offset(10000, 20000),
        unitsPerMeter: 1000,
      );
      final snap = ArchitectWallSnap.resolve(
        raw: const Offset(2.25, 2.05),
        project: project,
        scale: 100,
        underlay: doc,
        frame: frame,
      );
      expect(snap.point, const Offset(2.25, 2));
      final hidden = ArchitectWallSnap.resolve(
        raw: const Offset(2.25, 2.05),
        project: project,
        scale: 100,
        underlay: doc,
        frame: frame,
        visibility: {'base': false},
      );
      expect(hidden.isSnapped, isFalse);
      final ortho = ArchitectWallSnap.resolve(
        raw: const Offset(1, .12),
        anchor: Offset.zero,
        project: model.project,
        scale: 100,
      );
      expect(ortho.point.dy, closeTo(0, 1e-9));
    },
  );

  testWidgets(
    'Local keypad sets an exact length and Continue shares the next endpoint',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, Offset.zero);
      await workspace.wallTap(tester, const Offset(3, .04));
      await tester.tap(find.byKey(const ValueKey('wall-length-input')));
      await tester.pump();
      for (final key in ['4', '.', '2', '5']) {
        await tester.tap(find.byKey(ValueKey('wall-key-$key')));
        await tester.pump();
      }
      expect(find.byType(EditableText), findsNothing);
      await tester.tap(find.byKey(const ValueKey('wall-continue')));
      await tester.pump();
      final first = model.project.activeStorey.walls.single;
      expect(first.length, closeTo(4.25, 1e-9));
      expect(workspace.overlay(tester).activeDraftStart, first.endPoint);
      await workspace.wallTap(tester, first.endPoint + const Offset(0, 2));
      expect(model.project.activeStorey.walls.length, 1);
      expect(find.byKey(const ValueKey('wall-length-input')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wall-length-input')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall-key-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls.last.startPoint, first.endPoint);
      expect(model.project.activeStorey.walls.last.length, closeTo(3, 1e-9));
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      await tester.tap(find.byIcon(Icons.view_column_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pump();
      await workspace.wallTap(tester, const Offset(-2, -2));
      await workspace.wallTap(tester, const Offset(-1, -2));
      expect(find.byKey(const ValueKey('wall-length-input')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pump();
      expect(model.project.activeStorey.walls.length, 3);
      // Manual disabling stays disabled after a commit.
      await tester.tap(find.byKey(const ValueKey('wall-dimension-mode')));
      await tester.pump();
      await workspace.wallTap(tester, const Offset(-2, -3));
      await workspace.wallTap(tester, const Offset(-1, -2));
      expect(model.project.activeStorey.walls.length, 4);
      await workspace.wallTap(tester, const Offset(0, -2));
      expect(model.project.activeStorey.walls.length, 5);
      expect(find.byKey(const ValueKey('wall-length-input')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Selected endpoint drag keeps its neighbour stationary and can be undone',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      model.execute(
        CreateArchitectWall(
          storeyId: 's',
          wall: wall('a', Offset.zero, const Offset(4, 0)),
        ),
      );
      model.execute(
        CreateArchitectWall(
          storeyId: 's',
          wall: wall('b', const Offset(4, 0), const Offset(4, 3)),
        ),
      );
      await workspace.open(tester, model);
      await tester.ensureVisible(find.byIcon(Icons.line_weight_rounded));
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();
      await tester.longPressAt(workspace.screen(tester, const Offset(2, 0)));
      await tester.pump();
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(4, 0)),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await gesture.moveTo(workspace.screen(tester, const Offset(5, 0)));
      await tester.pump();
      expect(
        model.project.activeStorey.walls.first.endPoint,
        const Offset(4, 0),
      );
      await gesture.up();
      await tester.pump();
      expect(
        model.project.activeStorey.walls.first.endPoint,
        const Offset(5, 0),
      );
      expect(
        model.project.activeStorey.walls.last.startPoint,
        const Offset(4, 0),
      );
      await tester.tap(find.byKey(const ValueKey('architect-undo')));
      await tester.pump();
      expect(
        model.project.activeStorey.walls.last.startPoint,
        const Offset(4, 0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Phone keypad stays visible and does not change a locked endpoint during navigation',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      model.execute(
        CreateArchitectWall(
          storeyId: 's',
          wall: wall('a', const Offset(-1, -.5), const Offset(1.5, -.5)),
        ),
      );
      model.execute(
        CreateArchitectWall(
          storeyId: 's',
          wall: wall('b', const Offset(1.5, -.5), const Offset(1.5, 1.4)),
        ),
      );
      model.commit(
        model.project.copyWith(
          wallTypes: ArchitectWallType.standardCatalog(),
          storeys: [
            model.project.activeStorey.copyWith(
              walls: model.project.activeStorey.walls
                  .map(
                    (w) =>
                        w.copyWith(thickness: .37, wallTypeId: 'ext_25_12_eps'),
                  )
                  .toList(),
            ),
          ],
        ),
      );
      const screenshotKey = ValueKey('wall-phone-preview');
      if (const bool.fromEnvironment('UPDATE_ARCHITECT_WALL_PREVIEW')) {
        await tester.runAsync(() async {
          final fontFile = File('C:/Windows/Fonts/arial.ttf');
          if (await fontFile.exists()) {
            final font = FontLoader('Roboto')
              ..addFont(
                Future.value(
                  ByteData.sublistView(await fontFile.readAsBytes()),
                ),
              );
            await font.load();
          }
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: screenshotKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
            ),
            locale: const Locale('bg'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.line_weight_rounded));
      await tester.tap(find.byIcon(Icons.line_weight_rounded));
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-2, -2, 5, 5), padding: 40);
      await tester.pump();
      // A quick tap on the existing wall now selects it. An aimed hold starts
      // an attached wall without bypassing that selection behavior.
      final start = await tester.startGesture(
        workspace.screen(tester, const Offset(-1, -.5)) + const Offset(0, 64),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await start.up();
      await tester.pump();
      if (const bool.fromEnvironment('UPDATE_ARCHITECT_WALL_PREVIEW')) {
        final held = await tester.startGesture(
          workspace.screen(tester, const Offset(-1, 1.5)) + const Offset(0, 64),
        );
        await tester.pump(const Duration(milliseconds: 281));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(screenshotKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File(
            'docs/images/architect_wall_bim_placement.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
        await held.cancel();
        await tester.pump();
      }
      await workspace.wallTap(tester, const Offset(-1, 1.5));
      final end = workspace.overlay(tester).activeDraftEnd;
      await tester.tap(find.byKey(const ValueKey('wall-length-input')));
      await tester.pump();
      final input = find.byKey(const ValueKey('architect-viewport-input'));
      final first = await tester.startGesture(
        tester.getTopLeft(input) + const Offset(20, 370),
        pointer: 31,
      );
      final second = await tester.startGesture(
        tester.getTopLeft(input) + const Offset(60, 370),
        pointer: 32,
      );
      await first.moveBy(const Offset(-10, 0));
      await second.moveBy(const Offset(15, 0));
      await second.up();
      await first.up();
      await tester.pump();
      expect(workspace.overlay(tester).activeDraftEnd, end);
      expect(model.project.activeStorey.walls.length, 2);
      for (final key in [
        'wall-length-input',
        'wall-key-0',
        'wall-end',
        'wall-continue',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(rect.bottom, lessThanOrEqualTo(800));
      }
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('UPDATE_ARCHITECT_WALL_PREVIEW')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(screenshotKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File(
            'docs/images/architect_wall_phone.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
