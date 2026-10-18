import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/step_parser.dart';
import 'package:vector_math/vector_math_64.dart';

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

  test('StepParser accurately triangulates keramida_300x420.step with B-spline wave', () {
    final file = File('C:/Users/KoTo/Dropbox/test_files/keramida_300x420.step');
    if (!file.existsSync()) return;

    final bytes = file.readAsBytesSync();
    final mesh = StepParser.parseFromBytes(bytes, name: 'keramida_300x420.step');
    print('Keramida triangles: ${mesh.triangles.length}, min: ${mesh.bounds.min}, max: ${mesh.bounds.max}');

    // Ensure the wave reaches ~30.4mm height and has smooth geometry
    expect(mesh.triangles.length, greaterThan(50));
    expect(mesh.bounds.max.z, greaterThan(25.0)); // The wave peaks at ~30.4 mm
    expect(mesh.bounds.max.x, closeTo(300.0, 1.0));
    expect(mesh.bounds.max.y, closeTo(420.0, 1.0));
  });

  test('StepParser accurately triangulates tondach_twiston9.step without false chords', () {
    final file = File('C:/Users/KoTo/Dropbox/test_files/tondach_twiston9.step');
    if (!file.existsSync()) return;

    final bytes = file.readAsBytesSync();
    final mesh = StepParser.parseFromBytes(bytes, name: 'tondach_twiston9.step');
    print('Tondach triangles: ${mesh.triangles.length}, min: ${mesh.bounds.min}, max: ${mesh.bounds.max}');

    // Let's inspect all 31 faces
    // We can add a debug loop

    expect(mesh.triangles.length, greaterThan(1800));
    expect(mesh.bounds.max.x, closeTo(300.0, 1.0));
    expect(mesh.bounds.max.y, closeTo(500.0, 1.0));
    expect(mesh.bounds.max.z, closeTo(23.9, 1.0));
    expect(mesh.bounds.min.z, closeTo(-33.2, 1.0));

    // Verify no skewed diagonal triangles across main body (spindle artifact)
    int skewedCount = 0;
    for (final t in mesh.triangles) {
      final dx01 = (t.v0.x - t.v1.x).abs();
      final dy01 = (t.v0.y - t.v1.y).abs();
      final dx02 = (t.v0.x - t.v2.x).abs();
      final dy02 = (t.v0.y - t.v2.y).abs();
      final dx12 = (t.v1.x - t.v2.x).abs();
      final dy12 = (t.v1.y - t.v2.y).abs();

      if ((dy01 > 300 || dy02 > 300 || dy12 > 300) &&
          (dx01 > 50 || dx02 > 50 || dx12 > 50)) {
        skewedCount++;
      }
    }
    expect(skewedCount, equals(0), reason: 'Spindle artifact triangles must be 0');

    // Verify both nail holes are open through-holes (not capped/covered)
    bool pointInTri2D(Vector2 p, Vector2 a, Vector2 b, Vector2 c) {
      final v0 = c - a;
      final v1 = b - a;
      final v2 = p - a;
      final dot00 = v0.dot(v0);
      final dot01 = v0.dot(v1);
      final dot02 = v0.dot(v2);
      final dot11 = v1.dot(v1);
      final dot12 = v1.dot(v2);
      final denom = dot00 * dot11 - dot01 * dot01;
      if (denom.abs() < 1e-8) return false;
      final invDenom = 1.0 / denom;
      final u = (dot11 * dot02 - dot01 * dot12) * invDenom;
      final v = (dot00 * dot12 - dot01 * dot02) * invDenom;
      return (u >= 0) && (v >= 0) && (u + v <= 1);
    }

    final h1 = Vector2(115.0, 486.0);
    final h2 = Vector2(185.0, 486.0);
    int cover1 = 0;
    int cover2 = 0;

    for (final t in mesh.triangles) {
      final minY = [t.v0.y, t.v1.y, t.v2.y].reduce((a, b) => a < b ? a : b);
      final maxY = [t.v0.y, t.v1.y, t.v2.y].reduce((a, b) => a > b ? a : b);
      if (minY >= 470.0 && maxY <= 501.0) {
        final a = Vector2(t.v0.x, t.v0.y);
        final b = Vector2(t.v1.x, t.v1.y);
        final c = Vector2(t.v2.x, t.v2.y);
        if (pointInTri2D(h1, a, b, c)) {
          print('Covering Hole 1: v0=${t.v0}, v1=${t.v1}, v2=${t.v2}');
          cover1++;
        }
        if (pointInTri2D(h2, a, b, c)) cover2++;
      }
    }
    expect(cover1, equals(0), reason: 'Hole 1 must not be covered');
    expect(cover2, equals(0), reason: 'Hole 2 must not be covered');

    // Verify both cylindrical nail holes are present and triangulated
    final hole1Tris = mesh.triangles.where((t) =>
        (t.v0.x - 115.0).abs() <= 5.0 && (t.v0.y - 486.0).abs() <= 5.0).toList();
    final hole2Tris = mesh.triangles.where((t) =>
        (t.v0.x - 185.0).abs() <= 5.0 && (t.v0.y - 486.0).abs() <= 5.0).toList();
    expect(hole1Tris.length, greaterThanOrEqualTo(50));
    expect(hole2Tris.length, greaterThanOrEqualTo(50));
  });
}






