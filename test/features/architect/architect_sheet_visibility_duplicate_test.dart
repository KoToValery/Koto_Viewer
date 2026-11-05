import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_layout.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheet_viewport.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheets_screen.dart';

import 'architect_publication_test.dart' as publication;

const _drawing = ArchitectSavedDrawing(
  id: 'plan:s',
  sourceId: 's',
  kind: ArchitectDrawingKind.plan,
  visibility: {'dimensions': false},
);
const _place = ArchitectDrawingPlacement(
  id: 'first',
  drawingId: 'plan:s',
  frame: Rect.fromLTWH(70, 60, 160, 120),
  anchor: Offset(1, 2),
  scale: 100,
  rotation: 37,
  showTitle: false,
);

Future<ArchitectCommandController> _pumpScreen(
  WidgetTester tester,
  List<ArchitectDrawingPlacement> placements,
) async {
  await tester.binding.setSurfaceSize(const Size(1000, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = ArchitectCommandController(
    publication.fixture().copyWith(
      document: ArchitectDocument(
        drawings: const [_drawing],
        sheets: [ArchitectSheet(id: 'sheet', placements: placements)],
      ),
    ),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ArchitectSheetsScreen(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Offset _global(WidgetTester tester, Offset paper) =>
    tester.getTopLeft(
      find.byKey(const ValueKey('architect-sheet-viewport-input')),
    ) +
    tester
        .state<ArchitectSheetViewportState>(find.byType(ArchitectSheetViewport))
        .paperToScreen(paper);

Future<void> _select(WidgetTester tester, Offset paper) async {
  await tester.tapAt(_global(tester, paper));
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(_global(tester, from));
  await gesture.moveTo(_global(tester, to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;
  setUpAll(() async {
    l = lookupAppLocalizations(const Locale('en'));
    await (FontLoader('ArchitectNoto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
  });

  testWidgets(
    'visibility edits only the selected placement and Cancel is inert',
    (tester) async {
      final first = _place.copyWith(
        frame: const Rect.fromLTWH(20, 20, 100, 100),
        visibilityOverrides: const {'axes': false},
      );
      final sibling = _place.copyWith(
        id: 'sibling',
        frame: const Rect.fromLTWH(200, 20, 100, 100),
        visibilityOverrides: const {'zones': false},
      );
      final controller = await _pumpScreen(tester, [first, sibling]);
      final originalDrawing = controller.project.document.drawings.single
          .toJson();
      await _select(tester, first.frame.center);
      await tester.tap(find.byTooltip(l.architectSheetVisibility));
      await tester.pumpAndSettle();
      final dimensions = find.widgetWithText(
        CheckboxListTile,
        l.architectSheetDimensions,
      );
      expect(tester.widget<CheckboxListTile>(dimensions).value, isFalse);
      await tester.tap(dimensions);
      await tester.tap(
        find.widgetWithText(CheckboxListTile, l.architectSheetZones),
      );
      await tester.tap(find.text(l.architectSheetSave));
      await tester.pumpAndSettle();
      final placements = controller.project.document.sheets.single.placements;
      expect(placements.first.visibilityOverrides, {
        'axes': false,
        'dimensions': true,
        'zones': false,
      });
      expect(placements.last.toJson(), sibling.toJson());
      expect(
        controller.project.document.drawings.single.toJson(),
        originalDrawing,
      );
      expect(controller.undoCount, 1);
      final saved = placements.first.toJson();

      await tester.tap(find.byTooltip(l.architectSheetVisibility));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckboxListTile, l.architectSheetAxes),
      );
      await tester.tap(find.text(l.architectSheetCancel));
      await tester.pumpAndSettle();
      expect(
        controller.project.document.sheets.single.placements.first.toJson(),
        saved,
      );
      expect(controller.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duplicate preserves polygon and display settings on a full sheet',
    (tester) async {
      const crop = [
        Offset.zero,
        Offset(400, 0),
        Offset(400, 277),
        Offset(210, 277),
        Offset(210, 220),
        Offset(0, 220),
      ];
      final original = _place.copyWith(
        frame: const Rect.fromLTWH(10, 10, 400, 277),
        crop: crop,
        scale: 75,
        showTitle: true,
        visibilityOverrides: const {
          'axes': false,
          'zones': false,
          'dimensions': true,
        },
      );
      final controller = await _pumpScreen(tester, [original]);
      expect(
        ArchitectSheetLayout.freeAreas(
          controller.project,
          controller.project.document.sheets.single,
          l,
        ),
        isEmpty,
      );
      await _select(tester, const Offset(80, 80));
      await _press(tester, 'architect-sheet-snap');
      await tester.tap(find.byTooltip(l.architectSheetDuplicate));
      await tester.pumpAndSettle();
      expect(
        controller.project.document.sheets.single.placements,
        hasLength(1),
      );
      expect(controller.undoCount, 0);
      await tester.tapAt(_global(tester, const Offset(35, 35)));
      await tester.pumpAndSettle();
      final placements = controller.project.document.sheets.single.placements;
      expect(placements, hasLength(2));
      final duplicate = placements.last;
      expect(duplicate.id, isNot(original.id));
      expect(duplicate.number, '2');
      expect(
        (duplicate.frame.topLeft - const Offset(35, 35)).distance,
        lessThan(1e-8),
      );
      expect(duplicate.frame.width, closeTo(original.frame.width, 1e-8));
      expect(duplicate.frame.height, closeTo(original.frame.height, 1e-8));
      expect(duplicate.crop, original.crop);
      expect(duplicate.visibilityOverrides, original.visibilityOverrides);
      expect(duplicate.scale, original.scale);
      expect(duplicate.rotation, original.rotation);
      expect(duplicate.anchor, original.anchor);
      expect(duplicate.showTitle, original.showTitle);
      expect(placements.first.toJson(), original.toJson());
      expect(controller.undoCount, 1);

      await tester.tap(find.byTooltip(l.architectSheetDuplicate));
      await tester.pumpAndSettle();
      await _press(tester, 'architect-sheet-place-cancel');
      expect(
        controller.project.document.sheets.single.placements,
        hasLength(2),
      );
      expect(controller.undoCount, 1);
      controller.undo();
      await tester.pumpAndSettle();
      expect(
        controller.project.document.sheets.single.placements.single.toJson(),
        original.toJson(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'screen crop commits one Undo and cancelled edits leave no history',
    (tester) async {
      final controller = await _pumpScreen(tester, [_place]);
      await _select(tester, _place.frame.center);
      await _press(tester, 'architect-sheet-snap');
      await _press(tester, 'architect-sheet-crop');
      await _drag(tester, _place.frame.topLeft, const Offset(90, 75));
      await _drag(tester, const Offset(230, 127.5), const Offset(215, 127.5));
      expect(controller.undoCount, 0);
      expect(
        controller.project.document.sheets.single.placements.single.toJson(),
        _place.toJson(),
      );
      await _press(tester, 'architect-sheet-crop-save');
      expect(controller.undoCount, 1);
      final cropped =
          controller.project.document.sheets.single.placements.single;
      expect(cropped.frame.left, closeTo(90, 1e-8));
      expect(cropped.frame.top, closeTo(75, 1e-8));
      expect(cropped.frame.width, closeTo(125, 1e-8));
      expect(cropped.frame.height, closeTo(105, 1e-8));
      expect(
        (ArchitectSheetGeometry.sourceToPaper(cropped, const Offset(3, 4)) -
                ArchitectSheetGeometry.sourceToPaper(
                  _place,
                  const Offset(3, 4),
                ))
            .distance,
        lessThan(1e-8),
      );
      controller.undo();
      await tester.pumpAndSettle();
      expect(
        controller.project.document.sheets.single.placements.single.toJson(),
        _place.toJson(),
      );
      expect(controller.undoCount, 0);
      controller.redo();
      await tester.pumpAndSettle();
      expect(
        controller.project.document.sheets.single.placements.single.toJson(),
        cropped.toJson(),
      );
      await _press(tester, 'architect-sheet-crop');
      await _drag(tester, cropped.frame.topLeft, const Offset(105, 85));
      await _press(tester, 'architect-sheet-crop-cancel');
      expect(
        controller.project.document.sheets.single.placements.single.toJson(),
        cropped.toJson(),
      );
      expect(controller.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
