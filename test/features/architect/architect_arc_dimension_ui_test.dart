import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_arc_dimension_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_arc_dimension_overlay.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

const capture = ValueKey('arc-dimension-capture');
const arc = ArchitectWall(
  id: 'arc',
  startPoint: Offset(-2, 0),
  endPoint: Offset(2, 0),
  arcBulge: -.5,
  thickness: .25,
);
const neighbor = ArchitectWall(
  id: 'neighbor',
  startPoint: Offset(2, 0),
  endPoint: Offset(4, 0),
);

Future<void> open(
  WidgetTester tester,
  ArchitectCommandController model,
  String language,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    ),
  );
  await tester.pumpAndSettle();
  workspace.camera(tester).fit(const Rect.fromLTRB(-4, -4, 4, 4), padding: 32);
  await tester.pumpAndSettle();
}

Future<void> button(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String value) async {
  for (final key in value.split('')) {
    await button(tester, 'arc-key-$key');
  }
}

Future<void> screenshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('UPDATE_ARC_DIMENSION_PREVIEW')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(capture),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(
      '.dart_tool/arc_dimension_previews',
    ).create(recursive: true);
    await File(
      '.dart_tool/arc_dimension_previews/arc_dimension_$name.png',
    ).writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Radius typing retains a major arc through an intermediate semicircle',
    (tester) async {
      final major = arc.copyWith(arcBulge: -2);
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [major]),
      );
      addTearDown(model.dispose);
      await open(tester, model, 'en', const Size(390, 844));
      workspace
          .camera(tester)
          .fit(const Rect.fromLTRB(-6, -6, 6, 6), padding: 32);
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, major.centerPointAt(.5)));
      await tester.pumpAndSettle();
      await button(tester, 'wall-arc-dimension-badge');
      final l = AppLocalizations.of(
        tester.element(find.byType(ArchitectWallArcDimensionDialog)),
      )!;
      await tester.tap(find.text(l.architectRadius));
      await tester.pumpAndSettle();
      await enter(tester, '2.75');
      final preview = tester
          .widget<ArchitectWallArcDimensionOverlay>(
            find.byType(ArchitectWallArcDimensionOverlay),
          )
          .arc;
      expect(preview.bulge, lessThan(-1));
      expect(preview.radius, closeTo(2.75, 1e-9));
      expect(model.canUndo, isFalse);
      await button(tester, 'wall-arc-dimension-save');
      await editing.acceptGeometryCommand(tester);
      expect(
        model.project.activeStorey.walls.single.arc!.radius,
        closeTo(2.75, 1e-9),
      );
      expect(model.project.activeStorey.walls.single.arcBulge, lessThan(-1));
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A distant radius center stays editable at different zoom levels without camera changes',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', walls: [arc]),
      );
      addTearDown(model.dispose);
      await open(tester, model, 'bg', const Size(360, 800));
      await tester.tapAt(workspace.screen(tester, arc.centerPointAt(.5)));
      await tester.pumpAndSettle();
      final camera = workspace.camera(tester);
      final scale = camera.scale, translation = camera.translation;
      await button(tester, 'wall-arc-dimension-badge');
      final l = AppLocalizations.of(
        tester.element(find.byType(ArchitectWallArcDimensionDialog)),
      )!;
      await tester.tap(find.text(l.architectRadius));
      await tester.pumpAndSettle();
      await enter(tester, '500');
      await button(tester, 'wall-arc-dimension-save');
      await editing.acceptGeometryCommand(tester);
      expect(camera.scale, scale);
      expect(camera.translation, translation);
      for (final factor in [.5, 3.0]) {
        final center = camera.size.center(Offset.zero);
        camera.navigate(
          previousFocal: center,
          focal: center,
          scaleFactor: factor,
        );
        await tester.pumpAndSettle();
        final rect = tester.getRect(
          find.byKey(const ValueKey('wall-arc-dimension-badge')),
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(800));
        await button(tester, 'wall-arc-dimension-badge');
        expect(find.byType(ArchitectWallArcDimensionDialog), findsOneWidget);
        await button(tester, 'wall-arc-dimension-cancel');
      }
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'The old size action opens curvature editing; numeric draft cancellation restores its shape',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', walls: [arc]),
      );
      addTearDown(model.dispose);
      await open(tester, model, 'en', const Size(1600, 1200));
      await tester.tapAt(workspace.screen(tester, arc.centerPointAt(.5)));
      await tester.pumpAndSettle();
      await button(tester, 'architect-wall-actions');
      final l = AppLocalizations.of(
        tester.element(find.byType(ArchitectWorkspaceScreen)),
      )!;
      await tester.tap(find.text(l.wallArc));
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectWallArcDimensionDialog), findsOneWidget);
      await button(tester, 'wall-arc-dimension-cancel');
      expect(model.canUndo, isFalse);
      await editing.selectTool(tester, 'wall');
      await button(tester, 'wall-drawing-mode');
      await button(tester, 'architect-wall-arc-mode');
      await workspace.wallTap(tester, const Offset(-2, -2));
      await workspace.wallTap(tester, const Offset(2, -2));
      final before = tester
          .widget<ArchitectWallArcDimensionOverlay>(
            find.byType(ArchitectWallArcDimensionOverlay),
          )
          .arc;
      await button(tester, 'wall-arc-dimension-badge');
      await enter(tester, '1.6');
      await button(tester, 'wall-arc-dimension-cancel');
      final after = tester
          .widget<ArchitectWallArcDimensionOverlay>(
            find.byType(ArchitectWallArcDimensionOverlay),
          )
          .arc;
      expect(after.bulge, before.bulge);
      expect(model.canUndo, isFalse);
      await button(tester, 'wall-stop-drawing');
      expect(
        find.byKey(const ValueKey('wall-arc-dimension-badge')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['bg', 'en']) {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      testWidgets(
        'Draft rise, radius switch and exact numeric preview fit $language $size',
        (tester) async {
          final model = editing.seeded(
            const ArchitectStorey(id: 's', name: ''),
          );
          addTearDown(model.dispose);
          await open(tester, model, language, size);
          await editing.selectTool(tester, 'wall');
          await button(tester, 'wall-arc-toggle');
          await workspace.wallTap(tester, const Offset(-2, 0));
          expect(
            find.byKey(const ValueKey('wall-arc-dimension-badge')),
            findsNothing,
          );
          await workspace.wallTap(tester, const Offset(2, 0));
          await tester.pumpAndSettle();
          final dimension = tester.widget<ArchitectWallArcDimensionOverlay>(
            find.byType(ArchitectWallArcDimensionOverlay),
          );
          expect(dimension.dimension, ArchitectArcDimension.sagitta);
          expect(dimension.arc.sagitta, closeTo(.8, 1e-8));
          final start = dimension.arc.start, end = dimension.arc.end;
          await screenshot(tester, 'draft_${language}_${size.width.toInt()}');
          await button(tester, 'wall-arc-dimension-badge');
          expect(find.byType(EditableText), findsNothing);
          await enter(tester, '1.25');
          expect(model.canUndo, isFalse);
          final l = AppLocalizations.of(
            tester.element(find.byType(ArchitectWallArcDimensionDialog)),
          )!;
          final edited = tester
              .widget<ArchitectWallArcDimensionOverlay>(
                find.byType(ArchitectWallArcDimensionOverlay),
              )
              .arc;
          expect(edited.sagitta, closeTo(1.25, 1e-8));
          await tester.tap(find.text(l.architectRadius));
          await tester.pumpAndSettle();
          final switched = tester.widget<ArchitectWallArcDimensionOverlay>(
            find.byType(ArchitectWallArcDimensionOverlay),
          );
          expect(switched.dimension, ArchitectArcDimension.radius);
          expect(switched.arc.bulge, edited.bulge);
          for (final key in [
            'wall-arc-dimension-input',
            'arc-key-0',
            'wall-arc-dimension-save',
            'wall-arc-dimension-cancel',
          ]) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
            expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
          }
          await screenshot(tester, 'editor_${language}_${size.width.toInt()}');
          await button(tester, 'wall-arc-dimension-save');
          // Moving a mouse over the canvas must not replace a typed curvature.
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(
            location: workspace.screen(tester, const Offset(-1, -1)),
          );
          await mouse.moveTo(workspace.screen(tester, const Offset(1, -1)));
          await tester.pumpAndSettle();
          expect(workspace.overlay(tester).activeWallArcBulge, edited.bulge);
          await mouse.removePointer();
          await button(tester, 'wall-arc-confirm');
          final wall = model.project.activeStorey.walls.single;
          expect(wall.startPoint, start);
          expect(wall.endPoint, end);
          expect(wall.arc!.sagitta, closeTo(1.25, 1e-8));
          expect(model.undoCount, 1);
          model.undo();
          expect(model.project.activeStorey.walls, isEmpty);
          model.redo();
          expect(
            model.project.activeStorey.walls.single.arcBulge,
            wall.arcBulge,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final language in ['bg', 'en']) {
    testWidgets(
      'Selected arc previews, cancels, rejects invalid input and saves once ($language)',
      (tester) async {
        final model = editing.seeded(
          const ArchitectStorey(id: 's', name: '', walls: [arc, neighbor]),
        );
        addTearDown(model.dispose);
        model.restore(model.project.copyWith(units: ArchitectUnit.centimeters));
        await open(tester, model, language, const Size(390, 844));
        await tester.tapAt(workspace.screen(tester, arc.centerPointAt(.5)));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementIds, {'arc'});
        final original = model.project.toJson();
        await button(tester, 'wall-arc-dimension-badge');
        await enter(tester, '125');
        expect(model.project.toJson(), original);
        final preview = tester.widget<ArchitectWallArcDimensionOverlay>(
          find.byType(ArchitectWallArcDimensionOverlay),
        );
        expect(preview.arc.sagitta, closeTo(1.25, 1e-8));
        await button(tester, 'wall-arc-dimension-cancel');
        expect(model.project.toJson(), original);
        expect(model.canUndo, isFalse);
        expect(
          tester
              .widget<ArchitectWallArcDimensionOverlay>(
                find.byType(ArchitectWallArcDimensionOverlay),
              )
              .arc
              .sagitta,
          1,
        );
        await button(tester, 'wall-arc-dimension-badge');
        await enter(tester, '0');
        final save = tester.widget<FilledButton>(
          find.byKey(const ValueKey('wall-arc-dimension-save')),
        );
        expect(save.onPressed, isNull);
        expect(model.canUndo, isFalse);
        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectWallArcDimensionDialog)),
        )!;
        expect(find.text(l.wallArcInvalidDimension), findsOneWidget);
        await button(tester, 'arc-key-⌫');
        // Physical comma input uses the same parser and never opens a native keyboard.
        for (final key in [
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.digit5,
          LogicalKeyboardKey.comma,
          LogicalKeyboardKey.digit5,
        ]) {
          await tester.sendKeyEvent(key);
          await tester.pump();
        }
        await button(tester, 'wall-arc-dimension-save');
        await editing.acceptGeometryCommand(tester);
        final changed = model.project.activeStorey.walls.first;
        expect(changed.arc!.sagitta, closeTo(1.255, 1e-8));
        expect(changed.startPoint, arc.startPoint);
        expect(changed.endPoint, arc.endPoint);
        expect(
          model.project.activeStorey.walls.last.toJson(),
          neighbor.copyWith(exteriorResolved: true).toJson(),
        );
        expect(model.undoCount, 1);
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project.toJson(), original);
        model.redo();
        expect(
          model.project.activeStorey.walls.first.arc!.sagitta,
          closeTo(1.255, 1e-8),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
