import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef NativeConvertDwgToDxf = Int32 Function(
  Pointer<Utf8> inDwgPath,
  Pointer<Utf8> outDxfPath,
);

typedef DartConvertDwgToDxf = int Function(
  Pointer<Utf8> inDwgPath,
  Pointer<Utf8> outDxfPath,
);

/// FFI bridge to native LibreDWG converter library.
class LibreDwgFfi {
  static DynamicLibrary? _lib;
  static DartConvertDwgToDxf? _convertFn;
  static bool _initAttempted = false;

  static bool get isAvailable {
    _ensureInitialized();
    return _convertFn != null;
  }

  static void _ensureInitialized() {
    if (_initAttempted) return;
    _initAttempted = true;

    try {
      if (Platform.isAndroid) {
        // Preload libredwg.so then load libkoto_dwg.so
        try {
          DynamicLibrary.open('libredwg.so');
        } catch (e) {
          debugPrint('LibreDwgFfi note: libredwg.so preload: $e');
        }
        try {
          _lib = DynamicLibrary.open('libkoto_dwg.so');
        } catch (_) {
          _lib = DynamicLibrary.open('libredwg.so');
        }
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('koto_dwg.dll');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libkoto_dwg.so');
      } else if (Platform.isMacOS || Platform.isIOS) {
        _lib = DynamicLibrary.process();
      }

      if (_lib != null) {
        _convertFn = _lib!
            .lookupFunction<NativeConvertDwgToDxf, DartConvertDwgToDxf>(
              'koto_convert_dwg_to_dxf',
            );
      }
    } catch (e) {
      debugPrint('LibreDwgFfi init note (native library not loaded): $e');
    }
  }

  /// Converts a DWG file at [inputDwgPath] to a DXF file at [outputDxfPath].
  /// Returns 0 on success, or a non-zero error code on failure.
  static int convert(String inputDwgPath, String outputDxfPath) {
    _ensureInitialized();

    final fn = _convertFn;
    if (fn == null) {
      throw UnsupportedError(
        'Native LibreDWG library is not available on this platform.',
      );
    }

    final inPtr = inputDwgPath.toNativeUtf8();
    final outPtr = outputDxfPath.toNativeUtf8();

    try {
      return fn(inPtr, outPtr);
    } finally {
      malloc.free(inPtr);
      malloc.free(outPtr);
    }
  }
}
