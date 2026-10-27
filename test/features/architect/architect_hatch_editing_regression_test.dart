import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_polygon_geometry.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_shape_dimension_panel.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_distance_drafting_panel.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_new_point_test.dart' as points;
import 'architect_workspace_interaction_test.dart' as workspace;

const outer = [Offset(0, 0), Offset(8, 0), Offset(8, 6), Offset(0, 6)];
const hole = [Offset(2, 2), Offset(4, 2), Offset(4, 4), Offset(2, 4)];
const hatch = ArchitectCadPrimitive(
  id: 'p',
  type: CadPrimitiveType.hatch,
  startPoint: Offset.zero,
  endPoint: Offset(8, 6),
  holes: [hole],
);
ArchitectCommandController hatchModel() => editing.seeded(
  const ArchitectStorey(id: 's', name: '', cadPrimitives: [hatch]),
);
Future<void> key(WidgetTester tester, String value) async {
  for (final digit in value.split('')) {
    await tester.tap(find.byKey(ValueKey('shape-key-$digit')));
    await tester.pump();
  }
}

Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(workspace.screen(tester, from));
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.moveTo(workspace.screen(tester, to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Contour updates remove an overtaken corner instead of storing an orphan line',
    () {
      final model = hatchModel();
      addTearDown(model.dispose);
      // Pull the left part of the top edge inward. The old corner at (0,0)
      // would otherwise backtrack over the left edge as a free spur.
      model.execute(
        const UpdateArchitectPolygon(
          storeyId: 's',
          elementId: 'p',
          polygon: [
            Offset(0, 0),
            Offset(0, 1),
            Offset(1, 1),
            Offset(1, 0),
            Offset(8, 0),
            Offset(8, 6),
            Offset(0, 6),
          ],
        ),
      );
      final result = model.project.activeStorey.cadPrimitives.single;
      expect(result.polygonCorners, [
        const Offset(0, 1),
        const Offset(1, 1),
        const Offset(1, 0),
        const Offset(8, 0),
        const Offset(8, 6),
        const Offset(0, 6),
      ]);
      expect(BimPolygonGeometry.valid(result.polygonCorners), isTrue);
      expect(result.holes, [hole]);
      model.undo();
      expect(
        model.project.activeStorey.cadPrimitives.single.polygonCorners,
        outer,
      );
    },
  );
  testWidgets(
    'Selecting a hatch exposes edit tools and offsets all outer edges only',
    (tester) async {
      final model = hatchModel();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.tapAt(workspace.screen(tester, const Offset(1, 1)));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'p');
      expect(find.byKey(const ValueKey('polygon-edge-offset')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('hatch-edit-new-point')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
      await tester.pumpAndSettle();
      expect(find.text('Outer contour'), findsOneWidget);
      await key(tester, '0.5'); // centimetres
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      final result = model.project.activeStorey.cadPrimitives.single;
      expect(result.polygonCorners, [
        const Offset(-.5, -.5),
        const Offset(8.5, -.5),
        const Offset(8.5, 6.5),
        const Offset(-.5, 6.5),
      ]);
      expect(result.holes, [hole]);
      expect(workspace.overlay(tester).selectedElementId, 'p');
      model.undo();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.single.polygonCorners,
        outer,
      );
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Offset acts on the whole opening and rejects a collapsed contour',
    (tester) async {
      final model = hatchModel();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.tapAt(workspace.screen(tester, const Offset(1, 1)));
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(3, 2)));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).polygonEditHoleIndex, 0);
      await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
      await tester.pumpAndSettle();
      expect(find.text('Opening contour'), findsOneWidget);
      await key(tester, '0.5');
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      final result = model.project.activeStorey.cadPrimitives.single;
      expect(result.polygonCorners, outer);
      expect(result.holes.single, [
        const Offset(1.5, 1.5),
        const Offset(4.5, 1.5),
        const Offset(4.5, 4.5),
        const Offset(1.5, 4.5),
      ]);
      model.undo();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
      await tester.pumpAndSettle();
      await key(tester, '2'); // would touch/cross the host
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('shape-save')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('shape-cancel')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.cadPrimitives.single.holes, [hole]);
      expect(tester.takeException(), isNull);
    },
  );
  for (final kind in ['hatch', ...points.kinds]) {
    testWidgets('New point stays selected after a touch hold and move: $kind', (
      tester,
    ) async {
      final fixture = points.fixture(kind);
      final model = kind == 'hatch'
          ? hatchModel()
          : editing.seeded(
              kind == 'zone'
                  ? fixture.copyWith(
                      zones: [
                        for (final z in fixture.zones)
                          z.copyWith(isAutoBoundary: false),
                      ],
                    )
                  : fixture,
            );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      final select = ['wall', 'beam', 'line'].contains(kind)
          ? const Offset(1, 0)
          : const Offset(1, 1);
      await editing.hold(tester, select);
      expect(workspace.overlay(tester).selectedElementId, 'p');
      await tester.tap(
        find.byKey(const ValueKey('architect-selection-new-point')),
      );
      await tester.pumpAndSettle();
      final before = model.project;
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(3, 0)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.moveTo(workspace.screen(tester, const Offset(4, 0)));
      await tester.pump();
      expect(identical(before, model.project), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      final path = InsertArchitectElementPoint.pathOf(
        model.project.activeStorey,
        'p',
      )!;
      expect(path.points, contains(const Offset(4, 0)));
      expect(workspace.overlay(tester).selectedElementId, 'p');
      expect(workspace.overlay(tester).selectedElementIds, {'p'});
      expect(
        find.byKey(const ValueKey('architect-new-point-banner')),
        findsNothing,
      );
      model.undo();
      await tester.pumpAndSettle();
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Hatch pulls and retracts with the same clean contour as slabs', (
    tester,
  ) async {
    final contours = <List<Offset>>[];
    for (final slab in [false, true]) {
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: '',
          cadPrimitives: slab ? [] : [hatch.copyWith(holes: [])],
          slabs: slab ? [const ArchitectSlab(id: 'p', polygon: outer)] : [],
        ),
      );
      await workspace.open(tester, model);
      await editing.hold(tester, const Offset(1, 1));
      await drag(tester, const Offset(8, 3), const Offset(9, 3));
      await drag(tester, const Offset(9, 3), const Offset(7, 3));
      final poly = slab
          ? model.project.activeStorey.slabs.single.polygon
          : model.project.activeStorey.cadPrimitives.single.polygonCorners;
      expect(BimPolygonGeometry.valid(poly), isTrue);
      expect(poly.every((p) => p.dx <= 7), isTrue);
      expect(workspace.overlay(tester).polygonLeaderLine, isNull);
      contours.add(poly);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      model.dispose();
    }
    expect(contours.first, contours.last);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Drawing tool cannot select an existing element by tap or hold', (
    tester,
  ) async {
    final model = editing.seeded(points.fixture('wall'));
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await editing.selectTool(tester, 'wall');
    final gesture = await tester.startGesture(
      workspace.screen(tester, const Offset(2, 0)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(workspace.overlay(tester).selectedElementId, isNull);
    expect(workspace.overlay(tester).selectedElementIds, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['bg', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Phone hatch toolbar and offset stay readable: $locale $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const capture = bool.fromEnvironment('CAPTURE_HATCH_EDITING');
          if (capture) {
            await tester.runAsync(() async {
              final font = FontLoader('Roboto')
                ..addFont(
                  Future.value(
                    ByteData.sublistView(
                      await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
                    ),
                  ),
                );
              await font.load();
              final icons = FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
              await icons.load();
            });
          }
          final model = hatchModel();
          model.commit(
            model.project.copyWith(units: ArchitectUnit.centimeters),
          );
          addTearDown(model.dispose);
          final colors = brightness == Brightness.dark
              ? const ColorScheme.dark(
                  primary: Color(0xFF4F46E5),
                  surface: Color(0xFF1E293B),
                  onSurface: Color(0xFFF8FAFC),
                )
              : const ColorScheme.light(
                  primary: Color(0xFF4F46E5),
                  surface: Colors.white,
                  onSurface: Color(0xFF0F172A),
                );
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('hatch-phone-capture'),
              child: MaterialApp(
                locale: Locale(locale),
                theme: ThemeData(useMaterial3: true, colorScheme: colors),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: ArchitectWorkspaceScreen(commandController: model),
              ),
            ),
          );
          await tester.pumpAndSettle();
          workspace.camera(tester).fit(const Rect.fromLTWH(-2, -2, 12, 10));
          await tester.pumpAndSettle();
          await editing.hold(tester, const Offset(1, 1));
          final actions = find.byKey(const ValueKey('hatch-edit-new-point'));
          expect(tester.getRect(actions).right, lessThanOrEqualTo(360));
          expect(
            find.byKey(const ValueKey('polygon-edge-offset')),
            findsOneWidget,
          );
          Future<void> snapshot(String name) async {
            if (!capture || locale != 'bg') return;
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('hatch-phone-capture')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '.dart_tool/hatch-$name-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await snapshot('edit');
          await tester.tap(find.byKey(const ValueKey('polygon-edge-offset')));
          await tester.pumpAndSettle();
          await key(tester, '50');
          expect(
            tester.getRect(find.byKey(const ValueKey('shape-save'))).bottom,
            lessThanOrEqualTo(800),
          );
          await snapshot('offset');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final brightness in Brightness.values) {
    for (final shape in [true, false]) {
      testWidgets('Numeric panel contrast: $brightness shape=$shape', (
        tester,
      ) async {
        final theme = ThemeData(brightness: brightness, useMaterial3: true);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 260,
                  child: shape
                      ? BimShapeDimensionPanel(
                          values: const [50],
                          labels: const ['Offset'],
                          unit: 'cm',
                          minimum: -100,
                          signed: true,
                          onChanged: (_, _) {},
                          onSave: () {},
                          onCancel: () {},
                        )
                      : BimDistanceDraftingPanel(
                          length: 50,
                          unit: 'cm',
                          keypadInitiallyOpen: true,
                          onLength: (_) {},
                          onEnd: () {},
                          onContinue: () {},
                          onUnlock: () {},
                          onCancel: () {},
                        ),
                ),
              ),
            ),
          ),
        );
        final digit = find.descendant(
          of: find.byKey(ValueKey(shape ? 'shape-key-1' : 'wall-key-1')),
          matching: find.text('1'),
        );
        final fg = tester.widget<Text>(digit).style!.color!;
        final panel = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(
                  shape ? BimShapeDimensionPanel : BimDistanceDraftingPanel,
                ),
                matching: find.byType(Material),
              )
              .first,
        );
        final bg = panel.color!;
        final a = fg.computeLuminance(), b = bg.computeLuminance();
        final ratio = (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05));
        expect(ratio, greaterThanOrEqualTo(4.5));
        final button = tester.widget<FilledButton>(
          find.byKey(ValueKey(shape ? 'shape-save' : 'wall-continue')),
        );
        final actionFg = button.style!.foregroundColor!.resolve({})!;
        final actionBg = button.style!.backgroundColor!.resolve({})!;
        final light = actionFg.computeLuminance(),
            dark = actionBg.computeLuminance();
        expect(
          light > dark
              ? (light + .05) / (dark + .05)
              : (dark + .05) / (light + .05),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
