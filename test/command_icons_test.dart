import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every catalogue asset is local, vector-only and localized', () {
    final assets = <String>{};
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      for (final id in AppIconId.values) {
        expect(id.label(l).trim(), isNotEmpty, reason: '${id.name}: $locale');
      }
    }
    for (final id in AppIconId.values) {
      expect(assets.add(id.assetPath), isTrue);
      final root = XmlDocument.parse(
        File(id.assetPath).readAsStringSync(),
      ).rootElement;
      expect(root.name.local, 'svg');
      expect(root.getAttribute('viewBox'), '0 0 24 24');
      expect(root.getAttribute('fill'), 'none');
      expect(root.getAttribute('stroke'), 'currentColor');
      for (final element in root.descendants.whereType<XmlElement>()) {
        expect(
          {
            'path',
            'rect',
            'circle',
            'ellipse',
            'line',
            'polyline',
            'polygon',
            'g',
          },
          contains(element.name.local),
          reason: id.assetPath,
        );
        for (final attribute in element.attributes) {
          expect(attribute.name.local, isNot('href'));
          expect(attribute.value, isNot(contains('url(')));
        }
      }
    }
    expect(
      Directory('assets/icons/commands').listSync().whereType<File>().where(
        (file) => file.path.endsWith('.svg'),
      ),
      hasLength(assets.length),
    );
  });

  test('geometrically different BIM edits have distinct symbols', () {
    final symbols = BimEditAction.values.map(BimEditActions.icon).toSet();
    expect(symbols, hasLength(BimEditAction.values.length));
    expect(BimEditActions.icon(BimEditAction.newPoint), AppIconId.newPoint);
    expect(BimEditActions.icon(BimEditAction.join), AppIconId.join);
    expect(
      () => AppIcons.fromMaterial(const IconData(0xffff)),
      throwsArgumentError,
    );
  });

  test('all SVGs decode and paint at small command sizes', () async {
    final pictures = <PictureInfo>[];
    try {
      for (final id in AppIconId.values) {
        final info = await vg.loadPicture(SvgAssetLoader(id.assetPath), null);
        expect(info.size, const Size(24, 24), reason: id.assetPath);
        final image = await info.picture.toImage(24, 24);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        expect(
          [
            for (var i = 3; i < bytes.length; i += 4) bytes[i],
          ].any((a) => a > 0),
          isTrue,
          reason: '${id.name} must not be an empty/placeholder icon',
        );
        image.dispose();
        pictures.add(info);
      }
      if (Platform.environment['UPDATE_COMMAND_ICON_PREVIEWS'] == 'true') {
        await _writeContactSheets(pictures);
      }
    } finally {
      for (final picture in pictures) {
        picture.picture.dispose();
      }
    }
  });

  testWidgets('inherits dimensions, color and disabled opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: IconTheme(
            data: IconThemeData(size: 18, color: Colors.blue, opacity: .4),
            child: AppIcon(AppIconId.move),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(tester.getSize(find.byType(AppIcon)), const Size(18, 18));
    expect(
      svg.colorFilter,
      ColorFilter.mode(Colors.blue.withValues(alpha: .4), BlendMode.srcIn),
    );
    expect(svg.excludeFromSemantics, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final width in [360.0, 800.0, 1280.0]) {
      testWidgets('menu works at $width in ${locale.languageCode}', (
        tester,
      ) async {
        tester.view.reset();
        tester.view.physicalSize = Size(width, width == 800 ? 360 : 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var selected = false;
        final l = lookupAppLocalizations(locale);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: PopupMenuButton<String>(
                  key: const ValueKey('open-commands'),
                  onSelected: (_) => selected = true,
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      key: const ValueKey('menu-mirror-copy'),
                      value: 'mirrorCopy',
                      checked: true,
                      child: AppMenuLabel(
                        icon: AppIconId.mirrorCopy,
                        child: Text(l.architectMirrorCopy),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open-commands')));
        await tester.pumpAndSettle();
        expect(find.text(l.architectMirrorCopy), findsOneWidget);
        expect(find.byType(AppIcon), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('menu-mirror-copy')));
        await tester.pumpAndSettle();
        expect(selected, isTrue);
      });
    }
  }
}

Future<void> _writeContactSheets(List<PictureInfo> pictures) async {
  final font = FontLoader('CommandPreview')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  await font.load();
  final folder = Directory('scratch/command_icon_previews')
    ..createSync(recursive: true);
  const columns = 5, perPage = 60, cellWidth = 240.0, cellHeight = 116.0;
  final l = lookupAppLocalizations(const Locale('bg'));
  for (var start = 0; start < pictures.length; start += perPage) {
    final end = (start + perPage).clamp(0, pictures.length);
    final rows = ((end - start) / columns).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xfff2f4f7), BlendMode.src);
    for (var index = start; index < end; index++) {
      final x = ((index - start) % columns) * cellWidth;
      final y = ((index - start) ~/ columns) * cellHeight;
      final id = AppIconId.values[index];
      final paragraph =
          (ui.ParagraphBuilder(
                  ui.ParagraphStyle(fontSize: 12, fontFamily: 'CommandPreview'),
                )
                ..pushStyle(ui.TextStyle(color: Colors.black))
                ..addText('${id.label(l)}\n${id.name}'))
              .build()
            ..layout(const ui.ParagraphConstraints(width: cellWidth - 12));
      canvas.drawParagraph(paragraph, Offset(x + 6, y + 4));
      paragraph.dispose();
      for (var row = 0; row < 2; row++) {
        final bounds = Rect.fromLTWH(
          x + 4,
          y + 44 + row * 33,
          cellWidth - 8,
          31,
        );
        canvas.drawRect(
          bounds,
          Paint()..color = row == 0 ? Colors.white : const Color(0xff181c24),
        );
        var column = 0;
        for (final size in [14.0, 16.0, 20.0, 24.0]) {
          canvas.save();
          canvas.translate(x + 12 + column * 54, bounds.top + (31 - size) / 2);
          canvas.saveLayer(
            Rect.fromLTWH(-1, -1, size + 2, size + 2),
            Paint()
              ..colorFilter = ColorFilter.mode(
                row == 0 ? Colors.black : Colors.white,
                BlendMode.srcIn,
              ),
          );
          canvas.scale(size / 24);
          canvas.drawPicture(pictures[index].picture);
          canvas.restore();
          canvas.restore();
          column++;
        }
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (columns * cellWidth).toInt(),
      (rows * cellHeight).toInt(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '${folder.path}/icons_${start ~/ perPage + 1}.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  }
  final data = {for (final id in AppIconId.values) id.name: id.assetPath};
  File('${folder.path}/assets.json').writeAsStringSync(jsonEncode(data));
}
