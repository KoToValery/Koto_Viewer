import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/widgets/architect_project_wizard_dialog.dart';
import 'package:kotoview/src/features/bim_projects/widgets/bim_new_project_wizard.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_distance_drafting_panel.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_shape_dimension_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(
  Widget home, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);
Finder field(String kind, int index) =>
    find.byKey(ValueKey('architect-wizard-$kind-$index'));
String input(WidgetTester tester, String kind, int index) =>
    tester.widget<TextFormField>(field(kind, index)).controller!.text;
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'centimetres by default; axes only; editable linked storeys and persisted precision',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ArchitectProject? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await ArchitectProjectWizardDialog.show(
                    context,
                    initialProjectName: 'Home',
                  ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'cm'))
            .selected,
        isTrue,
      );
      expect(find.textContaining('1.00 m ='), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('architect-wizard-precision-1')),
      );
      await tester.tap(find.byKey(const ValueKey('architect-wizard-step-1')));
      await tester.pumpAndSettle();
      expect(find.text('Storeys & Heights'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byKey(const ValueKey('architect-wizard-step-2')));
      await tester.pumpAndSettle();
      expect(find.text('Wall Types & Balcony Parapet'), findsNothing);
      expect(input(tester, 'elevation', 0), '±0.000');
      expect(input(tester, 'height', 0), '300.0');
      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.byKey(const ValueKey('architect-wizard-add-storey')),
        );
        await tester.pumpAndSettle();
      }
      expect(input(tester, 'height', 1), '290.0');
      expect(input(tester, 'height', 2), '290.0');
      expect(input(tester, 'elevation', 1), '+3.000');
      expect(input(tester, 'elevation', 2), '+5.900');

      // Elevation & height fields are read-only and open programmatic keypad.
      final elevWidget = tester.widget<TextField>(
        find.descendant(of: field('elevation', 1), matching: find.byType(TextField)),
      );
      expect(elevWidget.readOnly, isTrue);

      await tester.tap(field('height', 0));
      await tester.pumpAndSettle();
      for (final key in ['3', '2', '0', '.', '5']) {
        await tester.tap(find.byKey(ValueKey('bim-number-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
      await tester.pumpAndSettle();
      expect(input(tester, 'elevation', 1), '+3.205');
      expect(input(tester, 'elevation', 2), '+6.105');

      await tester.tap(field('elevation', 1));
      await tester.pumpAndSettle();
      for (final key in ['3', '.', '5', '0']) {
        await tester.tap(find.byKey(ValueKey('bim-number-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
      await tester.pumpAndSettle();
      expect(input(tester, 'height', 0), '350.0');
      expect(input(tester, 'height', 1), '260.5');
      expect(input(tester, 'elevation', 2), '+6.105');

      await tester.tap(field('height', 2));
      await tester.pumpAndSettle();
      for (final key in ['2', '9', '5']) {
        await tester.tap(find.byKey(ValueKey('bim-number-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.units, ArchitectUnit.centimeters);
      expect(result!.distanceDecimals, 1);
      expect(
        result!.storeys.map((s) => s.elevation),
        orderedEquals([0, 3.5, 6.105]),
      );
      expect(result!.storeys[1].height, closeTo(2.605, 1e-9));
      expect(result!.storeys[2].height, closeTo(2.95, 1e-9));
      final restored = ArchitectProject.fromJson(result!.toJson());
      expect(restored.distanceDecimals, 1);
      expect(restored.formatLength(1.234), '123.4 cm');
      expect(restored.storeys.every((s) => s.slabs.isEmpty), isTrue);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'Bulgarian phone wizard follows $brightness and starts with one storey',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            const ArchitectProjectWizardDialog(),
            locale: const Locale('bg'),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Единици'), findsOneWidget);
        expect(find.text('Оси'), findsOneWidget);
        expect(find.text('Етажи'), findsOneWidget);
        final context = tester.element(find.byType(Dialog));
        expect(Theme.of(context).brightness, brightness);
        await tester.tap(find.byKey(const ValueKey('architect-wizard-step-2')));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('H= (cm)'), findsOneWidget);
        expect(find.text('готов под → готов под'), findsOneWidget);
        expect(find.text('Височина (cm)'), findsNothing);
        expect(find.text('Добави етаж'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'BIM project type text uses the $brightness surface foreground',
      (tester) async {
        await tester.pumpWidget(
          app(const BimNewProjectWizard(), brightness: brightness),
        );
        await tester.pumpAndSettle();
        final title = find.text('Structural BiM');
        expect(title, findsOneWidget);
        final context = tester.element(title);
        expect(
          tester.widget<Text>(title).style!.color,
          Theme.of(context).colorScheme.onSurface,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final decimals in [0, 1, 2]) {
    testWidgets('draft and shape inputs respect $decimals decimal places', (
      tester,
    ) async {
      var distance = 125.0;
      await tester.pumpWidget(
        app(
          BimDistanceDraftingPanel(
            length: distance,
            unit: 'cm',
            decimals: decimals,
            keypadInitiallyOpen: true,
            onLength: (v) => distance = v,
            onEnd: () {},
            onContinue: () {},
            onUnlock: () {},
            onCancel: () {},
          ),
        ),
      );
      expect(
        find.text('${distance.toStringAsFixed(decimals)} cm'),
        findsOneWidget,
      );
      for (final key in ['1', '.', '2', '3', '4']) {
        await tester.tap(
          find.byKey(ValueKey('wall-key-$key')),
          warnIfMissed: false,
        );
        await tester.pump();
      }
      expect(
        distance,
        decimals == 0
            ? 1234
            : decimals == 1
            ? 1.2
            : 1.23,
      );
      await tester.pumpWidget(
        app(
          BimShapeDimensionPanel(
            values: [125],
            labels: const ['L'],
            unit: 'cm',
            decimals: decimals,
            minimum: 0,
            onChanged: (_, value) => distance = value,
            onSave: () {},
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('${125.toStringAsFixed(decimals)} cm'), findsOneWidget);
      for (final key in ['2', '.', '3', '4', '5']) {
        await tester.tap(
          find.byKey(ValueKey('shape-key-$key')),
          warnIfMissed: false,
        );
        await tester.pump();
      }
      expect(
        distance,
        decimals == 0
            ? 2345
            : decimals == 1
            ? 2.3
            : 2.34,
      );
    });
  }

  test('3D walls never fabricate a peripheral slab', () {
    final base = ArchitectProject.starter(name: 'Home', storeyCount: 1);
    final wall = ArchitectWall(
      id: 'wall',
      startPoint: Offset.zero,
      endPoint: const Offset(4, 0),
      wallTypeId: base.wallTypes.first.id,
      thickness: .25,
      height: 3,
    );
    final project = base.copyWith(
      storeys: [
        base.activeStorey.copyWith(walls: [wall]),
      ],
    );
    final preview = Architect3dBuilder.buildProjectMesh(project);
    final actual = Architect3dBuilder.buildProjectMesh(
      project,
      previewGeometry: false,
    );
    expect(preview.triangles.length, actual.triangles.length);
    expect(preview.triangles.isNotEmpty, isTrue);
    expect(Architect3dBuilder.buildProjectMesh(base).triangles, isEmpty);
  });

  testWidgets('Wizard decimal places defaults to 1 and displays responsive example', (tester) async {
    await tester.pumpWidget(
      app(
        const ArchitectProjectWizardDialog(),
        locale: const Locale('bg'),
      ),
    );
    await tester.pumpAndSettle();

    // Chip 1 is selected by default
    final chip1 = tester.widget<ChoiceChip>(find.byKey(const ValueKey('architect-wizard-precision-1')));
    expect(chip1.selected, isTrue);

    // Example shows 0.0
    final exampleFinder = find.byKey(const ValueKey('architect-wizard-precision-example'));
    expect(exampleFinder, findsOneWidget);
    expect(tester.widget<Text>(exampleFinder).data, '0.0');
    expect(find.text('Пример: '), findsOneWidget);

    // Tap 0
    await tester.tap(find.byKey(const ValueKey('architect-wizard-precision-0')));
    await tester.pump();
    expect(tester.widget<Text>(exampleFinder).data, '0');

    // Tap 2
    await tester.tap(find.byKey(const ValueKey('architect-wizard-precision-2')));
    await tester.pump();
    final exampleText = tester.widget<Text>(exampleFinder);
    expect(exampleText.data, '0.00');
    expect(exampleText.style?.color, Colors.black);
  });

  testWidgets(
    'Grid preset stays selected on bay resize, preview stays compact, custom scheme adds spans, and Create shows loading state',
    (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final completer = Completer<void>();
      ArchitectProject? createdProject;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => ArchitectProjectWizardDialog.show(
                context,
                onCreate: (p, _) async {
                  createdProject = p;
                  await completer.future;
                  return p;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Switch to Axes tab.
      await tester.tap(find.byKey(const ValueKey('architect-wizard-step-1')));
      await tester.pumpAndSettle();

      // Select 4.50 / 4.50 preset (2x2 bays) and check compact preview height.
      await tester.tap(find.widgetWithText(ChoiceChip, '4.50 / 4.50'));
      await tester.pumpAndSettle();
      final previewSize = tester.getSize(
        find.byKey(const ValueKey('architect-grid-preview')),
      );
      expect(previewSize.height, lessThan(200));

      // Change bay count using picker -> preset 4.50 / 4.50 remains selected (not Custom).
      final pickerRect = tester.getRect(
        find.byKey(const ValueKey('architect-grid-picker')),
      );
      await tester.tapAt(
        pickerRect.topLeft + Offset(pickerRect.width * 3.5 / 8, pickerRect.height * 2.5 / 6),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '4.50 / 4.50')).selected,
        isTrue,
      );
      expect(
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Custom')).selected,
        isFalse,
      );

      // Select Custom -> exposes arbitrary X/Y span editor and allows adding a bay.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('architect-grid-custom-editor')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('grid-add-x')));
      await tester.pumpAndSettle();
      for (final d in ['6', '2', '5']) {
        await tester.tap(find.byKey(ValueKey('wall-key-$d')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('grid-custom-x-4')), findsOneWidget);

      // Move to Storeys tab and press Create with async onCreate -> shows loading state instead of wizard steps.
      await tester.tap(find.byKey(const ValueKey('architect-wizard-step-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(createdProject, isNotNull);
      expect(find.byKey(const ValueKey('architect-wizard-creating')), findsOneWidget);
      expect(find.byKey(const ValueKey('architect-wizard-step-2')), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('architect-wizard-creating')), findsNothing);
    },
  );
}
