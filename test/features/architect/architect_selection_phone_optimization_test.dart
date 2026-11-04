import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart'
    show ArchitectTool;
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_marquee_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_candidate_picker.dart';
import 'package:kotoview/src/features/architect/widgets/architect_selection_control.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_touch_candidates_test.dart' as touch;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

List<Offset> box(double left, double top, double right, double bottom) => [
  Offset(left, top),
  Offset(right, top),
  Offset(right, bottom),
  Offset(left, bottom),
];

Future<void> phone(
  WidgetTester tester,
  ArchitectCommandController model, {
  String language = 'bg',
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('select-optimized-capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(language),
        theme: ThemeData(brightness: brightness, fontFamily: 'TestReadable'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    ),
  );
  await tester.pumpAndSettle();
  workspace.camera(tester).fit(const Rect.fromLTWH(-4, -4, 8, 8), padding: 24);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_SELECT_OPTIMIZATION')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('select-optimized-capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/select-optimized-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await qa.loadQaFonts();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    await (FontLoader(
      'ArchitectNoto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final relation in ArchitectSelectionRelation.values) {
    test(
      'Area ${relation.name} includes text and elevation markers without outside labels',
      () {
        final model = editing.seeded(
          const ArchitectStorey(
            id: 's',
            name: '',
            annotations: [
              ArchitectAnnotation(
                id: 'note',
                position: Offset(-1, 0),
                text: 'A',
              ),
              ArchitectAnnotation(
                id: 'outside-note',
                position: Offset(20, 20),
                text: 'B',
              ),
            ],
            elevationMarkers: [
              ArchitectElevationMarker(
                id: 'level',
                position: Offset(1, 0),
                elevation: 0,
              ),
              ArchitectElevationMarker(
                id: 'outside-level',
                position: Offset(20, 20),
                elevation: 3,
              ),
            ],
          ),
        );
        addTearDown(model.dispose);
        final original = model.project;
        expect(
          ArchitectMarqueeTool.evaluateSelection(
            storey: original.activeStorey,
            project: original,
            polygon: box(-5, -5, 5, 5),
            relation: relation,
          ),
          {'note', 'level'},
        );
        expect(model.project, same(original));
        expect(model.undoCount, 0);
      },
    );
  }

  test(
    'Inside requires complete annotation lettering and elevation symbols',
    () {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: '',
          annotations: [
            ArchitectAnnotation(
              id: 'note',
              position: Offset.zero,
              text: 'Long annotation',
            ),
          ],
          elevationMarkers: [
            ArchitectElevationMarker(
              id: 'level',
              position: Offset(10, 0),
              elevation: 3,
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      Set<String> hits(
        List<Offset> polygon,
        ArchitectSelectionRelation relation,
      ) => ArchitectMarqueeTool.evaluateSelection(
        storey: model.project.activeStorey,
        project: model.project,
        polygon: polygon,
        relation: relation,
      );
      expect(
        hits(box(-.05, -.05, .15, .15), ArchitectSelectionRelation.crossing),
        {'note'},
      );
      expect(
        hits(box(-.05, -.05, .15, .15), ArchitectSelectionRelation.contained),
        isEmpty,
      );
      expect(
        hits(box(9.95, -.05, 10.05, .05), ArchitectSelectionRelation.crossing),
        {'level'},
      );
      expect(
        hits(box(9.95, -.05, 10.05, .05), ArchitectSelectionRelation.contained),
        isEmpty,
      );
    },
  );

  testWidgets(
    'Phone selection controls never resize the canvas or duplicate clear',
    (tester) async {
      final model = editing.seeded(touch.scene);
      addTearDown(model.dispose);
      await phone(tester, model);
      final viewportSize = workspace.camera(tester).size;
      await tools.chooseMulti(tester);
      expect(workspace.camera(tester).size, viewportSize);
      await workspace.wallTap(tester, const Offset(2, 2));
      expect(
        find.byKey(const ValueKey('architect-clear-selection')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('architect-selection-control-clear')),
        findsOneWidget,
      );
      final controls = tester.getRect(find.byType(ArchitectSelectionControl));
      final canvas = tester.getRect(
        find.byKey(const ValueKey('architect-canvas')),
      );
      expect(canvas.contains(controls.center), isTrue);
      await tools.selectionAction(tester, 'architect-selection-move');
      expect(find.byType(ArchitectSelectionControl), findsNothing);
      expect(workspace.camera(tester).size, viewportSize);
      expect(model.undoCount, 0);
    },
  );

  testWidgets(
    'Phone primary buttons have 44 pixel targets and overflow keeps wall commands',
    (tester) async {
      final model = editing.seeded(touch.scene);
      addTearDown(model.dispose);
      await phone(tester, model);
      await workspace.wallTap(tester, const Offset(-2, 0));
      for (final key in [
        'architect-selection-move',
        'architect-selection-properties',
        'architect-selection-delete',
        'architect-clear-selection',
        'architect-selection-more',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.width, greaterThanOrEqualTo(44), reason: key);
        expect(rect.height, greaterThanOrEqualTo(44), reason: key);
        expect(rect.left, greaterThanOrEqualTo(0), reason: key);
        expect(rect.right, lessThanOrEqualTo(320), reason: key);
      }
      await tester.tap(find.byKey(const ValueKey('architect-selection-more')));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(ArchitectWorkspaceScreen)),
      )!;
      expect(find.text(l.architectMirrorCopy), findsOneWidget);
      expect(find.text(l.bimNewPoint), findsOneWidget);
      expect(find.byKey(const ValueKey('wall-cut')), findsOneWidget);
      await capture(tester, 'actions-bg');
      await tools.selectionAction(tester, 'architect-selection-mirror-copy');
      expect(
        find.byKey(const ValueKey('architect-command-apply')),
        findsOneWidget,
      );
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ['door', 'window']) {
    testWidgets(
      'Phone $kind flip from overlap actions keeps confirmation and Undo',
      (tester) async {
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: '',
            walls: [
              ArchitectWall(
                id: 'wall',
                startPoint: const Offset(-3, 0),
                endPoint: const Offset(3, 0),
                doors: kind == 'door'
                    ? const [
                        ArchitectDoor(
                          id: 'door',
                          wallId: 'wall',
                          uuid: 'door',
                          offsetRatio: .5,
                        ),
                      ]
                    : const [],
                windows: kind == 'window'
                    ? const [
                        ArchitectWindow(
                          id: 'window',
                          wallId: 'wall',
                          uuid: 'window',
                          offsetRatio: .5,
                        ),
                      ]
                    : const [],
              ),
            ],
          ),
        );
        addTearDown(model.dispose);
        await phone(tester, model);
        final original = model.project;
        await workspace.wallTap(tester, Offset.zero);
        expect(workspace.overlay(tester).selectedElementIds, {kind});
        expect(find.byType(ArchitectCandidatePicker), findsOneWidget);
        await tools.selectionAction(
          tester,
          kind == 'door'
              ? 'architect-door-flip-swing'
              : 'architect-window-flip-side',
        );
        expect(model.project, same(original));
        expect(model.undoCount, 0);
        await editing.acceptGeometryCommand(tester);
        if (kind == 'door') {
          expect(
            model.project.activeStorey.walls.single.doors.single.openInward,
            isFalse,
          );
        } else {
          expect(
            model.project.activeStorey.walls.single.windows.single.isFlipped,
            isTrue,
          );
        }
        expect(model.undoCount, 1);
        model.undo();
        expect(model.project, same(original));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['bg', 'en']) {
    for (final brightness in Brightness.values) {
      for (final textScale in [1.0, 1.6]) {
        testWidgets(
          'Phone $language $brightness text $textScale preserves overlap and active tool',
          (tester) async {
            final model = editing.seeded(touch.scene);
            addTearDown(model.dispose);
            final original = model.project;
            await phone(
              tester,
              model,
              language: language,
              brightness: brightness,
              textScale: textScale,
            );
            await workspace.wallTap(tester, Offset.zero);
            final picker = tester.widget<ArchitectCandidatePicker>(
              find.byType(ArchitectCandidatePicker),
            );
            expect(picker.labels.map((e) => e.id), ['column', 'wall']);
            expect(workspace.overlay(tester).selectedElementIds, {'column'});
            await touch.tapKey(tester, 'architect-candidate-next');
            expect(workspace.overlay(tester).selectedElementIds, {'wall'});
            expect(
              tester
                  .widget<ArchitectToolPalette>(
                    find.byType(ArchitectToolPalette),
                  )
                  .activeTool,
              ArchitectTool.wall,
            );
            expect(
              find.byKey(const ValueKey('architect-draw-selection')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('architect-selection-bar')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('architect-selection-more')),
              findsOneWidget,
            );
            await tools.chooseMulti(tester);
            await workspace.wallTap(tester, Offset.zero);
            final chooser = tester.getRect(
              find.byType(ArchitectCandidatePicker),
            );
            final position = find.byKey(
              const ValueKey('architect-candidate-position'),
            );
            expect(
              find.descendant(
                of: find.byType(ArchitectCandidatePicker),
                matching: find.text('1/2'),
              ),
              findsOneWidget,
            );
            expect(
              tester.getRect(position).right,
              lessThanOrEqualTo(chooser.right),
            );
            expect(chooser.left, greaterThanOrEqualTo(0));
            expect(chooser.right, lessThanOrEqualTo(320));
            expect(chooser.bottom, lessThanOrEqualTo(800));
            await capture(tester, '$language-${brightness.name}-$textScale');
            await tools.selectionAction(
              tester,
              'architect-selection-properties',
            );
            expect(find.byType(ArchitectCandidatePicker), findsNothing);
            expect(model.project, same(original));
            expect(model.undoCount, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
