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
      await tester.enterText(field('height', 0), '320,5');
      await tester.pump();
      expect(input(tester, 'elevation', 1), '+3.205');
      expect(input(tester, 'elevation', 2), '+6.205');
      await tester.enterText(field('elevation', 1), '3.50');
      await tester.pump();
      expect(input(tester, 'height', 0), '350.0');
      expect(input(tester, 'height', 1), '270.5');
      expect(input(tester, 'elevation', 2), '+6.205');
      await tester.enterText(field('height', 2), 'NaN');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Check the levels and heights.'), findsOneWidget);
      await tester.enterText(field('height', 2), '290');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.units, ArchitectUnit.centimeters);
      expect(result!.distanceDecimals, 1);
      expect(
        result!.storeys.map((s) => s.elevation),
        orderedEquals([0, 3.5, 6.205]),
      );
      expect(result!.storeys[1].height, closeTo(2.705, 1e-9));
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
}
