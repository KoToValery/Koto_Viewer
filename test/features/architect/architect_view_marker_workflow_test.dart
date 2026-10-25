import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elevation_markers.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/widgets/architect_workspace_view_placement.dart';
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_elevation_ui_test.dart' as qa;
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';

Future<void> headerNew(WidgetTester tester, String type) async {
  await tester.tap(find.byKey(ValueKey('architect-view-$type')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is PopupMenuItem<String> && w.value == 'new',
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final type in ['section', 'elevation']) {
    for (final header in [true, false]) {
      for (final side in [1, -1]) {
        testWidgets(
          '$type from ${header ? 'header' : 'Views'} waits for arrow $side and commits once',
          (tester) async {
            final model = workspace.commands();
            addTearDown(model.dispose);
            await workspace.open(tester, model);
            if (header) {
              await headerNew(tester, type);
            } else {
              await tools.choose(
                tester,
                type == 'section'
                    ? Icons.splitscreen_outlined
                    : Icons.apartment,
              );
              await tester.pumpAndSettle();
            }
            expect(
              workspace.overlay(tester).activeTool,
              type == 'section'
                  ? ArchitectTool.section
                  : ArchitectTool.elevation,
            );
            expect(find.byType(ArchitectWorkspaceViewPlacement), findsNothing);
            workspace.camera(tester).fit(const Rect.fromLTRB(-4, -4, 8, 6));
            await tester.pumpAndSettle();
            await workspace.wallTap(tester, const Offset(-1, 0));
            await workspace.wallTap(tester, const Offset(5, 0));
            await tester.pumpAndSettle();
            expect(model.project.sections, isEmpty);
            expect(model.project.elevations, isEmpty);
            expect(model.canUndo, isFalse);
            final positive = find.byKey(
              const ValueKey('architect-view-direction-positive'),
            );
            final negative = find.byKey(
              const ValueKey('architect-view-direction-negative'),
            );
            expect(positive.hitTestable(), findsOneWidget);
            expect(negative.hitTestable(), findsOneWidget);
            // An arbitrary third point no longer picks an implicit depth or side.
            await workspace.wallTap(tester, const Offset(0, 2));
            expect(model.project.sections, isEmpty);
            expect(model.project.elevations, isEmpty);
            await tester.tap(side == 1 ? positive : negative);
            await tester.pumpAndSettle();
            final direction = type == 'section'
                ? model.project.sections.single.viewDirection
                : model.project.elevations.single.viewDirection;
            expect(direction.dx, closeTo(0, 1e-8));
            expect(direction.dy, closeTo(side.toDouble(), 1e-8));
            expect(
              type == 'section'
                  ? model.project.sections.single.viewDepth
                  : model.project.elevations.single.viewDepth,
              isNull,
            );
            expect(
              find.byKey(const ValueKey('architect-view-direction-positive')),
              findsNothing,
            );
            model.undo();
            await tester.pumpAndSettle();
            expect(model.project.sections, isEmpty);
            expect(model.project.elevations, isEmpty);
            model.redo();
            await tester.pumpAndSettle();
            expect(
              type == 'section'
                  ? model.project.sections.length
                  : model.project.elevations.length,
              1,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final locale in ['bg', 'en']) {
    testWidgets(
      'Phone $locale edge placement keeps both arrows reachable; cancellation is clean',
      (tester) async {
        final model = workspace.commands();
        addTearDown(model.dispose);
        await qa.phone(tester);
        tester.view.physicalSize = const Size(320, 740);
        final capture = GlobalKey();
        await tester.pumpWidget(
          qa.host(
            ArchitectWorkspaceScreen(commandController: model),
            locale,
            capture,
          ),
        );
        await tester.pumpAndSettle();
        await headerNew(tester, 'section');
        workspace.camera(tester).fit(const Rect.fromLTRB(-4, -4, 8, 6));
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(-1, -3));
        await workspace.wallTap(tester, const Offset(5, -3));
        await tester.pumpAndSettle();
        for (final side in ['positive', 'negative']) {
          expect(
            find
                .byKey(ValueKey('architect-view-direction-$side'))
                .hitTestable(),
            findsOneWidget,
          );
        }
        await qa.capturePhone(tester, capture, 'marker-direction-$locale');
        await tester.tap(
          find.byKey(const ValueKey('architect-view-direction-cancel')),
        );
        await tester.pumpAndSettle();
        expect(model.project.sections, isEmpty);
        expect(model.canUndo, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'Selected section and facade outlines follow open jogged lines rather than bounding boxes',
    () {
      final model = workspace.commands();
      addTearDown(model.dispose);
      final project = model.project.copyWith(
        sections: [
          const ArchitectSection(
            id: 'cut',
            start: Offset.zero,
            end: Offset(4, 3),
            steps: [Offset(2, 1)],
          ),
        ],
        elevations: [
          const ArchitectElevation(
            id: 'facade',
            start: Offset.zero,
            end: Offset(4, 3),
            steps: [Offset(2, 1)],
          ),
        ],
      );
      for (final id in ['cut', 'facade']) {
        final metrics = ArchitectSelection.outline(
          project,
          id,
        ).computeMetrics().toList();
        expect(metrics, hasLength(1));
        expect(metrics.single.isClosed, isFalse);
        expect(metrics.single.length, closeTo(6, 1e-6));
      }
    },
  );

  test('Ordinary marker selection does not paint a depth box', () async {
    final model = workspace.commands();
    addTearDown(model.dispose);
    final project = model.project.copyWith(
      sections: [
        const ArchitectSection(
          id: 'cut',
          start: Offset.zero,
          end: Offset(4, 0),
          viewDepth: 2,
        ),
      ],
      elevations: [
        const ArchitectElevation(
          id: 'facade',
          start: Offset.zero,
          end: Offset(4, 0),
          viewDepth: 2,
        ),
      ],
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(20, 70)
      ..scale(30);
    drawArchitectElevationMarkers(
      canvas,
      project,
      30,
      Colors.black,
      lookupAppLocalizations(const Locale('en')),
      selectedIds: {'cut', 'facade'},
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(rgba!.getUint8((130 * 200 + 80) * 4 + 3), 0);
    image.dispose();
    picture.dispose();
  });
}
