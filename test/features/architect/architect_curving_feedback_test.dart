import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/widgets/architect_canvas_hint.dart';
import 'package:kotoview/src/features/architect/widgets/architect_curving_edge_overlay.dart';
import 'architect_arc_dimension_ui_test.dart' as arc_ui;
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
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
  for (final language in ['bg', 'en']) {
    for (final width in [320.0, 390.0]) {
      for (final pending in [false, true]) {
        testWidgets(
          'One compact hint avoids curve, grip and neighbor: $language $width pending=$pending',
          (tester) async {
            tester.view.physicalSize = Size(width, 700);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var applied = 0, cancelled = 0;
            final neighbor = Rect.fromLTWH(16, 150, width - 32, 100);
            final curve = [
              const Offset(24, 420),
              const Offset(70, 340),
              const Offset(180, 280),
              Offset(width - 24, 360),
            ];
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Stack(
                      children: [
                        ArchitectCurvingEdgeOverlay(
                          p1: curve.first,
                          p2: curve.last,
                          chordMid: const Offset(160, 390),
                          handlePos: const Offset(180, 280),
                          gripPos: const Offset(180, 232),
                          isCurved: true,
                          curvePoints: curve,
                          distanceText: '158.4 cm',
                          snapLabel: AppLocalizations.of(context)!.snapMidpoint,
                          pendingConfirmation: pending,
                          intersectsDrawing: (r) => r.overlaps(neighbor),
                          onConfirm: () => applied++,
                          onCancel: () => cancelled++,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final hint = tester.widget<ArchitectCanvasHint>(
              find.byType(ArchitectCanvasHint),
            );
            final localized = AppLocalizations.of(
              tester.element(find.byType(ArchitectCanvasHint)),
            )!;
            expect(hint.message, 'h=158.4 cm · ${localized.snapMidpoint}');
            final rect = tester.getRect(
              find.byKey(const ValueKey('architect-curving-feedback')),
            );
            expect(rect.left, greaterThanOrEqualTo(8));
            expect(rect.right, lessThanOrEqualTo(width - 8));
            expect(rect.top, greaterThanOrEqualTo(80));
            expect(rect.bottom, lessThanOrEqualTo(600));
            expect(rect.overlaps(neighbor), isFalse);
            expect(
              rect.overlaps(
                Rect.fromCircle(center: const Offset(180, 232), radius: 24),
              ),
              isFalse,
            );
            for (var i = 1; i < curve.length; i++) {
              expect(
                rect.overlaps(
                  Rect.fromPoints(curve[i - 1], curve[i]).inflate(12),
                ),
                isFalse,
              );
            }
            if (pending) {
              await tester.tap(
                find.byKey(const ValueKey('architect-command-apply')),
              );
              await tester.tap(
                find.byKey(const ValueKey('architect-command-cancel')),
              );
              expect(applied, 1);
              expect(cancelled, 1);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'Workspace curving localizes one midpoint hint and cancellation preserves geometry ($language)',
      (tester) async {
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: '',
            walls: [
              editing.wall('edit', const Offset(-2, 0), const Offset(2, 0)),
              editing.wall(
                'target',
                const Offset(-2, 1.5),
                const Offset(2, 1.5),
              ),
            ],
          ),
        );
        addTearDown(model.dispose);
        await arc_ui.open(tester, model, language, const Size(390, 844));
        await tester.tapAt(workspace.screen(tester, Offset.zero));
        await tester.pumpAndSettle();
        await tools.selectionAction(tester, 'wall-curve');
        final overlay = tester.widget<ArchitectCurvingEdgeOverlay>(
          find.byType(ArchitectCurvingEdgeOverlay),
        );
        final original = model.project.toJson();
        final origin = tester.getTopLeft(
          find.byKey(const ValueKey('architect-viewport-input')),
        );
        final drag = await tester.startGesture(origin + overlay.gripPos);
        final offset = overlay.gripPos - overlay.handlePos;
        await drag.moveTo(
          workspace.screen(tester, const Offset(0, 1.5)) + offset,
        );
        await tester.pump();
        await drag.up();
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectCurvingEdgeOverlay)),
        )!;
        expect(find.textContaining(l.snapMidpoint), findsOneWidget);
        expect(find.textContaining('Midpoint alignment'), findsNothing);
        expect(find.text(l.architectLineCurved), findsNothing);
        expect(model.project.toJson(), original);
        await arc_ui.screenshot(tester, 'curving_feedback_$language');
        await arc_ui.button(tester, 'architect-command-cancel');
        expect(model.project.toJson(), original);
        expect(model.canUndo, isFalse);
        expect(find.byType(ArchitectCurvingEdgeOverlay), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
