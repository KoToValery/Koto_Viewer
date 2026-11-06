import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_railing_selection.dart';
import 'package:kotoview/src/features/architect/rendering/architect_railing_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_railing_catalog.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_compositions.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_composition_editor.dart';

const oldWall = ArchitectWall(
  id: 'w',
  startPoint: Offset.zero,
  endPoint: Offset(3, 0),
  thickness: .12,
  height: 1.2,
  parapet: true,
  followStoreyHeight: false,
);
ArchitectProject project(List<ArchitectWall> walls) => ArchitectProject(
  id: 'p',
  name: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  storeys: [ArchitectStorey(id: 's', name: '', walls: walls)],
  activeStoreyId: 's',
);
ArchitectWallType preset(ArchitectRailingKind kind) => ArchitectRailingCatalog
    .presets
    .firstWhere((type) => type.railing!.kind == kind);

Future<void> openEditor(
  WidgetTester tester,
  ArchitectWallType type, {
  String language = 'bg',
  double width = 360,
  bool dark = false,
  required bool Function(ArchitectWallType) onApply,
}) async {
  tester.view.physicalSize = Size(width, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        fontFamily: 'Roboto',
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RepaintBoundary(
                key: const ValueKey('capture-railing'),
                child: ArchitectWallCompositionEditor(
                  project: project(
                    [],
                  ).copyWith(units: ArchitectUnit.centimeters),
                  type: type,
                  typeUseCount: 0,
                  onApply: (value, _, _) => onApply(value),
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
}

Finder dimension(String kind, String id) => find.descendant(
  of: find.byKey(ValueKey('railing-$kind-$id-centimeters')),
  matching: find.byType(TextFormField),
);

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['KOTO_VISUALS'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture-railing')),
    );
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await Directory('scratch').create(recursive: true);
    await File('scratch/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'placing a library type saves its definition atomically and preserves existing IDs',
    () {
      final type = preset(ArchitectRailingKind.glassPosts);
      final initial = project([]).copyWith(wallTypes: const []);
      final model = ArchitectCommandController(initial);
      addTearDown(model.dispose);
      final baseline = model.project;
      final placed = oldWall.copyWith(
        wallTypeId: type.id,
        railing: type.railing,
        thickness: type.totalThickness,
      );
      model.execute(
        CreateArchitectWall(storeyId: 's', wall: placed, wallType: type),
      );
      expect(model.project.wallTypes.single.id, type.id);
      expect(
        model.project.activeStorey.walls.single.railing!.kind,
        type.railing!.kind,
      );
      model.undo();
      expect(model.project, same(baseline));
      expect(model.project.wallTypes, isEmpty);
      final custom = type.copyWith(name: 'Personal', customHeight: 1.3);
      final saved = CreateArchitectWall(
        storeyId: 's',
        wall: placed,
        wallType: type,
      ).apply(initial.copyWith(wallTypes: [custom]));
      expect(saved.wallTypes.single, same(custom));
    },
  );

  test(
    'local composition keeps height unless edited; Undo restores legacy',
    () {
      final original = project([oldWall]);
      final model = ArchitectCommandController(original);
      final baseline = model.project;
      addTearDown(model.dispose);
      model.execute(
        SetArchitectWallComposition(
          type: preset(ArchitectRailingKind.glassChannel),
          storeyId: 's',
          wallIds: const {'w'},
        ),
      );
      expect(model.project.activeStorey.walls.single.height, 1.2);
      expect(model.project.activeStorey.walls.single.resolvedLayers, isEmpty);
      model.undo();
      expect(model.project, same(baseline));
      model.redo();
      expect(
        model.project.activeStorey.walls.single.railing!.kind,
        ArchitectRailingKind.glassChannel,
      );
      final edited = SetArchitectWallComposition(
        type: preset(ArchitectRailingKind.solidStainless),
        storeyId: 's',
        wallIds: const {'w'},
        railingHeight: 1.35,
      ).apply(model.project);
      expect(edited.activeStorey.walls.single.height, 1.35);
      expect(
        edited.activeStorey.walls.single.solidBodyHeight,
        closeTo(1.2, 1e-9),
      );
      final plain = ArchitectWallType.standardCatalog().first;
      expect(
        SetArchitectWallComposition(
          type: plain,
          storeyId: 's',
          wallIds: const {'w'},
        ).apply(edited).activeStorey.walls.single.railing,
        isNull,
      );
    },
  );

  test(
    'conversion with hosted openings fails atomically and placement ignores rails',
    () {
      final host = oldWall.copyWith(
        doors: [
          const ArchitectDoor(
            id: 'd',
            wallId: 'w',
            uuid: 'door-id',
            offsetRatio: .5,
          ),
        ],
      );
      final original = project([host]);
      expect(
        () => SetArchitectWallComposition(
          type: preset(ArchitectRailingKind.glassPosts),
          storeyId: 's',
          wallIds: const {'w'},
        ).apply(original),
        throwsA(isA<ArchitectRailingOpeningsError>()),
      );
      expect(original.activeStorey.walls.single.doors.single.id, 'd');
      final rail = oldWall.copyWith(
        railing: preset(ArchitectRailingKind.glassChannel).railing,
      );
      final rear = oldWall.copyWith(
        id: 'rear',
        startPoint: const Offset(0, .5),
        endPoint: const Offset(3, .5),
        parapet: false,
      );
      expect(
        ArchitectOpeningPlacement.resolve(
          rawPoint: const Offset(1.5, 0),
          walls: [rail, rear],
          openingWidth: .9,
        )!.wall.id,
        'rear',
      );
      expect(
        ArchitectOpeningPlacement.resolve(
          rawPoint: const Offset(1.5, 0),
          walls: [rail],
          fixedHostWall: rail,
          openingWidth: .9,
        ),
        isNull,
      );
    },
  );

  test(
    'physical snap edges exclude the selectable envelope of an open rail',
    () {
      final rail = oldWall.copyWith(
        thickness: .5,
        railing: preset(ArchitectRailingKind.verticalBars).railing,
      );
      final p = project([rail]);
      final snap = ArchitectSnapGeometry.of(p);
      expect(snap.edges.any((edge) => edge.owner == '@wall-axis:w'), isTrue);
      expect(
        snap.edges
            .where((edge) => edge.owner == 'w')
            .every((edge) => edge.a.dy.abs() < .03 && edge.b.dy.abs() < .03),
        isTrue,
      );
      expect(
        ArchitectWallGeometry.of(
          p.activeStorey.walls,
        ).corners.every((point) => point.dy.abs() < .03),
        isTrue,
      );
      expect(
        ArchitectWallClearance.nearest(rail, [
          rail,
          oldWall.copyWith(id: 'other'),
        ]),
        isEmpty,
      );
    },
  );

  test(
    'side-mounted selection envelope contains the actual components without becoming a solid',
    () {
      final rail = oldWall.copyWith(
        railing: preset(
          ArchitectRailingKind.glassChannel,
        ).railing!.copyWith(mounting: ArchitectRailingMount.side),
      );
      final p = project([rail]);
      final envelope = ArchitectRailingSelection.envelope(
        rail,
        p.activeStorey.walls,
      );
      final parts = ArchitectRailingGeometry.components(
        rail,
        walls: p.activeStorey.walls,
      );
      for (final part in parts) {
        final bounds = part.plan.getBounds();
        expect(
          ArchitectSelection.bounds(
            p,
            'w',
          )!.inflate(.00001).contains(bounds.center),
          isTrue,
        );
      }
      expect(envelope.contains(parts.first.plan.getBounds().center), isTrue);
      expect(rail.resolvedLayers, isEmpty);
    },
  );

  for (final width in [320.0, 360.0, 390.0]) {
    final language = width == 360 ? 'en' : 'bg';
    for (final kind in ArchitectRailingKind.values) {
      testWidgets(
        'railing ${kind.name} fits $width $language and preserves height',
        (tester) async {
          ArchitectWallType? saved;
          await openEditor(
            tester,
            preset(kind).copyWith(customHeight: 1.2),
            width: width,
            language: language,
            dark: width == 320,
            onApply: (value) {
              saved = value;
              return true;
            },
          );
          expect(tester.takeException(), isNull);
          expect(dimension(kind.name, 'height'), findsOneWidget);
          if (kind == ArchitectRailingKind.solidStainless && width == 360) {
            await capture(tester, 'architect_railing_inox_en_360');
          }
          if (kind == ArchitectRailingKind.glassChannel && width == 390) {
            await capture(tester, 'architect_railing_glass_bg_390');
          }
          await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
          await tester.pumpAndSettle();
          expect(saved!.customHeight, 1.2);
          expect(saved!.railing!.kind, kind);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'height updates dependent solid height; precise edits use project units',
    (tester) async {
      ArchitectWallType? saved;
      await openEditor(
        tester,
        preset(ArchitectRailingKind.solidStainless),
        onApply: (value) {
          saved = value;
          return true;
        },
      );
      await tester.enterText(dimension('solidStainless', 'height'), '135');
      await tester.pump();
      final input = tester.widget<TextFormField>(
        dimension('solidStainless', 'solid-height'),
      );
      expect(input.controller!.text, '120');
      await tester.enterText(
        dimension('solidStainless', 'solid-height'),
        '115,5',
      );
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      expect(saved!.customHeight, 1.35);
      expect(saved!.railing!.solidHeight, closeTo(1.155, 1e-9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coping and solid height stay consistent without unused controls',
    (tester) async {
      ArchitectWallType? saved;
      await openEditor(
        tester,
        preset(ArchitectRailingKind.solidCap),
        onApply: (value) {
          saved = value;
          return true;
        },
      );
      await tester.enterText(dimension('solidCap', 'solid-height'), '100');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('railing-details-solidCap')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('railing-mount-solidCap')),
        findsNothing,
      );
      final coping = dimension('solidCap', 'coping');
      expect(tester.widget<TextFormField>(coping).controller!.text, '5');
      await tester.enterText(coping, '4');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(dimension('solidCap', 'solid-height'))
            .controller!
            .text,
        '101',
      );
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      expect(saved!.railing!.copingThickness, .04);
      expect(saved!.railing!.solidHeightAt(1.05), closeTo(1.01, 1e-9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refused conversion explains hosted openings in the editor', (
    tester,
  ) async {
    final original = project([
      oldWall.copyWith(
        doors: [
          const ArchitectDoor(
            id: 'd',
            wallId: 'w',
            uuid: 'door-id',
            offsetRatio: .5,
          ),
        ],
      ),
    ]);
    await openEditor(
      tester,
      preset(ArchitectRailingKind.glassChannel),
      language: 'en',
      onApply: (value) {
        SetArchitectWallComposition(
          type: value,
          storeyId: 's',
          wallIds: const {'w'},
        ).apply(original);
        return true;
      },
    );
    await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Move or remove the wall’s doors and windows first.'),
      findsOneWidget,
    );
    expect(find.byType(ArchitectWallCompositionEditor), findsOneWidget);
    expect(original.activeStorey.walls.single.doors.single.id, 'd');
    expect(tester.takeException(), isNull);
  });
}
