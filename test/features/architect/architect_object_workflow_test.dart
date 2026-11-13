import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/components/definitions/furniture_components.dart';
import 'package:kotoview/src/features/architect/components/definitions/service_components.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_component_opening_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_component_placement.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_rotation.dart';
import 'package:kotoview/src/features/architect/services/component_library_service.dart';
import 'package:kotoview/src/features/architect/widgets/architect_component_library_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

final bed = FurnitureBedDouble();
final originalObject = ArchitectComponentInstance(
  id: 'object',
  definitionId: bed.id,
  position: const Offset(-.8, -1),
  parameters: bed.defaultParameters,
  label: 'A-12',
  elevationOffset: .08,
  rotation: math.pi / 12,
);

ArchitectCommandController model({bool object = false, bool locked = false}) =>
    editing.seeded(
      ArchitectStorey(
        id: 's',
        name: '',
        components: [if (object) originalObject.copyWith(isLocked: locked)],
      ),
    );

Future<void> open(
  WidgetTester tester,
  ArchitectCommandController commands, {
  String language = 'en',
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('object-review'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: brightness, fontFamily: 'ArchitectNoto'),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: commands),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, ArchitectTool tool) async {
  tester
      .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
      .onToolChanged(tool);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['OBJECT_REVIEW_IMAGES'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('object-review')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/object_review').createSync(recursive: true);
    File(
      'build/object_review/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class OpeningCanvas implements Canvas {
  int lines = 0, clips = 0;
  @override
  void clipPath(Path path, {bool doAntiAlias = true}) => clips++;
  @override
  void drawLine(Offset a, Offset b, Paint p) => lines++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ComponentLibraryService.instance.init();
    for (final family in ['Roboto', 'ArchitectNoto']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    }
  });
  setUp(() => ComponentLibraryService.instance.setActiveDefinition(bed));

  test(
    'Wall attachment uses closest physical face and respects magnet off',
    () {
      final near = editing
          .wall('near', Offset.zero, const Offset(5, 0))
          .copyWith(referenceLine: WallReferenceLine.inner);
      final far = editing.wall('far', const Offset(0, .6), const Offset(5, .6));
      final face = near.centerStart + near.normalVector * (near.thickness / 2);
      final raw = Offset(2, face.dy + .02);
      final result = ArchitectComponentPlacement.resolve(
        raw: raw,
        definition: bed,
        walls: [far, near],
        rotation: .7,
        tolerance: .25,
        magnetic: true,
      );
      expect(result.$1, Offset(2, face.dy));
      expect(result.$2, closeTo(0, 1e-9));
      final free = ArchitectComponentPlacement.resolve(
        raw: raw,
        definition: bed,
        walls: [near],
        rotation: .7,
        tolerance: .25,
        magnetic: false,
      );
      expect(free, (raw, .7));
    },
  );

  test(
    'Opening crosses are clipped to real voids and avoid casing and pipes',
    () {
      for (final kind in ServiceComponentKind.values.where(
        (k) => k != ServiceComponentKind.fireplace,
      )) {
        final definition = ServiceComponentDefinition(kind);
        final block = definition
            .generateGeometry(definition.defaultParameters)
            .block2d;
        expect(block.openingPaths, isNotEmpty, reason: kind.name);
        final canvas = OpeningCanvas();
        ArchitectComponentOpeningPainter.draw(canvas, block, Paint());
        expect(canvas.clips, block.openingPaths.length);
        expect(canvas.lines, 2 * block.openingPaths.length);
        final vector = ArchitectVectorCanvas();
        ArchitectComponentOpeningPainter.draw(
          vector,
          block,
          Paint()..strokeWidth = .001,
        );
        expect(vector.operations.every((op) => op.clip != null), isTrue);
      }
      final definition = ServiceComponentDefinition(
        ServiceComponentKind.combinedRiser,
      );
      final block = definition
          .generateGeometry(definition.defaultParameters)
          .block2d;
      expect(
        block.openingPaths.first.contains(const Offset(-.135, .125)),
        isFalse,
      );
      expect(
        block.openingPaths.first.contains(const Offset(-.245, .125)),
        isFalse,
      );
    },
  );

  test('Object translation, duplication and rotation preserve model data', () {
    final commands = model(object: true);
    addTearDown(commands.dispose);
    final moved = MoveArchitectElements(
      storeyId: 's',
      elementIds: {'object'},
      delta: const Offset(1, 2),
    ).apply(commands.project);
    expect(
      moved.activeStorey.components.single.position,
      originalObject.position + const Offset(1, 2),
    );
    final (copied, id) = ArchitectElementTool().duplicateElementById(
      moved.activeStorey,
      'object',
      offset: const Offset(2, 0),
    );
    expect(id, isNotNull);
    expect(copied.components.length, 2);
    expect(copied.components.last.label, originalObject.label);
    expect(copied.components.last.rotation, originalObject.rotation);
    final rotated = ArchitectRotation.apply(
      copied,
      {id!},
      copied.components.last.position,
      math.pi / 2,
    );
    expect(
      rotated.components.last.rotation,
      closeTo(originalObject.rotation + math.pi / 2, 1e-9),
    );
    final locked = model(object: true, locked: true);
    addTearDown(locked.dispose);
    expect(
      MoveArchitectElement(
        storeyId: 's',
        elementId: 'object',
        delta: const Offset(1, 1),
      ).apply(locked.project),
      same(locked.project),
    );
  });

  for (final language in ['bg', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Phone Object placement, cancel and repeat toggle: $language $brightness',
        (tester) async {
          final commands = model(object: true);
          addTearDown(commands.dispose);
          await open(
            tester,
            commands,
            language: language,
            brightness: brightness,
          );
          await choose(tester, ArchitectTool.component);
          final button = find.byKey(const ValueKey('architect-tool-component'));
          final l = AppLocalizations.of(tester.element(button))!;
          expect(
            find.descendant(
              of: button,
              matching: find.text(l.architectToolComponent),
            ),
            findsOneWidget,
          );
          // Tapping over an existing bed stages another object, without selecting it.
          await workspace.wallTap(tester, const Offset(-.5, 0));
          await tester.pumpAndSettle();
          expect(commands.project.activeStorey.components.length, 1);
          expect(workspace.overlay(tester).componentPreview, isNotNull);
          expect(workspace.overlay(tester).selectedElementId, isNull);
          await capture(tester, 'placement_${language}_${brightness.name}');
          await tester.tap(
            find.byKey(const ValueKey('architect-draft-confirm')),
          );
          await tester.pumpAndSettle();
          expect(commands.project.activeStorey.components.length, 2);
          expect(commands.undoCount, 1);
          expect(workspace.overlay(tester).componentPreview, isNull);
          await workspace.wallTap(tester, const Offset(2, 1));
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
                .activeTool,
            ArchitectTool.pan,
          );
          expect(workspace.overlay(tester).componentPreview, isNull);
          expect(find.byType(ArchitectComponentLibraryDialog), findsNothing);
          // The pending object was discarded, and a new canvas tap selects only.
          await workspace.wallTap(tester, const Offset(2, 1));
          await tester.pumpAndSettle();
          expect(commands.project.activeStorey.components.length, 2);
          commands.undo();
          await tester.pumpAndSettle();
          expect(commands.project.activeStorey.components.length, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final manualSelection in [false, true]) {
    testWidgets(
      'Selected object moves directly with one Undo, manual=$manualSelection',
      (tester) async {
        final commands = model(object: true);
        addTearDown(commands.dispose);
        await open(tester, commands);
        await tools.setMagnetic(tester, false);
        if (manualSelection) await choose(tester, ArchitectTool.select);
        await workspace.wallTap(tester, const Offset(-.5, 0));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementId, originalObject.id);
        expect(workspace.overlay(tester).componentPreview, isNull);
        await tester.dragFrom(
          workspace.screen(tester, const Offset(-.5, 0)),
          const Offset(70, -25),
        );
        await tester.pumpAndSettle();
        final moved = commands.project.activeStorey.components.single;
        expect(moved.position, isNot(originalObject.position));
        expect(moved.rotation, originalObject.rotation);
        expect(moved.label, originalObject.label);
        expect(commands.undoCount, 1);
        commands.undo();
        await tester.pumpAndSettle();
        expect(
          commands.project.activeStorey.components.single.position,
          originalObject.position,
        );
        commands.redo();
        await tester.pumpAndSettle();
        expect(
          commands.project.activeStorey.components.single.position,
          moved.position,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Object Drag reviews a target and commits once', (tester) async {
    final commands = model(object: true);
    addTearDown(commands.dispose);
    await open(tester, commands);
    await workspace.wallTap(tester, const Offset(-.5, 0));
    await tester.pumpAndSettle();
    await tools.selectionAction(tester, 'architect-selection-move');
    expect(
      workspace.overlay(tester).dragController!.isPickingBasePoint,
      isTrue,
    );
    await capture(tester, 'drag_before_base');
    await workspace.wallTap(tester, const Offset(-.5, 0));
    await tester.pumpAndSettle();
    expect(
      workspace.overlay(tester).dragController!.isDraggingToTarget,
      isTrue,
    );
    await workspace.wallTap(tester, const Offset(-.1, .3));
    await tester.pumpAndSettle();
    expect(commands.undoCount, 0);
    expect(workspace.overlay(tester).componentPreview, isNull);
    await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
    await tester.pumpAndSettle();
    expect(
      commands.project.activeStorey.components.single.position,
      isNot(originalObject.position),
    );
    expect(commands.undoCount, 1);
    commands.undo();
    await tester.pumpAndSettle();
    expect(
      commands.project.activeStorey.components.single.position,
      originalObject.position,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Object placement hold never opens editing; cancel discards it', (
    tester,
  ) async {
    final commands = model(object: true);
    addTearDown(commands.dispose);
    await open(tester, commands);
    await choose(tester, ArchitectTool.component);
    final gesture = await tester.startGesture(
      workspace.screen(tester, const Offset(-.5, 0)),
    );
    await tester.pump(const Duration(milliseconds: 750));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(ArchitectRadialMenu), findsNothing);
    expect(commands.undoCount, 0);
    expect(workspace.overlay(tester).componentPreview, isNotNull);
    await tester.tap(find.byKey(const ValueKey('architect-draft-cancel')));
    await tester.pumpAndSettle();
    expect(workspace.overlay(tester).componentPreview, isNull);
    expect(commands.project.activeStorey.components.length, 1);
    expect(
      tester
          .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
          .activeTool,
      ArchitectTool.pan,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Catalog cancel and stale replacement leave the current document intact',
    (tester) async {
      final commands = model(object: true);
      addTearDown(commands.dispose);
      await open(tester, commands);
      await workspace.wallTap(tester, const Offset(-.5, 0));
      await tester.pumpAndSettle();
      await tools.selectionAction(tester, 'architect-component-replace');
      final dialog = find.byType(ArchitectComponentLibraryDialog);
      Navigator.of(tester.element(dialog)).pop();
      await tester.pumpAndSettle();
      expect(commands.undoCount, 0);
      await tools.selectionAction(tester, 'architect-component-replace');
      final callback = tester
          .widget<ArchitectComponentLibraryDialog>(dialog)
          .onSelectComponent!;
      commands.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'object',
          delta: Offset(1, 0),
        ),
      );
      await tester.pumpAndSettle();
      final latest = commands.project;
      callback(FurnitureSofa());
      expect(commands.project, same(latest));
      expect(commands.undoCount, 1);
      Navigator.of(tester.element(dialog)).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['bg', 'en']) {
    testWidgets('Replace from catalog preserves identity and Undo: $language', (
      tester,
    ) async {
      final commands = model(object: true);
      addTearDown(commands.dispose);
      final activeId = ComponentLibraryService.instance.activeDefinition.id;
      await open(
        tester,
        commands,
        language: language,
        brightness: language == 'bg' ? Brightness.dark : Brightness.light,
      );
      await workspace.wallTap(tester, const Offset(-.5, 0));
      await tester.pumpAndSettle();
      final secondary = await tester.startGesture(
        workspace.screen(tester, const Offset(-.5, 0)),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await secondary.up();
      await tester.pumpAndSettle();
      final radial = tester.widget<ArchitectRadialMenu>(
        find.byType(ArchitectRadialMenu),
      );
      expect(
        radial.items.any((i) => i.action == ArchitectRadialAction.replace),
        isTrue,
      );
      radial.onDismiss();
      await tester.pumpAndSettle();
      // Both the context menu and the selection bar expose replacement.
      final menuItems = tester.widget<ArchitectToolPalette>(
        find.byType(ArchitectToolPalette),
      );
      expect(menuItems.activeTool, ArchitectTool.component);
      await tools.selectionAction(tester, 'architect-component-replace');
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectComponentLibraryDialog), findsOneWidget);
      await capture(tester, 'library_$language');
      final category = find.byKey(const ValueKey('component-library-category'));
      final dropdown = tester
          .widget<DropdownButton<ArchitectComponentCategory>>(category);
      expect(
        dropdown.dropdownColor,
        Theme.of(tester.element(category)).colorScheme.surfaceContainerHigh,
      );
      await tester.enterText(
        find.byType(TextField).first,
        language == 'bg' ? 'Диван' : 'Sofa',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('component-library-item-furniture_sofa')),
      );
      await tester.pumpAndSettle();
      final replacement = commands.project.activeStorey.components.single;
      expect(replacement.definitionId, 'furniture_sofa');
      expect(replacement.id, originalObject.id);
      expect(replacement.position, originalObject.position);
      expect(replacement.rotation, originalObject.rotation);
      expect(replacement.elevationOffset, originalObject.elevationOffset);
      expect(replacement.label, originalObject.label);
      expect(workspace.overlay(tester).componentPreview, isNull);
      // Selecting an edit target may load its preset; replacement does not arm placement.
      expect(ComponentLibraryService.instance.activeDefinition.id, activeId);
      expect(commands.undoCount, 1);
      final saved = ArchitectProject.fromJson(commands.project.toJson());
      expect(
        saved.activeStorey.components.single.definitionId,
        replacement.definitionId,
      );
      commands.undo();
      await tester.pumpAndSettle();
      expect(
        commands.project.activeStorey.components.single.definitionId,
        bed.id,
      );
      commands.redo();
      await tester.pumpAndSettle();
      expect(
        commands.project.activeStorey.components.single.definitionId,
        replacement.definitionId,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
