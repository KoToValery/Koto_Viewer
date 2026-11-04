import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_fenestration_style.dart';
import 'package:kotoview/src/features/architect/rendering/fenestration_3d_builder.dart';
import 'package:kotoview/src/features/architect/screens/fenestration_editor_screen.dart';
import 'package:kotoview/src/features/architect/services/fenestration_library_service.dart';
import 'package:kotoview/src/features/architect/widgets/architect_component_library_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/fenestration_preview.dart';

ArchitectFenestrationStyle doorStyle() =>
    ArchitectFenestrationStyle.standardCatalog()
        .firstWhere((s) => s.id == 'door_interior_standard')
        .copyWith(id: 'review-door', name: 'D-01');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'transom keeps door body, supports editing, splitting, and old JSON',
    () {
      final door = doorStyle();
      final combined = door.withTransom(const FenestrationTransom());
      expect(combined.defaultHeight, closeTo(2.4, 1e-9));
      expect(combined.doorBodyHeight, closeTo(door.defaultHeight, 1e-9));
      expect(combined.getPaneRect('transom_pane')!.top, closeTo(2, 1e-9));
      expect(combined.hitTest(const Offset(.45, 2.2))!.$1.id, 'transom_pane');
      final split = combined.splitPane('transom_pane', vertical: true);
      expect(split.transom!.subdivision.collectPanes(), hasLength(2));
      expect(split.rootSubdivision.toJson(), door.rootSubdivision.toJson());
      final edited = split.setPaneMetricDimension(
        split.transom!.subdivision.collectPanes().first.id,
        .35,
        true,
      );
      expect(
        edited
            .getPaneRect(edited.transom!.subdivision.collectPanes().first.id)!
            .width,
        closeTo(.35, 1e-9),
      );
      final restored = ArchitectFenestrationStyle.fromJson(combined.toJson());
      expect(restored.toJson(), combined.toJson());
      expect(restored.withTransom(null).toJson(), door.toJson());
      expect(
        ArchitectFenestrationStyle.fromJson(door.toJson()).transom,
        isNull,
      );
      expect(combined.copyWith(defaultHeight: 2.7).transom!.height, .4);
    },
  );

  test(
    'solid infill preserves mechanism and survives serialization and splits',
    () {
      final door = doorStyle();
      final leaf = door.panes.single.copyWith(infill: FenestrationInfill.solid);
      expect(leaf.isOpenable, isTrue);
      expect(leaf.isGlazed, isFalse);
      final updated = door.updatePane(leaf).splitPane(leaf.id, vertical: true);
      for (final pane in ArchitectFenestrationStyle.fromJson(
        updated.toJson(),
      ).panes) {
        expect(pane.isOpenable, isTrue);
        expect(pane.isGlazed, isFalse);
      }
    },
  );

  test('physical clear zones exclude profiles and agree with the plan cut', () {
    final style = doorStyle().withTransom(const FenestrationTransom());
    final layout = style.resolveLayout();
    expect(layout.dividers, hasLength(1));
    expect(layout.dividers.single.center.dy, closeTo(2, 1e-9));
    for (final entry in layout.panes.values) {
      for (final profile in layout.dividers) {
        expect(entry.rect.overlaps(profile), isFalse);
      }
    }
    for (final hingeLeft in [false, true]) {
      for (final inward in [false, true]) {
        final leaf = style
            .doorPlanLeaves(
              center: Offset.zero,
              direction: const Offset(1, 0),
              normal: const Offset(0, 1),
              width: .9,
              height: 2.4,
              wallThickness: .37,
              isHingeLeft: hingeLeft,
              openInward: inward,
            )
            .single;
        expect(leaf.hinge.dx.sign, hingeLeft ? -1 : 1);
        expect(leaf.direction.dy.sign, inward ? 1 : -1);
        expect(leaf.length, closeTo(.82, 1e-9));
      }
    }
    expect(
      style.doorPlanLeaves(
        center: Offset.zero,
        direction: const Offset(1, 0),
        normal: const Offset(0, 1),
        width: .9,
        height: 2.4,
        wallThickness: .37,
        cutHeight: 2.2,
      ),
      isEmpty,
    );
    final tris = Fenestration3dBuilder.buildOpening3D(
      style: style,
      wallStart: const Offset(0, 0),
      wallEnd: const Offset(4, 0),
      wallThickness: .37,
      coreThickness: .25,
      insulationThickness: .12,
      exteriorSign: 1,
      offsetRatio: .5,
      width: .9,
      height: 2.4,
      sillHeight: 0,
      storeyElevation: 0,
    );
    final hinges = tris.where(
      (t) => t.color == Fenestration3dBuilder.hingeColor,
    );
    expect(hinges, isNotEmpty);
    expect(
      hinges.expand((t) => [t.v0.z, t.v1.z, t.v2.z]).every((z) => z < 2),
      isTrue,
    );
    expect(
      tris
          .where((t) => t.color == Fenestration3dBuilder.glassColor)
          .any((t) => t.v0.z > 2),
      isTrue,
    );
  });

  test(
    'built-in copies and legacy collisions have stable independent identities',
    () async {
      final preset = ArchitectFenestrationStyle.standardCatalog().first;
      SharedPreferences.setMockInitialValues({
        'architect_fenestration_custom_styles_v1': jsonEncode([
          preset.copyWith(name: 'Existing custom', defaultWidth: 1.73).toJson(),
        ]),
      });
      final library = FenestrationLibraryService.forTesting();
      await library.init();
      final custom = library.getAllStyles().singleWhere(
        (s) => s.name == 'Existing custom',
      );
      expect(custom.id, isNot(preset.id));
      expect(custom.isPreset, isFalse);
      expect(
        library.getStyleById(preset.id)!.defaultWidth,
        preset.defaultWidth,
      );
      final reopened = FenestrationLibraryService.forTesting();
      await reopened.init();
      expect(reopened.getStyleById(custom.id)!.defaultWidth, 1.73);
      final saved = await library.saveStyle(
        preset.copyWith(name: 'New custom'),
      );
      expect(saved.id, isNot(preset.id));
      await library.saveStyle(saved.copyWith(defaultWidth: 1.95));
      expect(
        library.getAllStyles().where((s) => s.id == saved.id),
        hasLength(1),
      );
      expect(library.getStyleById(saved.id)!.defaultWidth, 1.95);
      expect(await library.deleteStyle(preset.id), isFalse);
      library.dispose();
      reopened.dispose();
    },
  );

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/fenestration_review')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
    });
  }

  Future<void> openEditor(
    WidgetTester tester,
    Size size,
    Locale locale,
    GlobalKey boundary, {
    ArchitectFenestrationStyle? style,
    ValueChanged<ArchitectFenestrationStyle?>? result,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final saved =
                      await Navigator.push<ArchitectFenestrationStyle>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RepaintBoundary(
                            key: boundary,
                            child: FenestrationEditorScreen(
                              initialStyle: style ?? doorStyle(),
                            ),
                          ),
                        ),
                      );
                  result?.call(saved);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('exact decimal input, transom, undo, save and reload', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final key = GlobalKey();
    ArchitectFenestrationStyle? saved;
    await openEditor(
      tester,
      const Size(1280, 900),
      const Locale('bg'),
      key,
      result: (s) => saved = s,
    );
    final width = find.descendant(
      of: find.byKey(const ValueKey('fenestration-width')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(width, '97,5');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fenestration-transom')));
    await tester.pumpAndSettle();
    expect(find.text('240 cm'), findsOneWidget);
    final l = AppLocalizations.of(
      tester.element(find.byType(FenestrationEditorScreen)),
    )!;
    await tester.tap(find.byTooltip(l.undoAction));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fenestration-total-height')),
      findsNothing,
    );
    await tester.tap(find.byTooltip(l.architectFenestrationRedo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fenestration-save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.defaultWidth, closeTo(.975, 1e-9));
    expect(saved!.defaultHeight, closeTo(2.4, 1e-9));
    final reloaded = FenestrationLibraryService.forTesting();
    await reloaded.init();
    expect(reloaded.getStyleById(saved!.id)!.transom!.height, .4);
    final placed = ArchitectDoor(
      id: 'd',
      wallId: 'w',
      offsetRatio: .5,
      uuid: 'd',
      width: saved!.defaultWidth,
      height: saved!.defaultHeight,
      style: saved,
    );
    expect(
      ArchitectDoor.fromJson(placed.toJson()).resolvedStyle!.transom!.height,
      .4,
    );
    expect(tester.takeException(), isNull);
    reloaded.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  for (final locale in ['bg', 'en']) {
    for (final size in [const Size(320, 740), const Size(1440, 960)]) {
      testWidgets('editor visual review $locale $size', (tester) async {
        final key = GlobalKey();
        await openEditor(
          tester,
          size,
          Locale(locale),
          key,
          style: doorStyle()
              .withTransom(const FenestrationTransom())
              .copyWith(name: 'D-01 / 100 × 240'),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(FenestrationEditorScreen)),
        )!;
        for (final view in [
          l.architectFenestrationElevationShort,
          l.architectFenestrationPlanShort,
          l.architectFenestration3DShort,
        ]) {
          await tester.tap(find.text(view));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            key,
            'editor_${locale}_${size.width.toInt()}_${view == l.architectFenestrationElevationShort
                ? 'elevation'
                : view == l.architectFenestrationPlanShort
                ? 'plan'
                : '3d'}',
          );
        }
        await tester.tap(find.text(l.architectFenestrationElevationShort));
        await tester.pumpAndSettle();
        await tester.showKeyboard(
          find.descendant(
            of: find.byKey(const ValueKey('fenestration-width')),
            matching: find.byType(TextFormField),
          ),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.binding.setSurfaceSize(null);
      });
    }
  }

  testWidgets('library renders actual elevation, plan and 3D cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await FenestrationLibraryService.instance.saveStyle(doorStyle().withTransom(const FenestrationTransom()));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: const ArchitectComponentLibraryDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(
      find.byType(ArchitectComponentLibraryDialog),
    );
    final l = AppLocalizations.of(context)!;
    await tester.enterText(find.byType(TextField), 'D-01');
    await tester.pumpAndSettle();
    for (final mode in [
      FenestrationPreviewMode.elevation,
      FenestrationPreviewMode.plan,
      FenestrationPreviewMode.threeD,
    ]) {
      final label = mode == FenestrationPreviewMode.elevation
          ? l.architectFenestrationElevationShort
          : mode == FenestrationPreviewMode.plan
          ? l.architectFenestrationPlanShort
          : l.architectFenestration3DShort;
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(FenestrationPreview), findsWidgets);
      expect(
        tester
            .widgetList<FenestrationPreview>(find.byType(FenestrationPreview))
            .every((w) => w.mode == mode),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'library_bg_${mode.name}');
    }
    await tester.binding.setSurfaceSize(null);
  });
}
