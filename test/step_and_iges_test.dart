import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/geometry/nurbs_surface.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
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

  group('NURBS Mathematical Surface Evaluator Tests', () {
    test('NurbsSurface evaluates bilinear planar patch with exact midpoint and normal', () {
      final controlPoints = [
        [const Vector3(0, 0, 0), const Vector3(0, 20, 0)],
        [const Vector3(10, 0, 0), const Vector3(10, 20, 0)],
      ];

      final nurbs = NurbsSurface(
        degreeU: 1,
        degreeV: 1,
        knotsU: [0.0, 0.0, 1.0, 1.0],
        knotsV: [0.0, 0.0, 1.0, 1.0],
        controlPoints: controlPoints,
      );

      final mid = nurbs.evaluate(0.5, 0.5);
      expect(mid.x, closeTo(5.0, 1e-4));
      expect(mid.y, closeTo(10.0, 1e-4));
      expect(mid.z, closeTo(0.0, 1e-4));

      final norm = nurbs.evaluateNormal(0.5, 0.5);
      expect(norm.z.abs(), closeTo(1.0, 1e-3));

      final triangles = nurbs.tessellate(samplesU: 4, samplesV: 4);
      expect(triangles.length, equals(32)); // 4x4 quad grid = 16 quads * 2 = 32 triangles
      final mesh = Mesh3D(name: 'bilinear', triangles: triangles);
      expect(mesh.bounds.sizeX, closeTo(10.0, 0.01));
      expect(mesh.bounds.sizeY, closeTo(20.0, 0.01));
      expect(mesh.surfaceArea, closeTo(200.0, 1.0));
    });

    test('NurbsSurface evaluates rational weights pulling surface towards weighted control point', () {
      // 3x3 quadratic patch with center control point raised
      final cp = [
        [const Vector3(0, 0, 0), const Vector3(0, 10, 0), const Vector3(0, 20, 0)],
        [const Vector3(10, 0, 0), const Vector3(10, 10, 10), const Vector3(10, 20, 0)],
        [const Vector3(20, 0, 0), const Vector3(20, 10, 0), const Vector3(20, 20, 0)],
      ];
      final knots = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0];

      // Polynomial surface (all weights = 1.0)
      final polyNurbs = NurbsSurface(
        degreeU: 2,
        degreeV: 2,
        knotsU: knots,
        knotsV: knots,
        controlPoints: cp,
      );
      final pMidPoly = polyNurbs.evaluate(0.5, 0.5);

      // Rational surface with center weight = 10.0
      final rationalWeights = [
        [1.0, 1.0, 1.0],
        [1.0, 10.0, 1.0],
        [1.0, 1.0, 1.0],
      ];
      final ratNurbs = NurbsSurface(
        degreeU: 2,
        degreeV: 2,
        knotsU: knots,
        knotsV: knots,
        controlPoints: cp,
        weights: rationalWeights,
      );
      final pMidRat = ratNurbs.evaluate(0.5, 0.5);

      // Higher center weight pulls Z higher towards control point Z=10
      expect(pMidRat.z, greaterThan(pMidPoly.z));
      expect(pMidRat.x, closeTo(10.0, 1e-4));
      expect(pMidRat.y, closeTo(10.0, 1e-4));
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

    test('StepParser evaluates B_SPLINE_SURFACE_WITH_KNOTS without geometry deformation', () {
      const stepNurbs = '''ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('STEP NURBS Surface'), '2;1');
FILE_NAME('curved_sheet.step', '2026-09-13', ('Author'), ('Org'), 'Processor', 'System', '');
FILE_SCHEMA(('CONFIG_CONTROL_DESIGN'));
ENDSEC;
DATA;
#10 = CARTESIAN_POINT('', (0.0, 0.0, 0.0));
#11 = CARTESIAN_POINT('', (10.0, 0.0, 5.0));
#12 = CARTESIAN_POINT('', (20.0, 0.0, 0.0));

#20 = CARTESIAN_POINT('', (0.0, 15.0, 0.0));
#21 = CARTESIAN_POINT('', (10.0, 15.0, 8.0));
#22 = CARTESIAN_POINT('', (20.0, 15.0, 0.0));

#30 = CARTESIAN_POINT('', (0.0, 30.0, 0.0));
#31 = CARTESIAN_POINT('', (10.0, 30.0, 5.0));
#32 = CARTESIAN_POINT('', (20.0, 30.0, 0.0));

#100 = B_SPLINE_SURFACE_WITH_KNOTS('ROOF_PATCH', 2, 2, (
  (#10, #11, #12),
  (#20, #21, #22),
  (#30, #31, #32)
), .UNSPECIFIED., .F., .F., .F., (3, 3), (3, 3), (0.0, 1.0), (0.0, 1.0), .UNSPECIFIED.);
#110 = ADVANCED_FACE('', (), #100, .T.);
ENDSEC;
END-ISO-10303-21;
''';

      final bytes = Uint8List.fromList(utf8.encode(stepNurbs));
      final mesh = StepParser.parseFromBytes(bytes, name: 'curved_sheet.step');

      expect(mesh.triangles, isNotEmpty);
      expect(mesh.bounds.sizeX, closeTo(20.0, 0.1));
      expect(mesh.bounds.sizeY, closeTo(30.0, 0.1));
      expect(mesh.bounds.sizeZ, greaterThan(2.0)); // Surface is curved upwards in Z
      expect(mesh.surfaceArea, greaterThan(600.0));
    });

    test('StepParser parses complex entity instances with RATIONAL_B_SPLINE_SURFACE', () {
      const stepComplex = '''ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('Complex NURBS'), '2;1');
FILE_NAME('complex.step', '2026-09-13', ('Author'), ('Org'), 'Processor', 'System', '');
FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));
ENDSEC;
DATA;
#1 = CARTESIAN_POINT('', (0.0, 0.0, 0.0));
#2 = CARTESIAN_POINT('', (10.0, 0.0, 0.0));
#3 = CARTESIAN_POINT('', (0.0, 10.0, 0.0));
#4 = CARTESIAN_POINT('', (10.0, 10.0, 0.0));

#50 = (
  BOUNDED_SURFACE()
  B_SPLINE_SURFACE(1, 1, ((#1, #2), (#3, #4)), .UNSPECIFIED., .F., .F., .F.)
  B_SPLINE_SURFACE_WITH_KNOTS((2, 2), (2, 2), (0.0, 1.0), (0.0, 1.0), .UNSPECIFIED.)
  GEOMETRIC_REPRESENTATION_ITEM()
  RATIONAL_B_SPLINE_SURFACE(((1.0, 1.0), (1.0, 1.0)))
  REPRESENTATION_ITEM('COMPLEX_SURF')
  SURFACE()
);
ENDSEC;
END-ISO-10303-21;
''';

      final bytes = Uint8List.fromList(utf8.encode(stepComplex));
      final mesh = StepParser.parseFromBytes(bytes, name: 'complex.step');

      expect(mesh.triangles, isNotEmpty);
      expect(mesh.bounds.sizeX, closeTo(10.0, 0.1));
      expect(mesh.bounds.sizeY, closeTo(10.0, 0.1));
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

    test('IgesParser evaluates Entity 128 (Rational B-Spline Surface) with exact dimensions', () {
      // IGES Entity 128:
      // K1=1, K2=1, M1=1, M2=1 (bilinear: 2x2 control points, degree 1x1)
      // PROP1..5 = 0, 0, 0, 0, 0
      // Knots u (4 values): 0.0, 0.0, 1.0, 1.0
      // Knots v (4 values): 0.0, 0.0, 1.0, 1.0
      // Weights (4 values): 1.0, 1.0, 1.0, 1.0
      // Control points (12 values): (0,0,0), (25,0,0), (0,40,0), (25,40,0)
      // Bounds (4 values): 0.0, 1.0, 0.0, 1.0
      final d1 = '     128       1       0       0       0       0       0       000010001D      1';
      final d2 = '     128       0       1       1       0                               0D      2';
      final p1 = '128, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1P      1';
      final p2 = '1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 25.0, 0.0, 0.0, 0.0, 40.0, 0.0,     1P      2';
      final p3 = '25.0, 40.0, 0.0, 0.0, 1.0, 0.0, 1.0;                                   1P      3';

      final igesContent = '$d1\n$d2\n$p1\n$p2\n$p3\n';
      final bytes = Uint8List.fromList(utf8.encode(igesContent));
      final mesh = IgesParser.parseFromBytes(bytes, name: 'nurbs.iges');

      expect(mesh.triangles, isNotEmpty);
      expect(mesh.bounds.sizeX, closeTo(25.0, 0.05));
      expect(mesh.bounds.sizeY, closeTo(40.0, 0.05));
      expect(mesh.bounds.sizeZ, closeTo(0.0, 0.05));
      expect(mesh.surfaceArea, closeTo(1000.0, 10.0)); // 25 x 40 = 1000 area
    });

    test('IgesParser resolves Entity 144 pointing to Entity 128 and applies Entity 124 transformation', () {
      // Entity 124 (Transformation Matrix): Translation by (+100, +200, +50)
      // DE index 1 (D1/D2)
      // Entity 128 (NURBS Surface): DE index 3 (D3/D4), transformed by Entity 124 (pointer 1)
      // Entity 144 (Trimmed Surface): DE index 5 (D5/D6), references surface at DE index 3
      final d1 = '     124       1       0       0       0       0       0       000010001D      1';
      final d2 = '     124       0       1       1       0                               0D      2';
      final d3 = '     128       2       0       0       0       0       1       000010001D      3';
      final d4 = '     128       0       1       1       0                               0D      4';
      final d5 = '     144       4       0       0       0       0       0       000010001D      5';
      final d6 = '     144       0       1       1       0                               0D      6';

      final p1 = '124, 1.0, 0.0, 0.0, 100.0, 0.0, 1.0, 0.0, 200.0, 0.0, 0.0, 1.0, 50.0;   1P      1';
      final p2 = '128, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 3P      2';
      final p3 = '1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 10.0, 0.0, 0.0, 0.0, 10.0, 0.0,     3P      3';
      final p4 = '10.0, 10.0, 0.0, 0.0, 1.0, 0.0, 1.0;                                   3P      4';
      final p5 = '144, 3, 0, 0;                                                           5P      5';

      final igesContent = '$d1\n$d2\n$d3\n$d4\n$d5\n$d6\n$p1\n$p2\n$p3\n$p4\n$p5\n';
      final bytes = Uint8List.fromList(utf8.encode(igesContent));
      final mesh = IgesParser.parseFromBytes(bytes, name: 'transformed_trimmed.iges');

      expect(mesh.triangles, isNotEmpty);
      // Verify translation was applied: X in [100, 110], Y in [200, 210], Z in [50, 50]
      expect(mesh.bounds.min.x, closeTo(100.0, 0.1));
      expect(mesh.bounds.max.x, closeTo(110.0, 0.1));
      expect(mesh.bounds.min.y, closeTo(200.0, 0.1));
      expect(mesh.bounds.max.y, closeTo(210.0, 0.1));
      expect(mesh.bounds.min.z, closeTo(50.0, 0.1));
      expect(mesh.bounds.max.z, closeTo(50.0, 0.1));
    });
  });
}
