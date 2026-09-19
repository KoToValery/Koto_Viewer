import 'dart:typed_data';

class Jpeg2000Result {
  final int width;
  final int height;
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
  final Int32List? rawPixels;
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

bool get isJpeg2000Available => false;

Jpeg2000Result? decodeJpeg2000(Uint8List compressedBytes) => null;

Jpeg2000RawResult? decodeJpeg2000Raw(Uint8List compressedBytes) => null;
