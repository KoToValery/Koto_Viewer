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
    final absolutePath = File(path).absolute.path;
    if (Platform.isAndroid) {
      final data = await readAndroidObjectStream(absolutePath);
      return compute(_decodeObjects, data);
    }
    if (Platform.isWindows) {
      // Keep the large native stream in the same isolate that decodes it.
      return compute(_readWindows, absolutePath);
    }
    throw const FormatException(
      'Direct DWG reading is not available on this platform',
    );
  }

  static Future<DxfDocument> _readWindows(String absolutePath) async {
    final executable = AcadrustConverterService.findExecutable();
    if (executable == null) {
      throw const FormatException('The native DWG reader is not installed');
    }
    final process = await Process.start(executable, ['--read', absolutePath]);
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
      return _decodeObjects(results[1] as Uint8List);
    } finally {
      process.kill();
    }
  }

  /// Android transport seam; preserves native diagnostics without converting
  /// the source or loading native libraries in the Flutter process.
  @visibleForTesting
  static Future<Uint8List> readAndroidObjectStream(
    String absolutePath, {
    MethodChannel channel = AcadrustConverterService.androidChannel,
  }) async {
    try {
      final result = await channel.invokeMethod<Uint8List>('readDwg', {
        'inputPath': absolutePath,
      });
      if (result == null || result.isEmpty) {
        throw const FormatException('DWG reader returned no objects');
      }
      return result;
    } on PlatformException catch (error) {
      debugPrint(
        'DwgReaderService Android: ${error.code}; ${error.message}; ${error.details}',
      );
      if (error.code == 'OOM_KILLED') throw const DwgMemoryLimitException();
      throw _AndroidDwgReadException(error.code, {
        'platformMessage': error.message,
        'details': error.details,
      });
    }
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

class _AndroidDwgReadException extends FormatException {
  _AndroidDwgReadException(String code, this.nativeDetails)
    : super('DWG reader: $code');
  final dynamic nativeDetails;

  // The viewer uses the existing localized loading error and `message`.
  // AppErrorHandler's logs also retain the actual native status and reason.
  @override
  String toString() => '${super.toString()}; native=$nativeDetails';
}

DxfDocument _decodeObjects(Uint8List bytes) {
  try {
    return DwgDocumentAdapter.decode(
      const Utf8Decoder().fuse(const JsonDecoder()).convert(bytes)
          as Map<String, dynamic>,
    );
  } on Error catch (error) {
    throw FormatException('Unsupported native DWG object structure: $error');
  }
}
