import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/widgets/architect_stair_perimeter_overlay.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_drafting_panel.dart';
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  for (final language in ['en', 'bg']) {
    testWidgets(
      'perimeter stair uses shared length panel and lifted pointer on phone $language',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (Platform.environment['UPDATE_STAIR_PERIMETER_PREVIEW'] == 'true') {
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
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('stair-perimeter-capture'),
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
        final draft = tester
            .widget<ArchitectStairPerimeterOverlay>(
              find.byType(ArchitectStairPerimeterOverlay),
            )
            .draft;
        draft.replaceDesign(
          draft.design.copyWith(code: StairCode.geometryOnly),
        );
        expect(
          find.byKey(const ValueKey('stair-perimeter-part')),
          findsOneWidget,
        );
        await tester.tapAt(workspace.screen(tester, Offset.zero));
        await tester.pump();
        final gesture = await tester.startGesture(
          workspace.screen(tester, const Offset(1, 0)),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.byKey(const ValueKey('architect-offset-pointer')),
          findsOneWidget,
        );
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(draft.reviewing, isTrue);
        expect(find.byKey(const ValueKey('wall-length-input')), findsOneWidget);
        await tester.tapAt(workspace.screen(tester, const Offset(1.4, 0)));
        await tester.pumpAndSettle();
        tester
            .widget<ArchitectWallDraftingPanel>(
              find.byKey(const ValueKey('stair-perimeter-panel')),
            )
            .onLength(1.4);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-continue')));
        await tester.pumpAndSettle();
        expect(draft.segments, hasLength(1));

        await tester.tapAt(workspace.screen(tester, const Offset(2.6, 0)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-continue')));
        await tester.pumpAndSettle();
        await tester.tapAt(workspace.screen(tester, const Offset(2.6, 1.4)));
        await tester.pumpAndSettle();
        tester
            .widget<ArchitectWallDraftingPanel>(
              find.byKey(const ValueKey('stair-perimeter-panel')),
            )
            .onLength(1.4);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-continue')));
        await tester.pumpAndSettle();
        expect(draft.committedPreview!.design!.layout!.flights, hasLength(2));
        if (Platform.environment['UPDATE_STAIR_PERIMETER_PREVIEW'] == 'true') {
          workspace
              .camera(tester)
              .fit(const Rect.fromLTRB(-.5, -2, 4.5, 4), padding: 24);
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('stair-perimeter-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'scratch/stair_perimeter_phone_$language.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        expect(model.project.activeStorey.stairs, isEmpty);
        await tester.tap(find.byKey(const ValueKey('stair-draft-apply')));
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.stairs, hasLength(1));
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.stairs, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
