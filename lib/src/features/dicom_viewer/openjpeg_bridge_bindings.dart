// Hand-written FFI bindings for openjpeg_bridge.
// Equivalent to what dart_ffigen would generate from openjpeg_bridge.h.
// If clang/llvm is available: dart run ffigen --config ffigen_openjpeg.yaml
//
// ignore_for_file: always_specify_types, camel_case_types
// ignore_for_file: directives_ordering, non_constant_identifier_names

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// Native type aliases
// ---------------------------------------------------------------------------
typedef _OPJDecodeToRgbaNative = Int32 Function(
  Pointer<Uint8> data,
  Int32 length,
  Pointer<Int32> outWidth,
  Pointer<Int32> outHeight,
  Pointer<Pointer<Uint8>> outRgba,
);

typedef _OPJDecodeToRgbaDart = int Function(
  Pointer<Uint8> data,
  int length,
  Pointer<Int32> outWidth,
  Pointer<Int32> outHeight,
  Pointer<Pointer<Uint8>> outRgba,
);

typedef _OPJDecodeRawNative = Int32 Function(
  Pointer<Uint8> data,
  Int32 length,
  Pointer<Int32> outWidth,
  Pointer<Int32> outHeight,
  Pointer<Int32> outNumComps,
  Pointer<Int32> outPrec,
  Pointer<Int32> outSgnd,
  Pointer<Pointer<Int32>> outPixels,
  Pointer<Pointer<Uint8>> outRgba,
);

typedef _OPJDecodeRawDart = int Function(
  Pointer<Uint8> data,
  int length,
  Pointer<Int32> outWidth,
  Pointer<Int32> outHeight,
  Pointer<Int32> outNumComps,
  Pointer<Int32> outPrec,
  Pointer<Int32> outSgnd,
  Pointer<Pointer<Int32>> outPixels,
  Pointer<Pointer<Uint8>> outRgba,
);

typedef _OPJFreeBufferNative = Void Function(Pointer<Uint8> buf);
typedef _OPJFreeBufferDart = void Function(Pointer<Uint8> buf);

// ---------------------------------------------------------------------------
// Library loader
// ---------------------------------------------------------------------------

/// Returns the platform-specific filename of the openjpeg_bridge shared lib.
String _libraryName() {
  if (Platform.isAndroid) return 'libopenjpeg_bridge.so';
  if (Platform.isWindows) return 'openjpeg_bridge.dll';
  if (Platform.isLinux) return 'libopenjpeg_bridge.so';
  if (Platform.isMacOS) return 'libopenjpeg_bridge.dylib';
  throw UnsupportedError(
      'openjpeg_bridge: unsupported platform ${Platform.operatingSystem}');
}

/// Loads the DynamicLibrary once (cached).
DynamicLibrary? _cachedLib;
bool _loadAttempted = false;

DynamicLibrary? _openLibrary() {
  if (_loadAttempted) return _cachedLib;
  _loadAttempted = true;
  try {
    _cachedLib = DynamicLibrary.open(_libraryName());
  } catch (_) {
    if (Platform.isWindows) {
      final candidates = [
        'build\\windows\\x64\\runner\\Debug\\openjpeg_bridge.dll',
        'build\\windows\\x64\\runner\\Release\\openjpeg_bridge.dll',
        'build\\windows\\x64\\Debug\\openjpeg_bridge.dll',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) {
          try {
            _cachedLib = DynamicLibrary.open(path);
            return _cachedLib;
          } catch (_) {}
        }
      }
    }
    _cachedLib = null; // JPEG 2000 not available on this platform
  }
  return _cachedLib;
}

// ---------------------------------------------------------------------------
// Public Dart API
// ---------------------------------------------------------------------------

/// Returns true if JPEG 2000 decoding is available on this device.
bool get isJpeg2000Available => _openLibrary() != null;

/// Decode a JPEG 2000 codestream or JP2 container.
///
/// Returns null if the library is not available or decoding fails.
/// On success returns [Jpeg2000Result] with width, height, and RGBA pixels.
Jpeg2000Result? decodeJpeg2000(List<int> compressedBytes) {
  final lib = _openLibrary();
  if (lib == null) return null;

  // Lazy-bind the functions
  final decodeFunc = lib.lookupFunction<_OPJDecodeToRgbaNative, _OPJDecodeToRgbaDart>(
    'opj_decode_to_rgba',
  );
  final freeFunc = lib.lookupFunction<_OPJFreeBufferNative, _OPJFreeBufferDart>(
    'opj_free_buffer',
  );

  // Copy input into native memory
  final inputPtr = calloc<Uint8>(compressedBytes.length);
  try {
    for (int i = 0; i < compressedBytes.length; i++) {
      inputPtr[i] = compressedBytes[i] & 0xFF;
    }

    // Allocate output pointers
    final widthPtr = calloc<Int32>();
    final heightPtr = calloc<Int32>();
    final rgbaPtr = calloc<Pointer<Uint8>>();

    try {
      final result = decodeFunc(
        inputPtr,
        compressedBytes.length,
        widthPtr,
        heightPtr,
        rgbaPtr,
      );

      if (result == 0) return null;

      final width = widthPtr.value;
      final height = heightPtr.value;
      final nativeRgba = rgbaPtr.value;

      if (width <= 0 || height <= 0 || nativeRgba == nullptr) return null;

      // Copy RGBA from native memory into Dart Uint8List
      final pixelCount = width * height * 4;
      final dartRgba = Uint8List(pixelCount);
      for (int i = 0; i < pixelCount; i++) {
        dartRgba[i] = nativeRgba[i];
      }

      // Free the native buffer
      freeFunc(nativeRgba);

      return Jpeg2000Result(
        width: width,
        height: height,
        rgba: dartRgba,
      );
    } finally {
      calloc.free(widthPtr);
      calloc.free(heightPtr);
      calloc.free(rgbaPtr);
    }
  } finally {
    calloc.free(inputPtr);
  }
}

