import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/cantilever_analysis_models.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'package:kotoview/src/features/structural_designer/widgets/element_palette_bar.dart';

void main() {
  for (final locale in ['en', 'bg']) {
    testWidgets(
      'grouped dock routes tools and context actions at 360px: $locale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var tool = StructuralDrawTool.column;
        var slabs = 0, stairs = 0, reports = 0, align = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: ElementPaletteBar(
                  activeTool: tool,
                  onSelectTool: (t) => setState(() => tool = t),
                  currentColumnPreset: const StructuralColumn(
                    id: 'preset',
                    center: Offset.zero,
                    width: .25,
                    height: .30,
                  ),
                  onUpdateColumnPreset: (_) {},
                  currentWallThickness: .25,
                  onUpdateWallThickness: (_) {},
                  currentSlabThickness: .20,
                  onUpdateSlabThickness: (_) {},
                  isDrawingSlab: tool == StructuralDrawTool.slab,
                  slabPointCount: 0,
                  onCloseSlab: () {},
                  onUndoPoint: () {},
                  onClearSlab: () {},
                  onRotateColumn: () {},
                  analysisSummary: StructuralAnalysisSummary.empty,
                  onOpenCantileverReport: () => reports++,
                  onOpenVerticalCapacityReport: () => reports++,
                  onOpenSeismicReport: () => reports++,
                  onGenerateSlabs: () => slabs++,
                  onGenerateStaircaseOpenings: () => stairs++,
                  onManageUnderlays: () => align++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = await AppLocalizations.delegate.load(Locale(locale));
        expect(
          find.byKey(const ValueKey('bim-generate-supports')),
          findsNothing,
        );
        expect(find.text(l.axisLockX), findsNothing);
        expect(find.text(l.axisLockY), findsNothing);
        expect(find.text(l.layersTabTitle), findsNothing);
        await tester.tap(find.byKey(const ValueKey('bim-tool-group-underlay')));
        await tester.pumpAndSettle();
        expect(tool, StructuralDrawTool.select);
        expect(find.text(l.toolColumn), findsNothing);
        expect(find.text(l.layersTabTitle), findsOneWidget);
        await tester.tap(find.text(l.toolMeasure));
        await tester.pumpAndSettle();
        expect(tool, StructuralDrawTool.measure);
        await tester.ensureVisible(find.text(l.bimAlignmentTitle));
        await tester.tap(find.text(l.bimAlignmentTitle));
        expect(align, 1);
        await tester.tap(find.byKey(const ValueKey('bim-tool-group-checks')));
        await tester.pumpAndSettle();
        expect(tool, StructuralDrawTool.select);
        expect(
          find.byKey(const ValueKey('bim-generate-supports')),
          findsNothing,
        );
        await tester.tap(find.text(l.bimSupportSpacingAction));
        expect(reports, 1);
        await tester.tap(
          find.byKey(const ValueKey('bim-tool-group-structure')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.toolSlab));
        await tester.tap(find.text(l.toolSlab));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.bimGenerateSlabs));
        await tester.tap(find.text(l.bimGenerateSlabs));
        expect(slabs, 1);
        await tester.ensureVisible(find.text(l.toolOpening));
        await tester.tap(find.text(l.toolOpening));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('auto-staircase-openings')));
        expect(stairs, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
