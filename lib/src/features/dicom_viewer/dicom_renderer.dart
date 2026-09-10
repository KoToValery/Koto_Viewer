import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

import 'dicom_parser.dart';
import 'openjpeg_bridge_bindings.dart' as j2k;

/// Result of rendering a single DICOM frame.
class DicomRenderResult {
  final ui.Image image;
  final int frameIndex;
  final int totalFrames;
  final double windowCenter;
  final double windowWidth;

  const DicomRenderResult({
    required this.image,
    required this.frameIndex,
    required this.totalFrames,
    this.windowCenter = 127,
    this.windowWidth = 256,
  });
}

/// Windowing preset for common DICOM viewing scenarios.
class WindowPreset {
  final String name;
  final double center;
  final double width;

  const WindowPreset({
    required this.name,
    required this.center,
    required this.width,
  });

  static const List<WindowPreset> presets = [
    WindowPreset(name: 'Soft Tissue', center: 40, width: 400),
    WindowPreset(name: 'Brain', center: 40, width: 80),
    WindowPreset(name: 'Bone', center: 300, width: 1500),
    WindowPreset(name: 'Lung', center: -600, width: 1500),
    WindowPreset(name: 'Liver', center: 60, width: 160),
    WindowPreset(name: 'Spine', center: 30, width: 300),
  ];
}

/// Pure-Dart DICOM pixel renderer.
/// Supports:
///  - Uncompressed 8-bit and 16-bit grayscale (MONOCHROME1/2)
///  - Uncompressed RGB (SamplesPerPixel=3)
///  - JPEG Baseline encapsulated (Transfer Syntax 1.2.840.10008.1.2.4.50)
///  - Multi-frame datasets
///  - Windowing/leveling with configurable center + width
class DicomRenderer {
  /// Render a specific [frameIndex] (0-based) from the given file bytes.
  ///
  /// [windowCenter] and [windowWidth] override the values from the header.
  /// Pass null to use the header values (or auto-window if not present).
  static Future<DicomRenderResult> renderFrame({
    required Uint8List fileBytes,
    required DicomHeader header,
    int frameIndex = 0,
    double? windowCenter,
    double? windowWidth,
  }) async {
    final frame = frameIndex.clamp(0, header.numberOfFrames - 1);

    if (DicomTransferSyntax.isUncompressed(header.transferSyntaxUID)) {
      return _renderUncompressed(
        fileBytes: fileBytes,
        header: header,
        frameIndex: frame,
        windowCenter: windowCenter,
        windowWidth: windowWidth,
      );
    } else if (DicomTransferSyntax.isJpegBaseline(header.transferSyntaxUID) ||
        DicomTransferSyntax.isJpegLossless(header.transferSyntaxUID)) {
      return _renderJpegEncapsulated(
        fileBytes: fileBytes,
        header: header,
        frameIndex: frame,
        windowCenter: windowCenter,
        windowWidth: windowWidth,
      );
    } else if (DicomTransferSyntax.isJpeg2000(header.transferSyntaxUID)) {
      return _renderJpeg2000Encapsulated(
        fileBytes: fileBytes,
        header: header,
        frameIndex: frame,
        windowCenter: windowCenter,
        windowWidth: windowWidth,
      );
    } else {
      throw UnsupportedError(
          'Transfer syntax not supported for rendering: ${header.transferSyntaxLabel}');
    }
  }

  // --------------------------------------------------------------------------
  // Uncompressed rendering
  // --------------------------------------------------------------------------

  static Future<DicomRenderResult> _renderUncompressed({
    required Uint8List fileBytes,
    required DicomHeader header,
    required int frameIndex,
    double? windowCenter,
    double? windowWidth,
  }) async {
    final frameOffset = header.pixelDataOffset + frameIndex * header.frameSizeBytes;
    final frameEnd = frameOffset + header.frameSizeBytes;

    if (frameOffset >= fileBytes.length) {
      throw DicomParseException(
          'Frame $frameIndex data starts beyond file length '
          '(offset=$frameOffset, fileLen=${fileBytes.length})');
    }

    final pixelBytes = fileBytes.sublist(
      frameOffset,
      frameEnd.clamp(0, fileBytes.length),
    );

    final res = _pixelBytesToRgba(pixelBytes, header, windowCenter, windowWidth);
    final image = await _createImage(res.$1, header.columns, header.rows);

    return DicomRenderResult(
      image: image,
      frameIndex: frameIndex,
      totalFrames: header.numberOfFrames,
      windowCenter: res.$2,
      windowWidth: res.$3,
    );
  }

