import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_properties_session.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_properties_shell.dart';
import 'architect_elevation_ui_test.dart' as qa;
import 'package:shared_preferences/shared_preferences.dart';
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tools;
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/widgets/architect_view_properties_dialog.dart';

ArchitectProject project() => ArchitectProject(
  id: 'p',
  name: 'Test',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [
    ArchitectStorey(
      id: 's',
      name: 'Level 1',
      walls: [
        const ArchitectWall(
          id: 'w',
          startPoint: Offset.zero,
          endPoint: Offset(5, 0),
          thickness: .25,
          height: 2.8,
          followStoreyHeight: false,
          doors: [
            ArchitectDoor(
              id: 'd',
              uuid: 'door-test',
              wallId: 'w',
              offsetRatio: .5,
              width: .9,
              height: 2.1,
              specId: '1',
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'dimension metadata converts area and paper pens without rounding geometry',
    () {
      final p = project().copyWith(units: ArchitectUnit.centimeters);
      expect(
        ArchitectPropertyDescriptor.of('targetArea').parse('12,75', p),
        12.75,
      );
      expect(
        ArchitectPropertyDescriptor.of('height').parse('280', p),
        closeTo(2.8, 1e-12),
      );
      expect(ArchitectPropertyDescriptor.of('strokeWidth').parse('0.25', p), 2);
      expect(
        ArchitectPropertyDescriptor.of('stepCount').parse('3.5', p),
        isNull,
      );
      expect(ArchitectPropertyDescriptor.of('baseOffset').parse('-20', p), -.2);
    },
  );
  test(
    'properties session previews without history and publishes one atomic edit',
    () {
      final p = project(), c = ArchitectCommandController(project());
      final session = ArchitectPropertiesSession(c.project);
      session.stage(
        'height',
        (p) => const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'w'},
          values: {'height': 3.1},
        ).apply(p),
      );
      session.stage(
        'base',
        (p) => const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'w'},
          values: {'baseOffset': .2},
        ).apply(p),
      );
      expect(c.undoCount, 0);
      expect(
        c.project.activeStorey.walls.single.height,
        p.activeStorey.walls.single.height,
      );
      session.commit(c);
      expect(c.undoCount, 1);
      expect(c.project.activeStorey.walls.single.height, 3.1);
      c.undo();
      expect(c.project.activeStorey.walls.single.baseOffset, 0);
      c.redo();
      expect(c.project.activeStorey.walls.single.height, 3.1);
      c.dispose();
      session.dispose();
    },
  );
  for (final language in ['bg', 'en']) {
    for (final width in [320.0, 390.0, 1200.0]) {
      testWidgets(
        'adaptive wall $language $width keeps draft across tabs and cancels',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = project();
          ArchitectProject? preview;
          var applied = false;
          final capture = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(language),
                theme: ThemeData(
                  fontFamily: 'TestReadable',
                  brightness: width == 390 ? Brightness.dark : Brightness.light,
                ),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: RepaintBoundary(
                  key: const ValueKey('home-capture'),
                  child: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showArchitectProperties<void>(
                          context: context,
                          builder: (_) => ArchitectElementPropertiesDialog(
                            project: p,
                            elementIds: {'w'},
                            onApply: (_, _) => false,
                            onApplyProject: (next) {
                              applied = true;
                              return true;
                            },
                            onPreview: (next) => preview = next,
                          ),
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final height = find.descendant(
            of: find.byKey(const ValueKey('architect-property-height')),
            matching: find.byType(TextFormField),
          );
          await tester.enterText(height, '3,15');
          await tester.pumpAndSettle();
          expect(preview!.activeStorey.walls.single.height, 3.15);
          expect(p.activeStorey.walls.single.height, 2.8);
          await tester.tap(find.byKey(const ValueKey('properties-tab-1')));
          await tester.pumpAndSettle();
          if (const bool.fromEnvironment('CAPTURE_PROPERTIES') &&
              language == 'bg' &&
              width == 390) {
            await tester.runAsync(() async {
              final image = await tester
                  .renderObject<RenderRepaintBoundary>(find.byKey(capture))
                  .toImage(pixelRatio: 1.5);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'scratch/properties_composition_phone.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.tap(find.byKey(const ValueKey('properties-tab-0')));
          await tester.pumpAndSettle();
          expect(tester.widget<TextFormField>(height).controller!.text, '3,15');
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_PROPERTIES')) {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(capture),
              );
              final image = await boundary.toImage(pixelRatio: 1.5);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'scratch/properties_wall_${language}_${width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          // Intentional Cancel discards the whole session without another confirmation.
          final l = AppLocalizations.of(
            tester.element(find.byType(ArchitectElementPropertiesDialog)),
          )!;
          await tester.tap(find.widgetWithText(TextButton, l.cancel).last);
          await tester.pumpAndSettle();
          expect(applied, isFalse);
          expect(preview, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('door ID appears once and numbers edit inline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ArchitectElementPropertiesDialog(
            project: project(),
            elementIds: {'d'},
            onApply: (_, _) => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('architect-property-specId')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('invalid composition input cannot be discarded by Save', (
    tester,
  ) async {
    var applied = false;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => showArchitectProperties<void>(
                context: context,
                builder: (_) => ArchitectElementPropertiesDialog(
                  project: project(),
                  elementIds: {'w'},
                  onApply: (_, _) => false,
                  onApplyProject: (next) {
                    applied = true;
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('properties-tab-1')));
    await tester.pumpAndSettle();
    final thickness = find
        .byWidgetPredicate(
          (w) =>
              w is TextFormField &&
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'wall-layer-thickness-',
              ),
        )
        .first;
    await tester.ensureVisible(thickness);
    await tester.enterText(thickness, '.');
    await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
    await tester.pumpAndSettle();
    expect(applied, isFalse);
    expect(find.byType(ArchitectElementPropertiesDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    final l = AppLocalizations.of(
      tester.element(find.byType(ArchitectElementPropertiesDialog)),
    )!;
    await tester.tap(find.widgetWithText(TextButton, l.cancel).last);
    await tester.pumpAndSettle();
  });
  testWidgets('large text and keyboard leave the save action accessible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 200),
          ),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ArchitectElementPropertiesDialog(
            project: project(),
            elementIds: {'w'},
            onApply: (_, _) => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('architect-properties-save')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('workspace opens compact properties over the real drawing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = ArchitectCommandController(project());
    addTearDown(c.dispose);
    final capture = GlobalKey();
    await tester.pumpWidget(
      qa.host(ArchitectWorkspaceScreen(commandController: c), 'bg', capture),
    );
    await tester.pumpAndSettle();
    await tools.choose(tester, Icons.near_me_outlined);
    await workspace.wallTap(tester, const Offset(1, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('architect-selection-properties')),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ArchitectPropertiesShell)).dy, 0);
    expect(c.undoCount, 0);
    expect(workspace.camera(tester).size.height, lessThan(400));
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_PROPERTIES')) {
      await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(capture))
            .toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'scratch/properties_workspace_phone.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
    await tester.pumpAndSettle();
    expect(c.undoCount, 0);
    expect(find.byType(ArchitectElementPropertiesDialog), findsNothing);
  });
  testWidgets('view depth previews project units and saves one history entry', (
    tester,
  ) async {
    final c = ArchitectCommandController(
      project().copyWith(
        units: ArchitectUnit.centimeters,
        sections: [
          const ArchitectSection(
            id: 'cut',
            start: Offset.zero,
            end: Offset(5, 0),
          ),
        ],
      ),
    );
    addTearDown(c.dispose);
    ArchitectProject? preview;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => showArchitectProperties<void>(
                context: context,
                builder: (_) => ArchitectViewPropertiesDialog(
                  project: c.project,
                  viewId: 'cut',
                  controller: c,
                  onPreview: (p) => preview = p,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    final depth = find.byType(TextFormField).last;
    await tester.enterText(depth, '250');
    await tester.pumpAndSettle();
    expect(preview!.sections.single.viewDepth, 2.5);
    expect(c.project.sections.single.viewDepth, isNull);
    expect(c.undoCount, 0);
    final l = AppLocalizations.of(
      tester.element(find.byType(ArchitectViewPropertiesDialog)),
    )!;
    await tester.tap(find.widgetWithText(FilledButton, l.save));
    await tester.pumpAndSettle();
    expect(c.project.sections.single.viewDepth, 2.5);
    expect(c.undoCount, 1);
    c.undo();
    expect(c.project.sections.single.viewDepth, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flip a mixed selection reverses each wall independently', (
    tester,
  ) async {
    final p = project();
    final wall = p.activeStorey.walls.single;
    final source = p.updateActiveStorey(
      p.activeStorey.copyWith(
        walls: [
          wall,
          wall.copyWith(
            id: 'w2',
            startPoint: const Offset(0, 3),
            endPoint: const Offset(5, 3),
            doors: [],
            exteriorSide: wall.exteriorSide == WallExteriorSide.right
                ? WallExteriorSide.left
                : WallExteriorSide.right,
          ),
        ],
      ),
    );
    ArchitectProject? saved;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => showArchitectProperties<void>(
                context: context,
                builder: (_) => ArchitectElementPropertiesDialog(
                  project: source,
                  elementIds: {'w', 'w2'},
                  onApply: (_, _) => false,
                  onApplyProject: (next) {
                    saved = next;
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('properties-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-property-flipSide')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    for (var i = 0; i < 2; i++) {
      expect(
        saved!.activeStorey.walls[i].exteriorSide,
        isNot(source.activeStorey.walls[i].exteriorSide),
      );
    }
    expect(
      saved!.activeStorey.walls.map((w) => w.exteriorSide).toSet().length,
      2,
    );
    expect(tester.takeException(), isNull);
  });
}
