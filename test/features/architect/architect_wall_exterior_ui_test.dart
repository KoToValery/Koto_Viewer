import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_exterior_resolver.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'architect_wall_exterior_test.dart' as data;
import 'architect_workspace_interaction_test.dart' as workspace;

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
  for (final language in ['bg', 'en']) {
    testWidgets('Phone exterior review and independent overrides ($language)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ArchitectCommandController(
        data.project(data.rectangle().take(3).toList()),
      );
      addTearDown(controller.dispose);
      const capture = ValueKey('exterior-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-1, -1, 8, 6), padding: 20);
      await tester.pumpAndSettle();
      controller.execute(
        CreateArchitectWall(storeyId: 's', wall: data.rectangle().last),
      );
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).wallExteriorReviewIds.length, 4);
      Future<void> captureImage(String suffix) async {
        if (!const bool.fromEnvironment('UPDATE_WALL_EXTERIOR_PREVIEW')) return;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File(
            'scratch/wall_exterior_${suffix}_$language.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }

      await captureImage('plan');
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(ArchitectWorkspaceScreen)),
          builder: (_) => ArchitectElementPropertiesDialog(
            project: controller.project,
            elementIds: const {'0'},
            onApply: (values, texts) {
              controller.execute(
                SetArchitectElementProperties(
                  storeyId: 's',
                  elementIds: const {'0'},
                  values: values,
                  textValues: texts,
                ),
              );
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(ArchitectElementPropertiesDialog)),
      )!;
      final location = find.byKey(
        const ValueKey('architect-property-location'),
      );
      await tester.ensureVisible(location);
      await tester.tap(location);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.wallInterior).last);
      await tester.pumpAndSettle();
      final flip = find.byKey(const ValueKey('architect-property-flipSide'));
      await tester.ensureVisible(flip);
      await tester.tap(flip);
      await tester.pumpAndSettle();
      final side = find.byKey(
        const ValueKey('architect-property-sideMode-manual'),
      );
      expect(side, findsOneWidget);
      await tester.ensureVisible(side);
      await tester.tap(side);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.wallAutomatic).last);
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'bg' ? 'Носеща' : 'Load-bearing'),
        findsNothing,
      );
      await captureImage('properties');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
      await tester.pumpAndSettle();
      final wall = controller.project.activeStorey.walls.first;
      expect(wall.isInterior, isTrue);
      expect(wall.locationMode, WallResolutionMode.manual);
      expect(wall.exteriorSideMode, WallResolutionMode.automatic);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Exterior arrows are confined to the interaction layer', (
    tester,
  ) async {
    final model = data.project(data.rectangle());
    final floor = ArchitectWallExteriorResolver.resolveStorey(
      model.activeStorey,
    );
    final project = model.updateActiveStorey(floor);
    Future<ui.Image> raster(
      ArchitectPaintLayer layer,
      Set<String> review,
    ) async {
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      canvas.translate(35, 35);
      canvas.scale(40);
      Architect2dPainter(
        project: project,
        activeTool: ArchitectTool.pan,
        layer: layer,
        paintGrid: false,
        zoomScale: 40,
        wallExteriorReviewIds: review,
      ).paint(canvas, const Size(320, 240));
      final picture = recorder.endRecording();
      final image = await picture.toImage(320, 240);
      picture.dispose();
      return image;
    }

    Future<List<int>> bytes(ArchitectPaintLayer layer, Set<String> ids) async {
      final image = await raster(layer, ids);
      final data = (await image.toByteData())!.buffer.asUint8List().toList();
      image.dispose();
      return data;
    }

    await tester.runAsync(() async {
      final ids = floor.walls.map((w) => w.id).toSet();
      expect(
        await bytes(ArchitectPaintLayer.model, ids),
        await bytes(ArchitectPaintLayer.model, {}),
      );
      expect(
        await bytes(ArchitectPaintLayer.interaction, ids),
        isNot(await bytes(ArchitectPaintLayer.interaction, {})),
      );
    });
  });
}
