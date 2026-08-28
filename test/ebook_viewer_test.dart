import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/ebook_viewer/models/ebook_models.dart';
import 'package:kotoview/src/features/ebook_viewer/parser/epub_parser.dart';
import 'package:kotoview/src/features/ebook_viewer/parser/fb2_parser.dart';
import 'package:kotoview/src/features/ebook_viewer/parser/ebook_parser.dart';

void main() {
  group('E-Book Model & Identification Tests', () {
    test('PdfItem correctly identifies .epub, .fb2, and .fb2.zip', () {
      final epubItem = PdfItem(
        path: '/storage/books/War_and_Peace.epub',
        name: 'War_and_Peace.epub',
        sizeInBytes: 1024 * 1024,
        lastOpened: DateTime.now(),
      );
      expect(epubItem.fileType, equals(KotoFileType.epub));
      expect(epubItem.isEbook, isTrue);
      expect(epubItem.category, equals(FileCategory.documents));

      final fb2Item = PdfItem(
        path: '/storage/books/Pod_Igoto.fb2',
        name: 'Pod_Igoto.fb2',
        sizeInBytes: 500 * 1024,
        lastOpened: DateTime.now(),
      );
      expect(fb2Item.fileType, equals(KotoFileType.fb2));
      expect(fb2Item.isEbook, isTrue);

      final fb2ZipItem = PdfItem(
        path: '/storage/books/Nemili_Nedragi.fb2.zip',
        name: 'Nemili_Nedragi.fb2.zip',
        sizeInBytes: 250 * 1024,
        lastOpened: DateTime.now(),
      );
      expect(fb2ZipItem.fileType, equals(KotoFileType.fb2));
      expect(fb2ZipItem.isEbook, isTrue);
    });

    test('EbookSettings and theme properties', () {
      const settings = EbookSettings();
      expect(settings.fontSize, equals(17.0));
      expect(settings.themeMode, equals(EbookThemeMode.sepia));

      final darkSettings = settings.copyWith(themeMode: EbookThemeMode.dark, fontSize: 20.0);
      expect(darkSettings.themeMode, equals(EbookThemeMode.dark));
      expect(darkSettings.fontSize, equals(20.0));
    });
  });

  group('EPUB Parser Tests', () {
    test('Parses EPUB archive with OPF, metadata, and chapters in Cyrillic', () {
      final archive = Archive();

      // container.xml
      const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      archive.addFile(ArchiveFile('META-INF/container.xml', utf8.encode(containerXml).length, utf8.encode(containerXml)));

      // content.opf
      const opfXml = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Под игото</dc:title>
    <dc:creator>Иван Вазов</dc:creator>
    <dc:language>bg</dc:language>
    <dc:publisher>Български писател</dc:publisher>
    <dc:date>1894</dc:date>
  </metadata>
  <manifest>
    <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>''';
      archive.addFile(ArchiveFile('OEBPS/content.opf', utf8.encode(opfXml).length, utf8.encode(opfXml)));

      // chapter1.xhtml
      const ch1Xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Глава I. Гост</title></head>
<body>
  <h1>Глава I. Гост</h1>
  <p>Тая вечер чорбаджи Марко, гологлав, по халат, вечеряше с челядта си на двора.</p>
  <blockquote>— Жено, тури още малко сол в чорбата.</blockquote>
</body>
</html>''';
      archive.addFile(ArchiveFile('OEBPS/chapter1.xhtml', utf8.encode(ch1Xhtml).length, utf8.encode(ch1Xhtml)));

      // chapter2.xhtml
      const ch2Xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Глава II. Бурята</title></head>
<body>
  <h2>Глава II. Бурята</h2>
  <p>Нощта беше тъмна и ветровита над Бяла черква.</p>
</body>
</html>''';
      archive.addFile(ArchiveFile('OEBPS/chapter2.xhtml', utf8.encode(ch2Xhtml).length, utf8.encode(ch2Xhtml)));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final book = EpubParser.parse(zipBytes, fileName: 'Pod_Igoto.epub', filePath: '/test/Pod_Igoto.epub');

      expect(book.title, equals('Под игото'));
      expect(book.metadata.authors, contains('Иван Вазов'));
      expect(book.metadata.language, equals('bg'));
      expect(book.chapterCount, equals(2));
      expect(book.chapters[0].title, equals('Глава I. Гост'));
      expect(book.chapters[0].rawText, contains('Тая вечер чорбаджи Марко'));
      expect(book.chapters[1].title, equals('Глава II. Бурята'));
    });
  });

  group('FB2 Parser Tests', () {
    test('Parses FB2 XML structure with Cyrillic encoding and base64 cover', () {
      const fb2Xml = '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <genre>classic</genre>
      <author>
        <first-name>Христо</first-name>
        <last-name>Ботев</last-name>
      </author>
      <book-title>Стихотворения</book-title>
      <annotation>
        <p>Безсмъртните поеми на българския революционер.</p>
      </annotation>
      <date>1875</date>
      <coverpage>
        <image l:href="#cover.jpg"/>
      </coverpage>
      <lang>bg</lang>
    </title-info>
  </description>
  <body>
    <title><p>Христо Ботев — Стихотворения</p></title>
    <section>
      <title><p>Хаджи Димитър</p></title>
      <epigraph><p>„Настане вечер — месец изгрее...“</p></epigraph>
      <p>Жив е той, жив е! Там на Балкана,</p>
      <p>потънал в кърви лежи и пъшка,</p>
      <p>юнак с дълбока на гърди рана,</p>
      <p>юнак във младост и в сила мъжка.</p>
    </section>
  </body>
  <binary id="cover.jpg" content-type="image/jpeg">/9j/4AAQSkZJRg==</binary>
</FictionBook>''';

      final fb2Bytes = utf8.encode(fb2Xml);
      final book = Fb2Parser.parse(Uint8List.fromList(fb2Bytes), fileName: 'Botev.fb2', filePath: '/test/Botev.fb2');

      expect(book.title, equals('Стихотворения'));
      expect(book.metadata.authors, contains('Христо Ботев'));
      expect(book.metadata.coverBytes, isNotNull);
      expect(book.chapterCount, equals(1));
      expect(book.chapters[0].title, equals('Хаджи Димитър'));
      expect(book.chapters[0].rawText, contains('Жив е той, жив е!'));
    });
  });
}