  /// Convert raw pixel bytes to RGBA Uint8List using windowing.
  static (Uint8List rgba, double wc, double ww) _pixelBytesToRgba(
    Uint8List pixelBytes,
    DicomHeader header,
    double? overrideCenter,
    double? overrideWidth,
  ) {
    final w = header.columns;
    final h = header.rows;
    final rgba = Uint8List(w * h * 4);
    double wc = overrideCenter ?? header.windowCenter ?? 127;
    double ww = overrideWidth ?? header.windowWidth ?? 256;

    if (header.samplesPerPixel == 3) {
      // RGB (8-bit per channel)
      _renderRgb(pixelBytes, rgba, w, h);
    } else if (header.bitsAllocated == 8) {
      _renderMono8(pixelBytes, rgba, w, h, header);
    } else {
      // 16-bit (most CT/MRI)
      final res = _renderMono16(
        pixelBytes,
        rgba,
        w,
        h,
        header,
        overrideCenter,
        overrideWidth,
      );
      wc = res.$1;
      ww = res.$2;
    }

    return (rgba, wc, ww);
  }

  static void _renderRgb(Uint8List src, Uint8List dst, int w, int h) {
    final pixels = w * h;
    for (int i = 0; i < pixels; i++) {
      final si = i * 3;
      final di = i * 4;
      dst[di] = si < src.length ? src[si] : 0;       // R
      dst[di + 1] = si + 1 < src.length ? src[si + 1] : 0; // G
      dst[di + 2] = si + 2 < src.length ? src[si + 2] : 0; // B
      dst[di + 3] = 255;                               // A
    }
  }

  static void _renderMono8(
    Uint8List src,
    Uint8List dst,
    int w,
    int h,
    DicomHeader header,
  ) {
    final pixels = w * h;
    final invert = header.isMonochrome1;
    for (int i = 0; i < pixels; i++) {
      int v = i < src.length ? src[i] : 0;
      if (invert) v = 255 - v;
      final di = i * 4;
      dst[di] = v;
      dst[di + 1] = v;
      dst[di + 2] = v;
      dst[di + 3] = 255;
    }
  }

  /// Apply VOI LUT (windowing) on pre-calculated Hounsfield/modality values
  /// and write to dst RGBA buffer. Returns the effective (center, width).
  static (double center, double width) _applyWindowingToRgba({
    required Float64List values,
    required Uint8List dst,
    required bool invert,
    required double? overrideCenter,
    required double? overrideWidth,
    required double defaultCenter,
    required double defaultWidth,
    required double pixMin,
    required double pixMax,
  }) {
    double wc = overrideCenter ?? (defaultWidth > 0 ? defaultCenter : 0);
    double ww = overrideWidth ?? defaultWidth;

    final needAutoWindow = ww <= 0;
    if (needAutoWindow) {
      ww = (pixMax - pixMin).clamp(1, double.maxFinite);
      wc = pixMin + ww / 2;
    }

    final winLow = wc - ww / 2.0;
    final winHigh = wc + ww / 2.0;
    final pixels = values.length;

    for (int i = 0; i < pixels; i++) {
      final val = values[i];
      int v;
      if (val <= winLow) {
        v = 0;
      } else if (val >= winHigh) {
        v = 255;
      } else {
        v = ((val - winLow) / ww * 255.0).round().clamp(0, 255);
      }
      if (invert) v = 255 - v;
      final di = i * 4;
      dst[di] = v;
      dst[di + 1] = v;
      dst[di + 2] = v;
      dst[di + 3] = 255;
    }

    return (wc, ww);
  }

  static (double center, double width) _renderMono16(
    Uint8List src,
    Uint8List dst,
    int w,
    int h,
    DicomHeader header,
    double? overrideCenter,
    double? overrideWidth,
  ) {
    final pixels = w * h;
    final isSigned = header.isSigned;
    final bitsStored = header.bitsStored;
    final highBit = header.highBit;
    final invert = header.isMonochrome1;

    // Rescale parameters (Modality LUT)
    final intercept = header.rescaleIntercept ?? 0.0;
    final slope = header.rescaleSlope ?? 1.0;

    // Build a mask for stored bits
    final storedMask = (1 << bitsStored) - 1;
    final signBit = 1 << highBit;

    double pixMin = double.maxFinite;
    double pixMax = -double.maxFinite;

    // Parse all pixel values
    final values = Float64List(pixels);
    for (int i = 0; i < pixels; i++) {
      final si = i * 2;
      if (si + 1 >= src.length) {
        values[i] = 0;
        continue;
      }
      int raw = src[si] | (src[si + 1] << 8);
      // Mask to stored bits
      raw = raw & storedMask;
      // Sign extend if signed
      int pixelValue;
      if (isSigned && (raw & signBit) != 0) {
        pixelValue = raw - (1 << bitsStored);
      } else {
        pixelValue = raw;
      }
      // Apply modality LUT (rescale)
      final hounsfieldValue = pixelValue * slope + intercept;
      values[i] = hounsfieldValue;
      if (hounsfieldValue < pixMin) pixMin = hounsfieldValue;
      if (hounsfieldValue > pixMax) pixMax = hounsfieldValue;
    }

    return _applyWindowingToRgba(
      values: values,
      dst: dst,
      invert: invert,
      overrideCenter: overrideCenter,
      overrideWidth: overrideWidth,
      defaultCenter: header.windowCenter ?? 0,
      defaultWidth: header.windowWidth ?? 0,
      pixMin: pixMin,
      pixMax: pixMax,
    );
  }

