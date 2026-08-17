import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/pptx_viewer/models/pptx_models.dart';
import 'package:kotoview/src/features/pptx_viewer/parser/pptx_parser.dart';

void main() {
  group('PptxParser Tests', () {
    test('parses multi-slide PPTX zip archive with titles and bullet runs', () {
      final slide1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="2" name="Title 1"/>
          <p:nvPr><p:ph type="ctrTitle"/></p:nvPr>
        </p:nvSpPr>
        <p:txBody>
          <a:p>
            <a:r><a:t>Презентация на проекта KotoView</a:t></a:r>
          </a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Subtitle 2"/></p:nvSpPr>
        <p:txBody>
          <a:p>
            <a:r><a:t>Автор: Инж. Валери Котов</a:t></a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

      final slide2Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="2" name="Title 1"/>
          <p:nvPr><p:ph type="title"/></p:nvPr>
        </p:nvSpPr>
        <p:txBody>
          <a:p>
            <a:r><a:t>Основни модули и формати</a:t></a:r>
          </a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Content"/></p:nvSpPr>
        <p:txBody>
          <a:p>
            <a:pPr lvl="0"><a:buChar char="•"/></a:pPr>
            <a:r><a:rPr b="1"/><a:t>PDF, DXF, DWG</a:t></a:r>
            <a:r><a:t> - векторни чертежи</a:t></a:r>
          </a:p>
          <a:p>
            <a:pPr lvl="0"><a:buChar char="•"/></a:pPr>
            <a:r><a:t>PPT, PPTX, RTF, DOCX - документи</a:t></a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

      final archive = Archive();
      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slide1Xml.length, utf8.encode(slide1Xml)));
      archive.addFile(ArchiveFile('ppt/slides/slide2.xml', slide2Xml.length, utf8.encode(slide2Xml)));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final presentation = PptxParser.parse(zipBytes);

      expect(presentation.slideCount, 2);
      expect(presentation.slides[0].title, 'Презентация на проекта KotoView');
      expect(presentation.slides[0].shapes.length, 1);
      expect(presentation.slides[0].shapes[0].plainText, contains('Инж. Валери Котов'));

      expect(presentation.slides[1].title, 'Основни модули и формати');
      expect(presentation.slides[1].shapes.length, 1);
      expect(presentation.slides[1].shapes[0].paragraphs.length, 2);
      expect(presentation.slides[1].shapes[0].paragraphs[0].isBullet, true);
      expect(presentation.slides[1].shapes[0].paragraphs[0].plainText, 'PDF, DXF, DWG - векторни чертежи');
    });
  });
}
