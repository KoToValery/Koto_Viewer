import 'package:kotoview/src/features/structural_designer/widgets/element_palette_bar.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'staircase_geometry_detector_test.dart' as geometry;
import 'package:kotoview/src/features/structural_designer/widgets/initial_scheme_dialog.dart';
import 'package:kotoview/src/features/structural_designer/widgets/staircase_setup_dialog.dart';
import 'staircase_automatic_openings_test.dart' as f;

Future<void> pump(
  WidgetTester tester,
  StructuralProject initial,
  void Function(StructuralProject) save, {
  Map<String, DxfDocument>? source,
  String lang = 'en',
  Size viewport = const Size(1000, 900),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final docs = source ?? f.drawings();
  final doc = DxfDocument(
    entities: docs['g']!.entities,
    layers: {},
    blocks: {},
    headerVars: {},
    entityStats: {},
    bounds: const Rect.fromLTRB(-2, -2, 8, 8),
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StructuralDesignerScreen(
        document: doc,
        initialProject: initial,
        title: 'Automatic stairs',
        bimContext: StructuralBimContext(
          underlaysByStorey: docs,
          projectBounds: doc.bounds,
          cadUnitsPerMeter: 1,
          onProjectChanged: save,
          onLayerVisibilityChanged: (_, _) {},
          onWallsDetected: (_) {},
          onExport: (_, _, _) async {},
          onManageStoreys: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> generateStairs(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('bim-navigation')));
  await tester.pumpAndSettle();
  tester.widget<ElementPaletteBar>(find.byType(ElementPaletteBar))
      .onSelectTool(StructuralDrawTool.slabOpening);
  await tester.pumpAndSettle();
  final button = find.byKey(const ValueKey('auto-staircase-openings'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'one opening action cuts and saves, repeat does not duplicate, undo restores all levels',
    (tester) async {
      var saved = f.building();
      await pump(tester, saved, (p) => saved = p);
      await generateStairs(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(StaircaseSetupDialog), findsNothing);
      expect(saved.storeys[1].slabs.single.openings, hasLength(1));
      expect(saved.storeys.first.slabs.single.openings, isEmpty);
      expect(saved.storeys.last.slabs.single.openings, isEmpty);
      expect(saved.staircases, isEmpty);
      expect(saved.storeys.every((s) => s.staircaseZones.isEmpty), isTrue);
      await generateStairs(tester);
      expect(saved.storeys[1].slabs.single.openings, hasLength(1));
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.undo_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(saved.storeys[1].slabs.single.openings, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'automatic stairs preserve a manual arrival cut without a setup dialog',
    (tester) async {
      var saved = f.building(manual: true);
      await pump(tester, saved, (p) => saved = p);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await generateStairs(tester);
      expect(find.byType(StaircaseSetupDialog), findsNothing);
      expect(find.byType(InitialSchemeDialog), findsNothing);
      expect(find.text(l.staircaseAutoMissing('+2.80')), findsNothing);
      expect(saved.storeys.first.slabs.single.openings, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'automatic stairs cut the arrival floor without opening a column generator',
    (tester) async {
      var saved = f.building();
      await pump(tester, saved, (p) => saved = p);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await generateStairs(tester);
      expect(find.byType(StaircaseSetupDialog), findsNothing);
      expect(find.text(l.staircaseAutoAdded(1)), findsOneWidget);
      expect(find.text(l.staircaseAutoMissing('±0.00')), findsNothing);
      expect(saved.storeys[1].slabs.single.openings, hasLength(1));
      expect(saved.storeys.first.slabs.single.openings, isEmpty);
      expect(find.byType(InitialSchemeDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'stair preset offers a direct automatic button without a setup dialog',
    (tester) async {
      var saved = f.building();
      await pump(tester, saved, (p) => saved = p);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.ensureVisible(find.text(l.toolOpening));
      await tester.tap(find.text(l.toolOpening));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l.stairsOpeningLabel));
      await tester.tap(find.text(l.stairsOpeningLabel));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('auto-staircase-openings')),
      );
      await tester.tap(find.byKey(const ValueKey('auto-staircase-openings')));
      await tester.pumpAndSettle();
      expect(saved.storeys[1].slabs.single.openings, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'an unresolved automatic cut preserves floors and leaves opening drawing available',
    (tester) async {
      var saved = f.building();
      final docs = f.drawings();
      docs['f'] = geometry.doc(geometry.run());
      await pump(tester, saved, (p) => saved = p, source: docs);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await generateStairs(tester);
      expect(saved.activeStorey.id, 'g');
      expect(
        saved.storeys.every((s) => s.slabs.every((p) => p.openings.isEmpty)),
        isTrue,
      );
      final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is Structural2dPainter,
      );
      expect(
        (tester.widget<CustomPaint>(paint).painter as Structural2dPainter)
            .activeTool,
        StructuralDrawTool.slabOpening,
      );
      expect(find.byType(StaircaseSetupDialog), findsNothing);
      expect(find.text(l.staircaseAutoNotFound), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Bulgarian mobile stair button cuts immediately and fits the dock',
    (tester) async {
      var saved = f.building();
      await pump(
        tester,
        saved,
        (p) => saved = p,
        lang: 'bg',
        viewport: const Size(360, 800),
      );
      final l = await AppLocalizations.delegate.load(const Locale('bg'));
      await tester.ensureVisible(find.text(l.toolOpening));
      await tester.tap(find.text(l.toolOpening));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l.stairsOpeningLabel));
      await tester.tap(find.text(l.stairsOpeningLabel));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('auto-staircase-openings')),
      );
      await tester.tap(find.byKey(const ValueKey('auto-staircase-openings')));
      await tester.pumpAndSettle();
      expect(saved.storeys[1].slabs.single.openings, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
