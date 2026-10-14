import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_drag_session.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_editing_viewport.dart';
import 'package:kotoview/src/features/architect/adapters/architect_element_adapters.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart'
    as a;
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/structural_designer/adapters/structural_element_adapters.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart'
    as s;

void main() {
  test(
    'grab offset, baseline preview, zero move and stale context share one contract',
    () {
      final session = BimDragSession(
        context: 1,
        original: const Offset(3, 4),
        anchor: const Offset(3, 4),
        translate: (p, d) => p + d,
      );
      session.grabAt(const Offset(3.2, 4.1));
      session.updateTarget(1, session.targetForPointer(const Offset(5.2, 6.1)));
      expect((session.preview - const Offset(5, 6)).distance, lessThan(1e-9));
      session.updateTarget(1, session.targetForPointer(const Offset(3.2, 4.1)));
      expect(session.finish(1), isNull);
      final stale = BimDragSession(
        context: 1,
        original: 0.0,
        anchor: Offset.zero,
        translate: (_, d) => d.dx,
      );
      stale.updateTarget(1, const Offset(2, 0));
      expect(stale.finish(2), isNull);
    },
  );
  test(
    'profile rotation changes pose once and preserves vertical/local dimensions',
    () {
      const architect = a.ArchitectColumn(
        id: 'c',
        position: Offset(2, 2),
        width: .25,
        depth: .5,
        height: 7,
      );
      final rotated = const ArchitectColumnEditingAdapter().rotate(
        architect,
        math.pi / 2,
      );
      expect(rotated.rotationDeg, closeTo(90, 1e-9));
      expect(rotated.width, .25);
      expect(rotated.depth, .5);
      expect(rotated.height, 7);
      const native = s.StructuralColumn(
        id: 'c',
        center: Offset(2, 2),
        width: .25,
        height: .5,
        shape: s.ColumnShape.lShape,
        isMirrored: true,
      );
      final structural = const StructuralColumnEditingAdapter().rotate(
        native,
        math.pi / 2,
      );
      expect(structural.rotationRad, math.pi / 2);
      expect(structural.shape, s.ColumnShape.lShape);
      expect(structural.isMirrored, isTrue);
    },
  );

  for (final beam in [false, true]) {
    testWidgets(
      'Architect Drag+ previews, cancels and commits once for ${beam ? 'beam' : 'column'}',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const anchor = Offset(2, 2);
        final project = ArchitectProject(
          id: 'p',
          name: 'Test',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: 'f',
          storeys: [
            ArchitectStorey(
              id: 'f',
              name: 'Floor',
              columns: beam
                  ? []
                  : const [
                      a.ArchitectColumn(
                        id: 'c',
                        position: anchor,
                        width: .25,
                        depth: .5,
                        height: 7,
                        rotationDeg: 30,
                      ),
                    ],
              beams: beam
                  ? const [
                      ArchitectBeam(
                        id: 'b',
                        startPoint: Offset(1, 2),
                        endPoint: Offset(3, 2),
                        width: .35,
                        depth: .8,
                      ),
                    ]
                  : [],
            ),
          ],
        );
        final commands = ArchitectCommandController(project);
        addTearDown(commands.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: commands),
          ),
        );
        await tester.pumpAndSettle();
        tester
            .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
            .onToolChanged(beam ? ArchitectTool.beam : ArchitectTool.column);
        await tester.pumpAndSettle();
        Architect2dPainter plan() => tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<Architect2dPainter>()
            .firstWhere((p) => p.layer == ArchitectPaintLayer.interaction);
        Offset screen(Offset model) =>
            tester.getTopLeft(
              find.byKey(const ValueKey('architect-viewport-input')),
            ) +
            plan().viewport!.toScreen(model);
        Future<void> begin() async {
          final viewport = tester.widget<BimEditingViewport>(
            find.byType(BimEditingViewport),
          );
          expect(
            viewport.onSelectionHold!(plan().viewport!.toScreen(anchor)),
            isTrue,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Drag+'));
          await tester.pumpAndSettle();
        }

        int count(ArchitectProject p) =>
            beam ? p.activeStorey.beams.length : p.activeStorey.columns.length;
        await begin();
        expect(count(commands.project), 1);
        expect(count(plan().project), 2);
        final draftId = beam
            ? plan().project.activeStorey.beams.last.id
            : plan().project.activeStorey.columns.last.id;
        await tester.tap(find.widgetWithText(TextButton, 'Cancel').first);
        await tester.pumpAndSettle();
        expect(count(commands.project), 1);
        expect(commands.canUndo, isFalse);
        await begin();
        final gesture = await tester.startGesture(
          screen(anchor),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(screen(const Offset(4, 4)));
        await tester.pump();
        expect(count(commands.project), 1);
        final previewId = beam
            ? plan().project.activeStorey.beams.last.id
            : plan().project.activeStorey.columns.last.id;
        expect(previewId, isNot(draftId));
        await gesture.moveTo(screen(const Offset(5, 4)));
        await tester.pump();
        expect(
          beam
              ? plan().project.activeStorey.beams.last.id
              : plan().project.activeStorey.columns.last.id,
          previewId,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(count(commands.project), 2);
        expect(
          beam
              ? commands.project.activeStorey.beams.last.id
              : commands.project.activeStorey.columns.last.id,
          previewId,
        );
        if (beam) {
          expect(
            commands.project.activeStorey.beams.last.startPoint,
            const Offset(4, 4),
          );
          expect(commands.project.activeStorey.beams.last.depth, .8);
        } else {
          expect(
            commands.project.activeStorey.columns.last.position,
            const Offset(5, 4),
          );
          expect(commands.project.activeStorey.columns.last.rotationDeg, 30);
          expect(commands.project.activeStorey.columns.last.height, 7);
        }
        commands.undo();
        expect(count(commands.project), 1);
        expect(commands.canUndo, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
