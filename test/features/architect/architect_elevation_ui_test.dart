import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_elevations_screen.dart';
import 'architect_elevation_test.dart' as fixture;
import 'architect_workspace_interaction_test.dart' as workspace;

Widget host(Widget child, String locale, GlobalKey capture) => RepaintBoundary(
  key: capture,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: 'TestReadable', useMaterial3: true),
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

Future<void> capturePhone(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  if (!const bool.fromEnvironment('ELEVATION_QA_CAPTURE')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/architect-elevation-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Rect planBounds(ArchitectProject p) {
  final points = [
    for (final s in p.storeys) ...[
      for (final w in s.walls) ...w.polygonCorners,
      for (final slab in s.slabs) ...slab.polygon,
    ],
    for (final e in p.elevations) ...[e.start, e.end],
    if (p.northSymbol != null) p.northSymbol!.position,
  ];
  return (Path()..addPolygon(points, false)).getBounds().inflate(3);
}

Future<void> tapPlan(
  WidgetTester tester,
  ArchitectProject project,
  Offset p,
) async {
  final finder = find.byKey(const ValueKey('architect-facade-plan'));
  final rect = tester.getRect(finder), bounds = planBounds(project);
  final scale =
      math.min(rect.width / bounds.width, rect.height / bounds.height) * .85;
  await tester.tapAt(rect.center + (p - bounds.center) * scale);
  await tester.pumpAndSettle();
}

Future<void> loadQaFonts() async {
  final file = File('C:/Windows/Fonts/arial.ttf');
  if (!Platform.isWindows || !file.existsSync()) return;
  final loader = FontLoader('TestReadable')
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  setUpAll(loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('workspace opens elevations using the shared project', (
    tester,
  ) async {
    final controller = ArchitectCommandController(fixture.elevationProject());
    addTearDown(controller.dispose);
    await workspace.open(tester, controller);
    await tester.tap(find.byKey(const ValueKey('architect-view-elevation')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('architect-building-elevations')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ArchitectElevationsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['bg', 'en']) {
    testWidgets(
      'phone placement snaps parallel, renders facade and rotates north ($locale)',
      (tester) async {
        await phone(tester);
        final controller = ArchitectCommandController(
          fixture.elevationProject(markers: false),
        );
        addTearDown(controller.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          host(ArchitectElevationsScreen(controller: controller), locale, key),
        );
        await tester.pumpAndSettle();
        await tapPlan(tester, controller.project, const Offset(-1, -2));
        await tapPlan(tester, controller.project, const Offset(9, -1.9));
        await tapPlan(tester, controller.project, const Offset(4, 0));
        expect(controller.project.elevations, hasLength(1));
        final facade = controller.project.elevations.single;
        expect(facade.start.dy, closeTo(facade.end.dy, 1e-6));
        expect(facade.compassDirection(0), ArchitectCompassDirection.north);
        expect(
          find.byKey(const ValueKey('architect-facade-drawing')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await capturePhone(tester, key, 'facade-$locale');

        await tester.tap(find.byKey(const ValueKey('architect-north')));
        await tester.pumpAndSettle();
        await tapPlan(tester, controller.project, const Offset(-2, -2));
        await tapPlan(tester, controller.project, const Offset(-2, -4));
        expect(controller.project.northSymbol!.angle, closeTo(0, 1e-6));
        await capturePhone(tester, key, 'plan-$locale');
        final buildingBefore = controller.project.storeys;
        await tester.tap(find.byKey(const ValueKey('architect-north')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('architect-north-angle')),
          '90',
        );
        await tester.pumpAndSettle();
        await capturePhone(tester, key, 'north-$locale');
        await tester.tap(find.byKey(const ValueKey('architect-north-save')));
        await tester.pumpAndSettle();
        expect(
          controller.project.northSymbol!.angle,
          closeTo(math.pi / 2, 1e-6),
        );
        expect(
          controller.project.elevations.single.compassDirection(
            controller.project.northSymbol!.angle,
          ),
          ArchitectCompassDirection.west,
        );
        expect(controller.project.storeys, buildingBefore);
        expect(
          find.textContaining(locale == 'bg' ? 'Запад' : 'West'),
          findsWidgets,
        );
        await tester.tap(find.byKey(const ValueKey('architect-facade-undo')));
        await tester.pumpAndSettle();
        expect(controller.project.northSymbol!.angle, closeTo(0, 1e-6));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'cancel, invalid angle, flip, delete and history stay consistent ($locale)',
      (tester) async {
        await phone(tester);
        final controller = ArchitectCommandController(
          fixture.elevationProject(),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          host(
            ArchitectElevationsScreen(controller: controller),
            locale,
            GlobalKey(),
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectElevationsScreen)),
        )!;
        await tester.tap(find.byKey(const ValueKey('architect-north')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('architect-north-angle')),
          'NaN',
        );
        await tester.tap(find.byKey(const ValueKey('architect-north-save')));
        await tester.pumpAndSettle();
        expect(find.text(l.architectNorthInvalidAngle), findsOneWidget);
        await tester.tap(find.text(l.cancel));
        await tester.pumpAndSettle();
        expect(controller.canUndo, isFalse);
        await tester.tap(find.byKey(const ValueKey('architect-facade-new')));
        await tester.pumpAndSettle();
        await tapPlan(tester, controller.project, const Offset(-1, -2));
        await tester.tap(find.text(l.cancel));
        await tester.pumpAndSettle();
        expect(controller.project.elevations, hasLength(1));
        expect(controller.canUndo, isFalse);
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.architectFacadeReverse));
        await tester.pumpAndSettle();
        expect(controller.project.elevations.single.viewSide, -1);
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.delete));
        await tester.pumpAndSettle();
        expect(controller.project.elevations, isEmpty);
        await tester.tap(find.byKey(const ValueKey('architect-facade-undo')));
        await tester.pumpAndSettle();
        expect(controller.project.elevations.single.viewSide, -1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
