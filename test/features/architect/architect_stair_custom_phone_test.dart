import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_draft_overlay.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_stair_custom_test.dart' as custom;

void main() {
  for (final language in ['en', 'bg']) {
    testWidgets('free stair editor stays usable on a phone in $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['UPDATE_CUSTOM_STAIR_PREVIEW'] == 'true') {
        await tester.runAsync(() async {
          for (final family in ['Roboto', 'ArchitectNoto']) {
            await (FontLoader(family)..addFont(
                  rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
                ))
                .load();
          }
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      final model = workspace.commands();
      addTearDown(model.dispose);
      const capture = ValueKey('custom-stair-phone-capture');
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
      await tools.choose(tester, Icons.stairs_rounded);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('stair-tool-freeform')),
      );
      await tester.tap(find.byKey(const ValueKey('stair-tool-freeform')));
      await tester.pumpAndSettle();
      var overlay = tester.widget<ArchitectStairDraftOverlay>(
        find.byType(ArchitectStairDraftOverlay),
      );
      final draft = overlay.draft;
      final source = custom.customStair();
      // Draw a compact three-flight stair and a trapezoidal cell.
      draft.replaceDesign(source.design!);
      draft.pick(const Offset(0, 0));
      draft.pick(const Offset(1.2, 0));
      draft.beginFlight();
      draft.pick(const Offset(1.8, -.6));
      draft.pick(const Offset(1.8, -2.1));
      draft.beginFlight();
      draft.pick(const Offset(1.2, -2.7));
      draft.pick(const Offset(-.6, -2.7));
      draft.beginPolygon(cell: true);
      for (final p in const [
        Offset(-1, -3.7),
        Offset(2.8, -3.5),
        Offset(2.9, 1),
        Offset(-1, 1.1),
      ]) {
        draft.pick(p);
      }
      draft.finishPolygon();
      draft.select(draft.layout.flights.last.id);
      workspace
          .camera(tester)
          .fit(const Rect.fromLTRB(-1.5, -5, 3.5, 2.5), padding: 24);
      await tester.pumpAndSettle();
      final viewportRect = tester.getRect(
        find.byKey(const ValueKey('architect-viewport-input')),
      );
      final panStart = viewportRect.center + const Offset(0, 100);
      final pan = await tester.startGesture(panStart);
      await pan.moveBy(const Offset(35, 20));
      await tester.pump();
      await pan.up();
      await tester.pump();
      expect(draft.layout.flights, hasLength(3));
      final a = await tester.startGesture(
        panStart - const Offset(35, 0),
        pointer: 301,
      );
      final b = await tester.startGesture(
        panStart + const Offset(35, 0),
        pointer: 302,
      );
      await a.moveBy(const Offset(-15, 0));
      await b.moveBy(const Offset(15, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(draft.layout.flights, hasLength(3));
      expect(find.byType(ArchitectToolPalette).hitTestable(), findsNothing);
      final apply = find.byKey(const ValueKey('stair-draft-apply'));
      await tester.ensureVisible(apply);
      expect(tester.widget<IconButton>(apply).onPressed, isNotNull);
      expect(viewportRect.overlaps(tester.getRect(apply)), isTrue);
      if (Platform.environment['UPDATE_CUSTOM_STAIR_PREVIEW'] == 'true') {
        workspace
            .camera(tester)
            .fit(const Rect.fromLTRB(-1.5, -5, 3.5, 2.5), padding: 24);
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'scratch/custom_stair_phone_$language.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(
        find.byKey(const ValueKey('stair-draft-part-properties')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stair-part-width')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('stair-part-width')),
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('stair-part-width')),
          matching: find.byType(TextFormField),
        ),
        '1.1',
      );
      await tester.pumpAndSettle();
      expect(draft.layout.flights.last.width, 1.1);
      final l = await AppLocalizations.delegate.load(Locale(language));
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('stair-draft-cancel')),
      );
      await tester.tap(find.byKey(const ValueKey('stair-draft-cancel')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.stairs, isEmpty);
      expect(find.byType(ArchitectStairDraftOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