  // --------------------------------------------------------------------------
  // JPEG Encapsulated rendering (Phase 3)
  // --------------------------------------------------------------------------

  static Future<DicomRenderResult> _renderJpegEncapsulated({
    required Uint8List fileBytes,
    required DicomHeader header,
    required int frameIndex,
    double? windowCenter,
    double? windowWidth,
  }) async {
    // Extract JPEG bytes for the requested frame
    final jpegBytes = extractEncapsulatedFrame(fileBytes, header, frameIndex);
    if (jpegBytes == null || jpegBytes.isEmpty) {
      throw DicomParseException(
          'Could not extract JPEG frame $frameIndex from encapsulated pixel data');
    }

    // Use Flutter's built-in image codec
    final codec = await ui.instantiateImageCodec(jpegBytes);
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;

    return DicomRenderResult(
      image: image,
      frameIndex: frameIndex,
      totalFrames: header.numberOfFrames,
    );
  }

  // --------------------------------------------------------------------------
  // JPEG 2000 rendering (Phase 4) — requires openjpeg_bridge native lib
  // --------------------------------------------------------------------------

  static Future<DicomRenderResult> _renderJpeg2000Encapsulated({
    required Uint8List fileBytes,
    required DicomHeader header,
    required int frameIndex,
    double? windowCenter,
    double? windowWidth,
  }) async {
    // Extract J2K bytes for the requested frame (same encapsulation as JPEG)
    final j2kBytes = extractEncapsulatedFrame(fileBytes, header, frameIndex);
    if (j2kBytes == null || j2kBytes.isEmpty) {
      throw DicomParseException(
          'Could not extract JPEG 2000 frame $frameIndex from encapsulated pixel data');
    }

    // Try native openjpeg decoder first
    if (j2k.isJpeg2000Available) {
      // 1. Try raw decoding to apply proper DICOM windowing/VOI LUT
      final raw = j2k.decodeJpeg2000Raw(j2kBytes);
      if (raw != null) {
        if (raw.numComps == 1 && raw.rawPixels != null) {
          final w = raw.width;
          final h = raw.height;
          final pixels = w * h;
          final rawPixels = raw.rawPixels!;
          final rgba = Uint8List(pixels * 4);

          final intercept = header.rescaleIntercept ?? 0.0;
          final slope = header.rescaleSlope ?? 1.0;
          final invert = header.isMonochrome1;

          double pixMin = double.maxFinite;
          double pixMax = -double.maxFinite;

          final values = Float64List(pixels);
          for (int i = 0; i < pixels; i++) {
            final val = rawPixels[i] * slope + intercept;
            values[i] = val;
            if (val < pixMin) pixMin = val;
            if (val > pixMax) pixMax = val;
          }

          final res = _applyWindowingToRgba(
            values: values,
            dst: rgba,
            invert: invert,
            overrideCenter: windowCenter,
            overrideWidth: windowWidth,
            defaultCenter: header.windowCenter ?? 0,
            defaultWidth: header.windowWidth ?? 0,
            pixMin: pixMin,
            pixMax: pixMax,
          );

          final image = await _createImage(rgba, w, h);
          return DicomRenderResult(
            image: image,
            frameIndex: frameIndex,
            totalFrames: header.numberOfFrames,
            windowCenter: res.$1,
            windowWidth: res.$2,
          );
        } else if (raw.rgba != null) {
          final image = await _createImage(raw.rgba!, raw.width, raw.height);
          return DicomRenderResult(
            image: image,
            frameIndex: frameIndex,
            totalFrames: header.numberOfFrames,
          );
        }
      }

      // Fallback: opj_decode_to_rgba (now includes dynamic min-max normalization)
      final decoded = j2k.decodeJpeg2000(j2kBytes);
      if (decoded != null) {
        final image = await _createImage(decoded.rgba, decoded.width, decoded.height);
        return DicomRenderResult(
          image: image,
          frameIndex: frameIndex,
          totalFrames: header.numberOfFrames,
        );
      }
    }

    // Fallback: try Flutter's codec (works if the platform has J2K support — rare)
    try {
      final codec = await ui.instantiateImageCodec(j2kBytes);
      final frameInfo = await codec.getNextFrame();
      return DicomRenderResult(
        image: frameInfo.image,
        frameIndex: frameIndex,
        totalFrames: header.numberOfFrames,
      );
    } catch (_) {
      throw UnsupportedError(
          'JPEG 2000 decoding is not available on this platform. '
          'The openjpeg_bridge native library was not found.');
    }
  }

