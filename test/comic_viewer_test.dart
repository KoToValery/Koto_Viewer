import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/comic_viewer/models/comic_models.dart';
import 'package:kotoview/src/features/comic_viewer/parser/comic_parser.dart';

void main() {
  group('Comic Book Model & File Identification Tests', () {
    test('PdfItem correctly identifies .cbz, .cbr, and .cbt files', () {
      final cbzItem = PdfItem(
        path: '/storage/comics/Batman_Issue_01.cbz',
        name: 'Batman_Issue_01.cbz',
        sizeInBytes: 1024 * 1024,
        lastOpened: DateTime.now(),
      );
      expect(cbzItem.fileType, equals(KotoFileType.cbz));
      expect(cbzItem.isComic, isTrue);
      expect(cbzItem.category, equals(FileCategory.documents));

      final cbrItem = PdfItem(
        path: '/storage/comics/SpiderMan.CBR',
        name: 'SpiderMan.CBR',
        sizeInBytes: 2048,
        lastOpened: DateTime.now(),
      );
      expect(cbrItem.fileType, equals(KotoFileType.cbr));
      expect(cbrItem.isComic, isTrue);

      final cbtItem = PdfItem(
        path: '/storage/comics/OnePiece.cbt',
        name: 'OnePiece.cbt',
        sizeInBytes: 4096,
        lastOpened: DateTime.now(),
      );
      expect(cbtItem.fileType, equals(KotoFileType.cbt));
      expect(cbtItem.isComic, isTrue);
    });

    test('ComicReadingMode labels and shortLabels', () {
      expect(ComicReadingMode.leftToRight.shortLabel, equals('LTR'));
      expect(ComicReadingMode.rightToLeft.shortLabel, equals('Manga'));
      expect(ComicReadingMode.verticalContinuous.shortLabel, equals('Webtoon'));
    });
  });

  group('ComicParser Archive & Metadata Tests', () {
    test('Parses CBZ archive with natural page ordering and skips hidden files', () {
      final archive = Archive();

      // Add dummy files out of order
      final dummyPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      archive.addFile(ArchiveFile('page_10.png', dummyPng.length, dummyPng));
      archive.addFile(ArchiveFile('page_2.png', dummyPng.length, dummyPng));
      archive.addFile(ArchiveFile('page_1.png', dummyPng.length, dummyPng));
      archive.addFile(ArchiveFile('__MACOSX/._page_1.png', 4, [0, 0, 0, 0]));
      archive.addFile(ArchiveFile('.DS_Store', 4, [0, 0, 0, 0]));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final comic = ComicParser.parseFromBytes(
        zipBytes,
        fileName: 'Hero_Adventures_01.cbz',
        filePath: '/test/Hero_Adventures_01.cbz',
      );

      expect(comic.title, equals('Hero Adventures 01'));
      expect(comic.pageCount, equals(3));
      expect(comic.pages[0].fileName, equals('page_1.png'));
      expect(comic.pages[1].fileName, equals('page_2.png'));
      expect(comic.pages[2].fileName, equals('page_10.png'));
    });

    test('Parses ComicInfo.xml metadata correctly including Manga mode flag', () {
      final archive = Archive();

      const comicInfoXml = '''<?xml version="1.0"?>
<ComicInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Title>The Final Battle</Title>
  <Series>Cyber Samurai</Series>
  <Number>42</Number>
  <Summary>The heroes confront the cyber dragon in Neo Tokyo.</Summary>
  <Writer>Stan Lee</Writer>
  <Penciller>Jack Kirby</Penciller>
  <Genre>Sci-Fi / Action</Genre>
  <Year>2026</Year>
  <Month>8</Month>
  <Publisher>Koto Comics</Publisher>
  <Manga>YesAndRightToLeft</Manga>
</ComicInfo>''';

      final dummyJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      archive.addFile(ArchiveFile('ComicInfo.xml', utf8.encode(comicInfoXml).length, utf8.encode(comicInfoXml)));
      archive.addFile(ArchiveFile('001.jpg', dummyJpg.length, dummyJpg));
      archive.addFile(ArchiveFile('002.jpg', dummyJpg.length, dummyJpg));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final comic = ComicParser.parseFromBytes(
        zipBytes,
        fileName: 'Cyber_Samurai_42.cbz',
        filePath: '/test/Cyber_Samurai_42.cbz',
      );

      expect(comic.title, equals('The Final Battle'));
      expect(comic.metadata.series, equals('Cyber Samurai'));
      expect(comic.metadata.number, equals('42'));
      expect(comic.metadata.writer, equals('Stan Lee'));
      expect(comic.metadata.penciller, equals('Jack Kirby'));
      expect(comic.metadata.year, equals(2026));
      expect(comic.metadata.month, equals(8));
      expect(comic.metadata.publisher, equals('Koto Comics'));
      expect(comic.metadata.isManga, isTrue);
      expect(comic.pageCount, equals(2));
    });
  });
}
