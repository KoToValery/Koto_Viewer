import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/step_parser.dart';

void main() {
  test('StepParser parses PCB board solids and surfaces', () {
    const stepContent = '''ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('PCB Model'),'2;1');
FILE_NAME('board.step','2025-01-01',('User'),(''),'','','');
FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));
ENDSEC;
DATA;
#1 = CARTESIAN_POINT('',(0.0,0.0,0.0));
#2 = DIRECTION('',(0.0,0.0,1.0));
#3 = DIRECTION('',(1.0,0.0,0.0));
#4 = AXIS2_PLACEMENT_3D('',#1,#2,#3);
#10 = CARTESIAN_POINT('',(-20.0,-20.0,0.0));
#11 = CARTESIAN_POINT('',(20.0,-20.0,0.0));
#12 = CARTESIAN_POINT('',(20.0,20.0,0.0));
#13 = CARTESIAN_POINT('',(-20.0,20.0,0.0));
#20 = VERTEX_POINT('',#10);
#21 = VERTEX_POINT('',#11);
#22 = VERTEX_POINT('',#12);
#23 = VERTEX_POINT('',#13);
#30 = LINE('',#10,#3);
#40 = EDGE_CURVE('',#20,#21,#30,.T.);
#41 = EDGE_CURVE('',#21,#22,#30,.T.);
#42 = EDGE_CURVE('',#22,#23,#30,.T.);
#43 = EDGE_CURVE('',#23,#20,#30,.T.);
#50 = ORIENTED_EDGE('',*,*,#40,.T.);
#51 = ORIENTED_EDGE('',*,*,#41,.T.);
#52 = ORIENTED_EDGE('',*,*,#42,.T.);
#53 = ORIENTED_EDGE('',*,*,#43,.T.);
#60 = EDGE_LOOP('',(#50,#51,#52,#53));
#70 = FACE_OUTER_BOUND('',#60,.T.);
#80 = PLANE('',#4);
#90 = ADVANCED_FACE('PCB_SURFACE',
  (#70),
  #80,.T.);
#100 = CLOSED_SHELL('',(#90));
#110 = MANIFOLD_SOLID_BREP('Board',#100);
#120 = ADVANCED_BREP_SHAPE_REPRESENTATION('BoardRep',(#4,#110),#4);
ENDSEC;
END-ISO-10303-21;''';

    final mesh = StepParser.parseFromBytes(Uint8List.fromList(stepContent.codeUnits), name: 'test_board.step');
    expect(mesh.triangles.length, greaterThanOrEqualTo(2));
  });

  test('StepParser on real Proteus STEP if available', () {
    final path = 'C:/Users/Creator/Downloads/Files_for_KOKO/Converter_0_2_5to_4_20ma.STEP';
    final file = File(path);
    if (!file.existsSync()) return;

    final bytes = file.readAsBytesSync();
    final mesh = StepParser.parseFromBytes(bytes, name: 'Converter.step');
    expect(mesh.triangles.length, greaterThan(5000));
  });
}
