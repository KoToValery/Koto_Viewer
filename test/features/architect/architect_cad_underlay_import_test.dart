import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/core/services/acadrust_converter_service.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_underlay_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drag_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_underlay_service.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_underlay_bar.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_viewport_controller.dart';
import 'package:kotoview/src/features/bim_projects/services/architect_project_creation_helper.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _dxf(int width, {int? units = 4, bool allOff = false}) => <Object>[
  0,
  'SECTION',
  2,
  'HEADER',
  if (units != null) ...[9, r'$INSUNITS', 70, units],
  9,
  r'$MEASUREMENT',
  70,
  0,
  0,
  'ENDSEC',
  0,
  'SECTION',
  2,
  'TABLES',
  0,
  'TABLE',
  2,
  'LAYER',
  70,
  2,
  0,
  'LAYER',
  2,
  'Plan',
  70,
  0,
  62,
  allOff ? -7 : 7,
  0,
  'LAYER',
  2,
  'Off',
  70,
  0,
  62,
  -7,
  0,
  'ENDTAB',
  0,
  'ENDSEC',
  0,
  'SECTION',
  2,
  'ENTITIES',
  0,
  'LINE',
  8,
  'Plan',
  10,
  0,
  20,
  0,
  11,
  width,
  21,
  0,
  0,
  'LINE',
  8,
  'Plan',
  10,
  0,
  20,
  0,
  11,
  0,
  21,
  width ~/ 2,
  0,
  'LINE',
  8,
  'Off',
  10,
  0,
  20,
  width ~/ 2,
  11,
  width,
  21,
  width ~/ 2,
  0,
  'ENDSEC',
  0,
  'EOF',
].join('\n');

ArchitectProject _project() {
  final now = DateTime(2026);
  return ArchitectProject(
    id: 'cad_import',
    name: 'Cad import',
    createdAt: now,
    updatedAt: now,
    activeStoreyId: 'ground',
    storeys: const [ArchitectStorey(id: 'ground', name: 'Ground')],
  );
}

