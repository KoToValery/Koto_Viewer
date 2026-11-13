import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_underlay_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_underlay_presentation.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_underlay_bar.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

const _config = ArchitectCadUnderlayConfig(
  storeyId: 's',
  fileName: 'plan.dxf',
  internalCopyPath: '',
  opacity: .3,
);

DxfDocument _document([
  BimCoordinateFrame frame = const BimCoordinateFrame(),
]) => DxfDocument(
  layers: {
    'source': DxfLayer(name: 'source', trueColor: 0x00ff00, lineweight: .13),
  },
  blocks: {},
  headerVars: {},
  entityStats: {},
  bounds: frame.rectToCad(const Rect.fromLTWH(0, 0, 10, 6)),
  entities: [
    DxfLine(
      layer: 'source',
      p1: frame.toCad(const Offset(1, 1)),
      p2: frame.toCad(const Offset(9, 1)),
    ),
    DxfLine(
      layer: 'source',
      p1: frame.toCad(const Offset(1, 3)),
      p2: frame.toCad(const Offset(9, 3)),
      trueColor: 0xff0000,
      lineWeight: .7,
    ),
  ],
);

ArchitectProject _project() => ArchitectProject(
  id: 'underlay-display',
  name: 'Underlay display',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: const [ArchitectStorey(id: 's', name: 'Floor')],
  cadUnderlays: const {'s': _config},
);

Future<ByteData> _pixels(
  ArchitectCadUnderlayConfig config, {
  BimCoordinateFrame frame = const BimCoordinateFrame(),
  Map<String, bool> visibility = const {},
}) async {
  final viewport = BimViewportController()
    ..resize(const Size(140, 100))
    ..fit(const Rect.fromLTWH(0, 0, 10, 6), padding: 20);
  addTearDown(viewport.dispose);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  ArchitectUnderlayPainter(
    document: _document(frame),
    frame: frame,
    viewport: viewport,
    cadConfig: config,
    visibility: visibility,
  ).paint(canvas, const Size(140, 100));
  final picture = recorder.endRecording();
  final image = await picture.toImage(140, 100);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  picture.dispose();
  return bytes;
}

