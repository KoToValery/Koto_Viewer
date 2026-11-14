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

    final ptInInsulationA = const Offset(4.75, 0.06);
    final ptInInsulationB = const Offset(5.06, -0.25);
    final ptInCornerInsulation = const Offset(5.06, 0.06);

    expect(layers.core.contains(ptInCornerInsulation), isFalse, reason: 'Core must not enter outer corner insulation');
    expect(layers.core.contains(ptInInsulationA), isFalse, reason: 'Core must not enter Wall A insulation');
    expect(layers.core.contains(ptInInsulationB), isFalse, reason: 'Core must not enter Wall B insulation');

    expect(layers.insulation.contains(ptInCornerInsulation), isTrue, reason: 'Insulation must be present at outer corner');
    expect(layers.insulation.contains(ptInInsulationA), isTrue, reason: 'Insulation must be present along Wall A');
    expect(layers.insulation.contains(ptInInsulationB), isTrue, reason: 'Insulation must be present along Wall B');

    // Outer leading line sits strictly on the outer core face (Y = 0 for A, X = 5 for B).
    expect(wallA.coreCenterStart.dy, closeTo(-0.125, 1e-9));
    expect(wallB.coreCenterStart.dx, closeTo(4.875, 1e-9));
  });
}
