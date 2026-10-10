import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/services/slab_opening_placement.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';

const outer = [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)];
const hole = [
  Offset(2, 2),
  Offset(6, 2),
  Offset(6, 4),
  Offset(4, 4),
  Offset(4, 6),
  Offset(2, 6),
];
void main() {
  test(
    'BIM arrival-floor placement never cuts the ceiling or transfers a ceiling opening',
    () {
      const floor = StructuralSlab(
        id: 'floor',
        polygon: outer,
        isFloorSlab: true,
      );
      const roof = StructuralSlab(id: 'roof', polygon: outer);
      final result = SlabOpeningPlacement.apply(
        slabs: [roof, floor],
        polygon: hole,
        scale: 1,
        type: SlabOpeningType.staircase,
        floorOwnedOnly: true,
      );
      expect(result.accepted, true);
      expect(result.opening, ('floor', 0));
      expect(result.slabs!.first.openings, isEmpty);
      expect(result.slabs!.last.openings.single, hole);
      expect(
        SlabOpeningPlacement.apply(
          slabs: [roof],
          polygon: hole,
          scale: 1,
          type: SlabOpeningType.staircase,
          floorOwnedOnly: true,
        ).issue,
        OpeningPlacementIssue.missingSlab,
      );
      expect(
        SlabOpeningPlacement.apply(
          slabs: [roof.addOpening(hole), floor],
          polygon: hole,
          scale: 1,
          replacing: ('roof', 0),
          floorOwnedOnly: true,
        ).accepted,
        false,
      );
    },
  );
  for (final mode in ['mouse', 'tap', 'hold']) {
    testWidgets(
      'staircase L polygon belongs to arrival floor, preserves ground and roof: $mode',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1100, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final doc = DxfDocument(
          entities: [const DxfLine(p1: Offset(0, 4), p2: Offset(10, 4))],
          layers: {},
          blocks: {},
          headerVars: {},
          bounds: const Rect.fromLTWH(0, 0, 10, 10),
          entityStats: {},
        );
        var saved = const StructuralProject(
          activeStoreyIndex: 1,
          storeys: [
            StoreyLevel(
              id: 'g',
              name: '±0.00',
              elevation: 0,
              slabs: [
                StructuralSlab(id: 'ground', polygon: outer, isFloorSlab: true),
              ],
            ),
            StoreyLevel(
              id: 'f',
              name: '+2.80',
              elevation: 2.8,
              slabs: [
                StructuralSlab(
                  id: 'arrival',
                  polygon: outer,
                  isFloorSlab: true,
                ),
                StructuralSlab(id: 'roof', polygon: outer),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StructuralDesignerScreen(
              document: doc,
              initialProject: saved,
              initialCadBounds: doc.bounds,
              title: 'Staircase',
              bimContext: StructuralBimContext(
                underlaysByStorey: {'g': doc, 'f': doc},
                projectBounds: doc.bounds,
                cadUnitsPerMeter: 1,
                onProjectChanged: (p) => saved = p,
                onLayerVisibilityChanged: (_, _) {},
                onWallsDetected: (_) {},
                onExport: (_, _, _) async {},
                onManageStoreys: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.tap(find.text(l.toolOpening));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.stairsOpeningLabel));
        await tester.pumpAndSettle();
        expect(find.text(l.openingPointByPointPrompt), findsOneWidget);
        Finder paintFinder() => find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is Structural2dPainter,
        );
        Structural2dPainter painter() =>
            tester.widget<CustomPaint>(paintFinder()).painter
                as Structural2dPainter;
        Offset screen(Offset p) => tester
            .renderObject<RenderBox>(paintFinder())
            .localToGlobal(painter().cadToScene(p));
        if (mode == 'mouse') {
          for (final p in [
            const Offset(0, 2),
            const Offset(1, 2),
            const Offset(1, 3),
          ]) {
            final gesture = await tester.startGesture(
              screen(p),
              kind: PointerDeviceKind.mouse,
            );
            await gesture.up();
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text(l.closeOpening(3)));
          await tester.pumpAndSettle();
          expect(
            painter().openingPointsInProgress,
            hasLength(3),
            reason:
                'An invalid cut must leave its draft available for correction.',
          );
          expect(saved.storeys[1].slabs.first.openings, isEmpty);
          await tester.tap(find.byTooltip(l.cancelOpening));
          await tester.pumpAndSettle();
          expect(painter().openingPointsInProgress, isEmpty);
        }
        for (var i = 0; i < hole.length; i++) {
          final gesture = await tester.startGesture(
            screen(i == 2 ? hole[i] + const Offset(.03, -.03) : hole[i]) +
                (mode == 'hold' ? const Offset(0, 64) : Offset.zero),
            kind: mode == 'mouse'
                ? PointerDeviceKind.mouse
                : PointerDeviceKind.touch,
          );
          await tester.pump(
            mode == 'hold'
                ? const Duration(milliseconds: 650)
                : const Duration(milliseconds: 20),
          );
          await gesture.up();
          await tester.pumpAndSettle();
          expect(painter().openingPointsInProgress, hasLength(i + 1));
          expect(saved.storeys[1].slabs.first.openings, isEmpty);
        }
        await tester.tap(find.text(l.closeOpening(hole.length)));
        await tester.pumpAndSettle();
        expect(saved.storeys[1].slabs.first.openings.single, hole);
        expect(
          saved.storeys[1].slabs.first.getOpeningType(0),
          SlabOpeningType.staircase,
        );
        expect(saved.storeys[0].slabs.single.openings, isEmpty);
        expect(saved.storeys[1].slabs.last.openings, isEmpty);
        final below = saved.ceilingSlabStoreyFor(saved.storeys.first)!;
        expect(below.slabs.single.openings.single, hole);
        expect(painter().openingPointsInProgress, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
