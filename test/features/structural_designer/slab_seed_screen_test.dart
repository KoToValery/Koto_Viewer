import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/services/structural_persistence_service.dart';
import 'slab_corner_and_projection_test.dart' show document, rectangle;

void main() {
  testWidgets(
    'standalone drawing exposes menu and slab button and generates without metadata',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = document(
        rectangle().selectedWallPairs
            .expand(
              (p) => [
                DxfLine(
                  p1: p.segmentA.start,
                  p2: p.segmentA.end,
                  layer: 'walls',
                ),
                DxfLine(
                  p1: p.segmentB.start,
                  p2: p.segmentB.end,
                  layer: 'walls',
                ),
              ],
            )
            .toList(),
      );
      doc.headerVars[r'$INSUNITS'] = '4';
      doc.layers['walls'] = DxfLayer(name: 'walls');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: StructuralDesignerScreen(
            document: doc,
            title: 'slab_menu_test',
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Close the existing standalone wall-detection suggestion.
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Generate initial slabs'), findsOneWidget);
      await tester.tap(find.text('Generate initial slabs'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final saved = await StructuralPersistenceService.loadProject(
        documentKey: 'slab_menu_test',
      );
      expect(saved!.activeStorey.slabs, hasLength(1));
      await tester.tap(find.text('Slab'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(ActionChip, 'Generate initial slabs');
      expect(button, findsOneWidget);
      expect(button.hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'explicit generation saves, repeat preserves edits, undo saves removal',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = document([]);
      doc.headerVars[BimUnderlayMetadata.key] = jsonEncode({
        'version': 1,
        'complete': true,
        'layers': [],
        'slabEnvelope': {
          'contours': [
            [
              [0, 0],
              [5000, 0],
              [5000, 4000],
              [0, 4000],
            ],
          ],
        },
      });
      const initial = StructuralProject(
        storeys: [StoreyLevel(id: 's', name: 'Ground')],
      );
      final saved = <StructuralProject>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: StructuralDesignerScreen(
            document: doc,
            initialProject: initial,
            bimContext: StructuralBimContext(
              underlaysByStorey: {'s': doc},
              projectBounds: doc.bounds,
              cadUnitsPerMeter: 1000,
              onProjectChanged: saved.add,
              onLayerVisibilityChanged: (_, _) {},
              onWallsDetected: (_) {},
              onManageStoreys: () {},
              onExport: (_, _, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      Future<void> command() async {
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Generate initial slabs'));
        await tester.pumpAndSettle();
      }

      await command();
      expect(saved, isEmpty);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(saved.last.activeStorey.slabs.length, 1);
      final saves = saved.length;
      await command();
      expect(saved.length, saves);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.byIcon(Icons.undo_rounded).first);
      await tester.pumpAndSettle();
      expect(saved.last.activeStorey.slabs, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
