import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'acadrust_converter_service.dart';

class DwgExportCancelled implements Exception {
  const DwgExportCancelled();
}

/// Encodes publication geometry as a real DWG. Android uses FD pipes in the
/// isolated native worker. No intermediate CAD files or large Binder messages.
abstract final class DwgExportService {
  static const maxBytes = 256 * 1024 * 1024;
  static int _sequence = 0;

  static Future<Uint8List> encode(
    Uint8List dxf, {
    bool Function()? isCancelled,
  }) async {
    _checkCancelled(isCancelled);
    if (dxf.isEmpty || dxf.length > maxBytes) {
      throw const FormatException('Invalid DWG export input size');
    }
    final Uint8List bytes;
    if (Platform.isAndroid) {
      bytes = await encodeAndroid(dxf, isCancelled: isCancelled);
    } else if (Platform.isWindows) {
      bytes = await _encodeWindows(dxf, isCancelled);
    } else {
      throw UnsupportedError('DWG export is unavailable on this platform');
    }
    _checkCancelled(isCancelled);
    _validate(bytes);
    return bytes;
  }

  @visibleForTesting
  static Future<Uint8List> encodeAndroid(
    Uint8List dxf, {
    MethodChannel channel = AcadrustConverterService.androidChannel,
    bool Function()? isCancelled,
  }) async {
    _checkCancelled(isCancelled);
    final jobId = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    var cancelSent = false;
    final timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!cancelSent && (isCancelled?.call() ?? false)) {
        cancelSent = true;
        unawaited(
          channel
              .invokeMethod<void>('cancelDwgExport', {'jobId': jobId})
              .catchError((Object _) {}),
        );
      }
    });
    try {
      final bytes = await channel.invokeMethod<Uint8List>('writeDwg', {
        'dxfBytes': dxf,
        'jobId': jobId,
      });
      _checkCancelled(isCancelled);
      if (bytes == null) throw const FormatException('Empty DWG export');
      _validate(bytes);
      return bytes;
    } on PlatformException catch (e) {
      if (e.code == 'DWG_EXPORT_CANCELLED' || (isCancelled?.call() ?? false)) {
        throw const DwgExportCancelled();
      }
      throw FormatException(
        'DWG export: ${e.code}; ${e.message}; ${e.details}',
      );
    } finally {
      timer.cancel();
    }
  }

  static Future<Uint8List> _encodeWindows(
    Uint8List input,
    bool Function()? cancelled,
  ) async {
    final executable = AcadrustConverterService.findExecutable();
    if (executable == null) {
      throw const FormatException('Native DWG writer is not installed');
    }
    final process = await Process.start(executable, ['--write-dwg']);
    final timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (cancelled?.call() ?? false) process.kill();
    });
    Future<void> send() async {
      process.stdin.add(input);
      await process.stdin.close();
    }

    try {
      final result = await Future.wait<Object?>([
        process.exitCode,
        _collect(process),
        process.stderr
            .transform(const Utf8Decoder(allowMalformed: true))
            .fold<String>(
              '',
              (a, b) =>
                  (a + b).substring(0, (a.length + b.length).clamp(0, 8192)),
            ),
        send(),
      ]).timeout(AcadrustConverterService.conversionTimeout);
      _checkCancelled(cancelled);
      if (result[0] != 0) {
        throw FormatException('DWG export failed: ${result[2]}');
      }
      return result[1] as Uint8List;
    } catch (_) {
      _checkCancelled(cancelled);
      rethrow;
    } finally {
      timer.cancel();
      process.kill();
    }
  }

  static Future<Uint8List> _collect(Process process) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in process.stdout) {
      if (bytes.length + chunk.length > maxBytes) {
        process.kill();
        throw const FormatException('DWG export exceeds the transport limit');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static void _checkCancelled(bool Function()? cancelled) {
    if (cancelled?.call() ?? false) throw const DwgExportCancelled();
  }

  static void _validate(Uint8List bytes) {
    if (bytes.length < 64 ||
        bytes.length > maxBytes ||
        String.fromCharCodes(bytes.take(6)) != 'AC1032') {
      throw const FormatException('Native writer returned an invalid DWG');
    }
  }
}
