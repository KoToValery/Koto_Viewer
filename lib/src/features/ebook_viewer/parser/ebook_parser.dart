import 'dart:io';
import 'dart:typed_data';
import '../models/ebook_models.dart';
import 'epub_parser.dart';
import 'fb2_parser.dart';

class EbookParser {
  const EbookParser._();

  static Future<EbookBook> parseFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('E-Book file not found: $filePath');
    }
    final bytes = await file.readAsBytes();
    final fileName = filePath.split(Platform.pathSeparator).last;
    return parseFromBytes(bytes, fileName: fileName, filePath: filePath);
  }

  static EbookBook parseFromBytes(
    Uint8List bytes, {
    required String fileName,
    required String filePath,
  }) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.epub')) {
      return EpubParser.parse(bytes, fileName: fileName, filePath: filePath);
    } else if (lower.endsWith('.fb2') || lower.endsWith('.fb2.zip')) {
      return Fb2Parser.parse(bytes, fileName: fileName, filePath: filePath);
    } else if (lower.endsWith('.zip')) {
      // Check if it is a zipped EPUB or FB2
      try {
        return EpubParser.parse(bytes, fileName: fileName, filePath: filePath);
      } catch (_) {
        return Fb2Parser.parse(bytes, fileName: fileName, filePath: filePath);
      }
    }

    // Default try EPUB, then FB2
    try {
      return EpubParser.parse(bytes, fileName: fileName, filePath: filePath);
    } catch (_) {
      return Fb2Parser.parse(bytes, fileName: fileName, filePath: filePath);
    }
  }
}
