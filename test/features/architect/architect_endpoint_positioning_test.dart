import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_manual_selection_test.dart' as selection;
import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

List<ArchitectWall> room({double angle = 0, bool reverse = false}) {
  Offset rotate(Offset p) => Offset(
    p.dx * math.cos(angle) - p.dy * math.sin(angle),
    p.dx * math.sin(angle) + p.dy * math.cos(angle),
  );
  final walls = [
    editing.wall('a', rotate(const Offset(2, 0)), rotate(const Offset(4, 4))),
    editing.wall('b', rotate(const Offset(2, 0)), rotate(const Offset(10, 0))),
    editing.wall('c', rotate(const Offset(4, 4)), rotate(const Offset(10, 4))),
    editing.wall(
      'd',
      rotate(const Offset(10, -1)),
      rotate(const Offset(10, 5)),
    ),
  ];
  return reverse
      ? [
          for (final w in walls)
            w.copyWith(startPoint: w.endPoint, endPoint: w.startPoint),
        ]
      : walls;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final angle in [0.0, .63, math.pi / 2]) {
    for (final reverse in [false, true]) {
      test(
        'Independent junction offsets preserve the opposite end at $angle, reversed $reverse',
        () {
          final walls = room(angle: angle, reverse: reverse);
          final model = editing.seeded(
            ArchitectStorey(id: 's', name: 'Floor', walls: walls),
          );
          addTearDown(model.dispose);
          final original = model.project;
          final gaps = ArchitectWallClearance.endpoints(walls[0], walls);
          expect(gaps, hasLength(2));
          expect(gaps.every((g) => g.neighborId == 'd'), isTrue);
          expect(gaps.first.distance, closeTo(reverse ? 5.875 : 7.875, 1e-8));
          expect(gaps.last.distance, closeTo(reverse ? 7.875 : 5.875, 1e-8));
          for (final gap in gaps) {
            final fixed = gap.atStart!
                ? walls[0].endPoint
                : walls[0].startPoint;
            model.execute(
              SetArchitectWallEndpointClearance(
                storeyId: 's',
                wallId: 'a',
                neighborId: 'd',
                supportId: gap.supportId!,
                atStart: gap.atStart!,
                distance: 3,
              ),
            );
            final next = model.project.activeStorey.walls;
            expect(gap.atStart! ? next[0].endPoint : next[0].startPoint, fixed);
            expect(
              (next[0].unitVector - walls[0].unitVector).distance,
              greaterThan(.01),
            );
            final readouts = ArchitectWallClearance.endpoints(next[0], next);
            expect(
              readouts.firstWhere((g) => g.atStart == gap.atStart).distance,
              closeTo(3, 1e-8),
            );
            expect(
              readouts.firstWhere((g) => g.atStart != gap.atStart).distance,
              closeTo(
                gaps.firstWhere((g) => g.atStart != gap.atStart).distance,
                1e-8,
              ),
            );
            expect(next[3].toJson(), walls[3].toJson());
            expect(model.undoCount, 1);
            model.undo();
            expect(model.project, same(original));
          }
        },
      );
    }
  }

  test(
    'Detached junctions are excluded; supports extend and zero offsets remain editable',
    () {
      final walls = room();
      expect(
        ArchitectWallClearance.endpoints(
          walls[0].copyWith(connectStart: false),
          walls,
        ),
        hasLength(1),
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', walls: walls),
      );
      addTearDown(model.dispose);
      model.execute(
        const SetArchitectWallEndpointClearance(
          storeyId: 's',
          wallId: 'a',
          neighborId: 'd',
          supportId: 'b',
          atStart: true,
          distance: 12,
        ),
      );
      expect(
        model.project.activeStorey.walls[0].startPoint.dx,
        closeTo(-2.125, 1e-8),
      );
      expect(
        model.project.activeStorey.walls[1].startPoint.dx,
        closeTo(-2.125, 1e-8),
      );
      model.execute(
        const SetArchitectWallEndpointClearance(
          storeyId: 's',
          wallId: 'a',
          neighborId: 'd',
          supportId: 'b',
          atStart: true,
          distance: 0,
        ),
      );
      final next = model.project.activeStorey.walls;
      expect(next[0].endPoint, walls[0].endPoint);
      expect(
        ArchitectWallClearance.endpoints(next[0], next).first.distance,
        closeTo(0, 1e-8),
      );
      model.execute(
        const SetArchitectWallEndpointClearance(
          storeyId: 's',
          wallId: 'a',
          neighborId: 'd',
          supportId: 'b',
          atStart: true,
          distance: 2,
        ),
      );
      expect(
        model.project.activeStorey.walls[0].startPoint.dx,
        closeTo(7.875, 1e-8),
      );
    },
  );

  test('A wall aligned with D keeps independently editable junctions', () {
    final walls = room();
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 'Floor', walls: walls),
    );
    addTearDown(model.dispose);
    model.execute(
      const SetArchitectWallEndpointClearance(
        storeyId: 's',
        wallId: 'a',
        neighborId: 'd',
        supportId: 'b',
        atStart: true,
        distance: 5.875,
      ),
    );
    expect(model.project.activeStorey.walls[0].startPoint, const Offset(4, 0));
    model.execute(
      const SetArchitectWallEndpointClearance(
        storeyId: 's',
        wallId: 'a',
        neighborId: 'd',
        supportId: 'b',
        atStart: true,
        distance: 3,
      ),
    );
    expect(
      model.project.activeStorey.walls[0].startPoint,
      const Offset(6.875, 0),
    );
    expect(model.project.activeStorey.walls[0].endPoint, const Offset(4, 4));
    expect(model.project.activeStorey.walls[3].toJson(), walls[3].toJson());
  });

  testWidgets(
    'Select exposes editable endpoint dimensions and keeps the other endpoint fixed',
    (tester) async {
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', walls: room()),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await selection.selectTool(tester);
      await workspace.wallTap(tester, const Offset(3, 2));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('wall-clearance-d-start')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('wall-clearance-d-end')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('wall-clearance-d-start')));
      await tester.pumpAndSettle();
      for (final key in ['6']) {
        await tester.tap(find.byKey(ValueKey('wall-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls[0].endPoint, const Offset(4, 4));
      expect(
        model.project.activeStorey.walls[0].startPoint.dx,
        closeTo(3.875, 1e-8),
      );
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Magnet lives in Settings and Parallel supports a signed exact offset',
    (tester) async {
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [editing.wall('a', Offset.zero, const Offset(4, 3))],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      expect(find.byKey(const ValueKey('architect-snap-toggle')), findsNothing);
      await tool_ui.setMagnetic(tester, false);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'architect_magnetic_snap',
        ),
        isFalse,
      );
      await selection.selectTool(tester);
      await workspace.wallTap(tester, const Offset(1, .75));
      await tester.pumpAndSettle();
      final parallel = find.byKey(const ValueKey('architect-wall-parallel'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('architect-selection-bar')),
          matching: parallel,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('architect-wall-floating-actions')),
          matching: parallel,
        ),
        findsNothing,
      );
      await tester.longPress(parallel);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('architect-axis-value')),
        '-2',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('architect-axis-value-save')));
      await tester.pumpAndSettle();
      final wall = model.project.activeStorey.walls.single;
      expect((wall.unitVector - const Offset(.8, .6)).distance, lessThan(1e-8));
      expect(
        (wall.startPoint - const Offset(1.2, -1.6)).distance,
        lessThan(1e-8),
      );
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['bg', 'en']) {
    testWidgets(
      'Phone $language keeps endpoint readouts visible around the fan',
      (tester) async {
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: 'Floor', walls: room()),
        );
        addTearDown(model.dispose);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture =
            Platform.environment['UPDATE_ARCHITECT_ENDPOINT_PREVIEW'] == 'true';
        if (capture) {
          await tester.runAsync(() async {
            await (FontLoader('Roboto')..addFont(
                  File(
                    'C:/Windows/Fonts/arial.ttf',
                  ).readAsBytes().then(ByteData.sublistView),
                ))
                .load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: boundary,
              child: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await selection.selectTool(tester);
        await workspace.wallTap(tester, const Offset(3, 2));
        await tester.pumpAndSettle();
        final viewport = tester.getRect(
          find.byKey(const ValueKey('architect-viewport-input')),
        );
        final menu = await selection.holdMenu(tester, const Offset(3, 2));
        for (final end in ['start', 'end']) {
          final rect = tester.getRect(
            find.byKey(ValueKey('wall-clearance-d-$end')),
          );
          expect(viewport.contains(rect.topLeft), isTrue);
          expect(viewport.contains(rect.bottomRight), isTrue);
          for (final action in menu.items) {
            expect(
              rect.overlaps(
                tester.getRect(
                  find.byKey(
                    ValueKey('architect-radial-${action.action.name}'),
                  ),
                ),
              ),
              isFalse,
            );
          }
        }
        if (capture && language == 'bg') {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              'docs/images/architect_endpoint_clearances_phone.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