  /// Parse encapsulated pixel data and return raw bytes for a specific frame.
  ///
  /// Encapsulated structure (PS3.5 §A.4):
  /// ```
  /// (7FE0,0010) OB undefined-length
  ///   Item (FFFE,E000) [Basic Offset Table — may be empty]
  ///   Item (FFFE,E000) [Frame 0 compressed bytes]
  ///   Item (FFFE,E000) [Frame 1 compressed bytes]
  ///   ...
  ///   Sequence Delimiter (FFFE,E0DD) 00000000
  /// ```
  static Uint8List? extractEncapsulatedFrame(
    Uint8List bytes,
    DicomHeader header,
    int frameIndex,
  ) {
    int pos = header.pixelDataOffset;

    // Helper to read uint32 LE
    int readU32(int offset) {
      if (offset + 4 > bytes.length) return 0;
      return (bytes[offset] |
              (bytes[offset + 1] << 8) |
              (bytes[offset + 2] << 16) |
              (bytes[offset + 3] << 24)) &
          0xFFFFFFFF;
    }

    int readU16(int offset) {
      if (offset + 2 > bytes.length) return 0;
      return bytes[offset] | (bytes[offset + 1] << 8);
    }

    bool isTag(int offset, int g, int e) {
      if (offset + 4 > bytes.length) return false;
      return readU16(offset) == g && readU16(offset + 2) == e;
    }

    // Skip Basic Offset Table (first item after pixel data tag)
    if (isTag(pos, 0xFFFE, 0xE000)) {
      final botLen = readU32(pos + 4);
      pos += 8 + botLen; // skip item tag(4) + length(4) + data
    }

    int frameCount = 0;
    while (pos + 8 <= bytes.length) {
      if (isTag(pos, 0xFFFE, 0xE0DD)) {
        // Sequence delimiter — end of encapsulated data
        break;
      }
      if (!isTag(pos, 0xFFFE, 0xE000)) {
        // Unexpected tag — stop
        break;
      }

      final itemLen = readU32(pos + 4);
      pos += 8; // skip item tag + length

      if (itemLen == 0xFFFFFFFF) {
        // Should not happen in valid DICOM, skip
        break;
      }

      if (frameCount == frameIndex) {
        // This is our frame
        final end = (pos + itemLen).clamp(0, bytes.length);
        return bytes.sublist(pos, end);
      }

      pos += itemLen;
      frameCount++;
    }

    return null;
  }

  // --------------------------------------------------------------------------
  // ui.Image creation
  // --------------------------------------------------------------------------

  static Future<ui.Image> _createImage(Uint8List rgba, int width, int height) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (image) => completer.complete(image),
    );
    return completer.future;
  }

  // --------------------------------------------------------------------------
  // Utility: compute auto-window for display
  // --------------------------------------------------------------------------

  /// Returns the effective window center and width to use for display.
  /// Combines header defaults, rescale parameters, and user overrides.
  static (double center, double width) effectiveWindow(
    DicomHeader header, {
    double? overrideCenter,
    double? overrideWidth,
  }) {
    double wc = overrideCenter ?? header.windowCenter ?? 127;
    double ww = overrideWidth ?? header.windowWidth ?? 256;
    if (ww <= 0) ww = 256;
    return (wc, ww);
  }

  /// Suggested initial window range based on modality.
  static WindowPreset? suggestPresetForModality(String? modality) {
    if (modality == null) return null;
    switch (modality.toUpperCase()) {
      case 'CT':
        return const WindowPreset(name: 'Soft Tissue', center: 40, width: 400);
      case 'MR':
        return null; // MRI varies too much; rely on header values
      case 'XR':
      case 'CR':
      case 'DX':
        return null; // Use header values
      default:
        return null;
    }
  }
}
