import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const directory = String.fromEnvironment('DWG_PHONE_FIXTURE_DIR');
  for (final fixture in {
    '+-0,00 Worksheet.dwg': (2778, 138, 21),
    'К1_ситуация Worksheet.dwg': (3034, 45, 0),
  }.entries) {
    test(
      'direct phone reproduction drawing: ${fixture.key}',
      () async {
        final temp = await Directory.systemTemp.createTemp('dwg_phone_');
        try {
          final source = await File(
            '$directory/${fixture.key}',
          ).copy('${temp.path}/${fixture.key}');
          final doc = await DxfParser.parseFromFile(source);
          expect(doc.entities.length, fixture.value.$1);
          expect(doc.blocks.length, fixture.value.$2);
          expect(
            doc.entities.whereType<DxfHatch>().where((e) => e.isWipeout).length,
            fixture.value.$3,
          );
          expect(
            temp.listSync().length,
            1,
            reason: 'Opening DWG must not write intermediate CAD files',
          );
        } finally {
          await temp.delete(recursive: true);
        }
      },
      skip:
          directory.isEmpty ||
          !Platform.isWindows ||
          !File('$directory/${fixture.key}').existsSync(),
    );
  }
}
