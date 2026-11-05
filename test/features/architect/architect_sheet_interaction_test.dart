import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_composer.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_layout.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheet_viewport.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheets_screen.dart';
import 'architect_publication_test.dart' as publication;

const _place = ArchitectDrawingPlacement(
  id: 'a',
  drawingId: 'plan:s',
  frame: Rect.fromLTWH(70, 60, 160, 120),
  anchor: Offset(1, 2),
  scale: 100,
  showTitle: false,
  rotation: 37,
);

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    this.places = const [_place],
    this.crop = false,
    this.pending,
    this.selected = 'a',
  });
  final List<ArchitectDrawingPlacement> places;
  final bool crop;
  final ArchitectDrawingPlacement? pending;
  final String? selected;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late var sheet = ArchitectSheet(id: 'sheet', placements: widget.places);
  late var cropping = widget.crop;
  late var pending = widget.pending;
  late var selected = widget.selected;
  final viewport = GlobalKey<ArchitectSheetViewportState>();
  int commits = 0;
  int sceneBuilds = 0, contentBuilds = 0;
  String? opened;
  ArchitectDrawingPlacement get place => sheet.placements.first;
  void change(VoidCallback update) => setState(update);
  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: ArchitectSheetViewport(
        key: viewport,
        sheet: sheet,
        selectedId: selected,
        cropMode: cropping,
        pendingPlacement: pending,
        buildScene: (_) {
          sceneBuilds++;
          return const ArchitectVectorScene([], 100);
        },
        buildContent: (_) {
          contentBuilds++;
          return const ArchitectVectorScene([], 100);
        },
        onSelect: (id) => setState(() => selected = id),
        onMove: (place) => setState(() {
          commits++;
          sheet = sheet.copyWith(
            placements: [
              for (final p in sheet.placements)
                if (p.id == place.id) place else p,
            ],
          );
        }),
        onPlace: (place) => setState(() {
          commits++;
          sheet = sheet.copyWith(placements: [...sheet.placements, place]);
          pending = null;
          selected = place.id;
        }),
        onCrop: (place) => setState(() {
          commits++;
          sheet = sheet.copyWith(placements: [place]);
          cropping = false;
        }),
        onCancelPlacement: () => setState(() => pending = null),
        onCancelCrop: () => setState(() => cropping = false),
        onOpenSource: (id) => opened = id,
      ),
    ),
  );
}

