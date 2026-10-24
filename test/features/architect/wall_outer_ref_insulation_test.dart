import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_network.dart';

void main() {
  test('Two exterior walls with outer reference line and insulation at corner', () {
    // Wall A goes horizontally from (0, 0) to (5, 0).
    // Exterior is +Y (left of direction (1, 0)), so normal is (0, 1).
    // Reference line is outer (at Y = 0).
    // Thickness = 0.37 (0.25 core + 0.12 EPS).
    final wallA = ArchitectWall(
      id: 'wallA',
      startPoint: const Offset(0, 0),
      endPoint: const Offset(5, 0),
      thickness: 0.37,
      wallTypeId: 'ext_25_12_eps',
      referenceLine: WallReferenceLine.outer,
      exteriorSide: WallExteriorSide.left,
    );

    // Wall B turns 90 degrees and goes vertically from (5, 0) to (5, -5).
    // Direction is (0, -1). Left of (0, -1) is (+1, 0), so normal is (1, 0) (+X is exterior).
    // Reference line is outer (at X = 5).
    final wallB = ArchitectWall(
      id: 'wallB',
      startPoint: const Offset(5, 0),
      endPoint: const Offset(5, -5),
      thickness: 0.37,
      wallTypeId: 'ext_25_12_eps',
      referenceLine: WallReferenceLine.outer,
      exteriorSide: WallExteriorSide.left,
    );

    final catalog = ArchitectWallType.standardCatalog();
    final layers = ArchitectWallLayers.build([wallA, wallB], catalog);

    print('Body bounds: ${layers.body.getBounds()}');
    print('Core bounds: ${layers.core.getBounds()}');
    print('Insulation bounds: ${layers.insulation.getBounds()}');

    final ptInInsulationA = const Offset(4.75, -0.06);
    final ptInInsulationB = const Offset(4.94, -0.25);
    final ptInCornerInsulation = const Offset(4.94, -0.06);

    print('Does core contain ptInInsulationA (4.75, -0.06)? ${layers.core.contains(ptInInsulationA)}');
    print('Does core contain ptInInsulationB (4.94, -0.25)? ${layers.core.contains(ptInInsulationB)}');
    print('Does core contain ptInCornerInsulation (4.94, -0.06)? ${layers.core.contains(ptInCornerInsulation)}');

    print('Does insulation contain ptInInsulationA? ${layers.insulation.contains(ptInInsulationA)}');
    print('Does insulation contain ptInInsulationB? ${layers.insulation.contains(ptInInsulationB)}');
    print('Does insulation contain ptInCornerInsulation? ${layers.insulation.contains(ptInCornerInsulation)}');

    expect(layers.core.contains(ptInCornerInsulation), isFalse, reason: 'Core must not enter outer corner insulation');
    expect(layers.core.contains(ptInInsulationA), isFalse, reason: 'Core must not enter Wall A insulation');
    expect(layers.core.contains(ptInInsulationB), isFalse, reason: 'Core must not enter Wall B insulation');

    expect(layers.insulation.contains(ptInCornerInsulation), isTrue, reason: 'Insulation must be present at outer corner');
    expect(layers.insulation.contains(ptInInsulationA), isTrue, reason: 'Insulation must be present along Wall A');
    expect(layers.insulation.contains(ptInInsulationB), isTrue, reason: 'Insulation must be present along Wall B');
  });
}
