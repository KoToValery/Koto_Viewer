import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_editing/operations/bim_axis_operations.dart';
import 'package:kotoview/src/features/architect/widgets/architect_grid_axis_offset_dialog.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/widgets/element_palette_bar.dart';

void main() {
  test(
    'oblique/reversed axis offset follows canvas side and preserves metadata',
    () {
      const axis = StructuralGridAxis(
        id: 'a',
        name: 'A',
        start: Offset(1, 2),
        end: Offset(5, 5),
        bubbleAtStart: false,
        sourceStoreyIds: ['f'],
      );
      final reverse = axis.copyWith(start: axis.end, end: axis.start);
      for (final original in [axis, reverse]) {
        for (final side in [const Offset(0, 8), const Offset(8, 0)]) {
          final sign = BimAxisOperations.offsetSign(original, side);
          final copy = BimAxisOperations.offset(original, 2, sign);
          final delta = copy.start - original.start;
          expect(delta.distance, closeTo(2, 1e-9));
          expect(
            BimAxisOperations.dot(delta, original.direction),
            closeTo(0, 1e-9),
          );
          expect(
            BimAxisOperations.dot(
              delta,
              side - (original.start + original.end) / 2,
            ),
            greaterThan(0),
          );
          expect(copy.sourceStoreyIds, ['f']);
          expect(copy.bubbleAtStart, isFalse);
        }
      }
      expect(
        () => BimAxisOperations.offset(axis, double.nan, 1),
        throwsArgumentError,
      );
    },
  );

  test(
    'shared endpoint edit bounds minimum length and aligns reverse extents',
    () {
      const axis = StructuralGridAxis(
        id: 'a',
        name: 'A',
        start: Offset.zero,
        end: Offset(6, 0),
      );
      final reverse = axis.copyWith(
        id: 'b',
        start: const Offset(6, 2),
        end: const Offset(0, 2),
      );
      final resized = BimAxisOperations.handlePreview(
        original: axis,
        startHandle: true,
        point: const Offset(9, 0),
        axes: [axis, reverse],
        captureRadius: .2,
      );
      expect(resized.length, closeTo(.3, 1e-9));
      final aligned = BimAxisOperations.alignParallel([axis, reverse], resized);
      expect(aligned.last.end.dx, resized.start.dx);
      expect(aligned.last.start, reverse.start);
    },
  );

  testWidgets(
    'Architect offset uses the shared blank compact dialog and canvas direction',
    (tester) async {
      double? metres;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showArchitectGridAxisOffsetDialog(
                  context: context,
                  unitToMeters: .01,
                  unitSymbol: 'cm',
                  onStartDragMode: (v) => metres = v,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      final field = find.byKey(const ValueKey('architect-offset-distance'));
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).title,
        isNull,
      );
      await tester.enterText(field, '125,5');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Offset'));
      await tester.pumpAndSettle();
      expect(metres, closeTo(1.255, 1e-12));
    },
  );

  for (final units in [1.0, 1000.0]) {
    testWidgets(
      'Construction axis preview/cancel/single commit in CAD $units',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final doc = DxfDocument(
          layers: {},
          blocks: {},
          entities: [],
          headerVars: {},
          entityStats: {},
          bounds: Rect.fromLTWH(0, 0, 10 * units, 10 * units),
        );
        final axis = StructuralGridAxis(
          id: 'a',
          name: 'A',
          start: Offset(2 * units, 5 * units),
          end: Offset(8 * units, 5 * units),
          bubbleAtStart: false,
          sourceStoreyIds: const ['f'],
        );
        final original = StructuralProject(
          gridAxes: [axis],
          storeys: [
            StoreyLevel(id: 'f', name: 'Floor', gridAxes: [axis]),
          ],
        );
        final changes = <StructuralProject>[];
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StructuralDesignerScreen(
              document: doc,
              initialProject: original,
              bimContext: StructuralBimContext(
                underlaysByStorey: {'f': doc},
                projectBounds: doc.bounds,
                cadUnitsPerMeter: units,
                onProjectChanged: changes.add,
                onLayerVisibilityChanged: (_, _) {},
                onWallsDetected: (_) {},
                onExport: (_, _, _) async {},
                onManageStoreys: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester
            .widget<ElementPaletteBar>(find.byType(ElementPaletteBar))
            .onSelectTool(StructuralDrawTool.select);
        await tester.pumpAndSettle();
        final paint = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is Structural2dPainter,
        );
        Structural2dPainter plan() =>
            tester.widget<CustomPaint>(paint).painter as Structural2dPainter;
        Offset point(Offset cad) => tester
            .renderObject<RenderBox>(paint)
            .localToGlobal(plan().cadToScene(cad));
        final baseline = changes.length;
        final cancelled = await tester.startGesture(
          point(axis.start),
          kind: PointerDeviceKind.mouse,
          pointer: 91,
        );
        await cancelled.moveTo(point(Offset(units, 5 * units)));
        await tester.pump();
        expect(changes.length, baseline);
        expect(
          plan().currentStorey.gridAxes.single.start.dx,
          closeTo(units, 1e-6),
        );
        await cancelled.cancel();
        await tester.pumpAndSettle();
        expect(plan().currentStorey.gridAxes.single.start, axis.start);
        expect(changes.length, baseline);
        final drag = await tester.startGesture(
          point(axis.start),
          kind: PointerDeviceKind.mouse,
        );
        await drag.moveTo(point(Offset(units, 5 * units)));
        await tester.pump();
        await drag.up();
        await tester.pumpAndSettle();
        expect(changes.length, baseline + 1);
        expect(
          changes.last.effectiveGridAxes.single.start.dx,
          closeTo(units, 1e-6),
        );
        expect(changes.last.effectiveGridAxes.single.sourceStoreyIds, ['f']);
        expect(changes.last.effectiveGridAxes.single.bubbleAtStart, isFalse);
        await tester.tap(find.byIcon(Icons.undo_rounded).first);
        await tester.pumpAndSettle();
        expect(plan().currentStorey.gridAxes.single.start, axis.start);
        final beforeMove = changes.length;
        final body = await tester.startGesture(
          point(Offset(5 * units, 5 * units)),
          kind: PointerDeviceKind.mouse,
        );
        await body.moveTo(point(Offset(5 * units, 6 * units)));
        await tester.pump();
        expect(changes.length, beforeMove);
        await body.up();
        await tester.pumpAndSettle();
        expect(changes.length, beforeMove + 1);
        expect(
          changes.last.effectiveGridAxes.single.start.dy,
          closeTo(6 * units, 1e-6),
        );
        expect(
          changes.last.effectiveGridAxes.single.length,
          closeTo(axis.length, 1e-6),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
