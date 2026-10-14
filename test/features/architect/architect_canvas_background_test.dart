import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_underlay_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [390.0, 1200.0]) {
    for (final language in ['bg', 'en']) {
      testWidgets('Canvas switches and persists at $width in $language', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final commands = ArchitectCommandController(
          ArchitectProject(
            id: 'p',
            name: 'Plan',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            activeStoreyId: 's',
            storeys: [ArchitectStorey(id: 's', name: 'Floor')],
          ),
        );
        addTearDown(commands.dispose);
        final app = MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: commands),
        );
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        final initialPainter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<Architect2dPainter>()
            .firstWhere((p) => p.layer == ArchitectPaintLayer.model);
        final project = commands.project;
        final zoom = initialPainter.viewport!.scale;

        Future<void> toggle() async {
          if (width < 600) {
            await tester.tap(find.byKey(const ValueKey('architect-more')));
            await tester.pumpAndSettle();
          }
          final button = find.byKey(
            ValueKey(
              width < 600
                  ? 'architect-canvas-background-menu'
                  : 'architect-canvas-background',
            ),
          );
          final l10n = AppLocalizations.of(tester.element(button))!;
          if (width < 600) {
            expect(find.text(l10n.architectCanvasDark), findsOneWidget);
          } else {
            expect(
              tester.widget<IconButton>(button).tooltip,
              l10n.architectCanvasDark,
            );
          }
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await toggle();
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(const ValueKey('architect-canvas')),
              )
              .color,
          const ArchitectCanvasPalette.dark().background,
        );
        final paints = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter);
        for (final painter in paints.whereType<Architect2dPainter>()) {
          expect(painter.palette.isDark, isTrue);
          expect(painter.viewport!.scale, zoom);
        }
        expect(
          paints.whereType<ArchitectUnderlayPainter>().single.palette.isDark,
          isTrue,
        );
        final newPainter = paints.whereType<Architect2dPainter>().firstWhere(
          (p) => p.layer == ArchitectPaintLayer.model,
        );
        expect(newPainter.shouldRepaint(initialPainter), isTrue);
        expect(commands.project, same(project));
        expect(commands.canUndo, isFalse);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'architect_dark_canvas',
          ),
          isTrue,
        );

        // Reopening restores the choice; a second switch returns to light.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(const ValueKey('architect-canvas')),
              )
              .color,
          const ArchitectCanvasPalette.dark().background,
        );
        if (width < 600) {
          await tester.tap(find.byKey(const ValueKey('architect-more')));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.byKey(
            ValueKey(
              width < 600
                  ? 'architect-canvas-background-menu'
                  : 'architect-canvas-background',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(const ValueKey('architect-canvas')),
              )
              .color,
          const ArchitectCanvasPalette.light().background,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('Black CAD geometry remains visible on the dark canvas', () async {
    final project = ArchitectProject(
      id: 'p',
      name: 'Plan',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      storeys: [
        ArchitectStorey(
          id: 's',
          name: 'Floor',
          cadPrimitives: const [
            ArchitectCadPrimitive(
              id: 'line',
              type: CadPrimitiveType.line,
              startPoint: Offset(1, 2),
              endPoint: Offset(5, 2),
              colorValue: 0xFF000000,
            ),
          ],
        ),
      ],
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const palette = ArchitectCanvasPalette.dark();
    canvas.drawColor(palette.background, BlendMode.src);
    canvas.scale(40);
    Architect2dPainter(
      project: project,
      palette: palette,
      activeTool: ArchitectTool.select,
      zoomScale: 40,
      paintGrid: false,
    ).paint(canvas, const Size(240, 160));
    final picture = recorder.endRecording();
    final image = await picture.toImage(240, 160);
    final pixels = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    // Anti-aliased one-pixel line straddles rows 79 and 80.
    expect(pixels.getUint8((80 * 240 + 120) * 4), greaterThan(90));
    expect(project.activeStorey.cadPrimitives.single.colorValue, 0xFF000000);
    image.dispose();
    picture.dispose();
  });
}