class _Paths extends PathProviderPlatform {
  final String root;
  _Paths(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

class _Picker extends FilePicker {
  File source;
  _Picker(this.source);

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(
      name: source.uri.pathSegments.last,
      size: 1,
      path: source.path,
    ),
  ]);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 40));
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
  }
  fail('CAD import did not reach the expected state.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late BimProjectLibraryService library;
  late ArchitectUnderlayService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('cad_underlay_review_');
    library = BimProjectLibraryService(customRootDir: temp);
    service = ArchitectUnderlayService(libraryService: library);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test(
    'source units, source visibility and reviewed bytes survive publication',
    () async {
      final file = await File(
        '${temp.path}/floor.dxf',
      ).writeAsString(_dxf(12000));
      final prepared = await service.prepareCadUnderlay(file);
      addTearDown(prepared.dispose);
      expect(prepared.declaredUnit, DxfUnit.millimeters);
      expect(prepared.suggestedUnitsPerMeter, 1000);
      expect(prepared.document.layers['Off']!.isVisible, isFalse);

      // The external drawing can be overwritten while the preview is open.
      await file.writeAsString(_dxf(48000, units: 6));
      final (project, architect) = await createArchitectWorkProject(
        library: library,
        archProject: _project(),
        underlays: {
          'ground': ArchitectCadImportSelection(
            prepared: prepared,
            unitsPerMeter: prepared.suggestedUnitsPerMeter,
            cadOrientation: true,
          ),
        },
      );
      final config = architect.cadUnderlays['ground']!;
      final frame = config.frame(const BimCoordinateFrame());
      expect(
        frame.toModel(const Offset(0, 6000)).dy,
        lessThan(frame.toModel(Offset.zero).dy),
      );
      expect(frame.rectToModel(prepared.document.bounds).width, 12);
      expect(
        frame.toCad(frame.toModel(const Offset(8500, 2500))),
        const Offset(8500, 2500),
      );
      final reopened = await library.loadArchitectProject(project.id);
      expect(reopened!.cadUnderlays['ground']!.cadOrientation, isTrue);
      expect(
        project.storeys.single.processing['source'],
        config.internalCopyPath,
      );
      expect(project.storeys.single.processing.containsKey('version'), isFalse);
      final document = await service.loadSavedCadUnderlay(
        config,
        projectId: project.id,
      );
      expect(document!.bounds.width, 12000);
      expect(document.layers['Off']!.isVisible, isFalse);
    },
  );

  test(
    'unitless plans use an estimate despite the measurement-system header',
    () async {
      final file = await File(
        '${temp.path}/unitless.dxf',
      ).writeAsString(_dxf(1200, units: null, allOff: true));
      final prepared = await service.prepareCadUnderlay(file);
      addTearDown(prepared.dispose);
      expect(prepared.scaleIsEstimated, isTrue);
      expect(prepared.suggestedUnitsPerMeter, 1000);
      expect(prepared.document.layers['Plan']!.isVisible, isFalse);
      final result = await service.commitCadUnderlay(
        projectId: 'units',
        storeyId: 'ground',
        selection: ArchitectCadImportSelection(
          prepared: prepared,
          unitsPerMeter: 100,
          cadOrientation: true,
        ),
      );
      expect(
        result.config
            .frame(const BimCoordinateFrame())
            .rectToModel(result.document.bounds)
            .width,
        12,
      );
    },
  );

  test(
    'drag uses the same Y-up transform for the ghost and the committed origin',
    () {
      final drag = ArchitectDragController();
      addTearDown(drag.dispose);
      const frame = BimCoordinateFrame(
        origin: Offset(4000, 5000),
        unitsPerMeter: 1000,
        invertY: true,
      );
      drag.startDrag(isUnderlay: true, isCadUnderlay: true);
      const base = Offset(2, 3);
      const target = Offset(5, -1);
      drag.grabBasePoint(base, frame: frame);
      drag.updateTargetHover(target, project: _project(), frame: frame);
      final ghost = drag.ghostCadFrame!;
      final committed = drag.computeCadPlacement(
        targetPointModel: target,
        existingMask: [base],
      );
      expect(ghost.toModel(frame.toCad(base)), target);
      expect(ghost.origin, Offset(committed.newOriginX, committed.newOriginY));
      expect(committed.translatedMask, [target]);
    },
  );

  test(
    'plan rendering includes text, block and hatch from the CAD renderer',
    () {
      final viewport = BimViewportController()
        ..resize(const Size(300, 240))
        ..fit(const Rect.fromLTWH(0, 0, 10, 8), padding: 12);
      addTearDown(viewport.dispose);
      final document = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: {
          'detail': DxfBlock(
            name: 'detail',
            basePoint: Offset.zero,
            entities: const [
              DxfLine(layer: '0', p1: Offset.zero, p2: Offset(3, 4)),
            ],
          ),
        },
        entities: const [
          DxfInsert(layer: '0', blockName: 'detail', insertPoint: Offset(2, 1)),
          DxfText(
            layer: '0',
            text: 'ROOM',
            insertPoint: Offset(1, 4),
            height: 0.5,
          ),
          DxfHatch(
            layer: '0',
            isSolid: true,
            boundaryPaths: [
              [Offset(6, 1), Offset(7, 1), Offset(7, 2), Offset(6, 2)],
            ],
          ),
        ],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 10, 8),
        entityStats: const {},
      );
      final picture = ui.PictureRecorder();
      ArchitectUnderlayPainter(
        viewport: viewport,
        document: document,
        frame: const BimCoordinateFrame(origin: Offset(0, 8), invertY: true),
        visibility: const {},
      ).paint(Canvas(picture), viewport.size);
      picture.endRecording().dispose();
      final stats = DxfPainter.lastStats!;
      expect(stats.insertCount, 1);
      expect(stats.textCount, 1);
      expect(stats.hatchCount, 1);
    },
  );

  final nativeDwg = File('test_files/0.dwg');
  test(
    'native DWG imports as an oriented architectural snapshot',
    () async {
      final imported = await service.importOrReloadCadUnderlay(
        projectId: 'native',
        storeyId: 'ground',
        sourceFile: nativeDwg,
      );
      expect(
        imported.document.entities.any((entity) => !entity.isPaperSpace),
        isTrue,
      );
      expect(imported.config.cadOrientation, isTrue);
      final reopened = await service.loadSavedCadUnderlay(
        imported.config,
        projectId: 'native',
      );
      expect(reopened!.entities.length, imported.document.entities.length);
      expect(
        reopened.getInsertionUnits(),
        imported.document.getInsertionUnits(),
      );
    },
    skip:
        !nativeDwg.existsSync() ||
        AcadrustConverterService.findExecutable() == null,
  );

  for (final phone in [false, true]) {
    testWidgets(
      'workspace import and revision history on ${phone ? 'phone' : 'desktop'}',
      (tester) async {
        final source = File('${temp.path}/original.dxf')
          ..writeAsStringSync(_dxf(12000));
        final other = File('${temp.path}/replacement.dxf')
          ..writeAsStringSync(_dxf(18000));
        final broken = File('${temp.path}/broken.dxf')
          ..writeAsStringSync('bad DXF');
        final picker = _Picker(source);
        final previousPaths = PathProviderPlatform.instance;
        FilePicker.platform = picker;
        PathProviderPlatform.instance = _Paths(temp.path);
        addTearDown(() {
          PathProviderPlatform.instance = previousPaths;
        });
        tester.view.physicalSize = phone
            ? const Size(360, 800)
            : const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = ArchitectCommandController(_project());
        addTearDown(model.dispose);
        final l = lookupAppLocalizations(Locale(phone ? 'bg' : 'en'));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(l.localeName),
            theme: ThemeData(
              brightness: phone ? Brightness.dark : Brightness.light,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        );
        await tester.pumpAndSettle();
        tester
            .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
            .onToolChanged(ArchitectTool.cadUnderlay);
        await tester.pumpAndSettle();
        final bar = find.byType(ArchitectCadUnderlayBar);
        final size = find.byKey(const ValueKey('architect-cad-import-size'));
        ArchitectCadUnderlayConfig? cfg() =>
            model.project.cadUnderlays['ground'];
        ArchitectUnderlayPainter painter() => tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((widget) => widget.painter)
            .whereType<ArchitectUnderlayPainter>()
            .first;

        await tester.tap(
          find.descendant(of: bar, matching: find.text(l.architectUnderlayAdd)),
        );
        await _pumpUntil(tester, () => size.evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text('12 × 6 m'), findsOneWidget);
        expect(cfg(), isNull);
        if (phone) {
          await tester.tap(find.textContaining(l.architectCadScaleAuto).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.architectUnderlayCadScaleCustom).last);
          await tester.pumpAndSettle();
          final input = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          await tester.enterText(input, '0');
          await tester.pump();
          final confirm = find.widgetWithText(
            FilledButton,
            l.architectCadImportAccept,
          );
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
          await tester.enterText(input, '2000');
          await tester.pump();
          expect(find.text('6 × 3 m'), findsOneWidget);
        }
        await tester.tap(find.widgetWithText(TextButton, l.cancel).last);
        await tester.pumpAndSettle();
        expect(cfg(), isNull);

        await tester.tap(
          find.descendant(of: bar, matching: find.text(l.architectUnderlayAdd)),
        );
        await _pumpUntil(tester, () => size.evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, l.architectCadImportAccept),
        );
        await _pumpUntil(tester, () => cfg() != null);
        await tester.pumpAndSettle();
        expect(painter().frame.invertY, isTrue);
        expect(painter().document!.bounds.width, 12000);
        if (phone) {
          model.commit(
            model.project.copyWith(
              cadUnderlays: {'ground': cfg()!.copyWith(cadOrientation: false)},
            ),
          );
          await tester.pump();
          expect(painter().frame.invertY, isFalse);
        }
        final original = cfg()!;

        Future<void> replace() async {
          await tester.tap(
            find.descendant(
              of: bar,
              matching: find.byTooltip(l.contextMenuMore),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.architectCadReplaceAccept));
        }

        picker.source = broken;
        await replace();
        await _pumpUntil(
          tester,
          () => find.text(l.architectCadImportEmpty).evaluate().isNotEmpty,
        );
        expect(cfg(), same(original));

        picker.source = other;
        await replace();
        await _pumpUntil(tester, () => size.evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        if (phone) {
          final orientation = find.widgetWithText(
            SwitchListTile,
            l.architectCadOrientation,
          );
          expect(tester.widget<SwitchListTile>(orientation).value, isFalse);
          await tester.ensureVisible(orientation);
          await tester.tap(orientation);
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.widgetWithText(FilledButton, l.architectCadReplaceAccept),
        );
        await _pumpUntil(tester, () => cfg()?.fileName == 'replacement.dxf');
        await tester.pumpAndSettle();
        expect(painter().document!.bounds.width, 18000);
        expect(painter().frame.invertY, isTrue);
        expect(cfg()!.unitsPerMeter, 1000);
        expect(cfg()!.lockedCadOriginX, original.lockedCadOriginX);
        model.undo();
        await tester.pump();
        expect(cfg()!.fileName, 'original.dxf');
        expect(painter().document!.bounds.width, 12000);
        expect(painter().frame.invertY, !phone);
        model.redo();
        await tester.pump();
        expect(painter().document!.bounds.width, 18000);
        await tester.tap(
          find.descendant(
            of: bar,
            matching: find.text(l.architectUnderlayScale),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.text('mm'),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('cm').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, l.applyAction));
        await tester.pumpAndSettle();
        expect(painter().frame.unitsPerMeter, 100);
        expect(painter().frame.origin.dx, original.lockedCadOriginX);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
