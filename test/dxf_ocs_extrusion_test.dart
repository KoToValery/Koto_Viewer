import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_math.dart';

void main() {
  group('OCS & Extrusion Vector (Arbitrary Axis Algorithm)', () {
    test('Identity Extrusion Vector (0, 0, 1)', () {
      final ocs = OcsTransform.fromExtrusion(0, 0, 1);
      expect(ocs.isIdentity, isTrue);

      final p = ocs.toWcs2D(10.0, 20.0);
      expect(p.dx, closeTo(10.0, 1e-6));
      expect(p.dy, closeTo(20.0, 1e-6));

      expect(ocs.angleToWcs(45.0), closeTo(45.0, 1e-6));
      expect(ocs.transformBulge(0.5), equals(0.5));

      final arc = ocs.transformArcAngles(30.0, 120.0);
      expect(arc.startAngleDeg, closeTo(30.0, 1e-6));
      expect(arc.endAngleDeg, closeTo(120.0, 1e-6));
    });

    test('Zero length Extrusion Vector fallback to identity', () {
      final ocs = OcsTransform.fromExtrusion(0, 0, 0);
      expect(ocs.isIdentity, isTrue);
    });

    test('Inverted Extrusion Vector (0, 0, -1) - Mirrored / Flipped Geometry', () {
      final ocs = OcsTransform.fromExtrusion(0, 0, -1);
      expect(ocs.isIdentity, isFalse);
      expect(ocs.nz, equals(-1.0));

      // According to Arbitrary Axis Algorithm:
      // Since |nx| < 1/64 and |ny| < 1/64:
      // Ax = (0, 1, 0) x (0, 0, -1) = (-1, 0, 0) => X_ocs = (-1, 0, 0)
      // Y_ocs = (0, 0, -1) x (-1, 0, 0) = (0, 1, 0)
      expect(ocs.xx, closeTo(-1.0, 1e-6));
      expect(ocs.xy, closeTo(0.0, 1e-6));
      expect(ocs.yx, closeTo(0.0, 1e-6));
      expect(ocs.yy, closeTo(1.0, 1e-6));

      // Point transformation negates X and preserves Y
      final pt = ocs.toWcs2D(25.0, 50.0);
      expect(pt.dx, closeTo(-25.0, 1e-6));
      expect(pt.dy, closeTo(50.0, 1e-6));

      // Bulge sign must be inverted for correct curvature in 2D projection
      expect(ocs.transformBulge(0.4142), closeTo(-0.4142, 1e-6));

      // Arc transformation:
      // OCS arc from 270 deg to 0 (360) deg:
      // In WCS 2D CCW representation: start = 180, end = 270
      final arc = ocs.transformArcAngles(270.0, 0.0);
      expect(arc.startAngleDeg, closeTo(180.0, 1e-6));
      expect(arc.endAngleDeg, closeTo(270.0, 1e-6));
    });

    test('Arbitrary 3D Extrusion Vector generates Orthonormal Basis', () {
      // Tilted normal from ArchiCAD roof / inclined wall
      final ocs = OcsTransform.fromExtrusion(0.3, 0.4, 0.866);
      expect(ocs.isIdentity, isFalse);

      // Verify X_ocs and Y_ocs are unit vectors
      final xLen = math.sqrt(ocs.xx * ocs.xx + ocs.xy * ocs.xy + ocs.xz * ocs.xz);
      final yLen = math.sqrt(ocs.yx * ocs.yx + ocs.yy * ocs.yy + ocs.yz * ocs.yz);
      expect(xLen, closeTo(1.0, 1e-6));
      expect(yLen, closeTo(1.0, 1e-6));

      // Verify orthogonality: X_ocs . Y_ocs == 0
      final dot = ocs.xx * ocs.yx + ocs.xy * ocs.yy + ocs.xz * ocs.yz;
      expect(dot, closeTo(0.0, 1e-6));

      // Verify orthogonality with normal: X_ocs . N == 0 and Y_ocs . N == 0
      final dotXN = ocs.xx * ocs.nx + ocs.xy * ocs.ny + ocs.xz * ocs.nz;
      final dotYN = ocs.yx * ocs.nx + ocs.yy * ocs.ny + ocs.yz * ocs.nz;
      expect(dotXN, closeTo(0.0, 1e-6));
      expect(dotYN, closeTo(0.0, 1e-6));
    });

    test('DXF CIRCLE & ARC parsing with inverted normal (0, 0, -1)', () {
      const dxf = '''0
SECTION
2
ENTITIES
0
CIRCLE
8
0
10
50.0
20
60.0
40
25.0
210
0.0
220
0.0
230
-1.0
0
ARC
8
0
10
100.0
20
200.0
40
30.0
50
270.0
51
0.0
210
0.0
220
0.0
230
-1.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxf);
      expect(doc.entities.length, equals(2));

      final circle = doc.entities[0] as DxfCircle;
      // Center X inverted from 50 to -50
      expect(circle.center.dx, closeTo(-50.0, 1e-6));
      expect(circle.center.dy, closeTo(60.0, 1e-6));
      expect(circle.radius, equals(25.0));

      final arc = doc.entities[1] as DxfArc;
      // Center X inverted from 100 to -100
      expect(arc.center.dx, closeTo(-100.0, 1e-6));
      expect(arc.center.dy, closeTo(200.0, 1e-6));
      expect(arc.radius, equals(30.0));
      // Arc angles properly transformed to CCW 180 -> 270
      expect(arc.startAngleDeg, closeTo(180.0, 1e-6));
      expect(arc.endAngleDeg, closeTo(270.0, 1e-6));
    });

    test('DXF LWPOLYLINE with extrusion vector and bulge', () {
      const dxf = '''0
SECTION
2
ENTITIES
0
LWPOLYLINE
8
0
90
2
70
0
10
10.0
20
20.0
42
0.5
10
30.0
20
40.0
210
0.0
220
0.0
230
-1.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxf);
      expect(doc.entities.length, equals(1));

      final poly = doc.entities.first as DxfLwPolyline;
      expect(poly.vertices.length, equals(2));
      // X coordinates inverted
      expect(poly.vertices[0].x, closeTo(-10.0, 1e-6));
      expect(poly.vertices[0].y, closeTo(20.0, 1e-6));
      // Bulge sign inverted
      expect(poly.vertices[0].bulge, closeTo(-0.5, 1e-6));

      expect(poly.vertices[1].x, closeTo(-30.0, 1e-6));
      expect(poly.vertices[1].y, closeTo(40.0, 1e-6));
    });

    test('DXF TEXT & INSERT with extrusion vector', () {
      const dxf = '''0
SECTION
2
ENTITIES
0
TEXT
8
0
1
Sample Room
10
150.0
20
80.0
40
5.0
50
0.0
210
0.0
220
0.0
230
-1.0
0
INSERT
8
0
2
DOOR_BLOCK
10
200.0
20
300.0
41
1.0
42
1.0
50
90.0
210
0.0
220
0.0
230
-1.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxf);
      expect(doc.entities.length, equals(2));

      final text = doc.entities[0] as DxfText;
      expect(text.text, equals('Sample Room'));
      expect(text.insertPoint.dx, closeTo(-150.0, 1e-6));
      expect(text.insertPoint.dy, closeTo(80.0, 1e-6));
      // 0 deg in OCS (-Z) points in (-1, 0) direction = 180 deg in WCS
      expect(text.rotationDeg, closeTo(180.0, 1e-6));

      final insert = doc.entities[1] as DxfInsert;
      expect(insert.blockName, equals('DOOR_BLOCK'));
      expect(insert.insertPoint.dx, closeTo(-200.0, 1e-6));
      expect(insert.insertPoint.dy, closeTo(300.0, 1e-6));
      // ScaleX negated to mirror block geometry across Y axis
      expect(insert.scaleX, closeTo(-1.0, 1e-6));
      expect(insert.rotationDeg, closeTo(-90.0, 1e-6));
    });
  });
}
