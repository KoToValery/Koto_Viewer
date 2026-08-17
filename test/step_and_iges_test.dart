import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/step_parser.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/iges_parser.dart';

void main() {
  group('Stage 2: 3D File Type Identification Tests', () {
    test('PdfItem correctly identifies STEP and IGES 3D CAD files', () {
      final stepItem = PdfItem(
        path: '/storage/emulated/0/Download/bracket.step',
        name: 'bracket.step',
        sizeInBytes: 500000,
        lastOpened: DateTime.now(),
      );
      expect(stepItem.fileType, equals(KotoFileType.step));
      expect(stepItem.isStep, isTrue);
      expect(stepItem.is3d, isTrue);

      final stpItem = PdfItem(
        path: '/storage/emulated/0/Download/motor_mount.stp',
        name: 'motor_mount.stp',
        sizeInBytes: 300000,
        lastOpened: DateTime.now(),
      );
      expect(stpItem.fileType, equals(KotoFileType.step));
      expect(stpItem.is3d, isTrue);

      final igesItem = PdfItem(
        path: '/storage/emulated/0/Download/turbine_blade.iges',
        name: 'turbine_blade.iges',
        sizeInBytes: 800000,
        lastOpened: DateTime.now(),
      );
      expect(igesItem.fileType, equals(KotoFileType.iges));
      expect(igesItem.isIges, isTrue);
      expect(igesItem.is3d, isTrue);

      final igsItem = PdfItem(
        path: '/storage/emulated/0/Download/gear.igs',
        name: 'gear.igs',
        sizeInBytes: 400000,
        lastOpened: DateTime.now(),
      );
      expect(igsItem.fileType, equals(KotoFileType.iges));
      expect(igsItem.is3d, isTrue);
    });
  });

  group('STEP 3D Parser Tests', () {
    test('StepParser extracts CARTESIAN_POINT, POLY_LOOP, and triangulates 3D faces', () {
      const stepContent = '''ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('STEP Model'), '2;1');
FILE_NAME('cube.step', '2026-08-17', ('Author'), ('Org'), 'Processor', 'System', '');
FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));
ENDSEC;
DATA;
#10 = CARTESIAN_POINT('', (0.0, 0.0, 0.0));
#11 = CARTESIAN_POINT('', (10.0, 0.0, 0.0));
#12 = CARTESIAN_POINT('', (10.0, 10.0, 0.0));
#13 = CARTESIAN_POINT('', (0.0, 10.0, 0.0));
#14 = CARTESIAN_POINT('', (0.0, 0.0, 10.0));
#15 = CARTESIAN_POINT('', (10.0, 0.0, 10.0));
#16 = CARTESIAN_POINT('', (10.0, 10.0, 10.0));
#17 = CARTESIAN_POINT('', (0.0, 10.0, 10.0));

#20 = VERTEX_POINT('', #10);
#21 = VERTEX_POINT('', #11);
#22 = VERTEX_POINT('', #12);
#23 = VERTEX_POINT('', #13);

#30 = POLY_LOOP('', (#10, #11, #12, #13));
#31 = POLY_LOOP('', (#14, #15, #16, #17));
#32 = POLY_LOOP('', (#10, #11, #15, #14));
#33 = POLY_LOOP('', (#12, #13, #17, #16));

#40 = FACE_OUTER_BOUND('', #30, .T.);
#50 = ADVANCED_FACE('', (#40), #60, .T.);
#60 = CLOSED_SHELL('', (#50));
#70 = MANIFOLD_SOLID_BREP('CUBE', #60);
ENDSEC;
END-ISO-10303-21;
''';

      final bytes = Uint8List.fromList(utf8.encode(stepContent));
      final mesh = StepParser.parseFromBytes(bytes, name: 'cube.step');

      expect(mesh.triangles.length, equals(8)); // 4 quad poly loops * 2 triangles each = 8 triangles
      expect(mesh.bounds.sizeX, closeTo(10.0, 0.01));
      expect(mesh.bounds.sizeY, closeTo(10.0, 0.01));
      expect(mesh.bounds.sizeZ, closeTo(10.0, 0.01));
    });
  });

  group('IGES 3D Parser Tests', () {
    test('IgesParser parses 80-column records and extracts 3D triangles', () {
      // Create a valid 80-column formatted IGES snippet with D and P sections
      final d1 = '     106       1       0       0       0       0       0       000010001D      1';
      final d2 = '     106       0       1       1       0                               0D      2';
      final p1 = '106, 1, 3, 0.0, 0.0, 0.0, 20.0, 0.0, 0.0, 0.0, 30.0, 0.0;             1P      1';

      final igesContent = '$d1\n$d2\n$p1\n';
      final bytes = Uint8List.fromList(utf8.encode(igesContent));
      final mesh = IgesParser.parseFromBytes(bytes, name: 'triangle.iges');

      expect(mesh.triangles.length, equals(1));
      expect(mesh.bounds.sizeX, closeTo(20.0, 0.01));
      expect(mesh.bounds.sizeY, closeTo(30.0, 0.01));
    });
  });
}
