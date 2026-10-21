import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/components/definitions/furniture_components.dart';
import 'package:kotoview/src/features/architect/components/definitions/kitchen_components.dart';
import 'package:kotoview/src/features/architect/components/definitions/sanitary_components.dart';
import 'package:kotoview/src/features/architect/components/dsl/parametric_script_parser.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/component_geometry_cache.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Architectural Component Library - Coordinate Conventions & Parity', () {
    test('Origin convention: X centered, Y=0 back, Z=0 bottom', () {
      final toiletDef = SanitaryToiletWallHung();
      const params = {'width': 0.36, 'depth': 0.54, 'height': 0.40};
      final geo = toiletDef.generateGeometry(params);

      // Verify 2D Block bounds
      final block = geo.block2d;
      expect(block.bounds.left, closeTo(-0.18, 1e-4));
      expect(block.bounds.right, closeTo(0.18, 1e-4));
      expect(block.bounds.top, closeTo(0.0, 1e-4));
      expect(block.bounds.bottom, closeTo(0.54, 1e-4));

      // Verify 3D Mesh bounds
      final bounds3d = geo.mesh3d.bounds;
      expect(bounds3d.min.x, closeTo(-0.18, 0.03));
      expect(bounds3d.max.x, closeTo(0.18, 0.03));
      expect(bounds3d.min.y, closeTo(0.0, 0.02));
      expect(bounds3d.max.y, closeTo(0.54, 0.02));
      expect(bounds3d.min.z, closeTo(0.0, 0.02));
      expect(bounds3d.max.z, closeTo(0.40, 0.02));
    });

    test('Double Bed has correct headboard at Y=0 and dimensions', () {
      final bedDef = FurnitureBedDouble();
      const params = {'width': 1.80, 'depth': 2.00, 'height': 0.95};
      final geo = bedDef.generateGeometry(params);

      expect(geo.block2d.bounds.width, closeTo(1.80, 1e-4));
      expect(geo.block2d.bounds.height, closeTo(2.00, 1e-4));
      expect(geo.mesh3d.triangles.isNotEmpty, isTrue);
    });

    test('Kitchen Base Cabinet has correct modular dimensions', () {
      final cabDef = KitchenBaseCabinet();
      const params = {'width': 0.60, 'depth': 0.60, 'height': 0.86};
      final geo = cabDef.generateGeometry(params);

      expect(geo.block2d.bounds.width, closeTo(0.60, 1e-4));
      expect(geo.block2d.bounds.height, closeTo(0.60, 1e-4));
      expect(geo.mesh3d.triangles.isNotEmpty, isTrue);
    });
  });

  group('Geometry Cache & glTF Conversion', () {
    test('ComponentGeometryCache reuses geometry for identical parameters', () {
      final cache = ComponentGeometryCache.instance;
      cache.clear();

      final toilet = SanitaryToiletWallHung();
      const paramsA = {'width': 0.36, 'depth': 0.54, 'height': 0.40};
      const paramsB = {'width': 0.3600001, 'depth': 0.5400001, 'height': 0.40};

      final geo1 = cache.getOrCompute(toilet, paramsA);
      final geo2 = cache.getOrCompute(toilet, paramsB);

      // Should return identical cached instance due to millimetre quantization
      expect(identical(geo1, geo2), isTrue);
      expect(cache.size, equals(1));
    });

    test('ComponentGltfCoordinateConverter converts Z-up to Y-up', () {
      const archPoint = Vector3(1.5, 2.0, 3.5);
      final gltfPoint = ComponentGltfCoordinateConverter.toGltfVector(archPoint);

      // X remains X
      expect(gltfPoint.x, closeTo(1.5, 1e-6));
      // Y_gltf becomes Z_arch
      expect(gltfPoint.y, closeTo(3.5, 1e-6));
      // Z_gltf becomes -Y_arch
      expect(gltfPoint.z, closeTo(-2.0, 1e-6));
    });
  });

  group('DSL Script Parser & In-App Component Generator', () {
    test('Parses JSON script with math expressions into working 3D/2D definition', () {
      const script = '''
      {
        "id": "test_desk",
        "name": "Custom Standing Desk",
        "category": "office",
        "placementMode": "wallAttached",
        "defaultParams": { "width": 1.40, "depth": 0.70, "height": 0.75 },
        "solids": [
          {
            "type": "box",
            "origin": ["-width/2", 0.0, "height - 0.04"],
            "size": ["width", "depth", 0.04],
            "color": "#8D6E63"
          }
        ],
        "symbol2d": {
          "details": [
            {
              "type": "line",
              "from": ["-width/2", 0.0],
              "to": ["width/2", "depth"]
            }
          ]
        }
      }
      ''';

      final def = ParametricScriptParser.parse(script);
      expect(def.id, equals('test_desk'));
      expect(def.category, equals(ArchitectComponentCategory.office));
      expect(def.placementMode, equals(ComponentPlacementMode.wallAttached));

      final geo = def.generateGeometry({'width': 1.60, 'depth': 0.80, 'height': 0.80});
      expect(geo.block2d.bounds.width, closeTo(1.60, 1e-4));
      expect(geo.block2d.bounds.height, closeTo(0.80, 1e-4));
      expect(geo.mesh3d.triangles.isNotEmpty, isTrue);
    });
  });

  group('Storey Serialization & Deserialization with Components', () {
    test('ArchitectStorey round-trips components list through JSON', () {
      const instance = ArchitectComponentInstance(
        id: 'comp_101',
        definitionId: 'sanitary_toilet_wall_hung',
        position: Offset(2.4, 3.8),
        elevationOffset: 0.15,
        rotation: 1.5707963,
        parameters: {'width': 0.36, 'depth': 0.54, 'height': 0.40},
      );

      final storey = const ArchitectStorey(
        id: 'storey_1',
        name: 'First Floor',
        components: [instance],
      );

      final json = storey.toJson();
      final restored = ArchitectStorey.fromJson(json);

      expect(restored.components.length, equals(1));
      final rComp = restored.components.first;
      expect(rComp.id, equals('comp_101'));
      expect(rComp.definitionId, equals('sanitary_toilet_wall_hung'));
      expect(rComp.position.dx, closeTo(2.4, 1e-4));
      expect(rComp.position.dy, closeTo(3.8, 1e-4));
      expect(rComp.elevationOffset, closeTo(0.15, 1e-4));
      expect(rComp.rotation, closeTo(1.5707963, 1e-4));
      expect(rComp.parameters['width'], equals(0.36));
    });
  });
}
