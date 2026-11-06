import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'architect_command_confirmation_test.dart' as scene;
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tool_ui;

void main() {
  testWidgets('Visual review of command controls on a Bulgarian phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final captureImages =
        Platform.environment['UPDATE_ARCHITECT_COMMAND_PREVIEW'] == 'true';
    if (captureImages) {
      await tester.runAsync(() async {
        final font = File('C:/Windows/Fonts/arial.ttf');
        if (await font.exists()) {
          await (FontLoader(
            'Roboto',
          )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
    }
    final model = editing.seeded(
      const ArchitectStorey(id: 's', name: '', walls: [scene.interior]),
    );
    addTearDown(model.dispose);
    const capture = ValueKey('command-visual-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: model),
        ),
      ),
    );
    await tester.pumpAndSettle();
    workspace
        .camera(tester)
        .fit(const Rect.fromLTRB(-4, -4, 4, 4), padding: 32);
    await tester.pumpAndSettle();
    await editing.ensureSelectionTool(tester);
    await workspace.wallTap(tester, const Offset(2, -1));
    await tester.pumpAndSettle();
    await tool_ui.selectionAction(tester, 'architect-selection-mirror-copy');
    await tester.tapAt(workspace.screen(tester, Offset.zero));
    await tester.pumpAndSettle();
    Future<void> screenshot(String name) async {
      if (!captureImages) return;
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('scratch/$name.png').writeAsBytes(data.buffer.asUint8List());
        image.dispose();
      });
    }

    await screenshot('command_mirror_aim_bg');
    await tester.tap(
      find.byKey(const ValueKey('architect-mirror-vertical-btn')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('architect-command-apply')),
          )
          .onPressed,
      isNotNull,
    );
    expect(workspace.overlay(tester).project.activeStorey.walls, hasLength(2));
    await screenshot('command_mirror_review_bg');
    expect(model.project.activeStorey.walls, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
