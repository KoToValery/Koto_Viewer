import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/components/dsl/parametric_script_parser.dart';
import 'package:kotoview/src/features/architect/services/component_library_service.dart';
import 'package:kotoview/src/features/architect/widgets/architect_component_library_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/component_dimensions_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/component_studio_dialog.dart';

class _JsonPicker extends FilePicker {
  static const source =
      '{"id":"import_mobile","name":"My lamp","category":"lighting",'
      '"defaultParams":{"width":0.4,"depth":0.4,"height":0.8},'
      '"solids":[{"type":"cylinder","radius":"width/2"}]}';
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
  }) async {
    expect(type, FileType.custom);
    expect(allowedExtensions, ['json']);
    expect(withData, isTrue);
    final bytes = Uint8List.fromList(utf8.encode(source));
    return FilePickerResult([
      PlatformFile(name: 'lamp.json', size: bytes.length, bytes: bytes),
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final fonts = FontLoader('ArchitectNoto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await ComponentLibraryService.instance.init();
  });

  Future<void> open(
    WidgetTester tester,
    Widget dialog,
    String locale,
    Size size,
    GlobalKey boundary,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(fontFamily: 'ArchitectNoto'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showDialog<void>(context: context, builder: (_) => dialog),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['COMPONENT_REVIEW_IMAGES'] != '1') return;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final folder = Directory('build/component_library_review')
        ..createSync(recursive: true);
      File(
        '${folder.path}/$name.png',
      ).writeAsBytesSync(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final locale in ['bg', 'en']) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      testWidgets(
        'Library and studio fit $locale ${size.width}x${size.height}',
        (tester) async {
          final key = GlobalKey();
          await open(
            tester,
            const ArchitectComponentLibraryDialog(),
            locale,
            size,
            key,
          );
          expect(tester.takeException(), isNull);
          final l = AppLocalizations.of(
            tester.element(find.byType(ArchitectComponentLibraryDialog)),
          )!;
          await tester.enterText(
            find.byType(TextField),
            l.architectComponentSofa,
          );
          await tester.pumpAndSettle();
          expect(
            find.byWidgetPredicate(
              (w) => w is Text && w.data == l.architectComponentSofa,
            ),
            findsOneWidget,
          );
          expect(find.text(l.architectComponentBedDouble), findsNothing);
          await tester.enterText(find.byType(TextField), '');
          await tester.pumpAndSettle();
          if (locale == 'bg' && size.width == 390) {
            await capture(tester, key, 'library_bg_phone');
            await tester.tap(
              find.byKey(const ValueKey('component-library-preview-mode')),
            );
            await tester.pumpAndSettle();
            await capture(tester, key, 'library_3d_bg_phone');
          }
          await tester.tap(find.byTooltip(l.close));
          await tester.pumpAndSettle();
          await open(tester, const ComponentStudioDialog(), locale, size, key);
          expect(find.byType(Slider), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('2D'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('3D'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (locale == 'bg' && size.width == 390) {
            await capture(tester, key, 'studio_3d_bg_phone');
          }
        },
      );
    }
  }

  testWidgets(
    'Typed sizes accept decimal commas, lock XYZ, and retain all validation errors',
    (tester) async {
      final library = ComponentLibraryService.instance;
      final bed = library.findDefinition('furniture_bed_double')!;
      final key = GlobalKey();
      await open(
        tester,
        ComponentDimensionsDialog(
          definition: bed,
          parameters: bed.defaultParameters,
        ),
        'bg',
        const Size(390, 844),
        key,
      );
      final width = find.byKey(const ValueKey('component-size-width'));
      final depth = find.byKey(const ValueKey('component-size-depth'));
      final height = find.byKey(const ValueKey('component-size-height'));
      await tester.tap(find.byType(SwitchListTile));
      await tester.enterText(width, '90,0');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(depth).controller!.text, '100');
      expect(tester.widget<TextField>(height).controller!.text, '47.5');
      await capture(tester, key, 'dimensions_bg_phone');
      await tester.tap(find.byType(SwitchListTile));
      await tester.enterText(width, '0');
      await tester.enterText(depth, '0');
      await tester.enterText(depth, '100');
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Edited source must compile before it can be saved', (
    tester,
  ) async {
    final key = GlobalKey();
    await open(
      tester,
      const ComponentStudioDialog(),
      'en',
      const Size(320, 568),
      key,
    );
    final count = ComponentLibraryService.instance
        .getAllDefinitions()
        .whereType<ScriptedComponentDefinition>()
        .length;
    await tester.enterText(
      find.byKey(const ValueKey('component-studio-code')),
      '{"solids":[{"type":"missing"}]}',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(
      ComponentLibraryService.instance
          .getAllDefinitions()
          .whereType<ScriptedComponentDefinition>()
          .length,
      count,
    );
    expect(find.textContaining('Check the object code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Both JSON and Dart exports preserve authored names and dimensions',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final script = jsonEncode({
        'id': '9-a:b',
        'name': r'Furniture $name',
        'defaultParams': {'width': 1.2, 'depth': .6, 'height': .8},
        'solids': [
          {'type': 'box'},
        ],
      });
      await open(
        tester,
        ComponentStudioDialog(initialScriptJson: script),
        'en',
        const Size(390, 844),
        GlobalKey(),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(ComponentStudioDialog)),
      )!;
      await tester.tap(find.byTooltip(l.architectComponentExportJsonTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.architectComponentExportDartTooltip));
      await tester.pumpAndSettle();
      expect(copied, contains('class LibraryComponent_9_a_b'));
      expect(copied, contains(r'Furniture \$name'));
      await tester.tap(find.byTooltip(l.architectComponentExportJsonTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.architectComponentExportJsonTooltip));
      await tester.pumpAndSettle();
      final definition = ParametricScriptParser.parse(copied!);
      expect(definition.defaultName, r'Furniture $name');
      expect(definition.defaultParameters['width'], 1.2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'JSON import previews, saves, filters and selects an object in one tap',
    (tester) async {
      FilePicker.platform = _JsonPicker();
      String? selected;
      final key = GlobalKey();
      await open(
        tester,
        ArchitectComponentLibraryDialog(
          onSelectComponent: (d) => selected = d.id,
        ),
        'en',
        const Size(390, 844),
        key,
      );
      final context = tester.element(
        find.byType(ArchitectComponentLibraryDialog),
      );
      final l = AppLocalizations.of(context)!;
      await tester.tap(find.byTooltip(l.architectLibraryImportHelp));
      await tester.pumpAndSettle();
      expect(find.byType(ComponentStudioDialog), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('component-studio-code')),
            )
            .controller!
            .text,
        contains('import_mobile'),
      );
      expect(
        ComponentLibraryService.instance.findDefinition('import_mobile'),
        isNull,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(
        ComponentLibraryService.instance.findDefinition('import_mobile'),
        isNotNull,
        reason: find
            .byType(SelectableText)
            .evaluate()
            .map((e) => (e.widget as SelectableText).data)
            .join('\n'),
      );
      await tester.tap(find.byTooltip(l.close).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('component-library-category')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l.architectCategoryLighting).last);
      await tester.tap(find.text(l.architectCategoryLighting).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('component-library-source')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.architectLibraryCustom).last);
      await tester.pumpAndSettle();
      expect(find.text('My lamp'), findsOneWidget);
      await tester.tap(find.text('My lamp'));
      await tester.pumpAndSettle();
      expect(selected, 'import_mobile');
      expect(ComponentLibraryService.instance.activeParameters['width'], .4);
      expect(find.byType(ArchitectComponentLibraryDialog), findsNothing);
      await tester.runAsync(
        () => ComponentLibraryService.instance.deleteCustomScript(
          'import_mobile',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
