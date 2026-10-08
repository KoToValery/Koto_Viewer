import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/widgets/initial_scheme_dialog.dart';
import 'initial_scheme_generator_test.dart' as fixtures;

void main() {
  testWidgets(
    'real menu accepts once, Undo restores and cancel leaves model unchanged',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (project, pairs) = fixtures.fixture();
      final document = DxfDocument(
        entities: [
          for (final p in pairs) ...[
            DxfLine(layer: 'walls', p1: p.segmentA.start, p2: p.segmentA.end),
            DxfLine(layer: 'walls', p1: p.segmentB.start, p2: p.segmentB.end),
          ],
        ],
        layers: {'walls': DxfLayer(name: 'walls', isVisible: true)},
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 20, 16),
        entityStats: {'LINE': pairs.length * 2},
      );
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: document,
            initialProject: project,
            title: 'scheme-test',
            initialCadBounds: document.bounds,
          ),
        ),
      );
      await tester.pumpAndSettle();
      StoreyLevel current() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<Structural2dPainter>()
          .first
          .currentStorey;
      final before = current();
      Future<void> open() async {
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.schemeGenerate));
        await tester.pumpAndSettle();
        expect(find.byType(InitialSchemeDialog), findsOneWidget);
      }

      await open();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('accept-scheme')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('accept-scheme')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('accept-scheme')));
      await tester.pumpAndSettle();
      expect(
        current().columns.length + current().shearWalls.length,
        greaterThan(before.columns.length + before.shearWalls.length),
      );
      await tester.tap(find.byTooltip(l.undoAction).first);
      await tester.pumpAndSettle();
      expect(current().toJson(), before.toJson());
      await open();
      await tester.ensureVisible(find.text(l.cancel).last);
      await tester.tap(find.text(l.cancel).last);
      await tester.pumpAndSettle();
      expect(current().toJson(), before.toJson());
      expect(tester.takeException(), isNull);
    },
  );
}
