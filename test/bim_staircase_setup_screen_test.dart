import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/widgets/staircase_setup_dialog.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_inventory.dart';

const plate = [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)];
const zone = [Offset(2, 2), Offset(6, 2), Offset(6, 6), Offset(2, 6)];
const cut = [
  Offset(3, 3),
  Offset(5, 3),
  Offset(5, 4),
  Offset(4, 4),
  Offset(4, 5),
  Offset(3, 5),
];
void main() {
  testWidgets(
    'BIM menu requires scope, ground zone stays solid, arrival polygon cuts only its floor',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final document = DxfDocument(
        entities: [],
        layers: {},
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
        entityStats: {},
      );
      var saved = const StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'g',
            name: 'g',
            slabs: [
              StructuralSlab(id: 'sg', polygon: plate, isFloorSlab: true),
            ],
          ),
          StoreyLevel(
            id: 'f',
            name: 'f',
            elevation: 2.8,
            slabs: [
              StructuralSlab(id: 'sf', polygon: plate, isFloorSlab: true),
              StructuralSlab(id: 'roof', polygon: plate),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: document,
            initialProject: saved,
            initialCadBounds: document.bounds,
            title: 'staircase setup',
            bimContext: StructuralBimContext(
              underlaysByStorey: {'g': document, 'f': document},
              projectBounds: document.bounds,
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
      Finder paint() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is Structural2dPainter,
      );
      Structural2dPainter painter() =>
          tester.widget<CustomPaint>(paint()).painter as Structural2dPainter;
      Offset screen(Offset p) => tester
          .renderObject<RenderBox>(paint())
          .localToGlobal(painter().cadToScene(p));
      Future<void> menu(String title) async {
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title).last);
        await tester.pumpAndSettle();
      }

      Future<void> polygon(List<Offset> points, {bool isZone = false}) async {
        for (final p in points) {
          final gesture = await tester.startGesture(
            screen(p),
            kind: PointerDeviceKind.mouse,
          );
          await gesture.up();
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.text(
            isZone
                ? l.staircaseCloseZone(points.length)
                : l.closeOpening(points.length),
          ),
        );
        await tester.pumpAndSettle();
      }

      await menu(l.schemeGenerate);
      expect(find.byType(StaircaseSetupDialog), findsOneWidget);
      expect(saved.storeys.every((s) => s.columns.isEmpty), isTrue);
      await tester.tap(find.text(l.staircaseAdd));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.staircaseDrawZone).first);
      await tester.pumpAndSettle();
      expect(painter().currentStorey.id, 'g');
      expect(find.text(l.staircaseZoneHint), findsWidgets);
      await polygon(zone, isZone: true);
      expect(saved.staircases, hasLength(1));
      final id = saved.staircases.single.id;
      expect(saved.storeys.first.staircaseZones[id], zone);
      expect(saved.storeys.first.slabs.single.openings, isEmpty);
      await menu(l.staircaseSetupTitle);
      await tester.tap(find.text(l.staircaseDrawOpening));
      await tester.pumpAndSettle();
      expect(painter().currentStorey.id, 'f');
      await polygon(cut);
      expect(saved.storeys.last.slabs.first.openings.single, cut);
      expect(saved.storeys.last.slabs.last.openings, isEmpty);
      expect(saved.storeys.first.slabs.single.openings, isEmpty);
      await menu(l.staircaseSetupTitle);
      await tester.tap(find.text(l.staircaseDrawZone).last);
      await tester.pumpAndSettle();
      await polygon(zone, isZone: true);
      expect(
        StaircaseInventory.evaluate(saved, 1, requireReview: true).ready,
        isTrue,
      );
      expect(saved.storeys.last.slabs.first.openings.single, cut);
      expect(tester.takeException(), isNull);
    },
  );
}
