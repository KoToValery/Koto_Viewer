import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/ifc_parser.dart';

void main() {
  test('Composite multi-layer roof structure in roof.ifc constructs 290mm thick outer shell', () {
    final file = File(r'C:\Users\Creator\Dropbox\test_files\roof.ifc');
    expect(file.existsSync(), isTrue, reason: 'roof.ifc must exist');

    final content = file.readAsStringSync();
    final model = IfcParser.parseFromText(content);

    // Verify roof element is present
    expect(model.elements.length, equals(1));

    final mainRoof = model.elements.first;
    expect(mainRoof.name, equals('RT - 005'));
    expect(mainRoof.category, equals('Roof'));
    expect(mainRoof.ifcType, equals('IFCSLAB'));

    // Verify full composite thickness is preserved (Z min is 372.4, not 668.5)
    // Total vertical span is over 2100mm, with the full 290mm composite slab thickness
    expect(mainRoof.bounds.min.z, closeTo(372.4, 1.0));
    expect(mainRoof.bounds.max.z, closeTo(2502.2, 1.0));

    // Outer envelope consists of:
    // - 6 top triangles (exterior tiles)
    // - 6 bottom triangles (ceiling underside)
    // - 48 side triangles (full 290mm fascia edge around perimeter across all 6 layers)
    expect(mainRoof.triangles.length, equals(60));

    final topFaces = mainRoof.triangles.where((t) => t.normal.z > 0.2).toList();
    final bottomFaces = mainRoof.triangles.where((t) => t.normal.z < -0.2).toList();
    final sideFaces = mainRoof.triangles.where((t) => t.normal.z.abs() <= 0.2).toList();

    expect(topFaces.length, equals(6));
    expect(bottomFaces.length, equals(6));
    expect(sideFaces.length, equals(48));

    // Verify top faces are colored with French Red roof tile color
    for (final tri in topFaces) {
      expect(tri.color, isNotNull);
      expect(tri.color!.r, greaterThan(0.8));
      expect(tri.color!.g, closeTo(0.38, 0.05));
      expect(tri.color!.b, closeTo(0.13, 0.05));
    }

    // Verify side faces use the fascia pine wood styling
    for (final tri in sideFaces) {
      expect(tri.color, isNotNull);
      expect(tri.color!.r, greaterThan(0.9));
    }

    // Slabs with full thickness are closed 3D solids and should not be double-sided
    for (final tri in mainRoof.triangles) {
      expect(tri.isDoubleSided, isFalse);
    }
  });
}
