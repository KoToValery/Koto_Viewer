import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';

void main() {
  group('Smart Category Classification Tests', () {
    test('PdfItem assigns correct FileCategory for all supported formats', () {
      final now = DateTime.now();

      // 2D CAD
      final dxf = PdfItem(path: '/a/drawing.dxf', name: 'drawing.dxf', sizeInBytes: 100, lastOpened: now);
      final plt = PdfItem(path: '/a/plot.plt', name: 'plot.plt', sizeInBytes: 100, lastOpened: now);
      final svg = PdfItem(path: '/a/vector.svg', name: 'vector.svg', sizeInBytes: 100, lastOpened: now);
      final eps = PdfItem(path: '/a/postscript.eps', name: 'postscript.eps', sizeInBytes: 100, lastOpened: now);
      expect(dxf.category, equals(FileCategory.cad2d));
      expect(plt.category, equals(FileCategory.cad2d));
      expect(svg.category, equals(FileCategory.cad2d));
      expect(eps.category, equals(FileCategory.cad2d));

      // 3D CAD
      final step = PdfItem(path: '/a/part.step', name: 'part.step', sizeInBytes: 100, lastOpened: now);
      final iges = PdfItem(path: '/a/turbine.iges', name: 'turbine.iges', sizeInBytes: 100, lastOpened: now);
      final stl = PdfItem(path: '/a/mesh.stl', name: 'mesh.stl', sizeInBytes: 100, lastOpened: now);
      final glb = PdfItem(path: '/a/model.glb', name: 'model.glb', sizeInBytes: 100, lastOpened: now);
      expect(step.category, equals(FileCategory.cad3d));
      expect(iges.category, equals(FileCategory.cad3d));
      expect(stl.category, equals(FileCategory.cad3d));
      expect(glb.category, equals(FileCategory.cad3d));

      // PCB
      final kicad = PdfItem(path: '/a/board.kicad_pcb', name: 'board.kicad_pcb', sizeInBytes: 100, lastOpened: now);
      final gbr = PdfItem(path: '/a/layer.gtl', name: 'layer.gtl', sizeInBytes: 100, lastOpened: now);
      final drl = PdfItem(path: '/a/holes.drl', name: 'holes.drl', sizeInBytes: 100, lastOpened: now);
      expect(kicad.category, equals(FileCategory.pcb));
      expect(gbr.category, equals(FileCategory.pcb));
      expect(drl.category, equals(FileCategory.pcb));

      // Documents
      final pdf = PdfItem(path: '/a/doc.pdf', name: 'doc.pdf', sizeInBytes: 100, lastOpened: now);
      final docx = PdfItem(path: '/a/word.docx', name: 'word.docx', sizeInBytes: 100, lastOpened: now);
      final pptx = PdfItem(path: '/a/slides.pptx', name: 'slides.pptx', sizeInBytes: 100, lastOpened: now);
      final ppt = PdfItem(path: '/a/old.ppt', name: 'old.ppt', sizeInBytes: 100, lastOpened: now);
      final rtf = PdfItem(path: '/a/memo.rtf', name: 'memo.rtf', sizeInBytes: 100, lastOpened: now);
      final xlsx = PdfItem(path: '/a/table.xlsx', name: 'table.xlsx', sizeInBytes: 100, lastOpened: now);
      final txt = PdfItem(path: '/a/readme.txt', name: 'readme.txt', sizeInBytes: 100, lastOpened: now);
      final md = PdfItem(path: '/a/notes.md', name: 'notes.md', sizeInBytes: 100, lastOpened: now);
      expect(pdf.category, equals(FileCategory.documents));
      expect(docx.category, equals(FileCategory.documents));
      expect(pptx.category, equals(FileCategory.documents));
      expect(pptx.isPresentation, true);
      expect(ppt.category, equals(FileCategory.documents));
      expect(ppt.isPresentation, true);
      expect(rtf.category, equals(FileCategory.documents));
      expect(rtf.isRtf, true);
      expect(xlsx.category, equals(FileCategory.documents));
      expect(txt.category, equals(FileCategory.documents));
      expect(md.category, equals(FileCategory.documents));
    });

    test('Category filtering and search filtering behaves accurately', () {
      final now = DateTime.now();
      final items = [
        PdfItem(path: '/a/site_plan.dxf', name: 'site_plan.dxf', sizeInBytes: 100, lastOpened: now),
        PdfItem(path: '/a/engine.step', name: 'engine.step', sizeInBytes: 100, lastOpened: now),
        PdfItem(path: '/a/mainboard.kicad_pcb', name: 'mainboard.kicad_pcb', sizeInBytes: 100, lastOpened: now),
        PdfItem(path: '/a/invoice.pdf', name: 'invoice.pdf', sizeInBytes: 100, lastOpened: now),
        PdfItem(path: '/a/engine_spec.pdf', name: 'engine_spec.pdf', sizeInBytes: 100, lastOpened: now),
      ];

      // Filter by Category CAD 3D
      final cad3dFiles = items.where((f) => f.category == FileCategory.cad3d).toList();
      expect(cad3dFiles.length, equals(1));
      expect(cad3dFiles.first.name, equals('engine.step'));

      // Filter by Category Documents
      final docFiles = items.where((f) => f.category == FileCategory.documents).toList();
      expect(docFiles.length, equals(2));

      // Search keyword 'engine'
      final searchFiles = items.where((f) => f.name.toLowerCase().contains('engine')).toList();
      expect(searchFiles.length, equals(2)); // engine.step and engine_spec.pdf
    });
  });
}
