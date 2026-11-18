import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/dxf_viewer/models/dxf_models.dart';
import '../../features/dxf_viewer/parser/dwg_document_adapter.dart';
import 'acadrust_converter_service.dart';
import 'dwg_converter_service.dart' show DwgMemoryLimitException;

/// Reads the original DWG into drawing objects. No converted files or KCAD
/// caches are read/written. Native parsing stays outside the Flutter process.
class DwgReaderService {
  static const int maxPayloadBytes = 256 * 1024 * 1024;

  static Future<DxfDocument> read(String path) async {
    if (!await File(path).exists()) {
      throw FileSystemException('DWG does not exist', path);
    }
    final Uint8List data;
    if (Platform.isAndroid) {
      try {
        final result = await AcadrustConverterService.androidChannel
            .invokeMethod<Uint8List>('readDwg', {
              'inputPath': File(path).absolute.path,
            });
        if (result == null || result.isEmpty) {
          throw const FormatException('DWG reader returned no objects');
        }
        data = result;
      } on PlatformException catch (error) {
        if (error.code == 'OOM_KILLED') throw const DwgMemoryLimitException();
        throw FormatException('DWG reader: ${error.code}');
      }
    } else if (Platform.isWindows) {
      final executable = AcadrustConverterService.findExecutable();
      if (executable == null) {
        throw const FormatException('The native DWG reader is not installed');
      }
      final process = await Process.start(executable, [
        '--read',
        File(path).absolute.path,
      ]);
      final stdout = _collect(process.stdout, process);
      final stderr = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .fold<String>(
            '',
            (text, chunk) => text.length < 8192
                ? text +
                      chunk.substring(
                        0,
                        chunk.length.clamp(0, 8192 - text.length),
                      )
                : text,
          );
      try {
        final results = await Future.wait<Object>([
          process.exitCode,
          stdout,
          stderr,
        ]).timeout(AcadrustConverterService.conversionTimeout);
        if (results[0] != 0) {
          throw FormatException('DWG read failed: ${results[2]}');
        }
        data = results[1] as Uint8List;
      } finally {
        process.kill();
      }
    } else {
      throw const FormatException(
        'Direct DWG reading is not available on this platform',
      );
    }
    return compute(_decodeObjects, data);
  }

  static Future<Uint8List> _collect(
    Stream<List<int>> stream,
    Process process,
  ) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > maxPayloadBytes) {
        process.kill();
        throw const DwgMemoryLimitException();
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }
}

DxfDocument _decodeObjects(Uint8List bytes) {
  try {
    return DwgDocumentAdapter.decode(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  } on Error catch (error) {
    throw FormatException('Unsupported native DWG object structure: $error');
  }
}