// ---------------------------------------------------------------------------
// Result classes
// ---------------------------------------------------------------------------

class Jpeg2000Result {
  final int width;
  final int height;

  /// Raw RGBA pixel data: width × height × 4 bytes.
  final Uint8List rgba;

  const Jpeg2000Result({
    required this.width,
    required this.height,
    required this.rgba,
  });
}

class Jpeg2000RawResult {
  final int width;
  final int height;
  final int numComps;
  final int precision;
  final int isSigned;

  /// Raw decoded pixel values (non-null when numComps == 1 for grayscale).
  final Int32List? rawPixels;

  /// 8-bit RGBA pixel values (non-null when numComps >= 3 for color).
  final Uint8List? rgba;

  const Jpeg2000RawResult({
    required this.width,
    required this.height,
    required this.numComps,
    required this.precision,
    required this.isSigned,
    this.rawPixels,
    this.rgba,
  });
}

/// Decode a JPEG 2000 codestream or JP2 container to raw pixel data.
///
/// For grayscale (numComps == 1), returns the unshifted/unclipped raw pixel
/// values as an Int32List, suitable for DICOM windowing/VOI LUT.
/// For color (numComps >= 3), returns 8-bit RGBA pixel bytes.
Jpeg2000RawResult? decodeJpeg2000Raw(List<int> compressedBytes) {
  final lib = _openLibrary();
  if (lib == null) return null;

  _OPJDecodeRawDart? decodeRawFunc;
  try {
    decodeRawFunc = lib.lookupFunction<_OPJDecodeRawNative, _OPJDecodeRawDart>(
      'opj_decode_raw',
    );
  } catch (_) {
    // If opj_decode_raw is not available, fall back to null so caller can use decodeJpeg2000
    return null;
  }

  final freeFunc = lib.lookupFunction<_OPJFreeBufferNative, _OPJFreeBufferDart>(
    'opj_free_buffer',
  );

  final inputPtr = calloc<Uint8>(compressedBytes.length);
  try {
    for (int i = 0; i < compressedBytes.length; i++) {
      inputPtr[i] = compressedBytes[i] & 0xFF;
    }

    final widthPtr = calloc<Int32>();
    final heightPtr = calloc<Int32>();
    final compsPtr = calloc<Int32>();
    final precPtr = calloc<Int32>();
    final sgndPtr = calloc<Int32>();
    final pixelsPtr = calloc<Pointer<Int32>>();
    final rgbaPtr = calloc<Pointer<Uint8>>();

    try {
      final result = decodeRawFunc(
        inputPtr,
        compressedBytes.length,
        widthPtr,
        heightPtr,
        compsPtr,
        precPtr,
        sgndPtr,
        pixelsPtr,
        rgbaPtr,
      );

      if (result == 0) return null;

      final width = widthPtr.value;
      final height = heightPtr.value;
      final comps = compsPtr.value;
      final prec = precPtr.value;
      final sgnd = sgndPtr.value;
      final nativePixels = pixelsPtr.value;
      final nativeRgba = rgbaPtr.value;

      if (width <= 0 || height <= 0) return null;

      Int32List? dartPixels;
      Uint8List? dartRgba;

      if (comps == 1 && nativePixels != nullptr) {
        final pixelCount = width * height;
        dartPixels = Int32List(pixelCount);
        for (int i = 0; i < pixelCount; i++) {
          dartPixels[i] = nativePixels[i];
        }
        freeFunc(nativePixels.cast<Uint8>());
      } else if (nativeRgba != nullptr) {
        final byteCount = width * height * 4;
        dartRgba = Uint8List(byteCount);
        for (int i = 0; i < byteCount; i++) {
          dartRgba[i] = nativeRgba[i];
        }
        freeFunc(nativeRgba);
      }

      return Jpeg2000RawResult(
        width: width,
        height: height,
        numComps: comps,
        precision: prec,
        isSigned: sgnd,
        rawPixels: dartPixels,
        rgba: dartRgba,
      );
    } finally {
      calloc.free(widthPtr);
      calloc.free(heightPtr);
      calloc.free(compsPtr);
      calloc.free(precPtr);
      calloc.free(sgndPtr);
      calloc.free(pixelsPtr);
      calloc.free(rgbaPtr);
    }
  } finally {
    calloc.free(inputPtr);
  }
}