int _channel(ByteData pixels, int x, int y, int channel) =>
    pixels.getUint8((y * 140 + x) * 4 + channel);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'CAD opacity changes rendered pixels, including with source styles',
    () async {
      for (final original in [false, true]) {
        final dim = await _pixels(
          _config.copyWith(opacity: .15, useOriginalColors: original),
        );
        final strong = await _pixels(
          _config.copyWith(opacity: .9, useOriginalColors: original),
        );
        expect(
          _channel(strong, 70, 50, 1),
          lessThan(_channel(dim, 70, 50, 1) - 30),
        );
      }
    },
  );

  test(
    'original colors and weights resolve entity and ByLayer styles independently',
    () async {
      final doc = _document();
      final style = ArchitectUnderlayPresentation(
        palette: const ArchitectCanvasPalette.light(),
        zoomScale: 10,
        opacity: .8,
        useOriginalColors: true,
        useOriginalLineweights: true,
      );
      final layerPen = style.pen(doc.entities.first, doc.layers['source']);
      final entityPen = style.pen(doc.entities.last, doc.layers['source']);
      expect(layerPen.color.g, 1);
      expect(layerPen.color.r, 0);
      expect(entityPen.color.r, 1);
      expect(entityPen.color.g, 0);
      expect(entityPen.color.a, closeTo(.8, .001));
      expect(entityPen.strokeWidth, closeTo(.7 * 9.5 / 10, 1e-6));
      expect(layerPen.strokeWidth, closeTo(.13 * 9.5 / 10, 1e-6));
      final thin = await _pixels(
        _config.copyWith(opacity: 1, useOriginalColors: true),
      );
      final weighted = await _pixels(
        _config.copyWith(
          opacity: 1,
          useOriginalColors: true,
          useOriginalLineweights: true,
        ),
      );
      expect(_channel(thin, 70, 52, 1), 255);
      expect(_channel(weighted, 70, 52, 1), lessThan(100));
      expect(doc.layers['source']!.lineweight, .13);
      expect(doc.entities.last.lineWeight, .7);
    },
  );

  test('appearance keeps the CAD frame, crop and layer filtering', () async {
    const frame = BimCoordinateFrame(
      origin: Offset(10000, 20000),
      unitsPerMeter: 1000,
    );
    final config = _config.copyWith(
      opacity: 1,
      useOriginalColors: true,
      useOriginalLineweights: true,
      maskPolygon: const [
        Offset(0, 0),
        Offset(5, 0),
        Offset(5, 6),
        Offset(0, 6),
      ],
    );
    final masked = await _pixels(config, frame: frame);
    expect(_channel(masked, 60, 50, 1), lessThan(100));
    expect(_channel(masked, 100, 50, 1), 255);
    final hidden = await _pixels(
      config,
      frame: frame,
      visibility: {'source': false},
    );
    expect(_channel(hidden, 60, 50, 1), 255);
  });

  test('legacy defaults and source style settings survive serialization', () {
    final legacy = ArchitectCadUnderlayConfig.fromJson({
      'storeyId': 's',
      'fileName': 'old.dxf',
      'internalCopyPath': '',
    });
    expect(legacy.useOriginalColors, isFalse);
    expect(legacy.useOriginalLineweights, isFalse);
    final edited = _config.copyWith(
      useOriginalColors: true,
      useOriginalLineweights: true,
    );
    final restored = ArchitectCadUnderlayConfig.fromJson(
      jsonDecode(jsonEncode(edited.toJson())),
    );
    expect(restored.toJson(), edited.toJson());
    expect(restored.copyWith(opacity: .8).useOriginalColors, isTrue);
    expect(
      restored.copyWith(useOriginalColors: false).useOriginalLineweights,
      isTrue,
    );
  });

  for (final language in ['bg', 'en']) {
    testWidgets('underlay display controls fit a narrow $language phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var colors = false;
      var weights = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.35)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-underlay-dialog'),
                child: const Text('Edit'),
                onPressed: () => showArchitectUnderlayEditDialog(
                  context: context,
                  title: 'plan.dxf',
                  initialOpacity: .4,
                  onOpacityChanged: (_) {},
                  onOpenLayers: () {},
                  isLockOrigin: true,
                  onToggleLockOrigin: (_) {},
                  onRemove: () {},
                  onUseOriginalColorsChanged: (value) => colors = value,
                  onUseOriginalLineweightsChanged: (value) => weights = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-underlay-dialog')));
      await tester.pumpAndSettle();
      for (final key in [
        'architect-underlay-original-colors',
        'architect-underlay-original-lineweights',
      ]) {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }
      expect(colors, isTrue);
      expect(weights, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'workspace underlay dialog updates the painter live and supports undo',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = ArchitectCommandController(_project());
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(
            commandController: model,
            underlaysByStorey: {'s': _document()},
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
          .onToolChanged(ArchitectTool.cadUnderlay);
      await tester.pumpAndSettle();
      tester
          .widget<ArchitectCadUnderlayBar>(find.byType(ArchitectCadUnderlayBar))
          .onOpenContextMenu!(const Offset(200, 200));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is PopupMenuItem<String> && w.value == 'edit',
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<Slider>(
            find.byKey(const ValueKey('architect-underlay-opacity')),
          )
          .onChanged!(.8);
      await tester.pumpAndSettle();
      for (final key in [
        'architect-underlay-original-colors',
        'architect-underlay-original-lineweights',
      ]) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<ArchitectUnderlayPainter>()
          .single;
      expect(painter.cadConfig!.opacity, .8);
      expect(painter.cadConfig!.useOriginalColors, isTrue);
      expect(painter.cadConfig!.useOriginalLineweights, isTrue);
      expect(model.undoCount, 3);
      final saved = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(model.project.toJson())),
      );
      expect(saved.cadUnderlays['s']!.toJson(), painter.cadConfig!.toJson());
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
      await tester.tap(find.widgetWithText(TextButton, l.close));
      await tester.pumpAndSettle();
      model.undo();
      model.undo();
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project.cadUnderlays['s']!.opacity, .3);
      expect(model.project.cadUnderlays['s']!.useOriginalColors, isFalse);
      model.redo();
      model.redo();
      model.redo();
      await tester.pumpAndSettle();
      expect(model.project.cadUnderlays['s']!.useOriginalLineweights, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
