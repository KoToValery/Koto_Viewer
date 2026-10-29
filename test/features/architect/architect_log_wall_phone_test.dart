import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_elevations_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_3d_viewport.dart';
import 'package:kotoview/src/features/architect/widgets/architect_projection_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_projection_status.dart';
import 'package:kotoview/src/features/cad_3d/cad_3d_controller.dart';
import 'package:kotoview/src/features/cad_3d/widgets/cad_3d_viewport.dart';
import 'architect_log_wall_performance_test.dart' as fixture;
import 'architect_projection_test_helper.dart' as projection;
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_workspace_views_test.dart' as views;

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final language in ['bg', 'en']) {
    testWidgets(
      'attached log section, facade and 3D load on a phone ($language)',
      (tester) async {
        await qa.phone(tester);
        final project = fixture.attachedLogProject().copyWith(
          elevations: const [
            ArchitectElevation(
              id: 'front',
              start: Offset(6.4, 14),
              end: Offset(15.2, 14),
              viewSide: -1,
            ),
          ],
        );
        final commands = ArchitectCommandController(project);
        addTearDown(commands.dispose);
        final capture = GlobalKey();
        Widget host(Widget child) => RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'TestReadable', useMaterial3: true),
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: child,
          ),
        );
        await tester.pumpWidget(
          host(ArchitectBuildingSectionsScreen(controller: commands)),
        );
        await projection.settleProjection(tester, attempts: 750);
        expect(find.byType(ArchitectProjectionStatus), findsNothing);
        expect(find.byType(ArchitectProjectionEditor), findsOneWidget);
        if (const bool.fromEnvironment('LOG_QA_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final path = File(
              'build/log-wall-audit-2026-10-28/section_$language.png',
            );
            await path.parent.create(recursive: true);
            await path.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(
          host(ArchitectElevationsScreen(controller: commands)),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-facade-plan-toggle')),
        );
        await projection.settleProjection(tester, attempts: 750);
        expect(
          find.byKey(const ValueKey('architect-facade-drawing')),
          findsOneWidget,
        );
        expect(find.byType(ArchitectProjectionStatus), findsNothing);
        final camera = Cad3DController();
        addTearDown(camera.dispose);
        await tester.pumpWidget(
          host(Architect3dViewport(project: project, controller: camera)),
        );
        expect(find.byType(ArchitectProjectionStatus), findsOneWidget);
        await projection.settleProjection(tester);
        expect(find.byType(ArchitectProjectionStatus), findsNothing);
        expect(find.byType(Cad3DViewport), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'workspace opens attached log section and retains cached paths during navigation',
    (tester) async {
      final commands = ArchitectCommandController(fixture.attachedLogProject());
      addTearDown(commands.dispose);
      await workspace.open(tester, commands);
      tester.view.physicalSize = const Size(390, 844);
      await views.select(
        tester,
        'section',
        commands.project.sections.single.id,
      );
      expect(find.byType(ArchitectProjectionStatus), findsNothing);
      final editor = tester.widget<ArchitectProjectionEditor>(
        find.byType(ArchitectProjectionEditor),
      );
      expect(editor.paths, isNotEmpty);
      final target = find.byKey(
        const ValueKey('architect-workspace-projection'),
      );
      await tester.dragFrom(
        tester.getRect(target).center,
        const Offset(40, 15),
      );
      await projection.settleProjection(tester);
      expect(
        tester
            .widget<ArchitectProjectionEditor>(
              find.byType(ArchitectProjectionEditor),
            )
            .paths,
        same(editor.paths),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
