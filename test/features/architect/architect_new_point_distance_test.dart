import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_new_point_measure.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_new_point_distance_dialog.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_editor_feedback_regression_test.dart' as feedback;
import 'architect_workspace_interaction_test.dart' as workspace;

Future<void> keys(WidgetTester tester, String text) async {
  for (final character in text.split('')) {
    await tester.tap(find.byKey(ValueKey('new-point-key-$character')));
    await tester.pump();
  }
}

void main() {
  setUpAll(() async {
    for (final family in ['Roboto', 'ArchitectNoto']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final bulge in [0.0, .4, -.4, 1.5, -1.5]) {
    test('Endpoint distances follow the native reference line ($bulge)', () {
      final wall = ArchitectWall(
        id: 'w',
        startPoint: const Offset(8, 2),
        endPoint: const Offset(0, 1),
        thickness: .25,
        arcBulge: bulge,
      );
      final point = wall.referencePointAt(.37);
      final measure = ArchitectNewPointMeasure(wall, point);
      expect(measure.distanceFrom(1), closeTo(wall.length * .37, 1e-8));
      expect(measure.distanceFrom(2), closeTo(wall.length * .63, 1e-8));
      for (final endpoint in [1, 2]) {
        expect(
          (ArchitectNewPointMeasure.pointAtDistance(
                    wall,
                    endpoint,
                    measure.distanceFrom(endpoint),
                  ) -
                  point)
              .distance,
          lessThan(1e-8),
        );
      }
      for (final invalid in [
        0.0,
        -.1,
        wall.length,
        wall.length + 1,
        double.nan,
      ]) {
        expect(
          () => ArchitectNewPointMeasure.pointAtDistance(wall, 1, invalid),
          throwsArgumentError,
        );
      }
    });
  }

  for (final language in ['bg', 'en']) {
    testWidgets(
      'New point previews during active Wall move and exact input ($language)',
      (tester) async {
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: '',
            walls: [
              editing
                  .wall('wall', Offset.zero, const Offset(8, 0))
                  .addDoor(
                    const ArchitectDoor(
                      id: 'door',
                      wallId: 'wall',
                      uuid: 'd',
                      offsetRatio: .75,
                      width: 1,
                    ),
                  ),
            ],
          ),
        );
        addTearDown(model.dispose);
        SharedPreferences.setMockInitialValues({
          'architect_dark_canvas': language == 'en',
        });
        await feedback.phone(tester, model, language);
        expect(workspace.overlay(tester).palette.isDark, language == 'en');
        workspace.camera(tester).fit(const Rect.fromLTWH(-1, -3, 10, 6));
        await tester.pumpAndSettle();
        // Ordinary navigation picks the wall and adopts its drawing tool.
        await workspace.wallTap(tester, const Offset(2, 0));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
              .activeTool,
          ArchitectTool.wall,
        );
        final hold = await tester.startGesture(
          workspace.screen(tester, const Offset(2, 0)),
        );
        await tester.pump(const Duration(milliseconds: 701));
        await hold.up();
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-radial-newPoint')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
              .activeTool,
          ArchitectTool.wall,
        );
        final original = model.project;
        expect(
          find.byKey(const ValueKey('architect-new-point-distance-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-new-point-distance-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-dynamic-dimensions')),
          findsNothing,
        );

        final painter = workspace.overlay(tester);
        final origin = tester.getTopLeft(
          find.byKey(const ValueKey('architect-viewport-input')),
        );
        final grip =
            origin +
            workspace.camera(tester).toScreen(painter.newPointCandidate!) +
            painter.newPointHandleOffset!;
        final drag = await tester.startGesture(grip);
        await drag.moveTo(
          workspace.screen(tester, const Offset(3, 0)) +
              painter.newPointHandleOffset!,
        );
        await tester.pump();
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(3, .01),
        );
        expect(model.project, same(original));
        await drag.up();
        await tester.pumpAndSettle();

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: workspace.screen(tester, const Offset(3, 0)),
        );
        await mouse.moveTo(workspace.screen(tester, const Offset(4, 0)));
        await tester.pumpAndSettle();
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(4, .01),
        );

        await tester.tap(
          find.byKey(const ValueKey('architect-new-point-distance-1')),
        );
        await tester.pumpAndSettle();
        await keys(tester, '2.5');
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(2.5, 1e-8),
        );
        expect(model.project, same(original));
        await feedback.snapshot(
          tester,
          'architect_new_point_numeric_$language',
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-new-point-distance-apply')),
        );
        await tester.pumpAndSettle();
        await mouse.moveTo(workspace.screen(tester, const Offset(7, 0)));
        await tester.pumpAndSettle();
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(2.5, 1e-8),
        );
        await feedback.snapshot(
          tester,
          'architect_new_point_live_distances_$language',
        );
        final camera = workspace.camera(tester),
            focal = camera.size.center(Offset.zero);
        camera.navigate(previousFocal: focal, focal: focal, scaleFactor: 1.25);
        await tester.pumpAndSettle();
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(2.5, 1e-8),
        );

        // A deliberate canvas gesture releases exact placement; merely opening
        // and applying an unchanged numeric value preserves the actual point.
        await tester.tapAt(workspace.screen(tester, const Offset(4, 0)));
        await tester.pumpAndSettle();
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(4, 1e-8),
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-new-point-distance-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-new-point-distance-apply')),
        );
        await tester.pumpAndSettle();
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(4, 1e-8),
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-new-point-distance-1')),
        );
        await tester.pumpAndSettle();
        await keys(tester, '2.5');
        await tester.tap(
          find.byKey(const ValueKey('architect-new-point-distance-apply')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('architect-new-point-distance-2')),
        );
        await tester.pumpAndSettle();
        await keys(tester, '3');
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(5, 1e-8),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(2.5, 1e-8),
        );
        expect(
          find.byKey(const ValueKey('architect-new-point-banner')),
          findsOneWidget,
        );

        for (final invalid in ['0', '6', '9']) {
          await tester.tap(
            find.byKey(const ValueKey('architect-new-point-distance-1')),
          );
          await tester.pumpAndSettle();
          await keys(tester, invalid);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(
                    const ValueKey('architect-new-point-distance-apply'),
                  ),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(
            find.byKey(const ValueKey('architect-new-point-distance-cancel')),
          );
          await tester.pumpAndSettle();
        }
        expect(model.undoCount, 0);
        await editing.acceptGeometryCommand(tester);
        expect(
          model.project.activeStorey.walls.first.endPoint.dx,
          closeTo(2.5, 1e-8),
        );
        expect(model.undoCount, 1);
        model.undo();
        expect(model.project, same(original));
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Arc numeric preview uses arc distance, rolls back and supports millimetres',
    (tester) async {
      final wall = ArchitectWall(
        id: 'wall',
        startPoint: Offset.zero,
        endPoint: const Offset(8, 0),
        thickness: .25,
        arcBulge: -.4,
      );
      final seed = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [wall]),
      );
      final model = seed.project.copyWith(units: ArchitectUnit.millimeters);
      seed.dispose();
      final commands = workspace.commands();
      commands.commit(model);
      addTearDown(commands.dispose);
      await feedback.phone(tester, commands, 'en');
      final original = commands.project;
      workspace.camera(tester).fit(const Rect.fromLTWH(-1, -3, 10, 6));
      await tester.pumpAndSettle();
      await editing.contextHold(tester, wall.referencePointAt(.25));
      await tester.tap(find.byKey(const ValueKey('architect-radial-newPoint')));
      await tester.pumpAndSettle();
      final before = workspace.overlay(tester).newPointCandidate!;
      await tester.tap(
        find.byKey(const ValueKey('architect-new-point-distance-2')),
      );
      await tester.pumpAndSettle();
      await keys(tester, '1200.1234');
      final expected = wall.referencePointAt(1 - 1.2001234 / wall.length);
      expect(
        (workspace.overlay(tester).newPointCandidate! - expected).distance,
        lessThan(1e-8),
      );
      await tester.tap(
        find.byKey(const ValueKey('architect-new-point-distance-cancel')),
      );
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).newPointCandidate, before);
      expect(commands.project, same(original));
      await feedback.snapshot(tester, 'architect_new_point_arc_distances_en');
      // An external model change invalidates the modal's captured edit session.
      await tester.tap(
        find.byKey(const ValueKey('architect-new-point-distance-1')),
      );
      await tester.pumpAndSettle();
      commands.execute(
        UpdateArchitectWall(
          storeyId: 's',
          wall: wall.copyWith(height: 3.2, followStoreyHeight: false),
        ),
      );
      await tester.pumpAndSettle();
      await keys(tester, '1200');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('architect-new-point-distance-apply')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('architect-new-point-distance-cancel')),
      );
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).newPointCandidate, isNull);
      expect(commands.project.activeStorey.walls.single.height, 3.2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Numeric keyboard handles comma and preserves unedited precision',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      final previews = <double>[];
      double? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<double>(
                  context: context,
                  builder: (_) => ArchitectNewPointDistanceDialog(
                    project: model.project,
                    endpoint: 1,
                    distance: 3.2345678,
                    accepts: (distance) => distance > 0 && distance < 8,
                    onPreview: previews.add,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result, 3.2345678);
      expect(previews, isEmpty);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final (key, character) in [
        (LogicalKeyboardKey.digit1, '1'),
        (LogicalKeyboardKey.comma, ','),
        (LogicalKeyboardKey.digit2, '2'),
      ]) {
        await tester.sendKeyEvent(key, character: character);
        await tester.pump();
      }
      expect(previews.last, 1.2);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result, 1.2);
      expect(tester.takeException(), isNull);
    },
  );
}