Future<_HarnessState> _pump(
  WidgetTester tester, {
  List<ArchitectDrawingPlacement> places = const [_place],
  bool crop = false,
  ArchitectDrawingPlacement? pending,
  String? selected = 'a',
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    _Harness(
      key: key,
      places: places,
      crop: crop,
      pending: pending,
      selected: selected,
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

Offset _global(WidgetTester tester, Offset paper) =>
    tester.getTopLeft(
      find.byKey(const ValueKey('architect-sheet-viewport-input')),
    ) +
    tester
        .state<ArchitectSheetViewportState>(find.byType(ArchitectSheetViewport))
        .paperToScreen(paper);

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(_global(tester, from));
  await gesture.moveTo(_global(tester, to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pointer previews reuse the sheet and drawing content layers', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _press(tester, 'architect-sheet-snap');
    final gesture = await tester.startGesture(
      _global(tester, _place.frame.center),
    );
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(
        _global(tester, _place.frame.center + Offset(i * 2, i.toDouble())),
      );
      await tester.pump();
    }
    expect(h.sceneBuilds, 2);
    expect(h.contentBuilds, 1);
    expect(h.commits, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(h.commits, 1);
  });
  testWidgets(
    'selected view drags once without changing scale or source anchor',
    (tester) async {
      final h = await _pump(tester);
      await _press(tester, 'architect-sheet-snap');
      await _drag(
        tester,
        _place.frame.center,
        _place.frame.center + const Offset(25, 17),
      );
      expect(h.commits, 1);
      expect(h.place.frame.left, closeTo(95, 1e-8));
      expect(h.place.frame.top, closeTo(77, 1e-8));
      expect(h.place.anchor, _place.anchor);
      expect(h.place.scale, _place.scale);
      expect(h.place.rotation, _place.rotation);
    },
  );

  testWidgets('unselected and locked views cannot accidentally move', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      selected: null,
      places: [_place.copyWith(locked: true)],
    );
    await _drag(
      tester,
      _place.frame.center,
      _place.frame.center + const Offset(25, 17),
    );
    expect(h.commits, 0);
    expect(h.place.frame, _place.frame);
    await tester.tapAt(_global(tester, _place.frame.center));
    await tester.pumpAndSettle();
    expect(h.selected, 'a');
  });

  testWidgets('second finger cancels a drag before camera navigation', (
    tester,
  ) async {
    final h = await _pump(tester);
    final first = await tester.startGesture(
      _global(tester, _place.frame.center),
      pointer: 1,
    );
    await first.moveBy(const Offset(40, 20));
    final second = await tester.startGesture(
      _global(tester, const Offset(300, 180)),
      pointer: 2,
    );
    await first.moveBy(const Offset(15, 5));
    await second.moveBy(const Offset(-15, -5));
    await second.up();
    await first.up();
    await tester.pumpAndSettle();
    expect(h.commits, 0);
    expect(h.place.frame, _place.frame);
  });

  testWidgets('rectangle crop previews and commits once with stable content', (
    tester,
  ) async {
    final h = await _pump(tester, crop: true);
    await _press(tester, 'architect-sheet-snap');
    await _drag(
      tester,
      _place.frame.topLeft,
      _place.frame.topLeft + const Offset(20, 15),
    );
    expect(h.commits, 0);
    await _press(tester, 'architect-sheet-crop-save');
    expect(h.commits, 1);
    expect(h.place.crop, isNull);
    expect(h.place.frame.left, closeTo(90, 1e-8));
    expect(h.place.frame.top, closeTo(75, 1e-8));
    expect(h.place.scale, 100);
    final before = ArchitectSheetGeometry.sourceToPaper(
      _place,
      const Offset(3, 4),
    );
    final after = ArchitectSheetGeometry.sourceToPaper(
      h.place,
      const Offset(3, 4),
    );
    expect((before - after).distance, lessThan(1e-8));
  });

  testWidgets(
    'polygon can add and remove vertices, save, and convert to rectangle',
    (tester) async {
      final h = await _pump(tester, crop: true);
      await _press(tester, 'architect-sheet-snap');
      await _press(tester, 'architect-sheet-crop-polygon');
      await _press(tester, 'architect-sheet-crop-add-point');
      await _drag(tester, const Offset(150, 60), const Offset(150, 90));
      await _press(tester, 'architect-sheet-crop-save');
      expect(h.place.crop, hasLength(5));
      expect(ArchitectSheetGeometry.valid(h.place), isTrue);
      expect(h.commits, 1);
      h.change(() => h.cropping = true);
      await tester.pumpAndSettle();
      await tester.tapAt(_global(tester, const Offset(150, 90)));
      await tester.pumpAndSettle();
      await _press(tester, 'architect-sheet-crop-remove-point');
      await _press(tester, 'architect-sheet-crop-save');
      expect(h.place.crop, hasLength(4));
      h.change(() => h.cropping = true);
      await tester.pumpAndSettle();
      await _press(tester, 'architect-sheet-crop-rectangle');
      await _press(tester, 'architect-sheet-crop-save');
      expect(h.place.crop, isNull);
    },
  );

  testWidgets(
    'invalid crop cannot save and Escape cancels every preview edit',
    (tester) async {
      final h = await _pump(tester, crop: true);
      await _press(tester, 'architect-sheet-snap');
      await _drag(tester, _place.frame.topLeft, const Offset(260, 220));
      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('architect-sheet-crop-save')),
      );
      expect(button.onPressed, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(h.commits, 0);
      expect(h.place.toJson(), _place.toJson());
      expect(h.cropping, isFalse);
    },
  );

  testWidgets(
    'overlap picker selects each placement and double tap opens its source',
    (tester) async {
      final h = await _pump(
        tester,
        selected: null,
        places: [
          _place,
          _place.copyWith(id: 'b', number: '2'),
        ],
      );
      await tester.tapAt(_global(tester, _place.frame.center));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('architect-sheet-candidate-a')),
        findsOneWidget,
      );
      await _press(tester, 'architect-sheet-candidate-b');
      expect(h.selected, 'b');
      h.change(() => h.sheet = h.sheet.copyWith(placements: [h.place]));
      await tester.pumpAndSettle();
      await tester.tapAt(_global(tester, _place.frame.center));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(_global(tester, _place.frame.center));
      await tester.pumpAndSettle();
      expect(h.opened, 'plan:s');
    },
  );

  testWidgets(
    'placement preview commits only after a click and supports Escape',
    (tester) async {
      final h = await _pump(tester, pending: _place.copyWith(id: 'new'));
      expect(h.sheet.placements, hasLength(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(h.pending, isNull);
      expect(h.commits, 0);
      h.change(() => h.pending = _place.copyWith(id: 'new'));
      await tester.pumpAndSettle();
      await _press(tester, 'architect-sheet-snap');
      await tester.tapAt(_global(tester, const Offset(20, 30)));
      await tester.pumpAndSettle();
      expect(h.sheet.placements, hasLength(2));
      expect(h.commits, 1);
      expect(
        (h.sheet.placements.last.frame.topLeft - const Offset(20, 30)).distance,
        lessThan(1e-8),
      );
    },
  );

  testWidgets('off-sheet views remain reachable through camera navigation', (
    tester,
  ) async {
    final outside = _place.copyWith(
      frame: const Rect.fromLTWH(-180, 60, 100, 100),
    );
    final h = await _pump(tester, places: [outside]);
    h.viewport.currentState!.navigation.panBy(const Offset(400, 0));
    await tester.pumpAndSettle();
    await _press(tester, 'architect-sheet-snap');
    await _drag(
      tester,
      outside.frame.center,
      outside.frame.center + const Offset(60, 0),
    );
    expect(h.commits, 1);
    expect(h.place.frame.left, closeTo(-120, 1e-8));
  });

  testWidgets(
    'full sheet allows insertion, arrangement, custom scale, Undo and PDF',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const drawing = ArchitectSavedDrawing(
        id: 'plan:s',
        sourceId: 's',
        kind: ArchitectDrawingKind.plan,
      );
      final controller = ArchitectCommandController(
        publication.fixture().copyWith(
          document: ArchitectDocument(
            drawings: const [drawing],
            sheets: [
              ArchitectSheet(
                id: 'sheet',
                placements: [
                  _place.copyWith(frame: const Rect.fromLTWH(10, 10, 400, 277)),
                ],
              ),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      final l = lookupAppLocalizations(const Locale('en'));
      expect(
        ArchitectSheetLayout.freeAreas(
          controller.project,
          controller.project.document.sheets.single,
          l,
        ),
        isEmpty,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectSheetsScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.architectSheetPlace));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SimpleDialogOption, l.architectSheetPlan),
      );
      await tester.pumpAndSettle();
      expect(
        controller.project.document.sheets.single.placements,
        hasLength(1),
      );
      await tester.tapAt(_global(tester, const Offset(20, 20)));
      await tester.pumpAndSettle();
      expect(
        controller.project.document.sheets.single.placements,
        hasLength(2),
      );
      final before = controller.project.document.sheets.single.placements.last;
      await _press(tester, 'architect-sheet-scale');
      await tester.enterText(
        find.byKey(const ValueKey('architect-sheet-scale-input')),
        '250',
      );
      await tester.tap(find.text(l.architectSheetSave));
      await tester.pumpAndSettle();
      final after = controller.project.document.sheets.single.placements.last;
      expect(after.scale, 250);
      expect(
        after.frame.width,
        closeTo(before.frame.width * before.scale / 250, 1e-8),
      );
      controller.undo();
      await tester.pumpAndSettle();
      expect(
        controller.project.document.sheets.single.placements.last.toJson(),
        before.toJson(),
      );
      // Reduce the original oversized viewport and arrange both freely inserted
      // views before publication. This is the previously blocked user workflow.
      await tester.tapAt(_global(tester, const Offset(40, 40)));
      await tester.pumpAndSettle();
      await _press(tester, 'architect-sheet-candidate-a');
      await _press(tester, 'architect-sheet-scale');
      await tester.enterText(
        find.byKey(const ValueKey('architect-sheet-scale-input')),
        '500',
      );
      await tester.tap(find.text(l.architectSheetSave));
      await tester.pumpAndSettle();
      final second = controller.project.document.sheets.single.placements.last;
      await tester.tapAt(_global(tester, second.frame.center));
      await tester.pumpAndSettle();
      await _press(tester, 'architect-sheet-snap');
      await _drag(
        tester,
        second.frame.center,
        second.frame.center + const Offset(0, 100),
      );
      final arranged = controller.project.document.sheets.single;
      expect(
        ArchitectSheetComposer.issues(controller.project, arranged, l),
        isEmpty,
      );
      final bytes = await ArchitectPdfExport.export(controller.project, [
        arranged,
      ], l);
      expect(bytes.length, greaterThan(1000));
      expect(tester.takeException(), isNull);
    },
  );

  for (final factor in [1.0, 2.5]) {
    testWidgets('live snapping uses screen pixels at zoom $factor', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        places: [
          _place.copyWith(
            showTitle: false,
            frame: const Rect.fromLTWH(70, 60, 100, 80),
          ),
        ],
      );
      final camera = h.viewport.currentState!;
      final focal = camera.paperToScreen(h.place.frame.center);
      camera.navigation.navigate(
        previousFocal: focal,
        focal: focal,
        scaleFactor: factor,
      );
      await tester.pumpAndSettle();
      final tolerance = 6 / camera.pixelsPerMm;
      final start = h.place.frame.center;
      final target = start + Offset(10 + tolerance - h.place.frame.left, 0);
      await _drag(tester, start, target);
      expect(h.place.frame.left, closeTo(10, 1e-8));
    });
  }
}
