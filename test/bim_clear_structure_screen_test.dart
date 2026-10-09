import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';

void main() {
  testWidgets(
    'Clear supports removes all floors, preserves slabs/axes, and Undo restores',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = DxfDocument(
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
        entities: [],
        layers: {},
        blocks: {},
        headerVars: {},
        entityStats: {},
      );
      const slab = StructuralSlab(
        id: 'manual-slab',
        polygon: [Offset.zero, Offset(10, 0), Offset(10, 10), Offset(0, 10)],
      );
      const axis = StructuralGridAxis(
        id: 'manual-axis',
        name: 'A',
        start: Offset.zero,
        end: Offset(10, 0),
      );
      final original = StructuralProject(
        title: 'P',
        gridAxes: [axis],
        storeys: [
          for (var i = 0; i < 2; i++)
            StoreyLevel(
              id: 's$i',
              name: 'S$i',
              elevation: i * 2.8,
              slabs: [slab],
              gridAxes: [axis],
              columns: [
                StructuralColumn(id: 'c$i', center: const Offset(2, 2)),
              ],
              shearWalls: [
                StructuralShearWall(
                  id: 'w$i',
                  start: Offset.zero,
                  end: const Offset(0, 3),
                ),
              ],
            ),
        ],
      );
      var saved = original;
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            initialProject: original,
            title: 'P',
            initialCadBounds: doc.bounds,
            bimContext: StructuralBimContext(
              underlaysByStorey: {'s0': doc, 's1': doc},
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
      Future<void> open() async {
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        expect(find.text(l.schemeReadinessTitle), findsNothing);
        await tester.tap(find.text(l.bimClearStructure));
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.text(l.bimClearStructureConfirm(4)), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, l.cancel));
      await tester.pumpAndSettle();
      expect(
        saved.storeys.every(
          (s) => s.columns.length == 1 && s.shearWalls.length == 1,
        ),
        true,
      );
      await open();
      await tester.tap(find.widgetWithText(FilledButton, l.delete));
      await tester.pumpAndSettle();
      expect(
        saved.storeys.every((s) => s.columns.isEmpty && s.shearWalls.isEmpty),
        true,
      );
      expect(saved.storeys.every((s) => s.slabs.single.id == slab.id), true);
      expect(saved.effectiveGridAxes.single.id, axis.id);
      await tester.tap(find.byTooltip(l.undoAction).first);
      await tester.pumpAndSettle();
      expect(
        saved.storeys.every(
          (s) => s.columns.length == 1 && s.shearWalls.length == 1,
        ),
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
