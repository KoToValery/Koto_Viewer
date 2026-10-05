import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/bim_projects/widgets/bim_elevation_dialog.dart';
import 'package:kotoview/src/features/bim_projects/widgets/bim_new_project_wizard.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/services/structural_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Elevations accept decimal comma and signs and reject invalid input',
    () {
      for (final entry in {
        ' -3,20 ': -3.2,
        '+2.85': 2.85,
        '±0.00': 0.0,
        '-0.001': 0.0,
        '2.856': 2.86,
      }.entries) {
        expect(BimStoreyUnderlay.parseElevation(entry.key), entry.value);
      }
      for (final invalid in [
        '',
        'NaN',
        'Infinity',
        '1e309',
        '±2.80',
        '2,3.4',
      ]) {
        expect(BimStoreyUnderlay.parseElevation(invalid), isNull);
      }
      expect(BimStoreyUnderlay.formatElevation(-0.001), '±0.00');
    },
  );

  test('Sorting preserves storey IDs, attachments and original order', () {
    final project = BimWorkProject(
      id: 'p',
      name: 'P',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      storeys: const [
        BimStoreyUnderlay(
          storeyId: 'a',
          name: 'A',
          elevation: 3.45,
          underlayFileName: 'underlays/a.dxf',
          controlPoint: Offset(10, 20),
        ),
        BimStoreyUnderlay(storeyId: 'b', name: 'B', elevation: -3.2),
      ],
    );
    final sorted = project.sortedStoreysByElevation;
    expect(sorted.map((s) => s.storeyId), ['b', 'a']);
    expect(sorted.last.underlayFileName, 'underlays/a.dxf');
    expect(sorted.last.controlPoint, const Offset(10, 20));
    expect(project.storeys.first.storeyId, 'a');
  });

  Widget app(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets(
    'Elevation dialog validates duplicates then returns a custom elevation',
    (tester) async {
      double? selected;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () async => selected = await showBimElevationDialog(
                context: context,
                initialElevation: 0,
                occupiedElevations: [2.85],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '2,85');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('A storey already has this elevation.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '-3,20');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(selected, -3.2);
    },
  );

  testWidgets('Wizard retains unique IDs after deleting and adding a storey', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(const BimNewProjectWizard()));
    await tester.pumpAndSettle();
    final oldIds = tester
        .widgetList<Card>(find.byType(Card))
        .map((c) => c.key)
        .toSet();
    await tester.tap(find.byTooltip('Delete Storey').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Storey'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      '-3,20',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(cards.length, 3);
    expect(cards.map((c) => c.key).toSet().length, 3);
    expect(cards.where((c) => !oldIds.contains(c.key)).length, 1);
    await tester.tap(find.text('Sort by elevation'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Card).first,
        matching: find.text('-3.20'),
      ),
      findsOneWidget,
    );
  });

  group('BIM axis export', () {
    late Directory temp;
    setUp(
      () async => temp = await Directory.systemTemp.createTemp('bim_axes_'),
    );
    tearDown(() async => temp.delete(recursive: true));

    const axis = StructuralGridAxis(
      id: 'axis-1',
      name: 'A',
      start: Offset(100, 200),
      end: Offset(120, 200),
      bubbleAtEnd: false,
    );

    test(
      'Static axis snapshot has transformed coordinates, pattern and bubbles',
      () async {
        const storey = StoreyLevel(
          id: 's',
          name: 'S',
          elevation: 0,
          gridAxes: [axis],
        );
        final before = jsonEncode(storey.toJson());
        final file = await StructuralPersistenceService.exportStoreyToDxfFile(
          storey: storey,
          baseName: 'axis',
          outputDirectory: temp,
          cpRef: const Offset(100, 200),
          cpLocal: const Offset(10, 20),
          unitScale: 2,
          cadUnitsPerMeter: 10,
          axisLayerName: 'BIM_Axis',
        );
        final doc = await DxfParser.parseFromFile(file);
        expect(doc.layers.containsKey('BIM_Axis'), isTrue);
        expect(doc.layers.containsKey('S-AXIS'), isFalse);
        final line = doc.entities.whereType<DxfLine>().single;
        expect(line.layer, 'BIM_Axis');
        expect(line.p1, const Offset(10, 20));
        expect(line.p2, const Offset(20, 20));
        expect(line.lineType, 'BIM_AXIS_DASHED');
        expect(doc.lineTypes.containsKey('BIM_AXIS_DASHED'), isTrue);
        expect(doc.entities.whereType<DxfCircle>().single.radius, 2);
        expect(doc.entities.whereType<DxfText>().single.text, 'A');
        expect(jsonEncode(storey.toJson()), before);
      },
    );

    test(
      'BIM export uses current shared axes, including edits and removal',
      () async {
        final project = BimWorkProject(
          id: 'p',
          name: 'P',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          storeys: const [
            BimStoreyUnderlay(storeyId: 's', name: 'S', elevation: 0),
          ],
        );
        const structural = StructuralProject(
          title: 'P',
          gridAxes: [axis],
          storeys: [StoreyLevel(id: 's', name: 'S', elevation: 0)],
        );
        final before = jsonEncode(structural.toJson());
        final file = await BimExportService.exportStoreyDxf(
          project: project,
          structural: structural,
          storeyId: 's',
          outputDirectory: temp,
        );
        var doc = await DxfParser.parseFromFile(file);
        expect(doc.entities.whereType<DxfLine>().single.layer, 'BIM_Axis');
        expect(jsonEncode(structural.toJson()), before);
        final cleared = structural.copyWithGridAxes([]);
        final empty = await BimExportService.exportStoreyDxf(
          project: project,
          structural: cleared,
          storeyId: 's',
          outputDirectory: temp,
        );
        doc = await DxfParser.parseFromFile(empty);
        expect(doc.entities.where((e) => e.layer == 'BIM_Axis'), isEmpty);
      },
    );
  });
}
