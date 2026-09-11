import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/ifc_parser.dart';

void main() {
  test('Window and door opening voids in wall_openings.ifc', () {
    final file = File(r'C:\Users\Creator\Dropbox\test_files\wall_openings.ifc');
    if (!file.existsSync()) return;

    final content = file.readAsStringSync();
    final model = IfcParser.parseFromText(content);

    final window = model.elements.firstWhere((e) => e.id == 161);
    final door = model.elements.firstWhere((e) => e.id == 178);
    final wall = model.elements.firstWhere((e) => e.id == 118);

    // 1. Window bounds match opening cutout (900mm width, 1510mm with exterior sill drip)
    expect(window.bounds.sizeX, closeTo(900.0, 1.0));
    expect(window.bounds.sizeZ, closeTo(1510.0, 1.0));


    // 2. Wall does not contain reveal quads overlapping with the door casing
    // Door #178 spans X in [-411.5, 288.5]. Any reveal quads directly at the jambs
    // inside the wall thickness should not duplicate the door casing.
    final wallTrisAtDoorJambs = wall.triangles.where((t) {
      final minX = t.v0.x < t.v1.x ? (t.v0.x < t.v2.x ? t.v0.x : t.v2.x) : (t.v1.x < t.v2.x ? t.v1.x : t.v2.x);
      final maxX = t.v0.x > t.v1.x ? (t.v0.x > t.v2.x ? t.v0.x : t.v2.x) : (t.v1.x > t.v2.x ? t.v1.x : t.v2.x);
      return (minX >= -412.0 && maxX <= -410.0) || (minX >= 287.5 && maxX <= 289.5);
    }).toList();
    expect(wallTrisAtDoorJambs.isEmpty, isTrue,
        reason: 'Door opening should not duplicate casing with wall reveal quads');

    // 3. Wall does not contain sill quads penetrating through the window frame
    // Window frame is at Y in [-389.9, -314.9] at Z = 900.
    final wallTrisPenetratingWindowFrame = wall.triangles.where((t) {
      final z0 = t.v0.z; final z1 = t.v1.z; final z2 = t.v2.z;
      if ((z0 - 900.0).abs() < 1.0 && (z1 - 900.0).abs() < 1.0 && (z2 - 900.0).abs() < 1.0) {
        final minX = t.v0.x < t.v1.x ? (t.v0.x < t.v2.x ? t.v0.x : t.v2.x) : (t.v1.x < t.v2.x ? t.v1.x : t.v2.x);
        final maxX = t.v0.x > t.v1.x ? (t.v0.x > t.v2.x ? t.v0.x : t.v2.x) : (t.v1.x > t.v2.x ? t.v1.x : t.v2.x);
        // Only inspect inside the window opening X range [865, 1764]
        if (minX >= 865.0 && maxX <= 1764.0) {
          final minY = t.v0.y < t.v1.y ? (t.v0.y < t.v2.y ? t.v0.y : t.v2.y) : (t.v1.y < t.v2.y ? t.v1.y : t.v2.y);
          final maxY = t.v0.y > t.v1.y ? (t.v0.y > t.v2.y ? t.v0.y : t.v2.y) : (t.v1.y > t.v2.y ? t.v1.y : t.v2.y);
          return minY < -315.0 && maxY > -389.0;
        }
      }
      return false;
    }).toList();

    expect(wallTrisPenetratingWindowFrame.isEmpty, isTrue,

        reason: 'Wall sill quad must not penetrate window frame');

    // 4. Empty opening #134 maintains full reveals
    // Opening #134 is at X in [2257.6, 3157.6], Z in [900, 1800]
    final opening134Reveals = wall.triangles.where((t) {
      final minX = t.v0.x < t.v1.x ? (t.v0.x < t.v2.x ? t.v0.x : t.v2.x) : (t.v1.x < t.v2.x ? t.v1.x : t.v2.x);
      final maxX = t.v0.x > t.v1.x ? (t.v0.x > t.v2.x ? t.v0.x : t.v2.x) : (t.v1.x > t.v2.x ? t.v1.x : t.v2.x);
      return minX >= 2250.0 && maxX <= 3165.0;
    }).toList();
    expect(opening134Reveals.isNotEmpty, isTrue,
        reason: 'Empty opening #134 must retain reveal surfaces');
  });
}
