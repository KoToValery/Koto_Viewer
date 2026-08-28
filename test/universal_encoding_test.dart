import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

void main() {
  group('UniversalEncodingService Multi-Language & International Script Tests', () {
    test('Decodes UTF-8 with and without BOM', () {
      final utf8NoBom = [0xD0, 0x9F, 0xD0, 0xB0, 0xD1, 0x80, 0xD1, 0x82, 0xD0, 0xB5, 0xD1, 0x80]; // Партер
      final result1 = UniversalEncodingService.decodeBytesWithEncoding(utf8NoBom);
      expect(result1.text, 'Партер');
      expect(result1.encodingName, 'UTF-8');

      final utf8Bom = [0xEF, 0xBB, 0xBF, 0xD0, 0x9F, 0xD0, 0xB0, 0xD1, 0x80, 0xD1, 0x82, 0xD0, 0xB5, 0xD1, 0x80];
      final result2 = UniversalEncodingService.decodeBytesWithEncoding(utf8Bom);
      expect(result2.text, 'Партер');
      expect(result2.encodingName, 'UTF-8 (BOM)');
    });

    test('Decodes UTF-16 LE and BE with and without BOM', () {
      // "CAD" in UTF-16 LE: 0x43 0x00, 0x41 0x00, 0x44 0x00
      final utf16Le = [0xFF, 0xFE, 0x43, 0x00, 0x41, 0x00, 0x44, 0x00];
      final res1 = UniversalEncodingService.decodeBytesWithEncoding(utf16Le);
      expect(res1.text, 'CAD');
      expect(res1.encodingName, contains('UTF-16 LE'));

      final utf16Be = [0xFE, 0xFF, 0x00, 0x43, 0x00, 0x41, 0x00, 0x44];
      final res2 = UniversalEncodingService.decodeBytesWithEncoding(utf16Be);
      expect(res2.text, 'CAD');
      expect(res2.encodingName, contains('UTF-16 BE'));
    });

    test('Decodes Cyrillic (Windows-1251): Bulgarian, Russian, Serbian, Ukrainian', () {
      // "Партер" in Windows-1251: 0xCF, 0xE0, 0xF0, 0xF2, 0xE5, 0xF0
      final bgBytes = [0xCF, 0xE0, 0xF0, 0xF2, 0xE5, 0xF0];
      final res = UniversalEncodingService.decodeBytesWithEncoding(bgBytes);
      expect(res.text, 'Партер');
      expect(res.encodingName, contains('1251'));
    });

    test('Decodes Greek (Windows-1253): Greek Cadastre & Surveying', () {
      // "Ελληνικά" in Windows-1253:
      // Ε (0xC5), λ (0xEB), λ (0xEB), η (0xE7), ν (0xED), ι (0xE9), κ (0xEA), ά (0xDC)
      final greekBytes = [0xC5, 0xEB, 0xEB, 0xE7, 0xED, 0xE9, 0xEA, 0xDC];
      final res = UniversalEncodingService.decodeBytesWithEncoding(greekBytes);
      expect(res.text, 'Ελληνικά');
      expect(res.encodingName, contains('1253'));
    });

    test('Decodes Central European (Windows-1250): Polish, Czech, Slovak, Hungarian, Romanian', () {
      // Polish: Ściana (0x8C, 0x63, 0x69, 0x61, 0x6E, 0x61)
      final polishBytes = [0x8C, 0x63, 0x69, 0x61, 0x6E, 0x61];
      final res1 = UniversalEncodingService.decodeBytesWithEncoding(polishBytes);
      expect(res1.text, 'Ściana');
      expect(res1.encodingName, contains('1250'));

      // Czech: Přízemí (0x50, 0xF8, 0xED, 0x7A, 0x65, 0x6D, 0xED)
      final czechText = UniversalEncodingService.decodeWindows1250([0x50, 0xF8, 0xED, 0x7A, 0x65, 0x6D, 0xED]);
      expect(czechText, 'Přízemí');
    });

    test('Decodes Turkish (Windows-1254)', () {
      // "Giriş" in Turkish CP1254: 0x47, 0x69, 0x72, 0x69, 0xFE
      final turkishText = UniversalEncodingService.decodeWindows1254([0x47, 0x69, 0x72, 0x69, 0xFE]);
      expect(turkishText, 'Giriş');
    });

    test('Decodes Western European (Windows-1252): German, French, Spanish, Nordic', () {
      // German: "Träger äöüß"
      final deText = UniversalEncodingService.decodeWindows1252([0x54, 0x72, 0xE4, 0x67, 0x65, 0x72, 0x20, 0xE4, 0xF6, 0xFC, 0xDF]);
      expect(deText, 'Träger äöüß');

      // French: "Fenêtre"
      final frText = UniversalEncodingService.decodeWindows1252([0x46, 0x65, 0x6E, 0xEA, 0x74, 0x72, 0x65]);
      expect(frText, 'Fenêtre');
    });

    test('Universal ISO 10303-21 String Decoder (IFC & STEP) across global alphabets', () {
      // 1. Cyrillic: \X2\041F04300440044204350440\X0\ -> Партер
      expect(UniversalEncodingService.decodeIso10303String(r'\X2\041F04300440044204350440\X0\'), 'Партер');

      // 2. Greek: \X2\039503BB03BB03B703BD03B903BA03AC\X0\ -> Ελληνικά
      expect(UniversalEncodingService.decodeIso10303String(r'\X2\039503BB03BB03B703BD03B903BA03AC\X0\'), 'Ελληνικά');

      // 3. Polish: \X2\015A010701050144017C\X0\ -> Śćąńż
      expect(UniversalEncodingService.decodeIso10303String(r'\X2\015A010701050144017C\X0\'), 'Śćąńż');

      // 4. German: \X2\00E400F600FC00DF\X0\ -> äöüß
      expect(UniversalEncodingService.decodeIso10303String(r'\X2\00E400F600FC00DF\X0\'), 'äöüß');

      // 5. CJK Chinese: \X2\5EFA7B51\X0\ -> 建筑 (Architecture)
      expect(UniversalEncodingService.decodeIso10303String(r'\X2\5EFA7B51\X0\'), '建筑');

      // 6. CJK Japanese: \X2\8A2D8A08\X0\ -> 設計 (Design)
      expect(UniversalEncodingService.decodeIso10303String(r'\X2\8A2D8A08\X0\'), '設計');

      // 7. Arabic: \X2\06450639064506270631\X0\ -> معمار (Architect)
      expect(UniversalEncodingService.decodeIso10303String(r'\X2\06450639064506270631\X0\'), 'معمار');

      // 8. Escaped single quotes
      expect(UniversalEncodingService.decodeIso10303String(r"Architect''s Villa"), "Architect's Villa");
    });

    test('Universal CAD Text Decoder for AutoCAD DXF & DWG', () {
      // 1. Unicode \U+0395\U+03BB\U+03BB\U+03B7\U+03BD\U+03B9\U+03BA\U+03AC -> Ελληνικά
      expect(UniversalEncodingService.decodeCadString(r'\U+0395\U+03BB\U+03BB\U+03B7\U+03BD\U+03B9\U+03BA\U+03AC'), 'Ελληνικά');

      // 2. AutoCAD MIF Cyrillic: \M+5C0\M+5F0\M+5F5 -> Арх
      expect(UniversalEncodingService.decodeCadString(r'\M+5C0\M+5F0\M+5F5'), 'Арх');

      // 3. AutoCAD MIF Greek: \M+7C5\M+7EB\M+7EB\M+7E7\M+7ED\M+7E9\M+7EA\M+7DC -> Ελληνικά
      expect(UniversalEncodingService.decodeCadString(r'\M+7C5\M+7EB\M+7EB\M+7E7\M+7ED\M+7E9\M+7EA\M+7DC'), 'Ελληνικά');

      // 4. CAD symbols & decimal Cyrillic
      expect(UniversalEncodingService.decodeCadString(r'%%c150 %%p0.05 %%192%%193'), '⌀150 ±0.05 АБ');
    });

    test('Repairs Latin-1 Mojibake into clean text', () {
      // Double-encoded UTF-8: "ÐÐ°Ñ€Ñ‚ÐµÑ€" -> "Партер"
      expect(UniversalEncodingService.repairDoubleEncodedUtf8('ÐÐ°Ñ€Ñ‚ÐµÑ€'), 'Партер');

      // Misinterpreted Latin-1 Cyrillic: "Àðõèòåêòóðà" -> "Архитектура"
      expect(UniversalEncodingService.repairMojibake('Àðõèòåêòóðà'), 'Архитектура');
    });
  });
}
