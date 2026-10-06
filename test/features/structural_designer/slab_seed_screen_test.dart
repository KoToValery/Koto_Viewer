import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'slab_corner_and_projection_test.dart' show document;

void main() {
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
              onLayerVisibilityChanged: (_, __) {},
              onWallsDetected: (_) {},
              onManageStoreys: () {},
              onExport: (_, __, ___) async {},
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
