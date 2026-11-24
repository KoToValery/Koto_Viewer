import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';

Future<void> openProject(
  WidgetTester tester,
  StoreyLevel storey,
  String toolLabel,
  ValueChanged<StructuralProject> onSave,
) async {
  const bounds = Rect.fromLTWH(0, 0, 10000, 10000);
  final document = DxfDocument(
    entities: [],
    layers: {},
    blocks: {},
    headerVars: {},
    bounds: bounds,
    entityStats: {},
  );
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: StructuralDesignerScreen(
        document: document,
        initialProject: StructuralProject(storeys: [storey]),
        bimContext: StructuralBimContext(
          underlaysByStorey: {storey.id: document},
          projectBounds: bounds,
          cadUnitsPerMeter: 1000,
          onProjectChanged: onSave,
          onLayerVisibilityChanged: (_, _) {},
          onWallsDetected: (_) {},
          onExport: (_, _, _) async {},
          onManageStoreys: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final tool = find.text(toolLabel);
  await tester.ensureVisible(tool);
  await tester.tap(tool);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('construction-viewport-input')));
  await tester.pumpAndSettle();
}

Future<void> enterSize(WidgetTester tester, String digits) async {
  for (final digit in digits.characters) {
    await tester.tap(find.byKey(ValueKey('bim-number-key-$digit')));
    await tester.pump();
  }
}

Finder get applySize => find.byKey(const ValueKey('bim-numeric-dialog-apply'));

void main() {
  testWidgets('Selected rotated column edits its displayed width and undoes', (
    tester,
  ) async {
    const column = StructuralColumn(
      id: 'c1',
      name: 'C1',
      center: Offset(5000, 5000),
      width: 250,
      height: 400,
      rotationRad: math.pi / 2,
    );
    final saved = <StructuralProject>[];
    await openProject(
      tester,
      const StoreyLevel(id: 's1', name: 'Ground', columns: [column]),
      'Column',
      saved.add,
    );
    final originalSaveCount = saved.length;
    await tester.tap(find.widgetWithText(TextButton, '40'));
    await tester.pumpAndSettle();
    expect(find.text('Width'), findsOneWidget);
    final input = find.byKey(const ValueKey('bim-numeric-dialog-input'));
    expect(tester.widget<TextField>(input).controller!.text, '40');
    await enterSize(tester, '0');
    expect(tester.widget<FilledButton>(applySize).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saved.length, originalSaveCount);

    await tester.tap(find.widgetWithText(TextButton, '40'));
    await tester.pumpAndSettle();
    await enterSize(tester, '52.5');
    await tester.tap(applySize);
    await tester.pumpAndSettle();
    final updated = saved.last.activeStorey.columns.single;
    expect(updated.height, closeTo(525, 1e-8));
    expect(updated.width, column.width);
    expect(updated.center, column.center);
    expect(updated.rotationRad, column.rotationRad);
    expect(find.widgetWithText(TextButton, '52.5'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(saved.last.activeStorey.columns.single.toJson(), column.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selected L-shaped column edits its actual leg thickness', (
    tester,
  ) async {
    const column = StructuralColumn(
      id: 'c2',
      center: Offset(5000, 5000),
      shape: ColumnShape.lShape,
      width: 600,
      height: 400,
      thickness: 180,
    );
    final saved = <StructuralProject>[];
    await openProject(
      tester,
      const StoreyLevel(id: 's1', name: 'Ground', columns: [column]),
      'Column',
      saved.add,
    );
    await tester.tap(find.widgetWithText(TextButton, '18'));
    await tester.pumpAndSettle();
    await enterSize(tester, '40');
    expect(tester.widget<FilledButton>(applySize).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '18'));
    await tester.pumpAndSettle();
    await enterSize(tester, '22.5');
    await tester.tap(applySize);
    await tester.pumpAndSettle();
    final updated = saved.last.activeStorey.columns.single;
    expect(updated.thickness, closeTo(225, 1e-8));
    expect(updated.width, column.width);
    expect(updated.height, column.height);
  });

  testWidgets(
    'Selected shear wall edits length and thickness on its reference line',
    (tester) async {
      const wall = StructuralShearWall(
        id: 'w1',
        name: 'W1',
        start: Offset(4250, 5000),
        end: Offset(5750, 5000),
        thickness: 230,
        referenceLine: ShearWallReferenceLine.leftFace,
      );
      final saved = <StructuralProject>[];
      await openProject(
        tester,
        const StoreyLevel(id: 's1', name: 'Ground', shearWalls: [wall]),
        'Shear Wall',
        saved.add,
      );
      await tester.tap(find.widgetWithText(TextButton, '150'));
      await tester.pumpAndSettle();
      await enterSize(tester, '180');
      await tester.tap(applySize);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '23'));
      await tester.pumpAndSettle();
      await enterSize(tester, '25.5');
      await tester.tap(applySize);
      await tester.pumpAndSettle();

      final updated = saved.last.activeStorey.shearWalls.single;
      expect(updated.start, wall.start);
      expect(updated.end, const Offset(6050, 5000));
      expect(updated.thickness, closeTo(255, 1e-8));
      expect(updated.referenceLine, wall.referenceLine);
      expect(tester.takeException(), isNull);
    },
  );
}
